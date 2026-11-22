-- Formulas: Ragnarok-style stat math (shared so server and client agree)
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes).Classes
local FruitsCfg = require(Shared.Config.Fruits)
local TokiCfg = require(Shared.Config.Toki)
local PetsCfg = require(Shared.Config.Pets)
local ItemDB = require(Shared.Modules.ItemDB)

local F = {}
F.StatNames = { "STR", "AGI", "VIT", "INT", "DEX", "LUK" }
F.MaxStat = 99

function F.BaseExpToNext(level)
	return math.floor(30 * level ^ 2.1 + 60 * level)
end

function F.JobExpToNext(level)
	return math.floor(22 * level ^ 2.05 + 40 * level)
end

function F.StatCost(current)
	return math.floor((current - 1) / 10) + 2
end

function F.StatPointsForLevel(level)
	return math.floor(level / 5) + 3
end

local function addBonus(target, bonus)
	if not bonus then
		return
	end
	for k, v in pairs(bonus) do
		if type(v) == "number" then
			target[k] = (target[k] or 0) + v
		end
	end
end

function F.FindItem(profile, uid)
	for _, e in ipairs(profile.inventory) do
		if e.uid == uid then
			return e
		end
	end
	return nil
end

-- Sum bonuses from equipment + cards
function F.EquipBonus(profile)
	local b = { weaponAtk = 0, weaponMatk = 0, equipDef = 0, equipMdef = 0 }
	for _, uid in pairs(profile.equipment) do
		local entry = F.FindItem(profile, uid)
		local def = entry and ItemDB.Get(entry.id)
		if def then
			local refine = entry.refine or 0
			if def.kind == "Weapon" then
				local grade = ItemDB.Grade(def)
				local mult = (grade and grade.mult or 1) * (1 + refine * GameConfig.Refine.AtkPerRefine)
				b.weaponAtk += (def.atk or 0) * mult
				b.weaponMatk += (def.matk or 0) * mult
			else
				b.equipDef += (def.def or 0) + refine * GameConfig.Refine.DefPerRefine
				b.equipMdef += def.mdef or 0
			end
			for _, k in ipairs({ "str", "agi", "vit", "int", "dex", "luk", "maxHp", "maxSp" }) do
				if def[k] then
					b[k] = (b[k] or 0) + def[k]
				end
			end
			if entry.cards then
				for _, cardId in ipairs(entry.cards) do
					local c = ItemDB.Cards[cardId]
					if c then
						addBonus(b, c.bonus)
					end
				end
			end
		end
	end
	return b
end

-- v0.25.70 Toki attribute bonus: { STR = 3, ... } (Config/Toki Bonus; advanced forms = sea 3)
function F.TokiStats(profile)
	local out = {}
	local t = profile.toki
	if type(t) ~= "table" then
		return out
	end
	local B = TokiCfg.Bonus
	if t.Conqueror then
		local adv = t.Conqueror.advanced
		for _, k in ipairs(F.StatNames) do
			out[k] = (out[k] or 0) + (adv and B.Conqueror.advancedAll or B.Conqueror.all)
		end
		if adv then
			out.LUK += B.Conqueror.advancedLuk
		end
	end
	for _, id in ipairs({ "Armament", "Observation" }) do
		if t[id] then
			local adv = t[id].advanced
			for _, k in ipairs(TokiCfg.ById[id].stats) do
				out[k] = (out[k] or 0) + (adv and B[id].advancedMain or B[id].main)
			end
			if adv then
				out.LUK = (out.LUK or 0) + B[id].advancedLuk
			end
		end
	end
	return out
end

-- v0.25.70 Power: one number for how strong someone is (Conqueror Toki compares Powers, not levels). The same shape
-- for players and monsters: level, the better attack, defense and HP.
function F.Power(d, level)
	return math.floor(level * 5 + math.max(d.atk or 0, d.matk or 0) + (d.def or 0) * 3 + (d.maxHp or 0) / 8)
end
function F.MonsterPower(def)
	return math.floor(def.level * 5 + (def.atk or 0) + (def.def or 0) * 3 + (def.hp or 0) / 8)
end

-- v0.25.69: where each attribute's bonus comes from, for the Stats tooltip: { STR = { { "Gear", 2 }, { "Fruit", 3 } } }
function F.StatSources(profile)
	local out = {}
	local function add(stat, label, v)
		if v and v ~= 0 then
			out[stat] = out[stat] or {}
			table.insert(out[stat], { label, v })
		end
	end
	local gear, cards = {}, {}
	for _, uid in pairs(profile.equipment or {}) do
		local entry = F.FindItem(profile, uid)
		local def = entry and ItemDB.Get(entry.id)
		if def then
			for _, k in ipairs(F.StatNames) do
				gear[k] = (gear[k] or 0) + (def[string.lower(k)] or 0)
			end
			for _, cardId in ipairs(entry.cards or {}) do
				local c = ItemDB.Cards[cardId]
				local cb = {}
				addBonus(cb, c and c.bonus)
				for _, k in ipairs(F.StatNames) do
					cards[k] = (cards[k] or 0) + (cb[string.lower(k)] or 0)
				end
			end
		end
	end
	local toki = F.TokiStats(profile)
	local fruitDef = profile.fruit and FruitsCfg.ById[profile.fruit.id]
	local fruit = profile.fruit and FruitsCfg.StatsFor(profile.fruit.id, profile.fruit.mastery) or {}
	for _, k in ipairs(F.StatNames) do
		add(k, "Gear", gear[k])
		add(k, "Cards", cards[k])
		add(k, fruitDef and (fruitDef.name .. " (Mastery " .. (profile.fruit.mastery or 0) .. ")") or "Fruit", fruit[k])
		add(k, "Toki", toki[k])
	end
	return out
end

-- buffs: { atk=0.25, def=0.3, crit=20, flee=40, aspd=0.2 } (current buff totals)
function F.Compute(profile, buffs)
	buffs = buffs or {}
	local cls = Classes[profile.class] or Classes.Brawler
	local lvl = profile.baseLevel
	local b = F.EquipBonus(profile)
	local s = profile.stats
	-- active pet bonus (grows with each evolution stage)
	if profile.activePet and profile.pets then
		for _, pet in ipairs(profile.pets) do
			if pet.uid == profile.activePet then
				local sp = PetsCfg.ById[pet.species]
				for k, v in pairs(sp and sp.bonus or {}) do
					b[k] = (b[k] or 0) + (v[pet.stage] or 0)
				end
			end
		end
	end
	-- Toki (v0.25.70): Conqueror = every attribute; Armament / Observation = their two
	for stat, v in pairs(F.TokiStats(profile)) do
		local k = string.lower(stat)
		b[k] = (b[k] or 0) + v
	end
	-- Cursed Fruit attribute bonus (v0.25.69, grows with Fruit Mastery)
	if profile.fruit then
		for stat, v in pairs(FruitsCfg.StatsFor(profile.fruit.id, profile.fruit.mastery)) do
			local k = string.lower(stat)
			b[k] = (b[k] or 0) + v
		end
	end
	-- Cursed Fruit passive
	local fp = profile.fruit and FruitsCfg.ById[profile.fruit.id] and FruitsCfg.ById[profile.fruit.id].passive
	if fp then
		b.flee = (b.flee or 0) + (fp.flee or 0)
		b.defPct = (b.defPct or 0) + (fp.defPct or 0)
		b.atkPct = (b.atkPct or 0) + (fp.atkPct or 0)
		b.hpPct = (b.hpPct or 0) + (fp.maxHpPct or 0)
	end
	-- Heritage perks (Config/Looks, v0.24.0)
	local her = profile.heritage
	local herSpeed, herMatk = 1, 0
	if her == "Islander" then
		b.hpPct = (b.hpPct or 0) + 0.05
		b.expPct = (b.expPct or 0) + 0.05
	elseif her == "Skyborn" then
		herSpeed = 1.05
	elseif her == "Tidekin" then
		b.defPct = (b.defPct or 0) + 0.05
	elseif her == "Beastkin" then
		b.atkPct = (b.atkPct or 0) + 0.05
		herSpeed = 1.05
	elseif her == "Oni" then
		b.atkPct = (b.atkPct or 0) + 0.08
		b.defPct = (b.defPct or 0) + 0.06
	elseif her == "Cinderwing" then
		-- the 0.1% heritage: always +10% HP, then FLAME (+25% ATK / MATK) or CALM (+20% speed, +10% FLEE, +8% ASPD)
		b.hpPct = (b.hpPct or 0) + 0.1
		if profile.heritageMode == "calm" then
			herSpeed = 1.2
			b.aspd = (b.aspd or 0) + 0.08
		else
			b.atkPct = (b.atkPct or 0) + 0.25
			herMatk = 0.25
		end
	end
	local STR = s.STR + (b.str or 0)
	local AGI = s.AGI + (b.agi or 0)
	local VIT = s.VIT + (b.vit or 0)
	local INT = s.INT + (b.int or 0)
	local DEX = s.DEX + (b.dex or 0)
	local LUK = s.LUK + (b.luk or 0)

	local d = {}
	d.STR, d.AGI, d.VIT, d.INT, d.DEX, d.LUK = STR, AGI, VIT, INT, DEX, LUK
	d.maxHp = math.floor(((100 + lvl * 20 + VIT * 14 + lvl * VIT * 0.6) * cls.hpMod + (b.maxHp or 0)) * (1 + (b.hpPct or 0)))
	d.maxSp = math.floor(((30 + lvl * 4 + INT * 6) * cls.spMod + (b.maxSp or 0)) * (her == "Tidekin" and 1.08 or 1))
	d.atk = math.floor((STR * 2.2 + DEX * 0.4 + LUK * 0.3 + lvl + b.weaponAtk + (b.atk or 0)) * (1 + (b.atkPct or 0) + (buffs.atk or 0)))
	d.matk = math.floor((INT * 3 + lvl + b.weaponMatk + (b.matk or 0)) * (1 + (buffs.atk or 0) + herMatk))
	d.def = math.floor((VIT * 0.8 + b.equipDef + (b.def or 0)) * (1 + (b.defPct or 0) + (buffs.def or 0)))
	d.mdef = math.floor(INT * 0.5 + b.equipMdef + (b.mdef or 0))
	d.hit = math.floor(lvl + DEX * 1.6 + (b.hit or 0))
	d.flee = math.floor((lvl + AGI * 1.6 + (b.flee or 0) + (buffs.flee or 0)) * ((her == "Skyborn" and 1.05) or (her == "Cinderwing" and profile.heritageMode == "calm" and 1.1) or 1))
	d.crit = 1 + LUK * 0.35 + (b.crit or 0) + (buffs.crit or 0)
	local aspd = (b.aspd or 0) + (buffs.aspd or 0)
	d.attackInterval = math.max(0.35, 1.5 * (1 - AGI * 0.006 - DEX * 0.0015) / (1 + aspd))
	d.moveSpeed = math.min(24, 17 + AGI * 0.05) * herSpeed
	d.cannonDamage = (b.cannonDamage or 0) + (cls.passive and cls.passive.cannonDamage or 0)
	d.shipSpeed = (b.shipSpeed or 0) + (cls.passive and cls.passive.shipSpeed or 0)
	d.shipHp = b.shipHp or 0
	d.expPct = b.expPct or 0
	d.beliPct = b.beliPct or 0
	d.dmgVsBoss = b.dmgVsBoss or 0
	d.dmgVsSeafolk = b.dmgVsSeafolk or 0
	d.isMagic = cls.id == "Navigator" or cls.id == "Doctor"
	return d
end

-- Base damage (player->monster and monster->player)
function F.Damage(atk, def, mult, critChance)
	local crit = math.random() * 100 < (critChance or 0)
	local raw = atk * (mult or 1) * (0.9 + math.random() * 0.2)
	local dmg
	if crit then
		dmg = raw * 1.5
	else
		dmg = raw * (100 / (100 + def))
	end
	return math.max(1, math.floor(dmg)), crit
end

function F.HitChance(hit, flee)
	return math.clamp(80 + hit - flee, 5, 95) / 100
end

return F
