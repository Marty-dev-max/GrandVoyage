-- Interact (client): our own look for every "press E" ProximityPrompt and for NPC nameplates.
--  * Prompts: Roblox's default grey prompt is replaced (Style = Custom) by a slanted game-styled card that slides in:
--    a key cap (E, or a tap icon on touch screens) + the action ("Talk") in the display font + what it is ("Old Salt Rowan").
--    Touch / click on the card triggers it too. Keyboard E keeps working through ProximityPromptService.
--  * NPC nameplates (BillboardGui "Nameplate" made on the server): restyled here into a big outlined title with a role
--    chip and a dark ribbon subtitle, so the baked map does not need a rebuild.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UI = require(script.Parent.Parent.UI.UIKit)

local Interact = {}
local T = UI.Theme
local New = UI.New
local player = Players.LocalPlayer
local FONT = Font.fromEnum(Enum.Font.Arcade)

local function tween(o, t, props, style)
	TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out), props):Play()
end

-- ===== prompts =====
local shown = {} -- prompt -> billboard

local function buildPrompt(prompt, inputType)
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local bb = New("BillboardGui", { Name = "GVPrompt", AlwaysOnTop = true, Active = true, LightInfluence = 0, Size = UDim2.fromOffset(300, 74), SizeOffset = Vector2.new(0.5, 0), StudsOffset = Vector3.new(1.2, 0.5, 0), ResetOnSpawn = false, Adornee = prompt.Parent, Parent = gui })
	local card = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(-40, 0), Size = UDim2.fromOffset(280, 64), Parent = bb })
	UI.Corner(card, 14)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = card })
	UI.Stroke(card, T.Edge, 3)
	-- accent stripe on the left edge (the slanted tab of our windows)
	local stripe = New("Frame", { BackgroundColor3 = T.Gold, Size = UDim2.new(0, 8, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = card })
	UI.Corner(stripe, 4)
	-- key cap
	local key = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(22, 9), Size = UDim2.fromOffset(46, 46), Parent = card })
	UI.Corner(key, 10)
	New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 236, 150), T.Gold), Rotation = 90, Parent = key })
	UI.Stroke(key, T.Edge, 3)
	local keyText = inputType == Enum.ProximityPromptInputType.Touch and "👆" or (inputType == Enum.ProximityPromptInputType.Gamepad and "X" or prompt.KeyboardKeyCode.Name)
	New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = keyText, FontFace = FONT, TextSize = 26, TextColor3 = T.Edge, Parent = key })
	-- hold progress (only for prompts with a hold time)
	local fill
	if prompt.HoldDuration > 0 then
		fill = New("Frame", { BackgroundColor3 = T.Green, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0, 0, 0, 5), Parent = card })
		UI.Corner(fill, 3)
	end
	local action = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 6), Size = UDim2.new(1, -88, 0, 30), Text = string.upper(prompt.ActionText), FontFace = FONT, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	New("UIStroke", { Color = T.Edge, Thickness = 2.5, Parent = action })
	New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 34), Size = UDim2.new(1, -88, 0, 22), Text = prompt.ObjectText, FontFace = FONT, TextSize = 17, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	-- slide in
	local sc = New("UIScale", { Scale = 0.6, Parent = card })
	card.BackgroundTransparency = 0
	tween(card, 0.25, { Position = UDim2.fromOffset(0, 0) })
	tween(sc, 0.25, { Scale = 1 })
	-- tap / click the card to use it (touch screens have no E key)
	card.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()
		tween(sc, 0.08, { Scale = 0.94 }, Enum.EasingStyle.Quad)
	end)
	card.MouseButton1Up:Connect(function()
		prompt:InputHoldEnd()
		tween(sc, 0.15, { Scale = 1 })
	end)
	local conns = {}
	if fill then
		table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
			fill.Size = UDim2.new(0, 0, 0, 5)
			TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 0, 5) }):Play()
		end))
		table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
			fill.Size = UDim2.new(0, 0, 0, 5)
		end))
	end
	table.insert(conns, prompt.Triggered:Connect(function()
		-- a little "pressed" pop
		key.Size = UDim2.fromOffset(40, 40)
		key.Position = UDim2.fromOffset(25, 12)
		tween(key, 0.2, { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(22, 9) })
	end))
	shown[prompt] = { bb = bb, conns = conns }
end

local function hidePrompt(prompt)
	local s = shown[prompt]
	if not s then
		return
	end
	shown[prompt] = nil
	for _, c in ipairs(s.conns) do
		c:Disconnect()
	end
	s.bb:Destroy()
end

local function claim(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- ===== NPC nameplates =====
local styled = setmetatable({}, { __mode = "k" })
local ROLE_ICON = { Blacksmith = "🔨", Shop = "🛒", Tavern = "🍺", FastTravel = "🗺️", Shipwright = "⚓", BossBoard = "👑", JobMaster = "🎓", Guild = "🏴", Dungeon = "🏰", Stall = "🏪", Quest = "📜" }
local function styleNameplate(model)
	local bb = model:FindFirstChild("Nameplate", true)
	if not bb or not bb:IsA("BillboardGui") or styled[bb] then
		return
	end
	styled[bb] = true
	local titleL, subL = bb:FindFirstChild("Title"), bb:FindFirstChild("Subtitle")
	local title = titleL and titleL.Text or model.Name
	local sub = subL and subL.Text or nil
	local color = titleL and titleL.TextColor3 or T.Gold
	for _, c in ipairs(bb:GetChildren()) do
		if c:IsA("GuiObject") then
			c.Visible = false
		end
	end
	bb.Size = UDim2.fromOffset(320, 92)
	bb.LightInfluence = 0
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bb })
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = holder })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = row })
	local icon = ROLE_ICON[model:GetAttribute("Role") or ""] or "💬"
	local chip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(40, 40), Parent = row })
	UI.Corner(chip, 10)
	New("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.3)), Rotation = 90, Parent = chip })
	UI.Stroke(chip, T.Edge, 3)
	New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = icon, TextScaled = true, FontFace = FONT, Parent = chip })
	local t = New("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 44), Text = title, FontFace = FONT, TextSize = 22, TextColor3 = color, Parent = row })
	New("UIStroke", { Color = T.Edge, Thickness = 3, Parent = t })
	if sub and sub ~= "" then
		local ribbon = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.15, Parent = holder })
		UI.Corner(ribbon, 8)
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = ribbon })
		local s = New("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), Text = "◆ " .. sub, FontFace = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(255, 240, 200), Parent = ribbon })
		local _ = s
	end
end

function Interact.Start()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			claim(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			claim(d)
		end
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			buildPrompt(prompt, inputType)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(hidePrompt)
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		styleNameplate(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(m)
		task.defer(styleNameplate, m)
	end)
	local _ = UserInputService
end

return Interact
