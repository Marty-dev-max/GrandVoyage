-- Islands of the Azure East (v0.25.11, owner): spread north and south of the route east to the Crimson Wall, so
-- sailing means picking a heading, not a straight line. x still grows with the level (SeaZones.Segment relies on it);
-- z = north/south offset. The world code builds each island at z 0 and moves it (WorldBuilder.buildIsland).
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
		subtitle = "Garrison Harbor",
		layout = "ConchBay", -- v0.25.20: hand-laid in World/ConchBay.lua (owner concept art)
		x = 2100, z = 800,
		radius = 255,
		levels = { 10, 20 },
		palette = { sand = Color3.fromRGB(250, 232, 184), grass = Color3.fromRGB(148, 206, 108), dirt = Color3.fromRGB(150, 112, 80), accent = Color3.fromRGB(62, 124, 224), wall = Color3.fromRGB(236, 230, 214) },
		theme = "MarineOutpost",
		townRadius = 95,
		-- v0.25.23 (owner): recruits on the terrace-1 street and wolves on the terrace-2 street, right on the way up the
		-- stairs to the garrison; riflemen on the training lawn, the Axe-Arm Captain in the courtyard (before the turn)
		spawns = {
			{ offset = Vector2.new(-32, 143), radius = 6, monster = "MarineRecruit", count = 3 },
			{ offset = Vector2.new(32, 143), radius = 6, monster = "MarineRecruit", count = 3 },
			{ offset = Vector2.new(-30, 79), radius = 6, monster = "GuardWolf", count = 3 },
			{ offset = Vector2.new(30, 79), radius = 6, monster = "GuardWolf", count = 2 },
			{ offset = Vector2.new(-52, -2), radius = 10, monster = "MarineRifleman", count = 5 },
		},
		boss = { id = "AxeCaptain", offset = Vector2.new(24, 0), respawn = 25 * 60 },
	},
	{
		id = "Marmalade",
		name = "Marmalade Town",
		subtitle = "Town of Empty Streets",
		x = 3900, z = -750,
		radius = 250,
		levels = { 20, 30 },
		palette = { sand = Color3.fromRGB(255, 222, 162), grass = Color3.fromRGB(176, 212, 98), dirt = Color3.fromRGB(170, 112, 70), accent = Color3.fromRGB(255, 140, 36), wall = Color3.fromRGB(255, 238, 210) },
		theme = "CircusTown",
		layout = "Marmalade", -- v0.25.24: hand-laid in World/Marmalade.lua (owner concept art)
		townRadius = 95,
		-- v0.25.24 (World/Marmalade layout, offsets before the island turns): clowns on the west coast path,
		-- acrobats on the east one, lions in the orange groves on the hill, Captain Confetti in the town hall square
		spawns = {
			{ offset = Vector2.new(-150, 70), radius = 16, monster = "ClownGrunt", count = 6 },
			{ offset = Vector2.new(152, 0), radius = 16, monster = "CircusAcrobat", count = 5 }, -- clear of the turned shipyard (v0.25.25)
			{ offset = Vector2.new(0, -192), radius = 20, monster = "CircusLion", count = 4 },
		},
		boss = { id = "CaptainConfetti", offset = Vector2.new(0, -58), respawn = 30 * 60 },
		dungeon = "CircusTent",
	},
	{
		id = "Honeyslope",
		name = "Honeyslope Village",
		subtitle = "Village of the Long Slope",
		x = 5300, z = 1350,
		radius = 260,
		levels = { 30, 40 },
		palette = { sand = Color3.fromRGB(245, 226, 176), grass = Color3.fromRGB(108, 200, 118), dirt = Color3.fromRGB(150, 110, 78), accent = Color3.fromRGB(150, 92, 200), wall = Color3.fromRGB(250, 244, 230) },
		theme = "SlopeVillage",
		layout = "Honeyslope", -- v0.25.130: hand-laid in World/Honeyslope.lua (owner concept notes)
		townRadius = 90,
		spawns = {
			{ offset = Vector2.new(-130, 115), radius = 42, monster = "NightCatPirate", count = 6 },
			{ offset = Vector2.new(125, 125), radius = 38, monster = "HypnoThug", count = 5 },
			{ offset = Vector2.new(-120, -150), radius = 36, monster = "ClawCat", count = 4 }, -- v0.25.130: off the manor hill
		},
		boss = { id = "SilentClaw", offset = Vector2.new(145, -120), respawn = 35 * 60 },
	},
	{
		id = "Barracuda",
		name = "Barracuda Bistro",
		subtitle = "The Floating Restaurant",
		x = 6800, z = -1250,
		radius = 160, -- v0.25.131: 195 left the raft mostly empty deck
		levels = { 40, 50 },
		palette = { sand = Color3.fromRGB(200, 150, 100), grass = Color3.fromRGB(226, 196, 148), dirt = Color3.fromRGB(150, 100, 64), accent = Color3.fromRGB(236, 78, 66), wall = Color3.fromRGB(255, 246, 232) },
		theme = "FloatingRestaurant",
		layout = "Barracuda", -- v0.25.131: hand-laid in World/Barracuda.lua (owner concept notes)
		townRadius = 70,
		floating = true,
		spawns = {
			{ offset = Vector2.new(-84, 70), radius = 30, monster = "ArmadaRaider", count = 6 }, -- v0.25.131: inside the smaller raft
			{ offset = Vector2.new(84, 70), radius = 30, monster = "StarvedPirate", count = 5 },
			{ offset = Vector2.new(0, -100), radius = 30, monster = "ArmoredGunner", count = 4 },
		},
		boss = { id = "ArmadaAdmiral", offset = Vector2.new(0, 285), respawn = 40 * 60, atSea = true },
	},
	{
		id = "Mikan",
		name = "Mikan Isles",
		subtitle = "Tangerine Groves & Sawtooth Park",
		x = 8500, z = 1150,
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
		x = 10300, z = -300,
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
	x = 12600,
	thickness = 400,
	height = 1400,
	canalWidth = 220,
	gateOffsetX = -160,
}

-- Guild War sea forts (between islands)
local Forts = {
	{ id = "FortWest", name = "Fort Driftwood", x = 3000, z = 120 },
	{ id = "FortMid", name = "Fort Tidebreak", x = 6100, z = 60 },
	{ id = "FortEast", name = "Fort Gullwatch", x = 9300, z = 500 },
}

local byId = {}
for i, island in ipairs(Islands) do
	island.index = i
	byId[island.id] = island
end

-- v0.25.21 (owner): every island after the first turns so its front (local +Z, where Conch Bay's long pier is)
-- faces the island before it: arriving ships see a harbor welcoming them. WorldBuilder builds an island unturned
-- with `island.localOffsets`, then rotates the finished island by `island.yaw`; every offset below is stored
-- already turned, so runtime code (monster areas, bosses, arenas, compass) keeps using island.x/z + offset.
local function turn(v, yaw)
	local c, s = math.cos(yaw), math.sin(yaw)
	return Vector2.new(c * v.X + s * v.Y, -s * v.X + c * v.Y)
end
for i = 2, #Islands do
	local isl, prev = Islands[i], Islands[i - 1]
	isl.yaw = math.atan2(prev.x - isl.x, (prev.z or 0) - (isl.z or 0))
	isl.localOffsets = { spawns = {}, boss = isl.boss and isl.boss.offset, arena = isl.arena and isl.arena.offset }
	for k, sp in ipairs(isl.spawns) do
		isl.localOffsets.spawns[k] = sp.offset
		sp.offset = turn(sp.offset, isl.yaw)
	end
	if isl.boss and isl.boss.offset then
		isl.boss.offset = turn(isl.boss.offset, isl.yaw)
	end
	if isl.arena and isl.arena.offset then
		isl.arena.offset = turn(isl.arena.offset, isl.yaw)
	end
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
