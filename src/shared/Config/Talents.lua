-- Talent cards (remake R3, docs/Plan-Remake.md sec 4). Separate from the monster cards that go into gear slots.
-- Every base level up gives one pick: the server offers 3 cards (TalentService, weighted by rarity) from the ones you
-- qualify for, you keep 1. A talent is kept for good (no respec yet).
-- need = { stats = { VIT = 10 }, any = { WPN = 15, MAR = 15 } (one of them), mastery = { Cook = 10 }, level = 10 }
--   stats are the TOTAL attributes (points + race + gear + ...), like the Stats window's TOTAL column.
-- bonus keys = Formulas.Compute bonus fields (fractions unless noted):
--   hpPct atkPct defPct aspd expPct beliPct dmgVsBoss shipSpeed shipHp cannonDamage reloadCut repairMult healMult
--   foodMult staminaPct staminaRegenPct speedPct, flat: flee crit hit maxSp mdef,
--   guard: blockCut (block takes less), postureCut (posture fills slower), parryAdd (s), fallCut, dodgeAdd (s),
--   damage types: dmgSlash dmgBlunt dmgPierce dmgElement, specials: lastStand (bonus dmg under 30% HP),
--   shipHitMult (your own hits on ships), burnKick (chance that kicks set the target on fire)
-- Names are our own (never another game's talent / card names).
local T = {}

T.Rarity = {
	Common = { weight = 70, color = Color3.fromRGB(205, 210, 220) },
	Rare = { weight = 25, color = Color3.fromRGB(80, 160, 255) },
	Epic = { weight = 7, color = Color3.fromRGB(190, 100, 255) },
}
T.RarityOrder = { "Common", "Rare", "Epic" }

T.Offer = 3 -- cards per pick

T.List = {
	-- ===== body (anyone) =====
	{ id = "IronLungs", name = "Iron Lungs", rarity = "Common", icon = "dash", need = { stats = { END = 8 } }, bonus = { staminaPct = 0.15 }, text = "Stamina +15%" },
	{ id = "SecondWind", name = "Second Wind", rarity = "Common", icon = "dash", need = { stats = { END = 14 } }, bonus = { staminaRegenPct = 0.2 }, text = "Stamina refills 20% faster" },
	{ id = "SeaLegs", name = "Sea Legs", rarity = "Common", icon = "boots", need = {}, bonus = { speedPct = 0.04 }, text = "Move speed +4%" },
	{ id = "ThickHide", name = "Thick Hide", rarity = "Common", icon = "armor", need = { stats = { VIT = 8 } }, bonus = { hpPct = 0.06 }, text = "Max HP +6%" },
	{ id = "CatLanding", name = "Cat Landing", rarity = "Common", icon = "boots", need = { stats = { END = 6 } }, bonus = { fallCut = 0.4 }, text = "Fall damage -40%" },
	{ id = "StubbornMind", name = "Stubborn Mind", rarity = "Common", icon = "charm", need = { stats = { WIL = 8 } }, bonus = { maxSp = 20, mdef = 5 }, text = "Max SP +20, MDEF +5" },
	{ id = "LightStep", name = "Light Step", rarity = "Common", icon = "boots", need = { stats = { END = 12 } }, bonus = { flee = 8 }, text = "FLEE +8" },
	{ id = "LuckyDoubloon", name = "Lucky Doubloon", rarity = "Common", icon = "coin", need = {}, bonus = { beliPct = 0.08 }, text = "Doubloons from monsters +8%" },
	{ id = "QuickLearner", name = "Quick Learner", rarity = "Common", icon = "book", need = {}, bonus = { expPct = 0.05 }, text = "EXP +5%" },
	{ id = "ShieldArm", name = "Shield Arm", rarity = "Rare", icon = "armor", need = { stats = { VIT = 15 } }, bonus = { blockCut = 0.2 }, text = "Blocked blows hurt 20% less" },
	{ id = "RootedStance", name = "Rooted Stance", rarity = "Rare", icon = "armor", need = { stats = { END = 18 } }, bonus = { postureCut = 0.25 }, text = "Posture fills 25% slower when you block" },
	{ id = "SharpReflex", name = "Sharp Reflex", rarity = "Rare", icon = "charm", need = { stats = { WIL = 14 } }, bonus = { parryAdd = 0.06 }, text = "Parry window +0.06 s" },
	{ id = "BigGameHunter", name = "Big Game Hunter", rarity = "Rare", icon = "skull", need = { level = 12 }, bonus = { dmgVsBoss = 0.1 }, text = "+10% damage to bosses" },
	{ id = "HotBlood", name = "Hot Blood", rarity = "Rare", icon = "flame", need = { level = 8 }, bonus = { atkPct = 0.05 }, text = "ATK +5%" },
	{ id = "KeenEye", name = "Keen Eye", rarity = "Rare", icon = "crown", need = { any = { WPN = 14, MAR = 14 } }, bonus = { crit = 4 }, text = "Critical chance +4" },
	{ id = "ToughAsNails", name = "Tough as Nails", rarity = "Rare", icon = "armor", need = { stats = { VIT = 20 } }, bonus = { defPct = 0.08, hpPct = 0.04 }, text = "DEF +8%, Max HP +4%" },
	{ id = "LastStand", name = "Last Stand", rarity = "Epic", icon = "skull", need = { stats = { VIT = 25 } }, bonus = { lastStand = 0.2 }, text = "Below 30% HP you deal +20% damage" },
	{ id = "GhostStep", name = "Ghost Step", rarity = "Epic", icon = "dash", need = { stats = { END = 25 } }, bonus = { dodgeAdd = 0.08 }, text = "Dash dodges stay open 0.08 s longer" },
	{ id = "Unshaken", name = "Unshaken", rarity = "Epic", icon = "charm", need = { stats = { WIL = 25, VIT = 15 } }, bonus = { postureCut = 0.2, blockCut = 0.15 }, text = "Posture -20%, blocked blows -15%" },
	-- ===== weapon arts =====
	{ id = "EdgeDiscipline", name = "Edge Discipline", rarity = "Rare", icon = "sword", need = { stats = { WPN = 14 } }, bonus = { dmgSlash = 0.08 }, text = "Slash damage +8%" },
	{ id = "BoneBreaker", name = "Bone Breaker", rarity = "Rare", icon = "knuckles", need = { any = { MAR = 14, WPN = 14 } }, bonus = { dmgBlunt = 0.08 }, text = "Blunt damage +8%" },
	{ id = "SteadyAim", name = "Steady Aim", rarity = "Rare", icon = "musket_ball", need = { stats = { WPN = 14 } }, bonus = { dmgPierce = 0.08, hit = 6 }, text = "Pierce damage +8%, HIT +6" },
	{ id = "Attuned", name = "Attuned", rarity = "Rare", icon = "flame", need = { any = { FRU = 14, WPN = 14 } }, bonus = { dmgElement = 0.08 }, text = "Element damage +8%" },
	{ id = "FastHands", name = "Fast Hands", rarity = "Rare", icon = "knuckles", need = { stats = { MAR = 18 } }, bonus = { aspd = 0.06 }, text = "Attack speed +6%" },
	{ id = "ArmsMaster", name = "Arms Master", rarity = "Epic", icon = "sword", need = { stats = { WPN = 40 } }, bonus = { atkPct = 0.08, crit = 3 }, text = "ATK +8%, critical chance +3" },
	{ id = "StoneKnuckles", name = "Stone Knuckles", rarity = "Epic", icon = "knuckles", need = { stats = { MAR = 40 } }, bonus = { dmgBlunt = 0.12, aspd = 0.04 }, text = "Blunt damage +12%, attack speed +4%" },
	-- ===== Mastery Talents (need a Field Mastery level) =====
	{ id = "HullBreaker", name = "Hull Breaker", rarity = "Rare", icon = "hammer", need = { mastery = { Shipwright = 10 } }, bonus = { shipHitMult = 0.5, dmgVsBoss = 0.04 }, text = "Your hits on ships +50%, bosses +4%" },
	{ id = "EmberKick", name = "Ember Kick", rarity = "Rare", icon = "flame", need = { mastery = { Cook = 10 }, stats = { MAR = 12 } }, bonus = { burnKick = 0.3 }, text = "Kicks set the target on fire (30%)" },
	{ id = "FieldMedic", name = "Field Medic", rarity = "Rare", icon = "medkit", need = { mastery = { Doctor = 10 } }, bonus = { healMult = 0.15, reviveHp = 0.1 }, text = "Heals +15%, revived players +10% HP" },
	{ id = "Tailwind", name = "Tailwind Captain", rarity = "Rare", icon = "compass", need = { mastery = { Navigator = 10 } }, bonus = { shipSpeed = 0.05, speedPct = 0.03 }, text = "Ships +5% faster, you +3%" },
	{ id = "PowderMonkey", name = "Powder Monkey", rarity = "Rare", icon = "gunpowder", need = { mastery = { Gunner = 10 } }, bonus = { cannonDamage = 0.1, reloadCut = 0.05 }, text = "Cannon damage +10%, reload -5%" },
	{ id = "IronHull", name = "Iron Hull", rarity = "Epic", icon = "ship", need = { mastery = { Shipwright = 30 } }, bonus = { shipHp = 0.15 }, text = "Your ships have +15% hull HP" },
	{ id = "StormRider", name = "Storm Rider", rarity = "Epic", icon = "compass", need = { mastery = { Navigator = 30 } }, bonus = { shipSpeed = 0.1 }, text = "Your ships sail +10% faster" },
	{ id = "GalleyFeast", name = "Galley Feast", rarity = "Epic", icon = "meat_m", need = { mastery = { Cook = 30 } }, bonus = { foodMult = 0.3, staminaRegenPct = 0.1 }, text = "Food heals +30%, Stamina refills +10%" },
	{ id = "MiracleWorker", name = "Miracle Worker", rarity = "Epic", icon = "medkit", need = { mastery = { Doctor = 30 } }, bonus = { healMult = 0.25 }, text = "Heals +25%" },
	{ id = "BroadsideAce", name = "Broadside Ace", rarity = "Epic", icon = "gunpowder", need = { mastery = { Gunner = 30 } }, bonus = { cannonDamage = 0.15 }, text = "Cannon damage +15%" },
}

T.ById = {}
for _, t in ipairs(T.List) do
	assert(not T.ById[t.id], "duplicate talent " .. t.id)
	assert(T.Rarity[t.rarity], "talent rarity " .. t.id)
	T.ById[t.id] = t
end

-- ctx = { stats = { VIT = 12, ... } (totals), mastery = { Cook = 3 }, level = 5 }
function T.Meets(t, ctx)
	local n = t.need or {}
	if n.level and (ctx.level or 1) < n.level then
		return false
	end
	for k, v in pairs(n.stats or {}) do
		if (ctx.stats[k] or 0) < v then
			return false
		end
	end
	if n.any then
		local ok = false
		for k, v in pairs(n.any) do
			if (ctx.stats[k] or 0) >= v then
				ok = true
			end
		end
		if not ok then
			return false
		end
	end
	for k, v in pairs(n.mastery or {}) do
		if (ctx.mastery[k] or 1) < v then
			return false
		end
	end
	return true
end

-- "VIT 10, Cook Mastery 10" for the card's requirement line
function T.NeedText(t)
	local n, out = t.need or {}, {}
	if n.level then
		table.insert(out, "Lv." .. n.level)
	end
	for k, v in pairs(n.stats or {}) do
		table.insert(out, k .. " " .. v)
	end
	if n.any then
		local parts = {}
		for k, v in pairs(n.any) do
			table.insert(parts, k .. " " .. v)
		end
		table.sort(parts)
		table.insert(out, table.concat(parts, " or "))
	end
	for k, v in pairs(n.mastery or {}) do
		table.insert(out, k .. " Mastery " .. v)
	end
	return #out > 0 and table.concat(out, ", ") or "Anyone"
end

-- summed bonuses of the talents a profile holds
function T.Bonus(profile)
	local out = {}
	for _, id in ipairs(profile and profile.talents or {}) do
		local t = T.ById[id]
		for k, v in pairs(t and t.bonus or {}) do
			out[k] = (out[k] or 0) + v
		end
	end
	return out
end

return T
