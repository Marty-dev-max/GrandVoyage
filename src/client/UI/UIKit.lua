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

-- v0.25.28 (owner reference "Pixel UI & Icons"): 16-bit fantasy RPG frames: deep indigo panels, a dark outer edge,
-- a light lavender bevel line inside it, gold trim and rivets, glowing icon tiles, hue-shifted gradient bars
UI.Theme = {
	Panel = Color3.fromRGB(40, 37, 82),
	PanelTop = Color3.fromRGB(58, 54, 112),
	PanelDeep = Color3.fromRGB(22, 20, 50),
	Edge = Color3.fromRGB(10, 9, 26),
	Bevel = Color3.fromRGB(122, 116, 200), -- inner light rim of frames
	Trim = Color3.fromRGB(232, 190, 92), -- gold rivets / plaque trim
	Accent = Color3.fromRGB(156, 84, 255),
	AccentHot = Color3.fromRGB(230, 90, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextSoft = Color3.fromRGB(214, 212, 236), -- v0.25.6: brighter (owner: hard to read)
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

-- v0.24.0 (owner): the whole game uses the pixel font Press Start 2P (Enum.Font.Arcade); UI/PixelUI scales fixed
-- text sizes for it and squares every corner
-- v0.25.28 (owner: the pixel font does not suit every text): pixel font for titles, labels, buttons and numbers;
-- descriptions, dialog and long text ("Semi") use Builder Sans (Roblox's UI font) at its real size: easy to read
local PIXEL_FONT = Font.fromEnum(Enum.Font.Arcade)
local BODY_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
UI.Fonts = {
	Display = PIXEL_FONT,
	Bold = PIXEL_FONT,
	Semi = BODY_FONT,
	Body = BODY_FONT,
	Number = PIXEL_FONT,
}
UI.BodyFamily = BODY_FONT.Family
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

function UI.Corner(parent, _r)
	-- voxel UI (v0.24.0): square corners everywhere
	return New("UICorner", { CornerRadius = UDim.new(0, 0), Parent = parent })
end

function UI.Stroke(parent, color, thick, mode)
	return New("UIStroke", { Color = color or T.Edge, Thickness = thick or 2.5, ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter, Parent = parent })
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

-- rich-text color helpers (v0.25.2, owner: names of classes, stats, guilds in their own colors)
function UI.Colored(text, c)
	return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), text)
end
UI.StatColor = {
	STR = Color3.fromRGB(255, 110, 80), AGI = Color3.fromRGB(110, 230, 120), VIT = Color3.fromRGB(255, 170, 70),
	INT = Color3.fromRGB(150, 130, 255), DEX = Color3.fromRGB(90, 210, 255), LUK = Color3.fromRGB(255, 220, 80),
}

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
	if kind == "Semi" or kind == "Body" then
		t.TextSize = math.floor(size * 0.95 + 0.5) -- Builder Sans reads at its own size (PixelUI leaves it alone)
		t.LineHeight = 1.05
		UI.Stroke(t, T.Edge, 1.2, Enum.ApplyStrokeMode.Contextual).Transparency = 0.35
	else
		UI.Stroke(t, T.Edge, math.max(1.2, size / 9), Enum.ApplyStrokeMode.Contextual)
	end
	if props then
		for k, v in pairs(props) do
			t[k] = v
		end
	end
	return t
end

-- pixel-art "hue shifting": highlights drift warm and lighter, shadows drift cool and darker (never plain lerps to
-- white / black), which is what makes the reference bars and icons look rich instead of flat
function UI.Shade(c, k)
	local h, sat, v = c:ToHSV()
	if k > 0 then
		return Color3.fromHSV((h - 0.035 * k) % 1, math.clamp(sat * (1 - 0.35 * k), 0, 1), math.clamp(v + (1 - v) * 0.6 * k + 0.12 * k, 0, 1))
	end
	k = -k
	return Color3.fromHSV((h + 0.045 * k) % 1, math.clamp(sat * (1 + 0.15 * k), 0, 1), math.clamp(v * (1 - 0.5 * k), 0, 1))
end
function UI.RichFill(c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Shade(c, 0.75)),
		ColorSequenceKeypoint.new(0.18, UI.Shade(c, 0.3)),
		ColorSequenceKeypoint.new(0.55, c),
		ColorSequenceKeypoint.new(1, UI.Shade(c, -0.55)),
	})
end

-- two-tone pixel frame: dark outer edge (UIStroke) + light bevel line just inside (child frame)
function UI.Bevel(frame, color, inset, transparency)
	-- v0.25.42: inside a Folder, so a UIListLayout / UIGridLayout on the frame does not lay the rim out as its first
	-- item (it pushed a card's whole content below the card: the Guild window "fell down")
	local holder = frame:FindFirstChild("BevelHolder") or New("Folder", { Name = "BevelHolder", Parent = frame })
	local b = New("Frame", { Name = "Bevel", BackgroundTransparency = 1, Position = UDim2.fromOffset(inset or 2, inset or 2), Size = UDim2.new(1, -(inset or 2) * 2, 1, -(inset or 2) * 2), ZIndex = frame.ZIndex, Parent = holder })
	UI.Stroke(b, color or T.Bevel, 1.5).Transparency = transparency or 0.2
	return b
end

-- ===== animated gradients (rarity shine / rainbow) =====
local shines = {}
local rainbows = {}
local pulses = {} -- v0.25.36: ImageLabel -> base transparency (rarity aura breathing in and out)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for img, base in pairs(pulses) do
		if img.Parent then
			img.ImageTransparency = base + 0.18 * (0.5 + 0.5 * math.sin(t * 2.6))
		else
			pulses[img] = nil
		end
	end
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
-- Mythic: bright pastel rainbow (prismatic) for backgrounds; spins slowly so it shimmers
local PRISM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 200)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 226, 150)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(170, 250, 180)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 236, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(170, 180, 255)),
	ColorSequenceKeypoint.new(0.84, Color3.fromRGB(230, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 200)),
})
UI.PrismaticSequence = PRISM
-- keep a UIGradient turning (rainbow / prismatic shimmer)
function UI.SpinGradient(g)
	rainbows[g] = true
	return g
end

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
-- v0.25.28 (owner reference "Pixel UI & Icons"): an item tile is a DARK slot tinted by its rarity, with a bright
-- rarity rim and a soft aura of that color behind the icon, so the icon itself is what glows (no flat bright fills)
function UI.RarityStyle(frame, rarityId, strong)
	local tier = Rarity.Get(rarityId)
	-- v0.25.36 (owner: Secret looked plain gray): every tier has its own look and motion, climbing with the rank
	--   Common/Uncommon flat · Rare + sheen sweep · Epic + breathing aura + glowing rim · Legendary + pixel particles
	--   Mythic prismatic · Secret dark violet with a holographic foil that drifts + rainbow rim
	local secret = tier.id == "Secret" or tier.rainbow
	frame.BackgroundColor3 = tier.prismatic and Color3.fromRGB(110, 100, 170) or Color3.new(1, 1, 1)
	local g = frame:FindFirstChild("RarityGradient") or New("UIGradient", { Name = "RarityGradient", Rotation = 90, Parent = frame })
	g.Color = tier.prismatic and PRISM
		or (secret and ColorSequence.new(Color3.fromRGB(92, 40, 140), Color3.fromRGB(14, 8, 30)))
		or ColorSequence.new(T.PanelTop:Lerp(tier.color, 0.38), T.PanelDeep:Lerp(tier.color, 0.12))
	if tier.prismatic then
		rainbows[g] = true
	end
	if secret and not frame:FindFirstChild("Foil") then
		local foil = New("Frame", { Name = "Foil", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = frame.ZIndex, Parent = frame })
		local corner = frame:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Clone().Parent = foil
		end
		rainbows[New("UIGradient", { Color = RAINBOW, Parent = foil })] = true
	end
	if not frame:FindFirstChild("RarityAura") then
		local okT, texCfg = pcall(require, ReplicatedStorage.Shared.Config.Textures)
		if okT and texCfg.glow then
			New("ImageLabel", { Name = "RarityAura", BackgroundTransparency = 1, Image = texCfg.glow, ImageTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.05, 1.05), ZIndex = frame.ZIndex, Parent = frame })
		end
	end
	local aura = frame:FindFirstChild("RarityAura")
	if aura then
		aura.ImageColor3 = (tier.prismatic or secret) and Color3.fromRGB(255, 230, 255) or UI.Shade(tier.color, 0.25)
		aura.ImageTransparency = tier.rank <= 1 and 0.7 or (0.55 - math.min(tier.rank, 5) * 0.05)
		if tier.rank >= 4 then
			pulses[aura] = aura.ImageTransparency
		end
	end
	local st = frame:FindFirstChild("RarityStroke") or UI.Stroke(frame, tier.color, strong and 3.5 or 2.5)
	st.Name = "RarityStroke"
	st.Thickness = strong and 3.5 or 2.5
	st.Color = (tier.rainbow or tier.prismatic or tier.rank >= 4) and Color3.new(1, 1, 1) or UI.Shade(tier.color, 0.15)
	if tier.rainbow or tier.prismatic then
		local sg = st:FindFirstChild("Rainbow") or New("UIGradient", { Name = "Rainbow", Color = RAINBOW, Parent = st })
		rainbows[sg] = true
	elseif tier.rank >= 4 and not st:FindFirstChild("Glow") then
		-- animated border glow: a bright highlight runs round the rim
		local c = UI.Shade(tier.color, 0.1)
		rainbows[New("UIGradient", { Name = "Glow", Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.45, c), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.55, c), ColorSequenceKeypoint.new(1, c) }), Parent = st })] = true
	end
	if tier.rank >= 3 and not frame:FindFirstChild("Shine") then
		UI.Shine(frame)
	end
	if tier.rank >= 5 and not frame:FindFirstChild("Sparkles") then
		UI.Sparkles(frame, secret and Color3.new(1, 1, 1) or UI.Shade(tier.color, 0.3), strong and 10 or 5, { float = true, star = 0.6, color2 = secret and Color3.fromRGB(255, 150, 230) or nil })
	end
	return tier
end

-- v0.25.36 (owner): a fruit's tile / stage gets pixel particles shaped like its power (rubber swirls, flames, smoke...)
local FRUIT_PT = { Bounce = "pt_swirl", Blaze = "pt_flame", Haze = "pt_cloud", Ward = "pt_hex", Split = "pt_slice", Slick = "pt_drop" }
function UI.FruitFx(frame, fruitId, n)
	local icon = FRUIT_PT[fruitId or ""]
	if not icon or frame:FindFirstChild("FruitFx") then
		return
	end
	local layer = UI.Sparkles(frame, Color3.new(1, 1, 1), n or 6, { float = true, icons = { icon }, iconFrac = 0.8, iconMin = 10, iconMax = 20, star = 0.5 })
	if layer then
		layer.Name = "FruitFx"
	end
end

-- rainbow text for the top tiers (item names / rarity labels); text has no background, so the gradient tints it
function UI.RarityText(label, rarityId)
	local tier = Rarity.Get(rarityId)
	if tier.rainbow or tier.prismatic then
		label.TextColor3 = Color3.new(1, 1, 1)
		rainbows[New("UIGradient", { Color = tier.prismatic and PRISM or RAINBOW, Parent = label })] = true
	end
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
	UI.Stroke(btn, T.Edge, 3)
	-- only one UIStroke per object renders, so the label outline uses the built-in text stroke
	btn.TextStrokeColor3 = T.Edge
	btn.TextStrokeTransparency = 0
	-- pixel bevel: a bright line along the top, a dark lip along the bottom
	New("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 2), Position = UDim2.fromOffset(2, 2), ZIndex = btn.ZIndex + 1, Parent = btn })
	New("Frame", { Name = "Lip", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 4), Position = UDim2.fromScale(0, 1), ZIndex = btn.ZIndex + 1, Parent = btn })
	New("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 9, Parent = btn })
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = btn })
	UI.Tactile(btn)
	-- v0.25.3 (owner: no emoji): "<emoji> Label" draws the emoji's pixel icon at the left instead
	local first, rest = string.match(text or "", "^(%S+)%s+(.+)$")
	if first and not string.match(first, "^[%w%p]+$") and UI.IconId(first) then -- emoji only, never a word
		btn.Text = rest
		local ic = UI.Icon(btn, first, 26, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -26, 0.5, 0), ZIndex = btn.ZIndex + 2 }) -- v0.25.100: x is inside the 30 px left padding (it sat on the first letter)
		New("UIAspectRatioConstraint", { Parent = ic })
		ic.Size = UDim2.new(0, 26, 0.9, 0)
		local pad = btn:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, 30)
		end
	end
	-- v0.25.99: UIPadding also moves child frames, so the bevel lines are pushed back out by the padding (on short
	-- buttons like PARTY the lip sat across the text)
	local function fitBevel()
		local p = btn:FindFirstChildOfClass("UIPadding")
		local l, r, t, b = p.PaddingLeft.Offset, p.PaddingRight.Offset, p.PaddingTop.Offset, p.PaddingBottom.Offset
		btn.Gloss.Position = UDim2.fromOffset(2 - l, 2 - t)
		btn.Gloss.Size = UDim2.new(1, l + r - 4, 0, 2)
		btn.Lip.Position = UDim2.new(0, -l, 1, b)
		btn.Lip.Size = UDim2.new(1, l + r, 0, 4)
	end
	fitBevel()
	local pad = btn:FindFirstChildOfClass("UIPadding")
	for _, prop in ipairs({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }) do
		pad:GetPropertyChangedSignal(prop):Connect(fitBevel)
	end
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

-- start (optional): the ratio it starts at (progress bars pass 0 so they fill up instead of draining in red)
function UI.Bar(parent, color, size, label, start)
	local back = New("Frame", { BackgroundColor3 = T.PanelDeep:Lerp(Color3.new(0, 0, 0), 0.35), Size = size or UDim2.new(1, 0, 0, 16), Parent = parent })
	UI.Corner(back, 8)
	UI.Stroke(back, T.Edge, 2)
	-- inner shadow along the top of the empty track
	New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Parent = back })
	local ghost = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Size = UDim2.new(start or 1, 0, 1, 0), Parent = back })
	UI.Corner(ghost, 8)
	local fill = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(start or 1, 0, 1, 0), Parent = back })
	UI.Corner(fill, 8)
	local g = New("UIGradient", { Color = UI.RichFill(color), Rotation = 90, Parent = fill })
	local hi = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 2), Position = UDim2.fromOffset(2, 2), Parent = fill })
	UI.Corner(hi, 6)
	-- segment ticks (every 10%) give the bar its "gauge" detail
	for i = 1, 9 do
		New("Frame", { BackgroundColor3 = T.Edge, BackgroundTransparency = 0.7, BorderSizePixel = 0, Position = UDim2.new(i / 10, 0, 0, 3), Size = UDim2.new(0, 1, 1, -6), ZIndex = 2, Parent = back })
	end
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
	local pop = New("UIScale", { Parent = back })
	local bar = { back = back, fill = fill, text = txt, ratio = start or 1, token = 0 }
	function bar:Set(ratio, text)
		ratio = math.clamp(ratio, 0, 1)
		if math.abs(ratio - self.ratio) > 0.0005 then
			self.token += 1
			local token = self.token
			if ratio < self.ratio then
				-- damage: the bar drops fast, the lost part stays as a red chunk for a beat, then drains away;
				-- a big hit also punches the bar and flashes it white
				local lost = self.ratio - ratio
				ghost.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
				ghost.BackgroundTransparency = 0.05
				Tween(fill, 0.12, { Size = UDim2.new(ratio, 0, 1, 0) })
				task.delay(0.28, function()
					if self.token == token then
						Tween(ghost, 0.45, { Size = UDim2.new(ratio, 0, 1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
				end)
				if lost > 0.02 then
					pop.Scale = 1 + math.min(0.12, lost * 0.6)
					Tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
					hi.BackgroundTransparency = 0.1
					Tween(hi, 0.2, { BackgroundTransparency = 0.75 })
				end
			else
				-- healing: a pale band leads, the fill catches up smoothly
				ghost.BackgroundColor3 = Color3.fromRGB(200, 255, 210)
				ghost.BackgroundTransparency = 0.35
				ghost.Size = UDim2.new(ratio, 0, 1, 0)
				Tween(fill, 0.35, { Size = UDim2.new(ratio, 0, 1, 0) })
			end
			self.ratio = ratio
		end
		if text then
			txt.Text = text
		end
	end
	function bar:SetColor(c)
		g.Color = UI.RichFill(c)
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
	UI.Bevel(f, T.Bevel, 2, 0.6)
	return f
end

-- ===== 3D-rendered icon pack (tools/blender/render_icons.py -> Config/Icons) =====
-- Code can keep passing emoji: the ones below map to rendered icons automatically, anything else stays text.
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
UI.Icons = Icons
local EMOJI_ICON = {
	["🎒"] = "bag", ["📊"] = "stats", ["✨"] = "skills", ["⚓"] = "anchor", ["🏴"] = "flag", ["👥"] = "party",
	["🗺️"] = "map", ["👑"] = "crown", ["📜"] = "scroll", ["🐾"] = "paw", ["💎"] = "gem", ["⚙️"] = "gear",
	["🪙"] = "coin", ["☠"] = "skull", ["☠️"] = "skull", ["🏳"] = "whiteflag", ["🔨"] = "hammer", ["🃏"] = "card",
	["🥚"] = "egg", ["🪺"] = "golden_egg", ["🪤"] = "bait", ["🧰"] = "chest", ["📘"] = "book", ["⛵"] = "ship",
	["🧿"] = "charm", ["🍖"] = "meat", ["🪵"] = "wood", ["⚔️"] = "sword", ["👊"] = "knuckles", ["🛍️"] = "shop", ["🏪"] = "stall",
	["🏆"] = "crown", ["📅"] = "scroll", ["🎁"] = "chest", ["📖"] = "book", ["🧑‍✈️"] = "party", ["🎓"] = "book",
	["🛡️"] = "armor", ["💉"] = "medkit", ["🧭"] = "map", ["🎯"] = "slingshot", ["🍳"] = "boots",
	-- v0.25.3 pixel pack additions
	["💨"] = "dash", ["🔥"] = "flame", ["🌙"] = "calm", ["🖥️"] = "graphics", ["🔊"] = "audio", ["🤖"] = "autobattle", ["⌨️"] = "keyboard",
	["🛠️"] = "developer", ["🪟"] = "interface", ["💰"] = "coin", ["🧪"] = "potion", ["🏅"] = "merit", ["🗡️"] = "sword", ["🧢"] = "hat",
	["🎩"] = "hat", ["🪝"] = "bait", ["🧱"] = "ore", ["🔩"] = "rivet", ["📡"] = "compass", ["🐚"] = "crabshell",
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
	MeatOnBone = "meat_s", RoastShank = "meat_m", BigFeast = "meat_l", TangerineJuice = "grog_s", SeaGrog = "grog_m", CaptainsKeg = "grog_l", RepairKit = "repairkit", RefineGuard = "charm",
	CaptainsLog = "book", SeaEgg = "egg", GoldenEgg = "golden_egg", SeaBait = "bait", Wood = "wood", TreasureWood = "wood_gold",
	SailCloth = "cloth", SteelOre = "ore", TidecoreShard = "shard", PureTidecore = "shard_pure",
	TreasureMap = "map", WantedPoster = "poster", MarineBadge = "badge", CompassCharm = "charm",
	TangerinePin = "charm", SharkToothNecklace = "charm",
	-- v0.25.3: monster materials get their own pixel icons
	CrabShell = "crabshell", MonkeyFur = "monkeyfur", TigerPelt = "tigerpelt", BoarTusk = "boartusk", ClownPaint = "clownpaint",
	CatClaw = "catclaw", ArmorRivet = "rivet", SharkfolkFin = "sharkfin", IronIngot = "ingot", Gunpowder = "gunpowder",
	LeviathanScale = "scale", SeaCompass = "compass", SeastoneBracer = "charm", SeastoneShackle = "charm",
}
local WEAPON_ICON = { Sword = "sword", Knuckles = "knuckles", Slingshot = "slingshot", Shoes = "boots", StormBaton = "staff", MedKit = "medkit", Hammer = "hammer" }
local KIND_ICON = { Armor = "armor", Headgear = "hat", Accessory = "charm", Card = "card", Egg = "egg", Consumable = "potion", Material = "ore" }
function UI.ItemIconName(def)
	if not def then
		return nil
	end
	-- v0.25.36: worn pieces show themselves (tools/gen_acc_icons.py draws acc_<id> from Config/Accessories)
	if Icons["acc_" .. def.id] then
		return "acc_" .. def.id
	end
	if def.kind == "Card" and def.mtype and Icons["card_" .. def.mtype] then
		return "card_" .. def.mtype
	end
	-- v0.25.97: every weapon grade has its own pixel icon (tools/gen_pixel_icons.py WEAPON_GRADE_ICONS)
	local wIcon = def.weaponType and def.grade and ("w_" .. def.weaponType .. "_" .. def.grade)
	if wIcon and Icons[wIcon] then
		return wIcon
	end
	return ITEM_ICON[def.id]
		or (def.fruit and ("fruit_" .. string.lower(def.fruit)))
		or (def.weaponType and WEAPON_ICON[def.weaponType])
		or KIND_ICON[def.kind]
end
function UI.ItemIconId(def)
	local name = UI.ItemIconName(def)
	return name and Icons[name] or nil
end

-- v0.25.14 (owner: voxel item previews): the pixel icon extruded into blocks (Config/IconVoxels, made by
-- tools/gen_icon_voxels.py) in a ViewportFrame, turning slowly. icon = icon name or emoji. nil when there is no data.
local IconVoxels = require(ReplicatedStorage.Shared.Config.IconVoxels)
function UI.VoxelIcon(parent, icon, size, props)
	local data = IconVoxels[EMOJI_ICON[icon] or icon]
	if not data then
		return nil
	end
	local vp = New("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Ambient = Color3.fromRGB(110, 105, 135),
		LightColor = Color3.fromRGB(255, 248, 230), LightDirection = Vector3.new(0.6, -0.8, 0.7), Parent = parent })
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local m = Instance.new("Model")
	local cols = {}
	for i, hex in ipairs(data.pal) do
		cols[i] = Color3.fromHex(hex)
	end
	local ALPHA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&()*+,/:;<=>?@[]^_`{|}~"
	for y, row in ipairs(data.rows) do
		local x, i = 0, 1
		while i <= #row do
			local ch = string.sub(row, i, i)
			i += 1
			local j = i
			while j <= #row and string.find(string.sub(row, j, j), "%d") do
				j += 1
			end
			local n = j > i and tonumber(string.sub(row, i, j - 1)) or 1
			i = j
			if ch ~= "." then
				local c = cols[string.find(ALPHA, ch, 1, true)]
				New("Part", { Anchored = true, Size = Vector3.new(n, 1, 2), Color = c, Material = Enum.Material.SmoothPlastic,
					CFrame = CFrame.new(-(x + n / 2 - 16), 16 - (y - 0.5), 0), Parent = m })
			end
			x += n
		end
	end
	m.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -62), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	local yaw = math.rad(-20)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		yaw += dt * 0.8
		m:PivotTo(CFrame.Angles(0, math.sin(yaw) * 0.6, 0))
	end)
	return vp
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
	-- v0.25.28: an icon tile like the reference sheet: dark tile tinted by the color, a rim in that color, and a soft
	-- aura of the same color behind the icon (the "each item glows" look)
	local chip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(size, size), Parent = parent })
	UI.Corner(chip, math.floor(size * 0.3))
	UI.Gradient(chip, T.PanelTop:Lerp(color, 0.35), T.PanelDeep:Lerp(color, 0.15), 90)
	UI.Stroke(chip, T.Edge, 2.5)
	UI.Bevel(chip, UI.Shade(color, 0.3), 2, 0.15)
	local texOk, texCfg = pcall(require, ReplicatedStorage.Shared.Config.Textures)
	if texOk and texCfg.glow then
		New("ImageLabel", { Name = "Aura", BackgroundTransparency = 1, Image = texCfg.glow, ImageColor3 = UI.Shade(color, 0.35), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.25, 1.25), ZIndex = chip.ZIndex, Parent = chip })
	end
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

-- v0.25.94 (owner: Street Fist looked like a boxing glove; Brawlers fight bare-fisted): a clenched bare fist with
-- tape wraps, built from blocks (knuckles face -Z = the camera in ModelViewOf).
function UI.FistModel()
	local m = Instance.new("Model")
	local SKIN, WRAP, TAPE = Color3.fromRGB(232, 176, 128), Color3.fromRGB(244, 240, 228), Color3.fromRGB(206, 52, 52)
	local function b(sx, sy, sz, x, y, z, c)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CastShadow = true, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Size, p.CFrame, p.Color = Vector3.new(sx, sy, sz), CFrame.new(x, y, z), c
		p.Parent = m
	end
	b(1.0, 0.9, 0.9, 0, 0.05, 0.15, SKIN) -- back of the hand
	for i, x in ipairs({ -0.375, -0.125, 0.125, 0.375 }) do
		local c = i % 2 == 0 and SKIN or SKIN:Lerp(Color3.new(0, 0, 0), 0.08)
		b(0.24, 0.62, 0.34, x, -0.02, -0.4, c) -- curled fingers
		b(0.22, 0.16, 0.2, x, 0.3, -0.47, SKIN:Lerp(Color3.new(1, 1, 1), 0.12)) -- knuckle bumps
	end
	b(1.04, 0.16, 0.38, 0, 0.12, -0.42, WRAP) -- tape across the knuckles
	b(0.26, 0.32, 0.42, -0.52, -0.16, -0.22, SKIN) -- thumb base
	b(0.52, 0.22, 0.26, -0.16, -0.26, -0.62, SKIN) -- thumb across the fingers
	b(1.06, 0.3, 0.96, 0, 0.05, 0.22, WRAP) -- wrap around the palm
	b(0.8, 0.8, 0.5, 0, 0, 0.82, WRAP) -- wrist wrap
	b(0.84, 0.84, 0.09, 0, 0, 0.7, TAPE)
	b(0.84, 0.84, 0.09, 0, 0, 0.96, TAPE)
	b(0.68, 0.68, 0.3, 0, 0, 1.2, SKIN) -- forearm
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	return m
end

function UI.ModelView(parent, folder, key, size, spin, props)
	if folder == "Weapons" and key == "Knuckles" then
		return UI.ModelViewOf(parent, UI.FistModel(), size, spin, props)
	end
	if folder == "Weapons" and key == "Shoes" then
		return nil -- v0.25.97: Leg Style is bare legs (no boot mesh): callers fall back to the w_Shoes_<grade> voxel icon
	end
	local src = UI.ModelAsset(folder, key)
	if not src then
		return nil
	end
	return UI.ModelViewOf(parent, src:Clone(), size, spin, props)
end

-- v0.25.98 (owner: every grade looked the same): weapon previews = the grade's own voxel icon (w_<Type>_<Grade>),
-- the shared Wep_ mesh only when a weapon has no grade icon
function UI.WeaponView(parent, def, size, spin, props)
	local icon = def.weaponType and def.grade and ("w_" .. def.weaponType .. "_" .. def.grade)
	return (icon and UI.VoxelIcon(parent, icon, size, props))
		or (def.weaponType and UI.ModelView(parent, "Weapons", def.weaponType, size, spin, props))
end

-- v0.25.36: a worn accessory as 3D blocks on a plain stand (same blocks as on the character), spinning
function UI.AccessoryView(parent, id, size, props)
	local Accessory = require(ReplicatedStorage.Shared.Modules.Accessory)
	local VC = require(ReplicatedStorage.Shared.Modules.VoxelChar)
	if not Accessory.Has(id) then
		return nil
	end
	local m = Instance.new("Model")
	local used = {}
	local function block(sz, cf, color, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = sz
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = m
	end
	local function limbOf(limb)
		used[limb] = true
		if limb == "Head" then
			local r = VC.Rest.Head
			return CFrame.new(r[2] + Vector3.new(0, (VC.HEAD - r[1].Y) / 2, 0)), Vector3.new(VC.HEAD, VC.HEAD, VC.HEAD)
		end
		local r = VC.Rest[limb]
		return r and CFrame.new(r[2]), r and r[1]
	end
	Accessory.Build(id, limbOf, function(sz, cf, color, material)
		block(sz, cf, color, material)
	end)
	for limb in pairs(used) do
		local cf, sz = limbOf(limb)
		if cf then
			block(sz * 0.98, cf, limb == "Head" and Color3.fromRGB(222, 200, 178) or Color3.fromRGB(120, 126, 146))
		end
	end
	local cf = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position)
	return UI.ModelViewOf(parent, m, size, 0.8, props)
end

-- v0.25.90: a monster as players see it in the world: humanoid ones are voxel characters (Config/MonsterLooks, the
-- same look + accessories + held weapon ModelFactory.VoxelMonster builds on the server), others the Assets mesh.
function UI.MonsterModel(id)
	local MonsterLooks = require(ReplicatedStorage.Shared.Config.MonsterLooks)
	local look = MonsterLooks.Look(id or "")
	if not look then
		local src = UI.ModelAsset("Monsters", id or "")
		return src and src:Clone()
	end
	local VC = require(ReplicatedStorage.Shared.Modules.VoxelChar)
	local Accessory = require(ReplicatedStorage.Shared.Modules.Accessory)
	local race, variant = MonsterLooks.Race(id)
	local m = VC.Preview(look, race, variant)
	local function limbOf(limb)
		local r = VC.Rest[limb == "Head" and "Head" or limb]
		if not r then
			return nil
		end
		if limb == "Head" then
			return CFrame.new(r[2] + Vector3.new(0, (VC.HEAD - r[1].Y) / 2, 0)), Vector3.new(VC.HEAD, VC.HEAD, VC.HEAD)
		end
		return CFrame.new(r[2]), r[1]
	end
	local e = MonsterLooks.ById[id]
	local list = table.clone(e.acc or {})
	if e.held then
		table.insert(list, e.held)
	end
	for _, a in ipairs(list) do
		Accessory.Build(a, limbOf, function(sz, cf, color, material)
			New("Part", { Anchored = true, Size = sz, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = m })
		end)
	end
	m.WorldPivot = CFrame.new((m:GetBoundingBox()).Position)
	return m
end
function UI.MonsterView(parent, id, size, spin, props)
	local m = UI.MonsterModel(id)
	return m and UI.ModelViewOf(parent, m, size, spin, props)
end

function UI.ModelViewOf(parent, m, size, spin, props)
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

-- v0.25.13 (owner: windows looked flat): a layer of pixel particles inside `frame`: little squares that drift up
-- and fade, plus 4-point twinkle stars. opts: float (rise + wrap), z (ZIndex, default frame.ZIndex), star (0..1 share
-- of stars). One throttled RenderStepped per layer, disconnected when the frame goes away.
function UI.Sparkles(frame, color, n, opts)
	opts = opts or {}
	color = color or Color3.new(1, 1, 1)
	local z = opts.z or frame.ZIndex
	local holder = New("Frame", { Name = "Sparkles", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = z, Parent = frame })
	local parts = {}
	local rnd = Random.new()
	-- v0.25.29 (owner): themed particles: opts.icons = pixel icon names that float up among the sparks (coins in the
	-- Bag, paws in Pets, skulls for Bosses...), opts.iconFrac = share of them, opts.iconColor = optional tint,
	-- opts.plus = plus signs instead of stars, opts.bubble = hollow rising bubbles (sea), opts.color2 = second spark color
	local iconIds = {}
	for _, nm in ipairs(opts.icons or {}) do
		local id = UI.IconId(nm)
		if id then
			table.insert(iconIds, id)
		end
	end
	for i = 1, n do
		local isIcon = #iconIds > 0 and rnd:NextNumber() < (opts.iconFrac or 0.5)
		local star = not isIcon and rnd:NextNumber() < (opts.star or 0.35)
		local sz = isIcon and rnd:NextInteger(opts.iconMin or 12, opts.iconMax or 18) or (star and rnd:NextInteger(9, 16) or rnd:NextInteger(4, 7))
		local p = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rnd:NextNumber(), rnd:NextNumber()), Size = UDim2.fromOffset(sz, sz), ZIndex = z, Parent = holder })
		local bits = {}
		local c = (opts.color2 and rnd:NextNumber() < 0.5) and opts.color2 or color
		if isIcon then
			local img = New("ImageLabel", { BackgroundTransparency = 1, Image = iconIds[rnd:NextInteger(1, #iconIds)], ImageColor3 = opts.iconColor or Color3.new(1, 1, 1), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Rotation = rnd:NextInteger(-15, 15), ZIndex = z, Parent = p })
			table.insert(bits, img)
		elseif star and opts.plus then
			table.insert(bits, New("Frame", { BorderSizePixel = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 3, 1, 0), ZIndex = z, Parent = p }))
			table.insert(bits, New("Frame", { BorderSizePixel = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 3), ZIndex = z, Parent = p }))
		elseif opts.bubble and not star then
			local bub = New("Frame", { BackgroundColor3 = c, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = p })
			UI.Stroke(bub, c, 1.5)
			p.Size = UDim2.fromOffset(sz + 3, sz + 3)
			table.insert(bits, bub:FindFirstChildOfClass("UIStroke"))
		elseif star then
			table.insert(bits, New("Frame", { BorderSizePixel = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), ZIndex = z, Parent = p }))
			table.insert(bits, New("Frame", { BorderSizePixel = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), ZIndex = z, Parent = p }))
		else
			table.insert(bits, New("Frame", { BorderSizePixel = 0, BackgroundColor3 = c, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = p }))
		end
		parts[i] = { f = p, bits = bits, ph = rnd:NextNumber(0, 6.28), sp = rnd:NextNumber(1.2, 3), vy = opts.float and rnd:NextNumber(0.015, 0.05) or 0, max = rnd:NextNumber(0.5, 0.95) }
	end
	local acc, t = 0, 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		acc += dt
		if acc < 1 / 30 then
			return
		end
		t += acc
		local step = acc
		acc = 0
		for _, q in ipairs(parts) do
			local tw = (math.sin(t * q.sp + q.ph) + 1) / 2
			for _, b in ipairs(q.bits) do
				if b:IsA("ImageLabel") then
					b.ImageTransparency = 1 - tw * q.max
				elseif b:IsA("UIStroke") then
					b.Transparency = 1 - tw * q.max
				else
					b.BackgroundTransparency = 1 - tw * q.max
				end
			end
			if q.vy > 0 then
				local pos = q.f.Position
				local y = pos.Y.Scale - q.vy * step
				if y < -0.05 then
					q.f.Position = UDim2.fromScale(rnd:NextNumber(), 1.05)
				else
					q.f.Position = UDim2.fromScale(pos.X.Scale, y)
				end
			end
		end
	end)
	return holder
end

-- v0.25.12 (owner): voxel eggs (Sea Egg / Golden Egg) built from blocks in a ViewportFrame, slowly turning.
-- Returns the frame and setTilt(radians) for hatch wobbles.
local EGG_LOOK = {
	SeaEgg = { base = Color3.fromRGB(245, 236, 212), spot = Color3.fromRGB(70, 170, 230), shine = Color3.fromRGB(255, 255, 255) },
	GoldenEgg = { base = Color3.fromRGB(255, 188, 50), spot = Color3.fromRGB(255, 240, 160), shine = Color3.fromRGB(255, 255, 220), sparkle = true,
		band = Color3.fromRGB(196, 112, 30), jewels = { Color3.fromRGB(255, 70, 90), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 255, 140) } },
}
function UI.VoxelEgg(parent, eggId, size, props)
	local look = EGG_LOOK[eggId] or EGG_LOOK.SeaEgg
	-- v0.25.13 (owner: "flat, only colors"): low ambient + strong key light so faces shade, per-block tone jitter,
	-- a bright highlight patch top-left, darker belly, neon glints on the golden egg; only surface blocks are built
	local vp = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Ambient = Color3.fromRGB(95, 90, 120),
		LightColor = Color3.fromRGB(255, 245, 225),
		LightDirection = Vector3.new(0.7, -0.9, 0.6),
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local m = Instance.new("Model")
	local R, H = 5, 13 -- grid: 10 wide, 13 tall
	local function inside(x, y, z)
		if x < 0 or z < 0 or y < 0 or x >= 2 * R or z >= 2 * R or y >= H then
			return false
		end
		local t = (y + 0.5) / H * 2 - 1 -- -1 bottom .. 1 top
		local r = R * math.sqrt(math.max(0, 1 - t * t)) * (1 - 0.16 * t) + 0.35
		local dx, dz = x + 0.5 - R, z + 0.5 - R
		return dx * dx + dz * dz <= r * r
	end
	local function hash(x, y, z, k)
		local h = math.sin(x * 12.9898 + y * 78.233 + z * 37.719 + k) * 43758.5453
		return h - math.floor(h)
	end
	local function colorAt(x, y, z)
		-- spots are 2x2x2 blobs; the golden egg gets a darker band set with neon jewels
		if look.band and (y == 5 or y == 6) then
			if y == 5 and (x + z) % 4 == 0 then
				return look.jewels[(x + z) % 3 + 1], true
			end
			return look.band, false
		end
		local c = hash(math.floor(x / 2), math.floor(y / 2), math.floor(z / 2), 0) > 0.72 and look.spot or look.base
		local shade = 0.78 + 0.3 * (y / H) + (hash(x, y, z, 7) - 0.5) * 0.12
		-- highlight patch on the upper front-left
		if y >= H * 0.62 and y <= H * 0.85 and x >= R + 1 and z <= 2 then
			return c:Lerp(look.shine, 0.55), false
		end
		if look.sparkle and hash(x, y, z, 3) > 0.93 then
			return look.shine, true
		end
		return Color3.new(math.min(1, c.R * shade), math.min(1, c.G * shade), math.min(1, c.B * shade)), false
	end
	for y = 0, H - 1 do
		for z = 0, 2 * R - 1 do
			for x = 0, 2 * R - 1 do
				local surface = inside(x, y, z) and not (inside(x + 1, y, z) and inside(x - 1, y, z) and inside(x, y + 1, z)
					and inside(x, y - 1, z) and inside(x, y, z + 1) and inside(x, y, z - 1))
				if surface then
					local c, glint = colorAt(x, y, z)
					New("Part", { Anchored = true, Size = Vector3.new(1.01, 1.01, 1.01), Color = c,
						Material = glint and Enum.Material.Neon or Enum.Material.SmoothPlastic, CFrame = CFrame.new(x + 0.5 - R, y - H / 2 + 0.5, z + 0.5 - R), Parent = m })
				end
			end
		end
	end
	-- twinkling pixel sparkles over the egg
	UI.Sparkles(vp, look.shine, 7, { star = 0.7 })
	m.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 2, -H * 0.62 / math.tan(math.rad(15))), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	local yaw, tilt = 0, 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		yaw += dt * 0.7
		m:PivotTo(CFrame.new(0, -H / 2, 0) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, H / 2, 0) * CFrame.Angles(0, yaw, 0))
	end)
	return vp, function(a)
		tilt = a
	end
end

-- Your own character in a ViewportFrame (Bag / Stats): a still copy of the avatar holding the weapon you have equipped
-- (weaponType -> Assets.Weapons model in the right hand). Drag left/right to turn it. Returns the frame and refresh(weaponType).
-- opts (v0.25.39, Job Master): zoom = mouse wheel zooms; water = a true mirror reflection under the feet + ripple
-- rings, lit in the color passed to refresh(weaponType, tint); shiftX = put the statue that far left (-) / right (+)
-- of the viewport's center (fraction of its width); onFrame(horizon) = the water line, fraction of the height
function UI.CharacterView(parent, props, opts)
	opts = opts or {}
	local vp = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(175, 175, 195),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.5, -0.8, -1),
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local world = New("WorldModel", { Parent = vp })
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	cam.Parent = vp
	vp.CurrentCamera = cam
	local yaw = math.rad(-18) -- face the camera (it sits on the -Z side), turned a little for a 3/4 look
	local model, mirror, mirrorPairs, feetY
	local zoom, frameCF, frameExt = opts.zoomStart or 1, nil, nil
	local function frameCam()
		if not frameCF then
			return
		end
		local tan = math.tan(math.rad(13))
		local dist = frameExt.Y * 0.62 / tan * zoom
		local aspect = 1.8
		pcall(function()
			aspect = vp.AbsoluteSize.X / math.max(1, vp.AbsoluteSize.Y)
		end)
		-- the camera looks along +Z, so screen right is world -X: shifting the aim right moves the statue left
		-- shiftY (> 0) lifts the statue: aim lower by that share of the view height
		local side = Vector3.new((opts.shiftX or 0) * 2 * dist * tan * aspect, -(opts.shiftY or 0) * 2 * dist * tan, 0)
		local target = frameCF.Position + side
		cam.CFrame = CFrame.lookAt(target + Vector3.new(0, frameExt.Y * 0.04, -dist), target)
		if opts.onFrame then
			-- the horizon of a flat sea sits at eye height: a little above the middle (the camera looks slightly down)
			opts.onFrame(0.5 - (frameExt.Y * 0.04 / dist) / (2 * tan))
		end
	end
	-- a true mirror image (v0.25.40, owner: the flipped copy swapped left and right): every block reflected on its own
	-- across the water plane, rotation S*R*S with S = diag(1, -1, 1)
	local function reflect(cf)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		return CFrame.new(x, 2 * feetY - y, z, r00, -r01, r02, -r10, r11, -r12, r20, -r21, r22)
	end
	local function place()
		if model then
			model:PivotTo(CFrame.Angles(0, yaw, 0))
		end
		if mirrorPairs and feetY then
			for _, pr in ipairs(mirrorPairs) do
				pr[2].CFrame = reflect(pr[1].CFrame)
			end
		end
	end
	local lastType, watched, watchConns = nil, nil, {}
	local refresh
	-- v0.25.36 (owner: equip showed only after reopening the Bag): re-copy the statue as soon as worn pieces or the
	-- held fruit change on the real character
	local function watch(char)
		if watched == char then
			return
		end
		for _, c in ipairs(watchConns) do
			c:Disconnect()
		end
		watchConns, watched = {}, char
		local pending = false
		local function changed(child)
			if child:IsA("Model") and (child:GetAttribute("GVOutfit") or child.Name == "HeldFruit") and not pending and vp.Parent then
				pending = true
				task.delay(0.1, function()
					pending = false
					if vp.Parent then
						refresh(lastType)
					end
				end)
			end
		end
		table.insert(watchConns, char.ChildAdded:Connect(changed))
		table.insert(watchConns, char.ChildRemoved:Connect(changed))
	end
	pcall(function()
		vp.Destroying:Connect(function()
			for _, c in ipairs(watchConns) do
				c:Disconnect()
			end
		end)
	end)
	local lastTint = opts.tint
	refresh = function(weaponType, tint)
		lastType = weaponType
		tint = tint or lastTint
		lastTint = tint
		if player.Character then
			pcall(watch, player.Character)
		end
		if model then
			model:Destroy()
			model = nil
		end
		local char = player.Character
		if not char then
			return
		end
		local was = char.Archivable
		char.Archivable = true
		local ok, copy = pcall(function()
			return char:Clone()
		end)
		char.Archivable = was
		if not ok or not copy then
			return
		end
		-- a still statue: no scripts, no physics, no live weapon models (we add the equipped one below)
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or (d:IsA("Model") and d:GetAttribute("GVWeapon")) then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local hum = copy:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local root = copy:FindFirstChild("HumanoidRootPart")
		copy:PivotTo(CFrame.new())
		if root then
			copy.PrimaryPart = root
		end
		-- framed on the body alone (v0.25.39: weapons stick out differently, every class stood at another size)
		frameCF, frameExt = copy:GetBoundingBox()
		feetY = frameCF.Position.Y - frameExt.Y / 2
		-- the statue holds its weapon the way WeaponService draws it in a fight
		local A = CFrame.Angles
		local HOLD = {
			Sword = { { "RightHand", CFrame.new(0, -0.15, 0) * A(math.rad(-35), 0, 0) } },
			Slingshot = { { "LeftHand", CFrame.new(0, -0.15, 0) } },
			MedKit = { { "RightHand", CFrame.new(0, -0.45, -0.1) } },
			Knuckles = {}, -- bare fists / bare legs
			Shoes = {},
			Fists = {},
		}
		local tpl = weaponType and UI.ModelAsset("Weapons", weaponType)
		for _, h in ipairs(tpl and (HOLD[weaponType] or { { "RightHand", CFrame.new(0, -0.15, 0) } }) or {}) do
			local limb = copy:FindFirstChild(h[1])
			if limb then
				local w = tpl:Clone()
				w:PivotTo(limb.CFrame * h[2])
				w.Parent = copy
			end
		end
		copy.Parent = world
		model = copy
		if mirror then
			mirror:Destroy()
			mirror = nil
		end
		local oldWater = world:FindFirstChild("GVWater")
		if oldWater then
			oldWater:Destroy()
		end
		if opts.water then
			local c = tint or Color3.fromRGB(150, 120, 230)
			-- opts.plainLight (v0.25.68, Bag / Stats): the character keeps its own colors, only the water shows the tint
			if not opts.plainLight then
				vp.LightColor = c:Lerp(Color3.new(1, 1, 1), 0.45)
				vp.Ambient = c:Lerp(Color3.fromRGB(180, 180, 200), 0.55)
			end
			mirror = copy:Clone()
			mirrorPairs = {}
			local src, dst = copy:GetDescendants(), mirror:GetDescendants() -- a clone keeps the same order
			for i, d in ipairs(dst) do
				if d:IsA("BasePart") then
					d.Transparency = 1 - (1 - d.Transparency) * 0.42
					d.Color = d.Color:Lerp(c, 0.4)
					table.insert(mirrorPairs, { src[i], d })
				elseif d:IsA("Decal") then
					d.Transparency = 1 - (1 - d.Transparency) * 0.42
				end
			end
			mirror.Parent = world
			local water = Instance.new("Model")
			water.Name = "GVWater"
			-- ripples where the feet touch the water: rings of small white blocks (v0.25.41: a cylinder is a solid disc
			-- that washed the legs white). The water itself is drawn by the window behind the viewport.
			local RING_N = 22
			for i = 1, 2 do
				local ring = Instance.new("Model")
				ring.Name = "Ripple"
				ring:SetAttribute("Phase", (i - 1) * 0.5)
				for _ = 1, RING_N do
					local b = Instance.new("Part")
					b.Anchored = true
					b.Size = Vector3.new(0.35, 0.05, 0.35)
					b.Color = Color3.new(1, 1, 1)
					b.Material = Enum.Material.SmoothPlastic
					b.Parent = ring
				end
				ring.Parent = water
			end
			water.Parent = world
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not water.Parent then
					conn:Disconnect()
					return
				end
				for _, r in ipairs(water:GetChildren()) do
					local k = (os.clock() * 0.45 + r:GetAttribute("Phase")) % 1
					local rad = 1.2 + k * 3.2
					local blocks = r:GetChildren()
					for j, b in ipairs(blocks) do
						local a = j / #blocks * math.pi * 2
						b.CFrame = CFrame.new(math.cos(a) * rad, feetY + 0.02, math.sin(a) * rad) * CFrame.Angles(0, -a, 0)
						b.Transparency = 0.3 + k * 0.7
					end
				end
			end)
		else
			mirrorPairs = nil
		end
		frameCam()
		place()
	end
	pcall(function()
		vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCam)
	end)
	if opts.zoom then
		pcall(function()
			vp.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseWheel then
					zoom = math.clamp(zoom * (input.Position.Z > 0 and 0.9 or 1.1), 0.45, (opts.zoomStart or 1) * 1.4)
					frameCam()
				end
			end)
		end)
	end
	-- drag to turn: press on the statue, then follow the pointer anywhere (works with touch too; the viewport is
	-- Active so a drag does not also spin the camera). pcall: the headless UI harness has no input events.
	vp.Active = true
	local dragging, lastX = false, 0
	pcall(function()
		vp.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, lastX = true, input.Position.X
			end
		end)
		local c1 = UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				yaw += (input.Position.X - lastX) * 0.012
				lastX = input.Position.X
				place()
			end
		end)
		local c2 = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		vp.Destroying:Connect(function()
			c1:Disconnect()
			c2:Disconnect()
		end)
	end)
	return vp, refresh
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
		-- v0.25.99 (labels were ~6 px on screen): bigger text; the pixel font is square, so a label is #text x size wide
		local tsz = math.max(9, math.floor(height * 0.42))
		local w = (t[2] ~= "" and 42 or 20) + utf8.len(t[3]) * tsz -- icon 30 + padding 8 + slack
		local btn, holder = UI.Button(bar, t[2] ~= "" and (t[2] .. " " .. t[3]) or t[3], on and (t[4] or T.Orange) or T.Grey, UDim2.fromOffset(w, height), function()
			onPick(t[1])
		end)
		holder.LayoutOrder = i
		btn.TextScaled = false
		btn.TextSize = tsz -- (pixel font: PixelUI.TEXT_SCALE, set after PixelUI ran)
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

-- v0.25.29 (owner): menu tiles (HUD column + MENU window) wear their entry's own colors and particle theme:
-- it.bg = { top, bottom } gradient, it.fx = Sparkles options (+ color), it.stripes = pennant stripes (Guild)
function UI.DressMenuTile(tile, it, count)
	local fill = tile:FindFirstChild("Fill") or tile:FindFirstChildOfClass("UIGradient")
	if it.bg and fill then
		fill.Color = ColorSequence.new(it.bg[1], it.bg[2])
	end
	if it.stripes then
		for k = 0, 1 do
			New("Frame", { Name = "Pennant", BackgroundColor3 = it.stripes, BackgroundTransparency = 0.35, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.82 - k * 0.12, 0, 0.5, 0), Size = UDim2.new(0, 5, 1.6, 0), Rotation = 24, ZIndex = tile.ZIndex, Parent = tile })
		end
		tile.ClipsDescendants = true
	end
	local fx = it.fx or {}
	local opts = { float = true, star = fx.star or 0.45, icons = fx.icons, iconFrac = fx.iconFrac, iconColor = fx.iconColor, plus = fx.plus, bubble = fx.bubble, color2 = fx.color2, iconMin = fx.iconMin, iconMax = fx.iconMax }
	if fx.faction then
		local f = player:GetAttribute("Faction")
		opts.iconColor = f == "Marine" and T.Marine or (f == "Pirate" and T.Pirate or Color3.fromRGB(230, 230, 240))
	end
	return UI.Sparkles(tile, fx.color or Color3.new(1, 1, 1), count or 8, opts)
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
	-- v0.25.2 (owner, phone): Roblox's jump button / thumbstick drew on top of open windows; windows are modal, so
	-- the touch controls hide while one is open
	local touch = gui.Parent and gui.Parent:FindFirstChild("TouchGui")
	if touch and touch:IsA("ScreenGui") then
		touch.Enabled = openCount == 0
	end
	-- v0.25.6 (owner): the in-game MENU button sat on top of window titles: gameplay only
	local menuGui = gui.Parent and gui.Parent:FindFirstChild("MenuButton")
	local menuBtn = menuGui and menuGui:FindFirstChildWhichIsA("GuiObject")
	if menuBtn then
		menuBtn.Visible = openCount == 0
	end
	Tween(dim, 0.2, { BackgroundTransparency = openCount > 0 and 0.55 or 1 })
	Tween(blur, 0.25, { Size = openCount > 0 and 10 or 0 })
end
-- the dim backdrop only blocks clicks: windows close with their red X (or Esc), never by a stray click (owner request)

-- windows that can fill the screen (opts.fullscreen): they open full screen and a button next to the X shrinks them
-- back to a normal window (and back); the choice is remembered per window for this session
UI.FullPref = {}
-- a window never sticks out of the screen: offsets are capped to the visible canvas (small screens / Studio panes)
function UI.FitSize(size)
	local okSize, vp = pcall(function()
		return gui.AbsoluteSize
	end)
	if not okSize or not vp or vp.X < 10 then
		return size -- (headless UI harness: no layout sizes)
	end
	local sc = math.max(0.01, rootScale.Scale)
	local inset = 0
	pcall(function()
		inset = game:GetService("GuiService").TopbarInset.Max.Y
	end)
	local maxW, maxH = vp.X / sc - 40, (vp.Y - inset) / sc - 40
	return UDim2.new(size.X.Scale, math.min(size.X.Offset, maxW), size.Y.Scale, math.min(size.Y.Offset, maxH))
end
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
		Size = UI.FitSize(size or UDim2.fromOffset(560, 520)),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Parent = gui,
	})
	UI.Corner(frame, 20)
	New("UIGradient", { Color = ColorSequence.new(T.Panel:Lerp(Color3.new(1, 1, 1), 0.04), T.PanelDeep), Rotation = 90, Parent = frame })
	UI.Stroke(frame, T.Edge, 4)
	-- v0.25.28 pixel-RPG frame: dark edge (stroke) + light bevel ring + a second ring in the window's color, gold
	-- rivets in the corners, and the title on a plaque sitting on the top border (reference: "INVENTORY" panel)
	local rim = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = frame, ZIndex = 20 })
	UI.Corner(rim, 18)
	UI.Stroke(rim, T.Bevel, 2).Transparency = 0.1
	local rim2 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromOffset(7, 7), Parent = rim, ZIndex = 20 })
	UI.Stroke(rim2, color:Lerp(T.PanelDeep, 0.35), 1.5).Transparency = 0.25
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local rv = New("Frame", { BackgroundColor3 = T.Trim, BorderSizePixel = 0, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.new(c[1], c[1] == 0 and 3 or -3, c[2], c[2] == 0 and 3 or -3), Size = UDim2.fromOffset(8, 8), ZIndex = 21, Parent = rim })
		UI.Stroke(rv, T.Edge, 1.5)
		New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 3), Position = UDim2.fromOffset(1, 1), ZIndex = 22, Parent = rv })
	end
	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame, ZIndex = 21 })
	local tab = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 22, Parent = header })
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop:Lerp(color, 0.25), T.PanelDeep), Rotation = 90, Parent = tab })
	UI.Stroke(tab, T.Edge, 3)
	UI.Bevel(tab, T.Trim, 2, 0.15)
	New("UIPadding", { PaddingLeft = UDim.new(0, icon and 56 or 22), PaddingRight = UDim.new(0, 22), Parent = tab })
	-- a strip of the window's color under the plaque title
	New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 3), ZIndex = 23, Parent = tab })
	local titleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Text = string.upper(title),
		FontFace = F.Display,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 23,
		Parent = tab,
	})
	UI.Stroke(titleLabel, T.Edge, 3, Enum.ApplyStrokeMode.Contextual)
	New("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 226, 150)), Rotation = 90, Parent = titleLabel })
	if icon then
		local chip = UI.IconChip(tab, icon, color:Lerp(T.Gold, 0.25), 46)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, -50, 0.5, 0)
		chip.ZIndex = 25
		for _, d in ipairs(chip:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 26
			end
		end
	end
	tab.ClipsDescendants = false
	-- X (and the full-screen button) live in one holder: we move the holder, never the buttons, because the hover
	-- "jump" (UI.Tactile) remembers a button's position and used to snap it back to its old place
	local ctrl = New("Frame", { Name = "WindowButtons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 12, 0, -12), Size = UDim2.fromOffset(opts.fullscreen and 100 or 46, 46), ZIndex = 24, Parent = header })
	local close = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
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
		Parent = ctrl,
	})
	UI.Corner(close, 8)
	UI.Stroke(close, T.Edge, 3)
	UI.Bevel(close, Color3.fromRGB(255, 170, 170), 2, 0.2)
	UI.Tactile(close)
	-- v0.25.13 (owner: flat backgrounds): soft colored glows in two corners + floating pixel sparkles
	local texCfg = require(ReplicatedStorage.Shared.Config.Textures)
	local glowClip = New("Frame", { Name = "BgGlow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 20, Parent = frame })
	for _, g in ipairs({ { Vector2.new(1, 0), UDim2.new(1, 60, 0, -60), color }, { Vector2.new(0, 1), UDim2.new(0, -80, 1, 80), T.Gold } }) do
		New("ImageLabel", { BackgroundTransparency = 1, Image = texCfg.glow, ImageColor3 = g[3], ImageTransparency = 0.82, AnchorPoint = g[1], Position = g[2],
			Size = UDim2.fromScale(0.75, 0.75), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 20, Parent = glowClip })
	end
	UI.Sparkles(frame, color:Lerp(Color3.new(1, 1, 1), 0.6), 30, { float = true, z = 20, star = 0.4 })
	UI.Sparkles(frame, T.Gold:Lerp(Color3.new(1, 1, 1), 0.4), 14, { float = true, z = 20, star = 0.6 })
	local body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 1, -60), Parent = frame, ZIndex = 21 })
	-- v0.25.36 (owner: full screen looked tiny): in full screen the body keeps the framed window's layout and is
	-- scaled up to fill the screen (fonts, tiles, buttons grow together)
	local bodyScale = New("UIScale", { Scale = 1, Parent = body })
	local win = { frame = frame, body = body, id = id, header = header, resized = Instance.new("BindableEvent") }
	local windowSize = size or UDim2.fromOffset(560, 520)
	local restPos = UDim2.fromScale(0.5, 0.53)
	if opts.fullscreen then
		if UI.FullPref[id] == nil then
			UI.FullPref[id] = true
		end
		local maxBtn = New("TextButton", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = T.Gold,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 24,
			Parent = ctrl,
		})
		UI.Corner(maxBtn, 8)
		UI.Stroke(maxBtn, T.Edge, 3)
		UI.Tactile(maxBtn)
		-- drawn icon: one big square = "make it full screen", two stacked squares = "back to a window"
		local big = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 18), BackgroundTransparency = 1, ZIndex = 25, Parent = maxBtn })
		UI.Stroke(big, T.Edge, 3)
		local back = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 4, 0.5, -4), Size = UDim2.fromOffset(16, 13), BackgroundTransparency = 1, ZIndex = 25, Parent = maxBtn })
		UI.Stroke(back, T.Edge, 3)
		-- full screen (like big games' codex/menus): the window covers the whole screen edge to edge, the big title tab
		-- turns into a slim title bar, X and this button sit in the top-right corner; shrunk, it is a framed window again
		local frameCorner = frame:FindFirstChildOfClass("UICorner")
		local frameStroke = frame:FindFirstChildOfClass("UIStroke")
		local slim = New("Frame", { Name = "SlimBar", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56), Visible = false, ZIndex = 20, Parent = frame })
		New("UIGradient", { Color = ColorSequence.new(color:Lerp(T.PanelDeep, 0.35), T.PanelDeep), Rotation = 0, Parent = slim })
		local slimTitle = UI.Text(slim, string.upper(title), 26, Color3.new(1, 1, 1), "Display", { Position = UDim2.fromOffset(200, 0), Size = UDim2.new(1, -330, 1, 0), TextWrapped = false, ZIndex = 22 })
		if icon then
			local sc2 = UI.IconChip(slim, icon, color:Lerp(T.Gold, 0.35), 40)
			sc2.AnchorPoint = Vector2.new(0, 0.5)
			sc2.Position = UDim2.new(0, 152, 0.5, 0)
			win.slimChip = sc2
			for _, d in ipairs(sc2:GetDescendants()) do
				if d:IsA("GuiObject") then
					d.ZIndex = 23
				end
			end
			sc2.ZIndex = 23
		end
		local function apply(animate)
			local full = UI.FullPref[id]
			local inset = 0
			pcall(function()
				inset = game:GetService("GuiService").TopbarInset.Max.Y / math.max(0.01, rootScale.Scale)
			end)
			local top = math.max(inset, 44) + 12
			local target = full and UDim2.fromScale(1, 1) or windowSize
			restPos = full and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 0.53)
			win.full = full
			-- chrome
			slim.Size = UDim2.new(1, 0, 0, top)
			slim.Visible = full
			tab.Visible = not full
			rim.Visible = not full
			if frameCorner then
				frameCorner.CornerRadius = UDim.new(0, full and 0 or 20)
			end
			if frameStroke then
				frameStroke.Enabled = not full
			end
			ctrl.Position = full and UDim2.new(1, -12, 0, (top - 46) / 2) or UDim2.new(1, 12, 0, -12)
			-- the slim title starts right after Roblox's own top-left buttons (they are bigger on small screens)
			local left = 150
			pcall(function()
				left = game:GetService("GuiService").TopbarInset.Min.X / math.max(0.01, rootScale.Scale) + 14
			end)
			left = math.max(left, 60)
			if win.slimChip then
				win.slimChip.Position = UDim2.new(0, left, 0.5, 0)
			end
			slimTitle.Position = UDim2.fromOffset(left + (win.slimChip and 50 or 0), 0)
			slimTitle.Size = UDim2.new(1, -(left + 180), 1, 0)
			target = full and target or UI.FitSize(windowSize)
			body.Position = full and UDim2.fromOffset(20, top + 10) or UDim2.fromOffset(16, 46)
			local k = 1
			if full then
				pcall(function()
					local vs = workspace.CurrentCamera.ViewportSize / math.max(0.01, rootScale.Scale)
					local design = UI.FitSize(windowSize)
					k = math.clamp(math.min((vs.X - 40) / math.max(1, design.X.Offset - 32), (vs.Y - top - 22) / math.max(1, design.Y.Offset - 60)), 1, 1.6)
				end)
			end
			bodyScale.Scale = k
			body.Size = full and UDim2.new(1 / k, -40 / k, 1 / k, -(top + 22) / k) or UDim2.new(1, -32, 1, -60)
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

function UI.AnyOpen()
	return next(openWindows) ~= nil
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
		if tier.rainbow or tier.prismatic then
			tg.Color = tier.prismatic and PRISM or RAINBOW
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
-- v0.25.2 (owner): server-wide news (boss up, fruit spawned, rare rolls...) goes into the chat as a colored
-- system line instead of the banner at the top (it covered the compass and the target's HP bar). The banner is
-- only the fallback when the new chat is not available.
function UI.Announce(text, rarityId)
	local ok = pcall(function()
		local channels = game:GetService("TextChatService"):FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		assert(general, "no chat channel")
		local tier = rarityId and Rarity.Get(rarityId)
		local clean = tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		general:DisplaySystemMessage(UI.Colored("📢 " .. clean, tier and tier.color or T.Gold))
	end)
	if ok then
		return
	end
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
	-- v0.25.28: pixel switch (green track + cream knob when on, slate when off)
	local ON, OFF = Color3.fromRGB(96, 196, 86), T.Grey
	local track = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(56, 28), BackgroundColor3 = value and ON or OFF, Parent = row })
	UI.Corner(track, 14)
	UI.Stroke(track, T.Edge, 2)
	New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Parent = track })
	local knob = New("Frame", { Size = UDim2.fromOffset(22, 22), Position = value and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(246, 234, 204), Parent = track })
	UI.Corner(knob, 11)
	UI.Stroke(knob, T.Edge, 2)
	UI.Tactile(row)
	row.Activated:Connect(function()
		value = not value
		Audio.Play("BlkToggle", { pitch = value and 1.1 or 0.9 })
		Tween(knob, 0.15, { Position = value and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
		Tween(track, 0.15, { BackgroundColor3 = value and ON or OFF })
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
-- ===== Combo / style meter =====
-- Every hit you land fills a style meter: ranks D C B A S SS SSS (each a full bar). It bounces on every hit, drains
-- when you stop hitting (faster at high ranks), and catches fire from S up. Shows the hit count and the total damage
-- of the current streak; the streak ends when the meter runs dry.
local RANKS = {
	{ "D", "DULL", Color3.fromRGB(170, 180, 200) },
	{ "C", "COOL", Color3.fromRGB(110, 210, 255) },
	{ "B", "BRAVO", Color3.fromRGB(120, 235, 140) },
	{ "A", "AWESOME", Color3.fromRGB(255, 214, 70) },
	{ "S", "STYLISH", Color3.fromRGB(255, 140, 50) },
	{ "SS", "SAVAGE", Color3.fromRGB(255, 70, 80) },
	{ "SSS", "SENSATIONAL", Color3.fromRGB(255, 90, 220) },
}
local PER_RANK = 100
local combo = { points = 0, hits = 0, total = 0, last = 0, rank = 0 }
-- Layout (owner, v0.21): middle-right of the screen, a VERTICAL tube that the hits push upward. The fill springs
-- (overshoots and wobbles), a glowing head rides the top of the liquid, bubbles rise inside, and the rank letter rides
-- next to the fill level. Rank-up = the tube flashes white, bursts and refills from the bottom.
local TEX = {}
pcall(function()
	TEX = require(ReplicatedStorage.Shared.Config.Textures)
end)
local BAR_H, BAR_W = 250, 26
local comboFrame = New("Frame", { Name = "StyleMeter", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -22, 0.47, 0), Size = UDim2.fromOffset(190, 300), BackgroundTransparency = 1, Visible = false, Parent = gui })
local comboScale = New("UIScale", { Parent = comboFrame })
local comboBase = 1
-- HUD.Layout places the meter next to the menu column (and shrinks it on phones)
function UI.PlaceStyleMeter(pos, scale)
	comboFrame.Position = pos
	comboBase = scale or 1
	comboScale.Scale = comboBase
end
local flames = New("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.85), Position = UDim2.fromOffset(70, 150), Size = UDim2.fromOffset(150, 150), ImageTransparency = 1, Image = TEX.flame or "", ZIndex = 1, Parent = comboFrame })
-- the tube (right side), fill grows from the bottom
local comboBar = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 160, 0, 20 + BAR_H), Size = UDim2.fromOffset(BAR_W, BAR_H), BackgroundColor3 = T.PanelDeep, ClipsDescendants = true, ZIndex = 2, Parent = comboFrame })
UI.Corner(comboBar, 13)
local barStroke = UI.Stroke(comboBar, T.Edge, 3)
local comboFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = comboBar })
UI.Corner(comboFill, 13)
local fillGrad = New("UIGradient", { Rotation = 90, Parent = comboFill })
-- glossy stripe down the tube
local gloss = New("Frame", { Position = UDim2.new(0, 5, 0, 6), Size = UDim2.new(0, 5, 1, -12), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 5, Parent = comboBar })
UI.Corner(gloss, 3)
local barFlash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = comboBar })
UI.Corner(barFlash, 13)
-- tick marks every quarter
for i = 1, 3 do
	New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, i / 4, 0), Size = UDim2.new(0.35, 0, 0, 2), BackgroundColor3 = T.Edge, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 4, Parent = comboBar })
end
-- the glowing head that rides the liquid (outside the clip so it can bloom past the tube)
local head = New("ImageLabel", { BackgroundTransparency = 1, Image = TEX.glow or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(160, 20 + BAR_H), Size = UDim2.fromOffset(70, 40), ImageTransparency = 0.3, ZIndex = 4, Parent = comboFrame })
local barScale = New("UIScale", { Parent = comboBar })
-- rank letter + name ride beside the fill level; hits and total sit at the bottom
local letter = UI.Text(comboFrame, "D", 78, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(70, 150), Size = UDim2.fromOffset(140, 90), TextXAlignment = Enum.TextXAlignment.Center, Rotation = -8, ZIndex = 3, TextWrapped = false })
local letterScale = New("UIScale", { Parent = letter })
-- v0.24.6 (owner): just the letter (no rank word); HITS sits right under its number; TOTAL DMG shares the color of its
-- number, which heats up from gold to orange to red (and a hot crimson past 5,000) as the damage grows
local rankName = UI.Text(comboFrame, "", 16, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(70, 192), Size = UDim2.fromOffset(150, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Visible = false })
local hitsText = UI.Text(comboFrame, "0", 34, Color3.new(1, 1, 1), "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(136, 222), Size = UDim2.fromOffset(120, 34), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, TextWrapped = false })
local hitsScale = New("UIScale", { Parent = hitsText })
UI.Text(comboFrame, "HITS", 12, T.TextSoft, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(136, 256), Size = UDim2.fromOffset(120, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
local totalText = UI.Text(comboFrame, "0", 20, T.Gold, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(136, 276), Size = UDim2.fromOffset(120, 22), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, TextWrapped = false })
local totalLabel = UI.Text(comboFrame, "TOTAL DMG", 11, T.Gold, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(136, 299), Size = UDim2.fromOffset(120, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
local function damageHeat(total)
	local stops = {
		{ 0, Color3.fromRGB(255, 226, 120) },
		{ 1000, Color3.fromRGB(255, 150, 50) },
		{ 2500, Color3.fromRGB(255, 60, 50) },
		{ 5000, Color3.fromRGB(220, 20, 70) },
		{ 10000, Color3.fromRGB(255, 40, 160) },
	}
	for i = 2, #stops do
		if total <= stops[i][1] then
			local a, b = stops[i - 1], stops[i]
			return a[2]:Lerp(b[2], (total - a[1]) / (b[1] - a[1]))
		end
	end
	return stops[#stops][2]
end

local fillShown, fillVel = 0, 0 -- spring state of the liquid (0..1 of the current rank)
local letterY = 150

local function rankOf(points)
	return math.clamp(math.floor(points / PER_RANK) + 1, 1, #RANKS)
end

local function paint(rank)
	local r = RANKS[rank]
	letter.Text = r[1]
	letter.TextColor3 = r[3]
	rankName.Text = r[2]
	rankName.TextColor3 = r[3]:Lerp(Color3.new(1, 1, 1), 0.3)
	fillGrad.Color = ColorSequence.new(r[3]:Lerp(Color3.new(1, 1, 1), 0.5), r[3]:Lerp(Color3.new(0, 0, 0), 0.15))
	barStroke.Color = rank >= 4 and r[3]:Lerp(T.Edge, 0.35) or T.Edge
	head.ImageColor3 = r[3]:Lerp(Color3.new(1, 1, 1), 0.4)
	letter.TextSize = 70 + #r[1] * 4
end

-- a bubble rising inside the tube
local function bubble(color)
	local s = math.random(4, 8)
	local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(25, 75) / 100, 0, 1, -4), Size = UDim2.fromOffset(s, s), BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6), BackgroundTransparency = 0.2, ZIndex = 4, Parent = comboBar })
	UI.Corner(b, s)
	local top = 1 - math.max(0.05, fillShown)
	local d = 0.35 + math.random() * 0.3
	Tween(b, d, { Position = UDim2.new(b.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, top, 0), BackgroundTransparency = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(d, function()
		b:Destroy()
	end)
end

-- rank-up: the tube flashes, a ring bursts off the top, the liquid drops and refills
local function burst(color)
	barFlash.BackgroundTransparency = 0
	Tween(barFlash, 0.3, { BackgroundTransparency = 1 })
	local ring = New("ImageLabel", { BackgroundTransparency = 1, Image = TEX.ring or "", ImageColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(160, 20), Size = UDim2.fromOffset(30, 30), ZIndex = 6, Parent = comboFrame })
	Tween(ring, 0.4, { Size = UDim2.fromOffset(170, 170), ImageTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.42, function()
		ring:Destroy()
	end)
	comboScale.Scale = comboBase * 1.12
	Tween(comboScale, 0.35, { Scale = comboBase }, Enum.EasingStyle.Back)
	fillShown, fillVel = 0, 0
end

-- amount = damage dealt (for the total), crit adds extra style
function UI.ComboHit(amount, crit)
	local now = os.clock()
	if combo.points <= 0 then
		combo.hits, combo.total = 0, 0
		fillShown, fillVel = 0, 0
	end
	combo.hits += 1
	combo.total += tonumber(amount) or 0
	combo.last = now
	-- low ranks fill fast, high ranks need more; crits count extra
	local rank = rankOf(combo.points)
	combo.points = math.min(#RANKS * PER_RANK - 1, combo.points + (26 - rank * 2.4) + (crit and 14 or 0))
	local newRank = rankOf(combo.points)
	if newRank ~= combo.rank then
		local up = newRank > combo.rank
		combo.rank = newRank
		paint(newRank)
		if up then
			letterScale.Scale = 1.9
			Tween(letterScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			burst(RANKS[newRank][3])
			Audio.Play("Rarity" .. ({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" })[newRank], { volume = 0.5 })
		end
	else
		letterScale.Scale = 1.18
		Tween(letterScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	-- kick the liquid upward (the spring overshoots, then settles)
	fillVel += crit and 5 or 3
	for _ = 1, crit and 4 or 2 do
		bubble(RANKS[newRank][3])
	end
	hitsText.Text = tostring(combo.hits)
	totalText.Text = UI.Format(math.floor(combo.total))
	local heat = damageHeat(combo.total)
	totalText.TextColor3 = heat
	totalLabel.TextColor3 = heat
	hitsScale.Scale = crit and 1.6 or 1.35
	Tween(hitsScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	barScale.Scale = crit and 1.18 or 1.1
	Tween(barScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	barFlash.BackgroundTransparency = crit and 0.2 or 0.6
	Tween(barFlash, 0.15, { BackgroundTransparency = 1 })
	-- jolt
	letter.Rotation = -8 + math.random(-6, 6)
	Tween(letter, 0.15, { Rotation = -8 })
	if not comboFrame.Visible then
		comboFrame.Visible = true
		comboScale.Scale = comboBase * 0.6
		Tween(comboScale, 0.35, { Scale = comboBase }, Enum.EasingStyle.Back)
	end
end
RunService.RenderStepped:Connect(function(dt)
	if not comboFrame.Visible then
		return
	end
	local now = os.clock()
	-- drain after a short grace; the higher the rank, the faster it drains
	if now - combo.last > 0.9 then
		combo.points -= dt * (18 + combo.rank * 9)
	end
	if combo.points <= 0 then
		combo.points, combo.rank = 0, 0
		comboFrame.Visible = false
		return
	end
	local rank = rankOf(combo.points)
	if rank ~= combo.rank then
		-- drained down a rank: the tube is full of the lower rank again
		combo.rank = rank
		paint(rank)
		fillShown = 1
	end
	-- spring the liquid toward the target
	dt = math.min(dt, 1 / 20)
	local target = (combo.points % PER_RANK) / PER_RANK
	fillVel += ((target - fillShown) * 160 - fillVel * 14) * dt
	fillShown = math.clamp(fillShown + fillVel * dt, 0, 1.06)
	local f = math.min(fillShown, 1)
	comboFill.Size = UDim2.fromScale(1, f)
	local topY = 20 + BAR_H * (1 - f)
	head.Position = UDim2.fromOffset(160, topY)
	local pulse = 1 + math.sin(now * 10) * 0.08
	head.Size = UDim2.fromOffset(70 * pulse, 40 * pulse)
	head.ImageTransparency = f < 0.02 and 1 or 0.25
	-- the letter rides beside the liquid level (clamped so it never covers the hit counter)
	letterY += (math.clamp(topY, 60, 170) - letterY) * math.min(1, dt * 12)
	letter.Position = UDim2.fromOffset(70, letterY)
	rankName.Position = UDim2.fromOffset(70, letterY + 40)
	flames.Position = UDim2.fromOffset(70, letterY + 30)
	-- on fire from S up: flickering flames behind the letter (SSS flames shift color), the tube glows too
	if rank >= 5 then
		flames.ImageTransparency = 0.15 + math.random() * 0.15
		local fl = 1 + math.sin(now * 18) * 0.06 + math.random() * 0.04
		flames.Size = UDim2.fromOffset(150 * fl, (130 + (rank - 5) * 25) * fl)
		flames.ImageColor3 = rank == 7 and Color3.fromHSV((now * 0.4) % 1, 0.7, 1) or RANKS[rank][3]
		if math.random() < dt * 8 then
			bubble(RANKS[rank][3])
		end
	else
		flames.ImageTransparency = 1
	end
	if rank == 7 then
		barStroke.Color = Color3.fromHSV((now * 0.5) % 1, 0.6, 1)
	end
end)

UI.CurrencyIcon = "🪙"
return UI
