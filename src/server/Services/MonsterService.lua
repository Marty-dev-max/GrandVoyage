-- MonsterService: spawning, AI, damage, EXP, loot and card drops
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Reach = require(Shared.Modules.Reach)
local Monsters = require(Shared.Config.Monsters)
local Islands = require(Shared.Config.Islands)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)
local Anim = require(Shared.Modules.Anim)
local SerpentChain = require(Shared.Modules.SerpentChain)
local ModelFactory = require(script.Parent.Parent.World.ModelFactory)

local MS = {}
local R
local mobs = {} -- uid -> mob
local byModel = {} -- model -> mob
local nextUid = 0
local folder

function MS.Init(registry)
	R = registry
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace
end

local function groundAt(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:FindFirstChild("World") }
	local hit = workspace:Raycast(Vector3.new(x, fromY or 400, z), Vector3.new(0, -800, 0), params)
	return hit and hit.Position or Vector3.new(x, 8, z)
end
MS.GroundAt = groundAt

local function makeBar(mob)
	local root = mob.root
	local bb = ModelFactory.Billboard(root, mob.def.name, "Lv." .. mob.def.level, mob.def.isBoss and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1), 3 + (mob.def.style.scale or 1) * 2.5)
	bb.Size = UDim2.fromOffset(mob.def.isBoss and 260 or 170, 62)
	bb.MaxDistance = mob.def.isBoss and 260 or 110
	local back = Instance.new("Frame")
	back.Name = "HPBack"
	back.Size = UDim2.new(0.8, 0, 0, 8)
	back.Position = UDim2.new(0.1, 0, 1, -6)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.BorderSizePixel = 0
	back.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = mob.def.isBoss and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(110, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	c:Clone().Parent = fill
	mob.hpFill = fill
end

local function updateBar(mob)
	if mob.hpFill then
		mob.hpFill.Size = UDim2.new(math.clamp(mob.hp / mob.maxHp, 0, 1), 0, 1, 0)
	end
	mob.model:SetAttribute("HP", mob.hp)
end

-- opts: { zone = {center=Vector3, radius}, onDeath = fn(mob, killer), noRespawn = bool, parent = Instance, hpMult = n }
function MS.Spawn(monsterId, position, opts)
	local def = Monsters[monsterId]
	if not def then
		warn("unknown monster", monsterId)
		return nil
	end
	opts = opts or {}
	nextUid += 1
	local model = ModelFactory.Monster(def)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	local mob = {
		uid = nextUid,
		def = def,
		model = model,
		root = root,
		hum = hum,
		hp = math.floor(def.hp * (opts.hpMult or 1)),
		maxHp = math.floor(def.hp * (opts.hpMult or 1)),
		home = position,
		zone = opts.zone,
		opts = opts,
		damageBy = {},
		lastAttack = 0,
		lastMove = 0,
		nextWander = os.clock() + math.random() * 5,
		nextSpecial = os.clock() + 8,
	}
	model:SetAttribute("MobUid", mob.uid)
	model:SetAttribute("MonsterId", def.id)
	model:SetAttribute("Level", def.level)
	model:SetAttribute("MaxHP", mob.maxHp)
	model:SetAttribute("Boss", def.isBoss == true)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 4 + (def.style.scale or 1) * 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
	if hum then
		hum.WalkSpeed = def.moveSpeed
		hum.MaxHealth = 1e9 -- real HP lives in mob.hp (Humanoid is only used for walking)
		hum.Health = 1e9
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	model.Parent = opts.parent or folder
	if root and root:IsDescendantOf(workspace) then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	makeBar(mob)
	updateBar(mob)
	-- voxel monsters animate with real animations played here on the server (they replicate to every client):
	-- an idle loop underneath, a walk loop whose weight follows the speed, attack + hit one-shots
	if hum and model:GetAttribute("RealModel") then
		task.defer(function()
			if mob.dead or not model.Parent then
				return
			end
			Anim.Play(hum, "Mon_Idle", { fade = 0 })
			mob.walkTrack = Anim.Play(hum, "Mon_Walk", { fade = 0, weight = 0.01 })
			mob.walkW = 0
		end)
	end
	mobs[mob.uid] = mob
	byModel[model] = mob
	return mob
end

function MS.FromInstance(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	local m = inst
	while m and m ~= workspace do
		if byModel[m] then
			return byModel[m]
		end
		m = m.Parent
	end
	return nil
end

function MS.InRadius(pos, radius)
	local out = {}
	for _, mob in pairs(mobs) do
		if not mob.dead and mob.root and Reach.Gap(pos, mob.model) <= radius then
			table.insert(out, mob)
		end
	end
	return out
end

local function rollDrops(player, def, mult, pos)
	local d = R.PlayerService.Derived(player)
	local got = {}
	for _, drop in ipairs(def.drops or {}) do
		local id, chance, mn, mx = drop[1], drop[2], drop[3] or 1, drop[4] or 1
		if math.random() < chance * (mult or 1) then
			local qty = math.random(mn, mx)
			if R.InventoryService.AddItem(player, id, qty) then
				table.insert(got, { id = id, qty = qty })
			end
		end
	end
	-- Cards (LUK slightly increases the chance)
	local luk = d and d.LUK or 1
	if def.card and ItemDB.Get(def.card) and math.random() < def.cardChance * (1 + luk * 0.003) then
		if R.InventoryService.AddItem(player, def.card, 1) then
			table.insert(got, { id = def.card, qty = 1, card = true })
			Net.PushAll("Announce", { text = "✨ " .. player.DisplayName .. " obtained " .. ItemDB.Get(def.card).name .. "!", kind = "card", rarity = ItemDB.Get(def.card).rarity })
		end
	end
	local beli = def.beli and math.random(def.beli[1], def.beli[2]) or 0
	if beli > 0 then
		beli = math.floor(beli * (1 + (d and d.beliPct or 0)))
		R.PlayerService.AddBeli(player, beli)
	end
	-- pos: where the loot bursts out on the client before flying into the HUD
	Net.Push(player, "Loot", { items = got, beli = beli, pos = pos })
	return got
end
MS.RollDrops = rollDrops

local function die(mob, killer)
	if mob.dead then
		return
	end
	mob.dead = true
	local def = mob.def
	-- EXP is shared by damage contribution
	local top, topDmg = nil, 0
	for pl, dmg in pairs(mob.damageBy) do
		if pl.Parent then
			local share = math.clamp(dmg / mob.maxHp, 0, 1)
			R.PartyService.ShareExp(pl, def.exp * share, def.jobExp * share, mob.root.Position)
			R.QuestService.Event(pl, "Kill", def.id)
			if dmg > topDmg then
				top, topDmg = pl, dmg
			end
		end
	end
	if top then
		rollDrops(top, def, 1, mob.root and mob.root.Position)
		if def.isBoss then
			Net.PushAll("Announce", { text = "👑 MVP! " .. top.DisplayName .. " defeated " .. def.name .. "!", kind = "mvp" })
			R.PlayerService.GiveExp(top, def.exp * 0.3, def.jobExp * 0.3, mob.root.Position)
			for pl, dmg in pairs(mob.damageBy) do
				if pl ~= top and pl.Parent and dmg / mob.maxHp >= 0.05 then
					R.PlayerService.AddBeli(pl, math.floor((def.beli and def.beli[1] or 0) * 0.3))
					R.PlayerService.Notify(pl, "Boss participation reward: Doubloons", "good")
				end
			end
		end
		R.PvPService.OnMobKilled(top, def)
		R.FruitService.OnKill(top)
		if def.isBoss then
			R.FruitService.RollDrop(top, require(Shared.Config.Fruits).Drops.Boss, "MVP " .. def.name)
			R.PearlService.Earn(top, require(Shared.Config.Pearls).Sources.MVP, "mvp")
			R.QuestService.Event(top, "Boss", def.id)
		end
	end
	Net.FX("MobDeath", { pos = mob.root.Position, color = def.style.color, boss = def.isBoss, model = mob.model }, mob.root.Position, 300)
	if mob.opts.onDeath then
		task.spawn(mob.opts.onDeath, mob, top)
	end
	mobs[mob.uid] = nil
	byModel[mob.model] = nil
	local model = mob.model
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	task.delay(0.6, function()
		model:Destroy()
	end)
	if mob.zone and not mob.opts.noRespawn then
		task.delay(def.respawn, function()
			local z = mob.zone
			local a = math.random() * math.pi * 2
			local r = math.random() * z.radius
			local pos = groundAt(z.center.X + math.cos(a) * r, z.center.Z + math.sin(a) * r)
			MS.Spawn(def.id, pos, mob.opts)
		end)
	end
end

-- Attacked (hit or miss) while not fighting anyone: the monster startles ("!" pops over its head with a gasp, MobAlert FX),
-- snaps around to face the attacker and charges in at double speed for a moment, then fights as usual (owner, v0.22.3).
local CHARGE_TIME, CHARGE_SPEED = 1.6, 2
function MS.Provoke(mob, player)
	if mob.dead or not player or mob.target ~= nil or not mob.root then
		return
	end
	if mob.opts.canDamage and not mob.opts.canDamage(player) then
		return
	end
	mob.target = player
	local proot = R.PlayerService.Root(player)
	Net.FX("MobAlert", { model = mob.model }, mob.root.Position, 250)
	if mob.def.static or mob.opts.static or not proot then
		return
	end
	local look = Vector3.new(proot.Position.X, mob.root.Position.Y, proot.Position.Z)
	if (look - mob.root.Position).Magnitude > 0.5 then
		mob.root.CFrame = CFrame.lookAt(mob.root.Position, look)
	end
	if mob.hum then
		mob.hum.WalkSpeed = mob.def.moveSpeed * CHARGE_SPEED
		mob.hum:MoveTo(proot.Position)
		mob.lastMove = os.clock()
		-- ready to swing as soon as it arrives
		mob.lastAttack = math.min(mob.lastAttack, os.clock() - mob.def.attackSpeed * 0.6)
		local hum = mob.hum
		task.delay(CHARGE_TIME, function()
			if hum.Parent and not mob.dead then
				hum.WalkSpeed = mob.def.moveSpeed
			end
		end)
	end
end

-- kind (optional) colors the number on clients: fire, burn, poison, ice, shock, pierce, pet, cannon
function MS.Damage(mob, amount, player, crit, kind)
	if mob.dead then
		return
	end
	if mob.opts.canDamage and player and not mob.opts.canDamage(player) then
		Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 4, 0), text = "IMMUNE" }, mob.root.Position, 200)
		return
	end
	amount = math.floor(amount)
	mob.hp -= amount
	if player then
		mob.damageBy[player] = (mob.damageBy[player] or 0) + amount
		MS.Provoke(mob, player)
	end
	Net.FX("Damage", { pos = mob.root.Position + Vector3.new(0, 3, 0), amount = amount, crit = crit, kind = kind, src = player and player.UserId or 0, model = mob.model }, mob.root.Position, 250)
	if mob.walkTrack and os.clock() - (mob.hitAnimAt or 0) > 0.35 then
		mob.hitAnimAt = os.clock()
		Anim.Play(mob.hum, "Mon_Hit", { fade = 0.03 })
	end
	updateBar(mob)
	if mob.hp <= 0 then
		die(mob, player)
	end
end

-- Remove a monster without rewards but keep its spawn point alive (used by pet capture)
function MS.Remove(mob)
	if mob.dead then
		return
	end
	mob.damageBy = {}
	die(mob, nil)
end

-- swap placeholder-bodied mobs for the real (voxel) models once AssetService has loaded them;
-- only mobs nobody is fighting, so nothing is lost
function MS.RefreshModels()
	local n = 0
	for uid, mob in pairs(mobs) do
		if mob.zone and not mob.def.isBoss and not mob.dead and not mob.model:GetAttribute("RealModel") and next(mob.damageBy) == nil and mob.target == nil then
			mob.dead = true
			mobs[uid] = nil
			mob.model:Destroy()
			MS.Spawn(mob.def.id, mob.home, mob.opts)
			n += 1
		end
	end
	return n
end

function MS.Kill(mob)
	mob.opts.noRespawn = true
	mob.damageBy = {}
	die(mob, nil)
end

local function validTarget(mob, pl)
	if not pl or not pl.Parent then
		return false
	end
	local root = R.PlayerService.Root(pl)
	local hum = R.PlayerService.Humanoid(pl)
	if not root or not hum or hum.Health <= 0 then
		return false
	end
	local leash = mob.zone and (mob.zone.radius + 70) or 140
	if (root.Position - mob.home).Magnitude > leash then
		return false
	end
	return true, root
end

local function findAggroTarget(mob)
	local best, bestD = nil, mob.def.isBoss and 45 or 26
	for _, pl in ipairs(Players:GetPlayers()) do
		local ok, root = validTarget(mob, pl)
		if ok then
			local d = (root.Position - mob.root.Position).Magnitude
			if d < bestD then
				best, bestD = pl, d
			end
		end
	end
	return best
end

local function bossSpecial(mob)
	local center = mob.root.Position
	local radius = 20 + (mob.def.style.scale or 1) * 3
	Net.FX("Telegraph", { pos = center, radius = radius, time = 1.2 }, center, 300)
	task.delay(1.2, function()
		if mob.dead then
			return
		end
		Net.FX("Slam", { pos = mob.root.Position, radius = radius }, center, 300)
		for _, pl in ipairs(Players:GetPlayers()) do
			local root = R.PlayerService.Root(pl)
			if root and Reach.Gap(root.Position, mob.model) <= radius then
				R.CombatService.MonsterHit(mob, pl, 1.8)
			end
		end
	end)
end

-- ===== full-length serpents (v0.22.5: Bay Serpent) =====
-- The head walks with its Humanoid; the body + tail follow its trail (Modules/SerpentChain). Every 0.2 s the body's
-- piece centers go out as the BodyPts attribute: Reach measures hits against the whole body, and clients draw it.
-- Attacks are telegraphed on the deck first (red line / circle that fills up), then land:
--   lunge bite (close): the head darts along a 28-stud line;  water spit (far): a 50-stud jet;  tail slam: a circle
--   around the tail. Every third attack is a tail slam.
local function serpentAnchor(mob)
	return mob.root.CFrame:PointToWorldSpace(mob.neckOffset)
end

local function serpentInit(mob)
	local spec = mob.def.serpent
	local cf, ext = mob.model:GetBoundingBox()
	local rel = mob.root.CFrame:PointToObjectSpace(cf.Position)
	-- the neck end: back (+Z) of the head model, at body height above its lowest point
	mob.neckOffset = rel + Vector3.new(0, -ext.Y / 2 + spec.radius, ext.Z / 2 - 1.5)
	mob.headHalf = ext.Z / 2
	mob.model:SetAttribute("NeckOffset", mob.neckOffset)
	mob.model:SetAttribute("BodyRadius", spec.radius)
	mob.chain = SerpentChain.New(spec)
	SerpentChain.Reset(mob.chain, serpentAnchor(mob), -mob.root.CFrame.LookVector)
end

local function serpentBody(mob)
	local anchor = serpentAnchor(mob)
	SerpentChain.Push(mob.chain, anchor)
	mob.pieces = SerpentChain.Pieces(mob.chain, anchor)
	mob.model:SetAttribute("BodyPts", SerpentChain.Pack(mob.pieces))
end

local function playersInLine(from, to, width)
	local out = {}
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local len = d.Magnitude
	if len < 0.1 then
		return out
	end
	d = d.Unit
	for _, pl in ipairs(Players:GetPlayers()) do
		local root = R.PlayerService.Root(pl)
		if root then
			local rel = root.Position - from
			local along = rel.X * d.X + rel.Z * d.Z
			local side = math.abs(rel.X * d.Z - rel.Z * d.X)
			if along >= -3 and along <= len + 2 and side <= width / 2 + 1.5 and math.abs(rel.Y) < 16 then
				table.insert(out, pl)
			end
		end
	end
	return out
end

local function serpentAttack(mob, troot, now)
	local def, root, hum = mob.def, mob.root, mob.hum
	local gy = mob.home.Y + 0.25
	local head = root.Position
	local flat = Vector3.new(troot.Position.X - head.X, 0, troot.Position.Z - head.Z)
	local dir = flat.Magnitude > 0.5 and flat.Unit or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	hum:MoveTo(root.Position)
	root.CFrame = CFrame.lookAt(head, head + dir)
	mob.attackN = (mob.attackN or 0) + 1
	local from = Vector3.new(head.X, gy, head.Z)
	if mob.attackN % 3 == 0 and mob.pieces then
		-- TAIL SLAM: the tail rises and crashes down
		local tail = mob.pieces[#mob.pieces].pos
		local center = Vector3.new(tail.X, gy, tail.Z)
		local radius = 15
		mob.busyUntil = now + 1.6
		Net.FX("Telegraph", { kind = "circle", pos = center, radius = radius, time = 1.1 }, center, 320)
		Net.FX("SerpentTail", { model = mob.model, time = 1.1 }, center, 320)
		task.delay(1.1, function()
			if mob.dead then
				return
			end
			Net.FX("Slam", { pos = center + Vector3.new(0, 2.5, 0), radius = radius }, center, 320)
			for _, pl in ipairs(Players:GetPlayers()) do
				local r = R.PlayerService.Root(pl)
				if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= radius + 1 and math.abs(r.Position.Y - center.Y) < 14 then
					R.CombatService.MonsterHit(mob, pl, 1.5)
				end
			end
		end)
	elseif flat.Magnitude <= 26 then
		-- LUNGE BITE along a line
		local to = from + dir * 28
		mob.busyUntil = now + 1.8
		Net.FX("Telegraph", { kind = "line", from = from, to = to, width = 9, time = 0.85 }, head, 320)
		task.delay(0.6, function()
			if not mob.dead then
				Anim.Play(hum, "Mon_SerpentBite", { fade = 0.05 })
			end
		end)
		task.delay(0.85, function()
			if mob.dead then
				return
			end
			hum.WalkSpeed = 80
			hum:MoveTo(to)
			Net.FX("SerpentBite", { from = from, to = to }, head, 320)
			task.delay(0.15, function()
				if not mob.dead then
					for _, pl in ipairs(playersInLine(from, to, 9)) do
						R.CombatService.MonsterHit(mob, pl, 1.7)
					end
				end
			end)
			task.delay(0.5, function()
				if not mob.dead and hum.Parent then
					hum.WalkSpeed = def.moveSpeed
					hum:MoveTo(root.Position)
				end
			end)
		end)
	else
		-- WATER SPIT: a long jet along a line
		local to = from + dir * 50
		mob.busyUntil = now + 1.9
		Net.FX("Telegraph", { kind = "line", from = from, to = to, width = 7, time = 1.1 }, head, 320)
		task.delay(0.6, function()
			if not mob.dead then
				Anim.Play(hum, "Mon_SerpentSpit", { fade = 0.05 })
			end
		end)
		task.delay(1.1, function()
			if mob.dead then
				return
			end
			local mouth = root.CFrame * Vector3.new(0, 1.5, -(mob.headHalf or 10) + 1)
			Net.FX("SerpentSpit", { from = mouth, to = to + Vector3.new(0, 1.2, 0) }, head, 320)
			for _, pl in ipairs(playersInLine(from, to, 7)) do
				R.CombatService.MonsterHit(mob, pl, 1.3)
			end
		end)
	end
end

local function serpentStep(mob, troot, now)
	if mob.busyUntil and now < mob.busyUntil then
		return
	end
	local head = mob.root.Position
	local flat = Vector3.new(troot.Position.X - head.X, 0, troot.Position.Z - head.Z)
	if flat.Magnitude > 18 and now - mob.lastMove > 0.35 then
		mob.lastMove = now
		mob.hum:MoveTo(troot.Position)
	elseif flat.Magnitude <= 18 then
		mob.hum:MoveTo(mob.root.Position)
	end
	if now - mob.lastAttack >= mob.def.attackSpeed and flat.Magnitude <= 48 then
		mob.lastAttack = now
		serpentAttack(mob, troot, now)
	end
end

local function syncTarget(mob)
	local id = mob.target and mob.target.UserId or 0
	if mob.lastTargetId ~= id then
		mob.lastTargetId = id
		mob.model:SetAttribute("TargetId", id)
	end
end

local function step(mob, now)
	if mob.dead or not mob.root or not mob.root.Parent or mob.def.static or mob.opts.static then
		return
	end
	local def = mob.def
	syncTarget(mob)
	-- walk cycle: blend in with the speed, play faster when running
	if mob.walkTrack then
		local v = mob.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local w = math.clamp(speed / math.max(4, def.moveSpeed * 0.6), 0, 1)
		if math.abs(w - mob.walkW) > 0.08 then
			mob.walkW = w
			mob.walkTrack:AdjustWeight(math.max(0.01, w), 0.2)
			mob.walkTrack:AdjustSpeed(math.clamp(speed / 8, 0.6, 2))
		end
	end
	local ok, troot = validTarget(mob, mob.target)
	if not ok then
		mob.target = nil
		if def.aggro then
			mob.target = findAggroTarget(mob)
			ok, troot = validTarget(mob, mob.target)
		end
	end
	if def.serpent and not mob.chain and mob.hum then
		serpentInit(mob)
	end
	if mob.chain then
		serpentBody(mob)
		if ok and troot and mob.hum then
			serpentStep(mob, troot, now)
			return
		end
	end
	if ok and troot then
		-- measured to the monster's body, so huge bosses can bite players standing at their feet
		local dist = Reach.Gap(troot.Position, mob.model)
		local reach = def.attackRange
		if dist > reach then
			if mob.hum and now - mob.lastMove > 0.35 then
				mob.lastMove = now
				mob.hum:MoveTo(troot.Position)
			end
		else
			if mob.hum then
				mob.hum:MoveTo(mob.root.Position)
			end
			local look = Vector3.new(troot.Position.X, mob.root.Position.Y, troot.Position.Z)
			if (look - mob.root.Position).Magnitude > 0.5 then
				mob.root.CFrame = CFrame.lookAt(mob.root.Position, look)
			end
			if now - mob.lastAttack >= def.attackSpeed then
				mob.lastAttack = now
				Net.FX("MobAttack", { model = mob.model, to = troot.Position, ranged = def.attackRange > 15, from = mob.root.Position }, mob.root.Position, 200)
				if mob.walkTrack then
					Anim.Play(mob.hum, "Mon_Attack", { fade = 0.05 })
				end
				local target = mob.target
				-- the hit lands on the attack clip's strike frame
				task.delay(def.attackRange > 15 and 0.3 or Anim.Strike("Mon_Attack"), function()
					if not mob.dead and target then
						R.CombatService.MonsterHit(mob, target, 1)
					end
				end)
			end
		end
		if def.isBoss and now >= mob.nextSpecial then
			mob.nextSpecial = now + 9
			bossSpecial(mob)
		end
	else
		-- Wander inside the zone; heal when back home
		if mob.hp < mob.maxHp and (mob.root.Position - mob.home).Magnitude < 20 then
			mob.hp = math.min(mob.maxHp, mob.hp + mob.maxHp * 0.05)
			mob.damageBy = {}
			updateBar(mob)
		end
		if mob.hum and now >= mob.nextWander then
			mob.nextWander = now + 4 + math.random() * 5
			local center = mob.zone and mob.zone.center or mob.home
			local radius = mob.zone and mob.zone.radius or 10
			if (mob.root.Position - center).Magnitude > radius + 15 then
				mob.hum:MoveTo(mob.home)
			else
				local a = math.random() * math.pi * 2
				local r = math.random() * radius
				mob.hum:MoveTo(Vector3.new(center.X + math.cos(a) * r, mob.root.Position.Y, center.Z + math.sin(a) * r))
			end
		end
	end
end

function MS.SpawnIslandMobs()
	for _, island in ipairs(Islands.List) do
		for _, sp in ipairs(island.spawns) do
			local cx, cz = island.x + sp.offset.X, sp.offset.Y
			local center = groundAt(cx, cz)
			local zone = { center = center, radius = sp.radius }
			for _ = 1, sp.count do
				local a = math.random() * math.pi * 2
				local r = math.random() * sp.radius
				MS.Spawn(sp.monster, groundAt(cx + math.cos(a) * r, cz + math.sin(a) * r), { zone = zone })
			end
		end
	end
end

function MS.Start()
	MS.SpawnIslandMobs()
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, mob in pairs(mobs) do
				local ok, err = pcall(step, mob, now)
				if not ok then
					warn("[MonsterService]", err)
				end
			end
			task.wait(0.2)
		end
	end)
end

return MS
