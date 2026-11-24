-- Daybreak Island (v0.22): a hand-laid layout after the owner's concept art.
--
--   West  : dense jungle. The spawn clearing (Old Salt Rowan's camp) sits in the middle of it, the Monkey Grove to
--           its north, the Tiger Den (ring of old stones) to its south.
--   Middle: a winding dirt trail runs east out of the jungle between the windmill hills. Bandit Hill (south) has the
--           bandit camp and a windmill; the North Windmill Hill and a lower terrace carry the other two mills.
--   East  : the windmill village: stone plaza with a two-tier fountain, timber-and-plaster houses with terracotta
--           roofs, the Job Master and shops around the plaza; south of it the farm fields and the Boar Meadow.
--   Coast : rocky shore all around, a stone harbor with three wooden docks (the middle one launches ships) and the
--           shipyard in the east, the lighthouse on a rock outcrop on the north-east (left when you face the island
--           from the harbor).
--
-- Coordinates are local to the island center (X east = toward Conch Bay, Z north/south). Monster zones come from
-- Config/Islands (spawns) and are kept clear of props. Story order: monkeys -> tigers -> boars -> bandits.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)

local D = {}

local P, Cyl, Ball, Wedge = Kit.P, Kit.Cyl, Kit.Ball, Kit.Wedge
local M = Enum.Material
local C = Kit.Colors
local rng = Kit.rng
local decor = Kit.decor

-- ===== key places (local X, Z) =====
local CAMP = Vector2.new(-165, 0) -- spawn clearing in the jungle
local SPAWN = Vector2.new(-161, -8) -- v0.25.20 (owner): a few steps in front of Old Salt Rowan (was -158, 6)
local PLAZA = Vector2.new(60, 0)
local PLAZA_R = 40
local BANDIT_HILL = Vector2.new(-35, -110)
local NORTH_HILL = Vector2.new(-45, 115)
local TERRACE = Vector2.new(-15, 66)
local LIGHTHOUSE = Vector2.new(150, 172)
local FIELDS = Vector2.new(140, -112)
local HARBOR_ARC = 0.5 -- radians either side of +X: stone quay instead of rocky shore
local QUAY_IN = 222 -- inner radius of the quay
local DOCK_Z = { -42, 0, 42 } -- the middle one is the launch dock

-- The island as it was before v0.22 (only used to advance the shared random stream, see WorldBuilder.buildIsland)
local LEGACY_SPAWNS = {
	{ offset = Vector2.new(-120, 115), radius = 42, monster = "BeachCrab", count = 6 },
	{ offset = Vector2.new(115, 120), radius = 38, monster = "ForestMonkey", count = 5 },
	{ offset = Vector2.new(-110, -130), radius = 42, monster = "WildBoar", count = 5 },
	{ offset = Vector2.new(70, -150), radius = 34, monster = "MountainBandit", count = 4 },
}
function D.LegacyIsland(island)
	local t = table.clone(island)
	t.spawns = LEGACY_SPAWNS
	t.layout = nil
	return t
end

-- ===== palette =====
local WALLS = { Color3.fromRGB(252, 242, 222), Color3.fromRGB(246, 230, 200), Color3.fromRGB(250, 236, 214) }
local ROOFS = { Color3.fromRGB(206, 96, 58), Color3.fromRGB(190, 82, 52), Color3.fromRGB(218, 116, 70), Color3.fromRGB(176, 76, 50) }
local TRIM = Color3.fromRGB(110, 70, 42)
local PATH = Color3.fromRGB(214, 176, 120)
local PATH_EDGE = Color3.fromRGB(188, 150, 100)
local STONE = Color3.fromRGB(196, 186, 168)
local JUNGLE = Color3.fromRGB(72, 160, 64)
local ROCK = Color3.fromRGB(150, 140, 128)

local function v2(x, z)
	return Vector2.new(x, z)
end

-- ===== winding paths =====
-- Catmull-Rom through the points, laid as flat dirt ribbons (Ground material: plants never grow on it)
local function spline(pts, step)
	local out = {}
	local n = #pts
	for i = 1, n - 1 do
		local p0 = pts[math.max(1, i - 1)]
		local p1, p2 = pts[i], pts[i + 1]
		local p3 = pts[math.min(n, i + 2)]
		local len = (p2 - p1).Magnitude
		local k = math.max(1, math.ceil(len / step))
		for j = 0, k - 1 do
			local t = j / k
			local t2, t3 = t * t, t * t * t
			-- (vector * number order: works in Roblox and in the Lune bake)
			local v = p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3
			table.insert(out, v * 0.5)
		end
	end
	table.insert(out, pts[n])
	return out
end

-- v0.22.5 (owner: paths overlapped and flickered): no two path surfaces share a height any more. Segments are cut to
-- their exact length (no overlap), the round joints sit a little LOWER (they only fill the gaps at bends), every path
-- gets its own small height step (where two paths cross, one lies cleanly on the other), and paths stop at the
-- plaza's outer ring instead of running over the paving.
-- v0.22.9 (concept review): a paved street ring runs around the plaza in front of the houses; trails stop at its edge
local STREET_IN, STREET_OUT = PLAZA_R + 2.5, 57
local PLAZA_CLIP = STREET_OUT + 0.5
local pathCount = 0
local pathPts = {} -- every trail sample with its half width (hill mounds keep clear of them)
local function clipToPlaza(a, b)
	local ina, inb = (a - PLAZA).Magnitude < PLAZA_CLIP, (b - PLAZA).Magnitude < PLAZA_CLIP
	if ina and inb then
		return nil
	end
	if not ina and not inb then
		return a, b
	end
	-- move the inside end out to the ring (circle-segment intersection)
	local o, i = ina and b or a, ina and a or b
	local d = i - o
	local f = o - PLAZA
	local A, B, C = d:Dot(d), 2 * f:Dot(d), f:Dot(f) - PLAZA_CLIP * PLAZA_CLIP
	local disc = math.max(0, B * B - 4 * A * C)
	local t = math.clamp((-B - math.sqrt(disc)) / (2 * A), 0, 1)
	local hit = o + d * t
	if ina then
		return hit, b
	end
	return a, hit
end

local function path(ctx, pts, width, opts)
	opts = opts or {}
	pathCount += 1
	local lift = 0.2 + (pathCount % 4) * 0.06
	local samples = spline(pts, 5)
	for _, sp in ipairs(samples) do
		table.insert(pathPts, { p = sp, r = width / 2 + 2.4 })
	end
	for i = 1, #samples - 1 do
		local a, b = clipToPlaza(samples[i], samples[i + 1])
		local cf
		if a then
			local pa, pb = ctx.at(a.X, a.Y), ctx.at(b.X, b.Y)
			-- every other segment sits 0.05 higher: at bends the boxes overlap on the inner side and would z-fight
			local mid = (pa + pb) / 2 + Vector3.new(0, lift + (i % 2) * 0.05, 0)
			local len = (pb - pa).Magnitude
			cf = CFrame.lookAt(mid, Vector3.new(pb.X, mid.Y, pb.Z))
			P(Vector3.new(width, 0.3, len), opts.color or PATH, cf, { material = opts.material or M.Ground, shadow = false, name = "Path" })
			-- soft darker rim so the trail reads from above
			P(Vector3.new(width + 2.4, 0.24, len), PATH_EDGE, cf * CFrame.new(0, -0.1, 0), { material = M.Ground, shadow = false, collide = false })
			-- round joints (slightly lower) so bends read as one smooth trail
			if i > 1 and (samples[i] - PLAZA).Magnitude >= PLAZA_CLIP then
				local jcf = CFrame.new(pa + Vector3.new(0, lift - 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				P(Vector3.new(0.3, width, width), opts.color or PATH, jcf, { material = opts.material or M.Ground, shadow = false, shape = Enum.PartType.Cylinder, name = "Path" })
				P(Vector3.new(0.24, width + 2.4, width + 2.4), PATH_EDGE, jcf * CFrame.new(-0.1, 0, 0), { material = M.Ground, shadow = false, collide = false, shape = Enum.PartType.Cylinder })
			end
			ctx.reserve(a.X, a.Y, width * 0.5 + 3)
		end
		if not opts.noStones and i % 3 == 0 then
			for _, side in ipairs({ -1, 1 }) do
				if rng:NextNumber() > 0.45 then
					local off, size = rng:NextNumber(-2, 2), rng:NextNumber(1.2, 2.2)
					if cf then
						local p = cf * Vector3.new(side * (width / 2 + 1.6), 0, off)
						Kit.Rock(p + Vector3.new(0, 0.3, 0), size, Color3.fromRGB(196, 190, 178)).CanCollide = false
					end
				end
			end
		end
	end
	return samples
end

local function lampsAlong(ctx, samples, every, offset)
	for i = every, #samples - 1, every do
		local a, b = samples[i], samples[i + 1]
		local dir = (b - a).Unit
		local side = (i // every) % 2 == 0 and 1 or -1
		local p = a + Vector2.new(-dir.Y, dir.X) * side * (offset or 7)
		if ctx.free(p.X, p.Y, 1.5) then
			Kit.Lamp(ctx.at(p.X, p.Y))
			ctx.reserve(p.X, p.Y, 2)
		end
	end
end

local function signpost(ctx, text, at, toward, width)
	local pos = ctx.at(at.X, at.Y)
	local face = ctx.at(toward.X, toward.Y) - pos
	Kit.PostSign(text, pos, Vector3.new(face.X, 0, face.Z).Unit, width or 12)
	ctx.reserve(at.X, at.Y, 2)
end

-- ===== nature =====
-- A jungle giant: big broad tree + buttress roots + hanging vines (roots/vines stay when the crown is dressed)
local function giantTree(ctx, x, z, scale)
	local base = ctx.at(x, z)
	local h = 14 * scale
	Kit.RoundTree(base, scale, Color3.fromRGB(70, 170, 70))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = scale * rng:NextNumber(2.4, 3.4)
		local cf = CFrame.lookAt(base, base + dir) * CFrame.new(0, scale * 0.9, -len / 2)
		-- an unrotated wedge is tall at +Z: the trunk side
		Wedge(Vector3.new(scale * 0.55, scale * 1.9, len), C.Trunk:Lerp(Color3.fromRGB(90, 60, 36), 0.3), cf, decor({ material = M.Wood }))
	end
	for _ = 1, math.floor(scale * 3) do
		local a, d = rng:NextNumber(0, math.pi * 2), h * rng:NextNumber(0.18, 0.3)
		local top = base + Vector3.new(math.cos(a) * d, h * rng:NextNumber(0.55, 0.65), math.sin(a) * d)
		local len = h * rng:NextNumber(0.2, 0.38)
		P(Vector3.new(0.25, len, 0.25), Color3.fromRGB(70, 150, 60), CFrame.new(top - Vector3.new(0, len / 2, 0)), decor({ collide = false, shadow = false, material = M.Grass }))
		Ball(0.7, Color3.fromRGB(90, 180, 70), top - Vector3.new(0, len, 0), decor({ collide = false, shadow = false, material = M.Grass }))
	end
	ctx.reserve(x, z, 4 + scale * 2)
end

-- Fill a region with jungle: broad trees, palms and bushes wherever it is free
local function jungle(ctx, center, radius, trees, minClear)
	local placed = 0
	for _ = 1, trees * 6 do
		if placed >= trees then
			break
		end
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
		local x, z = center.X + math.cos(a) * d, center.Y + math.sin(a) * d
		if ctx.free(x, z, minClear or 6) then
			local roll = rng:NextNumber()
			if roll < 0.62 then
				Kit.RoundTree(ctx.at(x, z), rng:NextNumber(1.2, 1.9), JUNGLE:Lerp(Color3.fromRGB(40, 120, 50), rng:NextNumber(0, 0.4)))
			elseif roll < 0.82 then
				Kit.Palm(ctx.at(x, z) - Vector3.new(0, 0.5, 0), rng:NextNumber(18, 26))
			else
				Kit.Bush(ctx.at(x, z), rng:NextNumber(4, 6.5), Color3.fromRGB(70, 160, 70))
			end
			ctx.reserve(x, z, 3.5)
			placed += 1
		end
	end
	-- undergrowth
	for _ = 1, trees do
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
		local x, z = center.X + math.cos(a) * d, center.Y + math.sin(a) * d
		if ctx.free(x, z, 2.5) then
			Kit.Bush(ctx.at(x, z), rng:NextNumber(2.6, 4.2), Color3.fromRGB(80, 170, 70))
			ctx.reserve(x, z, 1.5)
		end
	end
end

-- ===== buildings =====
local function timberHouse(ctx, x, z, w, d, opts, face)
	opts = opts or {}
	opts.timber = true
	opts.trim = TRIM
	opts.floors = opts.floors or (rng:NextNumber() > 0.5 and 2 or 1)
	local wall = opts.wall or WALLS[rng:NextInteger(1, #WALLS)]
	local roof = opts.roof or ROOFS[rng:NextInteger(1, #ROOFS)]
	return L.HouseAt(ctx, x, z, w, d, wall, roof, opts, face and ctx.at(face.X, face.Y) or nil)
end

local function fountain(ctx, at)
	local c = ctx.at(at.X, at.Y)
	local water = Color3.fromRGB(110, 210, 240)
	-- lower basin
	Cyl(2.8, 24, STONE, c + Vector3.new(0, 1.4, 0), { material = M.Cobblestone })
	Cyl(0.6, 21.5, water, c + Vector3.new(0, 2.1, 0), { material = M.Glass, transparency = 0.25, collide = false, shadow = false })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		P(Vector3.new(2.2, 0.8, 6.6), STONE:Lerp(Color3.new(1, 1, 1), 0.15), CFrame.new(c + Vector3.new(math.cos(a) * 11.4, 3.1, math.sin(a) * 11.4)) * CFrame.Angles(0, -a, 0), decor({ material = M.Marble }))
	end
	-- column + middle bowl
	Cyl(6.5, 3.4, STONE, c + Vector3.new(0, 5.4, 0), { material = M.Marble })
	Cyl(1.4, 12, STONE, c + Vector3.new(0, 8.4, 0), { material = M.Marble })
	Cyl(0.9, 10.6, STONE:Lerp(Color3.new(0, 0, 0), 0.1), c + Vector3.new(0, 7.6, 0), decor({ material = M.Marble }))
	Cyl(0.4, 10.4, water, c + Vector3.new(0, 9.0, 0), decor({ material = M.Glass, transparency = 0.25, collide = false, shadow = false }))
	-- upper column + top bowl + finial
	Cyl(3.6, 1.8, STONE, c + Vector3.new(0, 10.8, 0), decor({ material = M.Marble }))
	Cyl(1, 6, STONE, c + Vector3.new(0, 12.9, 0), decor({ material = M.Marble }))
	Cyl(0.3, 5.2, water, c + Vector3.new(0, 13.45, 0), decor({ material = M.Glass, transparency = 0.25, collide = false, shadow = false }))
	local top = Ball(1.6, STONE:Lerp(Color3.new(1, 1, 1), 0.2), c + Vector3.new(0, 14.4, 0), decor({ material = M.Marble }))
	-- water: spray on top, falling sheets from both bowls
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(210, 245, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Rate = 40
	spray.Speed = NumberRange.new(8, 11)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = Vector3.new(0, -28, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = top
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		for _, ring in ipairs({ { 5.6, 8.4, 5.6 }, { 2.9, 12.9, 3.6 } }) do
			local p = c + Vector3.new(math.cos(a) * ring[1], ring[2] - ring[3] / 2, math.sin(a) * ring[1])
			P(Vector3.new(1.6, ring[3], 0.15), Color3.fromRGB(190, 240, 255), CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), decor({ material = M.Glass, transparency = 0.45, collide = false, shadow = false }))
		end
	end
	ctx.reserve(at.X, at.Y, 13)
end

local function plaza(ctx)
	local c = ctx.at(PLAZA.X, PLAZA.Y)
	Cyl(1, PLAZA_R * 2 + 5, Color3.fromRGB(176, 164, 146), Vector3.new(c.X, 7.05, c.Z), { material = M.Cobblestone })
	Cyl(1, PLAZA_R * 2, Color3.fromRGB(226, 210, 178), Vector3.new(c.X, 7.1, c.Z), { material = M.Cobblestone })
	-- decorative rings around the fountain
	Cyl(1, 36, Color3.fromRGB(200, 186, 160), Vector3.new(c.X, 7.13, c.Z), { material = M.Cobblestone, collide = false })
	Cyl(1, 33, Color3.fromRGB(232, 218, 190), Vector3.new(c.X, 7.16, c.Z), { material = M.Cobblestone, collide = false })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		P(Vector3.new(0.8, 0.2, PLAZA_R - 20), Color3.fromRGB(200, 186, 160), CFrame.new(Vector3.new(c.X + math.cos(a) * (PLAZA_R / 2 + 9), 7.68, c.Z + math.sin(a) * (PLAZA_R / 2 + 9))) * CFrame.Angles(0, -a + math.pi / 2, 0), decor({ material = M.Cobblestone, collide = false, shadow = false }))
	end
	fountain(ctx, PLAZA)
	-- benches facing the fountain, flower planters, lamps on the rim
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = PLAZA.X + math.cos(a) * 19, PLAZA.Y + math.sin(a) * 19
		Kit.Bench(L.YawToward(ctx.at(x, z), c))
		local fx, fz = PLAZA.X + math.cos(a + 0.28) * 21, PLAZA.Y + math.sin(a + 0.28) * 21
		Cyl(1.6, 4, STONE, ctx.at(fx, fz) + Vector3.new(0, 0.8, 0), { material = M.Cobblestone })
		Kit.Bush(ctx.at(fx, fz) + Vector3.new(0, 1.4, 0), 2.6, Color3.fromRGB(90, 180, 80))
		Kit.Flowers(ctx.at(fx, fz) + Vector3.new(0, 1.2, 0), 1.6, 6)
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		Kit.Lamp(ctx.at(PLAZA.X + math.cos(a) * (PLAZA_R - 3), PLAZA.Y + math.sin(a) * (PLAZA_R - 3)))
	end
	-- bunting from the fountain top to the lamps
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 8
		local lamp = ctx.at(PLAZA.X + math.cos(a) * (PLAZA_R - 3), PLAZA.Y + math.sin(a) * (PLAZA_R - 3)) + Vector3.new(0, 8.5, 0)
		Kit.Bunting(c + Vector3.new(0, 14.6, 0), lamp)
	end
	ctx.reserve(PLAZA.X, PLAZA.Y, PLAZA_R - 2)
end

-- paved street ring between the plaza and the house fronts (blocks alternate 0.05 in height: they overlap a
-- little on the inner side and must never share a surface)
local function streetRing(ctx)
	local c = ctx.at(PLAZA.X, PLAZA.Y)
	local n = 56
	local depth = STREET_OUT - STREET_IN
	local w = 2 * math.pi * STREET_OUT / n + 0.6
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = c + dir * (STREET_IN + depth / 2)
		local y = 7.43 + (i % 2) * 0.05
		P(Vector3.new(w, 0.3, depth), Color3.fromRGB(206, 194, 170):Lerp(Color3.fromRGB(190, 178, 156), (i % 3) / 3), CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + dir), { material = M.Cobblestone, shadow = false, name = "Path" })
	end
	-- a darker kerb along the outer edge
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = c + dir * (STREET_OUT + 0.4)
		local y = 7.5 + (i % 2) * 0.05
		P(Vector3.new(w, 0.3, 0.8), Color3.fromRGB(150, 140, 126), CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + dir), decor({ material = M.Cobblestone, collide = false, shadow = false }))
	end
end

-- paving from a house's door out to the street (dir2 = from the house toward the plaza)
local function doorApron(ctx, front, dir2, width)
	local plazaDist = (front - PLAZA).Magnitude
	local len = math.max(0.5, plazaDist - STREET_OUT + 0.6)
	local mid2 = front + dir2 * (len / 2 - 0.3)
	local mid = ctx.at(mid2.X, mid2.Y)
	local y = 7.56
	P(Vector3.new(width, 0.3, len), Color3.fromRGB(200, 188, 164), CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X + dir2.X, y, mid.Z + dir2.Y)), decor({ material = M.Cobblestone, collide = false, shadow = false }))
end

-- the Sunrise Tavern's porch: a plank deck, posts, a striped awning, lanterns and a hanging tankard sign
local function tavernPorch(ctx, front, dir2, w)
	local f = ctx.at(front.X, front.Y)
	local d3 = Vector3.new(dir2.X, 0, dir2.Y)
	local cf = CFrame.lookAt(f, f + d3) -- -Z = toward the plaza
	local depth = 7
	P(Vector3.new(w - 4, 0.6, depth), Color3.fromRGB(176, 124, 78), cf * CFrame.new(0, 0.3, -depth / 2), { material = M.WoodPlanks })
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(0.7, 9.6, 0.7), C.DarkWood, cf * CFrame.new(sx * (w / 2 - 2.6), 5.1, -depth + 0.4), { material = M.Wood })
		-- lantern on each post
		local lamp = P(Vector3.new(0.9, 1.2, 0.9), Color3.fromRGB(255, 210, 110), cf * CFrame.new(sx * (w / 2 - 2.6), 6.2, -depth - 0.2), decor({ material = M.Neon, collide = false }))
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Parent = lamp
	end
	-- striped awning sloping down toward the street, ABOVE the doorway (v0.25.141: it crossed the open door at y 8)
	for k = 0, 5 do
		local stripe = (w - 3) / 6
		Wedge(Vector3.new(stripe, 3, depth + 1), k % 2 == 0 and Color3.fromRGB(196, 52, 46) or Color3.fromRGB(250, 240, 220),
			cf * CFrame.new(-(w - 3) / 2 + stripe * (k + 0.5), 10.4, -depth / 2) * CFrame.Angles(0, math.pi, 0), decor({ material = M.Plaster, collide = false }))
	end
	-- hanging sign: an iron arm off the right post with a board and a big tankard on it
	local arm = cf * CFrame.new(w / 2 - 2.6, 7.6, -depth - 0.2)
	P(Vector3.new(0.3, 0.3, 4), C.DarkWood, arm * CFrame.new(0, 0, -2), decor({ material = M.Metal, collide = false }))
	P(Vector3.new(0.25, 2.6, 3.2), Color3.fromRGB(150, 98, 58), arm * CFrame.new(0, -1.9, -3), decor({ material = M.Wood, collide = false }))
	local mug = arm * CFrame.new(0, -1.9, -3)
	Cyl(1.8, 1.5, Color3.fromRGB(240, 196, 70), (mug * CFrame.new(0.5, 0, 0)).Position, decor({ material = M.Metal, collide = false }))
	P(Vector3.new(0.3, 1.1, 0.3), Color3.fromRGB(240, 196, 70), mug * CFrame.new(0.5, 0, 1.05), decor({ material = M.Metal, collide = false }))
	P(Vector3.new(1.4, 0.35, 1.4), Color3.fromRGB(255, 252, 240), mug * CFrame.new(0.5, 0.95, 0), decor({ collide = false }))
	-- barrels and a bench by the door
	Kit.Barrel(f + d3 * 2 + cf.RightVector * (w / 2 - 1))
	Kit.Barrel(f + d3 * 3.5 + cf.RightVector * (w / 2 - 1.4))
end

-- v0.25.140 (owner reference clip): the important plaza buildings are bigger and ENTERABLE, their NPC inside
-- (Kit.House opts.hollow -> Kit.Interior). angle on the plaza ring -> size + interior + sign
local RING = 66
local HALLS = {
	[-0.62] = { w = 28, d = 20, floors = 2, hollow = "tavern", sign = "SUNRISE TAVERN", signLift = 2.6 }, -- sign above the porch awning
	[1.35] = { w = 24, d = 18, floors = 1, hollow = "smithy", sign = "BLACKSMITH" },
	[-1.18] = { w = 24, d = 18, floors = 1, hollow = "shop", sign = "GENERAL STORE" },
}
local function hallSpot(ctx, a)
	-- where the NPC stands inside the hall at ring angle a (local x, z) + its floor lift above the fixed NPC ground
	local h = HALLS[a]
	local r = RING + Kit.InteriorSpot(h.d)
	local x, z = PLAZA.X + math.cos(a) * r, PLAZA.Y + math.sin(a) * r
	return Vector2.new(x, z), ctx.at(PLAZA.X + math.cos(a) * RING, PLAZA.Y + math.sin(a) * RING).Y + 1.4 - 7.6
end

local function houses(ctx)
	-- ring around the plaza; gaps for the trail (west), the harbor street (east), the meadow lane (south) and
	-- the lighthouse lane (north-east)
	local ring = RING
	local angles = { 0.55, 1.35, 1.8, 2.3, 2.62, -2.62, -2.3, -1.85, -1.18, -0.62 }
	for i, a in ipairs(angles) do
		local x, z = PLAZA.X + math.cos(a) * ring, PLAZA.Y + math.sin(a) * ring
		local w, d = rng:NextNumber(15, 20), rng:NextNumber(12, 14)
		local opts = { floors = (i % 3 == 0) and 1 or 2 }
		local hall = HALLS[a]
		if hall then
			w, d = hall.w, hall.d
			opts = { floors = hall.floors, sign = hall.sign, hollow = hall.hollow, floorHeight = 11, signLift = hall.signLift }
		end
		timberHouse(ctx, x, z, w, d, opts, PLAZA)
		local dir2 = (PLAZA - Vector2.new(x, z)).Unit
		local front = Vector2.new(x, z) + dir2 * (d / 2)
		if opts.sign == "SUNRISE TAVERN" then
			tavernPorch(ctx, front, dir2, w)
			doorApron(ctx, front + dir2 * 7, dir2, 10)
		else
			doorApron(ctx, front, dir2, 6)
		end
		-- garden props by the doors
		local door = Vector2.new(x, z) + (PLAZA - Vector2.new(x, z)).Unit * (d / 2 + 4)
		local side = Vector2.new(-(PLAZA - Vector2.new(x, z)).Unit.Y, (PLAZA - Vector2.new(x, z)).Unit.X)
		local px = door + side * (w / 2 - 1)
		if ctx.free(px.X, px.Y, 1.5) then
			if i % 2 == 0 then
				Kit.Barrel(ctx.at(px.X, px.Y))
			else
				Kit.Flowers(ctx.at(px.X, px.Y), 1.8, 5)
			end
		end
	end
	-- houses lining the harbor street down to the quay
	for _, x in ipairs({ 128, 152, 176, 200 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local z = sz * rng:NextNumber(23, 26)
			if ctx.free(x, z, 9) then
				timberHouse(ctx, x, z, rng:NextNumber(13, 17), rng:NextNumber(11, 13), { floors = rng:NextNumber() > 0.4 and 2 or 1 }, Vector2.new(x, 0))
			end
		end
	end
	-- an outer row behind the ring (village depth, like the concept's stacked roofs)
	for _, a in ipairs({ 0.95, 1.25, 1.6, 2.05, -1.55, -2.05, -0.95, -1.25, 0.6, -0.6 }) do
		local x, z = PLAZA.X + math.cos(a) * 98, PLAZA.Y + math.sin(a) * 98
		if ctx.free(x, z, 10) then
			timberHouse(ctx, x, z, rng:NextNumber(13, 17), rng:NextNumber(11, 13), { floors = 1 }, PLAZA)
		end
	end
end

-- A grassy ramp from a hilltop down to the ground (owner, v0.23.0: instead of stone stairs): the walkable slope is
-- grass, its sides are rock (a slightly wider rock wedge under it + cliff slabs along both sides that shrink toward
-- the foot), and bushes sit at the bottom corners.
local RAMP_SLOPE = math.rad(27)
local function grassRamp(ctx, x, z, r, topY, a, width)
	width = width or 14
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local g = ctx.g
	local h = topY - g
	local run = h / math.tan(RAMP_SLOPE)
	local into = 4 -- tucked into the hill so the top edge meets the grass cap
	local len = run + into
	local c = Vector3.new(ctx.c.X + x, 0, z)
	local midXZ = c + dir * (r - into + len / 2)
	local slopeTop = h * (len / run) -- the wedge keeps rising inside the hill
	local mid = Vector3.new(midXZ.X, g + slopeTop / 2, midXZ.Z)
	-- WedgePart: high end at +Z, so -Z (LookVector) points down the slope, outward
	local cf = CFrame.lookAt(mid, mid + dir)
	Wedge(Vector3.new(width, slopeTop, len), ctx.pal.grass, cf, { material = M.Grass })
	Wedge(Vector3.new(width + 1.8, slopeTop, len), ROCK:Lerp(Color3.fromRGB(150, 120, 96), 0.3), cf * CFrame.new(0, -0.7, -0.4), { material = M.Rock })
	local right = dir:Cross(Vector3.yAxis)
	for _, side in ipairs({ -1, 1 }) do
		local k = 0
		local t = 0.08
		while t < 0.95 do
			k += 1
			local along = (r - 1) + run * t
			local hh = math.max(1.5, h * (1 - t) + 1.2)
			local at = c + dir * along + right * side * (width / 2 + 1.2) + Vector3.new(0, g + hh / 2 - 0.8, 0)
			local tone = rng:NextNumber() > 0.45 and ROCK or Color3.fromRGB(150, 120, 96)
			local slab = P(Vector3.new(4.5, hh, run / 5 + 1.5), tone, CFrame.lookAt(at, at + right * side) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.12, 0.12), 0), { material = M.Rock, collide = false })
			slab:SetAttribute("Kind", "Cliff" .. Kit.RockTone(tone))
			CollectionService:AddTag(slab, "EnvPart")
			t += 0.2
		end
		Kit.Bush(c + dir * (r + run + 1) + right * side * (width / 2 + 2) + Vector3.new(0, g, 0), rng:NextNumber(3, 4.2), Color3.fromRGB(96, 186, 80))
	end
	-- keep trees and props off the ramp
	for k = 0, 4 do
		local p = Vector3.new(x, 0, z) + dir * (r + run * k / 4)
		ctx.reserve(p.X, p.Z, width / 2 + 3)
	end
	return run
end

local function lighthouse(ctx)
	local top = L.Mesa(ctx, LIGHTHOUSE.X, LIGHTHOUSE.Y, 20, 8, nil, nil)
	grassRamp(ctx, LIGHTHOUSE.X, LIGHTHOUSE.Y, 20, top, -2.15, 12)
	local base = Vector3.new(ctx.c.X + LIGHTHOUSE.X, top, LIGHTHOUSE.Y)
	local s = 1.25
	local white, band = Color3.fromRGB(250, 246, 236), Color3.fromRGB(150, 84, 52)
	-- stone plinth
	Cyl(3 * s, 15 * s, STONE, base + Vector3.new(0, 1.5 * s, 0), { material = M.Cobblestone })
	local y = 3 * s
	for i = 0, 5 do
		local dia = (12 - i * 0.8) * s
		Cyl(7 * s, dia, white, base + Vector3.new(0, y + 3.5 * s, 0), { material = M.Plaster })
		Cyl(1 * s, dia + 0.5, band, base + Vector3.new(0, y + 7 * s, 0), decor({ material = M.Wood }))
		if i % 2 == 1 then
			P(Vector3.new(1.6, 2.6, 0.4) * s, Color3.fromRGB(80, 110, 140), CFrame.new(base + Vector3.new(0, y + 3.5 * s, 0)) * CFrame.Angles(0, i * 1.1, 0) * CFrame.new(0, 0, -dia / 2), decor({ material = M.Glass }))
		end
		y += 7 * s
	end
	-- gallery with railing
	Cyl(0.8 * s, 12 * s, band, base + Vector3.new(0, y + 0.4 * s, 0), { material = M.Wood })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		P(Vector3.new(0.3, 2.2, 0.3) * s, C.DarkWood, CFrame.new(base + Vector3.new(math.cos(a) * 5.6 * s, y + 1.9 * s, math.sin(a) * 5.6 * s)), decor())
	end
	-- lantern room + roof
	local lamp = Cyl(4.4 * s, 6 * s, Color3.fromRGB(255, 236, 150), base + Vector3.new(0, y + 3 * s, 0), decor({ material = M.Neon }))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		P(Vector3.new(0.35, 4.4, 0.35) * s, Color3.fromRGB(60, 50, 44), CFrame.new(base + Vector3.new(math.cos(a) * 3.1 * s, y + 3 * s, math.sin(a) * 3.1 * s)), decor())
	end
	for i = 0, 3 do
		Cyl(1.1 * s, (8 - i * 1.9) * s, ROOFS[1], base + Vector3.new(0, y + (5.8 + i * 1.1) * s, 0), {})
	end
	Ball(1.2 * s, Color3.fromRGB(255, 210, 80), base + Vector3.new(0, y + 10.4 * s, 0), decor())
	local light = Instance.new("SpotLight")
	light.Range = 60
	light.Brightness = 3
	light.Face = Enum.NormalId.Right
	light.Parent = lamp
	local glow = Instance.new("PointLight")
	glow.Range = 24
	glow.Brightness = 1.5
	glow.Color = Color3.fromRGB(255, 220, 140)
	glow.Parent = lamp
	CollectionService:AddTag(glow, "TownLight")
	ctx.reserve(LIGHTHOUSE.X, LIGHTHOUSE.Y, 22)
	-- keeper's cottage below the rock, on the lane
	timberHouse(ctx, 112, 150, 11, 9, { floors = 1 }, PLAZA)
	return top
end

local function windmill(ctx, x, z, scale)
	Kit.Windmill(ctx.at(x, z), scale, Color3.fromRGB(240, 222, 180))
	ctx.reserve(x, z, 8 * scale)
end

-- soften a hill's foot: grassy mounds and bushes that hide the sharp edge where the cliff meets the ground, plus a
-- few extra rock outcrops so the cliff ring is not a perfect cylinder (v0.22.9 concept review)
local function blendHill(ctx, x, z, r, stairs)
	local n = math.floor(2 * math.pi * r / 8)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local nearStairs = false
		for _, sa in ipairs(stairs or {}) do
			if math.abs(math.atan2(math.sin(a - sa), math.cos(a - sa))) < 0.4 then
				nearStairs = true
			end
		end
		local d = r + rng:NextNumber(1, 3.5)
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		for _, pp in ipairs(pathPts) do
			if (pp.p - Vector2.new(px, pz)).Magnitude < pp.r + 5 then
				nearStairs = true -- (a trail runs here: keep its edge clean)
				break
			end
		end
		if not nearStairs then
			local g = ctx.at(px, pz)
			local size = rng:NextNumber(7, 11)
			Ball(size, ctx.pal.grass:Lerp(Color3.fromRGB(60, 140, 50), rng:NextNumber(0, 0.25)), g - Vector3.new(0, size * 0.32, 0), { material = M.Grass, shadow = false })
			if i % 3 == 0 then
				Kit.Bush(g + Vector3.new(math.cos(a) * 2, 0, math.sin(a) * 2), rng:NextNumber(3, 4.5), Color3.fromRGB(96, 186, 80))
			elseif i % 4 == 1 then
				-- an outcrop leaning out of the cliff face
				local hh = rng:NextNumber(5, 9)
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local at = ctx.at(x + math.cos(a) * (r - 0.5), z + math.sin(a) * (r - 0.5)) + Vector3.new(0, hh / 2 - 0.5, 0)
				local tone = rng:NextNumber() > 0.4 and ROCK or Color3.fromRGB(150, 120, 96)
				local slab = P(Vector3.new(rng:NextNumber(6, 9), hh, rng:NextNumber(4, 6)), tone, CFrame.lookAt(at, at + dir) * CFrame.Angles(rng:NextNumber(-0.25, 0.1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.15, 0.15)), { material = M.Rock })
				slab:SetAttribute("Kind", "Cliff" .. Kit.RockTone(tone))
				CollectionService:AddTag(slab, "EnvPart")
			end
		end
	end
end

local function hills(ctx)
	local N, S, E = -math.pi / 2, math.pi / 2, 0
	-- North Windmill Hill: the big mill, Captain's Chest on top
	grassRamp(ctx, NORTH_HILL.X, NORTH_HILL.Y, 32, L.Mesa(ctx, NORTH_HILL.X, NORTH_HILL.Y, 32, 11, nil, nil), N)
	table.insert(ctx.blendLater, { NORTH_HILL.X, NORTH_HILL.Y, 32, { N } })
	windmill(ctx, NORTH_HILL.X - 4, NORTH_HILL.Y + 4, 1.45)
	Kit.Fence(ctx.at(NORTH_HILL.X - 22, NORTH_HILL.Y - 8), ctx.at(NORTH_HILL.X - 8, NORTH_HILL.Y - 22))
	ctx.reserve(NORTH_HILL.X, NORTH_HILL.Y, 34)
	-- lower terrace with the small mill, between the village and the trail
	grassRamp(ctx, TERRACE.X, TERRACE.Y, 18, L.Mesa(ctx, TERRACE.X, TERRACE.Y, 18, 6, nil, nil), E, 12)
	table.insert(ctx.blendLater, { TERRACE.X, TERRACE.Y, 18, { E } })
	windmill(ctx, TERRACE.X - 3, TERRACE.Y + 2, 1.0)
	ctx.reserve(TERRACE.X, TERRACE.Y, 22)
	-- Bandit Hill: the bandits took this windmill; their camp sits on the hilltop
	grassRamp(ctx, BANDIT_HILL.X, BANDIT_HILL.Y, 36, L.Mesa(ctx, BANDIT_HILL.X, BANDIT_HILL.Y, 36, 13, nil, nil), S)
	table.insert(ctx.blendLater, { BANDIT_HILL.X, BANDIT_HILL.Y, 36, { S } })
	local mill = BANDIT_HILL + Vector2.new(-17, -15)
	windmill(ctx, mill.X, mill.Y, 1.15)
	ctx.reserve(BANDIT_HILL.X, BANDIT_HILL.Y, 38)
end

local function banditCamp(ctx, zone)
	local c = ctx.at(zone.X, zone.Y)
	local function tent(off, yaw, color)
		local cf = CFrame.new(c + Vector3.new(off.X, 0, off.Y)) * CFrame.Angles(0, yaw, 0)
		for _, side in ipairs({ -1, 1 }) do
			Wedge(Vector3.new(6, 4.5, 3), color, cf * CFrame.new(0, 2.25, side * 1.5) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), decor({ material = M.Fabric, collide = false }))
		end
	end
	-- tents and junk sit on the rim of the zone; the middle stays open for the fights
	tent(Vector2.new(19, 6), 0.6, Color3.fromRGB(150, 110, 80))
	tent(Vector2.new(4, 20), 2.1, Color3.fromRGB(120, 100, 70))
	Kit.Junk(c + Vector3.new(-14, 0, 14), 5)
	Kit.Flag(c + Vector3.new(16, 0, -10), Color3.fromRGB(40, 40, 44), 12, true)
	local fire = c + Vector3.new(0, 0, 0)
	for i = 0, 3 do
		P(Vector3.new(0.9, 0.9, 4), C.DarkWood, CFrame.new(fire + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i * math.pi / 4, 0), decor({ material = M.Wood, collide = false }))
	end
	local flame = Ball(1.6, Color3.fromRGB(255, 150, 50), fire + Vector3.new(0, 1.4, 0), decor({ material = M.Neon, collide = false, transparency = 0.2 }))
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 6
	f.Parent = flame
end

local function camp(ctx)
	local c = ctx.at(CAMP.X, CAMP.Y)
	-- clearing: lighter grass, worn into the jungle
	Cyl(0.3, 64, Color3.fromRGB(128, 206, 92), Vector3.new(c.X, 7.62, c.Z), { material = M.Grass, collide = false })
	-- campfire with log seats
	local fire = c + Vector3.new(-6, 0, -4)
	Cyl(0.6, 6, Color3.fromRGB(120, 116, 110), fire + Vector3.new(0, 0.3, 0), { material = M.Slate })
	for i = 0, 4 do
		P(Vector3.new(0.9, 0.9, 4), C.DarkWood, CFrame.new(fire + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, i * math.pi / 5, 0.25), decor({ material = M.Wood, collide = false }))
	end
	local flame = Ball(1.8, Color3.fromRGB(255, 160, 60), fire + Vector3.new(0, 1.8, 0), decor({ material = M.Neon, collide = false, transparency = 0.15 }))
	local f = Instance.new("Fire")
	f.Size = 5
	f.Heat = 8
	f.Parent = flame
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 180, 100)
	light.Parent = flame
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.6
		local p = fire + Vector3.new(math.cos(a) * 6, 0.7, math.sin(a) * 6)
		local log = P(Vector3.new(4.5, 1.4, 1.4), C.Trunk, CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), { material = M.Wood })
		log.Shape = Enum.PartType.Cylinder
	end
	-- Rowan's tent, crates and a washed-up rowboat
	local tcf = CFrame.lookAt(c + Vector3.new(-18, 0, -14), fire)
	for _, side in ipairs({ -1, 1 }) do
		Wedge(Vector3.new(9, 6, 4.5), Color3.fromRGB(226, 206, 160), tcf * CFrame.new(0, 3, side * 2.25) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), { material = M.Fabric })
	end
	Kit.CrateStack(c + Vector3.new(-22, 0, 4))
	Kit.Rowboat(CFrame.new(c + Vector3.new(-26, 0.2, 16)) * CFrame.Angles(0, 0.8, 0.15))
	Kit.Lamp(c + Vector3.new(4, 0, -16))
	-- giants around the clearing
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2 + 0.25
		local x, z = CAMP.X + math.cos(a) * 42, CAMP.Y + math.sin(a) * 42
		if ctx.free(x, z, 7) then
			giantTree(ctx, x, z, rng:NextNumber(2.1, 2.6))
		end
	end
	-- close the clearing with jungle all round, except the three trail mouths (v0.22.9 concept review)
	local mouths = { math.atan2(6, 14), math.atan2(18, 4), math.atan2(-16, 4) }
	local a = 0
	while a < math.pi * 2 do
		local open = false
		for _, m in ipairs(mouths) do
			local da = math.abs(math.atan2(math.sin(a - m), math.cos(a - m)))
			if da < 0.32 then
				open = true
			end
		end
		if not open then
			local rr = rng:NextNumber(34, 40)
			local x, z = CAMP.X + math.cos(a) * rr, CAMP.Y + math.sin(a) * rr
			if ctx.free(x, z, 3) then
				if rng:NextNumber() < 0.35 then
					Kit.Palm(ctx.at(x, z), rng:NextNumber(13, 17))
				else
					Kit.RoundTree(ctx.at(x, z), rng:NextNumber(1.1, 1.5), Color3.fromRGB(70, 168, 66))
				end
				Kit.Bush(ctx.at(x + math.cos(a) * -4, z + math.sin(a) * -4), rng:NextNumber(3, 4.5), Color3.fromRGB(84, 170, 70))
			end
		end
		a += 0.24
	end
	-- two lanterns flank the main trail's mouth: the way to the village
	local m = mouths[1]
	for _, side in ipairs({ -1, 1 }) do
		local aa = m + side * 0.2
		Kit.Lamp(ctx.at(CAMP.X + math.cos(aa) * 30, CAMP.Y + math.sin(aa) * 30))
	end
	ctx.reserve(CAMP.X, CAMP.Y, 30)
end

local function monkeyGrove(ctx, zone, r)
	-- fruit-laden trees and hanging ropes around the grove (outside the fighting zone)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = zone.X + math.cos(a) * (r + 9), zone.Y + math.sin(a) * (r + 9)
		if ctx.free(x, z, 5) then
			Kit.RoundTree(ctx.at(x, z), rng:NextNumber(1.4, 1.8), Color3.fromRGB(80, 180, 70), Color3.fromRGB(255, 214, 60))
			ctx.reserve(x, z, 4)
		end
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local p = ctx.at(zone.X + math.cos(a) * (r + 3), zone.Y + math.sin(a) * (r + 3))
		Kit.Plant("Flowers", p, 1.5, Color3.fromRGB(255, 220, 70))
		Kit.Plant("Flowers", p + Vector3.new(0.9, 0, 0.5), 1.2, Color3.fromRGB(250, 200, 60))
	end
end

local function tigerDen(ctx, zone, r)
	-- a ring of big mossy stones with a gap facing the camp trail
	local toCamp = (CAMP - zone).Unit
	for i = 0, 10 do
		local a = i / 11 * math.pi * 2
		local d = r + rng:NextNumber(4, 8)
		local dir = Vector2.new(math.cos(a), math.sin(a))
		if dir:Dot(toCamp) < 0.85 then
			local p = zone + dir * d
			Kit.Rock(ctx.at(p.X, p.Y) + Vector3.new(0, 2, 0), rng:NextNumber(6, 11), Color3.fromRGB(120, 130, 110))
			ctx.reserve(p.X, p.Y, 5)
		end
	end
	-- claw-marked log and bones as flavour
	local c = ctx.at(zone.X, zone.Y)
	local log = P(Vector3.new(10, 2, 2), C.Trunk, CFrame.new(c + Vector3.new(r + 2, 1, -6)) * CFrame.Angles(0, 0.7, 0), { material = M.Wood })
	log.Shape = Enum.PartType.Cylinder
	for i = 1, 4 do
		P(Vector3.new(2.2, 0.4, 0.4), Color3.fromRGB(240, 236, 220), CFrame.new(c + Vector3.new(-r - 3 + i, 0.3, 8 + i * 0.7)) * CFrame.Angles(0, i, 0), decor({ collide = false }))
	end
end

local function meadow(ctx, zone, r)
	-- open grass for the boars, a fenced farm next to it (crop rows) and hay bales
	local f = ctx.at(FIELDS.X, FIELDS.Y)
	for row = 0, 6 do
		local base = f + Vector3.new(-15 + row * 5, 0, 0)
		P(Vector3.new(3, 0.8, 26), Color3.fromRGB(130, 90, 60), CFrame.new(base + Vector3.new(0, 0.35, 0)), decor({ material = M.Ground }))
		for k = 0, 6 do
			Kit.Plant(row % 2 == 0 and "LeafPlant" or "Flowers", base + Vector3.new(0, 0.75, -11 + k * 3.7), row % 2 == 0 and 2.2 or 1.6, row % 2 == 0 and Color3.fromRGB(140, 220, 90) or Color3.fromRGB(255, 205, 80))
		end
	end
	Kit.Fence(f + Vector3.new(-19, 0, -15), f + Vector3.new(19, 0, -15))
	Kit.Fence(f + Vector3.new(-19, 0, 15), f + Vector3.new(19, 0, 15))
	Kit.Fence(f + Vector3.new(19, 0, -15), f + Vector3.new(19, 0, 15))
	ctx.reserve(FIELDS.X, FIELDS.Y, 22)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		local p = ctx.at(zone.X + math.cos(a) * (r + 6), zone.Y + math.sin(a) * (r + 6))
		-- cylinder axis = X: a hay bale lying on its side
		P(Vector3.new(3, 3.2, 3.2), Color3.fromRGB(230, 196, 110), CFrame.new(p + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, a, 0), { material = M.Fabric, shape = Enum.PartType.Cylinder })
	end
	Kit.Fence(ctx.at(zone.X - r - 4, zone.Y + r + 2), ctx.at(zone.X + r + 4, zone.Y + r + 2))
end

-- ===== coast =====
local function base(ctx)
	local c, r, pal = ctx.c, ctx.r, ctx.pal
	-- shallow turquoise lagoon all around, sand shelf below (v0.22.9: deeper and darker; the pale one read as white
	-- water between the docks under the glassy sea surface)
	-- v0.25.134 (owner): organic voxel outline instead of discs (World/IslandShape)
	require(script.Parent.IslandShape).Build(ctx.island, c, r, Kit.parent, pal)
	-- jungle floor: deeper green over the west half (thin, walk-through; plants still grow on it)
	for _, j in ipairs({ { -150, 0, 95 }, { -110, 130, 70 }, { -110, -135, 70 }, { -60, 0, 50 } }) do
		Cyl(0.25, j[3] * 2, Color3.fromRGB(92, 176, 72), Vector3.new(c.X + j[1], 7.56, j[2]), { material = M.Grass, collide = false, shadow = false })
	end
	-- rocky shore: a ring of cliff slabs (-> stylized rock meshes) except along the harbor
	local circ = 2 * math.pi * (r - 7)
	local n = math.ceil(circ / 12)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local rel = math.atan2(math.sin(a), math.cos(a))
		if math.abs(rel) > HARBOR_ARC + 0.02 then
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local _ = dir
			rng:NextNumber(12, 17)
			rng:NextNumber(-1.5, 2)
			rng:NextNumber()
			rng:NextNumber(-0.15, 0.15) -- v0.25.134: round cliff ring gone (IslandShape has cliffs), draws kept
		end
	end
	-- rocks in the surf (the harbor mouth stays clear for ships)
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rel = math.atan2(math.sin(a), math.cos(a))
		if math.abs(rel) > HARBOR_ARC + 0.15 then
			local d = r + rng:NextNumber(2, 16)
			Kit.RockCluster(c + Vector3.new(math.cos(a) * d, rng:NextNumber(0, 2), math.sin(a) * d), rng:NextNumber(4, 9))
		end
	end
end

local function harbor(ctx)
	local c, r = ctx.c, ctx.r
	-- stone quay: a band of cobblestone between QUAY_IN and the sea wall along the harbor arc
	local seg = 0.04
	local a = -HARBOR_ARC
	local k = 0
	while a < HARBOR_ARC - 0.001 do
		k += 1
		-- neighbouring blocks overlap a little: every other one sits 0.12 higher / further out (no z-fighting flicker)
		local alt = (k % 2) * 0.12
		local am = a + seg / 2
		local dir = Vector3.new(math.cos(am), 0, math.sin(am))
		local depth = r - QUAY_IN
		local w = r * seg + 1.2
		local mid = c + dir * (QUAY_IN + depth / 2)
		P(Vector3.new(w, 2.4, depth), Color3.fromRGB(204, 192, 172), CFrame.lookAt(mid + Vector3.new(0, 6.4 + alt, 0), mid + Vector3.new(0, 6.4 + alt, 0) + dir), { material = M.Cobblestone })
		-- sea wall face
		local wall = c + dir * (r + 0.5 + alt)
		P(Vector3.new(w, 15, 3), Color3.fromRGB(168, 160, 150), CFrame.lookAt(wall + Vector3.new(0, 0.1, 0), wall + Vector3.new(0, 0.1, 0) + dir), { material = M.Slate })
		local nearDock = false
		for _, dz in ipairs(DOCK_Z) do
			if math.abs(wall.Z - dz) < 10 then
				nearDock = true
			end
		end
		if not nearDock then
			P(Vector3.new(w, 0.8, 3.6), Color3.fromRGB(214, 204, 186), CFrame.lookAt(wall + Vector3.new(0, 7.9 + alt, 0), wall + Vector3.new(0, 7.9 + alt, 0) + dir), decor({ material = M.Cobblestone }))
		end
		a += seg
	end
	-- bollards along the wall
	for k = -5, 5 do
		local aa = k / 5 * (HARBOR_ARC - 0.05)
		local p = c + Vector3.new(math.cos(aa), 0, math.sin(aa)) * (r - 1.5) + Vector3.new(0, 7.6, 0)
		local skip = false
		for _, dz in ipairs(DOCK_Z) do
			if math.abs(p.Z - dz) < 12 then
				skip = true
			end
		end
		if not skip then
			Cyl(1.8, 1.6, Color3.fromRGB(60, 60, 66), p + Vector3.new(0, 0.9, 0), decor({ material = M.Metal }))
		end
	end
	ctx.reserve(r - 20, 0, 30)
end

-- one wooden dock reaching east from the quay; the launch dock is tagged "Dock" (sailing, landing, quests)
local function dock(ctx, z, len, launch)
	local island = ctx.island
	local x0 = ctx.c.X + math.sqrt(ctx.r * ctx.r - z * z) - 2
	local y = 6.9
	local wood = Color3.fromRGB(190, 135, 85)
	for i = 0, math.floor(len / 10) - 1 do
		P(Vector3.new(10 - 0.3, 1, 14), wood:Lerp(Color3.fromRGB(160, 110, 70), i % 2), CFrame.new(x0 + (i + 0.5) * 10, y, z), { material = M.WoodPlanks })
	end
	for i = 0, math.floor(len / 15) do
		for _, sz in ipairs({ -7, 7 }) do
			Cyl(17, 1.6, Color3.fromRGB(120, 80, 50), Vector3.new(x0 + i * 15, -1, z + sz), { material = M.Wood })
			Cyl(1.4, 2.1, C.Rope, Vector3.new(x0 + i * 15, 7.9, z + sz), decor({ material = M.Fabric }))
		end
	end
	local tip = Vector3.new(x0 + len, y, z)
	Kit.Lamp(Vector3.new(tip.X - 3, y + 0.5, z + 6))
	if launch then
		local marker = P(Vector3.new(4, 1, 4), Color3.new(1, 1, 1), CFrame.new(tip + Vector3.new(-6, 0.6, 0)), { transparency = 1, collide = false, name = "DockMarker" })
		marker:SetAttribute("Island", island.id)
		marker:SetAttribute("Side", 1)
		marker:SetAttribute("LaunchCf", CFrame.new(Vector3.new(tip.X + 60, GameConfig.SeaLevel - GameConfig.Ship.GridSize * 0.5, z)) * CFrame.Angles(0, -math.pi / 2, 0))
		marker:SetAttribute("LandCf", CFrame.new(Vector3.new(x0 + 10, y + 4, z)))
		CollectionService:AddTag(marker, "Dock")
		for _, sz in ipairs({ -22, 22 }) do
			Ball(4, Color3.fromRGB(255, 80, 70), tip + Vector3.new(30, -6, sz), {})
			Ball(1.4, Color3.fromRGB(255, 240, 160), tip + Vector3.new(30, -3.6, sz), { material = M.Neon, decor = true, collide = false })
		end
		-- v0.25.109 (owner): no island name sign (the name shows on screen when you arrive: Controllers/IslandEnter)
	else
		-- moored rowboats and a little sailboat along the side docks
		Kit.Rowboat(CFrame.new(x0 + len * 0.45, 0.3, z + (z > 0 and 11 or -11)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(196, 130, 80))
		Kit.Rowboat(CFrame.new(x0 + len * 0.8, 0.3, z + (z > 0 and -11 or 11)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 150, 210))
	end
	Kit.CrateStack(Vector3.new(x0 + 5, y + 0.5, z + 4))
	return x0
end

local function sailboat(cf)
	P(Vector3.new(5, 2.2, 16), Color3.fromRGB(150, 96, 58), cf * CFrame.new(0, 0.8, 0), decor({ material = M.WoodPlanks }))
	Wedge(Vector3.new(5, 2.2, 4), Color3.fromRGB(150, 96, 58), cf * CFrame.new(0, 0.8, -10) * CFrame.Angles(0, math.pi, math.pi), decor())
	P(Vector3.new(5.2, 0.4, 16.4), C.White, cf * CFrame.new(0, 2, 0), decor({ collide = false }))
	P(Vector3.new(0.5, 16, 0.5), C.DarkWood, cf * CFrame.new(0, 10, -1), decor())
	Wedge(Vector3.new(0.2, 13, 8), Color3.fromRGB(250, 244, 226), cf * CFrame.new(0, 9.5, 3.2), decor({ material = M.Fabric, collide = false }))
end

local function harborDetails(ctx)
	local c = ctx.c
	-- stalls and cargo along the quay
	for i, z in ipairs({ -26, -14, 14, 26 }) do
		local x = 232
		Kit.Stall(CFrame.lookAt(Vector3.new(c.X + x, 7.6, z), Vector3.new(c.X + x - 10, 7.6, z)), ({ Color3.fromRGB(230, 80, 70), Color3.fromRGB(70, 150, 220), Color3.fromRGB(250, 190, 60), Color3.fromRGB(110, 190, 100) })[i])
	end
	for _, p in ipairs({ { 240, -64 }, { 240, 62 }, { 226, 78 }, { 232, -84 } }) do
		Kit.CrateStack(Vector3.new(c.X + p[1], 7.6, p[2]))
	end
	for _, p in ipairs({ { 238, 20 }, { 238, -20 }, { 236, 34 } }) do
		Kit.Barrel(Vector3.new(c.X + p[1], 7.6, p[2]))
	end
	sailboat(CFrame.new(c.X + 300, 0.2, 21) * CFrame.Angles(0, math.pi / 2, 0))
	-- small boats moored beside the outer piers (the middle launch dock stays clear)
	sailboat(CFrame.new(c.X + 282, 0.2, 54) * CFrame.Angles(0, math.pi / 2, 0))
	Kit.Rowboat(CFrame.new(c.X + 268, 0.3, -56) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(200, 90, 70))
	-- steps from the shipyard platform (top 5) up to the quay (top 7.6), where the quay meets the platform
	local qx = math.sqrt((ctx.r + 0.5) ^ 2 - 64 ^ 2)
	Kit.Stairs(Vector3.new(c.X + qx + 4.8, 5, -64), Vector3.new(-1, 0, 0), 2.6, 8)
end

local function harborStreet(ctx)
	-- cobbled street from the plaza to the quay
	local x0, x1 = PLAZA.X + STREET_OUT, QUAY_IN + 0.5
	local mid = ctx.at((x0 + x1) / 2, 0)
	P(Vector3.new(x1 - x0, 0.3, 16), Color3.fromRGB(214, 200, 174), CFrame.new(mid + Vector3.new(0, 0.12, 0)), { material = M.Cobblestone, shadow = false, name = "Path" })
	P(Vector3.new(x1 - x0, 0.24, 19), Color3.fromRGB(176, 164, 146), CFrame.new(mid + Vector3.new(0, 0.06, 0)), { material = M.Cobblestone, shadow = false, collide = false })
	for x = x0 + 12, x1 - 6, 24 do
		for _, sz in ipairs({ -11, 11 }) do
			Kit.Lamp(ctx.at(x, sz))
		end
	end
	for x = x0, x1, 2 do
		ctx.reserve(x, 0, 10)
	end
end

-- ===== NPCs =====
local function npcs(ctx, api)
	local function put(role, title, color, hat, at, extra, face)
		api.npc(ctx, role, title, color, hat, at.X, at.Y, extra, face)
	end
	local P0 = PLAZA
	local function onPlaza(a, d)
		return P0 + Vector2.new(math.cos(a), math.sin(a)) * (d or 29)
	end
	-- jungle camp: the tutorial guide by the fire
	put("Guide", Quests.Guide.Daybreak or "Guide", Color3.fromRGB(255, 200, 90), "captain", CAMP + Vector2.new(-2, -14), { SubTitle = "📜 Quests" }, SPAWN)
	-- plaza: Job Master and the Bounty Board at the trail entrance, shops around the fountain
	put("JobMaster", "Job Master", Color3.fromRGB(142, 28, 42), "master", onPlaza(2.75), { SubTitle = "Choose a Class" }, P0)
	local bb = onPlaza(-2.7, 50)
	put("BossBoard", "Bounty Board", Color3.fromRGB(255, 220, 120), nil, bb, { SubTitle = "Bosses & Bounties" }, P0) -- v0.25.119 (owner): by the small house at the west street
	-- v0.25.120 (owner): the TOP 50 POWER board stands on the NPC's left, in front of the house (off the trail), and is
	-- part of the map so it shows in Studio Edit; Controllers/PowerBoard puts the list on its "Board" part
	do
		local f = (P0 - bb).Unit
		local spot = bb + Vector2.new(f.Y, -f.X) * 9.5
		local g = ctx.at(spot.X, spot.Y)
		local base = CFrame.lookAt(g, g + Vector3.new(f.X, 0, f.Y))
		local model = Instance.new("Model")
		model.Name = "PowerBoard"
		model.Parent = Kit.parent
		CollectionService:AddTag(model, "PowerBoard")
		local W, H = 13, 16
		local wood = Color3.fromRGB(92, 60, 36)
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(0.6, H + 2.2, 0.6), wood, base * CFrame.new(sx * (W / 2 + 0.2), (H + 2.2) / 2, 0.25), { material = M.Wood, parent = model })
		end
		P(Vector3.new(W, H, 0.4), Color3.fromRGB(60, 40, 28), base * CFrame.new(0, 1.6 + H / 2, 0), { material = M.WoodPlanks, parent = model, name = "Board" })
		P(Vector3.new(W + 0.6, 0.5, 0.7), Color3.fromRGB(140, 30, 40), base * CFrame.new(0, 1.6 + H + 0.2, 0), { material = M.Wood, parent = model })
		P(Vector3.new(W + 0.4, 0.3, 0.6), wood, base * CFrame.new(0, 1.45, 0), { material = M.Wood, parent = model })
		model.PrimaryPart = model:FindFirstChild("Board")
	end
	-- v0.25.140: the shopkeepers stand inside their buildings (behind the counter / at the anvil), the barkeep too
	local spot, lift = hallSpot(ctx, -1.18)
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, spot, { SubTitle = "Shop", Lift = lift }, P0)
	spot, lift = hallSpot(ctx, 1.35)
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", spot, { SubTitle = "Refine & Cards", Lift = lift }, P0)
	spot, lift = hallSpot(ctx, -0.62)
	put("Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, spot, { SubTitle = "Hire Crew", Lift = lift }, P0)
	-- harbor: shipwright by the shipyard, courier gulls by the north dock
	put("Shipwright", "Shipwright", Color3.fromRGB(90, 140, 200), "bandana", Vector2.new(230, -58), { SubTitle = "Shipyard & Launch" }, Vector2.new(150, -40))
	put("Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, Vector2.new(230, -42), { SubTitle = "Hire Crew" }, Vector2.new(150, -40)) -- v0.25.107: beside the Shipwright
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", Vector2.new(228, 50), { SubTitle = "Fast Travel" }, PLAZA)
	-- post with a gull on it
	local post = ctx.at(228, 56)
	P(Vector3.new(1, 6, 1), C.DarkWood, CFrame.new(post + Vector3.new(0, 3, 0)), { material = M.Wood })
	Ball(1.6, C.White, post + Vector3.new(0, 6.8, 0), decor())
	Wedge(Vector3.new(0.4, 0.5, 1), Color3.fromRGB(255, 180, 60), CFrame.new(post + Vector3.new(0, 6.8, -1.1)), decor())
end

-- ===== chests (explicit spots: hilltops, the lighthouse rock, the jungle) =====
local function chests(ctx, api, lightTop)
	local island = ctx.island
	local n = 0
	local rand = Random.new(4242)
	local function put(tier, x, z, y)
		n += 1
		local pos = y and Vector3.new(ctx.c.X + x, y, z) or ctx.at(x, z)
		api.chest(island.id .. "_" .. n, tier, island, pos, rand:NextNumber(0, math.pi * 2))
		ctx.reserve(x, z, 4)
	end
	put("Captain", NORTH_HILL.X + 13, NORTH_HILL.Y - 11)
	put("Golden", LIGHTHOUSE.X + 10, LIGHTHOUSE.Y - 6, lightTop)
	put("Silver", BANDIT_HILL.X - 22, BANDIT_HILL.Y + 6)
	put("Silver", -186, -124)
	put("Wooden", -96, 200)
	put("Wooden", -100, -196)
	put("Wooden", -192, 118)
end

-- ===== build =====
function D.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	local ctx = api.makeCtx(island, c, r, 7.5)
	ctx.foam = api.foam
	base(ctx)
	harbor(ctx)

	-- 1. terrain: hills and the lighthouse rock, then the trails
	ctx.blendLater = {}
	pathCount, pathPts = 0, {}
	hills(ctx)
	local lightTop = lighthouse(ctx)
	local spawnsByMonster = {}
	for _, sp in ipairs(island.spawns) do
		spawnsByMonster[sp.monster] = sp
	end
	local trail = path(ctx, { CAMP + v2(14, 6), v2(-132, 18), v2(-108, 34), v2(-82, 22), v2(-58, -2), v2(-30, -18), v2(-4, -10), PLAZA - v2(PLAZA_R - 2, 0) }, 11)
	-- side trails into the groves stay narrow: the wide main trail is the obvious way to the village
	path(ctx, { CAMP + v2(4, 18), v2(-160, 42), v2(-152, 60) }, 6)
	path(ctx, { CAMP + v2(4, -16), v2(-160, -40), v2(-150, -66) }, 6)
	path(ctx, { v2(-30, -18), v2(-34, -36), v2(-35, -46) }, 8)
	local meadowLane = path(ctx, { PLAZA - v2(0, PLAZA_R - 2), v2(64, -72), v2(72, -110), v2(75, -122) }, 9)
	local lightLane = path(ctx, { PLAZA + v2(26, 29), v2(100, 80), v2(118, 118), v2(130, 142) }, 8)
	path(ctx, { PLAZA + Vector2.new(math.cos(2.05), math.sin(2.05)) * (PLAZA_R - 2), v2(28, 60), v2(17, 66) }, 7)
	harborStreet(ctx)

	-- 2. buildings and landmarks
	plaza(ctx)
	streetRing(ctx)
	for _, h in ipairs(ctx.blendLater) do
		blendHill(ctx, h[1], h[2], h[3], h[4])
	end
	houses(ctx)
	camp(ctx)
	local bandits = spawnsByMonster.MountainBandit
	if bandits then
		banditCamp(ctx, bandits.offset)
	end
	for _, z in ipairs(DOCK_Z) do
		dock(ctx, z, z == 0 and 90 or 62, z == 0)
	end
	api.shipyard(island)
	harborDetails(ctx)
	npcs(ctx, api)

	-- monster zones stay open ground (ctx reserved them); dress their surroundings
	local monkeys, tigers, boars = spawnsByMonster.ForestMonkey, spawnsByMonster.JungleTiger, spawnsByMonster.WildBoar
	if monkeys then
		monkeyGrove(ctx, monkeys.offset, monkeys.radius)
	end
	if tigers then
		tigerDen(ctx, tigers.offset, tigers.radius)
	end
	if boars then
		meadow(ctx, boars.offset, boars.radius)
	end

	-- 3. vegetation: the jungle in the west, a ring of trees around the island, palms on the rocky shore
	jungle(ctx, v2(-150, 0), 95, 70, 7)
	jungle(ctx, v2(-120, 140), 80, 34, 7)
	jungle(ctx, v2(-120, -140), 80, 34, 7)
	jungle(ctx, v2(-70, 10), 40, 10, 7)
	-- woods around the rest of the island (the concept is green to the shore)
	jungle(ctx, v2(105, -195), 45, 16, 8)
	jungle(ctx, v2(-15, -190), 40, 14, 8)
	jungle(ctx, v2(40, 175), 55, 22, 8)
	jungle(ctx, v2(120, 95), 30, 8, 8)
	jungle(ctx, v2(175, -150), 30, 8, 8)
	jungle(ctx, v2(-40, 195), 35, 10, 8)
	for _, g in ipairs({ { -200, 60, 2.5 }, { -205, -55, 2.4 }, { -105, 70, 2.2 }, { -95, -60, 2.3 }, { -190, -160, 2.2 }, { -175, 165, 2.3 } }) do
		if ctx.free(g[1], g[2], 8) then
			giantTree(ctx, g[1], g[2], g[3])
		end
	end
	-- village greenery: round trees between houses, behind the village and on the hills
	L.Scatter(ctx, 26, 60, r - 26, function(pos, x)
		if x > -60 then
			Kit.RoundTree(pos, rng:NextNumber(0.9, 1.3), Color3.fromRGB(96, 196, 84))
		end
	end, 7)
	L.Scatter(ctx, 30, 40, r - 22, function(pos)
		Kit.Bush(pos, rng:NextNumber(3, 4.5), Color3.fromRGB(110, 200, 90))
	end, 3)
	L.Scatter(ctx, 40, 20, r - 20, function(pos)
		Kit.Flowers(pos, 2.5, 6)
	end, 2)
	for i = 1, 30 do
		local a = i / 30 * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local rel = math.atan2(math.sin(a), math.cos(a))
		local d = r - rng:NextNumber(16, 24)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if math.abs(rel) > HARBOR_ARC + 0.1 and ctx.free(x, z, 3) then
			Kit.Palm(ctx.at(x, z) - Vector3.new(0, 0.5, 0), rng:NextNumber(17, 24))
			ctx.reserve(x, z, 3)
		end
	end

	-- 4. lighting and details: lamps on the trails (no direction signs: owner, v0.22.5)
	lampsAlong(ctx, trail, 7, 8)
	lampsAlong(ctx, meadowLane, 6, 6.5)
	lampsAlong(ctx, lightLane, 6, 6.5)
	Kit.Flag(ctx.at(BANDIT_HILL.X + 4, BANDIT_HILL.Y + 30), Color3.fromRGB(40, 40, 44), 10, true)

	-- spawn point in the camp clearing (players start and respawn here)
	-- facing down the main trail toward the village roofs (players spawn looking that way)
	local sp = ctx.at(SPAWN.X, SPAWN.Y) + Vector3.new(0, 0.2, 0)
	local toward = ctx.at(CAMP.X - 2, CAMP.Y - 14) -- face Rowan
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.lookAt(sp, Vector3.new(toward.X, sp.Y, toward.Z)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")

	chests(ctx, api, lightTop)
	api.banner(island, c)
	Kit.parent = prev
	return f
end

D.Places = { Camp = CAMP, Spawn = SPAWN, Plaza = PLAZA, BanditHill = BANDIT_HILL, NorthHill = NORTH_HILL, Terrace = TERRACE, Lighthouse = LIGHTHOUSE, Fields = FIELDS }

return D
