-- Origin home islands (R5, owner 28 Nov 2026: every Origin starts on an island of its own). Small Lv 1-5 islands
-- west of Daybreak (Config/Islands, `origin`). Coordinates are local and unturned: +Z = the front, which faces
-- Daybreak once the island turns, so every island has its jetty + spawn on the +Z side. Docks stay at local +-x and
-- the shipyard group (Shipwright, Tavern Keeper, Courier Gull Post) is placed and turned by WorldBuilder.
--   Bastion Rock      (Marine Cadet)   the cadet academy on a rock plateau, a drill yard, supply sheds raided by thieves
--   Smuggler's Hollow (Bounty Hunter)  a cave in a sea cliff over a wharf town: the Rusty Hook bar + a wanted wall
--   Shackle Reef      (Outlaw)         a prison hulk wrecked on the reef, the escapees' camp under the palms
--   Inkwell Isle      (Relic Seeker)   a library on a hill with a reading tower, old ruins looted by tomb robbers
-- Our own places and names.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P, Cyl, Ball = Kit.P, Kit.Cyl, Kit.Ball
local M = Enum.Material

local OI = {}

local GROUND = 7.6
local SOUTH = math.pi / 2 -- stairs angle toward +Z (the front)
local WOOD = Color3.fromRGB(150, 108, 70)
local DARK = Color3.fromRGB(84, 60, 44)
local IRON = Color3.fromRGB(70, 68, 66)
local STRAW = Color3.fromRGB(222, 186, 104)

local function v(x, z)
	return Vector2.new(x, z)
end

local decor = Kit.decor

-- a dirt / sand path through points (x, z); alternating heights so bends never share a top face
local pathK = 0
local function path(ctx, pts, width, color, mat)
	for i = 2, #pts do
		local a, b = ctx.at(pts[i - 1].X, pts[i - 1].Y), ctx.at(pts[i].X, pts[i].Y)
		local y = math.max(a.Y, b.Y)
		a, b = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
		pathK += 1
		local dy = 0.1 + (pathK % 3) * 0.04
		local mid, len = (a + b) / 2, (b - a).Magnitude
		P(Vector3.new(width or 8, 0.3, len + (width or 8) * 0.6), color or Color3.fromRGB(184, 140, 96), CFrame.lookAt(mid + Vector3.new(0, dy, 0), b + Vector3.new(0, dy, 0)), { material = mat or M.Ground })
		ctx.reserve((pts[i - 1].X + pts[i].X) / 2, (pts[i - 1].Y + pts[i].Y) / 2, len / 2 + 3)
	end
end

-- the front jetty on posts, out from the beach toward Daybreak, with a rowboat
local function jetty(ctx)
	local r = ctx.r
	local z0, z1 = r - 6, r + 46
	P(Vector3.new(10, 0.8, z1 - z0), WOOD, CFrame.new(ctx.c + Vector3.new(0, GROUND - 1.2, (z0 + z1) / 2)), { material = M.WoodPlanks })
	for z = z0 + 4, z1, 8 do
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(1.2, GROUND + 4, 1.2), DARK, CFrame.new(ctx.c + Vector3.new(sx * 5.4, (GROUND + 4) / 2 - 2.6, z)), { material = M.Wood })
		end
	end
	Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(-10, 0.4, z1 - 12)) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(110, 150, 190))
	Kit.Lamp(ctx.c + Vector3.new(4.5, GROUND - 0.8, z1 - 2))
	ctx.reserve(0, r - 20, 14)
end

local function campfire(ctx, x, z)
	local c = ctx.at(x, z)
	Cyl(0.6, 6, Color3.fromRGB(120, 116, 110), c + Vector3.new(0, 0.3, 0), { material = M.Slate })
	for i = 0, 4 do
		P(Vector3.new(0.9, 0.9, 4), DARK, CFrame.new(c + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, i * math.pi / 5, 0.25), decor({ material = M.Wood, collide = false }))
	end
	local flame = Ball(1.8, Color3.fromRGB(255, 160, 60), c + Vector3.new(0, 1.8, 0), decor({ material = M.Neon, collide = false, transparency = 0.15 }))
	local f = Instance.new("Fire")
	f.Size = 5
	f.Heat = 8
	f.Parent = flame
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 180, 100)
	light.Parent = flame
	-- log seats round it
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.5
		P(Vector3.new(5, 1.4, 1.4), WOOD, CFrame.new(c + Vector3.new(math.cos(a) * 6, 0.7, math.sin(a) * 6)) * CFrame.Angles(0, -a + math.pi / 2, 0), { material = M.Wood })
	end
	ctx.reserve(x, z, 9)
end

local function spawnPoint(ctx, x, z)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.at(x, z) + Vector3.new(0, 0.2, 0)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", ctx.island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
end

-- trees, bushes and flowers on whatever is still free
local function greenery(ctx, trees, kind)
	local rng = Kit.rng
	local r = ctx.r
	for _ = 1, trees do
		local x, z = rng:NextNumber(-r, r), rng:NextNumber(-r, r)
		if ctx.free(x, z, 7) then
			if kind == "palm" then
				Kit.Palm(ctx.at(x, z))
			elseif kind == "pine" or (kind == "mixed" and rng:NextNumber() > 0.6) then
				Kit.PineTree(ctx.at(x, z), rng:NextNumber(0.8, 1.2))
			else
				Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.85, 1.25))
			end
			ctx.reserve(x, z, 6)
		end
	end
	for _ = 1, math.floor(trees * 0.6) do
		local x, z = rng:NextNumber(-r, r), rng:NextNumber(-r, r)
		if ctx.free(x, z, 3) then
			if rng:NextNumber() > 0.55 then
				Kit.Flowers(ctx.at(x, z), 4, 6)
			else
				Kit.Bush(ctx.at(x, z), rng:NextNumber(2.5, 4))
			end
		end
	end
end

local function shoreRocks(ctx, n)
	local rng = Kit.rng
	local r = ctx.r
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local d = r + rng:NextNumber(-8, 16)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local front = z > r - 40 and math.abs(x) < 30
		local docks = math.abs(z) < 30 and math.abs(x) > r - 50
		if not front and not docks then
			if i % 3 == 0 then
				Kit.RockCluster(ctx.c + Vector3.new(x, -0.5, z), rng:NextNumber(6, 10))
			else
				Kit.Rock(ctx.c + Vector3.new(x, -0.5, z), rng:NextNumber(5, 10))
			end
		end
	end
end

-- a training dummy: post, crossbar arms, straw body and head
local function dummy(cf)
	P(Vector3.new(0.6, 6, 0.6), DARK, cf * CFrame.new(0, 3, 0), { material = M.Wood })
	P(Vector3.new(4.5, 0.5, 0.5), DARK, cf * CFrame.new(0, 4.6, 0), decor({ material = M.Wood }))
	P(Vector3.new(2.2, 2.6, 1.6), STRAW, cf * CFrame.new(0, 4, 0), decor({ material = M.Plaster }))
	P(Vector3.new(1.6, 1.6, 1.6), STRAW, cf * CFrame.new(0, 6.2, 0), decor({ material = M.Plaster }))
end

local function guide(ctx, api, x, z, face, extra)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local e = { SubTitle = "📜 Quests" }
	for k, val in pairs(extra or {}) do
		e[k] = val
	end
	api.npc(ctx, "Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), nil, x, z, e, face)
end

-- ===================================================================================================================
-- Bastion Rock (Marine Cadet): plateau + academy, drill yard in front, supply sheds west
local function bastionRock(ctx, api)
	local WHITE, NAVY, STONE = Color3.fromRGB(242, 240, 234), Color3.fromRGB(44, 70, 140), Color3.fromRGB(176, 172, 166)
	L.Tiers(ctx, { { x = 0, z = -62, r = 48, h = 14, force = true, stairs = { SOUTH } } })
	local top = ctx.at(0, -70)
	Kit.House(CFrame.lookAt(top, top + Vector3.new(0, 0, 1)), 34, 18, WHITE, NAVY, {
		floors = 2, floorHeight = 10, trim = NAVY, shutter = Color3.fromRGB(70, 110, 190), stone = STONE, sign = "CADET ACADEMY",
	})
	for _, sx in ipairs({ -1, 1 }) do
		Kit.Tower(ctx.at(sx * 34, -48), 10, 26, WHITE, NAVY, { band = Color3.fromRGB(70, 110, 190) })
	end
	Kit.Flag(ctx.at(0, -32), Color3.fromRGB(60, 110, 220), 18)
	-- the drill yard: packed sand, a row of training dummies, flags on the corners
	local yard = ctx.at(0, 36)
	P(Vector3.new(46, 0.3, 30), Color3.fromRGB(226, 206, 160), CFrame.new(yard + Vector3.new(0, 0.12, 0)), { material = M.Sand })
	for _, x in ipairs({ -18, -10, 10, 18 }) do -- the middle stays open: the academy stairs come down there
		dummy(CFrame.new(ctx.at(x, 30)) * CFrame.Angles(0, math.pi, 0))
	end
	for _, c in ipairs({ v(-22, 22), v(22, 22), v(-22, 50), v(22, 50) }) do
		Kit.Flag(ctx.at(c.X, c.Y), Color3.fromRGB(60, 110, 220), 9)
	end
	ctx.reserve(0, 36, 26)
	-- weapon racks by the yard
	for _, sx in ipairs({ -1, 1 }) do
		local rk = CFrame.new(ctx.at(sx * 30, 36)) * CFrame.Angles(0, math.pi / 2, 0)
		P(Vector3.new(6, 0.5, 1), DARK, rk * CFrame.new(0, 3.5, 0), { material = M.Wood })
		for k = -2, 2 do
			P(Vector3.new(0.3, 5, 0.3), Color3.fromRGB(190, 190, 200), rk * CFrame.new(k * 1.1, 2.6, 0.4) * CFrame.Angles(0.15, 0, 0), decor({ material = M.Metal, collide = false }))
		end
	end
	-- supply sheds the thieves raid (west), crates spilled about
	for _, s in ipairs({ { -70, 96, 0.4 }, { -118, 30, 1.2 } }) do
		local p = ctx.at(s[1], s[2])
		Kit.House(CFrame.new(p) * CFrame.Angles(0, s[3], 0), 12, 9, Color3.fromRGB(200, 176, 140), Color3.fromRGB(120, 86, 60), { floors = 1, trim = DARK, sign = "STORES" })
		ctx.reserve(s[1], s[2], 9)
	end
	Kit.CrateStack(ctx.at(-58, 74))
	Kit.Crate(ctx.at(-96, 74), 3, 0.5)
	Kit.Barrel(ctx.at(-104, 46) + Vector3.new(0, 0.5, 0))
	-- people: the Marine Registrar (Marine Cadets start in front of him) and the instructor
	api.npc(ctx, "Marine", "Marine Registrar", Color3.fromRGB(70, 110, 200), "marine", -12, 64, { SubTitle = "Join the Marines" }, v(-12, 100))
	guide(ctx, api, 14, 64, v(14, 100))
	path(ctx, { v(0, 132), v(0, 96), v(0, 58) }, 8, Color3.fromRGB(196, 176, 140), M.Cobblestone)
	path(ctx, { v(-24, 40), v(-50, 60), v(-66, 86) }, 6)
	jetty(ctx)
	spawnPoint(ctx, 0, 112)
	greenery(ctx, 70, "pine")
	shoreRocks(ctx, 36)
end

-- ===================================================================================================================
-- Smuggler's Hollow (Bounty Hunter): a cliff with a cave mouth at the back, the wharf town in front of it
local function smugglersHollow(ctx, api)
	local ROCKC = Color3.fromRGB(120, 112, 104)
	L.Tiers(ctx, { { x = 0, z = -74, r = 60, h = 24, force = true, cap = { dx = 0, dz = -10, r = 34, h = 12 } } })
	-- the cave mouth in the cliff face: dark hollow, timber frame, lanterns
	local mouth = ctx.c + Vector3.new(0, GROUND, -74 + 61)
	P(Vector3.new(16, 14, 4), Color3.fromRGB(26, 22, 22), CFrame.new(mouth + Vector3.new(0, 7, -1)), { material = M.Slate })
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(1.6, 15, 1.6), DARK, CFrame.new(mouth + Vector3.new(sx * 8.6, 7.5, 2.4)), { material = M.Wood })
		Kit.Lamp(mouth + Vector3.new(sx * 11, 0, 4))
	end
	P(Vector3.new(19, 1.6, 1.8), DARK, CFrame.new(mouth + Vector3.new(0, 15, 2.4)), { material = M.Wood })
	Kit.Sign("THE HOLLOW", CFrame.new(mouth + Vector3.new(0, 17.6, 2.8)), Vector2.new(14, 3), Color3.fromRGB(255, 220, 150), Color3.fromRGB(60, 44, 34))
	-- rails + crates running into the cave (smuggled cargo)
	for k = 0, 5 do
		P(Vector3.new(6, 0.3, 1), DARK, CFrame.new(mouth + Vector3.new(0, 0.2, 6 + k * 4)), decor({ material = M.Wood }))
	end
	for _, sx in ipairs({ -1.6, 1.6 }) do
		P(Vector3.new(0.3, 0.3, 24), IRON, CFrame.new(mouth + Vector3.new(sx, 0.5, 16)), decor({ material = M.Metal }))
	end
	Kit.CrateStack(mouth + Vector3.new(-7, 0, 10))
	Kit.Barrel(mouth + Vector3.new(7, 0.5, 12))
	ctx.reserve(0, -2, 14)
	-- the Rusty Hook (bar + general store inside)
	local barAt = ctx.at(-34, 30)
	local face = ctx.at(0, 52)
	Kit.House(CFrame.lookAt(barAt, Vector3.new(face.X, barAt.Y, face.Z)), 24, 18, Color3.fromRGB(150, 110, 78), Color3.fromRGB(96, 62, 48), {
		floors = 1, floorHeight = 11, hollow = "tavern", sign = "RUSTY HOOK", trim = DARK, timber = true,
	})
	ctx.reserve(-34, 30, 16)
	local dirIn = (v(-34, 30) - v(0, 52)).Unit
	local spot = v(-34, 30) + dirIn * Kit.InteriorSpot(18)
	api.npc(ctx, "Shop", "Rusty Hook Bar", Color3.fromRGB(240, 170, 80), "bandana", spot.X, spot.Y, { SubTitle = "Shop", Lift = barAt.Y + 1.4 - GROUND }, v(0, 52))
	-- the wanted wall: a plank wall full of posters, the Bounty Board stands in front of it (Bounty Hunters start here)
	local wall = CFrame.lookAt(ctx.at(30, 28), ctx.at(10, 60))
	P(Vector3.new(16, 9, 1), WOOD, wall * CFrame.new(0, 4.5, 0), { material = M.WoodPlanks })
	local rng = Kit.rng
	for k = 0, 9 do
		local px, py = -6 + (k % 5) * 3, 2.6 + math.floor(k / 5) * 3.6
		P(Vector3.new(2.2, 2.8, 0.12), Color3.fromRGB(240, 226, 190):Lerp(Color3.fromRGB(220, 200, 150), rng:NextNumber()), wall * CFrame.new(px, py, -0.56) * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1)), decor({ material = M.SmoothPlastic, collide = false }))
	end
	ctx.reserve(30, 28, 10)
	api.npc(ctx, "BossBoard", "Bounty Board", Color3.fromRGB(255, 220, 120), nil, 22, 42, { SubTitle = "Bosses & Bounties" }, v(10, 80))
	guide(ctx, api, -4, 60, v(0, 100))
	-- market stalls + lamps along the wharf street
	Kit.Stall(CFrame.lookAt(ctx.at(-14, 84), ctx.at(0, 84)), Color3.fromRGB(200, 150, 60))
	Kit.Stall(CFrame.lookAt(ctx.at(14, 90), ctx.at(0, 90)), Color3.fromRGB(150, 70, 60))
	for _, l in ipairs({ v(-8, 70), v(8, 104), v(-8, 120) }) do
		Kit.Lamp(ctx.at(l.X, l.Y))
	end
	path(ctx, { v(0, 134), v(0, 100), v(0, 60), v(0, 14) }, 9, Color3.fromRGB(150, 130, 110), M.WoodPlanks)
	path(ctx, { v(12, 56), v(44, 56), v(60, 52) }, 6)
	campfire(ctx, 56, 86)
	jetty(ctx)
	spawnPoint(ctx, 0, 116)
	-- rocky scrub: boulders and few trees
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-140, 140), rng:NextNumber(-140, 140)
		if ctx.free(x, z, 6) then
			Kit.Rock(ctx.at(x, z), rng:NextNumber(5, 9), ROCKC)
		end
	end
	greenery(ctx, 40, "mixed")
	shoreRocks(ctx, 44)
end

-- ===================================================================================================================
-- Shackle Reef (Outlaw): the prison hulk aground on the north-west reef, the escapees' camp in the palms
local function hulk(ctx)
	-- a long hull lying on its side in the sand, bow up, barred cell windows, a broken mast across the beach
	local base = CFrame.new(ctx.at(-62, -110)) * CFrame.Angles(0, 0.5, 0) * CFrame.Angles(0, 0, 0.28)
	local HULL, BAND = Color3.fromRGB(70, 56, 46), Color3.fromRGB(120, 40, 36)
	for k = -4, 4 do
		local w = 16 - math.abs(k) * 1.1
		P(Vector3.new(w, 12, 6.2), HULL:Lerp(Color3.fromRGB(96, 78, 60), (k % 2) * 0.3), base * CFrame.new(0, 4, k * 6) * CFrame.Angles(k == 4 and 0.35 or 0, 0, 0), { material = M.WoodPlanks })
		P(Vector3.new(w + 0.4, 1.2, 6.3), BAND, base * CFrame.new(0, 8.8, k * 6), decor({ material = M.WoodPlanks }))
		if math.abs(k) <= 3 then
			-- a cell window with iron bars on the high side
			for bx = -1, 1 do
				P(Vector3.new(0.25, 2.6, 0.25), IRON, base * CFrame.new(w / 2 + 0.2, 5, k * 6 + bx * 0.8), decor({ material = M.Metal, collide = false }))
			end
			P(Vector3.new(0.3, 2.8, 2.6), Color3.fromRGB(24, 20, 20), base * CFrame.new(w / 2 + 0.05, 5, k * 6), decor({ collide = false }))
		end
	end
	-- the broken mast and its torn sail on the sand
	local mast = CFrame.new(ctx.at(-30, -86)) * CFrame.Angles(0, -0.7, 0)
	P(Vector3.new(1.8, 1.8, 34), Color3.fromRGB(110, 80, 56), mast * CFrame.new(0, 1, 0), { material = M.Wood })
	P(Vector3.new(12, 0.3, 10), Color3.fromRGB(214, 204, 180), mast * CFrame.new(5, 0.3, -6) * CFrame.Angles(0, 0.3, 0), decor({ material = M.Plaster, collide = false }))
	-- chains + an anchor half in the sand
	for k = 0, 7 do
		P(Vector3.new(0.5, 1.2, 1.6), IRON, CFrame.new(ctx.at(-82 + k * 1.4, -70 + k * 0.6) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0.4, (k % 2) * math.pi / 2), decor({ material = M.Metal, collide = false }))
	end
	ctx.reserve(-62, -110, 30)
end

local function shackleReef(ctx, api)
	hulk(ctx)
	-- the escapees' camp: fire, lean-tos of driftwood and sailcloth, broken shackles
	campfire(ctx, 6, 40)
	local rng = Kit.rng
	for _, t in ipairs({ { -14, 28, 0.6 }, { 24, 26, -0.6 }, { 4, 18, 0 } }) do
		local cf = CFrame.lookAt(ctx.at(t[1], t[2]), ctx.at(6, 40))
		P(Vector3.new(7, 0.4, 6), Color3.fromRGB(214, 200, 170), cf * CFrame.new(0, 2.6, 1.2) * CFrame.Angles(math.rad(48), 0, 0), { material = M.Plaster })
		for _, sx in ipairs({ -3.2, 3.2 }) do
			P(Vector3.new(0.6, 4.6, 0.6), WOOD, cf * CFrame.new(sx, 2.3, -0.6), { material = M.Wood })
		end
		ctx.reserve(t[1], t[2], 6)
	end
	for k = 0, 2 do
		local p = ctx.at(-4 + k * 3, 52)
		Cyl(0.4, 1.6, IRON, p + Vector3.new(0, 0.3, 0), decor({ material = M.Metal, collide = false }))
		P(Vector3.new(0.4, 0.4, 2.2), IRON, CFrame.new(p + Vector3.new(0.9, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), decor({ material = M.Metal, collide = false }))
	end
	Kit.Flag(ctx.at(-22, 44), Color3.fromRGB(30, 30, 34), 12, true)
	Kit.Junk(ctx.at(30, 52), 5)
	guide(ctx, api, 6, 58, v(6, 100))
	path(ctx, { v(0, 134), v(4, 96), v(6, 66) }, 7, Color3.fromRGB(236, 214, 160), M.Sand)
	path(ctx, { v(-6, 34), v(-30, 0), v(-44, -36) }, 6, Color3.fromRGB(236, 214, 160), M.Sand)
	jetty(ctx)
	spawnPoint(ctx, 0, 112)
	greenery(ctx, 60, "palm")
	shoreRocks(ctx, 30)
end

-- ===================================================================================================================
-- Inkwell Isle (Relic Seeker): a hill with the library + its reading tower, a garden below, ruins east
local function inkwellIsle(ctx, api)
	local CREAM, PURPLE, STONE = Color3.fromRGB(240, 230, 210), Color3.fromRGB(110, 70, 160), Color3.fromRGB(186, 180, 170)
	L.Tiers(ctx, { { x = 0, z = -44, r = 46, h = 12, force = true, stairs = { SOUTH } } })
	local top = ctx.at(0, -44)
	local topY = top.Y
	local D = 20
	Kit.House(CFrame.lookAt(top, top + Vector3.new(0, 0, 1)), 30, D, CREAM, PURPLE, {
		floors = 2, floorHeight = 11, hollow = "shop", trim = Color3.fromRGB(70, 50, 90), shutter = Color3.fromRGB(150, 110, 200), stone = STONE, sign = "INKWELL LIBRARY",
	})
	-- the librarian sells maps + supplies inside (Relic Seekers start in front of the counter)
	api.npc(ctx, "Shop", "Librarian", Color3.fromRGB(150, 110, 200), nil, 0, -44 - Kit.InteriorSpot(D), { SubTitle = "Maps & Supplies", Lift = topY + 1.4 - GROUND }, v(0, 0))
	Kit.Tower(ctx.at(24, -62), 12, 34, CREAM, PURPLE, { band = Color3.fromRGB(150, 110, 200) })
	-- a giant quill + ink pot statue in the reading garden
	local g = ctx.at(-34, 46)
	Cyl(1.2, 14, STONE, g + Vector3.new(0, 0.6, 0), { material = M.Cobblestone })
	P(Vector3.new(5, 4, 5), Color3.fromRGB(40, 40, 60), CFrame.new(g + Vector3.new(0, 3.2, 0)), { material = M.Glass })
	P(Vector3.new(0.6, 12, 0.6), Color3.fromRGB(240, 240, 250), CFrame.new(g + Vector3.new(0.8, 9, 0)) * CFrame.Angles(0, 0, -0.25), decor({ material = M.SmoothPlastic }))
	P(Vector3.new(0.4, 6, 2.6), Color3.fromRGB(250, 250, 255), CFrame.new(g + Vector3.new(2.2, 13, 0)) * CFrame.Angles(0, 0, -0.25), decor({ material = M.SmoothPlastic, collide = false }))
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		Kit.Bench(CFrame.lookAt(ctx.at(-34 + math.cos(a) * 14, 46 + math.sin(a) * 14), g))
	end
	Kit.Flowers(ctx.at(-50, 58), 5, 10)
	Kit.Flowers(ctx.at(-18, 60), 5, 10)
	ctx.reserve(-34, 46, 18)
	-- the ruins (east): a ring of broken pillars + fallen blocks round the tomb robbers' dig
	local rng = Kit.rng
	local rc = v(76, -58)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = ctx.at(rc.X + math.cos(a) * 30, rc.Y + math.sin(a) * 30)
		if ctx.free(rc.X + math.cos(a) * 30, rc.Y + math.sin(a) * 30, 2) then
			local h = rng:NextNumber(4, 13)
			P(Vector3.new(3, h, 3), STONE:Lerp(Color3.fromRGB(150, 160, 140), rng:NextNumber(0, 0.4)), CFrame.new(p + Vector3.new(0, h / 2, 0)), { material = M.Cobblestone })
			if i % 3 == 0 then
				P(Vector3.new(3, 3, 7), STONE, CFrame.new(p + Vector3.new(4, 1.5, 3)) * CFrame.Angles(0, a, 0.2), { material = M.Cobblestone })
			end
		end
	end
	guide(ctx, api, 14, 70, v(14, 110))
	path(ctx, { v(0, 134), v(0, 96), v(0, 30) }, 8, Color3.fromRGB(196, 186, 166), M.Cobblestone)
	path(ctx, { v(14, 20), v(44, -10), v(58, -34) }, 6)
	jetty(ctx)
	spawnPoint(ctx, 0, 112)
	greenery(ctx, 80, "mixed")
	shoreRocks(ctx, 36)
end

local BUILD = {
	BastionRock = bastionRock,
	SmugglersHollow = smugglersHollow,
	ShackleReef = shackleReef,
	InkwellIsle = inkwellIsle,
}

-- a LAYOUTS module for one island: { Build = function(island, api) }
function OI.For(id)
	return {
		Build = function(island, api)
			local f = api.folderOf(island.id, Kit.parent)
			local prev = Kit.parent
			Kit.parent = f
			local c = Vector3.new(island.x, 0, 0)
			local r = island.radius
			api.base(island, c, r)
			-- the base's round "gentle hill" mounds read as stray green boxes: drop them (as Honeyslope does)
			for _, o in ipairs(f:GetChildren()) do
				local pos = o:IsA("Part") and o.CFrame.Position
				if pos and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and pos.Y < 0 then
					o:Destroy()
				end
			end
			local ctx = api.makeCtx(island, c, r, GROUND)
			ctx.foam = api.foam
			BUILD[id](ctx, api)
			api.dock(island, 1)
			api.dock(island, -1)
			api.shipyard(island)
			api.placeChests(ctx)
			api.banner(island, c)
			Kit.parent = prev
			return f
		end,
	}
end

return OI
