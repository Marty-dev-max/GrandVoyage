-- MobZones (v0.25.143, owner: "monster spots should read from the map itself, no labels"): every island monster area
-- (Islands spawns with radius >= 12; small town patrols are skipped) gets
--   * a worn clearing: irregular dirt / mud / sand tiles laid on the ground inside the circle,
--   * a border: stakes (camps) or rocks + bones (dens) around the rim, open toward the island middle (the way in),
--   * a LAIR at the back of the circle that says who lives there: camp = tents + fire + tall flag, den = rock cave,
--     grove = a huge stump with fruit bunches and vines, wallow = mud pools + broken fence.
-- Built at runtime by MonsterService (needs raycasts on the finished map), so Studio Edit does not show it.
-- Blocks only (voxel look), anchored, CanQuery off: clicks and monster ground rays pass through.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local MonsterLooks = require(ReplicatedStorage.Shared.Config.MonsterLooks)

local Z = {}
local M = Enum.Material

-- monster id -> theme (humanoids default to camp, the rest to den)
local THEME = {
	ForestMonkey = "grove", WildBoar = "wallow", CircusLion = "den", JungleTiger = "den", ClawCat = "den",
	GuardWolf = "den", SharkfolkBrawler = "camp", SawfolkRaider = "camp", OctofolkBrute = "camp",
}
local GROUND = {
	camp = Color3.fromRGB(176, 132, 88), den = Color3.fromRGB(160, 134, 100), grove = Color3.fromRGB(140, 148, 84),
	wallow = Color3.fromRGB(146, 108, 72),
}
local OK_MAT = { [M.Grass] = true, [M.Ground] = true, [M.Sand] = true, [M.Mud] = true, [M.LeafyGrass] = true, [M.Slate] = true, [M.Rock] = true }

local folder
local function blk(size, color, cf, mat, opts)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = opts and opts.collide or false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = not (opts and opts.flat)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local function ground(x, z, grassOnly)
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if hit and OK_MAT[hit.Material] and hit.Normal.Y > 0.9 and hit.Position.Y > 4 then
		if grassOnly and hit.Material ~= M.Grass and hit.Material ~= M.LeafyGrass then
			return nil
		end
		return hit.Position
	end
	return nil
end

local function hash(a, b)
	local h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return h - math.floor(h)
end

-- worn clearing: 4-stud tiles inside the circle, ragged edge
local function clearing(c, r, color)
	local step = 4
	for gx = -r, r, step do
		for gz = -r, r, step do
			local d = math.sqrt(gx * gx + gz * gz)
			local n = hash(c.X + gx, c.Z + gz)
			if d < r * (0.7 + n * 0.25) and n > 0.03 then
				local p = ground(c.X + gx, c.Z + gz, true)
				if p then
					local shade = color:Lerp(Color3.new(0, 0, 0), n * 0.12)
					blk(Vector3.new(step, 0.3, step), shade, CFrame.new(p + Vector3.new(0, 0.12, 0)), M.Sand, { flat = true })
				end
			end
		end
	end
end

local function at(c, a, d)
	return ground(c.X + math.cos(a) * d, c.Z + math.sin(a) * d)
end

local function tent(p, yaw, color)
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	-- stepped block tent: 4 layers getting narrower + a dark doorway
	for i = 0, 3 do
		blk(Vector3.new(7 - i * 1.7, 1.4, 8), i % 2 == 0 and color or color:Lerp(Color3.new(1, 1, 1), 0.2), cf * CFrame.new(0, 0.7 + i * 1.4, 0), M.Plaster, { collide = true })
	end
	blk(Vector3.new(2.2, 2.6, 0.2), Color3.fromRGB(30, 22, 20), cf * CFrame.new(0, 1.3, -4.05), M.SmoothPlastic)
	blk(Vector3.new(0.4, 7, 0.4), Color3.fromRGB(90, 60, 36), cf * CFrame.new(0, 3.5, -4.3), M.Wood)
end

local function campfire(p)
	for i = 0, 3 do
		blk(Vector3.new(3.6, 0.7, 0.7), Color3.fromRGB(96, 62, 38), CFrame.new(p + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, i * math.pi / 4, 0), M.Wood)
	end
	local flame = blk(Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(255, 150, 50), CFrame.new(p + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.6, 0), M.Neon)
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 6
	f.Parent = flame
	local l = Instance.new("PointLight")
	l.Range = 18
	l.Brightness = 1.4
	l.Color = Color3.fromRGB(255, 160, 80)
	l.Parent = flame
end

local function flag(p, color)
	blk(Vector3.new(0.7, 18, 0.7), Color3.fromRGB(80, 56, 36), CFrame.new(p + Vector3.new(0, 9, 0)), M.Wood, { collide = true })
	blk(Vector3.new(0.2, 3.4, 5), color, CFrame.new(p + Vector3.new(0, 16, 2.6)), M.Plaster)
	blk(Vector3.new(0.25, 1.2, 1.2), Color3.fromRGB(240, 236, 220), CFrame.new(p + Vector3.new(0, 16, 2.6)), M.Plaster)
end

local function crate(p, yaw)
	blk(Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(190, 140, 86), CFrame.new(p + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, yaw, 0), M.WoodPlanks, { collide = true })
end

local function rock(p, s, color)
	blk(Vector3.new(s, s * 0.7, s * 0.9), color, CFrame.new(p + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(0, s, 0), M.Slate, { collide = true })
	blk(Vector3.new(s * 0.6, s * 0.5, s * 0.6), color:Lerp(Color3.new(1, 1, 1), 0.1), CFrame.new(p + Vector3.new(s * 0.15, s * 0.75, 0)) * CFrame.Angles(0, s * 2, 0), M.Slate, { collide = true })
end

local function bones(p, yaw)
	for i = 0, 2 do
		blk(Vector3.new(2.2, 0.35, 0.35), Color3.fromRGB(240, 234, 216), CFrame.new(p + Vector3.new(i * 0.6, 0.2, i * 0.4)) * CFrame.Angles(0, yaw + i * 1.3, 0), M.SmoothPlastic)
	end
	blk(Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(236, 230, 212), CFrame.new(p + Vector3.new(-0.8, 0.45, -0.6)), M.SmoothPlastic)
end

-- lair builders: p = the lair spot (back of the zone), out = unit vector from the zone middle to the lair
local LAIR = {}
function LAIR.camp(p, out, color)
	local yaw = math.atan2(out.X, out.Z)
	tent(p, yaw, color)
	tent(p + Vector3.new(-out.Z, 0, out.X) * 10 - out * 2, yaw + 0.5, color:Lerp(Color3.new(0, 0, 0), 0.2))
	campfire(p - out * 8)
	flag(p + Vector3.new(out.Z, 0, -out.X) * 9, color)
	crate(p + Vector3.new(out.Z, 0, -out.X) * 6 - out * 3, 0.3)
	crate(p + Vector3.new(out.Z, 0, -out.X) * 7 - out * 0.5, 0.9)
end
function LAIR.den(p, out)
	-- a rock cave: two piles of boulders, a roof slab and a black mouth facing the zone
	local side = Vector3.new(-out.Z, 0, out.X)
	local stone = Color3.fromRGB(118, 112, 104)
	for _, s in ipairs({ -1, 1 }) do
		rock(p + side * s * 5, 6.5, stone)
		rock(p + side * s * 4 + out * 3, 5, stone:Lerp(Color3.new(0, 0, 0), 0.1))
	end
	local yaw = math.atan2(out.X, out.Z)
	blk(Vector3.new(14, 3, 9), stone:Lerp(Color3.new(1, 1, 1), 0.05), CFrame.new(p + Vector3.new(0, 7.5, 0) + out * 1.5) * CFrame.Angles(0, yaw, 0), M.Slate, { collide = true })
	blk(Vector3.new(5.5, 5.5, 0.4), Color3.fromRGB(16, 14, 14), CFrame.new(p + Vector3.new(0, 2.9, 0) - out * 1.2) * CFrame.Angles(0, yaw, 0), M.SmoothPlastic)
	blk(Vector3.new(9, 3.5, 3), Color3.fromRGB(96, 130, 70), CFrame.new(p + Vector3.new(0, 9.6, 0) + out * 2) * CFrame.Angles(0, yaw, 0), M.Grass)
	bones(p - out * 6 + side * 3, 0.4)
	bones(p - out * 9 - side * 4, 2.1)
end
function LAIR.grove(p, out)
	-- a huge hollow stump with vines and fruit bunches: the monkeys' tree
	local bark = Color3.fromRGB(116, 80, 50)
	for i = 0, 3 do
		blk(Vector3.new(8 - i, 3, 8 - i), bark:Lerp(Color3.new(0, 0, 0), i * 0.05), CFrame.new(p + Vector3.new(0, 1.5 + i * 3, 0)) * CFrame.Angles(0, i * 0.4, 0), M.Wood, { collide = true })
	end
	blk(Vector3.new(14, 2.5, 14), Color3.fromRGB(70, 150, 60), CFrame.new(p + Vector3.new(0, 13.2, 0)), M.Grass, { collide = true })
	blk(Vector3.new(10, 2.5, 10), Color3.fromRGB(90, 170, 70), CFrame.new(p + Vector3.new(0, 15.4, 0)) * CFrame.Angles(0, 0.6, 0), M.Grass)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local q = p + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		blk(Vector3.new(0.35, 6, 0.35), Color3.fromRGB(60, 120, 50), CFrame.new(q + Vector3.new(0, 9, 0)), M.Grass)
		if i % 2 == 0 then
			blk(Vector3.new(1.6, 1.8, 1.2), Color3.fromRGB(250, 214, 60), CFrame.new(q + Vector3.new(0, 11.4, 0)), M.SmoothPlastic)
		end
	end
	blk(Vector3.new(3.2, 3.6, 0.3), Color3.fromRGB(30, 20, 14), CFrame.new(p + Vector3.new(0, 1.8, 0) - out * 4.1) * CFrame.Angles(0, math.atan2(out.X, out.Z), 0), M.SmoothPlastic)
end
function LAIR.wallow(p, out)
	-- mud pools with a shine and a broken fence behind them
	for i = 0, 2 do
		local q = p - out * (i * 6) + Vector3.new(-out.Z, 0, out.X) * ((i - 1) * 5)
		local g = ground(q.X, q.Z)
		if g then
			blk(Vector3.new(7, 0.3, 5), Color3.fromRGB(78, 56, 38), CFrame.new(g + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, i, 0), M.Mud, { flat = true })
			blk(Vector3.new(4, 0.32, 2.5), Color3.fromRGB(110, 86, 60), CFrame.new(g + Vector3.new(0.5, 0.22, 0)) * CFrame.Angles(0, i, 0), M.Glass, { flat = true })
		end
	end
	local side = Vector3.new(-out.Z, 0, out.X)
	for k = -3, 3 do
		if k ~= 1 then
			local q = p + out * 5 + side * k * 2.5
			local g = ground(q.X, q.Z)
			if g then
				blk(Vector3.new(0.5, k == -2 and 1.6 or 3, 0.5), Color3.fromRGB(120, 84, 50), CFrame.new(g + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, k * 0.08), M.Wood, { collide = true })
			end
		end
	end
	local q = p + out * 5
	local g = ground(q.X, q.Z)
	if g then
		blk(Vector3.new(0.4, 0.4, 10), Color3.fromRGB(130, 92, 56), CFrame.new(g + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.atan2(side.X, side.Z), 0.12), M.Wood)
	end
end

-- border: markers on the rim, open on the side that faces the island middle (the way in)
local function border(c, r, theme, inward)
	local n = math.floor(r * 0.45)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if dir:Dot(inward) < 0.6 then
			local p = at(c, a, r + 2)
			if p then
				if theme == "camp" then
					-- palisade stakes in pairs, sharpened (a small block on top)
					for k = 0, 1 do
						local q = p + Vector3.new(-dir.Z, 0, dir.X) * (k * 1.1)
						blk(Vector3.new(0.8, 4.2, 0.8), Color3.fromRGB(120, 84, 50), CFrame.new(q + Vector3.new(0, 2, 0)), M.Wood, { collide = true })
						blk(Vector3.new(0.5, 0.6, 0.5), Color3.fromRGB(150, 110, 70), CFrame.new(q + Vector3.new(0, 4.4, 0)), M.Wood)
					end
				elseif i % 2 == 0 then
					rock(p, 2.2 + hash(p.X, p.Z) * 2, Color3.fromRGB(128, 124, 116))
				elseif theme ~= "grove" then
					bones(p, a)
				end
			end
		end
	end
end

function Z.Build()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	params.FilterDescendantsInstances = { world }
	folder = Instance.new("Folder")
	folder.Name = "MobZones"
	folder.Parent = world
	local n = 0
	for _, island in ipairs(Islands.List) do
		local mid = Vector3.new(island.x, 0, island.z or 0)
		for _, sp in ipairs(island.spawns or {}) do
			if sp.radius >= 12 and sp.lair ~= false then
				local cx, cz = island.x + sp.offset.X, (island.z or 0) + sp.offset.Y
				local c = ground(cx, cz) or Vector3.new(cx, 8, cz)
				local theme = THEME[sp.monster] or (MonsterLooks.ById[sp.monster] and "camp" or "den")
				local inward = (mid - Vector3.new(cx, 0, cz))
				inward = inward.Magnitude > 1 and inward.Unit or Vector3.xAxis
				clearing(c, sp.radius, GROUND[theme])
				border(c, sp.radius, theme, inward)
				local out = -inward
				local lp = ground(cx + out.X * sp.radius * 0.8, cz + out.Z * sp.radius * 0.8)
				if lp then
					local color = Color3.fromHSV(hash(cx, cz), 0.55, 0.6)
					LAIR[theme](lp, out, color)
				end
				n += 1
			end
		end
	end
	print(string.format("[MobZones] %d monster areas dressed", n))
end

return Z
