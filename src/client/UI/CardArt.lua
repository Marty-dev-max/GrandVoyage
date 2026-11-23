-- CardArt (v0.25.90, owner: pixel cards laid out like a trading card game, manga art): one card face, used by the drop
-- reveal (CardReveal) and the Bag preview.
--   rarity-colored frame + holo foil sweep, POWER top-left, monster type (kanji in its color) top-right, name plate,
--   art window = manga panel (speed lines + screentone, Textures.card_manga tinted by rarity) with the monster's real
--   3D model (UI.MonsterView: humanoid monsters are voxel characters), rarity stars, effect box, footer.
-- Laid out for a 220 x 308 face; Fitted() scales it into any box.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.UIKit)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local MonsterTypes = require(ReplicatedStorage.Shared.Config.MonsterTypes)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)

local CardArt = {}
CardArt.W, CardArt.H = 220, 308
local New = UI.New
local INK = Color3.fromRGB(18, 16, 26)
local PAPER = Color3.fromRGB(252, 246, 228)
local GOLD = Color3.fromRGB(255, 214, 90)
local ART_Y, ART_H = 40, 152

-- builds the face inside `parent` (filling it). Returns { face, foil (UIGradient), view, viewScale, viewPos, name,
-- chroma, stars = { { label, scale } } }
function CardArt.Build(parent, def, opts)
	opts = opts or {}
	local tier = UI.Rarity.Get(def.rarity)
	local mon = Monsters[def.monster or ""]
	local ty = mon and MonsterTypes[mon.mtype or ""]
	local light = tier.color:Lerp(Color3.new(1, 1, 1), 0.45)
	local face = New("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = parent })
	local g = New("UIGradient", { Color = ColorSequence.new(tier.top, tier.bottom), Rotation = 90, Parent = face })
	if tier.rainbow then
		g.Color = ColorSequence.new(Color3.fromRGB(60, 50, 80), Color3.fromRGB(12, 10, 20))
	elseif tier.prismatic then
		g.Color = UI.PrismaticSequence
		UI.SpinGradient(g)
	end
	-- frame: bright rarity rim outside, ink line inside
	local rim = UI.Stroke(face, (tier.rainbow or tier.prismatic) and Color3.new(1, 1, 1) or light, 4)
	if tier.prismatic or tier.rainbow then
		UI.SpinGradient(New("UIGradient", { Color = UI.RainbowSequence, Parent = rim }))
	end
	local inner = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 6, Parent = face })
	UI.Stroke(inner, INK, 2)

	-- header: POWER (left), name, type badge (right)
	local pw = New("Frame", { Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(46, 28), BackgroundColor3 = INK, ZIndex = 8, Parent = face })
	UI.Stroke(pw, GOLD, 1.5)
	UI.Text(pw, "POWER", 7, GOLD, "Display", { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 9), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	UI.Text(pw, mon and tostring(Formulas.MonsterPower(mon)) or "?", 13, Color3.new(1, 1, 1), "Number", {
		Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 9 })
	local badge = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 7), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = ty and ty.color or Color3.fromRGB(90, 90, 100), ZIndex = 8, Parent = face })
	badge:SetAttribute("PxKeep", true)
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = badge }):SetAttribute("PxKeep", true)
	UI.Text(badge, ty and ty.kanji or "?", 17, Color3.new(1, 1, 1), "Semi", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	local name = UI.Text(face, def.name or "Card", 14, Color3.new(1, 1, 1), "Display", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(1, -116, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 11 })
	UI.Stroke(name, INK, 2.5, Enum.ApplyStrokeMode.Contextual)
	local chroma = {}
	if tier.rank >= 6 then -- RGB split on the name from Mythic up
		for i, c in ipairs({ Color3.fromRGB(255, 40, 80), Color3.fromRGB(40, 230, 255) }) do
			local copy = name:Clone()
			for _, ch in ipairs(copy:GetChildren()) do
				ch:Destroy()
			end
			copy.TextColor3 = c
			copy.TextTransparency = 0.25
			copy.ZIndex = 10
			copy.Parent = face
			chroma[i] = copy
		end
	end

	-- art window: manga panel tinted by rarity + the monster
	local art = New("ImageLabel", {
		Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, ART_Y), Size = UDim2.new(1, -20, 0, ART_H),
		Image = Tex.card_manga or "", ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.62), ResampleMode = Enum.ResamplerMode.Pixelated,
		ScaleType = Enum.ScaleType.Crop, BackgroundColor3 = PAPER, ZIndex = 7, Parent = face })
	UI.Stroke(art, INK, 3)
	local viewPos = UDim2.new(0.5, 0, 0, ART_Y + ART_H / 2 - 4)
	local view = UI.MonsterView(face, def.monster, 190, opts.spin == nil and 0.5 or opts.spin)
	if not view then
		view = UI.Icon(face, UI.ItemIconName(def) or "card", 120)
	end
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = viewPos
	view.ZIndex = 9
	local viewScale = New("UIScale", { Scale = opts.popIn and 0.4 or 1, Parent = view })

	-- stars
	local starRow = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, ART_Y + ART_H + 2), Size = UDim2.fromOffset(180, 22), ZIndex = 11, Parent = face })
	local nStars = UI.Rarity.StarsOf(tier.id)
	local stars = {}
	for i = 1, nStars do
		local st = UI.Text(starRow, "★", 20, GOLD, "Display", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - (nStars + 1) / 2) * 22, 0.5, 0), Size = UDim2.fromOffset(22, 22),
			TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = opts.popIn and 1 or 0, ZIndex = 11 })
		UI.Stroke(st, Color3.fromRGB(110, 60, 10), 2, Enum.ApplyStrokeMode.Contextual)
		stars[i] = { label = st, scale = New("UIScale", { Scale = opts.popIn and 0 or 1, Parent = st }) }
	end

	-- effect box (paper, ink text) + footer
	local box = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, ART_Y + ART_H + 26), Size = UDim2.new(1, -20, 0, 72), BackgroundColor3 = PAPER, ZIndex = 8, Parent = face })
	UI.Stroke(box, INK, 2)
	local slot = def.cardSlot and string.upper(def.cardSlot) or "ANY"
	local tag = New("Frame", { Position = UDim2.fromOffset(6, -8), Size = UDim2.fromOffset(84, 15), BackgroundColor3 = INK, ZIndex = 9, Parent = box })
	UI.Text(tag, slot .. " SLOT", 8, GOLD, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10 })
	local desc = UI.Text(box, def.desc or "", 12, INK, "Semi", {
		Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 1, -14), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true, ZIndex = 10 })
	for _, s in ipairs(desc:GetChildren()) do
		if s:IsA("UIStroke") then
			s:Destroy() -- ink on paper: no outline
		end
	end
	New("UITextSizeConstraint", { MaxTextSize = 13, Parent = desc })
	UI.Text(face, string.upper(tier.id), 8, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(100, 10), ZIndex = 9 })
	UI.Text(face, ty and (string.upper(ty.name) .. " TYPE") or "", 8, ty and ty.color:Lerp(Color3.new(1, 1, 1), 0.4) or Color3.new(1, 1, 1), "Display", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), Size = UDim2.fromOffset(110, 10), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 })

	-- holographic foil: two rarity-tinted bands sweeping across the whole face (stronger for rarer cards)
	local k = math.clamp((tier.rank - 1) / 6, 0.1, 1)
	local foil = New("Frame", { Name = "Foil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ZIndex = 12, Parent = face })
	local fg = New("UIGradient", {
		Color = (tier.rainbow or tier.prismatic or tier.rank >= 4) and UI.RainbowSequence or ColorSequence.new({
			ColorSequenceKeypoint.new(0, tier.color), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 240)), ColorSequenceKeypoint.new(1, tier.top) }),
		Rotation = 30,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.4, 0.55 - 0.3 * k), NumberSequenceKeypoint.new(0.47, 1),
			NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(0.68, 0.7 - 0.3 * k),
			NumberSequenceKeypoint.new(0.74, 1), NumberSequenceKeypoint.new(1, 1) }),
		Parent = foil,
	})
	return { face = face, foil = fg, view = view, viewScale = viewScale, viewPos = viewPos, name = name, chroma = chroma, stars = stars }
end

-- the card scaled to fit `parent` (centered), foil sweeping by itself; returns the parts + the holder
function CardArt.Fitted(parent, def, opts)
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = parent })
	local card = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(CardArt.W, CardArt.H), BackgroundTransparency = 1, Parent = holder })
	local sc = New("UIScale", { Parent = card })
	local parts = CardArt.Build(card, def, opts)
	local function fit()
		local ok, abs = pcall(function()
			return holder.AbsoluteSize
		end)
		if ok and abs.X > 0 then
			sc.Scale = math.min(abs.X / CardArt.W, abs.Y / CardArt.H) * 0.94
		end
	end
	fit()
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local RunService = game:GetService("RunService")
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		parts.foil.Offset = Vector2.new(((os.clock() * 0.4) % 2) - 1, 0)
	end)
	parts.holder = holder
	return parts
end

return CardArt
