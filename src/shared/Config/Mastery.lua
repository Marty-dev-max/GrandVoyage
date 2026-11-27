-- Field Job Mastery (remake R3, docs/Plan-Remake.md sec 4): no Job classes. Anyone can repair, cook, steer, heal and
-- shoot cannons; doing it for real raises that field's Mastery (Lv 1..Max) and unlocks passive perks at Lv 10 / 30 / 50.
-- Mastery levels also unlock "Mastery Talents" in the Talent card pool (Config/Talents `need.mastery`).
-- Perk `bonus` keys are Formulas.Compute bonus fields (fractions): repairMult, shipHp, shipSpeed, foodMult, healMult,
-- reviveHp, cannonDamage, reloadCut. They add up across tiers.
local M = {}

M.Max = 50

M.Order = { "Shipwright", "Navigator", "Cook", "Doctor", "Gunner" }

-- Mastery v2 (docs/Plan-Mastery-v2.md, owner table): Lv 10 = passive, Lv 30 = an unlock, Lv 50 = the big one.
-- `soon = true` = shown in the Mastery tab but not in the game yet (M3-M6 of the plan). Cook recipes unlock by
-- Config/Recipes `lv` (Lv 30 = L recipes + Pepper Skewer, Lv 50 = Leviathan Feast).
M.Fields = {
	Shipwright = {
		name = "Shipwright", icon = "hammer", color = Color3.fromRGB(196, 120, 70),
		how = "Repair ships: Patch Planks, Repair Kits or hammer skills",
		perks = {
			{ lv = 10, name = "Sturdy Patch", text = "Repairs +30%, 25% chance to keep the planks", bonus = { repairMult = 0.3, plankSave = 0.25 } },
			{ lv = 30, name = "Emergency Repair", text = "Skill: patch the whole ship and every leak at once", soon = true },
			{ lv = 50, name = "Reinforced Hull", text = "Ships you sail have +20% hull HP", bonus = { shipHp = 0.2 } },
		},
	},
	Navigator = {
		name = "Navigator", icon = "compass", color = Color3.fromRGB(150, 110, 230),
		how = "Sail a ship from the helm (moving, not anchored)",
		perks = {
			{ lv = 10, name = "Wind Reader", text = "Your ships sail +10% faster", bonus = { shipSpeed = 0.1 } },
			{ lv = 30, name = "Storm Sense", text = "See storms, whirlpools and sea currents on the map", soon = true },
			{ lv = 50, name = "Master Helmsman", text = "Weather hurts your ship 50% less, sharp turns", soon = true },
		},
	},
	Cook = {
		name = "Cook", icon = "meat_m", color = Color3.fromRGB(240, 150, 60),
		how = "Cook at any campfire (press E there). Better timing = tastier food",
		perks = {
			{ lv = 10, name = "Good Seasoning", text = "Food and drinks heal you +30%. Unlocks M recipes", bonus = { foodMult = 0.3 } },
			{ lv = 30, name = "Combat Cuisine", text = "Unlocks L recipes + the Pepper Skewer (damage buff)" },
			{ lv = 50, name = "Leviathan Feast", text = "Unlocks the Leviathan Feast: a buff for the whole party" },
		},
	},
	Doctor = {
		name = "Doctor", icon = "medkit", color = Color3.fromRGB(230, 90, 170),
		how = "Heal others (Bandages, healing skills) and revive downed players",
		perks = {
			{ lv = 10, name = "Steady Hands", text = "Your heals +20%, healing items ready 25% sooner", bonus = { healMult = 0.2, itemCdCut = 0.25 } },
			{ lv = 30, name = "Adrenaline Revive", text = "Players you revive stand up with +20% HP", bonus = { reviveHp = 0.2 } },
			{ lv = 50, name = "Miracle Mist", text = "Skill: a healing mist that cures the whole party", soon = true },
		},
	},
	Gunner = {
		name = "Gunner", icon = "gunpowder", color = Color3.fromRGB(110, 170, 230),
		how = "Hit enemy ships with your cannons (fire from the helm)",
		perks = {
			{ lv = 10, name = "Quick Loader", text = "Cannons reload 25% faster", bonus = { reloadCut = 0.25 } },
			{ lv = 30, name = "Chain & Bomb Shot", text = "Unlocks chain shot (slows ships) and bomb shot", soon = true },
			{ lv = 50, name = "Full Broadside", text = "Skill: every gun fires at once, even while reloading", soon = true },
		},
	},
}

-- Timing Bar (Mastery v2 M1, shared by every field): green = perfect, yellow = good, the rest = plain
M.Timing = {
	Sweep = 0.75, -- seconds for the needle to cross the bar once (it goes back and forth)
	GreenMin = 0.08, -- green width at Lv 1 (fraction of the bar) ...
	GreenMax = 0.22, -- ... and at Lv Max
	Yellow = 0.12, -- extra width on each side of the green
	Timeout = 6, -- no press = plain result
	Lag = 0.9, -- the client's stop time may be this much older than the server's clock (ping + frame; a sanity check, not anti-cheat)
}

function M.GreenWidth(level)
	local t = math.clamp((level - 1) / (M.Max - 1), 0, 1)
	return M.Timing.GreenMin + (M.Timing.GreenMax - M.Timing.GreenMin) * t
end

-- needle position 0..1 after `t` seconds (ping-pong)
function M.Needle(t)
	local x = (t / M.Timing.Sweep) % 2
	return x <= 1 and x or 2 - x
end

-- XP gains per action (MasteryService): per HP repaired / healed, per second at the helm, per cannon hit, per meal
M.Gain = {
	RepairPerHp = 0.12, -- Shipwright: 100 hull HP repaired = 12 XP
	HelmPerSec = 1, -- Navigator: per second sailing at the helm (MinSpeed studs/s or faster)
	HelmMinSpeed = 6,
	FoodUse = 2, -- Cook: eating one food / drink item (Mastery v2: cooking is the main way)
	Feast = 14, -- Cook: a party food buff (Hearty Meal)
	HealPerHp = 0.1, -- Doctor: per HP healed on others
	SelfHealK = 0.25, -- healing yourself counts a quarter
	Revive = 40, -- Doctor: a revive
	CannonHit = 3, -- Gunner: per ball that hits a hostile ship
	CannonPerDmg = 0.04,
}

-- XP for the next level
function M.ToNext(level)
	return math.floor(30 + level * 18 + level * level * 0.6)
end

function M.Level(profile, field)
	local m = profile and profile.mastery and profile.mastery[field]
	return (m and m.lv) or 1
end

-- summed perk bonuses of every unlocked tier
function M.Bonus(profile)
	local out = {}
	for _, id in ipairs(M.Order) do
		local lv = M.Level(profile, id)
		for _, perk in ipairs(M.Fields[id].perks) do
			if lv >= perk.lv then
				for k, v in pairs(perk.bonus or {}) do
					out[k] = (out[k] or 0) + v
				end
			end
		end
	end
	return out
end

return M
