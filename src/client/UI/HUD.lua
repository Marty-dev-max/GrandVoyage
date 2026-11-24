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
local CardReveal = require(script.Parent.CardReveal)
local ItemReveal = require(script.Parent.ItemReveal)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.Parent.State)
local Combat = require(script.Parent.Parent.Controllers.Combat)
local Hotkeys = require(script.Parent.Parent.Controllers.Hotkeys)
local Audio = require(script.Parent.Parent.Controllers.Audio)
local Readability = require(script.Parent.Parent.Controllers.Readability)
local SkillSets = require(Shared.Modules.SkillSets)

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

-- v0.24.6 (owner): the status card and the currency row are soft fades now, not hard grey boxes: a dark panel that
-- melts away toward its open side (fadeTo = "right" | "left"), no outline
local function softPanel(parent, size, pos, anchor, fadeTo)
	local f = New("Frame", { BackgroundColor3 = Color3.fromRGB(12, 12, 22), BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero, Parent = parent })
	f:SetAttribute("PxKeep", true)
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, fadeTo == "left" and 1 or 0.15),
			NumberSequenceKeypoint.new(0.55, 0.35),
			NumberSequenceKeypoint.new(1, fadeTo == "left" and 0.15 or 1),
		}),
		Parent = f,
	})
	return f
end

-- swap a pill's icon (rendered image or emoji text)
local function setPillIcon(obj, icon)
	if obj:IsA("ImageLabel") then
		obj.Image = UI.IconId(icon) or ""
	else
		obj.Text = icon
	end
end

local function pill(parent, pos, icon, color)
	local f = glass(parent, UDim2.fromOffset(240, 44), pos, Vector2.new(1, 0))
	local ic = UI.Icon(f, icon, 46, { Position = UDim2.fromOffset(0, -2), Name = "PillIcon" })
	local label = UI.Text(f, "0", 24, color, "Number", { Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(46, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local _ = ic
	return f, label
end

-- ===== Level ring: left half = Base EXP (green), right half = Job EXP (class color) =====
-- Both halves fill from the bottom up to the top. Built from chunky rotated segments (no image assets needed).
local SEGMENTS = 13
local RING_SIZE = 148
local ring -- { frame, scale, base = {segs}, job = {segs}, shown = {base, job}, target = {base, job}, hold, jobColor }

local function buildRing(parent, pos)
	local frame = New("Frame", { Size = UDim2.fromOffset(RING_SIZE, RING_SIZE), Position = pos, BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	local sc = New("UIScale", { Parent = frame })
	-- v0.24.12 (owner): the dark disc behind the ring is a soft fade now (no hard grey plate / thick outline)
	local disc = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 12, 22), BackgroundTransparency = 0.25, ZIndex = 3, Parent = frame })
	disc:SetAttribute("PxKeep", true)
	disc.Visible = false -- v0.25.30 (owner): no dark fade behind the portrait, it read as a box
	UI.Corner(disc, RING_SIZE)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.6) }),
		Parent = disc,
	})
	-- v0.25.113 (owner drew it): the ring is a SQUARE frame of segments around the square portrait. Each half runs
	-- from the level badge (bottom middle) along the bottom edge, up its side and along the top to the middle.
	local c, h = RING_SIZE / 2, RING_SIZE / 2 - 18 -- v0.25.122 (owner): cells hug the gold portrait frame
	-- v0.25.121 (owner: uneven ticks, jumbled corners): equal square cells on one pitch, a cell ON each corner, so the
	-- column and the rows join into one closed square. Per half: 1 bottom cell beside the badge, bottom corner, 7 up
	-- the side, top corner, 3 along the top (gap at the top middle) = SEGMENTS
	local pitch = 2 * h / 8
	local cells = { { c - h + pitch, c + h } }
	for k = 0, 8 do
		table.insert(cells, { c - h, c + h - k * pitch })
	end
	for k = 1, 3 do
		table.insert(cells, { c - h + k * pitch, c - h })
	end
	assert(#cells == SEGMENTS)
	local segs = { base = {}, job = {} }
	for _, half in ipairs({ "base", "job" }) do
		for i = 1, SEGMENTS do
			local x, y = cells[i][1], cells[i][2]
			if half == "job" then
				x = 2 * c - x
			end
			local seg = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = T.PanelDeep,
				ZIndex = 4,
				Parent = frame,
			})
			UI.Corner(seg, 3)
			UI.Stroke(seg, T.Edge, 1.5)
			segs[half][i] = seg
		end
	end
	-- portrait
	local face = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RING_SIZE - 58, RING_SIZE - 58), BackgroundColor3 = T.Ocean, ZIndex = 5, Parent = frame })
	UI.Corner(face, RING_SIZE)
	local faceStroke = UI.Stroke(face, T.Gold, 3.5)
	-- v0.25.113 (owner reference): pixel halftone burst in the class color behind the head
	local _, setFaceFx = UI.Halftone(face, T.Purple, { z = 5, cells = 9, size = UDim2.fromScale(1.1, 1.1) })
	face.ClipsDescendants = true
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
		setFaceFx = setFaceFx,
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
					Audio.Play("Coin", { pitch = it.half == "base" and 0.95 or 1.08, volume = 0.22 })
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

local SkillLook = require(script.Parent.SkillLook)
local AmmoCfg = require(Shared.Config.Ammo)
local skillIconId, skillColor = SkillLook.IconId, SkillLook.Color

local function buildStatus()
	-- the card sits behind the ring; the ring overlaps its left edge
	-- v0.25.29 (owner reference): ONE framed character card: portrait + level ring, class • faction, HP / SP, EXP /
	-- JOB, boost timers (PC: bottom-left next to the hotbar; phones keep it top-left, the thumbstick is bottom-left)
	-- v0.25.119 (owner): the card tucks under the ring (ring in front), no channel between the ring and the card edge
	local card = glass(UI.Root, UDim2.fromOffset(460, 128), UDim2.fromOffset(60, 22))
	UI.Bevel(card, T.Bevel, 2, 0.3)
	statusCard = card
	buildRing(UI.Root, UDim2.fromOffset(14, 10))
	local name = UI.Text(card, player.DisplayName, 24, T.Text, "Display", { Position = UDim2.fromOffset(96, 6), Size = UDim2.new(1, -106, 0, 28), TextWrapped = false, Visible = false })
	-- v0.25.113 (owner): class • job and the EXP / JOB readouts are centered over the bars, in the pixel font
	local cls = UI.Text(card, "", 15, T.TextSoft, "Display", { Position = UDim2.fromOffset(96, 8), Size = UDim2.new(1, -108, 0, 20), TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center })
	New("UIStroke", { Color = T.Edge, Thickness = 2, Parent = cls })
	local holder = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 31), Size = UDim2.new(1, -108, 0, 46), Parent = card })
	UI.List(holder, nil, 5)
	bars = {
		hp = UI.Bar(holder, T.Green, UDim2.new(1, 0, 0, 22), "HP"),
		sp = UI.Bar(holder, T.Blue, UDim2.new(1, 0, 0, 18), "SP"),
		name = name,
		cls = cls,
	}
	-- EXP readouts that match the two ring halves
	local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 80), Size = UDim2.new(1, -108, 0, 18), Parent = card })
	UI.List(row, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center)
	bars.expText = UI.Text(row, "", 14, T.Green, "Display", { Size = UDim2.fromOffset(120, 18), TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center })
	bars.jobText = UI.Text(row, "", 14, T.Purple, "Display", { Size = UDim2.fromOffset(120, 18), TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center })
	New("UIStroke", { Color = T.Edge, Thickness = 2, Parent = bars.expText })
	New("UIStroke", { Color = T.Edge, Thickness = 2, Parent = bars.jobText })
	-- v0.24.12 (owner): Store boost timers (2x EXP / 2x DROP / FRUIT RADAR) sit right under the EXP readouts;
	-- Controllers/Heritage fills this row
	HUD.boostRow = New("Frame", { Name = "BoostRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 101), Size = UDim2.new(1, -108, 0, 20), Parent = card })
	UI.List(HUD.boostRow, Enum.FillDirection.Horizontal, 6)
	-- v0.25.113 (owner: frame too tall): the card only grows for the boost row while a boost is running
	local function fitCard()
		local any = false
		for _, ch in ipairs(HUD.boostRow:GetChildren()) do
			if ch:IsA("GuiObject") then
				any = true
			end
		end
		HUD.cardH = any and 128 or 106
		card.Size = UDim2.fromOffset(card.Size.X.Offset, HUD.cardH)
	end
	HUD.boostRow.ChildAdded:Connect(fitCard)
	HUD.boostRow.ChildRemoved:Connect(fitCard)
	fitCard()
	buffRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(170, 158), Size = UDim2.fromOffset(300, 30), Parent = UI.Root })
	-- v0.24.8 (owner): the party sits right under the player card as one horizontal strip (above the quest tracker):
	-- member chips with name + HP while in a party, else a PARTY button that opens the Party window
	local partyBar = glass(UI.Root, UDim2.fromOffset(400, 36), UDim2.fromOffset(16, 156))
	UI.Bevel(partyBar, T.Bevel, 2, 0.4)
	HUD.partyBar = partyBar
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = partyBar })
	local partyRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = partyBar })
	UI.List(partyRow, Enum.FillDirection.Horizontal, 6).VerticalAlignment = Enum.VerticalAlignment.Center
	local partyHp = {}
	local function renderParty()
		for _, c in ipairs(partyRow:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		partyHp = {}
		local members = State.party or {}
		if #members == 0 then
			local b = UI.Button(partyRow, "👥 PARTY", T.Green, UDim2.fromOffset(112, 26), function()
				Panels.Open("Party")
			end)
			b.Parent.LayoutOrder = 1
			HUD.partyWidth = 130 -- v0.25.30 (owner): just the PARTY button, no hint text
			partyBar.Size = UDim2.fromOffset(HUD.partyWidth, 36)
			return
		end
		for i, m in ipairs(members) do
			if type(m) == "table" and m.userId and m.userId ~= player.UserId then
				local chip = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(20, 22, 36), BackgroundTransparency = 0.15, Size = UDim2.fromOffset(94, 28), LayoutOrder = i, Parent = partyRow })
				UI.Stroke(chip, m.leader and T.Gold or Color3.fromRGB(90, 100, 130), 1.5)
				UI.Text(chip, (m.leader and "★" or "") .. tostring(m.name or "?"), 11, m.leader and T.Gold or T.Text, "Bold", { Position = UDim2.fromOffset(4, 1), Size = UDim2.new(1, -8, 0, 14), TextWrapped = false })
				local back = New("Frame", { BackgroundColor3 = Color3.fromRGB(40, 20, 24), BorderSizePixel = 0, Position = UDim2.new(0, 4, 1, -9), Size = UDim2.new(1, -8, 0, 6), Parent = chip })
				local fill = New("Frame", { BackgroundColor3 = T.Green, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = back })
				partyHp[m.userId] = fill
				chip.Activated:Connect(function()
					Panels.Open("Party")
				end)
			end
		end
	end
	-- (members: one chip each, the strip fits them)
	local function fitParty()
		local n = 0
		for _, c in ipairs(partyRow:GetChildren()) do
			if c:IsA("TextButton") then
				n += 1
			end
		end
		if n > 0 then
			HUD.partyWidth = 16 + n * 100
			partyBar.Size = UDim2.fromOffset(HUD.partyWidth, 36)
		end
	end
	State.Changed:Connect(function(kind)
		if kind == "party" then
			renderParty()
			fitParty()
		end
	end)
	-- PC layout (v0.25.29): the party strip sits right under the quest tracker / hunt card, wherever they end
	RunService.RenderStepped:Connect(function()
		if not HUD.bottomCard or not HUD.questFrame then
			return
		end
		local tr = HUD.questFrame
		local y = tr.Position.Y.Offset + (tr.Visible and tr.Size.Y.Offset + 8 or 60) -- 60: under the 52 px scroll button
		local hunt = UI.Root:FindFirstChild("HuntCard")
		if hunt and hunt.Visible then
			y = math.max(y, hunt.Position.Y.Offset + hunt.Size.Y.Offset + 8)
		end
		partyBar.Position = UDim2.fromOffset(16, y)
	end)
	renderParty()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for uid, fill in pairs(partyHp) do
				local pl = Players:GetPlayerByUserId(uid)
				local hum = pl and pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
				local k = hum and math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1) or 0
				fill.Size = UDim2.fromScale(k, 1)
				fill.BackgroundColor3 = k > 0.5 and T.Green or (k > 0.25 and T.Gold or T.Red)
			end
		end
	end)
	UI.List(buffRow, Enum.FillDirection.Horizontal, 6)

	-- one compact row of currencies (was three tall pills)
	-- v0.25.29 (owner reference): top-right = separate framed pills (coins, bounty, gems), easy to read at a glance
	local row = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(470, 42), Parent = UI.Root })
	row.Name = "CurrencyRow" -- Readability fits the compass between the MENU button and this row
	UI.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right).VerticalAlignment = Enum.VerticalAlignment.Center
	local function segment(order, icon, color, width, tip)
		local seg = glass(row, UDim2.fromOffset(width, 40), UDim2.new())
		seg.LayoutOrder = order
		UI.Bevel(seg, T.Bevel, 2, 0.35)
		local ic = UI.Icon(seg, icon, 36, { Name = "PillIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0) })
		local label = UI.Text(seg, "0", 20, color, "Number", { Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0), TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Right })
		if tip then
			UI.Tooltip(seg, tip)
		end
		return seg, label, ic
	end
	local _, ml = segment(1, UI.CurrencyIcon, T.Gold, 150, function()
		return "<b>Doubloons</b>\nEarned from monsters, ships and bosses.", T.Gold
	end)
	money = ml
	local _, bl, bic = segment(2, "☠", T.Pirate, 128, function()
		return "<b>Bounty / Merit</b>\nPirates earn Bounty, Marines earn Merit.", T.Pirate
	end)
	bounty = { label = bl, icon = bic }
	local _, pl = segment(3, PearlsCfg.Icon, Color3.fromRGB(150, 225, 255), 120, function()
		return "<b>Gems</b>\nEarned from chests, exploring, story quests and MVP bosses. Spend them in the Gem Shop or trade them in stalls (Lv." .. PearlsCfg.Trade.MinLevel .. "+).", Color3.fromRGB(150, 225, 255)
	end)
	HUD.pearls = pl
	pointsBtn = UI.Button(UI.Root, "+ POINTS", T.Gold, UDim2.fromOffset(150, 40), function()
		Panels.Open("Stats")
	end)
	pointsBtn.Parent.AnchorPoint = Vector2.new(1, 0)
	pointsBtn.Parent.Position = UDim2.new(1, -16, 0, 64)
	-- build stamp (bottom-right): tells you which version of the code Studio is running
	UI.Text(UI.Root, "v" .. GameConfig.Version, 12, Color3.fromRGB(220, 220, 235), "Bold", { Name = "Version", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -2), Size = UDim2.fromOffset(120, 14), TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.35 })
	orbLayer = New("Frame", { Name = "OrbLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = UI.Root })
end

-- Anime-Vanguards-style menu: square colored tiles with a big icon, a label and a key hint, in two columns
-- Every window with its icon, color, hotkey and label. main = shown as a tile; the rest live in the MENU hub.
-- v0.25.29 (owner): each tile has its own color pair (bg) and a particle theme (fx) that says what it is:
-- coins in the Bag, twinkling stars in Skills, sea bubbles on the Map / Ships, paws in Pets, gems + gold coins in the
-- Store, green pluses in Stats / Party, your faction's flags in Guild, skulls + embers for Bosses, gears in Settings
local function hex(h)
	return Color3.fromHex(h)
end
local MENU = {
	{ "🎒", "Inventory", T.Ocean, "I", "Bag", main = true, fx = { icons = { "coin" }, color = hex("FFE297") } },
	{ "✨", "Skills", hex("6852AD"), "K", "Skills", main = true, bg = { hex("6852AD"), hex("352259") }, fx = { color = hex("FFF195"), star = 0.85 } },
	{ "📜", "Quests", T.Gold:Lerp(T.Orange, 0.4), "J", "Quests", main = true, fx = { icons = { "scroll" }, iconFrac = 0.35, color = hex("FFE7B0") } },
	{ "🗺️", "Map", T.Ocean, "M", "Map", main = true, fx = { bubble = true, color = hex("B8F0FF"), star = 0.15 } },
	{ "🐾", "Pets", T.Green:Lerp(T.Ocean, 0.3), "N", "Pets", main = true, fx = { icons = { "paw" }, color = hex("D8FFE0") } },
	{ "🛍️", "PearlShop", hex("846030"), "H", "Store", main = true, bg = { hex("846030"), hex("513648") }, fx = { icons = { "gem", "coin" }, color = hex("FFE297"), star = 0.2 } },
	{ "📊", "Stats", T.Purple, "Y", "Stats", main = true, fx = { plus = true, star = 0.9, color = hex("7DFF8E") } },
	{ "ship", "SummonShip", T.OceanDark, nil, "Ships", fx = { bubble = true, color = hex("B8F0FF"), star = 0.15 } }, -- calls / stores the ship (editing = Shipwright NPC)
	{ "🏴", "Guild", hex("A44C64"), "G", "Crew", bg = { hex("A44C64"), hex("58293F") }, stripes = hex("FFC6A8"), fx = { icons = { "flag" }, faction = true, color = hex("FFC6A8") } },
	{ "👥", "Party", T.Green, "P", "Party", fx = { plus = true, star = 0.9, color = hex("C8FFC8") } },
	{ "👑", "BossBoard", hex("AC404F"), "B", "Bosses", bg = { hex("AC404F"), hex("541E35") }, fx = { icons = { "skull" }, iconFrac = 0.35, color = hex("FF9373"), star = 0 } },
	{ "⚙️", "Settings", T.Grey, "O", "Settings", fx = { icons = { "gear" }, color = hex("D8DCEA") } },
}
HUD.Menu = MENU
Panels.MenuItems = MENU

local function menuTile(parent, it)
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(74, 78), Parent = parent })
	local shadow = New("Frame", { Name = "Shadow", BackgroundColor3 = T.Edge, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 5), Parent = holder })
	UI.Corner(shadow, 14)
	local tile = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, -4), Parent = holder })
	UI.Corner(tile, 14)
	-- v0.25.28 (owner reference "Pixel UI & Icons"): a dark slot tinted by the tile's color with a colored bevel, and
	-- the icon glowing on an aura of that color (instead of a flat bright fill with stripes)
	New("UIGradient", { Name = "Fill", Color = ColorSequence.new(T.PanelTop:Lerp(it[3], 0.45), T.PanelDeep:Lerp(it[3], 0.18)), Rotation = 90, Parent = tile })
	UI.Stroke(tile, T.Edge, 3)
	UI.Bevel(tile, UI.Shade(it[3], 0.2), 2, 0.1)
	New("ImageLabel", { BackgroundTransparency = 1, Image = require(game:GetService("ReplicatedStorage").Shared.Config.Textures).glow, ImageColor3 = UI.Shade(it[3], 0.3), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(84, 84), Parent = tile })
	-- v0.25.17 / v0.25.29 (owner): the tile's own colors + its themed floating particles + a shine sweeping across
	UI.DressMenuTile(tile, it, 7)
	UI.Shine(tile, math.random())
	UI.Icon(tile, it[1], 54, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) })
	UI.Text(tile, string.upper(it[5]), 14, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -4), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	if it[4] then
		local key = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.PanelDeep, ZIndex = 3, Parent = tile })
		UI.Corner(key, 6)
		UI.Stroke(key, T.Edge, 2)
		local cap = UI.Text(key, Hotkeys.Label(it[2]), 13, T.Gold, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		Hotkeys.Changed.Event:Connect(function()
			cap.Text = Hotkeys.Label(it[2])
		end)
	end
	UI.Tactile(tile)
	tile.Activated:Connect(function()
		Panels.Toggle(it[2])
	end)
	-- red count badge (unspent stat / skill points)
	local badge = New("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 22), BackgroundColor3 = T.Red, Visible = false, ZIndex = 6, Parent = tile })
	UI.Corner(badge, 11)
	UI.Stroke(badge, T.Edge, 2)
	UI.Text(badge, "", 13, Color3.new(1, 1, 1), "Number", { Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	HUD.badges = HUD.badges or {}
	HUD.badges[it[2]] = badge
	return tile
end

local function buildMenu()
	-- top-anchored under the currency pills so it never runs into the skill bar or the mobile attack button
	local menu = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 116), Size = UDim2.fromOffset(158, 344), BackgroundTransparency = 1, Parent = UI.Root })
	menuFrame = menu
	menuScale = New("UIScale", { Parent = menu })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(74, 78), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = menu })
	for _, it in ipairs(MENU) do
		if it.main then
			menuTile(menu, it)
		end
	end
	menuTile(menu, { "anchor", "MenuHub", Color3.fromRGB(70, 60, 110), "L", "Menu", fx = { icons = { "anchor" }, color = Color3.fromHex("C9D4F0") } })
	-- v0.25.21 (owner): a tab on the left of the tiles folds the whole menu column away (and back)
	local tab, tabHolder = UI.Button(UI.Root, "▶", T.PanelDeep, UDim2.fromOffset(24, 56), function() end)
	UI.Bevel(tab, T.Bevel, 2, 0.3) -- v0.25.29: kept (owner), framed like the rest
	tab.TextScaled = false
	tab.TextSize = 14
	tab.Activated:Connect(function()
		menu.Visible = not menu.Visible
		tab.Text = menu.Visible and "▶" or "◀"
	end)
	-- placed in the menu's own coordinates (the HUD root is scaled, pixel math put the tab in the wrong corner):
	-- just left of the tiles, or at the screen edge where the column was when folded
	tabHolder.AnchorPoint = Vector2.new(1, 0)
	RunService.RenderStepped:Connect(function()
		local w = menu.Size.X.Offset * menuScale.Scale
		tabHolder.Position = menu.Position + UDim2.fromOffset(menu.Visible and (-w - 6) or 0, 0)
		tabHolder.Visible = not UI.AnyOpen()
	end)
	-- v0.25.44: window keys come from Controllers/Hotkeys (rebindable; CAS, so the camera's I / O zoom no longer eats
	-- the Bag key)
	for _, it in ipairs(MENU) do
		if it[4] then
			Hotkeys.On(it[2], function()
				Panels.Toggle(it[2])
			end)
		end
	end
	Hotkeys.On("MenuHub", function()
		Panels.Toggle("MenuHub")
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			UI.CloseAll()
		end
	end)
end

-- one square slot (skills and quick items share the look): returns the parts refresh() updates
local SLOT = 62
local function makeSlot(parent, keyText, order)
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT + 4), LayoutOrder = order, Parent = parent })
	local base = New("Frame", { Name = "Shadow", BackgroundColor3 = T.Edge, Size = UDim2.fromOffset(SLOT, SLOT), Position = UDim2.fromOffset(0, 4), Parent = holder })
	UI.Corner(base, 12)
	local slot = New("TextButton", { Size = UDim2.fromOffset(SLOT, SLOT), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = holder })
	UI.Corner(slot, 12)
	local grad = New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = slot })
	local stroke = UI.Stroke(slot, T.Edge, 3)
	local name = UI.Text(slot, "", 12, T.Text, "Bold", { Size = UDim2.new(1, -6, 1, -18), Position = UDim2.fromOffset(3, 14), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	local keyBox = New("Frame", { BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.15, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(#keyText > 1 and 24 or 18, 17), ZIndex = 7, Parent = slot })
	UI.Corner(keyBox, 5)
	local key = UI.Text(keyBox, keyText, 13, T.Gold, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
	-- one line, the full slot width (v0.25.42, owner: "10 SP" wrapped onto two lines over the icon)
	local count = UI.Text(slot, "", 12, T.Text, "Number", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -2), Size = UDim2.new(1, -6, 0, 14), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 7 })
	New("UIStroke", { Color = T.Edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = count })
	local cd = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 5, Parent = slot })
	UI.Corner(cd, 12)
	local cdText = UI.Text(slot, "", 24, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	local autoDot = New("Frame", { BackgroundColor3 = T.Green, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -15, 0, 3), Visible = false, ZIndex = 7, Parent = slot })
	UI.Corner(autoDot, 6)
	UI.Stroke(autoDot, T.Edge, 1.5)
	UI.Tactile(slot)
	local icon = New("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SLOT - 14, SLOT - 14), Visible = false, ZIndex = 2, Parent = slot })
	return { slot = slot, holder = holder, icon = icon, name = name, cd = cd, cdText = cdText, auto = autoDot, sp = count, count = count, grad = grad, stroke = stroke, key = key, base = base }
end

local function row(parent, order)
	local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, SLOT + 4), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, Parent = parent })
	UI.List(r, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Bottom
	return r
end

-- Hotbar (v0.25.71, owner): main row = race mode, Dash, the 6 SET buttons (keys 1-6: Class / Fruit / Basic / three
-- Toki), potions F1 F2, ammo, AUTO; the row above = E R F Z X C, the skills of the picked set (Shared/Modules/SkillSets).
local itemSlots, barRows
local setSlots = {}
-- the icon a set button shows
local SET_ICON = { Basic = "anchor", Armament = "toki_arm", Observation = "toki_obs", Conqueror = "toki_conq" }
local SET_LABEL = { Class = "CLASS", Fruit = "FRUIT", Basic = "BASIC", Armament = "ARM", Observation = "OBS", Conqueror = "CONQ" }
local function setIcon(p, set)
	if set.id == "Class" then
		local c = p and ClassesCfg.Classes[p.class]
		return c and c.icon or "sword"
	elseif set.id == "Fruit" then
		return p and p.fruit and ("fruit_" .. string.lower(p.fruit.id)) or "fruit_unknown"
	end
	return SET_ICON[set.id] or "skills"
end

-- a drawn bullet (round pellet with a shine): ammo has no rendered icons
function HUD.Pellet(parent, color, size)
	local f = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = parent })
	UI.Corner(f, size)
	local g = New("UIGradient", { Name = "Tint", Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), color:Lerp(Color3.new(0, 0, 0), 0.35)), Rotation = 60, Parent = f })
	UI.Stroke(f, T.Edge, 2.5)
	local shine = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Position = UDim2.fromScale(0.2, 0.16), Size = UDim2.fromScale(0.3, 0.22), ZIndex = 5, Parent = f })
	UI.Corner(shine, size)
	local _ = g
	return f
end
local function tintPellet(f, color)
	local g = f:FindFirstChild("Tint")
	if g then
		g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), color:Lerp(Color3.new(0, 0, 0), 0.35))
	end
end

local function ammoCount(p, a)
	if not a.item then
		return math.huge
	end
	local n = 0
	for _, e in ipairs(p.inventory or {}) do
		if e.id == a.item then
			n += e.qty or 1
		end
	end
	return n
end

-- the ammo picker pops up above the bullet button: every kind with how many you carry; tap one, then "Load"
local picker
function HUD.ToggleAmmoPicker()
	if picker then
		picker:Destroy()
		picker = nil
		return
	end
	local p = State.profile
	if not p then
		return
	end
	local chosen = p.ammo or AmmoCfg.Default
	-- pops up right above the bullet button (it used to open at the right edge, on top of the menu)
	local pos = UDim2.new(1, -16, 1, -(SLOT * 2 + 34))
	local anchor = Vector2.new(1, 1)
	pcall(function()
		local b = HUD.ammo.btn
		local sc = UI.GetScale()
		local cx = (b.AbsolutePosition.X + b.AbsoluteSize.X / 2) / sc
		local top = b.AbsolutePosition.Y / sc
		local canvasW = UI.Root.AbsoluteSize.X / sc
		cx = math.clamp(cx, 200, canvasW - 200)
		pos = UDim2.fromOffset(cx, top - 10)
		anchor = Vector2.new(0.5, 1)
	end)
	picker = New("Frame", { AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(380, 330), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 30, Parent = UI.Root })
	UI.Corner(picker, 16)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = picker })
	UI.Stroke(picker, T.Edge, 3)
	UI.Pop(picker)
	local function draw()
		for _, c in ipairs(picker:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		UI.Text(picker, "AMMO", 20, T.Gold, "Display", { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(200, 24), ZIndex = 31 })
		local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 160), ZIndex = 31, Parent = picker })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(78, 76), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
		for _, a in ipairs(AmmoCfg.List) do
			local n = ammoCount(p, a)
			local isSel = a.id == chosen
			local cell = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = isSel and T.Gold:Lerp(T.Panel, 0.5) or T.Panel, ZIndex = 32, Parent = grid })
			UI.Corner(cell, 12)
			UI.Stroke(cell, isSel and T.Gold or T.Edge, isSel and 4 or 2.5)
			local pel = HUD.Pellet(cell, a.color, 34)
			pel.ZIndex = 33
			UI.Text(cell, n == math.huge and "∞" or tostring(n), 13, n == 0 and T.Red or T.Text, "Number", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(40, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 34 })
			if a.id == (p.ammo or AmmoCfg.Default) then
				UI.Text(cell, "IN USE", 10, T.Green, "Display", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(50, 12), ZIndex = 34 })
			end
			UI.Tactile(cell)
			cell.Activated:Connect(function()
				chosen = a.id
				draw()
			end)
		end
		local a = AmmoCfg.ById[chosen]
		UI.Text(picker, a.name, 18, a.color:Lerp(Color3.new(1, 1, 1), 0.3), "Display", { Position = UDim2.fromOffset(14, 210), Size = UDim2.new(1, -28, 0, 22), ZIndex = 31 })
		UI.Text(picker, a.desc .. (a.item and ("\nBuy at the General Store (" .. UI.CurrencyIcon .. " " .. a.price .. " each).") or ""), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(14, 234), Size = UDim2.new(1, -28, 0, 36), ZIndex = 31 })
		local inUse = a.id == (p.ammo or AmmoCfg.Default)
		local _, h = UI.Button(picker, inUse and "In use" or "Load", inUse and T.Grey or T.Green, UDim2.fromOffset(160, 44), function()
			if inUse then
				return
			end
			task.spawn(function()
				local res = Net.Request("SetAmmo", { id = a.id })
				if res.msg then
					UI.Toast(res.msg, res.ok and "good" or "bad")
				end
				if res.ok then
					p.ammo = a.id
					Audio.Play("Equip")
					if picker then
						draw()
					end
				end
			end)
		end)
		h.AnchorPoint = Vector2.new(0.5, 1)
		h.Position = UDim2.new(0.5, 0, 1, -10)
		h.ZIndex = 32
	end
	draw()
end
HUD.TintPellet = tintPellet
HUD.AmmoCount = ammoCount

local function buildSkillBar()
	local bar = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(900, 2 * (SLOT + 4) + 8), BackgroundTransparency = 1, Parent = UI.Root })
	HUD.hotbar = bar
	local vlist = UI.List(bar, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	vlist.VerticalAlignment = Enum.VerticalAlignment.Bottom
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	local second = row(bar, 1)
	local main = row(bar, 2)
	barRows = { main = main, second = second }
	for _, r in ipairs({ second, main }) do
		r:FindFirstChildOfClass("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	end

	-- Dash (Q) opens the bar; AUTO sits at the far end (after the ammo button for slingshot users)
	local dash = makeSlot(main, "Q", 0)
	dash.name.Text = "DASH"
	dash.name.TextSize = 13
	UI.Icon(dash.slot, "dash", 34, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), ZIndex = 3 })
	dash.name.Position = UDim2.new(0, 3, 1, -20)
	dash.name.Size = UDim2.new(1, -6, 0, 16)
	dash.grad.Color = ColorSequence.new(T.Ocean:Lerp(Color3.new(1, 1, 1), 0.2), T.Ocean:Lerp(Color3.new(0, 0, 0), 0.45))
	dash.slot.Activated:Connect(function()
		Combat.Dash()
	end)
	UI.Tooltip(dash.slot, function()
		return "<b>Dash</b>  [Q]\nA quick burst the way you move (or face). " .. GameConfig.Dash.Cooldown .. "s cooldown.", T.Ocean
	end)
	HUD.dashSlot = dash
	-- the second row starts where the skills start (under it sits the Dash button)
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = 0, Parent = second })
	-- heritage mode (Cinderwing FLAME / CALM, key V; G is the Guild window): a fire slot left of Dash, lit or dark; hidden for other heritages
	local her = makeSlot(main, "V", -1)
	her.name.Text = "FLAME"
	her.name.TextSize = 12
	her.name.Position = UDim2.new(0, 3, 1, -20)
	her.name.Size = UDim2.new(1, -6, 0, 16)
	local herIcon = UI.Icon(her.slot, "flame", 34, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), ZIndex = 3 })
	local herSpacer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = -1, Parent = second })
	local LooksCfg = require(Shared.Config.Looks)
	local function refreshHeritage()
		local h = LooksCfg.HeritageById[player:GetAttribute("Heritage") or ""]
		local show = h ~= nil and h.modes == true
		her.holder.Visible = show
		herSpacer.Visible = show
		local lit = player:GetAttribute("HeritageMode") ~= "calm"
		her.name.Text = lit and "FLAME" or "CALM"
		if herIcon:IsA("ImageLabel") then
			herIcon.ImageTransparency = lit and 0 or 0.35
		else
			herIcon.TextTransparency = lit and 0 or 0.55
		end
		if herIcon:IsA("ImageLabel") then
			herIcon.Image = UI.IconId(lit and "flame" or "calm") or ""
		end
		her.grad.Color = lit and ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(150, 40, 20)) or ColorSequence.new(T.PanelTop, T.PanelDeep)
	end
	her.slot.Activated:Connect(function()
		task.spawn(function()
			local res = Net.Request("HeritageMode")
			if res.msg then
				UI.Toast(res.msg, res.ok and "good" or "bad")
			end
		end)
	end)
	UI.Tooltip(her.slot, function()
		return "<b>Race mode</b>  [V]\nFLAME: +25% ATK/MATK.  CALM: +20% speed, +10% FLEE.", T.Orange
	end)
	player:GetAttributeChangedSignal("Heritage"):Connect(refreshHeritage)
	player:GetAttributeChangedSignal("HeritageMode"):Connect(refreshHeritage)
	refreshHeritage()
	HUD.heritageSlot = her

	skillSlots = {}
	Hotkeys.Changed.Event:Connect(function()
		for i, s in ipairs(skillSlots) do
			s.key.Text = Combat.SKILL_KEY_LABELS[i]
		end
		for n, s in ipairs(setSlots) do
			s.key.Text = Hotkeys.Label("Set" .. n)
		end
	end)
	-- the 6 set buttons on the main row
	for n, set in ipairs(SkillSets.Sets) do
		local s = makeSlot(main, Hotkeys.Label("Set" .. n), n)
		setSlots[n] = s
		s.set = set
		s.name.Position = UDim2.new(0, 3, 1, -18)
		s.name.Size = UDim2.new(1, -6, 0, 15)
		s.name.TextSize = 10
		s.name.ZIndex = 4
		s.icon.Size = UDim2.fromOffset(SLOT - 26, SLOT - 26)
		s.sp.TextXAlignment = Enum.TextXAlignment.Center
		s.sp.AnchorPoint = Vector2.new(0.5, 1)
		s.sp.Position = UDim2.new(0.5, 0, 1, -2)
		s.sp.TextSize = 10
		s.icon.Position = UDim2.fromScale(0.5, 0.42)
		s.slot.Activated:Connect(function()
			Combat.SetActiveSet(n)
		end)
		UI.Tooltip(s.slot, function()
			local p = State.profile
			local list = {}
			for _, e in ipairs(SkillSets.Skills(p, n)) do
				table.insert(list, (e.ready and "" or "(locked) ") .. e.skill.name)
			end
			local open = SkillSets.Open(p, n)
			return "<b>Set " .. n .. ": " .. set.name .. "</b>  [" .. Hotkeys.Label("Set" .. n) .. "]\n"
				.. (open and (#list > 0 and table.concat(list, " • ") or "No skills yet") or (set.id == "Fruit" and "Eat a Cursed Fruit to unlock" or "You do not have this Toki yet"))
				.. "\nAuto Battle: " .. (SkillSets.Auto(p, n) and "uses this set" or "skips this set"), T.Gold
		end)
	end
	-- the skills of the picked set on the row above (E R F Z X C)
	for i = 1, GameConfig.SkillBarSize do
		local s = makeSlot(second, Combat.SKILL_KEY_LABELS[i], i)
		skillSlots[i] = s
		-- v0.25.50 (owner): on touch, hold the skill button and drag to aim (manual mode), lift to cast
		local touchAimed = false
		s.slot.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			touchAimed = false -- (a drag that ended off the button never got its Activated)
			local id = Combat.BarId(i)
			if id and id ~= "" and Combat.AimableSkill(id) then
				touchAimed = Combat.TouchAim(id, i, input)
			end
		end)
		s.slot.Activated:Connect(function()
			if touchAimed then
				touchAimed = false -- the aim casts it when the finger lifts
				return
			end
			local id = Combat.BarId(i)
			local e = SkillSets.Skills(State.profile, Combat.ActiveSet())[i]
			if id and id ~= "" then
				Combat.CastSkill(id)
			elseif e then
				UI.Toast(e.skill.fruit and ("Needs Fruit Mastery " .. (e.skill.mastery or 1)) or (e.skill.name .. ": learn it in the Skills window"), "bad")
			else
				Panels.Open("Skills", { tab = "Sets" })
			end
		end)
		s.slot.MouseEnter:Connect(function()
			local id = Combat.BarId(i)
			Readability.HoverSkill = (id and id ~= "") and id or nil
		end)
		s.slot.MouseLeave:Connect(function()
			Readability.HoverSkill = nil
		end)
		UI.Tooltip(s.slot, function()
			local p = State.profile
			local e = SkillSets.Skills(p, Combat.ActiveSet())[i]
			local sk = e and e.skill
			if not sk then
				return "Empty: this set has no skill here", T.TextSoft
			end
			local lvText = sk.fruit and ("Mastery " .. (p.fruit and p.fruit.mastery or 0)) or ("Lv." .. (p.skills[sk.id] or 0))
			return string.format("<b>%s</b>  %s\n%s\nSP %d  •  Cooldown %ss", sk.name, lvText, sk.desc or "", sk.sp, sk.cd), skillColor(sk)
		end)
	end
	-- a little gap between skills and items
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 4), LayoutOrder = 50, Parent = main })
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 4), LayoutOrder = 50, Parent = second })
	-- v0.25.55 (owner reference): F1 = HP potion, F2 = SP potion. A gear on each slot opens the picker (which potion +
	-- auto drink below %), the threshold sits above the slot
	itemSlots = {}
	for i = 1, 2 do
		local kind = i == 1 and "hp" or "sp"
		local s = makeSlot(main, "F" .. i, 100 + i)
		s.kind = kind
		itemSlots[i] = s
		s.pct = UI.Text(s.holder, "", 10, T.Gold, "Number", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 0, -1), Size = UDim2.new(1, -14, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false }) -- v0.25.99: left of the gear (centered it ran under it)
		New("UIStroke", { Color = T.Edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = s.pct })
		local gear = New("ImageButton", { BackgroundColor3 = T.PanelDeep, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(20, 20), ZIndex = 9, Parent = s.holder })
		UI.Corner(gear, 10)
		UI.Stroke(gear, T.Edge, 1.5)
		UI.Icon(gear, "gear", 16, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 10 })
		gear.Activated:Connect(function()
			Panels.Open("Potion", { kind = kind })
		end)
		s.slot.Activated:Connect(function()
			Combat.UsePotion(kind)
		end)
		UI.Tooltip(s.slot, function()
			local _, show = Combat.PotionPick(kind)
			local def = ItemDB.Get(show or "")
			return "<b>" .. (kind == "hp" and "HP potion" or "SP potion") .. "</b>  [F" .. i .. "]\n" .. (def and def.name or "") .. "\nGear: pick the potion and when it drinks by itself", kind == "hp" and T.Red or T.Ocean
		end)
	end
	-- the skill row stays lined up over the set buttons: spacers for the potion slots
	for i = 1, 2 do
		New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = 100 + i, Parent = second })
	end

	-- v0.25.3 (owner): reads AUTO or MANUAL (not "AUTO ON"), with a pixel icon above the word
	-- v0.25.28 (owner reference: a switch): dark plate, the word on the left, a sliding switch on the right
	autoBtn = UI.Button(main, "MANUAL", T.PanelTop, UDim2.fromOffset(132, SLOT), function()
		Combat.ToggleAuto()
	end)
	autoBtn.Parent.LayoutOrder = 220
	autoBtn.TextXAlignment = Enum.TextXAlignment.Left
	local pad = autoBtn:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingRight = UDim.new(0, 50)
	end
	local track = New("Frame", { Name = "SwitchTrack", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 44, 0.5, 0), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = T.Grey, ZIndex = autoBtn.ZIndex + 2, Parent = autoBtn })
	UI.Stroke(track, T.Edge, 2)
	New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), ZIndex = autoBtn.ZIndex + 3, Parent = track })
	local knob = New("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(246, 234, 204), ZIndex = autoBtn.ZIndex + 4, Parent = track })
	UI.Stroke(knob, T.Edge, 2)
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(5, 5), Position = UDim2.fromOffset(2, 2), ZIndex = autoBtn.ZIndex + 5, Parent = knob })
	HUD.autoSwitch = { track = track, knob = knob }
	UI.Tooltip(autoBtn, function()
		return State.auto and "<b>AUTO</b>  [" .. Hotkeys.Label("Auto") .. "]\nFights monsters within your search range (gear button), uses ticked skills and eats food. Tap for MANUAL."
			or "<b>MANUAL</b>  [" .. Hotkeys.Label("Auto") .. "]\nYou aim and attack yourself. Tap for AUTO.", T.Green
	end)
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(132, SLOT), LayoutOrder = 220, Parent = second })
	-- v0.25.44 (owner): a gear right of the switch opens the Auto Battle settings (search range, eat below)
	local gearBtn, gh = UI.Button(main, "", T.PanelTop, UDim2.fromOffset(40, SLOT), function()
		Panels.Toggle("AutoBattle")
	end)
	gh.LayoutOrder = 221
	UI.Icon(gearBtn, "gear", 30, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = gearBtn.ZIndex + 1 })
	UI.Tooltip(gearBtn, function()
		return "<b>Auto Battle settings</b>\nSearch range and when to eat", T.Green
	end)
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, SLOT), LayoutOrder = 221, Parent = second })

	-- ammo (slingshot classes): the loaded bullet, tap to pick another kind
	local ammoHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT + 4), LayoutOrder = 210, Visible = false, Parent = main })
	local ammoSpacer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = 210, Visible = false, Parent = second })
	local ammoBtn = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(SLOT, SLOT), BackgroundColor3 = Color3.new(1, 1, 1), Parent = ammoHolder })
	UI.Corner(ammoBtn, SLOT)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = ammoBtn })
	UI.Stroke(ammoBtn, T.Gold, 3)
	UI.Tactile(ammoBtn)
	local ammoIcon = HUD.Pellet(ammoBtn, Color3.new(1, 1, 1), 34)
	local ammoCount = UI.Text(ammoBtn, "", 13, T.Text, "Number", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.fromOffset(50, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	HUD.ammo = { holder = ammoHolder, spacer = ammoSpacer, btn = ammoBtn, icon = ammoIcon, count = ammoCount }
	-- v0.25.81 (owner): one ammo only (Musket Ball): the button just shows how many are left
	ammoBtn.Activated:Connect(function()
		local p = State.profile
		local a = AmmoCfg.ById[AmmoCfg.Default]
		UI.Toast((p and ammoCount(p, a) or 0) .. " " .. a.name .. "s left. Buy more at the General Store; bandits and gunners drop them.", "info")
	end)
	UI.Tooltip(ammoBtn, function()
		local a = AmmoCfg.ById[AmmoCfg.Default]
		return "<b>" .. a.name .. "s</b>\n" .. a.desc .. "\nGeneral Store, or dropped by bandits and gunners.", Color3.fromRGB(200, 200, 210)
	end)

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

-- ===== loot that flies =====
local function bump(gui)
	if not gui then
		return
	end
	local sc = gui:FindFirstChild("LootPop") or New("UIScale", { Name = "LootPop", Parent = gui })
	sc.Scale = 1.25
	UI.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD.FlyLoot(data)
	-- 3D first: the drops hop out of the monster and fly into you (VFX.LootMagnet), then the HUD flight below
	pcall(function()
		local VFXc = require(script.Parent.Parent.Controllers.VFX)
		local n = ((data.beli and data.beli > 0) and 5 or 0) + #(data.items or {}) * 2
		if n > 0 and typeof(data.pos) == "Vector3" then
			VFXc.LootMagnet(data.pos, n, { Color3.fromRGB(255, 205, 70), Color3.fromRGB(255, 240, 150), Color3.fromRGB(170, 230, 255) })
		end
	end)
	-- v0.25.8 (owner): drops fly into the character only (no more flight to the money counter / Bag tile);
	-- the sounds play as they reach you
	task.delay(0.55, function()
		if data.beli and data.beli > 0 then
			Audio.Play("Coin", { volume = 0.7, pitch = 0.95 + math.random() * 0.1 })
			if money then
				bump(money)
			end
		end
		if data.items and #data.items > 0 then
			Audio.Play("Pickup", { volume = 0.6 })
		end
	end)
end

function HUD.Loot(data)
	pcall(HUD.FlyLoot, data)
	local function add(text, rarityId, quiet)
		local tier = Rarity.Get(rarityId)
		local f = New("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), Parent = lootFeed })
		UI.Corner(f, 12)
		UI.RarityStyle(f, rarityId)
		UI.Pad(f, 6)
		UI.Text(f, text, 17, T.Text, "Bold", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), TextWrapped = false })
		UI.Pop(f, 0.5)
		if tier.rank >= 4 and not quiet then
			Audio.Play("Rarity" .. tier.id)
		end
		task.delay(3, function()
			UI.Tween(f, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			f:Destroy()
		end)
	end
	if data.beli and data.beli > 0 then
		-- gold style only: the Legendary jingle on every coin drop was the shrill "ping" the owner heard (v0.24.12)
		add("+" .. UI.Format(data.beli) .. " " .. UI.CurrencyIcon, "Legendary", true)
		-- kill combo: each loot within 4 s of the last plays the coin a little higher (resets when you stop)
		local now = os.clock()
		HUD.killStreak = (now - (HUD.lastLootAt or 0) < 4) and math.min((HUD.killStreak or 0) + 1, 12) or 0
		HUD.lastLootAt = now
		if not data.pos then
			Audio.Play("Coin", { pitch = 0.85 + math.min(HUD.killStreak, 5) * 0.02, volume = 0.7 })
		end
	end
	for _, it in ipairs(data.items or {}) do
		local def = ItemDB.Get(it.id)
		local reveal = not it.card and ItemReveal.Worth(def) -- v0.25.92: Rare+ items get the full-screen GET! moment
		add((it.card and "🃏 " or "") .. (def and def.name or it.id) .. "  x" .. it.qty, def and def.rarity or "Common", reveal)
		if reveal then
			ItemReveal.Play(def)
		end
		if it.card then
			if def then
				CardReveal.Play(def)
			else
				Audio.Play("CardDrop")
				UI.Banner("Card Drop!", it.id, Rarity.Get().color)
			end
		end
	end
	local frames = {}
	for _, c in ipairs(lootFeed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	for i = 1, #frames - 4 do
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
	local guild = player:GetAttribute("GuildName")
	local guildColor = faction == "Marine" and T.Marine or (faction == "Pirate" and T.Pirate or T.Gold)
	bars.cls.RichText = true
	bars.cls.Text = (fruitDef and (fruitDef.icon .. " ") or "") .. (cls and cls.icon or "") .. " " .. UI.Colored(player:GetAttribute("ClassName") or "", cls and cls.color or T.Text)
		.. "  •  Job Lv." .. (player:GetAttribute("JobLevel") or 1) .. (guild and ("  •  " .. UI.Colored(guild, guildColor)) or "")
	ring.jobColor = cls and (cls.ringColor or cls.color) or T.Purple
	ring.face.BackgroundColor3 = (cls and cls.color or T.Ocean):Lerp(Color3.fromRGB(10, 10, 20), 0.6)
	ring.setFaceFx(cls and cls.color or T.Ocean)
	bars.expText.Text = string.format("EXP %.1f%%", ring.target.base * 100)
	bars.jobText.Text = string.format("JOB %.1f%%", ring.target.job * 100)
	bars.jobText.TextColor3 = ring.jobColor
	ring.faceStroke.Color = faction == "Marine" and T.Marine or (faction == "Pirate" and T.Pirate or T.Gold)
	local beliNow = player:GetAttribute("Beli") or 0
	money.Text = beliNow >= 1000000 and UI.Short(beliNow) or UI.Format(beliNow)
	-- attribute (live) or the synced profile, whichever arrives first
	local prof = State.profile
	local pearls = player:GetAttribute("Pearls") or (prof and ((prof.pearls or 0) + (prof.pearlsBound or 0))) or 0
	HUD.pearls.Text = UI.Format(pearls)
	if faction == "Pirate" then
		setPillIcon(bounty.icon, "☠")
		bounty.label.Text = UI.Short(player:GetAttribute("Bounty") or 0)
		bounty.label.TextColor3 = T.Pirate
	elseif faction == "Marine" then
		setPillIcon(bounty.icon, "⚓")
		bounty.label.Text = UI.Format(player:GetAttribute("Merit") or 0) .. " Merit"
		bounty.label.TextColor3 = T.Marine
	else
		setPillIcon(bounty.icon, "🏳")
		bounty.label.Text = "Civilian"
		bounty.label.TextColor3 = T.TextSoft
	end
	local pts = (player:GetAttribute("StatPoints") or 0) + (player:GetAttribute("SkillPoints") or 0)
	-- unspent points show as red badges on the Stats / Skills tiles (the long "+ POINTS" button is gone)
	pointsBtn.Parent.Visible = false
	local _ = pts
	for panel, n in pairs({ Stats = player:GetAttribute("StatPoints") or 0, Skills = player:GetAttribute("SkillPoints") or 0 }) do
		local badge = HUD.badges and HUD.badges[panel]
		if badge then
			badge.Visible = n > 0
			local lbl = badge:FindFirstChild("Label")
			if lbl then
				lbl.Text = n > 99 and "99+" or tostring(n)
			end
		end
	end
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
	-- v0.25.71 set buttons: the picked one lit gold, locked ones dim, a green dot = Auto Battle uses it
	local p = State.profile
	local active = Combat.ActiveSet()
	for n, s in ipairs(setSlots) do
		local open = SkillSets.Open(p, n)
		local icon = setIcon(p, s.set)
		if s.lastIcon ~= icon then
			s.lastIcon = icon
			local img = UI.IconId(icon)
			s.icon.Image = img or ""
			s.icon.Visible = img ~= nil
			s.name.Text = img and "" or s.set.name
		end
		s.icon.ImageTransparency = open and 0 or 0.65
		s.sp.Text = SET_LABEL[s.set.id] or ""
		s.sp.TextColor3 = n == active and T.Gold or T.TextSoft
		local c = n == active and T.Gold or (open and T.PanelTop or T.PanelDeep)
		s.grad.Color = n == active and ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.1), c:Lerp(Color3.new(0, 0, 0), 0.55)) or ColorSequence.new(c, T.PanelDeep)
		s.stroke.Color = n == active and Color3.new(1, 1, 1) or T.Edge
		s.stroke.Thickness = n == active and 4 or 3
		s.auto.Visible = open and SkillSets.Auto(p, n)
	end
	-- the skills of the picked set (E R F Z X C)
	local now = os.clock()
	local setList = SkillSets.Skills(p, active)
	for i, s in ipairs(skillSlots) do
		local entry = setList[i]
		local id = entry and entry.skill.id
		local skill = entry and entry.skill or nil
		local iconId = skill and skillIconId(skill)
		s.icon.Image = iconId or ""
		s.icon.Visible = iconId ~= nil
		-- skill icons are full tiles already (gen_skill_icons.py): they fill the slot, no second frame inside it
		s.icon.Size = UDim2.fromScale(1, 1)
		-- with an icon the name moves to the tooltip; without one it stays as text
		s.name.Text = (skill and not iconId) and skill.name or ""
		s.sp.Text = skill and (skill.sp .. "SP") or ""
		s.sp.TextColor3 = Color3.fromRGB(150, 200, 255)
		local c = skillColor(skill)
		s.grad.Color = skill and ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.45)) or ColorSequence.new(T.PanelTop, T.PanelDeep)
		s.slot.BackgroundTransparency = skill and 0 or 0.35
		local left = skill and ((State.cooldowns[id] or 0) - now) or 0
		s.cd.Size = UDim2.new(1, 0, skill and left > 0 and math.clamp(left / skill.cd, 0, 1) or 0, 0)
		s.cdText.Text = (skill and left > 0) and string.format(left < 1 and "%.1f" or "%d", left) or ""
		s.auto.Visible = false
		s.icon.ImageTransparency = (entry and not entry.ready) and 0.65 or 0
		s.stroke.Color = (skill and (player:GetAttribute("SP") or 0) < skill.sp) and T.Red or T.Edge
	end
	-- dash cooldown sweep
	if HUD.dashSlot then
		local left = Combat.dashReadyAt - now
		HUD.dashSlot.cd.Size = UDim2.new(1, 0, left > 0 and math.clamp(left / GameConfig.Dash.Cooldown, 0, 1) or 0, 0)
		HUD.dashSlot.cdText.Text = left > 0 and string.format("%.1f", left) or ""
	end
	-- potion slots (v0.25.55): the potion it would drink now, how many are left, the auto-drink threshold
	for _, s in ipairs(itemSlots or {}) do
		local _, show = Combat.PotionPick(s.kind)
		local def = show and ItemDB.Get(show) or nil
		local _, byId = Combat.PotionsOwned(s.kind)
		local qty = def and byId[def.id] and byId[def.id].qty or 0
		local img = def and UI.ItemIconId(def)
		s.icon.Image = img or ""
		s.icon.Visible = img ~= nil
		s.icon.ImageTransparency = qty == 0 and 0.6 or 0
		s.name.Text = (def and not img) and def.name or ""
		s.count.Text = tostring(qty)
		s.count.TextColor3 = qty > 0 and T.Text or T.Red
		local pct = (p and p.settings and p.settings[s.kind .. "Pct"]) or Combat.POTION_PCT[s.kind]
		s.pct.Text = pct > 0 and ("<" .. pct .. "%") or "OFF"
		local c = s.kind == "hp" and T.Red or T.Ocean
		s.grad.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.1), c:Lerp(Color3.new(0, 0, 0), 0.55))
		s.slot.BackgroundTransparency = 0
	end
	-- ammo button: only for slingshot users
	if HUD.ammo and p then
		local wType = require(Shared.Modules.WeaponInfo).TypeOf(p)
		local shoots = AmmoCfg.Weapons[wType or ""] == true
		HUD.ammo.holder.Visible = shoots
		HUD.ammo.spacer.Visible = shoots
		if shoots then
			local a = AmmoCfg.ById[AmmoCfg.Default]
			tintPellet(HUD.ammo.icon, a.color)
			local n = ammoCount(p, a)
			HUD.ammo.count.Text = tostring(n)
			HUD.ammo.count.TextColor3 = n == 0 and T.Red or T.Text
		elseif picker then
			picker:Destroy()
			picker = nil
		end
	end
	autoBtn.Text = State.auto and "AUTO" or "MANUAL"
	autoBtn.TextColor3 = State.auto and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(225, 222, 245)
	local sw = HUD.autoSwitch
	if sw and sw.on ~= State.auto then
		sw.on = State.auto
		UI.Tween(sw.knob, 0.15, { Position = State.auto and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, Enum.EasingStyle.Back)
		UI.Tween(sw.track, 0.15, { BackgroundColor3 = State.auto and Color3.fromRGB(96, 196, 86) or T.Grey })
	end
	-- target
	-- v0.25.6 (owner): the target bar only while fighting it (its HP moved in the last 6 s) or for bosses, not
	-- whenever something is merely selected
	local tgt = State.target
	if tgt and tgt.Parent then
		local hpNow = tgt:GetAttribute("HP")
		if tgt ~= HUD.tgtSeen or hpNow ~= HUD.tgtHp then
			if tgt == HUD.tgtSeen then
				HUD.tgtHitAt = os.clock()
			end
			HUD.tgtSeen, HUD.tgtHp = tgt, hpNow
		end
	end
	local fighting = tgt and (tgt:GetAttribute("Boss") or os.clock() - (HUD.tgtHitAt or 0) < 6)
	if tgt and tgt.Parent and tgt.PrimaryPart and fighting then
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
		setHighlight(tgt and tgt.Parent and tgt or nil) -- still outlined while selected
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
	-- v0.25.29 (owner reference): PC = quest + party top-left, the character card bottom-left beside the hotbar,
	-- currencies top-right. Phones / small windows keep the card on top (thumbstick bottom-left, no room for both).
	local rowW = 1080
	local okW, absW = pcall(function()
		return barRows.main.AbsoluteSize.X
	end)
	if okW and absW and absW > 0 then
		rowW = absW / sc
	end
	local bottomCard = not compact and not UI.IsMobile and canvas.X >= 536 + rowW + 24
	HUD.bottomCard = bottomCard
	if bottomCard then
		statusCard.AnchorPoint = Vector2.new(0, 1)
		statusCard.Position = UDim2.new(0, 60, 1, -14)
		statusCard.Size = UDim2.fromOffset(460, HUD.cardH or 106)
		ring.frame.Position = UDim2.new(0, 14, 1, -166)
		buffRow.AnchorPoint = Vector2.new(0, 1)
		buffRow.Position = UDim2.new(0, 170, 1, -146)
		if HUD.hotbar then
			-- v0.25.30 (owner: the card and the hotbar overlapped): the bar starts right after the card
			HUD.hotbar.AnchorPoint = Vector2.new(0, 1)
			HUD.hotbar.Position = UDim2.new(0, 536, 1, -12)
			HUD.hotbar:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	else
		statusCard.AnchorPoint = Vector2.zero
		ring.frame.Position = UDim2.fromOffset(14, topY)
		statusCard.Position = UDim2.fromOffset(60, topY + 12)
		statusCard.Size = UDim2.fromOffset(compact and 370 or 440, HUD.cardH or 106)
		buffRow.AnchorPoint = Vector2.zero
		buffRow.Position = UDim2.fromOffset(compact and 356 or 426, topY + 176)
		if HUD.hotbar then
			HUD.hotbar.AnchorPoint = Vector2.new(0.5, 1)
			HUD.hotbar.Position = UDim2.new(0.5, 0, 1, -12)
			HUD.hotbar:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
		end
	end
	if HUD.partyBar then
		HUD.partyBar.Position = UDim2.fromOffset(16, topY + 176)
		HUD.partyBar.Size = UDim2.fromOffset(HUD.partyWidth or 130, 36)
	end
	-- target frame: narrower on small screens so it clears the status card
	targetFrame.Size = UDim2.fromOffset(compact and 300 or 380, 70)
	-- menu: 3 small columns on phones, 2 big columns elsewhere
	local grid = menuFrame:FindFirstChildOfClass("UIGridLayout")
	if compact then
		-- 4 small columns x 3 rows so the menu ends well above the mobile attack button
		menuScale.Scale = 0.8
		menuFrame.Size = UDim2.fromOffset(326, 166)
	else
		menuScale.Scale = 1
		menuFrame.Size = UDim2.fromOffset(158, 344)
	end
	if grid then
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	end
	-- quest tracker sits under the player card
	if HUD.questFrame then
		HUD.questFrame.Position = UDim2.fromOffset(16, bottomCard and topY + 8 or topY + 222)
		HUD.questFrame.Size = UDim2.fromOffset(compact and 300 or 330, HUD.questFrame.Size.Y.Offset)
	end
	-- loot feed: bottom-left on PC; on touch screens the thumbstick lives there, so stack it under the tracker
	local list = lootFeed:FindFirstChildOfClass("UIListLayout")
	if UI.IsMobile then
		lootFeed.AnchorPoint = Vector2.new(0, 0)
		lootFeed.Position = UDim2.fromOffset(16, topY + 366)
		if list then
			list.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	else
		lootFeed.AnchorPoint = Vector2.new(0, 1)
		lootFeed.Position = bottomCard and UDim2.new(0, 16, 1, -190) or UDim2.new(0, 16, 1, -24)
		if list then
			list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end
	-- toasts sit just left of the menu column (they used to slide under the currency pills)
	local menuW = compact and 326 * 0.8 or 158
	UI.ToastHolder.Position = UDim2.new(1, -(menuW + 32), 0, 222)
	-- the style meter (vertical tube) stands middle-right: left of the menu column, or under the small phone menu
	if compact then
		UI.PlaceStyleMeter(UDim2.new(1, -96, 0.46, 0), 0.6) -- v0.25.2: above the touch attack button (it sat behind it)
	else
		UI.PlaceStyleMeter(UDim2.new(1, -(menuW + 30), 0.5, 0), 1)
	end
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
	-- the hotbar's width is only known after it rendered once (the bottom card needs it): lay out again then,
	-- and whenever it changes (slots added, ammo button)
	pcall(function()
		barRows.main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(HUD.Layout)
		end)
	end)
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
