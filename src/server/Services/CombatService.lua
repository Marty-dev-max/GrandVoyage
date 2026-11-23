-- CombatService: basic attacks, skills, buffs, regen and player damage (server-authoritative)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ClassesCfg = require(Shared.Config.Classes)
local MonsterTypes = require(Shared.Config.MonsterTypes)
local Reach = require(ReplicatedStorage.Shared.Modules.Reach)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)
local GameConfig = require(Shared.Config.GameConfig)

local Combat = {}
local R
-- v0.25.37: the player's class type (Config/Classes mtype) for the type matchups
local function classType(player)
	local p = R and R.DataService.Get(player)
	local c = p and ClassesCfg.Classes[p.class]
	return c and c.mtype
end
local buffs = {} -- player -> { {id, stats, expires} }
local lastAttack = {}
local skillCd = {} -- player -> { skillId -> time }
local lastHurt = {}

local AnimClips = require(Shared.Config.AnimClips)
local AmmoCfg = require(Shared.Config.Ammo)
-- ranged basic attacks: the shot flies this long after the release frame (matches VFX.Projectile durations)
local CHARGE_BONUS = 0.6 -- full charge = x1.6 damage (client Combat CHARGE_TIME = 1.2 s)
local SHOT_FLIGHT = { Slingshot = 0.18, MedKit = 0.2 }
-- v0.25.77 melee cleave: share of the hit the others in the arc take (heavy weapons sweep harder), and how many
local CLEAVE = { Fists = 0.6, Knuckles = 0.6, Shoes = 0.7, Sword = 0.75, Hammer = 0.85, StormBaton = 0.7 }
local CLEAVE_MAX = 4 -- (v0.25.51: the Navigator's baton is melee now)
local combos = {} -- player -> { n, last }
local WeaponInfo = require(Shared.Modules.WeaponInfo)
local WeaponRange = WeaponInfo.Range

function Combat.Init(registry)
	R = registry
end

function Combat.GetBuffs(player)
	local total = {}
	local list = buffs[player]
	if list then
		local now = os.clock()
		for _, b in ipairs(list) do
			if b.expires > now then
				for k, v in pairs(b.stats) do
					total[k] = (total[k] or 0) + v
				end
			end
		end
	end
	return total
end

function Combat.ClearBuffs(player)
	buffs[player] = nil
	player:SetAttribute("Buffs", "")
	player:SetAttribute("PumpUntil", nil)
end

-- v0.25.69 Bounce Pump Up (owner): while pumped every Bounce move is faster (skill `pumped` table overrides its fields)
local PUMP_SPEED = 1.6 -- clips play this much faster, strikes land that much sooner
local PUMP_CD = 0.6 -- cooldowns x0.6
function Combat.Pumped(player)
	return Combat.HasBuff(player, "F_GearUp")
end

local function syncBuffAttr(player)
	local ids = {}
	for _, b in ipairs(buffs[player] or {}) do
		table.insert(ids, b.id)
	end
	player:SetAttribute("Buffs", table.concat(ids, ","))
end

function Combat.AddBuff(player, id, stats, duration)
	buffs[player] = buffs[player] or {}
	local list = buffs[player]
	for i = #list, 1, -1 do
		if list[i].id == id then
			table.remove(list, i)
		end
	end
	table.insert(list, { id = id, stats = stats, expires = os.clock() + duration })
	syncBuffAttr(player)
	R.PlayerService.Recompute(player)
end

-- true while the buff `id` is running on the player (Balloon Body bounces blows back, v0.25.66)
function Combat.HasBuff(player, id)
	local now = os.clock()
	for _, b in ipairs(buffs[player] or {}) do
		if b.id == id and b.expires > now then
			return true
		end
	end
	return false
end

local function weaponType(player)
	-- equipped weapon, else the class's own style (Modules/WeaponInfo, shared with the client)
	return WeaponInfo.TypeOf(R.DataService.Get(player))
end

local function alive(player)
	local hum = R.PlayerService.Humanoid(player)
	return hum and hum.Health > 0 and not R.KnockdownService.IsDowned(player)
end

-- ===== Damage to players =====
function Combat.DamagePlayer(player, amount, info)
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if not hum or hum.Health <= 0 or not root then
		return
	end
	if player:GetAttribute("Invulnerable") or R.KnockdownService.IsDowned(player) then
		return
	end
	-- v0.25.14: a lethal monster hit knocks you DOWN (KnockdownService); PvP (info.killer) still kills
	if hum.Health - amount <= 0 and not (info and info.killer) and GameConfig.Knockdown.Enabled then
		Net.FX("Damage", { pos = root.Position + Vector3.new(0, 3, 0), amount = amount, crit = info and info.crit, toPlayer = true, char = player.Character }, root.Position, 200)
		R.KnockdownService.Down(player)
		return
	end
	hum.Health = math.max(0, hum.Health - amount)
	lastHurt[player] = os.clock()
	Net.FX("Damage", { pos = root.Position + Vector3.new(0, 3, 0), amount = amount, crit = info and info.crit, toPlayer = true, char = player.Character }, root.Position, 200)
	if hum.Health <= 0 and info and info.killer then
		R.PvPService.OnPlayerKilled(player, info.killer)
	end
end

-- Monster hits player
-- v0.25.65 fruit passives (docs/Plan-Fruits-v2.md): how a monster's blows land. Gunners shoot, blades/claws/axes
-- cut, everything else is blunt. Bosses / elites with Tōki (def.toki) or Seastone weapons ignore Logia bodies.
local MonsterLooks = require(Shared.Config.MonsterLooks)
local HELD_DMG = { HeldRifle = "shot", HeldPistol = "shot", HeldCutlass = "slash", HeldClaws = "slash", HeldBattleAxe = "slash", HeldTrident = "slash" }
local function monsterDmgType(def)
	if def.dmgType then
		return def.dmgType
	end
	local look = MonsterLooks.ById[def.id]
	return look and HELD_DMG[look.held or ""] or "blunt"
end
Combat.MonsterDmgType = monsterDmgType
local LOGIA = { Blaze = true, Haze = true }
local smokeZones = {} -- v0.25.76 Smoke Screen clouds { pos, r, untilT }
local channels = {} -- v0.25.79 held barriers: player -> { skill, t0, shape, radius, mult, magic }

-- a monster blow that a held barrier stops: the Wall covers its holder's front, the Dome everyone inside it from
-- monsters outside it
local function barrierBlocks(mob, victim)
	if not mob.root then
		return false
	end
	for holder, ch in pairs(channels) do
		local hr = R.PlayerService.Root(holder)
		if hr then
			if ch.shape == "Wall" and holder == victim then
				local to = (mob.root.Position - hr.Position) * Vector3.new(1, 0, 1)
				local look = hr.CFrame.LookVector * Vector3.new(1, 0, 1)
				if to.Magnitude > 0.1 and look.Magnitude > 0.1 and to.Unit:Dot(look.Unit) > 0.2 then
					return true, hr.Position + look.Unit * 3
				end
			elseif ch.shape == "Dome" then
				local vr = R.PlayerService.Root(victim)
				if vr and (vr.Position - hr.Position).Magnitude <= ch.radius and (mob.root.Position - hr.Position).Magnitude > ch.radius - 1 then
					return true, vr.Position
				end
			end
		end
	end
	return false
end

-- true = the blow was absorbed by the victim's fruit body (Logia passes through, rubber bounces bullets back,
-- a split body lets blades through)
local function fruitBody(mob, player, mult)
	local fruit = player:GetAttribute("Fruit")
	if not fruit or (player:GetAttribute("SeastoneUntil") or 0) > os.clock() then
		return false
	end
	local root = R.PlayerService.Root(player)
	local at = root and root.Position + Vector3.new(0, 3, 0)
	local kind = monsterDmgType(mob.def)
	if LOGIA[fruit] and not mob.def.toki then
		if at then
			Net.FX("Miss", { pos = at, text = fruit == "Blaze" and "FLAME BODY" or "SMOKE BODY" }, at, 200)
		end
		return true
	elseif fruit == "Split" and kind == "slash" then
		if at then
			Net.FX("Miss", { pos = at, text = "SPLIT!" }, at, 200)
		end
		return true
	elseif fruit == "Bounce" and (kind == "shot" or (kind == "blunt" and not mob.def.isBoss and Combat.HasBuff(player, "F_BalloonBody"))) then
		-- the bullet bounces off the rubber and flies back at the shooter; puffed up (Balloon Body, v0.25.66) blunt
		-- blows from any side bounce back too (bosses hit too hard to bounce)
		local back = math.max(1, math.floor(mob.def.atk * (mult or 1)))
		if at then
			Net.FX("Miss", { pos = at, text = "BOING!" }, at, 200)
			if kind == "shot" then
				Net.FX("Cannonball", { from = at, to = mob.root.Position, t = 0.18 }, at, 300)
			else
				Net.FX("Skill", { skill = "F_BalloonBounce", from = at, to = mob.root.Position, char = player.Character }, at, 200)
			end
		end
		task.delay(0.18, function()
			if not mob.dead then
				R.MonsterService.Damage(mob, back, player, false, "fruit")
			end
		end)
		return true
	end
	return false
end

function Combat.MonsterHit(mob, player, mult)
	if R.KnockdownService.IsDowned(player) then
		R.KnockdownService.TryExecute(mob, player)
		return
	end
	local d = R.PlayerService.Derived(player)
	if not d then
		return
	end
	if fruitBody(mob, player, mult) then
		return
	end
	do
		local blocked, at = barrierBlocks(mob, player)
		if blocked then
			Net.FX("Miss", { pos = at + Vector3.new(0, 3, 0), text = "BLOCKED" }, at, 200)
			Net.FX("Skill", { skill = "F_BarrierBlock", from = at, to = mob.root.Position }, at, 200)
			return
		end
	end
	-- v0.25.76 Smoke Screen: a monster blinded by the cloud swings at nothing half the time
	if mob.root and #smokeZones > 0 then
		local now = os.clock()
		for i = #smokeZones, 1, -1 do
			local z = smokeZones[i]
			if now > z.untilT then
				table.remove(smokeZones, i)
			elseif (mob.root.Position - z.pos).Magnitude <= z.r and math.random() < 0.5 then
				local root = R.PlayerService.Root(player)
				if root then
					Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "LOST IN SMOKE" }, root.Position, 150)
				end
				return
			end
		end
	end
	local hit = (mob.def.level * 1.8 + 25) * (1 + (mob.def.hitBonus or 0)) -- AGI monsters aim better (Config/Monsters types)
	if math.random() > Formulas.HitChance(hit, d.flee) then
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0) }, root.Position, 150)
		end
		return
	end
	local crit = mob.def.critChance and math.random() < mob.def.critChance
	local typeK = MonsterTypes.Mult(mob.def.mtype, classType(player))
	local dmg = Formulas.Damage(mob.def.atk, d.def, (mult or 1) * typeK * (crit and 1.5 or 1), mob.def.isBoss and 5 or 1)
	Combat.DamagePlayer(player, dmg, crit and { crit = true } or nil)
	-- INT monsters can stun (the client freezes movement for a moment)
	if mob.def.stunChance and math.random() < mob.def.stunChance and not R.KnockdownService.IsDowned(player) then
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "STUNNED!" }, root.Position, 200)
		end
		Net.Push(player, "Stun", { seconds = 1 })
	end
	-- v0.25.17 (owner): boss blows and special attacks shove you away from the attacker (on the ground or in the air)
	local proot = R.PlayerService.Root(player)
	if proot and mob.root and (mob.def.isBoss or (mult or 1) >= 1.3) and not R.KnockdownService.IsDowned(player) then
		local away = (proot.Position - mob.root.Position) * Vector3.new(1, 0, 1)
		Net.Push(player, "Knock", { dir = away.Magnitude > 0.1 and away.Unit or proot.CFrame.LookVector * -1, power = mob.def.isBoss and 55 or 32 })
	end
end

-- ===== target helpers =====
-- Returns { kind="mob", mob=... } or { kind="player", player=... }
local function resolveTarget(attacker, inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	local mob = R.MonsterService.FromInstance(inst)
	if mob and not mob.dead then
		return { kind = "mob", mob = mob, pos = mob.root.Position, model = mob.model }
	end
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	local pl = model and Players:GetPlayerFromCharacter(model)
	if pl and pl ~= attacker and alive(pl) and R.PvPService.CanFight(attacker, pl) then
		return { kind = "player", player = pl, pos = R.PlayerService.Root(pl).Position, model = pl.Character }
	end
	-- v0.25.42 (owner): NPC hulls can be beaten apart by hand too, not only with cannons
	local ship = R.ShipService.NpcShipOf(inst)
	if ship then
		return { kind = "ship", ship = ship, pos = inst:IsA("BasePart") and inst.Position or ship.root.Position, model = ship.model }
	end
	return nil
end

-- damage over time: `ticks` hits of `perTick`, 0.6 s apart (burn / poison); a fresh one replaces the old of the same kind
local dots = setmetatable({}, { __mode = "k" }) -- mob -> { [kind] = token }
local function applyDot(attacker, mob, kind, perTick, ticks)
	dots[mob] = dots[mob] or {}
	local token = (dots[mob][kind] or 0) + 1
	dots[mob][kind] = token
	-- v0.25.80 (owner): you SEE it burn / sicken (flames or green fumes on the body for the whole dot)
	if mob.model and mob.root then
		Net.FX("Burning", { model = mob.model, kind = kind, seconds = ticks * 0.6 + 0.2 }, mob.root.Position, 250)
	end
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.6)
			if mob.dead or dots[mob][kind] ~= token then
				return
			end
			R.MonsterService.Damage(mob, math.max(1, perTick), attacker.Parent and attacker or nil, false, kind)
		end
	end)
end

-- the element a fruit's skills hit with (colors the numbers; Blaze also burns)
local FRUIT_ELEMENT = { Blaze = "fire", Haze = "smoke", Ward = "barrier", Split = "slash", Slick = "slick", Bounce = "rubber" }

-- opts: critBonus, ignoreDef, slow, splash (ammo), element (number color), dot = { kind, pct, ticks }
local SHIP_HIT = 0.6
local function hitTarget(attacker, target, mult, magic, opts)
	local d = R.PlayerService.Derived(attacker)
	if not d then
		return
	end
	opts = opts or {}
	local crit = (d.crit or 0) + (opts.critBonus or 0)
	local atk = magic and d.matk or d.atk
	if target.kind == "ship" then
		-- hulls shrug off most of a blow (they have ship HP); crits still count
		local dmg = atk * mult * SHIP_HIT * (math.random() * 100 < crit and 1.5 or 1)
		R.ShipService.DamageShip(target.ship, math.max(1, math.floor(dmg)), nil, attacker)
		return
	end
	if target.kind == "mob" then
		local mob = target.mob
		local flee = mob.def.level * 1.3 + 10
		if not magic and math.random() > Formulas.HitChance(d.hit, flee) then
			Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 3, 0) }, mob.root.Position, 200)
			-- a swing that misses still starts the fight (owner, v0.22.3)
			R.MonsterService.Provoke(mob, attacker)
			return
		end
		local bonus = 1
		if mob.def.isBoss then
			bonus += d.dmgVsBoss
		end
		if mob.def.style and mob.def.style.shape == "fishman" then
			bonus += d.dmgVsSeafolk
		end
		bonus *= MonsterTypes.Mult(classType(attacker), mob.def.mtype)
		local mdef = opts.ignoreDef and 0 or (magic and mob.def.def * 0.5 or mob.def.def)
		local dmg, isCrit = Formulas.Damage(atk, mdef, mult * bonus, magic and 0 or crit)
		if opts.split and not mob.def.isBoss then
			local ar = R.PlayerService.Root(attacker)
			mob.splitKill = opts.split
			mob.splitDir = ar and (mob.root.Position - ar.Position) * Vector3.new(1, 0, 1) or nil
		else
			mob.splitKill = nil
		end
		R.MonsterService.Damage(mob, dmg, attacker, isCrit, opts.element)
		R.PetService.OnOwnerHit(attacker, mob)
		-- knockback on the hits that should feel heavy (combo finisher, Heavy Attack, strong skills; crits a little)
		local knock = opts.knock or (isCrit and 2.5 or nil)
		if knock and not mob.dead then
			local aroot = R.PlayerService.Root(attacker)
			if aroot then
				R.MonsterService.Knockback(mob, opts.knockFrom or aroot.Position, knock, opts.knockPower or (isCrit and 1 or 1))
			end
		end
		if opts.dot and not mob.dead then
			applyDot(attacker, mob, opts.dot[1], math.floor(dmg * opts.dot[2]), opts.dot[3])
		end
		if opts.stun and not mob.dead and not mob.def.isBoss then
			-- v0.25.77 dazed (Smoke Pellet): frozen in place for opts.stun seconds
			R.MonsterService.Stun(mob, opts.stun)
		end
		if opts.slow and mob.hum and not mob.dead then
			-- frost: slowed for 2 s (restored from the monster's own speed, so stacking cannot freeze it)
			mob.hum.WalkSpeed = mob.def.moveSpeed * opts.slow
			mob.slowUntil = os.clock() + 2
			task.delay(2.05, function()
				if mob.hum and not mob.dead and os.clock() >= (mob.slowUntil or 0) then
					mob.hum.WalkSpeed = mob.def.moveSpeed
				end
			end)
		end
		if opts.splash then
			-- blast: everyone else nearby takes half (no chain explosions)
			for _, other in ipairs(R.MonsterService.InRadius(mob.root.Position, opts.splash)) do
				if other ~= mob and not other.dead then
					hitTarget(attacker, { kind = "mob", mob = other, pos = other.root.Position, model = other.model }, mult * 0.5, magic, { critBonus = opts.critBonus, element = "fire" })
				end
			end
		end
	elseif target.kind == "player" then
		local td = R.PlayerService.Derived(target.player)
		if not td then
			return
		end
		R.FruitService.TrySeastone(attacker, target.player)
		if not magic and math.random() > Formulas.HitChance(d.hit, td.flee) then
			Net.FX("Miss", { pos = target.pos + Vector3.new(0, 3, 0) }, target.pos, 200)
			return
		end
		-- PvP damage is reduced by 40% so fights last longer
		local pdef = opts.ignoreDef and 0 or (magic and td.mdef or td.def)
		local dmg, isCrit = Formulas.Damage(atk, pdef, mult * 0.6, magic and 0 or crit)
		Combat.DamagePlayer(target.player, dmg, { crit = isCrit, killer = attacker })
	end
end

-- a hit that lands on the attack animation's strike frame (damage used to land before the fist/blade got there)
local function hitLater(delay, attacker, target, mult, magic, opts)
	task.delay(delay, function()
		if not attacker.Parent or not alive(attacker) then
			return
		end
		if target.kind == "mob" and target.mob.dead then
			return
		end
		if target.kind == "ship" and target.ship.sinking then
			return
		end
		if target.kind == "player" and not alive(target.player) then
			return
		end
		hitTarget(attacker, target, mult, magic, opts)
	end)
end

-- the wait before the next basic attack: quick inside a 4-hit string, end-lag after the finisher (GameConfig.M1)
-- v0.25.75: each weapon's own tempo (WeaponInfo.M1: quick / finish / reset), same numbers as the client
local function m1Gap(player, d)
	local c = combos[player]
	local m = WeaponInfo.M1Of(weaponType(player))
	if not c or os.clock() - c.last >= m.reset then
		return d.attackInterval * m.quick
	end
	return d.attackInterval * (c.n >= GameConfig.M1.Hits and m.finish or m.quick)
end

-- which combo hit this basic attack is (the clients play the same clip: it is sent in the FX), and how fast to play
-- it: a swing longer than the attack interval is sped up to fit, so fast attackers never queue swings that lag behind
local function comboStep(player, wType)
	local w = AnimClips.Weapons[wType] or AnimClips.Weapons.Fists
	local m = WeaponInfo.M1Of(wType)
	local c = combos[player] or { n = 0, last = 0 }
	combos[player] = c
	local now = os.clock()
	c.n = (now - c.last < m.reset) and (c.n % #w.combo) + 1 or 1
	c.last = now
	local clip = AnimClips[w.combo[c.n]]
	local d = R.PlayerService.Derived(player)
	local length = clip and clip.keys[#clip.keys].t or 0.3
	local speed = math.clamp(length / math.max(0.15, (d and d.attackInterval or 0.6) * m.quick * 0.9), 1, 2.5)
	return c.n, (clip and clip.strike or 0.12) / speed, speed
end

-- the clip a skill plays (same choice as the client's CharAnim) and its strike time
local function skillStrike(player, skill)
	local w = AnimClips.Weapons[weaponType(player)] or {}
	local name = skill.anim or (skill.heavy and AnimClips.HeavyFor(weaponType(player))) or w[skill.kind] or AnimClips.SkillKinds[skill.kind] or "Skill_Cast"
	local clip = AnimClips[name]
	return clip and clip.strike or 0.15
end

local function inRadiusTargets(attacker, pos, radius)
	local list = {}
	for _, mob in ipairs(R.MonsterService.InRadius(pos, radius)) do
		table.insert(list, { kind = "mob", mob = mob, pos = mob.root.Position })
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= attacker and alive(pl) then
			local root = R.PlayerService.Root(pl)
			if root and (root.Position - pos).Magnitude <= radius and R.PvPService.CanFight(attacker, pl) then
				table.insert(list, { kind = "player", player = pl, pos = root.Position })
			end
		end
	end
	return list
end

function Combat.HealPlayer(player, amount)
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
		if root then
			Net.FX("Heal", { pos = root.Position + Vector3.new(0, 3, 0), amount = math.floor(amount) }, root.Position, 200)
		end
	end
end

local function partyInRadius(player, radius)
	local root = R.PlayerService.Root(player)
	local list = { player }
	if not root then
		return list
	end
	for _, m in ipairs(R.PartyService.Members(player)) do
		if m ~= player and alive(m) then
			local r2 = R.PlayerService.Root(m)
			if r2 and (r2.Position - root.Position).Magnitude <= radius then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- ===== handlers =====
-- v0.25.81: every character gets one starter pouch of Musket Balls (the first time they shoot or load in as a
-- Sharpshooter)
function Combat.MusketStarter(player)
	local p = R.DataService.Get(player)
	if not p or p.musketStarter then
		return
	end
	if R.InventoryService.AddItem(player, AmmoCfg.ById[AmmoCfg.Default].item, AmmoCfg.Starter) then
		p.musketStarter = true
		R.PlayerService.MarkDirty(player)
		R.PlayerService.Notify(player, "Starter pouch: " .. AmmoCfg.Starter .. " Musket Balls", "good")
	end
end

local function setup()
	R.DataService.Loaded:Connect(function(pl)
		task.delay(4, function()
			if pl.Parent and AmmoCfg.Weapons[weaponType(pl)] then
				Combat.MusketStarter(pl) -- a Sharpshooter sees the pouch right away
			end
		end)
	end)
	Net.Handle("Attack", function(player, data)
		if not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		local d = R.PlayerService.Derived(player)
		local now = os.clock()
		local gap = m1Gap(player, d)
		local since = lastAttack[player] and now - lastAttack[player] or math.huge
		if since < gap * 0.9 then
			return false
		end
		local target = resolveTarget(player, data.target)
		if not target then
			return false
		end
		local root = R.PlayerService.Root(player)
		local wType = weaponType(player)
		local range = WeaponRange[wType] or 10
		if Reach.Gap(root.Position, target.model) > range + 4.5 then
			return false, "Too far away"
		end
		lastAttack[player] = now
		-- v0.25.52 (owner): the Navigator stays an INT class: its melee baton hits with MATK (no lightning ball since v0.25.51)
		local magic = wType == "StormBaton"
		R.WeaponService.Draw(player, wType)
		local n, strike, speed = comboStep(player, wType)
		-- v0.25.81 (owner): the musket fires Musket Balls, 1 per shot; none left = no shot
		local ammo, mult = nil, 1
		if AmmoCfg.Weapons[wType] then
			ammo = AmmoCfg.ById[AmmoCfg.Default]
			Combat.MusketStarter(player)
			if not R.InventoryService.RemoveItem(player, ammo.item, 1) then
				lastAttack[player] = nil
				R.PlayerService.Notify(player, "Out of Musket Balls: buy more at the General Store", "bad")
				return false, "Out of Musket Balls"
			end
			mult = ammo.mult
		end
		-- v0.25.75 rhythm: the weapon's damage shape for hit n, PERFECT timing (+20%, the client saw the click land on the
		-- beat; the server checks it came right after the gap), FLAWLESS finisher after three perfect hits
		local rh = WeaponInfo.Rhythm
		mult *= WeaponInfo.M1Mult(wType, n)
		local c = combos[player]
		local perfect = data.perfect == true and n > 1 and since <= gap + rh.Window + 0.35
		if n == 1 then
			c.perfects = 0
		elseif perfect then
			c.perfects = (c.perfects or 0) + 1
		end
		local flawless = perfect and n == 4 and c.perfects == 3
		if perfect then
			mult *= rh.Perfect * (flawless and rh.Flawless or 1)
		end
		Net.FX("BasicAttack", { from = root.Position, to = target.pos, weapon = wType, char = player.Character, combo = n, speed = speed, ammo = ammo and ammo.id, perfect = perfect or nil, flawless = flawless or nil, target = perfect and target.model or nil }, root.Position, 250)
		local hopts = ammo and { critBonus = ammo.critBonus, ignoreDef = ammo.ignoreDef, slow = ammo.slow, splash = ammo.splash, element = ammo.element, dot = ammo.dot } or {}
		if wType == "MedKit" then
			-- the Doctor's stinging powder: a little poison on every throw
			hopts.element, hopts.dot = "poison", { "poison", 0.15, 3 }
		end
		-- the last hit of the combo shoves the monster back (v0.24.12, owner)
		local comboLen = #((AnimClips.Weapons[wType] or AnimClips.Weapons.Fists).combo)
		if n == comboLen and comboLen > 1 then
			hopts.knock, hopts.knockPower = 5, 1
			if flawless then
				hopts.knock, hopts.knockPower = 9, 2.4
			end
		end
		hitLater(strike + (SHOT_FLIGHT[wType] or 0), player, target, mult, magic, hopts)
		-- v0.25.77 (owner: one hit at a time felt odd in a crowd): melee swings CLEAVE: every other enemy inside the
		-- weapon's reach in front of you (a wide arc) takes CLEAVE of the hit, up to CLEAVE_MAX of them
		local cleave = CLEAVE[wType]
		if cleave then
			local face = (target.pos - root.Position) * Vector3.new(1, 0, 1)
			face = face.Magnitude > 0.1 and face.Unit or root.CFrame.LookVector
			local extra = 0
			for _, tt in ipairs(inRadiusTargets(player, root.Position, range + 3)) do
				local key = tt.mob or tt.player
				if key ~= (target.mob or target.player) and extra < CLEAVE_MAX then
					local to = (tt.pos - root.Position) * Vector3.new(1, 0, 1)
					local model = tt.mob and tt.mob.model or (tt.player and tt.player.Character)
					if to.Magnitude < 2 or (to.Unit:Dot(face) > 0.3 and model and Reach.Gap(root.Position, model) <= range + 2) then
						extra += 1
						hitLater(strike, player, tt, mult * cleave, magic, hopts)
					end
				end
			end
		end
		return true
	end, 0.2)

	-- Manual mode swing at the air (owner, v0.22.8: a click always punches, even with nothing in reach): the same
	-- attack clip for everyone to see, no target, no damage, no ammo; shares the attack-speed limit with Attack
	Net.Handle("Swing", function(player, data)
		if not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		local d = R.PlayerService.Derived(player)
		local now = os.clock()
		if lastAttack[player] and now - lastAttack[player] < m1Gap(player, d) * 0.9 then
			return false
		end
		local root = R.PlayerService.Root(player)
		local dir = typeof(data.dir) == "Vector3" and Vector3.new(data.dir.X, 0, data.dir.Z) or Vector3.zero
		dir = dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
		lastAttack[player] = now
		local wType = weaponType(player)
		R.WeaponService.Draw(player, wType)
		local n, _, speed = comboStep(player, wType)
		Net.FX("BasicAttack", { from = root.Position, to = root.Position + dir * (WeaponRange[wType] or 8), weapon = wType, char = player.Character, combo = n, speed = speed, miss = true }, root.Position, 250)
		return true
	end, 0.15)

	-- Dash: the client moves itself; we keep the cooldown honest and broadcast the streak for everyone else
	local lastDash = {}
	Net.Handle("Dash", function(player, data)
		local now = os.clock()
		if lastDash[player] and now - lastDash[player] < GameConfig.Dash.Cooldown * 0.9 then
			return false
		end
		local root = R.PlayerService.Root(player)
		if not root or not alive(player) or typeof(data.dir) ~= "Vector3" then
			return false
		end
		lastDash[player] = now
		local dir = Vector3.new(data.dir.X, 0, data.dir.Z)
		dir = dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
		Net.FX("Dash", { from = root.Position, to = root.Position + dir * GameConfig.Dash.Speed * GameConfig.Dash.Duration, char = player.Character }, root.Position, 250)
		return true
	end, 0.3)

	-- Slingshot Launch (Bounce passive, v0.25.66): the client aims, grabs a spot with both arms and flings itself there
	-- (it owns its character's physics); we check the fruit, the range and the cooldown and show the arms to everyone
	local FruitsCfg = require(Shared.Config.Fruits)
	local slings = {} -- player -> { to, at, last }
	Net.Handle("Sling", function(player, data)
		local cfg = FruitsCfg.Slingshot
		local st = slings[player] or { last = 0 }
		slings[player] = st
		local root = R.PlayerService.Root(player)
		if type(data) ~= "table" or not root or not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		if player:GetAttribute("Fruit") ~= "Bounce" then
			return false, "Only a rubber body can do that"
		end
		if (player:GetAttribute("SeastoneUntil") or 0) > os.clock() then
			return false, "Seastone! Your fruit powers are sealed"
		end
		local now = os.clock()
		if data.phase == "grab" then
			local to = data.to
			if typeof(to) ~= "Vector3" or to.Magnitude ~= to.Magnitude or to.Magnitude > 1e6 then
				return false
			end
			local dist = (to - root.Position).Magnitude
			if dist > cfg.Range + 8 or dist < cfg.MinDist * 0.5 then
				return false, "Too far"
			end
			if now - st.last < cfg.Cooldown * (Combat.Pumped(player) and cfg.PumpCooldownMult or 1) * 0.85 then
				return false, "Arms still stretched"
			end
			st.to, st.at = to, now
			Net.FX("Sling", { char = player.Character, to = to, phase = "grab" }, root.Position, 350)
			return true
		elseif data.phase == "go" then
			if not st.to or now - (st.at or 0) > cfg.GrabSeconds + 1.5 then
				return false
			end
			st.last = now
			local pumped = Combat.Pumped(player)
			Net.FX("Sling", { char = player.Character, to = st.to, phase = "go", pumped = pumped }, root.Position, 350)
			if pumped then
				-- v0.25.69 (owner): pumped, you rocket straight along the arms and ram whatever is in the way
				local from, to = root.Position, st.to + Vector3.new(0, cfg.PumpLift, 0)
				local path = to - from
				local d = R.PlayerService.Derived(player)
				local magic = d and d.matk > d.atk
				local seen = {}
				for step = 0, path.Magnitude + 6, 4 do
					local at = from + path.Unit * math.min(step, path.Magnitude)
					for _, tt in ipairs(inRadiusTargets(player, at, 6)) do
						local key = tt.mob or tt.player
						if key and not seen[key] then
							seen[key] = true
							hitLater(step / cfg.PumpSpeed, player, tt, cfg.PumpMult, magic, { element = "rubber", knock = 8, knockPower = 2.4, knockFrom = from })
						end
					end
				end
			end
			st.to = nil
			return true
		elseif data.phase == "cancel" then
			st.to = nil
			Net.FX("Sling", { char = player.Character, phase = "cancel" }, root.Position, 350)
			return true
		end
		return false
	end, 0.08)
	Players.PlayerRemoving:Connect(function(pl)
		slings[pl] = nil
	end)

	-- ===== v0.25.79 Channel skills (Shield: Barrier Wall / Dome): start on key down, end on key up =====
	local function endChannel(player, ch)
		if channels[player] ~= ch then
			return
		end
		channels[player] = nil
		local c = player.Character
		if c then
			c:SetAttribute("Channel", nil)
			c:SetAttribute("ChannelR", nil)
		end
		local skill = ch.skill
		skillCd[player] = skillCd[player] or {}
		skillCd[player][skill.id] = os.clock() + skill.cd
		local root = R.PlayerService.Root(player)
		if not root or not alive(player) then
			return
		end
		-- the release: the wall slams forward / the dome bursts outward, knocking back what it hits
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.zAxis
		local center = skill.shape == "Wall" and root.Position + look * 5 or root.Position
		local r = skill.shape == "Wall" and (skill.pushRadius or 9) or (skill.radius or 14)
		local opts = { element = "barrier", knock = skill.shape == "Wall" and 12 or 9, knockPower = 2.5, knockFrom = root.Position }
		for _, t in ipairs(inRadiusTargets(player, center, r)) do
			hitTarget(player, t, ch.mult, ch.magic, opts)
		end
		Net.FX("Skill", { skill = skill.id .. "_End", from = root.Position, to = center, char = player.Character, radius = r, look = look }, root.Position, 350)
		R.FruitService.OnCast(player)
	end
	Net.Handle("ChannelStart", function(player, data)
		local skill = ClassesCfg.SkillById[type(data) == "table" and data.skillId or ""]
		if not skill or skill.kind ~= "Channel" or channels[player] or not alive(player) then
			return false
		end
		local lv, why = R.FruitService.SkillLevel(player, skill)
		if not lv then
			return false, why
		end
		skillCd[player] = skillCd[player] or {}
		if skillCd[player][skill.id] and os.clock() < skillCd[player][skill.id] then
			return false, "On cooldown"
		end
		local sp = player:GetAttribute("SP") or 0
		if sp < skill.sp then
			return false, "Not enough SP"
		end
		player:SetAttribute("SP", sp - skill.sp)
		local d = R.PlayerService.Derived(player)
		local ch = { skill = skill, t0 = os.clock(), shape = skill.shape, radius = skill.radius or 14, mult = (skill.mult or 1) * (1 + 0.1 * (lv - 1)), magic = d and d.matk > d.atk }
		channels[player] = ch
		local c = player.Character
		if c then
			c:SetAttribute("Channel", skill.shape)
			c:SetAttribute("ChannelR", skill.radius)
		end
		if skill.shape == "Dome" then
			-- v0.25.81 (owner): the dome is a solid wall for monsters: one that reaches it stops at the glass (it is held at
			-- the rim every frame, no shove); bosses are too big to hold (their blows are still blocked)
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local root = R.PlayerService.Root(player)
				if channels[player] ~= ch or not root then
					conn:Disconnect()
					return
				end
				local center = root.Position
				local r = ch.radius
				for _, mob in ipairs(R.MonsterService.InRadius(center, r + 2)) do
					local mr = mob.root
					if not mob.dead and mr and not mob.def.isBoss and not mob.def.isLeviathan then
						local off = (mr.Position - center) * Vector3.new(1, 0, 1)
						local dist = off.Magnitude
						if dist < r + 1 and dist > 0.1 then
							local out = off.Unit
							local rot = mr.CFrame - mr.Position
							mr.CFrame = rot + Vector3.new(center.X, mr.Position.Y, center.Z) + out * (r + 1)
							local v = mr.AssemblyLinearVelocity
							local inward = v:Dot(-out)
							if inward > 0 then
								mr.AssemblyLinearVelocity = v + out * inward
							end
						end
					end
				end
			end)
		end
		task.spawn(function()
			while channels[player] == ch do
				task.wait(0.25)
				if channels[player] ~= ch then
					break
				end
				local left = (player:GetAttribute("SP") or 0) - skill.spPerSec * 0.25
				if left < 0 or os.clock() - ch.t0 > (skill.maxHold or 6) or not alive(player) then
					endChannel(player, ch)
					break
				end
				player:SetAttribute("SP", left)
			end
		end)
		return true
	end, 0.2)
	Net.Handle("ChannelEnd", function(player)
		local ch = channels[player]
		if ch then
			endChannel(player, ch)
		end
		return true
	end, 0.05)
	Players.PlayerRemoving:Connect(function(pl)
		channels[pl] = nil
	end)

	-- Barrier Steps (Shield passive): the stepping client tells the server so the others see the step
	Net.Handle("BarrierStep", function(player, data)
		local root = R.PlayerService.Root(player)
		if player:GetAttribute("Fruit") ~= "Ward" or not root or type(data) ~= "table" or typeof(data.pos) ~= "Vector3" or (data.pos - root.Position).Magnitude > 12 then
			return false
		end
		Net.FX("Skill", { skill = "F_BarrierStep", from = data.pos, to = data.pos, stepper = player.UserId }, root.Position, 300)
		return true
	end, 0.12)

	-- v0.25.80 Glass Stairway (Shield, owner): StairsStart pays and opens a short drawing window; the drawing client
	-- builds its steps locally (instant, collidable) and sends them in batches; every other client builds the same
	-- collidable steps from the FX, so anyone can climb them. Steps must chain (<= Run + Rise apart) and stay near you.
	local stairs = {}
	Net.Handle("StairsStart", function(player, data)
		local skill = ClassesCfg.SkillById[type(data) == "table" and data.skillId or ""]
		if not skill or skill.kind ~= "Stairs" or not alive(player) then
			return false
		end
		local lv, why = R.FruitService.SkillLevel(player, skill)
		if not lv then
			return false, why
		end
		skillCd[player] = skillCd[player] or {}
		if skillCd[player][skill.id] and os.clock() < skillCd[player][skill.id] then
			return false, "On cooldown"
		end
		local sp = player:GetAttribute("SP") or 0
		if sp < skill.sp then
			return false, "Not enough SP"
		end
		player:SetAttribute("SP", sp - skill.sp)
		skillCd[player][skill.id] = os.clock() + skill.cd
		local d = R.PlayerService.Derived(player)
		stairs[player] = { t0 = os.clock(), n = 0, max = skill.maxSteps or 32, hold = skill.maxHold or 5, per = skill.spPerStep or 0,
			mult = (skill.mult or 1) * (1 + 0.1 * (lv - 1)), magic = d and d.matk > d.atk, hit = {} }
		R.FruitService.OnCast(player)
		return true
	end, 0.2)
	Net.Handle("StairStep", function(player, data)
		local st = stairs[player]
		local root = R.PlayerService.Root(player)
		local cfg = FruitsCfg.GlassStairs
		if not st or not root or type(data) ~= "table" or type(data.pts) ~= "table" or os.clock() - st.t0 > st.hold + 1.5 then
			return false
		end
		local ok = {}
		for i, pt in ipairs(data.pts) do
			if i > 12 or st.n >= st.max or typeof(pt) ~= "Vector3" or pt ~= pt then
				break
			end
			if (pt - root.Position).Magnitude > cfg.Reach then
				break
			end
			if st.last and (pt - st.last).Magnitude > cfg.Run + cfg.Rise + 0.6 then
				break
			end
			-- v0.25.81 (owner): every step costs SP (draw for as long as your SP lasts)
			local spNow = player:GetAttribute("SP") or 0
			if spNow < st.per then
				break
			end
			player:SetAttribute("SP", spNow - st.per)
			st.last = pt
			st.n += 1
			table.insert(ok, pt)
			-- a step that bursts out under / into a monster hurts it (each one once per stairway)
			for _, tt in ipairs(inRadiusTargets(player, pt + Vector3.new(0, 1.5, 0), 4)) do
				local key = tt.mob or tt.player
				if key and not st.hit[key] then
					st.hit[key] = true
					hitTarget(player, tt, st.mult, st.magic, { element = "barrier", knock = 4, knockPower = 1.2, knockFrom = pt })
				end
			end
		end
		if #ok > 0 then
			Net.FX("Skill", { skill = "F_GlassStairs_Step", from = ok[1], to = ok[#ok], pts = ok, first = st.n == #ok, stepper = player.UserId }, root.Position, 500)
		end
		return true
	end, 0.05)

	Net.Handle("CastSkill", function(player, data)
		if not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		local p = R.DataService.Get(player)
		local skill = ClassesCfg.SkillById[data.skillId]
		if skill and (skill.kind == "Channel" or skill.kind == "Stairs") then
			return false -- held barriers go through ChannelStart / ChannelEnd, Glass Stairway through StairsStart
		end
		local lv
		if skill and skill.fruit then
			local why
			lv, why = R.FruitService.SkillLevel(player, skill)
			if not lv then
				return false, why
			end
			if skill.kind == "Buff" or skill.kind == "PartyBuff" then
				lv = 1 -- fruit buffs do not scale with mastery (they would get absurd)
			end
		elseif skill and skill.toki then
			-- v0.25.70 Toki skills: yours if you have that Toki
			lv = R.TokiService.Has(p, skill.toki) and 1 or nil
			if not lv then
				return false, "You do not have the " .. skill.toki .. " Toki"
			end
		else
			lv = skill and p.skills[skill.id]
		end
		if not lv then
			return false, "Skill not learned"
		end
		if not skill.fruit and not skill.toki and skill.class ~= p.class and skill.class ~= "Common" then
			return false, "Switch to " .. (ClassesCfg.Classes[skill.class] and ClassesCfg.Classes[skill.class].name or "that class") .. " to use this skill"
		end
		local pumped = skill.fruit == "Bounce" and skill.id ~= "F_GearUp" and Combat.Pumped(player)
		if pumped and skill.pumped then
			-- the pumped version of the move: its `pumped` fields win, the rest is the normal skill
			skill = setmetatable(table.clone(skill.pumped), { __index = skill })
		end
		skillCd[player] = skillCd[player] or {}
		local now = os.clock()
		if skillCd[player][skill.id] and now < skillCd[player][skill.id] then
			return false, "On cooldown"
		end
		local sp = player:GetAttribute("SP") or 0
		if sp < skill.sp then
			return false, "Not enough SP"
		end
		local root = R.PlayerService.Root(player)
		local d = R.PlayerService.Derived(player)
		local mult = (skill.mult or 1) * (1 + 0.1 * (lv - 1))
		-- v0.25.65: charge-up skills hit harder the longer the key was held (client sends 0..1)
		if skill.charge then
			local c = tonumber(data.charge) or 0
			mult *= 1 + CHARGE_BONUS * math.clamp(c == c and c or 0, 0, 1)
		end
		-- v0.25.75 LINK: a damage skill right after your M1 finisher hits harder (weave skills into the strings)
		do
			local c = combos[player]
			local rh = WeaponInfo.Rhythm
			if c and c.n == 4 and now - c.last <= rh.LinkWindow and skill.mult then
				mult *= rh.Link
				Net.Push(player, "Link", {})
			end
		end
		local magic = skill.magic == true
		if skill.fruit then
			magic = d.matk > d.atk -- fruits use whichever attack stat is better
		end
		local kind = skill.kind
		local fxData = { fx = skill.fx, from = root.Position, char = player.Character, skill = skill.id }
		local strike = skillStrike(player, skill)
		local travel = skill.travel or 0.2 -- a Ranged skill reaches its target this long after the strike frame
		if pumped then
			strike /= PUMP_SPEED
			travel = 0.06 -- compressed air: there in a blink
			fxData.pumped = true
			fxData.speed = PUMP_SPEED
		end
		-- v0.25.80: clients time projectiles with the server (strike frame, then the flight / delay)
		fxData.strike = strike
		fxData.travel = kind == "Ranged" and travel or skill.delay
		fxData.splash = skill.splash
		local skillOpts = nil
		if skill.fruit then
			local el = FRUIT_ELEMENT[skill.fruit]
			skillOpts = { element = el, dot = el == "fire" and { "burn", 0.2, 3 } or nil }
		end
		if skill.slow then
			skillOpts = skillOpts or {}
			skillOpts.slow = skill.slow -- dazed (Navigator Baton Flurry)
		end
		if skill.stun then
			skillOpts = skillOpts or {}
			skillOpts.stun = skill.stun -- v0.25.77 Smoke Pellet: lost in the smoke
		end
		if skill.split then
			skillOpts = skillOpts or {}
			skillOpts.split = skill.split -- v0.25.77 Swordsman: a kill by this skill cuts the monster in two
		end
		-- knockback (v0.24.12): damage skills shove on their LAST hit; power = the skill's multiplier (Heavy Attack 2.2+)
		local knockPower = skill.knockPower or (skill.heavy and math.max(2.2, mult)) or mult
		local knockDist = skill.knockDist or math.clamp(2.5 + knockPower * 2, 3, 10) -- Recoil Cannon sends them far
		local function lastHitOpts(isLast, from)
			if not isLast or (kind ~= "Melee" and kind ~= "Ranged" and kind ~= "Dash" and kind ~= "AoE" and kind ~= "GroundAoE") then
				return skillOpts
			end
			local o = table.clone(skillOpts or {})
			o.knock, o.knockPower, o.knockFrom = knockDist, knockPower, from
			return o
		end

		local aimDir = typeof(data.dir) == "Vector3" and Vector3.new(data.dir.X, 0, data.dir.Z) or nil
		if aimDir and (aimDir.Magnitude < 0.5 or aimDir.Magnitude ~= aimDir.Magnitude or aimDir.Magnitude == math.huge) then
			aimDir = nil
		end
		aimDir = aimDir and aimDir.Unit
		-- v0.25.48 (owner: hold-to-aim follows the cursor up and down): the path may tilt, at most ~53 degrees
		local aim3 = aimDir
		if aimDir and data.dir.Y == data.dir.Y and math.abs(data.dir.Y) < math.huge then
			local y = math.clamp(data.dir.Unit.Y, -0.8, 0.8)
			aim3 = aimDir * math.sqrt(1 - y * y) + Vector3.new(0, y, 0)
		end
		-- v0.25.50 (owner: skills did not hurt NPC hulls, only M1): every damage skill also hits hostile ships in its area
		local shipDmg = math.floor((magic and d.matk or d.atk) * mult * (skill.hits or 1) * 0.8)
		local function shipLine(from, to)
			task.delay(strike, R.ShipService.SkillHit, player, from, to, 8, shipDmg)
		end
		local function shipCircle(center, radius)
			task.delay(math.max(0.25, strike), R.ShipService.SkillHitCircle, player, center, radius, shipDmg)
		end
		if (kind == "Melee" or kind == "Ranged") and aimDir and not resolveTarget(player, data.target) then
			-- manual mode, aimed at nothing in particular: the skill goes out along the aim and hits what is in its path
			local range = skill.range or 10
			root.CFrame = CFrame.lookAt(root.Position, root.Position + aimDir)
			-- ships in the path take the hit too (at sea there are rarely monsters to aim at); v0.25.42: from anywhere
			do
				local shipRange = math.max(range, 40)
				fxData.to = root.Position + aim3 * shipRange
				shipLine(root.Position, root.Position + aimDir * shipRange)
			end
			local land = strike + (kind == "Ranged" and travel or 0)
			local seen = {}
			if skill.firstHit then
				-- v0.25.81 Ward Pistol: the ball flies until it meets someone (or its range) and bursts there
				local burst = root.Position + aim3 * range
				for step = 2, range, 2 do
					local at = root.Position + aim3 * step
					if #inRadiusTargets(player, at, 3.5) > 0 then
						burst = at
						break
					end
				end
				local frac = (burst - root.Position).Magnitude / range
				fxData.to = burst
				fxData.travel = travel * frac
				for _, tt in ipairs(inRadiusTargets(player, burst, skill.splash or 5)) do
					hitLater(strike + travel * frac, player, tt, mult, magic, lastHitOpts(true, root.Position))
				end
				range = 0 -- no path hits below
			end
			for step = 2, range, 3 do
				for _, tt in ipairs(inRadiusTargets(player, root.Position + aim3 * step, skill.line or skill.splash or 4.5)) do
					local key = tt.mob or tt.player
					if key and not seen[key] then
						seen[key] = true
						for i = 1, skill.hits or 1 do
							hitLater(land + (skill.hitEvery or 0.09) * (i - 1), player, tt, mult, magic, lastHitOpts(i == (skill.hits or 1), root.Position))
						end
					end
				end
			end
		elseif kind == "Melee" or kind == "Ranged" then
			local target = resolveTarget(player, data.target)
			if not target then
				return false, "No target"
			end
			if Reach.Gap(root.Position, target.model) > (skill.range or 10) + 4.5 then
				return false, "Too far away"
			end
			fxData.to = target.pos
			if target.kind ~= "ship" then
				shipLine(root.Position, target.pos) -- a crewman on deck: the hull under him takes it too
			end
			local land = strike + (kind == "Ranged" and travel or 0)
			for i = 1, skill.hits or 1 do
				hitLater(land + (skill.hitEvery or 0.09) * (i - 1), player, target, mult, magic, lastHitOpts(i == (skill.hits or 1), root.Position))
			end
			if skill.splash then
				-- v0.25.66 Recoil Cannon: the shock wave around the target throws everyone near it too
				for _, tt in ipairs(inRadiusTargets(player, target.pos, skill.splash)) do
					if (tt.mob or tt.player) ~= (target.mob or target.player) then
						hitLater(land + 0.03, player, tt, mult * 0.7, magic, lastHitOpts(true, root.Position))
					end
				end
			end
			if skill.line then
				-- v0.25.69 pumped Stretch Pistol: the blast of air hits everything between you and the target too
				local from, seen = root.Position, { [target.mob or target.player or 0] = true }
				local path = target.pos - from
				if skill.pierce and path.Magnitude > 0.5 then
					-- v0.25.81 Flying Slash: the wave flies on through to its full range, cutting everyone in its way
					path = path.Unit * math.max(path.Magnitude, skill.range or 40)
				end
				for step = 2, path.Magnitude, 3 do
					for _, tt in ipairs(inRadiusTargets(player, from + path.Unit * step, skill.line)) do
						local key = tt.mob or tt.player
						if key and not seen[key] then
							seen[key] = true
							hitLater(strike + travel * step / path.Magnitude, player, tt, mult * 0.8, magic, lastHitOpts(true, from))
						end
					end
				end
			end
			if skill.id == "OniSlash" then
				hitLater(land + 0.15, player, target, mult * 0.5, magic)
			end
			if skill.pull and target.kind == "mob" then
				-- v0.25.65 Smoke Grip: drag the monster to you (a shove away from a point behind it)
				local from = root.Position
				task.delay(land, function()
					local mob = target.mob
					if mob and not mob.dead and mob.root then
						local away = (mob.root.Position - from) * Vector3.new(1, 0, 1)
						if away.Magnitude > 6 then
							-- dragged to ~4 studs in front of you, at a speed it can actually travel (v0.25.77)
							local dist = away.Magnitude - 4.5
							R.MonsterService.Knockback(mob, mob.root.Position + away.Unit * 5, dist / 0.88, 3, math.clamp(dist / 80, 0.24, 0.45))
						end
					end
				end)
			end
		elseif kind == "Dash" then
			-- dash toward the target (or straight ahead), hitting everything along the way
			local t = resolveTarget(player, data.target)
			local dir = t and (t.pos - root.Position) or aimDir or root.CFrame.LookVector
			dir = Vector3.new(dir.X, 0, dir.Z)
			if dir.Magnitude < 0.1 then
				dir = root.CFrame.LookVector
			end
			dir = dir.Unit
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Monsters") }
			params.RespectCanCollide = true
			local hit = workspace:Raycast(root.Position, dir * skill.range, params)
			local dist = hit and math.max(0, hit.Distance - 3) or skill.range
			local from = root.Position
			local to = from + dir * dist
			-- v0.24.14 (playtest: the dash felt like a teleport): the caster's client slides there at DASH_SPEED (it owns
			-- its physics); the hits below land along the path at the same speed
			Net.Push(player, "SkillDash", { dir = dir, dist = dist, speed = 60 })
			fxData.to = to
			shipLine(from, from + dir * skill.range)
			local seen = {}
			for step = 0, dist, 4 do
				for _, tt in ipairs(inRadiusTargets(player, from + dir * step, 6)) do
					local key = tt.mob or tt.player
					if key and not seen[key] then
						seen[key] = true
						hitLater(0.08 + step / 60, player, tt, mult, magic, lastHitOpts(true))
					end
				end
			end
		elseif kind == "AoE" then
			fxData.to = root.Position
			fxData.radius = skill.radius
			shipCircle(root.Position, skill.radius or 10)
			if skill.ticks then
				-- v0.25.65: lingering storms (White Out, Split Festival) hit again every tickEvery seconds, around you
				fxData.vanish = skill.vanish
				if skill.vanish then
					-- v0.25.76 White Out: you ARE the smoke while it spins: nothing can hit you
					local stamp = os.clock()
					player:SetAttribute("Invulnerable", true)
					player:SetAttribute("VanishAt", stamp)
					task.delay(strike + skill.vanish, function()
						if player:GetAttribute("VanishAt") == stamp then
							player:SetAttribute("Invulnerable", nil)
						end
					end)
				end
				for i = 1, skill.ticks do
					task.delay(strike + (skill.delay or 0) + (i - 1) * (skill.tickEvery or 0.3), function()
						local r = R.PlayerService.Root(player)
						if r and alive(player) then
							for _, t in ipairs(inRadiusTargets(player, r.Position, skill.radius)) do
								hitTarget(player, t, mult, magic, lastHitOpts(i == skill.ticks, r.Position))
							end
						end
					end)
				end
			else
				for _, t in ipairs(inRadiusTargets(player, root.Position, skill.radius)) do
					hitLater(strike, player, t, mult, magic, lastHitOpts(true, root.Position))
				end
			end
		elseif kind == "GroundAoE" then
			local pos = typeof(data.pos) == "Vector3" and data.pos or nil
			if not pos then
				local t = resolveTarget(player, data.target)
				pos = t and t.pos
			end
			if not pos or (pos - root.Position).Magnitude > (skill.range or 40) + 6 then
				return false, "Invalid position"
			end
			fxData.to = pos
			fxData.radius = skill.radius
			shipCircle(pos, skill.radius or 10)
			if skill.smoke then
				-- v0.25.76 Smoke Screen: monsters inside the cloud miss half their blows for `smoke` seconds
				table.insert(smokeZones, { pos = pos, r = skill.radius or 14, untilT = os.clock() + skill.smoke })
				fxData.smoke = skill.smoke
			end
			-- v0.25.65: `ticks` = a lingering area (Flame Twister) or a delayed chain of bursts (Emberflies `delay`)
			for i = 1, skill.ticks or 1 do
				task.delay(math.max(0.25, strike) + (skill.delay or 0) + (i - 1) * (skill.tickEvery or 0.3), function()
					for _, t in ipairs(inRadiusTargets(player, pos, skill.radius)) do
						hitTarget(player, t, mult, magic, lastHitOpts(i == (skill.ticks or 1), pos))
					end
				end)
			end
		elseif kind == "Heal" then
			Combat.HealPlayer(player, (skill.power or 50) * (1 + 0.25 * (lv - 1)) + d.matk * 0.5)
		elseif kind == "PartyHeal" then
			fxData.radius = skill.radius
			local amount = (skill.power or 100) * (1 + 0.2 * (lv - 1)) + d.matk * 1.2
			for _, m in ipairs(partyInRadius(player, skill.radius or 30)) do
				Combat.HealPlayer(m, amount)
			end
		elseif kind == "Buff" or kind == "PartyBuff" then
			local stats = {}
			local scale = 1 + 0.15 * (lv - 1)
			for k, v in pairs(skill.buff) do
				stats[k] = v * scale
			end
			local targets = kind == "PartyBuff" and partyInRadius(player, skill.radius or 30) or { player }
			if skill.syringe then
				-- v0.25.77 Adrenaline Shot: a syringe flies into every crewmate it reaches (FX)
				fxData.allies = {}
				fxData.radius = skill.radius or 30 -- v0.25.80: the halo on the ground shows how far it reaches
				for _, m in ipairs(targets) do
					if m ~= player and m.Character then
						table.insert(fxData.allies, m.Character)
					end
				end
			end
			for _, m in ipairs(targets) do
				Combat.AddBuff(m, skill.id, stats, skill.duration)
			end
			if skill.id == "F_GearUp" then
				-- clients read this to charge faster / show the pumped moves (server time, GetServerTimeNow)
				player:SetAttribute("PumpUntil", workspace:GetServerTimeNow() + skill.duration)
			end
		elseif kind == "Roar" then
			local ok, why = R.TokiService.Roar(player, skill)
			if not ok then
				return false, why
			end
			fxData = nil -- the roar has its own FX (TokiRoar)
		elseif kind == "ShipBuff" then
			if not R.ShipService.AddShipBuff(player, skill.id, skill.buff.shipSpeed * (1 + 0.15 * (lv - 1)), skill.duration) then
				return false, "You must be on a ship"
			end
		elseif kind == "ShipRepair" then
			if not R.ShipService.RepairNearby(player, skill.power * (1 + 0.2 * (lv - 1))) then
				return false, "You must be on a ship"
			end
		end

		player:SetAttribute("SP", sp - skill.sp)
		local cd = skill.cd * (pumped and PUMP_CD or 1)
		skillCd[player][skill.id] = now + cd
		if skill.fruit then
			R.FruitService.OnCast(player)
		end
		lastAttack[player] = now
		if not skill.fruit and not skill.toki and kind ~= "ShipBuff" and kind ~= "ShipRepair" then
			R.WeaponService.Draw(player, weaponType(player))
		end
		if fxData then
			Net.FX("Skill", fxData, root.Position, 350)
		end
		return { ok = true, data = { cd = cd } }
	end, 0.15)
end

function Combat.Start()
	setup()
	Players.PlayerRemoving:Connect(function(pl)
		buffs[pl] = nil
		lastAttack[pl] = nil
		skillCd[pl] = nil
		lastHurt[pl] = nil
		combos[pl] = nil
	end)
	-- HP/SP regen + buff expiry
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for _, pl in ipairs(Players:GetPlayers()) do
				local d = R.PlayerService.Derived(pl)
				local hum = R.PlayerService.Humanoid(pl)
				if d and hum and hum.Health > 0 and not R.KnockdownService.IsDowned(pl) then
					local sp = pl:GetAttribute("SP") or 0
					pl:SetAttribute("SP", math.min(d.maxSp, sp + 1 + d.maxSp * 0.015 + d.INT * 0.1))
					if now - (lastHurt[pl] or 0) > 6 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.015 + d.VIT * 0.3)
					end
				end
				local list = buffs[pl]
				if list then
					local changed = false
					for i = #list, 1, -1 do
						if list[i].expires <= now then
							table.remove(list, i)
							changed = true
						end
					end
					if changed then
						syncBuffAttr(pl)
						R.PlayerService.Recompute(pl)
					end
				end
			end
		end
	end)
end

return Combat
