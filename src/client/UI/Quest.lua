-- Quest UI: the quest tracker (left side, under the player card), NPC dialog box (bottom center, typewriter text),
-- the quest marker target used by Readability (compass mark + edge arrow + light beam), and chest visuals.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Islands = require(Shared.Config.Islands)
local Monsters = require(Shared.Config.Monsters)
local Rarity = require(Shared.Modules.Rarity)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.Parent.State)
local Audio = require(script.Parent.Parent.Controllers.Audio)

local Quest = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New

local tracker, tTitle, tChapter, tGoal, tCount, tBar, tHint, tDist, skipBtn, tChevron
-- collapsed by default: chapter, title, goal and progress only (the screen stays clean); tap to expand the hint
local expanded = false
local COLLAPSED_H, EXPANDED_H = 82, 118
local dialog, dName, dText, dNext, dChip
local data -- last "Quest" push

-- ===== where the marker points =====
local function npcPos(role, islandId)
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		if m:GetAttribute("Role") == role and m:GetAttribute("Island") == islandId and m.Parent then
			return m:GetPivot().Position
		end
	end
	return nil
end

local function targetOf(step)
	local at = step.at or {}
	local isl = Islands.ById[step.island]
	if at.npc then
		return npcPos(at.npc, step.island)
	elseif at.spawn and isl then
		for _, sp in ipairs(isl.spawns) do
			if sp.monster == at.spawn then
				return Vector3.new(isl.x + sp.offset.X, 8, (isl.z or 0) + sp.offset.Y)
			end
		end
	elseif at.island then
		local dest = Islands.ById[at.island]
		if dest then
			return Vector3.new(dest.x - dest.radius + 20, 8, dest.z or 0) -- the west dock you arrive at
		end
	end
	return nil
end

local function goalText(step, progress)
	local g = step.goal
	local count = g.count or 1
	if g.kind == "JobLevel" or g.kind == "Level" then
		return step.text, string.format("%d/%d", math.min(progress, count), count), math.clamp(progress / count, 0, 1)
	end
	if count > 1 then
		return step.text, string.format("%d/%d", math.min(progress, count), count), math.clamp(progress / count, 0, 1)
	end
	return step.text, "", progress >= count and 1 or 0
end

-- ===== tracker =====
local function buildTracker()
	tracker = New("TextButton", { Name = "QuestTracker", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(330, COLLAPSED_H), Position = UDim2.fromOffset(16, 190), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = UI.Root })
	UI.Corner(tracker, 14)
	UI.Gradient(tracker, T.PanelTop, T.PanelDeep, 90)
	UI.Stroke(tracker, T.Edge, 3)
	local accent = New("Frame", { BackgroundColor3 = T.Gold, Size = UDim2.new(0, 6, 1, -16), Position = UDim2.fromOffset(8, 8), Parent = tracker })
	UI.Corner(accent, 3)
	local chip = UI.IconChip(tracker, "📜", T.Gold, 30)
	chip.Position = UDim2.fromOffset(20, 8)
	tChapter = UI.Text(tracker, "MAIN QUEST", 12, T.Gold, "Display", { Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -66, 0, 14), TextWrapped = false })
	tTitle = UI.Text(tracker, "", 18, T.Text, "Display", { Position = UDim2.fromOffset(58, 20), Size = UDim2.new(1, -66, 0, 22), TextWrapped = false })
	tGoal = UI.Text(tracker, "", 15, T.Text, "Bold", { Position = UDim2.fromOffset(22, 46), Size = UDim2.new(1, -90, 0, 20), TextWrapped = false })
	tCount = UI.Text(tracker, "", 16, T.Gold, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 46), Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right })
	local barBack = New("Frame", { BackgroundColor3 = T.PanelDeep, Position = UDim2.fromOffset(22, 70), Size = UDim2.new(1, -34, 0, 8), Parent = tracker })
	UI.Corner(barBack, 4)
	tBar = New("Frame", { BackgroundColor3 = T.Green, Size = UDim2.fromScale(0, 1), Parent = barBack })
	UI.Corner(tBar, 4)
	tHint = UI.Text(tracker, "", 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(22, 82), Size = UDim2.new(1, -34, 0, 30), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Visible = false })
	tDist = UI.Text(tracker, "", 13, T.Gold, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 22), Size = UDim2.fromOffset(80, 18), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
	tChevron = UI.Text(tracker, "▾", 16, T.TextSoft, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(18, 18), TextXAlignment = Enum.TextXAlignment.Center })
	local sb
	sb, skipBtn = UI.Button(tracker, "Skip tutorial", T.Grey, UDim2.fromOffset(110, 24), function()
		UI.Confirm("Skip the Daybreak tutorial? You keep everything you have, but miss its rewards.", function()
			task.spawn(Net.Request, "QuestSkipTutorial")
		end, nil, "Skip", "Keep playing")
	end)
	sb.TextScaled = false
	sb.TextSize = 12
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -8, 1, 4)
	UI.Tactile(tracker)
	tracker.Activated:Connect(function()
		expanded = not expanded
		Quest.ApplyExpanded()
	end)
	-- expanded mode: replay the NPC's lines
	local rb, replay = UI.Button(tracker, "💬 Replay", T.Ocean, UDim2.fromOffset(96, 24), function()
		local step = data and Quests.ById[data.id or ""]
		if step then
			Quest.Dialog(Quests.Guide[step.island] or "Guide", step.dialog)
		end
	end)
	rb.TextScaled = false
	rb.TextSize = 12
	replay.AnchorPoint = Vector2.new(0, 0)
	replay.Position = UDim2.new(0, 8, 1, 4)
	Quest.replayBtn = replay
	HUD.questFrame = tracker
end

local function refreshTracker()
	local step = data and Quests.ById[data.id or ""]
	if not step then
		tracker.Visible = data ~= nil and data.done == true
		if tracker.Visible then
			tChapter.Text = "MAIN QUEST"
			tTitle.Text = "Azure East complete!"
			tGoal.Text = "The Grand Current opens in the next update"
			tCount.Text = ""
			tBar.Size = UDim2.fromScale(1, 1)
			tHint.Text = ""
			skipBtn.Visible = false
		end
		State.questTarget = nil
		return
	end
	tracker.Visible = true
	local isl = Islands.ById[step.island]
	tChapter.Text = (data.tutorial and "TUTORIAL" or "MAIN QUEST") .. "  •  " .. string.upper(isl and isl.name or step.island) .. "  •  " .. data.step .. "/" .. data.total
	tTitle.Text = step.title
	local text, count, ratio = goalText(step, data.progress or 0)
	if step.goal.kind == "Kill" and step.goal.target and Monsters[step.goal.target] then
		local lvl = Monsters[step.goal.target].level or 1
		text = text .. ' <font color="#' .. Rarity.LevelColor(player:GetAttribute("Level") or 1, lvl):ToHex() .. '">Lv.' .. lvl .. "</font>"
	end
	tGoal.Text = "☐ " .. text
	tCount.Text = count
	UI.Tween(tBar, 0.25, { Size = UDim2.fromScale(ratio, 1) })
	tHint.Text = step.hint or ""
	Quest.ApplyExpanded()
	State.questTarget = targetOf(step)
	State.questLabel = step.text
end

function Quest.ApplyExpanded()
	if not tracker then
		return
	end
	tracker.Size = UDim2.fromOffset(tracker.Size.X.Offset, expanded and EXPANDED_H or COLLAPSED_H)
	tHint.Visible = expanded
	tChevron.Text = expanded and "▴" or "▾"
	skipBtn.Visible = expanded and data ~= nil and data.tutorial == true
	if Quest.replayBtn then
		Quest.replayBtn.Visible = expanded
	end
end

-- ===== dialog =====
local lines, lineIdx = {}, 0
local typing
local function showLine()
	local text = lines[lineIdx]
	if not text then
		UI.Tween(dialog, 0.15, { Position = UDim2.new(0.5, 0, 1, 40) })
		task.delay(0.16, function()
			dialog.Visible = false
		end)
		return
	end
	dText.Text = text
	dText.MaxVisibleGraphemes = 0
	dNext.Text = lineIdx < #lines and "Next ▶" or "Got it!"
	local myTyping = {}
	typing = myTyping
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n, 2 do
			if typing ~= myTyping then
				return
			end
			dText.MaxVisibleGraphemes = i
			task.wait(0.012)
		end
		dText.MaxVisibleGraphemes = -1
	end)
end

local function buildDialog()
	dialog = New("Frame", { Name = "QuestDialog", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -124), Size = UDim2.fromOffset(640, 128), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 14, Parent = UI.Root })
	UI.Corner(dialog, 16)
	UI.Gradient(dialog, T.PanelTop, T.PanelDeep, 90)
	UI.Stroke(dialog, T.Edge, 4)
	dChip = UI.IconChip(dialog, "🧔", T.Gold, 64)
	dChip.Position = UDim2.fromOffset(14, 32)
	dChip.Rotation = -5
	local tag = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(20, -16), Size = UDim2.fromOffset(240, 32), ZIndex = 31, Parent = dialog })
	UI.Corner(tag, 8)
	UI.Gradient(tag, T.Gold:Lerp(Color3.new(1, 1, 1), 0.3), T.Orange, 90)
	UI.Stroke(tag, T.Edge, 3)
	dName = UI.Text(tag, "", 19, Color3.new(1, 1, 1), "Display", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 32, TextWrapped = false })
	dText = UI.Text(dialog, "", 17, T.Text, "Semi", { Position = UDim2.fromOffset(92, 22), Size = UDim2.new(1, -110, 0, 64), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31 })
	local btn, holder = UI.Button(dialog, "Next ▶", T.Green, UDim2.fromOffset(120, 36), function()
		local n = utf8.len(dText.Text) or 0
		if dText.MaxVisibleGraphemes ~= -1 and dText.MaxVisibleGraphemes < n then
			typing = nil
			dText.MaxVisibleGraphemes = -1 -- first click finishes the line
			return
		end
		lineIdx += 1
		showLine()
	end)
	dNext = btn
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -14, 1, -12)
	holder.ZIndex = 32
end

function Quest.Dialog(speaker, newLines)
	if not newLines or #newLines == 0 then
		return
	end
	lines, lineIdx = newLines, 1
	dName.Text = speaker or "Guide"
	dialog.Visible = true
	dialog.Position = UDim2.new(0.5, 0, 1, 40)
	UI.Tween(dialog, 0.3, { Position = UDim2.new(0.5, 0, 1, -124) }, Enum.EasingStyle.Back)
	Audio.Play("UIOpen")
	showLine()
end

-- ===== chests: show opened ones as open and dimmed, only for this player =====
local function paintChests()
	local opened = State.profile and State.profile.chests or {}
	for _, m in ipairs(CollectionService:GetTagged("Chest")) do
		local id = m:GetAttribute("ChestId")
		if opened[id] and not m:GetAttribute("ShownOpen") then
			m:SetAttribute("ShownOpen", true)
			local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				prompt.Enabled = false
			end
			local lid = m:FindFirstChild("Lid")
			if lid then
				lid.CFrame = lid.CFrame * CFrame.new(0, 0.6, 1.1) * CFrame.Angles(math.rad(-70), 0, 0)
				local light = lid:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = false
				end
			end
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
					p.Transparency = 1
				end
			end
		end
	end
end

function Quest.ChestCount(islandId)
	local opened = State.profile and State.profile.chests or {}
	local found, total = 0, 0
	for _, m in ipairs(CollectionService:GetTagged("Chest")) do
		if m:GetAttribute("Island") == islandId then
			total += 1
			if opened[m:GetAttribute("ChestId")] then
				found += 1
			end
		end
	end
	return found, total
end

-- ===== push handlers (wired in init.client.lua) =====
function Quest.OnQuest(d)
	data = d
	State.quest = d
	refreshTracker()
	if d.dialog then
		local step = Quests.ById[d.id or ""]
		Quest.Dialog(d.speaker or (step and Quests.Guide[step.island]) or "Guide", d.dialog)
	end
end

function Quest.OnComplete(d)
	UI.Notice("QUEST COMPLETE  •  " .. string.upper(d.title or ""), T.Green)
	Audio.Play("RarityRare")
	UI.Bounce(tracker)
end

function Quest.OnDialog(d)
	Quest.Dialog(d.speaker, d.lines)
end

function Quest.OnChest(d)
	local tier = Rarity.Get(d.rarity)
	UI.Notice("🧰 " .. string.upper(d.name) .. " FOUND  •  " .. d.found .. "/" .. d.total .. " on this island", tier.color)
	Audio.Play("Rarity" .. tier.id)
	-- open the lid right away (the profile sync follows)
	State.profile = State.profile or {}
	State.profile.chests = State.profile.chests or {}
	State.profile.chests[d.id] = true
	paintChests()
end

function Quest.Start()
	buildTracker()
	buildDialog()
	if HUD.Layout then
		HUD.Layout()
	end
	State.Changed:Connect(function(kind)
		if kind == "profile" then
			paintChests()
			refreshTracker()
		end
	end)
	-- distance readout
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and State.questTarget and tracker.Visible then
			local d = (Vector2.new(State.questTarget.X, State.questTarget.Z) - Vector2.new(root.Position.X, root.Position.Z)).Magnitude
			tDist.Text = d < 25 and "here!" or (UI.Format(math.floor(d)) .. " m ➜")
		else
			tDist.Text = ""
		end
	end)
	task.spawn(Net.Request, "QuestState")
end

return Quest
