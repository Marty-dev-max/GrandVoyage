-- Exploration chests. Every island hides a handful; each player can open each chest once.
-- Rewards scale with the island's level (Doubloons x level^0.8, EXP as a share of a level's EXP).
-- items: { id, qty, chance }
local C = {}

C.Tiers = {
	Wooden = {
		name = "Wooden Chest", rarity = "Common", body = Color3.fromRGB(150, 98, 52), trim = Color3.fromRGB(110, 110, 120),
		beli = 120, expPct = 0.04,
		items = { { "MeatOnBone", 3, 1 }, { "Wood", 10, 0.6 }, { "SteelOre", 1, 0.35 } },
	},
	Silver = {
		name = "Silver Chest", rarity = "Rare", body = Color3.fromRGB(70, 74, 92), trim = Color3.fromRGB(205, 215, 230),
		beli = 350, expPct = 0.08,
		items = { { "SteelOre", 3, 1 }, { "TangerineJuice", 3, 0.7 }, { "TidecoreShard", 1, 0.12 } },
	},
	Golden = {
		name = "Golden Chest", rarity = "Epic", body = Color3.fromRGB(150, 40, 50), trim = Color3.fromRGB(255, 200, 60),
		beli = 900, expPct = 0.15,
		items = { { "SteelOre", 6, 1 }, { "TidecoreShard", 1, 0.5 }, { "RefineGuard", 1, 0.2 } },
	},
	Captain = {
		name = "Captain's Chest", rarity = "Legendary", body = Color3.fromRGB(60, 34, 90), trim = Color3.fromRGB(255, 215, 80),
		beli = 2400, expPct = 0.3,
		items = { { "TidecoreShard", 2, 1 }, { "RefineGuard", 1, 0.5 }, { "TreasureMap", 1, 0.3 } },
	},
}

-- Bonus for finding every chest on an island
C.IslandBonus = { beli = 1500, expPct = 0.25, items = { { "TreasureMap", 1, 1 } } }

-- Server-side sanity check: the player must be this close to open (the prompt range is smaller)
C.MaxOpenDistance = 16

return C
