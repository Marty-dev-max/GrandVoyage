-- SkillSets (v0.25.71, owner): the hotbar is 6 SETS of up to 6 skills. Keys 1-6 pick the set, E R F Z X C cast the
-- skills of the set you are on (like most action games). Every set fills itself from where its skills come from:
--   1 Class   = your class's skills            2 Fruit       = your Cursed Fruit's skills (locked by Mastery)
--   3 Basic   = Heavy Attack, First Aid (later: weapon arts in the second sea)
--   4 Armament / 5 Observation / 6 Conqueror = Toki skills (the whole set is locked until you have that Toki)
-- Auto Battle uses the skills of the sets ticked in settings.autoSets (all by default): tick only 2 to farm Mastery.
-- Used by the client (HUD, Combat, Skills window) and the server (SetAutoSettings check).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ClassesCfg = require(Shared.Config.Classes)
local FruitsCfg = require(Shared.Config.Fruits)
local TokiCfg = require(Shared.Config.Toki)
local MasteryCfg = require(Shared.Config.Mastery)

local S = {}
S.Size = 6
S.Sets = {
	{ id = "Class", name = "Arts" }, -- remake R3: Weapon Arts (the skills of the weapon in hand)
	{ id = "Fruit", name = "Cursed Fruit" },
	{ id = "Basic", name = "Basic" },
	{ id = "Armament", name = "Armament Toki", toki = "Armament" },
	{ id = "Observation", name = "Observation Toki", toki = "Observation" },
	{ id = "Conqueror", name = "Conqueror Toki", toki = "Conqueror" },
}

local function hasToki(p, kind)
	return type(p.toki) == "table" and p.toki[kind] ~= nil
end

-- the skills of set n: a list of { skill = def, ready = bool } (ready = learned / unlocked)
function S.Skills(p, n)
	local set = S.Sets[n]
	local out = {}
	if not p or not set then
		return out
	end
	local function add(sk, ready)
		if #out < S.Size then
			table.insert(out, { skill = sk, ready = ready })
		end
	end
	if set.id == "Class" then
		local cls = ClassesCfg.Classes[p.class]
		for _, sk in ipairs(cls and cls.skills or {}) do
			add(sk, (p.skills[sk.id] or 0) > 0)
		end
	elseif set.id == "Fruit" then
		local f = p.fruit and FruitsCfg.ById[p.fruit.id]
		for _, sk in ipairs(f and f.skills or {}) do
			add(sk, (p.fruit.mastery or 0) >= (sk.mastery or 1))
		end
	elseif set.id == "Basic" then
		for _, sk in ipairs(ClassesCfg.Classes.Common.skills) do
			add(sk, (p.skills[sk.id] or 0) > 0)
		end
		-- remake M4: Mastery skills join the set only once their field is high enough (no dim slots for most players)
		for _, sk in ipairs(MasteryCfg.Skills) do
			if MasteryCfg.Level(p, sk.mastery) >= sk.lv then
				add(sk, true)
			end
		end
	elseif set.toki then
		for _, sk in ipairs(TokiCfg.Skills) do
			if sk.toki == set.toki then
				add(sk, hasToki(p, set.toki))
			end
		end
	end
	return out
end

-- can you switch to set n at all? (a fruit to use, a Toki you have)
function S.Open(p, n)
	local set = S.Sets[n]
	if not p or not set then
		return false
	end
	if set.id == "Fruit" then
		return p.fruit ~= nil
	elseif set.toki then
		return hasToki(p, set.toki)
	end
	return true
end

-- the skill id in slot i of set n ("" = empty or not ready)
function S.Id(p, n, i)
	local e = S.Skills(p, n)[i]
	return e and e.ready and e.skill.id or ""
end

-- may Auto Battle use set n? (settings.autoSets[n] ~= false; every set by default)
function S.Auto(p, n)
	local a = p and p.settings and p.settings.autoSets
	return type(a) ~= "table" or a[n] ~= false
end

return S
