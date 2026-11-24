-- Mikan Isles (v0.25.132, owner concept notes: docs/Islands-Concept.md row 5). Island coordinates before the island
-- turns: +Z = south = the harbor (faces Barracuda Bistro, the previous island).
--   South: wooden jetty, the spawn with shop + blacksmith, a small village round a cobbled plaza.
--   West: tangerine groves in rows. East: round rice paddies (rings of water and rice) in several pools.
--   North: Sawtooth Park, the Sawtooth Overlord's walled waterside palace: coral walls with scallop-shell crests,
--   a main gate south, a WATER GATE north where a canal runs out to the sea, a tall tiered hall, a pool with a
--   pavilion, the boss courtyard. South-west shore: an old wreck.
-- Our own palace: no shark-teeth roofs or shark marks, no buildings from any other work.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)
local P = Kit.P
local M = Enum.Material

local MK = {}

local GROUND = 7.6
local DIRT = Color3.fromRGB(206, 170, 112)
local CORAL = Color3.fromRGB(236, 128, 108)
local CORAL_D = Color3.fromRGB(196, 92, 80)
local CREAM = Color3.fromRGB(250, 238, 214)
local SHELL = Color3.fromRGB(255, 214, 196)
local STONE = Color3.fromRGB(200, 190, 172)
local WATER = Color3.fromRGB(64, 168, 214)
local RICE = Color3.fromRGB(132, 196, 80)
local TRIM = Color3.fromRGB(116, 80, 54)
local ORANGE = Color3.fromRGB(255, 150, 20)
local PAL = { x = 20, z = -165, hx = 62, hz = 50 } -- the palace compound (center + half sizes)

local function v(x, z)
	return Vector2.new(x, z)
end

-- a dirt road through points (x, z): overlapping segments at alternating heights (no shared top faces)
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

-- a round slab of parallel strips clipped to the circle (one big cylinder voxelizes into a plus, two squares a star)
local function disc(ctx, cx, cz, r, y, thick, color, opts)
	local step = 3
	for x = -r + step / 2, r, step do
		local len = 2 * math.sqrt(math.max(0, r * r - x * x))
		if len > 1 then
			P(Vector3.new(step, thick, len), color, CFrame.new(ctx.c + Vector3.new(cx + x, y - thick / 2, cz)), opts)
		end
	end
end

local function water(ctx, size, x, y, z)
	return P(size, WATER, CFrame.new(ctx.c + Vector3.new(x, y, z)), { material = M.Glass, transparency = 0.2, reflectance = 0.15, collide = false })
end

-- a scallop shell crest: ribs of falling height side by side, pale and pink alternating, standing on cf (faces -Z of cf)
local function shell(cf, size)
	local n = 7
	local w = size / n
	for k = -3, 3 do
		local h = size * 0.55 * math.sqrt(math.max(0.05, 1 - (k / 3.6) ^ 2))
		P(Vector3.new(w * 0.92, h, w * 0.9), k % 2 == 0 and SHELL or Color3.new(1, 1, 1), cf * CFrame.new(k * w, h / 2, 0), Kit.decor({ material = M.Plaster }))
	end
	P(Vector3.new(w * 2, w, w * 1.2), CORAL_D, cf * CFrame.new(0, w / 2, 0), Kit.decor({ material = M.Plaster }))
end

-- a coral wall from a to b (local x, z) with merlons on top; `gap` = { at, half } leaves an opening along it
local function wall(ctx, a, b, h, gap)
	local A, B = ctx.c + Vector3.new(a.X, GROUND, a.Y), ctx.c + Vector3.new(b.X, GROUND, b.Y)
	local dir = (B - A).Unit
	local len = (B - A).Magnitude
	local pieces = { { 0, len } }
	if gap then
		pieces = { { 0, gap[1] - gap[2] }, { gap[1] + gap[2], len } }
	end
	for _, pc in ipairs(pieces) do
		local l = pc[2] - pc[1]
		if l > 0.5 then
			local mid = A + dir * (pc[1] + l / 2)
			local cf = CFrame.lookAt(mid, mid + dir)
			P(Vector3.new(4, h, l), CORAL, cf * CFrame.new(0, h / 2, 0), { material = M.Plaster })
			P(Vector3.new(4.6, 1.2, l), CREAM, cf * CFrame.new(0, h + 0.6, 0), Kit.decor({ material = M.Plaster }))
			for s = 2.5, l - 2.5, 6 do
				P(Vector3.new(4.2, 2, 2.6), CORAL_D, cf * CFrame.new(0, h + 2.2, -l / 2 + s), Kit.decor({ material = M.Plaster }))
			end
			P(Vector3.new(4.3, 1, l), CORAL_D, cf * CFrame.new(0, 0.5, 0), Kit.decor({ material = M.Brick }))
		end
	end
end

-- a round-ish corner tower: stacked square blocks turned 45 degrees every layer + a shell crest
local function tower(ctx, x, z, h, face)
	local base = ctx.c + Vector3.new(x, GROUND, z)
	for i = 0, 1 do
		P(Vector3.new(9, h, 9), i == 0 and CORAL or CORAL:Lerp(CREAM, 0.15), CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, i * math.pi / 4, 0), { material = M.Plaster })
	end
	P(Vector3.new(11, 1.4, 11), CREAM, CFrame.new(base + Vector3.new(0, h + 0.7, 0)), Kit.decor({ material = M.Plaster }))
	shell(CFrame.new(base + Vector3.new(0, h + 1.4, 0)) * CFrame.Angles(0, face or 0, 0), 10)
end

local function palace(ctx)
	local cx, cz, hx, hz = PAL.x, PAL.z, PAL.hx, PAL.hz
	local H = 14
	-- courtyard floor (pale stone strips)
	P(Vector3.new(hx * 2 - 4, 0.3, hz * 2 - 4), STONE, CFrame.new(ctx.c + Vector3.new(cx, GROUND + 0.15, cz)), { material = M.Cobblestone })
	-- walls: main gate in the south wall, the water gate in the north wall
	wall(ctx, v(cx - hx, cz + hz), v(cx + hx, cz + hz), H, { hx, 9 })
	wall(ctx, v(cx - hx, cz - hz), v(cx + hx, cz - hz), H, { hx, 8 })
	wall(ctx, v(cx - hx, cz - hz), v(cx - hx, cz + hz), H)
	wall(ctx, v(cx + hx, cz - hz), v(cx + hx, cz + hz), H)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		tower(ctx, cx + s[1] * hx, cz + s[2] * hz, H + 8, s[2] > 0 and 0 or math.pi)
	end
	-- main gate: two gate towers, a lintel, the name, lanterns
	local gz = cz + hz
	for _, sx in ipairs({ -1, 1 }) do
		tower(ctx, cx + sx * 12, gz, H + 6, 0)
		Kit.Lamp(ctx.c + Vector3.new(cx + sx * 8, GROUND, gz + 6))
	end
	P(Vector3.new(20, 4, 5), CORAL_D, CFrame.new(ctx.c + Vector3.new(cx, GROUND + H + 1, gz)), { material = M.Plaster })
	shell(CFrame.new(ctx.c + Vector3.new(cx, GROUND + H + 3, gz)), 12)
	Kit.Sign("SAWTOOTH PARK", CFrame.new(ctx.c + Vector3.new(cx, GROUND + H - 2.5, gz + 2.7)) * CFrame.Angles(0, math.pi, 0), Vector2.new(16, 2.6), Color3.fromRGB(255, 240, 210), Color3.fromRGB(120, 50, 44))
	-- water gate: an arch over the canal, iron grille raised half way, the canal out to the north shore
	local wz = cz - hz
	P(Vector3.new(18, 5, 5.2), CORAL_D, CFrame.new(ctx.c + Vector3.new(cx, GROUND + H - 1.5, wz)), { material = M.Plaster })
	for k = -3, 3 do
		P(Vector3.new(0.6, 7, 0.6), Color3.fromRGB(70, 72, 80), CFrame.new(ctx.c + Vector3.new(cx + k * 2.2, GROUND + H - 5, wz)), Kit.decor({ material = M.Metal }))
	end
	P(Vector3.new(15, 0.6, 0.6), Color3.fromRGB(70, 72, 80), CFrame.new(ctx.c + Vector3.new(cx, GROUND + H - 8.3, wz)), Kit.decor({ material = M.Metal }))
	local z0, z1 = cz - 18, -ctx.r - 6
	water(ctx, Vector3.new(12, 0.4, z0 - z1), cx, GROUND + 0.25, (z0 + z1) / 2)
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(2, 1.2, z0 - z1), STONE, CFrame.new(ctx.c + Vector3.new(cx + sx * 7, GROUND + 0.6, (z0 + z1) / 2)), { material = M.Cobblestone })
	end
	-- the tiered hall at the back (pagoda-like, coral roofs) with a shell crown
	local hall = ctx.c + Vector3.new(cx + 24, GROUND, cz - 26)
	Kit.Pagoda(hall, 1.45, CREAM, CORAL_D)
	shell(CFrame.new(hall + Vector3.new(0, 36 * 1.45 - 1, 0)), 16)
	-- the pool + pavilion on the west side of the yard
	local px, pz = cx - 32, cz - 18
	P(Vector3.new(30, 1, 24), STONE, CFrame.new(ctx.c + Vector3.new(px, GROUND + 0.5, pz)), { material = M.Cobblestone })
	water(ctx, Vector3.new(26, 0.4, 20), px, GROUND + 1.1, pz)
	local pv = ctx.c + Vector3.new(px, GROUND, pz + 18)
	P(Vector3.new(16, 1, 10), Color3.fromRGB(176, 126, 82), CFrame.new(pv + Vector3.new(0, 0.9, 0)), { material = M.WoodPlanks })
	for _, s in ipairs({ { -7, -4 }, { 7, -4 }, { -7, 4 }, { 7, 4 } }) do
		P(Vector3.new(1, 8, 1), CORAL_D, CFrame.new(pv + Vector3.new(s[1], 5, s[2])), { material = M.Wood })
	end
	for k = 0, 2 do
		P(Vector3.new(19 - k * 4, 1, 13 - k * 3), k % 2 == 0 and CORAL or CREAM, CFrame.new(pv + Vector3.new(0, 9.5 + k, 0)), { material = M.Plaster })
	end
	-- coral planters along the yard
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			local x, z = cx + s * 14, cz + hz - 12 - k * 14
			P(Vector3.new(4, 1.6, 4), CORAL_D, CFrame.new(ctx.c + Vector3.new(x, GROUND + 0.8, z)), { material = M.Brick })
			Kit.Bush(ctx.c + Vector3.new(x, GROUND + 1.6, z), 3, Color3.fromRGB(70, 170, 90))
		end
	end
	ctx.reserve(cx, cz, math.max(hx, hz) + 8)
end

-- round rice paddies: a dirt bank, a ring of water, a ring of rice with tufts, water again in the middle
local function paddies(ctx)
	local rng = Kit.rng
	for _, pd in ipairs({ { 150, -40, 26 }, { 200, 14, 19 }, { 140, 24, 18 }, { 182, -100, 22 }, { 104, -92, 15 } }) do
		local x, z, r = pd[1], pd[2], pd[3]
		disc(ctx, x, z, r + 3, GROUND + 0.5, 0.5, DIRT, { material = M.Ground })
		disc(ctx, x, z, r, GROUND + 0.6, 0.12, WATER, { material = M.Glass, transparency = 0.15, reflectance = 0.15 })
		disc(ctx, x, z, r * 0.72, GROUND + 0.68, 0.12, RICE:Lerp(Color3.fromRGB(80, 140, 60), 0.3), { material = M.Grass })
		disc(ctx, x, z, r * 0.32, GROUND + 0.76, 0.12, WATER, { material = M.Glass, transparency = 0.15, reflectance = 0.15 })
		local n = math.floor(r * 1.6)
		for i = 1, n do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local d = rng:NextNumber(r * 0.4, r * 0.66)
			P(Vector3.new(0.8, rng:NextNumber(1.4, 2.4), 0.8), RICE, CFrame.new(ctx.c + Vector3.new(x + math.cos(a) * d, GROUND + 1.4, z + math.sin(a) * d)), Kit.decor({ material = M.Grass }))
		end
		ctx.reserve(x, z, r + 4)
	end
end

-- tangerine groves in rows on the west side
local function groves(ctx)
	local rng = Kit.rng
	for gx = -228, -104, 15 do
		for gz = -72, 68, 15 do
			local x, z = gx + rng:NextNumber(-2, 2), gz + rng:NextNumber(-2, 2)
			if x * x + z * z < (ctx.r - 26) ^ 2 and ctx.free(x, z, 4) then
				Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.75, 0.95), Color3.fromRGB(70, 170, 70), ORANGE)
			end
		end
	end
	Kit.PostSign("GROVES", ctx.at(-98, 76), Vector3.new(1, 0, 0), 8)
	for k = 0, 4 do
		Kit.Crate(ctx.at(-100 - k * 3, 84), 2.6, rng:NextNumber(0, 1))
	end
end

-- the village: a cobbled plaza with a block fountain, houses round it facing in
local function village(ctx)
	local vx, vz = 0, 112
	disc(ctx, vx, vz, 22, GROUND + 0.35, 0.3, STONE, { material = M.Cobblestone })
	P(Vector3.new(10, 1.6, 10), CORAL_D, CFrame.new(ctx.c + Vector3.new(vx, GROUND + 1, vz)), { material = M.Brick })
	water(ctx, Vector3.new(8.4, 0.3, 8.4), vx, GROUND + 1.7, vz)
	P(Vector3.new(2, 5, 2), CREAM, CFrame.new(ctx.c + Vector3.new(vx, GROUND + 3.6, vz)), { material = M.Plaster })
	shell(CFrame.new(ctx.c + Vector3.new(vx, GROUND + 6, vz)), 5)
	ctx.reserve(vx, vz, 24)
	local roofs = { ORANGE, Color3.fromRGB(80, 170, 150), CORAL_D, Color3.fromRGB(240, 190, 70) }
	local k = 0
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		-- skip the road mouths: north (palace), south (harbor), west (groves), east (paddies)
		local sa, ca = math.sin(a), math.cos(a)
		if math.abs(sa) < 0.9 and math.abs(ca) < 0.95 then
			k += 1
			local x, z = vx + ca * 46, vz + sa * 46
			local p = ctx.at(x, z)
			Kit.House(CFrame.lookAt(p, ctx.at(vx, vz)), 14, 11, CREAM, roofs[k % #roofs + 1], { floors = 1 + k % 2, trim = TRIM, chimney = false })
			ctx.reserve(x, z, 11)
		end
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.5
		Kit.Lamp(ctx.c + Vector3.new(vx + math.cos(a) * 25, GROUND, vz + math.sin(a) * 25))
	end
end

-- tropical woods filling the open ground: palms near the shore, round trees inland, bushes + flowers between
local function woods(ctx)
	local rng = Kit.rng
	for _ = 1, 320 do
		local x, z = rng:NextNumber(-245, 245), rng:NextNumber(-245, 245)
		local d = math.sqrt(x * x + z * z)
		if ctx.free(x, z, 7) then
			if d > 190 or rng:NextNumber() > 0.6 then
				Kit.Palm(ctx.at(x, z) - Vector3.new(0, 3.2, 0))
			else
				Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.9, 1.4), Color3.fromRGB(60, 160, 70), rng:NextNumber() > 0.7 and ORANGE or nil)
			end
			ctx.reserve(x, z, 6)
		end
	end
	for _ = 1, 110 do
		local x, z = rng:NextNumber(-240, 240), rng:NextNumber(-240, 240)
		if ctx.free(x, z, 3) then
			if rng:NextNumber() > 0.55 then
				Kit.Flowers(ctx.at(x, z), 4, 6)
			else
				Kit.Bush(ctx.at(x, z), rng:NextNumber(2.5, 4))
			end
		end
	end
end

-- an old wreck beached on the south-west shore
local function wreck(ctx)
	local c = ctx.at(-168, 184)
	local base = CFrame.new(c) * CFrame.Angles(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(20))
	local wood = Color3.fromRGB(92, 66, 46)
	P(Vector3.new(14, 3, 40), wood, base * CFrame.new(0, -1, 0), { material = M.WoodPlanks })
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(2, 7, 36), wood:Lerp(Color3.new(0, 0, 0), 0.15), base * CFrame.new(sx * 7, 2, -1), { material = M.WoodPlanks })
	end
	P(Vector3.new(10, 6, 6), wood, base * CFrame.new(0, 2, 18) * CFrame.Angles(math.rad(-20), 0, 0), { material = M.WoodPlanks })
	P(Vector3.new(1.6, 22, 1.6), Color3.fromRGB(120, 84, 56), base * CFrame.new(0, 12, -4) * CFrame.Angles(math.rad(25), 0, math.rad(12)), { material = M.Wood })
	P(Vector3.new(10, 8, 0.3), Color3.fromRGB(220, 210, 185), base * CFrame.new(1, 16, -6) * CFrame.Angles(math.rad(25), 0, math.rad(40)), { material = M.Plaster, collide = false })
	Kit.Barrel(c + Vector3.new(14, 0.5, -6))
	Kit.Barrel(c + Vector3.new(-12, 0.5, 10))
	ctx.reserve(-168, 184, 24)
end

-- the south jetty with rowboats
local function jetty(ctx)
	local z0, z1 = 250, 318
	P(Vector3.new(10, 0.8, z1 - z0), Color3.fromRGB(150, 108, 70), CFrame.new(ctx.c + Vector3.new(0, GROUND - 1.2, (z0 + z1) / 2)), { material = M.WoodPlanks })
	for z = z0 + 4, z1, 8 do
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(1.2, GROUND + 4, 1.2), TRIM, CFrame.new(ctx.c + Vector3.new(sx * 5.4, (GROUND + 4) / 2 - 2.6, z)), { material = M.Wood })
		end
	end
	for _, b in ipairs({ { -10, 284, 0.25 }, { 10, 300, -0.2 } }) do
		Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(b[1], 0.4, b[2])) * CFrame.Angles(0, b[3], 0), ORANGE)
	end
	Kit.Lamp(ctx.c + Vector3.new(4.5, GROUND - 0.8, z1 - 2))
	Kit.CrateStack(ctx.c + Vector3.new(-14, GROUND, 228))
	ctx.reserve(0, 240, 14)
end

local function npcs(ctx, api)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face)
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -24, 190, { SubTitle = "Shop" }, v(0, 190))
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 24, 190, { SubTitle = "Refine & Cards" }, v(0, 190))
	put("FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", 30, 160, { SubTitle = "Fast Travel" }, v(0, 160))
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 212, { SubTitle = "📜 Quests" }, v(0, 190))
	local d = ctx.island.dungeon and Dungeons[ctx.island.dungeon]
	if d then
		-- the way down into the Depths: outside the palace's main gate
		put("Dungeon", d.name, Color3.fromRGB(200, 80, 160), "clown", PAL.x - 26, PAL.z + PAL.hz + 12, { DungeonId = ctx.island.dungeon, SubTitle = "Dungeon Lv." .. d.minLevel .. "+" }, v(PAL.x, PAL.z + PAL.hz + 40))
	end
end

function MK.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	-- the base's round "gentle hill" mounds read as stray green boxes: drop them (as Marmalade / Honeyslope do)
	for _, o in ipairs(f:GetChildren()) do
		local pos = o:IsA("Part") and o.CFrame.Position
		if pos and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and pos.Y < 0 then
			o:Destroy()
		end
	end
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	-- 1. the big pieces + NPCs (they reserve their spots)
	palace(ctx)
	npcs(ctx, api)
	village(ctx)
	paddies(ctx)
	wreck(ctx)
	jetty(ctx)
	-- 2. roads: harbor -> plaza -> palace gate, lanes west (groves) + east (paddies)
	road(ctx, { v(0, 246), v(0, 200), v(-4, 160), v(0, 134) })
	road(ctx, { v(0, 90), v(8, 40), v(-6, -20), v(14, -70), v(PAL.x, PAL.z + PAL.hz + 4) })
	road(ctx, { v(-22, 106), v(-66, 92), v(-100, 70) }, 7)
	road(ctx, { v(22, 106), v(70, 76), v(110, 50) }, 7)
	-- 3. harbor services: side docks + shipyard
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 4. groves, palms + shore rocks, greenery, chests last
	groves(ctx)
	L.Coast(ctx, 34)
	api.placeChests(ctx)
	woods(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 204)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return MK
