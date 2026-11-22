-- Conch Bay (v0.25.22, owner concept art: overhead = placement, aerial = elevation, market view = street level).
-- Island coordinates before the island turns: +Z = south = the long pier.
--   Waterfront (7.6): cream paved quay, striped stalls either side of the axis, a T-shaped pier to the south.
--   Terrace 1 (+7) and Terrace 2 (+14): cream stone retaining walls, rows of cream stucco houses with teal shutters and
--     terracotta / blue roofs, doors to the sea, side stairs at the ends.
--   Garrison plateau (+21): walled compound, gate on the axis, open sand courtyard, training lawn, buildings along the
--     walls, two tapered blue towers with outside spiral stairs. The tall one stands on the axis, so from the market it
--     shows between the rooftops and leads you up the stairs.
--   Wooded cliffs (rock lobes with trees) behind it, to the north and the sides, higher than the garrison.
-- One straight stairway on the axis: quay -> T1 -> T2 -> gate. Our own names; no emblem on towers or banners.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P, Cyl = Kit.P, Kit.Cyl
local M = Enum.Material

local CB = {}

-- palette (from the concept art)
local STUCCO = Color3.fromRGB(240, 228, 202)
local STONE = Color3.fromRGB(226, 212, 182)
local PAVE = Color3.fromRGB(222, 206, 172)
local SHUTTER = Color3.fromRGB(46, 140, 140)
local TRIM = Color3.fromRGB(150, 118, 88)
local ROOFS = { Color3.fromRGB(204, 98, 62), Color3.fromRGB(62, 100, 190), Color3.fromRGB(196, 84, 56), Color3.fromRGB(72, 112, 200), Color3.fromRGB(214, 120, 70) }
local TOWER, TOWER_D = Color3.fromRGB(100, 150, 215), Color3.fromRGB(70, 115, 185)
local AWNINGS = { Color3.fromRGB(170, 90, 210), Color3.fromRGB(80, 180, 100), Color3.fromRGB(240, 200, 50), Color3.fromRGB(225, 70, 70), Color3.fromRGB(60, 140, 220) }
local SAND = Color3.fromRGB(226, 196, 140)
local WOOD = Color3.fromRGB(120, 80, 50)

local GROUND = 7.6 -- quay (the island's grass top is 7.5)
local T1, T2, TOP = GROUND + 7, GROUND + 14, GROUND + 21
-- footprints { x0, x1, z0, z1 } in island coordinates
local QUAY = { -150, 150, 170, 234 }
local TER1 = { -135, 135, 105, 170 }
local TER2 = { -115, 115, 40, 105 }
local PLATEAU = { -105, 105, -120, 40 }
local FORT = { -92, 92, -110, 32 } -- garrison walls
local STAIR_W = 12
local SIDE1, SIDE2 = 122, 102 -- x of the side stairs up to T1 and T2

-- terraces are boxes: teach ctx.height about them so ctx.at() lands on the right level
local function withRects(ctx)
	local rects = {}
	local base = ctx.height
	ctx.height = function(x, z)
		local h = base(x, z)
		for _, r in ipairs(rects) do
			if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] and r[5] > h then
				h = r[5]
			end
		end
		return h
	end
	return function(r, top)
		table.insert(rects, { r[1], r[2], r[3], r[4], top })
	end
end

local function block(ctx, r, y0, y1, color, mat, name)
	local c = Vector3.new((r[1] + r[2]) / 2, (y0 + y1) / 2, (r[3] + r[4]) / 2)
	return P(Vector3.new(r[2] - r[1], y1 - y0, r[4] - r[3]), color, CFrame.new(ctx.c + c), { material = mat, name = name })
end

-- a terrace: a stone block (its front is the retaining wall), paved top, light coping along the front edge
local function terrace(ctx, addRect, r, top)
	block(ctx, r, 2, top - 0.6, STONE, M.Brick)
	block(ctx, r, top - 0.6, top, PAVE, M.Cobblestone)
	P(Vector3.new(r[2] - r[1] + 1, 0.8, 1.6), STUCCO, CFrame.new(ctx.c + Vector3.new((r[1] + r[2]) / 2, top + 0.4, r[4] - 0.4)), Kit.decor({ material = M.Brick }))
	addRect(r, top)
end

-- straight flight against a south-facing wall at wallZ, from `low` up to `high`, centered on x
local function flight(ctx, x, wallZ, low, high, width)
	local run = math.ceil((high - low) / 1.25) * 2.3
	Kit.Stairs(ctx.c + Vector3.new(x, low, wallZ + run), Vector3.new(0, 0, -1), high - low, width or STAIR_W, PAVE)
	ctx.reserve(x, wallZ + run / 2, run / 2 + 4)
	return run
end

local function house(ctx, x, z, w, d, roof, floors)
	local pos = ctx.at(x, z)
	Kit.House(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), w, d, STUCCO, roof, { floors = floors, shutter = SHUTTER, trim = TRIM, stone = STONE })
	ctx.reserve(x, z, math.max(w, d) * 0.6)
end

-- a tapered tower: stacked rings narrowing upward, an outside stair spiralling up, balcony + lantern + flag on top
local function taperedTower(ctx, x, z, base, height, d0, d1)
	local p = ctx.c + Vector3.new(x, base, z)
	local rings = math.floor(height / 4)
	local function radius(h)
		return (d0 + (d1 - d0) * math.clamp(h / height, 0, 1)) / 2
	end
	for i = 0, rings - 1 do
		Cyl(4.2, radius(i * 4) * 2, (i % 4 == 3) and TOWER_D or TOWER, p + Vector3.new(0, i * 4 + 2, 0), { material = M.Brick })
	end
	for i = 1, rings - 2, 2 do -- dark window slits
		local rr = radius(i * 4)
		for j = 0, 3 do
			local a = j * math.pi / 2 + i * 0.4
			P(Vector3.new(1.6, 2.4, 0.4), Color3.fromRGB(40, 50, 80), CFrame.new(p + Vector3.new(math.cos(a) * rr, i * 4 + 2, math.sin(a) * rr)) * CFrame.Angles(0, -a + math.pi / 2, 0), Kit.decor({ collide = false }))
		end
	end
	-- outside stair: 1.25-stud steps spiralling up against the wall, a rail post on every other step
	local steps = math.floor(height / 1.25)
	for s = 0, steps - 1 do
		local h = s * 1.25
		local rr = radius(h) + 2
		local a = s * 0.22
		local at = p + Vector3.new(math.cos(a) * rr, h + 0.6, math.sin(a) * rr)
		P(Vector3.new(4, 0.6, 4.4), PAVE, CFrame.new(at) * CFrame.Angles(0, -a, 0), { material = M.Cobblestone })
		if s % 2 == 0 then
			P(Vector3.new(0.4, 3, 0.4), WOOD, CFrame.new(at + Vector3.new(math.cos(a) * 2, 1.5, math.sin(a) * 2)), Kit.decor({ collide = false }))
		end
	end
	local topY = base + rings * 4
	Cyl(1, d1 + 5, STONE, ctx.c + Vector3.new(x, topY + 0.5, z), { material = M.Brick })
	Cyl(5, d1 * 0.45, STUCCO, ctx.c + Vector3.new(x, topY + 3.5, z), {})
	Cyl(2, d1 * 0.55, Color3.fromRGB(230, 190, 70), ctx.c + Vector3.new(x, topY + 7, z), {})
	Kit.Flag(ctx.c + Vector3.new(x, topY + 8, z), TOWER_D, 8)
	ctx.reserve(x, z, d0 / 2 + 5)
	return topY
end

local function garrison(ctx)
	local h = 12
	block(ctx, FORT, TOP - 0.2, TOP + 0.15, SAND, M.Sand) -- the open courtyard
	local function wall(x0, x1, z0, z1)
		block(ctx, { x0, x1, z0, z1 }, TOP, TOP + h, STONE, M.Brick)
		local alongX = (x1 - x0) > (z1 - z0)
		local len = alongX and (x1 - x0) or (z1 - z0)
		for k = 0, math.floor(len / 6) - 1 do
			local o = (alongX and x0 or z0) + 3 + k * 6
			local pos = alongX and Vector3.new(o, TOP + h + 1, (z0 + z1) / 2) or Vector3.new((x0 + x1) / 2, TOP + h + 1, o)
			P(Vector3.new(3, 2, 3), STONE, CFrame.new(ctx.c + pos), Kit.decor({ material = M.Brick }))
		end
	end
	local gap = 8
	wall(FORT[1], FORT[2], FORT[3], FORT[3] + 3) -- north
	wall(FORT[1], FORT[1] + 3, FORT[3], FORT[4]) -- west
	wall(FORT[2] - 3, FORT[2], FORT[3], FORT[4]) -- east
	wall(FORT[1], -gap, FORT[4] - 3, FORT[4]) -- south, gate in the middle
	wall(gap, FORT[2], FORT[4] - 3, FORT[4])
	for _, corner in ipairs({ { FORT[1], FORT[3] }, { FORT[2], FORT[3] }, { FORT[1], FORT[4] }, { FORT[2], FORT[4] } }) do
		Kit.Tower(ctx.c + Vector3.new(corner[1], TOP, corner[2]), 9, h + 6, STONE, ROOFS[2], { material = M.Brick })
	end
	-- the gate: pillars, lintel, plain blue banners, two guard huts outside
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(5, h + 6, 5), STONE, CFrame.new(ctx.c + Vector3.new(sx * (gap + 1.5), TOP + (h + 6) / 2, FORT[4] - 1.5)), { material = M.Brick })
		P(Vector3.new(3, 8, 0.3), TOWER_D, CFrame.new(ctx.c + Vector3.new(sx * (gap + 6), TOP + h - 3, FORT[4] + 0.3)), Kit.decor({ material = M.Fabric, collide = false }))
		local hut = ctx.at(sx * 18, FORT[4] + 4)
		Kit.House(CFrame.lookAt(hut, hut + Vector3.new(0, 0, 1)), 5, 5, STUCCO, ROOFS[2], { stone = STONE, trim = TRIM, chimney = false })
	end
	P(Vector3.new(gap * 2 + 8, 4, 5), STONE, CFrame.new(ctx.c + Vector3.new(0, TOP + h + 2, FORT[4] - 1.5)), { material = M.Brick })
	Kit.Sign("CONCH BAY GARRISON", CFrame.new(ctx.c + Vector3.new(0, TOP + h + 2, FORT[4] + 1.4)) * CFrame.Angles(0, math.pi, 0), Vector2.new(18, 2.4), Color3.fromRGB(255, 240, 190))
	-- barracks and stores along the north and side walls, doors to the yard
	for i, x in ipairs({ -70, -48, -24, 24, 48, 70 }) do
		local pos = ctx.at(x, FORT[3] + 12)
		Kit.House(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), 16, 12, STUCCO, ROOFS[i % 2 + 1], { stone = STONE, shutter = SHUTTER, trim = TRIM })
	end
	for _, sx in ipairs({ -1, 1 }) do
		for i, z in ipairs({ -62, -36 }) do
			local pos = ctx.at(sx * (FORT[2] - 12), z)
			Kit.House(CFrame.lookAt(pos, pos + Vector3.new(-sx, 0, 0)), 16, 12, STUCCO, ROOFS[i % 2 + 1], { stone = STONE, shutter = SHUTTER, trim = TRIM })
		end
	end
	-- training lawn (riflemen drill here), practice posts, crates
	P(Vector3.new(34, 0.3, 24), Color3.fromRGB(110, 190, 90), CFrame.new(ctx.c + Vector3.new(-52, TOP + 0.3, -2)), { material = M.Grass })
	for i = 0, 3 do
		local p = ctx.c + Vector3.new(-64 + i * 8, TOP, -12)
		P(Vector3.new(1.2, 5, 1.2), Color3.fromRGB(150, 105, 65), CFrame.new(p + Vector3.new(0, 2.5, 0)), { material = M.Wood })
		P(Vector3.new(4, 1, 1), Color3.fromRGB(150, 105, 65), CFrame.new(p + Vector3.new(0, 4, 0)), { material = M.Wood })
	end
	Kit.CrateStack(ctx.c + Vector3.new(64, TOP, 14))
	Kit.Barrel(ctx.c + Vector3.new(70, TOP + 0.5, 20))
	for _, t in ipairs({ { -36, -84 }, { 36, -84 }, { -80, 20 }, { 78, -6 } }) do
		Kit.RoundTree(ctx.c + Vector3.new(t[1], TOP, t[2]), 0.9)
	end
	-- the two tapered towers: the tall one on the axis (seen from the market), a shorter one beside it
	-- 84 tall: from the quay its top clears the single-storey front row of terrace 1
	taperedTower(ctx, 0, -58, TOP, 84, 36, 18)
	taperedTower(ctx, 44, -40, TOP, 48, 24, 13)
end

-- the waterfront: quay paving, seawall, bollards, lamps, two groups of stalls, the T pier
local function waterfront(ctx)
	block(ctx, QUAY, 2, GROUND, PAVE, M.Cobblestone, "Quay")
	P(Vector3.new(QUAY[2] - QUAY[1], 9, 3), STONE, CFrame.new(ctx.c + Vector3.new(0, GROUND - 4.6, QUAY[4] + 1.5)), { material = M.Brick })
	for x = QUAY[1] + 8, QUAY[2] - 8, 16 do
		if math.abs(x) > 10 then
			Cyl(1.6, 1.6, Color3.fromRGB(60, 60, 70), ctx.c + Vector3.new(x, GROUND + 0.8, QUAY[4] - 2), Kit.decor())
		end
	end
	for x = QUAY[1] + 20, QUAY[2] - 20, 40 do
		Kit.Lamp(ctx.c + Vector3.new(x, GROUND, QUAY[4] - 6))
	end
	-- stalls face the sea in two rows either side of the axis; the walk from the pier to the stairs stays open
	local k = 0
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			k += 1
			local x = sx * (26 + i * 15)
			Kit.Stall(CFrame.new(ctx.c + Vector3.new(x, GROUND, 204)) * CFrame.Angles(0, math.pi, 0), AWNINGS[k % #AWNINGS + 1])
			ctx.reserve(x, 204, 6)
		end
	end
	-- T-shaped pier
	local z0, z1 = QUAY[4], QUAY[4] + 70
	for i = 0, (z1 - z0) / 5 - 1 do
		P(Vector3.new(12, 1, 4.6), Color3.fromRGB(190, 135, 85):Lerp(Color3.fromRGB(160, 110, 70), i % 2), CFrame.new(ctx.c + Vector3.new(0, GROUND - 0.5, z0 + i * 5 + 2.5)), { material = M.WoodPlanks })
	end
	local crossZ = z1 - 8
	P(Vector3.new(56, 1, 8), Color3.fromRGB(180, 128, 80), CFrame.new(ctx.c + Vector3.new(0, GROUND - 0.55, crossZ)), { material = M.WoodPlanks })
	for z = z0 + 6, z1, 10 do
		for _, sx in ipairs({ -6, 6 }) do
			Cyl(16, 1.8, WOOD, ctx.c + Vector3.new(sx, -1, z), { material = M.Wood })
		end
	end
	for _, sx in ipairs({ -27, 27 }) do
		Cyl(16, 1.8, WOOD, ctx.c + Vector3.new(sx, -1, crossZ), { material = M.Wood })
		Kit.Lamp(ctx.c + Vector3.new(sx, GROUND - 0.05, crossZ))
	end
	Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(16, 0.3, z0 + 26)))
	Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(-16, 0.3, z0 + 40)), Color3.fromRGB(90, 150, 210))
	Kit.CrateStack(ctx.c + Vector3.new(-22, GROUND, QUAY[4] - 8))
	Kit.Barrel(ctx.c + Vector3.new(22, GROUND + 0.5, QUAY[4] - 8))
end

-- rows of houses on a terrace (doors to the sea), clear of the central stairs and the side stairs
local function houseRows(ctx, rx, rows, sideXs)
	local rng = Kit.rng
	for _, row in ipairs(rows) do
		local z, maxFloors = row[1], row[2]
		local x = rx[1] + 10
		while x < rx[2] - 8 do
			local w = rng:NextNumber(13, 17)
			local cx = x + w / 2
			local clear = math.abs(cx) > STAIR_W / 2 + w / 2 + 3
			for _, sxv in ipairs(sideXs) do
				clear = clear and math.abs(math.abs(cx) - sxv) > 4 + w / 2 + 3
			end
			if clear then -- no ctx.free: the street spawns (v0.25.23) are reserved and would delete the houses
				house(ctx, cx, z, w, rng:NextNumber(11, 12.5), ROOFS[rng:NextInteger(1, #ROOFS)], (rng:NextNumber() > 0.5 and maxFloors > 1) and 2 or 1)
				if rng:NextNumber() > 0.6 then -- a planter tree beside the door, never in the stair corridor
					local tx = cx + (w / 2 + 2) * (rng:NextNumber() > 0.5 and 1 or -1)
					if math.abs(tx) > STAIR_W / 2 + 3 then
						Kit.RoundTree(ctx.at(tx, z + 8), 0.55)
					end
				end
			end
			x += w + 4
		end
	end
end

-- wooded cliffs behind and beside the garrison, higher than it; the docks (z 0) and the shipyard stay open
local function cliffs(ctx)
	L.Tiers(ctx, {
		{ x = 0, z = -178, r = 62, h = 30, force = true, top = "trees", cap = { dz = -8, r = 40, h = 8 } },
		-- v0.25.25: NW lobe pulled in behind the garrison, the harbor dock + shipyard now turn to that side (next island)
		{ x = -60, z = -205, r = 34, h = 26, force = true, top = "trees", cap = { dx = -4, dz = -6, r = 20, h = 8 } },
		{ x = 150, z = -150, r = 55, h = 26, force = true, top = "trees", cap = { dx = 8, dz = -6, r = 34, h = 8 } },
		{ x = -178, z = -92, r = 34, h = 18, force = true, top = "trees" },
		{ x = 178, z = -92, r = 34, h = 18, force = true, top = "trees" },
	})
end

-- NPCs on the quay in front of the first terrace wall; the guide meets you at the pier head
local function npcs(ctx, api)
	local Quests = require(game:GetService("ReplicatedStorage").Shared.Config.Quests)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face or Vector2.new(x, 260))
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -60, 182, { SubTitle = "Shop" })
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 60, 182, { SubTitle = "Refine & Cards" })
	put("Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, -95, 182, { SubTitle = "Hire Crew" })
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 95, 182, { SubTitle = "Fast Travel" })
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", 16, 224, { SubTitle = "📜 Quests" }, Vector2.new(0, 300))
end

function CB.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	-- the base's random grass mounds turn into big cubes and blocked the west way to the harbor (v0.25.25): drop them
	-- (matched by size + material: Lune's bake has no default Part.Position / Shape)
	for _, o in ipairs(f:GetChildren()) do
		if o:IsA("Part") and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and o.CFrame.Position.Y < 0 then
			o:Destroy()
		end
	end
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	local addRect = withRects(ctx)
	-- 1. elevation: plateau, two terraces, the quay; wooded cliffs behind
	block(ctx, PLATEAU, 2, TOP - 1.2, Color3.fromRGB(150, 138, 120), M.Slate)
	block(ctx, PLATEAU, TOP - 1.2, TOP, Color3.fromRGB(118, 190, 92), M.Grass)
	addRect(PLATEAU, TOP)
	terrace(ctx, addRect, TER2, T2)
	terrace(ctx, addRect, TER1, T1)
	addRect(QUAY, GROUND)
	cliffs(ctx)
	-- 2. the route: one straight stairway on the axis, side stairs at the terrace ends, lamps at every landing
	flight(ctx, 0, TER1[4], GROUND, T1)
	flight(ctx, 0, TER2[4], T1, T2)
	flight(ctx, 0, PLATEAU[4], T2, TOP)
	for _, sx in ipairs({ -1, 1 }) do
		flight(ctx, sx * SIDE1, TER1[4], GROUND, T1, 8)
		flight(ctx, sx * SIDE2, TER2[4], T1, T2, 8)
		for _, z in ipairs({ TER1[4] - 3, TER2[4] - 3, PLATEAU[4] - 3 }) do
			Kit.Lamp(ctx.at(sx * (STAIR_W / 2 + 2), z))
		end
	end
	-- 3. NPCs before anything that checks free ground
	npcs(ctx, api)
	-- 4. the garrison, the waterfront, the houses
	garrison(ctx)
	waterfront(ctx)
	-- the front row by the quay stays single-storey so the tall tower shows over it from the market
	houseRows(ctx, TER1, { { 156, 1 }, { 128, 2 } }, { SIDE1, SIDE2 })
	houseRows(ctx, TER2, { { 92, 2 }, { 64, 2 } }, { SIDE2 })
	-- 5. harbor services: side docks + shipyard
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 6. trees on the plateau rim, palms on the quay ends, the coast, chests last (they look for cliff tops)
	for _, t in ipairs({ { -100, 30 }, { 100, 30 }, { -100, -40 }, { 100, -40 }, { -100, -110 }, { 100, -110 } }) do
		Kit.RoundTree(ctx.at(t[1], t[2]), 1.1)
	end
	for _, x in ipairs({ -142, 142 }) do
		Kit.Palm(ctx.at(x, 196))
		Kit.Palm(ctx.at(x, 222))
	end
	L.Coast(ctx, 18)
	for _ = 1, 40 do -- trees on the side meadows only (L.Greenery would also hit the quay and terraces)
		local sx = Kit.rng:NextNumber() > 0.5 and 1 or -1
		local x, z = sx * Kit.rng:NextNumber(152, 232), Kit.rng:NextNumber(-50, 150)
		if ctx.free(x, z, 5) and ctx.height(x, z) < GROUND + 1 then
			Kit.RoundTree(ctx.at(x, z), Kit.rng:NextNumber(0.85, 1.25))
			ctx.reserve(x, z, 5)
		end
	end
	api.placeChests(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 214)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end


return CB
