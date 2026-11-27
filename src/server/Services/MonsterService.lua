-- MonsterService: spawning, AI, damage, EXP, loot and card drops
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Reach = require(Shared.Modules.Reach)
local Monsters = require(Shared.Config.Monsters)
local DamageTypes = require(Shared.Config.DamageTypes)
local Icons = require(Shared.Config.Icons)
local GameConfig = require(Shared.Config.GameConfig)
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

-- v0.25.137 (owner reference clip): bosses publish their drop table + the focus type as model attributes; the HUD
-- target panel shows them with the live DAMAGE PROGRESS (damage each player dealt / max HP, attribute DmgShare)
local function bossAttrs(mob)
	local def = mob.def
	local lines = {}
	for _, d in ipairs(def.drops or {}) do
		local it = ItemDB.Get(d[1])
		if it then
			table.insert(lines, { it.name, d[2] })
		end
	end
	if def.card and def.cardChance and def.cardChance > 0 and ItemDB.Get(def.card) then
		table.insert(lines, { "Card: " .. def.name, def.cardChance })
	end
	local bd = GameConfig.BladeDrop
	if bd and bd.BossChance then
		table.insert(lines, { "Mystery Blade", bd.BossChance })
	end
	table.sort(lines, function(x, y)
		return x[2] > y[2]
	end)
	while #lines > 6 do
		table.remove(lines, 1) -- keep the rare ones, they are what players hunt for
	end
	local parts = {}
	for _, l in ipairs(lines) do
		table.insert(parts, (l[1]:gsub("[|;]", "")) .. "|" .. l[2])
	end
	mob.model:SetAttribute("BossDrops", table.concat(parts, ";"))
	-- remake: the damage type this boss is weak to (Config/DamageTypes)
	local _, weak = DamageTypes.Pair(def.id)
	mob.model:SetAttribute("BossFocus", weak)
end

local function shareUpdate(mob)
	-- throttled: "Name|UserId|share;..." best first, at most 8 players
	local now = os.clock()
	if now - (mob.shareAt or 0) < 0.2 then
		return
	end
	mob.shareAt = now
	local total, list = 0, {}
	for pl, dmg in pairs(mob.damageBy) do
		if pl.Parent then
			total += dmg
			table.insert(list, { pl, dmg })
		end
	end
	table.sort(list, function(x, y)
		return x[2] > y[2]
	end)
	local parts = {}
	for i = 1, math.min(8, #list) do
		local pl = list[i][1]
		-- v0.25.139 (owner): progress = damage dealt / the boss's max HP (grows as you hit, not a 100% share)
		table.insert(parts, (pl.DisplayName:gsub("[|;]", "")) .. "|" .. pl.UserId .. "|" .. string.format("%.4f", math.min(1, list[i][2] / math.max(1, mob.maxHp))))
	end
	mob.model:SetAttribute("DmgShare", table.concat(parts, ";"))
end

-- top share of a monster plate kept for the damage-type chips (remake)
local CHIP_ROW = 0.27
local function makeBar(mob)
	if mob.def.isBoss then
		pcall(bossAttrs, mob)
	end
	local root = mob.root
	local elite = mob.def.mini ~= nil -- v0.25.148 mini boss: gold ELITE plate, no boss intro / music
	local bb = ModelFactory.Billboard(root, mob.def.name, (elite and "ELITE  " or "") .. "Lv." .. mob.def.level .. "  " .. string.rep("★", mob.def.stars or 1),
		mob.def.isBoss and Color3.fromRGB(255, 90, 90) or elite and Color3.fromRGB(255, 205, 70) or Color3.new(1, 1, 1), 3 + (mob.def.style.scale or 1) * 2.5)
	-- remake damage types (Config/DamageTypes): a pair of chips centered above the name, weak (green, "+") left and
	-- resist (red, "-") right, each showing its type's icon. Sized from the plate height (the client rescales plates).
	local res, weak = DamageTypes.Pair(mob.def.id)
	local function chip(name, dtype, side, rim, sign)
		local info = DamageTypes.Info[dtype]
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(side < 0 and 1 or 0, 1)
		f.Position = UDim2.new(0.5, side * 3, CHIP_ROW, -1)
		f.SizeConstraint = Enum.SizeConstraint.RelativeYY
		f.Size = UDim2.fromScale(CHIP_ROW - 0.04, CHIP_ROW - 0.04)
		f.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
		f.BackgroundTransparency = 0.15
		f.BorderSizePixel = 0
		f.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Color = rim
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = f
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(0.86, 0.86)
		img.Position = UDim2.fromScale(0.07, 0.07)
		img.Image = Icons[info.icon] or ""
		img.ResampleMode = Enum.ResamplerMode.Pixelated
		img.ImageTransparency = sign == "-" and 0.25 or 0
		img.Parent = f
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.AnchorPoint = Vector2.new(1, 1)
		s.Position = UDim2.new(1, 4, 1, 4)
		s.Size = UDim2.fromScale(0.55, 0.55)
		s.Font = Enum.Font.Arcade
		s.TextScaled = true
		s.Text = sign
		s.TextColor3 = rim
		s.TextStrokeTransparency = 0
		s.Parent = f
	end
	if weak then
		chip("WeakChip", weak, -1, Color3.fromRGB(110, 235, 120), "+")
	end
	if res then
		chip("ResistChip", res, 1, Color3.fromRGB(235, 80, 80), "-")
	end
	if weak or res then
		-- the plate grows a row on top for the chips (a BillboardGui clips everything outside its box)
		local title, sub = bb:FindFirstChild("Title"), bb:FindFirstChild("Subtitle")
		if title then
			title.Position = UDim2.fromScale(0, CHIP_ROW)
			title.Size = UDim2.fromScale(1, 0.55 * (1 - CHIP_ROW))
		end
		if sub then
			sub.Position = UDim2.fromScale(0, CHIP_ROW + 0.55 * (1 - CHIP_ROW))
			sub.Size = UDim2.fromScale(1, 0.4 * (1 - CHIP_ROW))
		end
	end
	bb.Size = UDim2.fromOffset(mob.def.isBoss and 260 or elite and 210 or 170, (weak or res) and math.floor(62 / (1 - CHIP_ROW)) or 62)
	bb.MaxDistance = mob.def.isBoss and 260 or elite and 160 or 110
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
	fill.BackgroundColor3 = mob.def.isBoss and Color3.fromRGB(255, 70, 70) or elite and Color3.fromRGB(255, 190, 50) or Color3.fromRGB(110, 230, 110)
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

-- opts: { zone = {center=Vector3, radius}, onDeath = fn(mob, killer), noRespawn = bool, parent = Instance, hpMult = n,
--   def = a ready definition (ship crew scale theirs), model = a ready model already placed (ship crew figures) }
-- Roblox's own R15 idle / walk animations (free for every game) for the voxel humanoid monsters
local R15_LOOPS = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://507777826" }
local function r15Loop(hum, key, weight)
	local animator = Anim.Animator(hum)
	if not animator then
		return nil
	end
	local a = Instance.new("Animation")
	a.Name = "Mob" .. key
	a.AnimationId = R15_LOOPS[key]
	local ok, tr = pcall(animator.LoadAnimation, animator, a)
	if not ok then
		return nil
	end
	tr.Looped = true
	tr.Priority = Enum.AnimationPriority.Core
	tr:Play(0, weight)
	return tr
end

function MS.Spawn(monsterId, position, opts)
	opts = opts or {}
	local def = opts.def or Monsters[monsterId]
	if not def then
		warn("unknown monster", monsterId)
		return nil
	end
	nextUid += 1
	local model = opts.model or ModelFactory.Monster(def)
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
	model:SetAttribute("Elite", def.mini ~= nil)
	if not opts.model then
		model:PivotTo(CFrame.new(position + Vector3.new(0, 4 + (def.style.scale or 1) * 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
	end
	if hum then
		hum.WalkSpeed = def.moveSpeed
		hum.MaxHealth = 1e9 -- real HP lives in mob.hp (Humanoid is only used for walking)
		hum.Health = 1e9
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	if not opts.model then
		model.Parent = opts.parent or folder
	end
	if root and root:IsDescendantOf(workspace) and not opts.model then
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
			if model:GetAttribute("R15Mob") then
				-- voxel humanoids (v0.25.32): Roblox's default R15 idle / walk, a player clip to attack, Hurt when hit
				r15Loop(hum, "Idle", 1)
				mob.walkTrack = r15Loop(hum, "Walk", 0.01)
				mob.walkRate = 14
				mob.attackClip = model:GetAttribute("AttackClip")
				mob.hitClip = "Hurt"
			else
				Anim.Play(hum, "Mon_Idle", { fade = 0 })
				mob.walkTrack = Anim.Play(hum, "Mon_Walk", { fade = 0, weight = 0.01 })
			end
			mob.walkW = 0
		end)
	end
	mobs[mob.uid] = mob
	byModel[model] = mob
	-- v0.25.1: clients near by see it assemble out of blocks (MobSpawn FX)
	Net.FX("MobSpawn", { model = model, pos = position }, position, 180)
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

-- remake R2: what kind of foe this was, for the Origin reward perks (OriginService.RewardMult)
local function rewardSrcOf(def)
	return { kind = def.isBoss and "boss" or "mob", human = R.OriginService.IsHuman(def) }
end

local function rollDrops(player, def, mult, pos)
	local d = R.PlayerService.Derived(player)
	if R.StoreService and R.StoreService.BoostActive(player, "drop") then
		mult = (mult or 1) * 2 -- Store 2x Drop
	end
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
	-- v0.25.124 blades (GameConfig.BladeDrop): bosses roll a Twenty Tides blade, other monsters a Forty Fathoms one
	local bd = GameConfig.BladeDrop
	local tier = def.isBoss and "Tide" or ((def.level or 0) >= bd.MobLevel and "Fathom")
	local list = tier and ItemDB.Blades[tier]
	if list and math.random() < (def.isBoss and bd.BossChance or bd.MobChance) * (mult or 1) then
		local id = list[math.random(#list)]
		if R.InventoryService.AddItem(player, id, 1) then
			table.insert(got, { id = id, qty = 1 })
			if def.isBoss then
				Net.PushAll("Announce", { text = "⚔️ " .. player.DisplayName .. " found " .. ItemDB.Get(id).name .. "!", kind = "card", rarity = ItemDB.Get(id).rarity })
			end
		end
	end
	-- Cards (remake: no luck attribute, the plain chance)
	local luk = 0
	if def.card and ItemDB.Get(def.card) and math.random() < def.cardChance * (1 + luk * 0.003) then
		if R.InventoryService.AddItem(player, def.card, 1) then
			table.insert(got, { id = def.card, qty = 1, card = true })
			Net.PushAll("Announce", { text = "✨ " .. player.DisplayName .. " obtained " .. ItemDB.Get(def.card).name .. "!", kind = "card", rarity = ItemDB.Get(def.card).rarity })
		end
	end
	local beli = def.beli and math.random(def.beli[1], def.beli[2]) or 0
	if beli > 0 then
		beli = math.floor(beli * (1 + (d and d.beliPct or 0)) * R.OriginService.RewardMult(R.PlayerService.Profile(player), rewardSrcOf(def), "beli"))
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
	local rewardSrc = rewardSrcOf(def) -- remake R2: Origin perks (boss / monster, humanoid or not)
	-- EXP is shared by damage contribution
	local top, topDmg = nil, 0
	for pl, dmg in pairs(mob.damageBy) do
		if pl.Parent then
			local share = math.clamp(dmg / mob.maxHp, 0, 1)
			R.PartyService.ShareExp(pl, def.exp * share, def.jobExp * share, mob.root.Position, rewardSrc)
			R.QuestService.Event(pl, "Kill", def.id)
			local pp = R.PlayerService.Profile(pl) -- v0.25.127 Index: defeated count per monster
			if pp then
				pp.index = pp.index or {}
				pp.index.kills = pp.index.kills or {}
				pp.index.kills[def.id] = (pp.index.kills[def.id] or 0) + 1
			end
			if dmg > topDmg then
				top, topDmg = pl, dmg
			end
		end
	end
	if top then
		rollDrops(top, def, 1, mob.root and mob.root.Position)
		if def.isBoss then
			Net.PushAll("Announce", { text = "👑 MVP! " .. top.DisplayName .. " defeated " .. def.name .. "!", kind = "mvp" })
			R.PlayerService.GiveExp(top, def.exp * 0.3, def.jobExp * 0.3, mob.root.Position, rewardSrc)
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
	Net.FX("MobDeath", { pos = mob.root.Position, color = def.style.color, boss = def.isBoss, model = mob.model, split = mob.splitKill, splitDir = mob.splitDir }, mob.root.Position, 300)
	if mob.opts.onDeath then
		task.spawn(mob.opts.onDeath, mob, top)
	end
	mobs[mob.uid] = nil
	byModel[mob.model] = nil
	local model = mob.model
	if mob.opts.model then
		-- ship crew are welded to their ship: cut them loose first, anchoring them would freeze the whole ship
		for _, w in ipairs(model:GetDescendants()) do
			if w:IsA("WeldConstraint") or w:IsA("JointInstance") then
				w:Destroy()
			end
		end
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	-- v0.24.0 (owner): the body stays a moment: clients topple it to the ground, it lies there, then breaks into
	-- voxel blocks + pixel dust (CreatureAnim.deathFall). Nothing can target it meanwhile (removed from mobs above).
	model:SetAttribute("Dead", true)
	for _, g in ipairs(model:GetDescendants()) do
		if g:IsA("BillboardGui") then
			g.Enabled = false -- name + HP bar go away at once
		end
	end
	task.delay(def.isBoss and 3.6 or 2.6, function()
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
	if mob.sea then
		return -- the sea serpent wakes and moves on its own (seaStep)
	end
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
-- match = "weak" / "resist" from Config/DamageTypes (CombatService hitTarget): a tag over the number
function MS.Damage(mob, amount, player, crit, kind, match)
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
		if mob.def.isBoss then
			shareUpdate(mob)
		end
		R.KnockdownService.OnMobHit(mob, player)
		MS.Provoke(mob, player)
	end
	Net.FX("Damage", { pos = mob.root.Position + Vector3.new(0, 3, 0), amount = amount, crit = crit, kind = kind, match = match, src = player and player.UserId or 0, model = mob.model }, mob.root.Position, 250)
	if mob.walkTrack and os.clock() - (mob.hitAnimAt or 0) > 0.35 then
		mob.hitAnimAt = os.clock()
		Anim.Play(mob.hum, mob.hitClip or "Mon_Hit", { fade = 0.03 })
	end
	updateBar(mob)
	if mob.hp <= 0 then
		die(mob, player)
	end
end

-- Knockback (v0.24.12, owner): a strong hit shoves the monster back a few studs, it skids (clients draw dust lines at
-- its feet: Knockback FX) and its AI pauses for the skid. power = how hard the hit was (combo finisher 1, Heavy Attack
-- 2, skills = their damage multiplier). Bosses and huge monsters only budge for power >= BOSS_POWER, and less far.
local BOSS_POWER = 2.4
local knockParams = RaycastParams.new()
knockParams.FilterType = Enum.RaycastFilterType.Exclude
-- durOverride (v0.25.77): a longer slide for long pulls (Smoke Grip), so the speed stays sane
function MS.Knockback(mob, fromPos, dist, power, durOverride)
	if mob.dead or not mob.root or not mob.hum or mob.sea or mob.chain or mob.def.static or mob.opts.static then
		return
	end
	local big = mob.def.isBoss or (mob.def.style and (mob.def.style.scale or 1) >= 2)
	if big then
		if (power or 1) < BOSS_POWER then
			return
		end
		dist *= 0.45
	end
	local root = mob.root
	local dir = Vector3.new(root.Position.X - fromPos.X, 0, root.Position.Z - fromPos.Z)
	if dir.Magnitude < 0.1 then
		dir = -root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	-- stop at walls / trees, and never shove a monster off a cliff or into the sea
	knockParams.FilterDescendantsInstances = { mob.model, workspace:FindFirstChild("Monsters") }
	local wall = workspace:Raycast(root.Position, dir * (dist + 1.5), knockParams)
	if wall then
		dist = math.max(0, wall.Distance - 1.5)
	end
	local to = root.Position + dir * dist
	local ground = workspace:Raycast(to + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), knockParams)
	if not ground or ground.Material == Enum.Material.Water then
		dist *= 0.3
	end
	if dist < 0.6 then
		return
	end
	local dur = durOverride or 0.24
	mob.knockUntil = os.clock() + dur + 0.12
	mob.hum:MoveTo(root.Position)
	local att = Instance.new("Attachment")
	att.Name = "KnockAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	-- v0.25.77 (owner: Smoke Grip threw monsters into the sky): the full velocity is driven, and the vertical part is
	-- never allowed upward (the plane mode left Y free: an unlimited sideways force on a slope or into a body climbed)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	local speed = dist / dur * 1.35 -- starts fast, eases out below
	lv.VectorVelocity = dir * speed
	lv.Parent = root
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur and lv.Parent do
			local k = (os.clock() - t0) / dur
			lv.VectorVelocity = dir * speed * (1 - k) * 1.3 + Vector3.new(0, math.min(0, root.AssemblyLinearVelocity.Y), 0)
			task.wait()
		end
		lv:Destroy()
		att:Destroy()
	end)
	Net.FX("Knockback", { model = mob.model, dir = dir, dist = dist, dur = dur, big = big == true }, root.Position, 220)
end

-- drop a monster whose model is already gone (ship crew when their ship sinks): no rewards, no death FX
function MS.Forget(mob)
	mob.dead = true
	mobs[mob.uid] = nil
	byModel[mob.model] = nil
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

-- v0.25.70 Conqueror Toki: monsters far weaker than you (by Power) do not dare to start a fight
local TokiCfg = require(Shared.Config.Toki)
local Formulas = require(Shared.Modules.Formulas)
local function cowedBy(mob, pl)
	local t = pl:GetAttribute("Toki")
	if not t or not string.find(t, "Conqueror", 1, true) or mob.def.isBoss then
		return false
	end
	mob.power = mob.power or Formulas.MonsterPower(mob.def)
	return mob.power < (pl:GetAttribute("Power") or 0) * TokiCfg.Conqueror.Calm
end
-- v0.25.77: dazed for `seconds` (Smoke Pellet): stands still, "DAZED"
function MS.Stun(mob, seconds)
	if mob.dead or not mob.root then
		return
	end
	mob.knockUntil = math.max(mob.knockUntil or 0, os.clock() + seconds)
	if mob.hum then
		mob.hum:MoveTo(mob.root.Position)
	end
	Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 4, 0), text = "DAZED" }, mob.root.Position, 200)
end
-- Conqueror's Roar: frozen in fear for `seconds`, forgets its target
function MS.Cow(mob, seconds)
	if mob.dead or not mob.root then
		return
	end
	mob.knockUntil = os.clock() + seconds
	mob.target = nil
	if mob.hum then
		mob.hum:MoveTo(mob.root.Position)
	end
	Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 4, 0), text = "COWED!" }, mob.root.Position, 200)
end

local function findAggroTarget(mob)
	local best, bestD = nil, mob.def.aggroRadius or (mob.def.isBoss and 45 or 26)
	for _, pl in ipairs(Players:GetPlayers()) do
		local ok, root = validTarget(mob, pl)
		if ok and not cowedBy(mob, pl) then
			local d = (root.Position - mob.root.Position).Magnitude
			if d < bestD then
				best, bestD = pl, d
			end
		end
	end
	return best
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

local function bossCharge(mob, troot)
	-- v0.25.1: a telegraphed charge along a line at the target (alternates with the slam)
	local center = mob.root.Position
	local flat = Vector3.new(troot.Position.X - center.X, 0, troot.Position.Z - center.Z)
	if flat.Magnitude < 1 then
		return false
	end
	local dir = flat.Unit
	local len = math.clamp(flat.Magnitude + 12, 24, 60)
	local width = 8 + (mob.def.style.scale or 1) * 2
	local to = center + dir * len
	knockParams.FilterDescendantsInstances = { mob.model, workspace:FindFirstChild("Monsters") }
	local wall = workspace:Raycast(center, dir * len, knockParams)
	if wall then
		len = math.max(8, wall.Distance - 4)
		to = center + dir * len
	end
	Net.FX("Telegraph", { kind = "line", from = center - Vector3.new(0, 2.5, 0), to = to - Vector3.new(0, 2.5, 0), width = width, time = 1.1 }, center, 300)
	Net.FX("MobAlert", { model = mob.model }, center, 250)
	mob.knockUntil = os.clock() + 1.6 -- hold still while winding up and running
	mob.root.CFrame = CFrame.lookAt(center, center + dir)
	task.delay(1.1, function()
		if mob.dead or not mob.root then
			return
		end
		local from = mob.root.Position
		local dur = 0.4
		Net.FX("BossCharge", { from = from, to = from + dir * len, time = dur }, from, 300)
		local att = Instance.new("Attachment")
		att.Parent = mob.root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = math.huge
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (len / dur)
		lv.Parent = mob.root
		task.delay(dur, function()
			lv:Destroy()
			att:Destroy()
		end)
		for _, pl in ipairs(playersInLine(from, from + dir * len, width)) do
			R.CombatService.MonsterHit(mob, pl, 1.6)
		end
	end)
	return true
end

local function bossSlam(mob, radius, mult)
	local center = mob.root.Position
	Net.FX("Telegraph", { pos = center, radius = radius, time = 1.2, model = mob.model }, center, 300)
	task.delay(1.2, function()
		if mob.dead then
			return
		end
		Net.FX("Slam", { pos = mob.root.Position, radius = radius }, center, 300)
		for _, pl in ipairs(Players:GetPlayers()) do
			local root = R.PlayerService.Root(pl)
			if root and Reach.Gap(root.Position, mob.model) <= radius then
				R.CombatService.MonsterHit(mob, pl, mult)
			end
		end
	end)
end

-- v0.25.148 (owner): Captain Confetti fights like a Split-fruit user. The pieces fly on every client through
-- FruitFX (FX "BossFruit" = FruitFX.Play with the boss model as the caster); hits land here when they arrive.
local function confettiSpecial(mob, troot)
	local center = mob.root.Position
	if mob.specialN % 3 == 1 and troot then
		-- Rocket Forearm: the forearm shoots along a telegraphed line and punches whoever stands in it
		local flat = Vector3.new(troot.Position.X - center.X, 0, troot.Position.Z - center.Z)
		if flat.Magnitude < 1 then
			flat = mob.root.CFrame.LookVector
		end
		local dir = flat.Unit
		local len = math.clamp(flat.Magnitude + 10, 20, 54)
		local to = center + dir * len
		Net.FX("Telegraph", { kind = "line", from = center - Vector3.new(0, 2.5, 0), to = to - Vector3.new(0, 2.5, 0), width = 7, time = 0.9 }, center, 300)
		mob.knockUntil = os.clock() + 1.4 -- stands still while the arm is away
		mob.root.CFrame = CFrame.lookAt(center, center + dir)
		task.delay(0.9, function()
			if mob.dead or not mob.root then
				return
			end
			local travel = 0.35
			Net.FX("BossFruit", { skill = "F_SplitCannon", char = mob.model, from = mob.root.Position, to = to, strike = 0, travel = travel }, center, 300)
			task.delay(travel, function()
				if not mob.dead then
					for _, pl in ipairs(playersInLine(center, to, 7)) do
						R.CombatService.MonsterHit(mob, pl, 1.7)
					end
				end
			end)
		end)
		return
	end
	if mob.specialN % 3 == 2 then
		-- Scatter Storm: the body comes apart and whirls around him, 4 hits on everyone inside the ring
		local radius = 16
		Net.FX("Telegraph", { pos = center, radius = radius, time = 1.0, model = mob.model }, center, 300)
		mob.knockUntil = os.clock() + 3.6
		task.delay(1.0, function()
			if mob.dead or not mob.root then
				return
			end
			Net.FX("BossFruit", { skill = "F_SplitFestival", char = mob.model, from = mob.root.Position, radius = radius, strike = 0 }, center, 300)
			for i = 1, 4 do
				task.delay(0.3 + i * 0.45, function()
					if mob.dead then
						return
					end
					for _, pl in ipairs(Players:GetPlayers()) do
						local root = R.PlayerService.Root(pl)
						if root and Reach.Gap(root.Position, mob.model) <= radius then
							R.CombatService.MonsterHit(mob, pl, 0.6)
						end
					end
				end)
			end
		end)
		return
	end
	if not (troot and bossCharge(mob, troot)) then
		bossSlam(mob, 20 + (mob.def.style.scale or 1) * 3, 1.8)
	end
end

local function bossSpecial(mob)
	local radius = 20 + (mob.def.style.scale or 1) * 3
	mob.specialN = (mob.specialN or 0) + 1
	local ok, troot = validTarget(mob, mob.target)
	if mob.def.id == "CaptainConfetti" and mob.hum then
		confettiSpecial(mob, ok and troot or nil)
		return
	end
	if mob.specialN % 2 == 0 and ok and troot and mob.hum and not mob.chain and not mob.sea then
		if bossCharge(mob, troot) then
			return
		end
	end
	bossSlam(mob, radius, 1.8)
end

-- v0.25.148 mini bosses (Config/Monsters `mini`): one telegraphed special each, weaker than a boss's
local function miniSpecial(mob)
	local ok, troot = validTarget(mob, mob.target)
	local kind = mob.def.mini
	if kind == "charge" and ok and troot and bossCharge(mob, troot) then
		return
	end
	if kind == "summon" then
		-- whistles up to 2 lions from the cages (they never respawn)
		mob.helpers = mob.helpers or {}
		for i = #mob.helpers, 1, -1 do
			if mob.helpers[i].dead then
				table.remove(mob.helpers, i)
			end
		end
		if #mob.helpers < 2 then
			Net.FX("MobAlert", { model = mob.model }, mob.root.Position, 250)
			local a = math.random() * math.pi * 2
			local p = mob.root.Position + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
			local helper = MS.Spawn("CircusLion", groundAt(p.X, p.Z), { noRespawn = true, hpMult = 0.5 })
			if helper then
				helper.target = mob.target
				table.insert(mob.helpers, helper)
			end
			return
		end
	end
	bossSlam(mob, 10 + (mob.def.style.scale or 1) * 3, 1.5)
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
	mob.headHalfY = ext.Y / 2
	mob.model:SetAttribute("NeckOffset", mob.neckOffset)
	mob.model:SetAttribute("BodyRadius", spec.radius)
	mob.chain = SerpentChain.New(spec)
	SerpentChain.Reset(mob.chain, serpentAnchor(mob), -mob.root.CFrame.LookVector)
end

local function serpentBody(mob)
	local anchor = serpentAnchor(mob)
	if mob.bodyY then
		-- at sea the body swims along the water line; only the neck rises when the head rears up (client lifts it)
		anchor = Vector3.new(anchor.X, math.min(anchor.Y, mob.bodyY), anchor.Z)
	end
	SerpentChain.Push(mob.chain, anchor)
	mob.pieces = SerpentChain.Pieces(mob.chain, anchor)
	mob.model:SetAttribute("BodyPts", SerpentChain.Pack(mob.pieces))
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

-- ===== sea serpent (v0.23.0, owner): no arena. It lies under the water at its spawn point and rises when a player
-- comes within wakeRadius (usually sailing past). It swims around its target's ship, rears its neck high before every
-- attack (the client curls the body up after the head), spits a water jet / lunges and bites / slams its tail; hits
-- damage the ship and break planks off it (ShipService.Smash). With nobody near it dives back and heals.
local SEA = GameConfig.SeaLevel

local function seaInit(mob)
	local root, hum = mob.root, mob.hum
	hum.PlatformStand = true
	hum.WalkSpeed = 0
	for _, p in ipairs(mob.model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			if p ~= root then
				p.Massless = true
			end
		end
	end
	root.Anchored = false
	local att = Instance.new("Attachment")
	att.Name = "SeaAttach"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e9
	ap.MaxVelocity = 30
	ap.Responsiveness = 18
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e9
	ao.Responsiveness = 10
	ao.Parent = root
	local half = mob.headHalfY or 10
	mob.bodyY = SEA - 1
	mob.swimY = SEA - 3 + half
	mob.hiddenY = SEA - half * 2 - 10
	mob.model:SetAttribute("BodyY", mob.bodyY)
	mob.model:SetAttribute("SeaState", "hidden")
	mob.sea = { state = "hidden", rear = 0, until_ = 0, angle = math.random() * math.pi * 2, look = -root.CFrame.LookVector }
	ap.Position = Vector3.new(mob.home.X, mob.hiddenY, mob.home.Z)
	ao.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
	root.CFrame = CFrame.new(ap.Position)
	mob.ap, mob.ao = ap, ao
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

local function flatDist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function seaPlayers(mob, radius, from)
	local best, bestD = nil, radius
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = R.PlayerService.Root(pl)
		local h = R.PlayerService.Humanoid(pl)
		if r and h and h.Health > 0 then
			local d = flatDist(r.Position, from)
			if d < bestD then
				best, bestD = pl, d
			end
		end
	end
	return best
end

-- damage the ships a strike crosses, and break planks off them where it lands
local function hitShips(list, mob, mult, smashAt, pieces)
	for _, ship in ipairs(list) do
		R.ShipService.DamageShip(ship, mob.def.atk * 6 * mult, nil, nil)
		R.ShipService.Smash(ship, smashAt and smashAt(ship) or ship.root.Position, pieces)
	end
end

local function seaAttack(mob, troot, now)
	local root, sea = mob.root, mob.sea
	local head = root.Position
	local tpos = troot.Position
	local flat = Vector3.new(tpos.X - head.X, 0, tpos.Z - head.Z)
	local dir = flat.Magnitude > 0.5 and flat.Unit or root.CFrame.LookVector
	sea.look = dir
	mob.attackN = (mob.attackN or 0) + 1
	local wy = SEA + 0.4
	local from = Vector3.new(head.X, wy, head.Z)
	-- rear up first: the head climbs high above the water, the neck curls up behind it
	sea.rear = 22
	local function settle(t)
		task.delay(t, function()
			if not mob.dead then
				sea.rear = 0
				mob.ap.MaxVelocity = mob.def.moveSpeed * 1.6
			end
		end)
	end
	if mob.attackN % 3 == 0 and mob.pieces then
		local tail = mob.pieces[#mob.pieces].pos
		local center = Vector3.new(tail.X, wy, tail.Z)
		local radius = 18
		sea.until_ = now + 1.8
		Net.FX("Telegraph", { kind = "circle", pos = center, radius = radius, sea = true, time = 1.2 }, center, 500)
		Net.FX("SerpentTail", { model = mob.model, time = 1.2 }, center, 500)
		task.delay(1.2, function()
			if mob.dead then
				return
			end
			Net.FX("Slam", { pos = center + Vector3.new(0, 2, 0), radius = radius }, center, 500)
			Net.FX("Splash", { pos = center }, center, 500)
			for _, pl in ipairs(Players:GetPlayers()) do
				local r = R.PlayerService.Root(pl)
				if r and flatDist(r.Position, center) <= radius + 1 and math.abs(r.Position.Y - center.Y) < 18 then
					R.CombatService.MonsterHit(mob, pl, 1.4)
				end
			end
			hitShips(R.ShipService.InCircle(center, radius), mob, 1.2, function()
				return center + Vector3.new(0, 3, 0)
			end, 4)
		end)
		settle(1.6)
	elseif flat.Magnitude <= 40 then
		-- LUNGE: rear, then the head dives along the line onto the ship and bites
		local to = from + dir * math.min(flat.Magnitude + 8, 46)
		sea.until_ = now + 2.1
		Net.FX("Telegraph", { kind = "line", from = from, to = to, width = 11, sea = true, time = 0.9 }, head, 500)
		task.delay(0.65, function()
			if not mob.dead then
				Anim.Play(mob.hum, "Mon_SerpentBite", { fade = 0.05 })
			end
		end)
		task.delay(0.9, function()
			if mob.dead then
				return
			end
			sea.rear = 4
			sea.lunge = to
			mob.ap.MaxVelocity = 110
			Net.FX("SerpentBite", { from = from, to = to }, head, 500)
			task.delay(0.2, function()
				if mob.dead then
					return
				end
				for _, pl in ipairs(playersInLine(from, to, 11)) do
					R.CombatService.MonsterHit(mob, pl, 1.7)
				end
				hitShips(R.ShipService.InLine(from, to, 11), mob, 1.5, function(ship)
					return ship.root.Position:Lerp(from, 0.25) + Vector3.new(0, 3, 0)
				end, 5)
			end)
			task.delay(0.7, function()
				sea.lunge = nil
			end)
		end)
		settle(1.7)
	else
		-- WATER SPIT: rear high and blast a jet along the line
		local to = from + dir * math.min(flat.Magnitude + 10, 70)
		sea.until_ = now + 2.0
		Net.FX("Telegraph", { kind = "line", from = from, to = to, width = 8, sea = true, time = 1.1 }, head, 500)
		task.delay(0.6, function()
			if not mob.dead then
				Anim.Play(mob.hum, "Mon_SerpentSpit", { fade = 0.05 })
			end
		end)
		task.delay(1.1, function()
			if mob.dead then
				return
			end
			local mouth = root.CFrame * Vector3.new(0, 1.5, -(mob.headHalf or 10) + 1)
			Net.FX("SerpentSpit", { from = mouth, to = to + Vector3.new(0, 2, 0) }, head, 500)
			for _, pl in ipairs(playersInLine(from, to, 8)) do
				R.CombatService.MonsterHit(mob, pl, 1.3)
			end
			hitShips(R.ShipService.InLine(from, to, 8), mob, 1.0, function(ship)
				return ship.root.Position:Lerp(from, 0.3) + Vector3.new(0, 3, 0)
			end, 3)
		end)
		settle(1.6)
	end
end

local function seaStep(mob, now)
	local sea, root, def = mob.sea, mob.root, mob.def
	local home = mob.home
	local wake = (mob.zone and mob.zone.radius) or 150
	local pos = root.Position
	local target = Vector3.new(home.X, mob.hiddenY, home.Z)
	if sea.state == "hidden" then
		local pl = seaPlayers(mob, wake, home)
		if pl then
			mob.target = pl
			sea.state = "rising"
			mob.model:SetAttribute("SeaState", "rising") -- client BossIntro
			sea.until_ = now + 1.8
			local up = Vector3.new(home.X, SEA, home.Z)
			Net.FX("SerpentRise", { pos = up }, up, 700)
			Net.FX("MobAlert", { model = mob.model }, up, 700)
		end
	elseif sea.state == "rising" then
		target = Vector3.new(home.X, mob.swimY + 8, home.Z)
		mob.ap.MaxVelocity = 26
		if now >= sea.until_ then
			sea.state = "fight"
			mob.model:SetAttribute("SeaState", "fight") -- client BossIntro
			mob.ap.MaxVelocity = def.moveSpeed * 1.6
		end
	elseif sea.state == "fight" then
		local ok = mob.target and mob.target.Parent and R.PlayerService.Root(mob.target)
		local troot = ok and R.PlayerService.Root(mob.target)
		if not troot or flatDist(troot.Position, home) > wake + 140 or (R.PlayerService.Humanoid(mob.target) and R.PlayerService.Humanoid(mob.target).Health <= 0) then
			mob.target = seaPlayers(mob, wake + 60, home)
			troot = mob.target and R.PlayerService.Root(mob.target)
		end
		if not troot then
			sea.state = "diving"
			mob.model:SetAttribute("SeaState", "diving") -- client BossIntro
			sea.until_ = now + 3
			sea.rear = 0
		else
			if sea.lunge then
				target = Vector3.new(sea.lunge.X, mob.swimY + sea.rear, sea.lunge.Z)
			else
				-- circle the target at a standoff distance, then attack
				sea.angle += 0.06
				local standoff = 30
				local desired = troot.Position + Vector3.new(math.cos(sea.angle), 0, math.sin(sea.angle)) * standoff
				if now < sea.until_ then
					desired = pos -- hold still while winding up
				end
				target = Vector3.new(desired.X, mob.swimY + sea.rear, desired.Z)
				local move = Vector3.new(desired.X - pos.X, 0, desired.Z - pos.Z)
				if now >= sea.until_ and move.Magnitude > 2 then
					sea.look = move.Unit
				else
					local t = Vector3.new(troot.Position.X - pos.X, 0, troot.Position.Z - pos.Z)
					if t.Magnitude > 1 then
						sea.look = t.Unit
					end
				end
				if now >= sea.until_ and now - mob.lastAttack >= def.attackSpeed then
					mob.lastAttack = now
					seaAttack(mob, troot, now)
				end
			end
		end
	elseif sea.state == "diving" then
		target = Vector3.new(pos.X, mob.hiddenY, pos.Z)
		if now >= sea.until_ then
			sea.state = "hidden"
			mob.model:SetAttribute("SeaState", "hidden") -- client BossIntro
			mob.hp = mob.maxHp
			mob.damageBy = {}
			mob.target = nil
			updateBar(mob)
			root.CFrame = CFrame.new(home.X, mob.hiddenY, home.Z)
		end
	end
	mob.ap.Position = target
	mob.ao.CFrame = CFrame.lookAt(Vector3.zero, sea.look or Vector3.new(1, 0, 0))
	-- no name plate floating over empty water while it lies hidden
	local bb = root:FindFirstChildWhichIsA("BillboardGui")
	if bb then
		bb.Enabled = sea.state ~= "hidden"
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
	if mob.knockUntil and now < mob.knockUntil then
		return -- skidding back from a knockback (MS.Knockback)
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
			mob.walkTrack:AdjustSpeed(math.clamp(speed / (mob.walkRate or 8), 0.6, 2))
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
		if mob.opts.seaBoss then
			seaInit(mob)
		end
	end
	if mob.sea then
		seaStep(mob, now)
		serpentBody(mob)
		return
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
				local clip = mob.attackClip or "Mon_Attack"
				if mob.walkTrack then
					Anim.Play(mob.hum, clip, { fade = 0.05 })
				end
				local target = mob.target
				-- the hit lands on the attack clip's strike frame
				task.delay(def.attackRange > 15 and 0.3 or Anim.Strike(clip), function()
					if not mob.dead and target then
						R.CombatService.MonsterHit(mob, target, 1)
					end
				end)
			end
		end
		if def.isBoss and now >= mob.nextSpecial then
			mob.nextSpecial = now + 9
			bossSpecial(mob)
		elseif def.mini and now >= mob.nextSpecial then
			mob.nextSpecial = now + 11
			miniSpecial(mob)
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
	-- v0.25.143: dress each monster area first (clearing, border, lair) so it reads from the map
	local ok, err = pcall(require(script.Parent.Parent.World.MobZones).Build)
	if not ok then
		warn("[MobZones]", err)
	end
	for _, island in ipairs(Islands.List) do
		for _, sp in ipairs(island.spawns) do
			local cx, cz = island.x + sp.offset.X, (island.z or 0) + sp.offset.Y
			local center = groundAt(cx, cz)
			local zone = { center = center, radius = sp.radius }
			for _ = 1, sp.count do
				local a = math.random() * math.pi * 2
				local r = math.random() * sp.radius
				MS.Spawn(sp.monster, groundAt(cx + math.cos(a) * r, cz + math.sin(a) * r), { zone = zone })
			end
		end
		for _, sp in ipairs(island.minis or {}) do -- v0.25.148: one elite each, respawns from def.respawn
			local center = groundAt(island.x + sp.offset.X, (island.z or 0) + sp.offset.Y)
			MS.Spawn(sp.monster, center, { zone = { center = center, radius = sp.radius } })
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
