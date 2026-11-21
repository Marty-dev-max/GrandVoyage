-- CombatService: basic attacks, skills, buffs, regen and player damage (server-authoritative)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ClassesCfg = require(Shared.Config.Classes)
local Reach = require(ReplicatedStorage.Shared.Modules.Reach)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)
local GameConfig = require(Shared.Config.GameConfig)

local Combat = {}
local R
local buffs = {} -- player -> { {id, stats, expires} }
local lastAttack = {}
local skillCd = {} -- player -> { skillId -> time }
local lastHurt = {}

local AnimClips = require(Shared.Config.AnimClips)
local AmmoCfg = require(Shared.Config.Ammo)
-- ranged basic attacks: the shot flies this long after the release frame (matches VFX.Projectile durations)
local SHOT_FLIGHT = { Slingshot = 0.18, StormBaton = 0.22, MedKit = 0.2 }
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
function Combat.MonsterHit(mob, player, mult)
	if R.KnockdownService.IsDowned(player) then
		R.KnockdownService.TryExecute(mob, player)
		return
	end
	local d = R.PlayerService.Derived(player)
	if not d then
		return
	end
	local hit = mob.def.level * 1.8 + 25
	if math.random() > Formulas.HitChance(hit, d.flee) then
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0) }, root.Position, 150)
		end
		return
	end
	local dmg = Formulas.Damage(mob.def.atk, d.def, mult or 1, mob.def.isBoss and 5 or 1)
	Combat.DamagePlayer(player, dmg)
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
	return nil
end

-- damage over time: `ticks` hits of `perTick`, 0.6 s apart (burn / poison); a fresh one replaces the old of the same kind
local dots = setmetatable({}, { __mode = "k" }) -- mob -> { [kind] = token }
local function applyDot(attacker, mob, kind, perTick, ticks)
	dots[mob] = dots[mob] or {}
	local token = (dots[mob][kind] or 0) + 1
	dots[mob][kind] = token
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
local function hitTarget(attacker, target, mult, magic, opts)
	local d = R.PlayerService.Derived(attacker)
	if not d then
		return
	end
	opts = opts or {}
	local crit = (d.crit or 0) + (opts.critBonus or 0)
	local atk = magic and d.matk or d.atk
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
		local mdef = opts.ignoreDef and 0 or (magic and mob.def.def * 0.5 or mob.def.def)
		local dmg, isCrit = Formulas.Damage(atk, mdef, mult * bonus, magic and 0 or crit)
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
		if target.kind == "player" and not alive(target.player) then
			return
		end
		hitTarget(attacker, target, mult, magic, opts)
	end)
end

-- the wait before the next basic attack: quick inside a 4-hit string, end-lag after the finisher (GameConfig.M1)
local function m1Gap(player, d)
	local c = combos[player]
	local M1 = GameConfig.M1
	if not c or os.clock() - c.last >= M1.Reset then
		return d.attackInterval * M1.Quick
	end
	return d.attackInterval * (c.n >= M1.Hits and M1.End or M1.Quick)
end

-- which combo hit this basic attack is (the clients play the same clip: it is sent in the FX), and how fast to play
-- it: a swing longer than the attack interval is sped up to fit, so fast attackers never queue swings that lag behind
local function comboStep(player, wType)
	local w = AnimClips.Weapons[wType] or AnimClips.Weapons.Fists
	local c = combos[player] or { n = 0, last = 0 }
	combos[player] = c
	local now = os.clock()
	c.n = (now - c.last < GameConfig.M1.Reset) and (c.n % #w.combo) + 1 or 1
	c.last = now
	local clip = AnimClips[w.combo[c.n]]
	local d = R.PlayerService.Derived(player)
	local length = clip and clip.keys[#clip.keys].t or 0.3
	local speed = math.clamp(length / math.max(0.15, (d and d.attackInterval or 0.6) * GameConfig.M1.Quick * 0.9), 1, 2.5)
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
local function setup()
	Net.Handle("Attack", function(player, data)
		if not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		local d = R.PlayerService.Derived(player)
		local now = os.clock()
		if lastAttack[player] and now - lastAttack[player] < m1Gap(player, d) * 0.9 then
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
		local magic = wType == "StormBaton"
		R.WeaponService.Draw(player, wType)
		local n, strike, speed = comboStep(player, wType)
		-- slingshots fire the picked ammo (1 per shot; out of it -> free Pebble Shot)
		local ammo, mult = nil, 1
		if AmmoCfg.Weapons[wType] then
			local p = R.DataService.Get(player)
			ammo = AmmoCfg.ById[p and p.ammo or ""] or AmmoCfg.ById[AmmoCfg.Default]
			if ammo.item and not R.InventoryService.RemoveItem(player, ammo.item, 1) then
				R.PlayerService.Notify(player, "Out of " .. ammo.name .. ": back to Pebble Shot", "bad")
				p.ammo = AmmoCfg.Default
				R.PlayerService.MarkDirty(player)
				ammo = AmmoCfg.ById[AmmoCfg.Default]
			end
			mult = ammo.mult
		end
		Net.FX("BasicAttack", { from = root.Position, to = target.pos, weapon = wType, char = player.Character, combo = n, speed = speed, ammo = ammo and ammo.id }, root.Position, 250)
		local hopts = ammo and { critBonus = ammo.critBonus, ignoreDef = ammo.ignoreDef, slow = ammo.slow, splash = ammo.splash, element = ammo.element, dot = ammo.dot } or {}
		if wType == "MedKit" then
			-- the Doctor's stinging powder: a little poison on every throw
			hopts.element, hopts.dot = "poison", { "poison", 0.15, 3 }
		end
		-- the last hit of the combo shoves the monster back (v0.24.12, owner)
		local comboLen = #((AnimClips.Weapons[wType] or AnimClips.Weapons.Fists).combo)
		if n == comboLen and comboLen > 1 then
			hopts.knock, hopts.knockPower = 5, 1
		end
		hitLater(strike + (SHOT_FLIGHT[wType] or 0), player, target, mult, magic, hopts)
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

	Net.Handle("CastSkill", function(player, data)
		if not alive(player) or player:GetAttribute("Vending") then
			return false
		end
		local p = R.DataService.Get(player)
		local skill = ClassesCfg.SkillById[data.skillId]
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
		else
			lv = skill and p.skills[skill.id]
		end
		if not lv then
			return false, "Skill not learned"
		end
		if not skill.fruit and skill.class ~= p.class and skill.class ~= "Common" then
			return false, "Switch to " .. (ClassesCfg.Classes[skill.class] and ClassesCfg.Classes[skill.class].name or "that class") .. " to use this skill"
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
		local magic = skill.magic == true
		if skill.fruit then
			magic = d.matk > d.atk -- fruits use whichever attack stat is better
		end
		local kind = skill.kind
		local fxData = { fx = skill.fx, from = root.Position, char = player.Character, skill = skill.id }
		local strike = skillStrike(player, skill)
		local skillOpts = nil
		if skill.fruit then
			local el = FRUIT_ELEMENT[skill.fruit]
			skillOpts = { element = el, dot = el == "fire" and { "burn", 0.2, 3 } or nil }
		end
		-- knockback (v0.24.12): damage skills shove on their LAST hit; power = the skill's multiplier (Heavy Attack 2.2+)
		local knockPower = (skill.heavy and math.max(2.2, mult)) or mult
		local knockDist = math.clamp(2.5 + knockPower * 2, 3, 10)
		local function lastHitOpts(isLast, from)
			if not isLast or (kind ~= "Melee" and kind ~= "Ranged" and kind ~= "Dash" and kind ~= "AoE" and kind ~= "GroundAoE") then
				return skillOpts
			end
			local o = table.clone(skillOpts or {})
			o.knock, o.knockPower, o.knockFrom = knockDist, knockPower, from
			return o
		end

		local aimDir = typeof(data.dir) == "Vector3" and Vector3.new(data.dir.X, 0, data.dir.Z) or nil
		if aimDir and (aimDir.Magnitude < 0.5 or aimDir.Magnitude ~= aimDir.Magnitude) then
			aimDir = nil
		end
		aimDir = aimDir and aimDir.Unit
		if (kind == "Melee" or kind == "Ranged") and aimDir and not resolveTarget(player, data.target) then
			-- manual mode, aimed at nothing in particular: the skill goes out along the aim and hits what is in its path
			local range = skill.range or 10
			root.CFrame = CFrame.lookAt(root.Position, root.Position + aimDir)
			fxData.to = root.Position + aimDir * range
			-- ships in the path take the hit too (at sea there are rarely monsters to aim at)
			if R.ShipService.IsOnShip(player) then
				local shipRange = math.max(range, 40)
				fxData.to = root.Position + aimDir * shipRange
				local dmg = math.floor((magic and d.matk or d.atk) * mult * (skill.hits or 1) * 0.8)
				local from = root.Position
				task.delay(strike, function()
					R.ShipService.SkillHit(player, from, from + aimDir * shipRange, 8, dmg)
				end)
			end
			local land = strike + (kind == "Ranged" and 0.2 or 0)
			local seen = {}
			for step = 2, range, 3 do
				for _, tt in ipairs(inRadiusTargets(player, root.Position + aimDir * step, 4.5)) do
					local key = tt.mob or tt.player
					if key and not seen[key] then
						seen[key] = true
						for i = 1, skill.hits or 1 do
							hitLater(land + 0.09 * (i - 1), player, tt, mult, magic, lastHitOpts(i == (skill.hits or 1)))
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
			local land = strike + (kind == "Ranged" and 0.2 or 0)
			for i = 1, skill.hits or 1 do
				hitLater(land + 0.09 * (i - 1), player, target, mult, magic, lastHitOpts(i == (skill.hits or 1)))
			end
			if skill.id == "OniSlash" then
				hitLater(land + 0.15, player, target, mult * 0.5, magic)
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
			for _, t in ipairs(inRadiusTargets(player, root.Position, skill.radius)) do
				hitLater(strike, player, t, mult, magic, lastHitOpts(true, root.Position))
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
			task.delay(math.max(0.25, strike), function()
				for _, t in ipairs(inRadiusTargets(player, pos, skill.radius)) do
					hitTarget(player, t, mult, magic, lastHitOpts(true, pos))
				end
			end)
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
			for _, m in ipairs(targets) do
				Combat.AddBuff(m, skill.id, stats, skill.duration)
			end
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
		skillCd[player][skill.id] = now + skill.cd
		if skill.fruit then
			R.FruitService.OnCast(player)
		end
		lastAttack[player] = now
		if not skill.fruit and kind ~= "ShipBuff" and kind ~= "ShipRepair" then
			R.WeaponService.Draw(player, weaponType(player))
		end
		Net.FX("Skill", fxData, root.Position, 350)
		return { ok = true, data = { cd = skill.cd } }
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
