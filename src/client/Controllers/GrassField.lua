-- GrassField (client): real 3D grass blades around the player, swaying in the wind.
-- The island ground is a few big Grass parts (painted GV_Grass texture from afar). Near the camera we lay a carpet of
-- grass-patch meshes (Assets.Env.GrassPatch_n, 4x4 studs of short blades) on a 4-stud grid: each cell is raycast once,
-- patches are pooled and moved as you walk, and nearby patches sway with workspace:BulkMoveTo.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Settings = require(script.Parent.Settings)

local GrassField = {}

local CELL = 4
local RADIUS = { Low = 20, Medium = 32, High = 46, Ultra = 60 }
local HEIGHT = 1.0 -- blade height in studs
local GRASS = Enum.Material.Grass

local folder
local LIFT = CFrame.new(0, HEIGHT / 2, 0) -- the mesh pivot is its center: stand it on the ground
local sources = {}
local cache = {} -- cell key -> false | { cf = CFrame, variant = n }
local live = {} -- cell key -> { part, base, phase }
local pool = {} -- variant -> { parts }
local params

local function key(ix, iz)
	return ix * 100000 + iz
end

local function hash(ix, iz)
	return bit32.bxor(ix * 73856093 % 4294967296, iz * 19349663 % 4294967296)
end

local function insideProp(inst)
	local m = inst:FindFirstAncestorOfClass("Model")
	return m ~= nil and CollectionService:HasTag(m, "EnvProp")
end

local function probe(ix, iz)
	local k = key(ix, iz)
	local c = cache[k]
	if c ~= nil then
		return c
	end
	local h = hash(ix, iz)
	-- jitter inside the cell so the grid never shows
	local x = ix * CELL + (h % 100) / 100 * CELL * 0.6
	local z = iz * CELL + (math.floor(h / 100) % 100) / 100 * CELL * 0.6
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -340, 0), params)
	if hit and hit.Material == GRASS and hit.Normal.Y > 0.85 and not insideProp(hit.Instance) then
		local yaw = (h % 628) / 100
		c = { cf = CFrame.new(hit.Position + Vector3.new(0, -0.05, 0)) * CFrame.Angles(0, yaw, 0), variant = (h % 7 == 0) and 2 or 1, phase = (h % 1000) / 160 }
	else
		c = false
	end
	cache[k] = c
	return c
end

local function take(variant)
	local list = pool[variant]
	if list and #list > 0 then
		return table.remove(list)
	end
	local src = sources[variant] or sources[1]
	local p = src:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function give(variant, p)
	p.CFrame = CFrame.new(0, -500, 0)
	pool[variant] = pool[variant] or {}
	table.insert(pool[variant], p)
end

local function loadSources()
	local env = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Env")
	if not env then
		return false
	end
	for i = 1, 2 do
		local m = env:FindFirstChild("GrassPatch_" .. i)
		local mp = m and m:FindFirstChildWhichIsA("MeshPart")
		if mp then
			local p = mp:Clone()
			-- normalized models are 10 studs tall: shrink to blade height
			p.Size = p.Size * (HEIGHT / math.max(p.Size.Y, 0.01))
			sources[i] = p
		end
	end
	return sources[1] ~= nil
end

function GrassField.Start()
	folder = Instance.new("Folder")
	folder.Name = "GrassField"
	folder.Parent = workspace
	task.spawn(function()
		-- wait for the server to load the meshes (AssetService) and the world
		local world = workspace:WaitForChild("World", 120)
		for _ = 1, 240 do
			if loadSources() then
				break
			end
			task.wait(0.5)
		end
		if not sources[1] or not world then
			return
		end
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { world }

		local acc, swayAcc = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			swayAcc += dt
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local focus = cam.Focus.Position
			local radius = RADIUS[Settings.Values and Settings.Values.quality or "High"] or 46
			if focus.Y > 160 then
				radius = 0 -- flying high / sailing far above: no blades
			end
			if acc >= 0.2 then
				acc = 0
				local cx, cz = math.floor(focus.X / CELL), math.floor(focus.Z / CELL)
				local r = math.ceil(radius / CELL)
				local want = {}
				local probes = 0
				for ix = cx - r, cx + r do
					for iz = cz - r, cz + r do
						local dx, dz = (ix - cx) * CELL, (iz - cz) * CELL
						if dx * dx + dz * dz <= radius * radius then
							local k = key(ix, iz)
							local c = cache[k]
							if c == nil and probes < 160 then
								probes += 1
								c = probe(ix, iz)
							end
							if c then
								want[k] = c
							end
						end
					end
				end
				for k, e in pairs(live) do
					if not want[k] then
						give(e.variant, e.part)
						live[k] = nil
					end
				end
				for k, c in pairs(want) do
					if not live[k] then
						local p = take(c.variant)
						p.CFrame = c.cf * LIFT
						live[k] = { part = p, base = c.cf, phase = c.phase, variant = c.variant }
					end
				end
			end
			-- wind sway for the patches near the camera (20 Hz, one bulk move)
			if swayAcc >= 0.05 then
				swayAcc = 0
				local t = os.clock()
				local parts, cfs = {}, {}
				for _, e in pairs(live) do
					local d = e.base.Position - focus
					if d.X * d.X + d.Z * d.Z < 900 then
						local s = math.sin(t * 2.1 + e.phase + e.base.Position.X * 0.05)
						table.insert(parts, e.part)
						table.insert(cfs, e.base * CFrame.Angles(s * 0.07, 0, math.cos(t * 1.7 + e.phase) * 0.05) * LIFT)
					end
				end
				if #parts > 0 then
					workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				end
			end
		end)
	end)
end

return GrassField
