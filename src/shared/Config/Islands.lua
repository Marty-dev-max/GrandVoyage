-- Islands of the Azure East, laid out in a straight line along +X toward the Crimson Wall.
-- Names are original (inspired by classic pirate-adventure islands, not copied).
-- spawns: offset from island center (X,Z), radius, monster, count
local Islands = {
	{
		id = "Daybreak",
		name = "Daybreak Island",
		subtitle = "Windmill Village",
		x = 0,
		radius = 250,
		levels = { 1, 10 },
		palette = { sand = Color3.fromRGB(255, 228, 164), grass = Color3.fromRGB(124, 214, 92), dirt = Color3.fromRGB(160, 108, 70), accent = Color3.fromRGB(232, 96, 72), wall = Color3.fromRGB(255, 244, 222) },
		theme = "Windmill",
		-- hand-laid layout in World/Daybreak.lua (jungle camp in the west, windmill village, harbor in the east)
		layout = "Daybreak",
		townRadius = 90,
		town = Vector2.new(60, 0), -- plaza center (offset from the island center)
		plants = 260, -- denser ground plants (jungle floor)
		-- story order from the jungle camp: monkeys -> tigers -> boars -> bandits
		spawns = {
			{ offset = Vector2.new(-150, 88), radius = 26, monster = "ForestMonkey", count = 6, area = "Monkey Grove" },
			{ offset = Vector2.new(-145, -100), radius = 28, monster = "JungleTiger", count = 5, area = "Tiger Den" },
			{ offset = Vector2.new(75, -155), radius = 30, monster = "WildBoar", count = 5, area = "Boar Meadow" },
			{ offset = Vector2.new(-27, -100), radius = 17, monster = "MountainBandit", count = 5, area = "Bandit Hill" },
		},
		-- the Bay Serpent guards the way out, at sea in front of the harbor on the route to Conch Bay. v0.23.0 (owner):
		-- no arena; it lies under the water there and rises to fight ships that sail within wakeRadius.
		-- A story fight (quest T12), so it comes back quickly.
		boss = { id = "BaySerpent", offset = Vector2.new(700, 0), respawn = 3 * 60, atSea = true, sea = true, wakeRadius = 150 },
	},
	{
		id = "ConchBay",
		name = "Conch Bay",
		subtitle = "Marine Outpost 135",
		x = 1800,
		radius = 255,
		levels = { 10, 20 },
		palette = { sand = Color3.fromRGB(250, 232, 184), grass = Color3.fromRGB(148, 206, 108), dirt = Color3.fromRGB(150, 112, 80), accent = Color3.fromRGB(62, 124, 224), wall = Color3.fromRGB(236, 230, 214) },
		theme = "MarineOutpost",
		townRadius = 95,
		spawns = {
			{ offset = Vector2.new(-125, 120), radius = 42, monster = "MarineRecruit", count = 6 },
			{ offset = Vector2.new(125, 120), radius = 38, monster = "GuardWolf", count = 5 },
			{ offset = Vector2.new(-70, -155), radius = 42, monster = "MarineRifleman", count = 5 },
		},
		boss = { id = "AxeCaptain", offset = Vector2.new(125, -115), respawn = 25 * 60 },
	},
	{
		id = "Marmalade",
		name = "Marmalade Town",
		subtitle = "Town of Empty Streets",
		x = 3600,
		radius = 250,
		levels = { 20, 30 },
		palette = { sand = Color3.fromRGB(255, 222, 162), grass = Color3.fromRGB(176, 212, 98), dirt = Color3.fromRGB(170, 112, 70), accent = Color3.fromRGB(255, 140, 36), wall = Color3.fromRGB(255, 238, 210) },
		theme = "CircusTown",
		townRadius = 95,
		spawns = {
			{ offset = Vector2.new(-125, 120), radius = 42, monster = "ClownGrunt", count = 6 },
			{ offset = Vector2.new(125, 120), radius = 38, monster = "CircusAcrobat", count = 5 },
			{ offset = Vector2.new(10, -165), radius = 40, monster = "CircusLion", count = 4 },
		},
		boss = { id = "CaptainConfetti", offset = Vector2.new(-135, -105), respawn = 30 * 60 },
		dungeon = "CircusTent",
	},
	{
		id = "Honeyslope",
		name = "Honeyslope Village",
		subtitle = "Village of the Long Slope",
		x = 5400,
		radius = 260,
		levels = { 30, 40 },
		palette = { sand = Color3.fromRGB(245, 226, 176), grass = Color3.fromRGB(108, 200, 118), dirt = Color3.fromRGB(150, 110, 78), accent = Color3.fromRGB(150, 92, 200), wall = Color3.fromRGB(250, 244, 230) },
		theme = "SlopeVillage",
		townRadius = 90,
		spawns = {
			{ offset = Vector2.new(-130, 115), radius = 42, monster = "NightCatPirate", count = 6 },
			{ offset = Vector2.new(125, 125), radius = 38, monster = "HypnoThug", count = 5 },
			{ offset = Vector2.new(-25, -165), radius = 42, monster = "ClawCat", count = 4 },
		},
		boss = { id = "SilentClaw", offset = Vector2.new(145, -120), respawn = 35 * 60 },
	},
	{
		id = "Barracuda",
		name = "Barracuda Bistro",
		subtitle = "The Floating Restaurant",
		x = 7200,
		radius = 195,
		levels = { 40, 50 },
		palette = { sand = Color3.fromRGB(200, 150, 100), grass = Color3.fromRGB(226, 196, 148), dirt = Color3.fromRGB(150, 100, 64), accent = Color3.fromRGB(236, 78, 66), wall = Color3.fromRGB(255, 246, 232) },
		theme = "FloatingRestaurant",
		townRadius = 70,
		floating = true,
		spawns = {
			{ offset = Vector2.new(-100, 95), radius = 34, monster = "ArmadaRaider", count = 6 },
			{ offset = Vector2.new(100, 95), radius = 34, monster = "StarvedPirate", count = 5 },
			{ offset = Vector2.new(0, -110), radius = 34, monster = "ArmoredGunner", count = 4 },
		},
		boss = { id = "ArmadaAdmiral", offset = Vector2.new(0, 285), respawn = 40 * 60, atSea = true },
	},
	{
		id = "Mikan",
		name = "Mikan Isles",
		subtitle = "Tangerine Groves & Sawtooth Park",
		x = 9000,
		radius = 270,
		levels = { 50, 60 },
		palette = { sand = Color3.fromRGB(250, 226, 170), grass = Color3.fromRGB(118, 200, 88), dirt = Color3.fromRGB(150, 104, 68), accent = Color3.fromRGB(255, 166, 28), wall = Color3.fromRGB(250, 240, 220) },
		theme = "SawtoothPark",
		townRadius = 95,
		spawns = {
			{ offset = Vector2.new(-135, 120), radius = 44, monster = "SharkfolkBrawler", count = 6 },
			{ offset = Vector2.new(135, 120), radius = 44, monster = "SawfolkRaider", count = 5 },
			{ offset = Vector2.new(-45, -170), radius = 44, monster = "OctofolkBrute", count = 4 },
		},
		boss = { id = "SawtoothOverlord", offset = Vector2.new(145, -130), respawn = 45 * 60 },
		dungeon = "SawtoothDepths",
	},
	{
		id = "Epilogue",
		name = "Epilogue Town",
		subtitle = "Town of Beginnings and Endings",
		x = 10800,
		radius = 310,
		levels = { 60, 70 },
		palette = { sand = Color3.fromRGB(235, 222, 192), grass = Color3.fromRGB(138, 190, 118), dirt = Color3.fromRGB(140, 110, 84), accent = Color3.fromRGB(196, 62, 58), wall = Color3.fromRGB(240, 230, 210) },
		theme = "HarborCity",
		townRadius = 130,
		arena = { offset = Vector2.new(-160, -160), radius = 55 },
		spawns = {
			{ offset = Vector2.new(-160, 150), radius = 42, monster = "BountyHunter", count = 6 },
			{ offset = Vector2.new(160, 150), radius = 42, monster = "MarineElite", count = 5 },
			{ offset = Vector2.new(170, -160), radius = 42, monster = "MistSoldier", count = 4 },
		},
		boss = { id = "MistCommodore", offset = Vector2.new(0, -215), respawn = 60 * 60 },
	},
}

-- The Crimson Wall and Backflow Peak (gateway to the Grand Current, next update)
local RedLine = {
	name = "Crimson Wall",
	peakName = "Backflow Peak",
	nextSea = "Grand Current",
	x = 12800,
	thickness = 400,
	height = 1400,
	canalWidth = 220,
	gateOffsetX = -160,
}

-- Guild War sea forts (between islands)
local Forts = {
	{ id = "FortWest", name = "Fort Driftwood", x = 4500, z = -330 },
	{ id = "FortMid", name = "Fort Tidebreak", x = 6300, z = 330 },
	{ id = "FortEast", name = "Fort Gullwatch", x = 9900, z = -330 },
}

local byId = {}
for i, island in ipairs(Islands) do
	island.index = i
	byId[island.id] = island
end

return {
	List = Islands,
	ById = byId,
	RedLine = RedLine,
	Forts = Forts,
	StartIsland = "Daybreak",
	SeaName = "Azure East",
	CalmName = "Doldrums",
}
