-- Marmalade Town (v0.25.24, owner concept art: docs/Islands-Concept.md row 2). Island coordinates before the island
-- turns: +Z = south = the harbor (faces Conch Bay, the previous island).
--   Harbor quay (south): stone seawall, bollards, the big-top circus ship moored broadside (our own: purple hull, gold
--     star figurehead, striped tent, pennant masts; no clown head, no pirate flag), a gangplank.
--   Grand boulevard: one long paved square from the quay north to the town hall, flower planters down the middle,
--     lamps both sides. House blocks either side (cream / pink / yellow / peach walls, orange tile roofs, green
--     shutters), doors to the boulevard and to the lanes, one cross street.
--   Town hall (north end): raised terrace + wide stairs, blue roof with a dome, the clock tower beside it.
--   Forest hill behind it (orange groves), winding dirt paths up both coasts, grey boulders all round the shore.
-- Monsters: clowns on the west path, acrobats on the east path, lions in the hill groves, Captain Confetti in the
-- square in front of the town hall (Config/Islands offsets). Original names only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P, Cyl = Kit.P, Kit.Cyl
local M = Enum.Material

local MT = {}

local GROUND = 7.6
local PAVE = Color3.fromRGB(214, 206, 192)
local PAVE2 = Color3.fromRGB(196, 188, 174)
local STONE = Color3.fromRGB(176, 170, 160)
local DIRT = Color3.fromRGB(196, 140, 84)
local WALLS = { Color3.fromRGB(246, 230, 200), Color3.fromRGB(240, 196, 190), Color3.fromRGB(246, 216, 146), Color3.fromRGB(244, 202, 160) }
local ROOFS = { Color3.fromRGB(232, 112, 48), Color3.fromRGB(242, 134, 60), Color3.fromRGB(214, 94, 42) }
local SHUTTER = Color3.fromRGB(70, 130, 80)
local TRIM = Color3.fromRGB(120, 82, 56)
local HALL_ROOF, HALL_WALL = Color3.fromRGB(56, 92, 200), Color3.fromRGB(236, 176, 104)
local GOLD = Color3.fromRGB(240, 196, 70)
local ORANGE_FRUIT = Color3.fromRGB(255, 150, 30)

local TOWN = { -122, 122, -112, 172 } -- paved town (x0, x1, z0, z1)
local QUAY_Z = 200 -- seawall line
local HALL = { -42, 42, -124, -88 } -- town hall terrace (the hill's lobes reach ~1.13 r, it stays clear)
local HALL_UP = 3

local function slab(ctx, r, y0, y1, color, mat, opts)
	opts = opts or {}
	opts.material = mat
	return P(Vector3.new(r[2] - r[1], y1 - y0, r[4] - r[3]), color, CFrame.new(ctx.c + Vector3.new((r[1] + r[2]) / 2, (y0 + y1) / 2, (r[3] + r[4]) / 2)), opts)
end

-- town hall: terrace + stairs, long two-storey hall with a blue roof, a dome on the ridge, flag
local function townHall(ctx)
	slab(ctx, HALL, 2, GROUND + HALL_UP, STONE, M.Brick)
	slab(ctx, { HALL[1] + 0.5, HALL[2] - 0.5, HALL[3] + 0.5, HALL[4] - 0.5 }, GROUND + HALL_UP - 0.1, GROUND + HALL_UP + 0.05, PAVE, M.Cobblestone)
	Kit.Stairs(ctx.c + Vector3.new(0, GROUND, HALL[4] + 6), Vector3.new(0, 0, -1), HALL_UP, 22, PAVE)
	for _, sx in ipairs({ -1, 1 }) do
		Kit.Lamp(ctx.c + Vector3.new(sx * 15, GROUND, HALL[4] + 8))
		Kit.RoundTree(ctx.c + Vector3.new(sx * 34, GROUND + HALL_UP, HALL[4] - 4), 0.6)
	end
	local base = ctx.c + Vector3.new(0, GROUND + HALL_UP, -108)
	local top = Kit.House(CFrame.lookAt(base, base + Vector3.new(0, 0, 1)), 50, 22, HALL_WALL, HALL_ROOF, { floors = 2, trim = Color3.fromRGB(250, 240, 220), shutter = Color3.fromRGB(250, 240, 220), stone = STONE, chimney = false, sign = "TOWN HALL", signBg = HALL_ROOF })
	-- dome: drum, blue cap rings, gold lantern
	local d = base + Vector3.new(0, top - 1, 0)
	Cyl(5, 12, Color3.fromRGB(250, 240, 220), d + Vector3.new(0, 2.5, 0), {})
	for i = 0, 3 do
		Cyl(1.6, 12 - i * 2.6, HALL_ROOF, d + Vector3.new(0, 5.8 + i * 1.5, 0), {})
	end
	Cyl(2.4, 2.2, GOLD, d + Vector3.new(0, 12.6, 0), {})
	Kit.Flag(d + Vector3.new(0, 13.8, 0), Color3.fromRGB(240, 120, 40), 6)
	-- side wings, one storey
	for _, sx in ipairs({ -1, 1 }) do
		local w = base + Vector3.new(sx * 32, 0, 2)
		Kit.House(CFrame.lookAt(w, w + Vector3.new(0, 0, 1)), 12, 16, HALL_WALL, HALL_ROOF, { trim = Color3.fromRGB(250, 240, 220), shutter = Color3.fromRGB(250, 240, 220), stone = STONE, chimney = false })
	end
end

-- clock tower: tall ochre shaft, clock faces on four sides, open belfry, stepped roof
local function clockTower(ctx, x, z)
	local p = ctx.c + Vector3.new(x, GROUND, z)
	local h = 40
	P(Vector3.new(11, 1.5, 11), STONE, CFrame.new(p + Vector3.new(0, 0.75, 0)), { material = M.Cobblestone })
	P(Vector3.new(9, h, 9), Color3.fromRGB(232, 168, 84), CFrame.new(p + Vector3.new(0, h / 2, 0)), { material = M.Brick })
	for i = 1, 3 do
		P(Vector3.new(9.6, 0.8, 9.6), Color3.fromRGB(250, 236, 210), CFrame.new(p + Vector3.new(0, i * 10, 0)), Kit.decor())
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		local face = CFrame.new(p + Vector3.new(0, h - 8, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -4.6)
		P(Vector3.new(5.4, 5.4, 0.3), Color3.fromRGB(250, 246, 236), face, Kit.decor())
		P(Vector3.new(0.5, 2.2, 0.2), Color3.fromRGB(40, 40, 50), face * CFrame.new(0, 0.9, -0.2), Kit.decor({ collide = false }))
		P(Vector3.new(1.8, 0.5, 0.2), Color3.fromRGB(40, 40, 50), face * CFrame.new(0.7, 0, -0.2), Kit.decor({ collide = false }))
		-- belfry openings
		P(Vector3.new(3.2, 4.4, 0.3), Color3.fromRGB(70, 46, 30), CFrame.new(p + Vector3.new(0, h - 2.4, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -4.6), Kit.decor({ collide = false }))
	end
	for i = 0, 4 do
		local s = 10.4 - i * 2.2
		P(Vector3.new(s, 1.8, s), Color3.fromRGB(206, 82, 40), CFrame.new(p + Vector3.new(0, h + 0.9 + i * 1.8, 0)), { material = M.Brick })
	end
	P(Vector3.new(0.6, 4, 0.6), GOLD, CFrame.new(p + Vector3.new(0, h + 11, 0)), Kit.decor())
	ctx.reserve(x, z, 8)
end

-- the grand boulevard: lighter paving, planters with flowers down the middle, lamps on both sides
local function boulevard(ctx)
	slab(ctx, { -30, 30, HALL[4], QUAY_Z - 4 }, GROUND - 0.2, GROUND + 0.06, PAVE2, M.Cobblestone)
	for _, z in ipairs({ -34, 14, 62, 110 }) do
		P(Vector3.new(7, 1.4, 18), STONE, CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.7, z)), { material = M.Brick })
		P(Vector3.new(5.6, 0.3, 16.6), Color3.fromRGB(110, 78, 50), CFrame.new(ctx.c + Vector3.new(0, GROUND + 1.45, z)), Kit.decor({ material = M.Ground }))
		Kit.Flowers(ctx.c + Vector3.new(0, GROUND + 1.6, z), 3, 9)
		Kit.Bush(ctx.c + Vector3.new(0, GROUND + 1.6, z - 6), 2.4)
		Kit.Bush(ctx.c + Vector3.new(0, GROUND + 1.6, z + 6), 2.4)
		ctx.reserve(0, z, 10)
	end
	for z = -76, QUAY_Z - 14, 28 do
		for _, sx in ipairs({ -1, 1 }) do
			Kit.Lamp(ctx.c + Vector3.new(sx * 31, GROUND, z))
		end
	end
end

-- house blocks either side: three columns per side, doors toward the boulevard, one cross street at z ~ 38
local function houseBlocks(ctx)
	local rng = Kit.rng
	for _, sx in ipairs({ -1, 1 }) do
		for col, x in ipairs({ 46, 77, 108 }) do
			local z = -86
			while z < QUAY_Z - 40 do
				local w = rng:NextNumber(13, 16)
				local cz = z + w / 2
				local cross = cz > 26 and cz < 50
				local hall = col == 1 and cz < -80
				if not cross and not hall then
					local pos = ctx.c + Vector3.new(sx * x, GROUND, cz)
					local d = rng:NextNumber(11, 12.5)
					Kit.House(CFrame.lookAt(pos, pos + Vector3.new(-sx, 0, 0)), w, d, WALLS[rng:NextInteger(1, #WALLS)], ROOFS[rng:NextInteger(1, #ROOFS)], {
						floors = rng:NextNumber() > 0.4 and 2 or 1, shutter = SHUTTER, trim = TRIM, stone = STONE, timber = rng:NextNumber() > 0.6,
						sign = (col == 1 and rng:NextNumber() > 0.75) and ({ "BAKERY", "JAM SHOP", "PET FOOD", "TAILOR", "FRUIT" })[rng:NextInteger(1, 5)] or nil,
					})
					ctx.reserve(sx * x, cz, 8)
					-- a striped market awning beside some boulevard doors (never over the door)
					if col == 1 and rng:NextNumber() > 0.55 then
						Kit.Stall(CFrame.new(ctx.c + Vector3.new(sx * (x - d / 2 - 4), GROUND, cz + w / 2 - 1)) * CFrame.Angles(0, sx * math.pi / 2, 0), ROOFS[1])
					end
				end
				z += w + (rng:NextNumber() > 0.7 and 6 or 2)
			end
		end
	end
end

-- the harbor: quay band, seawall, bollards, crates; the circus ship moored broadside with a gangplank
local function harbor(ctx)
	slab(ctx, { TOWN[1], TOWN[2], TOWN[4], QUAY_Z }, 2, GROUND, PAVE, M.Cobblestone)
	P(Vector3.new(TOWN[2] - TOWN[1] + 4, 10, 3), STONE, CFrame.new(ctx.c + Vector3.new(0, GROUND - 5.1, QUAY_Z + 1.5)), { material = M.Brick })
	for x = TOWN[1] + 8, TOWN[2] - 8, 14 do
		if math.abs(x - 28) < 6 then -- the gangplank lands here
			continue
		end
		Cyl(1.6, 1.6, Color3.fromRGB(60, 60, 70), ctx.c + Vector3.new(x, GROUND + 0.8, QUAY_Z - 2), Kit.decor())
	end
	Kit.CrateStack(ctx.c + Vector3.new(-70, GROUND, QUAY_Z - 8))
	Kit.Barrel(ctx.c + Vector3.new(-62, GROUND + 0.5, QUAY_Z - 6))
	Kit.CrateStack(ctx.c + Vector3.new(84, GROUND, QUAY_Z - 9))
	-- the ship (decor, not a sailing ship): hull along x, deck at GROUND + 1.4
	local sz = QUAY_Z + 22
	local deckY = GROUND + 1.4
	local purple, gold = Color3.fromRGB(120, 50, 120), GOLD
	local function hull(y0, y1, len, wid, color)
		P(Vector3.new(len, y1 - y0, wid), color, CFrame.new(ctx.c + Vector3.new(0, (y0 + y1) / 2, sz)), { material = M.WoodPlanks })
	end
	hull(-4, 0, 70, 16, purple:Lerp(Color3.new(0, 0, 0), 0.25))
	hull(0, 4, 80, 21, purple)
	hull(4, deckY - 1, 86, 24, purple)
	hull(deckY - 1, deckY, 86, 24, Color3.fromRGB(196, 140, 86))
	P(Vector3.new(86.4, 0.8, 24.4), gold, CFrame.new(ctx.c + Vector3.new(0, 4.4, sz)), Kit.decor())
	-- bow (east): stepped point + gold star figurehead; stern castle (west)
	for i = 1, 4 do
		local w = 24 - i * 5
		P(Vector3.new(4, deckY + 4 - i * 0.6, w), purple, CFrame.new(ctx.c + Vector3.new(43 + i * 4 - 2, (deckY + 4 - i * 0.6) / 2 - 2, sz)), { material = M.WoodPlanks })
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		P(Vector3.new(1.2, 3.4, 1.2), gold, CFrame.new(ctx.c + Vector3.new(60, deckY + 2, sz)) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.6, 0), Kit.decor())
	end
	P(Vector3.new(18, 6, 24), purple, CFrame.new(ctx.c + Vector3.new(-34, deckY + 3, sz)), { material = M.WoodPlanks })
	P(Vector3.new(17.6, 0.4, 23.6), Color3.fromRGB(196, 140, 86), CFrame.new(ctx.c + Vector3.new(-34, deckY + 6.2, sz)), { material = M.WoodPlanks })
	for _, e in ipairs({ { 0, -11.8, 18, 0.6 }, { 0, 11.8, 18, 0.6 }, { -8.8, 0, 0.6, 24 } }) do
		P(Vector3.new(e[3], 1.2, e[4]), gold, CFrame.new(ctx.c + Vector3.new(-34 + e[1], deckY + 7, sz + e[2])), Kit.decor())
	end
	for i = -2, 2 do
		P(Vector3.new(2, 2, 0.3), Color3.fromRGB(255, 220, 140), CFrame.new(ctx.c + Vector3.new(-34 + i * 3.4, deckY + 3.4, sz - 12.1)), Kit.decor({ material = M.Neon, collide = false }))
	end
	Kit.CircusTent(ctx.c + Vector3.new(4, deckY, sz), 0.58)
	local masts = { -18, 24 }
	for _, mx in ipairs(masts) do
		Kit.Flag(ctx.c + Vector3.new(mx, deckY, sz), Color3.fromRGB(230, 60, 60), 26)
	end
	Kit.Bunting(ctx.c + Vector3.new(-18, deckY + 25, sz), ctx.c + Vector3.new(24, deckY + 25, sz))
	-- gangplank from the quay up onto the deck
	local g0, g1 = ctx.c + Vector3.new(28, GROUND + 0.2, QUAY_Z - 3), ctx.c + Vector3.new(28, deckY + 0.2, sz - 10)
	local mid, len = (g0 + g1) / 2, (g1 - g0).Magnitude
	P(Vector3.new(5, 0.6, len), Color3.fromRGB(186, 130, 80), CFrame.lookAt(mid, g1), { material = M.WoodPlanks })
	ctx.reserve(28, QUAY_Z - 6, 6)
end

-- winding dirt paths up both coasts (x = sx * (150 + 18 sin(z / 40))), orange trees and fences along them
local function coastPaths(ctx)
	local rng = Kit.rng
	for _, sx in ipairs({ -1, 1 }) do
		local prevPt
		local k = 0
		for z = QUAY_Z - 10, -90, -14 do
			local pt = ctx.c + Vector3.new(sx * (150 + 18 * math.sin(z / 40)), GROUND, z)
			if prevPt then
				k += 1
				local mid, len = (prevPt + pt) / 2, (pt - prevPt).Magnitude
				-- alternating 0.04 heights: the overlapping bends never share a top face
				P(Vector3.new(9, 0.3, len + 2), DIRT, CFrame.lookAt(mid + Vector3.new(0, 0.1 + (k % 2) * 0.04, 0), pt + Vector3.new(0, 0.1 + (k % 2) * 0.04, 0)), { material = M.Ground })
				if k % 2 == 0 then
					local side = (rng:NextNumber() > 0.5) and 1 or -1
					Kit.RoundTree(mid + Vector3.new(side * 10, 0, 0), rng:NextNumber(0.75, 1), nil, ORANGE_FRUIT)
				end
			end
			prevPt = pt
		end
		-- a lane from the town's cross street out to the path
		P(Vector3.new(44, 0.3, 8), DIRT, CFrame.new(ctx.c + Vector3.new(sx * 143, GROUND + 0.12, 38)), { material = M.Ground })
	end
end

-- forest hill behind the town hall (orange groves), lower wooded lobes at the sides
local function hill(ctx)
	L.Tiers(ctx, {
		{ x = 0, z = -190, r = 56, h = 22, force = true, top = "trees", cap = { dz = -8, r = 36, h = 14 } },
		{ x = -150, z = -150, r = 46, h = 16, force = true, top = "trees", cap = { dx = -8, dz = -8, r = 26, h = 8 } },
		{ x = 150, z = -150, r = 46, h = 16, force = true, top = "trees", cap = { dx = 8, dz = -8, r = 26, h = 8 } },
	})
	local rng = Kit.rng
	for _ = 1, 40 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 50)
		local x, z = math.cos(a) * d, -190 + math.sin(a) * d * 0.9
		Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.85, 1.3), nil, rng:NextNumber() > 0.5 and ORANGE_FRUIT or nil)
	end
end

-- grey boulders all around the shore (some in the surf)
local function shoreRocks(ctx)
	local rng = Kit.rng
	local r = ctx.r
	for i = 1, 54 do
		local a = i / 54 * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local d = r + rng:NextNumber(-14, 22)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local harbor = z > 150 and math.abs(x) < 130
		local docks = math.abs(z) < 30 and math.abs(x) > 200
		if not harbor and not docks then
			local y = d < r - 4 and GROUND - 1 or -0.5
			if i % 3 == 0 then
				Kit.RockCluster(ctx.c + Vector3.new(x, y, z), rng:NextNumber(7, 12))
			else
				Kit.Rock(ctx.c + Vector3.new(x, y, z), rng:NextNumber(6, 13))
			end
		end
	end
end

local function npcs(ctx, api, r)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face or Vector2.new(0, z))
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -22, 132, { SubTitle = "Shop" })
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 22, 132, { SubTitle = "Refine & Cards" })
	put("Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, -22, 86, { SubTitle = "Hire Crew" })
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 22, 86, { SubTitle = "Fast Travel" })
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 176, { SubTitle = "📜 Quests" }, Vector2.new(0, 150))
	local d = Dungeons[ctx.island.dungeon]
	if d then
		put("Dungeon", d.name, Color3.fromRGB(200, 80, 160), "clown", 38, 192, { DungeonId = ctx.island.dungeon, SubTitle = "Dungeon Lv." .. d.minLevel .. "+" }, Vector2.new(38, 150))
	end
	put("Shipwright", "Shipwright", Color3.fromRGB(90, 140, 200), "bandana", r - 30, -40, { SubTitle = "Shipyard & Launch" }, Vector2.new(0, -40))
end

function MT.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	-- the base's "gentle hill" mounds poked up through the paving as green cubes: drop the ones under the town
	for _, o in ipairs(f:GetChildren()) do
		-- matched by size + material (Lune's bake has no default Part.Position / Shape)
		if o:IsA("Part") and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and o.CFrame.Position.Y < 0 then
			local x, z, rr = o.CFrame.Position.X - c.X, o.CFrame.Position.Z, o.Size.X / 2
			if x + rr > TOWN[1] - 6 and x - rr < TOWN[2] + 6 and z + rr > TOWN[3] - 6 and z - rr < QUAY_Z then
				o:Destroy()
			end
		end
	end
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	-- 1. ground: the paved town, the hill behind
	slab(ctx, TOWN, 2, GROUND, PAVE, M.Cobblestone, { name = "Town" })
	hill(ctx)
	-- 2. NPCs first (they reserve their spots), then the landmarks
	npcs(ctx, api, r)
	townHall(ctx)
	clockTower(ctx, 58, -106)
	boulevard(ctx)
	harbor(ctx)
	houseBlocks(ctx)
	coastPaths(ctx)
	-- 3. harbor services: side docks + shipyard
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 4. shore, bushes on the green, chests last (they look for hill tops)
	shoreRocks(ctx)
	for _ = 1, 30 do
		local x, z = Kit.rng:NextNumber(-220, 220), Kit.rng:NextNumber(-60, 200)
		if math.abs(x) > 128 and ctx.free(x, z, 4) then
			Kit.Bush(ctx.at(x, z), Kit.rng:NextNumber(2.5, 4))
		end
	end
	api.placeChests(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 182)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return MT
