-- QuestService: the main story chain (Config/Quests). Server-authoritative progress, rewards and NPC dialog.
-- Progress comes from three places:
--   * QS.Event(player, kind, target, amount): called by other services (kills, ship sinks, dungeon clears, chests)
--   * Net.AfterHandle: successful client requests (AllocateStat, EquipItem, CastSkill, Refine, LaunchShip, ...)
--   * QS.Check(player): state goals (Reach, JobLevel, Level, Class), re-checked whenever the profile syncs
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Islands = require(Shared.Config.Islands)
local Charts = require(Shared.Modules.Charts)
local Net = require(Shared.Modules.Net)

local QS = {}
local R

-- successful request -> quest event kind
-- (stat points from the Stats window's Apply / Auto upgrade are reported by PlayerService with the amount raised)
local ACTION_EVENTS = {
	AllocateStat = "Stat",
	EquipItem = "Equip",
	CastSkill = "Skill",
	Refine = "Refine",
	ShopBuy = "Buy",
	RecruitCrew = "Hire",
	LaunchShip = "Launch",
}
local STATE_KINDS = { Reach = true, JobLevel = true, Level = true, Class = true, Talent = true, Arrive = true }

local function questOf(p)
	if type(p.quest) ~= "table" then
		p.quest = { step = 1, progress = 0 }
	end
	local q = p.quest
	-- inserted steps: saves already past the insertion point move up one (nobody redoes a step)
	if (q.v or 1) < 2 then
		if q.step >= 12 then -- v2: Bay Serpent at 12
			q.step += 1
		end
		q.v = 2
	end
	if q.v < 3 then
		if q.step >= 10 then -- v3: Boar Hunt at 10 (after the Job Master)
			q.step += 1
		end
		q.v = 3
	end
	return q
end

-- R5 (0.1.27): the Origin prologue (quest.pro = { origin, i }) runs before main step 1; returns the chain + index
local function proChain(q)
	local pro = type(q.pro) == "table" and q.pro or nil
	local chain = pro and Quests.Prologue[pro.origin or ""]
	if chain and (pro.i or 1) <= #chain then
		return chain, pro.i or 1
	end
	if pro then
		q.pro = nil -- finished (or an Origin without a prologue)
	end
	return nil
end

local function stepOf(p)
	local q = questOf(p)
	local chain, i = proChain(q)
	if chain then
		return chain[i]
	end
	return Quests.Main[q.step]
end
QS.StepOf = stepOf

-- Arrive goals: the character stands on that island (flat distance from its middle)
local function onIsland(player, islandId)
	local isl = Islands.ById[islandId or ""]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (isl and root) then
		return false
	end
	local d = Vector2.new(root.Position.X - isl.x, root.Position.Z - (isl.z or 0)).Magnitude
	return d <= isl.radius + 30 and root.Position.Y > -5
end

local function push(player, showDialog)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	local q = questOf(p)
	local chain, i = proChain(q)
	local s = stepOf(p)
	local lines = s and Quests.DialogFor(s, p.origin)
	Net.Push(player, "Quest", {
		step = q.step,
		total = #Quests.Main,
		progress = q.progress,
		done = s == nil,
		id = s and s.id,
		dialog = showDialog and lines or nil,
		lines = lines, -- Replay talk (Origin-specific lines)
		speaker = s and Quests.SpeakerOf(s) or nil,
		tutorial = q.step <= Quests.TutorialEnd,
		pro = chain and { i = i, n = #chain } or nil,
	})
end
QS.Push = push

local function grant(player, reward)
	if not reward then
		return
	end
	if reward.beli then
		R.PlayerService.AddBeli(player, reward.beli)
	end
	if (reward.exp or 0) > 0 or (reward.job or 0) > 0 then
		R.PlayerService.GiveExp(player, reward.exp or 0, reward.job or 0)
	end
	local got = {}
	for _, it in ipairs(reward.items or {}) do
		R.InventoryService.AddItem(player, it[1], it[2])
		table.insert(got, { id = it[1], qty = it[2] })
	end
	Net.Push(player, "Loot", { beli = reward.beli, items = got })
end

-- the island's story is done: the Sea Compass points to the next port and its name shows from now on (Charts)
local function chartNext(player, step)
	local id = Charts.RevealedBy(step)
	local isl = id and Islands.ById[id]
	if not isl then
		return
	end
	if R.InventoryService.Count(player, "SeaCompass") <= 0 then
		R.InventoryService.AddItem(player, "SeaCompass", 1)
	end
	task.delay(2.5, function()
		if player.Parent then
			Net.Push(player, "Banner", { title = "🧭 New Course Charted", subtitle = "Your compass points to " .. isl.name })
		end
	end)
end

local function complete(player)
	local p = R.PlayerService.Profile(player)
	local s = stepOf(p)
	if not s then
		return
	end
	local q = questOf(p)
	if s.prologue then
		-- Origin prologue: next prologue step (no Gems: the main chain pays those)
		local keep = q.pro.keep -- (Admin "prologue" tests keep the main step's progress here)
		q.pro.i = (q.pro.i or 1) + 1
		q.progress = 0
		proChain(q)
		if not q.pro and keep then
			q.progress = keep
		end
		R.PlayerService.MarkDirty(player)
		grant(player, s.reward)
		Net.Push(player, "QuestComplete", { title = s.title, reward = s.reward })
		push(player, true)
		task.defer(QS.Check, player)
		return
	end
	q.step += 1
	q.progress = 0
	R.PlayerService.MarkDirty(player)
	grant(player, s.reward)
	local PearlsCfg = require(Shared.Config.Pearls)
	R.PearlService.Earn(player, PearlsCfg.Sources.QuestStep + (s.index == Quests.TutorialEnd and PearlsCfg.Sources.TutorialDone or 0), "quest")
	Net.Push(player, "QuestComplete", { title = s.title, reward = s.reward })
	chartNext(player, q.step)
	push(player, true)
	-- the next step may already be satisfied (e.g. you were already Job Lv.10)
	task.defer(QS.Check, player)
end

local function matches(goal, kind, target)
	if goal.kind ~= kind then
		return false
	end
	return goal.target == nil or target == nil or goal.target == target
end

function QS.Event(player, kind, target, amount)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	-- dailies and achievements listen to the same events
	if R.ProgressService then
		R.ProgressService.Event(player, kind, target, amount)
	end
	local s = stepOf(p)
	if not s or STATE_KINDS[s.goal.kind] or not matches(s.goal, kind, target) then
		return
	end
	local q = questOf(p)
	q.progress += amount or 1
	R.PlayerService.MarkDirty(player)
	if q.progress >= (s.goal.count or 1) then
		complete(player)
	else
		push(player, false)
	end
end

function QS.Check(player)
	local p = R.PlayerService.Profile(player)
	local s = p and stepOf(p)
	if s and s.goal.kind == "Stat" and p.stats then
		-- already trained enough (by hand earlier, or by Auto upgrade): done; saves that got stuck here before v0.22.3
		local raised = 0
		for _, v in pairs(p.stats) do
			raised += math.max(0, v) -- remake attributes start at 0
		end
		if raised >= (s.goal.count or 1) then
			complete(player)
		end
		return
	end
	if not s or not STATE_KINDS[s.goal.kind] then
		return
	end
	local g = s.goal
	local done = (g.kind == "Reach" and p.unlocked[g.target])
		or (g.kind == "Arrive" and onIsland(player, g.target))
		or (g.kind == "JobLevel" and (p.jobLevel >= g.count or (p.classSwitches or 0) > 0))
		or (g.kind == "Level" and p.baseLevel >= g.count)
		or (g.kind == "Class" and (p.classSwitches or 0) > 0)
		or (g.kind == "Talent" and #(p.talents or {}) >= (g.count or 1))
	if done then
		complete(player)
	else
		local q = questOf(p)
		local cur = (g.kind == "JobLevel" and p.jobLevel) or (g.kind == "Level" and p.baseLevel) or (g.kind == "Talent" and #(p.talents or {})) or 0
		if q.progress ~= cur then
			q.progress = cur
			push(player, false)
		end
	end
end

-- NPC "Talk" prompts (WorldBuilder calls this for every NPC). Returns true if a quest dialog was shown.
function QS.OnTalk(player, role, islandId)
	local p = R.PlayerService.Profile(player)
	local s = p and stepOf(p)
	if not s then
		if role == "Guide" then
			Net.Push(player, "QuestDialog", { speaker = Quests.Guide[islandId] or "Guide", lines = { "You've done everything I could ask, Captain. The Grand Current awaits beyond the Crimson Wall!" } })
			return true
		end
		return false
	end
	if s.goal.kind == "Talk" and s.goal.target == role and s.island == islandId then
		QS.Event(player, "Talk", role)
		return true
	end
	if role == "Guide" then
		-- remind the player what to do (or point them to the right island)
		local there = Islands.ById[s.island]
		local lines = s.island == islandId and Quests.DialogFor(s, p.origin) or { "Your next job is on " .. (there and there.name or s.island) .. ". Check the quest tracker on the left!" }
		Net.Push(player, "QuestDialog", { speaker = Quests.Guide[islandId] or "Guide", lines = lines })
		return true
	end
	return false
end

function QS.Init(registry)
	R = registry
end

function QS.Start()
	Net.AfterHandle(function(player, action, _payload, result)
		local kind = ACTION_EVENTS[action]
		if kind and result and result.ok then
			QS.Event(player, kind)
		end
	end)
	Net.Handle("QuestPing", function(player, data)
		-- client-only actions that cannot be cheated in a meaningful way (turning Auto Battle on)
		if data.kind == "Auto" then
			QS.Event(player, "Auto")
		end
		return true
	end, 1)
	-- v0.25.8 (owner: no quest after rejoining): the client asks with QuestState while still on the title menu, where
	-- Net's gate refuses it, so push the quest as soon as a character slot is loaded (also after MENU -> PLAY)
	R.DataService.Loaded:Connect(function(player)
		task.delay(1.5, function()
			if player.Parent and R.PlayerService.Profile(player) then
				push(player, false)
				QS.Check(player)
			end
		end)
	end)
	-- Arrive goals (Origin prologue: reach Daybreak) are checked from the character's position
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local p = R.PlayerService.Profile(player)
				local s = p and stepOf(p)
				if s and s.goal.kind == "Arrive" then
					QS.Check(player)
				end
			end
		end
	end)
	Net.Handle("QuestState", function(player)
		push(player, false)
		QS.Check(player)
		return true
	end, 1)
	Net.Handle("QuestSkipTutorial", function(player)
		local p = R.PlayerService.Profile(player)
		local q = p and questOf(p)
		if not q or q.step > Quests.TutorialEnd then
			return false, "The tutorial is already over"
		end
		q.step = Quests.TutorialEnd + 1
		q.progress = 0
		q.pro = nil -- the Origin prologue goes with it
		if R.InventoryService.Count(player, "SeaCompass") <= 0 then
			R.InventoryService.AddItem(player, "SeaCompass", 1)
		end
		R.PlayerService.MarkDirty(player)
		push(player, true)
		task.defer(QS.Check, player)
		return true, "Tutorial skipped"
	end, 2)
end

return QS
