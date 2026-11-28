-- WorldBuilder: builds the Azure East procedurally in a bright low-poly cartoon style.
-- W1 (owner, 28 Nov 2026, docs/Plan-WorldMap.md): the Azure East is the north-east quarter of the world
-- (Shared/Modules/WorldShape): the Crimson Wall on its west, world-edge walls north and east, the Doldrums along its
-- south side, the Grand Current band past them, Backflow Peak in the south-west corner where the wall crosses the band.
--
-- To bake the map for hand-editing in Studio, run in the Command Bar:
--   require(game.ServerScriptService.Server.World.WorldBuilder).Build()
-- The game reuses an existing workspace.World instead of rebuilding (keep the NPC/Dock/Plot/IslandSpawn tags).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local IslandsCfg = require(Shared.Config.Islands)
local Dungeons = require(Shared.Config.Dungeons)
local Quests = require(Shared.Config.Quests)
local ChestsCfg = require(Shared.Config.Chests)
local Monsters = require(Shared.Config.Monsters)
local Kit = require(script.Parent.Kit)
local Layouts = require(script.Parent.IslandLayouts)
local Daybreak = require(script.Parent.Daybreak)
local WS = require(Shared.Modules.WorldShape)

local WB = {}
local R
local npcs = {}
local plots = {}
local docks = {}
local spawns = {}
local G = GameConfig.Ship.GridSize
local rng = Kit.rng
local M = Enum.Material

local P, Cyl, Ball = Kit.P, Kit.Cyl, Kit.Ball
local function folderOf(name, parent)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end
local function sign(text, cf, size, color, bg)
	return Kit.Sign(text, cf, size, color, bg)
end
local function rock(pos, size, color)
	return Kit.Rock(pos, size, color)
end
local function foam(pos, diameter)
	local f = Cyl(0.3, diameter, Color3.fromRGB(245, 252, 255), pos, { material = M.Neon, transparency = 0.35, collide = false, shadow = false, name = "Foam" })
	f.CanQuery = false
	CollectionService:AddTag(f, "Foam")
	return f
end

-- ===== NPCs =====
-- v0.25.112 (owner): walk-in ring colors per shop role (Blacksmith white-gray, General Store blue, Tavern pink,
-- Shipwright green); the client draws the rings from the same table (Controllers/NpcZones reads Role + ZoneColor)
WB.ZONE_ROLES = {
	Blacksmith = Color3.fromRGB(225, 230, 240),
	Shop = Color3.fromRGB(70, 190, 255),
	Tavern = Color3.fromRGB(255, 110, 190),
	Shipwright = Color3.fromRGB(110, 230, 120),
	JobMaster = Color3.fromRGB(255, 60, 60), -- v0.25.118 (owner): red ring
}
WB.ZONE_RADIUS = 7
-- face (optional): local X/Z point the NPC looks at (default: the island center)
local function npc(ctx, role, title, color, hat, x, z, extra, face)
	local island = ctx.island
	local ModelFactory = require(script.Parent.ModelFactory)
	local m = ModelFactory.NPC(title, color, hat)
	local pos = Vector3.new(island.x + x, 0, (island.z or 0) + z)
	local ground = (island.floating and 8 or 7.6) + (extra and extra.Lift or 0) -- fixed so the map can be baked outside Studio; Lift = on a building floor
	local look = face and Vector3.new(island.x + face.X, ground + 2.6, (island.z or 0) + face.Y) or Vector3.new(island.x, ground + 2.6, 0)
	m:PivotTo(CFrame.lookAt(Vector3.new(pos.X, ground + 2.6, pos.Z), look))
	m:SetAttribute("Role", role)
	m:SetAttribute("Island", island.id)
	if extra then
		for k, v in pairs(extra) do
			m:SetAttribute(k, v)
		end
	end
	Cyl(1, 7, Color3.fromRGB(255, 230, 170), Vector3.new(pos.X, ground + 0.3, pos.Z), { material = M.Sand })
	-- v0.25.112 (owner): shop NPCs glow in their own color (and get a walk-in ring, Controllers/NpcZones); the rest stay yellow
	Cyl(0.3, 8, WB.ZONE_ROLES[role] or Color3.fromRGB(255, 210, 90), Vector3.new(pos.X, ground + 0.85, pos.Z), { material = M.Neon, transparency = 0.5, collide = false, decor = true })
	ModelFactory.Billboard(m.PrimaryPart, title, extra and extra.SubTitle or nil, Color3.fromRGB(255, 230, 120), 5.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = m.PrimaryPart
	if WB.ZONE_ROLES[role] then
		-- the ring replaces the "Talk" prompt (walk in = open); ZoneColor tells the client to draw it
		m:SetAttribute("ZoneColor", WB.ZONE_ROLES[role])
		prompt.Enabled = false
	end
	CollectionService:AddTag(m, "NPC")
	m.Parent = Kit.parent
	ctx.reserve(x, z, 8)
	return m
end

local function standardNPCs(ctx)
	local island = ctx.island
	local r = math.min(island.townRadius, island.radius - 40)
	npc(ctx, "Blacksmith", "Blacksmith", Color3.fromRGB(110, 90, 80), "bandana", r * 0.55, -r * 0.6, { SubTitle = "Refine & Cards" })
	npc(ctx, "Shop", "General Store", Color3.fromRGB(240, 170, 80), nil, -r * 0.2, -r * 0.75, { SubTitle = "Shop" })
	npc(ctx, "FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", -r * 0.65, r * 0.35, { SubTitle = "Fast Travel" })
	npc(ctx, "Guide", Quests.Guide[island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", r * 0.32, r * 0.05, { SubTitle = "📜 Quests" })
	-- v0.25.21 (owner): Bounty Board only on the first and the last island (v0.25.108: the Registrar is the Marine one in Conch Bay)
	if island.id == "Daybreak" or island.id == "Epilogue" then
		npc(ctx, "BossBoard", "Bounty Board", Color3.fromRGB(255, 220, 120), nil, r * 0.15, r * 0.7, { SubTitle = "Bosses & Bounties" })
		ctx.reserve(r * 0.6, r * 0.45, 8) -- remake 0.1.10 (owner): no Job Master; keep its reservation (shared Kit.rng use)
	end
	if island.dungeon then
		local d = Dungeons[island.dungeon]
		npc(ctx, "Dungeon", d.name, Color3.fromRGB(200, 80, 160), "clown", -island.radius * 0.15, island.radius * 0.45, { DungeonId = island.dungeon, SubTitle = "Dungeon Lv." .. d.minLevel .. "+" })
	end
end

-- ===== Docks / shipyard =====
-- turn a group of parts (and their CFrame / Vector3 attributes) around the island center by local angle a
local function turnGroup(group, island, a)
	if not a or a == 0 then
		return
	end
	local Rg = CFrame.new(island.x, 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(-island.x, 0, 0)
	local parts, targets = {}, {}
	for _, o in ipairs(group:GetDescendants()) do
		if o:IsA("BasePart") then
			table.insert(parts, o)
			table.insert(targets, Rg * o.CFrame)
		end
		for k, v in pairs(o:GetAttributes()) do
			if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
				o:SetAttribute(k, Rg * v)
			end
		end
	end
	for i, part in ipairs(parts) do
		part.CFrame = targets[i] -- targets first, then assign: welded NPC parts would otherwise move twice
	end
end

local function buildDock(island, side)
	local zc = island.z or 0
	local x0 = island.x + side * (island.radius - 25)
	local len = 90
	local dockY = 5
	for i = 0, 8 do
		P(Vector3.new(len / 9 - 0.4, 1, 16), Color3.fromRGB(190, 135, 85):Lerp(Color3.fromRGB(160, 110, 70), i % 2), CFrame.new(x0 + side * (i + 0.5) * len / 9, dockY, zc), { material = M.WoodPlanks })
	end
	for i = 0, 4 do
		for _, sz in ipairs({ -8, 8 }) do
			Cyl(16, 1.6, Color3.fromRGB(120, 80, 50), Vector3.new(x0 + side * i * len / 4, -2.5, zc + sz), { material = M.Wood })
			Cyl(1.6, 2.2, Color3.fromRGB(214, 186, 132), Vector3.new(x0 + side * i * len / 4, 4.2, zc + sz), { material = M.Fabric, decor = true })
		end
	end
	local tip = Vector3.new(x0 + side * len, dockY, zc)
	local launchPos, yaw
	if side > 0 then
		launchPos = Vector3.new(tip.X + 60, GameConfig.SeaLevel - G * 0.5, zc)
		yaw = -math.pi / 2
	else
		launchPos = Vector3.new(tip.X - 60, GameConfig.SeaLevel - G * 0.5, zc + 40)
		yaw = 0
	end
	local marker = P(Vector3.new(4, 1, 4), Color3.new(1, 1, 1), CFrame.new(tip + Vector3.new(-side * 6, 0.6, 0)), { transparency = 1, collide = false, name = "DockMarker" })
	marker:SetAttribute("Island", island.id)
	marker:SetAttribute("Side", side)
	marker:SetAttribute("LaunchCf", CFrame.new(launchPos) * CFrame.Angles(0, yaw, 0))
	marker:SetAttribute("LandCf", CFrame.new(Vector3.new(x0 + side * 10, dockY + 4, zc)))
	CollectionService:AddTag(marker, "Dock")
	for _, sz in ipairs({ -22, 22 }) do
		Ball(4, Color3.fromRGB(255, 80, 70), tip + Vector3.new(side * 30, -4, sz), {})
		Ball(1.4, Color3.fromRGB(255, 240, 160), tip + Vector3.new(side * 30, -1.6, sz), { material = M.Neon, decor = true, collide = false })
	end
	-- moored rowboats + cargo
	Kit.Rowboat(CFrame.new(x0 + side * 35, 0.3, zc + 13) * CFrame.Angles(0, math.pi / 2, 0))
	Kit.Rowboat(CFrame.new(x0 + side * 60, 0.3, zc - 13) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 150, 210))
	Kit.CrateStack(Vector3.new(x0 + side * 14, dockY + 0.5, zc - 5))
	Kit.Lamp(Vector3.new(tip.X - side * 3, dockY + 0.5, zc + 7))
end

-- v0.25.25 (owner): the shipyard sits on the side that faces the NEXT island, so you launch toward where you are
-- going instead of crossing the island (it used to be fixed at local east and often faced the Doldrums).
-- Angle (local, before the island's own yaw) that turns the default east yard; nil = keep (Daybreak).
local function yardAngle(island, worldZ)
	local nxt = island.nextId and IslandsCfg.ById[island.nextId] -- R5: the next route island, Daybreak for an Origin island
	if not island.yaw or not nxt then
		return island.yaw and 0 or nil
	end
	local wx, wz = nxt.x - island.x, (nxt.z or 0) - worldZ
	local c, s = math.cos(island.yaw), math.sin(island.yaw)
	local lx, lz = wx * c - wz * s, wx * s + wz * c -- world -> island-local (undo Angles(0, yaw))
	local want = math.atan2(lz, lx)
	-- v0.25.27 (owner): keep the yard parallel to the island: pick the island SIDE (east / north / west) closest to
	-- the next island; never the south side, that is the front harbor facing the previous island
	local best, bestD = 0, math.huge
	for _, side in ipairs({ 0, -math.pi / 2, math.pi }) do
		local d = math.abs(math.atan2(math.sin(want - side), math.cos(want - side)))
		if d < bestD then
			best, bestD = side, d
		end
	end
	return -best -- Angles(0, a) turns an XZ angle phi into phi - a: the east yard goes to `best`
end

local function buildShipyard(island)
	local size = GameConfig.Ship.PlotSize
	local w, l = size.X * G, size.Z * G
	local baseX = island.x + island.radius - 10
	local platformZ = -(70 + l / 2)
	local count = 3
	local totalW = count * w + (count - 1) * 10
	local group = Instance.new("Model")
	group.Name = "Shipyard"
	group.Parent = Kit.parent
	local prevParent = Kit.parent
	Kit.parent = group
	-- v0.25.150 (owner: the slipway platform did not fit the islands): no platform any more, the ship you build
	-- hangs over the water so it can be seen from every side (even from below). Only a boardwalk along the near end
	-- stays, for the builder to stand on.
	P(Vector3.new(totalW + 20, 2, 10), Color3.fromRGB(175, 125, 80), CFrame.new(baseX + totalW / 2 - 10, 4, platformZ + l / 2 + 7), { material = M.WoodPlanks })
	for i = 0, 6 do
		Cyl(14, 2.4, Color3.fromRGB(110, 74, 46), Vector3.new(baseX - 8 + i * (totalW + 16) / 6, -3, platformZ + l / 2 + 11), { material = M.Wood })
	end
	for i = 0, count - 1 do
		local x = baseX + i * (w + 10)
		local origin = CFrame.new(x, 9, platformZ + l / 2 - 2)
		-- the slip: invisible, only its tag + attributes (the builder's grid and camera use them)
		local plotPart = P(Vector3.new(w, 0.2, l), Color3.fromRGB(196, 160, 112), CFrame.new(x + w / 2, 9, platformZ - 2), { collide = false, name = "Plot", material = M.WoodPlanks, shadow = false, transparency = 1 })
		plotPart.CanQuery = false
		plotPart:SetAttribute("Island", island.id)
		plotPart:SetAttribute("Origin", origin)
		plotPart:SetAttribute("StandCf", CFrame.new(x + w / 2, 8, platformZ + l / 2 + 7))
		CollectionService:AddTag(plotPart, "Plot")
		-- two mooring posts per slip on the boardwalk
		for _, sx in ipairs({ 0, w }) do
			P(Vector3.new(1.2, 3, 1.2), Color3.fromRGB(110, 76, 46), CFrame.new(x + sx, 6.5, platformZ + l / 2 + 3), { material = M.Wood })
		end
	end
	for _, sx in ipairs({ -16, 16 }) do
		P(Vector3.new(1.6, 24, 1.6), Color3.fromRGB(120, 80, 50), CFrame.new(baseX + totalW / 2 + sx, 17, platformZ + l / 2 + 2), { material = M.Wood })
	end
	sign("SHIPYARD", CFrame.new(baseX + totalW / 2, 27, platformZ + l / 2 + 2), Vector2.new(34, 7), Color3.fromRGB(255, 240, 180))
	Kit.CrateStack(Vector3.new(baseX + totalW + 2, 5, platformZ + l / 2 - 4))
	-- islands after the first: the Shipwright stands at the yard and the whole yard turns toward the next island
	-- (Daybreak, hand-laid, keeps its own Shipwright and its east-facing yard)
	local a = island.yardAngle
	if a then
		npc({ island = island, reserve = function() end }, "Shipwright", "Shipwright", Color3.fromRGB(90, 140, 200), "bandana", island.radius - 24, platformZ + l / 2 + 12, { SubTitle = "Shipyard & Launch" }, Vector2.new(island.radius + 30, platformZ))
		-- v0.25.107 (owner): the Tavern Keeper (hire crew) stands beside the Shipwright on every island
		npc({ island = island, reserve = function() end }, "Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, island.radius - 24, platformZ + l / 2 + 28, { SubTitle = "Recruit Crew" }, Vector2.new(island.radius + 30, platformZ))
		-- v0.25.149 (owner: hard to find): the Courier Gull Post (fast travel) stands at the harbor too, and a flight lands here
		npc({ island = island, reserve = function() end }, "FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", island.radius - 24, platformZ + l / 2 + 46, { SubTitle = "Fast Travel" }, Vector2.new(island.radius + 30, platformZ))
		turnGroup(group, island, a)
	end
	Kit.parent = prevParent
end

-- ===== Island base terrain =====
local function lobeAngles()
	-- beach lobes avoid the east (+X) side where docks and the shipyard sit
	return { 1.2, 1.9, 2.6, 3.3, 4.0, 4.7, 5.3 }
end

local IslandShape = require(script.Parent.IslandShape)

local function buildBase(island, c, r)
	local pal = island.palette
	if island.floating then
		Cyl(10, r * 2, Color3.fromRGB(180, 130, 85), c + Vector3.new(0, 1, 0), { material = M.WoodPlanks })
		Cyl(3, r * 2 - 10, pal.grass, c + Vector3.new(0, 6.5, 0), { material = M.WoodPlanks })
		for i = 0, 35 do
			local a = i / 36 * math.pi * 2
			P(Vector3.new(1, 4, (r * 2 * math.pi) / 36 + 0.2), Color3.fromRGB(250, 245, 235), CFrame.new(c + Vector3.new(math.cos(a) * (r - 3), 10, math.sin(a) * (r - 3))) * CFrame.Angles(0, -a, 0), {})
		end
		foam(c + Vector3.new(0, 0.1, 0), r * 2 + 10)
		return
	end
	-- v0.25.134 (owner): organic voxel outline (World/IslandShape) instead of stacked discs. The lobe draws stay so
	-- the shared rng stream (and every later island) is unchanged.
	for _ in ipairs(lobeAngles()) do
		rng:NextNumber(0.28, 0.4)
	end
	IslandShape.Build(island, c, r, Kit.parent, pal)
	-- gentle hills away from the town
	for i = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(r * 0.45, r * 0.7)
		Ball(rng:NextNumber(30, 54), pal.grass:Lerp(Color3.new(1, 1, 0.6), 0.1), c + Vector3.new(math.cos(a) * d, -9, math.sin(a) * d), { material = M.Grass })
	end
end

local function makeCtx(island, c, r, g)
	local reserved = {}
	local ctx = { island = island, c = c, r = r, g = g, pal = island.palette, mesas = {} }
	-- ground height follows the highest mesa tier under the point
	function ctx.height(x, z)
		local h = g
		for _, m in ipairs(ctx.mesas) do
			local dx, dz = x - m.x, z - m.z
			if dx * dx + dz * dz <= (m.r - 1) ^ 2 and m.top > h then
				h = m.top
			end
		end
		return h
	end
	function ctx.at(x, z)
		return Vector3.new(island.x + x, ctx.height(x, z), z)
	end
	function ctx.reserve(x, z, radius)
		table.insert(reserved, { x = x, z = z, r = radius })
	end
	function ctx.free(x, z, radius)
		-- v0.25.134: the organic outline (never smaller than r - 14) decides where land ends
		local limit = island.floating and r - 12 or IslandShape.Radius(island, r, math.atan2(z, x)) - 12
		if math.sqrt(x * x + z * z) > limit then
			return false
		end
		for _, rr in ipairs(reserved) do
			local dx, dz = x - rr.x, z - rr.z
			if dx * dx + dz * dz < (rr.r + radius) ^ 2 then
				return false
			end
		end
		return true
	end
	for _, sp in ipairs(island.spawns) do
		ctx.reserve(sp.offset.X, sp.offset.Y, sp.radius + 6)
	end
	if island.boss and not island.boss.atSea then
		ctx.reserve(island.boss.offset.X, island.boss.offset.Y, 38)
	end
	ctx.reserve(r - 25, 0, 18) -- east dock
	ctx.reserve(-r + 25, 0, 18) -- west dock
	local ya = island.yardAngle or 0 -- shipyard platform (turned toward the next island, buildShipyard)
	ctx.reserve((r + 20) * math.cos(ya) - 110 * math.sin(ya), -(r + 20) * math.sin(ya) - 110 * math.cos(ya), 80)
	ctx.reserve(r * 0.45, 20, 9) -- spawn point
	return ctx
end

-- ===== Exploration chests =====
-- Captain's Chest on the highest mesa, Golden/Silver on the next tiers, Wooden on the shore, Silver in a field.
local function chestModel(id, tier, island, pos, yaw)
	local def = ChestsCfg.Tiers[tier]
	local m = Instance.new("Model")
	m.Name = "Chest_" .. id
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local k = tier == "Captain" and 1.35 or 1
	-- v0.25.113 (owner references): voxel treasure chest = plank box with frame bands (trim color), corner caps,
	-- a hinged lid Model (attribute Hinge = its back edge, client opens it), a padlock Model on the front and a gold heap
	-- inside that shows once the lid swings up
	local function at(x, y, z)
		return cf * CFrame.new(x * k, y * k, z * k)
	end
	local dark = def.body:Lerp(Color3.new(0, 0, 0), 0.3)
	local trimDark = def.trim:Lerp(Color3.new(0, 0, 0), 0.25)
	local body = P(Vector3.new(3.2, 1.9, 2.1) * k, def.body, at(0, 0.95, 0), { parent = m, material = M.WoodPlanks, name = "Body" })
	for _, y in ipairs({ 0.62, 1.28 }) do
		P(Vector3.new(3.22, 0.08, 2.12) * k, dark, at(0, y, 0), { parent = m, material = M.Wood, collide = false })
	end
	P(Vector3.new(3.36, 0.24, 2.26) * k, def.trim, at(0, 0.12, 0), { parent = m, material = M.Metal, collide = false })
	P(Vector3.new(3.34, 0.18, 2.24) * k, def.trim, at(0, 1.84, 0), { parent = m, material = M.Metal, collide = false })
	for _, x in ipairs({ -0.85, 0.85 }) do
		P(Vector3.new(0.3, 1.96, 2.2) * k, def.trim, at(x, 0.98, 0), { parent = m, material = M.Metal, collide = false })
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(0.32, 2, 0.32) * k, trimDark, at(sx * 1.5, 1, sz * 0.95), { parent = m, material = M.Metal, collide = false })
		end
	end
	-- the hoard (hidden inside the closed lid)
	local gold, goldHi = Color3.fromRGB(255, 196, 52), Color3.fromRGB(255, 232, 120)
	P(Vector3.new(2.9, 0.3, 1.8) * k, gold, at(0, 2.02, 0), { parent = m, material = M.Metal, collide = false, name = "Hoard" })
	for i, c in ipairs({ { -0.9, -0.3 }, { -0.2, 0.25 }, { 0.6, -0.2 }, { 1.05, 0.35 }, { 0.15, -0.45 }, { -0.7, 0.4 } }) do
		P(Vector3.new(0.7, 0.22, 0.7) * k, i % 2 == 0 and goldHi or gold, at(c[1], 2.2 + (i % 3) * 0.06, c[2]), { parent = m, material = M.Metal, collide = false })
	end
	-- the lid: a Model turned around its back top edge
	local lidM = Instance.new("Model")
	lidM.Name = "Lid"
	lidM.Parent = m
	P(Vector3.new(3.24, 0.5, 2.14) * k, def.body:Lerp(Color3.new(1, 1, 1), 0.08), at(0, 2.2, 0), { parent = lidM, material = M.WoodPlanks, name = "LidTop" })
	P(Vector3.new(3.0, 0.3, 1.7) * k, def.body:Lerp(Color3.new(1, 1, 1), 0.12), at(0, 2.58, 0), { parent = lidM, material = M.WoodPlanks, collide = false })
	P(Vector3.new(3.36, 0.16, 2.28) * k, def.trim, at(0, 2.0, 0), { parent = lidM, material = M.Metal, collide = false })
	for _, x in ipairs({ -0.85, 0.85 }) do
		P(Vector3.new(0.3, 0.84, 2.2) * k, def.trim, at(x, 2.34, 0), { parent = lidM, material = M.Metal, collide = false })
	end
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(0.34, 0.56, 2.22) * k, trimDark, at(sx * 1.5, 2.22, 0), { parent = lidM, material = M.Metal, collide = false })
	end
	P(Vector3.new(0.5, 0.42, 0.14) * k, def.trim, at(0, 2.0, -1.12), { parent = lidM, material = M.Metal, collide = false }) -- hasp
	lidM:SetAttribute("Hinge", at(0, 1.95, 1.07))
	-- padlock: body + shackle through the hasp
	local lock = Instance.new("Model")
	lock.Name = "Lock"
	lock.Parent = m
	P(Vector3.new(0.62, 0.54, 0.26) * k, trimDark, at(0, 1.52, -1.24), { parent = lock, material = M.Metal, collide = false, name = "LockBody" })
	P(Vector3.new(0.14, 0.14, 0.3) * k, Color3.fromRGB(30, 24, 20), at(0, 1.48, -1.26), { parent = lock, collide = false })
	for _, x in ipairs({ -0.2, 0.2 }) do
		P(Vector3.new(0.12, 0.34, 0.12) * k, Color3.fromRGB(170, 170, 180), at(x, 1.94, -1.22), { parent = lock, material = M.Metal, collide = false })
	end
	P(Vector3.new(0.52, 0.12, 0.12) * k, Color3.fromRGB(170, 170, 180), at(0, 2.12, -1.22), { parent = lock, material = M.Metal, collide = false })
	-- glow ring + light so chests read from a distance
	Cyl(0.15, 6 * k, def.trim, pos + Vector3.new(0, 0.1, 0), { parent = m, material = M.Neon, transparency = 0.55, collide = false })
	local light = Instance.new("PointLight")
	light.Color = def.trim
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = body
	m.PrimaryPart = body
	m:SetAttribute("ChestId", id)
	m:SetAttribute("Tier", tier)
	m:SetAttribute("Island", island.id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	CollectionService:AddTag(m, "Chest")
	m.Parent = Kit.parent
	return m
end

local function placeChests(ctx)
	local island = ctx.island
	local rand = Random.new(#island.id * 7919 + island.x)
	local n = 0
	local function put(tier, x, z)
		n += 1
		chestModel(island.id .. "_" .. n, tier, island, ctx.at(x, z), rand:NextNumber(0, math.pi * 2))
		ctx.reserve(x, z, 4)
	end
	-- mesa tops, highest first
	local mesas = table.clone(ctx.mesas)
	table.sort(mesas, function(a, b)
		return a.top > b.top
	end)
	local tiers = { "Captain", "Golden", "Silver" }
	local used = 0
	for _, m in ipairs(mesas) do
		if used >= #tiers then
			break
		end
		-- find a spot on this mesa whose ground really is this mesa's top (not a cap sitting on it)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + rand:NextNumber(0, 0.5)
			local d = m.r * (k % 2 == 0 and 0.45 or 0.7)
			local x, z = m.x + math.cos(a) * d, m.z + math.sin(a) * d
			if math.abs(ctx.height(x, z) - m.top) < 0.01 then
				used += 1
				put(tiers[used], x, z)
				break
			end
		end
	end
	-- shore chests away from the docks (docks sit at angle 0 and pi)
	for _, a in ipairs({ 2.0, 4.3 }) do
		local d = ctx.r - 26
		put("Wooden", math.cos(a) * d, math.sin(a) * d)
	end
	-- one silver chest somewhere in the open
	for _ = 1, 60 do
		local a, d = rand:NextNumber(0, math.pi * 2), rand:NextNumber(ctx.r * 0.45, ctx.r * 0.8)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if ctx.free(x, z, 5) then
			put("Silver", x, z)
			break
		end
	end
	if used < #tiers then
		-- islands without tiers (the floating restaurant) still get a captain's chest
		put(used == 0 and "Captain" or "Golden", -ctx.r * 0.3, ctx.r * 0.25)
	end
end

local addBannerAndArena

local function buildIslandGeneric(island)
	local f = folderOf(island.id, Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	local c = Vector3.new(island.x, 0, 0)
	local r = island.radius
	local g = island.floating and 8 or 7.5
	buildBase(island, c, r)
	local ctx = makeCtx(island, c, r, g)
	Cyl(1, island.townRadius * 2, Color3.fromRGB(235, 215, 170), c + Vector3.new(0, 7.1, 0), { material = M.Cobblestone })
	Cyl(1.05, island.townRadius * 2 + 4, Color3.fromRGB(200, 180, 140), c + Vector3.new(0, 7.05, 0), { material = M.Cobblestone })
	standardNPCs(ctx)
	Layouts.Build(ctx)
	placeChests(ctx)
	buildDock(island, 1)
	buildDock(island, -1)
	buildShipyard(island)
	local spawnPart = P(Vector3.new(8, 1, 8), Color3.fromRGB(255, 240, 160), CFrame.new(c + Vector3.new(r * 0.45, g + 0.2, 20)), { name = "SpawnPoint", material = M.Neon, transparency = 1, collide = false, shadow = false })
	spawnPart:SetAttribute("Island", island.id)
	CollectionService:AddTag(spawnPart, "IslandSpawn")
	addBannerAndArena(island, c)
	Kit.parent = prev
	return f
end

-- floating island title + the boss arena at sea
function addBannerAndArena(island, c)
	local banner = P(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 95, 0)), { transparency = 1, collide = false })
	banner:SetAttribute("IslandBanner", island.id)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(460, 110)
	bb.MaxDistance = 2400
	bb.LightInfluence = 0
	bb.Parent = banner
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.55)
	t.BackgroundTransparency = 1
	t.FontFace = Font.fromEnum(Enum.Font.Arcade)
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 245, 210)
	t.Text = island.name
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(30, 40, 70)
	st.Parent = t
	local t2 = t:Clone()
	t2.Position = UDim2.fromScale(0, 0.55)
	t2.Size = UDim2.fromScale(1, 0.25)
	t2.FontFace = Font.fromEnum(Enum.Font.Arcade)
	t2.Text = island.subtitle or ""
	t2.Parent = bb
	local t3 = t2:Clone()
	t3.Name = "Levels"
	t3.Position = UDim2.fromScale(0, 0.8)
	t3.Size = UDim2.fromScale(1, 0.2)
	t3.Text = "Lv. " .. island.levels[1] .. " - " .. island.levels[2]
	t3.TextColor3 = Color3.fromRGB(255, 220, 90)
	t3:SetAttribute("MinLevel", island.levels[1])
	t3.Parent = bb
	-- a sea boss with no arena (v0.23.0, Bay Serpent). v0.25.113 (owner): no buoys and no warning sign any more,
	-- players find it by sailing out
	if island.boss and island.boss.atSea and island.boss.sea then
		local _ = island.boss
	elseif island.boss and island.boss.atSea then
		local bp = Vector3.new(island.x + island.boss.offset.X, 0, island.boss.offset.Y)
		local ar = island.boss.arenaRadius or 42 -- deck radius
		Cyl(30, ar * 2 + 6, Color3.fromRGB(120, 125, 130), bp + Vector3.new(0, -10, 0), { material = M.Slate })
		Cyl(2, ar * 2, Color3.fromRGB(150, 110, 75), bp + Vector3.new(0, 5.5, 0), { material = M.WoodPlanks })
		foam(bp + Vector3.new(0, 0.1, 0), ar * 2 + 12)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			rock(bp + Vector3.new(math.cos(a) * (ar + 2), 3, math.sin(a) * (ar + 2)), rng:NextNumber(8, 14), Color3.fromRGB(100, 105, 115))
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			Kit.Flag(bp + Vector3.new(math.cos(a) * (ar - 4), 6.5, math.sin(a) * (ar - 4)), Color3.fromRGB(220, 50, 60), 12)
		end
		-- boarding steps on the harbor side so you can climb up from the water or a rowboat
		if island.boss.arenaRadius then
			local a = math.pi - math.pi / 8 -- between two rim rocks, facing the harbor
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			for k = 0, 3 do
				local at = bp + dir * (ar + 3 + k * 4) + Vector3.new(0, 5.5 - k * 1.8, 0)
				P(Vector3.new(10, 1, 5), Color3.fromRGB(150, 110, 75), CFrame.lookAt(at, at + dir), { material = M.WoodPlanks })
			end
		end
		local marker = P(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(bp + Vector3.new(0, 28, 0)), { transparency = 1, collide = false })
		local bbb = Instance.new("BillboardGui")
		bbb.Size = UDim2.fromOffset(300, 50)
		bbb.MaxDistance = 900
		bbb.Parent = marker
		local bt = t:Clone()
		bt.Size = UDim2.fromScale(1, 1)
		bt.Text = "☠ BOSS ARENA"
		bt.TextColor3 = Color3.fromRGB(255, 110, 110)
		bt.Parent = bbb
	end
end

-- helpers a hand-laid island module may use (World/ConchBay.lua ...)
local layoutApi = {
	folderOf = folderOf, npc = npc, makeCtx = makeCtx, foam = foam, chest = chestModel, shipyard = buildShipyard,
	banner = addBannerAndArena, base = buildBase, standardNPCs = standardNPCs, dock = buildDock, placeChests = placeChests,
}
local LAYOUTS = {
	ConchBay = { module = require(script.Parent.ConchBay), seed = 20261122 },
	Marmalade = { module = require(script.Parent.Marmalade), seed = 20261123 },
	Honeyslope = { module = require(script.Parent.Honeyslope), seed = 20261124 },
	Barracuda = { module = require(script.Parent.Barracuda), seed = 20261125 },
	Mikan = { module = require(script.Parent.Mikan), seed = 20261126 },
	Epilogue = { module = require(script.Parent.Epilogue), seed = 20261127 },
	-- R5 Origin home islands (World/OriginIslands): built last, so no generic burn is needed (fresh = true)
	BastionRock = { module = require(script.Parent.OriginIslands).For("BastionRock"), seed = 20261128, fresh = true },
	SmugglersHollow = { module = require(script.Parent.OriginIslands).For("SmugglersHollow"), seed = 20261129, fresh = true },
	ShackleReef = { module = require(script.Parent.OriginIslands).For("ShackleReef"), seed = 20261130, fresh = true },
	InkwellIsle = { module = require(script.Parent.OriginIslands).For("InkwellIsle"), seed = 20261131, fresh = true },
}

-- the island exactly as its builder lays it out (hand-tuned numbers from Islands.WithRaw, at z 0, unturned)
local function buildIslandRaw(island)
	if island.layout == "Daybreak" then
		-- Advance the shared Kit random stream exactly as the previous Daybreak did (built into a detached model
		-- that is thrown away), so every island after it keeps its layout; then build the new Daybreak on its own stream.
		local scratch = Instance.new("Model")
		local prev = Kit.parent
		Kit.parent = scratch
		buildIslandGeneric(Daybreak.LegacyIsland(island))
		Kit.parent = prev
		scratch:Destroy()
		local f
		Kit.WithRng(Random.new(20261117), function()
			f = Daybreak.Build(island, {
				folderOf = folderOf, npc = npc, makeCtx = makeCtx, foam = foam, chest = chestModel,
				shipyard = buildShipyard, banner = addBannerAndArena,
			})
		end)
		return f
	end
	local f
	local layout = island.layout and LAYOUTS[island.layout]
	if layout then
		-- hand-laid island (v0.25.20): burn the old generic build to keep the shared Kit.rng stream where every later
		-- island expects it, then build the new layout on its own stream (same trick as Daybreak)
		if not layout.fresh then
			local scratch = Instance.new("Model")
			local prev = Kit.parent
			Kit.parent = scratch
			buildIslandGeneric(island)
			Kit.parent = prev
			scratch:Destroy()
		end
		Kit.WithRng(Random.new(layout.seed), function()
			f = layout.module.Build(island, layoutApi)
		end)
	else
		f = buildIslandGeneric(island)
	end
	return f
end

-- R5 (remake): scale a finished island around its center (cx, 0, 0) by S, then turn it by yaw and move it to z dz.
-- Everything grows (ground, buildings, trees, docks; y about sea level) except people-size things, which keep their
-- size and only move with the ground: NPC models, chests, and Kit props built inside Kit.Human (they carry the
-- attribute HumanAt = the point they stand on). Position attributes (dock LaunchCf, prop Base, ...) move the same
-- way; EnvProp Height grows with the trees.
local function placeIsland(f, cx, S, yaw, dz)
	local T = CFrame.new(cx, 0, dz) * CFrame.Angles(0, yaw, 0) * CFrame.new(-cx, 0, 0)
	local function sp(v)
		return Vector3.new(cx + (v.X - cx) * S, v.Y * S, v.Z * S)
	end
	local function mapCf(cf)
		return T * (cf.Rotation + sp(cf.Position))
	end
	local function moveAttrs(o)
		for k, v in pairs(o:GetAttributes()) do
			if typeof(v) == "CFrame" then
				o:SetAttribute(k, mapCf(v))
			elseif typeof(v) == "Vector3" then
				o:SetAttribute(k, T * sp(v))
			elseif k == "Height" and type(v) == "number" and S ~= 1 then
				o:SetAttribute(k, v * S)
			end
		end
	end
	-- people-size models: keep the size, move them so their feet land where the ground went
	local keep = {}
	if S ~= 1 then
		for _, tag in ipairs({ "NPC", "Chest" }) do
			for _, m in ipairs(CollectionService:GetTagged(tag)) do
				if m:IsA("Model") and m:IsDescendantOf(f) then
					keep[m] = true
				end
			end
		end
	end
	local function keptModel(o)
		local m = o:FindFirstAncestorWhichIsA("Model")
		while m and m ~= f do
			if keep[m] then
				return m
			end
			m = m:FindFirstAncestorWhichIsA("Model")
		end
		return nil
	end
	moveAttrs(f)
	-- targets first, then assign: welded (unanchored) assemblies would otherwise move twice
	local parts, targets, grow = {}, {}, {}
	for _, o in ipairs(f:GetDescendants()) do
		if o:IsA("BasePart") then
			local km = S ~= 1 and keptModel(o)
			if km then
				-- feet = the bottom of the model's box (computed once per model below)
				table.insert(parts, o)
				table.insert(targets, km)
			else
				local at = o:GetAttribute("HumanAt")
				if S ~= 1 and typeof(at) == "Vector3" then
					table.insert(parts, o)
					table.insert(targets, T * (o.CFrame.Rotation + (sp(at) + (o.Position - at))))
				else
					table.insert(parts, o)
					table.insert(targets, mapCf(o.CFrame))
					if S ~= 1 then
						table.insert(grow, o)
					end
				end
			end
		end
		if not (S ~= 1 and (keep[o] or keptModel(o))) then
			moveAttrs(o)
		end
	end
	-- kept models: one offset per model (bottom center of its box -> scaled + turned)
	local shift = {}
	for m in pairs(keep) do
		local cf, size = m:GetBoundingBox()
		local foot = cf.Position - Vector3.new(0, size.Y / 2, 0)
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			-- NPC (ModelFactory.NPC: root 2.6 above the feet); its box also holds a glow disc sunk into the ground
			foot = hrp.Position - Vector3.new(0, 2.6, 0)
		end
		local to = T * sp(foot)
		shift[m] = { rot = T.Rotation, from = foot, to = to }
		local M = CFrame.new(to) * T.Rotation * CFrame.new(-foot)
		local list = m:GetDescendants()
		table.insert(list, m)
		for _, o in ipairs(list) do
			if not (keep[o] and o ~= m) then -- a kept model inside another one moves with its own offset
				for k, v in pairs(o:GetAttributes()) do
					if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
						o:SetAttribute(k, M * v)
					end
				end
			end
		end
	end
	for i, t in ipairs(targets) do
		if typeof(t) == "Instance" then
			local sh = shift[t]
			targets[i] = CFrame.new(sh.to) * sh.rot * CFrame.new(-sh.from) * parts[i].CFrame
		end
	end
	for _, part in ipairs(grow) do
		part.Size *= S
		for _, c in ipairs(part:GetChildren()) do
			if c:IsA("Attachment") then
				c.Position *= S
			elseif c:IsA("SpecialMesh") then
				c.Scale *= S
			elseif c:IsA("PointLight") or c:IsA("SpotLight") or c:IsA("SurfaceLight") then
				c.Range = math.min(60, c.Range * S)
			elseif c:IsA("JointInstance") then
				c.C0 = c.C0.Rotation + c.C0.Position * S
				c.C1 = c.C1.Rotation + c.C1.Position * S
			elseif c:IsA("SurfaceGui") and c.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
				c.PixelsPerStud /= S
			end
		end
	end
	for i, part in ipairs(parts) do
		part.CFrame = targets[i]
	end
end

local function buildIsland(island)
	-- v0.25.11: islands spread north/south. The builders (and their many absolute coordinates) work at z 0, so
	-- build there and move the finished island, including position attributes (dock LaunchCf / LandCf ...).
	-- v0.25.21: build unturned (Islands.WithRaw swaps the unturned offsets in), then turn by island.yaw.
	-- R5: built with the hand-tuned (unscaled) numbers, then scaled by WorldScale around the island center.
	local dz = island.z or 0
	if island.layout ~= "Daybreak" then
		island.yardAngle = yardAngle(island, dz)
	end
	local f
	IslandsCfg.WithRaw(island, function()
		island.z = nil
		local ok, err = pcall(function()
			f = buildIslandRaw(island)
		end)
		island.z = dz
		if not ok then
			error(err, 0)
		end
	end)
	local S = IslandsCfg.Scale or 1
	local yaw = island.yaw or 0
	if dz ~= 0 or yaw ~= 0 or S ~= 1 then
		placeIsland(f, island.x, S, yaw, dz)
	end
	return f
end

local function buildForts()
	local f = folderOf("Forts", Kit.parent)
	local prev = Kit.parent
	Kit.parent = f
	for _, fort in ipairs(IslandsCfg.Forts) do
		local c = Vector3.new(fort.x, 0, fort.z)
		Cyl(30, 150, Color3.fromRGB(150, 150, 160), c + Vector3.new(0, -10, 0), { material = M.Slate })
		Cyl(2, 140, Color3.fromRGB(190, 185, 175), c + Vector3.new(0, 5.5, 0), { material = M.Cobblestone })
		foam(c + Vector3.new(0, 0.1, 0), 156)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			if i ~= 2 then
				P(Vector3.new(50, 14, 4), Color3.fromRGB(170, 165, 160), CFrame.new(c) * CFrame.Angles(0, a, 0) * CFrame.new(0, 13, 62), { material = M.Brick })
				for k = -2, 2 do
					P(Vector3.new(6, 3, 5), Color3.fromRGB(185, 180, 172), CFrame.new(c) * CFrame.Angles(0, a, 0) * CFrame.new(k * 10, 21.5, 62), { material = M.Brick, decor = true })
				end
			end
			Kit.Tower(c + Vector3.new(math.cos(a) * 64, 0, math.sin(a) * 64), 10, 26, Color3.fromRGB(160, 155, 150), Color3.fromRGB(110, 80, 70), { material = M.Brick })
		end
		local flagPole = c + Vector3.new(0, 6.5, 30)
		local flag = Kit.Flag(flagPole, Color3.fromRGB(240, 240, 240), 24)
		flag.Name = "FortFlag"
		flag:SetAttribute("Fort", fort.id)
		sign(fort.name, CFrame.new(c + Vector3.new(0, 30, -62)), Vector2.new(30, 6), Color3.fromRGB(255, 230, 150))
		local dockIsland = { id = "Fort_" .. fort.id, x = fort.x, z = fort.z, radius = 70, name = fort.name }
		buildDock(dockIsland, math.sign(fort.z) < 0 and 1 or -1)
	end
	Kit.parent = prev
end

-- v0.25.11 (owner plan, docs/Plan-FirstSea.md): stops between the islands: sea stacks to steer around, sandbars
-- with palms, and old wrecks. Own Random + Kit.WithRng so every island layout stays identical.
local function buildIslets(world)
	local f = folderOf("Islets", world)
	local prev = Kit.parent
	Kit.parent = f
	local rand = Random.new(25011)
	local function clear(x, z)
		if WS.WallDist(x, z) < 500 then
			return false
		end
		for _, isl in ipairs(IslandsCfg.List) do
			local bx, bz = isl.x, isl.z or 0
			if (Vector2.new(x - bx, z - bz)).Magnitude < isl.radius + 280 then
				return false
			end
			if isl.boss and isl.boss.atSea then
				local sx, sz = bx + isl.boss.offset.X, bz + isl.boss.offset.Y
				if (Vector2.new(x - sx, z - sz)).Magnitude < 260 then
					return false
				end
			end
		end
		for _, fort in ipairs(IslandsCfg.Forts) do
			if (Vector2.new(x - fort.x, z - fort.z)).Magnitude < 260 then
				return false
			end
		end
		return true
	end
	local function spot()
		for _ = 1, 40 do
			local x = rand:NextNumber(WS.West + 500, WS.East - 500) -- W1: anywhere in the Azure East
			local z = rand:NextNumber(WS.North + 500, WS.BeltN - 400)
			if clear(x, z) then
				return Vector3.new(x, 0, z)
			end
		end
		return nil
	end
	Kit.WithRng(Random.new(25012), function()
		-- sea stacks: tall rock pillars in small groups
		for _ = 1, 14 do
			local c = spot()
			if c then
				for k = 1, rand:NextInteger(2, 4) do
					local p = c + Vector3.new(rand:NextNumber(-40, 40), 0, rand:NextNumber(-40, 40))
					local w, h = rand:NextNumber(14, 26), rand:NextNumber(24, 60)
					P(Vector3.new(w, h + 20, w * rand:NextNumber(0.8, 1.2)), Color3.fromRGB(110, 112, 120):Lerp(Color3.fromRGB(150, 140, 125), rand:NextNumber()),
						CFrame.new(p + Vector3.new(0, h / 2 - 10, 0)) * CFrame.Angles(0, rand:NextNumber(0, 6.28), 0), { material = M.Slate, name = "SeaStack" .. k })
					foam(p + Vector3.new(0, 0.1, 0), w * 1.8)
				end
			end
		end
		-- sandbars with a palm or two
		for _ = 1, 7 do
			local c = spot()
			if c then
				local r = rand:NextNumber(26, 44)
				Cyl(6, r * 2, Color3.fromRGB(245, 222, 160), c + Vector3.new(0, -1.5, 0), { material = M.Sand })
				foam(c + Vector3.new(0, 0.1, 0), r * 2 + 10)
				for _ = 1, rand:NextInteger(1, 2) do
					Kit.Palm(c + Vector3.new(rand:NextNumber(-r * 0.4, r * 0.4), 1.5, rand:NextNumber(-r * 0.4, r * 0.4)))
				end
				Kit.Rock(c + Vector3.new(r * 0.5, 1.5, -r * 0.3), rand:NextNumber(5, 9))
			end
		end
		-- wrecks: a listing broken hull and a snapped mast
		for _ = 1, 5 do
			local c = spot()
			if c then
				local base = CFrame.new(c) * CFrame.Angles(0, rand:NextNumber(0, 6.28), 0) * CFrame.Angles(0, 0, math.rad(rand:NextNumber(14, 26)))
				local wood = Color3.fromRGB(92, 66, 46)
				P(Vector3.new(14, 3, 40), wood, base * CFrame.new(0, -1, 0), { material = M.WoodPlanks })
				for _, sx in ipairs({ -1, 1 }) do
					P(Vector3.new(2, 7, 36), wood:Lerp(Color3.new(0, 0, 0), 0.15), base * CFrame.new(sx * 7, 2, -1), { material = M.WoodPlanks })
				end
				P(Vector3.new(10, 6, 6), wood, base * CFrame.new(0, 2, 18) * CFrame.Angles(math.rad(-20), 0, 0), { material = M.WoodPlanks })
				P(Vector3.new(1.6, 22, 1.6), Color3.fromRGB(120, 84, 56), base * CFrame.new(0, 12, -4) * CFrame.Angles(math.rad(25), 0, math.rad(12)), { material = M.Wood })
				P(Vector3.new(10, 8, 0.3), Color3.fromRGB(200, 190, 165), base * CFrame.new(1, 16, -6) * CFrame.Angles(math.rad(25), 0, math.rad(40)), { material = M.Fabric, collide = false })
				Kit.Barrel(c + Vector3.new(rand:NextNumber(-20, 20), 0.5, rand:NextNumber(-20, 20)))
			end
		end
	end)
	Kit.parent = prev
end

local function buildOcean(world)
	local f = folderOf("Ocean", world)
	local lane = GameConfig.Lane
	local tile = 2048
	-- W1: water over the Azure East, the Doldrums and the Grand Current band south of it (WorldShape draw box).
	-- Windy sea: clear turquoise; Doldrums: dark, glassy water. Tiled in x and z (parts max 2048).
	local x0, x1 = WS.DrawMinX, WS.DrawMaxX
	local x = x0
	while x < x1 - 1 do
		local w = math.min(tile, x1 - x)
		local cx = x + w / 2
		local function strip(z0, z1, color, name, y, refl, transp)
			local z = z0
			while z < z1 - 1 do
				local d = math.min(tile, z1 - z)
				local p = P(Vector3.new(w, 2, d), color, CFrame.new(cx, y, z + d / 2), { parent = f, material = Enum.Material.Glass, transparency = transp, collide = false, shadow = false, name = name })
				p.Reflectance = refl
				z += d
			end
		end
		local farS = WS.DrawMaxZ + 400
		strip(WS.DrawMinZ, WS.BeltN, Color3.fromRGB(40, 175, 230), "Water", -1, 0, 0.25)
		strip(WS.BeltN, WS.BandN, Color3.fromRGB(20, 110, 140), "CalmWater", -1.05, 0.25, 0.15)
		strip(WS.BandN, WS.BandS, Color3.fromRGB(30, 140, 210), "Water", -1, 0, 0.25) -- the Grand Current (locked)
		strip(WS.BandS, WS.BeltS, Color3.fromRGB(20, 110, 140), "CalmWater", -1.05, 0.25, 0.15)
		strip(WS.BeltS, farS, Color3.fromRGB(40, 175, 230), "Water", -1, 0, 0.25)
		-- Foam lines marking the Doldrums edges, and a faint line where the wind starts to fade
		for _, z in ipairs({ WS.BeltN, WS.BandN, WS.BandS, WS.BeltS }) do
			P(Vector3.new(w, 0.3, 6), Color3.fromRGB(240, 250, 255), CFrame.new(cx, 0.1, z), { parent = f, material = Enum.Material.Neon, transparency = 0.35, collide = false, shadow = false, name = "CalmEdge" })
		end
		P(Vector3.new(w, 0.3, 3), Color3.fromRGB(255, 255, 255), CFrame.new(cx, 0.1, WS.BeltN - lane.EdgeWidth), { parent = f, material = Enum.Material.SmoothPlastic, transparency = 0.6, collide = false, shadow = false })
		-- Sea floor
		strip(WS.DrawMinZ, farS, Color3.fromRGB(230, 210, 150), "SeaFloor", -46, 0, 0)
		x += w
	end
	-- Warning buoys along the Doldrums edge (south side of the Azure East)
	local bx = WS.West + 200
	while bx < WS.East - 200 do
		local pos = Vector3.new(bx, 0, WS.BeltN - lane.EdgeWidth * 0.5)
		if WS.WallDist(pos.X, pos.Z) > 300 then
			Cyl(5, 5, Color3.fromRGB(255, 200, 40), pos + Vector3.new(0, 1, 0), { parent = f })
			Ball(2.5, Color3.fromRGB(255, 70, 50), pos + Vector3.new(0, 5, 0), { parent = f, material = Enum.Material.Neon })
		end
		bx += 260
	end
end

-- Sea floor for diving (v0.22.4): a deep teal sand bed under the whole sea, with rocks, coral and seaweed on the
-- slopes around every island. Uses its own Random (never Kit's shared stream) so island layouts stay identical.
-- Kept out of the "Ocean" folder: the swim code raycasts it as the bottom.
local function buildSeaFloor(world)
	local f = folderOf("SeaFloor", world)
	local y = GameConfig.Swim.SeaFloorY
	local tile = 2000
	local x = WS.DrawMinX -- W1: under the whole drawn sea (WorldShape)
	while x < WS.DrawMaxX - 1 do
		local w = math.min(tile, WS.DrawMaxX - x)
		local z = WS.DrawMinZ
		while z < WS.DrawMaxZ - 1 do
			local d = math.min(tile, WS.DrawMaxZ - z)
			P(Vector3.new(w, 4, d), Color3.fromRGB(46, 92, 104), CFrame.new(x + w / 2, y - 2, z + d / 2), { parent = f, material = M.Sand, shadow = false, name = "Floor" })
			z += d
		end
		x += w
	end
	local rand = Random.new(46046)
	local coral = { Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 170, 90), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 230, 120) }
	for _, isl in ipairs(IslandsCfg.List) do
		if not isl.floating then
			local c = Vector3.new(isl.x, y, isl.z or 0)
			local function spot(minR, maxR)
				local a, r = rand:NextNumber(0, math.pi * 2), rand:NextNumber(isl.radius + minR, isl.radius + maxR)
				return c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			for _ = 1, 50 do
				local p, sz = spot(25, 220), rand:NextNumber(3, 9)
				P(Vector3.new(sz, sz * 0.7, sz * 0.9), Color3.fromRGB(70, 90, 96):Lerp(Color3.fromRGB(110, 120, 110), rand:NextNumber()),
					CFrame.new(p + Vector3.new(0, sz * 0.25, 0)) * CFrame.Angles(rand:NextNumber(0, 0.4), rand:NextNumber(0, 6.28), rand:NextNumber(0, 0.4)), { parent = f, material = M.Slate, decor = true })
			end
			for _ = 1, 40 do
				local p, h = spot(20, 200), rand:NextNumber(6, 16)
				P(Vector3.new(0.6, h, 0.25), Color3.fromRGB(60, 150, 80):Lerp(Color3.fromRGB(120, 170, 60), rand:NextNumber()),
					CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rand:NextNumber(-0.2, 0.2), rand:NextNumber(0, 6.28), rand:NextNumber(-0.2, 0.2)), { parent = f, material = M.Grass, collide = false, decor = true, shadow = false })
			end
			for _ = 1, 24 do
				local p = spot(25, 160)
				local col = coral[rand:NextInteger(1, #coral)]
				for k = 1, 3 do
					local h = rand:NextNumber(2, 5)
					P(Vector3.new(0.8, h, 0.8), col, CFrame.new(p + Vector3.new(rand:NextNumber(-1.2, 1.2), h / 2, rand:NextNumber(-1.2, 1.2))) * CFrame.Angles(rand:NextNumber(-0.4, 0.4), 0, rand:NextNumber(-0.4, 0.4)), { parent = f, material = M.Slate, collide = false, decor = true })
					Ball(1.4 + k * 0.2, col:Lerp(Color3.new(1, 1, 1), 0.15), p + Vector3.new(rand:NextNumber(-1.5, 1.5), h, rand:NextNumber(-1.5, 1.5)), { parent = f, material = M.Slate, collide = false, decor = true })
				end
			end
		end
	end
end

-- W1 (owner, 28 Nov 2026, docs/Plan-WorldMap.md): the Crimson Wall runs north-south through the middle of the world
-- (the Azure East's west side), world-edge walls close its north and east sides, and Backflow Peak rises where the wall
-- crosses the Grand Current band (the sea's south-west corner). Own Random (never touch Kit's shared stream).
-- Wall v2 (owner refs: towering red cliffs of columnar rock wrapped in cloud bands, a ship tiny at the foot; the climb
-- = a narrow canyon of sheer column walls with the water rushing up it): every sea-facing face is a row of stone
-- columns (each juts out its own amount, stepped tops, 2-4 shaded segments), two cloud bands wrap the faces, and
-- Backflow Peak is a heightfield of columns on a grid turned along the canal, cut by the canyon the water climbs.
-- Built AFTER Voxelize / DeFlicker (WB.Build runs Voxelize on this model alone): nothing here overlaps coplanar.
-- Every big block is cut into <= 2000-stud pieces (Roblox caps a part at 2048).
local function buildRedLine(world)
	local f = folderOf("RedLine", world)
	local rl = IslandsCfg.RedLine
	local rand = Random.new(51051)
	local H = rl.height -- the wall
	local PEAK = rl.peakHeight or H * 1.3 -- the mountain's summit
	-- rock palette: deep red, red, salmon, pale (a column picks one, its segments vary around it)
	-- warm and bright on purpose: the sea's blue haze turns a far 2000-stud cliff purple, and darker reds got worse;
	-- these orange-reds read as red / terracotta through it (tested in Play at 1400 studs)
	local ROCK = { Color3.fromRGB(170, 59, 11), Color3.fromRGB(225, 78, 15), Color3.fromRGB(255, 101, 34), Color3.fromRGB(255, 130, 77) }
	local BODY = Color3.fromRGB(209, 74, 16)
	local LEDGE = Color3.fromRGB(110, 36, 18)
	local function rock(k)
		local i = math.clamp(k, 0, 0.999) * (#ROCK - 1)
		local a = math.floor(i)
		return ROCK[a + 1]:Lerp(ROCK[a + 2], i - a)
	end
	local function block(size, cf, color, opts)
		opts = opts or {}
		opts.parent = opts.parent or f
		opts.material = opts.material or M.Rock
		return P(size, color, cf, opts)
	end
	local function slab(x0, x1, z0, z1, y0, y1, color, mat)
		local x = x0
		while x < x1 - 0.5 do
			local w = math.min(2000, x1 - x)
			local z = z0
			while z < z1 - 0.5 do
				local d = math.min(2000, z1 - z)
				block(Vector3.new(w, y1 - y0, d), CFrame.new(x + w / 2, (y0 + y1) / 2, z + d / 2), color, { material = mat })
				z += d
			end
			x += w
		end
	end
	-- a wall block: rock body with a grass top (its sea faces get columns below)
	local function wall(x0, x1, z0, z1, top)
		top = top or H
		slab(x0, x1, z0, z1, -40, top, BODY)
		slab(x0, x1, z0, z1, top, top + 24, Color3.fromRGB(110, 170, 84), M.Grass)
	end

	-- a sea-facing face from a to b (Vector2, world x/z), `out` = unit normal into the sea: a row of columns
	local function face(a, b, out)
		local len = (b - a).Magnitude
		local along = (b - a).Unit
		local out3 = Vector3.new(out.X, 0, out.Y)
		local along3 = Vector3.new(along.X, 0, along.Y)
		local s = 0
		local h = H * 0.9
		while s < len - 4 do
			local w = math.min(rand:NextNumber(40, 110), len - s)
			-- the skyline wanders, with a deep notch now and then
			h = math.clamp(h + rand:NextNumber(-0.09, 0.09) * H, H * 0.62, H + 70)
			local top = h
			if rand:NextNumber() < 0.07 then
				top = h * rand:NextNumber(0.55, 0.8)
			end
			local base = rand:NextNumber()
			local depth = rand:NextNumber(16, 80)
			local mid = a + along * (s + w / 2)
			-- stacked drums (owner v2 review: one long block per column read as sticks): each drum its own depth and
			-- shade, and most joints get a dark jutting ledge, so the cliff reads as jointed, weathered rock
			local y0 = -40
			while y0 < top - 8 do
				local y1 = math.min(top, y0 + rand:NextNumber(140, 380))
				if top - y1 < 60 then
					y1 = top
				end
				local d = math.max(10, depth + rand:NextNumber(-26, 26))
				local c = rock(math.clamp(base + rand:NextNumber(-0.2, 0.2) + (y1 / H) * 0.15, 0, 1))
				local center = Vector3.new(mid.X, (y0 + y1) / 2, mid.Y) + out3 * (d / 2)
				block(Vector3.new(w, y1 - y0, d), CFrame.fromMatrix(center, along3, Vector3.yAxis), c)
				if y1 < top and rand:NextNumber() < 0.6 then
					local lh = rand:NextNumber(4, 10)
					local ld = d + rand:NextNumber(6, 16)
					local lc = Vector3.new(mid.X, y1 - lh / 2, mid.Y) + out3 * (ld / 2)
					block(Vector3.new(w + 0.6, lh, ld), CFrame.fromMatrix(lc, along3, Vector3.yAxis), LEDGE:Lerp(c, rand:NextNumber(0, 0.35)))
				end
				y0 = y1
			end
			-- fallen blocks at the foot, half in the surf
			if rand:NextNumber() < 0.22 then
				local sz = rand:NextNumber(18, 46)
				local p = Vector3.new(mid.X, sz * 0.2, mid.Y) + out3 * (depth + sz * rand:NextNumber(0.4, 1.4)) + along3 * rand:NextNumber(-20, 20)
				block(Vector3.new(sz, sz, sz * rand:NextNumber(0.7, 1.2)), CFrame.fromMatrix(p, along3, Vector3.yAxis) * CFrame.Angles(0, rand:NextNumber(-0.4, 0.4), 0), rock(rand:NextNumber(0, 0.4)))
			end
			s += w
		end
	end

	-- clouds: voxel puffs = a heaped clump of blocks (wide flat belly, rounder bumps on top, a blue-grey underside),
	-- long along `along3` (owner v2 review: thin single slabs read as floating planks)
	local CLOUD = Color3.fromRGB(250, 252, 255)
	local BELLY = Color3.fromRGB(206, 220, 240)
	local function puff(c, along3, l)
		local out3 = along3:Cross(Vector3.yAxis)
		local opts = function()
			return { material = M.SmoothPlastic, transparency = rand:NextNumber(0.03, 0.12), collide = false, shadow = false }
		end
		-- the belly: one long flat block
		local bd = rand:NextNumber(160, 260)
		block(Vector3.new(l, rand:NextNumber(40, 60), bd), CFrame.fromMatrix(c - Vector3.new(0, 30, 0), along3, Vector3.yAxis), BELLY, opts())
		-- heaps on top, bigger toward the middle
		for _ = 1, rand:NextInteger(6, 10) do
			local t = rand:NextNumber(-0.42, 0.42)
			local k = 1 - math.abs(t) * 1.3
			local sx = l * rand:NextNumber(0.18, 0.36)
			local sy = rand:NextNumber(60, 150) * k + 30
			local sz = bd * rand:NextNumber(0.55, 0.9)
			local p = c + along3 * (t * l) + Vector3.new(0, sy / 2 - 20 + rand:NextNumber(0, 20), 0) + out3 * rand:NextNumber(-40, 40)
			block(Vector3.new(sx, sy, sz), CFrame.fromMatrix(p, along3, Vector3.yAxis), CLOUD, opts())
		end
	end
	-- cloud bands hugging a face at one height, gaps between the puffs
	local function cloudBand(a, b, out, y, off)
		local len = (b - a).Magnitude
		local along = (b - a).Unit
		local out3 = Vector3.new(out.X, 0, out.Y)
		local along3 = Vector3.new(along.X, 0, along.Y)
		local s = rand:NextNumber(0, 300)
		while s < len do
			local l = math.min(rand:NextNumber(380, 900), len - s)
			if l > 160 then
				local mid = a + along * (s + l / 2)
				puff(Vector3.new(mid.X, y + rand:NextNumber(-70, 70), mid.Y) + out3 * (off + rand:NextNumber(100, 180)), along3, l)
			end
			s += l + rand:NextNumber(60, 320)
		end
	end

	local pk, wh, e = WS.Peak, WS.WallHalf, WS.Edge
	local southEnd = WS.DrawMaxZ + 600
	-- the middle wall north and south of the mountain (it runs into the mountain's flanks), the world edges
	wall(pk.X - wh, pk.X + wh, WS.North - e, pk.Y - WS.MountR * 0.55)
	wall(pk.X - wh, pk.X + wh, pk.Y + WS.MountR * 0.55, southEnd)
	wall(pk.X - wh, WS.East + e, WS.North - e, WS.North)
	wall(WS.East, WS.East + e, WS.North, southEnd)
	-- the faces the Azure East sees: west (the Crimson Wall), north and east edges
	local westEnd = pk.Y - math.sqrt(WS.MountR ^ 2 - wh ^ 2) + 40 -- where the wall face meets the mountain
	local faces = {
		{ Vector2.new(WS.West, WS.North), Vector2.new(WS.West, westEnd), Vector2.new(1, 0) },
		{ Vector2.new(WS.West, WS.North), Vector2.new(WS.East, WS.North), Vector2.new(0, 1) },
		{ Vector2.new(WS.East, WS.North), Vector2.new(WS.East, WS.BeltS), Vector2.new(-1, 0) },
	}
	for _, fc in ipairs(faces) do
		face(fc[1], fc[2], fc[3])
		cloudBand(fc[1], fc[2], fc[3], H * 0.38, 40)
		cloudBand(fc[1], fc[2], fc[3], H * 0.7, 10)
	end

	-- ===== Backflow Peak =====
	-- a grid of rock columns turned along the canal: u = distance from the Peak toward the Mouth, v = across it.
	-- Height profile: a sheer cliff right at the foot (the canyon's walls are tall from the first step), then a long
	-- rise to the summit. The canyon (|v| <= one cell) is cut down to just under the water, which climbs from the
	-- Mouth (sea level) to the summit pass at CLIMB.
	local dir = WS.MouthDir
	local u3 = Vector3.new(dir.X, 0, dir.Y)
	local v3 = Vector3.new(-dir.Y, 0, dir.X)
	local CELL = 120
	local R = WS.MountR
	local r0, r1 = R + 100, 300 -- the water: from the Mouth (u = r0) to the summit pass (u = r1)
	local CLIMB = PEAK * 0.7
	local function waterY(u)
		return math.clamp((r0 - u) / (r0 - r1), 0, 1) * CLIMB - 6
	end
	local function smooth(x)
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	local function heightAt(r)
		local t = 1 - r / R
		return PEAK * (0.42 * smooth(t / 0.14) + 0.58 * math.max(0, t) ^ 1.6)
	end
	local nCells = math.ceil(R / CELL) + 1
	for iu = -nCells, nCells do
		for iv = -nCells, nCells do
			local u, v = iu * CELL, iv * CELL
			local r = math.sqrt(u * u + v * v) + rand:NextNumber(-50, 50) -- a ragged foot
			if r < R then
				local canyon = math.abs(iv) <= 1 and u > -r1
				local top
				if canyon then
					-- the floor under the water: below the lowest water line in this cell (its Mouth-side edge)
					top = waterY(u + CELL / 2) - 24
				else
					top = heightAt(r) * rand:NextNumber(0.9, 1.08) + (math.abs(iv) == 2 and u > 0 and PEAK * 0.04 or 0)
				end
				if top > 4 then
					local base = math.clamp(top / PEAK, 0, 1)
					local c = canyon and rock(0.05) or rock(math.clamp(base * 0.75 + rand:NextNumber(-0.15, 0.15), 0, 1))
					local center = pk.X * Vector3.xAxis + pk.Y * Vector3.zAxis + u3 * u + v3 * v
					local y0 = -40
					-- tall columns break into two shades (an upper band), like the wall faces
					if not canyon and top > 400 then
						local cut = top * rand:NextNumber(0.45, 0.7)
						block(Vector3.new(CELL, cut - y0, CELL), CFrame.fromMatrix(center + Vector3.new(0, (y0 + cut) / 2, 0), v3, Vector3.yAxis), rock(math.clamp(base * 0.5 + rand:NextNumber(-0.1, 0.1), 0, 1)))
						y0 = cut
					end
					block(Vector3.new(CELL, top - y0, CELL), CFrame.fromMatrix(center + Vector3.new(0, (y0 + top) / 2, 0), v3, Vector3.yAxis), c)
					if not canyon and base > 0.86 then -- snow-pale caps at the summit
						block(Vector3.new(CELL, 10, CELL), CFrame.fromMatrix(center + Vector3.new(0, top + 5, 0), v3, Vector3.yAxis), Color3.fromRGB(245, 236, 226))
					end
				end
			end
		end
	end
	-- the water rushing UP the canyon: one ramp from the Mouth to the summit pass, then flat over the pass
	local a3 = Vector3.new(WS.Mouth.X, waterY(r0), WS.Mouth.Y)
	local top2 = pk + dir * r1
	local b3 = Vector3.new(top2.X, waterY(r1), top2.Y)
	local len = (b3 - a3).Magnitude
	local rampCf = CFrame.lookAt((a3 + b3) / 2, b3)
	local water = block(Vector3.new(rl.canalWidth, 3, len), rampCf, Color3.fromRGB(110, 215, 255), { material = M.Glass, transparency = 0.15, collide = false, name = "ReverseWater" })
	CollectionService:AddTag(water, "ReverseWater")
	block(Vector3.new(rl.canalWidth, 3, r1 * 2), CFrame.fromMatrix(Vector3.new(pk.X, waterY(r1), pk.Y), v3, Vector3.yAxis), Color3.fromRGB(110, 215, 255), { material = M.Glass, transparency = 0.15, collide = false, name = "ReverseWater" })
	for i = 0, 13 do -- white rapids up the ramp
		local foamPart = block(Vector3.new(rl.canalWidth - 8, 3.4, 18), rampCf * CFrame.new(0, 0.4, len / 2 - (i + 0.5) * len / 14), Color3.fromRGB(240, 252, 255), { material = M.Neon, transparency = 0.45, collide = false, shadow = false, name = "Foam" })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 26) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Rate = 14
		pe.Speed = NumberRange.new(40, 70)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Acceleration = Vector3.new(0, 60, 0)
		pe.Parent = foamPart
	end
	-- spray where the sea meets the canyon, then the entrance arch facing the sea (visible from afar)
	local mouth3 = Vector3.new(WS.Mouth.X, 0, WS.Mouth.Y)
	block(Vector3.new(rl.canalWidth * 2.2, 1, rl.canalWidth * 1.4), CFrame.fromMatrix(mouth3 + u3 * 80 + Vector3.new(0, 0.3, 0), v3, Vector3.yAxis), Color3.fromRGB(170, 235, 255), { material = M.Neon, transparency = 0.55, collide = false, shadow = false })
	local gate = mouth3 + u3 * 160
	local half = rl.canalWidth / 2
	for _, s in ipairs({ -1, 1 }) do
		local post = gate + v3 * s * (half + 24)
		block(Vector3.new(26, 170, 26), CFrame.new(post + Vector3.new(0, 85, 0)), Color3.fromRGB(250, 240, 220), { material = M.Marble })
		block(Vector3.new(36, 36, 36), CFrame.new(post + Vector3.new(0, 188, 0)), Color3.fromRGB(255, 210, 80), { material = M.SmoothPlastic })
	end
	block(Vector3.new(rl.canalWidth + 90, 28, 28), CFrame.fromMatrix(gate + Vector3.new(0, 170, 0), v3, Vector3.yAxis), Color3.fromRGB(250, 240, 220), { material = M.Marble })
	local signPos = gate + u3 * 14.5 + Vector3.new(0, 170, 0)
	local s = sign(string.upper(rl.peakName) .. "  •  " .. string.upper(rl.nextSea) .. "  (Lv." .. GameConfig.GrandLineLevel .. ")", CFrame.lookAt(signPos, signPos + u3), Vector2.new(rl.canalWidth + 60, 22), Color3.fromRGB(255, 230, 120), Color3.fromRGB(150, 40, 40))
	s.Parent = f
	-- cloud rings around the mountain at two heights (just outside its slope there) and a cap over the summit
	for _, y in ipairs({ PEAK * 0.3, PEAK * 0.55 }) do
		local r = R
		while r > 50 and heightAt(r) < y do
			r -= 40
		end
		local ring = 0
		while ring < math.pi * 2 do
			local step = rand:NextNumber(0.12, 0.3)
			local a = ring + step / 2
			local rr = r + rand:NextNumber(60, 220)
			local l = rr * step * rand:NextNumber(0.6, 0.95)
			local p = pk + Vector2.new(math.cos(a), math.sin(a)) * rr
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			if l > 120 then
				puff(Vector3.new(p.X, y + rand:NextNumber(-60, 60), p.Y), tangent, l)
			end
			ring += step + rand:NextNumber(0.05, 0.25)
		end
	end
	for _ = 1, 6 do -- a cap of cloud over the summit
		local a, r = rand:NextNumber(0, math.pi * 2), rand:NextNumber(0, 600)
		puff(Vector3.new(pk.X + math.cos(a) * r, PEAK + rand:NextNumber(60, 220), pk.Y + math.sin(a) * r), Vector3.new(math.cos(a + 1.3), 0, math.sin(a + 1.3)), rand:NextNumber(300, 520))
	end
end

local function setupLighting()
	local function ensure(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	local atm = ensure("Atmosphere", "Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(200, 230, 255)
	atm.Decay = Color3.fromRGB(120, 170, 220)
	atm.Glare = 0.3
	atm.Haze = 1.4
	local cc = ensure("ColorCorrectionEffect", "Stylize")
	cc.Saturation = 0.28
	cc.Contrast = 0.08
	cc.Brightness = 0.03
	cc.TintColor = Color3.fromRGB(255, 250, 240)
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	ensure("Sky", "Sky")
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20
end

-- ===== Public =====
-- Bump when the world's code changes in a way the baked map must pick up: a baked World with another version is thrown
-- away and rebuilt from code at server start (so the owner's published place updates through Rojo too).
-- Hand-built content made in Studio goes in workspace.Handmade (never touched by rebuilds). Kit props placed there
-- (tagged EnvProp/EnvPart) are dressed with the stylized meshes like the generated ones.
WB.WORLD_VERSION = 52 -- v52 (0.1.31-remake): Crimson Wall v2 = columnar red cliffs + cloud bands, Backflow Peak = a mountain of columns cut by the canyon the water climbs; v51 (0.1.30-remake, W1): the world is four seas around a cross: the Azure East is its north-east quarter (islands moved, walls on three sides, Backflow Peak in the south-west corner); v50 (0.1.29-remake): a Trader NPC on each Origin home island; v49 (0.1.26-remake, R5): four Origin home islands west of Daybreak (World/OriginIslands); v48 (0.1.24-remake, R5): islands built x GameConfig.WorldScale (1.5) around their center, people-size props keep their size; v47 (0.1.10-remake): no Job Master NPC (spots stay reserved); v46 (v0.25.150): no shipyard platform, the slips float (boardwalk only); v45 (v0.25.149): Courier Gull Post at every harbor, Marine Registrar by the Conch Bay stairs; v44 (v0.25.148): roof ridges sit on the stepped roof (no floating beam); v43 (v0.25.147): voxel stadium big top + the Confetti Crew occupying Marmalade; v42 (v0.25.146): Big Top for Captain Confetti, Epilogue execution platform; v41 (v0.25.143): a look of their own for every island quest giver; v40 (v0.25.142): one Tavern Keeper on Daybreak (inside the tavern); v39 (v0.25.141): tavern awning above the doorway; v38 (v0.25.140): enterable Daybreak tavern / smithy / store with their NPC inside; v37 (v0.25.134): organic voxel island outlines (IslandShape); v36 v36 (v0.25.133): Epilogue Town hand-laid; v35 v35 (v0.25.132): Mikan Isles hand-laid; v34 (v0.25.131): Barracuda Bistro hand-laid (World/Barracuda); v33 (v0.25.130): Honeyslope hand-laid (World/Honeyslope); v32 (v0.25.129): the Brig (jail cell) at the Conch Bay garrison; v31 (v0.25.120): Power board is a map piece in front of the west house; v30 (v0.25.119): Bounty Board moved to the west street house; v29 (v0.25.118): Job Master walk-in ring + new look; v28 (v0.25.115): DeFlicker stacks faces within 0.035 (grass under the plaza paving); v27 (v0.25.113): no Bay Serpent buoys/sign, wooden shipyard plots, voxel barrels/crates/chests; v26 (v0.25.112): DeFlicker pass, hill caps one step apart per lobe; v25 (v0.25.109): no island name signs at the docks; v24 (v0.25.108): Marine Registrar in Conch Bay, no Guild Registrar; v23 (v0.25.107): Tavern Keeper beside the Shipwright; v22 (v0.25.27): shipyards snap to the island side nearest the next island; v21 (v0.25.25): shipyards face the next island, circus ship offshore; v20 (v0.25.24): Marmalade Town hand-laid (World/Marmalade); v19 (v0.25.23): Conch Bay street spawns keep their houses; v18 (v0.25.22): Conch Bay terraced (quay, two terraces, garrison plateau, tapered towers); v17 (v0.25.21): islands turned to face the previous one, Conch Bay stairs; v16 (v0.25.20): Daybreak spawn by Rowan, Conch Bay hand-laid (World/ConchBay); v15 (v0.25.11): islands spread north/south, wider sea, islets; v14 (v0.25.6): Daybreak spawn by the campfire; v13: voxel NPCs; v12: Voxelize pass

-- Old copies of the map can hide anywhere in Workspace: a renamed or regrouped World, an island dragged into
-- Handmade, single NPCs / chests / docks pasted from an old bake. They draw on top of the new islands and register
-- duplicate NPCs, chests, docks and spawns. Owner's call (v0.22.2): only the current map may exist, so every generated
-- piece outside `keep` is removed, wherever it is (Handmade included). Generated pieces are recognised by what
-- WorldBuilder puts on them: a whole island folder holds its IslandSpawn part / IslandBanner, a whole map has a
-- WorldVersion attribute or an Ocean, and NPC / Chest / Dock / Plot tags mark the working props.
local MARKER_TAGS = { "IslandSpawn", "Dock", "Plot", "Chest", "NPC" }
function WB.RemoveStaleMaps(keep)
	local doomed = {}
	local function outside(inst)
		return inst.Parent ~= nil and inst ~= keep and not inst:IsDescendantOf(keep) and inst:IsDescendantOf(workspace)
	end
	local function container(inst)
		-- never the workspace or the Handmade folder itself
		local p = inst
		if p == workspace or (p.Parent == workspace and p.Name == "Handmade") then
			return nil
		end
		return p
	end
	-- a list, not a table keyed by instance: the Lune bake hands out a new userdata per access
	local function mark(inst, why)
		inst = inst and container(inst)
		if not (inst and outside(inst)) then
			return
		end
		for _, e in ipairs(doomed) do
			if e.inst == inst then
				return
			end
		end
		table.insert(doomed, { inst = inst, why = why })
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if outside(d) then
			if d:GetAttribute("WorldVersion") ~= nil then
				mark(d, "old map")
			elseif d:GetAttribute("IslandBanner") ~= nil or d:HasTag("IslandSpawn") then
				-- the island's spawn point and banner sit directly in its island folder
				mark(d.Parent, "old island " .. tostring(d:GetAttribute("IslandBanner") or d:GetAttribute("Island")))
			elseif d.Name == "Ocean" and (d:IsA("Model") or d:IsA("Folder")) and d:FindFirstChild("Water") then
				mark(d, "old ocean")
			elseif (d:IsA("Model") or d:IsA("Folder")) and (d.Name == "RedLine" or d.Name == "Forts" or d.Name == "Islets" or d.Name == "SeaFloor")
				and (d:FindFirstChild("Foam") or d:FindFirstChild("ReverseWater") or d:FindFirstChild("Floor")) then
				-- W1: whole-sea pieces of an old map left loose in the workspace (the main-era Crimson Wall + forts sat
				-- at the workspace root, out at x 12800)
				mark(d, "old " .. d.Name)
			end
			for _, tag in ipairs(MARKER_TAGS) do
				if d:HasTag(tag) then
					mark(d, "old " .. tag .. " " .. d.Name)
					break
				end
			end
		end
	end
	-- keep only the outermost pieces (decide everything before destroying anything)
	local roots = {}
	for _, e in ipairs(doomed) do
		local covered = false
		for _, o in ipairs(doomed) do
			if o.inst ~= e.inst and e.inst:IsDescendantOf(o.inst) then
				covered = true
				break
			end
		end
		if not covered then
			table.insert(roots, e)
		end
	end
	local n = 0
	for _, r in ipairs(roots) do
		print("[GrandVoyage] removing " .. r.why .. ": " .. r.inst:GetFullName())
		r.inst:Destroy()
		n += 1
	end
	if n > 0 then
		print(string.format("[GrandVoyage] removed %d leftover piece(s) of old maps; only the v%d World is left", n, WB.WORLD_VERSION))
	end
	return n
end

function WB.Build()
	if not workspace:FindFirstChild("Handmade") then
		local hm = Instance.new("Folder")
		hm.Name = "Handmade"
		hm.Parent = workspace
	end
	-- A place can hold more than one generated map (a second "World", a renamed copy, an old bake pasted in):
	-- keep only one current-version World and throw every other generated map away, or islands draw on top of
	-- each other. A generated map is recognised by its WorldVersion attribute or by its Ocean + Daybreak children.
	local keep
	for _, c in ipairs(workspace:GetChildren()) do
		local generated = c:GetAttribute("WorldVersion") ~= nil or (c:FindFirstChild("Ocean") ~= nil and c:FindFirstChild("Daybreak") ~= nil)
		if generated then
			if not keep and c.Name == "World" and c:GetAttribute("WorldVersion") == WB.WORLD_VERSION then
				keep = c
			else
				print("[GrandVoyage] removing old map " .. c:GetFullName() .. " (version " .. tostring(c:GetAttribute("WorldVersion")) .. "), building v" .. WB.WORLD_VERSION)
				c:Destroy()
			end
		end
	end
	if keep then
		WB.RemoveStaleMaps(keep)
		return keep
	end
	local world = Instance.new("Model")
	world.Name = "World"
	world:SetAttribute("WorldVersion", WB.WORLD_VERSION)
	world.Parent = workspace
	Kit.parent = world
	buildOcean(world)
	buildSeaFloor(world)
	for _, island in ipairs(IslandsCfg.List) do
		buildIsland(island)
	end
	buildForts()
	buildIslets(world)
	-- v0.24.0 (owner): everything round or sloped becomes blocks (World/Voxelize)
	local okVox, voxErr = pcall(require(script.Parent.Voxelize).Run, world)
	if not okVox then
		warn("[WorldBuilder] voxelize failed:", voxErr)
	end
	-- v0.25.112 (owner): lift pieces off coplanar faces so nothing z-fights (World/DeFlicker)
	local okDf, dfErr = pcall(require(script.Parent.DeFlicker).Run, world)
	if not okDf then
		warn("[WorldBuilder] deflicker failed:", dfErr)
	end
	-- W1 wall v2: after Voxelize / DeFlicker (thousands of plain blocks they never need to look at)
	local okRl, rlErr = pcall(buildRedLine, world)
	if not okRl then
		warn("[WorldBuilder] Crimson Wall failed:", rlErr)
	end
	setupLighting()
	WB.RemoveStaleMaps(world)
	return world
end

local function talkTo(player, entry)
	local Net = require(Shared.Modules.Net)
	-- quest NPCs (and quest steps that say "talk to X") get first say
	if R and R.QuestService then
		R.QuestService.OnTalk(player, entry.role, entry.island)
	end
	if entry.role ~= "Guide" then
		Net.Push(player, "OpenUI", { panel = entry.role, island = entry.island, dungeonId = entry.model:GetAttribute("DungeonId") })
	end
end

local function register()
	npcs, plots, docks, spawns = {}, {}, {}, {}
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
		local entry = { model = m, role = m:GetAttribute("Role"), island = m:GetAttribute("Island"), pos = m:GetPivot().Position }
		table.insert(npcs, entry)
		if prompt then
			prompt.Triggered:Connect(function(player)
				talkTo(player, entry)
			end)
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Plot")) do
		local plot = { part = p, origin = p:GetAttribute("Origin"), standCf = p:GetAttribute("StandCf"), island = p:GetAttribute("Island") }
		plot.folder = p.Parent
		table.insert(plots, plot)
	end
	for _, d in ipairs(CollectionService:GetTagged("Dock")) do
		table.insert(docks, { islandId = d:GetAttribute("Island"), pos = d.Position, launchCf = d:GetAttribute("LaunchCf"), landCf = d:GetAttribute("LandCf") })
	end
	for _, s in ipairs(CollectionService:GetTagged("IslandSpawn")) do
		-- owner (v0.22.3): no glowing spawn pad, players just appear (also hides the pad in maps baked before that)
		s.Transparency = 1
		s.CastShadow = false
		spawns[s:GetAttribute("Island")] = s.CFrame
	end
end

function WB.Init(registry)
	R = registry
	WB.Build()
	register()
	-- v0.25.112 (owner): shop NPCs stand in a glowing ring; walking into it opens their window (client
	-- Controllers/NpcZones asks, the server checks the player really stands in that NPC's ring)
	require(Shared.Modules.Net).Handle("ZoneEnter", function(player, data)
		local role = type(data) == "table" and data.role
		if type(role) ~= "string" or not WB.ZONE_ROLES[role] then
			return false
		end
		local ok, n = WB.NearNPC(player, role, WB.ZONE_RADIUS + 3)
		if not ok then
			return false
		end
		talkTo(player, n)
		return true
	end, 0.5)
end

function WB.Start() end

function WB.GetSpawn(islandId)
	return spawns[islandId] or spawns[IslandsCfg.StartIsland] or CFrame.new(0, 20, 0)
end

local function playerPos(player)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

-- remake R2: the first NPC with that role on that island (OriginService start spots)
function WB.FindNPC(role, islandId)
	for _, n in ipairs(npcs) do
		if n.role == role and (islandId == nil or n.island == islandId) then
			return n
		end
	end
	return nil
end

function WB.NearNPC(player, role, range)
	local pos = playerPos(player)
	if not pos then
		return false
	end
	for _, n in ipairs(npcs) do
		if n.role == role and (n.pos - pos).Magnitude <= (range or 24) then
			return true, n
		end
	end
	return false
end

function WB.FreePlotNear(player, owners)
	local pos = playerPos(player)
	if not pos then
		return nil
	end
	local best, bestD = nil, 220
	for _, plot in ipairs(plots) do
		local d = (plot.part.Position - pos).Magnitude
		if not owners[plot] and d < bestD then
			best, bestD = plot, d
		end
	end
	return best
end

function WB.NearestDock(pos)
	local best, bestD = nil, math.huge
	for _, d in ipairs(docks) do
		local dist = (Vector2.new(d.pos.X, d.pos.Z) - Vector2.new(pos.X, pos.Z)).Magnitude
		if dist < bestD then
			best, bestD = d, dist
		end
	end
	if not best then
		return nil
	end
	return { islandId = best.islandId, distance = bestD, launchCf = best.launchCf, landCf = best.landCf }
end

return WB
