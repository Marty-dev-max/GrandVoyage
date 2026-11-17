-- Sea Companions: original sea creatures with 3-stage evolutions.
-- Get them two ways: CAPTURE (throw Sea Bait at a capturable monster below 35% HP) or HATCH eggs found in chests.
-- The active pet follows you, attacks what you attack, and gives a passive bonus that grows with each evolution.
-- bonus keys: defPct, hpPct, atkPct, crit, beliPct (one value per stage)
local P = {}

P.Species = {
	{
		id = "Hermit", rarity = "Common", icon = "🦀", shape = "crab", color = Color3.fromRGB(240, 120, 90), accent = Color3.fromRGB(230, 200, 150),
		stages = { "Pinchy", "Shellguard", "Fortress Crab" }, bonus = { defPct = { 0.04, 0.08, 0.14 } }, bonusText = "DEF",
		material = "CrabShell", -- eggs only since Beach Crabs left Daybreak (v0.22); shells drop from Forest Monkeys
	},
	{
		id = "Boarlet", rarity = "Uncommon", icon = "🐗", shape = "boar", color = Color3.fromRGB(150, 100, 70), accent = Color3.fromRGB(240, 230, 210),
		stages = { "Boarlet", "Tusker", "Ironhide Boar" }, bonus = { hpPct = { 0.04, 0.08, 0.14 } }, bonusText = "Max HP",
		capture = { monster = "WildBoar", chance = 0.25 }, material = "BoarTusk",
	},
	{
		id = "Gull", rarity = "Rare", icon = "🐦", shape = "bird", color = Color3.fromRGB(245, 245, 250), accent = Color3.fromRGB(255, 190, 60),
		stages = { "Gullet", "Courier Gull", "Storm Albatross" }, bonus = { beliPct = { 0.05, 0.10, 0.18 } }, bonusText = "Doubloons",
		material = "SailCloth",
	},
	{
		id = "Puffer", rarity = "Epic", icon = "🐡", shape = "puffer", color = Color3.fromRGB(255, 210, 90), accent = Color3.fromRGB(120, 80, 40),
		stages = { "Puffling", "Spikepuff", "Urchin Lord" }, bonus = { atkPct = { 0.04, 0.08, 0.13 } }, bonusText = "ATK",
		material = "SharkfolkFin",
	},
	{
		id = "Lantern", rarity = "Legendary", icon = "🐟", shape = "lantern", color = Color3.fromRGB(60, 70, 120), accent = Color3.fromRGB(120, 255, 230),
		stages = { "Lantern Fry", "Lanternfin", "Abyss Lantern" }, bonus = { crit = { 3, 6, 10 } }, bonusText = "CRIT",
		material = "TidecoreShard",
	},
	{
		id = "Leviathan", rarity = "Secret", icon = "🐉", shape = "serpent", color = Color3.fromRGB(40, 110, 140), accent = Color3.fromRGB(200, 255, 255),
		stages = { "Baby Leviathan", "Sea Serpent", "Leviathan Wyrm" }, bonus = { atkPct = { 0.08, 0.14, 0.22 } }, bonusText = "ATK",
		capture = { monster = "Leviathan", chance = 0.01 }, material = "LeviathanScale",
	},
}

P.ById = {}
P.ByMonster = {}
for _, s in ipairs(P.Species) do
	P.ById[s.id] = s
	if s.capture then
		P.ByMonster[s.capture.monster] = s
	end
end

-- Eggs (items "SeaEgg" / "GoldenEgg"). Weights are shown in the game (odds disclosure).
P.Eggs = {
	SeaEgg = { name = "Sea Egg", icon = "🥚", rarity = "Uncommon", weights = { Hermit = 40, Boarlet = 35, Gull = 20, Puffer = 5 } },
	GoldenEgg = { name = "Golden Egg", icon = "🪺", rarity = "Epic", weights = { Gull = 40, Puffer = 35, Lantern = 22, Leviathan = 3 } },
}
-- Chance to find an egg in an exploration chest, by chest tier
P.ChestEggs = {
	Wooden = { egg = "SeaEgg", chance = 0.05 },
	Silver = { egg = "SeaEgg", chance = 0.10 },
	Golden = { egg = "GoldenEgg", chance = 0.15 },
	Captain = { egg = "GoldenEgg", chance = 0.30 },
}

P.Capture = { BaitItem = "SeaBait", MaxHpRatio = 0.35, Range = 40 }
P.MaxPets = 30
P.MaxLevel = 50
P.EvolveAt = { 15, 35 } -- level needed for stage 2 / stage 3
-- evolution cost: Doubloons x rarity multiplier + species material
P.EvolveCost = { { beli = 3000, material = 10 }, { beli = 25000, material = 25 } }
P.RarityMult = { Common = 1, Uncommon = 1.5, Rare = 2, Epic = 3, Legendary = 5, Secret = 8 }
P.ExpShare = 0.5 -- the active pet gets this share of the Base EXP you earn
P.AttackEvery = 1.6 -- seconds
P.AttackScale = { base = 0.15, perLevel = 0.01 } -- pet hit = owner ATK x (base + perLevel x level)

function P.ExpToNext(level)
	return math.floor(40 * level ^ 1.6)
end

return P
