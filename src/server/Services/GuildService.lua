-- GuildService = CREWS for players (v0.25.108, owner: "crew" = your shipmates; code, saves and the DataStore keep the
-- guild names). Forming a crew picks no side: a player's faction is their own (p.faction): Marines enlist / resign at the
-- Marine Registrar in Conch Bay, anyone else may raise the Jolly Roger (Pirate) from the Crew window (SetFaction).
-- Crewmates are put in one party as they come online; leaders/members invite online players by name.
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
		player:SetAttribute("GuildId", g.id)
		player:SetAttribute("GuildName", g.name)
	else
		p.guildId = nil
		player:SetAttribute("GuildId", nil)
		player:SetAttribute("GuildName", nil)
	end
	R.PlayerService.MarkDirty(player)
end

-- v0.25.108: crewmates sail together: join the party of the first online crewmate that has room
local function crewParty(player)
	local id = player:GetAttribute("GuildId")
	if not id or not R.PartyService.Join then
		return
	end
	for _, mate in ipairs(Players:GetPlayers()) do
		if mate ~= player and mate:GetAttribute("GuildId") == id and R.PartyService.Join(player, mate) then
			R.PlayerService.Notify(player, "You joined your crew's party", "good")
			return
		end
	end
end

function GS.OnPlayerJoin(player)
	local p = R.DataService.Get(player)
	if p and p.guildId then
		task.spawn(function()
			local g = GS.Get(p.guildId, true)
			if g and g.members[tostring(player.UserId)] then
				setPlayerGuild(player, g)
				crewParty(player)
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
			table.insert(list, 1, { id = g.id, name = g.name, count = count, level = g.level })
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
		local name = type(data) == "table" and type(data.name) == "string" and data.name:sub(1, 20) or ""
		if #name < 3 then
			return false, "Crew name needs at least 3 characters"
		end
		if p.guildId then
			return false, "You are already in a crew"
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
			return false, "That crew name is not allowed"
		end
		if not R.PlayerService.AddBeli(player, -GameConfig.GuildCreateCost) then
			return false, "Costs 🪙" .. GameConfig.GuildCreateCost
		end
		local id = HttpService:GenerateGUID(false):sub(1, 12)
		local g = {
			id = id,
			name = name,
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
		Net.PushAll("Announce", { text = "🏴 The crew " .. name .. " has set sail!" })
		return true, "Crew formed"
	end, 3)

	Net.Handle("GuildList", function()
		return { ok = true, data = read("index") or {} }
	end, 2)

	Net.Handle("GuildInfo", function(player)
		pushGuild(player)
		return true
	end, 1)

	local function joinCrew(player, id)
		local p = R.DataService.Get(player)
		if p.guildId then
			return false, "Leave your current crew first"
		end
		local joined
		local err
		update("g_" .. tostring(id), function(g)
			if not g then
				err = "Crew not found"
				return nil
			end
			local count = 0
			for _ in pairs(g.members) do
				count += 1
			end
			if count >= GameConfig.GuildMaxMembers then
				err = "Crew is full"
				return nil
			end
			g.members[tostring(player.UserId)] = { name = player.DisplayName, rank = "Member" }
			joined = g
			return g
		end)
		if not joined then
			return false, err or "Could not join the crew"
		end
		cache[joined.id] = { data = joined, loaded = os.clock() }
		addIndex(joined)
		setPlayerGuild(player, joined)
		pushGuild(player)
		for _, mate in ipairs(Players:GetPlayers()) do
			if mate ~= player and mate:GetAttribute("GuildId") == joined.id then
				pushGuild(mate)
			end
		end
		crewParty(player)
		return true, "Joined " .. joined.name
	end

	Net.Handle("GuildJoin", function(player, data)
		return joinCrew(player, type(data) == "table" and data.id)
	end, 2)

	-- v0.25.108: invite an online player by name (Roblox name or display name); they answer a YES / NO prompt
	local invites = {} -- target -> { from, id, expires }
	Net.Handle("CrewInvite", function(player, data)
		local p = R.DataService.Get(player)
		local want = type(data) == "table" and type(data.name) == "string" and string.lower(data.name:sub(1, 40)) or ""
		if not p.guildId then
			return false, "Form or join a crew first"
		end
		local target
		for _, pl in ipairs(Players:GetPlayers()) do
			if string.lower(pl.Name) == want or string.lower(pl.DisplayName) == want then
				target = pl
				break
			end
		end
		if not target or target == player then
			return false, "No player named that is in this server"
		end
		if target:GetAttribute("GuildId") then
			return false, target.DisplayName .. " is already in a crew"
		end
		local g = GS.Get(p.guildId)
		invites[target] = { from = player, id = p.guildId, expires = os.clock() + 60 }
		Net.Push(target, "Prompt", { kind = "CrewInvite", text = player.DisplayName .. " invites you to join the crew " .. (g and g.name or "") .. "!", from = player.UserId })
		return true, "Invite sent to " .. target.DisplayName
	end, 1)

	Net.Handle("CrewRespond", function(player, data)
		local inv = invites[player]
		invites[player] = nil
		if not inv or os.clock() > inv.expires then
			return false, "Invite expired"
		end
		if not (type(data) == "table" and data.accept) then
			return true
		end
		return joinCrew(player, inv.id)
	end, 0.5)

	-- v0.25.108: a player's own side. Marine = enlist / resign at the Marine Registrar (Conch Bay); Pirate = raise the
	-- Jolly Roger anywhere (not while a Marine)
	Net.Handle("SetFaction", function(player, data)
		local p = R.DataService.Get(player)
		local want = type(data) == "table" and data.faction
		local cur = p.faction or "None"
		if p.baseLevel < GameConfig.GuildCreateLevel then
			return false, "Requires Lv." .. GameConfig.GuildCreateLevel
		end
		local atDesk = R.WorldBuilder.NearNPC(player, "Marine")
		if want == "Marine" then
			if cur == "Marine" then
				return false, "You are already a Marine"
			end
			if not atDesk then
				return false, "Enlist at the Marine Registrar in Conch Bay"
			end
			if cur == "Pirate" and (p.bounty or 0) > 0 then
				return false, "Wanted pirates cannot enlist"
			end
		elseif want == "Pirate" then
			if cur == "Pirate" then
				return false, "You already fly the Jolly Roger"
			end
			if cur == "Marine" then
				return false, "Resign from the Marines first (Marine Registrar, Conch Bay)"
			end
		elseif want == "None" then
			if cur ~= "Marine" then
				return false, "Only Marines can resign"
			end
			if not atDesk then
				return false, "Resign at the Marine Registrar in Conch Bay"
			end
		else
			return false, "Unknown side"
		end
		p.faction = want
		player:SetAttribute("Faction", want)
		R.PlayerService.MarkDirty(player)
		if want == "Marine" then
			Net.PushAll("Announce", { text = "⚓ " .. player.DisplayName .. " enlisted in the Marines!" })
		elseif want == "Pirate" then
			Net.PushAll("Announce", { text = "☠️ " .. player.DisplayName .. " raised the Jolly Roger!" })
		end
		return true, want == "None" and "You are a Civilian again" or ("You are now a " .. want)
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
		return true, "You left the crew"
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
