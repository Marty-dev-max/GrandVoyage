-- Weather (client, Mastery v2 M6): draws the storms and whirlpools the server lists in the workspace attribute
-- "Weather" (Shared/Modules/Weather): voxel storm clouds + grey rain curtains (seen from afar by everyone), rain round
-- the camera, dark storm light (Atmos.SetStorm), lightning (random inside a storm + the server's "Lightning" FX on
-- ships), whirlpools as spinning foam rings round a dark core on the wave surface (everyone sees them within
-- SEE_WHIRL; Navigators Lv 30 (Storm Sense) see them from far, plus warnings on the ship card + the map).
-- Weather.List() = the storms moved on since the last update (for Sailing + the map).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local W = require(Shared.Modules.Weather)
local Waves = require(Shared.Modules.Waves)
local Net = require(Shared.Modules.Net)
local Atmos = require(script.Parent.Atmos)
local Audio = require(script.Parent.Audio)
local State = require(script.Parent.Parent.State)

local Weather = {}
local player = Players.LocalPlayer

local SEE_STORM = 2600 -- clouds drawn within this of the camera
local SEE_WHIRL = 160 -- whirlpools seen by eye within this (Storm Sense: SEE_WHIRL_SENSE)
local SEE_WHIRL_SENSE = 900
local CLOUD_Y = { 95, 140 }

local list, listAt = {}, os.clock()

local function navLv()
	local m = State.profile and State.profile.mastery and State.profile.mastery.Navigator
	return (m and m.lv) or 1
end
Weather.NavLv = navLv

-- every storm / whirlpool, storms moved along by their drift since the server's last update
function Weather.List()
	local dt = math.min(os.clock() - listAt, 1.5)
	local out = {}
	for _, e in ipairs(list) do
		if e.kind == "S" then
			table.insert(out, { kind = "S", id = e.id, x = e.x + e.vx * dt, z = e.z + e.vz * dt, r = e.r, vx = e.vx, vz = e.vz, k = e.k })
		else
			table.insert(out, e)
		end
	end
	return out
end

-- a tiny stable hash 0..1 (cloud shapes per storm id)
local function hash(a, b)
	local h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return h - math.floor(h)
end

local folder
local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "GVWeather"
		folder.Parent = workspace
	end
	return folder
end

local function block(size, color, tr, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Transparency = tr or 0
	p.Parent = getFolder()
	return p
end

-- ===== storms: a lid of dark blocks + rain curtains under it =====
local cloudSets = {} -- [id] = { parts = {}, offs = {}, tr = {} }
local function buildCloud(s)
	local set = { parts = {}, offs = {}, base = {} }
	local n = 18
	for i = 1, n do
		local a = hash(s.id, i) * math.pi * 2
		local rr = math.sqrt(hash(i, s.id + 3)) * s.r * 0.85
		local w = 40 + hash(s.id + i, 5) * 50
		local y = CLOUD_Y[1] + hash(i, 9 + s.id) * (CLOUD_Y[2] - CLOUD_Y[1])
		local shade = 52 + math.floor(hash(i, s.id + 11) * 30)
		local p = block(Vector3.new(w, 14 + hash(i, 2) * 14, w * (0.7 + hash(i, 4) * 0.6)), Color3.fromRGB(shade, shade + 4, shade + 14), 0)
		p.CastShadow = true -- the storm darkens the sea under it
		table.insert(set.parts, p)
		table.insert(set.offs, Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr))
		table.insert(set.base, 0)
	end
	for i = 1, 7 do -- rain curtains: tall see-through grey columns hanging from the cloud
		local a = hash(s.id, 40 + i) * math.pi * 2
		local rr = math.sqrt(hash(40 + i, s.id)) * s.r * 0.7
		local p = block(Vector3.new(36, 100, 36), Color3.fromRGB(120, 130, 150), 0.82)
		table.insert(set.parts, p)
		table.insert(set.offs, Vector3.new(math.cos(a) * rr, 48, math.sin(a) * rr))
		table.insert(set.base, 0.82)
	end
	return set
end

local function dropCloud(id)
	local set = cloudSets[id]
	if set then
		for _, p in ipairs(set.parts) do
			p:Destroy()
		end
		cloudSets[id] = nil
	end
end

-- ===== whirlpools: rings of foam blocks turning round a dark core =====
local whirlSets = {} -- [id] = { parts, ring info }
local RINGS = { { k = 0.95, n = 30, spin = 0.25, color = Color3.fromRGB(210, 240, 250), size = 3 }, { k = 0.62, n = 22, spin = 0.5, color = Color3.fromRGB(150, 205, 230), size = 3 },
	{ k = 0.36, n = 14, spin = 0.95, color = Color3.fromRGB(70, 130, 175), size = 3.4 } }
local function buildWhirl(e)
	local set = { parts = {}, ring = {}, idx = {}, n = {} }
	for ri, ring in ipairs(RINGS) do
		for i = 1, ring.n do
			local p = block(Vector3.new(ring.size + 1.5, 0.6, ring.size), ring.color, 0.1)
			table.insert(set.parts, p)
			table.insert(set.ring, ri)
			table.insert(set.idx, i)
		end
	end
	-- the dark core (a few flat tiles)
	for i = 1, 9 do
		local p = block(Vector3.new(9, 0.5, 9), Color3.fromRGB(10, 34, 66), 0.05)
		table.insert(set.parts, p)
		table.insert(set.ring, 0)
		table.insert(set.idx, i)
	end
	return set
end

local function dropWhirl(id)
	local set = whirlSets[id]
	if set then
		for _, p in ipairs(set.parts) do
			p:Destroy()
		end
		whirlSets[id] = nil
	end
end

-- ===== lightning =====
local function bolt(to, big)
	local top = Vector3.new(to.X + math.random(-20, 20), CLOUD_Y[1] + 5, to.Z + math.random(-20, 20))
	local pts = { top }
	local steps = 7
	for i = 1, steps - 1 do
		local p = top:Lerp(to, i / steps)
		table.insert(pts, p + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
	end
	table.insert(pts, to)
	local parts = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local p = block(Vector3.new(big and 1.6 or 1.1, big and 1.6 or 1.1, len), Color3.fromRGB(230, 240, 255), 0, Enum.Material.Neon)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		table.insert(parts, p)
	end
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - to).Magnitude or 0
	Atmos.Flash(math.clamp(1 - dist / 900, 0.15, 1))
	task.delay(math.clamp(dist / 1100, 0, 1.5), function() -- thunder comes a moment after the flash
		Audio.Play("ThunderCrack", { pos = to, volume = math.clamp(1.2 - dist / 1500, 0.3, 1.2), pitch = 0.8 + math.random() * 0.3 })
	end)
	for _, p in ipairs(parts) do
		TweenService:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(p, 0.4)
	end
end
Weather.Bolt = bolt

-- the Hard Turn spray: white blocks thrown off the hull
local function spray(pos)
	for _ = 1, 14 do
		local p = block(Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(235, 248, 255), 0.1)
		p.CFrame = CFrame.new(pos + Vector3.new(math.random(-8, 8), 1, math.random(-8, 8)))
		local goal = p.Position + Vector3.new(math.random(-16, 16), math.random(6, 14), math.random(-16, 16))
		TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = goal, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.8)
	end
	Audio.Play("Splash", { pos = pos, volume = 0.9 })
	Audio.Play("WindGust", { pos = pos, volume = 0.8 })
end

-- ===== rain round the camera =====
local rainPart, rainEmitter
local function rain(k, camPos)
	if not rainPart or not rainPart.Parent then
		rainPart = block(Vector3.new(160, 1, 160), Color3.new(1, 1, 1), 1)
		rainPart.Name = "Rain"
		rainEmitter = Instance.new("ParticleEmitter")
		rainEmitter.EmissionDirection = Enum.NormalId.Bottom
		rainEmitter.Speed = NumberRange.new(110, 130)
		rainEmitter.Lifetime = NumberRange.new(0.9, 1.1)
		rainEmitter.Size = NumberSequence.new(0.12)
		rainEmitter.Squash = NumberSequence.new(-3) -- long thin drops
		rainEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 215, 235))
		rainEmitter.Transparency = NumberSequence.new(0.35)
		rainEmitter.LightEmission = 0.2
		rainEmitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		rainEmitter.Rate = 0
		rainEmitter.Parent = rainPart
	end
	rainPart.CFrame = CFrame.new(camPos + Vector3.new(0, 70, 0))
	rainEmitter.Rate = k > 0.05 and 900 * k or 0
end

-- ===== per frame =====
local acc = 0
local flashAcc = 4
local stormAir = 0
local function step(dt)
	acc += dt
	if acc < 1 / 30 then
		return
	end
	local frameDt = acc
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local items = Weather.List()
	local t = os.clock()
	local lv = navLv()
	local seen = {}
	local camK = 0
	local parts, cfs = {}, {}
	for _, e in ipairs(items) do
		local d = W.Flat(camPos.X, camPos.Z, e.x, e.z)
		if e.kind == "S" then
			camK = math.max(camK, W.StormK(e, camPos.X, camPos.Z))
			if d < SEE_STORM + e.r then
				seen["S" .. e.id] = true
				local set = cloudSets[e.id]
				if not set then
					set = buildCloud(e)
					cloudSets[e.id] = set
				end
				local rot = CFrame.Angles(0, t * 0.02, 0)
				for i, p in ipairs(set.parts) do
					local o = rot * set.offs[i]
					table.insert(parts, p)
					table.insert(cfs, CFrame.new(e.x + o.X, GameConfig.SeaLevel + o.Y, e.z + o.Z))
					-- fade in / out with the storm's own strength
					local tr = 1 - (1 - set.base[i]) * math.clamp(e.k * 1.3, 0, 1)
					if math.abs(p.Transparency - tr) > 0.02 then
						p.Transparency = tr
					end
				end
			end
		else
			local range = lv >= 30 and SEE_WHIRL_SENSE or SEE_WHIRL
			if d < range + e.r then
				seen["W" .. e.id] = true
				local set = whirlSets[e.id]
				if not set then
					set = buildWhirl(e)
					whirlSets[e.id] = set
				end
				local wt = Waves.Now()
				for i, p in ipairs(set.parts) do
					local ri = set.ring[i]
					local x, z, yaw
					if ri == 0 then
						local gx, gz = (set.idx[i] - 1) % 3 - 1, math.floor((set.idx[i] - 1) / 3) - 1
						x, z, yaw = e.x + gx * 9, e.z + gz * 9, 0
					else
						local ring = RINGS[ri]
						local a = (set.idx[i] / ring.n) * math.pi * 2 + t * ring.spin
						local rr = e.r * ring.k
						x, z = e.x + math.cos(a) * rr, e.z + math.sin(a) * rr
						yaw = -a -- blocks lie along the ring
					end
					local y = GameConfig.SeaLevel + Waves.Height(x, z, wt, Waves.Damp(x, z)) + 0.6
					table.insert(parts, p)
					table.insert(cfs, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
				end
			end
		end
	end
	for id in pairs(cloudSets) do
		if not seen["S" .. id] then
			dropCloud(id)
		end
	end
	for id in pairs(whirlSets) do
		if not seen["W" .. id] then
			dropWhirl(id)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- the air under a storm: dark light, rain, lightning now and then
	stormAir += (camK - stormAir) * math.clamp(frameDt * 1.5, 0, 1)
	Atmos.SetStorm(stormAir)
	rain(stormAir, camPos)
	flashAcc -= frameDt
	if camK > 0.3 and flashAcc <= 0 then
		flashAcc = 4 + math.random() * 6
		local a = math.random() * math.pi * 2
		local r = 60 + math.random() * 220
		local x, z = camPos.X + math.cos(a) * r, camPos.Z + math.sin(a) * r
		bolt(Vector3.new(x, GameConfig.SeaLevel + 1, z), false)
	end
end

function Weather.Start()
	local function read()
		list = W.Decode(workspace:GetAttribute("Weather"))
		listAt = os.clock()
	end
	read()
	workspace:GetAttributeChangedSignal("Weather"):Connect(read)
	Net.OnFX(function(kind, data)
		if kind == "Lightning" and typeof(data.pos) == "Vector3" then
			bolt(data.pos, true)
		elseif kind == "ShipHardTurn" and typeof(data.pos) == "Vector3" then
			spray(data.pos)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Weather
