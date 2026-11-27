-- Cooking (Mastery v2 M2, docs/Plan-Mastery-v2.md sec 2). Cook at any campfire (CookService puts a "Cook" prompt on
-- every Fire in the world). Pick a recipe, play the Timing Bar (Config/Mastery Timing): green = 3 stars, yellow = 2,
-- else 1. One star = the plain item (same id as the shop one), 2 / 3 stars = their own item ids (<id>_2 / <id>_3,
-- made in Config/Items from this list) so they stack and the F1 / F2 auto potions still find them.
-- `kind` picks the buff a 2-3 star dish gives (Buff below). Items.lua also caps the sell price of everything cooked at
-- the cost of its ingredients (`sellCap`), so buying ingredients and selling the food never makes money.
-- This file must not require Config/Items (Items requires it).
local R = {}

R.Ingredients = { "RawMeat", "FreshFish", "Tangerine", "Spice" }

R.List = {
	{ id = "MeatOnBone", tier = "S", lv = 1, kind = "meat", needs = { RawMeat = 1 }, xp = 5 },
	{ id = "GrilledFish", tier = "S", lv = 1, kind = "fish", needs = { FreshFish = 1 }, xp = 5 },
	{ id = "TangerineJuice", tier = "S", lv = 1, kind = "fruit", needs = { Tangerine = 2 }, xp = 5 },
	{ id = "RoastShank", tier = "M", lv = 10, kind = "meat", needs = { RawMeat = 2, Spice = 1 }, xp = 9 },
	{ id = "FishStew", tier = "M", lv = 10, kind = "fish", needs = { FreshFish = 2, Spice = 1 }, xp = 9 },
	{ id = "SeaGrog", tier = "M", lv = 10, kind = "fruit", needs = { Tangerine = 3, Spice = 1 }, xp = 9 },
	{ id = "BigFeast", tier = "L", lv = 30, kind = "meat", needs = { RawMeat = 4, FreshFish = 1, Spice = 2 }, xp = 14 },
	{ id = "CaptainsKeg", tier = "L", lv = 30, kind = "fruit", needs = { Tangerine = 5, Spice = 2 }, xp = 14 },
	{ id = "PepperSkewer", tier = "L", lv = 30, kind = "spice", needs = { RawMeat = 2, Spice = 3 }, xp = 14 },
	{ id = "LeviathanFeast", tier = "Feast", lv = 50, kind = "feast", needs = { RawMeat = 3, FreshFish = 3, Tangerine = 2, Spice = 3 }, xp = 30 },
}

R.ById = {}
for i, r in ipairs(R.List) do
	r.order = i
	R.ById[r.id] = r
end

-- 2 / 3 star versions: heal multiplier, buff strength multiplier, buff seconds, name prefix
R.Stars = {
	[2] = { heal = 1.2, buffK = 1, dur = 60, prefix = "Tasty" },
	[3] = { heal = 1.4, buffK = 1.6, dur = 120, prefix = "Delicious" },
}

-- the buff a tasty dish gives, by main ingredient (CombatService buff stats: hpRegen / spRegen = regen x(1 + v),
-- stamRegen = Stamina regen +v, atk = damage +v)
R.Buff = {
	meat = { hpRegen = 0.5 },
	fish = { stamRegen = 0.25 },
	fruit = { spRegen = 0.5 },
	spice = { atk = 0.05 },
	feast = { hpRegen = 0.5, spRegen = 0.5 },
}
R.BuffText = {
	hpRegen = "HP regen",
	spRegen = "SP regen",
	stamRegen = "Stamina regen",
	atk = "damage",
	def = "defense",
}

-- Cook Mastery XP for one dish: more for more stars
function R.Xp(recipe, stars)
	return recipe.xp * (1 + 0.5 * ((stars or 1) - 1))
end

function R.ItemId(baseId, stars)
	return (stars or 1) > 1 and (baseId .. "_" .. stars) or baseId
end

-- "2 Raw Meat, 1 Spice" in a fixed order
function R.NeedsList(recipe)
	local out = {}
	for _, ing in ipairs(R.Ingredients) do
		if recipe.needs[ing] then
			table.insert(out, { id = ing, n = recipe.needs[ing] })
		end
	end
	return out
end

return R
