-- Honeyslope Village (v0.25.130, owner concept notes: docs/Islands-Concept.md row 3). Island coordinates before the
-- island turns: +Z = south = the harbor (faces Marmalade, the previous island).
--   South cove: sand beach, a long wooden jetty with rowboats, the spawn by the shop + blacksmith.
--   A winding dirt road climbs north to the village green: one giant old tree in the middle, benches round it.
--   Cottages ring the green (straw-thatch or orange roofs, cream / white walls), each with a fenced vegetable plot
--   behind it. Lanes go west to the crop fields (Night Cat pirates) and east to the hay meadow + red barn (thugs).
--   North: the road reaches a tall hill; stairs up to a white manor with a slate roof inside a ring of hedges and a
--   gate. Grey rock cliffs on the north-west and north-east shores (Silent Claw prowls below the east one).
-- Our own village: no characters or buildings from any other work.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P = Kit.P
local M = Enum.Material

local HS = {}

local GROUND = 7.6
local DIRT = Color3.fromRGB(184, 136, 88)
local SOIL = Color3.fromRGB(110, 76, 52)
local CROP = Color3.fromRGB(96, 170, 70)
local STRAW = Color3.fromRGB(222, 186, 104)
local WALLS = { Color3.fromRGB(250, 240, 218), Color3.fromRGB(246, 226, 196), Color3.fromRGB(252, 248, 238), Color3.fromRGB(238, 216, 180) }
local ROOFS = { STRAW, Color3.fromRGB(232, 120, 56), STRAW:Lerp(Color3.fromRGB(150, 110, 60), 0.3), Color3.fromRGB(214, 98, 46) }
local TRIM = Color3.fromRGB(116, 80, 54)
local SHUTTER = Color3.fromRGB(84, 132, 168)
local FENCE = Color3.fromRGB(196, 160, 112)
local GREEN_C = Vector2.new(0, 40) -- village green (the giant tree)
local HILL = { x = 0, z = -188, r = 64, h = 20, capR = 38, capH = 10 }
local S = math.pi / 2

-- a dirt road through points (x, z): overlapping segments, alternating 0.04 heights so bends never share a top face
local roadK = 0
local function road(ctx, pts, width)
	for i = 2, #pts do
		local a, b = ctx.at(pts[i - 1].X, pts[i - 1].Y), ctx.at(pts[i].X, pts[i].Y)
		a, b = Vector3.new(a.X, GROUND, a.Z), Vector3.new(b.X, GROUND, b.Z)
		roadK += 1
		local y = 0.1 + (roadK % 3) * 0.04
		local mid, len = (a + b) / 2, (b - a).Magnitude
		P(Vector3.new(width or 9, 0.3, len + (width or 9) * 0.6), DIRT, CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)), { material = M.Ground })
		ctx.reserve((pts[i - 1].X + pts[i].X) / 2, (pts[i - 1].Y + pts[i].Y) / 2, len / 2 + 3)
	end
end

local function v(x, z)
	return Vector2.new(x, z)
end

-- the green: a grass disc ring of path, the giant tree, benches facing it
local function green(ctx)
	local gx, gz = GREEN_C.X, GREEN_C.Y
	local pts = {}
	for i = 0, 16 do
		local a = i / 16 * math.pi * 2
		table.insert(pts, v(gx + math.cos(a) * 30, gz + math.sin(a) * 30))
	end
	road(ctx, pts, 8)
	Kit.RoundTree(ctx.at(gx, gz), 2.8)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local p = ctx.at(gx + math.cos(a) * 19, gz + math.sin(a) * 19)
		Kit.Bench(CFrame.lookAt(p, ctx.at(gx, gz)))
	end
	Kit.Flowers(ctx.at(gx + 12, gz - 10), 5, 10)
	Kit.Flowers(ctx.at(gx - 12, gz + 10), 5, 10)
	ctx.reserve(gx, gz, 36)
end

-- a fenced vegetable plot (soil bed + crop rows + pumpkins), facing `out`
local function plot(ctx, center, out, w, d)
	local yaw = math.atan2(out.X, out.Y)
	local base = ctx.at(center.X, center.Y)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	P(Vector3.new(w, 0.5, d), SOIL, cf * CFrame.new(0, 0.2, 0), { material = M.Ground })
	for k = 1, math.floor(w / 3) - 1 do
		local x = -w / 2 + k * 3
		P(Vector3.new(1.4, 0.9, d - 2), CROP, cf * CFrame.new(x, 0.75, 0), Kit.decor({ material = M.Grass, collide = false }))
		if k % 2 == 0 then
			P(Vector3.new(1.3, 1.1, 1.3), Color3.fromRGB(236, 132, 40), cf * CFrame.new(x + 1.5, 0.9, d / 2 - 2), Kit.decor({ collide = false }))
		end
	end
	local c = { cf * Vector3.new(-w / 2 - 1, 0, -d / 2 - 1), cf * Vector3.new(w / 2 + 1, 0, -d / 2 - 1), cf * Vector3.new(w / 2 + 1, 0, d / 2 + 1), cf * Vector3.new(-w / 2 - 1, 0, d / 2 + 1) }
	Kit.Fence(c[2], c[3], FENCE)
	Kit.Fence(c[3], c[4], FENCE)
	Kit.Fence(c[4], c[1], FENCE)
	ctx.reserve(center.X, center.Y, math.max(w, d) / 2 + 2)
end

-- cottages round the green, doors to the tree, a plot behind each
local HOUSES = { v(-48, -6), v(-78, 30), v(-64, 98), v(-30, 108), v(32, 108), v(56, 122), v(80, 40), v(58, -4), v(32, -40), v(-38, -46) }
local function cottages(ctx)
	local rng = Kit.rng
	for i, h in ipairs(HOUSES) do
		local out = (h - GREEN_C).Unit
		local pos = ctx.at(h.X, h.Y)
		local w, d = rng:NextNumber(12, 15), rng:NextNumber(10, 12)
		Kit.House(CFrame.lookAt(pos, ctx.at(GREEN_C.X, GREEN_C.Y)), w, d, WALLS[rng:NextInteger(1, #WALLS)], ROOFS[(i % #ROOFS) + 1], {
			floors = rng:NextNumber() > 0.7 and 2 or 1, trim = TRIM, shutter = SHUTTER, timber = rng:NextNumber() > 0.5,
			sign = ({ [1] = "BAKERY", [4] = "INN", [7] = "MILL SHOP" })[i],
		})
		ctx.reserve(h.X, h.Y, 10)
		plot(ctx, h + out * 17, out, 12, 9)
		if rng:NextNumber() > 0.5 then
			Kit.Barrel(ctx.at(h.X, h.Y) + Vector3.new(0, 0.5, 0) + Vector3.new(out.Y, 0, -out.X) * (w / 2 + 2))
		end
	end
end

-- the crop fields west (rows + scarecrows; no fences so the mobs roam) and the hay meadow + barn east
local function farmland(ctx)
	local rng = Kit.rng
	for _, f in ipairs({ { -150, 80, 34, 26 }, { -112, 140, 30, 24 }, { -170, 140, 22, 30 } }) do
		local cf = CFrame.new(ctx.at(f[1], f[2]))
		P(Vector3.new(f[3], 0.4, f[4]), SOIL, cf * CFrame.new(0, 0.15, 0), { material = M.Ground })
		for k = 1, math.floor(f[3] / 3.4) - 1 do
			P(Vector3.new(1.5, 1, f[4] - 2), k % 3 == 0 and STRAW or CROP, cf * CFrame.new(-f[3] / 2 + k * 3.4, 0.7, 0), Kit.decor({ material = M.Grass, collide = false }))
		end
		-- scarecrow: post, crossbar, straw head with a hat
		local s = cf * CFrame.new(f[3] / 2 - 4, 0, -f[4] / 2 + 4)
		P(Vector3.new(0.6, 7, 0.6), TRIM, s * CFrame.new(0, 3.5, 0), { material = M.Wood })
		P(Vector3.new(5, 0.5, 0.5), TRIM, s * CFrame.new(0, 5.2, 0), Kit.decor({ material = M.Wood }))
		P(Vector3.new(2, 2, 2), STRAW, s * CFrame.new(0, 7.6, 0), Kit.decor({ material = M.Fabric }))
		P(Vector3.new(3.2, 0.4, 3.2), Color3.fromRGB(150, 90, 50), s * CFrame.new(0, 8.8, 0), Kit.decor({ material = M.Fabric }))
	end
	-- east: hay bales around the meadow, a red barn past it
	for _ = 1, 12 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(12, 40)
		local p = ctx.at(125 + math.cos(a) * d, 125 + math.sin(a) * d)
		P(Vector3.new(4, 3, 3), STRAW, CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, a, 0), { material = M.Fabric })
	end
	local barn = ctx.at(150, 172)
	Kit.House(CFrame.lookAt(barn, barn + Vector3.new(-1, 0, -1)), 20, 15, Color3.fromRGB(176, 62, 50), Color3.fromRGB(110, 70, 50), { floors = 1, floorHeight = 12, trim = Color3.fromRGB(246, 240, 226), shutter = Color3.fromRGB(246, 240, 226) })
	ctx.reserve(150, 172, 14)
end

-- the manor hill: a big lobe, a smaller cap on top, stairs south; the manor inside a hedge ring with a gate
local function manor(ctx)
	L.Tiers(ctx, {
		{ x = HILL.x, z = HILL.z, r = HILL.r, h = HILL.h, force = true, stairs = { S }, cap = { r = HILL.capR, h = HILL.capH, stairs = { S } } },
	})
	local top = ctx.at(HILL.x, HILL.z - 4)
	Kit.House(CFrame.lookAt(top, top + Vector3.new(0, 0, 1)), 34, 20, Color3.fromRGB(252, 250, 244), Color3.fromRGB(86, 104, 140), {
		floors = 2, floorHeight = 10, trim = Color3.fromRGB(70, 74, 90), shutter = Color3.fromRGB(70, 110, 150), stone = Color3.fromRGB(190, 186, 176), sign = "HILLCREST MANOR",
	})
	-- hedge ring on the cap rim, open at the front (south) for the gate
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		if math.abs(a - S) > 0.3 then
			Kit.Bush(ctx.at(HILL.x + math.cos(a) * (HILL.capR - 4), HILL.z + math.sin(a) * (HILL.capR - 4)), 4.2, Color3.fromRGB(62, 150, 80))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local g = ctx.at(HILL.x + sx * 7, HILL.z + HILL.capR - 4)
		P(Vector3.new(2.6, 8, 2.6), Color3.fromRGB(200, 196, 186), CFrame.new(g + Vector3.new(0, 4, 0)), { material = M.Brick })
		Kit.Ball(2.6, Color3.fromRGB(240, 196, 70), g + Vector3.new(0, 9.2, 0), Kit.decor())
	end
	-- trees on the lower lobe, round the cap
	local rng = Kit.rng
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		if math.abs(a - S) > 0.45 then
			local d = rng:NextNumber(HILL.capR + 6, HILL.r - 6)
			Kit.RoundTree(ctx.at(HILL.x + math.cos(a) * d, HILL.z + math.sin(a) * d), rng:NextNumber(0.8, 1.2))
		end
	end
end

-- grey rock cliffs on the north-west and north-east shores (bare tops, a few pines)
local function cliffs(ctx)
	L.Tiers(ctx, {
		{ x = -196, z = -84, r = 40, h = 26, force = true, cap = { dx = -8, dz = -6, r = 22, h = 10 } },
		{ x = 196, z = -84, r = 38, h = 22, force = true, cap = { dx = 8, dz = -6, r = 20, h = 8 } },
	})
	local rng = Kit.rng
	for _, cx in ipairs({ -196, 196 }) do
		for _ = 1, 4 do
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 26)
			Kit.PineTree(ctx.at(cx + math.cos(a) * d, -84 + math.sin(a) * d), rng:NextNumber(0.8, 1.1))
		end
	end
end

-- woods between the fields and the hill, and along the east side
local function woods(ctx)
	local rng = Kit.rng
	-- v0.25.130 (first look: the meadows were bare): a thick wood band round the village, thinner in the middle
	for _ = 1, 260 do
		local x, z = rng:NextNumber(-240, 240), rng:NextNumber(-240, 240)
		local d = math.sqrt(x * x + (z - 40) * (z - 40))
		if d > 120 and ctx.free(x, z, 7) then
			Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.85, 1.35))
			ctx.reserve(x, z, 6)
		end
	end
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-230, 230), rng:NextNumber(-230, 230)
		if ctx.free(x, z, 3) then
			if rng:NextNumber() > 0.6 then
				Kit.Flowers(ctx.at(x, z), 4, 6)
			else
				Kit.Bush(ctx.at(x, z), rng:NextNumber(2.5, 4))
			end
		end
	end
end

-- the south cove: a wooden jetty on posts with rowboats tied up
local function cove(ctx)
	local z0, z1 = 250, 318 -- from the beach out over the water (the square base reaches ~r)
	local plank = Color3.fromRGB(150, 108, 70)
	P(Vector3.new(10, 0.8, z1 - z0), plank, CFrame.new(ctx.c + Vector3.new(0, GROUND - 1.2, (z0 + z1) / 2)), { material = M.WoodPlanks })
	for z = z0 + 4, z1, 8 do
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(1.2, GROUND + 4, 1.2), TRIM, CFrame.new(ctx.c + Vector3.new(sx * 5.4, (GROUND + 4) / 2 - 2.6, z)), { material = M.Wood })
		end
	end
	for _, b in ipairs({ { -10, 284, 0.25 }, { 10, 300, -0.2 } }) do
		Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(b[1], 0.4, b[2])) * CFrame.Angles(0, b[3], 0), Color3.fromRGB(110, 150, 190))
	end
	Kit.Lamp(ctx.c + Vector3.new(4.5, GROUND - 0.8, z1 - 2))
	Kit.CrateStack(ctx.c + Vector3.new(-14, GROUND, 186))
	Kit.Barrel(ctx.c + Vector3.new(14, GROUND + 0.5, 188))
	P(Vector3.new(9, 0.3, 60), DIRT, CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.1, 222)), { material = M.Ground }) -- path down to the jetty
	ctx.reserve(0, 222, 16)
end

local function shoreRocks(ctx)
	local rng = Kit.rng
	local r = ctx.r
	for i = 1, 50 do
		local a = i / 50 * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local d = r + rng:NextNumber(-12, 20)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local cove = z > 150 and math.abs(x) < 60
		local docks = math.abs(z) < 30 and math.abs(x) > 200
		if not cove and not docks then
			local y = d < r - 4 and GROUND - 1 or -0.5
			if i % 3 == 0 then
				Kit.RockCluster(ctx.c + Vector3.new(x, y, z), rng:NextNumber(7, 12))
			else
				Kit.Rock(ctx.c + Vector3.new(x, y, z), rng:NextNumber(6, 12))
			end
		end
	end
end

local function npcs(ctx, api)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face or Vector2.new(0, z - 30))
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -24, 160, { SubTitle = "Shop" }, Vector2.new(0, 160))
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 24, 160, { SubTitle = "Refine & Cards" }, Vector2.new(0, 160))
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 26, 128, { SubTitle = "Fast Travel" }, Vector2.new(0, 128))
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 182, { SubTitle = "📜 Quests" }, Vector2.new(0, 160))
end

function HS.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	-- the base's round "gentle hill" mounds read as stray green boxes: drop them (as Marmalade does)
	for _, o in ipairs(f:GetChildren()) do
		local pos = o:IsA("Part") and o.CFrame.Position
		if pos and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and pos.Y < 0 then
			o:Destroy()
		end
	end
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	-- 1. landforms first (later pieces read their heights), then NPCs (they reserve their spots)
	manor(ctx)
	cliffs(ctx)
	npcs(ctx, api)
	-- 2. the roads: cove -> green -> hill stairs, lanes west + east
	road(ctx, { v(0, 196), v(8, 162), v(-6, 122), v(6, 86), v(0, 70) })
	road(ctx, { v(0, 10), v(-10, -28), v(8, -64), v(0, -86) })
	road(ctx, { v(-30, 52), v(-72, 70), v(-112, 92) }, 7)
	road(ctx, { v(30, 52), v(74, 82), v(108, 108) }, 7)
	green(ctx)
	cottages(ctx)
	farmland(ctx)
	cove(ctx)
	-- 3. harbor services: side docks + shipyard
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 4. greenery, shore, chests last (they look for hill tops)
	woods(ctx)
	shoreRocks(ctx)
	api.placeChests(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 176)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return HS
