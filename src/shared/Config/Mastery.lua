-- Field Job Mastery (remake R3, docs/Plan-Remake.md sec 4): no Job classes. Anyone can repair, cook, steer, heal and
-- shoot cannons; doing it for real raises that field's Mastery (Lv 1..Max) and unlocks passive perks at Lv 10 / 30 / 50.
-- Mastery levels also unlock "Mastery Talents" in the Talent card pool (Config/Talents `need.mastery`).
-- Perk `bonus` keys are Formulas.Compute bonus fields (fractions): repairMult, shipHp, shipSpeed, foodMult, healMult,
-- reviveHp, cannonDamage, reloadCut. They add up across tiers.
local M = {}

M.Max = 50

M.Order = { "Shipwright", "Navigator", "Cook", "Doctor", "Gunner" }

M.Fields = {
	Shipwright = {
		name = "Shipwright", icon = "hammer", color = Color3.fromRGB(196, 120, 70),
		how = "Repair ships with hammer skills or repair kits",
		perks = {
			{ lv = 10, name = "Steady Hands", text = "Ship repairs +30%", bonus = { repairMult = 0.3 } },
			{ lv = 30, name = "Tight Seams", text = "Your ships have +15% hull HP", bonus = { shipHp = 0.15 } },
			{ lv = 50, name = "Master Builder", text = "Repairs +30% more, hull HP +15% more", bonus = { repairMult = 0.3, shipHp = 0.15 } },
		},
	},
	Navigator = {
		name = "Navigator", icon = "compass", color = Color3.fromRGB(150, 110, 230),
		how = "Sail a ship from the helm (moving, not anchored)",
		perks = {
			{ lv = 10, name = "Read the Wind", text = "Your ships sail +10% faster", bonus = { shipSpeed = 0.1 } },
			{ lv = 30, name = "Current Rider", text = "Ships +8% faster again", bonus = { shipSpeed = 0.08 } },
			{ lv = 50, name = "Sea Master", text = "Ships +10% faster again", bonus = { shipSpeed = 0.1 } },
		},
	},
	Cook = {
		name = "Cook", icon = "meat_m", color = Color3.fromRGB(240, 150, 60),
		how = "Eat or share food and drinks, cook feasts (Hearty Meal)",
		perks = {
			{ lv = 10, name = "Good Seasoning", text = "Food and drinks heal +25%", bonus = { foodMult = 0.25 } },
			{ lv = 30, name = "Hearty Portions", text = "Food and drinks heal +25% more", bonus = { foodMult = 0.25 } },
			{ lv = 50, name = "Master Chef", text = "Food and drinks heal +30% more", bonus = { foodMult = 0.3 } },
		},
	},
	Doctor = {
		name = "Doctor", icon = "medkit", color = Color3.fromRGB(230, 90, 170),
		how = "Heal crewmates (healing skills) and revive downed players",
		perks = {
			{ lv = 10, name = "Field Dressing", text = "Your heals +20%", bonus = { healMult = 0.2 } },
			{ lv = 30, name = "Steady Pulse", text = "Players you revive stand up with +20% HP", bonus = { reviveHp = 0.2 } },
			{ lv = 50, name = "Miracle Hands", text = "Your heals +30% more", bonus = { healMult = 0.3 } },
		},
	},
	Gunner = {
		name = "Gunner", icon = "gunpowder", color = Color3.fromRGB(110, 170, 230),
		how = "Hit enemy ships with your cannons (fire from the helm)",
		perks = {
			{ lv = 10, name = "Powder Hand", text = "Cannon damage +10%", bonus = { cannonDamage = 0.1 } },
			{ lv = 30, name = "Quick Swab", text = "Cannons reload 12% faster", bonus = { reloadCut = 0.12 } },
			{ lv = 50, name = "Broadside Ace", text = "Cannon damage +15% more", bonus = { cannonDamage = 0.15 } },
		},
	},
}

-- XP gains per action (MasteryService): per HP repaired / healed, per second at the helm, per cannon hit, per meal
M.Gain = {
	RepairPerHp = 0.12, -- Shipwright: 100 hull HP repaired = 12 XP
	HelmPerSec = 1, -- Navigator: per second sailing at the helm (MinSpeed studs/s or faster)
	HelmMinSpeed = 6,
	FoodUse = 6, -- Cook: one food / drink item
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
				for k, v in pairs(perk.bonus) do
					out[k] = (out[k] or 0) + v
				end
			end
		end
	end
	return out
end

return M
