-- Interact (client): our own look for every "press E" ProximityPrompt and for NPC nameplates.
--  * Prompts: Roblox's default grey prompt is replaced (Style = Custom) by a slanted game-styled card that slides in:
--    a key cap (E, or a tap icon on touch screens) + the action ("Talk") in the display font + what it is ("Rowan").
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
local BIG = 0.9 -- v0.25.50 (owner: too big up close; was 1.35)

local function buildPrompt(prompt, inputType)
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	-- v0.25.129: faction-only prompts (Arrest = Marines) are switched off locally for everyone else
	local only = prompt:GetAttribute("OnlyFaction")
	if only and player:GetAttribute("Faction") ~= only then
		prompt.Enabled = false
		return
	end
	-- v0.25.33 (owner): your own Revive prompt while downed = WILL POWER, one try per knockdown (KnockdownService)
	local char = player.Character
	local mine = prompt.Name == "RevivePrompt" and char ~= nil and prompt:IsDescendantOf(char)
	if mine then
		if char:GetAttribute("WillTried") ~= nil and char:GetAttribute("WillTried") == char:GetAttribute("Downed") then
			prompt.Enabled = false -- local only: the try is spent
			return
		end
		local conn
		conn = char:GetAttributeChangedSignal("WillTried"):Connect(function()
			conn:Disconnect()
			prompt.Enabled = false
		end)
	end
	local actionText = mine and "Get up" or prompt.ActionText
	local objectText = mine and string.format("Will power %d%% (one try)", math.floor((prompt:GetAttribute("Will") or 0.1) * 100 + 0.5)) or prompt.ObjectText
	-- v0.25.43 (owner): your own stall's counter opens the stall editor
	if prompt:FindFirstAncestor("Stall_" .. player.UserId) then
		actionText, objectText = "Manage", "Your stall"
	end
	-- v0.25.23 (owner: too small, off to the side): centered over the head, where the NPC's nameplate sits (hidden
	-- while the card shows); BIG scales the card
	local plate = prompt.Parent:FindFirstChild("Nameplate")
	plate = plate and plate:IsA("BillboardGui") and plate or nil
	local bb = New("BillboardGui", { Name = "GVPrompt", AlwaysOnTop = true, Active = true, LightInfluence = 0, Size = UDim2.fromOffset(280 * BIG + 10, 64 * BIG + 10), StudsOffsetWorldSpace = plate and plate.StudsOffsetWorldSpace or Vector3.new(0, 3, 0), ResetOnSpawn = false, Adornee = prompt.Parent, Parent = gui })
	if plate then
		plate.Enabled = false
	end
	local card = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(280, 64), Parent = bb })
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
	local action = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 6), Size = UDim2.new(1, -88, 0, 30), Text = string.upper(actionText), FontFace = FONT, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	New("UIStroke", { Color = T.Edge, Thickness = 2.5, Parent = action })
	New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 34), Size = UDim2.new(1, -88, 0, 22), Text = objectText, FontFace = FONT, TextSize = 17, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	-- slide in
	local sc = New("UIScale", { Scale = 0.6, Parent = card })
	card.BackgroundTransparency = 0
	tween(card, 0.25, { Position = UDim2.fromScale(0.5, 0.5) })
	tween(sc, 0.25, { Scale = BIG })
	-- tap / click the card to use it (touch screens have no E key)
	card.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()
		tween(sc, 0.08, { Scale = 0.94 * BIG }, Enum.EasingStyle.Quad)
	end)
	card.MouseButton1Up:Connect(function()
		prompt:InputHoldEnd()
		tween(sc, 0.15, { Scale = BIG })
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
	-- v0.25.43 (owner): no card while the camera is zoomed far out (you are near, but looking from the sky)
	local CAM_FAR = 45
	table.insert(conns, game:GetService("RunService").RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local a = prompt.Parent
		local pos = a and (a:IsA("BasePart") and a.Position or (a:IsA("Attachment") and a.WorldPosition))
		if cam and pos then
			bb.Enabled = (cam.CFrame.Position - pos).Magnitude < CAM_FAR
		end
	end))
	shown[prompt] = { bb = bb, conns = conns, plate = plate }
end

-- a prompt card is on screen (Combat lets E go to it instead of casting skill 1)
function Interact.AnyShown()
	return next(shown) ~= nil
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
	if s.plate then
		s.plate.Enabled = true
	end
end

local function claim(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- ===== NPC nameplates =====
local styled = setmetatable({}, { __mode = "k" })
-- pixel icon names (v0.25.8: no emoji)
local NEAR = 22 -- studs: closer than this an NPC plate shows its name and role
local ROLE_ICON = { Blacksmith = "hammer", Shop = "bag", Tavern = "juice", FastTravel = "map", Shipwright = "anchor", BossBoard = "crown", JobMaster = "book", Guild = "flag", Marine = "anchor", Dungeon = "skull", Stall = "chest", Quest = "scroll" }
-- v0.25.8 (owner): nameplates are big up close and shrink with distance, gone when far (the plaza was a wall of names)
local plates = setmetatable({}, { __mode = "k" }) -- billboard -> { sc = UIScale, text, ribbon }
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
	-- v0.25.112 (owner: every NPC looked the same yellow): shop NPCs wear their ring color and show their name from afar
	local zone = model:GetAttribute("ZoneColor")
	if typeof(zone) == "Color3" then
		color = zone
	end
	for _, c in ipairs(bb:GetChildren()) do
		if c:IsA("GuiObject") then
			c.Visible = false
		end
	end
	bb.Size = UDim2.fromOffset(320, 92)
	bb.LightInfluence = 0
	-- v0.25.27 (owner: the icon drifted off the head): anchored bottom-center, so the distance UIScale shrinks the plate
	-- toward the NPC's head instead of toward the billboard's top-left corner
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 1), Parent = bb })
	bb.MaxDistance = 160
	local entry = { sc = New("UIScale", { Parent = holder }), zone = typeof(zone) == "Color3" }
	plates[bb] = entry
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = holder })
	entry.row = row
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = row })
	local icon = ROLE_ICON[model:GetAttribute("Role") or ""] or "scroll"
	local chip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(46, 46), Parent = row })
	UI.Corner(chip, 10)
	New("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.3)), Rotation = 90, Parent = chip })
	UI.Stroke(chip, T.Edge, 3)
	UI.Icon(chip, icon, 46, { Size = UDim2.fromScale(1, 1) })
	local t = New("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 44), Text = title, FontFace = FONT, TextSize = 22, TextColor3 = color, Parent = row })
	New("UIStroke", { Color = T.Edge, Thickness = 3, Parent = t })
	entry.text = t
	if sub and sub ~= "" then
		local ribbon = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.15, Parent = holder })
		UI.Corner(ribbon, 8)
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = ribbon })
		local s = New("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), Text = "◆ " .. sub, FontFace = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(255, 240, 200), Parent = ribbon })
		local _ = s
		entry.ribbon = ribbon
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
	task.spawn(function()
		while true do
			local cam = workspace.CurrentCamera
			if cam then
				-- v0.25.21 (owner: too much text on screen): from afar an NPC is just its icon; walk up (within
				-- NEAR studs of your character) and the name + role appear
				local char = game:GetService("Players").LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				for bb, e in pairs(plates) do
					local a = bb.Adornee or bb.Parent
					if a and a:IsA("BasePart") then
						local dist = (a.Position - cam.CFrame.Position).Magnitude
						local near = root ~= nil and (a.Position - root.Position).Magnitude < NEAR
						local named = near or e.zone -- shop NPCs keep their name up from afar
						-- far = icon only: never below ~30 px, and it drops to the bottom row = right over the head
						e.sc.Scale = math.clamp(28 / math.max(dist, 1), near and 0.3 or 0.65, 1.1)
						e.row.Position = near and UDim2.new() or UDim2.new(0, 0, 1, -48)
						if e.text then
							e.text.Visible = named
						end
						if e.ribbon then
							e.ribbon.Visible = near
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)
	local _ = UserInputService
end

return Interact
