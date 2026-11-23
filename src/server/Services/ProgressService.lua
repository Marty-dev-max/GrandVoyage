-- ProgressService: daily quests (Config/Dailies) and achievements + titles (Config/Achievements).
-- Every gameplay event already flows through QuestService.Event, which forwards here (one funnel for all progress).
-- Profile: daily = { day, list = { { id, kind, target, count, progress, claimed } }, bonusClaimed }
--          ach = { counters = { [key] = n }, done = { [id] = true }, claimed = { [id] = true } }, title = achievement id
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Dailies = require(Shared.Config.Dailies)
local Hunts = require(Shared.Config.Hunts)
local Achievements = require(Shared.Config.Achievements)
local Monsters = require(Shared.Config.Monsters)
local Islands = require(Shared.Config.Islands)
local Quests = require(Shared.Config.Quests)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local PG = {}
local R

local function today()
	return os.date("!%Y%m%d")
end

-- monsters that live on islands (good daily targets)
local islandMonsters = {}
for _, isl in ipairs(Islands.List) do
	for _, sp in ipairs(isl.spawns) do
		local def = Monsters[sp.monster]
		if def then
			table.insert(islandMonsters, { id = sp.monster, level = def.level, name = def.name })
		end
	end
end

local function pickLocalMonster(level, rng)
	local best = {}
	for _, m in ipairs(islandMonsters) do
		if m.level <= level + 3 and m.level >= level - 8 then
			table.insert(best, m)
		end
	end
	if #best == 0 then
		-- fall back to the strongest monster at or below your level
		local top
		for _, m in ipairs(islandMonsters) do
			if m.level <= level and (not top or m.level > top.level) then
				top = m
			end
		end
		return top or islandMonsters[1]
	end
	return best[rng:NextInteger(1, #best)]
end

-- hunts (Config/Hunts): a monster that lives on an island; the reward pays out by itself when the count is reached
-- and the same hunt starts again (v0.25.86, owner: AFK-friendly, no claim button)
local function huntDef(id)
	local def = type(id) == "string" and Monsters[id]
	if not def then
		return nil
	end
	for _, m in ipairs(islandMonsters) do
		if m.id == id then
			return def
		end
	end
	return nil
end

local function payHunt(player, p, def)
	p.hunt.progress = 0
	local exp = math.floor(def.exp * Hunts.Count * Hunts.ExpMult)
	local job = math.floor((def.jobExp or 0) * Hunts.Count * Hunts.ExpMult)
	local b = def.beli or { 0, 0 }
	local beli = math.floor((b[1] + b[2]) / 2 * Hunts.Count * Hunts.BeliMult)
	R.PlayerService.GiveExp(player, exp, job)
	R.PlayerService.AddBeli(player, beli)
	local got = {}
	for _, it in ipairs(Hunts.Items) do
		R.InventoryService.AddItem(player, it[1], it[2])
		table.insert(got, { id = it[1], qty = it[2] })
	end
	Net.Push(player, "Loot", { beli = beli, items = got })
	Net.Push(player, "Notice", { text = "HUNT COMPLETE  •  reward paid, next round started", color = "Green" })
	R.PlayerService.MarkDirty(player)
end

-- ===== dailies =====
local function rollDailies(player, p)
	local rng = Random.new(player.UserId * 7 + tonumber(today()))
	local eligible = {}
	for _, t in ipairs(Dailies.Pool) do
		if p.baseLevel >= (t.minLevel or 1) and (not t.needsFruit or p.fruit) then
			table.insert(eligible, t)
		end
	end
	local list = {}
	while #list < Dailies.Count and #eligible > 0 do
		local t = table.remove(eligible, rng:NextInteger(1, #eligible))
		local entry = { id = t.id, kind = t.kind, count = t.count, progress = 0, claimed = false }
		if t.target == "local" then
			local m = pickLocalMonster(p.baseLevel, rng)
			entry.target = m.id
			entry.targetName = m.name
		end
		table.insert(list, entry)
	end
	p.daily = { day = today(), list = list, bonusClaimed = false }
end

local function daily(player, p)
	if type(p.daily) ~= "table" or p.daily.day ~= today() then
		rollDailies(player, p)
		R.PlayerService.MarkDirty(player)
	end
	return p.daily
end
PG.Daily = daily

local function ach(p)
	if type(p.ach) ~= "table" then
		p.ach = { counters = {}, done = {}, claimed = {} }
	end
	return p.ach
end

local function finishAchievement(player, a)
	local p = R.PlayerService.Profile(player)
	local st = ach(p)
	if st.done[a.id] then
		return
	end
	st.done[a.id] = true
	R.PlayerService.MarkDirty(player)
	Net.Push(player, "Achievement", { id = a.id, name = a.name, icon = a.icon, rarity = a.rarity or "Rare", title = a.title })
end

-- counter achievements
local function bump(player, p, key, amount)
	local st = ach(p)
	st.counters[key] = (st.counters[key] or 0) + amount
	for _, a in ipairs(Achievements.List) do
		if a.counter == key and not st.done[a.id] and st.counters[key] >= a.count then
			finishAchievement(player, a)
		end
	end
end

function PG.Event(player, kind, target, amount)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	amount = amount or 1
	-- dailies
	local d = daily(player, p)
	for _, e in ipairs(d.list) do
		if e.kind == kind and (e.target == nil or e.target == target) and e.progress < e.count then
			e.progress = math.min(e.count, e.progress + amount)
			if e.progress >= e.count then
				Net.Push(player, "Notice", { text = "DAILY COMPLETE  •  claim it in Quests (J)", color = "Green" })
			end
			R.PlayerService.MarkDirty(player)
		end
	end
	-- repeatable hunt (v0.25.18)
	local h = p.hunt
	if kind == "Kill" and type(h) == "table" and h.id == target and (h.progress or 0) < Hunts.Count then
		h.progress = math.min(Hunts.Count, (h.progress or 0) + amount)
		local def = h.progress >= Hunts.Count and huntDef(h.id)
		if def then
			payHunt(player, p, def)
		end
		R.PlayerService.MarkDirty(player)
	end
	-- achievement counters
	bump(player, p, kind, amount)
	if target then
		bump(player, p, kind .. ":" .. tostring(target), amount)
	end
end

-- state achievements (checked on every profile sync)
function PG.Check(player)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	daily(player, p) -- rolls today's dailies (also covers players who joined before this service started)
	local st = ach(p)
	local function count(t)
		local n = 0
		for _ in pairs(t or {}) do
			n += 1
		end
		return n
	end
	local maxStage = 0
	for _, pet in ipairs(p.pets or {}) do
		maxStage = math.max(maxStage, pet.stage or 1)
	end
	local qstep = type(p.quest) == "table" and p.quest.step or 1
	local value = {
		islands = count(p.unlocked),
		chests = count(p.chests),
		fruit = p.fruit and 1 or 0,
		mastery = p.fruit and p.fruit.mastery or 0,
		pets = #(p.pets or {}),
		petStage = maxStage,
		tutorial = qstep > Quests.TutorialEnd and 1 or 0,
		story = qstep > #Quests.Main and 1 or 0,
		level = p.baseLevel,
		beli = p.beli,
	}
	for _, a in ipairs(Achievements.List) do
		if a.state and not st.done[a.id] and (value[a.state] or 0) >= a.count then
			finishAchievement(player, a)
		end
	end
end

-- titles moved to TitleService (Config/Titles): keep the old entry point working
local function setTitleAttr(player, p)
	if R and R.TitleService then
		R.TitleService.SetAttributes(player, p)
	end
end
PG.SetAttributes = setTitleAttr

function PG.Init(registry)
	R = registry
end

function PG.Start()
	R.DataService.Loaded:Connect(function(player) -- v0.24.0: once a character slot is loaded (title menu)
		task.delay(3, function()
			local p = R.PlayerService.Profile(player)
			if p then
				daily(player, p)
				setTitleAttr(player, p)
			end
		end)
	end)

	Net.Handle("DailyClaim", function(player, data)
		local p = R.PlayerService.Profile(player)
		local d = daily(player, p)
		local e = d.list[tonumber(data.index) or 0]
		if not e then
			return false, "Unknown daily"
		end
		if e.claimed then
			return false, "Already claimed"
		end
		if e.progress < e.count then
			return false, "Not finished yet"
		end
		e.claimed = true
		local L = p.baseLevel
		local beli = math.floor(Dailies.Reward.beliPerLevel * L ^ 0.85)
		local exp = math.floor(Formulas.BaseExpToNext(L) * Dailies.Reward.expPct)
		R.PlayerService.AddBeli(player, beli)
		R.PlayerService.GiveExp(player, exp, math.floor(exp * 0.6))
		R.PearlService.Earn(player, Dailies.Reward.pearls, "daily")
		Net.Push(player, "Loot", { beli = beli })
		R.PlayerService.MarkDirty(player)
		return true, "Daily reward claimed"
	end, 0.5)

	-- hunts: pick one or abandon it (the reward pays itself, see payHunt)
	Net.Handle("HuntStart", function(player, data)
		local p = R.PlayerService.Profile(player)
		local def = huntDef(data.id)
		if not def then
			return false, "Unknown hunt"
		end
		if p.baseLevel < math.max(1, def.level - Hunts.LevelLead) then
			return false, "Requires Lv." .. math.max(1, def.level - Hunts.LevelLead)
		end
		p.hunt = { id = def.id, progress = 0 }
		R.PlayerService.MarkDirty(player)
		return true, "Hunt started: " .. def.name
	end, 0.5)
	Net.Handle("HuntAbandon", function(player)
		local p = R.PlayerService.Profile(player)
		p.hunt = nil
		R.PlayerService.MarkDirty(player)
		return true, "Hunt abandoned"
	end, 0.5)
	Net.Handle("HuntClaim", function(player)
		local p = R.PlayerService.Profile(player)
		local h = p.hunt
		local def = type(h) == "table" and huntDef(h.id)
		if not def then
			return false, "No hunt"
		end
		if (h.progress or 0) < Hunts.Count then
			return false, "Not finished yet"
		end
		payHunt(player, p, def) -- a save that was already full before v0.25.86
		return true, "Hunt reward claimed! It starts again."
	end, 0.5)

	Net.Handle("DailyBonus", function(player)
		local p = R.PlayerService.Profile(player)
		local d = daily(player, p)
		if d.bonusClaimed then
			return false, "Already claimed today"
		end
		for _, e in ipairs(d.list) do
			if not e.claimed then
				return false, "Claim all 3 dailies first"
			end
		end
		d.bonusClaimed = true
		R.PearlService.Earn(player, Dailies.Bonus.pearls, "daily bonus")
		local got = {}
		for _, it in ipairs(Dailies.Bonus.items) do
			R.InventoryService.AddItem(player, it[1], it[2])
			table.insert(got, { id = it[1], qty = it[2] })
		end
		Net.Push(player, "Loot", { items = got })
		bump(player, p, "DailyAll", 1)
		R.PlayerService.MarkDirty(player)
		return true, "All dailies done! Come back tomorrow."
	end, 1)

	Net.Handle("AchievementClaim", function(player, data)
		local p = R.PlayerService.Profile(player)
		local st = ach(p)
		local a = Achievements.ById[tostring(data.id)]
		if not a or not st.done[a.id] then
			return false, "Not unlocked yet"
		end
		if st.claimed[a.id] then
			return false, "Already claimed"
		end
		st.claimed[a.id] = true
		-- achievements are one-time, so they do not use up the daily Pearl cap
		R.PearlService.Earn(player, a.pearls, "achievement", true)
		R.PlayerService.MarkDirty(player)
		return true, "+" .. a.pearls .. " Gems"
	end, 0.5)

end

return PG
