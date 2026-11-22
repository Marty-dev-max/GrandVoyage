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

-- ===== Bounce Bounce =====
FX.F_StretchPistol = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	local len = (to - from).Magnitude
	if len < 1 then
		return
	end
	local cf = CFrame.lookAt(from, to)
	local arm = blk(Vector3.new(0.9, 0.9, 0.1), C.skin, cf, false)
	tw(arm, 0.14, { Size = Vector3.new(0.9, 0.9, len), CFrame = cf * CFrame.new(0, 0, -len / 2) })
	local fist = fistBlocks(cf, { C.skin, C.skin }, 1.5, false)
	moveAll(fist, cf, CFrame.lookAt(to, to + (to - from).Unit), 0.14)
	task.delay(0.16, function()
		Voxels.Pixels(to, { count = 30, colors = { C.white, C.pink }, size = 0.35, speed = 14, gravity = 0, life = 0.4, glow = 0.6, spread = 1 })
		tw(arm, 0.18, { Size = Vector3.new(0.9, 0.9, 0.1), CFrame = cf })
		moveAll(fist, CFrame.lookAt(to, to + (to - from).Unit), cf, 0.18)
		fade(arm, 0.18, 0.05)
		for _, p in ipairs(fist) do
			fade(p, 0.18, 0.05)
		end
	end)
end
FX.F_BounceGatling = function(d)
	local from, to = d.from + Vector3.new(0, 1, 0), d.to or d.from
	if (to - from).Magnitude < 1 then
		return
	end
	for k = 1, 10 do
		task.delay(k * 0.045, function()
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
			local cf = CFrame.lookAt(from + jitter * 0.3, to + jitter)
			local f = fistBlocks(cf, { C.skin, C.skin }, 0.9, false)
			moveAll(f, cf, CFrame.lookAt(to + jitter, to + jitter + (to - from).Unit), 0.09)
			for _, p in ipairs(f) do
				fade(p, 0.09, 0.08)
			end
			task.delay(0.09, function()
				Voxels.Pixels(to + jitter, { count = 6, colors = { C.white, C.pink }, size = 0.3, speed = 8, gravity = 0, life = 0.25, glow = 0.5, spread = 0.5 })
			end)
		end)
	end
end
FX.F_BalloonBody = function(d)
	local r = charRoot(d)
	local at = r and r.Position or d.from
	local b = blk(Vector3.new(3, 3, 3), C.pink, CFrame.new(at), false, 0.35)
	tw(b, 0.3, { Size = Vector3.new(8, 8, 8) }, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		tw(b, 0.25, { Size = Vector3.new(3, 3, 3), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	Debris:AddItem(b, 0.8)
	Voxels.Pixels(at, { count = 20, colors = { C.pink, C.white }, size = 0.35, speed = 10, gravity = 0, life = 0.5, glow = 0.4, spread = 3 })
end
FX.F_GearUp = function(d)
	local r = charRoot(d)
	if not r then
		return
	end
	for k = 0, 12 do
		task.delay(k * 0.15, function()
			if r.Parent then
				Voxels.Pixels(r.Position + Vector3.new(0, 1, 0), { count = 10, colors = { Color3.fromRGB(255, 230, 235), C.pink, C.white }, size = 0.45, speed = 3, gravity = -10, life = 0.9, glow = 0.3, spread = 2.5 })
			end
		end)
	end
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
FX.F_RecoilCannon = FX.F_StretchPistol
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
