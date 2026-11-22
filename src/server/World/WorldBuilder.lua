-- WorldBuilder: builds the Azure East procedurally in a bright low-poly cartoon style.
-- Islands sit in a straight line; the sea between them is the sailing lane, the far edges are the
-- Doldrums, and the Crimson Wall closes the route at the end.
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
-- face (optional): local X/Z point the NPC looks at (default: the island center)
local function npc(ctx, role, title, color, hat, x, z, extra, face)
	local island = ctx.island
	local ModelFactory = require(script.Parent.ModelFactory)
	local m = ModelFactory.NPC(title, color, hat)
	local pos = Vector3.new(island.x + x, 0, (island.z or 0) + z)
	local ground = island.floating and 8 or 7.6 -- fixed so the map can be baked outside Studio
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
	Cyl(0.3, 8, Color3.fromRGB(255, 210, 90), Vector3.new(pos.X, ground + 0.85, pos.Z), { material = M.Neon, transparency = 0.5, collide = false, decor = true })
	ModelFactory.Billboard(m.PrimaryPart, title, extra and extra.SubTitle or nil, Color3.fromRGB(255, 230, 120), 5.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = m.PrimaryPart
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
	npc(ctx, "Tavern", "Tavern Keeper", Color3.fromRGB(200, 90, 90), nil, -r * 0.6, -r * 0.4, { SubTitle = "Hire Crew" })
	npc(ctx, "FastTravel", "Courier Gull Post", Color3.fromRGB(240, 240, 240), "marine", -r * 0.65, r * 0.35, { SubTitle = "Fast Travel" })
	npc(ctx, "Guide", Quests.Guide[island.id] or "Guide", Color3.fromRGB(255, 200, 90), "captain", r * 0.32, r * 0.05, { SubTitle = "📜 Quests" })
	-- v0.25.21 (owner): Bounty Board and Guild Registrar only on the first and the last island
	if island.id == "Daybreak" or island.id == "Epilogue" then
		npc(ctx, "BossBoard", "Bounty Board", Color3.fromRGB(255, 220, 120), nil, r * 0.15, r * 0.7, { SubTitle = "Bosses & Bounties" })
		npc(ctx, "JobMaster", "Job Master", Color3.fromRGB(120, 200, 140), "marine", r * 0.6, r * 0.45, { SubTitle = "Choose a Class" })
		npc(ctx, "Guild", "Guild Registrar", Color3.fromRGB(90, 90, 200), "marine", -r * 0.15, r * 0.8, { SubTitle = "Marine / Pirate Guilds" })
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
	sign(island.name, CFrame.new(x0 + side * 6, dockY + 10, zc - 10) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0), Vector2.new(18, 4))
end

-- v0.25.25 (owner): the shipyard sits on the side that faces the NEXT island, so you launch toward where you are
-- going instead of crossing the island (it used to be fixed at local east and often faced the Doldrums).
-- Angle (local, before the island's own yaw) that turns the default east yard; nil = keep (Daybreak).
local function yardAngle(island, worldZ)
	local nxt = island.index and IslandsCfg.List[island.index + 1]
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
	P(Vector3.new(totalW + 20, 2, l + 24), Color3.fromRGB(175, 125, 80), CFrame.new(baseX + totalW / 2 - 10, 4, platformZ), { material = M.WoodPlanks })
	for i = 0, 6 do
		Cyl(14, 2.4, Color3.fromRGB(110, 74, 46), Vector3.new(baseX - 8 + i * (totalW + 16) / 6, -3, platformZ + l / 2 + 10), { material = M.Wood })
		Cyl(14, 2.4, Color3.fromRGB(110, 74, 46), Vector3.new(baseX - 8 + i * (totalW + 16) / 6, -3, platformZ - l / 2 - 10), { material = M.Wood })
	end
	for i = 0, count - 1 do
		local x = baseX + i * (w + 10)
		local origin = CFrame.new(x, 5, platformZ + l / 2)
		local plotPart = P(Vector3.new(w, 0.2, l), Color3.fromRGB(120, 200, 255), CFrame.new(x + w / 2, 5.05, platformZ), { transparency = 0.6, collide = false, name = "Plot", material = M.Neon, shadow = false })
		plotPart:SetAttribute("Island", island.id)
		plotPart:SetAttribute("Origin", origin)
		plotPart:SetAttribute("StandCf", CFrame.new(x + w / 2, 8, platformZ + l / 2 + 6))
		CollectionService:AddTag(plotPart, "Plot")
		for _, sx in ipairs({ 0, w }) do
			P(Vector3.new(0.4, 0.4, l), Color3.new(1, 1, 1), CFrame.new(x + sx, 5.3, platformZ), { material = M.Neon, collide = false, shadow = false })
		end
		-- crane
		P(Vector3.new(1.4, 26, 1.4), Color3.fromRGB(240, 190, 60), CFrame.new(x + w + 5, 18, platformZ - l / 2 + 4), { material = M.Metal, decor = true })
		P(Vector3.new(1, 1, 18), Color3.fromRGB(240, 190, 60), CFrame.new(x + w + 5, 30.5, platformZ - l / 2 + 12), { material = M.Metal, decor = true })
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
		turnGroup(group, island, a)
	end
	Kit.parent = prevParent
end

-- ===== Island base terrain =====
local function lobeAngles()
	-- beach lobes avoid the east (+X) side where docks and the shipyard sit
	return { 1.2, 1.9, 2.6, 3.3, 4.0, 4.7, 5.3 }
end

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
	Cyl(40, r * 2 + 40, pal.sand:Lerp(Color3.fromRGB(90, 140, 150), 0.5), c + Vector3.new(0, -24, 0), { material = M.Sand })
	-- shallow lagoon visible through the water
	Cyl(2, r * 2 + 130, Color3.fromRGB(110, 226, 214), c + Vector3.new(0, -6, 0), { material = M.Sand, shadow = false, collide = false })
	Cyl(14, r * 2, pal.sand, c + Vector3.new(0, -3, 0), { material = M.Sand })
	foam(c + Vector3.new(0, 0.1, 0), r * 2 + 6)
	for _, a in ipairs(lobeAngles()) do
		local lr = r * rng:NextNumber(0.28, 0.4)
		local d = r - lr * 0.45
		local lp = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		Cyl(14, lr * 2, pal.sand, lp + Vector3.new(0, -3, 0), { material = M.Sand })
		Cyl(2, lr * 2 + 70, Color3.fromRGB(110, 226, 214), lp + Vector3.new(0, -6, 0), { material = M.Sand, shadow = false, collide = false })
		foam(lp + Vector3.new(0, 0.12, 0), lr * 2 + 6)
	end
	-- layer-cake edge: brown dirt band under a grass cap
	Cyl(5.5, r * 2 - 32, pal.dirt, c + Vector3.new(0, 3.75, 0), { material = M.Ground })
	Cyl(1.6, r * 2 - 28, pal.grass, c + Vector3.new(0, 6.7, 0), { material = M.Grass })
	Cyl(6, r * 2 - 34, pal.grass, c + Vector3.new(0, 4.5, 0), { material = M.Grass })
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
		if math.sqrt(x * x + z * z) > r - 12 then
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
	local big = tier == "Captain" and 1.35 or 1
	local body = P(Vector3.new(3.4, 2, 2.3) * big, def.body, cf * CFrame.new(0, 1 * big, 0), { parent = m, material = M.WoodPlanks, name = "Body" })
	local lid = P(Vector3.new(3.5, 0.9, 2.4) * big, def.body:Lerp(Color3.new(1, 1, 1), 0.08), cf * CFrame.new(0, 2.45 * big, 0), { parent = m, material = M.WoodPlanks, name = "Lid" })
	for _, x in ipairs({ -1.1, 1.1 }) do
		P(Vector3.new(0.35, 2.95, 2.45) * big, def.trim, cf * CFrame.new(x * big, 1.5 * big, 0), { parent = m, material = M.Metal })
	end
	P(Vector3.new(0.6, 0.7, 0.2) * big, def.trim, cf * CFrame.new(0, 1.8 * big, -1.2 * big), { parent = m, material = M.Metal, name = "Lock" })
	-- glow ring + light so chests read from a distance
	Cyl(0.15, 6 * big, def.trim, pos + Vector3.new(0, 0.1, 0), { parent = m, material = M.Neon, transparency = 0.55, collide = false })
	local light = Instance.new("PointLight")
	light.Color = def.trim
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = lid
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
	-- a sea boss with no arena (v0.23.0, Bay Serpent): only a ring of red buoys and a warning sign over the water
	if island.boss and island.boss.atSea and island.boss.sea then
		local bp = Vector3.new(island.x + island.boss.offset.X, 0, island.boss.offset.Y)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local p = bp + Vector3.new(math.cos(a) * 95, 0, math.sin(a) * 95)
			Cyl(5, 3.2, Color3.fromRGB(230, 60, 50), p + Vector3.new(0, 0.6, 0), { collide = false })
			Ball(1.2, Color3.fromRGB(255, 230, 140), p + Vector3.new(0, 3.6, 0), { material = M.Neon, collide = false, decor = true })
		end
		local marker = P(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(bp + Vector3.new(0, 30, 0)), { transparency = 1, collide = false })
		local bbb = Instance.new("BillboardGui")
		bbb.Size = UDim2.fromOffset(320, 50)
		bbb.MaxDistance = 900
		bbb.Parent = marker
		local bt = t:Clone()
		bt.Size = UDim2.fromScale(1, 1)
		bt.Text = "☠ SERPENT WATERS"
		bt.TextColor3 = Color3.fromRGB(255, 110, 110)
		bt.Parent = bbb
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
}

local function buildIsland(island)
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
	-- v0.25.11: islands spread north/south. The generic builder (and its many absolute coordinates) works at z 0, so
	-- build there and move the finished island, including position attributes (dock LaunchCf / LandCf ...).
	local dz = island.z or 0
	island.yardAngle = yardAngle(island, dz)
	island.z = nil
	-- build unturned: swap the turned config offsets for the local ones while the island is laid out
	local lo = island.localOffsets
	local turned
	if lo then
		turned = { spawns = {}, boss = island.boss and island.boss.offset, arena = island.arena and island.arena.offset }
		for k, sp in ipairs(island.spawns) do
			turned.spawns[k] = sp.offset
			sp.offset = lo.spawns[k]
		end
		if island.boss then
			island.boss.offset = lo.boss
		end
		if island.arena then
			island.arena.offset = lo.arena
		end
	end
	local f
	local layout = island.layout and LAYOUTS[island.layout]
	if layout then
		-- hand-laid island (v0.25.20): burn the old generic build to keep the shared Kit.rng stream where every later
		-- island expects it, then build the new layout on its own stream (same trick as Daybreak)
		local scratch = Instance.new("Model")
		local prev = Kit.parent
		Kit.parent = scratch
		buildIslandGeneric(island)
		Kit.parent = prev
		scratch:Destroy()
		Kit.WithRng(Random.new(layout.seed), function()
			f = layout.module.Build(island, layoutApi)
		end)
	else
		f = buildIslandGeneric(island)
	end
	island.z = dz
	if lo then
		for k, sp in ipairs(island.spawns) do
			sp.offset = turned.spawns[k]
		end
		if island.boss then
			island.boss.offset = turned.boss
		end
		if island.arena then
			island.arena.offset = turned.arena
		end
	end
	local yaw = island.yaw or 0
	if dz ~= 0 or yaw ~= 0 then
		-- turn around the island center, then move to its z (positions in attributes too: docks, plots, props)
		local T = CFrame.new(island.x, 0, dz) * CFrame.Angles(0, yaw, 0) * CFrame.new(-island.x, 0, 0)
		local function moveAttrs(o)
			for k, v in pairs(o:GetAttributes()) do
				if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
					o:SetAttribute(k, T * v)
				end
			end
		end
		moveAttrs(f)
		-- targets first, then assign: welded (unanchored) assemblies would otherwise move twice
		local parts, targets = {}, {}
		for _, o in ipairs(f:GetDescendants()) do
			if o:IsA("BasePart") then
				table.insert(parts, o)
				table.insert(targets, T * o.CFrame)
			end
			moveAttrs(o)
		end
		for i, part in ipairs(parts) do
			part.CFrame = targets[i]
		end
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
	local lane = GameConfig.Lane
	local function clear(x, z)
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
			local x = rand:NextNumber(500, IslandsCfg.RedLine.x - 700)
			local z = rand:NextNumber(-(lane.HalfWidth - 200), lane.HalfWidth - 200)
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
	local W = GameConfig.World
	local lane = GameConfig.Lane
	local tile = 2048
	local calmStart = lane.HalfWidth + lane.EdgeWidth
	local x = W.MinX
	while x < W.MaxX + 600 do
		local cx = x + tile / 2
		-- Sailing lane: clear turquoise; Doldrums beyond: dark, glassy water. Tiled in z too (parts max 2048).
		local function strip(z0, z1, color, name, y, refl, transp)
			local z = z0
			while z < z1 - 1 do
				local d = math.min(tile, z1 - z)
				local p = P(Vector3.new(tile, 2, d), color, CFrame.new(cx, y, z + d / 2), { parent = f, material = Enum.Material.Glass, transparency = transp, collide = false, shadow = false, name = name })
				p.Reflectance = refl
				z += d
			end
		end
		strip(-calmStart, calmStart, Color3.fromRGB(40, 175, 230), "Water", -1, 0, 0.25)
		for _, sz in ipairs({ -1, 1 }) do
			local far = W.HalfZ + 400
			if sz < 0 then
				strip(-far, -calmStart, Color3.fromRGB(20, 110, 140), "CalmWater", -1.05, 0.25, 0.15)
			else
				strip(calmStart, far, Color3.fromRGB(20, 110, 140), "CalmWater", -1.05, 0.25, 0.15)
			end
			-- Foam line marking the Doldrums edge
			P(Vector3.new(tile, 0.3, 6), Color3.fromRGB(240, 250, 255), CFrame.new(cx, 0.1, sz * calmStart), { parent = f, material = Enum.Material.Neon, transparency = 0.35, collide = false, shadow = false, name = "CalmEdge" })
			P(Vector3.new(tile, 0.3, 3), Color3.fromRGB(255, 255, 255), CFrame.new(cx, 0.1, sz * lane.HalfWidth), { parent = f, material = Enum.Material.SmoothPlastic, transparency = 0.6, collide = false, shadow = false })
		end
		-- Sea floor
		strip(-(W.HalfZ + 400), W.HalfZ + 400, Color3.fromRGB(230, 210, 150), "SeaFloor", -46, 0, 0)
		x += tile
	end
	-- Warning buoys along the Doldrums edge
	local bx = W.MinX
	while bx < IslandsCfg.RedLine.x - 300 do
		for _, sz in ipairs({ -1, 1 }) do
			local pos = Vector3.new(bx, 0, sz * (lane.HalfWidth + lane.EdgeWidth * 0.5))
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
	local W = GameConfig.World
	local y = GameConfig.Swim.SeaFloorY
	local tile = 2000
	local x = W.MinX
	while x < W.MaxX + 600 do
		local z = -W.HalfZ
		while z < W.HalfZ do
			P(Vector3.new(tile, 4, tile), Color3.fromRGB(46, 92, 104), CFrame.new(x + tile / 2, y - 2, z + tile / 2), { parent = f, material = M.Sand, shadow = false, name = "Floor" })
			z += tile
		end
		x += tile
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

local function buildRedLine(world)
	local f = folderOf("RedLine", world)
	local rl = IslandsCfg.RedLine
	local W = GameConfig.World
	local red = Color3.fromRGB(215, 95, 70)
	local half = rl.canalWidth / 2
	local wallLen = W.HalfZ + 600 - half
	local x0 = rl.x - rl.thickness / 2
	for _, sz in ipairs({ -1, 1 }) do
		local zc = sz * (half + wallLen / 2)
		P(Vector3.new(rl.thickness, rl.height, wallLen), red, CFrame.new(rl.x, rl.height / 2 - 40, zc), { parent = f, material = Enum.Material.Rock })
		-- Stepped rock strata for depth
		for i = 1, 7 do
			P(Vector3.new(rl.thickness + 18, 22, wallLen), red:Lerp(Color3.fromRGB(255, 170, 120), (i % 2) * 0.45), CFrame.new(rl.x, i * 175, zc), { parent = f, material = Enum.Material.Rock })
		end
		-- Jagged sea-facing cliff pillars (-> stylized red cliff meshes, facing the sea)
		for i = 1, 26 do
			local z = sz * (half + 40 + rng:NextNumber(0, math.min(wallLen - 80, 2400)))
			local h = rng:NextNumber(120, 700)
			local center = Vector3.new(x0 - 10, h / 2 - 20, z)
			local pillar = P(Vector3.new(rng:NextNumber(60, 160), h, rng:NextNumber(30, 70)), red:Lerp(Color3.fromRGB(150, 60, 45), rng:NextNumber(0, 0.5)), CFrame.lookAt(center, center - Vector3.xAxis), { parent = f, material = Enum.Material.Rock })
			pillar:SetAttribute("Kind", "CliffRed")
			CollectionService:AddTag(pillar, "EnvPart")
		end
		-- red cliff face over the lower wall near the canal (where players actually look)
		local zz = half + 6
		while zz < half + 1500 do
			local w = rng:NextNumber(60, 95)
			local y = -30
			while y < 400 do
				local hh = rng:NextNumber(55, 85)
				local center = Vector3.new(x0 - 4 - rng:NextNumber(0, 8), y + hh / 2, sz * (zz + w / 2))
				local slab = P(Vector3.new(w * 1.15, hh * 1.08, 34), red:Lerp(Color3.fromRGB(150, 60, 45), rng:NextNumber(0, 0.4)), CFrame.lookAt(center, center - Vector3.xAxis), { parent = f, material = Enum.Material.Rock, collide = false })
				slab:SetAttribute("Kind", "CliffRed")
				CollectionService:AddTag(slab, "EnvPart")
				y += hh
			end
			zz += w
		end
		P(Vector3.new(rl.thickness + 30, 40, wallLen), Color3.fromRGB(110, 190, 90), CFrame.new(rl.x, rl.height - 30, zc), { parent = f, material = Enum.Material.Grass })
	end
	-- Backflow Peak: a canal of water flowing UP the wall
	local rise, run = rl.height - 20, rl.thickness
	local len = math.sqrt(rise * rise + run * run)
	local ang = math.atan2(rise, run)
	local mid = Vector3.new(x0 + run / 2, rise / 2 - 6, 0)
	local rampCf = CFrame.new(mid) * CFrame.Angles(0, 0, ang)
	P(Vector3.new(len, 20, rl.canalWidth + 40), Color3.fromRGB(170, 80, 60), rampCf * CFrame.new(0, -14, 0), { parent = f, material = Enum.Material.Rock })
	local water = P(Vector3.new(len, 3, rl.canalWidth), Color3.fromRGB(110, 215, 255), rampCf, { parent = f, material = Enum.Material.Glass, transparency = 0.15, collide = false, name = "ReverseWater" })
	CollectionService:AddTag(water, "ReverseWater")
	for i = 0, 9 do
		local foam = P(Vector3.new(14, 3.4, rl.canalWidth - 8), Color3.fromRGB(240, 252, 255), rampCf * CFrame.new(-len / 2 + (i + 0.5) * len / 10, 0.4, 0), { parent = f, material = Enum.Material.Neon, transparency = 0.45, collide = false, shadow = false, name = "Foam" })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 18) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Rate = 14
		pe.Speed = NumberRange.new(40, 70)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Acceleration = Vector3.new(0, 60, 0)
		pe.Parent = foam
	end
	-- Whirlpool at the foot of the climb
	Cyl(1, rl.canalWidth * 2.2, Color3.fromRGB(170, 235, 255), Vector3.new(x0 - 80, 0.3, 0), { parent = f, material = Enum.Material.Neon, transparency = 0.55, collide = false, shadow = false })
	-- Entrance arch (huge, visible from afar)
	local gx = x0 + rl.gateOffsetX
	for _, sz in ipairs({ -1, 1 }) do
		P(Vector3.new(22, 150, 22), Color3.fromRGB(250, 240, 220), CFrame.new(gx, 75, sz * (half + 24)), { parent = f, material = Enum.Material.Marble })
		Ball(30, Color3.fromRGB(255, 210, 80), Vector3.new(gx, 160, sz * (half + 24)), { parent = f, material = Enum.Material.SmoothPlastic })
	end
	P(Vector3.new(24, 26, rl.canalWidth + 80), Color3.fromRGB(250, 240, 220), CFrame.new(gx, 150, 0), { parent = f, material = Enum.Material.Marble })
	local s = sign(string.upper(IslandsCfg.RedLine.peakName) .. "  •  " .. string.upper(IslandsCfg.RedLine.nextSea) .. "  (Lv." .. GameConfig.GrandLineLevel .. ")", CFrame.new(gx - 12.5, 150, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector2.new(rl.canalWidth + 60, 20), Color3.fromRGB(255, 230, 120), Color3.fromRGB(150, 40, 40))
	s.Parent = f
	-- Clouds on the summit
	for _ = 1, 18 do
		Ball(rng:NextNumber(80, 160), Color3.new(1, 1, 1), Vector3.new(rl.x + rng:NextNumber(-300, 300), rl.height + rng:NextNumber(-60, 80), rng:NextNumber(-1600, 1600)), { parent = f, collide = false, transparency = 0.1, shadow = false })
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
WB.WORLD_VERSION = 22 -- v22 (v0.25.27): shipyards snap to the island side nearest the next island; v21 (v0.25.25): shipyards face the next island, circus ship offshore; v20 (v0.25.24): Marmalade Town hand-laid (World/Marmalade); v19 (v0.25.23): Conch Bay street spawns keep their houses; v18 (v0.25.22): Conch Bay terraced (quay, two terraces, garrison plateau, tapered towers); v17 (v0.25.21): islands turned to face the previous one, Conch Bay stairs; v16 (v0.25.20): Daybreak spawn by Rowan, Conch Bay hand-laid (World/ConchBay); v15 (v0.25.11): islands spread north/south, wider sea, islets; v14 (v0.25.6): Daybreak spawn by the campfire; v13: voxel NPCs; v12: Voxelize pass

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
	buildRedLine(world)
	-- v0.24.0 (owner): everything round or sloped becomes blocks (World/Voxelize)
	local okVox, voxErr = pcall(require(script.Parent.Voxelize).Run, world)
	if not okVox then
		warn("[WorldBuilder] voxelize failed:", voxErr)
	end
	setupLighting()
	WB.RemoveStaleMaps(world)
	return world
end

local function register()
	npcs, plots, docks, spawns = {}, {}, {}, {}
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
		local entry = { model = m, role = m:GetAttribute("Role"), island = m:GetAttribute("Island"), pos = m:GetPivot().Position }
		table.insert(npcs, entry)
		if prompt then
			prompt.Triggered:Connect(function(player)
				local Net = require(Shared.Modules.Net)
				-- quest NPCs (and quest steps that say "talk to X") get first say
				if R and R.QuestService then
					R.QuestService.OnTalk(player, entry.role, entry.island)
				end
				if entry.role ~= "Guide" then
					Net.Push(player, "OpenUI", { panel = entry.role, island = entry.island, dungeonId = m:GetAttribute("DungeonId") })
				end
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
