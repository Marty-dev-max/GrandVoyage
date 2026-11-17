-- CardReveal: center-screen card drop reveal. Everything scales with rarity (Rare -> Secret):
--  1. tension: the face-down card floats up and vibrates faster and faster while glowing orbs get sucked in (rising charge)
--  2. whip flip: a snap flip with ghost trails, a 4-frame hitstop, then a bouncy landing (flip whoosh)
--  3. arcane shockwave rune rings + golden lightning (bass drop)
--  4. holographic foil sheen in the rarity color, the monster pops out of the frame with 3D parallax,
--     bouncy rarity stars, RGB chromatic split on the name from Mythic up (celestial chime)
-- Pitch of every layer rises with rarity. Reveals queue one at a time; tap/click skips the hold.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.UIKit)
local Audio = require(script.Parent.Parent.Controllers.Audio)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)

local CardReveal = {}
local New, Tween = UI.New, UI.Tween
local queue, busy = {}, false

local W, H = 220, 308
local GOLD = Color3.fromRGB(255, 214, 90)

local function screenGui()
	local pg = UI.Root.Parent
	local g = New("ScreenGui", { Name = "GVCardReveal", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	g.Parent = pg
	return g
end

-- glowing orb that flies from a random spot into the card
local function orb(parent, color, k)
	local a = math.random() * math.pi * 2
	local r = 180 + math.random() * 160 * (0.6 + k)
	local s = math.random(14, 30)
	local o = New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Tex.glow,
		ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(a) * r, 0.46, math.sin(a) * r),
		Size = UDim2.fromOffset(s, s),
		ImageTransparency = 0.6,
		ZIndex = 5,
		Parent = parent,
	})
	local d = 0.32 + math.random() * 0.2
	Tween(o, d, { Position = UDim2.fromScale(0.5, 0.46), ImageTransparency = 0, Size = UDim2.fromOffset(6, 6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(d, function()
		o:Destroy()
	end)
end

-- a jagged golden bolt from the card outward
local function bolt(parent, k)
	local a = math.random() * math.pi * 2
	local len = 160 + 200 * k
	local segs = 6
	local px, py = 0, 0
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = parent })
	for i = 1, segs do
		local t = i / segs
		local nx = math.cos(a) * len * t + (math.random() - 0.5) * 40
		local ny = math.sin(a) * len * t + (math.random() - 0.5) * 40
		local dx, dy = nx - px, ny - py
		local l = math.sqrt(dx * dx + dy * dy)
		New("Frame", {
			BackgroundColor3 = i % 2 == 0 and GOLD or Color3.fromRGB(255, 250, 220),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (px + nx) / 2, 0.46, (py + ny) / 2),
			Size = UDim2.fromOffset(l + 2, math.max(2, 5 - i * 0.6)),
			Rotation = math.deg(math.atan2(dy, dx)),
			ZIndex = 4,
			Parent = holder,
		})
		px, py = nx, ny
	end
	task.delay(0.06, function()
		for _, c in ipairs(holder:GetChildren()) do
			Tween(c, 0.18, { BackgroundTransparency = 1 })
		end
		task.wait(0.2)
		holder:Destroy()
	end)
end

local function ring(parent, color, delay, size, img)
	task.delay(delay, function()
		local r = New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = img or Tex.ring,
			ImageColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(60, 60),
			Rotation = math.random(0, 360),
			ZIndex = 3,
			Parent = parent,
		})
		Tween(r, 0.55, { Size = UDim2.fromOffset(size, size), ImageTransparency = 1, Rotation = r.Rotation + 90 }, Enum.EasingStyle.Quart)
		task.delay(0.6, function()
			r:Destroy()
		end)
	end)
end

-- the card face: rarity gradient, foil sheen, art popping out of the top, name, stars, bonus
local function buildFace(card, def, tier, k)
	local face = New("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 6, Parent = card })
	UI.Corner(face, 16)
	local g = New("UIGradient", { Color = ColorSequence.new(tier.top, tier.bottom), Rotation = 90, Parent = face })
	if tier.rainbow then
		g.Color = ColorSequence.new(Color3.fromRGB(60, 50, 80), Color3.fromRGB(12, 10, 20))
	end
	UI.Stroke(face, tier.rainbow and Color3.new(1, 1, 1) or tier.color:Lerp(Color3.new(1, 1, 1), 0.4), 4)
	-- inner art window
	local art = New("Frame", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(1, -28, 0, 150), BackgroundColor3 = Color3.fromRGB(20, 18, 34), BackgroundTransparency = 0.25, ZIndex = 7, Parent = face })
	UI.Corner(art, 10)
	UI.Stroke(art, Color3.fromRGB(20, 16, 30), 2)
	New("UIGradient", { Color = ColorSequence.new(tier.color:Lerp(Color3.new(0, 0, 0), 0.4), Color3.fromRGB(14, 12, 24)), Rotation = 90, Parent = art })
	-- holographic foil: two moving rarity-tinted bands across the whole face
	local foil = New("Frame", { Name = "Foil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ZIndex = 12, Parent = face })
	UI.Corner(foil, 16)
	local fc = tier.rainbow and UI.RainbowSequence or ColorSequence.new({
		ColorSequenceKeypoint.new(0, tier.color),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 240)),
		ColorSequenceKeypoint.new(1, tier.top),
	})
	local fg = New("UIGradient", {
		Color = fc,
		Rotation = 30,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.4, 0.35 - 0.2 * k),
			NumberSequenceKeypoint.new(0.47, 1),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(0.68, 0.5 - 0.2 * k),
			NumberSequenceKeypoint.new(0.74, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = foil,
	})
	-- the monster (or the card icon) bigger than the window, so it breaks out over the top edge
	local view = UI.ModelView(face, "Monsters", def.monster or "", 230, true)
	if not view then
		view = UI.Icon(face, UI.ItemIconId(def) or "🃏", 150)
	end
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.new(0.5, 0, 0, 70)
	view.ZIndex = 9
	local viewScale = New("UIScale", { Scale = 0.4, Parent = view })
	-- name + stars + bonus
	local name = UI.Text(face, def.name or "Card", 20, Color3.new(1, 1, 1), "Display", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 174),
		Size = UDim2.new(1, -16, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		ZIndex = 11,
	})
	UI.Stroke(name, Color3.fromRGB(20, 16, 30), 2.5, Enum.ApplyStrokeMode.Contextual)
	local chroma = {}
	if tier.rank >= 6 then
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
	local starRow = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 202), Size = UDim2.fromOffset(180, 28), ZIndex = 11, Parent = face })
	local nStars = math.clamp(tier.rank - 2, 1, 5)
	local stars = {}
	for i = 1, nStars do
		local st = UI.Text(starRow, "★", 26, i <= nStars and GOLD or Color3.new(0.3, 0.3, 0.3), "Display", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - (nStars + 1) / 2) * 30, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			ZIndex = 11,
		})
		UI.Stroke(st, Color3.fromRGB(110, 60, 10), 2, Enum.ApplyStrokeMode.Contextual)
		stars[i] = { label = st, scale = New("UIScale", { Scale = 0, Parent = st }) }
	end
	local desc = UI.Text(face, (def.desc or "") .. ((def.cardSlot and ("\n" .. string.upper(def.cardSlot) .. " SLOT")) or ""), 14, Color3.fromRGB(255, 250, 235), "Bold", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 234),
		Size = UDim2.new(1, -20, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		ZIndex = 11,
	})
	UI.Stroke(desc, Color3.fromRGB(20, 16, 30), 2, Enum.ApplyStrokeMode.Contextual)
	return { face = face, foil = fg, view = view, viewScale = viewScale, chroma = chroma, name = name, stars = stars }
end

local function play(def)
	local tier = UI.Rarity.Get(def.rarity)
	local r = tier.rank
	local k = math.clamp((r - 2) / 5, 0.15, 1) -- intensity: Rare 0.2 .. Secret 1
	local pitch = 0.85 + (r - 3) * 0.08
	local g = screenGui()
	local alive = true

	local dim = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = g })
	Tween(dim, 0.3, { BackgroundTransparency = 0.65 - 0.25 * k })
	local skip = false
	dim.MouseButton1Click:Connect(function()
		skip = true
	end)
	local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color, ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(420, 520), ZIndex = 2, Parent = g })

	-- the card, face down
	local card = New("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(32, 26, 52), ZIndex = 6, Parent = g })
	UI.Corner(card, 16)
	UI.Stroke(card, tier.color, 4)
	New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 56, 110), Color3.fromRGB(18, 14, 30)), Rotation = 90, Parent = card })
	local back = UI.Text(card, "?", 120, tier.color:Lerp(Color3.new(1, 1, 1), 0.3), "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	UI.Stroke(back, Color3.fromRGB(14, 10, 24), 4, Enum.ApplyStrokeMode.Contextual)
	local scale = New("UIScale", { Scale = 0.55, Parent = card })
	-- tap anywhere on the screen counts (the card sits above the dim)
	local conn = UserInputService.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			skip = true
		end
	end)

	-- 1. tension
	Audio.Play("CardCharge", { pitch = pitch })
	Tween(card, 0.45, { Position = UDim2.fromScale(0.5, 0.46) }, Enum.EasingStyle.Back)
	Tween(scale, 0.45, { Scale = 0.85 }, Enum.EasingStyle.Back)
	Tween(glow, 0.9, { ImageTransparency = 0.45 - 0.3 * k })
	local tension = 0.7 + 0.5 * k
	local t0 = os.clock()
	local home = UDim2.fromScale(0.5, 0.46)
	task.wait(0.3)
	while os.clock() - t0 < tension + 0.3 do
		local p = (os.clock() - t0 - 0.3) / tension
		local amp = 1 + p * (4 + 6 * k)
		card.Position = home + UDim2.fromOffset((math.random() - 0.5) * 2 * amp, (math.random() - 0.5) * 2 * amp)
		card.Rotation = (math.random() - 0.5) * amp * 0.6
		if math.random() < 0.35 + 0.45 * k then
			orb(g, tier.color, k)
		end
		task.wait(math.max(1 / 60, 0.07 * (1 - p)))
	end
	card.Position, card.Rotation = home, 0

	-- 2. whip flip with ghost trails, hitstop, bouncy landing
	Audio.Play("CardFlip", { pitch = pitch + 0.1 })
	local parts = buildFace(card, def, tier, k)
	for i = 1, 2 + math.floor(k * 3) do
		local ghost = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = home + UDim2.fromOffset(-i * 14, 0), Size = UDim2.fromOffset(W * 0.85, H * 0.85), BackgroundColor3 = tier.color, BackgroundTransparency = 0.45 + i * 0.1, ZIndex = 5, Parent = g })
		UI.Corner(ghost, 16)
		Tween(ghost, 0.25, { BackgroundTransparency = 1, Size = UDim2.fromOffset(4, H * 0.85) })
		task.delay(0.27, function()
			ghost:Destroy()
		end)
	end
	Tween(card, 0.07, { Size = UDim2.fromOffset(4, H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.07)
	back.Visible = false
	parts.face.Visible = true
	card.Size = UDim2.fromOffset(W, H)
	scale.Scale = 1.25 + 0.15 * k
	task.wait(4 / 60) -- hitstop
	Tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Elastic)

	-- 3. shockwave rune rings + golden lightning + bass
	Audio.Play("CardBass", { pitch = 0.8 + (r - 3) * 0.06 })
	local rings = 1 + math.floor(k * 3)
	for i = 1, rings do
		ring(g, i % 2 == 1 and tier.color or GOLD, (i - 1) * 0.08, 380 + i * 120)
	end
	ring(g, Color3.new(1, 1, 1), 0, 600, Tex.impact)
	local flash = New("Frame", { BackgroundColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.6), BackgroundTransparency = 0.35 - 0.25 * k, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = g })
	Tween(flash, 0.3, { BackgroundTransparency = 1 })
	if r >= 5 then
		task.spawn(function()
			for _ = 1, 3 + math.floor(k * 6) do
				bolt(g, k)
				task.wait(0.05)
			end
		end)
	end

	-- 4. art pops out, stars bounce in, chime
	Tween(parts.viewScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		Audio.Play("CardChime", { pitch = pitch + 0.15 })
	end)
	for i, s in ipairs(parts.stars) do
		task.delay(0.2 + i * 0.09, function()
			s.label.TextTransparency = 0
			s.scale.Scale = 1.8
			Tween(s.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Bounce)
			Audio.Play("Tick", { pitch = 1 + i * 0.1, volume = 0.5 })
		end)
	end

	-- live: foil sweep, 3D parallax (card tilts toward the mouse, art moves further than the frame), RGB jitter
	local step = RunService.RenderStepped:Connect(function()
		if not alive then
			return
		end
		local t = os.clock()
		parts.foil.Offset = Vector2.new(((t * 0.5) % 2) - 1, 0)
		local m = UserInputService:GetMouseLocation()
		local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local mx = math.clamp((m.X / vs.X - 0.5) * 2, -1, 1) + math.sin(t * 1.3) * 0.25
		local my = math.clamp((m.Y / vs.Y - 0.5) * 2, -1, 1) + math.cos(t * 1.1) * 0.2
		card.Rotation = mx * 4
		card.Position = home + UDim2.fromOffset(mx * 6, my * 4)
		parts.view.Position = UDim2.new(0.5, mx * 16, 0, 70 + my * 10)
		for i, c in ipairs(parts.chroma) do
			local sgn = i == 1 and -1 or 1
			c.Position = parts.name.Position + UDim2.fromOffset(sgn * (2 + math.random() * 3 * k), (math.random() - 0.5) * 2)
		end
	end)

	local hold = 2.2 + 0.8 * k
	local t1 = os.clock()
	skip = false
	while os.clock() - t1 < hold and not (skip and os.clock() - t1 > 0.6) do
		task.wait()
	end

	alive = false
	step:Disconnect()
	conn:Disconnect()
	Tween(scale, 0.25, { Scale = 0.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Tween(card, 0.25, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Tween(dim, 0.3, { BackgroundTransparency = 1 })
	Tween(glow, 0.3, { ImageTransparency = 1 })
	task.wait(0.32)
	g:Destroy()
end

function CardReveal.Play(def)
	if not def then
		return
	end
	table.insert(queue, def)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local d = table.remove(queue, 1)
			local ok, err = pcall(play, d)
			if not ok then
				warn("[CardReveal] " .. tostring(err))
				local pg = UI.Root.Parent
				local left = pg and pg:FindFirstChild("GVCardReveal")
				if left then
					left:Destroy()
				end
			end
		end
		busy = false
	end)
end

return CardReveal
