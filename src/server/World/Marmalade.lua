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
local SHIP_Z = 302 -- circus ship at anchor off the south shore (past the beach lobes)
local SHIP_DECK = GROUND + 1.4

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
		if math.abs(x) < 7 then -- the pier starts here
			continue
		end
		Cyl(1.6, 1.6, Color3.fromRGB(60, 60, 70), ctx.c + Vector3.new(x, GROUND + 0.8, QUAY_Z - 2), Kit.decor())
	end
	Kit.CrateStack(ctx.c + Vector3.new(-70, GROUND, QUAY_Z - 8))
	Kit.Barrel(ctx.c + Vector3.new(-62, GROUND + 0.5, QUAY_Z - 6))
	Kit.CrateStack(ctx.c + Vector3.new(84, GROUND, QUAY_Z - 9))
	-- v0.25.25 (owner): Captain Confetti's circus ship lies at anchor OFF the island; a long pier on the boulevard
	-- axis leads out to it. Decor only (not a sailing ship): hull along x, deck at SHIP_DECK.
	local sx0, sz = 0, SHIP_Z
	local deckY = SHIP_DECK
	local purple, dark, wood = Color3.fromRGB(122, 48, 124), Color3.fromRGB(80, 30, 84), Color3.fromRGB(196, 140, 86)
	local function at(x, y, z)
		return CFrame.new(ctx.c + Vector3.new(sx0 + x, y, sz + z))
	end
	-- stepped V-hull, one slice every 4 studs: half-width follows the profile, the deck line rises at bow and stern
	local L = 92
	for i = 0, L / 4 - 1 do
		local x = -L / 2 + 2 + i * 4
		local t = (x + L / 2) / L -- 0 stern .. 1 bow
		local hw = 13 * math.clamp(math.min(t / 0.12, (1 - t) / 0.3), 0.25, 1)
		local sheer = (t > 0.8 and (t - 0.8) * 22 or 0) + (t < 0.15 and (0.15 - t) * 16 or 0)
		local top = deckY + sheer
		P(Vector3.new(4.05, 4, hw * 1.1), dark, at(x, -4, 0), { material = M.WoodPlanks })
		P(Vector3.new(4.05, 4, hw * 1.6), purple, at(x, 0, 0), { material = M.WoodPlanks })
		P(Vector3.new(4.05, top - 2, hw * 2), purple, at(x, (top + 2) / 2, 0), { material = M.WoodPlanks })
		P(Vector3.new(4.05, 0.6, hw * 2 - 1.4), wood, at(x, top + 0.3, 0), { material = M.WoodPlanks })
		for _, side in ipairs({ -1, 1 }) do
			P(Vector3.new(4.05, 0.7, 0.4), GOLD, at(x, 4.6, side * hw), Kit.decor()) -- gold stripe
			if not (side < 0 and math.abs(x) <= 4) then -- the gangplank boards through a gap on the pier side
				P(Vector3.new(4.05, 1.6, 0.6), purple, at(x, top + 1.1, side * (hw - 0.3)), { material = M.WoodPlanks }) -- bulwark
			end
			if i % 2 == 0 and t > 0.15 and t < 0.85 then
				P(Vector3.new(1.4, 1.4, 0.3), Color3.fromRGB(40, 30, 40), at(x, 2.2, side * hw), Kit.decor({ collide = false })) -- porthole
			end
		end
	end
	-- stern castle with lit windows and lanterns
	P(Vector3.new(16, 7, 23), purple, at(-36, deckY + 4, 0), { material = M.WoodPlanks })
	P(Vector3.new(16.4, 0.6, 23.4), wood, at(-36, deckY + 7.8, 0), { material = M.WoodPlanks })
	for i = -2, 2 do
		P(Vector3.new(0.3, 2, 2.4), Color3.fromRGB(255, 220, 140), at(-44.1, deckY + 4.5, i * 4), Kit.decor({ material = M.Neon, collide = false }))
	end
	for _, side in ipairs({ -1, 1 }) do
		P(Vector3.new(1.2, 1.6, 1.2), Color3.fromRGB(255, 200, 90), at(-44, deckY + 9.4, side * 10), Kit.decor({ material = M.Neon, collide = false }))
	end
	-- bowsprit + gold star figurehead
	local bow = at(L / 2 + 4, deckY + 9, 0)
	P(Vector3.new(16, 1, 1), Color3.fromRGB(120, 80, 50), bow * CFrame.Angles(0, 0, math.rad(18)), { material = M.Wood })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		P(Vector3.new(1.4, 3.6, 0.8), GOLD, at(L / 2 - 1, deckY + 4, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.7, 0), Kit.decor())
	end
	-- the big top on deck, two masts with striped square sails, a crow's nest, pennants and bunting
	Kit.CircusTent(ctx.c + Vector3.new(sx0 + 12, deckY + 0.6, sz), 0.55) -- toward the bow: the gangplank lands at x 0
	for _, mx in ipairs({ -22, 28 }) do
		P(Vector3.new(1.6, 36, 1.6), Color3.fromRGB(120, 80, 50), at(mx, deckY + 18, 0), { material = M.Wood })
		P(Vector3.new(1, 1, 22), Color3.fromRGB(120, 80, 50), at(mx, deckY + 28, 0), { material = M.Wood })
		P(Vector3.new(1, 1, 18), Color3.fromRGB(120, 80, 50), at(mx, deckY + 16, 0), { material = M.Wood })
		for k = 0, 5 do
			local z = -10 + k * 3.6 + 1.8
			P(Vector3.new(0.4, 11.4, 3.6), k % 2 == 0 and Color3.fromRGB(225, 55, 60) or Color3.fromRGB(250, 246, 236), at(mx + 0.9, deckY + 22, z), { material = M.Fabric, collide = false })
		end
		P(Vector3.new(5, 1.6, 5), Color3.fromRGB(150, 100, 60), at(mx, deckY + 32, 0), { material = M.WoodPlanks })
		P(Vector3.new(0.3, 2.4, 4), Color3.fromRGB(240, 196, 70), at(mx + 2, deckY + 37, 0), Kit.decor({ material = M.Fabric, collide = false }))
	end
	Kit.Bunting(ctx.c + Vector3.new(sx0 - 22, deckY + 30, sz), ctx.c + Vector3.new(sx0 + 28, deckY + 30, sz))
	Kit.Bunting(ctx.c + Vector3.new(sx0 + 28, deckY + 30, sz), ctx.c + Vector3.new(sx0 + L / 2 + 10, deckY + 12, sz))
	-- anchor chain into the water
	P(Vector3.new(0.6, 10, 0.6), Color3.fromRGB(70, 70, 76), at(L / 2 - 8, 1, -12.5) * CFrame.Angles(0.3, 0, 0), Kit.decor({ material = M.Metal, collide = false }))
	-- the pier: quay -> ship, on the boulevard axis, piles every 10 studs, lamps, then a gangplank up to the deck
	local p0, p1 = QUAY_Z, sz - 16
	for i = 0, math.floor((p1 - p0) / 5) - 1 do
		P(Vector3.new(10, 1, 4.6), Color3.fromRGB(190, 135, 85):Lerp(Color3.fromRGB(160, 110, 70), i % 2), CFrame.new(ctx.c + Vector3.new(0, GROUND - 0.5, p0 + i * 5 + 2.5)), { material = M.WoodPlanks })
	end
	for z = p0 + 8, p1, 10 do
		for _, px in ipairs({ -5, 5 }) do
			Cyl(16, 1.6, Color3.fromRGB(120, 80, 50), ctx.c + Vector3.new(px, -1, z), { material = M.Wood })
		end
	end
	for z = p0 + 20, p1, 30 do
		Kit.Lamp(ctx.c + Vector3.new(-4.4, GROUND - 0.05, z))
	end
	local g0, g1 = ctx.c + Vector3.new(0, GROUND + 0.1, p1 - 1), ctx.c + Vector3.new(0, deckY + 0.7, sz - 9)
	local mid, len = (g0 + g1) / 2, (g1 - g0).Magnitude
	P(Vector3.new(5, 0.6, len), Color3.fromRGB(186, 130, 80), CFrame.lookAt(mid, g1), { material = M.WoodPlanks })
	ctx.reserve(0, QUAY_Z - 6, 6)
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

local function npcs(ctx, api)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face or Vector2.new(0, z))
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -22, 132, { SubTitle = "Shop" })
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 22, 132, { SubTitle = "Refine & Cards" })
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 22, 86, { SubTitle = "Fast Travel" })
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 176, { SubTitle = "📜 Quests" }, Vector2.new(0, 150))
	local d = Dungeons[ctx.island.dungeon]
	if d then
		put("Dungeon", d.name, Color3.fromRGB(200, 80, 160), "clown", 12, 192, { DungeonId = ctx.island.dungeon, SubTitle = "Dungeon Lv." .. d.minLevel .. "+" }, Vector2.new(12, 150))
	end
end

function MT.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	-- the base's "gentle hill" mounds poked up through the paving as green cubes: drop them
	for _, o in ipairs(f:GetChildren()) do
		-- matched by size + material (Lune's bake has no default Part.Position / Shape)
		local pos = o:IsA("Part") and o.CFrame.Position
		if pos and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and pos.Y < 0 then
			o:Destroy() -- all of them: out on the meadows they read as stray green boxes too
		elseif pos and pos.Z > 150 and math.abs(pos.X - c.X) < 170 and Vector2.new(pos.X - c.X, pos.Z).Magnitude > 60 then
			-- v0.25.25: the beach lobes (and their foam rings) off the harbor: open water for the circus ship
			if (o.Material == M.Sand and o.Size.X == 14) or o.Name == "Foam" then
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
	npcs(ctx, api)
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
