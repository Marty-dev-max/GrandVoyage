-- Barracuda Bistro (v0.25.131, owner concept notes: docs/Islands-Concept.md row 4). A round wooden raft at sea.
-- Island coordinates before the island turns: +Z = south = toward Honeyslope (the previous island).
--   Centre: the bistro, a round two-storey hall with mint walls, a striped orange / white stepped roof, a tall
--     mast with striped square sails and a pennant. Ground floor = dining room (rows of tables, doors south + north);
--     a wide balcony ring on top, reached by an outside stair on the east side; the upper room opens south.
--   South: open-air dining deck (tables + striped umbrellas), the spawn, shop + blacksmith, a long pier with rowboats.
--   West: the galley (kitchen house with chimney). East: the store deck (crates, barrels). North: gunners' deck.
-- Our own restaurant: no fish-head bow, no characters or signs from any other work.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local P = Kit.P
local M = Enum.Material

local BB = {}

local GROUND = 8
local MINT = Color3.fromRGB(150, 218, 196)
local MINT_D = Color3.fromRGB(104, 178, 160)
local ORANGE = Color3.fromRGB(240, 128, 60)
local WHITE = Color3.fromRGB(250, 246, 236)
local WOOD = Color3.fromRGB(150, 104, 66)
local WOOD_D = Color3.fromRGB(110, 74, 48)
local GLASS = Color3.fromRGB(60, 96, 130)
local HALL = Vector2.new(0, 0)
local R1, H1 = 34, 11 -- ground floor radius / height
local R2, H2 = 25, 10 -- upper floor
local BAL = 41 -- balcony radius
local N = 20 -- facets per ring

-- a ring of N wall facets around (cx, cz) at height y0 (base) .. y0 + h, facing the centre.
-- skip(i, a) -> true leaves that facet out (doors); color(i) picks the facet color
local function ring(ctx, cx, cz, r, y0, h, thick, color, opts, skip)
	local c = ctx.c + Vector3.new(cx, 0, cz)
	local w = 2 * math.pi * r / N + 0.35
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * math.pi * 2
		if not (skip and skip(i, a)) then
			local pos = c + Vector3.new(math.cos(a) * r, y0 + h / 2, math.sin(a) * r)
			P(Vector3.new(w, h, thick), type(color) == "function" and color(i) or color, CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)), opts or {})
		end
	end
end

-- a round slab of radius r (top at y) made of parallel plank strips clipped to the circle (two squares made a star)
local function disc(ctx, cx, cz, r, y, thick, color, mat, color2)
	local step = 3
	local k = 0
	for x = -r + step / 2, r, step do
		local len = 2 * math.sqrt(math.max(0, r * r - x * x))
		if len > 1 then
			k += 1
			P(Vector3.new(step, thick, len), (color2 and k % 2 == 0) and color2 or color, CFrame.new(ctx.c + Vector3.new(cx + x, y - thick / 2, cz)), { material = mat })
		end
	end
end

local function near(a, target, half)
	local d = math.abs(((a - target + math.pi) % (2 * math.pi)) - math.pi)
	return d < half
end

local SOUTH, NORTH, EAST = math.pi / 2, -math.pi / 2, 0

local function table4(ctx, x, z, cloth)
	local p = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(5, 0.5, 3.6), cloth, CFrame.new(p + Vector3.new(0, 3, 0)), { material = M.Plaster })
	P(Vector3.new(0.7, 2.8, 0.7), WOOD_D, CFrame.new(p + Vector3.new(0, 1.4, 0)), Kit.decor({ material = M.Wood }))
	for _, s in ipairs({ { -2.8, 0 }, { 2.8, 0 }, { 0, -2.6 }, { 0, 2.6 } }) do
		P(Vector3.new(1.4, 1.6, 1.4), WOOD, CFrame.new(p + Vector3.new(s[1], 0.8, s[2])), Kit.decor({ material = M.Wood }))
	end
	P(Vector3.new(0.6, 0.8, 0.6), ORANGE, CFrame.new(p + Vector3.new(0, 3.65, 0)), Kit.decor({ collide = false })) -- a little vase
end

local function umbrella(ctx, x, z, color)
	local p = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(0.4, 8, 0.4), WOOD_D, CFrame.new(p + Vector3.new(0, 4, 0)), Kit.decor({ collide = false, material = M.Wood }))
	for k = 0, 2 do
		local s = 8 - k * 2.6
		P(Vector3.new(s, 0.5, s), (k % 2 == 0) and color or WHITE, CFrame.new(p + Vector3.new(0, 8 + k * 0.5, 0)), Kit.decor({ collide = false, material = M.Plaster }))
	end
end

local function hall(ctx)
	local cx, cz = HALL.X, HALL.Y
	local y1 = GROUND + H1
	-- ground floor: floorboards, mint walls with windows, two doors (south + north)
	disc(ctx, cx, cz, R1 + 0.5, GROUND + 0.3, 0.4, Color3.fromRGB(196, 150, 104), M.WoodPlanks)
	local function door(i, a)
		return near(a, SOUTH, 0.2) or near(a, NORTH, 0.2)
	end
	ring(ctx, cx, cz, R1, GROUND, 3, 1.2, MINT_D, { material = M.WoodPlanks }, door)
	ring(ctx, cx, cz, R1, GROUND + 3, 5, 1, function(i)
		return i % 2 == 0 and GLASS or MINT
	end, { material = M.SmoothPlastic }, door)
	ring(ctx, cx, cz, R1, GROUND + 8, 3, 1.2, MINT, { material = M.WoodPlanks }, door)
	ring(ctx, cx, cz, R1 - 0.2, GROUND + 6.4, 4.6, 1.3, MINT, { material = M.WoodPlanks }, function(i, a)
		return not door(i, a) -- the lintel over each door
	end)
	-- dining room: rows of tables
	for _, row in ipairs({ -16, -6, 4, 14 }) do
		for _, col in ipairs({ -18, -8, 8, 18 }) do
			if Vector2.new(col, row).Magnitude < R1 - 7 then
				table4(ctx, cx + col, cz + row, (row + col) % 20 == 0 and WHITE or Color3.fromRGB(240, 220, 200))
			end
		end
	end
	-- the bar counter on the west wall
	P(Vector3.new(4, 4, 18), WOOD_D, CFrame.new(ctx.c + Vector3.new(cx - R1 + 6, GROUND + 2, cz)), { material = M.Wood })
	-- ceiling = balcony floor (wider than the walls), white rail round it with a gap at the east stair
	disc(ctx, cx, cz, BAL, y1 + 0.8, 0.8, Color3.fromRGB(186, 140, 96), M.WoodPlanks)
	ring(ctx, cx, cz, BAL - 0.6, y1 + 0.8, 3, 0.6, WHITE, { material = M.Wood }, function(i, a)
		return near(a, EAST, 0.22)
	end)
	-- upper room: smaller ring, big windows, opens south
	local y2 = y1 + 0.8
	local function up(i, a)
		return near(a, SOUTH, 0.25)
	end
	ring(ctx, cx, cz, R2, y2, 2.5, 1, MINT_D, { material = M.WoodPlanks }, up)
	ring(ctx, cx, cz, R2, y2 + 2.5, 5, 1, function(i)
		return i % 2 == 1 and GLASS or MINT
	end, {}, up)
	ring(ctx, cx, cz, R2, y2 + 7.5, 2.5, 1, MINT, { material = M.WoodPlanks })
	-- stepped striped roof: rings of facets narrowing upward, orange / white per facet
	local ry = y2 + H2
	disc(ctx, cx, cz, R2 + 2, ry + 0.6, 1.2, WHITE, M.WoodPlanks)
	for k = 0, 4 do
		local rr = R2 + 1 - k * 5
		ring(ctx, cx, cz, rr, ry + 0.6 + k * 2.4, 2.6, 5.5, function(i)
			return i % 2 == 0 and ORANGE or WHITE
		end, { material = M.Plaster })
	end
	disc(ctx, cx, cz, 6, ry + 13.2, 1.4, ORANGE, M.Plaster)
	-- the mast through the roof: two striped square sails and a pennant
	local base = ctx.c + Vector3.new(cx, ry + 12, cz)
	P(Vector3.new(1.6, 36, 1.6), WOOD_D, CFrame.new(base + Vector3.new(0, 18, 0)), { material = M.Wood })
	for _, s in ipairs({ { 12, 20, 14 }, { 26, 14, 10 } }) do
		local y, w, h = s[1], s[2], s[3]
		P(Vector3.new(w + 4, 0.8, 0.8), WOOD_D, CFrame.new(base + Vector3.new(0, y + h / 2 + 0.6, 0)), Kit.decor({ material = M.Wood }))
		local bands = 5
		for b = 0, bands - 1 do
			P(Vector3.new(w, h / bands, 0.4), (b % 2 == 0) and ORANGE or WHITE, CFrame.new(base + Vector3.new(0, y + h / 2 - (b + 0.5) * h / bands, 0.9)), Kit.decor({ collide = false, material = M.Plaster }))
		end
	end
	P(Vector3.new(0.3, 2.4, 7), ORANGE, CFrame.new(base + Vector3.new(0, 35, 3.6)), Kit.decor({ collide = false, material = M.Plaster }))
	-- outside stair on the east side, climbing north to the balcony
	Kit.Stairs(ctx.c + Vector3.new(cx + BAL + 3.5, GROUND, cz + 26), Vector3.new(0, 0, -1), H1 + 0.8, 7, Color3.fromRGB(196, 150, 104))
	Kit.Sign("BARRACUDA BISTRO", CFrame.new(ctx.c + Vector3.new(cx, y1 + 4.4, cz + BAL + 0.4)) * CFrame.Angles(0, math.pi, 0), Vector2.new(22, 3), Color3.fromRGB(255, 240, 200), Color3.fromRGB(70, 120, 110))
	ctx.reserve(cx, cz, BAL + 6)
	ctx.reserve(cx + BAL + 3.5, cz + 14, 10)
end

-- tables on the upper floor stand on the balcony floor
local function upperTables(ctx)
	local y = GROUND + H1 + 0.8
	for _, t in ipairs({ { -10, -8 }, { 10, -8 }, { 0, -15 } }) do
		local p = ctx.c + Vector3.new(HALL.X + t[1], y, HALL.Y + t[2])
		P(Vector3.new(5, 0.5, 3.6), WHITE, CFrame.new(p + Vector3.new(0, 3, 0)), { material = M.Plaster })
		P(Vector3.new(0.7, 2.8, 0.7), WOOD_D, CFrame.new(p + Vector3.new(0, 1.4, 0)), Kit.decor({ material = M.Wood }))
	end
end

-- open-air dining deck south of the hall: tables in rows, striped umbrellas
local function diningDeck(ctx)
	for _, z in ipairs({ 58, 74, 90 }) do
		for _, x in ipairs({ -36, -18, 0, 18, 36 }) do
			table4(ctx, x, z, WHITE)
			umbrella(ctx, x, z, (x / 18) % 2 == 0 and ORANGE or Color3.fromRGB(90, 170, 200))
		end
	end
	ctx.reserve(0, 74, 46)
end

local function galleyAndStores(ctx)
	local g = ctx.c + Vector3.new(-92, GROUND, -36)
	Kit.House(CFrame.lookAt(g, g + Vector3.new(1, 0, 0)), 22, 16, WHITE, Color3.fromRGB(200, 70, 60), { floors = 1, floorHeight = 10, trim = WOOD_D, shutter = MINT_D, sign = "GALLEY" })
	Kit.Barrel(g + Vector3.new(14, 0.5, -10))
	Kit.Barrel(g + Vector3.new(14, 0.5, 10))
	ctx.reserve(-92, -36, 16)
	for _, s in ipairs({ { 86, -30 }, { 100, -44 }, { 78, -52 } }) do
		Kit.CrateStack(ctx.c + Vector3.new(s[1], GROUND, s[2]))
	end
	for k = 0, 5 do
		Kit.Barrel(ctx.c + Vector3.new(96 + (k % 3) * 3.2, GROUND + 0.5, -20 + math.floor(k / 3) * 3.2))
	end
	ctx.reserve(90, -38, 18)
end

-- lamp posts round the hall with striped bunting between them, benches facing the sea
local function lamps(ctx)
	local pts = {}
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.31
		local p = ctx.c + Vector3.new(math.cos(a) * 58, GROUND, math.sin(a) * 58)
		Kit.Lamp(p)
		table.insert(pts, p + Vector3.new(0, 9, 0))
	end
	for i = 1, #pts do
		Kit.Bunting(pts[i], pts[i % #pts + 1], { ORANGE, WHITE, Color3.fromRGB(90, 170, 200) })
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		if not near(a, SOUTH, 0.3) and not near(a, 0, 0.2) and not near(a, math.pi, 0.2) then
			local p = ctx.c + Vector3.new(math.cos(a) * (ctx.r - 12), GROUND, math.sin(a) * (ctx.r - 12))
			Kit.Bench(CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))))
		end
	end
end

-- the raft itself: a round hull of dark planks, a plank deck on top, a white rail with gaps for the pier + docks
local function raft(ctx)
	local r = ctx.r
	disc(ctx, 0, 0, r - 1, GROUND - 0.6, GROUND + 1.4, Color3.fromRGB(96, 64, 42), M.Wood)
	disc(ctx, 0, 0, r, GROUND, 0.6, Color3.fromRGB(184, 134, 88), M.WoodPlanks, Color3.fromRGB(166, 118, 76))
	ring(ctx, 0, 0, r - 1.5, GROUND, 3, 0.8, WHITE, { material = M.Wood }, function(i, a)
		return near(a, SOUTH, 0.09) or near(a, 0, 0.1) or near(a, math.pi, 0.1)
	end)
	ctx.foam(ctx.c + Vector3.new(0, 0.1, 0), r * 2 + 10)
end

-- the long pier south, rowboats tied up, lamps
local function pier(ctx)
	local z0, z1 = ctx.r - 6, ctx.r + 60
	P(Vector3.new(12, 0.8, z1 - z0), Color3.fromRGB(176, 126, 82), CFrame.new(ctx.c + Vector3.new(0, GROUND - 0.4, (z0 + z1) / 2)), { material = M.WoodPlanks })
	for z = z0 + 6, z1, 9 do
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(1.3, GROUND + 6, 1.3), WOOD_D, CFrame.new(ctx.c + Vector3.new(sx * 6.4, (GROUND + 6) / 2 - 3, z)), { material = M.Wood })
		end
	end
	for _, b in ipairs({ { -13, z0 + 26, 0.2 }, { 13, z0 + 40, -0.25 }, { -13, z0 + 52, -0.1 } }) do
		Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(b[1], 0.4, b[2])) * CFrame.Angles(0, b[3], 0), Color3.fromRGB(240, 128, 60))
	end
	Kit.Lamp(ctx.c + Vector3.new(5, GROUND - 0.4, z1 - 2))
	Kit.Lamp(ctx.c + Vector3.new(-5, GROUND - 0.4, z0 + 20))
end

-- life rings on the rail, crates and barrels round the edge
local function deckDressing(ctx)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		if not near(a, SOUTH, 0.15) and not near(a, 0, 0.15) and not near(a, math.pi, 0.15) then
			local p = ctx.c + Vector3.new(math.cos(a) * (ctx.r - 4.2), GROUND + 3, math.sin(a) * (ctx.r - 4.2))
			for k = 0, 3 do
				local b = k * math.pi / 2
				P(Vector3.new(1, 1, 1.6), k % 2 == 0 and Color3.fromRGB(240, 80, 70) or WHITE, CFrame.lookAt(p, ctx.c + Vector3.new(0, p.Y, 0)) * CFrame.new(math.cos(b) * 1.3, math.sin(b) * 1.3, 0), Kit.decor({ collide = false }))
			end
		end
	end
end

local function npcs(ctx, api)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face or Vector2.new(0, 124))
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -26, 114, { SubTitle = "Shop" })
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 26, 114, { SubTitle = "Refine & Cards" })
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 48, 124, { SubTitle = "Fast Travel" })
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 134, { SubTitle = "📜 Quests" })
end

function BB.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	raft(ctx) -- our own round plank raft (the base's big cylinder turned into a sandy cross when voxelized)
	npcs(ctx, api)
	hall(ctx)
	upperTables(ctx)
	diningDeck(ctx)
	galleyAndStores(ctx)
	lamps(ctx)
	pier(ctx)
	deckDressing(ctx)
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	api.placeChests(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 124)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return BB
