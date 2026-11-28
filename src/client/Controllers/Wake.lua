-- Wake (R5, owner: a boat wake behind every ship). Voxel foam drawn locally for every ship in workspace.Ships
-- (player and NPC ships alike) within WAKE_NEAR of the camera:
--  * a V of foam blocks: two streams leave the stern quarters and drift outward while they grow and fade, so the
--    trail opens into a V behind a fast ship and stays a narrow ribbon behind a slow one;
--  * churned water straight behind the stern (bigger, slower blocks);
--  * bow spray above SPRAY_SPEED: small blocks thrown up and out from the bow, falling back with gravity.
-- Blocks ride the same wave surface VoxelSea draws (Shared/Modules/Waves) or the flat sea on Low. One pool of parts,
-- moved with BulkMoveTo; the oldest block is reused when the pool is full.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Waves = require(ReplicatedStorage.Shared.Modules.Waves)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Wake = {}

local SEA = GameConfig.SeaLevel
local POOL = 320
local WAKE_NEAR = 520
local MIN_SPEED = 3 -- studs/s before any foam shows
local SPRAY_SPEED = 22
local FOAM = Color3.fromRGB(240, 250, 252)
local CHURN = Color3.fromRGB(196, 236, 240)

local folder
local pool = {} -- { part, alive, t, life, pos, vel, size0, size1, kind, spin }
local nextSlot = 1
local ships = {} -- model -> { last = Vector3, speed, dir, acc, sprayAcc, half, width, off }
local VoxelSea

local function water(x, z, now)
	if VoxelSea and VoxelSea.On then
		return SEA + Waves.Height(x, z, now)
	end
	return SEA
end

local function grab()
	local slot = pool[nextSlot]
	nextSlot = nextSlot % POOL + 1
	return slot
end

local function spawn(kind, pos, vel, size0, size1, life, color)
	local s = grab()
	s.alive = true
	s.t = 0
	s.life = life
	s.pos = pos
	s.vel = vel
	s.size0 = size0
	s.size1 = size1
	s.kind = kind
	s.spin = (math.random() - 0.5) * 1.2
	s.yaw = math.random() * math.pi * 2
	s.part.Color = color
	s.part.Transparency = kind == "spray" and 0.05 or 0.15
	s.part.Size = Vector3.one * size0
end

local function shapeOf(model, root)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then
		return nil
	end
	local off = root.CFrame:PointToObjectSpace(cf.Position)
	return { half = size.Z / 2, width = size.X / 2, off = Vector3.new(off.X, 0, off.Z) }
end

local function stepShips(dt, now, cam)
	local list = workspace:FindFirstChild("Ships")
	if not list then
		return
	end
	for _, model in ipairs(list:GetChildren()) do
		local root = model:IsA("Model") and model.PrimaryPart
		if not root then
			continue
		end
		local st = ships[model]
		local pos = root.Position
		if not st then
			local shape = shapeOf(model, root)
			if not shape then
				continue
			end
			st = shape
			st.last = pos
			st.speed = 0
			st.dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			st.acc = 0
			st.sprayAcc = 0
			ships[model] = st
			model.Destroying:Connect(function()
				ships[model] = nil
			end)
		end
		local d = pos - st.last
		st.last = pos
		local flat = Vector3.new(d.X, 0, d.Z)
		local v = flat.Magnitude / math.max(dt, 1 / 240)
		if v > 400 then
			v = 0 -- a teleport (summoned somewhere else), not speed
		end
		st.speed += (v - st.speed) * (1 - math.exp(-6 * dt))
		if flat.Magnitude > 0.01 then
			st.dir = st.dir:Lerp(flat.Unit, 1 - math.exp(-8 * dt)).Unit
		end
		if st.speed < MIN_SPEED or (pos - cam).Magnitude > WAKE_NEAR then
			continue
		end
		local look = root.CFrame.LookVector
		local bow = Vector3.new(look.X, 0, look.Z).Unit
		local right = Vector3.new(-bow.Z, 0, bow.X)
		local center = Vector3.new(pos.X, 0, pos.Z) + root.CFrame:VectorToWorldSpace(st.off) * Vector3.new(1, 0, 1)
		local back = st.dir:Dot(bow) >= 0 and -bow or bow -- going astern: the wake trails the bow
		local stern = center + back * st.half * 0.92
		local k = math.clamp(st.speed / 40, 0.25, 1.6)
		-- foam every SPACING studs travelled (denser when fast, so the ribbon stays closed)
		st.acc += st.speed * dt
		local spacing = 1.8
		local n = 0
		while st.acc >= spacing and n < 6 do
			st.acc -= spacing
			n += 1
			local w = st.width * 0.55
			for _, side in ipairs({ -1, 1 }) do
				local p = stern + right * side * w + back * (math.random() * 1.5)
				local out = right * side * (st.speed * 0.32 + 1) + back * (st.speed * 0.12)
				local sz = (0.9 + math.random() * 0.9) * (0.7 + 0.4 * k)
				spawn("foam", p, out, sz, sz * (1.8 + k * 0.6), 2.6 + math.random() * 1.4 * k, FOAM)
			end
			if math.random() < 0.8 then
				local p = stern + right * (math.random() - 0.5) * st.width * 0.7 + back * math.random() * 2
				local sz = (1.4 + math.random() * 1.2) * (0.7 + 0.4 * k)
				spawn("churn", p, back * st.speed * 0.08, sz, sz * 1.6, 1.6 + math.random() * k, CHURN)
			end
		end
		-- bow spray
		if st.speed > SPRAY_SPEED then
			st.sprayAcc += dt * (st.speed - SPRAY_SPEED) * 0.9
			local bowPt = center - back * st.half * 0.85
			local m = 0
			while st.sprayAcc >= 1 and m < 4 do
				st.sprayAcc -= 1
				m += 1
				local side = math.random() < 0.5 and -1 or 1
				local p = bowPt + right * side * st.width * 0.35
				local vel = right * side * (4 + math.random() * 6) - back * st.speed * 0.6 + Vector3.new(0, 6 + math.random() * 8 * k, 0)
				local sz = 0.35 + math.random() * 0.45
				spawn("spray", p, vel, sz, sz * 0.6, 0.55 + math.random() * 0.35, FOAM)
			end
		end
	end
end

local parts, cfs = {}, {}
local function stepPool(dt, now)
	table.clear(parts)
	table.clear(cfs)
	for _, s in ipairs(pool) do
		if not s.alive then
			continue
		end
		s.t += dt
		local a = s.t / s.life
		if a >= 1 then
			s.alive = false
			s.part.Transparency = 1
			continue
		end
		local y
		if s.kind == "spray" then
			s.vel += Vector3.new(0, -workspace.Gravity * 0.35 * dt, 0)
			s.pos += s.vel * dt
			local wy = water(s.pos.X, s.pos.Z, now)
			if s.pos.Y < wy then
				s.t = s.life -- splashed back in
			end
			y = math.max(s.pos.Y, wy)
		else
			s.vel *= math.exp(-1.4 * dt) -- foam slows as it spreads
			s.pos += s.vel * dt
			y = water(s.pos.X, s.pos.Z, now) + 0.05
		end
		local size = s.size0 + (s.size1 - s.size0) * math.sqrt(a)
		-- flat foam slabs (a third as tall as wide), thrown spray stays cubic
		local h = s.kind == "spray" and size or math.max(0.3, size * 0.32)
		s.part.Size = Vector3.new(size, h, size)
		s.part.Transparency = s.kind == "spray" and 0.05 + a * 0.6 or 0.15 + a * a * 0.85
		s.yaw += s.spin * dt
		table.insert(parts, s.part)
		table.insert(cfs, CFrame.new(s.pos.X, y, s.pos.Z) * CFrame.Angles(0, s.yaw, 0))
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Wake.Start()
	VoxelSea = require(script.Parent.VoxelSea)
	folder = Instance.new("Folder")
	folder.Name = "GVWake"
	folder.Parent = workspace
	for i = 1, POOL do
		local p = Instance.new("Part")
		p.Name = "Foam"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = CFrame.new(0, -500, 0)
		p.Parent = folder
		pool[i] = { part = p, alive = false }
	end
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local now = Waves.Now()
		stepShips(dt, now, cam.CFrame.Position)
		stepPool(dt, now)
	end)
end

return Wake
