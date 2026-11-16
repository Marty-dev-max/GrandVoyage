-- MonsterService: spawning, AI, damage, EXP, loot and card drops
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Reach = require(Shared.Modules.Reach)
local Monsters = require(Shared.Config.Monsters)
local Islands = require(Shared.Config.Islands)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)
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

local function rollDrops(player, def, mult)
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
	Net.Push(player, "Loot", { items = got, beli = beli })
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
		rollDrops(top, def, 1)
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
	Net.FX("MobDeath", { pos = mob.root.Position, color = def.style.color, boss = def.isBoss }, mob.root.Position, 300)
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

function MS.Damage(mob, amount, player, crit)
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
		if not mob.target then
			mob.target = player
		end
	end
	Net.FX("Damage", { pos = mob.root.Position + Vector3.new(0, 3, 0), amount = amount, crit = crit, src = player and player.UserId or 0 }, mob.root.Position, 250)
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
	local ok, troot = validTarget(mob, mob.target)
	if not ok then
		mob.target = nil
		if def.aggro then
			mob.target = findAggroTarget(mob)
			ok, troot = validTarget(mob, mob.target)
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
				local target = mob.target
				task.delay(def.attackRange > 15 and 0.3 or 0.15, function()
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
