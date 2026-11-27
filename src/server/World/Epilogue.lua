-- Epilogue Town (v0.25.133, owner concept notes: docs/Islands-Concept.md row 6). Island coordinates before the island
-- turns: +Z = south = the harbor (faces Mikan Isles, the previous island).
--   South: a harbor with three piers, the spawn, then an ARCHED GATE reading "EPILOGUE TOWN" over the main street.
--   A paved ring road circles the old town; inside it the central square has a BELL TOWER in the middle and two
--   fountains, the domed TOWN HALL north of it, a church with a red dome west, the Marine HQ east, white houses with
--   terracotta / blue roofs all round. North: the Mist Commodore's broken watch square. North-west: the PvP arena.
--   East shore: the lighthouse on its rocks. Cypress + olive trees and palms outside the walls.
-- The square's landmark is the bell tower. v0.25.146 (owner): the old EXECUTION PLATFORM is back as the Mist Commodore's
-- stage at the north end of his square (our own: stone plinth, timber deck, stairs, rail, lantern posts; no rope).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P = Kit.P
local M = Enum.Material

local EP = {}

local GROUND = 7.6
local PAVE = Color3.fromRGB(206, 196, 180)
local PAVE2 = Color3.fromRGB(190, 180, 164)
local WHITE = Color3.fromRGB(248, 244, 236)
local CREAM = Color3.fromRGB(240, 230, 210)
local TERRA = Color3.fromRGB(196, 92, 60)
local BLUE = Color3.fromRGB(60, 110, 176)
local RED = Color3.fromRGB(196, 62, 58)
local STONE = Color3.fromRGB(200, 190, 172)
local TRIM = Color3.fromRGB(116, 80, 54)
local WATER = Color3.fromRGB(70, 170, 220)
local RING_R = 104 -- the ring road

local function v(x, z)
	return Vector2.new(x, z)
end

local roadK = 0
local function road(ctx, pts, width, color)
	for i = 2, #pts do
		local a, b = ctx.c + Vector3.new(pts[i - 1].X, GROUND, pts[i - 1].Y), ctx.c + Vector3.new(pts[i].X, GROUND, pts[i].Y)
		roadK += 1
		local y = 0.12 + (roadK % 3) * 0.04
		local mid, len = (a + b) / 2, (b - a).Magnitude
		P(Vector3.new(width or 10, 0.3, len + (width or 10) * 0.5), color or PAVE, CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)), { material = M.Cobblestone })
		-- small spots along the road (one circle over a long segment blocked whole house rings)
		local n = math.max(1, math.ceil(len / 8))
		for k = 0, n do
			local t = k / n
			ctx.reserve(pts[i - 1].X + (pts[i].X - pts[i - 1].X) * t, pts[i - 1].Y + (pts[i].Y - pts[i - 1].Y) * t, (width or 10) / 2 + 2)
		end
	end
end

-- a round slab of parallel strips clipped to the circle (big cylinders voxelize into a plus)
local function disc(ctx, cx, cz, r, y, thick, color, opts)
	local step = 3
	for x = -r + step / 2, r, step do
		local len = 2 * math.sqrt(math.max(0, r * r - x * x))
		if len > 1 then
			P(Vector3.new(math.min(step, r), thick, len), color, CFrame.new(ctx.c + Vector3.new(cx + x, y - thick / 2, cz)), opts)
		end
	end
end

-- a stepped voxel dome: discs shrinking along a quarter circle
local function dome(ctx, cx, cz, r, y, color)
	local n = 6
	for k = 0, n - 1 do
		local a0 = k / n * math.pi / 2
		local rr = r * math.cos(a0)
		local h = r * (math.sin((k + 1) / n * math.pi / 2) - math.sin(a0))
		disc(ctx, cx, cz, rr, y + r * math.sin(a0) + h, h + 0.05, color, { material = M.Plaster })
	end
	P(Vector3.new(1, 4, 1), Color3.fromRGB(240, 200, 80), CFrame.new(ctx.c + Vector3.new(cx, y + r + 2, cz)), Kit.decor({ material = M.Metal }))
end

local function fountain(ctx, x, z)
	local base = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(12, 1.6, 12), STONE, CFrame.new(base + Vector3.new(0, 0.8, 0)), { material = M.Brick })
	P(Vector3.new(10.4, 0.3, 10.4), WATER, CFrame.new(base + Vector3.new(0, 1.65, 0)), { material = M.Glass, transparency = 0.2, reflectance = 0.15, collide = false })
	P(Vector3.new(3, 4, 3), STONE, CFrame.new(base + Vector3.new(0, 3.5, 0)), { material = M.Brick })
	P(Vector3.new(5.6, 0.8, 5.6), STONE, CFrame.new(base + Vector3.new(0, 5.6, 0)), { material = M.Brick })
	P(Vector3.new(4.6, 0.3, 4.6), WATER, CFrame.new(base + Vector3.new(0, 6.05, 0)), { material = M.Glass, transparency = 0.2, collide = false })
	P(Vector3.new(1, 2.4, 1), WHITE, CFrame.new(base + Vector3.new(0, 7.2, 0)), { material = M.Plaster })
	ctx.reserve(x, z, 8)
end

-- the bell tower in the middle of the square: square shaft, open belfry with a bell, stepped red roof
local function bellTower(ctx, x, z)
	local base = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(14, 3, 14), STONE, CFrame.new(base + Vector3.new(0, 1.5, 0)), { material = M.Brick })
	P(Vector3.new(10, 26, 10), CREAM, CFrame.new(base + Vector3.new(0, 16, 0)), { material = M.Plaster })
	for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		P(Vector3.new(s[1] ~= 0 and 0.4 or 3, 5, s[2] ~= 0 and 0.4 or 3), Color3.fromRGB(70, 60, 54), CFrame.new(base + Vector3.new(s[1] * 5.05, 20, s[2] * 5.05)), Kit.decor())
	end
	-- belfry: 4 corner posts, the bell, a ledge
	local by = 29
	P(Vector3.new(11.4, 1, 11.4), STONE, CFrame.new(base + Vector3.new(0, by, 0)), { material = M.Brick })
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		P(Vector3.new(2.2, 8, 2.2), CREAM, CFrame.new(base + Vector3.new(s[1] * 4.3, by + 4.5, s[2] * 4.3)), { material = M.Plaster })
	end
	local gold = Color3.fromRGB(214, 170, 70)
	for k = 0, 2 do
		P(Vector3.new(4.2 - k * 1.2, 1.2, 4.2 - k * 1.2), gold, CFrame.new(base + Vector3.new(0, by + 2.6 + k * 1.2, 0)), Kit.decor({ material = M.Metal }))
	end
	P(Vector3.new(0.8, 1.4, 0.8), gold, CFrame.new(base + Vector3.new(0, by + 6.4, 0)), Kit.decor({ material = M.Metal }))
	for k = 0, 4 do
		P(Vector3.new(12 - k * 2.6, 1.6, 12 - k * 2.6), RED, CFrame.new(base + Vector3.new(0, by + 9.3 + k * 1.6, 0)), { material = M.Plaster })
	end
	Kit.Flag(base + Vector3.new(0, by + 17, 0), BLUE, 6)
	ctx.reserve(x, z, 10)
end

-- the central square: paving, the bell tower, two fountains, benches, lamps
local function square(ctx)
	disc(ctx, 0, 0, 44, GROUND + 0.36, 0.3, PAVE2, { material = M.Cobblestone })
	bellTower(ctx, 0, 0)
	fountain(ctx, -26, 6)
	fountain(ctx, 26, 6)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local p = ctx.c + Vector3.new(math.cos(a) * 38, GROUND, math.sin(a) * 38)
		Kit.Lamp(p)
		local b = ctx.c + Vector3.new(math.cos(a + 0.2) * 34, GROUND + 0.4, math.sin(a + 0.2) * 34)
		Kit.Bench(CFrame.lookAt(b, ctx.c + Vector3.new(0, GROUND + 0.4, 0)))
	end
	ctx.reserve(0, 0, 46)
end

-- the domed town hall north of the square: colonnade front, stepped dome on a drum
local function townHall(ctx)
	local x, z = 0, -76
	local base = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(46, 2, 32), STONE, CFrame.new(base + Vector3.new(0, 1, 0)), { material = M.Brick })
	P(Vector3.new(40, 16, 24), WHITE, CFrame.new(base + Vector3.new(0, 10, -2)), { material = M.Plaster })
	P(Vector3.new(42, 1.6, 26), STONE, CFrame.new(base + Vector3.new(0, 18.8, -2)), { material = M.Brick })
	for k = -4, 4 do
		P(Vector3.new(1.8, 15, 1.8), WHITE, CFrame.new(base + Vector3.new(k * 4.5, 9.5, 12)), { material = M.Plaster })
	end
	P(Vector3.new(42, 2, 4), STONE, CFrame.new(base + Vector3.new(0, 18, 12)), { material = M.Brick })
	for k = 0, 3 do
		P(Vector3.new(26 - k * 6, 1.6, 2), WHITE, CFrame.new(base + Vector3.new(0, 19.8 + k * 1.6, 13)), { material = M.Plaster })
	end
	P(Vector3.new(6, 10, 0.4), Color3.fromRGB(80, 60, 50), CFrame.new(base + Vector3.new(0, 6, 10.3)), Kit.decor({ material = M.Wood }))
	-- drum + dome
	disc(ctx, x, z - 2, 11, GROUND + 25, 6, CREAM, { material = M.Plaster })
	dome(ctx, x, z - 2, 11, GROUND + 25, BLUE)
	Kit.Sign("TOWN HALL", CFrame.new(base + Vector3.new(0, 16, 13.4)) * CFrame.Angles(0, math.pi, 0), Vector2.new(14, 2.4), Color3.fromRGB(255, 240, 200), Color3.fromRGB(60, 70, 110))
	Kit.Stairs(base + Vector3.new(0, 0, 18), Vector3.new(0, 0, -1), 2, 14, STONE)
	ctx.reserve(x, z, 26)
end

-- the church with the red dome, west of the square
local function church(ctx)
	local x, z = -78, -30
	local base = ctx.c + Vector3.new(x, GROUND, z)
	P(Vector3.new(22, 14, 30), WHITE, CFrame.new(base + Vector3.new(0, 7, 0)), { material = M.Plaster })
	P(Vector3.new(30, 12, 14), WHITE, CFrame.new(base + Vector3.new(0, 6, -2)), { material = M.Plaster })
	P(Vector3.new(24, 1.2, 32), STONE, CFrame.new(base + Vector3.new(0, 14.6, 0)), { material = M.Brick })
	disc(ctx, x, z - 2, 8, GROUND + 19, 4.4, WHITE, { material = M.Plaster })
	dome(ctx, x, z - 2, 8, GROUND + 19, RED)
	-- front bell gable facing the square (east)
	P(Vector3.new(1, 18, 8), WHITE, CFrame.new(base + Vector3.new(11.5, 9, 10)), { material = M.Plaster })
	P(Vector3.new(1.4, 2.2, 2.2), Color3.fromRGB(214, 170, 70), CFrame.new(base + Vector3.new(11.6, 14.5, 10)), Kit.decor({ material = M.Metal }))
	P(Vector3.new(0.4, 8, 5), Color3.fromRGB(80, 60, 50), CFrame.new(base + Vector3.new(11.2, 4, 0)), Kit.decor({ material = M.Wood }))
	for k = -1, 1 do
		P(Vector3.new(0.4, 5, 2), Color3.fromRGB(90, 150, 210), CFrame.new(base + Vector3.new(11.2, 9, k * 8)), Kit.decor({ material = M.Glass }))
	end
	for _, s in ipairs({ -1, 1 }) do
		Kit.PineTree(ctx.at(x + 16, z + s * 18), 1.1)
	end
	ctx.reserve(x, z, 22)
end

local function marineHQ(ctx)
	local x, z = 80, -36
	local p = ctx.at(x, z)
	Kit.House(CFrame.lookAt(p, ctx.at(0, z)), 30, 20, Color3.fromRGB(245, 247, 252), Color3.fromRGB(40, 70, 130), { floors = 3, trim = Color3.fromRGB(40, 70, 130), sign = "MARINE HQ" })
	Kit.Flag(ctx.at(x - 18, z + 14), Color3.fromRGB(40, 90, 180), 20, true)
	ctx.reserve(x, z, 22)
end

-- the arched town gate over the main street from the harbor
local function gate(ctx)
	local z = 156
	local base = ctx.c + Vector3.new(0, GROUND, z)
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(8, 24, 8), CREAM, CFrame.new(base + Vector3.new(sx * 12, 12, 0)), { material = M.Brick })
		P(Vector3.new(9, 2, 9), STONE, CFrame.new(base + Vector3.new(sx * 12, 25, 0)), { material = M.Brick })
		-- short walls running off each side
		P(Vector3.new(44, 10, 4), CREAM, CFrame.new(base + Vector3.new(sx * 38, 5, 0)), { material = M.Brick })
		P(Vector3.new(44, 1.2, 4.6), STONE, CFrame.new(base + Vector3.new(sx * 38, 10.6, 0)), Kit.decor({ material = M.Brick }))
		Kit.Lamp(ctx.c + Vector3.new(sx * 18, GROUND, z + 6))
		Kit.Bush(ctx.c + Vector3.new(sx * 62, GROUND + 1, z + 2), 4, Color3.fromRGB(80, 150, 80))
	end
	-- the arch: stepped blocks between the pillars
	for k = 0, 7 do
		local a = k / 7 * math.pi
		local ax = math.cos(a) * 8
		local ay = 17 + math.sin(a) * 5
		P(Vector3.new(3.2, 3.2, 8), CREAM, CFrame.new(base + Vector3.new(ax, ay, 0)), { material = M.Brick })
	end
	P(Vector3.new(32, 4, 8.6), CREAM, CFrame.new(base + Vector3.new(0, 24, 0)), { material = M.Brick })
	for k = -3, 3 do
		P(Vector3.new(2.4, 2, 8.6), STONE, CFrame.new(base + Vector3.new(k * 4.4, 27, 0)), Kit.decor({ material = M.Brick }))
	end
	Kit.Sign("EPILOGUE TOWN", CFrame.new(base + Vector3.new(0, 24, 4.4)) * CFrame.Angles(0, math.pi, 0), Vector2.new(26, 3.4), Color3.fromRGB(255, 236, 190), RED)
	Kit.Sign("EPILOGUE TOWN", CFrame.new(base + Vector3.new(0, 24, -4.4)), Vector2.new(26, 3.4), Color3.fromRGB(255, 236, 190), RED)
	ctx.reserve(0, z, 16)
	ctx.reserve(-38, z, 22)
	ctx.reserve(38, z, 22)
end

-- white houses with terracotta / blue roofs: an inner ring inside the ring road, an outer ring outside it
local function houses(ctx)
	local rng = Kit.rng
	local roofs = { TERRA, BLUE, TERRA:Lerp(Color3.fromRGB(150, 70, 40), 0.3), Color3.fromRGB(70, 140, 130) }
	local walls = { WHITE, CREAM, Color3.fromRGB(250, 236, 214), WHITE }
	local k = 0
	local function ring(r, n, floors, off)
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2 + off
			local x, z = math.cos(a) * r, math.sin(a) * r
			if ctx.free(x, z, 9) then
				k += 1
				local p = ctx.at(x, z)
				Kit.House(CFrame.lookAt(p, ctx.at(0, 0)), rng:NextInteger(12, 16), rng:NextInteger(10, 13), walls[k % #walls + 1], roofs[k % #roofs + 1], {
					floors = floors + (k % 2), trim = TRIM, shutter = k % 3 == 0 and BLUE or Color3.fromRGB(70, 130, 90), chimney = false,
				})
				ctx.reserve(x, z, 10)
			end
		end
	end
	ring(72, 16, 1, 0.1)
	ring(124, 26, 1, 0)
	ring(152, 30, 1, 0.12)
	ring(182, 34, 1, 0.05)
end

-- market stalls along the ring road
local function market(ctx)
	local cols = { RED, BLUE, Color3.fromRGB(240, 170, 60), Color3.fromRGB(80, 160, 110) }
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + 0.2
		local x, z = math.cos(a) * (RING_R - 11), math.sin(a) * (RING_R - 11)
		if ctx.free(x, z, 4) then
			local p = ctx.at(x, z)
			Kit.Stall(CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))), cols[i % #cols + 1])
			ctx.reserve(x, z, 5)
		end
	end
end

-- the PvP arena (island.arena): sand floor, stone stands with gaps, flags, sign
local function arena(ctx)
	local ar = ctx.island.arena
	if not ar then
		return
	end
	local x, z, r = ar.offset.X, ar.offset.Y, ar.radius
	disc(ctx, x, z, r, GROUND + 0.4, 0.4, Color3.fromRGB(230, 205, 150), { material = M.Sand })
	local ac = ctx.c + Vector3.new(x, GROUND, z)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		if i % 6 ~= 0 then
			for t = 0, 2 do
				local rr = r + 2 + t * 4
				P(Vector3.new(4, 2 + t * 2, rr * 0.28), STONE, CFrame.new(ac + Vector3.new(math.cos(a) * rr, 1 + t, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0), { material = M.Brick })
			end
		else
			Kit.Flag(ac + Vector3.new(math.cos(a) * (r + 3), 0, math.sin(a) * (r + 3)), RED, 12)
		end
	end
	Kit.PostSign("PVP ARENA", ac + Vector3.new(r * 0.85, 0, r * 0.85), Vector3.new(1, 0, 1), 10)
	ctx.reserve(x, z, r + 14)
end

-- the Mist Commodore's square north: worn paving, broken columns
local function bossSquare(ctx)
	local b = ctx.island.boss
	local x, z = b.offset.X, b.offset.Y
	disc(ctx, x, z, 36, GROUND + 0.38, 0.3, PAVE2:Lerp(Color3.fromRGB(150, 150, 160), 0.4), { material = M.Cobblestone })
	local rng = Kit.rng
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local h = rng:NextNumber(4, 14)
		P(Vector3.new(3, h, 3), STONE, CFrame.new(ctx.c + Vector3.new(x + math.cos(a) * 38, GROUND + h / 2, z + math.sin(a) * 38)), { material = M.Brick })
	end
	-- the platform at the north end, facing the square (+Z). No rng (the columns above keep their draws).
	local base = ctx.c + Vector3.new(x, GROUND + 0.38, z - 26)
	local WOOD, DARK = Color3.fromRGB(150, 104, 64), Color3.fromRGB(92, 62, 40)
	local W, D, H = 18, 12, 7
	P(Vector3.new(W + 2, 2, D + 2), STONE, CFrame.new(base + Vector3.new(0, 1, 0)), { material = M.Brick })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(1.4, H - 2, 1.4), DARK, CFrame.new(base + Vector3.new(sx * (W / 2 - 1), 2 + (H - 2) / 2, sz * (D / 2 - 1))), { material = M.Wood })
		end
	end
	for k = 0, 2 do
		-- cross braces under the deck
		P(Vector3.new(W - 2, 0.6, 0.6), DARK, CFrame.new(base + Vector3.new(0, 3 + k * 1.4, -(D / 2 - 1))), Kit.decor({ material = M.Wood }))
	end
	P(Vector3.new(W, 1, D), WOOD, CFrame.new(base + Vector3.new(0, H + 0.5, 0)), { material = M.WoodPlanks })
	-- rail round the back + sides
	for _, r in ipairs({ { 0, -D / 2 + 0.3, W, 0.5 }, { -W / 2 + 0.3, 0, 0.5, D }, { W / 2 - 0.3, 0, 0.5, D } }) do
		P(Vector3.new(r[3], 0.5, r[4]), DARK, CFrame.new(base + Vector3.new(r[1], H + 3.4, r[2])), { material = M.Wood })
	end
	for i = 0, 6 do
		P(Vector3.new(0.5, 2.6, 0.5), DARK, CFrame.new(base + Vector3.new(-W / 2 + 0.3 + i * (W - 0.6) / 6, H + 2.3, -D / 2 + 0.3)), Kit.decor({ material = M.Wood }))
	end
	-- stairs down the front (+Z), 1 stud steps
	for st = 0, H do
		P(Vector3.new(6, 1, 1.6), WOOD, CFrame.new(base + Vector3.new(0, H - st - 0.5 + 1, D / 2 + 0.8 + st * 1.6)), { material = M.WoodPlanks })
	end
	-- two tall lantern posts at the back corners with a crossbeam (banners hang from it)
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(1.2, 12, 1.2), DARK, CFrame.new(base + Vector3.new(sx * (W / 2 - 1.5), H + 1 + 6, -D / 2 + 1.5)), { material = M.Wood })
		local lamp = P(Vector3.new(1.2, 1.4, 1.2), Color3.fromRGB(255, 200, 120), CFrame.new(base + Vector3.new(sx * (W / 2 - 1.5), H + 11, -D / 2 + 2.6)), Kit.decor({ material = M.Neon }))
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 1.2
		l.Color = Color3.fromRGB(255, 200, 140)
		l.Parent = lamp
		P(Vector3.new(4, 7, 0.2), Color3.fromRGB(70, 80, 100), CFrame.new(base + Vector3.new(sx * 4.5, H + 8, -D / 2 + 1.5)), Kit.decor({ material = M.Plaster }))
	end
	P(Vector3.new(W - 1, 1, 1), DARK, CFrame.new(base + Vector3.new(0, H + 13, -D / 2 + 1.5)), { material = M.Wood })
end

local function lighthouse(ctx)
	local x, z = 232, -96
	Kit.RockCluster(ctx.c + Vector3.new(x, GROUND - 1, z), 14)
	Kit.Lighthouse(ctx.at(x, z) + Vector3.new(0, 1.5, 0), 1.2)
	ctx.reserve(x, z, 16)
end

-- three piers out from the south shore, boats tied up
local function harbor(ctx)
	for _, px in ipairs({ -64, 0, 64 }) do
		local z0, z1 = 268, 340
		P(Vector3.new(10, 0.8, z1 - z0), Color3.fromRGB(150, 108, 70), CFrame.new(ctx.c + Vector3.new(px, GROUND - 1.2, (z0 + z1) / 2)), { material = M.WoodPlanks })
		for zz = z0 + 4, z1, 8 do
			for _, sx in ipairs({ -1, 1 }) do
				P(Vector3.new(1.2, GROUND + 4, 1.2), TRIM, CFrame.new(ctx.c + Vector3.new(px + sx * 5.4, (GROUND + 4) / 2 - 2.6, zz)), { material = M.Wood })
			end
		end
		Kit.Lamp(ctx.c + Vector3.new(px + 4.5, GROUND - 0.8, z1 - 2))
		Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(px + 11, 0.4, z0 + 36)) * CFrame.Angles(0, 0.15, 0), px == 0 and RED or BLUE)
	end
	Kit.CrateStack(ctx.c + Vector3.new(-30, GROUND, 252))
	Kit.CrateStack(ctx.c + Vector3.new(34, GROUND, 256))
	Kit.Barrel(ctx.c + Vector3.new(40, GROUND + 0.5, 250))
	-- quay paving along the shore
	P(Vector3.new(200, 0.3, 24), PAVE, CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.1, 256)), { material = M.Cobblestone })
	ctx.reserve(0, 256, 30)
	ctx.reserve(-64, 256, 14)
	ctx.reserve(64, 256, 14)
end

local function trees(ctx)
	local rng = Kit.rng
	for _ = 1, 420 do
		local x, z = rng:NextNumber(-255, 255), rng:NextNumber(-255, 255)
		local d = math.sqrt(x * x + z * z)
		if d > 196 and ctx.free(x, z, 6) then
			local roll = rng:NextNumber()
			if roll < 0.35 then
				Kit.PineTree(ctx.at(x, z), rng:NextNumber(0.8, 1.2)) -- cypress
			elseif roll < 0.7 then
				Kit.RoundTree(ctx.at(x, z), rng:NextNumber(0.7, 1.05), Color3.fromRGB(120, 150, 100)) -- olive
			else
				Kit.Palm(ctx.at(x, z) - Vector3.new(0, 3.2, 0))
			end
			ctx.reserve(x, z, 5)
		end
	end
	for _ = 1, 100 do
		local x, z = rng:NextNumber(-250, 250), rng:NextNumber(-250, 250)
		if ctx.free(x, z, 3) then
			if rng:NextNumber() > 0.5 then
				Kit.Flowers(ctx.at(x, z), 4, 6)
			else
				Kit.Bush(ctx.at(x, z), rng:NextNumber(2.5, 4))
			end
		end
	end
end

local function npcs(ctx, api)
	local Quests = require(ReplicatedStorage.Shared.Config.Quests)
	local function put(role, title, color, hat, x, z, extra, face)
		api.npc(ctx, role, title, color, hat, x, z, extra, face)
	end
	put("Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -26, 226, { SubTitle = "Shop" }, v(0, 226))
	put("Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", 26, 226, { SubTitle = "Refine & Cards" }, v(0, 226))
	put("Guide", Quests.Guide[ctx.island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", -14, 244, { SubTitle = "📜 Quests" }, v(0, 226))
	-- the last island keeps the Bounty Board + Job Master (as Daybreak): on the square sides, facing the bell tower (off the main street: the Power board stands beside the Bounty Board)
	put("BossBoard", "Bounty Board", Color3.fromRGB(255, 220, 120), nil, -36, 30, { SubTitle = "Bosses & Bounties" }, v(0, 0))
	ctx.reserve(36, 30, 8) -- remake 0.1.10 (owner): no Job Master; its spot stays reserved (same layout)
end

function EP.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	for _, o in ipairs(f:GetChildren()) do
		local pos = o:IsA("Part") and o.CFrame.Position
		if pos and o.Material == M.Grass and o.Size.X >= 26 and o.Size.X == o.Size.Y and pos.Y < 0 then
			o:Destroy()
		end
	end
	local ctx = api.makeCtx(island, c, r, GROUND)
	ctx.foam = api.foam
	-- 1. landmarks + NPCs (they reserve their spots)
	npcs(ctx, api)
	square(ctx)
	townHall(ctx)
	church(ctx)
	marineHQ(ctx)
	gate(ctx)
	arena(ctx)
	bossSquare(ctx)
	lighthouse(ctx)
	harbor(ctx)
	-- 2. streets: the ring road, radial streets, the main street through the gate to the quay
	local ringPts = {}
	for i = 0, 28 do
		local a = i / 28 * math.pi * 2
		table.insert(ringPts, v(math.cos(a) * RING_R, math.sin(a) * RING_R))
	end
	road(ctx, ringPts, 12)
	road(ctx, { v(0, 40), v(0, 150), v(0, 246) }, 12)
	road(ctx, { v(-42, 0), v(-RING_R, 0) }, 9, PAVE2)
	road(ctx, { v(42, 0), v(RING_R, 0), v(250, 0) }, 9, PAVE2)
	road(ctx, { v(-RING_R, 0), v(-250, 0) }, 9, PAVE2)
	road(ctx, { v(0, -50), v(0, -RING_R), v(0, -180) }, 9, PAVE2)
	road(ctx, { v(-74, -74), v(-110, -110) }, 8, PAVE2) -- stops at the arena stands
	-- 3. harbor services: side docks + shipyard
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 4. the town, then trees outside it, chests
	market(ctx)
	houses(ctx)
	L.Coast(ctx, 30)
	api.placeChests(ctx)
	trees(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.2, 236)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return EP
