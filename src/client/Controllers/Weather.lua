-- Weather (client, Mastery v2 M6): draws the storms and whirlpools the server lists in the workspace attribute
-- "Weather" (Shared/Modules/Weather): voxel storm clouds + grey rain curtains (seen from afar by everyone), rain round
-- the camera, dark storm light (Atmos.SetStorm), lightning (random inside a storm + the server's "Lightning" FX on
-- ships), whirlpools (0.1.22: Controllers/VoxelSea sinks the block sea into the funnel; here = white foam streaks
-- sliding inward along the spiral arms + spray from the eye; everyone sees them within SEE_WHIRL, Navigators Lv 30
-- (Storm Sense) from far, plus warnings on the ship card + the map).
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
local Textures = require(Shared.Config.Textures)
local Net = require(Shared.Modules.Net)
local Atmos = require(script.Parent.Atmos)
local Audio = require(script.Parent.Audio)
local State = require(script.Parent.Parent.State)
local VoxelSea = require(script.Parent.VoxelSea)

local Weather = {}
local player = Players.LocalPlayer

local SEE_STORM = 2600 -- clouds drawn within this of the camera
local SEE_WHIRL = 320 -- whirlpools seen by eye within this (Storm Sense: SEE_WHIRL_SENSE)
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
	-- (0.1.19 look pass: one flat lid read as a faint smudge through the haze) a towering heap: a wide dark base
	-- layer, then smaller, lighter layers stacked toward the middle, so it reads as a storm cloud from far away
	local set = { parts = {}, offs = {}, base = {}, curtain = {} }
	local LAYERS = { { n = 16, y = 80, spread = 0.9, w = { 60, 110 }, h = { 18, 26 }, shade = 38 }, { n = 12, y = 104, spread = 0.7, w = { 55, 95 }, h = { 22, 30 }, shade = 58 },
		{ n = 9, y = 132, spread = 0.5, w = { 50, 85 }, h = { 24, 34 }, shade = 80 }, { n = 6, y = 162, spread = 0.32, w = { 45, 75 }, h = { 26, 36 }, shade = 104 },
		{ n = 3, y = 192, spread = 0.18, w = { 40, 60 }, h = { 24, 30 }, shade = 126 } }
	local k = 0
	for li, L in ipairs(LAYERS) do
		for i = 1, L.n do
			k += 1
			local a = hash(s.id, k) * math.pi * 2
			local rr = math.sqrt(hash(k, s.id + 3)) * s.r * L.spread
			local w = L.w[1] + hash(s.id + k, 5) * (L.w[2] - L.w[1])
			local h = L.h[1] + hash(k, 2 + li) * (L.h[2] - L.h[1])
			local shade = L.shade + math.floor(hash(k, s.id + 11) * 16)
			local p = block(Vector3.new(w, h, w * (0.75 + hash(k, 4) * 0.5)), Color3.fromRGB(shade + 2, shade + 3, shade + 7), 0)
			p.CastShadow = li == 1 -- the base layer darkens the sea under it
			table.insert(set.parts, p)
			table.insert(set.offs, Vector3.new(math.cos(a) * rr, L.y + (hash(k, 7) - 0.5) * 8, math.sin(a) * rr))
			table.insert(set.base, 0)
			table.insert(set.curtain, false)
		end
	end
	for i = 1, 9 do -- rain shafts: tall grey columns from the cloud base down to the sea
		local a = hash(s.id, 60 + i) * math.pi * 2
		local rr = math.sqrt(hash(60 + i, s.id)) * s.r * 0.75
		local wdt = 30 + hash(i, s.id + 61) * 24
		local p = block(Vector3.new(wdt, 76, wdt), Color3.fromRGB(78, 86, 104), 0.62)
		table.insert(set.parts, p)
		table.insert(set.offs, Vector3.new(math.cos(a) * rr, 36, math.sin(a) * rr))
		table.insert(set.base, 0.62)
		table.insert(set.curtain, true)
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
local whirlSets = {} -- [id] = { parts, kind, arm, idx }
local STREAKS = 11 -- foam streaks per spiral arm
local function buildWhirl(e)
	local set = { parts = {}, kind = {}, arm = {}, idx = {} }
	for j = 0, W.Whirl.Arms - 1 do
		for i = 1, STREAKS do
			local p = block(Vector3.new(1.3 + (i % 3) * 0.4, 0.6, 6 + (i % 4)), Color3.fromRGB(232, 248, 252), 1)
			table.insert(set.parts, p)
			table.insert(set.kind, "streak")
			table.insert(set.arm, j)
			table.insert(set.idx, i)
		end
	end
	-- the dark eye as flat tiles: only when the block sea does not draw the funnel (Low graphics / far)
	for i = 1, 9 do
		local p = block(Vector3.new(9, 0.5, 9), Color3.fromRGB(10, 34, 66), 1)
		table.insert(set.parts, p)
		table.insert(set.kind, "core")
		table.insert(set.arm, 0)
		table.insert(set.idx, i)
	end
	-- spray rising out of the eye
	local mist = block(Vector3.new(10, 1, 10), Color3.new(1, 1, 1), 1)
	local em = Instance.new("ParticleEmitter")
	em.Texture = Textures.px_square
	em.Color = ColorSequence.new(Color3.fromRGB(225, 242, 248))
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	em.Speed = NumberRange.new(5, 11)
	em.SpreadAngle = Vector2.new(35, 35)
	em.Lifetime = NumberRange.new(1.6, 2.6)
	em.RotSpeed = NumberRange.new(-90, 90)
	em.Acceleration = Vector3.new(0, -2, 0)
	em.EmissionDirection = Enum.NormalId.Top
	em.Rate = 0
	em.Parent = mist
	set.mist, set.em = mist, em
	return set
end

local function dropWhirl(id)
	local set = whirlSets[id]
	if set then
		for _, p in ipairs(set.parts) do
			p:Destroy()
		end
		if set.mist then
			set.mist:Destroy()
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
		rainPart = block(Vector3.new(110, 1, 110), Color3.new(1, 1, 1), 1)
		rainPart.Name = "Rain"
		rainEmitter = Instance.new("ParticleEmitter")
		rainEmitter.EmissionDirection = Enum.NormalId.Bottom
		rainEmitter.Speed = NumberRange.new(110, 130)
		rainEmitter.Lifetime = NumberRange.new(0.9, 1.1)
		rainEmitter.Texture = Textures.px_square -- (the default sparkle sprite was nearly invisible as rain)
		rainEmitter.Size = NumberSequence.new(0.22)
		rainEmitter.Squash = NumberSequence.new(3) -- positive = tall thin streaks (negative made flat dashes)
		rainEmitter.Color = ColorSequence.new(Color3.fromRGB(205, 220, 240))
		rainEmitter.Transparency = NumberSequence.new(0.35)
		rainEmitter.LightEmission = 0.4
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
					local x, z = e.x + o.X, e.z + o.Z
					table.insert(parts, p)
					table.insert(cfs, CFrame.new(x, GameConfig.SeaLevel + o.Y, z))
					-- fade in / out with the storm's own strength; a rain shaft close to the camera fades out (from
					-- inside it was a big see-through box in front of you)
					local vis = math.clamp(e.k * 1.3, 0, 1)
					if set.curtain[i] then
						vis *= math.clamp((W.Flat(camPos.X, camPos.Z, x, z) - 50) / 120, 0, 1)
					end
					local tr = 1 - (1 - set.base[i]) * vis
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
				local k = e.k or 1
				-- on the funnel the block sea draws, or flat on the waves when it does not (Low graphics / out of reach)
				local de = VoxelSea.On and VoxelSea.Drawn(e.id) or nil
				local drawn = de ~= nil
				local function surf(x, z)
					local h = Waves.Height(x, z, wt, Waves.Damp(x, z))
					if de then
						local dip, mul = W.Funnel(de, x, z)
						return GameConfig.SeaLevel + h * mul - dip
					end
					return GameConfig.SeaLevel + h
				end
				local dmin = W.Whirl.Core * 0.5
				for i, p in ipairs(set.parts) do
					local tr
					if set.kind[i] == "streak" then
						-- slides from the rim to the eye along its arm (s: 1 rim .. 0 eye), fading in and out
						local s = (set.idx[i] / STREAKS + set.arm[i] * 0.13 - wt * W.Whirl.Flow) % 1
						local d = dmin + (e.r * 0.95 - dmin) * s
						local x, z = W.ArmPoint(e, set.arm[i], d, wt)
						local x2, z2 = W.ArmPoint(e, set.arm[i], math.max(1, d - 4), wt)
						local a, b = Vector3.new(x, surf(x, z) + 0.45, z), Vector3.new(x2, surf(x2, z2) + 0.45, z2)
						table.insert(parts, p)
						table.insert(cfs, CFrame.lookAt(a, b))
						tr = 1 - 0.9 * k * math.clamp(s * 5, 0, 1) * math.clamp((1 - s) * 6, 0, 1)
					else
						local gx, gz = (set.idx[i] - 1) % 3 - 1, math.floor((set.idx[i] - 1) / 3) - 1
						local x, z = e.x + gx * 9, e.z + gz * 9
						table.insert(parts, p)
						table.insert(cfs, CFrame.new(x, surf(x, z) + 0.35, z))
						tr = drawn and 1 or 1 - 0.95 * k
					end
					if math.abs(p.Transparency - tr) > 0.03 then
						p.Transparency = tr
					end
				end
				table.insert(parts, set.mist)
				table.insert(cfs, CFrame.new(e.x, surf(e.x, e.z) + 0.5, e.z))
				set.em.Rate = 28 * k
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
