-- Marmalade Town (v0.25.24, owner concept art: docs/Islands-Concept.md row 2). Island coordinates before the island
-- turns: +Z = south = the harbor (faces Conch Bay, the previous island).
--   Harbor quay (south): stone seawall, bollards, the big-top circus ship moored broadside (our own: purple hull, gold
--     star figurehead, striped tent, pennant masts; no clown head, no pirate flag), a gangplank.
--   Grand boulevard: one long paved square from the quay north to the town hall, flower planters down the middle,
--     lamps both sides. House blocks either side (cream / pink / yellow / peach walls, orange tile roofs, green
--     shutters), doors to the boulevard and to the lanes, one cross street.
--   Town hall (north end): raised terrace + wide stairs, blue roof with a dome, the clock tower beside it.
--   Forest hill behind it (orange groves), winding dirt paths up both coasts, grey boulders all round the shore.
-- Monsters: the clown gang (Confetti Crew) holds the town: grunts at their crossroads checkpoint camp, acrobats on the
-- east path, the lions loose in the hill groves, Captain Confetti in the big top (Config/Islands offsets). Original names only.
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
local RED, WHITE = Color3.fromRGB(214, 44, 52), Color3.fromRGB(250, 244, 232)
local GANG, GANG2 = Color3.fromRGB(122, 64, 176), Color3.fromRGB(250, 200, 60) -- the Confetti Crew colors
local DARKIRON = Color3.fromRGB(52, 50, 58)

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
	Kit.Flag(d + Vector3.new(0, 13.8, 0), GANG, 6, true) -- v0.25.147: the Crew's flag flies over the hall
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

-- v0.25.147 (owner reference: a block-built circus big top, much bigger + taller, voxel like the rest): a stadium
-- tent (two poles on the x axis, round ends) built on a 2-stud grid. Roof = one block per cell whose top follows a
-- concave tent curve (steep at the peaks, flat at the eave, a sag between the poles), each block reaching down to its
-- lowest neighbour so the steps never show holes; radial red/white stripes (odd counts so the colors alternate at
-- every seam), gold trim + a scalloped valance on the eave. Striped wall with an open doorway toward the harbor (+Z)
-- under a framed marquee sign with bulbs. Inside = the show: plank floor, sawdust ring + curb, stadium bleachers
-- (open at the door and behind the stage), backstage curtain + stage, striped poles with a tightrope, a trapeze,
-- spotlights on the ring, garlands, drum pedestals, a fire hoop, a striped ball and the human-cannonball cannon.
-- Plaster cloth (Fabric renders dark). No rng: the town's random stream is unchanged.
local BIGTOP = { x = 0, z = -40, rs = 28, p = 22, wall = 14, eave = 15, top = 44, sag = 7 }

-- stadium distance from the pole segment, and which stripe a spot is on (true = red)
local function stadium(x, z)
	local dx = math.max(math.abs(x) - BIGTOP.p, 0)
	return math.sqrt(dx * dx + z * z)
end
local function redStripe(x, z)
	local P = BIGTOP.p
	if math.abs(x) <= P then
		return math.min(6, math.floor((x + P) / (2 * P) * 7)) % 2 == 0 -- 7 stripes across the middle (red at both seams)
	end
	local a = math.atan2(z, math.abs(x) - P) -- -pi/2 .. pi/2 around the pole
	local k = math.clamp(math.floor((a + math.pi / 2) / math.pi * 15), 0, 14) -- 15 sectors per end
	return (k + 1) % 2 == 0
end
local function roofH(x, z)
	local B = BIGTOP
	local t = math.clamp(stadium(x, z) / B.rs, 0, 1)
	local h = B.eave + (B.top - B.eave) * (1 - t) ^ 2.2
	if math.abs(x) < B.p then
		h -= B.sag * (1 - (x / B.p) ^ 2) * (1 - t) ^ 2
	end
	return math.floor(h + 0.5)
end
do -- self-check: the eave sits at the eave height, the poles are the peaks, the middle sags
	assert(roofH(0, BIGTOP.rs) == BIGTOP.eave and roofH(BIGTOP.p, 0) == BIGTOP.top and roofH(0, 0) == BIGTOP.top - BIGTOP.sag, "bigtop roof curve")
	local e = BIGTOP.rs - 1 -- the seams show at the eave
	for _, sz in ipairs({ -1, 1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			assert(redStripe(sx * (BIGTOP.p - 1), sz * e) ~= redStripe(sx * (BIGTOP.p + 1), sz * e), "bigtop stripe seams")
		end
	end
end

local function bigTop(ctx)
	local B = BIGTOP
	local c = ctx.c + Vector3.new(B.x, GROUND, B.z)
	local RW = B.rs - 3 -- wall line (3-stud eave overhang)
	local half = B.p + B.rs
	local function inRoof(x, z)
		return stadium(x, z) <= B.rs
	end
	local function inWall(x, z)
		return stadium(x, z) <= RW
	end
	local function door(x, z)
		return z > 0 and math.abs(x) < 5
	end
	-- roof + wall + floor on the 2-stud grid
	for x = -half + 1, half - 1, 2 do
		for z = -B.rs + 1, B.rs - 1, 2 do
			if inRoof(x, z) then
				local red = redStripe(x, z)
				local col = red and RED or WHITE
				local h = roofH(x, z)
				local lo, edge = h, false
				for _, o in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
					local nx, nz = x + o[1], z + o[2]
					if inRoof(nx, nz) then
						lo = math.min(lo, roofH(nx, nz))
					else
						edge = true
					end
				end
				local bottom = math.min(lo - 1, h - 1.5)
				P(Vector3.new(2, h - bottom, 2), col, CFrame.new(c + Vector3.new(x, (h + bottom) / 2, z)), { material = M.Plaster })
				if edge then
					P(Vector3.new(2.1, 0.5, 2.1), GOLD, CFrame.new(c + Vector3.new(x, bottom + 0.25, z)), Kit.decor({ material = M.Wood }))
					if (x + z) % 4 == 0 then -- scalloped valance
						P(Vector3.new(2, 1.6, 2), col, CFrame.new(c + Vector3.new(x, bottom - 0.8, z)), Kit.decor({ material = M.Plaster, collide = false }))
					end
				end
				if inWall(x, z) then
					-- wall = the outer ring of wall cells; floor planks everywhere inside
					local wallCell = false
					for _, o in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
						if not inWall(x + o[1], z + o[2]) then
							wallCell = true
						end
					end
					if wallCell then
						local y0 = door(x, z) and 10 or 0
						P(Vector3.new(2, B.wall - y0, 2), col, CFrame.new(c + Vector3.new(x, (y0 + B.wall) / 2, z)), { material = M.Plaster })
					else
						P(Vector3.new(2, 0.2, 2), ((x + z) % 4 == 0) and Color3.fromRGB(150, 98, 62) or Color3.fromRGB(162, 108, 70), CFrame.new(c + Vector3.new(x, 0.1, z)), Kit.decor({ material = M.WoodPlanks, shadow = false }))
					end
				end
			end
		end
	end
	-- doorway frame + marquee sign on the eave
	local front = c + Vector3.new(0, 0, RW)
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(1.2, 10.6, 1.2), GOLD, CFrame.new(front + Vector3.new(sx * 5.6, 5.3, 0.6)), { material = M.Wood })
	end
	P(Vector3.new(12.4, 1.2, 1.2), GOLD, CFrame.new(front + Vector3.new(0, 10.4, 0.6)), { material = M.Wood })
	local signC = c + Vector3.new(0, B.eave + 4.4, B.rs + 0.9)
	P(Vector3.new(27, 9.4, 1.2), DARKIRON, CFrame.new(signC), { material = M.Slate })
	Kit.Sign("CONFETTI CIRCUS", CFrame.new(signC + Vector3.new(0, 0, 0.5)) * CFrame.Angles(0, math.pi, 0), Vector2.new(24, 6.4), GANG2, Color3.fromRGB(120, 30, 40))
	for i = 0, 12 do -- marquee bulbs along the top and bottom of the frame
		for _, y in ipairs({ -4.3, 4.3 }) do
			P(Vector3.new(0.7, 0.7, 0.4), Color3.fromRGB(255, 236, 150), CFrame.new(signC + Vector3.new(-12 + i * 2, y, 0.75)), Kit.decor({ material = M.Neon, collide = false, shadow = false }))
		end
	end
	-- poles: striped columns through the roof, gold tip + crew pennant above each peak, bunting between the peaks
	for _, sx in ipairs({ -1, 1 }) do
		local pole = c + Vector3.new(sx * B.p, 0, 0)
		for y = 0, B.top + 3, 3 do
			P(Vector3.new(1.6, 3, 1.6), (y // 3) % 2 == 0 and RED or WHITE, CFrame.new(pole + Vector3.new(0, y + 1.5, 0)), { material = M.Plaster })
		end
		P(Vector3.new(0.7, 5, 0.7), GOLD, CFrame.new(pole + Vector3.new(0, B.top + 8.5, 0)), { material = M.Wood })
		P(Vector3.new(1.4, 1.4, 1.4), GOLD, CFrame.new(pole + Vector3.new(0, B.top + 11.4, 0)), Kit.decor({ material = M.Neon }))
		P(Vector3.new(0.2, 2.6, 4.6), GANG, CFrame.new(pole + Vector3.new(0, B.top + 9.4, 2.4)), Kit.decor({ material = M.Plaster, collide = false }))
		P(Vector3.new(0.25, 1, 1), GANG2, CFrame.new(pole + Vector3.new(0, B.top + 9.4, 2.4)), Kit.decor({ material = M.Plaster, collide = false }))
		-- tightrope platform + spotlight on the pole
		P(Vector3.new(3.4, 0.5, 3.4), Color3.fromRGB(120, 82, 56), CFrame.new(pole + Vector3.new(-sx * 0.6, 17, 0)), { material = M.WoodPlanks })
		local lamp = P(Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(255, 246, 220), CFrame.lookAt(pole + Vector3.new(-sx * 1.4, 21, 0), c + Vector3.new(0, 0, 0)), Kit.decor({ material = M.Neon, collide = false }))
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Front
		s.Angle = 50
		s.Range = 40
		s.Brightness = 2.2
		s.Color = sx < 0 and Color3.fromRGB(255, 226, 180) or Color3.fromRGB(255, 190, 220)
		s.Parent = lamp
	end
	Kit.Bunting(c + Vector3.new(-B.p, B.top + 6, 0), c + Vector3.new(B.p, B.top + 6, 0), { RED, GANG2, GANG, WHITE })
	-- tightrope between the platforms + a trapeze under the middle of the roof
	P(Vector3.new(2 * B.p - 3, 0.2, 0.2), Color3.fromRGB(230, 220, 190), CFrame.new(c + Vector3.new(0, 17.3, 0)), Kit.decor({ collide = false, shadow = false }))
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(0.15, 5, 0.15), Color3.fromRGB(230, 220, 190), CFrame.new(c + Vector3.new(sx * 1.6, 22.5, 8)), Kit.decor({ collide = false, shadow = false }))
	end
	P(Vector3.new(3.6, 0.35, 0.35), GOLD, CFrame.new(c + Vector3.new(0, 20, 8)), Kit.decor({ collide = false }))
	-- garlands from the poles to the wall top
	for _, g in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		Kit.Bunting(c + Vector3.new(g[1] * B.p, 24, 0), c + Vector3.new(g[1] * (B.p + 10), B.wall - 0.5, g[2] * (RW - 2)), { GANG2, RED, WHITE })
	end
	-- the ring: sawdust tiles + red/white curb
	for gx = -12, 12, 3 do
		for gz = -12, 12, 3 do
			if gx * gx + gz * gz <= 12.5 * 12.5 then
				P(Vector3.new(3, 0.2, 3), Color3.fromRGB(196, 158, 108), CFrame.new(c + Vector3.new(gx, 0.3 + ((gx + gz) % 2) * 0.02, gz)), Kit.decor({ material = M.Sand }))
			end
		end
	end
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		P(Vector3.new(3.4, 1, 1), i % 2 == 0 and RED or WHITE, CFrame.new(c + dir * 14 + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0), { material = M.Plaster })
	end
	-- bleachers: three rows on the grid, highest at the back; open at the door and behind the stage
	for x = -half + 1, half - 1, 2 do
		for z = -B.rs + 1, B.rs - 1, 2 do
			local d = stadium(x, z)
			local row = RW - 1.5 - d
			if row > 0 and row < 7.5 and not (z > 0 and math.abs(x) < 9) and not (z < 0 and math.abs(x) < 10) then
				local tier = 2 - math.floor(row / 2.5) -- 2 = against the wall (tallest)
				local h = 1.2 + tier * 1.3
				P(Vector3.new(2, h, 2), tier % 2 == 0 and Color3.fromRGB(60, 80, 190) or Color3.fromRGB(86, 108, 214), CFrame.new(c + Vector3.new(x, h / 2 + 0.2, z)), { material = M.WoodPlanks })
			end
		end
	end
	-- backstage: stage + curtain against the back wall
	local back = c + Vector3.new(0, 0, -RW + 2.5)
	P(Vector3.new(18, 1.4, 6), Color3.fromRGB(120, 82, 56), CFrame.new(back + Vector3.new(0, 0.7, 1.5)), { material = M.WoodPlanks })
	P(Vector3.new(18.4, 0.4, 0.4), GOLD, CFrame.new(back + Vector3.new(0, 1.4, 4.6)), Kit.decor({ material = M.Wood }))
	for i = 0, 9 do
		P(Vector3.new(1.8, 11, 0.6), i % 2 == 0 and Color3.fromRGB(160, 24, 40) or Color3.fromRGB(196, 36, 52), CFrame.new(back + Vector3.new(-8.1 + i * 1.8, 6.9, -1)), Kit.decor({ material = M.Plaster }))
	end
	P(Vector3.new(19, 1.6, 0.8), GOLD, CFrame.new(back + Vector3.new(0, 12.6, -0.8)), Kit.decor({ material = M.Wood }))
	-- show props round the ring
	local function drum(x, z, col)
		for i, s in ipairs({ 3.4, 3.8, 3.4 }) do
			P(Vector3.new(s, 0.8, s), i == 2 and GOLD or col, CFrame.new(c + Vector3.new(x, 0.2 + (i - 0.5) * 0.8, z)), { material = M.Plaster })
		end
		P(Vector3.new(2.6, 0.4, 2.6), WHITE, CFrame.new(c + Vector3.new(x, 2.8, z)), Kit.decor({ material = M.Plaster }))
	end
	drum(-17, -7, RED)
	drum(17, -7, GANG)
	drum(-17, 8, GANG)
	drum(17, 8, RED)
	-- fire hoop on two posts
	local hoop = c + Vector3.new(-26, 0, 4)
	for _, sz in ipairs({ -1, 1 }) do
		P(Vector3.new(0.6, 4, 0.6), DARKIRON, CFrame.new(hoop + Vector3.new(0, 2, sz * 3.4)), { material = M.Metal })
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local b = P(Vector3.new(0.8, 0.8, 0.8), i % 2 == 0 and Color3.fromRGB(255, 140, 40) or Color3.fromRGB(255, 210, 70), CFrame.new(hoop + Vector3.new(0, 7.4 + math.sin(a) * 3.4, math.cos(a) * 3.4)), Kit.decor({ material = M.Neon, collide = false }))
		if i % 4 == 0 then
			local f = Instance.new("Fire")
			f.Size = 2
			f.Heat = 4
			f.Parent = b
		end
	end
	-- striped ball
	for i = 0, 3 do
		local s = ({ 2.4, 3.2, 3.2, 2.4 })[i + 1]
		P(Vector3.new(s, 0.9, s), i % 2 == 0 and Color3.fromRGB(60, 120, 230) or GANG2, CFrame.new(c + Vector3.new(26, 0.65 + i * 0.9, 6)), { material = M.Plaster })
	end
	-- human-cannonball cannon aimed over the ring
	local can = c + Vector3.new(30, 0, -8)
	for _, sz in ipairs({ -1, 1 }) do
		P(Vector3.new(3, 3, 0.6), Color3.fromRGB(120, 82, 56), CFrame.new(can + Vector3.new(0, 1.5, sz * 1.8)), { material = M.Wood })
	end
	local barrel = CFrame.new(can + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -2.5)
	P(Vector3.new(2.6, 2.6, 9), RED, barrel, { material = M.Metal })
	P(Vector3.new(3.2, 3.2, 0.8), GOLD, barrel * CFrame.new(0, 0, -4.2), Kit.decor({ material = M.Metal }))
	P(Vector3.new(1.2, 1.2, 0.3), GOLD, barrel * CFrame.new(0, 1.4, 0) * CFrame.Angles(math.pi / 2, 0, 0), Kit.decor({ material = M.Neon, collide = false }))
	-- warm hanging lamps over the ring
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pos = c + Vector3.new(math.cos(a) * 11, 19, math.sin(a) * 11)
		P(Vector3.new(0.2, 5, 0.2), Color3.fromRGB(60, 50, 40), CFrame.new(pos + Vector3.new(0, 2.5, 0)), Kit.decor({ collide = false }))
		local bulb = P(Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 220, 140), CFrame.new(pos), Kit.decor({ material = M.Neon, collide = false }))
		local l = Instance.new("PointLight")
		l.Range = 20
		l.Brightness = 0.6
		l.Color = Color3.fromRGB(255, 210, 150)
		l.Parent = bulb
	end
	ctx.reserve(B.x - B.p, B.z, B.rs + 2)
	ctx.reserve(B.x, B.z, B.rs + 2)
	ctx.reserve(B.x + B.p, B.z, B.rs + 2)
end

-- v0.25.147 (owner: the clown gang has taken the town; lay it out so it tells the story): the player lands at the
-- harbor (townsfolk, shops) and walks up the boulevard into occupied ground: the Crew's barricade with a gap and a
-- KEEP OUT board, their checkpoint camp on the crossroads (the ClownGrunt spawn, Islands offset (0, 38)), parked
-- circus wagons, crew bunting strung lamp to lamp, confetti trodden into the paving all the way up, empty lion cages
-- with the doors hanging open beside the big top (the lions got loose up the hill), the crew's flag on the town hall,
-- and the big top itself in the hall square = Captain Confetti's show. No rng (hash for the confetti).
local function townStory(ctx)
	local at = function(x, z, y)
		return ctx.c + Vector3.new(x, GROUND + (y or 0), z)
	end
	-- barricade across the boulevard (gap in the middle)
	local BZ = 60
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			local x = sx * (8 + i * 4.4)
			local board = i % 2 == 0 and RED or WHITE
			P(Vector3.new(4.2, 0.8, 0.5), board, CFrame.new(at(x, BZ, 2.6)), { material = M.WoodPlanks })
			P(Vector3.new(4.2, 0.8, 0.5), i % 2 == 0 and WHITE or RED, CFrame.new(at(x, BZ, 1.4)), Kit.decor({ material = M.WoodPlanks }))
			P(Vector3.new(0.6, 3.4, 0.6), Color3.fromRGB(96, 62, 38), CFrame.new(at(x - 2, BZ, 1.7)), { material = M.Wood })
		end
		Kit.Crate(at(sx * 7, BZ + 2.2), 2.4, 0.3 * sx)
		Kit.Barrel(at(sx * 27, BZ + 2))
		Kit.Crate(at(sx * 26, BZ - 2.4), 2.6, 0.2)
		-- crew flags at the gap
		P(Vector3.new(0.6, 12, 0.6), Color3.fromRGB(96, 62, 38), CFrame.new(at(sx * 6, BZ - 1.4, 6)), { material = M.Wood })
		P(Vector3.new(0.2, 3, 4.6), GANG, CFrame.new(at(sx * 6, BZ - 1.4, 10.4) + Vector3.new(0, 0, 2.4)), Kit.decor({ material = M.Plaster, collide = false }))
		P(Vector3.new(0.25, 1.2, 1.2), GANG2, CFrame.new(at(sx * 6, BZ - 1.4, 10.4) + Vector3.new(0, 0, 2.4)), Kit.decor({ material = M.Plaster, collide = false }))
	end
	Kit.PostSign("KEEP OUT", at(-14, BZ + 3), Vector3.new(0, 0, 1), 8)
	-- the checkpoint camp on the crossroads: striped tents at the sides, a brazier, crates
	local function campTent(x, z, yaw, col)
		local cf = CFrame.new(at(x, z)) * CFrame.Angles(0, yaw, 0)
		for i = 0, 3 do
			P(Vector3.new(8 - i * 1.9, 1.5, 9), i % 2 == 0 and col or WHITE, cf * CFrame.new(0, 0.75 + i * 1.5, 0), { material = M.Plaster })
		end
		P(Vector3.new(2.4, 2.8, 0.2), Color3.fromRGB(30, 22, 20), cf * CFrame.new(0, 1.4, -4.55), Kit.decor({ collide = false }))
		P(Vector3.new(0.4, 2, 0.4), GOLD, cf * CFrame.new(0, 7, 0), Kit.decor())
	end
	campTent(-44, 32, -math.pi / 2, GANG) -- doors face the crossroads
	campTent(-44, 46, -math.pi / 2, RED)
	campTent(44, 38, math.pi / 2, GANG)
	local br = at(-34, 39)
	P(Vector3.new(3, 1.6, 3), DARKIRON, CFrame.new(br + Vector3.new(0, 0.8, 0)), { material = M.Metal })
	local coal = P(Vector3.new(2.2, 0.6, 2.2), Color3.fromRGB(255, 120, 40), CFrame.new(br + Vector3.new(0, 1.8, 0)), Kit.decor({ material = M.Neon }))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = coal
	local fl = Instance.new("PointLight")
	fl.Range = 18
	fl.Brightness = 1.2
	fl.Color = Color3.fromRGB(255, 160, 80)
	fl.Parent = coal
	Kit.CrateStack(at(34, 28))
	-- circus wagons parked in the cross street
	local function wagon(x, z, yaw, body, roof)
		local cf = CFrame.new(at(x, z)) * CFrame.Angles(0, yaw, 0)
		P(Vector3.new(5, 5, 11), body, cf * CFrame.new(0, 4, 0), { material = M.WoodPlanks })
		P(Vector3.new(5.6, 0.8, 11.6), roof, cf * CFrame.new(0, 6.9, 0), { material = M.Plaster })
		P(Vector3.new(4.4, 0.8, 10.4), roof, cf * CFrame.new(0, 7.7, 0), { material = M.Plaster })
		P(Vector3.new(5.2, 0.5, 11.2), GOLD, cf * CFrame.new(0, 1.7, 0), Kit.decor({ material = M.Wood }))
		for _, wz in ipairs({ -3.6, 3.6 }) do
			for _, wx in ipairs({ -2.8, 2.8 }) do
				P(Vector3.new(0.6, 3, 3), GOLD, cf * CFrame.new(wx, 1.5, wz), { material = M.Wood })
				P(Vector3.new(0.7, 1, 1), Color3.fromRGB(96, 62, 38), cf * CFrame.new(wx, 1.5, wz), Kit.decor({ collide = false }))
			end
		end
		for _, side in ipairs({ -1, 1 }) do -- a gold star on each side
			P(Vector3.new(0.2, 1.8, 0.6), GANG2, cf * CFrame.new(side * 2.55, 4.2, 0), Kit.decor({ collide = false }))
			P(Vector3.new(0.2, 0.6, 1.8), GANG2, cf * CFrame.new(side * 2.55, 4.2, 0), Kit.decor({ collide = false }))
		end
	end
	wagon(62, 34, 0.15, GANG, RED)
	wagon(-62, 42, -0.1, Color3.fromRGB(60, 120, 200), GANG2)
	-- crew bunting lamp to lamp across the boulevard
	for _, z in ipairs({ 8, 64, 120 }) do
		Kit.Bunting(at(-31, z, 9.4), at(31, z, 9.4), { GANG, GANG2, RED, WHITE })
	end
	-- empty lion cages beside the big top, doors hanging open (the lions are loose in the hill groves)
	local function cage(x, z, side)
		local cf = CFrame.new(at(x, z))
		P(Vector3.new(5, 1, 9), Color3.fromRGB(120, 82, 56), cf * CFrame.new(0, 1.6, 0), { material = M.WoodPlanks })
		P(Vector3.new(5.4, 0.8, 9.4), RED, cf * CFrame.new(0, 7.2, 0), { material = M.Plaster })
		for _, wz in ipairs({ -3, 3 }) do
			for _, wx in ipairs({ -2.6, 2.6 }) do
				P(Vector3.new(0.6, 2.2, 2.2), GOLD, cf * CFrame.new(wx, 1.1, wz), { material = M.Wood })
			end
		end
		for i = 0, 8 do
			local zz = -4.2 + i * 1.05
			P(Vector3.new(0.3, 4.8, 0.3), DARKIRON, cf * CFrame.new(-side * 2.3, 4.6, zz), { material = M.Metal })
		end
		for _, ez in ipairs({ -4.3, 4.3 }) do
			for i = 0, 3 do
				P(Vector3.new(0.3, 4.8, 0.3), DARKIRON, cf * CFrame.new(-1.5 + i, 4.6, ez), { material = M.Metal })
			end
		end
		-- the open door: bars swung out on the boulevard side, one bent bar on the ground
		local hinge = cf * CFrame.new(side * 2.3, 4.6, -4.2) * CFrame.Angles(0, side * 1.9, 0)
		for i = 0, 3 do
			P(Vector3.new(0.3, 4.8, 0.3), DARKIRON, hinge * CFrame.new(0, 0, i * 1.05 + 0.5), Kit.decor({ material = M.Metal }))
		end
		P(Vector3.new(0.3, 0.3, 3.6), DARKIRON, cf * CFrame.new(side * 4.4, 0.15, 3) * CFrame.Angles(0, 0.7, 0), Kit.decor({ material = M.Metal }))
		-- paw prints heading north toward the hill
		for i = 0, 2 do
			local p = cf * CFrame.new(side * (4 + i * 0.6), 0.08, -6 - i * 3.2)
			P(Vector3.new(0.9, 0.06, 0.9), Color3.fromRGB(92, 70, 52), p, Kit.decor({ collide = false, shadow = false }))
		end
	end
	cage(-36, -2, 1)
	cage(36, -2, -1)
	-- confetti trodden into the paving from the barricade up to the big top
	for gx = -28, 28, 2 do
		for gz = -10, 104, 2 do
			local h = math.sin(gx * 12.9898 + gz * 78.233) * 43758.5453
			h -= math.floor(h)
			if h < 0.09 then
				local cols = { RED, GANG, GANG2, Color3.fromRGB(80, 180, 240), Color3.fromRGB(110, 220, 120) }
				local jx, jz = (h * 97 % 1 - 0.5) * 1.6, (h * 211 % 1 - 0.5) * 1.6
				P(Vector3.new(0.7, 0.06, 0.7), cols[math.floor(h * 1000) % #cols + 1], CFrame.new(at(gx + jx, gz + jz, 0.09)) * CFrame.Angles(0, h * 20, 0), Kit.decor({ collide = false, shadow = false }))
			end
		end
	end
end

-- the grand boulevard: lighter paving, planters with flowers down the middle, lamps on both sides
local function boulevard(ctx)
	slab(ctx, { -30, 30, HALL[4], QUAY_Z - 4 }, GROUND - 0.2, GROUND + 0.06, PAVE2, M.Cobblestone)
	for _, z in ipairs({ 84, 128 }) do -- v0.25.147: the big top + the crossroads camp took the upper planters
		P(Vector3.new(7, 1.4, 18), STONE, CFrame.new(ctx.c + Vector3.new(0, GROUND + 0.7, z)), { material = M.Brick })
		P(Vector3.new(5.6, 0.3, 16.6), Color3.fromRGB(110, 78, 50), CFrame.new(ctx.c + Vector3.new(0, GROUND + 1.45, z)), Kit.decor({ material = M.Ground }))
		Kit.Flowers(ctx.c + Vector3.new(0, GROUND + 1.6, z), 3, 9)
		Kit.Bush(ctx.c + Vector3.new(0, GROUND + 1.6, z - 6), 2.4)
		Kit.Bush(ctx.c + Vector3.new(0, GROUND + 1.6, z + 6), 2.4)
		ctx.reserve(0, z, 10)
	end
	for z = -76, QUAY_Z - 14, 28 do
		for _, sx in ipairs({ -1, 1 }) do
			if stadium(sx * 31 - BIGTOP.x, z - BIGTOP.z) > BIGTOP.rs + 2 then -- none under the big top
				Kit.Lamp(ctx.c + Vector3.new(sx * 31, GROUND, z))
			end
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
				local hall = col == 1 and cz < -2 -- v0.25.147: the big top spreads over the first column (-86..-2)
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
	bigTop(ctx)
	townStory(ctx)
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
