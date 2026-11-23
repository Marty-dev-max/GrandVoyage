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
-- v0.25.74 Blaze phase 3 (docs/Plan-Fruits-v2.md): timings follow the server (strike of each Blaze_* clip + travel)
local EMBER = Color3.fromRGB(120, 255, 110) -- Emberflies drift green, then burst orange
local EMBER2 = Color3.fromRGB(210, 255, 170)
-- the caster's arm wrapped in flame for a moment (pixel flames off the hand block)
local function armFlame(char, side, seconds)
	local hand = typeof(char) == "Instance" and char:FindFirstChild((side or "Right") .. "Hand")
	if not hand then
		return
	end
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < seconds and hand.Parent do
			Voxels.Pixels(hand.Position, { count = 5, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.32, speed = 2.5, gravity = -9, life = 0.4, glow = 1, spread = 0.7 })
			task.wait(0.05)
		end
	end)
end
FX.ArmFlame = armFlame

-- Blaze Fist: the arm bursts into flame, a GIANT fist of fire flies (server: strike 0.08 + 0.2 travel), explodes
FX.F_FireFist = function(d)
	local to = d.to or d.from
	local from = d.from + Vector3.new(0, 1, 0)
	local hand = typeof(d.char) == "Instance" and d.char:FindFirstChild("RightHand")
	if hand then
		from = hand.Position
	end
	local dir = to - from
	if dir.Magnitude < 0.5 then
		return
	end
	armFlame(d.char, "Right", 0.45)
	task.delay(0.08, function()
		local fromCF = CFrame.lookAt(from, to)
		local parts = fistBlocks(fromCF, { C.fire2, C.fire1 }, 2.6, true)
		table.insert(parts, blk(Vector3.new(3.6, 3.6, 3.6), C.fire3, fromCF * CFrame.new(0, 0, 1.2), true, 0.45))
		table.insert(parts, blk(Vector3.new(2.4, 2.4, 4.5), C.fire1, fromCF * CFrame.new(0, 0, 2.6), true, 0.55))
		moveAll(parts, fromCF, CFrame.lookAt(to, to + dir.Unit), 0.2)
		for k = 1, 8 do
			task.delay(0.2 * k / 8, function()
				Voxels.Pixels(from:Lerp(to, k / 8), { count = 14, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.45, speed = 4, gravity = -10, life = 0.55, glow = 1, spread = 2 })
			end)
		end
		for _, p in ipairs(parts) do
			fade(p, 0.2, 0.15)
		end
	end)
	task.delay(0.28, function()
		fireBurst(to, 2)
		local V = require(script.Parent.VFX)
		V.Shockwave(to, dir, C.fire2, 9)
		V.Ring(ground(to) + Vector3.new(0, 0.3, 0), 10, C.fire2, 0.4)
	end)
end

-- Flame Twister: a tornado of fire blocks spins up from the ground and keeps turning while the server ticks
-- (5 hits, 0.35 s apart from 0.3 s)
FX.F_FlamePillar = function(d)
	local at = ground(d.to or d.from)
	local r = math.min(d.radius or 14, 16) * 0.6
	local blocks = {}
	for i = 1, 46 do
		local h = (i / 46) * 18
		local c = h < 5 and C.fire3 or (h < 11 and C.fire2 or C.fire1)
		blocks[i] = { b = blk(Vector3.one * (1.4 - h * 0.035), c, CFrame.new(at), true, 0.1), a = math.random() * 6.28, h = h }
	end
	local t0 = os.clock() + 0.25
	local life = 1.75
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t < 0 then
			return
		end
		local grow = math.min(1, t / 0.25)
		local shrink = t > life and math.max(0, 1 - (t - life) / 0.3) or 1
		for _, e in ipairs(blocks) do
			local rr = (r * 0.25 + r * (e.h / 18)) * grow * shrink -- a funnel, wide at the top
			local a = e.a + t * (9 - e.h * 0.2)
			e.b.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * rr, e.h * grow, math.sin(a) * rr)) * CFrame.Angles(a, a * 0.7, 0)
			e.b.Transparency = 0.1 + (1 - shrink) * 0.9
		end
		if t > life + 0.3 then
			conn:Disconnect()
			for _, e in ipairs(blocks) do
				e.b:Destroy()
			end
		end
	end)
	for k = 0, 6 do
		task.delay(0.3 + k * 0.25, function()
			Voxels.Pixels(at + Vector3.new(0, 2, 0), { count = 26, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.4, speed = 14, gravity = -16, life = 0.9, glow = 1, spread = r })
		end)
	end
	task.delay(0.3, function()
		require(script.Parent.VFX).Ring(at + Vector3.new(0, 0.3, 0), r * 1.6, C.fire2, 0.5)
	end)
end

-- Emberflies (v0.25.77, owner: no dark puffs, the green fire leaves YOUR body and sticks to the enemies): green
-- sparks fly out of your chest to the monsters around the spot, cling to them, then burst orange one by one
-- (server: delay 1.0 after the 0.2 strike, then 4 bursts 0.18 apart)
FX.F_Emberflies = function(d)
	local to = d.to or d.from
	local r = math.min(d.radius or 12, 14)
	local chest = typeof(d.char) == "Instance" and d.char:FindFirstChild("UpperTorso")
	local start = chest and chest.Position or (d.from + Vector3.new(0, 1.5, 0))
	-- the monsters it will cling to (nearest the spot first); spare sparks hover over the spot
	local hosts = {}
	local folder_ = workspace:FindFirstChild("Monsters")
	for _, m in ipairs(folder_ and folder_:GetChildren() or {}) do
		local p = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart"))
		if p and (p.Position - to).Magnitude <= r + 3 then
			table.insert(hosts, { part = p, d = (p.Position - to).Magnitude })
		end
	end
	table.sort(hosts, function(a, b)
		return a.d < b.d
	end)
	local flies = {}
	for i = 1, 9 do
		local host = #hosts > 0 and hosts[(i - 1) % #hosts + 1].part or nil
		local a = i * 2.4
		local off = Vector3.new(math.cos(a) * 1.6, 0.5 + (i % 3) * 0.8, math.sin(a) * 1.6)
		local spot = to + Vector3.new(math.cos(a) * r * 0.5, 1.5, math.sin(a) * r * 0.5)
		local core = blk(Vector3.new(0.55, 0.55, 0.55), EMBER2, CFrame.new(start), true, 0)
		local halo = blk(Vector3.new(1.2, 1.2, 1.2), EMBER, CFrame.new(start), true, 0.5)
		flies[i] = { core = core, halo = halo, host = host, off = off, spot = spot, seed = math.random() * 10, launch = 0.18 + i * 0.035 }
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, f in ipairs(flies) do
			if f.core.Parent then
				local target = (f.host and f.host.Parent) and (f.host.Position + f.off) or f.spot
				local k = math.clamp((t - f.launch) / 0.45, 0, 1)
				local ease = 1 - (1 - k) ^ 3
				local p = start:Lerp(target, ease) + Vector3.new(0, math.sin(ease * math.pi) * 2.5, 0)
				if k >= 1 then
					p = target + Vector3.new(math.sin(t * 6 + f.seed), math.sin(t * 9 + f.seed), math.cos(t * 5 + f.seed)) * 0.25
				end
				local pulse = 1 + math.sin(t * 16 + f.seed) * 0.25
				f.core.CFrame = CFrame.new(p) * CFrame.Angles(t * 4, t * 3, 0)
				f.halo.CFrame = CFrame.new(p)
				f.halo.Size = Vector3.one * 1.2 * pulse
				if k > 0 and k < 1 and math.random() < 0.4 then
					Voxels.Pixels(p, { count = 2, colors = { EMBER, EMBER2 }, size = 0.25, speed = 1, gravity = -3, life = 0.3, glow = 1, spread = 0.2 })
				end
			end
		end
		if t > 2 then
			conn:Disconnect()
		end
	end)
	for i, f in ipairs(flies) do
		task.delay(1.2 + ((i - 1) % 4) * 0.18 + math.random() * 0.04, function()
			local p = f.core.Parent and f.core.Position or f.spot
			f.core:Destroy()
			f.halo:Destroy()
			fireBurst(p, 0.9)
			local b = blk(Vector3.new(1, 1, 1), C.fire1, CFrame.new(p), true, 0.2)
			tw(b, 0.22, { Size = Vector3.new(5, 5, 5), Transparency = 1 })
			Debris:AddItem(b, 0.25)
		end)
	end
end

-- a fireball growing over the caster's head while the Inferno key is held (local, the caster's own view)
function FX.ChargeBall(char)
	local head = typeof(char) == "Instance" and (char:FindFirstChild("VoxelHead", true) or char:FindFirstChild("Head"))
	if not head then
		return function() end
	end
	local core = blk(Vector3.one, C.fire1, CFrame.new(head.Position), true, 0)
	local shell = blk(Vector3.one, C.fire2, CFrame.new(head.Position), true, 0.35)
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		local s = math.min(1, t / 1.2)
		local size = 1 + s * 4.5
		local p = head.Position + Vector3.new(0, 2 + size * 0.55, 0)
		core.Size = Vector3.one * size * 0.7
		shell.Size = Vector3.one * size * (1 + math.sin(t * 14) * 0.05)
		core.CFrame = CFrame.new(p) * CFrame.Angles(t * 2, t * 3, 0)
		shell.CFrame = CFrame.new(p) * CFrame.Angles(-t * 2.5, t, t)
		if math.random() < 0.6 then
			Voxels.Pixels(p, { count = 3, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.4, speed = 3, gravity = -8, life = 0.5, glow = 1, spread = size * 0.5 })
		end
	end)
	return function()
		conn:Disconnect()
		core:Destroy()
		shell:Destroy()
	end
end

-- Inferno (v0.25.77, owner): the giant fireball is hurled the way you aim (strike 0.14, 0.4 of flight) and bursts
-- into a sea of fire where it lands
FX.F_Inferno = function(d)
	local to = d.to or d.from
	local head = typeof(d.char) == "Instance" and d.char:FindFirstChild("UpperTorso")
	local from = (head and head.Position or d.from) + Vector3.new(0, 5, 0)
	local r = 14
	task.delay(0.14, function()
		local core = blk(Vector3.one * 3.6, C.fire1, CFrame.new(from), true, 0)
		local shell = blk(Vector3.one * 5.4, C.fire2, CFrame.new(from), true, 0.35)
		local t0 = os.clock()
		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function()
			local k = math.min(1, (os.clock() - t0) / 0.4)
			local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			core.CFrame = CFrame.new(p) * CFrame.Angles(k * 9, k * 7, 0)
			shell.CFrame = CFrame.new(p) * CFrame.Angles(-k * 6, k * 4, k * 3)
			Voxels.Pixels(p, { count = 5, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.5, speed = 3, gravity = -6, life = 0.5, glow = 1, spread = 2 })
			if k >= 1 then
				conn:Disconnect()
				core:Destroy()
				shell:Destroy()
			end
		end)
	end)
	task.delay(0.54, function()
		local at = ground(to)
		local V = require(script.Parent.VFX)
		V.Ring(at + Vector3.new(0, 0.3, 0), r, C.fire2, 0.5)
		V.Shockwave(at + Vector3.new(0, 2, 0), Vector3.yAxis, C.fire1, r * 0.8)
		fireBurst(at + Vector3.new(0, 2, 0), 2.6)
		for ring = 1, 4 do
			task.delay(ring * 0.06, function()
				local n = 10 + ring * 7
				for i = 1, n do
					local a = i / n * math.pi * 2 + ring * 0.4
					local p = at + Vector3.new(math.cos(a), 0, math.sin(a)) * (r * ring / 4) * (0.85 + math.random() * 0.3)
					local h = 1 + math.random() * 2.5
					local c = ring <= 1 and C.fire1 or (ring <= 2 and C.fire2 or C.fire3)
					local b = blk(Vector3.new(1.3, 0.2, 1.3), c, CFrame.new(p + Vector3.new(0, 0.1, 0)), true, 0.05)
					tw(b, 0.25, { Size = Vector3.new(1.3, h, 1.3), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) }, Enum.EasingStyle.Back)
					task.delay(0.5 + math.random() * 0.6, function()
						if b.Parent then
							tw(b, 0.35, { Size = Vector3.new(0.4, h * 1.6, 0.4), CFrame = CFrame.new(p + Vector3.new(0, h * 1.4, 0)), Transparency = 1 })
						end
					end)
					Debris:AddItem(b, 1.6)
				end
			end)
		end
	end)
end

-- ===== Haze Haze =====
local function smokePuff(pos, n, spread, life)
	Voxels.Pixels(pos, { count = n, colors = { C.smoke1, C.smoke2, C.smoke3 }, size = 0.7, speed = 2, gravity = -1, life = life or 1.2, glow = 0, spread = spread })
end
FX.F_SmokeBody = function(d)
	local r = charRoot(d)
	local p = r and r.Position or d.from
	smokePuff(p, 60, 3, 1.4)
	Voxels.Blocks(p, { count = 10, colors = { C.smoke1, C.smoke2 }, size = { 0.4, 0.8 }, speed = 5, up = 4, collide = false, life = 0.8, spread = 1.5 })
end
-- v0.25.76 Haze phase 4 (docs/Plan-Fruits-v2.md): timings follow the server (strike of each clip + travel)
-- Smoke Fist: a heavy fist of white smoke (Blaze_Fist pose: strike 0.08 + 0.2 travel), bursting into a cloud
FX.F_SmokeFist = function(d)
	local to = d.to or d.from
	local hand = typeof(d.char) == "Instance" and d.char:FindFirstChild("RightHand")
	local from = hand and hand.Position or (d.from + Vector3.new(0, 1, 0))
	local dir = to - from
	if dir.Magnitude < 0.5 then
		return
	end
	task.delay(0.08, function()
		local fromCF = CFrame.lookAt(from, to)
		local parts = fistBlocks(fromCF, { C.smoke1, C.smoke2 }, 2.4, false)
		for _, p in ipairs(parts) do
			p.Transparency = 0.1
		end
		table.insert(parts, blk(Vector3.new(3.4, 3.4, 3.4), C.smoke2, fromCF * CFrame.new(0, 0, 1.1), false, 0.5))
		moveAll(parts, fromCF, CFrame.lookAt(to, to + dir.Unit), 0.2)
		for k = 1, 7 do
			task.delay(0.2 * k / 7, function()
				smokePuff(from:Lerp(to, k / 7), 10, 1.4, 0.8)
			end)
		end
		for _, p in ipairs(parts) do
			fade(p, 0.2, 0.25)
		end
	end)
	task.delay(0.28, function()
		smokePuff(to, 50, 3.5, 1.3)
		Voxels.Blocks(to, { count = 14, colors = { C.smoke1, C.smoke2, C.smoke3 }, size = { 0.5, 1 }, speed = 14, up = 6, collide = false, life = 0.7, spread = 1.5 })
		require(script.Parent.VFX).Shockwave(to, dir, C.smoke1, 8)
	end)
end
-- Smoke Screen: the cloud rolls out of the sweep and hangs there as long as it blinds (server `smoke` seconds)
FX.F_SmokeScreen = function(d)
	local at = ground(d.to or d.from) + Vector3.new(0, 2, 0)
	local r = d.radius or 14
	local last = tonumber(d.smoke) or 6
	local banks = {}
	task.delay(0.28, function()
		for _ = 1, 12 do
			local off = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5) * r * 1.5
			local b = blk(Vector3.new(1, 1, 1), math.random() < 0.5 and C.smoke1 or C.smoke2, CFrame.new(at + off), false, 0.3)
			tw(b, 0.6, { Size = Vector3.new(5 + math.random() * 3, 3 + math.random() * 2, 5 + math.random() * 3), Transparency = 0.45 })
			table.insert(banks, b)
		end
	end)
	-- puffs keep rolling while it lasts
	for k = 0, math.floor(last / 0.5) do
		task.delay(0.28 + k * 0.5, function()
			smokePuff(at + Vector3.new((math.random() - 0.5) * r, 0, (math.random() - 0.5) * r), 22, r * 0.9, 1.6)
		end)
	end
	task.delay(0.28 + last, function()
		for _, b in ipairs(banks) do
			if b.Parent then
				tw(b, 0.8, { Transparency = 1, Size = b.Size * 1.3 })
				Debris:AddItem(b, 0.85)
			end
		end
	end)
end
-- Smoke Grip: a long arm of smoke snakes out of the hand (strike 0.12 + 0.2), coils round the enemy, then hauls it
-- back to you (the server drags the monster in at the same moment)
FX.F_SmokeGrip = function(d)
	local to = d.to or d.from
	local char = d.char
	local function handPos()
		local h = typeof(char) == "Instance" and char:FindFirstChild("RightHand")
		return h and h.Position or (d.from + Vector3.new(0, 1, 0))
	end
	local N = 16
	local segs = {}
	for i = 1, N do
		segs[i] = blk(Vector3.one * (1.1 - i * 0.025), i % 3 == 0 and C.smoke2 or C.smoke1, CFrame.new(handPos()), false, 0.15)
	end
	local coil = {}
	for i = 1, 8 do
		coil[i] = blk(Vector3.new(0.9, 0.9, 0.9), C.smoke1, CFrame.new(to), false, 1)
	end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		local base = handPos()
		local reach -- 0..1 how far the arm is out
		local tip = to
		if t < 0.12 then
			reach = 0
		elseif t < 0.32 then
			reach = (t - 0.12) / 0.2
		elseif t < 0.46 then
			reach = 1
		else
			-- haul back: the tip comes home with the enemy
			local k = math.min(1, (t - 0.46) / 0.3)
			tip = to:Lerp(base + (to - base).Unit * 4, k * k)
			reach = 1
		end
		local path = tip - base
		local side = path.Magnitude > 0.1 and path.Unit:Cross(Vector3.yAxis) or Vector3.xAxis
		side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
		for i, b in ipairs(segs) do
			local a = i / N
			local shown = a <= reach
			local wave = side * math.sin(a * math.pi * 3 - t * 18) * 1.1 * math.sin(a * math.pi) + Vector3.new(0, math.cos(a * math.pi * 2 - t * 14) * 0.5, 0)
			b.CFrame = CFrame.new(base + path * (a * math.max(reach, 0.001)) + wave) * CFrame.Angles(t * 3 + i, t * 2, 0)
			b.Transparency = shown and 0.15 or 1
		end
		-- the coil round the enemy (0.32 .. 0.76)
		local coiled = t > 0.3 and t < 0.76
		for i, b in ipairs(coil) do
			local a = i / #coil * math.pi * 2 + t * 10
			b.CFrame = CFrame.new(tip + Vector3.new(math.cos(a) * 2.2, 1 + math.sin(t * 6 + i) * 0.8, math.sin(a) * 2.2))
			b.Transparency = coiled and 0.2 or 1
		end
		if t > 0.8 then
			conn:Disconnect()
			for _, b in ipairs(segs) do
				smokePuff(b.Position, 2, 0.5, 0.5)
				b:Destroy()
			end
			for _, b in ipairs(coil) do
				b:Destroy()
			end
		end
	end)
	task.delay(0.32, function()
		smokePuff(to + Vector3.new(0, 2, 0), 26, 2.5, 0.9)
	end)
end
-- the caster turns invisible on EVERY client for `seconds` (White Out)
local function vanishChar(char, seconds)
	if typeof(char) ~= "Instance" then
		return
	end
	local hidden = {}
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.LocalTransparencyModifier < 1 then
			p.LocalTransparencyModifier = 1
			table.insert(hidden, p)
		elseif p:IsA("Decal") and p.Transparency < 1 then
			table.insert(hidden, p)
			p:SetAttribute("GVVanishT", p.Transparency)
			p.Transparency = 1
		end
	end
	task.delay(seconds, function()
		for _, p in ipairs(hidden) do
			if p.Parent then
				if p:IsA("Decal") then
					p.Transparency = p:GetAttribute("GVVanishT") or 0
				else
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end
-- White Out: you dissolve into a tornado of smoke that follows you around (6 hits, 0.4 s apart from 0.25)
FX.F_WhiteOut = function(d)
	local root = charRoot(d)
	if not root then
		return
	end
	local r = math.min(d.radius or 18, 20)
	local dur = tonumber(d.vanish) or 2.6
	task.delay(0.2, function()
		smokePuff(root.Position, 60, 3, 1.2)
		vanishChar(d.char, dur)
	end)
	local blocks = {}
	for i = 1, 40 do
		local h = math.random() * 12
		blocks[i] = { b = blk(Vector3.one * (0.6 + math.random() * 0.9), i % 3 == 0 and C.smoke2 or C.smoke1, CFrame.new(root.Position), false, 0.15), a = math.random() * 6.28, h = h, rr = 1.2 + h * 0.35 }
	end
	local t0 = os.clock() + 0.2
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		local at = root.Parent and ground(root.Position) or ground(d.from)
		local grow = math.clamp(t / 0.25, 0, 1)
		local fadeK = t > dur - 0.3 and math.max(0, (dur - t) / 0.3) or 1
		for _, e in ipairs(blocks) do
			local a = e.a + t * (8 - e.h * 0.25)
			local rr = e.rr * grow * (0.7 + 0.3 * fadeK) * (r / 18)
			e.b.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * rr, 0.5 + e.h * grow, math.sin(a) * rr)) * CFrame.Angles(a, a * 0.5, 0)
			e.b.Transparency = 0.15 + (1 - fadeK) * 0.85
		end
		if t > dur then
			conn:Disconnect()
			for _, e in ipairs(blocks) do
				e.b:Destroy()
			end
			if root.Parent then
				smokePuff(root.Position, 40, 2.5, 1)
			end
		end
	end)
	for k = 0, math.floor(dur / 0.4) do
		task.delay(0.25 + k * 0.4, function()
			if root.Parent then
				smokePuff(ground(root.Position) + Vector3.new(0, 3, 0), 18, r * 0.7, 1.2)
			end
		end)
	end
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
		local n = math.max(1, math.ceil(len / (o.seg or 1)))
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

-- Pump Up running (fxData.pumped, v0.25.69 owner): the moves are compressed air: a ring of air bursts off the elbow
-- and rings fly down the path ahead of a fist that is there in a blink
local AIR = Color3.fromRGB(235, 248, 255)
local function airBlast(from, to, size)
	local dir = to - from
	if dir.Magnitude < 0.5 then
		return
	end
	local V = vfx()
	local n = math.clamp(math.floor(dir.Magnitude / 6), 2, 7)
	for i = 0, n do
		task.delay(i * 0.012, function()
			V.Shockwave(from:Lerp(to, i / n), dir, AIR, size * (0.55 + 0.45 * i / n))
		end)
	end
	V.SpeedLines(from, to, AIR, 10)
	Voxels.Pixels(from, { count = 14, colors = { AIR, C.white, Color3.fromRGB(255, 215, 220) }, size = 0.35, speed = 8, gravity = -5, life = 0.5, glow = 0.2, spread = 1 })
end
FX.AirBlast = airBlast

FX.F_StretchPistol = function(d)
	local to = d.to or d.from
	local base = elbow(d.char, "Right", d.from + Vector3.new(0, 1, 0))
	local dir = to - base
	if dir.Magnitude < 1 then
		return
	end
	if d.pumped then
		-- pumped: strike 0.05 + 0.06 of air travel (server)
		hideArm(d.char, "Right", 0.38)
		task.delay(0.05, airBlast, base, to, 5)
		rubberArm({ char = d.char, side = "Right", from = d.from, to = to, delay = 0.05, tOut = 0.06, hold = 0.05, tBack = 0.13 })
		task.delay(0.11, function()
			local V = vfx()
			V.ImpactSplit(to, dir, AIR, 6.5)
			V.Shockwave(to, dir, C.pink, 8)
			boing(to, 3)
		end)
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
-- Bounce Gatling (owner v0.25.69: "many Stretch Pistols"): real stretching arms, both sides in turn, each one shooting
-- out to a spot around the target and snapping back; pumped = twice as many, faster, each with a puff of air
FX.F_BounceGatling = function(d)
	local to = d.to or d.from
	if (to - d.from).Magnitude < 1 then
		return
	end
	local pumped = d.pumped
	local arms = pumped and 24 or 16
	local first, span = pumped and 0.025 or 0.04, pumped and 0.5 or 0.5
	local hits, every = pumped and 12 or 8, pumped and 0.045 or 0.07
	hideArm(d.char, "Right", first + span + 0.2)
	hideArm(d.char, "Left", first + span + 0.2)
	for k = 0, arms - 1 do
		local sideName = k % 2 == 0 and "Right" or "Left"
		local jitter = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.8, math.random() - 0.5) * 3.6
		local at = first + k * span / arms
		rubberArm({ char = d.char, side = sideName, from = d.from, to = to + jitter, delay = at, tOut = pumped and 0.035 or 0.05,
			hold = 0.015, tBack = pumped and 0.045 or 0.065, thick = 0.75, seg = 1.4 })
		if pumped and k % 3 == 0 then
			task.delay(at, function()
				airBlast(elbow(d.char, sideName, d.from), to + jitter, 2.5)
			end)
		end
	end
	-- one impact per server hit
	for i = 0, hits - 1 do
		task.delay(first + (pumped and 0.035 or 0.05) + i * every, function()
			vfx().ImpactSplit(to + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2, to - d.from, pumped and AIR or C.pink, 2.6)
		end)
	end
end
FX.F_RecoilCannon = function(d)
	local to = d.to or d.from
	local dir = to - d.from
	if dir.Magnitude < 1 then
		return
	end
	local pumped = d.pumped
	-- normal: strike 0.1 + 0.2 travel; pumped: 0.06 + 0.06
	local strike, travel = pumped and 0.06 or 0.1, pumped and 0.06 or 0.2
	hideArm(d.char, "Right", pumped and 0.5 or 0.75)
	hideArm(d.char, "Left", pumped and 0.5 or 0.75)
	local side = dir.Unit:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
	for _, s in ipairs({ { "Right", 1 }, { "Left", -1 } }) do
		rubberArm({ char = d.char, side = s[1], from = d.from, to = to + side * s[2] * 1.1 + Vector3.new(0, 0.6, 0), delay = strike, tOut = travel,
			hold = pumped and 0.1 or 0.12, tBack = pumped and 0.2 or 0.28, palm = true, thick = 0.95 })
	end
	-- the recoil: dust ring at your feet as you shove
	task.delay(strike, function()
		vfx().Ring(ground(d.from) + Vector3.new(0, 0.3, 0), pumped and 9 or 6, C.white, 0.35)
		if pumped then
			airBlast(d.from + Vector3.new(0, 1, 0), to, 11)
		end
	end)
	task.delay(strike + travel, function()
		local V = vfx()
		V.Shockwave(to, dir, C.white, pumped and 18 or 13)
		V.ImpactSplit(to, dir, pumped and AIR or C.pink, pumped and 10 or 8)
		V.Ring(ground(to) + Vector3.new(0, 0.3, 0), pumped and 24 or 16, C.pink, 0.5)
		Voxels.Blocks(to, { count = pumped and 24 or 16, colors = { C.pink, C.white, C.lilac }, size = { 0.3, 0.7 }, speed = pumped and 30 or 22, up = 8, neon = true, collide = false, life = 0.6, spread = 2 })
		boing(to, pumped and 6 or 4)
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

-- ===== Blaze Flight (v0.25.74): while a Blaze user flies, the forearms and lower legs turn to fire (every client) =====
-- Flight tells the server (FlyState -> char attribute Flying); here the voxel blocks of those limbs hide locally and
-- pixel flames pour off the R15 parts underneath.
local FIRE_LIMBS = { "LeftLowerArm", "LeftHand", "RightLowerArm", "RightHand", "LeftLowerLeg", "LeftFoot", "RightLowerLeg", "RightFoot" }
local fireDressed = setmetatable({}, { __mode = "k" })
local function flameEmitter(parent, big)
	local Textures = require(game:GetService("ReplicatedStorage").Shared.Config.Textures)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BlazeLimb"
	e.Texture = Textures.px_flame or Textures.flame or ""
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.fire1), ColorSequenceKeypoint.new(0.45, C.fire2), ColorSequenceKeypoint.new(1, C.fire3) })
	e.LightEmission, e.LightInfluence = 1, 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.3 or 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, 7, 0)
	e.Rate = big and 45 or 30
	e.Parent = parent
	return e
end
-- v0.25.77 Haze flight: the lower legs turn to smoke and a long line of smoke trails behind you
local function smokeEmitter(parent, trail)
	local Textures = require(game:GetService("ReplicatedStorage").Shared.Config.Textures)
	local e = Instance.new("ParticleEmitter")
	e.Name = "HazeLimb"
	e.Texture = Textures.px_smoke or Textures.smoke or ""
	e.Color = ColorSequence.new(C.smoke1, C.smoke2)
	e.LightEmission, e.LightInfluence = 0.2, 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, trail and 1.6 or 1), NumberSequenceKeypoint.new(1, trail and 2.6 or 0.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = trail and NumberRange.new(1.2, 1.6) or NumberRange.new(0.3, 0.5)
	e.Speed = trail and NumberRange.new(0, 0.3) or NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Rate = trail and 60 or 30
	e.Parent = parent
	return e
end
local SMOKE_LIMBS = { "LeftLowerLeg", "LeftFoot", "RightLowerLeg", "RightFoot" }
local dressFire
dressFire = function(char, on, kind)
	local st = fireDressed[char]
	if st and on and st.kind ~= kind then
		dressFire(char, false) -- switched fruit while flying
		st = nil
	end
	if on and not st then
		st = { emitters = {}, blocks = {}, kind = kind }
		fireDressed[char] = st
		local limbs = {}
		for _, n in ipairs(kind == "Haze" and SMOKE_LIMBS or FIRE_LIMBS) do
			local p = char:FindFirstChild(n)
			if p then
				limbs[p] = true
				table.insert(st.emitters, kind == "Haze" and smokeEmitter(p, false) or flameEmitter(p, string.find(n, "Lower") ~= nil))
			end
		end
		local torso = char:FindFirstChild("LowerTorso")
		if kind == "Haze" and torso then
			table.insert(st.emitters, smokeEmitter(torso, true)) -- the line of smoke left in the sky
		end
		-- the sound of it: a soft crackling fire / a hiss of smoke, on the body
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			st.sound = require(script.Parent.Audio).Attach(kind == "Haze" and "HazeFlyLoop" or "BlazeFlyLoop", root, 70)
		end
		local body = char:FindFirstChild("VoxelBody")
		for _, b in ipairs(body and body:GetChildren() or {}) do
			local w = b:FindFirstChildOfClass("WeldConstraint")
			if w and limbs[w.Part0] then
				b.LocalTransparencyModifier = 1
				table.insert(st.blocks, b)
			end
		end
	elseif not on and st then
		fireDressed[char] = nil
		if st.sound then
			st.sound:Destroy()
		end
		for _, e in ipairs(st.emitters) do
			e.Enabled = false
			Debris:AddItem(e, 0.5)
		end
		for _, b in ipairs(st.blocks) do
			if b.Parent then
				b.LocalTransparencyModifier = 0
			end
		end
	end
end

function FX.Start()
	folder = Instance.new("Folder")
	folder.Name = "FruitFX"
	folder.Parent = workspace
	task.spawn(function()
		local Players = game:GetService("Players")
		while true do
			for _, pl in ipairs(Players:GetPlayers()) do
				local c = pl.Character
				if c then
					local fruit = pl:GetAttribute("Fruit")
					dressFire(c, (fruit == "Blaze" or fruit == "Haze") and c:GetAttribute("Flying") == true, fruit)
				end
			end
			for c in pairs(fireDressed) do
				if not c.Parent then
					fireDressed[c] = nil
				end
			end
			task.wait(0.2)
		end
	end)
end

return FX
