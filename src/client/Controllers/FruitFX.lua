-- FruitFX (client, v0.25.1, owner): pixel / voxel effects for every Cursed Fruit skill, played on top of the shared
-- skill FX (VFX handlers.Skill calls FruitFX.Play when the skill id starts with "F_"). Data: from, to, char, radius.
-- Everything is built from neon cubes (Controllers/Voxels Blocks) and square pixels (Voxels Pixels) + a few tweened
-- blocks, in each fruit's colors:
--   Blaze = fire (orange/yellow/red), Haze = smoke (white/grey/lavender), Ward = barrier panes (cyan glass),
--   Bounce = rubber (skin + pink), Split = body pieces (skin + purple seams), Slick = oil (black-brown + yellow shine).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Voxels = require(script.Parent.Voxels)

local FX = {}
local folder

local C = {
	fire1 = Color3.fromRGB(255, 240, 120), fire2 = Color3.fromRGB(255, 160, 40), fire3 = Color3.fromRGB(230, 70, 30),
	smoke1 = Color3.fromRGB(240, 240, 245), smoke2 = Color3.fromRGB(185, 182, 200), smoke3 = Color3.fromRGB(150, 140, 175),
	ward1 = Color3.fromRGB(150, 245, 255), ward2 = Color3.fromRGB(70, 200, 230),
	skin = Color3.fromRGB(246, 196, 150), pink = Color3.fromRGB(255, 130, 170),
	purple = Color3.fromRGB(170, 90, 230), lilac = Color3.fromRGB(215, 170, 255),
	oil = Color3.fromRGB(45, 36, 22), oil2 = Color3.fromRGB(80, 64, 34), shine = Color3.fromRGB(230, 215, 90),
	white = Color3.new(1, 1, 1),
}

local function blk(size, color, cf, neon, transp)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.CFrame = cf
	p.Parent = folder or workspace
	return p
end
local function tw(inst, t, props, style, dir)
	local tr = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tr:Play()
	return tr
end
local function fade(p, delay, t)
	task.delay(delay, function()
		if p.Parent then
			tw(p, t or 0.3, { Transparency = 1, Size = p.Size * 0.4 })
		end
	end)
	Debris:AddItem(p, delay + (t or 0.3) + 0.05)
end
local function ground(pos)
	return Vector3.new(pos.X, pos.Y - 2.6, pos.Z)
end
local function charRoot(d)
	local c = d.char
	return typeof(c) == "Instance" and c:FindFirstChild("HumanoidRootPart")
end
local function along(from, to, n, fn)
	for i = 1, n do
		fn(from:Lerp(to, i / n), i)
	end
end
-- a cluster of cubes shaped like a fist (used by Bounce / Split / Blaze)
local function fistBlocks(cf, colors, s, neon)
	s = s or 1
	local parts = {}
	table.insert(parts, blk(Vector3.new(1.6, 1.3, 1.2) * s, colors[1], cf, neon))
	for i = -1, 2 do
		table.insert(parts, blk(Vector3.new(0.38, 0.4, 0.5) * s, colors[2] or colors[1], cf * CFrame.new((i - 0.5) * 0.4 * s, 0.4 * s, -0.75 * s), neon))
	end
	return parts
end
local function moveAll(parts, fromCF, toCF, t)
	local rel = {}
	for i, p in ipairs(parts) do
		rel[i] = fromCF:ToObjectSpace(p.CFrame)
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / t)
		local cf = fromCF:Lerp(toCF, k)
		for i, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = cf * rel[i]
			end
		end
		if k >= 1 then
			conn:Disconnect()
		end
	end)
end

-- ===== Blaze Blaze =====
local function fireBurst(pos, power)
	Voxels.Blocks(pos, { count = math.floor(10 * power), colors = { C.fire1, C.fire2, C.fire3 }, size = { 0.3, 0.7 }, speed = 10 * power, up = 10, neon = true, collide = false, life = 0.6, spread = 1.2 })
	Voxels.Pixels(pos, { count = math.floor(30 * power), colors = { C.fire1, C.fire2, C.fire3 }, size = 0.35, speed = 14 * power, gravity = -6, life = 0.7, glow = 1, spread = 2 })
end
FX.F_FireFist = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	local dir = (to - from)
	if dir.Magnitude < 0.5 then
		return
	end
	local fromCF = CFrame.lookAt(from, to)
	local parts = fistBlocks(fromCF, { C.fire2, C.fire1 }, 1.8, true)
	table.insert(parts, blk(Vector3.new(2.6, 2.6, 2.6), C.fire3, fromCF * CFrame.new(0, 0, 0.8), true, 0.45))
	local t = math.clamp(dir.Magnitude / 90, 0.12, 0.5)
	moveAll(parts, fromCF, CFrame.lookAt(to, to + dir.Unit), t)
	for k = 1, 6 do
		task.delay(t * k / 6, function()
			Voxels.Pixels(from:Lerp(to, k / 6), { count = 10, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.4, speed = 3, gravity = -8, life = 0.5, glow = 1, spread = 1.5 })
		end)
	end
	for _, p in ipairs(parts) do
		fade(p, t, 0.2)
	end
	task.delay(t, function()
		fireBurst(to, 1.4)
	end)
end
FX.F_FlamePillar = function(d)
	local at = ground(d.to or d.from)
	local r = math.min(d.radius or 12, 16)
	for i = 0, 7 do
		task.delay(i * 0.05, function()
			local s = r * (1 - i * 0.08)
			local ring = blk(Vector3.new(s, 2.2, s), i % 2 == 0 and C.fire2 or C.fire3, CFrame.new(at + Vector3.new(0, 1 + i * 2.2, 0)) * CFrame.Angles(0, i * 0.4, 0), true, 0.25)
			tw(ring, 0.5, { Size = Vector3.new(s * 0.4, 2.2, s * 0.4), CFrame = ring.CFrame * CFrame.new(0, 6, 0) })
			fade(ring, 0.35, 0.3)
		end)
	end
	Voxels.Pixels(at + Vector3.new(0, 3, 0), { count = 60, colors = { C.fire1, C.fire2 }, size = 0.4, speed = 18, gravity = -14, life = 1, glow = 1, spread = r })
	fireBurst(at + Vector3.new(0, 1, 0), 1.6)
end
FX.F_FireDash = function(d)
	local from, to = d.from, d.to or d.from
	along(from, to, 8, function(p, i)
		task.delay(i * 0.03, function()
			Voxels.Pixels(ground(p) + Vector3.new(0, 0.6, 0), { count = 12, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.4, speed = 4, gravity = -10, life = 0.8, glow = 1, spread = 2 })
			local b = blk(Vector3.new(1.4, 0.3, 1.4), C.fire2, CFrame.new(ground(p) + Vector3.new(0, 0.15, 0)), true, 0.2)
			fade(b, 0.4, 0.5)
		end)
	end)
	fireBurst(to, 1)
end
FX.F_Inferno = function(d)
	local at = ground(d.from)
	local r = d.radius or 18
	for ring = 1, 3 do
		task.delay(ring * 0.1, function()
			local n = 14 + ring * 6
			for i = 1, n do
				local a = i / n * math.pi * 2
				local p = at + Vector3.new(math.cos(a), 0, math.sin(a)) * (r * ring / 3)
				local b = blk(Vector3.new(1.2, 1.2, 1.2), ring == 1 and C.fire1 or (ring == 2 and C.fire2 or C.fire3), CFrame.new(p + Vector3.new(0, 0.6, 0)), true)
				tw(b, 0.5, { CFrame = b.CFrame * CFrame.new(0, 3 + math.random() * 3, 0) * CFrame.Angles(math.random(), math.random(), 0) })
				fade(b, 0.3, 0.3)
			end
		end)
	end
	fireBurst(at + Vector3.new(0, 2, 0), 2.4)
end

-- ===== Haze Haze =====
local function smokePuff(pos, n, spread, life)
	Voxels.Pixels(pos, { count = n, colors = { C.smoke1, C.smoke2, C.smoke3 }, size = 0.7, speed = 2, gravity = -1, life = life or 1.2, glow = 0, spread = spread })
end
FX.F_SmokeGrip = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	along(from, to, 7, function(p, i)
		task.delay(i * 0.035, function()
			smokePuff(p, 8, 1.5, 0.7)
		end)
	end)
	task.delay(0.25, function()
		-- a big smoke hand closing on the target
		local cf = CFrame.lookAt(to + Vector3.new(0, 2, 0), from)
		for i = -2, 2 do
			local f = blk(Vector3.new(0.7, 2.6, 0.7), C.smoke1, cf * CFrame.new(i * 0.8, 1.2, 0), false, 0.15)
			tw(f, 0.25, { CFrame = cf * CFrame.new(i * 0.35, 0.3, -0.6) * CFrame.Angles(-0.9, 0, 0) })
			fade(f, 0.6, 0.4)
		end
		smokePuff(to + Vector3.new(0, 2, 0), 30, 3, 1)
	end)
end
FX.F_SmokeScreen = function(d)
	local at = ground(d.to or d.from) + Vector3.new(0, 2, 0)
	local r = d.radius or 14
	for k = 0, 5 do
		task.delay(k * 0.3, function()
			smokePuff(at, 40, r * 1.6, 1.6)
		end)
	end
	for _ = 1, 10 do
		local off = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * r * 1.4
		local b = blk(Vector3.new(4, 3, 4), C.smoke2, CFrame.new(at + off), false, 0.35)
		tw(b, 1.6, { Size = Vector3.new(6, 4.5, 6), Transparency = 0.6 })
		fade(b, 1.6, 0.6)
	end
end
FX.F_SmokeBody = function(d)
	local r = charRoot(d)
	local p = r and r.Position or d.from
	smokePuff(p, 60, 3, 1.4)
	Voxels.Blocks(p, { count = 10, colors = { C.smoke1, C.smoke2 }, size = { 0.4, 0.8 }, speed = 5, up = 4, collide = false, life = 0.8, spread = 1.5 })
end
FX.F_WhiteOut = function(d)
	local at = ground(d.from)
	local r = d.radius or 18
	local blocks = {}
	for i = 1, 36 do
		local b = blk(Vector3.new(1, 1, 1) * (0.6 + math.random() * 0.8), i % 3 == 0 and C.smoke2 or C.smoke1, CFrame.new(at), false, 0.1)
		blocks[i] = { b = b, a = math.random() * 6.28, h = math.random() * 14, rr = r * (0.3 + math.random() * 0.7) }
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = os.clock() - t0
		for _, e in ipairs(blocks) do
			local a = e.a + k * 6
			e.b.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * e.rr, 1 + e.h * math.min(1, k * 1.5), math.sin(a) * e.rr)) * CFrame.Angles(a, a * 0.5, 0)
		end
		if k > 1.2 then
			conn:Disconnect()
			for _, e in ipairs(blocks) do
				fade(e.b, 0, 0.3)
			end
		end
	end)
	smokePuff(at + Vector3.new(0, 4, 0), 50, r, 1.4)
end

-- ===== Ward Ward =====
local function pane(cf, w, h, life)
	local p = blk(Vector3.new(w, h, 0.4), C.ward1, cf, true, 0.45)
	local edge = blk(Vector3.new(w + 0.3, h + 0.3, 0.2), C.ward2, cf * CFrame.new(0, 0, 0.15), true, 0.2)
	fade(p, life, 0.3)
	fade(edge, life, 0.3)
	return p, edge
end
local function shatter(pos, n)
	Voxels.Blocks(pos, { count = n or 14, colors = { C.ward1, C.ward2, C.white }, size = { 0.3, 0.7 }, speed = 12, up = 6, neon = true, collide = false, life = 0.6, spread = 1.5 })
end
FX.F_BarrierBash = function(d)
	local from, to = d.from, d.to or d.from
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis
	local cf = CFrame.lookAt(from + dir * 2, from + dir * 3)
	local p, e = pane(cf, 5, 6, 0.35)
	tw(p, 0.18, { CFrame = cf * CFrame.new(0, 0, -5) })
	tw(e, 0.18, { CFrame = cf * CFrame.new(0, 0, -4.85) })
	task.delay(0.2, function()
		shatter(from + dir * 7, 16)
	end)
end
FX.F_BarrierWall = function(d)
	local r = charRoot(d)
	local at = r and r.Position or d.from
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local pos = at + Vector3.new(math.cos(a), 0, math.sin(a)) * 7
		local p, e = pane(CFrame.lookAt(pos, at), 4.5, 6, 1.2)
		p.Size = Vector3.new(0.1, 0.1, 0.4)
		e.Size = Vector3.new(0.1, 0.1, 0.2)
		tw(p, 0.25, { Size = Vector3.new(4.5, 6, 0.4) }, Enum.EasingStyle.Back)
		tw(e, 0.25, { Size = Vector3.new(4.8, 6.3, 0.2) }, Enum.EasingStyle.Back)
	end
end
FX.F_BarrierCrash = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	if (to - from).Magnitude < 0.5 then
		return
	end
	local cf = CFrame.lookAt(from, to)
	local p, e = pane(cf, 4, 4, 0.5)
	local t = math.clamp((to - from).Magnitude / 80, 0.1, 0.45)
	tw(p, t, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }, Enum.EasingStyle.Linear)
	tw(e, t, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) * CFrame.new(0, 0, 0.15) }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		shatter(to, 22)
	end)
end
FX.F_BarrierDome = function(d)
	local r = charRoot(d)
	local at = r and ground(r.Position) or ground(d.from)
	local rad = 12
	for ring = 0, 4 do
		local y = ring * rad / 5
		local rr = math.sqrt(math.max(0, rad * rad - y * y))
		local n = math.max(6, math.floor(rr * 0.9))
		for i = 1, n do
			local a = i / n * math.pi * 2 + ring * 0.3
			local b = blk(Vector3.new(1.4, 1.4, 1.4), ring % 2 == 0 and C.ward1 or C.ward2, CFrame.new(at + Vector3.new(math.cos(a) * rr, y + 0.7, math.sin(a) * rr)), true, 0.4)
			b.Size = Vector3.new(0.1, 0.1, 0.1)
			task.delay(ring * 0.05, function()
				tw(b, 0.2, { Size = Vector3.new(1.4, 1.4, 1.4) }, Enum.EasingStyle.Back)
			end)
			fade(b, 1.6, 0.4)
		end
	end
	local top = blk(Vector3.new(2, 2, 2), C.white, CFrame.new(at + Vector3.new(0, rad, 0)), true, 0.3)
	fade(top, 1.6, 0.4)
end

-- ===== Bounce Bounce (v0.25.66, docs/Plan-Fruits-v2.md phase 2) =====
-- The rubber arms are real voxel blocks in the character's own skin color (read from its hand block): a chain of
-- cubes from the elbow to the fist that stretches out, holds, and snaps back with a wobble. The real forearm + hand
-- hide (LocalTransparencyModifier, on every client) while the rubber arm is out.
local RunService = game:GetService("RunService")
local function vfx()
	return require(script.Parent.VFX)
end
local function voxBody(char)
	return typeof(char) == "Instance" and char:FindFirstChild("VoxelBody")
end
local function skinOf(char)
	local body = voxBody(char)
	local h = body and (body:FindFirstChild("RightHand") or body:FindFirstChild("LeftHand"))
	return h and h.Color or C.skin
end
FX.SkinOf = skinOf
-- hide the voxel blocks welded to a forearm / hand for `seconds` (overlapping hides: the latest wins; 0 = show now)
local hiddenUntil = setmetatable({}, { __mode = "k" })
local function hideArm(char, side, seconds)
	local body = voxBody(char)
	if not body then
		return
	end
	local lower, hand = char:FindFirstChild(side .. "LowerArm"), char:FindFirstChild(side .. "Hand")
	local untilT = os.clock() + seconds
	for _, b in ipairs(body:GetChildren()) do
		local w = b:FindFirstChildOfClass("WeldConstraint")
		if w and w.Part0 and (w.Part0 == lower or w.Part0 == hand) then
			if seconds <= 0 then -- show it again now (the arm snapped back early)
				hiddenUntil[b] = nil
				b.LocalTransparencyModifier = 0
			else
				hiddenUntil[b] = math.max(hiddenUntil[b] or 0, untilT)
				b.LocalTransparencyModifier = 1
			end
		end
	end
	if seconds <= 0 then
		return
	end
	task.delay(seconds + 0.02, function()
		for b, t in pairs(hiddenUntil) do
			if os.clock() >= t then
				hiddenUntil[b] = nil
				if b.Parent then
					b.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end
FX.HideArm = hideArm
-- where a rubber arm starts: the elbow (bottom of the upper arm), or the caster's position
local function elbow(char, side, fallback)
	local ua = typeof(char) == "Instance" and char:FindFirstChild(side .. "UpperArm")
	if ua then
		return (ua.CFrame * CFrame.new(0, -ua.Size.Y / 2, 0)).Position
	end
	return fallback or Vector3.zero
end
-- the fist / palm at the end of a rubber arm (offsets in the tip's space, facing -Z = along the arm)
local function tipShape(palm)
	if palm then
		return {
			{ Vector3.new(2, 2, 0.6), CFrame.new(0, 0, 0) },
			{ Vector3.new(0.42, 0.9, 0.5), CFrame.new(-0.72, 1.3, 0) }, { Vector3.new(0.42, 1.1, 0.5), CFrame.new(-0.24, 1.4, 0) },
			{ Vector3.new(0.42, 1.05, 0.5), CFrame.new(0.24, 1.38, 0) }, { Vector3.new(0.42, 0.85, 0.5), CFrame.new(0.72, 1.28, 0) },
			{ Vector3.new(0.5, 0.9, 0.5), CFrame.new(1.25, 0.2, 0) * CFrame.Angles(0, 0, -0.6) },
		}
	end
	return {
		{ Vector3.new(1.5, 1.35, 1.35), CFrame.new(0, 0, 0) },
		{ Vector3.new(0.36, 0.38, 0.4), CFrame.new(-0.54, 0.32, -0.8) }, { Vector3.new(0.36, 0.38, 0.4), CFrame.new(-0.18, 0.32, -0.8) },
		{ Vector3.new(0.36, 0.38, 0.4), CFrame.new(0.18, 0.32, -0.8) }, { Vector3.new(0.36, 0.38, 0.4), CFrame.new(0.54, 0.32, -0.8) },
	}
end
-- opts: char, side ("Right"/"Left"), from (fallback base), to (Vector3 or function), delay, tOut, hold (seconds or
-- math.huge = until handle.release()), tBack, palm, thick. Returns a handle { release(tBack), alive() }.
local function rubberArm(o)
	local skin = skinOf(o.char)
	local dark = skin:Lerp(Color3.new(0, 0, 0), 0.12)
	local thick = o.thick or 0.85
	local segs, tip = {}, {}
	for _, sp in ipairs(tipShape(o.palm)) do
		local b = blk(sp[1], skin, CFrame.new(), false)
		b.Transparency = 1
		table.insert(tip, { b = b, rel = sp[2] })
	end
	local function seg(i)
		local s = segs[i]
		if not s then
			s = blk(Vector3.new(thick, thick, 1.02), i % 2 == 0 and dark or skin, CFrame.new(), false)
			segs[i] = s
		end
		return s
	end
	local h = { phase = "out", t0 = os.clock() + (o.delay or 0) }
	local tOut, tBack, hold = o.tOut or 0.18, o.tBack or 0.2, o.hold or 0.05
	local backAt
	function h.release(t)
		if h.phase ~= "back" and h.phase ~= "done" then
			tBack = t or tBack
			h.phase, backAt = "back", os.clock()
		end
	end
	function h.alive()
		return h.phase ~= "done"
	end
	local conn
	local function finish()
		h.phase = "done"
		if conn then
			conn:Disconnect()
		end
		for _, s in pairs(segs) do
			s:Destroy()
		end
		for _, e in ipairs(tip) do
			e.b:Destroy()
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now < h.t0 then
			return
		end
		if typeof(o.char) == "Instance" and not o.char.Parent then
			return finish()
		end
		local base = elbow(o.char, o.side, o.from)
		local to = type(o.to) == "function" and o.to() or o.to
		local full = to - base
		if full.Magnitude < 0.3 then
			full = Vector3.new(0, 0, -0.3)
		end
		local ext, wob = 1, 0
		local k = (now - h.t0) / tOut
		if h.phase == "out" then
			if k >= 1 then
				h.phase = "hold"
			else
				ext = 1 - (1 - k) ^ 3
			end
		end
		if h.phase == "hold" and hold ~= math.huge and now - h.t0 > tOut + hold then
			h.release()
		end
		if h.phase == "back" then
			local b = (now - backAt) / tBack
			if b >= 1 then
				return finish()
			end
			ext = 1 - b * b
			wob = math.sin(b * math.pi) * 0.9
		end
		local len = full.Magnitude * ext
		local dir = full.Unit
		local side = dir:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
		local n = math.max(1, math.ceil(len))
		for i = 1, math.max(n, #segs) do
			if i <= n then
				local s = seg(i)
				local a = (i - 0.5) / n
				local w = side * math.sin(a * math.pi * 3 + now * 40) * wob * math.sin(a * math.pi)
				local l = len / n
				s.Size = Vector3.new(thick, thick, l * 1.04)
				s.CFrame = CFrame.lookAt(base + dir * (a * len) + w, base + dir * (a * len) + w + dir)
				s.Transparency = 0
			elseif segs[i] then
				segs[i].Transparency = 1
			end
		end
		local tipCF = CFrame.lookAt(base + dir * len, base + dir * (len + 1))
		for _, e in ipairs(tip) do
			e.b.CFrame = tipCF * e.rel
			e.b.Transparency = 0
		end
	end)
	-- safety: never leave an arm behind
	task.delay((o.delay or 0) + tOut + (hold == math.huge and 12 or hold) + tBack + 1, function()
		if h.phase ~= "done" then
			finish()
		end
	end)
	return h
end
FX.RubberArm = rubberArm
local function boing(pos, size)
	Voxels.Pixels(pos, { count = 18 + math.floor(size * 4), colors = { C.white, C.pink, C.lilac }, size = 0.35, speed = 10 + size * 2, gravity = 0, life = 0.4, glow = 0.6, spread = 1 })
end

FX.F_StretchPistol = function(d)
	local to = d.to or d.from
	local base = elbow(d.char, "Right", d.from + Vector3.new(0, 1, 0))
	local dir = to - base
	if dir.Magnitude < 1 then
		return
	end
	-- server: damage lands at strike 0.08 + 0.2 (Ranged)
	hideArm(d.char, "Right", 0.62)
	rubberArm({ char = d.char, side = "Right", from = d.from, to = to, delay = 0.08, tOut = 0.2, hold = 0.06, tBack = 0.24 })
	task.delay(0.28, function()
		vfx().ImpactSplit(to, dir, C.pink, 5)
		boing(to, 2)
	end)
end
FX.F_BounceGatling = function(d)
	local to = d.to or d.from
	if (to - d.from).Magnitude < 1 then
		return
	end
	hideArm(d.char, "Right", 0.7)
	hideArm(d.char, "Left", 0.7)
	local skin = skinOf(d.char)
	-- dozens of afterimage arms: a long skin bar + a fist, each one fading in ~0.12 s
	for k = 0, 21 do
		task.delay(0.04 + k * 0.026, function()
			local sideName = k % 2 == 0 and "Right" or "Left"
			local base = elbow(d.char, sideName, d.from + Vector3.new(0, 1, 0))
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3.4
			local tip = to + jitter
			local len = (tip - base).Magnitude
			local cf = CFrame.lookAt(base, tip)
			local bar = blk(Vector3.new(0.75, 0.75, len), skin, cf * CFrame.new(0, 0, -len / 2), false, 0.25)
			local fist = blk(Vector3.new(1.3, 1.2, 1.2), skin, CFrame.lookAt(tip, tip + cf.LookVector), false, 0.15)
			tw(bar, 0.13, { Transparency = 1 })
			tw(fist, 0.13, { Transparency = 1, Size = Vector3.new(1.7, 1.6, 1.6) })
			Debris:AddItem(bar, 0.15)
			Debris:AddItem(fist, 0.15)
			if k % 3 == 0 then
				Voxels.Pixels(tip, { count = 6, colors = { C.white, C.pink }, size = 0.3, speed = 9, gravity = 0, life = 0.22, glow = 0.5, spread = 0.6 })
			end
		end)
	end
	-- one impact per server hit (8 hits, 0.07 s apart, from strike 0.04)
	for i = 0, 7 do
		task.delay(0.04 + i * 0.07, function()
			vfx().ImpactSplit(to + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2, to - d.from, C.pink, 2.6)
		end)
	end
end
FX.F_RecoilCannon = function(d)
	local to = d.to or d.from
	local dir = to - d.from
	if dir.Magnitude < 1 then
		return
	end
	hideArm(d.char, "Right", 0.75)
	hideArm(d.char, "Left", 0.75)
	local side = dir.Unit:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
	for _, s in ipairs({ { "Right", 1 }, { "Left", -1 } }) do
		rubberArm({ char = d.char, side = s[1], from = d.from, to = to + side * s[2] * 1.1 + Vector3.new(0, 0.6, 0), delay = 0.1, tOut = 0.2, hold = 0.12, tBack = 0.28, palm = true, thick = 0.95 })
	end
	-- the recoil: dust ring at your feet as you shove
	task.delay(0.1, function()
		vfx().Ring(ground(d.from) + Vector3.new(0, 0.3, 0), 6, C.white, 0.35)
	end)
	task.delay(0.3, function()
		local V = vfx()
		V.Shockwave(to, dir, C.white, 13)
		V.ImpactSplit(to, dir, C.pink, 8)
		V.Ring(ground(to) + Vector3.new(0, 0.3, 0), 16, C.pink, 0.5)
		Voxels.Blocks(to, { count = 16, colors = { C.pink, C.white, C.lilac }, size = { 0.3, 0.7 }, speed = 22, up = 8, neon = true, collide = false, life = 0.6, spread = 2 })
		boing(to, 4)
	end)
end
-- Balloon Body: a round voxel balloon grows around the torso (shirt color, lighter top) for the whole buff
local function balloonShell()
	local out = {}
	local rx, ry, rz = 2.7, 2.1, 2.5
	for x = -3, 3 do
		for y = -3, 3 do
			for z = -3, 3 do
				local e = (x / rx) ^ 2 + (y / ry) ^ 2 + (z / rz) ^ 2
				local inner = ((math.abs(x) + 1) / rx) ^ 2 + ((math.abs(y) + 1) / ry) ^ 2 + ((math.abs(z) + 1) / rz) ^ 2
				if e <= 1 and inner > 1 then
					table.insert(out, Vector3.new(x, y, z))
				end
			end
		end
	end
	return out
end
local SHELL = balloonShell()
FX.F_BalloonBody = function(d)
	local char = d.char
	local torso = typeof(char) == "Instance" and char:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local old = char:FindFirstChild("GVBalloon")
	if old then
		old:Destroy()
	end
	local body = voxBody(char)
	local shirtB = body and body:FindFirstChild("UpperTorso")
	local shirt = shirtB and shirtB.Color or C.pink
	local hum = char:FindFirstChildOfClass("Humanoid")
	local Fruits = require(game:GetService("ReplicatedStorage").Shared.Config.Fruits)
	local skill
	for _, s in ipairs(Fruits.ById.Bounce.skills) do
		if s.id == "F_BalloonBody" then
			skill = s
		end
	end
	local dur = skill and skill.duration or 12
	local model = Instance.new("Model")
	model.Name = "GVBalloon"
	local center = CFrame.new(0, -0.55, -0.25)
	local cells = {}
	for _, v in ipairs(SHELL) do
		local c = v.Y >= 2 and shirt:Lerp(C.white, 0.25) or (v.Y <= -2 and shirt:Lerp(Color3.new(0, 0, 0), 0.15) or shirt)
		local b = Instance.new("Part")
		b.Size = Vector3.new(0.05, 0.05, 0.05)
		b.Color = c
		b.Material = Enum.Material.SmoothPlastic
		b.CanCollide, b.CanQuery, b.CanTouch, b.Massless, b.CastShadow = false, false, false, true, false
		b.CFrame = torso.CFrame
		local w = Instance.new("Weld")
		w.Part0, w.Part1 = torso, b
		w.C0 = center
		w.Parent = b
		b.Parent = model
		table.insert(cells, { w = w, b = b, v = v })
	end
	model.Parent = char
	local function scale(k)
		for _, e in ipairs(cells) do
			e.w.C0 = center * CFrame.new(e.v * k)
			e.b.Size = Vector3.new(1.02, 1.02, 1.02) * math.max(0.05, k)
		end
	end
	scale(0.05)
	local t0 = os.clock() + 0.3 -- grows on the inhale (Bounce_Balloon strike 0.45)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not model.Parent or not char.Parent or (hum and hum.Health <= 0) or char:GetAttribute("Downed") then
			t = math.max(t, dur)
		end
		if t < 0 then
			return
		elseif t < 0.3 then
			local k = t / 0.3
			scale(k + math.sin(k * math.pi) * 0.25) -- overshoot
		elseif t < dur then
			scale(1 + math.sin(t * 5) * 0.025) -- breathing wobble
		elseif t < dur + 0.25 then
			scale(1 - (t - dur) / 0.25)
		else
			conn:Disconnect()
			model:Destroy()
		end
	end)
	task.delay(0.3, function()
		Voxels.Pixels(torso.Position, { count = 20, colors = { C.pink, C.white }, size = 0.35, speed = 10, gravity = 0, life = 0.5, glow = 0.4, spread = 3 })
	end)
	-- deflating: air rushes out of the mouth
	task.delay(0.3 + dur, function()
		if torso.Parent then
			Voxels.Pixels(torso.Position + Vector3.new(0, 1.6, 0), { count = 26, colors = { C.white, Color3.fromRGB(225, 240, 255) }, size = 0.4, speed = 16, gravity = 0, life = 0.45, glow = 0.2, spread = 0.8 })
		end
	end)
end
-- a blow bounced off the balloon (CombatService fruitBody): a pink spring ring at you, a pop at the attacker
FX.F_BalloonBounce = function(d)
	local to = d.to or d.from
	vfx().Shockwave(d.from, to - d.from, C.pink, 6)
	task.delay(0.12, function()
		vfx().ImpactSplit(to, to - d.from, C.pink, 3)
	end)
end
-- Pump Up: steam pours off you and the skin flushes red for the whole buff
FX.F_GearUp = function(d)
	local char = d.char
	local r = charRoot(d)
	if not r then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local Fruits = require(game:GetService("ReplicatedStorage").Shared.Config.Fruits)
	local dur = 18
	for _, s in ipairs(Fruits.ById.Bounce.skills) do
		if s.id == "F_GearUp" then
			dur = s.duration or dur
		end
	end
	local old = char:FindFirstChild("GVPumpUp")
	if old then
		old:Destroy()
	end
	local hl = Instance.new("Highlight")
	hl.Name = "GVPumpUp"
	hl.FillColor = Color3.fromRGB(255, 70, 70)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	local steam = { Color3.fromRGB(255, 235, 235), C.white, Color3.fromRGB(255, 200, 205) }
	task.delay(0.5, function() -- the flex (Bounce_PumpUp strike)
		if not r.Parent then
			return
		end
		tw(hl, 0.25, { FillTransparency = 0.68 })
		vfx().Ring(ground(r.Position) + Vector3.new(0, 0.3, 0), 9, Color3.fromRGB(255, 120, 120), 0.45)
		Voxels.Pixels(r.Position + Vector3.new(0, 1, 0), { count = 50, colors = steam, size = 0.5, speed = 12, gravity = -12, life = 1, glow = 0.2, spread = 2.5 })
	end)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur + 0.5 and hl.Parent and r.Parent and not (hum and hum.Health <= 0) do
			local t = os.clock() - t0
			if t > 0.5 then
				-- thick at first, then a light steady steam (and a pulse in the red)
				Voxels.Pixels(r.Position + Vector3.new(0, 0.8, 0), { count = t < 2 and 10 or 4, colors = steam, size = 0.45, speed = 3, gravity = -9, life = 0.9, glow = 0.2, spread = 2.2 })
				hl.FillTransparency = 0.68 + math.sin(t * 6) * 0.06
			end
			task.wait(t < 2 and 0.12 or 0.35)
		end
		if hl.Parent then
			tw(hl, 0.4, { FillTransparency = 1 })
			Debris:AddItem(hl, 0.45)
		end
	end)
end

-- ===== Split Split =====
local function seamPixels(pos)
	Voxels.Pixels(pos, { count = 10, colors = { C.purple, C.lilac }, size = 0.25, speed = 6, gravity = 0, life = 0.4, glow = 0.8, spread = 1 })
end
FX.F_SplitCannon = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	if (to - from).Magnitude < 1 then
		return
	end
	local cf = CFrame.lookAt(from, to)
	local f = fistBlocks(cf, { C.skin, C.skin }, 1.3, false)
	local seam = blk(Vector3.new(2.2, 0.2, 0.2), C.purple, cf * CFrame.new(0, 0, 0.7), true)
	table.insert(f, seam)
	local t = math.clamp((to - from).Magnitude / 70, 0.12, 0.5)
	moveAll(f, cf, CFrame.lookAt(to, to + (to - from).Unit), t)
	for k = 1, 5 do
		task.delay(t * k / 5, function()
			seamPixels(from:Lerp(to, k / 5))
		end)
	end
	for _, p in ipairs(f) do
		fade(p, t, 0.15)
	end
	task.delay(t, function()
		Voxels.Blocks(to, { count = 10, colors = { C.purple, C.lilac, C.white }, size = { 0.25, 0.5 }, speed = 10, up = 4, neon = true, collide = false, life = 0.5, spread = 1 })
	end)
end
FX.F_ChopRush = function(d)
	local to = d.to or d.from
	for k = 0, 5 do
		task.delay(k * 0.07, function()
			local a = math.random() * math.pi
			local cf = CFrame.new(to + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.random() * 6.28, a)
			local s = blk(Vector3.new(7, 0.25, 0.25), k % 2 == 0 and C.purple or C.white, cf, true, 0.1)
			tw(s, 0.15, { Size = Vector3.new(9, 0.08, 0.08), Transparency = 1 })
			Debris:AddItem(s, 0.2)
			seamPixels(to + Vector3.new(0, 1.5, 0))
		end)
	end
end
FX.F_SplitEscape = function(d)
	local r = charRoot(d)
	local at = r and r.Position or d.from
	for i = 1, 3 do
		local b = blk(Vector3.new(1.6, 1.4, 1), i == 1 and C.skin or C.purple, CFrame.new(at + Vector3.new(0, (i - 2) * 1.6, 0)), false, 0.15)
		local out = Vector3.new(math.cos(i * 2.1), 0.3, math.sin(i * 2.1)) * 5
		tw(b, 0.2, { CFrame = CFrame.new(at + out + Vector3.new(0, (i - 2) * 1.6, 0)) * CFrame.Angles(0, i, 0.4) })
		task.delay(0.35, function()
			tw(b, 0.2, { CFrame = CFrame.new(at + Vector3.new(0, (i - 2) * 1.6, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		fade(b, 0.55, 0.1)
	end
	seamPixels(at)
end
FX.F_SplitFestival = function(d)
	local at = d.from
	local r = d.radius or 16
	local pieces = {}
	for i = 1, 14 do
		pieces[i] = { b = blk(Vector3.new(1, 1, 1) * (0.8 + math.random() * 0.6), i % 3 == 0 and C.purple or C.skin, CFrame.new(at), i % 3 == 0, 0), a = i / 14 * 6.28, rr = r * (0.4 + math.random() * 0.6), h = math.random() * 4 }
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = os.clock() - t0
		for _, e in ipairs(pieces) do
			local a = e.a + k * 9
			local rr = e.rr * math.min(1, k * 3)
			e.b.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * rr, e.h, math.sin(a) * rr)) * CFrame.Angles(a, a, 0)
		end
		if k > 0.9 then
			conn:Disconnect()
			for _, e in ipairs(pieces) do
				seamPixels(e.b.Position)
				fade(e.b, 0, 0.2)
			end
		end
	end)
end

-- ===== Slick Slick =====
local function oilPuddle(pos, size, life)
	local p = blk(Vector3.new(size, 0.12, size), C.oil, CFrame.new(ground(pos) + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, math.random() * 6, 0), false, 0.05)
	local s = blk(Vector3.new(size * 0.35, 0.13, size * 0.18), C.shine, p.CFrame * CFrame.new(-size * 0.15, 0.01, -size * 0.15), true, 0.35)
	p.Size = Vector3.new(0.2, 0.12, 0.2)
	tw(p, 0.25, { Size = Vector3.new(size, 0.12, size) })
	fade(p, life, 0.6)
	fade(s, life, 0.6)
end
local function oilDrops(pos, n)
	Voxels.Blocks(pos, { count = n, colors = { C.oil, C.oil2, C.shine }, size = { 0.2, 0.4 }, speed = 8, up = 6, collide = false, life = 0.5, spread = 1 })
end
FX.F_SlickSlide = function(d)
	local from, to = d.from, d.to or d.from
	along(from, to, 7, function(p, i)
		task.delay(i * 0.03, function()
			oilPuddle(p, 2.4, 1.6)
		end)
	end)
	oilDrops(to, 10)
end
FX.F_SlipAway = function(d)
	local r = charRoot(d)
	local at = r and r.Position or d.from
	oilPuddle(at, 5, 2)
	oilDrops(at, 14)
	Voxels.Pixels(at, { count = 16, colors = { C.shine, C.white }, size = 0.3, speed = 6, gravity = 0, life = 0.6, glow = 0.8, spread = 2 })
end
FX.F_SlickSpin = function(d)
	local at = d.from
	local r = d.radius or 11
	local blocks = {}
	for i = 1, 20 do
		blocks[i] = blk(Vector3.new(0.9, 0.5, 0.9), i % 4 == 0 and C.shine or C.oil2, CFrame.new(at), i % 4 == 0)
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = os.clock() - t0
		for i, b in ipairs(blocks) do
			local a = i / #blocks * 6.28 + k * 14
			local rr = r * math.min(1, k * 4)
			b.CFrame = CFrame.new(ground(at) + Vector3.new(math.cos(a) * rr, 0.8, math.sin(a) * rr))
		end
		if k > 0.6 then
			conn:Disconnect()
			for _, b in ipairs(blocks) do
				fade(b, 0, 0.2)
			end
		end
	end)
	oilDrops(at, 12)
end
FX.F_OilSlick = function(d)
	local at = d.to or d.from
	local r = d.radius or 14
	oilPuddle(at, r * 1.6, 3)
	for _ = 1, 6 do
		oilPuddle(at + Vector3.new((math.random() - 0.5) * r, 0, (math.random() - 0.5) * r), r * 0.5, 2.6)
	end
	oilDrops(at + Vector3.new(0, 2, 0), 20)
end

-- v0.25.65 fruit v2: new skills borrow the closest existing look until their own pass (docs/Plan-Fruits-v2.md)
FX.F_SmokeFist = FX.F_SmokeGrip
FX.F_Emberflies = FX.F_FireDash
FX.F_SplitRunner = FX.F_SplitEscape

function FX.Play(d)
	local f = FX[d.skill or ""]
	if f then
		local ok, err = pcall(f, d)
		if not ok then
			warn("[FruitFX]", d.skill, err)
		end
	end
end

function FX.Start()
	folder = Instance.new("Folder")
	folder.Name = "FruitFX"
	folder.Parent = workspace
end

return FX
