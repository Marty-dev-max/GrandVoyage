-- Quest UI: the quest tracker (left side, under the player card), NPC dialog box (bottom center, typewriter text),
-- the quest marker target used by Readability (compass mark + edge arrow + light beam), and chest visuals.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
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
local dialog, dName, dText, dNext, dChip, dTag
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
	elseif at.boss then
		local bi = Islands.ById[at.boss]
		if bi and bi.boss then
			return Vector3.new(bi.x + bi.boss.offset.X, 8, (bi.z or 0) + bi.boss.offset.Y)
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
local talkPitch = 1
local endTalk -- function: puts the camera back, removes the portrait (set by Quest.Dialog)
local function showLine()
	local text = lines[lineIdx]
	if not text then
		if endTalk then
			endTalk()
			endTalk = nil
		end
		UI.Tween(dialog, 0.15, { Position = UDim2.new(0.5, 0, 1, 40) })
		task.delay(0.16, function()
			dialog.Visible = false
		end)
		return
	end
	dText.Text = text
	dText.MaxVisibleGraphemes = 0
	local verb = UI.IsMobile and "Tap" or "Click"
	dNext.Text = lineIdx < #lines and ("▶ " .. verb .. " to continue") or ("✔ " .. verb .. " to close")
	local myTyping = {}
	typing = myTyping
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n, 2 do
			if typing ~= myTyping then
				return
			end
			dText.MaxVisibleGraphemes = i
			-- v0.25.2 (owner): pixel-game "voice": a soft blip every few letters, pitched per speaker
			if i % 6 == 1 then
				Audio.Play("Talk", { pitch = talkPitch * (0.94 + math.random() * 0.12), volume = 0.5 })
			end
			task.wait(0.012)
		end
		dText.MaxVisibleGraphemes = -1
	end)
end

local function buildDialog()
	-- the whole box is the "continue" button (big target, easy on phones); the rest of the screen stays playable
	dialog = New("TextButton", { Name = "QuestDialog", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -124), Size = UDim2.fromOffset(640, 128), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 14, Parent = UI.Root })
	UI.Corner(dialog, 16)
	UI.Gradient(dialog, T.PanelTop, T.PanelDeep, 90)
	UI.Stroke(dialog, T.Edge, 4)
	dChip = UI.IconChip(dialog, "🧔", T.Gold, 64)
	dChip.Position = UDim2.fromOffset(14, 32)
	dChip.Rotation = -5
	local tag = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(20, -16), Size = UDim2.fromOffset(240, 32), ZIndex = 31, Parent = dialog })
	dTag = tag
	UI.Corner(tag, 8)
	UI.Gradient(tag, T.Gold:Lerp(Color3.new(1, 1, 1), 0.3), T.Orange, 90)
	UI.Stroke(tag, T.Edge, 3)
	dName = UI.Text(tag, "", 19, Color3.new(1, 1, 1), "Display", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 32, TextWrapped = false })
	dText = UI.Text(dialog, "", 17, T.Text, "Semi", { Position = UDim2.fromOffset(92, 22), Size = UDim2.new(1, -110, 0, 64), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31 })
	-- blinking hint instead of a button
	dNext = UI.Text(dialog, "", 15, T.Gold, "Display", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10), Size = UDim2.fromOffset(240, 20), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 32 })
	local function advance()
		if not dialog.Visible then
			return
		end
		local n = utf8.len(dText.Text) or 0
		if dText.MaxVisibleGraphemes ~= -1 and dText.MaxVisibleGraphemes < n then
			typing = nil
			dText.MaxVisibleGraphemes = -1 -- first click finishes the line
			return
		end
		Audio.Play("UIClick")
		lineIdx += 1
		showLine()
	end
	dialog.Activated:Connect(advance)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			advance()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if dialog.Visible then
			dNext.TextTransparency = 0.15 + (math.sin(os.clock() * 5) + 1) * 0.3
		end
	end)
end

-- ===== talking to an NPC (v0.25.2, owner) =====
-- Near the NPC (within TALK_NEAR studs): the camera eases onto them (over the shoulder, a little to the side) and
-- eases back when the talk ends or you walk away. Far away (quest guide calling): their portrait in the dialog box
-- is a flickering cyan HOLOGRAM of the NPC model. Either way the portrait shows the real NPC, not an emoji.
local TALK_NEAR = 34
local function findNpc(name)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestD
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		if m.Name == name and m.Parent and m:IsA("Model") then
			local d = root and (m:GetPivot().Position - root.Position).Magnitude or 0
			if not best or d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best, bestD
end

local function portrait(npc, holo)
	-- v0.25.6 (owner's reference): a big half-body "bust" shot that stands out of the box's left edge, no frame
	local vp = New("ViewportFrame", { Name = "NpcPortrait", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -18, 1, 0), Size = UDim2.fromOffset(200, 230), ZIndex = 33, Ambient = holo and Color3.fromRGB(90, 220, 255) or Color3.fromRGB(200, 200, 210),
		LightColor = holo and Color3.fromRGB(120, 240, 255) or Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1), Parent = dialog })
	local m = npc:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif holo and d:IsA("BasePart") then
			d.Color = d.Color:Lerp(Color3.fromRGB(80, 220, 255), 0.6)
		end
	end
	m:PivotTo(CFrame.new())
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local midY = cf.Position.Y + size.Y * 0.16 -- head + torso (half body)
	local look = m:GetPivot().LookVector
	local side = m:GetPivot().RightVector
	cam.CFrame = CFrame.lookAt(Vector3.new(0, midY, 0) + look * 11 + side * 2.2 + Vector3.new(0, 0.6, 0), Vector3.new(0, midY, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- idle: a slow breathing bob so the portrait feels alive
	task.spawn(function()
		local base = m:GetPivot()
		while vp.Parent do
			m:PivotTo(base * CFrame.new(0, math.sin(os.clock() * 2) * 0.06, 0))
			task.wait(0.03)
		end
	end)
	if holo then
		-- scanlines + flicker
		for y = 0, 1, 0.1 do
			New("Frame", { BackgroundColor3 = Color3.fromRGB(120, 240, 255), BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 1), ZIndex = 32, Parent = vp })
		end
		task.spawn(function()
			while vp.Parent do
				vp.ImageTransparency = math.random() < 0.08 and 0.5 or 0.12
				task.wait(0.07)
			end
		end)
	end
	return vp
end

local function focusCamera(npc)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not cam or not root then
		return nil
	end
	local cf, size = npc:GetBoundingBox()
	local head = cf.Position + Vector3.new(0, size.Y * 0.32, 0)
	local toPlayer = Vector3.new(root.Position.X - head.X, 0, root.Position.Z - head.Z)
	toPlayer = toPlayer.Magnitude > 0.1 and toPlayer.Unit or npc:GetPivot().LookVector
	local side = Vector3.new(-toPlayer.Z, 0, toPlayer.X)
	local goal = CFrame.lookAt(head + toPlayer * 9 + side * 3 + Vector3.new(0, 1.2, 0), head - Vector3.new(0, 0.3, 0))
	local before = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = goal, FieldOfView = 55 }):Play()
	local startPos = root.Position
	local alive = true
	local function restore()
		if not alive then
			return
		end
		alive = false
		cam.CameraType = before == Enum.CameraType.Scriptable and Enum.CameraType.Custom or before
		TweenService:Create(cam, TweenInfo.new(0.4), { FieldOfView = 70 }):Play()
	end
	-- walking away ends the close-up (the dialog stays)
	task.spawn(function()
		while alive do
			task.wait(0.2)
			if not root.Parent or (root.Position - startPos).Magnitude > 8 then
				restore()
			end
		end
	end)
	return restore
end

function Quest.Dialog(speaker, newLines)
	if not newLines or #newLines == 0 then
		return
	end
	lines, lineIdx = newLines, 1
	dName.Text = speaker or "Guide"
	if endTalk then
		endTalk()
		endTalk = nil
	end
	local h = 0
	for i = 1, #(speaker or "") do
		h = (h * 31 + string.byte(speaker, i)) % 997
	end
	talkPitch = 0.8 + (h % 50) / 100
	local old = dialog:FindFirstChild("NpcPortrait")
	if old then
		old:Destroy()
	end
	local npc, dist = findNpc(speaker or "")
	if npc then
		local near = dist <= TALK_NEAR
		local ok, vp = pcall(portrait, npc, not near)
		dChip.Visible = not ok
		-- the bust takes the left of the box: text and name tag move right of it
		if ok then
			dText.Position = UDim2.fromOffset(190, 22)
			dText.Size = UDim2.new(1, -206, 0, 64)
			dTag.Position = UDim2.fromOffset(180, -16)
		end
		local restore = near and focusCamera(npc) or nil
		endTalk = function()
			if restore then
				restore()
			end
			if ok and vp then
				vp:Destroy()
			end
			dChip.Visible = true
			dText.Position = UDim2.fromOffset(92, 22)
			dText.Size = UDim2.new(1, -110, 0, 64)
			dTag.Position = UDim2.fromOffset(20, -16)
		end
	else
		dChip.Visible = true
	end
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
	State.Fire("quest")
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
