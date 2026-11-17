-- UIKit: anime-RPG style UI toolkit (dark glass panels, chunky outlined display font, rarity gradients,
-- bouncy hover/press motion with sounds). Every panel in the game is built from these helpers.
-- Fonts: Fredoka One for display text, Builder Sans Heavy for body text.
-- If you design the UI in Figma, map your tokens onto UI.Theme and UI.Fonts here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Modules.Rarity)
local Audio = require(script.Parent.Parent.Controllers.Audio)

local UI = {}
UI.Rarity = Rarity

UI.Theme = {
	Panel = Color3.fromRGB(24, 22, 36),
	PanelTop = Color3.fromRGB(42, 36, 66),
	PanelDeep = Color3.fromRGB(12, 11, 19),
	Edge = Color3.fromRGB(6, 5, 12),
	Accent = Color3.fromRGB(156, 84, 255),
	AccentHot = Color3.fromRGB(230, 90, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextSoft = Color3.fromRGB(184, 180, 214),
	Ocean = Color3.fromRGB(56, 168, 255),
	OceanDark = Color3.fromRGB(36, 104, 196),
	Orange = Color3.fromRGB(255, 142, 50),
	Gold = Color3.fromRGB(255, 202, 46),
	Red = Color3.fromRGB(255, 60, 84),
	Green = Color3.fromRGB(64, 222, 110),
	Blue = Color3.fromRGB(80, 140, 255),
	Purple = Color3.fromRGB(156, 84, 255),
	Pink = Color3.fromRGB(255, 92, 170),
	Grey = Color3.fromRGB(96, 96, 124),
	Marine = Color3.fromRGB(70, 140, 255),
	Pirate = Color3.fromRGB(240, 64, 74),
	Shadow = Color3.fromRGB(0, 0, 0),
}
local T = UI.Theme

UI.Fonts = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
	Semi = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Number = Font.new("rbxasset://fonts/families/FredokaOne.json"),
}
local F = UI.Fonts

UI.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GrandVoyageUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
UI.Root = gui

local rootScale = Instance.new("UIScale")
rootScale.Parent = gui
UI.UserScale = 1
local function rescale()
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 720
	rootScale.Scale = math.clamp(h / 860, 0.55, 1.25) * UI.UserScale
end
UI.Rescale = rescale
function UI.GetScale()
	return rootScale.Scale
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

function UI.New(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local New = UI.New

function UI.Tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local Tween = UI.Tween

function UI.Corner(parent, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

function UI.Stroke(parent, color, thick, mode)
	return New("UIStroke", { Color = color or T.Edge, Thickness = thick or 2.5, ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = parent })
end

function UI.Pad(parent, px)
	px = px or 10
	return New("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), Parent = parent })
end

-- idempotent: re-renders reuse the existing layout
function UI.List(parent, dir, padding, align)
	local l = parent:FindFirstChildOfClass("UIListLayout") or New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent })
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or 8)
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	return l
end

function UI.Gradient(parent, a, b, rot)
	return New("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = parent })
end

-- Outlined text. kind: "Display" | "Bold" | "Semi" | "Number"
function UI.Text(parent, text, size, color, kind, props)
	size = size or 18
	if UI.IsMobile and size < 13 then
		size = 13 -- the whole UI is scaled down on phones; anything smaller becomes unreadable
	end
	local t = New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		TextSize = size,
		TextColor3 = color or T.Text,
		FontFace = F[kind or "Bold"] or F.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.new(1, 0, 0, size + 6),
		Parent = parent,
	})
	UI.Stroke(t, T.Edge, math.max(1.2, size / 9), Enum.ApplyStrokeMode.Contextual)
	if props then
		for k, v in pairs(props) do
			t[k] = v
		end
	end
	return t
end

-- ===== animated gradients (rarity shine / rainbow) =====
local shines = {}
local rainbows = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for g in pairs(shines) do
		if g.Parent then
			g.Offset = Vector2.new(((t * 0.6 + (g:GetAttribute("Phase") or 0)) % 2) - 1, 0)
		else
			shines[g] = nil
		end
	end
	for g in pairs(rainbows) do
		if g.Parent then
			g.Rotation = (t * 60) % 360
		else
			rainbows[g] = nil
		end
	end
end)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 180, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)),
})
UI.RainbowSequence = RAINBOW

function UI.Shine(frame, phase)
	local overlay = New("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = (frame.ZIndex or 1) + 2, Parent = frame })
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = overlay
	end
	local g = New("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }),
		Parent = overlay,
	})
	g:SetAttribute("Phase", phase or math.random())
	shines[g] = true
	return overlay
end

-- Background + border styled by rarity tier
function UI.RarityStyle(frame, rarityId, strong)
	local tier = Rarity.Get(rarityId)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = frame:FindFirstChild("RarityGradient") or New("UIGradient", { Name = "RarityGradient", Rotation = 90, Parent = frame })
	g.Color = ColorSequence.new(tier.top, tier.bottom)
	local s = frame:FindFirstChild("RarityStroke") or UI.Stroke(frame, tier.color, strong and 3.5 or 2.5)
	s.Name = "RarityStroke"
	s.Color = tier.rainbow and Color3.new(1, 1, 1) or tier.color:Lerp(Color3.new(0, 0, 0), 0.25)
	if tier.rainbow then
		local sg = s:FindFirstChild("Rainbow") or New("UIGradient", { Name = "Rainbow", Color = RAINBOW, Parent = s })
		rainbows[sg] = true
	end
	if tier.rank >= 5 and not frame:FindFirstChild("Shine") then
		UI.Shine(frame)
	end
	return tier
end

-- ===== motion helpers =====
local function scaleOf(obj)
	return obj:FindFirstChild("MotionScale") or New("UIScale", { Name = "MotionScale", Parent = obj })
end
function UI.Pop(obj, from)
	local s = scaleOf(obj)
	s.Scale = from or 0.6
	Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
function UI.Bounce(obj)
	local s = scaleOf(obj)
	Tween(s, 0.08, { Scale = 1.15 }).Completed:Connect(function()
		Tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

-- Make any GuiButton feel tactile. Hover = a little "jump" (hop up, then hover slightly raised) + sound,
-- press = squash down, release = spring back + click. Objects placed by a UIListLayout/UIGridLayout cannot move,
-- so they hop with scale instead.
local function layoutControlled(obj)
	local p = obj.Parent
	return p ~= nil and (p:FindFirstChildOfClass("UIListLayout") ~= nil or p:FindFirstChildOfClass("UIGridLayout") ~= nil)
end
function UI.Tactile(btn, noSound)
	local s = scaleOf(btn)
	local base = btn.Position
	local lifted = false
	local hovering = false
	local function move(y, t, style)
		if not layoutControlled(btn) then
			return Tween(btn, t, { Position = base + UDim2.fromOffset(0, y) }, style)
		end
		return nil
	end
	btn.MouseEnter:Connect(function()
		hovering = true
		if not lifted then
			base = btn.Position
			lifted = true
		end
		local hop = move(-10, 0.09, Enum.EasingStyle.Quad)
		if hop then
			hop.Completed:Connect(function(state)
				if hovering and state == Enum.PlaybackState.Completed then
					move(-4, 0.35, Enum.EasingStyle.Bounce)
				end
			end)
			Tween(s, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		else
			Tween(s, 0.09, { Scale = 1.14 }, Enum.EasingStyle.Quad).Completed:Connect(function(state)
				if hovering and state == Enum.PlaybackState.Completed then
					Tween(s, 0.3, { Scale = 1.06 }, Enum.EasingStyle.Bounce)
				end
			end)
		end
		if not noSound then
			Audio.Play("UIHover")
		end
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		local back = move(0, 0.18, Enum.EasingStyle.Quad)
		if back then
			back.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not hovering then
					lifted = false
				end
			end)
		end
		Tween(s, 0.15, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		move(3, 0.05)
		Tween(s, 0.06, { Scale = 0.93 })
	end)
	btn.MouseButton1Up:Connect(function()
		move(hovering and -4 or 0, 0.25, Enum.EasingStyle.Back)
		Tween(s, 0.25, { Scale = hovering and 1.04 or 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(function()
		if not noSound then
			Audio.Play("UIClick")
		end
	end)
end

-- Recolor a button made by UI.Button (Roblox Instances cannot carry custom methods)
function UI.SetButtonColor(btn, c)
	local fill = btn:FindFirstChild("Fill")
	if fill then
		fill.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.28), c:Lerp(Color3.new(0, 0, 0), 0.12))
	end
	local shadow = btn.Parent and btn.Parent:FindFirstChild("Shadow")
	if shadow then
		shadow.BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.55)
	end
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = c:Lerp(Color3.new(0, 0, 0), 0.6)
	end
end

-- Glossy 3D button. Returns (button, holder)
function UI.Button(parent, text, color, size, onClick, props)
	color = color or T.Ocean
	local holder = New("Frame", { BackgroundTransparency = 1, Size = size or UDim2.fromOffset(150, 48), Parent = parent })
	local shadow = New("Frame", { Name = "Shadow", BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55), Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 5), Parent = holder })
	UI.Corner(shadow, 14)
	local btn = New("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = F.Display,
		TextScaled = true,
		AutoButtonColor = false,
		Parent = holder,
	})
	UI.Corner(btn, 14)
	local grad = New("UIGradient", { Name = "Fill", Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color:Lerp(Color3.new(0, 0, 0), 0.12)), Rotation = 90, Parent = btn })
	UI.Stroke(btn, color:Lerp(Color3.new(0, 0, 0), 0.6), 3)
	-- only one UIStroke per object renders, so the label outline uses the built-in text stroke
	btn.TextStrokeColor3 = T.Edge
	btn.TextStrokeTransparency = 0
	local gloss = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Size = UDim2.new(1, -10, 0.38, 0), Position = UDim2.fromOffset(5, 3), ZIndex = btn.ZIndex + 1, Parent = btn })
	UI.Corner(gloss, 10)
	New("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 9, Parent = btn })
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = btn })
	UI.Tactile(btn)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	if props then
		for k, v in pairs(props) do
			holder[k] = v
		end
	end
	return btn, holder
end

function UI.Bar(parent, color, size, label)
	local back = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = size or UDim2.new(1, 0, 0, 16), Parent = parent })
	UI.Corner(back, 8)
	UI.Stroke(back, T.Edge, 2)
	local ghost = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Size = UDim2.new(1, 0, 1, 0), Parent = back })
	UI.Corner(ghost, 8)
	local fill = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, 0), Parent = back })
	UI.Corner(fill, 8)
	local g = UI.Gradient(fill, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.15), 90)
	local hi = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, Size = UDim2.new(1, -4, 0.35, 0), Position = UDim2.fromOffset(2, 1), Parent = fill })
	UI.Corner(hi, 6)
	local txt = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		Text = label or "",
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = F.Number,
		TextScaled = true,
		ZIndex = 3,
		Parent = back,
	})
	UI.Stroke(txt, T.Edge, 1.6, Enum.ApplyStrokeMode.Contextual)
	local bar = { back = back, fill = fill, text = txt, ratio = 1 }
	function bar:Set(ratio, text)
		ratio = math.clamp(ratio, 0, 1)
		if ratio ~= self.ratio then
			Tween(fill, 0.18, { Size = UDim2.new(ratio, 0, 1, 0) })
			-- the white "ghost" trails behind on damage like action RPGs
			Tween(ghost, 0.6, { Size = UDim2.new(ratio, 0, 1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			self.ratio = ratio
		end
		if text then
			txt.Text = text
		end
	end
	function bar:SetColor(c)
		g.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c:Lerp(Color3.new(0, 0, 0), 0.15))
	end
	return bar
end

-- Dark glass card
function UI.Card(parent, size, color)
	local f = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = size or UDim2.new(1, 0, 0, 60), Parent = parent })
	UI.Corner(f, 12)
	local base = color or T.Panel
	New("UIGradient", { Name = "CardGradient", Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), 0.08), base:Lerp(Color3.new(0, 0, 0), 0.25)), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 2.5)
	return f
end

-- ===== 3D-rendered icon pack (tools/blender/render_icons.py -> Config/Icons) =====
-- Code can keep passing emoji: the ones below map to rendered icons automatically, anything else stays text.
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
UI.Icons = Icons
local EMOJI_ICON = {
	["🎒"] = "bag", ["📊"] = "stats", ["✨"] = "skills", ["⚓"] = "anchor", ["🏴"] = "flag", ["👥"] = "party",
	["🗺️"] = "map", ["👑"] = "crown", ["📜"] = "scroll", ["🐾"] = "paw", ["🦪"] = "pearl", ["⚙️"] = "gear",
	["🪙"] = "coin", ["☠"] = "skull", ["☠️"] = "skull", ["🏳"] = "whiteflag", ["🔨"] = "hammer", ["🃏"] = "card",
	["🥚"] = "egg", ["🪺"] = "golden_egg", ["🪤"] = "bait", ["🧰"] = "chest", ["📘"] = "book", ["⛵"] = "ship",
	["🧿"] = "charm", ["🍖"] = "meat", ["🪵"] = "wood", ["⚔️"] = "sword", ["👊"] = "knuckles", ["🛍️"] = "chest",
	["🏆"] = "crown", ["📅"] = "scroll", ["🎁"] = "chest", ["📖"] = "book", ["🧑‍✈️"] = "party", ["🎓"] = "book",
	["🛡️"] = "armor", ["💉"] = "medkit", ["🧭"] = "map", ["🎯"] = "slingshot", ["🍳"] = "boots",
}
function UI.IconId(icon)
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		return icon
	end
	return Icons[EMOJI_ICON[icon] or icon]
end

-- icon name for an item definition (Config/Items)
local ITEM_ICON = {
	MeatOnBone = "meat", BigFeast = "meat", TangerineJuice = "juice", RepairKit = "repairkit", RefineGuard = "charm",
	CaptainsLog = "book", SeaEgg = "egg", GoldenEgg = "golden_egg", SeaBait = "bait", Wood = "wood", TreasureWood = "wood",
	SailCloth = "cloth", SteelOre = "ore", IronIngot = "ore", Gunpowder = "ore", TidecoreShard = "shard", PureTidecore = "shard",
	LeviathanScale = "shard", TreasureMap = "map", WantedPoster = "scroll", MarineBadge = "charm", CompassCharm = "charm",
	TangerinePin = "charm", SharkToothNecklace = "charm",
}
local WEAPON_ICON = { Sword = "sword", Knuckles = "knuckles", Slingshot = "slingshot", Shoes = "boots", StormBaton = "staff", MedKit = "medkit", Hammer = "hammer" }
local KIND_ICON = { Armor = "armor", Headgear = "hat", Accessory = "charm", Card = "card", Egg = "egg", Consumable = "potion", Material = "ore" }
function UI.ItemIconId(def)
	if not def then
		return nil
	end
	local name = ITEM_ICON[def.id]
		or (def.fruit and ("fruit_" .. string.lower(def.fruit)))
		or (def.weaponType and WEAPON_ICON[def.weaponType])
		or KIND_ICON[def.kind]
	return name and Icons[name] or nil
end

-- An icon that is a rendered image when one exists, emoji text otherwise. Returns the GuiObject.
function UI.Icon(parent, icon, size, props)
	local id = UI.IconId(icon)
	local o
	if id then
		o = New("ImageLabel", { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(size, size), Parent = parent })
	else
		o = UI.Text(parent, icon or "", math.floor(size * 0.8), Color3.new(1, 1, 1), "Display", { Size = UDim2.fromOffset(size, size), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	end
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return o
end

-- Rounded square icon chip (gradient + outline), the building block of section headers and tabs
function UI.IconChip(parent, icon, color, size)
	size = size or 34
	color = color or T.Accent
	local chip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(size, size), Parent = parent })
	UI.Corner(chip, math.floor(size * 0.3))
	UI.Gradient(chip, color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	UI.Stroke(chip, T.Edge, 2.5)
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Size = UDim2.new(1, -6, 0.4, 0), Position = UDim2.fromOffset(3, 2), Parent = chip }, { New("UICorner", { CornerRadius = UDim.new(0, math.floor(size * 0.22)) }) })
	if UI.IconId(icon) then
		-- rendered icons pop slightly out of the chip (Anime Vanguards style)
		UI.Icon(chip, icon, math.floor(size * 1.12), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), ZIndex = (chip.ZIndex or 1) + 1 })
	else
		UI.Text(chip, icon or "", math.floor(size * 0.62), Color3.new(1, 1, 1), "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	end
	return chip
end

-- 3D model from ReplicatedStorage.Assets.<folder>.<key> (Blender models loaded by the server's AssetService) in a
-- ViewportFrame, slowly turning (Anime Vanguards style inventory). Returns nil when that model is not loaded, so
-- callers fall back to the 2D icon.
function UI.ModelAsset(folder, key)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local f = assets and assets:FindFirstChild(folder)
	return f and f:FindFirstChild(key)
end

function UI.ModelView(parent, folder, key, size, spin, props)
	local src = UI.ModelAsset(folder, key)
	if not src then
		return nil
	end
	local vp = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local m = src:Clone()
	m:PivotTo(CFrame.new())
	m.Parent = vp
	local _, ext = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = math.max(ext.X, ext.Y, ext.Z) * 0.62 / math.tan(math.rad(15))
	cam.CFrame = CFrame.lookAt(Vector3.new(0, ext.Y * 0.12, -dist), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	local yaw = math.rad(-25)
	m:PivotTo(CFrame.Angles(0, yaw, 0))
	if spin ~= false then
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not vp.Parent then
				conn:Disconnect()
				return
			end
			yaw += dt * (tonumber(spin) or 0.8)
			m:PivotTo(CFrame.Angles(0, yaw, 0))
		end)
	end
	return vp
end

-- Section header: icon chip + display title + accent rule, with optional right-aligned info text.
-- Returns (frame, rightLabel)
function UI.Section(parent, icon, title, color, rightText)
	color = color or T.Gold
	local f = New("Frame", { Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), Parent = parent })
	local chip = UI.IconChip(f, icon, color, 34)
	chip.Position = UDim2.fromOffset(0, 1)
	UI.Text(f, string.upper(title), 21, Color3.new(1, 1, 1), "Display", { Position = UDim2.fromOffset(44, 2), Size = UDim2.new(1, -44, 0, 26), TextWrapped = false })
	local rule = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(44, 31), Size = UDim2.new(1, -44, 0, 4), Parent = f })
	UI.Corner(rule, 2)
	New("UIGradient", { Color = ColorSequence.new(color, color), Transparency = NumberSequence.new(0, 1), Parent = rule })
	local right = UI.Text(f, rightText or "", 17, color, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0.5, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
	return f, right
end

-- Icon tab bar. tabs = { { id, icon, label, color? }, ... }. Width follows the label length so text never overflows.
function UI.TabBar(parent, tabs, current, onPick, height)
	height = height or 38
	local bar = New("Frame", { Name = "TabBar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height + 6), Parent = parent })
	UI.List(bar, Enum.FillDirection.Horizontal, 6)
	for i, t in ipairs(tabs) do
		local on = t[1] == current
		local ts = math.floor(height * 0.46)
		local w = math.floor(30 + (#t[3] + 2) * ts * 0.56)
		local btn, holder = UI.Button(bar, t[2] .. " " .. t[3], on and (t[4] or T.Orange) or T.Grey, UDim2.fromOffset(w, height), function()
			onPick(t[1])
		end)
		holder.LayoutOrder = i
		btn.TextScaled = false
		btn.TextSize = ts
		if not on then
			btn.TextColor3 = Color3.fromRGB(215, 212, 235)
		end
	end
	return bar
end

function UI.Scroll(parent, size)
	return New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = size or UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 7,
		ScrollBarImageColor3 = T.Gold,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- ===== Window =====
local blur = Lighting:FindFirstChild("UIBlur") or New("BlurEffect", { Name = "UIBlur", Size = 0, Parent = Lighting })
local dim = New("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 15, Parent = gui })
local openWindows = {}
local openCount = 0
local function refreshDim()
	openCount = 0
	for _ in pairs(openWindows) do
		openCount += 1
	end
	dim.Visible = openCount > 0
	Tween(dim, 0.2, { BackgroundTransparency = openCount > 0 and 0.55 or 1 })
	Tween(blur, 0.25, { Size = openCount > 0 and 10 or 0 })
end
-- the dim backdrop only blocks clicks: windows close with their red X (or Esc), never by a stray click (owner request)

-- windows that can fill the screen (opts.fullscreen): they open full screen and a button next to the X shrinks them
-- back to a normal window (and back); the choice is remembered per window for this session
UI.FullPref = {}
function UI.Window(id, title, size, color, icon, opts)
	opts = opts or {}
	if openWindows[id] then
		openWindows[id]:Destroy()
	end
	color = (color or T.Accent):Lerp(T.Accent, 0.45)
	local frame = New("Frame", {
		Name = "Win_" .. id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = size or UDim2.fromOffset(560, 520),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Parent = gui,
	})
	UI.Corner(frame, 20)
	New("UIGradient", { Color = ColorSequence.new(T.Panel:Lerp(Color3.new(1, 1, 1), 0.04), T.PanelDeep), Rotation = 90, Parent = frame })
	UI.Stroke(frame, T.Edge, 4)
	-- coloured rim light
	local rim = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = frame, ZIndex = 20 })
	UI.Corner(rim, 18)
	UI.Stroke(rim, color, 2).Transparency = 0.35
	-- Anime-Vanguards-style header: slanted accent tab on the left, red square close on the right
	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Parent = frame, ZIndex = 21 })
	local tab = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.62, 0, 0, 50), Position = UDim2.fromOffset(-10, -12), ZIndex = 22, Parent = header })
	UI.Corner(tab, 10)
	New("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(T.AccentHot, 0.35)), Rotation = 0, Parent = tab })
	UI.Stroke(tab, T.Edge, 3)
	local slant = New("Frame", { BackgroundColor3 = color:Lerp(T.AccentHot, 0.35), Size = UDim2.fromOffset(50, 50), Position = UDim2.new(1, -2, 0, 0), ZIndex = 22, Parent = tab })
	New("UIGradient", { Rotation = 45, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.499, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = slant })
	UI.Shine(tab, 0)
	local titleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(24, 0),
		Text = string.upper(title),
		FontFace = F.Display,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = tab,
	})
	UI.Stroke(titleLabel, T.Edge, 3, Enum.ApplyStrokeMode.Contextual)
	if icon then
		-- icon chip pokes out of the left of the tab, title shifts right
		local chip = UI.IconChip(tab, icon, color:Lerp(T.Gold, 0.35), 58)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, -4, 0.5, 2)
		chip.Rotation = -6
		chip.ZIndex = 25
		for _, d in ipairs(chip:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 26
			end
		end
		titleLabel.Position = UDim2.fromOffset(66, 0)
		titleLabel.Size = UDim2.new(1, -70, 1, 0)
		-- big faded watermark of the same icon in the window corner (Anime Vanguards-style decoration)
		local mark = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), Size = UDim2.fromOffset(190, 190), Text = icon, TextScaled = true, TextTransparency = 0.93, Rotation = -12, FontFace = F.Display, ZIndex = 20, Parent = frame })
		local _ = mark
	end
	-- diagonal speed stripes across the tab
	for k = 0, 2 do
		local st = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.86, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -70 - k * 22, 0.5, 0), Size = UDim2.fromOffset(8, 46), Rotation = 28, ZIndex = 22, Parent = tab })
		local _ = st
	end
	tab.ClipsDescendants = false
	local close = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 12, 0, -12),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = T.Red,
		Text = "X",
		FontFace = F.Display,
		TextSize = 28,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = T.Edge,
		AutoButtonColor = false,
		ZIndex = 24,
		Parent = header,
	})
	UI.Corner(close, 8)
	UI.Stroke(close, T.Edge, 3)
	UI.Tactile(close)
	local body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 1, -72), Parent = frame, ZIndex = 21 })
	local win = { frame = frame, body = body, id = id, header = header, resized = Instance.new("BindableEvent") }
	local windowSize = size or UDim2.fromOffset(560, 520)
	local restPos = UDim2.fromScale(0.5, 0.53)
	if opts.fullscreen then
		if UI.FullPref[id] == nil then
			UI.FullPref[id] = true
		end
		local maxBtn = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -42, 0, -12),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = T.Gold,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 24,
			Parent = header,
		})
		UI.Corner(maxBtn, 8)
		UI.Stroke(maxBtn, T.Edge, 3)
		UI.Tactile(maxBtn)
		-- drawn icon: one big square = "make it full screen", two stacked squares = "back to a window"
		local big = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 18), BackgroundTransparency = 1, ZIndex = 25, Parent = maxBtn })
		UI.Stroke(big, T.Edge, 3)
		local back = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 4, 0.5, -4), Size = UDim2.fromOffset(16, 13), BackgroundTransparency = 1, ZIndex = 25, Parent = maxBtn })
		UI.Stroke(back, T.Edge, 3)
		local function apply(animate)
			local full = UI.FullPref[id]
			-- full screen stays below Roblox's own top-bar buttons (the header tab pokes 12px above the frame)
			local inset = 0
			pcall(function()
				inset = game:GetService("GuiService").TopbarInset.Max.Y / math.max(0.01, rootScale.Scale)
			end)
			local top = math.max(inset, 44) + 18
			local target = full and UDim2.new(1, -36, 1, -(top + 14)) or windowSize
			restPos = full and UDim2.new(0.5, 0, 0.5, (top - 14) / 2) or UDim2.fromScale(0.5, 0.53)
			win.full = full
			big.Size = full and UDim2.fromOffset(16, 13) or UDim2.fromOffset(22, 18)
			big.Position = full and UDim2.new(0.5, -3, 0.5, 3) or UDim2.fromScale(0.5, 0.5)
			back.Visible = full
			if animate then
				Tween(frame, 0.22, { Size = target, Position = restPos })
				task.delay(0.24, function()
					win.resized:Fire(full)
				end)
			else
				frame.Size = target
			end
		end
		apply(false)
		maxBtn.Activated:Connect(function()
			UI.FullPref[id] = not UI.FullPref[id]
			apply(true)
		end)
		UI.Tooltip(maxBtn, function()
			return UI.FullPref[id] and "Shrink to a window" or "Full screen", T.Gold
		end)
		win.maxBtn = maxBtn
	end
	function win:Destroy()
		if openWindows[id] == win then
			openWindows[id] = nil
			Audio.Play("UIClose")
			refreshDim()
		end
		frame:Destroy()
		win.resized:Destroy()
	end
	close.Activated:Connect(function()
		win:Destroy()
	end)
	local sc = New("UIScale", { Scale = 0.8, Parent = frame })
	frame.Position = restPos + UDim2.fromScale(0, 0.09)
	Tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Tween(frame, 0.3, { Position = restPos }, Enum.EasingStyle.Back)
	openWindows[id] = win
	Audio.Play("UIOpen")
	refreshDim()
	return win
end

function UI.CloseWindow(id)
	if openWindows[id] then
		openWindows[id]:Destroy()
	end
end

function UI.IsOpen(id)
	return openWindows[id] ~= nil
end

function UI.CloseAll()
	for _, w in pairs(openWindows) do
		w:Destroy()
	end
end

-- ===== Tooltip =====
local tip = New("Frame", { Name = "Tooltip", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 60, Parent = gui })
UI.Corner(tip, 10)
New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = tip })
local tipStroke = UI.Stroke(tip, T.Gold, 2.5)
UI.Pad(tip, 10)
local tipText = UI.Text(tip, "", 16, T.Text, "Semi", { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), ZIndex = 61 })
function UI.Tooltip(obj, fn)
	obj.MouseEnter:Connect(function()
		local text, color = fn()
		if not text then
			return
		end
		tipText.Text = text
		tipStroke.Color = color or T.Gold
		tip.Visible = true
	end)
	obj.MouseLeave:Connect(function()
		tip.Visible = false
	end)
end
RunService.RenderStepped:Connect(function()
	if tip.Visible then
		local m = UserInputService:GetMouseLocation()
		tip.Position = UDim2.fromOffset(m.X / rootScale.Scale + 18, m.Y / rootScale.Scale - 10)
	end
end)

-- ===== Toasts (slide in from the right) =====
local toastHolder = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 120), Size = UDim2.fromOffset(420, 400), BackgroundTransparency = 1, Parent = gui })
local tl = UI.List(toastHolder, nil, 6, Enum.HorizontalAlignment.Right)
UI.ToastHolder = toastHolder
tl.VerticalAlignment = Enum.VerticalAlignment.Top
local toastColors = { info = T.Ocean, good = T.Green, bad = T.Red, level = T.Gold, pvp = T.Purple, card = T.Gold, mvp = T.Orange }
local toastIcons = { info = "💬", good = "✅", bad = "⚠️", level = "⬆️", pvp = "⚔️", card = "🃏", mvp = "👑" }
function UI.Toast(text, kind)
	kind = kind or "info"
	local color = toastColors[kind] or T.Ocean
	if kind == "bad" then
		Audio.Play("Error")
	end
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 46), Parent = toastHolder })
	local f = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(440, 0), Parent = holder })
	UI.Corner(f, 12)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 2.5)
	local strip = New("Frame", { BackgroundColor3 = color, Size = UDim2.new(0, 8, 1, 0), Parent = f })
	UI.Corner(strip, 4)
	UI.Text(f, (toastIcons[kind] or "") .. "  " .. text, 17, T.Text, "Bold", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -24, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	Tween(f, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	task.delay(3.4, function()
		Tween(f, 0.25, { Position = UDim2.fromOffset(440, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.26)
		holder:Destroy()
	end)
	local frames = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 6 then
		frames[1]:Destroy()
	end
end

-- ===== Banner (center screen punch) =====
-- Banners queue up and play one at a time (they used to stack on top of each other); a backlog plays faster.
local bannerQueue, bannerBusy = {}, false
local showBanner
function UI.Banner(title, subtitle, color, rarityId)
	table.insert(bannerQueue, { title, subtitle, color, rarityId })
	if bannerBusy then
		return
	end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			showBanner(b[1], b[2], b[3], b[4], #bannerQueue > 0 and 1.3 or 2.6)
		end
		bannerBusy = false
	end)
end

showBanner = function(title, subtitle, color, rarityId, hold)
	color = color or T.Gold
	local f = New("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(820, 150), BackgroundTransparency = 1, Parent = gui, ZIndex = 40 })
	local t = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.66, 0), Text = string.upper(title), FontFace = F.Display, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 41, Parent = f })
	local tg = New("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.55), color), Rotation = 90, Parent = t })
	UI.Stroke(t, T.Edge, 5, Enum.ApplyStrokeMode.Contextual)
	if rarityId then
		local tier = Rarity.Get(rarityId)
		if tier.rainbow then
			tg.Color = RAINBOW
			rainbows[tg] = true
		end
		Audio.Play("Rarity" .. tier.id)
	end
	local s = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.66), Size = UDim2.new(1, 0, 0.3, 0), Text = subtitle or "", FontFace = F.Bold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 41, Parent = f })
	UI.Stroke(s, T.Edge, 3, Enum.ApplyStrokeMode.Contextual)
	local sc = New("UIScale", { Scale = 2.2, Parent = f })
	t.TextTransparency = 1
	Tween(t, 0.15, { TextTransparency = 0 })
	Tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(hold)
	Tween(sc, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Tween(t, 0.25, { TextTransparency = 1 })
	Tween(s, 0.25, { TextTransparency = 1 })
	task.wait(0.3)
	f:Destroy()
end

-- ===== Server announcements (top marquee) =====
local announceBar = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(700, 40), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = gui, ClipsDescendants = true })
UI.Corner(announceBar, 20)
local annGrad = New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = announceBar })
local annStroke = UI.Stroke(announceBar, T.Gold, 2.5)
local announceText = UI.Text(announceBar, "", 19, T.Gold, "Bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
local announceQueue = {}
local announcing = false
function UI.Announce(text, rarityId)
	table.insert(announceQueue, { text = text, rarity = rarityId })
	if announcing then
		return
	end
	announcing = true
	task.spawn(function()
		while #announceQueue > 0 do
			local a = table.remove(announceQueue, 1)
			local tier = a.rarity and Rarity.Get(a.rarity)
			announceText.Text = "📢 " .. a.text
			announceText.TextColor3 = tier and tier.color or T.Gold
			annStroke.Color = tier and tier.color or T.Gold
			annGrad.Color = ColorSequence.new(T.PanelTop, T.PanelDeep)
			announceBar.Visible = true
			UI.Pop(announceBar, 0.8)
			task.wait(4)
		end
		announceBar.Visible = false
		announcing = false
	end)
end

function UI.Confirm(text, onYes, onNo, yesLabel, noLabel)
	local win = UI.Window("Confirm", "Confirm", UDim2.fromOffset(470, 260), T.Orange, "❓")
	UI.Text(win.body, text, 20, T.Text, "Bold", { Size = UDim2.new(1, 0, 0, 96), TextXAlignment = Enum.TextXAlignment.Center })
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 1, -58), Parent = win.body })
	UI.List(row, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	UI.Button(row, yesLabel or "Accept", T.Green, UDim2.fromOffset(160, 50), function()
		win:Destroy()
		if onYes then
			onYes()
		end
	end)
	UI.Button(row, noLabel or "Decline", T.Red, UDim2.fromOffset(160, 50), function()
		win:Destroy()
		if onNo then
			onNo()
		end
	end)
end

-- Floating "+123" popup at a screen position (e.g. currency gain)
function UI.FloatText(text, color, pos)
	local t = UI.Text(gui, text, 30, color or T.Gold, "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 50 })
	UI.Pop(t, 0.4)
	Tween(t, 1.1, { Position = t.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 })
	task.delay(1.15, function()
		t:Destroy()
	end)
end

function UI.Format(n)
	n = math.floor(n or 0)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

function UI.Short(n)
	n = n or 0
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return UI.Format(n)
end

-- Pill toggle switch (green = on, pink = off), Anime-Vanguards settings style
function UI.Toggle(parent, label, value, onChange, desc)
	local row = New("TextButton", { Size = UDim2.new(1, -8, 0, desc and 58 or 44), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = parent })
	UI.Corner(row, 10)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.Panel), Rotation = 90, Parent = row })
	UI.Stroke(row, T.Edge, 2)
	UI.Text(row, label, 17, T.Text, "Bold", { Position = UDim2.fromOffset(12, desc and 6 or 0), Size = UDim2.new(1, -90, 0, desc and 22 or 44) })
	if desc then
		UI.Text(row, desc, 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -90, 0, 24) })
	end
	local track = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(56, 28), BackgroundColor3 = value and T.Green or T.Pink, Parent = row })
	UI.Corner(track, 14)
	UI.Stroke(track, T.Edge, 2)
	local knob = New("Frame", { Size = UDim2.fromOffset(22, 22), Position = value and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.Corner(knob, 11)
	UI.Tactile(row)
	row.Activated:Connect(function()
		value = not value
		Tween(knob, 0.15, { Position = value and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
		Tween(track, 0.15, { BackgroundColor3 = value and T.Green or T.Pink })
		onChange(value)
	end)
	return row
end

-- Wide center notice bar ("Wave Completed!" style)
local noticeHolder = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 168), Size = UDim2.fromOffset(620, 120), BackgroundTransparency = 1, Parent = gui })
UI.List(noticeHolder, nil, 4, Enum.HorizontalAlignment.Center)
function UI.Notice(text, color)
	color = color or T.Green
	-- keep at most 2 notices on screen
	local bars = {}
	for _, c in ipairs(noticeHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(bars, c)
		end
	end
	for i = 1, #bars - 1 do
		bars[i]:Destroy()
	end
	local bar = New("Frame", { Size = UDim2.fromOffset(560, 34), BackgroundColor3 = color, Parent = noticeHolder })
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) }), Parent = bar })
	UI.Text(bar, text, 22, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	UI.Pop(bar, 0.7)
	task.delay(2.4, function()
		Tween(bar, 0.3, { BackgroundTransparency = 1 })
		local t = bar:FindFirstChildOfClass("TextLabel")
		if t then
			Tween(t, 0.3, { TextTransparency = 1 })
		end
		task.wait(0.32)
		bar:Destroy()
	end)
end

-- Hunting-Together-style combo counter (right side)
local combo = { count = 0, last = 0 }
local comboFrame = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 150, 0.4, 0), Size = UDim2.fromOffset(190, 70), BackgroundTransparency = 1, Visible = false, Parent = gui })
local comboText = UI.Text(comboFrame, "x0", 46, Color3.fromRGB(255, 70, 90), "Display", { Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Right })
UI.Text(comboFrame, "COMBO", 16, T.Text, "Display", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, -66, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })
local comboBar = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 52), Size = UDim2.fromOffset(60, 8), BackgroundColor3 = T.PanelDeep, Parent = comboFrame })
UI.Corner(comboBar, 4)
local comboFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 70, 90), Parent = comboBar })
UI.Corner(comboFill, 4)
function UI.ComboHit()
	local now = os.clock()
	if now - combo.last > 2.5 then
		combo.count = 0
	end
	combo.count += 1
	combo.last = now
	comboText.Text = "x" .. combo.count
	comboFrame.Visible = true
	UI.Bounce(comboText)
end
RunService.RenderStepped:Connect(function()
	if comboFrame.Visible then
		local left = 1 - (os.clock() - combo.last) / 2.5
		comboFill.Size = UDim2.fromScale(math.clamp(left, 0, 1), 1)
		if left <= 0 then
			comboFrame.Visible = false
		end
	end
end)

UI.CurrencyIcon = "🪙"
return UI
