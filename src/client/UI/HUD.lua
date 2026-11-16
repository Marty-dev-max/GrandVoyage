-- HUD: player card, currencies, side menu, skill bar + AUTO, target frame, loot feed
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ClassesCfg = require(Shared.Config.Classes)
local Monsters = require(Shared.Config.Monsters)
local ItemDB = require(Shared.Modules.ItemDB)
local Rarity = require(Shared.Modules.Rarity)
local FruitsCfg = require(Shared.Config.Fruits)
local PearlsCfg = require(Shared.Config.Pearls)
local PetsCfg = require(Shared.Config.Pets)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.UIKit)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.Parent.State)
local Combat = require(script.Parent.Parent.Controllers.Combat)
local Audio = require(script.Parent.Parent.Controllers.Audio)
local Readability = require(script.Parent.Parent.Controllers.Readability)

local HUD = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New
local Classes = ClassesCfg.Classes

local bars, money, bounty, pointsBtn, skillSlots, autoBtn, targetFrame, lootFeed, buffRow
local statusCard, menuFrame, menuScale, attackHolder

local function glass(parent, size, pos, anchor)
	local f = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero, Parent = parent })
	UI.Corner(f, 18)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 3)
	return f
end

local function pill(parent, pos, icon, color)
	local f = glass(parent, UDim2.fromOffset(240, 44), pos, Vector2.new(1, 0))
	local ic = UI.Text(f, icon, 28, color, "Display", { Size = UDim2.fromOffset(40, 44), Position = UDim2.fromOffset(6, -2), TextXAlignment = Enum.TextXAlignment.Center })
	local label = UI.Text(f, "0", 24, color, "Number", { Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(46, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local _ = ic
	return f, label
end

-- ===== Level ring: left half = Base EXP (green), right half = Job EXP (class color) =====
-- Both halves fill from the bottom up to the top. Built from chunky rotated segments (no image assets needed).
local SEGMENTS = 15
local RING_SIZE = 148
local ring -- { frame, scale, base = {segs}, job = {segs}, shown = {base, job}, target = {base, job}, hold, jobColor }

local function segmentAngle(half, i)
	-- degrees clockwise from the top. half = "base" (left side) | "job" (right side); i = 1 at the bottom
	local gap, span = 14, 180 - 28
	local a = 180 - gap - (i - 0.5) * span / SEGMENTS
	return half == "job" and a or 360 - a
end

local function buildRing(parent, pos)
	local frame = New("Frame", { Size = UDim2.fromOffset(RING_SIZE, RING_SIZE), Position = pos, BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	local sc = New("UIScale", { Parent = frame })
	local disc = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = frame })
	UI.Corner(disc, RING_SIZE)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = disc })
	UI.Stroke(disc, T.Edge, 4)
	local c, r = RING_SIZE / 2, RING_SIZE / 2 - 13
	local segs = { base = {}, job = {} }
	for _, half in ipairs({ "base", "job" }) do
		for i = 1, SEGMENTS do
			local a = math.rad(segmentAngle(half, i))
			local seg = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(c + r * math.sin(a), c - r * math.cos(a)),
				Size = UDim2.fromOffset(11, 17),
				Rotation = math.deg(a),
				BackgroundColor3 = T.PanelDeep,
				ZIndex = 4,
				Parent = frame,
			})
			UI.Corner(seg, 4)
			UI.Stroke(seg, T.Edge, 1.5)
			segs[half][i] = seg
		end
	end
	-- portrait
	local face = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RING_SIZE - 58, RING_SIZE - 58), BackgroundColor3 = T.Ocean, ZIndex = 5, Parent = frame })
	UI.Corner(face, RING_SIZE)
	local faceStroke = UI.Stroke(face, T.Gold, 3.5)
	local img = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 6, Parent = face })
	UI.Corner(img, RING_SIZE)
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then
			img.Image = url
		end
	end)
	-- level badge at the bottom of the ring
	local badge = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(72, 34), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = frame })
	UI.Corner(badge, 17)
	UI.Gradient(badge, T.Gold:Lerp(Color3.new(1, 1, 1), 0.45), T.Orange, 90)
	UI.Stroke(badge, T.Edge, 3)
	local lvl = UI.Text(badge, "1", 26, Color3.new(1, 1, 1), "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	ring = {
		frame = frame,
		scale = sc,
		segs = segs,
		face = face,
		faceStroke = faceStroke,
		lvl = lvl,
		shown = { base = 0, job = 0 },
		target = { base = 0, job = 0 },
		hold = 0,
		jobColor = T.Purple,
	}
	UI.Tooltip(frame, function()
		return string.format("<b>Base Lv.%d</b>  <font color=\"#40DE6E\">EXP %.1f%%</font>\n<b>Job Lv.%d</b>  JOB EXP %.1f%%", player:GetAttribute("Level") or 1, ring.target.base * 100, player:GetAttribute("JobLevel") or 1, ring.target.job * 100), T.Green
	end)
	return ring
end

local function paintHalf(half, ratio, color)
	local segs = ring.segs[half]
	local filled = ratio * SEGMENTS
	for i, seg in ipairs(segs) do
		local f = math.clamp(filled - (i - 1), 0, 1)
		if f >= 1 then
			seg.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), (i == math.floor(filled)) and 0.35 or 0)
		elseif f > 0 then
			seg.BackgroundColor3 = T.PanelDeep:Lerp(color, 0.35 + f * 0.5)
		else
			seg.BackgroundColor3 = T.PanelDeep:Lerp(T.Panel, 0.6)
		end
	end
end

-- point (in UI space, before the root UIScale) of the ring's current fill tip for a half
local function ringTip(half)
	local i = math.clamp(math.floor(ring.target[half] * SEGMENTS) + 1, 1, SEGMENTS)
	local seg = ring.segs[half][i]
	local o = ring.frame.Position
	return Vector2.new(o.X.Offset + seg.Position.X.Offset, o.Y.Offset + seg.Position.Y.Offset)
end

local function updateRing(dt)
	if not ring then
		return
	end
	for _, half in ipairs({ "base", "job" }) do
		local tgt, cur = ring.target[half], ring.shown[half]
		if os.clock() >= ring.hold then
			if tgt < cur - 0.001 then
				cur = tgt -- level up wrapped the bar
			else
				cur = math.min(tgt, cur + math.max(0.004, (tgt - cur) * math.min(1, dt * 6)))
			end
		end
		ring.shown[half] = cur
		paintHalf(half, cur, half == "base" and T.Green or ring.jobColor)
	end
end

-- ===== EXP orbs: fly from the monster to the ring =====
local orbLayer
local orbs = {}
local function orbCount(n)
	if n <= 0 then
		return 0
	end
	return math.clamp(2 + math.floor(math.log10(n + 1) * 1.5), 2, 8)
end

local function floatLabel(text, color, at)
	local t = UI.Text(orbLayer, text, 24, color, "Display", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(200, 28), TextWrapped = false, ZIndex = 52 })
	UI.Pop(t, 0.4)
	UI.Tween(t, 1.1, { Position = UDim2.fromOffset(at.X, at.Y - 36), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.15, function()
		t:Destroy()
	end)
end

function HUD.ExpGain(d)
	if not ring or not orbLayer then
		return
	end
	local sc = UI.GetScale()
	local cam = workspace.CurrentCamera
	local from
	local src = d.pos
	if not src then
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		src = r and r.Position
	end
	if src and cam then
		local v, onScreen = cam:WorldToViewportPoint(src)
		if onScreen then
			from = Vector2.new(v.X, v.Y) / sc
		end
	end
	if not from then
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		from = Vector2.new(vp.X * 0.5, vp.Y * 0.55) / sc
	end
	ring.hold = os.clock() + 0.75
	local now = os.clock()
	local groups = {
		{ half = "base", n = orbCount(d.base or 0), color = T.Green, label = "+" .. UI.Format(d.base or 0) .. " EXP" },
		{ half = "job", n = orbCount(d.job or 0), color = ring.jobColor, label = "+" .. UI.Format(d.job or 0) .. " JOB" },
	}
	for gi, g in ipairs(groups) do
		local to = ringTip(g.half)
		for i = 1, g.n do
			local o = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(from.X, from.Y), BackgroundColor3 = g.color:Lerp(Color3.new(1, 1, 1), 0.35), ZIndex = 50, Parent = orbLayer })
			UI.Corner(o, 8)
			UI.Stroke(o, Color3.new(1, 1, 1), 2)
			local glow = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = g.color, BackgroundTransparency = 0.6, ZIndex = 49, Parent = o })
			UI.Corner(glow, 15)
			local ang = math.random() * math.pi * 2
			local burst = from + Vector2.new(math.cos(ang), math.sin(ang)) * (40 + math.random() * 50)
			-- control point bows the path outward so the orbs swoop instead of moving in a straight line
			local mid = (burst + to) / 2 + Vector2.new((gi == 1 and -1 or 1) * (80 + math.random() * 80), -60 - math.random() * 60)
			table.insert(orbs, { o = o, p0 = from, p1 = burst, c = mid, p2 = to, t0 = now + (i - 1) * 0.045 + (gi - 1) * 0.08, half = g.half, color = g.color, last = i == g.n, label = g.label })
		end
	end
end

local function updateOrbs()
	local now = os.clock()
	for i = #orbs, 1, -1 do
		local it = orbs[i]
		local t = now - it.t0
		if t >= 0 then
			local pos
			if t < 0.2 then
				local k = 1 - (1 - t / 0.2) ^ 2 -- burst out
				pos = it.p0:Lerp(it.p1, k)
			else
				local k = math.clamp((t - 0.2) / 0.5, 0, 1)
				k = k * k -- accelerate into the ring
				local a = it.p1:Lerp(it.c, k)
				local b = it.c:Lerp(it.p2, k)
				pos = a:Lerp(b, k)
				it.o.Size = UDim2.fromOffset(16 - 6 * k, 16 - 6 * k)
				if k >= 1 then
					it.o:Destroy()
					table.remove(orbs, i)
					ring.hold = 0
					UI.Bounce(ring.frame)
					Audio.Play("Coin", { pitch = it.half == "base" and 1.6 or 1.9, volume = 0.35 })
					if it.last then
						floatLabel(it.label, it.color, it.p2 + Vector2.new(it.half == "base" and -150 or 18, it.half == "base" and -10 or 10))
					end
					continue
				end
			end
			it.o.Position = UDim2.fromOffset(pos.X, pos.Y)
		end
	end
end

-- color for a skill slot: its class color, or its fruit's color for Cursed Fruit skills
local function skillColor(skill)
	if not skill then
		return T.Panel
	end
	local cls = Classes[skill.class]
	if cls then
		return cls.color
	end
	local f = skill.fruit and FruitsCfg.ById[skill.fruit]
	return f and f.color or T.Accent
end

local function buildStatus()
	-- the card sits behind the ring; the ring overlaps its left edge
	local card = glass(UI.Root, UDim2.fromOffset(356, 128), UDim2.fromOffset(100, 22))
	statusCard = card
	UI.Shine(card, 0.3).BackgroundTransparency = 0.9
	buildRing(UI.Root, UDim2.fromOffset(14, 10))
	local name = UI.Text(card, player.DisplayName, 24, T.Text, "Display", { Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 28), TextWrapped = false })
	local cls = UI.Text(card, "", 14, T.TextSoft, "Semi", { Position = UDim2.fromOffset(70, 33), Size = UDim2.new(1, -80, 0, 18), TextWrapped = false })
	local holder = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 55), Size = UDim2.new(1, -82, 0, 46), Parent = card })
	UI.List(holder, nil, 5)
	bars = {
		hp = UI.Bar(holder, T.Green, UDim2.new(1, 0, 0, 22), "HP"),
		sp = UI.Bar(holder, T.Blue, UDim2.new(1, 0, 0, 18), "SP"),
		name = name,
		cls = cls,
	}
	-- EXP readouts that match the two ring halves
	local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 104), Size = UDim2.new(1, -82, 0, 18), Parent = card })
	UI.List(row, Enum.FillDirection.Horizontal, 14)
	bars.expText = UI.Text(row, "", 15, T.Green, "Display", { Size = UDim2.fromOffset(110, 18), TextWrapped = false })
	bars.jobText = UI.Text(row, "", 15, T.Purple, "Display", { Size = UDim2.fromOffset(110, 18), TextWrapped = false })
	buffRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(170, 158), Size = UDim2.fromOffset(300, 30), Parent = UI.Root })
	UI.List(buffRow, Enum.FillDirection.Horizontal, 6)

	local m, ml = pill(UI.Root, UDim2.new(1, -16, 0, 16), UI.CurrencyIcon, T.Gold)
	money = ml
	UI.Tooltip(m, function()
		return "<b>Doubloons</b>\nEarned from monsters, ships and bosses.", T.Gold
	end)
	local b, bl = pill(UI.Root, UDim2.new(1, -16, 0, 66), "☠", T.Pirate)
	bounty = { frame = b, label = bl, icon = b:FindFirstChildOfClass("TextLabel") }
	local pf, pl = pill(UI.Root, UDim2.new(1, -16, 0, 116), PearlsCfg.Icon, Color3.fromRGB(150, 225, 255))
	HUD.pearls = pl
	UI.Tooltip(pf, function()
		return "<b>Pearls</b>\nEarned from chests, exploring, story quests and MVP bosses. Spend them in the Pearl Shop or trade them in stalls (Lv." .. PearlsCfg.Trade.MinLevel .. "+).", Color3.fromRGB(150, 225, 255)
	end)
	pointsBtn = UI.Button(UI.Root, "+ POINTS", T.Gold, UDim2.fromOffset(150, 40), function()
		Panels.Open("Stats")
	end)
	pointsBtn.Parent.AnchorPoint = Vector2.new(1, 0)
	pointsBtn.Parent.Position = UDim2.new(1, -16, 0, 168)
	-- build stamp (bottom-right): tells you which version of the code Studio is running
	UI.Text(UI.Root, "v" .. GameConfig.Version, 12, Color3.fromRGB(220, 220, 235), "Bold", { Name = "Version", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -2), Size = UDim2.fromOffset(120, 14), TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.35 })
	orbLayer = New("Frame", { Name = "OrbLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = UI.Root })
end

-- Anime-Vanguards-style menu: square colored tiles with a big icon, a label and a key hint, in two columns
local MENU = {
	{ "🎒", "Inventory", T.Ocean, "I", "Bag" },
	{ "📊", "Stats", T.Purple, "C", "Stats" },
	{ "✨", "Skills", T.Gold, "K", "Skills" },
	{ "⚓", "Shipwright", T.OceanDark, nil, "Ships" },
	{ "🏴", "Guild", T.Pirate, "G", "Guild" },
	{ "👥", "Party", T.Green, "P", "Party" },
	{ "🗺️", "Map", T.Ocean, "M", "Map" },
	{ "👑", "BossBoard", T.Red, "B", "Bosses" },
	{ "📜", "Quests", T.Gold:Lerp(T.Orange, 0.4), "J", "Quests" },
	{ "🐾", "Pets", T.Green:Lerp(T.Ocean, 0.3), "N", "Pets" },
	{ "🦪", "PearlShop", Color3.fromRGB(80, 170, 220), nil, "Pearls" },
	{ "⚙️", "Settings", T.Grey, "O", "Settings" },
}
HUD.Menu = MENU

local function menuTile(parent, it)
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(74, 78), Parent = parent })
	local shadow = New("Frame", { Name = "Shadow", BackgroundColor3 = it[3]:Lerp(Color3.new(0, 0, 0), 0.6), Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 5), Parent = holder })
	UI.Corner(shadow, 14)
	local tile = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, -4), Parent = holder })
	UI.Corner(tile, 14)
	New("UIGradient", { Name = "Fill", Color = ColorSequence.new(it[3]:Lerp(Color3.new(1, 1, 1), 0.3), it[3]:Lerp(Color3.new(0, 0, 0), 0.2)), Rotation = 90, Parent = tile })
	UI.Stroke(tile, T.Edge, 3)
	-- diagonal stripes give the tile some anime "card" texture
	local stripes = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), Parent = tile })
	UI.Corner(stripes, 14)
	New("UIGradient", { Rotation = 60, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.46, 0), NumberSequenceKeypoint.new(1, 0) }), Parent = stripes })
	UI.Text(tile, it[1], 32, Color3.new(1, 1, 1), "Display", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center })
	UI.Text(tile, string.upper(it[5]), 14, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -4), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	if it[4] then
		local key = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.PanelDeep, ZIndex = 3, Parent = tile })
		UI.Corner(key, 6)
		UI.Stroke(key, T.Edge, 2)
		UI.Text(key, it[4], 13, T.Gold, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	UI.Tactile(tile)
	tile.Activated:Connect(function()
		Panels.Toggle(it[2])
	end)
	return tile
end

local function buildMenu()
	-- top-anchored under the currency pills so it never runs into the skill bar or the mobile attack button
	local menu = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 218), Size = UDim2.fromOffset(158, 430), BackgroundTransparency = 1, Parent = UI.Root })
	menuFrame = menu
	menuScale = New("UIScale", { Parent = menu })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(74, 78), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = menu })
	for _, it in ipairs(MENU) do
		menuTile(menu, it)
	end
	local keymap = {}
	for _, it in ipairs(MENU) do
		if it[4] then
			keymap[Enum.KeyCode[it[4]]] = it[2]
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local panel = keymap[input.KeyCode]
		if panel then
			Panels.Toggle(panel)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			UI.CloseAll()
		end
	end)
end

local function buildSkillBar()
	local bar = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(780, 100), BackgroundTransparency = 1, Parent = UI.Root })
	UI.List(bar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Bottom
	autoBtn = UI.Button(bar, "AUTO", T.Grey, UDim2.fromOffset(104, 88), function()
		Combat.ToggleAuto()
	end)
	UI.Tooltip(autoBtn, function()
		return "<b>Auto Battle</b>  [T]\nFights nearby monsters, uses ticked skills and drinks potions.", T.Green
	end)
	skillSlots = {}
	for i = 1, 8 do
		-- holder keeps the layout slot; the slot inside can hop on hover
		local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 76), Parent = bar })
		local base = New("Frame", { Name = "Shadow", BackgroundColor3 = T.Edge, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(0, 4), Parent = holder })
		UI.Corner(base, 14)
		local slot = New("TextButton", { Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = holder })
		UI.Corner(slot, 14)
		local grad = New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = slot })
		local stroke = UI.Stroke(slot, T.Edge, 3)
		local name = UI.Text(slot, "", 13, T.Text, "Bold", { Size = UDim2.new(1, -6, 1, -18), Position = UDim2.fromOffset(3, 14), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		local key = UI.Text(slot, tostring(i), 14, T.Gold, "Display", { Position = UDim2.fromOffset(5, 1), Size = UDim2.fromOffset(16, 16) })
		local sp = UI.Text(slot, "", 12, Color3.fromRGB(150, 200, 255), "Number", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -1), Size = UDim2.fromOffset(40, 14), TextXAlignment = Enum.TextXAlignment.Right })
		local cd = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 5, Parent = slot })
		UI.Corner(cd, 14)
		local cdText = UI.Text(slot, "", 26, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
		local autoDot = New("Frame", { BackgroundColor3 = T.Green, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -16, 0, 4), Visible = false, ZIndex = 7, Parent = slot })
		UI.Corner(autoDot, 6)
		UI.Stroke(autoDot, T.Edge, 1.5)
		UI.Tactile(slot)
		slot.Activated:Connect(function()
			local p = State.profile
			if p and p.skillBar[i] then
				Combat.CastSkill(p.skillBar[i])
			end
		end)
		slot.MouseEnter:Connect(function()
			local p = State.profile
			Readability.HoverSkill = p and p.skillBar[i]
		end)
		slot.MouseLeave:Connect(function()
			Readability.HoverSkill = nil
		end)
		UI.Tooltip(slot, function()
			local p = State.profile
			local s = p and p.skillBar[i] and ClassesCfg.SkillById[p.skillBar[i]]
			if not s then
				return nil
			end
			local lvText = s.fruit and ("Mastery " .. (p.fruit and p.fruit.mastery or 0)) or ("Lv." .. (p.skills[s.id] or 0))
			return string.format("<b>%s</b>  %s\n%s\nSP %d  •  Cooldown %ss", s.name, lvText, s.desc or "", s.sp, s.cd), skillColor(s)
		end)
		skillSlots[i] = { slot = slot, name = name, cd = cd, cdText = cdText, auto = autoDot, sp = sp, grad = grad, stroke = stroke, key = key, base = base }
	end
	if UI.IsMobile then
		local atk = UI.Button(UI.Root, "⚔️", T.Red, UDim2.fromOffset(110, 110), function()
			Combat.AttackNearest()
		end)
		atk.Parent.AnchorPoint = Vector2.new(1, 1)
		atk.Parent.Position = UDim2.new(1, -24, 1, -130)
		attackHolder = atk.Parent
		atk.TextScaled = false
		atk.TextSize = 46
	end
end

function HUD.NewHighlight()
	return New("Highlight", { FillTransparency = 0.85, FillColor = T.Red, OutlineColor = T.Red, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded })
end

-- the highlight dies with a monster model that gets destroyed; recreate it when that happens
local function setHighlight(model)
	if HUD.highlight.Parent == model then
		return
	end
	local ok = pcall(function()
		HUD.highlight.Parent = model
	end)
	if not ok then
		HUD.highlight = HUD.NewHighlight()
		HUD.highlight.Parent = model
	end
end

local function buildTarget()
	targetFrame = glass(UI.Root, UDim2.fromOffset(380, 70), UDim2.new(0.5, 0, 0, 88), Vector2.new(0.5, 0))
	targetFrame.Visible = false
	UI.Pad(targetFrame, 8)
	-- 🪤 Capture: shows when the target can be tamed, is below the HP threshold, and you carry Sea Bait
	local cap, capHolder = UI.Button(UI.Root, "🪤 Capture", T.Green, UDim2.fromOffset(150, 40), function()
		local t = State.target
		if t then
			local res = Net.Request("CapturePet", { target = t })
			UI.Toast(res.msg or (res.ok and "Tamed!" or "Failed"), res.ok and "good" or "bad")
		end
	end)
	capHolder.AnchorPoint = Vector2.new(0.5, 0)
	capHolder.Visible = false
	HUD.captureBtn = capHolder
	local _ = cap
	HUD.targetName = UI.Text(targetFrame, "", 20, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 24) })
	local hp = UI.Bar(targetFrame, T.Red, UDim2.new(1, 0, 0, 20), "")
	hp.back.Position = UDim2.fromOffset(0, 30)
	HUD.targetHp = hp
	-- Enabled only while there is a target: a Highlight with no Adornee outlines its Parent (the whole workspace!)
	-- Lives INSIDE the target model (so it can only ever outline that model) and is unparented when there is no target.
	-- Parented to workspace with no Adornee, a Highlight outlines the entire map.
	HUD.highlight = HUD.NewHighlight()
end

local function buildLoot()
	lootFeed = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -24), Size = UDim2.fromOffset(340, 260), BackgroundTransparency = 1, Parent = UI.Root })
	UI.List(lootFeed, nil, 5, Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Bottom
end

function HUD.Loot(data)
	local function add(text, rarityId)
		local tier = Rarity.Get(rarityId)
		local f = New("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), Parent = lootFeed })
		UI.Corner(f, 12)
		UI.RarityStyle(f, rarityId)
		UI.Pad(f, 6)
		UI.Text(f, text, 17, T.Text, "Bold", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), TextWrapped = false })
		UI.Pop(f, 0.5)
		if tier.rank >= 4 then
			Audio.Play("Rarity" .. tier.id)
		end
		task.delay(4.5, function()
			UI.Tween(f, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			f:Destroy()
		end)
	end
	if data.beli and data.beli > 0 then
		add("+" .. UI.Format(data.beli) .. " " .. UI.CurrencyIcon, "Legendary")
		Audio.Play("Coin")
	end
	for _, it in ipairs(data.items or {}) do
		local def = ItemDB.Get(it.id)
		add((it.card and "🃏 " or "") .. (def and def.name or it.id) .. "  x" .. it.qty, def and def.rarity or "Common")
		if it.card then
			Audio.Play("CardDrop")
			UI.Banner("Card Drop!", def and def.name or it.id, Rarity.Get(def and def.rarity).color, def and def.rarity)
		end
	end
	local frames = {}
	for _, c in ipairs(lootFeed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	for i = 1, #frames - 7 do
		frames[i]:Destroy()
	end
end

local buffIcons = { IronBody = "🛡", EagleEye = "🦅", HeatedLeg = "🔥", MirageVeil = "🌫", Adrenaline = "💉", SteelFrame = "🔩" }
local lastBuffs
local function refresh()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local r = hum.Health / math.max(1, hum.MaxHealth)
		bars.hp:Set(r, UI.Format(hum.Health) .. " / " .. UI.Format(hum.MaxHealth))
		bars.hp:SetColor(r < 0.3 and T.Red or (r < 0.6 and T.Gold or T.Green))
	end
	local sp, maxSp = player:GetAttribute("SP") or 0, player:GetAttribute("MaxSP") or 1
	bars.sp:Set(sp / maxSp, UI.Format(sp) .. " / " .. UI.Format(maxSp))
	local be, bn = player:GetAttribute("BaseExp") or 0, player:GetAttribute("BaseExpNext") or 1
	local je, jn = player:GetAttribute("JobExp") or 0, player:GetAttribute("JobExpNext") or 1
	ring.target.base = math.clamp(be / math.max(1, bn), 0, 1)
	ring.target.job = math.clamp(je / math.max(1, jn), 0, 1)
	ring.lvl.Text = tostring(player:GetAttribute("Level") or 1)
	local faction = player:GetAttribute("Faction") or "None"
	local clsId = player:GetAttribute("Class") or "Brawler"
	local cls = Classes[clsId]
	local fruitId = player:GetAttribute("Fruit")
	local fruitDef = fruitId and FruitsCfg.ById[fruitId]
	bars.cls.Text = (fruitDef and (fruitDef.icon .. " ") or "") .. (cls and cls.icon or "") .. " " .. (player:GetAttribute("ClassName") or "") .. "  •  Job Lv." .. (player:GetAttribute("JobLevel") or 1) .. (player:GetAttribute("GuildName") and ("  •  " .. player:GetAttribute("GuildName")) or "")
	ring.jobColor = cls and (cls.ringColor or cls.color) or T.Purple
	ring.face.BackgroundColor3 = cls and cls.color or T.Ocean
	bars.expText.Text = string.format("EXP %.1f%%", ring.target.base * 100)
	bars.jobText.Text = string.format("JOB %.1f%%", ring.target.job * 100)
	bars.jobText.TextColor3 = ring.jobColor
	ring.faceStroke.Color = faction == "Marine" and T.Marine or (faction == "Pirate" and T.Pirate or T.Gold)
	money.Text = UI.Format(player:GetAttribute("Beli") or 0)
	-- attribute (live) or the synced profile, whichever arrives first
	local prof = State.profile
	local pearls = player:GetAttribute("Pearls") or (prof and ((prof.pearls or 0) + (prof.pearlsBound or 0))) or 0
	HUD.pearls.Text = UI.Format(pearls)
	if faction == "Pirate" then
		bounty.icon.Text = "☠"
		bounty.label.Text = UI.Short(player:GetAttribute("Bounty") or 0)
		bounty.label.TextColor3 = T.Pirate
	elseif faction == "Marine" then
		bounty.icon.Text = "⚓"
		bounty.label.Text = UI.Format(player:GetAttribute("Merit") or 0) .. " Merit"
		bounty.label.TextColor3 = T.Marine
	else
		bounty.icon.Text = "🏳"
		bounty.label.Text = "Civilian"
		bounty.label.TextColor3 = T.TextSoft
	end
	local pts = (player:GetAttribute("StatPoints") or 0) + (player:GetAttribute("SkillPoints") or 0)
	pointsBtn.Parent.Visible = pts > 0
	pointsBtn.Text = "+" .. pts .. " POINTS"
	-- buffs
	local buffs = player:GetAttribute("Buffs") or ""
	if buffs ~= lastBuffs then
		lastBuffs = buffs
		for _, c in ipairs(buffRow:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for id in string.gmatch(buffs, "[^,]+") do
			local b = glass(buffRow, UDim2.fromOffset(30, 30), UDim2.new())
			UI.Text(b, buffIcons[id] or "✨", 18, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			UI.Pop(b)
		end
	end
	-- skill bar
	local p = State.profile
	local now = os.clock()
	for i, s in ipairs(skillSlots) do
		local id = p and p.skillBar[i]
		local skill = id and ClassesCfg.SkillById[id]
		s.name.Text = skill and skill.name or ""
		s.sp.Text = skill and (skill.sp .. " SP") or ""
		local c = skillColor(skill)
		s.grad.Color = skill and ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.45)) or ColorSequence.new(T.PanelTop, T.PanelDeep)
		local left = id and ((State.cooldowns[id] or 0) - now) or 0
		s.cd.Size = UDim2.new(1, 0, skill and left > 0 and math.clamp(left / skill.cd, 0, 1) or 0, 0)
		s.cdText.Text = (skill and left > 0) and string.format(left < 1 and "%.1f" or "%d", left) or ""
		s.auto.Visible = id ~= nil and p.autoSkills[id] == true
		s.stroke.Color = (skill and (player:GetAttribute("SP") or 0) < skill.sp) and T.Red or T.Edge
	end
	UI.SetButtonColor(autoBtn, State.auto and T.Green or T.Grey)
	autoBtn.Text = State.auto and "AUTO\nON" or "AUTO"
	-- target
	local tgt = State.target
	if tgt and tgt.Parent and tgt.PrimaryPart then
		targetFrame.Visible = true
		local mon = Monsters[tgt:GetAttribute("MonsterId") or ""]
		local lvl = tgt:GetAttribute("Level") or 1
		HUD.targetName.Text = (tgt:GetAttribute("Boss") and "👑 " or "") .. (mon and mon.name or tgt.Name) .. "  Lv." .. lvl
		HUD.targetName.TextColor3 = Rarity.LevelColor(player:GetAttribute("Level") or 1, lvl)
		local hp, max = tgt:GetAttribute("HP") or 0, tgt:GetAttribute("MaxHP") or 1
		HUD.targetHp:Set(hp / max, UI.Format(hp) .. " / " .. UI.Format(max))
		local tameable = PetsCfg.ByMonster[tgt:GetAttribute("MonsterId") or ""] ~= nil
		local hasBait = false
		for _, e in ipairs(p and p.inventory or {}) do
			if e.id == PetsCfg.Capture.BaitItem then
				hasBait = true
			end
		end
		HUD.captureBtn.Visible = tameable and hasBait and hp / max <= PetsCfg.Capture.MaxHpRatio
		HUD.captureBtn.Position = UDim2.new(0.5, 0, 0, targetFrame.Position.Y.Offset + targetFrame.Size.Y.Offset + 8)
		setHighlight(tgt)
	else
		targetFrame.Visible = false
		HUD.captureBtn.Visible = false
		setHighlight(nil)
	end
end

-- Responsive layout: keeps the top-left cluster under Roblox's own top-bar buttons and switches to a compact
-- arrangement on small screens (phones in landscape). Re-run whenever the screen or the top bar changes.
function HUD.Layout()
	if not statusCard then
		return
	end
	local sc = UI.GetScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1600, 900)
	local canvas = vp / sc
	local compact = canvas.Y < 760 or canvas.X < 1300
	HUD.compact = compact
	local inset = 0
	pcall(function()
		inset = GuiService.TopbarInset.Max.Y
	end)
	local topY = math.floor(inset / sc) + 4
	ring.frame.Position = UDim2.fromOffset(14, topY)
	statusCard.Position = UDim2.fromOffset(100, topY + 12)
	statusCard.Size = UDim2.fromOffset(compact and 300 or 356, 128)
	buffRow.Position = UDim2.fromOffset(170, topY + 148)
	-- target frame: narrower on small screens so it clears the status card
	targetFrame.Size = UDim2.fromOffset(compact and 300 or 380, 70)
	-- menu: 3 small columns on phones, 2 big columns elsewhere
	local grid = menuFrame:FindFirstChildOfClass("UIGridLayout")
	if compact then
		-- 4 small columns x 3 rows so the menu ends well above the mobile attack button
		menuScale.Scale = 0.8
		menuFrame.Size = UDim2.fromOffset(326, 250)
	else
		menuScale.Scale = 1
		menuFrame.Size = UDim2.fromOffset(158, 520)
	end
	if grid then
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	end
	-- quest tracker sits under the player card
	if HUD.questFrame then
		HUD.questFrame.Position = UDim2.fromOffset(16, topY + 192)
		HUD.questFrame.Size = UDim2.fromOffset(compact and 300 or 330, 116)
	end
	-- loot feed: bottom-left on PC; on touch screens the thumbstick lives there, so stack it under the tracker
	local list = lootFeed:FindFirstChildOfClass("UIListLayout")
	if UI.IsMobile then
		lootFeed.AnchorPoint = Vector2.new(0, 0)
		lootFeed.Position = UDim2.fromOffset(16, topY + 340)
		if list then
			list.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	else
		lootFeed.AnchorPoint = Vector2.new(0, 1)
		lootFeed.Position = UDim2.new(0, 16, 1, -24)
		if list then
			list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end
	-- toasts sit just left of the menu column (they used to slide under the currency pills)
	local menuW = compact and 326 * 0.8 or 158
	UI.ToastHolder.Position = UDim2.new(1, -(menuW + 32), 0, 222)
	if attackHolder then
		attackHolder.Size = UDim2.fromOffset(compact and 120 or 110, compact and 120 or 110)
	end
end

function HUD.Start()
	buildStatus()
	buildMenu()
	buildSkillBar()
	buildTarget()
	buildLoot()
	HUD.Layout()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(HUD.Layout)
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(HUD.Layout)
		end)
	end
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local ok2, err2 = pcall(function()
			updateRing(dt)
			updateOrbs()
		end)
		if not ok2 then
			warn("[HUD]", err2)
		end
		acc += dt
		if acc > 0.08 then
			acc = 0
			local ok, err = pcall(refresh)
			if not ok then
				warn("[HUD]", err)
			end
		end
	end)
end

return HUD
