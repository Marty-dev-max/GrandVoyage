-- Atmos (client): the game's light and air.
--   * Day / night cycle: the sun is the main light by day, the moon by night. Every client computes the same clock from
--     server time (no replication traffic). Key times (sunrise, morning, noon, golden hour, sunset, dusk, night) each have
--     a full light recipe (ambient, color shift, atmosphere, color grade, bloom, sun rays, cloud color) that is blended.
--   * Lamps light up at night (PointLights added to the warm Neon lamp bulbs of the baked world).
--   * Wind: soft curved wisps (Beams with a fading ribbon texture) that drift with the wind instead of hard white lines.
--   * Leaves: a few leaves tumble past when you stand on an island.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SeaZones = require(ReplicatedStorage.Shared.Modules.SeaZones)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)

local Atmos = {}

local C = Color3.fromRGB
-- light recipes by clock time; the last entry wraps to the first
local KEYS = {
	{ t = 0, bright = 1.8, amb = C(74, 86, 130), out = C(100, 116, 170), top = C(150, 175, 240), atm = C(62, 82, 138), decay = C(24, 34, 78), dens = 0.3, haze = 1.0, glare = 0, tint = C(200, 214, 255), sat = 0.1, con = 0.1, cb = 0.02, bloom = 0.9, rays = 0, cloud = C(96, 108, 152) },
	{ t = 5, bright = 1.8, amb = C(78, 84, 128), out = C(104, 112, 166), top = C(140, 150, 220), atm = C(70, 80, 130), decay = C(30, 34, 80), dens = 0.33, haze = 1.3, glare = 0.1, tint = C(200, 205, 255), sat = 0.1, con = 0.12, cb = -0.02, bloom = 0.85, rays = 0, cloud = C(110, 110, 150) },
	{ t = 6.3, bright = 2.1, amb = C(122, 100, 112), out = C(172, 130, 122), top = C(255, 168, 110), atm = C(255, 188, 150), decay = C(180, 110, 122), dens = 0.34, haze = 2.0, glare = 0.6, tint = C(255, 226, 202), sat = 0.3, con = 0.1, cb = 0.01, bloom = 0.75, rays = 0.13, cloud = C(255, 200, 182) },
	{ t = 9, bright = 3.0, amb = C(115, 115, 135), out = C(155, 155, 175), top = C(255, 240, 222), atm = C(200, 230, 255), decay = C(120, 170, 220), dens = 0.28, haze = 1.4, glare = 0.3, tint = C(255, 250, 240), sat = 0.28, con = 0.08, cb = 0.03, bloom = 0.5, rays = 0.06, cloud = C(255, 255, 255) },
	{ t = 13, bright = 3.2, amb = C(118, 118, 136), out = C(160, 160, 178), top = C(255, 250, 240), atm = C(200, 232, 255), decay = C(120, 172, 222), dens = 0.27, haze = 1.3, glare = 0.25, tint = C(255, 252, 244), sat = 0.28, con = 0.08, cb = 0.03, bloom = 0.45, rays = 0.05, cloud = C(255, 255, 255) },
	{ t = 16.5, bright = 2.8, amb = C(122, 110, 120), out = C(172, 150, 140), top = C(255, 202, 140), atm = C(255, 214, 170), decay = C(190, 140, 120), dens = 0.3, haze = 1.8, glare = 0.5, tint = C(255, 236, 212), sat = 0.32, con = 0.09, cb = 0.02, bloom = 0.6, rays = 0.1, cloud = C(255, 232, 205) },
	{ t = 18.2, bright = 2.0, amb = C(120, 94, 120), out = C(170, 118, 140), top = C(255, 138, 108), atm = C(255, 158, 150), decay = C(140, 80, 130), dens = 0.34, haze = 2.4, glare = 0.8, tint = C(255, 214, 210), sat = 0.35, con = 0.1, cb = 0.0, bloom = 0.8, rays = 0.14, cloud = C(255, 168, 160) },
	{ t = 19.4, bright = 1.8, amb = C(84, 84, 126), out = C(108, 112, 166), top = C(150, 140, 222), atm = C(110, 110, 172), decay = C(50, 50, 100), dens = 0.32, haze = 1.6, glare = 0.2, tint = C(210, 210, 255), sat = 0.2, con = 0.12, cb = -0.02, bloom = 0.85, rays = 0.02, cloud = C(140, 128, 182) },
	{ t = 21, bright = 1.8, amb = C(74, 86, 130), out = C(100, 116, 170), top = C(150, 175, 240), atm = C(62, 82, 138), decay = C(24, 34, 78), dens = 0.3, haze = 1.0, glare = 0, tint = C(200, 214, 255), sat = 0.1, con = 0.1, cb = 0.02, bloom = 0.9, rays = 0, cloud = C(96, 108, 152) },
}
local CALM = { atm = C(170, 190, 200), dens = 0.45, haze = 2.5 }

local calm, calmK = false, 0
local overrideClock -- dev: force a time of day

local function clockNow()
	if overrideClock then
		return overrideClock
	end
	local cfg = GameConfig.DayNight
	local phase = (workspace:GetServerTimeNow() / (cfg.CycleMinutes * 60)) % 1
	if phase < cfg.DayShare then
		return 6 + 12 * (phase / cfg.DayShare)
	end
	return (18 + 12 * ((phase - cfg.DayShare) / (1 - cfg.DayShare))) % 24
end
Atmos.Clock = clockNow

function Atmos.IsNight()
	local c = clockNow()
	return c < 6.2 or c > 18.6
end

function Atmos.SetClock(c)
	overrideClock = c
end

-- underwater blend (Controllers/Underwater): 0 = above the sea .. 1 = submerged (short, blue-green visibility)
local uwK = 0
function Atmos.SetUnderwater(k)
	uwK = k
end
local UW = { atm = Color3.fromRGB(26, 104, 150), decay = Color3.fromRGB(8, 50, 90), amb = Color3.fromRGB(60, 120, 160) }

function Atmos.SetCalm(on)
	calm = on
end

local function lerp(a, b, k)
	if typeof(a) == "Color3" then
		return a:Lerp(b, k)
	end
	return a + (b - a) * k
end

local function sample(clock)
	local a, b = KEYS[#KEYS], KEYS[1]
	for i = 1, #KEYS do
		if KEYS[i].t > clock then
			b = KEYS[i]
			a = KEYS[i - 1] or KEYS[#KEYS]
			break
		end
		a = KEYS[i]
		b = KEYS[i + 1] or KEYS[1]
	end
	local span = (b.t - a.t) % 24
	local k = span > 0 and ((clock - a.t) % 24) / span or 0
	k = k * k * (3 - 2 * k) -- smoothstep: no visible "kinks" between keys
	local out = {}
	for key, v in pairs(a) do
		if key ~= "t" then
			out[key] = lerp(v, b[key], k)
		end
	end
	return out
end

-- ===== lamps =====
local lamps = {}
local function collectLamps()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local warm = C(255, 220, 140)
	for _, p in ipairs(world:GetDescendants()) do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.Size.Magnitude < 4 then
			local c = p.Color
			if math.abs(c.R - warm.R) + math.abs(c.G - warm.G) + math.abs(c.B - warm.B) < 0.25 then
				local l = Instance.new("PointLight")
				l.Color = C(255, 196, 120)
				l.Range = 24
				l.Brightness = 0
				l.Shadows = false
				l.Parent = p
				table.insert(lamps, l)
			end
		end
	end
end

-- ===== wind wisps =====
local wispFolder
local wisps = {}
local MAX_WISPS = 26

local function spawnWisp(center, dir, strength)
	if #wisps >= MAX_WISPS then
		return
	end
	local up = Vector3.yAxis
	local side = dir:Cross(up).Unit
	local start = center + side * math.random(-90, 90) + dir * math.random(-70, 30) + up * math.random(3, 22)
	local len = 14 + math.random() * 16
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local tilt = (math.random() - 0.5) * 1.2
	a0.Parent = workspace.Terrain
	a1.Parent = workspace.Terrain
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = Tex.windwisp
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.FaceCamera = true
	b.LightEmission = 0.5
	b.LightInfluence = 0.3
	b.Segments = 16
	local w = 0.35 + math.random() * 0.45
	b.Width0 = w
	b.Width1 = w * 0.7
	b.Color = ColorSequence.new(C(255, 255, 255))
	b.Transparency = NumberSequence.new(1)
	b.CurveSize0 = len * (0.25 + math.random() * 0.2)
	b.CurveSize1 = -len * (0.25 + math.random() * 0.2)
	b.Parent = wispFolder
	table.insert(wisps, { a0 = a0, a1 = a1, beam = b, pos = start, dir = dir, side = side, len = len, tilt = tilt, born = os.clock(), life = 2.6 + math.random() * 1.6, speed = (14 + math.random() * 10) * strength, phase = math.random() * 6 })
end

local function updateWisps(dt)
	local now = os.clock()
	for i = #wisps, 1, -1 do
		local w = wisps[i]
		local age = (now - w.born) / w.life
		if age >= 1 then
			w.beam:Destroy()
			w.a0:Destroy()
			w.a1:Destroy()
			table.remove(wisps, i)
		else
			w.pos += w.dir * w.speed * dt
			-- the ribbon gently undulates (sway) while it drifts
			local sway = math.sin(now * 2.2 + w.phase) * 1.4
			local p0 = w.pos + w.side * sway
			local p1 = w.pos + w.dir * w.len + w.side * (-sway) + Vector3.yAxis * w.tilt * 3
			local axis0 = (w.dir + Vector3.yAxis * (0.5 + 0.3 * math.sin(now * 1.7 + w.phase))).Unit
			local axis1 = (w.dir - Vector3.yAxis * (0.5 + 0.3 * math.cos(now * 1.5 + w.phase))).Unit
			w.a0.WorldCFrame = CFrame.lookAt(p0, p0 + axis0) * CFrame.Angles(0, math.pi / 2, 0)
			w.a1.WorldCFrame = CFrame.lookAt(p1, p1 + axis1) * CFrame.Angles(0, math.pi / 2, 0)
			-- fade in, hold, fade out
			local vis = math.min(age / 0.25, 1, (1 - age) / 0.35)
			w.beam.Transparency = NumberSequence.new(1 - 0.55 * math.clamp(vis, 0, 1))
		end
	end
end

-- called by Sailing (strength 0..1.6); the old hard white streaks are gone
function Atmos.Wind(center, dir, strength, count)
	for _ = 1, count or 1 do
		spawnWisp(center, dir, strength)
	end
end

-- ===== leaves =====
local leafPart, leafEmitter
local function makeLeaves()
	leafPart = Instance.new("Part")
	leafPart.Name = "LeafWind"
	leafPart.Anchored = true
	leafPart.CanCollide = false
	leafPart.CanQuery = false
	leafPart.CanTouch = false
	leafPart.Transparency = 1
	leafPart.Size = Vector3.new(70, 14, 20)
	leafPart.Parent = wispFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.leaf
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 2.2
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(5, 9)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, -1.1, 0)
	e.Drag = 0.4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-160, 160)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.45) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(126, 196, 84)), ColorSequenceKeypoint.new(0.5, C(176, 214, 92)), ColorSequenceKeypoint.new(1, C(226, 190, 96)) })
	e.LightInfluence = 1
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Enabled = false
	e.Parent = leafPart
	leafEmitter = e
end

function Atmos.Start()
	wispFolder = Instance.new("Folder")
	wispFolder.Name = "AtmosFX"
	wispFolder.Parent = workspace
	makeLeaves()

	local atm = Lighting:WaitForChild("Atmosphere", 10)
	local cc = Lighting:FindFirstChild("Stylize")
	local bloom = Lighting:FindFirstChild("Bloom")
	local rays = Lighting:FindFirstChild("SunRays")
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = 16 -- a big storybook moon: it is the night's main light
		sky.SunAngularSize = 16
		sky.StarCount = 4000
		sky.CelestialBodiesShown = true
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.55
		clouds.Parent = workspace.Terrain
	end
	task.delay(4, collectLamps)


	local acc = 0
	local leafAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		updateWisps(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local clock = clockNow()
		local L = sample(clock)
		calmK += ((calm and 1 or 0) - calmK) * 0.08
		Lighting.ClockTime = clock
		Lighting.Brightness = L.bright
		Lighting.Ambient = L.amb
		Lighting.OutdoorAmbient = L.out
		Lighting.ColorShift_Top = L.top
		if atm then
			atm.Color = L.atm:Lerp(CALM.atm, calmK)
			atm.Decay = L.decay
			atm.Density = lerp(L.dens, CALM.dens, calmK)
			atm.Haze = lerp(L.haze, CALM.haze, calmK)
			atm.Glare = L.glare
		end
		if atm and uwK > 0.01 then
			atm.Color = atm.Color:Lerp(UW.atm, uwK)
			atm.Decay = atm.Decay:Lerp(UW.decay, uwK)
			atm.Density = lerp(atm.Density, 0.8, uwK)
			atm.Haze = lerp(atm.Haze, 2.6, uwK)
			atm.Glare = lerp(atm.Glare, 0, uwK)
			Lighting.Ambient = Lighting.Ambient:Lerp(UW.amb, uwK * 0.6)
			Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(UW.amb, uwK * 0.6)
		end
		if cc then
			cc.TintColor = L.tint
			cc.Saturation = L.sat
			cc.Contrast = L.con
			cc.Brightness = L.cb
		end
		if bloom and bloom.Enabled then
			bloom.Intensity = L.bloom
		end
		if rays and rays.Enabled then
			rays.Intensity = L.rays
		end
		if clouds then
			clouds.Color = L.cloud
		end
		local night = clock < 6.2 or clock > 18.6
		for _, l in ipairs(lamps) do
			l.Brightness += ((night and 1.6 or 0) - l.Brightness) * 0.15
			l.Enabled = l.Brightness > 0.02
		end

		-- leaves drift past when standing on an island, blown along the wind
		leafAcc += 0.1
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local onLand = root and SeaZones.OnIslandLand(root.Position) and root.Position.Y > 2
		leafEmitter.Enabled = onLand and true or false
		if root and onLand then
			local dir = Vector3.new(1, 0, -0.25).Unit
			local pos = root.Position - dir * 28 + Vector3.new(0, 9, 0)
			leafPart.CFrame = CFrame.lookAt(pos, pos + dir)
			if leafAcc > 0.6 then
				leafAcc = 0
				spawnWisp(root.Position, dir, 0.5) -- light breeze over the island too
			end
		end
	end)
end

return Atmos
