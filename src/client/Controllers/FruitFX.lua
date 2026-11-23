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
				-- v0.25.80 (owner): green turns orange just before each one bursts
				local heat = math.clamp((t - (f.burst - 0.45)) / 0.45, 0, 1)
				f.core.Color = EMBER2:Lerp(C.fire1, heat)
				f.halo.Color = EMBER:Lerp(C.fire2, heat)
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
		f.burst = 1.2 + ((i - 1) % 4) * 0.18 + math.random() * 0.04
	end
	for _, f in ipairs(flies) do
		task.delay(f.burst, function()
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

-- v0.25.81 (owner reference clip: a round VOXEL-art fireball, pixel particles, a soft billowing landing):
-- the ball is a sphere of cubes (yellow-white core -> orange -> red rim) that churns (cubes flicker between shades and
-- wobble), with pixel flames + embers streaming off it. move(cf, k) places it (k = scale), destroy() removes it.
local function voxelFireBall(radius)
	local cells = {}
	local cell = radius / 3.2
	local n = 4
	for ix = -n, n do
		for iy = -n, n do
			for iz = -n, n do
				local p = Vector3.new(ix, iy, iz) * cell
				local d = p.Magnitude
				if d <= radius and d >= radius - cell * 1.6 then
					local depth = d / radius
					local c = depth > 0.85 and C.fire3 or (depth > 0.7 and C.fire2 or C.fire1)
					local b = blk(Vector3.one * cell * 1.02, c, CFrame.new(p), true, depth > 0.85 and 0.15 or 0)
					table.insert(cells, { p = b, off = p, depth = depth, seed = math.random() * 10 })
				end
			end
		end
	end
	local core = blk(Vector3.one * radius * 1.3, Color3.fromRGB(255, 250, 220), CFrame.new(), true, 0)
	local light = Instance.new("PointLight")
	light.Color = C.fire2
	light.Range = radius * 5
	light.Brightness = 4
	light.Parent = core
	local Textures = require(game:GetService("ReplicatedStorage").Shared.Config.Textures)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Textures.px_flame or Textures.flame or ""
	pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.fire1), ColorSequenceKeypoint.new(0.5, C.fire2), ColorSequenceKeypoint.new(1, C.fire3) })
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	pe.Transparency = NumberSequence.new(0.05, 1)
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(2, 6)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.Acceleration = Vector3.new(0, 14, 0)
	pe.Rate = 60
	pe.Parent = core
	local parts, cfs = {}, {}
	local function move(cf, k)
		local t = os.clock()
		table.clear(parts)
		table.clear(cfs)
		for _, e in ipairs(cells) do
			local wob = 1 + math.sin(t * 9 + e.seed) * 0.05
			table.insert(parts, e.p)
			table.insert(cfs, cf * CFrame.new(e.off * k * wob))
			e.p.Size = Vector3.one * cell * 1.02 * k
			if math.random() < 0.08 then
				-- churning: a cube flickers one shade hotter or cooler
				e.p.Color = (e.depth > 0.85 and (math.random() < 0.5 and C.fire3 or C.fire2)) or (math.random() < 0.5 and C.fire2 or C.fire1)
			end
		end
		table.insert(parts, core)
		table.insert(cfs, cf)
		core.Size = Vector3.one * radius * 1.3 * k
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.35 * k), NumberSequenceKeypoint.new(1, 0.1) })
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		if math.random() < 0.5 then
			Voxels.Pixels(cf.Position, { count = 2, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.35 * k + 0.15, speed = 4, gravity = -10, life = 0.6, glow = 1, spread = radius * k })
		end
	end
	local function destroy()
		for _, e in ipairs(cells) do
			e.p:Destroy()
		end
		pe.Enabled = false
		core.Transparency = 1
		light:Destroy()
		Debris:AddItem(core, 0.7)
	end
	return move, destroy
end

-- a fireball growing over the caster's head while the Inferno key is held (local, the caster's own view)
function FX.ChargeBall(char)
	local head = typeof(char) == "Instance" and (char:FindFirstChild("VoxelHead", true) or char:FindFirstChild("Head"))
	if not head then
		return function() end
	end
	local R = 6 -- full size radius
	local move, destroy = voxelFireBall(R)
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = 0.2 + math.min(1, t / 1.2) * 0.8
		local p = head.Position + Vector3.new(0, 2 + R * k, 0)
		move(CFrame.new(p) * CFrame.Angles(t * 0.8, t * 1.3, 0), k)
	end)
	return function()
		conn:Disconnect()
		destroy()
	end
end

-- Inferno (v0.25.77, owner): the giant fireball is hurled the way you aim (strike 0.14, 0.4 of flight); v0.25.81: it
-- lands with a soft BILLOW of fire (cubes swell up and roll outward, cool to red and smoke) instead of a hard burst,
-- and a carpet of low flames stays where it fell
FX.F_Inferno = function(d)
	local to = d.to or d.from
	local head = typeof(d.char) == "Instance" and d.char:FindFirstChild("UpperTorso")
	local from = (head and head.Position or d.from) + Vector3.new(0, 9, 0)
	local r = d.splash or 18
	local R = 6
	task.delay(0.14, function()
		local move, destroy = voxelFireBall(R)
		local t0 = os.clock()
		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function()
			local t = os.clock() - t0
			local k = math.min(1, t / 0.4)
			local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			move(CFrame.new(p) * CFrame.Angles(t * 3, t * 2, 0), 1)
			if k >= 1 then
				conn:Disconnect()
				destroy()
			end
		end)
	end)
	task.delay(0.54, function()
		local at = ground(to)
		local V = require(script.Parent.VFX)
		V.Ring(at + Vector3.new(0, 0.3, 0), r, C.fire2, 0.7)
		-- the billow: fire cubes swell up from the impact and roll outward + upward, cooling to red then smoke
		local smoke = Color3.fromRGB(70, 60, 58)
		for _ = 1, 46 do
			local a = math.random() * math.pi * 2
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local dist = r * (0.25 + math.random() * 0.75)
			local up = 2 + math.random() * 9 * (1 - dist / r) + math.random() * 3
			local size = 1.2 + math.random() * 2.6
			local p0 = at + Vector3.new(0, 1.5, 0) + out * 1.5
			local p1 = at + out * dist + Vector3.new(0, up, 0)
			local b = blk(Vector3.one * 0.4, C.fire1, CFrame.new(p0) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), true, 0)
			local life = 0.9 + math.random() * 0.7
			tw(b, life * 0.45, { CFrame = CFrame.new(p0:Lerp(p1, 0.75)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Size = Vector3.one * size, Color = C.fire2 }, Enum.EasingStyle.Quart)
			task.delay(life * 0.45, function()
				if b.Parent then
					tw(b, life * 0.55, { CFrame = CFrame.new(p1 + Vector3.new(0, 3, 0)), Size = Vector3.one * size * 0.3, Color = (math.random() < 0.4) and smoke or C.fire3, Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				end
			end)
			Debris:AddItem(b, life + 0.1)
		end
		Voxels.Pixels(at + Vector3.new(0, 2, 0), { count = 70, colors = { C.fire1, C.fire2, C.fire3 }, size = 0.45, speed = 16, gravity = -9, life = 1.1, glow = 1, spread = r * 0.4 })
		-- low flames left on the ground for a moment
		for i = 1, 18 do
			local a = i / 18 * math.pi * 2
			local p = at + Vector3.new(math.cos(a), 0, math.sin(a)) * r * (0.3 + math.random() * 0.6)
			local h = 0.8 + math.random() * 1.6
			local b = blk(Vector3.new(1.2, 0.2, 1.2), math.random() < 0.5 and C.fire2 or C.fire3, CFrame.new(p), true, 0.1)
			tw(b, 0.3, { Size = Vector3.new(1.2, h, 1.2), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) }, Enum.EasingStyle.Back)
			task.delay(0.8 + math.random() * 0.8, function()
				if b.Parent then
					tw(b, 0.4, { Size = Vector3.new(0.4, h * 1.5, 0.4), CFrame = CFrame.new(p + Vector3.new(0, h * 1.3, 0)), Transparency = 1 })
				end
			end)
			Debris:AddItem(b, 2.2)
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
-- Smoke Screen (v0.25.80, owner): PUNCH a fist of smoke at the chosen spot (Blaze_Fist strike, then `delay` of flight
-- = d.travel); it bursts there into the cloud, which hangs as long as it blinds (server `smoke` seconds)
FX.F_SmokeScreen = function(d)
	local at = ground(d.to or d.from) + Vector3.new(0, 2, 0)
	local r = d.radius or 14
	local last = tonumber(d.smoke) or 6
	local strike = math.clamp(tonumber(d.strike) or 0.08, 0, 0.5)
	local land = strike + math.clamp(tonumber(d.travel) or 0.3, 0.05, 0.8)
	local banks = {}
	local hand = typeof(d.char) == "Instance" and d.char:FindFirstChild("RightHand")
	local from = hand and hand.Position or (d.from + Vector3.new(0, 1, 0))
	if (at - from).Magnitude > 1 then
		task.delay(strike, function()
			local fromCF = CFrame.lookAt(from, at)
			local parts = fistBlocks(fromCF, { C.smoke1, C.smoke2 }, 2.2, false)
			table.insert(parts, blk(Vector3.new(3, 3, 3), C.smoke2, fromCF * CFrame.new(0, 0, 1.1), false, 0.5))
			moveAll(parts, fromCF, CFrame.lookAt(at, at + (at - from).Unit), land - strike)
			for k = 1, 6 do
				task.delay((land - strike) * k / 6, function()
					smokePuff(from:Lerp(at, k / 6), 8, 1.2, 0.8)
				end)
			end
			for _, p in ipairs(parts) do
				fade(p, land - strike, 0.15)
			end
		end)
	end
	task.delay(land, function()
		-- the burst: a shockwave of smoke blocks, then the banks swell
		smokePuff(at, 60, r * 0.5, 1.4)
		Voxels.Blocks(at, { count = 16, colors = { C.smoke1, C.smoke2, C.smoke3 }, size = { 0.6, 1.2 }, speed = 18, up = 5, collide = false, life = 0.8, spread = 2 })
		require(script.Parent.VFX).Ring(at - Vector3.new(0, 1.7, 0), r, C.smoke1, 0.5)
		for _ = 1, 12 do
			local off = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5) * r * 1.5
			local b = blk(Vector3.new(1, 1, 1), math.random() < 0.5 and C.smoke1 or C.smoke2, CFrame.new(at + off), false, 0.3)
			tw(b, 0.6, { Size = Vector3.new(5 + math.random() * 3, 3 + math.random() * 2, 5 + math.random() * 3), Transparency = 0.45 })
			table.insert(banks, b)
		end
	end)
	-- puffs keep rolling while it lasts
	for k = 0, math.floor(last / 0.5) do
		task.delay(land + 0.3 + k * 0.5, function()
			smokePuff(at + Vector3.new((math.random() - 0.5) * r, 0, (math.random() - 0.5) * r), 22, r * 0.9, 1.6)
		end)
	end
	task.delay(land + last, function()
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

-- ===== v0.25.79 Shield phase 5: held barriers (Channel), their release, blocked blows, Barrier Steps =====
local GLASS, GLASS2 = Color3.fromRGB(150, 240, 255), Color3.fromRGB(80, 200, 240)
local function glassPane(size, cf, transp)
	local p = blk(size, GLASS, cf, true, transp or 0.62)
	local rim = blk(size + Vector3.new(0.25, 0.25, -size.Z + 0.06), GLASS2, cf, true, 0.25)
	return p, rim
end
-- the barrier a channeling character holds up (every client sees it): a 3x3 wall of panes in front, or a dome
local barriers = setmetatable({}, { __mode = "k" })
-- v0.25.80 (owner reference): the barrier is CLEAR GLASS, not a snowy glow: see-through panes (Glass material) with thin
-- pale edges and bright diagonal shine streaks that glint as a light band sweeps across
local function clearPane(size, cf)
	local p = blk(size, Color3.fromRGB(205, 245, 255), cf, false, 0.8)
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.15
	local rim = blk(size + Vector3.new(0.18, 0.18, -size.Z + 0.05), Color3.fromRGB(170, 235, 255), cf, true, 0.55)
	return p, rim
end
FX.ClearPane = clearPane
local function streak(cf, len)
	return blk(Vector3.new(0.22, len, 0.05), Color3.new(1, 1, 1), cf, true, 0.2)
end
local function grounded(char, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }
	return workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params) ~= nil
end
-- v0.25.81 (owner): the dome is VOXEL: a shell of clear glass cubes on a grid (a hemisphere on the ground, a whole
-- sphere in the air), every 4th cube carrying a diagonal shine streak that glints as a light band sweeps over.
-- All cubes are welded to one anchored hub, so following the holder moves a single part per frame.
local function voxelDome(char, root, radius)
	local r = math.min(radius or 14, 18)
	local sphere = not grounded(char, root)
	local cy = sphere and 0 or -2.6
	local cell = 2.4
	local hub = blk(Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), CFrame.new(root.Position + Vector3.new(0, cy, 0)), false, 1)
	local cubes, streaks = {}, {}
	local n = math.ceil(r / cell) + 1
	for ix = -n, n do
		for iy = sphere and -n or 0, n do
			for iz = -n, n do
				local p = Vector3.new(ix, iy, iz) * cell
				if math.abs(p.Magnitude - r) <= cell * 0.5 then
					local c = blk(Vector3.one * 0.1, Color3.fromRGB(205, 245, 255), hub.CFrame * CFrame.new(p), false, 0.82)
					c.Material = Enum.Material.Glass
					c.Reflectance = 0.15
					c.Anchored = false
					c.Massless = true
					local w = Instance.new("WeldConstraint")
					w.Part0, w.Part1 = hub, c
					w.Parent = c
					table.insert(cubes, { p = c, d = p.Magnitude, pos = p })
					if (ix + iy * 3 + iz * 5) % 4 == 0 then
						local out = p.Unit
						local cf = CFrame.lookAt(p + out * (cell * 0.52), p + out * 2) * CFrame.Angles(0, 0, 0.7)
						local sk = blk(Vector3.new(0.2, cell * 0.9, 0.05), Color3.new(1, 1, 1), hub.CFrame * cf, true, 0.75)
						sk.Anchored = false
						sk.Massless = true
						local w2 = Instance.new("WeldConstraint")
						w2.Part0, w2.Part1 = hub, sk
						w2.Parent = sk
						table.insert(streaks, { p = sk, phase = (p.X + p.Y) * 0.25 })
					end
				end
			end
		end
	end
	-- pop in ring by ring from the bottom (sizes only; the welds keep them in place)
	for _, e in ipairs(cubes) do
		local delay = math.clamp((e.pos.Y + r) / (2 * r), 0, 1) * 0.15
		task.delay(delay, function()
			if e.p.Parent then
				e.p.Size = Vector3.one * cell
			end
		end)
	end
	local conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not root.Parent then
			return
		end
		hub.CFrame = CFrame.new(root.Position + Vector3.new(0, cy, 0))
		local now = os.clock()
		for _, e in ipairs(streaks) do
			local glint = (math.sin(now * 2.2 - e.phase) + 1) / 2
			e.p.Transparency = 0.8 - glint ^ 3 * 0.75
		end
	end)
	local st = { shape = "Dome" }
	function st.stop()
		conn:Disconnect()
		barriers[char] = nil
		for _, e in ipairs(cubes) do
			e.p.Anchored = true
			fade(e.p, 0, 0.2)
		end
		for _, e in ipairs(streaks) do
			e.p.Anchored = true
			fade(e.p, 0, 0.2)
		end
		Debris:AddItem(hub, 0.3)
	end
	return st
end
local function dressBarrier(char, shape, radius)
	local st = barriers[char]
	if st and st.shape ~= shape then
		st.stop()
		st = nil
	end
	if not shape then
		if st then
			st.stop()
		end
		return
	end
	if st then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if shape == "Dome" then
		barriers[char] = voxelDome(char, root, radius)
		return
	end
	local parts = {}
	local layout = {} -- { offset CFrame in root space, size, world-aligned }
	if shape == "Wall" then
		for x = -1, 1 do
			for y = -1, 1 do
				table.insert(layout, { CFrame.new(x * 2.6, 1 + y * 2.6, -4), Vector3.new(2.5, 2.5, 0.25) })
			end
		end
	else
		-- a hemisphere on the ground, a full sphere when you are up in the air
		local r = math.min(radius or 14, 18)
		local sphere = not grounded(char, root)
		local cy = sphere and 0 or -2.6
		local ringsUp = 5
		for ring = sphere and -ringsUp + 1 or 0, ringsUp - 1 do
			local el = ring / ringsUp * math.pi / 2
			local rr = math.cos(el) * r
			local n = math.max(6, math.floor(rr * 2 * math.pi / 3))
			local w = rr * 2 * math.pi / n + 0.15
			local hgt = r * math.pi / 2 / ringsUp + 0.15
			for i = 1, n do
				local a = i / n * math.pi * 2 + ring * 0.2
				local pos = Vector3.new(math.cos(a) * rr, math.sin(el) * r + cy, math.sin(a) * rr)
				table.insert(layout, { CFrame.lookAt(pos, Vector3.new(0, cy, 0)), Vector3.new(w, hgt, 0.2), true })
			end
		end
		table.insert(layout, { CFrame.new(0, r + cy, 0) * CFrame.Angles(math.pi / 2, 0, 0), Vector3.new(3.2, 3.2, 0.2), true })
		if sphere then
			table.insert(layout, { CFrame.new(0, -r + cy, 0) * CFrame.Angles(-math.pi / 2, 0, 0), Vector3.new(3.2, 3.2, 0.2), true })
		end
	end
	for i, l in ipairs(layout) do
		local p, rim = clearPane(Vector3.new(0.1, 0.1, 0.1), root.CFrame * l[1])
		local e = { p = p, rim = rim, off = l[1], size = l[2], world = l[3], phase = (l[1].Position.X + l[1].Position.Y) * 0.25 }
		-- every other pane carries one or two diagonal shine streaks
		if i % 2 == 0 or shape == "Wall" then
			e.streaks = {}
			local len = math.min(l[2].X, l[2].Y) * 0.95
			for k = 1, (i % 4 == 0) and 2 or 1 do
				table.insert(e.streaks, { part = streak(p.CFrame, len), off = CFrame.new((k - 1.5) * l[2].X * 0.3, 0, -0.13) * CFrame.Angles(0, 0, 0.7), len = len * (k == 2 and 0.6 or 1) })
			end
		end
		parts[i] = e
	end
	local t0 = os.clock()
	local conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not root.Parent then
			return
		end
		local now = os.clock()
		local k = math.min(1, (now - t0) / 0.18)
		local base = root.CFrame
		local moved, cfs = {}, {}
		for i, e in ipairs(parts) do
			local kk = math.clamp(k * 1.6 - i * 0.01, 0, 1)
			-- the dome stays level around you (no tilting with the body), the wall turns with you
			local cf = e.world and (CFrame.new(base.Position) * e.off) or (base * e.off)
			table.insert(moved, e.p)
			table.insert(cfs, cf)
			table.insert(moved, e.rim)
			table.insert(cfs, cf * CFrame.new(0, 0, 0.04))
			if kk < 1 or e.sized ~= true then
				e.p.Size = e.size * kk
				e.rim.Size = (e.size + Vector3.new(0.18, 0.18, -e.size.Z + 0.05)) * kk
				e.sized = kk >= 1
			end
			if e.streaks then
				-- a light band sweeps over the glass: the streaks glint as it passes
				local glint = (math.sin(now * 2.2 - e.phase) + 1) / 2
				for _, sk in ipairs(e.streaks) do
					table.insert(moved, sk.part)
					table.insert(cfs, cf * sk.off)
					sk.part.Size = Vector3.new(0.22, sk.len * kk, 0.05)
					sk.part.Transparency = 0.75 - glint ^ 3 * 0.7
				end
			end
		end
		workspace:BulkMoveTo(moved, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	st = { shape = shape }
	function st.stop()
		conn:Disconnect()
		barriers[char] = nil
		for _, e in ipairs(parts) do
			fade(e.p, 0, 0.2)
			fade(e.rim, 0, 0.2)
			for _, sk in ipairs(e.streaks or {}) do
				fade(sk.part, 0, 0.2)
			end
		end
	end
	barriers[char] = st
end
local function shatterGlass(pos, n)
	Voxels.Blocks(pos, { count = n or 14, colors = { GLASS, GLASS2, C.white }, size = { 0.3, 0.7 }, speed = 14, up = 6, neon = true, collide = false, life = 0.6, spread = 1.5 })
end
-- release: the wall slams forward and breaks on what it hits / the dome bursts outward
FX.F_BarrierWall_End = function(d)
	local look = typeof(d.look) == "Vector3" and d.look or Vector3.zAxis
	local from = d.from + Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(from + look * 4, from + look * 5)
	local p, rim = glassPane(Vector3.new(7.5, 7.5, 0.4), cf, 0.4)
	tw(p, 0.16, { CFrame = cf * CFrame.new(0, 0, -6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tw(rim, 0.16, { CFrame = cf * CFrame.new(0, 0, -5.95) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.16, function()
		fade(p, 0, 0.1)
		fade(rim, 0, 0.1)
		shatterGlass(from + look * 10, 26)
		require(script.Parent.VFX).Shockwave(from + look * 10, look, GLASS, 11)
	end)
end
FX.F_BarrierDome_End = function(d)
	local at = d.from
	local r = d.radius or 14
	require(script.Parent.VFX).Ring(ground(at) + Vector3.new(0, 0.3, 0), r * 1.3, GLASS, 0.5)
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2
		local pos = at + Vector3.new(math.cos(a) * r * 0.8, 1 + (i % 3) * 2, math.sin(a) * r * 0.8)
		local p = blk(Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(205, 245, 255), CFrame.lookAt(pos, at), false, 0.6)
		p.Material = Enum.Material.Glass
		tw(p, 0.35, { CFrame = CFrame.lookAt(pos + (pos - at).Unit * 6, at) * CFrame.Angles(1, 0.5, 0), Transparency = 1 })
		Debris:AddItem(p, 0.4)
	end
	shatterGlass(at + Vector3.new(0, 2, 0), 30)
end
-- a monster blow stopped by a barrier: the pane flashes where it was hit
FX.F_BarrierBlock = function(d)
	local to = d.to or d.from
	local dir = (to - d.from) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis
	local p = d.from + dir * 2.5
	local pane = blk(Vector3.new(3, 3, 0.3), C.white, CFrame.lookAt(p, p + dir), true, 0.2)
	tw(pane, 0.25, { Transparency = 1, Size = Vector3.new(4.5, 4.5, 0.3) })
	Debris:AddItem(pane, 0.3)
	Voxels.Pixels(p, { count = 10, colors = { GLASS, C.white }, size = 0.3, speed = 8, gravity = 0, life = 0.3, glow = 1, spread = 1 })
	pcall(function()
		require(script.Parent.Audio).Play("ShieldBlock", { pos = p })
	end)
end
-- Barrier Steps of OTHER players (yours are real, local, collidable ones below)
local function stepVisual(pos, collide)
	-- v0.25.81 (owner: the jump steps still had the old look): clear glass like the dome / stairs + a shine streak
	local p, rim = clearPane(Vector3.new(4.6, 0.45, 4.6), CFrame.new(pos))
	p.CanCollide = collide == true
	p.Size = Vector3.new(0.2, 0.45, 0.2)
	tw(p, 0.12, { Size = Vector3.new(4.6, 0.45, 4.6) }, Enum.EasingStyle.Back)
	rim.Size = Vector3.new(4.8, 0.12, 4.8)
	rim.CFrame = CFrame.new(pos - Vector3.new(0, 0.22, 0))
	local sh = blk(Vector3.new(0.22, 0.05, 4), Color3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, 0.24, 0)) * CFrame.Angles(0, 0.7, 0), true, 0.25)
	local life = require(game:GetService("ReplicatedStorage").Shared.Config.Fruits).BarrierSteps.Life
	fade(p, life, 0.4)
	fade(rim, life, 0.4)
	fade(sh, life, 0.4)
	Voxels.Pixels(pos, { count = 8, colors = { GLASS, C.white }, size = 0.25, speed = 4, gravity = 2, life = 0.3, glow = 1, spread = 1.5 })
	return p
end
FX.F_BarrierStep = function(d)
	if d.stepper == game:GetService("Players").LocalPlayer.UserId then
		return
	end
	stepVisual(d.from, false)
end
-- your own Barrier Steps: jump and keep Space held; at the top of each hop a step appears under your feet, you land on
-- it and (Space still held) jump again = stairs into the sky. MaxSteps before you must touch the ground again.
local function stepsLoop()
	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local Net = require(game:GetService("ReplicatedStorage").Shared.Modules.Net)
	local cfg = require(game:GetService("ReplicatedStorage").Shared.Config.Fruits).BarrierSteps
	local me = Players.LocalPlayer
	local count, lastAt = 0, 0
	game:GetService("RunService").Heartbeat:Connect(function()
		local c = me.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not h or not r or h.Health <= 0 or me:GetAttribute("Fruit") ~= "Ward" or c:GetAttribute("Downed") then
			return
		end
		local airborne = h.FloorMaterial == Enum.Material.Air
		if not airborne then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { c }
			local below = workspace:Raycast(r.Position, Vector3.new(0, -6, 0), rp)
			if not (below and below.Instance and below.Instance.Name == "BarrierStep") then
				count = 0 -- back on real ground
			end
			return
		end
		local held = UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) or h.Jump
		if not held or count >= cfg.MaxSteps or os.clock() - lastAt < 0.22 or r.AssemblyLinearVelocity.Y > 2 then
			return
		end
		lastAt = os.clock()
		count += 1
		local feet = r.Position - Vector3.new(0, h.HipHeight + r.Size.Y / 2 + 0.3, 0)
		local fwd = r.CFrame.LookVector * Vector3.new(1, 0, 1)
		local pos = feet + (fwd.Magnitude > 0.1 and fwd.Unit * 0.8 or Vector3.zero)
		local step = stepVisual(pos, true)
		step.Name = "BarrierStep"
		step.CanQuery = true
		task.spawn(Net.Request, "BarrierStep", { pos = pos })
	end)
end
FX.StepsLoop = stepsLoop

-- ===== v0.25.80 (owner) Ward Pistol + Glass Stairway =====
local RunService = game:GetService("RunService")
local function vfx()
	return require(script.Parent.VFX)
end
-- Ward Pistol (v0.25.81, owner): HOLD = a ball of glass panes + spinning light rings forms round the right fist and
-- grows; LET GO = the punch throws it: it flies until it meets an enemy (or where it stops) and bursts there.
local function glassOrb(hand, scale)
	local orb = {}
	for _, face in ipairs({ CFrame.new(0, 0, -1), CFrame.new(0, 0, 1), CFrame.new(1, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(-1, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(0, 1, 0) * CFrame.Angles(math.pi / 2, 0, 0), CFrame.new(0, -1, 0) * CFrame.Angles(math.pi / 2, 0, 0) }) do
		local p, rim = clearPane(Vector3.new(2, 2, 0.12), hand.CFrame * face)
		table.insert(orb, { p = p, off = face, size = Vector3.new(2, 2, 0.12) })
		table.insert(orb, { p = rim, off = face * CFrame.new(0, 0, 0.03), size = rim.Size })
	end
	for k = 1, 2 do
		for e = 0, 3 do
			local bar = blk(Vector3.new(2.8, 0.14, 0.14), Color3.fromRGB(230, 252, 255), hand.CFrame, true, 0.1)
			table.insert(orb, { p = bar, off = CFrame.Angles(0, k * 1.1, 0) * CFrame.Angles(0, 0, e * math.pi / 2) * CFrame.new(0, 1.4, 0), spin = k, size = bar.Size })
		end
	end
	local function place(cf, k, t)
		for _, e in ipairs(orb) do
			local spin = e.spin and CFrame.Angles(t * 14 * e.spin, t * 9, 0) or CFrame.identity
			local o = e.off
			e.p.CFrame = cf * spin * (o - o.Position) + (cf * spin):VectorToWorldSpace(o.Position * k)
			e.p.Size = e.size * Vector3.new(k, k, 1)
		end
	end
	local function destroy()
		for _, e in ipairs(orb) do
			e.p:Destroy()
		end
	end
	place(hand.CFrame, scale or 1, 0)
	return place, destroy
end
-- the caster's own view while the key is held (Combat startAim): grows from a fist-sized ball to full size
function FX.HoldOrb(char)
	local hand = typeof(char) == "Instance" and char:FindFirstChild("RightHand")
	if not hand then
		return function() end
	end
	local place, destroy = glassOrb(hand, 0.5)
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if hand.Parent then
			place(hand.CFrame, 0.5 + math.min(1, t / 1.2) * 0.6, t)
		end
	end)
	return function()
		conn:Disconnect()
		destroy()
	end
end
FX.F_BarrierBash = function(d)
	local char = d.char
	local hand = typeof(char) == "Instance" and char:FindFirstChild("RightHand")
	local strike = math.clamp(tonumber(d.strike) or 0.08, 0.02, 0.5)
	local travel = math.clamp(tonumber(d.travel) or 0.3, 0.02, 0.6)
	local to = d.to or d.from
	if not hand then
		return
	end
	-- the ball on the fist until the punch lands (everyone sees it), then it flies
	local place, destroy = glassOrb(hand, 1)
	local t0 = os.clock()
	local from
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t < strike then
			if hand.Parent then
				place(hand.CFrame, 1, t)
			end
			return
		end
		from = from or (hand.Parent and hand.Position or d.from)
		local k = math.min(1, (t - strike) / travel)
		local p = from:Lerp(to, k)
		place(CFrame.lookAt(p, to + (to - from).Unit), 1.1, t)
		if k >= 1 then
			conn:Disconnect()
			destroy()
			local VFX = vfx()
			local dir = (to - from).Magnitude > 0.1 and (to - from).Unit or Vector3.zAxis
			VFX.Flash(to, Color3.new(1, 1, 1), 7)
			VFX.ImpactSplit(to, dir, Color3.fromRGB(190, 245, 255), 7)
			VFX.Shockwave(to, dir, Color3.fromRGB(220, 250, 255), 9)
			shatterGlass(to, 26)
			Voxels.Blocks(ground(to) + Vector3.new(0, 0.5, 0), { count = 10, colors = { Color3.fromRGB(196, 180, 150), Color3.fromRGB(140, 128, 110) }, size = { 0.5, 1.1 }, speed = 14, up = 14, collide = false, life = 0.8, spread = 2 })
			pcall(function()
				require(script.Parent.Audio).Play("ShieldBlock", { pos = to, pitch = 0.7 })
				require(script.Parent.Audio).Play("PunchHeavy", { pos = to })
			end)
		end
	end)
end

-- Glass Stairway: one clear glass step (collidable, everyone builds their own copy), shine streak, fades after Life
local stairsFolder
local function stairsRoot()
	if not stairsFolder or not stairsFolder.Parent then
		stairsFolder = Instance.new("Folder")
		stairsFolder.Name = "GVStairs"
		stairsFolder.Parent = workspace
	end
	return stairsFolder
end
function FX.StairStep(pos, dir, mine)
	local cfg = require(game:GetService("ReplicatedStorage").Shared.Config.Fruits).GlassStairs
	dir = (dir and dir.Magnitude > 0.1) and Vector3.new(dir.X, 0, dir.Z).Unit or Vector3.zAxis
	local cf = CFrame.lookAt(pos, pos + dir)
	local size = Vector3.new(cfg.Width, 0.45, cfg.Run + 0.35)
	local p = blk(size, Color3.fromRGB(205, 245, 255), cf, false, 0.7)
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.15
	p.Name = "BarrierStep"
	p.CanCollide = true
	p.CanQuery = true
	p.Parent = stairsRoot()
	local edge = blk(Vector3.new(cfg.Width + 0.1, 0.12, 0.14), Color3.fromRGB(200, 245, 255), cf * CFrame.new(0, 0.2, -size.Z / 2), true, 0.15)
	edge.Parent = stairsRoot()
	local sh = blk(Vector3.new(0.2, 0.05, size.Z * 0.9), Color3.new(1, 1, 1), cf * CFrame.new(-cfg.Width * 0.2 + math.random() * 0.8, 0.24, 0) * CFrame.Angles(0, 0.6, 0), true, 0.25)
	sh.Parent = stairsRoot()
	-- pops in from nothing
	for _, q in ipairs({ p, edge, sh }) do
		local full = q.Size
		q.Size = full * Vector3.new(0.2, 1, 0.2)
		tw(q, 0.12, { Size = full }, Enum.EasingStyle.Back)
		fade(q, cfg.Life, 0.5)
	end
	Voxels.Pixels(pos, { count = 6, colors = { Color3.fromRGB(190, 245, 255), Color3.new(1, 1, 1) }, size = 0.25, speed = 4, gravity = 2, life = 0.3, glow = 1, spread = 1.5 })
	if mine then
		pcall(function()
			require(script.Parent.Audio).Play("ShieldBlock", { pos = pos, volume = 0.25, pitch = 1.4 + math.random() * 0.3 })
		end)
	end
	task.delay(cfg.Life + 0.3, function()
		if p.Parent then
			Voxels.Blocks(pos, { count = 4, colors = { Color3.fromRGB(190, 245, 255), Color3.new(1, 1, 1) }, size = { 0.25, 0.5 }, speed = 6, up = 3, neon = true, collide = false, life = 0.5 })
		end
	end)
	return p
end
local lastStairPt = {}
FX.F_GlassStairs_Step = function(d)
	if d.stepper == game:GetService("Players").LocalPlayer.UserId or type(d.pts) ~= "table" then
		return
	end
	local prev = (not d.first) and lastStairPt[d.stepper] or nil
	for _, pt in ipairs(d.pts) do
		if typeof(pt) == "Vector3" then
			local dir = prev and (pt - prev) or nil
			FX.StairStep(pt, dir, false)
			prev = pt
		end
	end
	lastStairPt[d.stepper] = prev
end

-- ===== Bounce Bounce (v0.25.66, docs/Plan-Fruits-v2.md phase 2) =====
-- The rubber arms are real voxel blocks in the character's own skin color (read from its hand block): a chain of
-- cubes from the elbow to the fist that stretches out, holds, and snaps back with a wobble. The real forearm + hand
-- hide (LocalTransparencyModifier, on every client) while the rubber arm is out.
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
-- ===== Split Split (v0.25.81, docs/Plan-Fruits-v2.md phase 6) =====
-- The pieces that fly are COPIES of your own voxel blocks (sleeves, gloves, shoes, face and all): the real ones hide
-- (LocalTransparencyModifier, every client) while the copies move as one group, with purple seam pixels at the cuts.
local ARM_R = { "RightLowerArm", "RightHand" }
local HAND_R = { "RightHand" }
local LEGS = { "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
local PIECES = {
	{ "Head" },
	{ "UpperTorso" },
	{ "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	{ "RightUpperArm", "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	{ "RightUpperLeg", "RightLowerLeg", "RightFoot" },
}
-- copies of the blocks welded to `limbs`, placed relative to pivot (default: the first limb), originals hidden
local function limbPieces(char, limbs, seconds, pivotCF)
	local body = voxBody(char)
	if not body then
		return nil
	end
	local set = {}
	for _, n in ipairs(limbs) do
		local l = char:FindFirstChild(n)
		if l then
			set[l] = true
			pivotCF = pivotCF or l.CFrame
		end
	end
	if not pivotCF then
		return nil
	end
	local g = { parts = {}, rel = {}, pivot = pivotCF }
	local untilT = os.clock() + seconds
	for _, b in ipairs(body:GetChildren()) do
		local w = b:FindFirstChildOfClass("WeldConstraint")
		if b:IsA("BasePart") and w and set[w.Part0] then
			local was = b.Archivable
			b.Archivable = true
			local c = b:Clone()
			b.Archivable = was
			if c then
				for _, ch in ipairs(c:GetChildren()) do
					if not ch:IsA("Decal") then
						ch:Destroy()
					end
				end
				c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
				c.LocalTransparencyModifier = 0
				c.Parent = folder
				table.insert(g.parts, c)
				table.insert(g.rel, pivotCF:ToObjectSpace(b.CFrame))
			end
			hiddenUntil[b] = math.max(hiddenUntil[b] or 0, untilT)
			b.LocalTransparencyModifier = 1
			for _, dcl in ipairs(b:GetChildren()) do
				if dcl:IsA("Decal") then
					dcl.LocalTransparencyModifier = 1
				end
			end
		end
	end
	task.delay(seconds + 0.03, function()
		for _, bb in ipairs(body:GetChildren()) do
			local t = hiddenUntil[bb]
			if t and os.clock() >= t then
				hiddenUntil[bb] = nil
				if bb.Parent then
					bb.LocalTransparencyModifier = 0
					for _, dcl in ipairs(bb:GetChildren()) do
						if dcl:IsA("Decal") then
							dcl.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end
	end)
	local cfs = {}
	function g.move(cf)
		for i, rel in ipairs(g.rel) do
			cfs[i] = cf * rel
		end
		if #g.parts > 0 then
			workspace:BulkMoveTo(g.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	function g.destroy()
		for _, c in ipairs(g.parts) do
			c:Destroy()
		end
	end
	return g
end
FX.LimbPieces = limbPieces
local function splitHit(pos, dir)
	vfx().ImpactSplit(pos, dir, C.lilac, 4.5)
	Voxels.Blocks(pos, { count = 8, colors = { C.purple, C.lilac, C.white }, size = { 0.25, 0.5 }, speed = 10, up = 4, neon = true, collide = false, life = 0.5, spread = 1 })
end

-- 1 Rocket Forearm (charge): the forearm + fist come off at the elbow, fly to the target spinning a little, punch,
-- and fly back to snap on again
FX.F_SplitCannon = function(d)
	local char = d.char
	local to = d.to or d.from
	local strike = math.clamp(tonumber(d.strike) or 0.08, 0, 0.5)
	local travel = math.clamp(tonumber(d.travel) or 0.25, 0.05, 0.6)
	task.delay(strike, function()
		local g = typeof(char) == "Instance" and limbPieces(char, ARM_R, travel * 2 + 0.25)
		if not g then
			return
		end
		local start = g.pivot
		local dir = (to - start.Position).Magnitude > 0.1 and (to - start.Position).Unit or Vector3.zAxis
		-- the arm points down its length (-Y): a +90 degree turn about X puts -Y onto -Z, along the flight
		local aim = CFrame.lookAt(start.Position, start.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t < travel then
				local k = t / travel
				g.move(aim + (to - dir * 1.2 - start.Position) * k + Vector3.zero)
				if math.random() < 0.6 then
					seamPixels(start.Position:Lerp(to, k))
				end
			elseif t < travel * 2 + 0.2 then
				if not g.hit then
					g.hit = true
					splitHit(to, dir)
				end
				-- fly back to the elbow (it may have moved)
				local elbowNow = typeof(char) == "Instance" and char:FindFirstChild("RightLowerArm")
				local home = elbowNow and elbowNow.Position or start.Position
				local k = math.min(1, (t - travel) / (travel + 0.2))
				local p = (to - dir * 1.2):Lerp(home, k * k)
				g.move(CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, k * 8, 0))
			else
				conn:Disconnect()
				g.destroy()
				seamPixels(start.Position)
			end
		end)
	end)
end

-- 2 Phantom Hand: the hand flies off, swoops round BEHIND the enemy with a little knife and stabs from a new angle
-- on every hit (server hits at strike + i x hitEvery), then flies home
FX.F_ChopRush = function(d)
	local char = d.char
	local to = d.to or d.from
	local strike = math.clamp(tonumber(d.strike) or 0.1, 0, 0.5)
	local hits, every = 4, 0.18
	task.delay(math.max(0, strike - 0.2), function()
		local g = typeof(char) == "Instance" and limbPieces(char, HAND_R, 0.2 + hits * every + 0.45)
		if not g then
			return
		end
		local knife = blk(Vector3.new(0.18, 0.18, 1.6), Color3.fromRGB(220, 226, 236), CFrame.new(), false, 0)
		knife.Material = Enum.Material.Metal
		local start = g.pivot.Position
		local fwd = (to - start) * Vector3.new(1, 0, 1)
		fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.zAxis
		local function angleSpot(i)
			local a = math.atan2(fwd.Z, fwd.X) + math.pi + (i - (hits + 1) / 2) * 0.9 -- behind, fanning round
			return to + Vector3.new(math.cos(a) * 4.5, 1 + (i % 2) * 1.2, math.sin(a) * 4.5)
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local p, look
			if t < 0.2 then
				-- the swoop: an arc over the enemy to behind it
				local k = t / 0.2
				local behind = angleSpot(1)
				p = start:Lerp(behind, k) + Vector3.new(0, math.sin(k * math.pi) * 4, 0)
				look = behind - start
			elseif t < 0.2 + hits * every then
				local i = math.floor((t - 0.2) / every) + 1
				local k = ((t - 0.2) % every) / every
				local spot = angleSpot(i)
				-- pull back, then thrust into the enemy
				local thrust = k < 0.55 and (k / 0.55) or (1 - (k - 0.55) / 0.45)
				p = spot:Lerp(to + Vector3.new(0, 1.2, 0), thrust * 0.8)
				look = to + Vector3.new(0, 1.2, 0) - spot
				if k >= 0.55 and g.lastStab ~= i then
					g.lastStab = i
					local s = blk(Vector3.new(4, 0.18, 0.18), i % 2 == 0 and C.purple or C.white, CFrame.lookAt(p, p + look) * CFrame.Angles(0, math.pi / 2, 0), true, 0.1)
					tw(s, 0.12, { Size = Vector3.new(6, 0.05, 0.05), Transparency = 1 })
					Debris:AddItem(s, 0.15)
					seamPixels(p)
				end
			elseif t < 0.2 + hits * every + 0.35 then
				local k = (t - 0.2 - hits * every) / 0.35
				local home = typeof(char) == "Instance" and char:FindFirstChild("RightLowerArm")
				local from = angleSpot(hits)
				local h = home and (home.CFrame * CFrame.new(0, -home.Size.Y / 2, 0)).Position or start
				p = from:Lerp(h, k * k)
				look = h - from
			else
				conn:Disconnect()
				g.destroy()
				knife:Destroy()
				return
			end
			look = look.Magnitude > 0.1 and look.Unit or fwd
			local cf = CFrame.lookAt(p, p + look)
			g.move(cf * CFrame.Angles(math.pi / 2, 0, 0))
			knife.CFrame = cf * CFrame.new(0, 0, -1.1)
		end)
	end)
end

-- 3 Split Runner (dash): your legs come off as a spinning wheel and run down everything along the dash (the server
-- slides you at 60 studs/s, hits at 0.08 + step / 60); the upper body glides along above it
FX.F_SplitRunner = function(d)
	local char = d.char
	local from, to = d.from, d.to or d.from
	local dist = (to - from).Magnitude
	local dur = 0.08 + dist / 60
	local g = typeof(char) == "Instance" and limbPieces(char, LEGS, dur + 0.25)
	if not g then
		return
	end
	local dir = dist > 0.1 and (to - from).Unit or Vector3.zAxis
	local axis = Vector3.yAxis:Cross(dir).Unit
	local hip = g.pivot.Position - from -- the wheel turns round the hips
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.clamp((t - 0.05) / dur, 0, 1)
		local c = from:Lerp(to, k) + hip - Vector3.new(0, 0.4, 0)
		g.move(CFrame.new(c) * CFrame.fromAxisAngle(axis, -t * 22) * (g.pivot - g.pivot.Position))
		if math.random() < 0.5 then
			Voxels.Pixels(c - Vector3.new(0, 2, 0), { count = 2, colors = { Color3.fromRGB(190, 175, 150), C.lilac }, size = 0.3, speed = 4, gravity = 6, life = 0.35, spread = 0.6 })
		end
		if t > dur + 0.2 then
			conn:Disconnect()
			g.destroy()
			seamPixels(c)
		end
	end)
end
FX.F_SplitEscape = FX.F_SplitRunner

-- 4 Scatter Storm: EVERY piece of you comes apart and whirls round in a wild ring (the head bobs in the middle),
-- slamming into everything around over and over (server ticks), then they all fly back together
FX.F_SplitFestival = function(d)
	local char = d.char
	local root = typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local r = math.min(d.radius or 16, 18)
	local strike = math.clamp(tonumber(d.strike) or 0.1, 0, 0.5)
	local dur = strike + 7 * 0.3 + 0.4
	local groups = {}
	for i, limbs in ipairs(PIECES) do
		local g = limbPieces(char, limbs, dur + 0.1)
		if g then
			g.home = root.CFrame:ToObjectSpace(g.pivot)
			g.a = i / #PIECES * math.pi * 2
			g.rr = i == 1 and 0 or r * (0.35 + math.random() * 0.45)
			g.h = (math.random() - 0.3) * 3
			g.spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18
			g.speed = 6 + math.random() * 5
			table.insert(groups, g)
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local c = root.Parent and root.Position or d.from
		-- out over 0.3 s, whirl, back together in the last 0.3 s
		local out = math.min(1, t / 0.3) * math.clamp((dur - t) / 0.3, 0, 1)
		for _, g in ipairs(groups) do
			local homeCF = (root.Parent and root.CFrame or CFrame.new(c)) * g.home
			local a = g.a + t * g.speed
			local p = c + Vector3.new(math.cos(a) * g.rr, g.h + math.sin(t * 7 + g.a) * 1.2, math.sin(a) * g.rr)
			local whirl = CFrame.new(p) * CFrame.Angles(t * g.spin.X, t * g.spin.Y, t * g.spin.Z) * (g.pivot - g.pivot.Position)
			g.move(homeCF:Lerp(whirl, out))
			if out > 0.5 and math.random() < 0.15 then
				seamPixels(p)
			end
		end
		if t > dur then
			conn:Disconnect()
			for _, g in ipairs(groups) do
				g.destroy()
			end
		end
	end)
	pcall(function()
		require(script.Parent.Audio).Play("Whoosh", { pos = d.from, pitch = 0.8 })
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
-- v0.25.80 (owner): the WHOLE legs are gone (upper body flies on a tail of smoke)
local SMOKE_LIMBS = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
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
	pcall(stepsLoop)
	-- v0.25.81 (owner: Haze legs still showed): Roblox's camera transparency controller resets LocalTransparencyModifier
	-- on your own character's parts whenever the zoom changes, so the hidden limb blocks are re-hidden every frame
	game:GetService("RunService").RenderStepped:Connect(function()
		local now = os.clock()
		for b, t in pairs(hiddenUntil) do
			if now < t and b.Parent then
				b.LocalTransparencyModifier = 1
			end
		end
		for _, st in pairs(fireDressed) do
			for _, b in ipairs(st.blocks) do
				b.LocalTransparencyModifier = 1
			end
		end
	end)
	task.spawn(function()
		local Players = game:GetService("Players")
		while true do
			for _, pl in ipairs(Players:GetPlayers()) do
				local c = pl.Character
				if c then
					pcall(dressBarrier, c, c:GetAttribute("Channel"), c:GetAttribute("ChannelR"))
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
