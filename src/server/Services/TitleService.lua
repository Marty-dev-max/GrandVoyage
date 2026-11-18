-- TitleService: which titles a player has (Config/Titles), the equipped one, and the attributes everyone's client reads
-- (Title = name, TitleRarity = tier, TitleId). Conditions are checked every few seconds; once met, a title is kept for
-- good in p.titles (a bounty that drops or a fruit that changes never takes a title away). Default title: Greenhorn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local TitlesCfg = require(Shared.Config.Titles)
local Net = require(Shared.Modules.Net)

local TS = {}
local R
local OWNER_ID = 1527424396 -- the game's creator gets the Secret developer title

local function met(p, t)
	local n = t.need
	if t.soon then
		-- seas that are not out yet: the condition still counts if somebody gets there (bounty can already climb)
		if n.level then
			return false
		end
	end
	if n.granted then
		return false
	elseif n.level then
		return (p.baseLevel or 1) >= n.level
	elseif n.bounty then
		return (p.bounty or 0) >= n.bounty
	elseif n.merit then
		return (p.merit or 0) >= n.merit
	elseif n.job then
		if p.class == n.class and (p.jobLevel or 1) >= n.job then
			return true
		end
		local saved = p.classProgress and p.classProgress[n.class]
		return saved ~= nil and (saved.jobLevel or 1) >= n.job
	elseif n.mastery then
		return p.fruit ~= nil and p.fruit.id == n.fruit and (p.fruit.mastery or 0) >= n.mastery
	elseif n.achievement then
		return p.ach ~= nil and p.ach.done ~= nil and p.ach.done[n.achievement] == true
	end
	return false
end

function TS.Has(p, id)
	return p.titles ~= nil and p.titles[id] == true
end

function TS.SetAttributes(player, p)
	local id = p.title
	if id == nil then
		id = TitlesCfg.Default
	end
	local t = id ~= "" and TitlesCfg.ById[id] or nil
	if t and not TS.Has(p, t.id) then
		t = nil
	end
	player:SetAttribute("Title", t and t.name or nil)
	player:SetAttribute("TitleRarity", t and t.tier or nil)
	player:SetAttribute("TitleId", t and t.id or nil)
end

-- check every title; tell the player about new ones
function TS.Refresh(player, quiet)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	p.titles = p.titles or {}
	local fresh = {}
	for _, t in ipairs(TitlesCfg.List) do
		if not p.titles[t.id] and met(p, t) then
			p.titles[t.id] = true
			table.insert(fresh, t)
		end
	end
	if player.UserId == OWNER_ID and not p.titles.Developer then
		p.titles.Developer = true
	end
	if #fresh > 0 then
		R.PlayerService.MarkDirty(player)
		if not quiet then
			for _, t in ipairs(fresh) do
				Net.Push(player, "TitleUnlocked", { id = t.id, name = t.name, tier = t.tier })
			end
		end
	end
	TS.SetAttributes(player, p)
end

-- events / admin: give a Special title
function TS.Grant(player, id)
	local p = R.PlayerService.Profile(player)
	if p and TitlesCfg.ById[id] then
		p.titles = p.titles or {}
		p.titles[id] = true
		R.PlayerService.MarkDirty(player)
		Net.Push(player, "TitleUnlocked", { id = id, name = TitlesCfg.ById[id].name, tier = TitlesCfg.ById[id].tier })
	end
end

function TS.Init(registry)
	R = registry
end

function TS.Start()
	Net.Handle("SetTitle", function(player, data)
		local p = R.PlayerService.Profile(player)
		if not p then
			return false
		end
		local id = data.id
		if id == nil or id == "" then
			p.title = "" -- no title
		else
			id = tostring(id)
			if not TitlesCfg.ById[id] or not TS.Has(p, id) then
				return false, "Title not unlocked yet"
			end
			p.title = id
		end
		TS.SetAttributes(player, p)
		R.PlayerService.MarkDirty(player)
		return true
	end, 0.5)
	-- the first check is quiet (no flood of "unlocked" toasts on join), then every 5 s
	R.DataService.Loaded:Connect(function(player) -- v0.24.0: once a character slot is loaded (title menu)
		task.delay(3, function()
			TS.Refresh(player, true)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(TS.Refresh, player, true)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(TS.Refresh, player)
			end
		end
	end)
end

return TS
