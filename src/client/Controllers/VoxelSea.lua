-- VoxelSea (v0.25.144, owner reference: a sea made of block columns that rise and fall, white on the crests, dark in
-- the troughs, low waves). A square grid of block columns follows the camera; each column's top follows the shared
-- wave surface (Shared/Modules/Waves, the same one ShipService floats ships on), snapped to STEP-stud voxel steps, and
-- its color is picked from a height ramp. Columns are recycled toroidally: a column owns world cell (i, j) with
-- i % N == its slot, so moving the camera only re-targets the cells that scrolled in (one ground ray each: land cells
-- hide, shallow sand makes the column clear turquoise). The flat sea parts are lowered locally under the troughs and
-- the grid fades into them at its edge. Off on Low graphics (the textured flat sea stays).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Waves = require(ReplicatedStorage.Shared.Modules.Waves)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Settings = require(script.Parent.Settings)

local VoxelSea = {}

local CELL = 4
local STEP = 0.5 -- voxel height step
local DEPTH = 5 -- column height
local SEA = GameConfig.SeaLevel
local DROP = Waves.Amp + 0.3 -- how far the flat sea is lowered under the grid
local SIZES = { Medium = 40, High = 52, Ultra = 64 }

-- height ramp (n = height / local amplitude, -1..1): deep teal -> turquoise -> pale -> white crest
local RAMP = {
	{ -1.0, Color3.fromRGB(14, 78, 104) },
	{ -0.35, Color3.fromRGB(24, 128, 160) },
	{ 0.15, Color3.fromRGB(38, 172, 196) },
	{ 0.5, Color3.fromRGB(110, 214, 222) },
	{ 0.72, Color3.fromRGB(214, 244, 246) },
	{ 1.0, Color3.fromRGB(250, 255, 255) },
}
local BANDS = 12
local palette = {} -- [band][variant] = Color3
local function ramp(n)
	for i = 2, #RAMP do
		if n <= RAMP[i][1] then
			local a, b = RAMP[i - 1], RAMP[i]
			return a[2]:Lerp(b[2], (n - a[1]) / (b[1] - a[1]))
		end
	end
	return RAMP[#RAMP][2]
end
for b = 0, BANDS - 1 do
	palette[b] = {}
	local c = ramp(-1 + 2 * (b + 0.5) / BANDS)
	for v = 0, 2 do
		-- tiny per-cell shade variants: the block grid reads like the reference
		palette[b][v] = c:Lerp(v == 0 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), v == 1 and 0.05 or 0.035)
	end
end
local SHALLOW = Color3.fromRGB(90, 220, 215)

local N, folder, parts, cells, cfs
local ox, oz -- grid origin cell of the current window
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local lowered = {}

local function lowerFlatSea(ocean)
	for _, p in ipairs(ocean:GetDescendants()) do
		if p:IsA("BasePart") and p.Position.Y <= 0.3 and p.Size.Y <= 2.5 and p.Position.Y > -5 then
			lowered[p] = p.CFrame
			p.CFrame = p.CFrame - Vector3.new(0, DROP, 0)
		end
	end
end

-- static data for a world cell: hidden on land, clear over shallow sand, wave damping
local function retarget(c, i, j)
	c.i, c.j = i, j
	local x, z = i * CELL + CELL / 2, j * CELL + CELL / 2
	c.x, c.z = x, z
	c.damp = Waves.Damp(x, z)
	c.var = (i * 7 + j * 13) % 3
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -70, 0), params)
	c.land = hit ~= nil and hit.Position.Y > SEA - 1
	c.shallow = hit ~= nil and not c.land and hit.Position.Y > SEA - 10
	c.band = -1
	local p = c.part
	p.Transparency = c.land and 1 or (c.shallow and 0.45 or 0)
	if c.shallow then
		p.Color = SHALLOW
		c.band = -2
	end
end

local function build(n, world)
	N = n
	folder = Instance.new("Folder")
	folder.Name = "VoxelSea"
	folder.Parent = workspace
	-- ground rays see the map but not the (lowered) flat sea
	local list = {}
	for _, ch in ipairs(world:GetChildren()) do
		if ch.Name ~= "Ocean" then
			table.insert(list, ch)
		end
	end
	params.FilterDescendantsInstances = list
	parts, cells, cfs = table.create(n * n), table.create(n * n), table.create(n * n)
	for k = 1, n * n do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(CELL, DEPTH, CELL)
		p.CFrame = CFrame.new(0, -200, 0)
		p.Parent = folder
		parts[k] = p
		cells[k] = { part = p, i = math.huge, j = math.huge }
		cfs[k] = p.CFrame
	end
end

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local fx = cam.CFrame.Position + Vector3.new(look.X, 0, look.Z) * (N * CELL * 0.2)
	local cx, cz = math.floor(fx.X / CELL), math.floor(fx.Z / CELL)
	ox, oz = cx - N // 2, cz - N // 2
	local t = Waves.Now()
	local half = N / 2
	for si = 0, N - 1 do
		-- world column i in the window that maps to slot si
		local i = ox + ((si - ox) % N)
		for sj = 0, N - 1 do
			local j = oz + ((sj - oz) % N)
			local k = si * N + sj + 1
			local c = cells[k]
			if c.i ~= i or c.j ~= j then
				retarget(c, i, j)
			end
			if c.land then
				cfs[k] = CFrame.new(c.x, -200, c.z)
			else
				-- edge fade: full waves in the middle, flat (at the lowered sea) at the rim
				local e = math.max(math.abs(i - cx), math.abs(j - cz)) / half
				local w = math.clamp((1 - e) / 0.3, 0, 1)
				local raw = Waves.Raw(c.x, c.z, t)
				local h = raw * Waves.Amp * c.damp
				local top = SEA + h * w - DROP * (1 - w) * 0.9
				top = math.floor(top / STEP + 0.5) * STEP
				cfs[k] = CFrame.new(c.x, top - DEPTH / 2, c.z)
				if not c.shallow then
					local b = math.clamp(math.floor((raw * c.damp * w * 0.5 + 0.5) * BANDS), 0, BANDS - 1)
					if b ~= c.band then
						c.band = b
						c.part.Color = palette[b][c.var]
					end
				end
			end
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function VoxelSea.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 60)
		local ocean = world and world:WaitForChild("Ocean", 60)
		if not ocean then
			return
		end
		local q = Settings.Values and Settings.Values.quality or "High"
		local n = SIZES[q]
		if not n then
			return -- Low: keep the flat textured sea
		end
		lowerFlatSea(ocean)
		build(n, world)
		local acc = 0
		RunService.RenderStepped:Connect(function(dt)
			acc += dt
			if acc < 1 / 30 then
				return
			end
			acc = 0
			step()
		end)
	end)
end

return VoxelSea
