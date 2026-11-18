-- IslandLayouts: per-island set dressing built from Kit props.
-- Each theme gets (ctx) with: island, c (center at sea level), r (radius), g (ground height),
-- pal (palette), at(x, z) -> world pos on the ground, free(x, z, radius) -> bool, reserve(x, z, radius).
local Kit = require(script.Parent.Kit)

local L = {}
local C = Kit.Colors
local P, Cyl, Ball, Wedge = Kit.P, Kit.Cyl, Kit.Ball, Kit.Wedge
local M = Enum.Material
local rng = Kit.rng

local function yawToward(from, to)
	return CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
end

-- Place a house facing a point; the door (-Z) faces `face`
local function houseAt(ctx, x, z, w, d, wall, roof, opts, face)
	local pos = ctx.at(x, z)
	local target = face or ctx.at(0, 0)
	local cf = yawToward(pos, target)
	ctx.reserve(x, z, math.max(w, d) * 0.7)
	return Kit.House(cf, w, d, wall, roof, opts)
end

-- Ring of houses around the plaza, skipping reserved spots
function L.HouseRing(ctx, radius, count, wall, roofs, opts, startAngle)
	for i = 0, count - 1 do
		local a = (startAngle or 0.35) + i / count * math.pi * 2
		local x, z = math.cos(a) * radius, math.sin(a) * radius
		local w, d = rng:NextNumber(13, 19), rng:NextNumber(11, 14)
		if math.abs(math.cos(a)) < 0.9 and ctx.free(x, z, w * 0.7) then
			local o = table.clone(opts or {})
			o.floors = o.floors or (rng:NextNumber() > 0.6 and 2 or 1)
			houseAt(ctx, x, z, w, d, wall, roofs[i % #roofs + 1], o)
		end
	end
end

-- Scatter decor across free ground
function L.Scatter(ctx, count, minR, maxR, fn, clearance)
	local placed = 0
	for _ = 1, count * 4 do
		if placed >= count then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minR, maxR)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if ctx.free(x, z, clearance or 4) then
			fn(ctx.at(x, z), x, z)
			ctx.reserve(x, z, (clearance or 4) * 0.6)
			placed += 1
		end
	end
end

-- Dirt paths from the plaza to both docks + grass tufts everywhere (readable, never empty fields)
function L.Paths(ctx)
	local tr = ctx.island.townRadius
	if ctx.island.floating then
		return
	end
	for _, side in ipairs({ 1, -1 }) do
		local x0, x1 = side * (tr - 2), side * (ctx.r - 22)
		local len = math.abs(x1 - x0)
		local mid = ctx.at((x0 + x1) / 2, 0)
		P(Vector3.new(len, 0.3, 11), Color3.fromRGB(214, 180, 128), CFrame.new(mid + Vector3.new(0, 0.05, 0)), { material = M.Ground, shadow = false })
		for i = 0, math.floor(len / 9) do
			local x = x0 + side * i * 9
			Kit.Rock(ctx.at(x, 6.6 + rng:NextNumber(-0.4, 0.4)) + Vector3.new(0, 0.2, 0), 1.6, Color3.fromRGB(190, 186, 176)).CanCollide = false
		end
	end
	for _ = 1, 140 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(tr + 6, ctx.r - 16)
		local pos = ctx.at(math.cos(a) * d, math.sin(a) * d)
		local col = ctx.pal.grass:Lerp(Color3.fromRGB(60, 150, 50), rng:NextNumber(0.1, 0.4))
		for k = 0, 2 do
			Wedge(Vector3.new(0.3, 1.6, 0.9), col, CFrame.new(pos + Vector3.new(k * 0.5 - 0.5, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Kit.decor({ collide = false, shadow = false, material = M.Grass }))
		end
		if rng:NextNumber() > 0.75 then
			Kit.Flowers(pos, 2, 3)
		end
	end
end

function L.Plaza(ctx, withFountain)
	local tr = ctx.island.townRadius
	if withFountain ~= false then
		local c = ctx.at(0, 0)
		Cyl(2.4, 18, C.Stone, c + Vector3.new(0, 1.2, 0), { material = M.Cobblestone })
		Cyl(0.6, 15.5, Color3.fromRGB(90, 200, 255), c + Vector3.new(0, 2.2, 0), { material = M.Glass, transparency = 0.2, collide = false })
		Cyl(6, 3, C.Stone, c + Vector3.new(0, 4, 0), { material = M.Marble })
		Cyl(1, 7, C.Stone, c + Vector3.new(0, 7.2, 0), { material = M.Marble })
		Ball(2.4, Color3.fromRGB(150, 220, 255), c + Vector3.new(0, 8.6, 0), Kit.decor({ material = M.Glass, transparency = 0.3, collide = false }))
		ctx.reserve(0, 0, 11)
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.15
		local x, z = math.cos(a) * (tr - 5), math.sin(a) * (tr - 5)
		if ctx.free(x, z, 2) then
			Kit.Lamp(ctx.at(x, z))
		end
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.8
		local x, z = math.cos(a) * 20, math.sin(a) * 20
		if ctx.free(x, z, 3) then
			Kit.Bench(yawToward(ctx.at(x, z), ctx.at(0, 0)))
		end
	end
end

function L.Coast(ctx, palms)
	local r = ctx.r
	for i = 1, palms or 26 do
		local a = i / (palms or 26) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local d = r - rng:NextNumber(8, 20)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if math.cos(a) < 0.85 and math.cos(a) > -0.92 and ctx.free(x, z, 3) then
			Kit.Palm(ctx.at(x, z) - Vector3.new(0, 3.2, 0))
		end
	end
	for i = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		if math.cos(a) < 0.8 then
			Kit.RockCluster(ctx.c + Vector3.new(math.cos(a) * (r + 4), 1.5, math.sin(a) * (r + 4)), rng:NextNumber(5, 10))
		end
	end
end

function L.Greenery(ctx, trees, tint, fruit)
	L.Scatter(ctx, trees, ctx.island.townRadius + 30, ctx.r - 30, function(pos)
		if rng:NextNumber() > 0.4 then
			Kit.RoundTree(pos, rng:NextNumber(0.85, 1.3), tint, fruit)
		else
			Kit.PineTree(pos, rng:NextNumber(0.9, 1.4))
		end
	end, 7)
	L.Scatter(ctx, trees, ctx.island.townRadius + 8, ctx.r - 20, function(pos)
		Kit.Bush(pos, rng:NextNumber(3, 5))
	end, 3)
	L.Scatter(ctx, trees, 20, ctx.r - 25, function(pos)
		Kit.Flowers(pos, 3, 7)
	end, 2)
end

-- ===================== Themes =====================
-- ===================== Tiers (layer-cake mesas) =====================
-- spec: { x, z, r, h, stairs = { angles }, cap = { dx, dz, r, h, stairs = { angles } }, top = "trees" | "flowers" | nil }
local ROCK = Color3.fromRGB(184, 104, 84)
function L.Mesa(ctx, x, z, r, h, stairs, top)
	local base = ctx.at(x, z)
	local topY = Kit.Mesa(base, r, h, ctx.pal.grass, ctx.pal.rock or ROCK, ctx.pal.accent)
	table.insert(ctx.mesas, { x = x, z = z, r = r, top = topY })
	for _, a in ipairs(stairs or {}) do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local run = math.ceil((topY - base.Y) / 1.25) * 2.3
		local foot = Vector3.new(ctx.c.X + x, base.Y, z) + dir * (r + 1 + run)
		Kit.Stairs(foot, -dir, topY - base.Y, 10)
		local mid = Vector3.new(x, 0, z) + dir * (r + run / 2)
		ctx.reserve(mid.X, mid.Z, run / 2 + 5)
	end
	if top == "trees" then
		for i = 1, math.max(2, math.floor(r / 9)) do
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, r * 0.6)
			Kit.RoundTree(ctx.at(x + math.cos(a) * d, z + math.sin(a) * d), rng:NextNumber(0.8, 1.2))
		end
	elseif top == "flowers" then
		Kit.Flowers(ctx.at(x, z), r * 0.6, math.floor(r))
		Kit.Bush(ctx.at(x + r * 0.3, z), 4)
	end
	return topY
end

function L.Tiers(ctx, specs)
	for _, t in ipairs(specs or {}) do
		if ctx.free(t.x, t.z, t.r * 0.9) or t.force then
			L.Mesa(ctx, t.x, t.z, t.r, t.h, t.stairs, not t.cap and t.top or nil)
			if t.cap then
				L.Mesa(ctx, t.x + (t.cap.dx or 0), t.z + (t.cap.dz or 0), t.cap.r, t.cap.h, t.cap.stairs, t.top)
			end
			ctx.reserve(t.x, t.z, t.r + 2)
		end
	end
end

-- Ring of cliff mesas around the island rim (skips the dock side and anything reserved)
function L.Ridge(ctx)
	if ctx.island.floating then
		return
	end
	local a = 0.75
	local k = 0
	while a < 2 * math.pi - 0.75 do
		local rr = rng:NextNumber(20, 30)
		local d = ctx.r - rr - rng:NextNumber(6, 14)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if ctx.free(x, z, rr * 0.85) then
			k += 1
			local h = rng:NextNumber(9, 20)
			local toCenter = math.atan2(-z, -x)
			local stairs = (k % 3 == 1) and { toCenter + math.pi } or nil
			-- stairs face the island center: the foot is on the inner side
			if stairs then
				stairs = { math.atan2(z, x) + math.pi }
			end
			L.Mesa(ctx, x, z, rr, h, stairs, (k % 2 == 0) and "trees" or nil)
			if k % 3 == 0 then
				L.Mesa(ctx, x + math.cos(a) * rr * 0.25, z + math.sin(a) * rr * 0.25, rr * 0.5, rng:NextNumber(6, 10), nil, "trees")
			end
			ctx.reserve(x, z, rr + 2)
			a += (rr * 2.1) / d
		else
			a += 0.12
		end
	end
end

-- stairs angle = direction from the mesa toward the stair foot (use the side facing the island center)
local E, W, N, S = 0, math.pi, -math.pi / 2, math.pi / 2
L.TierSpecs = {
	Windmill = {
		{ x = -150, z = 0, r = 56, h = 12, stairs = { E, W }, cap = { dx = -12, dz = 0, r = 28, h = 9, stairs = { E } }, force = true },
		{ x = -10, z = -192, r = 28, h = 10, stairs = { S }, top = "trees" },
		{ x = 30, z = 200, r = 26, h = 12, stairs = { N }, cap = { dx = 0, dz = 4, r = 14, h = 7 }, top = "trees" },
	},
	MarineOutpost = {
		{ x = -150, z = 0, r = 68, h = 9, stairs = { E, W }, force = true },
		{ x = 50, z = 205, r = 28, h = 14, stairs = { N }, cap = { dx = 0, dz = 4, r = 14, h = 8 }, top = "flowers" },
	},
	CircusTown = {
		{ x = -150, z = 0, r = 44, h = 8, stairs = { E, W }, force = true },
		{ x = 0, z = -200, r = 30, h = 12, stairs = { S }, cap = { dx = 0, dz = -4, r = 16, h = 8 }, top = "trees" },
		{ x = 20, z = 200, r = 24, h = 9, stairs = { N }, top = "flowers" },
	},
	SlopeVillage = {
		{ x = -165, z = 0, r = 76, h = 18, stairs = { E }, cap = { dx = -24, dz = 0, r = 36, h = 8, stairs = { E } }, force = true },
		{ x = 40, z = -205, r = 26, h = 10, stairs = { S }, top = "trees" },
	},
	SawtoothPark = {
		{ x = -165, z = 0, r = 70, h = 8, stairs = { E, W }, force = true },
		{ x = 90, z = 60, r = 28, h = 6, stairs = { W }, force = true },
		{ x = 50, z = -150, r = 28, h = 5, stairs = { S }, force = true },
		{ x = -20, z = 150, r = 26, h = 7, stairs = { N }, force = true },
	},
	HarborCity = {
		{ x = 230, z = -60, r = 30, h = 16, stairs = { W }, force = true },
		{ x = -60, z = -100, r = 18, h = 8, stairs = { S }, force = true },
		{ x = 70, z = 105, r = 26, h = 6, stairs = { N }, force = true },
	},
}

local Themes = {}

-- Daybreak Island: windmill village, farms, pine forest, scrapyard
function Themes.Windmill(ctx)
	local pal = ctx.pal
	Kit.Windmill(ctx.at(-150, 0), 1.45, pal.accent)
	ctx.reserve(-150, 0, 14)
	Kit.Windmill(ctx.at(-195, -55), 0.9, Color3.fromRGB(255, 220, 120))
	ctx.reserve(-195, -55, 9)
	Kit.Windmill(ctx.at(-190, 60), 0.85, Color3.fromRGB(140, 200, 255))
	ctx.reserve(-190, 60, 9)
	-- crop fields
	for row = 0, 5 do
		local x = -160 + row * 5
		local base = ctx.at(x, -40)
		P(Vector3.new(3, 1, 24), Color3.fromRGB(130, 90, 60), CFrame.new(base + Vector3.new(0, 0.4, 0)), Kit.decor({ material = M.Ground }))
		for k = 0, 5 do
			Kit.Plant(row % 2 == 0 and "LeafPlant" or "Flowers", base + Vector3.new(0, 0.9, -10 + k * 4), row % 2 == 0 and 2.2 or 1.6, row % 2 == 0 and Color3.fromRGB(140, 220, 90) or Color3.fromRGB(255, 210, 90))
		end
	end
	Kit.Fence(ctx.at(-164, -54), ctx.at(-130, -54))
	Kit.Fence(ctx.at(-164, -26), ctx.at(-130, -26))
	ctx.reserve(-147, -40, 18)
	-- tavern
	houseAt(ctx, 0, -ctx.island.townRadius - 18, 24, 16, pal.wall, pal.accent, { floors = 2, sign = "SUNRISE TAVERN" })
	L.HouseRing(ctx, ctx.island.townRadius + 16, 11, pal.wall, { pal.accent, Color3.fromRGB(90, 150, 220), Color3.fromRGB(240, 170, 60) })
	-- pine forest around the monkey grove
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local x, z = 115 + math.cos(a) * 52, 120 + math.sin(a) * 52
		if ctx.free(x, z, 4) and math.sqrt(x * x + z * z) < ctx.r - 25 then
			Kit.PineTree(ctx.at(x, z), rng:NextNumber(1, 1.5))
		end
	end
	-- Grey Scrapyard by the bandit camp
	Kit.Junk(ctx.at(25, -195), 14)
	Kit.Junk(ctx.at(120, -185), 12)
	Kit.PostSign("GREY SCRAPYARD", ctx.at(20, -168), Vector3.new(0, 0, 1), 12)
	L.Greenery(ctx, 14)
	L.Coast(ctx)
end

-- Conch Bay: walled marine outpost, axe-captain statue tower, training yard
function Themes.MarineOutpost(ctx)
	local pal = ctx.pal
	local white, blue = Color3.fromRGB(245, 247, 252), C.Marine
	local cx, cz = -150, 0
	local half = 44
	for i = 0, 3 do
		local a = i * math.pi / 2
		local cf = CFrame.new(ctx.at(cx, cz)) * CFrame.Angles(0, a, 0)
		if i == 0 then
			-- east wall with gate gap
			for _, s in ipairs({ -1, 1 }) do
				P(Vector3.new(4, 12, half - 7), white, cf * CFrame.new(half, 6, s * (half / 2 + 3.5)), { material = M.Brick })
			end
			P(Vector3.new(5, 4, 16), blue, cf * CFrame.new(half, 13, 0), {})
			Kit.Sign("MARINE OUTPOST 135", cf * CFrame.new(half + 2.6, 14, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector2.new(15, 3), Color3.new(1, 1, 1), blue)
		else
			P(Vector3.new(4, 12, half * 2), white, cf * CFrame.new(half, 6, 0), { material = M.Brick })
		end
		P(Vector3.new(4.6, 1.2, half * 2), blue, cf * CFrame.new(half, 12.4, 0), Kit.decor())
		Kit.Tower(ctx.at(cx, cz) + (cf * CFrame.new(half, 0, half)).Position - ctx.at(cx, cz), 9, 18, white, blue, { band = blue })
	end
	ctx.reserve(cx, cz, half + 6)
	Kit.Tower(ctx.at(cx - 10, cz), 24, 46, white, nil, { band = blue })
	Kit.Sign("MARINE", CFrame.new(ctx.at(cx - 10, cz) + Vector3.new(12.4, 32, 0)) * CFrame.Angles(0, -math.pi / 2, 0), Vector2.new(14, 4), blue, white)
	Kit.Statue(ctx.at(cx - 10, cz) + Vector3.new(0, 46, 0), 1.6, Color3.fromRGB(235, 228, 214), "axe")
	-- training yard posts
	for i = 0, 2 do
		local p = ctx.at(cx + 18, cz - 20 + i * 20)
		P(Vector3.new(1, 8, 1), C.Wood, CFrame.new(p + Vector3.new(0, 4, 0)), { material = M.Wood })
		P(Vector3.new(6, 0.8, 0.8), C.Wood, CFrame.new(p + Vector3.new(0, 6.5, 0)), { material = M.Wood })
	end
	Kit.Flag(ctx.at(cx + half + 6, cz - 12), blue, 16, true)
	Kit.Flag(ctx.at(cx + half + 6, cz + 12), blue, 16, true)
	for _, p in ipairs({ { cx + 30, cz + 30 }, { cx + 30, cz - 30 } }) do
		Kit.CrateStack(ctx.at(p[1], p[2]))
	end
	houseAt(ctx, 0, ctx.island.townRadius + 18, 22, 15, pal.wall, blue, { floors = 2, sign = "FOOD SHACK" })
	L.HouseRing(ctx, ctx.island.townRadius + 16, 11, pal.wall, { blue, Color3.fromRGB(120, 170, 230), Color3.fromRGB(80, 100, 150) }, { stone = C.DarkStone })
	L.Greenery(ctx, 10)
	L.Coast(ctx)
end

-- Marmalade Town: orange roofs, empty streets, big-top pub, giant dog statue
function Themes.CircusTown(ctx)
	local pal = ctx.pal
	local hq = ctx.at(-150, 0)
	local hqCf = yawToward(hq, ctx.at(0, 0))
	local top = Kit.House(hqCf, 32, 26, Color3.fromRGB(250, 226, 190), Color3.fromRGB(200, 70, 60), { floors = 2, sign = "BIG TOP PUB" })
	Kit.CircusTent(hq + Vector3.new(0, top - 4, 0), 0.62)
	Cyl(6, 3.4, Color3.fromRGB(50, 50, 56), hq + Vector3.new(6, top + 2, -8), { material = M.Metal })
	ctx.reserve(-150, 0, 26)
	-- giant dog statue guarding the pet shop
	local dog = ctx.at(34, -30)
	P(Vector3.new(4, 2, 7), C.DarkStone, CFrame.new(dog + Vector3.new(0, 1, 0)), { material = M.Slate })
	P(Vector3.new(4.5, 4.5, 7), C.White, CFrame.new(dog + Vector3.new(0, 4.2, 0)), { material = M.Marble })
	Ball(5, C.White, dog + Vector3.new(0, 8, -3), { material = M.Marble })
	for _, s in ipairs({ -1, 1 }) do
		Wedge(Vector3.new(0.8, 2.6, 1.6), Color3.fromRGB(200, 196, 190), CFrame.new(dog + Vector3.new(s * 1.8, 10.6, -3)), Kit.decor())
	end
	ctx.reserve(34, -30, 7)
	houseAt(ctx, 45, -52, 16, 12, pal.wall, pal.accent, { sign = "PET FOOD" }, dog)
	-- two rings of orange roofs = streets
	local roofs = { pal.accent, Color3.fromRGB(255, 170, 70), Color3.fromRGB(230, 110, 40) }
	L.HouseRing(ctx, ctx.island.townRadius + 14, 13, pal.wall, roofs)
	L.HouseRing(ctx, ctx.island.townRadius + 44, 15, pal.wall, roofs, { chimney = false }, 0.1)
	-- rubble from the cannon blast
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * 70, math.sin(a) * 70
		if ctx.free(x, z, 5) then
			Kit.Junk(ctx.at(x, z), 6)
		end
	end
	-- bunting across the plaza
	local tr = ctx.island.townRadius - 5
	for i = 0, 4 do
		local a1, a2 = i / 5 * math.pi * 2 + 0.15, (i + 2) / 5 * math.pi * 2 + 0.15
		Kit.Bunting(ctx.at(math.cos(a1) * tr, math.sin(a1) * tr) + Vector3.new(0, 9, 0), ctx.at(math.cos(a2) * tr, math.sin(a2) * tr) + Vector3.new(0, 9, 0))
	end
	L.Scatter(ctx, 10, 20, ctx.island.townRadius, function(pos)
		Kit.CrateStack(pos)
	end, 5)
	L.Greenery(ctx, 9, Color3.fromRGB(140, 200, 80))
	L.Coast(ctx)
end

-- Honeyslope Village: hilltop mansion, the long slope, sheep, north cliffs, lookout tree
function Themes.SlopeVillage(ctx)
	local pal = ctx.pal
	-- hilltop manor sits on the top tier (built by L.Tiers)
	local top = ctx.at(-189, 0)
	local mansion = CFrame.lookAt(top, top + Vector3.new(100, 0, 0))
	Kit.House(mansion, 34, 24, Color3.fromRGB(252, 248, 240), Color3.fromRGB(150, 90, 200), { floors = 2, sign = "HILLTOP MANOR", floorHeight = 10 })
	local lower = ctx.at(-120, 0)
	for _, sgn in ipairs({ -1, 1 }) do
		P(Vector3.new(3, 10, 3), C.Stone, CFrame.new(lower + Vector3.new(30, 5, sgn * 9)), { material = M.Marble })
		Ball(3, Color3.fromRGB(255, 220, 90), lower + Vector3.new(30, 11, sgn * 9), Kit.decor())
		for k = 0, 4 do
			Kit.Bush(ctx.at(-150 + k * 9, sgn * 40), 4, Color3.fromRGB(70, 170, 90))
		end
	end
	Kit.Flowers(lower, 14, 24)
	-- sheep pen
	local pen = ctx.at(-70, -90)
	Kit.Fence(pen + Vector3.new(-14, 0, -9), pen + Vector3.new(14, 0, -9))
	Kit.Fence(pen + Vector3.new(14, 0, -9), pen + Vector3.new(14, 0, 9))
	Kit.Fence(pen + Vector3.new(14, 0, 9), pen + Vector3.new(-14, 0, 9))
	Kit.Fence(pen + Vector3.new(-14, 0, 9), pen + Vector3.new(-14, 0, -9))
	for i = 1, 4 do
		local sp = pen + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-5, 5))
		Ball(4, Color3.fromRGB(250, 250, 245), sp + Vector3.new(0, 2.6, 0), Kit.decor({ material = M.Fabric }))
		Ball(1.8, Color3.fromRGB(60, 50, 50), sp + Vector3.new(2, 3, 0), Kit.decor())
	end
	ctx.reserve(-70, -90, 17)
	-- lookout tree
	Kit.RoundTree(ctx.at(60, 175), 2.2, Color3.fromRGB(90, 180, 80))
	ctx.reserve(60, 175, 14)
	-- north cliffs
	for i = 0, 16 do
		local a = math.pi * 1.1 + i / 16 * math.pi * 0.8
		local d = ctx.r - 6
		local h = rng:NextNumber(14, 26)
		P(Vector3.new(rng:NextNumber(16, 26), h, 10), pal.dirt:Lerp(C.DarkStone, 0.5), CFrame.new(ctx.c + Vector3.new(math.cos(a) * d, h / 2 - 2, math.sin(a) * d)) * CFrame.Angles(0, -a, 0), { material = M.Rock })
	end
	L.HouseRing(ctx, ctx.island.townRadius + 16, 10, pal.wall, { pal.accent, Color3.fromRGB(110, 170, 230), Color3.fromRGB(230, 120, 90) })
	L.Greenery(ctx, 14)
	L.Coast(ctx, 18)
end

-- Barracuda Bistro: fish-shaped floating restaurant
function Themes.FloatingRestaurant(ctx)
	local pal = ctx.pal
	local g = ctx.g
	local c = ctx.c
	-- fish head (west) and tail fins (east)
	Ball(110, Color3.fromRGB(245, 168, 90), c + Vector3.new(-ctx.r - 18, 2, 0), { material = M.SmoothPlastic })
	Ball(70, Color3.fromRGB(255, 225, 170), c + Vector3.new(-ctx.r - 44, -6, 0), Kit.decor())
	for _, s in ipairs({ -1, 1 }) do
		Ball(18, Color3.new(1, 1, 1), c + Vector3.new(-ctx.r - 40, 26, s * 30), Kit.decor())
		Ball(9, Color3.fromRGB(30, 30, 40), c + Vector3.new(-ctx.r - 47, 27, s * 32), Kit.decor())
		-- tail lobes: vertical fins standing above the east dock
		Wedge(Vector3.new(3, 34, 44), Color3.fromRGB(240, 110, 80), CFrame.new(c + Vector3.new(ctx.r + 10, g + 10 + 17 * (s + 1) / 2 + (s < 0 and 0 or 10), 0)) * CFrame.Angles(0, math.pi / 2, s < 0 and math.pi or 0), {})
		-- battle fins (side platforms)
		Wedge(Vector3.new(60, 4, 50), Color3.fromRGB(200, 140, 90), CFrame.new(c + Vector3.new(-20, g - 2, s * (ctx.r + 18))) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), { material = M.WoodPlanks })
	end
	-- restaurant
	local rest = ctx.at(-118, 0)
	local cf = yawToward(rest, ctx.at(0, 0))
	local top = Kit.House(cf, 40, 30, pal.wall, pal.accent, { floors = 2, sign = "BARRACUDA BISTRO", floorHeight = 10 })
	Cyl(8, 10, C.White, rest + Vector3.new(0, top + 3, 0), { material = M.Fabric })
	Ball(13, C.White, rest + Vector3.new(0, top + 9, 0), { material = M.Fabric })
	ctx.reserve(-118, 0, 28)
	-- masts
	for _, z in ipairs({ -52, 52 }) do
		local mp = ctx.at(-60, z)
		Kit.CylCF(40, 1.6, C.DarkWood, CFrame.new(mp + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.pi / 2), { material = M.Wood })
		P(Vector3.new(0.3, 16, 18), C.White, CFrame.new(mp + Vector3.new(0, 24, 0)), Kit.decor({ material = M.Fabric }))
		ctx.reserve(-60, z, 3)
	end
	-- dining tables with umbrellas
	L.Scatter(ctx, 12, 20, ctx.r - 25, function(pos)
		Cyl(0.6, 6, C.White, pos + Vector3.new(0, 3, 0), Kit.decor())
		P(Vector3.new(0.5, 3, 0.5), C.DarkWood, CFrame.new(pos + Vector3.new(0, 1.5, 0)), Kit.decor())
		P(Vector3.new(0.3, 8, 0.3), C.DarkWood, CFrame.new(pos + Vector3.new(0, 4, 0)), Kit.decor({ collide = false }))
		for k = 0, 5 do
			Wedge(Vector3.new(0.2, 1.2, 4), k % 2 == 0 and pal.accent or C.White, CFrame.new(pos + Vector3.new(0, 8.4, 0)) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0, -2) * CFrame.Angles(0.35, 0, math.pi / 2), Kit.decor({ collide = false }))
		end
	end, 6)
	-- life rings + lanterns around the rail
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * (ctx.r - 3), g + 4, math.sin(a) * (ctx.r - 3))
		if i % 2 == 0 then
			Cyl(0.8, 3.4, Color3.fromRGB(255, 90, 80), p, Kit.decor({ collide = false }))
		else
			Ball(1.4, Color3.fromRGB(255, 220, 140), p + Vector3.new(0, 4, 0), Kit.decor({ material = M.Neon, collide = false }))
		end
	end
end

-- Mikan Isles: tangerine groves, pinwheel village, Sawtooth Park compound with pagoda
function Themes.SawtoothPark(ctx)
	local pal = ctx.pal
	local teal, dark = Color3.fromRGB(70, 160, 170), Color3.fromRGB(40, 80, 110)
	local cx, half = -165, 46
	local center = ctx.at(cx, 0)
	for i = 0, 3 do
		local cf = CFrame.new(center) * CFrame.Angles(0, i * math.pi / 2, 0)
		if i == 0 then
			for _, s in ipairs({ -1, 1 }) do
				P(Vector3.new(5, 20, half - 9), teal, cf * CFrame.new(half, 10, s * (half / 2 + 4.5)), { material = M.Brick })
			end
			-- shark-mouth gate
			P(Vector3.new(6, 30, 26), dark, cf * CFrame.new(half + 3, 15, 0), { material = M.Brick })
			Ball(20, Color3.fromRGB(16, 22, 30), (cf * CFrame.new(half + 5, 10, 0)).Position, { collide = false })
			for k = -4, 4 do
				Wedge(Vector3.new(1.2, 3, 1.4), Color3.new(1, 1, 1), cf * CFrame.new(half + 6.2, 18.5, k * 2.1) * CFrame.Angles(math.pi, 0, 0), Kit.decor())
				Wedge(Vector3.new(1.2, 2.4, 1.4), Color3.new(1, 1, 1), cf * CFrame.new(half + 6.2, 1.8, k * 2.1), Kit.decor())
			end
			Kit.Sign("SAWTOOTH PARK", cf * CFrame.new(half + 6.4, 27, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector2.new(18, 3.4), Color3.fromRGB(180, 240, 255), dark)
		else
			P(Vector3.new(5, 20, half * 2), teal, cf * CFrame.new(half, 10, 0), { material = M.Brick })
		end
		for k = -3, 3 do
			P(Vector3.new(5.5, 2.4, 4), teal:Lerp(Color3.new(1, 1, 1), 0.2), cf * CFrame.new(half, 21, k * 13), Kit.decor())
		end
	end
	ctx.reserve(cx, 0, half + 8)
	Kit.Pagoda(center + Vector3.new(-14, 0, 0), 1.2, Color3.fromRGB(240, 236, 220), dark)
	P(Vector3.new(30, 1, 24), Color3.fromRGB(60, 170, 230), CFrame.new(center + Vector3.new(18, 0.3, 0)), { material = M.Glass, transparency = 0.25, collide = false, reflectance = 0.2 })
	-- tangerine groves in rows
	for _, grove in ipairs({ { 50, -150 }, { -20, 150 }, { 90, 60 } }) do
		for gx = 0, 3 do
			for gz = 0, 2 do
				-- groves sit on their own terraces (reserved by L.Tiers), so no free() check here
				local x, z = grove[1] + gx * 12 - 18, grove[2] + gz * 12 - 12
				Kit.RoundTree(ctx.at(x, z), 0.8, Color3.fromRGB(70, 170, 70), Color3.fromRGB(255, 150, 20))
			end
		end
	end
	-- pinwheel windmill
	Kit.Windmill(ctx.at(0, -ctx.island.townRadius - 30), 0.6, Color3.fromRGB(255, 170, 40))
	ctx.reserve(0, -ctx.island.townRadius - 30, 8)
	L.HouseRing(ctx, ctx.island.townRadius + 16, 11, pal.wall, { pal.accent, Color3.fromRGB(230, 120, 60), Color3.fromRGB(110, 180, 120) })
	L.Greenery(ctx, 8, nil, Color3.fromRGB(255, 150, 20))
	L.Coast(ctx, 30)
end

-- Epilogue Town: big harbor city, execution platform, clock tower, arena, lighthouse
function Themes.HarborCity(ctx)
	local pal = ctx.pal
	local c = ctx.at(0, 0)
	-- execution platform
	local stone = Color3.fromRGB(196, 186, 176)
	for i = 0, 5 do
		P(Vector3.new(34 - i * 3.4, 2.4, 26 - i * 2.6), stone, CFrame.new(c + Vector3.new(0, 1.2 + i * 2.4, 0)), { material = M.Brick })
	end
	local deck = c + Vector3.new(0, 14.4, 0)
	P(Vector3.new(16, 1, 12), C.Wood, CFrame.new(deck + Vector3.new(0, 0.5, 0)), { material = M.WoodPlanks })
	for _, sx in ipairs({ -6, 6 }) do
		P(Vector3.new(1.6, 18, 1.6), C.DarkWood, CFrame.new(deck + Vector3.new(sx, 9, 0)), { material = M.Wood })
	end
	P(Vector3.new(15, 1.6, 2), C.DarkWood, CFrame.new(deck + Vector3.new(0, 18, 0)), { material = M.Wood })
	for _, sx in ipairs({ -10, 10 }) do
		P(Vector3.new(4, 9, 0.2), pal.accent, CFrame.new(deck + Vector3.new(sx, -4, -12.5)), Kit.decor({ material = M.Fabric }))
	end
	ctx.reserve(0, 0, 20)
	-- clock tower
	Kit.Tower(ctx.at(-60, -100), 14, 52, Color3.fromRGB(230, 220, 200), Color3.fromRGB(80, 90, 150), { material = M.Brick })
	local face = ctx.at(-60, -100) + Vector3.new(0, 42, -7.3)
	Cyl(0.4, 9, Color3.new(1, 1, 1), face, Kit.decor())
	P(Vector3.new(0.4, 3.6, 0.3), Color3.fromRGB(30, 30, 30), CFrame.new(face + Vector3.new(0, 1.4, -0.3)), Kit.decor({ collide = false }))
	ctx.reserve(-60, -100, 9)
	-- marine base
	houseAt(ctx, 70, 105, 30, 20, Color3.fromRGB(245, 247, 252), C.Marine, { floors = 3, sign = "MARINE HQ" })
	Kit.Flag(ctx.at(92, 105), C.Marine, 20, true)
	-- arena
	local ar = ctx.island.arena
	local ac = ctx.at(ar.offset.X, ar.offset.Y)
	Cyl(0.6, ar.radius * 2, Color3.fromRGB(230, 205, 150), ac + Vector3.new(0, 0.2, 0), { material = M.Sand })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		if i % 4 ~= 0 then
			P(Vector3.new(ar.radius * 0.42, 6, 4), stone, CFrame.new(ac + Vector3.new(math.cos(a) * ar.radius, 3, math.sin(a) * ar.radius)) * CFrame.Angles(0, -a + math.pi / 2, 0), { material = M.Brick })
		else
			Kit.Flag(ac + Vector3.new(math.cos(a) * (ar.radius + 3), 0, math.sin(a) * (ar.radius + 3)), Color3.fromRGB(220, 60, 60), 12)
		end
	end
	Kit.PostSign("PVP ARENA", ac + Vector3.new(ar.radius * 0.8, 0, ar.radius * 0.8), Vector3.new(1, 0, 1), 10)
	ctx.reserve(ar.offset.X, ar.offset.Y, ar.radius + 6)
	-- lighthouse
	Kit.Lighthouse(ctx.at(230, -60), 1.1)
	ctx.reserve(230, -60, 9)
	-- dense city rings
	local roofs = { pal.accent, Color3.fromRGB(80, 90, 150), Color3.fromRGB(160, 90, 60), Color3.fromRGB(70, 130, 110) }
	L.HouseRing(ctx, ctx.island.townRadius + 14, 18, pal.wall, roofs, { floors = 2 })
	L.HouseRing(ctx, ctx.island.townRadius + 48, 22, pal.wall, roofs, { floors = 3 }, 0.1)
	-- market street
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2 + 0.2
		local x, z = math.cos(a) * 45, math.sin(a) * 45
		if ctx.free(x, z, 5) then
			Kit.Stall(yawToward(ctx.at(x, z), c), roofs[i % #roofs + 1])
			ctx.reserve(x, z, 5)
		end
	end
	L.Greenery(ctx, 8)
	L.Coast(ctx, 30)
end

L.Themes = Themes
L.HouseAt = houseAt
L.YawToward = yawToward

function L.Build(ctx)
	if ctx.island.theme == "HarborCity" then
		local c = ctx.at(0, 0)
		Cyl(0.9, (ctx.island.townRadius + 72) * 2, Color3.fromRGB(196, 186, 170), Vector3.new(c.X, 7.12, c.Z), { material = M.Cobblestone })
	end
	L.Tiers(ctx, L.TierSpecs[ctx.island.theme])
	L.Ridge(ctx)
	L.Plaza(ctx, ctx.island.theme ~= "HarborCity")
	L.Paths(ctx)
	local theme = Themes[ctx.island.theme]
	if theme then
		theme(ctx)
	end
end

return L
