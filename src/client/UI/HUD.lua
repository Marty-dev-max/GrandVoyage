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

local bars, money, bounty, pointsBtn, skillSlots, autoBtn, autoIcon, targetFrame, lootFeed, buffRow
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
	-- v0.24.12 (owner): the dark disc behind the ring is a soft fade now (no hard grey plate / thick outline)
	local disc = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 12, 22), BackgroundTransparency = 0.25, ZIndex = 3, Parent = frame })
	disc:SetAttribute("PxKeep", true)
	UI.Corner(disc, RING_SIZE)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.6) }),
		Parent = disc,
	})
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
	local card = softPanel(UI.Root, UDim2.fromOffset(400, 150), UDim2.fromOffset(100, 22), nil, "right")
	statusCard = card
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
	-- v0.24.12 (owner): Store boost timers (2x EXP / 2x DROP / FRUIT RADAR) sit right under the EXP readouts;
	-- Controllers/Heritage fills this row
	HUD.boostRow = New("Frame", { Name = "BoostRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 126), Size = UDim2.new(1, -82, 0, 20), Parent = card })
	UI.List(HUD.boostRow, Enum.FillDirection.Horizontal, 6)
	buffRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(170, 158), Size = UDim2.fromOffset(300, 30), Parent = UI.Root })
	-- v0.24.8 (owner): the party sits right under the player card as one horizontal strip (above the quest tracker):
	-- member chips with name + HP while in a party, else a PARTY button that opens the Party window
	local partyBar = softPanel(UI.Root, UDim2.fromOffset(400, 36), UDim2.fromOffset(16, 156), nil, "right")
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
			UI.Text(partyRow, "Team up: shared EXP + drops", 11, Color3.fromRGB(200, 210, 230), "Semi", { LayoutOrder = 2, Size = UDim2.fromOffset(250, 26), TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false })
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
	State.Changed:Connect(function(kind)
		if kind == "party" then
			renderParty()
		end
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
	local row = softPanel(UI.Root, UDim2.fromOffset(470, 42), UDim2.new(1, -16, 0, 14), Vector2.new(1, 0), "left")
	row.Name = "CurrencyRow" -- Readability fits the compass between the MENU button and this row
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), Parent = row })
	UI.List(row, Enum.FillDirection.Horizontal, 4).VerticalAlignment = Enum.VerticalAlignment.Center
	local function segment(order, icon, color, width, tip)
		local seg = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 42), LayoutOrder = order, Parent = row })
		local ic = UI.Icon(seg, icon, 40, { Name = "PillIcon", Position = UDim2.fromOffset(-2, 0) })
		local label = UI.Text(seg, "0", 20, color, "Number", { Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -38, 1, 0), TextWrapped = false })
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
	-- Studio only: animation status under the version, so any screenshot the owner sends shows whether clips load and play
	if game:GetService("RunService"):IsStudio() then
		local animLine = UI.Text(UI.Root, "", 11, Color3.fromRGB(255, 230, 150), "Bold", { Name = "AnimStatus", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(620, 14), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.2 })
		task.spawn(function()
			local Anim = require(game:GetService("ReplicatedStorage").Shared.Modules.Anim)
			local CharAnim = require(script.Parent.Parent.Controllers.CharAnim)
			while animLine.Parent do
				local a, c = Anim.Stats, CharAnim.Stats
				local char = game:GetService("Players").LocalPlayer.Character
				animLine.Text = string.format("anim: %s | played %d (%s) | loaded %d local %d failed %d | weapon %s",
					c.kind, a.played, a.last, a.loaded, a.fallback, a.failed, char and tostring(char:GetAttribute("Weapon")) .. (char:GetAttribute("WeaponOut") and " out" or "") or "-")
				task.wait(0.5)
			end
		end)
	end
	orbLayer = New("Frame", { Name = "OrbLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = UI.Root })
end

-- Anime-Vanguards-style menu: square colored tiles with a big icon, a label and a key hint, in two columns
-- Every window with its icon, color, hotkey and label. main = shown as a tile; the rest live in the MENU hub.
local MENU = {
	{ "🎒", "Inventory", T.Ocean, "I", "Bag", main = true },
	{ "✨", "Skills", T.Gold, "K", "Skills", main = true },
	{ "📜", "Quests", T.Gold:Lerp(T.Orange, 0.4), "J", "Quests", main = true },
	{ "🗺️", "Map", T.Ocean, "M", "Map", main = true },
	{ "🐾", "Pets", T.Green:Lerp(T.Ocean, 0.3), "N", "Pets", main = true },
	{ "🛍️", "PearlShop", Color3.fromRGB(80, 170, 220), "H", "Shop", main = true },
	{ "📊", "Stats", T.Purple, "C", "Stats", main = true },
	{ "ship", "Shipwright", T.OceanDark, nil, "Ships" },
	{ "🏴", "Guild", T.Pirate, "G", "Guild" },
	{ "👥", "Party", T.Green, "P", "Party" },
	{ "👑", "BossBoard", T.Red, "B", "Bosses" },
	{ "⚙️", "Settings", T.Grey, "O", "Settings" },
}
HUD.Menu = MENU
Panels.MenuItems = MENU

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
	UI.Icon(tile, it[1], 54, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) })
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
	menuTile(menu, { "anchor", "MenuHub", Color3.fromRGB(70, 60, 110), "L", "Menu" })
	local keymap = {}
	for _, it in ipairs(MENU) do
		if it[4] then
			keymap[Enum.KeyCode[it[4]]] = it[2]
		end
		keymap[Enum.KeyCode.L] = "MenuHub"
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
	local count = UI.Text(slot, "", 13, T.Text, "Number", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -1), Size = UDim2.fromOffset(44, 15), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7 })
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

-- Hotbar (like the quick bars of big MMOs): main row = AUTO, skills 1-6, quick items F1-F4, expand toggle;
-- expanded row above = skills 7 8 9 0 - =, items F5-F8. Skills go in from the Skills window (Loadout tab).
local itemSlots, barRows, expandBtn
HUD.barExpanded = false
local function setExpanded(on)
	HUD.barExpanded = on
	if barRows then
		barRows.second.Visible = on
	end
	if expandBtn then
		expandBtn.Text = on and "v" or "^"
	end
	pcall(function()
		local Settings = require(script.Parent.Parent.Controllers.Settings)
		Settings.Set("barExpanded", on)
	end)
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
	local vlist = UI.List(bar, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	vlist.VerticalAlignment = Enum.VerticalAlignment.Bottom
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	local second = row(bar, 1)
	local main = row(bar, 2)
	second.Visible = false
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
	for i = 1, GameConfig.SkillBarSize do
		local parent = i <= 6 and main or second
		local s = makeSlot(parent, Combat.SKILL_KEY_LABELS[i], i)
		skillSlots[i] = s
		s.slot.Activated:Connect(function()
			local p = State.profile
			local id = p and p.skillBar[i]
			if id and id ~= "" then
				Combat.CastSkill(id)
			else
				Panels.Open("Skills", { tab = "Loadout" })
			end
		end)
		s.slot.MouseEnter:Connect(function()
			local p = State.profile
			local id = p and p.skillBar[i]
			Readability.HoverSkill = (id and id ~= "") and id or nil
		end)
		s.slot.MouseLeave:Connect(function()
			Readability.HoverSkill = nil
		end)
		UI.Tooltip(s.slot, function()
			local p = State.profile
			local sk = p and p.skillBar[i] and ClassesCfg.SkillById[p.skillBar[i]]
			if not sk then
				return "Empty slot: click to set up skills", T.TextSoft
			end
			local lvText = sk.fruit and ("Mastery " .. (p.fruit and p.fruit.mastery or 0)) or ("Lv." .. (p.skills[sk.id] or 0))
			return string.format("<b>%s</b>  %s\n%s\nSP %d  •  Cooldown %ss", sk.name, lvText, sk.desc or "", sk.sp, sk.cd), skillColor(sk)
		end)
	end
	-- a little gap between skills and items
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 4), LayoutOrder = 50, Parent = main })
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 4), LayoutOrder = 50, Parent = second })
	itemSlots = {}
	for i = 1, GameConfig.ItemBarSize do
		local s = makeSlot(i <= 4 and main or second, "F" .. i, 100 + i)
		itemSlots[i] = s
		s.slot.Activated:Connect(function()
			local p = State.profile
			local id = p and p.itemBar and p.itemBar[i]
			if id and id ~= "" then
				Combat.UseQuickItem(i)
			else
				Panels.Open("Skills", { tab = "Loadout" })
			end
		end)
		UI.Tooltip(s.slot, function()
			local p = State.profile
			local def = p and p.itemBar and p.itemBar[i] and ItemDB.Get(p.itemBar[i])
			if not def then
				return "Empty quick slot: click to put a potion or food here", T.TextSoft
			end
			return "<b>" .. def.name .. "</b>  [F" .. i .. "]\n" .. (def.desc or ""), T.Ocean
		end)
	end
	local eBtn, eh = UI.Button(main, "^", T.Ocean, UDim2.fromOffset(34, SLOT), function()
		setExpanded(not HUD.barExpanded)
	end)
	expandBtn = eBtn
	eh.LayoutOrder = 200
	UI.Tooltip(eBtn, function()
		return HUD.barExpanded and "Hide the second row" or "Show 6 more skill slots and F5-F8", T.Ocean
	end)
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(34, SLOT), LayoutOrder = 200, Parent = second })

	-- v0.25.3 (owner): reads AUTO or MANUAL (not "AUTO ON"), with a pixel icon above the word
	autoBtn = UI.Button(main, "MANUAL", T.Grey, UDim2.fromOffset(92, SLOT), function()
		Combat.ToggleAuto()
	end)
	autoBtn.Parent.LayoutOrder = 220
	autoIcon = UI.Icon(autoBtn, "manual", 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -4), ZIndex = autoBtn.ZIndex + 2 })
	local pad = autoBtn:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 26)
	end
	UI.Tooltip(autoBtn, function()
		return State.auto and "<b>AUTO</b>  [T]\nFights monsters within your search range (Skills -> Loadout), uses ticked skills and drinks potions. Tap for MANUAL."
			or "<b>MANUAL</b>  [T]\nYou aim and attack yourself. Tap for AUTO.", T.Green
	end)
	New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(92, SLOT), LayoutOrder = 220, Parent = second })

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
	ammoBtn.Activated:Connect(function()
		HUD.ToggleAmmoPicker()
	end)
	UI.Tooltip(ammoBtn, function()
		local p = State.profile
		local a = AmmoCfg.ById[p and p.ammo or ""] or AmmoCfg.ById[AmmoCfg.Default]
		return "<b>" .. a.name .. "</b> loaded\n" .. a.desc .. "\nTap to change ammo.", a.color
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
-- where a world point is on our UI canvas (the root ignores the top-bar inset, so viewport = screen)
local function canvasPoint(pos)
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local v, onScreen = cam:WorldToViewportPoint(pos)
	if not onScreen then
		return nil
	end
	local sc = UI.GetScale()
	return Vector2.new(v.X / sc, v.Y / sc)
end
local function centerOf(gui)
	local ok, p = pcall(function()
		local sc = UI.GetScale()
		return (gui.AbsolutePosition + gui.AbsoluteSize / 2) / sc
	end)
	return ok and p or nil
end
local function bump(gui)
	if not gui then
		return
	end
	local sc = gui:FindFirstChild("LootPop") or New("UIScale", { Name = "LootPop", Parent = gui })
	sc.Scale = 1.25
	UI.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end
-- an icon bursts out of `from`, hangs a moment, then swoops into `to`
local function fly(icon, size, from, to, delay, onArrive, image)
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y), Size = UDim2.fromOffset(size, size), ZIndex = 70, Parent = UI.Root })
	if image then
		New("ImageLabel", { BackgroundTransparency = 1, Image = image, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 71, Parent = holder })
	else
		local img = UI.Icon(holder, icon, size, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		if img then
			img.ZIndex = 71
		end
	end
	local a = math.random() * math.pi * 2
	local r = 40 + math.random() * 60
	local burst = from + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.7 - 30)
	UI.Tween(holder, 0.25, { Position = UDim2.fromOffset(burst.X, burst.Y) }, Enum.EasingStyle.Quad)
	task.delay(0.3 + delay, function()
		if not holder.Parent then
			return
		end
		local t = UI.Tween(holder, 0.5, { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(size * 0.6, size * 0.6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			holder:Destroy()
			if onArrive then
				onArrive()
			end
		end)
	end)
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
	local from = data.pos and canvasPoint(data.pos)
	if not from then
		return
	end
	if data.beli and data.beli > 0 and money then
		local to = centerOf(money.Parent) or Vector2.new(0, 0)
		local n = math.clamp(math.floor(math.log10(data.beli + 1) * 3), 3, 12)
		for i = 1, n do
			fly(UI.CurrencyIcon, 30, from, to, i * 0.035, function()
				if i == 1 or i == n then
					bump(money)
				end
				Audio.Play("Coin", { volume = 0.25, pitch = 0.9 + i * 0.03 })
			end)
		end
	end
	local bagTile = HUD.badges and HUD.badges.Inventory and HUD.badges.Inventory.Parent
	local bagAt = bagTile and centerOf(bagTile)
	for k, it in ipairs(data.items or {}) do
		local def = ItemDB.Get(it.id)
		local img = def and UI.ItemIconId(def)
		if bagAt then
			fly(def and def.icon or "📦", 50, from, bagAt, 0.25 + k * 0.12, function()
				bump(bagTile)
				Audio.Play("Pickup", { volume = 0.5, pitch = 0.95 + math.random() * 0.1 })
			end, img)
		end
	end
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
		add((it.card and "🃏 " or "") .. (def and def.name or it.id) .. "  x" .. it.qty, def and def.rarity or "Common")
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
	ring.face.BackgroundColor3 = cls and cls.color or T.Ocean
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
	-- skill bar (12 fixed slots; "" = empty)
	local p = State.profile
	if p and not HUD.expandSynced then
		-- the saved hotbar layout arrives with the profile
		HUD.expandSynced = true
		local Settings = require(script.Parent.Parent.Controllers.Settings)
		if (Settings.Values.barExpanded == true) ~= HUD.barExpanded then
			setExpanded(Settings.Values.barExpanded == true)
		end
	end
	local now = os.clock()
	for i, s in ipairs(skillSlots) do
		local id = p and p.skillBar[i]
		local skill = id and id ~= "" and ClassesCfg.SkillById[id] or nil
		local iconId = skill and skillIconId(skill)
		s.icon.Image = iconId or ""
		s.icon.Visible = iconId ~= nil
		-- with an icon the name moves to the tooltip; without one it stays as text
		s.name.Text = (skill and not iconId) and skill.name or ""
		s.sp.Text = skill and (skill.sp .. " SP") or ""
		s.sp.TextColor3 = Color3.fromRGB(150, 200, 255)
		local c = skillColor(skill)
		s.grad.Color = skill and ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.45)) or ColorSequence.new(T.PanelTop, T.PanelDeep)
		s.slot.BackgroundTransparency = skill and 0 or 0.35
		local left = skill and ((State.cooldowns[id] or 0) - now) or 0
		s.cd.Size = UDim2.new(1, 0, skill and left > 0 and math.clamp(left / skill.cd, 0, 1) or 0, 0)
		s.cdText.Text = (skill and left > 0) and string.format(left < 1 and "%.1f" or "%d", left) or ""
		s.auto.Visible = skill ~= nil and p.autoSkills[id] == true
		s.stroke.Color = (skill and (player:GetAttribute("SP") or 0) < skill.sp) and T.Red or T.Edge
	end
	-- dash cooldown sweep
	if HUD.dashSlot then
		local left = Combat.dashReadyAt - now
		HUD.dashSlot.cd.Size = UDim2.new(1, 0, left > 0 and math.clamp(left / GameConfig.Dash.Cooldown, 0, 1) or 0, 0)
		HUD.dashSlot.cdText.Text = left > 0 and string.format("%.1f", left) or ""
	end
	-- quick items: icon + how many are left in the bag
	for i, s in ipairs(itemSlots or {}) do
		local id = p and p.itemBar and p.itemBar[i]
		local def = id and id ~= "" and ItemDB.Get(id) or nil
		local qty = 0
		if def then
			for _, e in ipairs(p.inventory or {}) do
				if e.id == id then
					qty += e.qty or 1
				end
			end
		end
		local img = def and UI.ItemIconId(def)
		s.icon.Image = img or ""
		s.icon.Visible = img ~= nil
		s.icon.ImageTransparency = (def and qty == 0) and 0.6 or 0
		s.name.Text = (def and not img) and def.name or ""
		s.count.Text = def and tostring(qty) or ""
		s.count.TextColor3 = qty > 0 and T.Text or T.Red
		s.grad.Color = def and ColorSequence.new(T.Ocean:Lerp(Color3.new(1, 1, 1), 0.1), T.Ocean:Lerp(Color3.new(0, 0, 0), 0.5)) or ColorSequence.new(T.PanelTop, T.PanelDeep)
		s.slot.BackgroundTransparency = def and 0 or 0.35
	end
	-- ammo button: only for slingshot users
	if HUD.ammo and p then
		local wType = require(Shared.Modules.WeaponInfo).TypeOf(p)
		local shoots = AmmoCfg.Weapons[wType or ""] == true
		HUD.ammo.holder.Visible = shoots
		HUD.ammo.spacer.Visible = shoots
		if shoots then
			local a = AmmoCfg.ById[p.ammo or ""] or AmmoCfg.ById[AmmoCfg.Default]
			tintPellet(HUD.ammo.icon, a.color)
			local n = ammoCount(p, a)
			HUD.ammo.count.Text = n == math.huge and "∞" or tostring(n)
		elseif picker then
			picker:Destroy()
			picker = nil
		end
	end
	UI.SetButtonColor(autoBtn, State.auto and T.Green or T.Grey)
	autoBtn.Text = State.auto and "AUTO" or "MANUAL"
	if autoIcon and autoIcon:IsA("ImageLabel") then
		autoIcon.Image = UI.IconId(State.auto and "auto" or "manual") or ""
	end
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
	statusCard.Size = UDim2.fromOffset(compact and 330 or 400, 150)
	-- v0.24.12: party + quest moved below the level badge at the bottom of the ring (it covered the PARTY button)
	buffRow.Position = UDim2.fromOffset(compact and 356 or 426, topY + 176)
	if HUD.partyBar then
		HUD.partyBar.Position = UDim2.fromOffset(16, topY + 176)
		HUD.partyBar.Size = UDim2.fromOffset(compact and 330 or 400, 36)
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
		HUD.questFrame.Position = UDim2.fromOffset(16, topY + 222)
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
		lootFeed.Position = UDim2.new(0, 16, 1, -24)
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
