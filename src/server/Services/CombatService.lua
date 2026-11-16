-- CombatService: basic attacks, skills, buffs, regen and player damage (server-authoritative)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ClassesCfg = require(Shared.Config.Classes)
local ItemDB = require(Shared.Modules.ItemDB)
local Reach = require(ReplicatedStorage.Shared.Modules.Reach)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local Combat = {}
local R
local buffs = {} -- player -> { {id, stats, expires} }
local lastAttack = {}
local skillCd = {} -- player -> { skillId -> time }
local lastHurt = {}

local WeaponRange = { Knuckles = 9, Sword = 10, Shoes = 9, Hammer = 10, Slingshot = 48, StormBaton = 34, MedKit = 26 }

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
	local p = R.DataService.Get(player)
	local entry = p and p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
	local def = entry and ItemDB.Get(entry.id)
	return def and def.weaponType or "Sword"
end

local function alive(player)
	local hum = R.PlayerService.Humanoid(player)
	return hum and hum.Health > 0
end

-- ===== Damage to players =====
function Combat.DamagePlayer(player, amount, info)
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if not hum or hum.Health <= 0 or not root then
		return
	end
	if player:GetAttribute("Invulnerable") then
		return
	end
	hum.Health = math.max(0, hum.Health - amount)
	lastHurt[player] = os.clock()
	Net.FX("Damage", { pos = root.Position + Vector3.new(0, 3, 0), amount = amount, crit = info and info.crit, toPlayer = true }, root.Position, 200)
	if hum.Health <= 0 and info and info.killer then
		R.PvPService.OnPlayerKilled(player, info.killer)
	end
end

-- Monster hits player
function Combat.MonsterHit(mob, player, mult)
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

local function hitTarget(attacker, target, mult, magic, fx)
	local d = R.PlayerService.Derived(attacker)
	if not d then
		return
	end
	local atk = magic and d.matk or d.atk
	if target.kind == "mob" then
		local mob = target.mob
		local flee = mob.def.level * 1.3 + 10
		if not magic and math.random() > Formulas.HitChance(d.hit, flee) then
			Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 3, 0) }, mob.root.Position, 200)
			return
		end
		local bonus = 1
		if mob.def.isBoss then
			bonus += d.dmgVsBoss
		end
		if mob.def.style and mob.def.style.shape == "fishman" then
			bonus += d.dmgVsSeafolk
		end
		local dmg, crit = Formulas.Damage(atk, magic and mob.def.def * 0.5 or mob.def.def, mult * bonus, magic and 0 or d.crit)
		R.MonsterService.Damage(mob, dmg, attacker, crit)
		R.PetService.OnOwnerHit(attacker, mob)
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
		local dmg, crit = Formulas.Damage(atk, magic and td.mdef or td.def, mult * 0.6, magic and 0 or d.crit)
		Combat.DamagePlayer(target.player, dmg, { crit = crit, killer = attacker })
	end
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
		if lastAttack[player] and now - lastAttack[player] < d.attackInterval * 0.92 then
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
		Net.FX("BasicAttack", { from = root.Position, to = target.pos, weapon = wType, char = player.Character }, root.Position, 250)
		hitTarget(player, target, 1, magic)
		return true
	end, 0.2)

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

		if kind == "Melee" or kind == "Ranged" then
			local target = resolveTarget(player, data.target)
			if not target then
				return false, "No target"
			end
			if Reach.Gap(root.Position, target.model) > (skill.range or 10) + 4.5 then
				return false, "Too far away"
			end
			fxData.to = target.pos
			hitTarget(player, target, mult, magic)
			for i = 2, skill.hits or 1 do
				task.delay(0.09 * (i - 1), function()
					if target.kind ~= "mob" or not target.mob.dead then
						hitTarget(player, target, mult, magic)
					end
				end)
			end
			if skill.id == "OniSlash" then
				task.delay(0.15, function()
					if target.kind ~= "mob" or not target.mob.dead then
						hitTarget(player, target, mult * 0.5, magic)
					end
				end)
			end
		elseif kind == "Dash" then
			-- dash toward the target (or straight ahead), hitting everything along the way
			local t = resolveTarget(player, data.target)
			local dir = t and (t.pos - root.Position) or root.CFrame.LookVector
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
			root.CFrame = CFrame.lookAt(to, to + dir)
			fxData.to = to
			local seen = {}
			for step = 0, dist, 4 do
				for _, tt in ipairs(inRadiusTargets(player, from + dir * step, 6)) do
					local key = tt.mob or tt.player
					if key and not seen[key] then
						seen[key] = true
						hitTarget(player, tt, mult, magic)
					end
				end
			end
		elseif kind == "AoE" then
			fxData.to = root.Position
			fxData.radius = skill.radius
			for _, t in ipairs(inRadiusTargets(player, root.Position, skill.radius)) do
				hitTarget(player, t, mult, magic)
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
			task.delay(0.25, function()
				for _, t in ipairs(inRadiusTargets(player, pos, skill.radius)) do
					hitTarget(player, t, mult, magic)
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
	end)
	-- HP/SP regen + buff expiry
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for _, pl in ipairs(Players:GetPlayers()) do
				local d = R.PlayerService.Derived(pl)
				local hum = R.PlayerService.Humanoid(pl)
				if d and hum and hum.Health > 0 then
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
