-- GuildService: guilds must pick a side (Marine or Pirate) on creation
-- A player's faction comes from their guild (leaving = back to Civilian)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Modules.Net)

local GS = {}
local R
local store
local memory = {}
local cache = {} -- id -> { data, loaded }

function GS.Init(registry)
	R = registry
	pcall(function()
		store = DataStoreService:GetDataStore(GameConfig.GuildStoreName)
		store:GetAsync("__probe")
	end)
end

local function read(key)
	if not store then
		return memory[key]
	end
	local ok, v = pcall(store.GetAsync, store, key)
	return ok and v or nil
end

local function update(key, fn)
	if not store then
		memory[key] = fn(memory[key])
		return memory[key]
	end
	local result
	local ok, err = pcall(function()
		result = store:UpdateAsync(key, fn)
	end)
	if not ok then
		warn("[GuildService]", err)
	end
	return result
end

function GS.Get(id, fresh)
	if not id then
		return nil
	end
	local c = cache[id]
	if c and not fresh and os.clock() - c.loaded < 60 then
		return c.data
	end
	local data = read("g_" .. id)
	cache[id] = { data = data, loaded = os.clock() }
	return data
end

local function setPlayerGuild(player, g)
	local p = R.DataService.Get(player)
	if not p then
		return
	end
	if g then
		p.guildId = g.id
		p.faction = g.faction
		player:SetAttribute("GuildId", g.id)
		player:SetAttribute("GuildName", g.name)
	else
		p.guildId = nil
		p.faction = "None"
		player:SetAttribute("GuildId", nil)
		player:SetAttribute("GuildName", nil)
	end
	player:SetAttribute("Faction", p.faction)
	R.PlayerService.MarkDirty(player)
end

function GS.OnPlayerJoin(player)
	local p = R.DataService.Get(player)
	if p and p.guildId then
		task.spawn(function()
			local g = GS.Get(p.guildId, true)
			if g and g.members[tostring(player.UserId)] then
				setPlayerGuild(player, g)
			else
				setPlayerGuild(player, nil)
			end
		end)
	end
end

local function pushGuild(player)
	local p = R.DataService.Get(player)
	local g = p and GS.Get(p.guildId)
	Net.Push(player, "Guild", { guild = g })
end

local function addIndex(g)
	update("index", function(list)
		list = list or {}
		for i, e in ipairs(list) do
			if e.id == g.id then
				table.remove(list, i)
				break
			end
		end
		local count = 0
		for _ in pairs(g.members) do
			count += 1
		end
		if count > 0 then
			table.insert(list, 1, { id = g.id, name = g.name, faction = g.faction, count = count, level = g.level })
		end
		while #list > 200 do
			table.remove(list)
		end
		return list
	end)
end

function GS.Start()
	Net.Handle("GuildCreate", function(player, data)
		local p = R.DataService.Get(player)
		local name = type(data.name) == "string" and data.name:sub(1, 20) or ""
		local faction = data.faction
		if faction ~= "Marine" and faction ~= "Pirate" then
			return false, "Choose a side: Marine or Pirate"
		end
		if #name < 3 then
			return false, "Guild name needs at least 3 characters"
		end
		if p.guildId then
			return false, "You are already in a guild"
		end
		if p.baseLevel < GameConfig.GuildCreateLevel then
			return false, "Requires Lv." .. GameConfig.GuildCreateLevel
		end
		-- Filter the name with TextService (Roblox rules)
		local okFilter, filtered = pcall(function()
			local result = game:GetService("TextService"):FilterStringAsync(name, player.UserId)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not okFilter or filtered ~= name then
			return false, "That guild name is not allowed"
		end
		if not R.PlayerService.AddBeli(player, -GameConfig.GuildCreateCost) then
			return false, "Costs 🪙" .. GameConfig.GuildCreateCost
		end
		local id = HttpService:GenerateGUID(false):sub(1, 12)
		local g = {
			id = id,
			name = name,
			faction = faction,
			leader = player.UserId,
			members = { [tostring(player.UserId)] = { name = player.DisplayName, rank = "Leader" } },
			level = 1,
			exp = 0,
			created = os.time(),
		}
		update("g_" .. id, function()
			return g
		end)
		cache[id] = { data = g, loaded = os.clock() }
		addIndex(g)
		setPlayerGuild(player, g)
		pushGuild(player)
		Net.PushAll("Announce", { text = (faction == "Marine" and "⚓ Marine squadron " or "☠️ Pirate crew ") .. name .. " has been founded!" })
		return true, "Guild created"
	end, 3)

	Net.Handle("GuildList", function()
		return { ok = true, data = read("index") or {} }
	end, 2)

	Net.Handle("GuildInfo", function(player)
		pushGuild(player)
		return true
	end, 1)

	Net.Handle("GuildJoin", function(player, data)
		local p = R.DataService.Get(player)
		if p.guildId then
			return false, "Leave your current guild first"
		end
		local joined
		local err
		update("g_" .. tostring(data.id), function(g)
			if not g then
				err = "Guild not found"
				return nil
			end
			local count = 0
			for _ in pairs(g.members) do
				count += 1
			end
			if count >= GameConfig.GuildMaxMembers then
				err = "Guild is full"
				return nil
			end
			g.members[tostring(player.UserId)] = { name = player.DisplayName, rank = "Member" }
			joined = g
			return g
		end)
		if not joined then
			return false, err or "Could not join guild"
		end
		cache[joined.id] = { data = joined, loaded = os.clock() }
		addIndex(joined)
		setPlayerGuild(player, joined)
		pushGuild(player)
		return true, "Joined " .. joined.name
	end, 2)

	Net.Handle("GuildLeave", function(player)
		local p = R.DataService.Get(player)
		if not p.guildId then
			return false
		end
		local result = update("g_" .. p.guildId, function(g)
			if not g then
				return nil
			end
			g.members[tostring(player.UserId)] = nil
			if g.leader == player.UserId then
				local nextLeader = next(g.members)
				g.leader = nextLeader and tonumber(nextLeader) or 0
				if nextLeader then
					g.members[nextLeader].rank = "Leader"
				end
			end
			return g
		end)
		if result then
			cache[result.id] = { data = result, loaded = os.clock() }
			addIndex(result)
		end
		setPlayerGuild(player, nil)
		pushGuild(player)
		return true, "You left the guild"
	end, 2)

	Net.Handle("GuildKick", function(player, data)
		local p = R.DataService.Get(player)
		local targetId = tostring(data.userId)
		local ok = false
		local result = update("g_" .. tostring(p.guildId), function(g)
			if not g or g.leader ~= player.UserId or targetId == tostring(player.UserId) then
				return nil
			end
			g.members[targetId] = nil
			ok = true
			return g
		end)
		if not ok then
			return false, "No permission"
		end
		cache[result.id] = { data = result, loaded = os.clock() }
		local target = Players:GetPlayerByUserId(tonumber(targetId) or 0)
		if target then
			setPlayerGuild(target, nil)
			pushGuild(target)
		end
		pushGuild(player)
		return true
	end, 1)
end

return GS
