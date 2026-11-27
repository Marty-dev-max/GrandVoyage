-- ShipService: sailing (wind / Doldrums / Crimson Wall), cannons, 3-tier Marine+Pirate NPC ships, Leviathans
-- Physics: ships are unanchored assemblies driven by LinearVelocity + AlignOrientation (server-owned)
-- Players can walk the deck while the ship sails
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)
local NPCShips = require(Shared.Config.NPCShips)
local ShipParts = require(Shared.Config.ShipParts).Parts
local ShipStats = require(Shared.Modules.ShipStats)
local ShipModel = require(Shared.Modules.ShipModel)
local ShipHull = require(Shared.Modules.ShipHull)
local SeaZones = require(Shared.Modules.SeaZones)
local Net = require(Shared.Modules.Net)
local Recruits = require(Shared.Config.Recruits)
local MasteryCfg = require(Shared.Config.Mastery)
local Reach = require(Shared.Modules.Reach)
local CollectionService = game:GetService("CollectionService")

local Ship = {}
local R
local ships = {} -- id -> ship
local nextId = 0
local folder
local cfg = GameConfig.Ship
local G = cfg.GridSize
local lastToast = {}

function Ship.Init(registry)
	R = registry
	folder = Instance.new("Folder")
	folder.Name = "Ships"
	folder.Parent = workspace
end

local function flat(a, b)
	return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
end

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function toast(player, text, kind, key)
	key = player.UserId .. (key or text)
	if lastToast[key] and os.clock() - lastToast[key] < 4 then
		return
	end
	lastToast[key] = os.clock()
	R.PlayerService.Notify(player, text, kind)
end

-- ===== Ship construction =====
-- hull paint per faction (ShipModel.DressHull)
local HULL_STYLES = {
	None = { hull = Color3.fromRGB(140, 92, 56), trim = Color3.fromRGB(88, 58, 36), stripe = Color3.fromRGB(232, 192, 80) },
	Pirate = { hull = Color3.fromRGB(70, 50, 40), trim = Color3.fromRGB(38, 28, 24), stripe = Color3.fromRGB(196, 44, 44) },
	Marine = { hull = Color3.fromRGB(240, 240, 246), trim = Color3.fromRGB(60, 100, 190), stripe = Color3.fromRGB(232, 192, 80) },
}

local function buildShip(design, cf, opts)
	nextId += 1
	local minV, maxV = ShipModel.Bounds(design)
	local cx, cz = (minV.X + maxV.X) / 2, (minV.Z + maxV.Z) / 2
	local width, length = (maxV.X - minV.X) * G, (maxV.Z - minV.Z) * G
	local originCf = cf * CFrame.new(-cx * G, -minV.Y * G, cz * G)
	local phys
	if design.v == 2 then
		-- v0.25.152: a free-form hull sits as deep as its weight pushes it (ShipHull.Physics draft): keel at sea level - draft
		phys = ShipHull.Physics(design)
		originCf = originCf * CFrame.new(0, G * 0.5 - phys.draft, 0)
	end
	local model = ShipModel.BuildDesign(design, originCf, opts.colorFn)
	model.Name = opts.name
	-- a real hull around the block deck (dinghy / sloop / galleon by length): NPC ships only. v0.25.150 (owner):
	-- a player ship is exactly what they built (presets give a good-looking base), nothing is added on launch
	model:SetAttribute("SizeClass", ShipModel.SizeClass(maxV.Z - minV.Z))
	if opts.dress ~= false then
		local okHull, class = pcall(ShipModel.DressHull, model, design, originCf, opts.hullStyle)
		if okHull and class then
			model:SetAttribute("SizeClass", class)
		elseif not okHull then
			warn("[ShipService] hull dressing failed:", class)
		end
	end

	local root = Instance.new("Part")
	root.Name = "ShipRoot"
	root.Size = Vector3.new(math.max(width, 4), 2, math.max(length, 4))
	root.CFrame = cf * CFrame.new(0, 1, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.RootPriority = 10
	root.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0.5)
	root.Parent = model
	model.PrimaryPart = root

	local cannonParts, specialParts = {}, {}
	local partList = ShipStats.Parts(design)
	-- v0.25.153 (#24 #25): v2 cannons carry their scaled stats + firing arcs (ShipHull.Arcs); the arcs ride on the
	-- cannon model as attribute "Arcs" so the client's aim preview picks the same guns
	local arcs = design.v == 2 and ShipHull.Arcs(design) or nil
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") then
			local idx = child:GetAttribute("Index")
			local pdef = idx and partList[idx] and ShipParts[partList[idx].id]
			if pdef and pdef.cannon then
				local barrel = child:FindFirstChild("Barrel", true)
				local c = { model = child, muzzle = barrel and barrel:FindFirstChild("Muzzle"), damage = pdef.cannon.damage, range = pdef.cannon.range, reload = 1, speed = 1, readyAt = 0 }
				if arcs then
					local cs = ShipHull.CannonStats(partList[idx])
					c.damage, c.range, c.reload, c.speed, c.lob = cs.damage, cs.range, cs.reload, cs.speed, cs.lob
					c.fire = arcs[idx] and arcs[idx].fire or {}
					child:SetAttribute("Arcs", ShipHull.ArcString(c.fire))
					child:SetAttribute("Face", arcs[idx] and arcs[idx].face or 0)
					child:SetAttribute("Range", math.floor(c.range))
					c.port = not c.lob and ShipHull.PortSide(design, partList[idx]) or nil -- v0.25.155 (#34)
				end
				c.special = pdef.cannon.special
				table.insert(c.special and specialParts or cannonParts, c)
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "RootAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = math.huge
	ao.Responsiveness = 14
	ao.CFrame = cf.Rotation
	ao.Parent = root
	root.Anchored = false
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local _, yaw = cf:ToOrientation()
	local ship = {
		id = nextId,
		model = model,
		root = root,
		lv = lv,
		ao = ao,
		design = design,
		radius = math.max(width, length) / 2,
		width = width,
		length = length,
		yaw = yaw,
		throttle = 0,
		steer = 0,
		speed = 0,
		lastVolley = 0,
		buffs = {},
		damageBy = {},
		seaKings = {},
		cannons = cannonParts,
		specials = specialParts,
		seat = model:FindFirstChild("HelmSeat", true),
		list = phys and phys.list or 0, -- static lean from an off-centre load (v2 hulls)
		trim = phys and phys.trim or 0,
		heel = phys and phys.heel or 0, -- extra lean in turns under tall sails
		calmTime = 0,
		outCalmTime = 0,
		lostParts = 0,
	}
	ships[ship.id] = ship
	return ship
end

local function setAttrs(ship)
	local m = ship.model
	m:SetAttribute("HP", math.floor(ship.hp))
	m:SetAttribute("MaxHP", ship.maxHp)
	m:SetAttribute("Speed", math.floor(ship.speed))
	m:SetAttribute("MaxSpeed", math.floor(ship.maxSpeed or 0))
	m:SetAttribute("Zone", ship.zone or "Lane")
	m:SetAttribute("Wind", ship.wind or 1)
	m:SetAttribute("ReloadEnd", ship.reloadEnd or 0)
	m:SetAttribute("Cannons", #ship.cannons)
	m:SetAttribute("Manned", ship.stats and ship.stats.cannonsManned or 0)
	m:SetAttribute("Crew", ship.stats and ship.stats.crew or 0)
	-- v0.25.155 (Plan-Ships-v2 phase 3): water in the hull, gun-port lids, kegs, the special weapons' reload
	m:SetAttribute("Flood", math.floor(ship.flood or 0))
	m:SetAttribute("PortsOpen", os.clock() < (ship.portsUntil or 0))
	m:SetAttribute("PortShut", ship.portShut or 0)
	if ship.kegMax then
		m:SetAttribute("Kegs", ship.kegs or 0)
	end
	if ship.specials and #ship.specials > 0 then
		m:SetAttribute("SpecialEnd", ship.specialEnd or 0)
	end
	-- Mastery v2 M3: the shot loaded in the main guns and the active-reload zone ("" = no try left)
	if not ship.npc then
		m:SetAttribute("Shot", ship.shot or "Round")
		local a = ship.activeReload
		m:SetAttribute("ReloadStart", a and a.start or 0)
		m:SetAttribute("ReloadDur", a and a.dur or 0)
		m:SetAttribute("ReloadZone", (a and not a.used) and string.format("%.3f,%.3f,%.3f,%.3f", a.green[1], a.green[2], a.yellow[1], a.yellow[2]) or "")
	end
end

-- v0.25.155 (#34): which side's gun ports are shut because that side dips toward the water (1 starboard, -1 port)
local PORT_HEEL = 0.15
-- v0.25.155 (#32): every hit lets in water worth FLOOD_PER_DMG of its damage; each second FLOOD_LEAK of that water
-- turns into hull damage, each bilge pump cuts that damage (PUMP_CUT each, at most PUMP_MIN left) and drains faster
local FLOOD_PER_DMG, FLOOD_LEAK, PUMP_CUT, PUMP_MIN = 0.25, 0.12, 0.6, 0.2
local function portShutSide(ship)
	if ship.easy then
		return 0
	end
	local roll = ship.rollNow or 0
	return roll < -PORT_HEEL and 1 or (roll > PORT_HEEL and -1 or 0)
end

function Ship.GetShipOf(player)
	for _, s in pairs(ships) do
		if s.owner == player and not s.sinking then
			return s
		end
	end
	return nil
end

local function shipUnder(player)
	local root = R.PlayerService.Root(player)
	if not root then
		return nil
	end
	for _, s in pairs(ships) do
		if not s.sinking and s.root and flat(root.Position, s.root.Position) <= s.radius + 4 and root.Position.Y > -12 and root.Position.Y < 80 then
			return s
		end
	end
	return nil
end

function Ship.IsOnShip(player)
	return shipUnder(player) ~= nil
end

local function playersOn(ship)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local root = R.PlayerService.Root(pl)
		if root and flat(root.Position, ship.root.Position) <= ship.radius + 6 and root.Position.Y > -15 then
			table.insert(list, pl)
		end
	end
	return list
end

local function despawn(ship)
	ships[ship.id] = nil
	for _, sk in ipairs(ship.seaKings) do
		if not sk.dead then
			R.MonsterService.Kill(sk)
		end
	end
	if ship.model then
		ship.model:Destroy()
	end
end

function Ship.DespawnShipOf(player)
	local s = Ship.GetShipOf(player)
	if s then
		despawn(s)
	end
end

-- ===== Damage / sinking =====
local function hostile(a, b)
	if a == b or a.test or b.test then
		return false -- v0.25.155 (#21): a test sail fights nobody and nobody fights it
	end
	if a.owner and b.owner then
		return R.PvPService.ShipsHostile(a.owner, b.owner)
	end
	if a.owner and b.npc then
		return not (a.owner:GetAttribute("Faction") == "Marine" and b.npc.faction == "Marine")
	end
	if a.npc and b.owner then
		return not (b.owner:GetAttribute("Faction") == "Marine" and a.npc.faction == "Marine")
	end
	if a.npc and b.npc then
		return a.npc.faction ~= b.npc.faction
	end
	return false
end

local function breakRandomParts(ship, count)
	local candidates = {}
	for _, child in ipairs(ship.model:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "Helm" and child.Name ~= "Crew" then
			table.insert(candidates, child)
		end
	end
	for _ = 1, math.min(count, #candidates - 6) do
		local m = table.remove(candidates, math.random(1, #candidates))
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				for _, w in ipairs(p:GetChildren()) do
					if w:IsA("WeldConstraint") then
						w:Destroy()
					end
				end
				p.Massless = false
				p.CanCollide = false
				p.Color = p.Color:Lerp(Color3.new(0.1, 0.1, 0.1), 0.6)
				p.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), 30, math.random(-20, 20))
			end
		end
		game:GetService("Debris"):AddItem(m, 6)
		m.Parent = workspace
	end
end

local sink

-- ===== sea monsters (v0.23.0: the Bay Serpent fights ships) =====
local function shipRadius(ship)
	return ship.radius or (ship.root and math.max(ship.root.Size.X, ship.root.Size.Z) / 2) or 10
end

-- ships whose hull is crossed by a strike line (from -> to, width)
function Ship.InLine(from, to, width)
	local out = {}
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local len = d.Magnitude
	if len < 0.1 then
		return out
	end
	d = d.Unit
	for _, ship in pairs(ships) do
		if ship.root and not ship.sinking then
			local rel = ship.root.Position - from
			local along = rel.X * d.X + rel.Z * d.Z
			local side = math.abs(rel.X * d.Z - rel.Z * d.X)
			local r = shipRadius(ship)
			if along >= -r and along <= len + r and side <= width / 2 + r * 0.6 then
				table.insert(out, ship)
			end
		end
	end
	return out
end

-- v0.25.17 (owner): skills fired from a deck hit hostile ships along their path (cannons are no longer the only option)
-- v0.25.50 (owner: skills never hit NPC hulls): standing on an NPC ship (boarding) is not "your" ship, so it can be hit
local function attackerShip(player)
	local src = shipUnder(player)
	return (src and not src.npc) and src or nil
end
local function skillHitList(player, list, damage)
	local src = attackerShip(player)
	local hit = false
	local d = R.PlayerService.Derived(player)
	damage *= 1 + (d and d.shipHitMult or 0) -- remake R3 talent Hull Breaker
	for _, s in ipairs(list) do
		if s ~= src and (not src or hostile(src, s)) and (src or s.npc) then
			Ship.DamageShip(s, damage, src, player)
			hit = true
		end
	end
	return hit
end

function Ship.SkillHitCircle(player, center, radius, damage)
	return skillHitList(player, Ship.InCircle(center, radius), damage)
end

function Ship.SkillHit(player, from, to, width, damage)
	return skillHitList(player, Ship.InLine(from, to, width), damage)
end

-- v0.25.42: the NPC ship a clicked part belongs to (basic attacks and targeted skills can smash hulls)
function Ship.NpcShipOf(inst)
	for _, s in pairs(ships) do
		if s.npc and not s.sinking and s.model and inst:IsDescendantOf(s.model) then
			return s
		end
	end
	return nil
end

function Ship.InCircle(center, radius)
	local out = {}
	for _, ship in pairs(ships) do
		if ship.root and not ship.sinking then
			local p = ship.root.Position
			if (Vector2.new(p.X, p.Z) - Vector2.new(center.X, center.Z)).Magnitude <= radius + shipRadius(ship) * 0.7 then
				table.insert(out, ship)
			end
		end
	end
	return out
end

-- a heavy blow: hull planks and deck pieces near `pos` break off and tumble into the sea, wood splinters fly
function Ship.Smash(ship, pos, count)
	if not ship.model or ship.sinking then
		return
	end
	local near = {}
	for _, p in ipairs(ship.model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= ship.root and p.Transparency < 0.9 then
			-- only the hull planks (ShipModel.DressHull) and bow wedges break off: never the deck you stand on,
			-- the helm, masts or cannons
			local m = p:FindFirstAncestorOfClass("Model")
			local n = m and m.Name or ""
			local hullPiece = n == "Hull" or string.find(n, "Wedge", 1, true)
			if hullPiece then
				local dd = (p.Position - pos).Magnitude
				if dd < 14 then
					table.insert(near, { p = p, d = dd })
				end
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(count or 3, #near) do
		local p = near[i].p
		for _, w in ipairs(p:GetChildren()) do
			if w:IsA("WeldConstraint") then
				w:Destroy()
			end
		end
		p.Massless = false
		p.CanCollide = false
		p.Color = p.Color:Lerp(Color3.new(0.12, 0.1, 0.08), 0.35)
		p.Parent = workspace
		p.AssemblyLinearVelocity = (p.Position - pos).Unit * math.random(18, 34) + Vector3.new(0, math.random(22, 38), 0)
		p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		game:GetService("Debris"):AddItem(p, 5)
	end
	Net.FX("ShipDebris", { pos = pos }, pos, 500)
end

-- noFlood = this damage is the water / fire already in the hull (it adds no more water)
function Ship.DamageShip(ship, dmg, srcShip, player, noFlood)
	if ship.sinking or ship.test then
		return
	end
	ship.hp -= dmg
	if not noFlood then
		ship.flood = (ship.flood or 0) + dmg * FLOOD_PER_DMG -- v0.25.155 (#32): holed planks let water in
	end
	local key = player or (srcShip and srcShip.owner)
	if key then
		ship.damageBy[key] = (ship.damageBy[key] or 0) + dmg
	end
	if srcShip and ship.npc and srcShip.owner and not ship.target then
		ship.target = srcShip
	end
	local proot = player and ship.crew and R.PlayerService.Root(player)
	if proot and flat(proot.Position, ship.root.Position) <= ship.radius + 10 then
		ship.provoker = player -- someone on (or right by) the deck is smashing the hull: the crew drop everything
	end
	Net.FX("ShipHit", { pos = ship.root.Position, amount = math.floor(dmg) }, ship.root.Position, 500)
	local lostSteps = math.floor((1 - ship.hp / ship.maxHp) * 4)
	if lostSteps > ship.lostParts then
		ship.lostParts = lostSteps
		breakRandomParts(ship, 2 + ship.lostParts)
	end
	setAttrs(ship)
	if ship.hp <= 0 then
		sink(ship)
	end
end

sink = function(ship)
	if ship.sinking then
		return
	end
	ship.sinking = true
	local top, topD = nil, 0
	for pl, d in pairs(ship.damageBy) do
		if pl.Parent and d > topD then
			top, topD = pl, d
		end
	end
	Net.FX("ShipSink", { pos = ship.root.Position, radius = ship.radius }, ship.root.Position, 800)
	if ship.npc then
		local def = ship.npc
		if top then
			R.PartyService.ShareExp(top, def.exp, def.exp * 0.6, ship.root.Position)
			R.MonsterService.RollDrops(top, { drops = def.drops, beli = def.beli }, 1)
			R.PvPService.OnShipSunk(top, def)
			R.QuestService.Event(top, "Sink", nil)
			local FruitsCfg = require(Shared.Config.Fruits)
			R.FruitService.RollDrop(top, FruitsCfg.Drops.Ship[def.tier] or 0, def.name)
			if def.tier >= 3 then
				Net.PushAll("Announce", { text = "💥 " .. top.DisplayName .. " sank a " .. def.name .. "!", kind = "ship" })
			end
		end
	elseif ship.owner then
		local owner = ship.owner
		local p = R.DataService.Get(owner)
		if p then
			p.shipSunk = true
			R.PlayerService.MarkDirty(owner)
		end
		if top and top ~= owner then
			R.PvPService.OnPlayerKilled(owner, top)
		end
		-- v0.25.53 (owner): no warp back to the island; you stay in the water and can call the ship again on the spot
		for _, pl in ipairs(playersOn(ship)) do
			R.PlayerService.Notify(pl, pl == owner and "Your ship sank! Call it again: MENU > Ships" or "The ship sank!", "bad")
		end
	end
	ship.lv.VectorVelocity = Vector3.new(0, -4, 0)
	ship.ao.CFrame = CFrame.Angles(0, ship.yaw, 0) * CFrame.Angles(0.5, 0, 0.3)
	ship.ao.Responsiveness = 2
	task.delay(7, function()
		despawn(ship)
	end)
end

-- ===== Cannons =====
-- is a point over a ship's deck footprint (its rotated rectangle), give or take `extra` studs?
local function overShip(sh, pos, extra)
	local l = sh.root.CFrame:PointToObjectSpace(Vector3.new(pos.X, sh.root.Position.Y, pos.Z))
	return math.abs(l.X) <= sh.width / 2 + extra and math.abs(l.Z) <= sh.length / 2 + extra
end

-- v0.25.155 (#29): what a special weapon does to a ship it hits
local HARPOON_SLOW, HARPOON_SECONDS, FIRE_SECONDS = 0.45, 6, 8
local TEST_RADIUS = 380 -- v0.25.155 (#21): how far a test sail may go from its launch spot
local function specialHit(gun, s, damage, srcShip, player)
	if gun.special == "harpoon" then
		s.slowUntil = os.clock() + HARPOON_SECONDS -- the line holds: that ship drags at HARPOON_SLOW of its speed
		if srcShip.root and s.root then
			Net.FX("HarpoonLine", { a = srcShip.root, b = s.root, t = HARPOON_SECONDS }, s.root.Position, 600)
		end
	elseif gun.special == "firepot" then
		s.burn = { untilT = os.clock() + FIRE_SECONDS, dps = damage * 0.5, src = srcShip, player = player }
		Net.FX("Burning", { model = s.model, seconds = FIRE_SECONDS }, s.root.Position, 600)
	end
end

-- `shot` (Mastery v2 M3) = a MasteryCfg.Gunner.Shots entry for a player's main guns (Chain / Bomb), else nil
local function impact(pos, damage, srcShip, player, lock, gun, shot)
	local hitSomething = false
	local splashK = shot and shot.splash or 1
	for _, s in pairs(ships) do
		if s ~= srcShip and not s.sinking and hostile(srcShip, s) then
			-- v0.24.0: hits are measured to the ship's whole hull (not a circle around its middle), and the ship the
			-- shot was aimed at counts a wider margin (it was moving while the ball flew)
			local extra = cfg.SplashRadius * splashK * (s == lock and 0.9 or 0.5)
			if overShip(s, pos, extra) then
				Ship.DamageShip(s, damage, srcShip, player)
				if player and not s.test and not (srcShip and srcShip.test) then
					R.MasteryService.Add(player, "Gunner", MasteryCfg.Gain.CannonHit + damage * MasteryCfg.Gain.CannonPerDmg) -- remake R3
				end
				if gun and gun.special and not s.sinking then
					specialHit(gun, s, damage, srcShip, player)
				end
				if shot and shot.slow and not s.sinking then
					s.chainUntil = os.clock() + shot.seconds -- torn sails (Chain Shot)
					s.chainSlow = shot.slow
				end
				hitSomething = true
			end
		end
	end
	if player then
		for _, mob in ipairs(R.MonsterService.InRadius(pos, cfg.SplashRadius * splashK + 4)) do
			R.MonsterService.Damage(mob, damage * 1.5 * (shot and shot.crew or 1), player, false, gun and gun.special == "firepot" and "fire" or "cannon")
			hitSomething = true
		end
	end
	Net.FX(hitSomething and "Explosion" or "Splash", { pos = Vector3.new(pos.X, math.max(pos.Y, 0), pos.Z), radius = cfg.SplashRadius * splashK }, pos, 600)
end

-- the hostile ship a shot is aimed at (the click landed on or near it), if any
local function aimedShip(srcShip, target)
	local best, bestD
	for _, s in pairs(ships) do
		if s ~= srcShip and not s.sinking and hostile(srcShip, s) and overShip(s, target, 18) then
			local d = flat(target, s.root.Position)
			if not best or d < bestD then
				best, bestD = s, d
			end
		end
	end
	return best
end

local function fireBall(from, target, damage, range, srcShip, player, gun, shot)
	local shotSpeed = cfg.CannonballSpeed * (gun and gun.speed or 1)
	-- lead a moving target ship: aim where it will be when the ball lands (v0.24.0: shots used to land behind
	-- sailing NPC ships, so they never got hit)
	local lock = player and aimedShip(srcShip, target) or nil
	if lock then
		local off = target - lock.root.Position
		for _ = 1, 2 do
			local tt = flat(from, target) / shotSpeed + 0.25
			local v = lock.root.AssemblyLinearVelocity
			target = lock.root.Position + Vector3.new(v.X, 0, v.Z) * tt + Vector3.new(off.X, 0, off.Z) * 0.5
		end
		target = Vector3.new(target.X, 0, target.Z)
	end
	local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local dist = dir.Magnitude
	if dist < 1 then
		return
	end
	if dist > range then
		target = from + dir.Unit * range
		target = Vector3.new(target.X, 0, target.Z)
		dist = range
	end
	local t = dist / shotSpeed + 0.25
	Net.FX("Cannonball", { from = from, to = target, t = t, lob = gun and gun.lob or nil, kind = (gun and gun.special) or (shot and shot.fx) or nil }, from, 700)
	task.delay(t, impact, target, damage, srcShip, player, lock, gun, shot)
end

-- the target's bearing from a point in the ship's own frame (0 = bow, 90 = starboard), as ShipHull.Arcs counts it
local function bearingOf(ship, pos, target)
	local fwd = Vector3.new(-math.sin(ship.yaw), 0, -math.cos(ship.yaw))
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	return math.deg(math.atan2(to:Dot(right), to:Dot(fwd)))
end

-- returns fired, bearing (how many guns could bear on the target, ready or not), shut (guns behind a shut port),
-- firedGuns (the cannon tables that fired)
-- `guns` = which list (ship.cannons by default; the special weapons use ship.specials)
-- `o` (Mastery v2 M3): { shot = Gunner.Shots entry, ignoreReload = true (Full Broadside) }
local function volley(ship, target, count, damageMult, player, spread, fixedDamage, guns, o)
	o = o or {}
	local chosen = {}
	local firedGuns = {}
	local bearing, shut = 0, 0
	local now = os.clock()
	local shutSide = player and portShutSide(ship) or 0
	for _, c in ipairs(guns or ship.cannons) do
		local main = c.model.PrimaryPart
		if main and main.Parent then
			local pos = c.muzzle and c.muzzle.WorldPosition or main.Position
			local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			if to.Magnitude > 1 then
				local ok, score
				if c.fire then
					-- v0.25.153 (#25): v2 guns fire only inside their (unblocked) arcs, each on its own reload
					local b = bearingOf(ship, pos, target)
					ok = ShipHull.InArc(c.fire, b)
					local face = c.model:GetAttribute("Face")
					score = ok and 1 - math.abs(ShipHull.Wrap180(b - (face or b))) / 180 or 0
				else
					local face = main.CFrame.LookVector
					score = Vector3.new(face.X, 0, face.Z).Unit:Dot(to.Unit)
					ok = score > 0.25
				end
				if ok and c.port and c.port == shutSide then
					ok = false -- v0.25.155 (#34): that side heels toward the water, its ports are shut
					shut += 1
				end
				if ok then
					bearing += 1
					if not player or o.ignoreReload or (c.readyAt or 0) <= now then
						table.insert(chosen, { c = c, pos = pos, dot = score })
					end
				end
			end
		end
	end
	table.sort(chosen, function(a, b)
		return a.dot > b.dot
	end)
	local fired = 0
	local n = math.min(count, #chosen)
	-- v0.25.53 (owner): a player's broadside flies in parallel lanes (each cannon keeps its offset from the group's
	-- middle), matching the aim preview drawn by the client (Sailing); NPC ships still converge on their target
	local center = Vector3.zero
	for i = 1, n do
		center += chosen[i].pos / n
	end
	for i = 1, n do
		local item = chosen[i]
		local err = spread and Vector3.new((math.random() - 0.5) * spread, 0, (math.random() - 0.5) * spread) or Vector3.zero
		local lane = player and Vector3.new(item.pos.X - center.X, 0, item.pos.Z - center.Z) or Vector3.zero
		task.delay((i - 1) * 0.09, fireBall, item.pos, target + lane + err, fixedDamage or item.c.damage * damageMult, item.c.range, ship, player, item.c, o.shot)
		if player then
			item.c.readyAt = now + cfg.ReloadTime * (ship.reloadMult or 1) * (item.c.reload or 1)
		end
		fired += 1
		table.insert(firedGuns, item.c)
	end
	return fired, bearing, shut, firedGuns
end

-- ===== Player ships =====
local addRecruits -- v0.25.142, defined with addCrew below
local dropKeg -- v0.25.155, defined with the kegs below
-- `at` (CFrame, optional): where the ship appears (SummonShip in open water); else the nearest dock's launch spot
-- `testDesign` (v0.25.155, #21): a TEST SAIL of the builder's unsaved design: nothing is paid, it cannot be hurt,
-- fights nobody and stays near the yard (ShipyardService TestSail)
function Ship.Launch(player, slot, at, testDesign)
	local p = R.DataService.Get(player)
	local design = testDesign or p.ships[slot]
	if not design then
		return false, "No ship design in that slot"
	end
	local derived = R.PlayerService.Derived(player) or {}
	local rb = Recruits.Bonus(p.recruits) -- v0.25.142: Rowers add speed, Gunners cut the reload
	local stats = ShipStats.Compute(design, p.crew, { shipSpeed = (derived.shipSpeed or 0) + rb.speed, shipHp = derived.shipHp })
	if not stats.valid then
		return false, stats.problem or "A ship needs 1 helm and at least 1 sail or oar bench"
	end
	local dock = R.WorldBuilder.NearestDock(R.PlayerService.Root(player).Position)
	if not at and (not dock or dock.distance > 160) then
		return false, "Go to a dock or shipyard"
	end
	if p.shipSunk and not testDesign then
		local cost = math.floor(stats.value * cfg.SinkRepairPct) + 200
		if not R.PlayerService.AddBeli(player, -cost) then
			return false, "Your ship is sunk. Repair costs 🪙" .. cost
		end
		p.shipSunk = false
		R.PlayerService.Notify(player, "Ship repaired (🪙" .. cost .. ")", "info")
	end
	local ship = buildShip(design, at or dock.launchCf, { name = "Ship_" .. player.UserId, dress = false, colorFn = ShipModel.FactionColorFn(p and p.faction) })
	ship.owner = player
	ship.stats = stats
	ship.reloadMult = math.max(0.4, 1 - rb.reload - (derived.reloadCut or 0)) -- remake R3: Gunner perks / talents
	ship.easy = type(p.settings) == "table" and type(p.settings.client) == "table" and p.settings.client.shipEasy == true -- #23
	ship.pumps = stats.pumps or 0
	if (stats.kegs or 0) > 0 then
		ship.kegMax, ship.kegs = stats.kegs, stats.kegs
	end
	if testDesign then
		ship.test = true
		ship.testFrom = ship.root.Position
		ship.model:SetAttribute("Test", true)
	end
	ship.model:SetAttribute("Spyglass", stats.spyglass == true)
	ship.model:SetAttribute("Specials", #ship.specials)
	pcall(addRecruits, ship, p.recruits)
	ship.maxHp = stats.hp
	ship.hp = stats.hp
	ship.model:SetAttribute("OwnerId", player.UserId)
	ship.model:SetAttribute("ShipName", design.name)
	ship.model:SetAttribute("Faction", p.faction)
	local nameplate = Instance.new("BillboardGui")
	nameplate.Size = UDim2.fromOffset(240, 40)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	nameplate.MaxDistance = 600
	nameplate.Parent = ship.root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextStrokeTransparency = 0.4
	t.TextColor3 = p.faction == "Marine" and Color3.fromRGB(140, 200, 255) or (p.faction == "Pirate" and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1))
	t.Text = (testDesign and "TEST • " or "") .. design.name .. " • " .. player.DisplayName
	t.Parent = nameplate
	setAttrs(ship)
	task.delay(0.4, function()
		local hum = R.PlayerService.Humanoid(player)
		if ship.seat and hum then
			R.PlayerService.TeleportTo(player, ship.seat.CFrame)
			task.wait(0.15)
			ship.seat:Sit(hum)
		end
	end)
	return true
end

function Ship.Dock(player)
	local ship = Ship.GetShipOf(player)
	if not ship then
		return false, "You have no ship out"
	end
	local dock = R.WorldBuilder.NearestDock(ship.root.Position)
	if not dock or dock.distance > cfg.DockRange + ship.radius then
		return false, "Sail closer to a dock"
	end
	local riders = playersOn(ship)
	despawn(ship)
	local island = Islands.ById[dock.islandId]
	for _, pl in ipairs(riders) do
		if island then
			R.PlayerService.UnlockIsland(pl, dock.islandId)
		end
		R.PlayerService.TeleportTo(pl, dock.landCf)
	end
	return true, "Docked at " .. (island and island.name or "a sea fort")
end

function Ship.AddShipBuff(player, id, value, duration)
	local s = shipUnder(player)
	if not s then
		return false
	end
	s.buffs[id] = { value = value, expires = os.clock() + duration }
	Net.FX("Skill", { fx = "Wind", from = s.root.Position, to = s.root.Position, radius = s.radius }, s.root.Position, 400)
	return true
end

-- plug = true (or 1) pumps every drop of water out too, a number 0..1 that share of it (remake M4: timed repairs,
-- Emergency Repair)
function Ship.RepairNearby(player, pct, plug)
	local s = shipUnder(player)
	if not s or s.sinking or (s.owner and s.owner ~= player and not R.PartyService.Same(s.owner, player)) then
		return false
	end
	local before = s.hp
	local d = R.PlayerService.Derived(player)
	s.hp = math.min(s.maxHp, s.hp + s.maxHp * pct * (1 + (d and d.repairMult or 0))) -- remake R3: Shipwright perks
	local cut = plug == true and 1 or math.clamp(tonumber(plug) or 0, 0, 1)
	if cut > 0 and (s.flood or 0) > 0 then
		s.flood = cut >= 1 and 0 or s.flood * (1 - cut)
		if cut >= 1 then
			Net.FX("Miss", { pos = s.root.Position + Vector3.new(0, 6, 0), text = "LEAKS PLUGGED!" }, s.root.Position, 300)
		end
	end
	setAttrs(s)
	if not s.test and s.hp > before then
		R.MasteryService.Add(player, "Shipwright", (s.hp - before) * MasteryCfg.Gain.RepairPerHp)
	end
	Net.FX("Repair", { pos = s.root.Position, radius = s.radius, amount = math.floor(s.hp - before) }, s.root.Position, 400)
	return true
end

-- v0.25.142: a Carpenter recruit's slow patching (no FX burst)
function Ship.Patch(s, amount)
	if s and not s.sinking and s.hp then
		s.hp = math.min(s.maxHp, s.hp + amount)
		setAttrs(s)
	end
end

-- ===== v0.25.155 (Plan-Ships-v2 phase 3) =====
-- your own ship, with you at its helm
local function helmShip(player)
	local ship = Ship.GetShipOf(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if ship and hum and hum.SeatPart and hum.SeatPart == ship.seat then
		return ship
	end
	return nil
end

-- powder kegs (#30): float where they were dropped, arm after KEG_ARM s, blow up under a hostile hull
local KEG_DAMAGE, KEG_RADIUS, KEG_LIFE, KEG_ARM, KEG_MAX_OUT, KEG_REFILL = 180, 16, 90, 2, 6, 20
local kegs = {}
local kegFolder
function dropKeg(ship, pos) -- (forward-declared above Ship.Start's handlers)
	local mine = {}
	for i, k in ipairs(kegs) do
		if k.src == ship then
			table.insert(mine, i)
		end
	end
	if #mine >= KEG_MAX_OUT then
		local k = table.remove(kegs, mine[1])
		k.part:Destroy()
	end
	if not kegFolder then
		kegFolder = Instance.new("Folder")
		kegFolder.Name = "PowderKegs"
		kegFolder.Parent = workspace
	end
	local function piece(name, size, color, material, cf, parent)
		local pt = Instance.new("Part")
		pt.Name = name
		pt.Size, pt.Color, pt.Material, pt.CFrame = size, color, material, cf
		pt.Anchored, pt.CanCollide, pt.CanQuery, pt.CanTouch = true, false, false, false
		pt.Parent = parent
		return pt
	end
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.random() * 6.28, 0)
	local body = piece("PowderKeg", Vector3.new(2.6, 2.8, 2.6), Color3.fromRGB(120, 80, 48), Enum.Material.Wood, cf, nil)
	for _, y in ipairs({ -0.8, 0.8 }) do
		piece("Band", Vector3.new(2.75, 0.3, 2.75), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, cf * CFrame.new(0, y, 0), body)
	end
	piece("Fuse", Vector3.new(0.4, 0.6, 0.4), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, cf * CFrame.new(0, 1.7, 0), body)
	body.Parent = kegFolder
	local now = os.clock()
	table.insert(kegs, { part = body, src = ship, player = ship.owner, armAt = now + KEG_ARM, dieAt = now + KEG_LIFE })
	Net.FX("Splash", { pos = pos }, pos, 400)
end

local function kegStep(now)
	for i = #kegs, 1, -1 do
		local k = kegs[i]
		if not k.part.Parent or now > k.dieAt then
			k.part:Destroy()
			table.remove(kegs, i)
		elseif now > k.armAt then
			local pos = k.part.Position
			local boom = false
			for _, s in pairs(ships) do
				if not s.sinking and s.root and hostile(k.src, s) and overShip(s, pos, 3) then
					boom = true
					break
				end
			end
			if boom then
				for _, s in pairs(ships) do
					if not s.sinking and s.root and hostile(k.src, s) and overShip(s, pos, KEG_RADIUS * 0.6) then
						Ship.DamageShip(s, KEG_DAMAGE, k.src, k.player)
						Ship.Smash(s, pos, 3)
					end
				end
				if k.player and k.player.Parent then
					for _, mob in ipairs(R.MonsterService.InRadius(pos, KEG_RADIUS)) do
						R.MonsterService.Damage(mob, KEG_DAMAGE * 1.5, k.player, false, "cannon")
					end
				end
				Net.FX("Explosion", { pos = pos, radius = KEG_RADIUS }, pos, 700)
				k.part:Destroy()
				table.remove(kegs, i)
			end
		end
	end
end

-- once a second: water in the hull hurts it (bilge pumps cut that, #32), fire pots burn (#29), the keg rack refills
local function slowTick(ship, now)
	local f = ship.flood or 0
	if f < 0.5 then
		ship.flood = 0
	else
		local pumps = ship.pumps or 0
		local leak = f * FLOOD_LEAK
		ship.flood = math.max(0, f - leak * (1 + pumps * 0.5))
		local dmg = leak * math.max(PUMP_MIN, PUMP_CUT ^ pumps)
		if dmg >= 1 then
			Ship.DamageShip(ship, math.floor(dmg), nil, nil, true)
		end
	end
	local b = ship.burn
	if b then
		if now < b.untilT and not ship.sinking then
			Ship.DamageShip(ship, math.floor(b.dps), b.src, b.player, true)
		else
			ship.burn = nil
		end
	end
	if ship.kegMax and ship.kegs < ship.kegMax and now - (ship.kegRefill or now) >= KEG_REFILL then
		ship.kegs += 1
		ship.kegRefill = ship.kegs < ship.kegMax and now or nil
	end
	if ship.owner then
		local p = R.DataService.Get(ship.owner)
		ship.easy = p and type(p.settings) == "table" and type(p.settings.client) == "table" and p.settings.client.shipEasy == true
	end
end

-- #21: end a test sail (ShipyardService puts you back in the builder)
function Ship.EndTest(player)
	local ship = Ship.GetShipOf(player)
	if ship and ship.test then
		despawn(ship)
		return true
	end
	return false
end

function Ship.RepairOwned(player, pct, plug)
	local s = Ship.GetShipOf(player)
	if not s or shipUnder(player) ~= s then
		return false
	end
	return Ship.RepairNearby(player, pct, plug)
end

-- standing on (or seated in) that ship
function Ship.IsAboard(player, ship)
	return ship ~= nil and shipUnder(player) == ship
end

-- ===== NPC ships =====
local function npcDesign(def)
	local parts = {}
	local W, L = def.width, def.length
	local hull = def.tier >= 3 and "OakBlock" or "PlankBlock"
	for x = 0, W - 1 do
		for z = 0, L - 1 do
			table.insert(parts, { id = hull, x = x, y = 0, z = z, r = 0 })
		end
	end
	for x = 1, W - 2 do
		table.insert(parts, { id = "PlankWedge", x = x, y = 0, z = L, r = 0 })
	end
	table.insert(parts, { id = "Helm", x = math.floor(W / 2), y = 1, z = 1, r = 0 })
	if def.tier >= 2 then
		table.insert(parts, { id = "CrewCabin", x = math.floor(W / 2) - 1, y = 1, z = 2, r = 0 })
	end
	local mastId = def.faction == "Pirate" and "JollySail" or "MarineSail"
	if def.tier == 1 then
		mastId = "SmallMast"
	end
	for i = 1, def.masts do
		local z = math.floor(L * (i / (def.masts + 1))) + 1
		table.insert(parts, { id = mastId, x = math.floor(W / 2), y = 1, z = z, r = 0 })
	end
	local perSide = math.floor(def.cannons / 2)
	for i = 1, perSide do
		local z = math.floor((L - 2) * i / (perSide + 1)) + 1
		table.insert(parts, { id = def.tier >= 3 and "HeavyCannon" or "LightCannon", x = 0, y = 1, z = z, r = 1 })
		table.insert(parts, { id = def.tier >= 3 and "HeavyCannon" or "LightCannon", x = W - 1, y = 1, z = z, r = 3 })
	end
	return { name = def.name, parts = parts }
end

local function npcColor(def)
	return function(p)
		local pd = ShipParts[p.id]
		if pd.category ~= "Hull" then
			return nil
		end
		if def.faction == "Marine" then
			return p.y == 0 and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(70, 120, 220)
		end
		return Color3.fromRGB(110, 75, 50)
	end
end

-- NPC crew (v0.24.0, owner): voxel sailors on every NPC ship, a helmsman at the wheel and a gunner behind the cannons
-- (every other cannon on big ships), dressed by faction. Blocks welded to the ship root, no collisions.
local VoxelChar = require(Shared.Modules.VoxelChar)
local Looks = require(Shared.Config.Looks)
local CREW_RNG = Random.new(4242)
local function crewLook(faction)
	local look = Looks.Random(CREW_RNG)
	if faction == "Marine" then
		look.shirt = CREW_RNG:NextNumber() < 0.5 and 4 or 11 -- sailor stripes / polo
		look.shirt1, look.shirt2 = "F4F4F4", "2846A0"
		look.pants, look.pants1, look.pants2 = 1, "F4F4F4", "2846A0"
		look.shoes, look.shoes1 = 2, "1C1A22"
	else
		local tops = { 5, 8, 10, 15, 2 }
		look.shirt = tops[CREW_RNG:NextInteger(1, #tops)]
		look.pants = CREW_RNG:NextNumber() < 0.5 and 5 or 3
		look.pants1 = ({ "3A2A22", "2A2A32", "5A3A2A" })[CREW_RNG:NextInteger(1, 3)]
		look.pants2 = "C42A2E"
	end
	return look
end
-- v0.25.17 (owner): NPC crew can be fought. Each figure is a static monster riding the ship (MonsterService),
-- level = the area's island level (SeaZones segment) + 5 per ship tier; stats copied from the closest normal
-- monster of that level so balance follows the rest of the game.
local Monsters = require(Shared.Config.Monsters)
local Waves = require(Shared.Modules.Waves)
local function crewDef(shipDef, pos)
	local isl = Islands.List[SeaZones.Segment(pos.X)] or Islands.List[1]
	local level = isl.levels[2] + ((shipDef.tier or 1) - 1) * 5
	local best
	for _, m in pairs(Monsters) do
		if type(m) == "table" and m.level and not m.isBoss and not m.static and m.hp and m.atk and m.atk > 0 then
			if not best or math.abs(m.level - level) < math.abs(best.level - level) then
				best = m
			end
		end
	end
	local k = level / math.max(1, best.level)
	local d = table.clone(best)
	d.id = "ShipCrew"
	d.name = (shipDef.faction == "Marine" and "Marine Sailor" or "Pirate Deckhand") .. " Lv." .. level
	d.level = level
	d.hp = math.floor(best.hp * k)
	d.atk = math.floor(best.atk * k)
	d.exp = math.floor((best.exp or 0) * k)
	d.jobExp = math.floor((best.jobExp or 0) * k)
	d.static = true
	d.aggro = false
	d.drops = {}
	d.card = false
	d.cardChance = 0
	d.style = { shape = "humanoid", color = shipDef.faction == "Marine" and Color3.fromRGB(240, 240, 250) or Color3.fromRGB(150, 60, 50), scale = 1 }
	return d
end

local function addCrew(ship, def)
	local root = ship.root
	local spots = {}
	local cannons = 0
	for _, child in ipairs(ship.model:GetChildren()) do
		local main = child:IsA("Model") and child.PrimaryPart
		if main then
			if child.Name == "Helm" then
				-- behind the wheel, facing the bow
				local at = main.Position - root.CFrame.LookVector * 3
				table.insert(spots, { pos = at, face = root.CFrame.LookVector, y = main.Position.Y - G / 2, role = "helm" })
			elseif (ShipParts[child.Name] and ShipParts[child.Name].cannon) then
				cannons += 1
				if def.cannons <= 6 or cannons % 2 == 1 then
					local look = main.CFrame.LookVector
					local at = main.Position - Vector3.new(look.X, 0, look.Z).Unit * 3.2
					table.insert(spots, { pos = at, face = look, y = main.Position.Y - G / 2, role = "gunner" })
				end
			end
		end
	end
	local crewFolder = Instance.new("Model")
	crewFolder.Name = "Crew"
	local figs = {}
	for _, spot in ipairs(spots) do
		local fig = VoxelChar.Preview(crewLook(def.faction), nil, nil, nil, { lite = true })
		local face = Vector3.new(spot.face.X, 0, spot.face.Z)
		face = face.Magnitude > 0.01 and face.Unit or Vector3.zAxis
		local base = Vector3.new(spot.pos.X, spot.y, spot.pos.Z)
		fig:PivotTo(CFrame.lookAt(base, base + face))
		-- v0.25.42: blocks hang off the figure's main part, which rides the ship on a Weld whose C0 (deck space) the
		-- server moves when the crew walk over to fight a boarder (crewStep)
		local main = fig.PrimaryPart
		for _, d in ipairs(fig:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = true -- clicks and aim rays find the crew (v0.25.17)
				d.CanTouch = false
				d.Massless = true
				if d ~= main then
					local w = Instance.new("WeldConstraint")
					w.Part0 = main
					w.Part1 = d
					w.Parent = d
				end
			end
		end
		local weld = Instance.new("Weld")
		weld.Name = "DeckWeld"
		weld.Part0 = root
		weld.Part1 = main
		weld.C0 = root.CFrame:ToObjectSpace(main.CFrame)
		weld.Parent = main
		CollectionService:AddTag(fig, "ShipCrew") -- client target lists (Combat) look here: crew are not in workspace.Monsters
		fig.Parent = crewFolder
		table.insert(figs, { fig = fig, weld = weld, home = weld.C0, role = spot.role })
	end
	crewFolder.Parent = ship.model
	if ship.npc then
		local cdef = crewDef(def, root.Position)
		ship.crew = {}
		for _, c in ipairs(figs) do
			local fig = c.fig
			local mob = R.MonsterService.Spawn("ShipCrew", fig.PrimaryPart.Position, { def = cdef, model = fig, noRespawn = true })
			if mob then
				c.mob = mob
				c.at = c.home
				table.insert(ship.crew, c)
				fig.AncestryChanged:Connect(function()
					if not fig:IsDescendantOf(game) and not mob.dead then
						R.MonsterService.Forget(mob)
					end
				end)
			end
		end
	end
end

-- v0.25.142 (owner): your recruits stand at their posts on your ship: Gunners behind cannons, Rowers at the oar
-- benches, the rest on deck (Cooks aft near the helm, Carpenters amidships). Name tag over each; not targets.
function addRecruits(ship, list) -- (forward-declared above Ship.Launch)
	if not list or #list == 0 then
		return
	end
	local root = ship.root
	local posts = { Gunner = {}, Rower = {}, deck = {} }
	local deckY = root.Position.Y
	for _, child in ipairs(ship.model:GetChildren()) do
		local main = child:IsA("Model") and child.PrimaryPart
		if main then
			if child.Name == "Helm" then
				deckY = main.Position.Y - G / 2
				for _, sx in ipairs({ -1, 1 }) do
					table.insert(posts.deck, { pos = main.Position + root.CFrame.RightVector * sx * 3.5 + root.CFrame.LookVector * 2, face = root.CFrame.LookVector, y = deckY })
				end
			elseif (ShipParts[child.Name] and ShipParts[child.Name].cannon) then
				local look = main.CFrame.LookVector
				table.insert(posts.Gunner, { pos = main.Position - Vector3.new(look.X, 0, look.Z).Unit * 3.2, face = look, y = main.Position.Y - G / 2 })
			elseif child.Name == "OarBench" then
				table.insert(posts.Rower, { pos = main.Position, face = root.CFrame.LookVector, y = main.Position.Y - G / 2 })
			end
		end
	end
	-- extra deck spots along the middle line, bow to stern
	for k = -2, 2 do
		table.insert(posts.deck, { pos = root.Position + root.CFrame.LookVector * k * 4 + root.CFrame.RightVector * ((k % 2 == 0) and 1.5 or -1.5), face = -root.CFrame.RightVector, y = deckY })
	end
	local folder = Instance.new("Model")
	folder.Name = "Recruits"
	for i, r in ipairs(list) do
		if i > 10 then
			break
		end
		local spot = table.remove(posts[r.prof] or posts.deck, 1) or table.remove(posts.deck, 1)
		if not spot then
			break
		end
		local fig = VoxelChar.Preview(Recruits.Look(r), r.race, r.variant, nil, { lite = true })
		local face = Vector3.new(spot.face.X, 0, spot.face.Z)
		face = face.Magnitude > 0.01 and face.Unit or Vector3.zAxis
		local base = Vector3.new(spot.pos.X, spot.y, spot.pos.Z)
		fig:PivotTo(CFrame.lookAt(base, base + face))
		local main = fig.PrimaryPart
		for _, d in ipairs(fig:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				if d ~= main then
					local w = Instance.new("WeldConstraint")
					w.Part0 = main
					w.Part1 = d
					w.Parent = d
				end
			end
		end
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = main
		weld.C0 = root.CFrame:ToObjectSpace(main.CFrame)
		weld.Parent = main
		local prof = Recruits.Professions[r.prof]
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(160, 22)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		tag.MaxDistance = 50
		tag.Parent = main
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextStrokeTransparency = 0.3
		t.TextColor3 = Color3.fromRGB(255, 230, 170)
		t.Text = r.name .. " - " .. (prof and prof.name or "")
		t.Parent = tag
		fig.Parent = folder
	end
	folder.Parent = ship.model
end

local function spawnNPC(defId, pos, segment)
	local def = NPCShips.Ships[defId]
	local design = npcDesign(def)
	local yaw = math.random() * math.pi * 2
	local ship = buildShip(design, CFrame.new(pos.X, GameConfig.SeaLevel - G * 0.5, pos.Z) * CFrame.Angles(0, yaw, 0), { name = "NPC_" .. defId, colorFn = npcColor(def), hullStyle = HULL_STYLES[def.faction] })
	ship.npc = def
	ship.segment = segment
	ship.maxHp = def.hp
	ship.hp = def.hp
	ship.stats = { cannonsManned = def.cannons, crew = def.cannons }
	ship.model:SetAttribute("NPC", true)
	local okCrew, crewErr = pcall(addCrew, ship, def)
	if not okCrew then
		warn("[ShipService] NPC crew failed:", crewErr)
	end
	ship.model:SetAttribute("Faction", def.faction)
	ship.model:SetAttribute("Tier", def.tier)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 34, 0)
	bb.MaxDistance = 700
	bb.Parent = ship.root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextStrokeTransparency = 0.3
	t.TextColor3 = def.faction == "Marine" and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(255, 110, 110)
	t.Text = string.rep("★", def.tier) .. " " .. def.name .. " Lv." .. def.level
	t.Parent = bb
	setAttrs(ship)
	return ship
end

local function pickTier(weights)
	local r = math.random()
	local acc = 0
	for i, w in ipairs(weights) do
		acc += w
		if r <= acc then
			return i
		end
	end
	return 1
end

local function segmentBounds(seg)
	local a = Islands.List[seg]
	local b = Islands.List[seg + 1]
	local x1 = a.x + a.radius + 160
	local x2 = b and (b.x - b.radius - 160) or (Islands.RedLine.x - 500)
	-- v0.25.8 (owner): keep NPC ships clear of a sea boss's waters (Bay Serpent off Daybreak got crowded)
	if a.boss and a.boss.sea and a.boss.offset then
		x1 = math.max(x1, a.x + a.boss.offset.X + 380)
	end
	return x1, math.max(x1 + 80, x2)
end

local function npcSpawner()
	while true do
		task.wait(NPCShips.SpawnInterval)
		local counts = {}
		for _, s in pairs(ships) do
			if s.npc and s.segment then
				counts[s.segment] = (counts[s.segment] or 0) + 1
			end
		end
		for seg = 1, #Islands.List do
			local x1, x2 = segmentBounds(seg)
			local cx = (x1 + x2) / 2
			local near = false
			for _, pl in ipairs(Players:GetPlayers()) do
				local root = R.PlayerService.Root(pl)
				if root and math.abs(root.Position.X - cx) < 2600 then
					near = true
				end
			end
			if near and (counts[seg] or 0) < NPCShips.MaxPerSegment then
				local tier = pickTier(NPCShips.SegmentTierWeights[seg] or { 1 })
				local faction = math.random() < 0.5 and "Marine" or "Pirate"
				local pos = Vector3.new(x1 + math.random() * (x2 - x1), 0, (math.random() * 2 - 1) * (GameConfig.Lane.HalfWidth - 120))
				spawnNPC(faction .. tier, pos, seg)
			end
		end
	end
end

local function npcThink(ship, now)
	local def = ship.npc
	local pos = ship.root.Position
	-- v0.25.42 (owner): no helmsman = no sailing; boarded = gunners and helmsman leave their posts to fight
	local helmUp, gunners = true, 0
	for _, c in ipairs(ship.crew or {}) do
		if c.role == "helm" then
			helmUp = not c.mob.dead
		elseif not c.mob.dead then
			gunners += 1
		end
	end
	local manned = not ship.crew or (gunners > 0 and not ship.boarded)
	-- Acquire target
	if ship.target and (ship.target.sinking or not ships[ship.target.id] or flat(ship.target.root.Position, pos) > 520) then
		ship.target = nil
	end
	if not ship.target then
		local best, bestD = nil, 340
		for _, s in pairs(ships) do
			if s ~= ship and not s.sinking and (s.owner or s.npc) and hostile(ship, s) then
				local d = flat(s.root.Position, pos)
				if d < bestD then
					best, bestD = s, d
				end
			end
		end
		ship.target = best
	end
	local desired
	local throttle = 0.55
	if ship.target then
		local tp = ship.target.root.Position
		local to = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
		local d = to.Magnitude
		if d > 210 then
			desired = to.Unit
			throttle = 1
		elseif d < 100 then
			desired = -to.Unit
			throttle = 1
		else
			-- Turn broadside to fire
			local perp = Vector3.new(-to.Z, 0, to.X).Unit
			local fwd = Vector3.new(-math.sin(ship.yaw), 0, -math.cos(ship.yaw))
			desired = fwd:Dot(perp) >= 0 and perp or -perp
			throttle = 0.7
		end
		if manned and d < 270 and now - ship.lastVolley >= def.reload then
			ship.lastVolley = now
			local tv = ship.target.root.AssemblyLinearVelocity
			local flight = d / cfg.CannonballSpeed + 0.25
			local aim = tp + Vector3.new(tv.X, 0, tv.Z) * flight * 0.85
			volley(ship, aim, math.max(1, math.ceil(def.cannons / 2)), 1, nil, 34 - def.tier * 6, def.damage)
		end
	else
		if not ship.waypoint or flat(ship.waypoint, pos) < 60 then
			local x1, x2 = segmentBounds(ship.segment or SeaZones.Segment(pos.X))
			ship.waypoint = Vector3.new(x1 + math.random() * (x2 - x1), 0, (math.random() * 2 - 1) * (GameConfig.Lane.HalfWidth - 140))
		end
		desired = Vector3.new(ship.waypoint.X - pos.X, 0, ship.waypoint.Z - pos.Z).Unit
	end
	-- Avoid the Doldrums edge and islands
	if math.abs(pos.Z) > GameConfig.Lane.HalfWidth - 70 then
		desired = (desired + Vector3.new(0, 0, -math.sign(pos.Z) * 2)).Unit
	end
	local island, idist = SeaZones.NearestIsland(pos)
	if island and idist < island.radius + 90 then
		local away = Vector3.new(pos.X - island.x, 0, pos.Z - (island.z or 0)).Unit
		desired = (desired + away * 2).Unit
	end
	local desiredYaw = math.atan2(-desired.X, -desired.Z)
	ship.steer = math.clamp(-wrapAngle(desiredYaw - ship.yaw) * 2, -1, 1)
	ship.throttle = throttle
	if not helmUp or ship.boarded then
		ship.steer, ship.throttle = 0, 0
	end
end

-- ===== NPC crew on deck (v0.25.42, owner) =====
-- Crew are static monsters (MonsterService does not move them): here they walk the deck toward whoever they fight
-- (mob.target, set by MS.Provoke when hit), swing when in reach, and walk back to their posts when nobody is left.
local CREW_SPEED = 9
local function crewStep(ship, dt, now)
	local root = ship.root
	local fight
	for _, c in ipairs(ship.crew) do
		local mob = c.mob
		local pl = mob.target
		local proot = pl and R.PlayerService.Root(pl)
		local hum = pl and R.PlayerService.Humanoid(pl)
		if pl and (not proot or not hum or hum.Health <= 0 or flat(proot.Position, root.Position) > ship.radius + 40) then
			mob.target, pl, proot = nil, nil, nil
		end
		if pl and not mob.dead then
			fight = fight or pl
		end
	end
	local caller = ship.provoker or fight
	ship.provoker = nil
	ship.boarded = caller ~= nil
	for _, c in ipairs(ship.crew) do
		local mob = c.mob
		if not mob.dead and c.weld.Parent then
			if caller and not mob.target then
				R.MonsterService.Provoke(mob, caller) -- one is hit, they all come
			end
			local pl = mob.target
			local proot = pl and R.PlayerService.Root(pl)
			local here = c.at.Position
			local goal, faceTo = c.home.Position, nil
			if proot then
				local l = root.CFrame:PointToObjectSpace(proot.Position)
				local hx, hz = math.max(1, ship.width / 2 - 1.5), math.max(1, ship.length / 2 - 1.5)
				goal = Vector3.new(math.clamp(l.X, -hx, hx), here.Y, math.clamp(l.Z, -hz, hz))
				faceTo = Vector3.new(l.X, here.Y, l.Z)
			end
			local to = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
			local stopAt = proot and mob.def.attackRange * 0.7 or 0.05
			local nextPos = here
			if to.Magnitude > stopAt then
				nextPos = here + to.Unit * math.min(to.Magnitude - stopAt * 0.5, CREW_SPEED * dt)
				faceTo = faceTo or (here + to)
			end
			local cf
			if faceTo and (faceTo - nextPos).Magnitude > 0.3 then
				cf = CFrame.lookAt(nextPos, Vector3.new(faceTo.X, nextPos.Y, faceTo.Z))
			elseif not proot and to.Magnitude <= 0.05 then
				cf = c.home -- back at the post: original facing
			else
				cf = c.at.Rotation + nextPos
			end
			c.at = cf
			c.weld.C0 = cf
			if proot and Reach.Gap(proot.Position, mob.model) <= mob.def.attackRange + 1 and now - mob.lastAttack >= mob.def.attackSpeed then
				mob.lastAttack = now
				Net.FX("MobAttack", { model = mob.model, to = proot.Position, ranged = false, from = mob.root.Position }, mob.root.Position, 200)
				task.delay(0.3, function()
					if not mob.dead and mob.target == pl then
						R.CombatService.MonsterHit(mob, pl, 1)
					end
				end)
			end
		end
	end
end

-- ===== Leviathans in the Doldrums =====
local function updateSeaKings(ship, dt)
	for i = #ship.seaKings, 1, -1 do
		local sk = ship.seaKings[i]
		if sk.dead or not sk.model.Parent then
			table.remove(ship.seaKings, i)
		else
			sk.angle = (sk.angle or 0) + dt * 0.5
			local r = ship.radius + 26
			local base = ship.root.Position
			local bob = math.sin(os.clock() * 2 + sk.uid) * 3
			local p = Vector3.new(base.X + math.cos(sk.angle) * r, 6 + bob, base.Z + math.sin(sk.angle) * r)
			sk.model:PivotTo(CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z)))
			sk.biteTimer = (sk.biteTimer or 2) - dt
			if sk.biteTimer <= 0 then
				sk.biteTimer = 3
				Net.FX("MobAttack", { model = sk.model, to = base, from = p, ranged = false }, base, 400)
				Ship.DamageShip(ship, GameConfig.CalmBelt.SeaKingDamagePerHit * (1 + ship.calmTime / 30), nil, nil)
			end
		end
	end
end

local function calmBeltTick(ship)
	if ship.zone == "CalmBelt" then
		ship.calmTime += 1
		ship.outCalmTime = 0
		if ship.owner then
			toast(ship.owner, "⚠️ You entered the Doldrums! No wind, and Leviathans are coming!", "bad", "calm")
		end
		if ship.calmTime % GameConfig.CalmBelt.SeaKingSpawnInterval == 0 and #ship.seaKings < GameConfig.CalmBelt.MaxSeaKingsPerShip then
			local a = math.random() * math.pi * 2
			local p = ship.root.Position + Vector3.new(math.cos(a) * 60, -10, math.sin(a) * 60)
			local sk = R.MonsterService.Spawn("Leviathan", p, { static = true, noRespawn = true })
			if sk then
				for _, d in ipairs(sk.model:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				sk.angle = a
				table.insert(ship.seaKings, sk)
				Net.FX("SeaKingRise", { pos = p }, p, 600)
			end
		end
	else
		ship.calmTime = 0
		if #ship.seaKings > 0 then
			ship.outCalmTime += 1
			if ship.outCalmTime > 8 then
				for _, sk in ipairs(ship.seaKings) do
					if not sk.dead then
						R.MonsterService.Kill(sk)
					end
				end
				ship.seaKings = {}
			end
		end
	end
end

-- ===== physics step =====
local function stepShip(ship, dt, now)
	local pos = ship.root.Position
	local zone, wind = SeaZones.Get(pos)
	wind = ship.testWind or wind -- v0.25.155 (#21): the test sail's wind slider
	ship.zone, ship.wind = zone, wind
	local buff = 0
	for id, b in pairs(ship.buffs) do
		if b.expires > now then
			buff += b.value
		else
			ship.buffs[id] = nil
		end
	end
	local maxSpeed
	if ship.npc then
		maxSpeed = ship.npc.speed * math.max(wind, 0.2)
	else
		maxSpeed = ShipStats.Speed(ship.stats, wind, buff)
		-- The captain must be seated at the helm
		local hum = R.PlayerService.Humanoid(ship.owner)
		if not ship.seat or not hum or ship.seat.Occupant ~= hum then
			ship.throttle = 0
			ship.steer = 0
		end
	end
	if (ship.slowUntil or 0) > now then
		maxSpeed *= HARPOON_SLOW -- v0.25.155 (#29): a harpoon line drags on the hull
	end
	if (ship.chainUntil or 0) > now then
		maxSpeed *= ship.chainSlow or 1 -- Mastery v2 M3: Chain Shot tore the sails
	end
	ship.maxSpeed = maxSpeed
	local targetSpeed = ship.throttle >= 0 and ship.throttle * maxSpeed or ship.throttle * math.min(maxSpeed, 10)
	local accel = targetSpeed > ship.speed and 9 or 14
	if ship.speed < targetSpeed then
		ship.speed = math.min(targetSpeed, ship.speed + accel * dt)
	else
		ship.speed = math.max(targetSpeed, ship.speed - accel * dt)
	end
	local turnRate = ship.npc and 0.45 or ship.stats.turnRate
	ship.yaw -= ship.steer * turnRate * dt * math.clamp(0.35 + math.abs(ship.speed) / 40, 0.35, 1)
	local fwd = Vector3.new(-math.sin(ship.yaw), 0, -math.cos(ship.yaw))
	local vel = fwd * ship.speed
	-- World bounds
	local W = GameConfig.World
	if (pos.X < W.MinX and vel.X < 0) or (pos.X > W.MaxX and vel.X > 0) then
		vel = Vector3.new(0, 0, vel.Z)
	end
	if math.abs(pos.Z) > W.HalfZ and math.sign(vel.Z) == math.sign(pos.Z) then
		vel = Vector3.new(vel.X, 0, 0)
	end
	-- v0.25.155 (#21): a test sail stays within TEST_RADIUS of where it was launched
	if ship.test and ship.testFrom then
		local off = Vector3.new(pos.X - ship.testFrom.X, 0, pos.Z - ship.testFrom.Z)
		if off.Magnitude > TEST_RADIUS and vel:Dot(off) > 0 then
			vel -= off.Unit * vel:Dot(off.Unit)
			ship.speed = math.min(ship.speed, 6)
			toast(ship.owner, "Test area edge: turn back (or press BACK TO SHIPYARD)", "info", "testedge")
		end
	end
	-- Red Line / Reverse Mountain
	local rl = Islands.RedLine
	if pos.X > rl.x - rl.thickness / 2 - 90 and vel.X > 0 then
		vel = Vector3.new(-6, 0, vel.Z)
		ship.speed = math.min(ship.speed, 5)
		if ship.owner then
			local lvl = ship.owner:GetAttribute("Level") or 1
			if lvl < GameConfig.GrandLineLevel then
				toast(ship.owner, "Backflow Peak: reach Lv." .. GameConfig.GrandLineLevel .. " to climb to the Grand Current", "bad", "redline")
			elseif not GameConfig.GrandLineOpen then
				toast(ship.owner, "🌊 The Grand Current opens in the next update! Ready your ship.", "info", "redline")
			end
		end
	end
	-- v0.25.144: ride the shared voxel waves (Shared/Modules/Waves, same surface the clients draw): heave with the
	-- height under the hull, pitch / roll with the slope between bow-stern and port-starboard samples
	local wt = Waves.Now()
	local damp = Waves.Damp(pos.X, pos.Z)
	local fwd = Vector3.new(-math.sin(ship.yaw), 0, -math.cos(ship.yaw))
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local function hAt(v)
		return Waves.Height(pos.X + v.X, pos.Z + v.Z, wt, damp)
	end
	local hBow, hStern, hR, hL = hAt(fwd * 8), hAt(fwd * -8), hAt(right * 4), hAt(right * -4)
	local targetY = GameConfig.SeaLevel - G * 0.5 + 1 + (hBow + hStern + hR + hL) / 4
	local vy = math.clamp((targetY - pos.Y) * 4, -25, 25)
	ship.lv.VectorVelocity = vel + Vector3.new(0, vy, 0)
	-- v0.25.153 (#22): under sail the wind leans the ship over (heel from ShipHull.Physics, cut by keels), more with
	-- more sail out and a stronger wind
	-- v0.25.155 (#23): EASY ship physics (player setting) keeps the hull level: no wind heel, list or trim
	local heel = ship.easy and 0 or (ship.heel or 0)
	local windHeel = -heel * ((ship.sailLevel or 0) / 3) * math.clamp(wind, 0, 1.5)
	ship.heelNow = windHeel
	local lean = ship.steer * -(0.05 + heel * 0.5) * math.clamp(ship.speed / 40, 0, 1) + (ship.easy and 0 or (ship.list or 0)) + windHeel
	ship.rollNow = lean -- the steady lean (no wave rocking): gun ports shut on its low side (#34)
	local roll = math.clamp(math.atan2(hR - hL, 8) * 0.7, -0.12, 0.12) + lean
	local pitch = math.clamp(math.atan2(hBow - hStern, 16) * 0.7, -0.1, 0.1) + (ship.easy and 0 or (ship.trim or 0))
	ship.ao.CFrame = CFrame.Angles(0, ship.yaw, 0) * CFrame.Angles(pitch, 0, roll)
end

function Ship.Start()
	Net.Handle("LaunchShip", function(player, data)
		if Ship.GetShipOf(player) then
			return false, "You already have a ship at sea"
		end
		R.ShipyardService.ExitBuild(player)
		local p = R.DataService.Get(player)
		return Ship.Launch(player, math.clamp(math.floor(tonumber(data.slot) or p.activeShip or 1), 1, 3))
	end, 2)

	-- v0.25.23 (owner): the menu's Ships button calls your active ship out or puts it away; editing is the
	-- Shipwright's job. Out: at the nearest dock (within 400), or right where you swim in open water.
	Net.Handle("SummonShip", function(player)
		local ship = Ship.GetShipOf(player)
		local root = R.PlayerService.Root(player)
		if not root then
			return false
		end
		if ship then
			local dock = R.WorldBuilder.NearestDock(ship.root.Position)
			if dock and dock.distance <= cfg.DockRange + ship.radius then
				return Ship.Dock(player)
			end
			for _, pl in ipairs(playersOn(ship)) do
				if pl == player then
					return false, "Sail to a dock (or jump off) to put your ship away"
				end
			end
			if #playersOn(ship) > 0 then
				return false, "Your crew is still aboard"
			end
			despawn(ship)
			return true, "Ship stored"
		end
		R.ShipyardService.ExitBuild(player)
		local p = R.DataService.Get(player)
		local slot = p.activeShip or 1
		local dock = R.WorldBuilder.NearestDock(root.Position)
		if dock and dock.distance <= 400 then
			return Ship.Launch(player, slot)
		end
		if root.Position.Y > GameConfig.SeaLevel + 4 then
			return false, "Go to a dock, or swim out to sea, to call your ship"
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		local yaw = look.Magnitude > 0.01 and math.atan2(-look.X, -look.Z) or 0
		return Ship.Launch(player, slot, CFrame.new(root.Position.X, GameConfig.SeaLevel - G * 0.5, root.Position.Z) * CFrame.Angles(0, yaw, 0))
	end, 2)

	Net.Handle("SetActiveShip", function(player, data)
		local p = R.DataService.Get(player)
		local slot = math.floor(tonumber(type(data) == "table" and data.slot) or 0)
		if slot < 1 or slot > 3 or not p.ships[slot] then
			return false, "No ship in that slot"
		end
		p.activeShip = slot
		R.PlayerService.MarkDirty(player)
		return true
	end, 0.5)

	Net.Handle("DockShip", function(player)
		return Ship.Dock(player)
	end, 1)

	-- ===== main guns (F / click water; C = Full Broadside) =====
	local Gunner = MasteryCfg.Gunner
	-- the earliest gun still reloading -> ship.reloadEnd (server time) for the HUD bar
	local function reloadEndOf(ship, now)
		local nextReady = math.huge
		for _, c in ipairs(ship.cannons) do
			if (c.readyAt or 0) > now then
				nextReady = math.min(nextReady, c.readyAt)
			end
		end
		return nextReady < math.huge and nextReady - now or 0
	end

	-- the shot this volley really uses: Chain / Bomb need the Gunner level and one Gunpowder (taken after it fires).
	-- Changes nothing itself: returns def (nil = round shot), a note and `fallback` = the loaded special shot can't
	-- be used, so fireMain switches the ship back to Round only once a volley really fired (else the HUD would still
	-- say Chain while the next volley quietly fired Round).
	local function shotFor(player, ship)
		local id = ship.shot or "Round"
		local def = Gunner.Shots[id]
		local p = R.PlayerService.Profile(player)
		if not def or id == "Round" then
			return nil
		end
		if MasteryCfg.Level(p, "Gunner") < def.lv then
			return nil, "Round Shot loaded (Chain / Bomb need Gunner Mastery Lv." .. def.lv .. ")", true
		end
		if R.InventoryService.Count(player, "Gunpowder") < (def.powder or 0) then
			return nil, "Out of Gunpowder: Round Shot loaded", true
		end
		return def
	end

	local function fireMain(player, data, broadside)
		local ship = Ship.GetShipOf(player)
		if not ship or shipUnder(player) ~= ship then
			return false, "You must be aboard your own ship"
		end
		-- v0.25.53 (owner): only the captain at the helm fires; on deck you fight with your own weapons
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.SeatPart and hum.SeatPart.Name == "HelmSeat") then
			return false, "Take the helm to fire the cannons"
		end
		local target = type(data) == "table" and typeof(data.target) == "Vector3" and data.target
		if not target or target.X ~= target.X or target.Z ~= target.Z then
			return false
		end
		local now = os.clock()
		if ship.stats.cannonsManned <= 0 then
			return false, "No crew to man the cannons (recruit at a tavern)"
		end
		local serverNow = workspace:GetServerTimeNow()
		if broadside then
			local p = R.PlayerService.Profile(player)
			if MasteryCfg.Level(p, "Gunner") < Gunner.Broadside.lv then
				return false, "Full Broadside needs Gunner Mastery Lv." .. Gunner.Broadside.lv
			end
			local left = (player:GetAttribute("BroadsideReady") or 0) - serverNow
			if left > 0 then
				return false, string.format("Full Broadside ready in %ds", math.ceil(left))
			end
		end
		local d = R.PlayerService.Derived(player) or {}
		local shot, note, fallback = shotFor(player, ship)
		local mult = (1 + (d.cannonDamage or 0)) * (shot and shot.dmg or 1) * (broadside and Gunner.Broadside.mult or 1)
		-- v0.25.153: every gun reloads on its own (swivels fast, mortars slow); a shot fires the ready guns that bear.
		-- Full Broadside: every gun that bears fires, reloading or not
		local count = broadside and #ship.cannons or ship.stats.cannonsManned
		local fired, bearing, shut, firedGuns = volley(ship, target, count, mult, player, 6, nil, nil, { shot = shot, ignoreReload = broadside })
		ship.portsUntil = now + 8 -- v0.25.155 (#34): the lids swing open for the broadside
		if fired == 0 then
			if bearing == 0 and shut > 0 then
				return false, "Gun ports shut: the ship heels too far (fewer sails)"
			end
			return false, bearing > 0 and "Reloading" or "Target is outside your firing arcs (turn broadside)"
		end
		if shot and shot.powder then
			R.InventoryService.RemoveItem(player, "Gunpowder", shot.powder)
		end
		if fallback then
			ship.shot = "Round" -- back to round shot until Z picks the special one again
		end
		if broadside then
			player:SetAttribute("BroadsideReady", serverNow + Gunner.Broadside.cooldown)
			Net.FX("Explosion", { pos = ship.root.Position + Vector3.new(0, 4, 0), radius = 4 }, ship.root.Position, 600)
		end
		ship.lastVolley = now
		local dur = reloadEndOf(ship, now)
		ship.reloadEnd = serverNow + dur
		-- ACTIVE RELOAD (Mastery v2 M3): a green zone somewhere along this reload, wider with Gunner Mastery
		if dur > 0.6 then
			local RC = Gunner.Reload
			local gw = MasteryCfg.GreenWidth(MasteryCfg.Level(R.PlayerService.Profile(player), "Gunner"))
			local c = RC.CenterMin + math.random() * (RC.CenterMax - RC.CenterMin)
			local g = { math.max(0, c - gw / 2), math.min(1, c + gw / 2) }
			ship.activeReload = { start = serverNow, dur = dur, green = g, yellow = { math.max(0, g[1] - RC.Yellow), math.min(1, g[2] + RC.Yellow) }, guns = firedGuns }
		else
			ship.activeReload = nil
		end
		setAttrs(ship)
		local msg = broadside and ("FULL BROADSIDE!" .. (note and ("  " .. note) or "")) or note
		return { ok = true, msg = msg }
	end

	Net.Handle("FireCannons", function(player, data)
		return fireMain(player, data, false)
	end, 0.3)

	Net.Handle("Broadside", function(player, data)
		return fireMain(player, data, true)
	end, 1)

	-- F / FIRE while the reload bar runs: one try per reload; `t` = the client's server-clock time of the press
	Net.Handle("ActiveReload", function(player, data)
		local ship = helmShip(player)
		local a = ship and ship.activeReload
		if not a or a.used then
			return false
		end
		a.used = true
		local serverNow = workspace:GetServerTimeNow()
		local t = type(data) == "table" and tonumber(data.t)
		if not t or t ~= t or t > serverNow + 0.05 or t < serverNow - MasteryCfg.Timing.Lag then
			t = serverNow -- unbelievable stamp: judge by when it arrived
		end
		local x = (t - a.start) / a.dur
		local q = 1
		if x >= a.green[1] and x <= a.green[2] then
			q = 3
		elseif x >= a.yellow[1] and x <= a.yellow[2] then
			q = 2
		end
		local now = os.clock()
		if q > 1 then
			for _, c in ipairs(a.guns) do
				if (c.readyAt or 0) > now then
					c.readyAt = q == 3 and now or now + (c.readyAt - now) / 2
				end
			end
			ship.reloadEnd = serverNow + reloadEndOf(ship, now)
			if not ship.test then
				R.MasteryService.Add(player, "Gunner", q == 3 and MasteryCfg.Gain.ReloadPerfect or MasteryCfg.Gain.ReloadGood)
			end
		end
		setAttrs(ship)
		return { ok = true, data = { q = q } }
	end, 0.2)

	-- Z at the helm: Round -> Chain -> Bomb (only the unlocked ones)
	Net.Handle("SetShot", function(player, data)
		local ship = Ship.GetShipOf(player)
		local id = type(data) == "table" and data.shot
		local def = type(id) == "string" and Gunner.Shots[id]
		if not ship or not def then
			return false
		end
		if MasteryCfg.Level(R.PlayerService.Profile(player), "Gunner") < def.lv then
			return false, def.name .. " needs Gunner Mastery Lv." .. def.lv
		end
		ship.shot = id
		setAttrs(ship)
		return { ok = true, msg = def.name .. " loaded" .. (def.powder and " (1 Gunpowder per volley)" or "") }
	end, 0.2)

	-- v0.25.155 (#29): R at the helm fires the special weapons (harpoon guns, fire pots) that bear on the target
	Net.Handle("FireSpecial", function(player, data)
		local ship = helmShip(player)
		if not ship then
			return false, "Take the helm of your ship"
		end
		if #ship.specials == 0 then
			return false, "No harpoon gun or fire pot on this ship (Weapon parts)"
		end
		local target = type(data) == "table" and typeof(data.target) == "Vector3" and data.target
		if not target or target.X ~= target.X or target.Z ~= target.Z then
			return false
		end
		local d = R.PlayerService.Derived(player) or {}
		local now = os.clock()
		local fired, bearing = volley(ship, target, #ship.specials, 1 + (d.cannonDamage or 0), player, 4, nil, ship.specials)
		if fired == 0 then
			return false, bearing > 0 and "Reloading" or "Target is outside their firing arcs"
		end
		local nextReady = math.huge
		for _, c in ipairs(ship.specials) do
			nextReady = math.min(nextReady, c.readyAt or 0)
		end
		ship.specialEnd = workspace:GetServerTimeNow() + math.max(0, nextReady - now)
		setAttrs(ship)
		return true
	end, 0.3)

	-- v0.25.155 (#30): X at the helm drops a powder keg astern
	Net.Handle("DropKeg", function(player)
		local ship = helmShip(player)
		if not ship then
			return false, "Take the helm of your ship"
		end
		if not ship.kegMax then
			return false, "No Powder Keg Rack on this ship (Weapon parts)"
		end
		if (ship.kegs or 0) < 1 then
			return false, "No kegs left: the rack refills slowly"
		end
		ship.kegs -= 1
		ship.kegRefill = ship.kegRefill or os.clock()
		local at = ship.root.CFrame * CFrame.new(0, 0, ship.length / 2 + 4)
		dropKeg(ship, Vector3.new(at.X, GameConfig.SeaLevel + 0.6, at.Z))
		setAttrs(ship)
		return true
	end, 0.6)

	-- v0.25.155 (#33): lamps on your ship: "auto" (lit at night), "on", "off" for everyone who sees it
	Net.Handle("ShipLights", function(player, data)
		local ship = Ship.GetShipOf(player)
		local mode = type(data) == "table" and data.mode
		if not ship or (mode ~= "auto" and mode ~= "on" and mode ~= "off") then
			return false
		end
		ship.model:SetAttribute("Lights", mode)
		return true
	end, 0.3)

	-- v0.25.155 (#21): the test sail's wind (0 = dead calm .. 1.5 = a gale)
	Net.Handle("ShipTestWind", function(player, data)
		local ship = Ship.GetShipOf(player)
		local w = type(data) == "table" and tonumber(data.wind)
		if not ship or not ship.test or not w or w ~= w then
			return false
		end
		ship.testWind = math.clamp(w, 0, 1.5)
		return true
	end, 0.2)

	Net.Get("ShipInput").OnServerEvent:Connect(function(player, throttle, steer)
		local ship = Ship.GetShipOf(player)
		if not ship or type(throttle) ~= "number" or type(steer) ~= "number" then
			return
		end
		if throttle ~= throttle or steer ~= steer then
			return
		end
		ship.throttle = math.clamp(throttle, -0.4, 1)
		ship.steer = math.clamp(steer, -1, 1)
	end)

	-- physics loop
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, ship in pairs(ships) do
			if not ship.sinking and ship.root.Parent then
				local ok, err = pcall(stepShip, ship, dt, now)
				if not ok then
					warn("[ShipService]", err)
				end
				-- v0.25.150: sail level for every client's cloth (Controllers/SailCloth): 0 = furled, 1-3 = how far out
				local lvl = (ship.throttle or 0) > 0.01 and math.clamp(math.round(ship.throttle * 3), 1, 3) or 0
				if ship.sailLevel ~= lvl then
					ship.sailLevel = lvl
					ship.model:SetAttribute("Sails", lvl)
				end
				if ship.crew then
					local okC, errC = pcall(crewStep, ship, dt, now)
					if not okC then
						warn("[ShipService] crew:", errC)
					end
				end
				if #ship.seaKings > 0 then
					updateSeaKings(ship, dt)
				end
			end
		end
	end)

	-- AI + attributes + Doldrums (slower tick than physics)
	task.spawn(function()
		local acc = 0
		while true do
			task.wait(0.2)
			acc += 0.2
			local now = os.clock()
			for _, ship in pairs(ships) do
				if not ship.sinking then
					if ship.npc then
						pcall(npcThink, ship, now)
					end
					setAttrs(ship)
				end
			end
			local okK, errK = pcall(kegStep, now)
			if not okK then
				warn("[ShipService] kegs:", errK)
			end
			if acc >= 1 then
				acc = 0
				for _, ship in pairs(ships) do
					if not ship.sinking then
						local okT, errT = pcall(slowTick, ship, now)
						if not okT then
							warn("[ShipService] tick:", errT)
						end
					end
					if not ship.sinking and not ship.test then
						if ship.owner then
							calmBeltTick(ship)
							-- Discover islands while sailing past
							local island, d = SeaZones.NearestIsland(ship.root.Position)
							if island and d < island.radius + 350 then
								for _, pl in ipairs(playersOn(ship)) do
									local p = R.DataService.Get(pl)
									if p and not p.unlocked[island.id] then
										R.PlayerService.UnlockIsland(pl, island.id)
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	task.spawn(npcSpawner)
end

return Ship
