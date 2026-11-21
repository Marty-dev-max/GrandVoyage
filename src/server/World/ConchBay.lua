-- Conch Bay (v0.25.20, owner concept art, docs/Islands-Concept.md): a garrison island in layers.
--   North : a two-tier rock plateau with the walled garrison on top: square walls with battlements, a training yard,
--           two round "conch shell" towers with blue domes and spiral bands, a gate facing the town.
--   Middle: the harbor town at sea level: plaza with fountain, white houses with blue / red roofs.
--   South : the market street (striped awnings) running down to one long wooden pier.
-- Built at z 0 on its own Random stream (WorldBuilder.buildIsland), then moved to the island's z.
-- No Marine logos or One Piece landmarks: the towers are our conch shells.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Kit)
local L = require(script.Parent.IslandLayouts)
local P, Cyl = Kit.P, Kit.Cyl
local M = Enum.Material

local CB = {}

local WALL = Color3.fromRGB(242, 234, 216)
local STONE = Color3.fromRGB(226, 216, 196)
local ROOFS = { Color3.fromRGB(60, 110, 200), Color3.fromRGB(200, 80, 60), Color3.fromRGB(70, 130, 210), Color3.fromRGB(230, 120, 70) }
local SHELL, DOME, BAND = Color3.fromRGB(150, 195, 235), Color3.fromRGB(70, 120, 210), Color3.fromRGB(235, 245, 255)
local AWNINGS = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(60, 150, 220), Color3.fromRGB(240, 190, 50), Color3.fromRGB(90, 190, 110), Color3.fromRGB(170, 90, 210) }
local FORT = Vector2.new(0, -150) -- garrison plateau center (north)
local FW, FD = 96, 78 -- garrison wall rectangle

-- a round tower whose bands spiral up like a conch shell, with a blue dome
local function conchTower(base, height)
	Kit.Tower(base, 16, height, SHELL, DOME, { band = DOME })
	for k = 0, math.floor(height / 3) do
		local a = k * 0.75
		local y = 3 + k * 3
		P(Vector3.new(5, 1.3, 1.6), BAND, CFrame.new(base + Vector3.new(math.cos(a) * 8.3, y, math.sin(a) * 8.3)) * CFrame.Angles(0, -a + math.pi / 2, 0.35), Kit.decor({ collide = false }))
	end
	Kit.Flag(base + Vector3.new(0, height + 7, 0), Color3.fromRGB(70, 120, 210), 8)
end

local function garrison(ctx)
	local top = ctx.height(FORT.X, FORT.Y)
	local c = ctx.c + Vector3.new(FORT.X, top, FORT.Y)
	local h = 11
	local function wall(cx, cz, len, alongX)
		local size = alongX and Vector3.new(len, h, 3) or Vector3.new(3, h, len)
		P(size, STONE, CFrame.new(c + Vector3.new(cx, h / 2, cz)), { material = M.Brick })
		for k = 0, math.floor(len / 6) - 1 do
			local o = -len / 2 + 3 + k * 6
			local pos = alongX and Vector3.new(cx + o, h + 1, cz) or Vector3.new(cx, h + 1, cz + o)
			P(Vector3.new(3, 2, 3), STONE, CFrame.new(c + pos), Kit.decor({ material = M.Brick }))
		end
	end
	wall(0, -FD / 2, FW, true)
	wall(-FW / 2, 0, FD, false)
	wall(FW / 2, 0, FD, false)
	-- south wall with the gate in the middle (14 studs wide)
	local side = (FW - 14) / 2
	wall(-(7 + side / 2), FD / 2, side, true)
	wall(7 + side / 2, FD / 2, side, true)
	for _, x in ipairs({ -8.5, 8.5 }) do
		P(Vector3.new(4, h + 5, 4), STONE, CFrame.new(c + Vector3.new(x, (h + 5) / 2, FD / 2)), { material = M.Brick })
	end
	P(Vector3.new(21, 3, 4), DOME, CFrame.new(c + Vector3.new(0, h + 3.5, FD / 2)), { material = M.Brick })
	Kit.Sign("CONCH BAY GARRISON", CFrame.new(c + Vector3.new(0, h + 3.5, FD / 2 + 2.2)) * CFrame.Angles(0, math.pi, 0), Vector2.new(19, 2.6), Color3.fromRGB(255, 240, 190))
	-- training yard: grass square, practice posts, a weapon rack
	P(Vector3.new(44, 0.3, 26), Color3.fromRGB(110, 190, 90), CFrame.new(c + Vector3.new(0, 0.2, 12)), { material = M.Grass })
	for i = 0, 3 do
		local p = c + Vector3.new(-15 + i * 10, 0, 12)
		P(Vector3.new(1.2, 5, 1.2), Color3.fromRGB(150, 105, 65), CFrame.new(p + Vector3.new(0, 2.5, 0)), { material = M.Wood })
		P(Vector3.new(4, 1, 1), Color3.fromRGB(150, 105, 65), CFrame.new(p + Vector3.new(0, 4, 0)), { material = M.Wood })
	end
	Kit.CrateStack(c + Vector3.new(-36, 0, 26))
	Kit.Barrel(c + Vector3.new(36, 0.5, 26))
	-- two conch towers at the back of the yard, a low hall between them
	conchTower(c + Vector3.new(-22, 0, -16), 34)
	conchTower(c + Vector3.new(22, 0, -16), 30)
	Kit.House(CFrame.new(c + Vector3.new(0, 0, -24)), 22, 14, WALL, DOME, { floors = 2 })
	ctx.reserve(FORT.X, FORT.Y, 70)
end

-- the market street: paving from the plaza down to the pier, stalls on both sides
local function market(ctx, r)
	local z0, z1 = ctx.island.townRadius - 10, r - 26
	local mid = (z0 + z1) / 2
	P(Vector3.new(14, 0.5, z1 - z0), Color3.fromRGB(214, 204, 186), CFrame.new(ctx.at(0, mid) + Vector3.new(0, 0.05, 0)), { material = M.Cobblestone })
	local k = 0
	for z = z0 + 6, z1 - 6, 13 do
		for _, sx in ipairs({ -1, 1 }) do
			k += 1
			local pos = ctx.at(sx * 11, z)
			Kit.Stall(CFrame.new(pos) * CFrame.Angles(0, sx * math.pi / 2, 0), AWNINGS[k % #AWNINGS + 1])
			ctx.reserve(sx * 11, z, 5)
		end
	end
	for z = z0, z1, 26 do
		Kit.Lamp(ctx.at(-7, z))
		Kit.Lamp(ctx.at(7, z))
	end
	ctx.reserve(0, mid, 8)
end

-- one long pier running south into the bay
local function pier(ctx, r)
	local z0, len = r - 30, 100
	local y = 5
	for i = 0, len / 5 - 1 do
		P(Vector3.new(11, 1, 4.6), Color3.fromRGB(190, 135, 85):Lerp(Color3.fromRGB(160, 110, 70), i % 2), CFrame.new(ctx.c + Vector3.new(0, y, z0 + i * 5 + 2.5)), { material = M.WoodPlanks })
	end
	for i = 0, len / 10 do
		for _, sx in ipairs({ -5.5, 5.5 }) do
			Cyl(14, 1.6, Color3.fromRGB(120, 80, 50), ctx.c + Vector3.new(sx, -2, z0 + i * 10), { material = M.Wood })
		end
	end
	Kit.Lamp(ctx.c + Vector3.new(-4.5, y + 0.5, z0 + len - 4))
	Kit.Lamp(ctx.c + Vector3.new(4.5, y + 0.5, z0 + len - 4))
	Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(12, 0.3, z0 + 40)))
	Kit.Rowboat(CFrame.new(ctx.c + Vector3.new(-12, 0.3, z0 + 70)), Color3.fromRGB(90, 150, 210))
	Kit.CrateStack(ctx.c + Vector3.new(3, y + 0.5, z0 + 20))
end

-- the town grid (concept: dense blocks of white houses with blue / red roofs along straight streets)
local function townGrid(ctx, r)
	local rng = Kit.rng
	local function block(x, z)
		if not ctx.free(x, z, 8) then
			return
		end
		local w, d = rng:NextNumber(12, 16), rng:NextNumber(10, 13)
		local pos = ctx.at(x, z)
		-- doors face the nearest north-south street (x = 0) or the plaza
		local face = math.abs(x) > 24 and Vector3.new(ctx.c.X, pos.Y, pos.Z) or Vector3.new(pos.X, pos.Y, ctx.c.Z)
		Kit.House(CFrame.lookAt(pos, face), w, d, WALL, ROOFS[rng:NextInteger(1, #ROOFS)], { stone = STONE, floors = rng:NextNumber() > 0.55 and 2 or 1 })
		ctx.reserve(x, z, math.max(w, d) * 0.62)
	end
	for z = -40, r - 70, 21 do
		for _, x in ipairs({ -32, -54, -76, -98, 32, 54, 76, 98 }) do
			block(x, z)
		end
	end
end

function CB.Build(island, api)
	local f = api.folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	api.base(island, c, r)
	local ctx = api.makeCtx(island, c, r, 7.5)
	ctx.foam = api.foam
	-- 1. the garrison plateau: two rock tiers, stairs down to the town on the south face
	L.Tiers(ctx, { { x = FORT.X, z = FORT.Y, r = 100, h = 10, stairs = { math.pi / 2 }, force = true, cap = { r = 66, h = 12, stairs = { math.pi / 2 } } } })
	garrison(ctx)
	-- 2. town: plaza + NPCs first (they reserve their spots), market street, then two rings of houses
	L.Plaza(ctx, true)
	api.standardNPCs(ctx)
	market(ctx, r)
	townGrid(ctx, r)
	L.Paths(ctx)
	-- 3. harbor: the long south pier, the side docks and the shipyard
	pier(ctx, r)
	api.dock(island, 1)
	api.dock(island, -1)
	api.shipyard(island)
	-- 4. greenery on the slopes and the coast, chests last (they look for mesa tops)
	L.Coast(ctx, 22)
	L.Greenery(ctx, 22)
	api.placeChests(ctx)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(ctx.at(0, r - 40) + Vector3.new(0, 0.2, 0)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	api.banner(island, c)
	Kit.parent = prev
	return f
end

return CB
