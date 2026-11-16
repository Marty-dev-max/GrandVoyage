-- NPCShips: Marine and Pirate NPC ships in 3 tiers, each with different drops
-- Layouts are generated from length/width/masts/cannons in ShipService
local Ships = {
	-- Marines: drop shipbuilding materials (iron, gunpowder, badges)
	Marine1 = { faction = "Marine", tier = 1, name = "Marine Patrol Sloop", level = 15,
		length = 9, width = 4, masts = 1, cannons = 2, hp = 900, damage = 40, speed = 30, reload = 4.5,
		beli = { 800, 1500 }, exp = 600,
		drops = { { "IronIngot", 0.6, 1, 3 }, { "Gunpowder", 0.6, 1, 3 }, { "MarineBadge", 0.8, 2, 5 }, { "SteelOre", 0.4, 1, 2 } } },
	Marine2 = { faction = "Marine", tier = 2, name = "Marine Frigate", level = 35,
		length = 13, width = 5, masts = 2, cannons = 6, hp = 3600, damage = 70, speed = 34, reload = 4,
		beli = { 3000, 6000 }, exp = 3500,
		drops = { { "IronIngot", 0.9, 3, 6 }, { "Gunpowder", 0.9, 3, 6 }, { "MarineBadge", 1, 5, 10 }, { "TidecoreShard", 0.25, 1, 2 }, { "MarineCoat", 0.05, 1, 1 } } },
	Marine3 = { faction = "Marine", tier = 3, name = "Marine Battleship", level = 60,
		length = 19, width = 7, masts = 3, cannons = 12, hp = 12000, damage = 110, speed = 32, reload = 3.5,
		beli = { 12000, 22000 }, exp = 14000,
		drops = { { "IronIngot", 1, 6, 12 }, { "TidecoreShard", 0.6, 1, 3 }, { "PureTidecore", 0.06, 1, 1 }, { "MarineCaptainCard", 0.01, 1, 1 }, { "Hammer_Master", 0.01, 1, 1 } } },
	-- Pirates: drop lots of Beli, treasure and maps
	Pirate1 = { faction = "Pirate", tier = 1, name = "Pirate Dinghy", level = 15,
		length = 8, width = 4, masts = 1, cannons = 2, hp = 800, damage = 45, speed = 34, reload = 4.5,
		beli = { 1500, 2800 }, exp = 600,
		drops = { { "Wood", 0.8, 3, 6 }, { "SailCloth", 0.6, 1, 3 }, { "MeatOnBone", 0.6, 2, 4 } } },
	Pirate2 = { faction = "Pirate", tier = 2, name = "Pirate Brigantine", level = 35,
		length = 12, width = 5, masts = 2, cannons = 6, hp = 3200, damage = 75, speed = 38, reload = 4,
		beli = { 6000, 11000 }, exp = 3500,
		drops = { { "Wood", 1, 6, 10 }, { "SailCloth", 0.9, 3, 6 }, { "TreasureMap", 0.15, 1, 1 }, { "TidecoreShard", 0.2, 1, 1 } } },
	Pirate3 = { faction = "Pirate", tier = 3, name = "Pirate Galleon", level = 60,
		length = 18, width = 7, masts = 3, cannons = 12, hp = 11000, damage = 120, speed = 34, reload = 3.5,
		beli = { 25000, 45000 }, exp = 14000,
		drops = { { "TreasureMap", 0.6, 1, 2 }, { "TreasureWood", 0.25, 1, 1 }, { "PureTidecore", 0.06, 1, 1 }, { "PirateCaptainCard", 0.01, 1, 1 }, { "Sword_Master", 0.01, 1, 1 } } },
}

-- Tier weights per sea segment (index of the island just passed)
-- segment 1 = Daybreak -> Conch Bay ... segment 7 = after Epilogue Town
local SegmentTierWeights = {
	{ 1, 0, 0 },
	{ 0.85, 0.15, 0 },
	{ 0.6, 0.4, 0 },
	{ 0.3, 0.6, 0.1 },
	{ 0.15, 0.6, 0.25 },
	{ 0.05, 0.5, 0.45 },
	{ 0, 0.4, 0.6 },
}

return {
	Ships = Ships,
	SegmentTierWeights = SegmentTierWeights,
	MaxPerSegment = 3,
	SpawnInterval = 25,
}
