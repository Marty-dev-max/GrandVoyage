-- VoxelSea (v0.25.144, owner reference: a sea made of block columns that rise and fall, white on the crests, dark in
-- the troughs). Block columns follow the camera; each column's top follows the shared wave surface
-- (Shared/Modules/Waves, the same one ShipService floats ships on), snapped to voxel steps, colored from a height ramp.
-- v0.25.145 (owner: the square patch following the camera looked bad, waves too low, make it the whole sea, no
-- stutter): TWO tiers = fine 4-stud blocks near the camera + coarse 12-stud blocks out to ~290 studs (the coarse
-- tier skips the cells the fine one covers), every frame for the fine tier, every other frame for the coarse one.
-- The flat sea beyond is recolored locally to the ramp's middle and lowered under the troughs; the coarse tier's rim
-- fades height AND color into it, so the edge melts away at the horizon.
-- Columns are recycled toroidally: a column owns world cell (i, j) with i % N == its slot, so moving only re-targets
-- the cells that scrolled in (one ground ray each: land cells hide, shallow sand makes the column clear turquoise).
-- Off on Low graphics (the textured flat sea stays).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Waves = require(ReplicatedStorage.Shared.Modules.Waves)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Settings = require(script.Parent.Settings)

local VoxelSea = {}

local SEA = GameConfig.SeaLevel
local DROP = Waves.Amp + 0.4 -- how far the flat sea is lowered under the troughs
-- per quality: { fine N, coarse N } (fine cells 4 studs, coarse 12)
local SIZES = { Medium = { 36, 36 }, High = { 48, 48 }, Ultra = { 56, 56 } }

-- height ramp (n = height / amplitude, -1..1): deep teal -> turquoise -> pale -> white crest
local RAMP = {
	{ -1.0, Color3.fromRGB(12, 70, 98) },
	{ -0.35, Color3.fromRGB(22, 122, 156) },
	{ 0.15, Color3.fromRGB(36, 166, 194) },
	{ 0.5, Color3.fromRGB(104, 210, 220) },
	{ 0.72, Color3.fromRGB(212, 243, 245) },
	{ 1.0, Color3.fromRGB(250, 255, 255) },
}
local FLAT = Color3.fromRGB(28, 140, 172) -- the flat far sea = the ramp near 0 (slightly below: rest water)
local BANDS = 14
local FADES = 4 -- color steps from the ramp into FLAT at the coarse rim
local palette = {} -- [fade][band][variant] = Color3
local function ramp(n)
	for i = 2, #RAMP do
		if n <= RAMP[i][1] then
			local a, b = RAMP[i - 1], RAMP[i]
			return a[2]:Lerp(b[2], (n - a[1]) / (b[1] - a[1]))
		end
	end
	return RAMP[#RAMP][2]
end
for f = 0, FADES do
	palette[f] = {}
	for b = 0, BANDS - 1 do
		palette[f][b] = {}
		local c = ramp(-1 + 2 * (b + 0.5) / BANDS):Lerp(FLAT, f / FADES)
		for v = 0, 2 do
			-- tiny per-cell shade variants: the block grid reads like the reference
			palette[f][b][v] = c:Lerp(v == 0 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), v == 1 and 0.05 or 0.035)
		end
	end
end
local SHALLOW = Color3.fromRGB(90, 220, 215)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local folder

local function recolorFlatSea(ocean)
	for _, p in ipairs(ocean:GetDescendants()) do
		if p:IsA("BasePart") and p.Position.Y <= 0.3 and p.Size.Y <= 2.5 and p.Position.Y > -5 then
			p.CFrame = p.CFrame - Vector3.new(0, DROP, 0)
			if p.Name == "Water" then
				p.Color = FLAT
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0
				p.Reflectance = 0
			end
		end
	end
end

local function newTier(n, cell, step, depth, fadeRim, fine)
	local t = { n = n, cell = cell, step = step, depth = depth, fadeRim = fadeRim, fine = fine }
	t.parts, t.cells, t.cfs = table.create(n * n), table.create(n * n), table.create(n * n)
	for k = 1, n * n do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(cell, depth, cell)
		p.CFrame = CFrame.new(0, -200, 0)
		p.Parent = folder
		t.parts[k] = p
		t.cells[k] = { part = p, i = math.huge, j = math.huge }
		t.cfs[k] = p.CFrame
	end
	return t
end

-- static data for a world cell: hidden on land, clear over shallow sand, wave damping
local function retarget(t, c, i, j)
	c.i, c.j = i, j
	local x, z = i * t.cell + t.cell / 2, j * t.cell + t.cell / 2
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

-- fine: the inner square (in coarse cells) the fine tier covers, so the coarse tier hides there
local function stepTier(t, fx, fz, now, hole)
	local n, cell = t.n, t.cell
	local cx, cz = math.floor(fx / cell), math.floor(fz / cell)
	local ox, oz = cx - n // 2, cz - n // 2
	local half = n / 2
	local cells, cfs = t.cells, t.cfs
	for si = 0, n - 1 do
		local i = ox + ((si - ox) % n)
		for sj = 0, n - 1 do
			local j = oz + ((sj - oz) % n)
			local k = si * n + sj + 1
			local c = cells[k]
			if c.i ~= i or c.j ~= j then
				retarget(t, c, i, j)
			end
			local x, z = c.x, c.z
			if c.land or (hole and math.abs(x - hole.x) < hole.r and math.abs(z - hole.z) < hole.r) then
				cfs[k] = CFrame.new(x, -200, z)
			else
				local w, f = 1, 0
				if t.fadeRim then
					-- rim fade: full waves inside, flat at the lowered sea + FLAT color at the edge
					local e = math.max(math.abs(i - cx), math.abs(j - cz)) / half
					w = math.clamp((1 - e) / 0.35, 0, 1)
					f = math.floor((1 - w) * FADES + 0.5)
				end
				local raw = Waves.Raw(x, z, now)
				local h = raw * Waves.Amp * c.damp
				local top = SEA + h * w - DROP * (1 - w)
				top = math.floor(top / t.step + 0.5) * t.step
				cfs[k] = CFrame.new(x, top - t.depth / 2, z)
				if not c.shallow then
					local b = math.clamp(math.floor((raw * c.damp * 0.5 + 0.5) * BANDS), 0, BANDS - 1)
					local key = f * 100 + b
					if key ~= c.band then
						c.band = key
						c.part.Color = palette[f][b][c.var]
					end
				end
			end
		end
	end
	workspace:BulkMoveTo(t.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function VoxelSea.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 60)
		local ocean = world and world:WaitForChild("Ocean", 60)
		if not ocean then
			return
		end
		local q = Settings.Values and Settings.Values.quality or "High"
		local sz = SIZES[q]
		if not sz then
			return -- Low: keep the flat textured sea
		end
		recolorFlatSea(ocean)
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
		local fine = newTier(sz[1], 4, 0.5, 8, false, true)
		local coarse = newTier(sz[2], 12, 1, 10, true, false)
		local frame = 0
		RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			frame += 1
			local now = Waves.Now()
			local pos = cam.CFrame.Position
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
			local f1 = pos + flat * (fine.n * fine.cell * 0.25)
			stepTier(fine, f1.X, f1.Z, now)
			if frame % 2 == 0 then
				-- the coarse ring leaves a hole a little smaller than the fine square (no gaps at the seam)
				local hole = { x = (math.floor(f1.X / 4) + 0.5) * 4, z = (math.floor(f1.Z / 4) + 0.5) * 4, r = fine.n * 4 / 2 - 8 }
				local f2 = pos + flat * (coarse.n * coarse.cell * 0.15)
				stepTier(coarse, f2.X, f2.Z, now, hole)
			end
		end)
	end)
end

return VoxelSea
