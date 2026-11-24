--!strict
-- v0.25.134 (owner: "islands feel fixed to a circle"): organic island outline built from 8-stud voxel columns.
-- Land never shrinks below the old grass disc (r - 14), so every hand-laid prop stays on grass; it only grows
-- headlands. Docks (local +-x) and the south harbor (+z) are forced out to r. Rows of equal cells are merged into
-- one part each (about 1000 parts per island). Own Random per island id: the shared Kit.rng is never touched.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Kit)

local S = {}

local CELL = 8
local TOP = 7.5 -- walkable grass top (GROUND 7.6 props sit on it)
local M = Enum.Material

local O = require(game:GetService("ReplicatedStorage").Shared.Modules.IslandOutline)
local near = O.Near
local beach = O.Beach
S.Radius = O.Radius

local function params(island)
	-- build randomness: same seed as the outline phases, the 6 phase draws burned first
	local rnd = Random.new(O.Hash(tostring(island.id)))
	for _ = 1, 6 do
		rnd:NextNumber(0, math.pi * 2)
	end
	return { rnd = rnd }
end

-- cell kinds: 1 grass, 2 cliff ledge, 3 high sand, 4 low sand, 5 shallows; nil = open sea
local KIND = {
	{ y0 = -6, y1 = TOP, mat = M.Grass },
	{ y0 = -6, y1 = 3.2, mat = M.Rock },
	{ y0 = -6, y1 = 3.6, mat = M.Sand },
	{ y0 = -6, y1 = 1.8, mat = M.Sand },
	{ y0 = -9, y1 = -5, mat = M.Sand },
}

function S.Build(island, c: Vector3, r: number, parent: Instance, pal)
	local p = params(island)
	local rnd = p.rnd
	local rock = Color3.fromRGB(150, 140, 128)
	local dirt = pal.dirt or Color3.fromRGB(140, 105, 75)
	local colors = {
		pal.grass,
		rock,
		pal.sand,
		pal.sand:Lerp(Color3.fromRGB(200, 190, 160), 0.25),
		Color3.fromRGB(34, 168, 186),
	}
	local function kindAt(x: number, z: number): number?
		local d = math.sqrt(x * x + z * z)
		local a = math.atan2(z, x)
		local R = S.Radius(island, r, a)
		if d <= R then
			return 1
		end
		local b = beach(island, r, a)
		if b < 6 then
			if d <= R + 6 then
				return 2 -- rocky ledge under a cliff
			end
		elseif d <= R + b * 0.5 then
			return 3
		elseif d <= R + b then
			return 4
		end
		if d <= R + math.max(b, 6) + 34 then
			return 5
		end
		return nil
	end
	local function part(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, name: string)
		local o = Instance.new("Part")
		o.Anchored = true
		o.Size = size
		o.CFrame = cf
		o.Color = color
		o.Material = mat
		o.TopSurface = Enum.SurfaceType.Smooth
		o.BottomSurface = Enum.SurfaceType.Smooth
		o.Name = name
		o.Parent = parent
		return o
	end
	local ext = math.ceil((r * 1.3 + 70) / CELL)
	local grid = {}
	for iz = -ext, ext do
		local row = {}
		grid[iz] = row
		for ix = -ext, ext do
			row[ix] = kindAt(ix * CELL, iz * CELL)
		end
	end
	local function kAt(ix, iz)
		local row = grid[iz]
		return row and row[ix]
	end
	for iz = -ext, ext do
		local row = grid[iz]
		local ix = -ext
		while ix <= ext do
			local k = row[ix]
			if not k then
				ix += 1
				continue
			end
			local j = ix
			while j + 1 <= ext and row[j + 1] == k do
				j += 1
			end
			local spec = KIND[k]
			local x0, x1 = (ix - 0.5) * CELL, (j + 0.5) * CELL
			local z = iz * CELL
			local w = x1 - x0
			if k == 1 then
				-- earth body under a 1-stud grass cap: from the sea the edge reads as a layered cliff
				local body = part(Vector3.new(w, TOP - 1 - spec.y0, CELL), CFrame.new(c.X + (x0 + x1) / 2, (spec.y0 + TOP - 1) / 2, c.Z + z), dirt:Lerp(rock, 0.45 + rnd:NextNumber(-0.08, 0.08)), M.Rock, "IslandBody")
				body.CastShadow = false
				part(Vector3.new(w, 1, CELL), CFrame.new(c.X + (x0 + x1) / 2, TOP - 0.5, c.Z + z), colors[1], M.Grass, "IslandGrass")
			else
				local col = colors[k]:Lerp(Color3.new(0, 0, 0), rnd:NextNumber(0, 0.05))
				local o = part(Vector3.new(w, spec.y1 - spec.y0, CELL), CFrame.new(c.X + (x0 + x1) / 2, (spec.y0 + spec.y1) / 2, c.Z + z), col, spec.mat, k == 5 and "Shallows" or "IslandShore")
				if k == 5 then
					o.CanCollide = false
					o.CastShadow = false
				end
			end
			ix = j + 1
		end
	end
	-- surf: thin white blocks on every shore cell that touches open water or the shallows
	for iz = -ext, ext do
		for ix = -ext, ext do
			local k = grid[iz][ix]
			if k and k <= 4 then
				for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local nk = kAt(ix + n[1], iz + n[2])
					if nk == nil or nk == 5 then
						local cx, cz = (ix + n[1] * 0.62) * CELL, (iz + n[2] * 0.62) * CELL
						local size = n[1] ~= 0 and Vector3.new(CELL * 0.35, 0.3, CELL + 1) or Vector3.new(CELL + 1, 0.3, CELL * 0.35)
						local f = part(size, CFrame.new(c.X + cx, 0.15, c.Z + cz), Color3.fromRGB(245, 252, 255), M.Neon, "ShoreFoam")
						f.Transparency = 0.35
						f.CanCollide = false
						f.CanQuery = false
						f.CastShadow = false
						CollectionService:AddTag(f, "Foam")
					end
				end
			end
		end
	end
	-- chunky rock blocks at the foot of the cliffs + a few sea stacks
	for iz = -ext, ext do
		for ix = -ext, ext do
			if grid[iz][ix] == 2 and rnd:NextNumber() < 0.35 then
				local s = rnd:NextNumber(3, 6)
				local h = rnd:NextNumber(3, 9)
				part(Vector3.new(s, h, s * rnd:NextNumber(0.7, 1.3)), CFrame.new(c.X + ix * CELL + rnd:NextNumber(-2, 2), 2 + h / 2 - 2, c.Z + iz * CELL + rnd:NextNumber(-2, 2)) * CFrame.Angles(0, math.floor(rnd:NextNumber(0, 4)) * math.pi / 8, 0), rock:Lerp(Color3.new(0, 0, 0), rnd:NextNumber(0, 0.15)), M.Rock, "ShoreRock")
			end
		end
	end
	-- headlands beyond the old disc (no layout ever used them): woods, palms by the beaches, bushes and boulders.
	-- Own stream through Kit.WithRng so the shared Kit.rng never moves.
	Kit.WithRng(rnd, function()
		for iz = -ext, ext do
			for ix = -ext, ext do
				if grid[iz][ix] == 1 then
					local x, z = ix * CELL + rnd:NextNumber(-3, 3), iz * CELL + rnd:NextNumber(-3, 3)
					local a = math.atan2(z, x)
					local d = math.sqrt(x * x + z * z)
					local R = S.Radius(island, r, a)
					local free = near(a, 0, 0.6) + near(a, math.pi, 0.6) + near(a, math.pi / 2, 0.9) == 0
					if free and d > r - 8 and d < R - 4 then
						local roll = rnd:NextNumber()
						local pos = c + Vector3.new(x, TOP, z)
						if roll < 0.2 then
							if beach(island, r, a) > 8 and d > R - 16 then
								Kit.Palm(pos - Vector3.new(0, 3.2, 0), rnd:NextNumber(14, 20))
							else
								Kit.RoundTree(pos, rnd:NextNumber(0.9, 1.35))
							end
						elseif roll < 0.3 then
							Kit.Bush(pos, rnd:NextNumber(3, 5))
						elseif roll < 0.34 then
							Kit.RockCluster(pos, rnd:NextNumber(3, 6))
						end
					end
				end
			end
		end
	end)
	for _ = 1, 7 do
		local a = rnd:NextNumber(0, math.pi * 2)
		if near(a, 0, 0.5) + near(a, math.pi, 0.5) + near(a, math.pi / 2, 0.8) == 0 then
			local d = S.Radius(island, r, a) + beach(island, r, a) + rnd:NextNumber(18, 40)
			local base = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			local h = rnd:NextNumber(6, 16)
			local s = rnd:NextNumber(7, 12)
			part(Vector3.new(s, h + 6, s), CFrame.new(base + Vector3.new(0, h / 2 - 3, 0)), rock, M.Rock, "SeaStack")
			part(Vector3.new(s * 0.6, 3, s * 0.6), CFrame.new(base + Vector3.new(s * 0.15, h + 1.5, -s * 0.1)), rock:Lerp(Color3.new(1, 1, 1), 0.1), M.Rock, "SeaStack")
		end
	end
end

return S
