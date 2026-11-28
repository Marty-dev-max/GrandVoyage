-- Islands of the Azure East. W1 (owner, 28 Nov 2026, docs/Plan-WorldMap.md): the Azure East is the north-east quarter
-- of a world shaped like four seas around a cross (Shared/Modules/WorldShape). Daybreak lies by the east edge, the route
-- zigzags west and south-west to Epilogue near Backflow Peak in the middle of the world. x / z are RAW (x WorldScale
-- below), -z = north. The world code builds each island at z 0 and moves it (WorldBuilder.buildIsland). The route order
-- is the list order (Islands.Route), never x: SeaZones.Segment measures along the route.
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
			{ offset = Vector2.new(-27, -100), radius = 17, monster = "MountainBandit", count = 5, area = "Bandit Hill", lair = false },
		},
		-- v0.25.148 mini bosses: kept out of `spawns` (WorldBuilder reserves room per spawn, which would move the
		-- generated islands, and hunts / dailies / the quest arrow should not send players to a single elite)
		minis = { { offset = Vector2.new(-27, -100), radius = 4, monster = "BanditChief" } },
		-- the Bay Serpent guards the way out, at sea in front of the harbor on the route to Conch Bay. v0.23.0 (owner):
		-- no arena; it lies under the water there and rises to fight ships that sail within wakeRadius.
		-- A story fight (quest T12), so it comes back quickly.
		boss = { id = "BaySerpent", offset = Vector2.new(0, 760), respawn = 3 * 60, atSea = true, sea = true, wakeRadius = 150 },
	},
	{
		id = "ConchBay",
		name = "Conch Bay",
		subtitle = "Garrison Harbor",
		layout = "ConchBay", -- v0.25.20: hand-laid in World/ConchBay.lua (owner concept art)
		x = -1470, z = -1200,
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
		minis = { { offset = Vector2.new(0, 79), radius = 4, monster = "SpoiledEnsign" } }, -- terrace-2 street between the wolves
		boss = { id = "AxeCaptain", offset = Vector2.new(24, 0), respawn = 25 * 60 },
	},
	{
		id = "Marmalade",
		name = "Marmalade Town",
		subtitle = "Town of Empty Streets",
		x = -2930, z = 400,
		radius = 250,
		levels = { 20, 30 },
		palette = { sand = Color3.fromRGB(255, 222, 162), grass = Color3.fromRGB(176, 212, 98), dirt = Color3.fromRGB(170, 112, 70), accent = Color3.fromRGB(255, 140, 36), wall = Color3.fromRGB(255, 238, 210) },
		theme = "CircusTown",
		layout = "Marmalade", -- v0.25.24: hand-laid in World/Marmalade.lua (owner concept art)
		townRadius = 95,
		-- v0.25.24 (World/Marmalade layout, offsets before the island turns): clowns on the west coast path,
		-- acrobats on the east one, lions in the orange groves on the hill, Captain Confetti in the town hall square
		spawns = {
			{ offset = Vector2.new(0, 38), radius = 14, monster = "ClownGrunt", count = 6, lair = false }, -- v0.25.147: the Crew's checkpoint camp on the crossroads (Marmalade townStory)
			{ offset = Vector2.new(152, 0), radius = 16, monster = "CircusAcrobat", count = 5 }, -- clear of the turned shipyard (v0.25.25)
			{ offset = Vector2.new(0, -192), radius = 20, monster = "CircusLion", count = 4 },
		},
		minis = { { offset = Vector2.new(30, 8), radius = 5, monster = "BeastTamer" } }, -- by the east lion cage (Marmalade townStory)
		boss = { id = "CaptainConfetti", offset = Vector2.new(0, -40), respawn = 30 * 60, indoorY = 20 }, -- v0.25.146: inside the Big Top (v0.25.147 bigger, centre z -40)
		dungeon = "CircusTent",
	},
	{
		id = "Honeyslope",
		name = "Honeyslope Village",
		subtitle = "Village of the Long Slope",
		x = -4400, z = -1330,
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
		x = -5870, z = 530,
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
		x = -7330, z = -1070,
		radius = 270,
		levels = { 50, 60 },
		palette = { sand = Color3.fromRGB(250, 226, 170), grass = Color3.fromRGB(118, 200, 88), dirt = Color3.fromRGB(150, 104, 68), accent = Color3.fromRGB(255, 166, 28), wall = Color3.fromRGB(250, 240, 220) },
		theme = "SawtoothPark",
		layout = "Mikan", -- v0.25.132: hand-laid (World/Mikan.lua)
		townRadius = 95,
		spawns = {
			{ offset = Vector2.new(-135, 120), radius = 44, monster = "SharkfolkBrawler", count = 6 },
			{ offset = Vector2.new(135, 120), radius = 44, monster = "SawfolkRaider", count = 5 },
			{ offset = Vector2.new(-90, -120), radius = 40, monster = "OctofolkBrute", count = 4 },
		},
		boss = { id = "SawtoothOverlord", offset = Vector2.new(20, -140), respawn = 45 * 60 }, -- the palace courtyard
		dungeon = "SawtoothDepths",
	},
	{
		id = "Epilogue",
		name = "Epilogue Town",
		subtitle = "Town of Beginnings and Endings",
		x = -8600, z = 1070,
		radius = 310,
		levels = { 60, 70 },
		palette = { sand = Color3.fromRGB(235, 222, 192), grass = Color3.fromRGB(138, 190, 118), dirt = Color3.fromRGB(140, 110, 84), accent = Color3.fromRGB(196, 62, 58), wall = Color3.fromRGB(240, 230, 210) },
		theme = "HarborCity",
		layout = "Epilogue", -- v0.25.133: hand-laid (World/Epilogue.lua)
		townRadius = 130,
		arena = { offset = Vector2.new(-160, -160), radius = 55 },
		spawns = {
			{ offset = Vector2.new(-160, 150), radius = 42, monster = "BountyHunter", count = 6 },
			{ offset = Vector2.new(160, 150), radius = 42, monster = "MarineElite", count = 5 },
			{ offset = Vector2.new(170, -160), radius = 42, monster = "MistSoldier", count = 4 },
		},
		boss = { id = "MistCommodore", offset = Vector2.new(0, -215), respawn = 60 * 60 },
	},
	-- ===== R5 (owner, 28 Nov 2026): ORIGIN home islands =====
	-- Small Lv 1-5 islands east of Daybreak (W1: by the east edge), one per Origin (Config/Origins `island`): a new character starts on its
	-- Origin's island, learns the ropes there and sails (or rides the current) to Daybreak. They are NOT on the story
	-- route: `origin` marks them, Islands.Route leaves them out (sea segments, NPC ships, whirlpools, the route
	-- currents), each one faces Daybreak and gets its own current toward it. Hand-laid in World/OriginIslands.lua.
	-- Kept last in this list so the shared world random stream of the islands above never changes.
	{
		id = "BastionRock",
		origin = "MarineCadet",
		name = "Bastion Rock",
		subtitle = "Cadet Academy",
		layout = "BastionRock",
		x = 720, z = -820,
		radius = 150,
		levels = { 1, 5 },
		palette = { sand = Color3.fromRGB(236, 226, 200), grass = Color3.fromRGB(120, 196, 104), dirt = Color3.fromRGB(150, 130, 110), accent = Color3.fromRGB(62, 110, 210), wall = Color3.fromRGB(236, 234, 228) },
		theme = "CadetAcademy",
		townRadius = 50,
		spawns = {
			{ offset = Vector2.new(-82, 58), radius = 18, monster = "GullThief", count = 5, area = "Supply Sheds" },
			{ offset = Vector2.new(-92, -46), radius = 16, monster = "ForestMonkey", count = 4, area = "Cliff Pines" },
		},
		minis = { { offset = Vector2.new(-88, 80), radius = 4, monster = "GullBoss" } }, -- between the raided sheds
	},
	{
		id = "SmugglersHollow",
		origin = "BountyHunter",
		name = "Smuggler's Hollow",
		subtitle = "Hunters' Den",
		layout = "SmugglersHollow",
		x = 1000, z = -300,
		radius = 150,
		levels = { 1, 5 },
		palette = { sand = Color3.fromRGB(220, 200, 160), grass = Color3.fromRGB(128, 170, 92), dirt = Color3.fromRGB(120, 96, 76), accent = Color3.fromRGB(220, 160, 60), wall = Color3.fromRGB(196, 170, 136) },
		theme = "SmugglerCove",
		townRadius = 50,
		spawns = {
			{ offset = Vector2.new(70, 52), radius = 18, monster = "DockRat", count = 5, area = "Back Wharf" },
			{ offset = Vector2.new(-84, 34), radius = 16, monster = "ForestMonkey", count = 4, area = "Scrub" },
		},
		minis = { { offset = Vector2.new(92, 70), radius = 4, monster = "WharfKing" } }, -- the far end of the back wharf
	},
	{
		id = "ShackleReef",
		origin = "Outlaw",
		name = "Shackle Reef",
		subtitle = "Wreck of the Prison Hulk",
		layout = "ShackleReef",
		x = 1000, z = 300,
		radius = 150,
		levels = { 1, 5 },
		palette = { sand = Color3.fromRGB(246, 230, 180), grass = Color3.fromRGB(110, 190, 96), dirt = Color3.fromRGB(150, 110, 76), accent = Color3.fromRGB(200, 70, 60), wall = Color3.fromRGB(200, 186, 160) },
		theme = "PrisonWreck",
		townRadius = 50,
		spawns = {
			{ offset = Vector2.new(-58, -66), radius = 18, monster = "HulkJailer", count = 5, area = "The Wreck" },
			{ offset = Vector2.new(84, -36), radius = 16, monster = "ForestMonkey", count = 4, area = "Palm Grove" },
		},
		minis = { { offset = Vector2.new(-30, -60), radius = 4, monster = "HulkWarden" } }, -- on the sand in front of the hulk (beside it = water)
	},
	{
		id = "InkwellIsle",
		origin = "RelicSeeker",
		name = "Inkwell Isle",
		subtitle = "Scholars' Library",
		layout = "InkwellIsle",
		x = 720, z = 820,
		radius = 150,
		levels = { 1, 5 },
		palette = { sand = Color3.fromRGB(240, 228, 196), grass = Color3.fromRGB(116, 200, 110), dirt = Color3.fromRGB(140, 116, 90), accent = Color3.fromRGB(150, 100, 200), wall = Color3.fromRGB(240, 232, 214) },
		theme = "Library",
		townRadius = 50,
		spawns = {
			{ offset = Vector2.new(76, -58), radius = 20, monster = "TombRobber", count = 5, area = "Old Ruins" },
			{ offset = Vector2.new(-86, -30), radius = 16, monster = "ForestMonkey", count = 4, area = "Ink Woods" },
		},
		minis = { { offset = Vector2.new(76, -58), radius = 4, monster = "TombDigger" } }, -- in the middle of the dig
	},
}

-- The Crimson Wall and Backflow Peak (gateway to the Grand Current, next update). Where they stand: WorldShape.
local RedLine = {
	name = "Crimson Wall",
	peakName = "Backflow Peak",
	nextSea = "Grand Current",
	thickness = 400,
	height = 1400,
	canalWidth = 220,
	gateOffsetX = -160,
}

-- Guild War sea forts (between islands)
local Forts = {
	{ id = "FortWest", name = "Fort Driftwood", x = -1870, z = -100 }, -- W1: off the Conch Bay - Marmalade crossing
	{ id = "FortMid", name = "Fort Tidebreak", x = -4780, z = -120 }, -- Honeyslope - Barracuda
	{ id = "FortEast", name = "Fort Gullwatch", x = -7580, z = 230 }, -- Mikan - Epilogue
}

-- R5 (remake): the world is GameConfig.WorldScale x bigger. Island positions, sizes and every offset below grow by it at
-- load (runtime code reads the scaled numbers). `island.raw` keeps the hand-tuned numbers the island builders were laid
-- out with: WorldBuilder builds an island with them (Islands.WithRaw) and then scales the finished map around its center.
local GameConfig = require(script.Parent.GameConfig)
local S = GameConfig.WorldScale or 1
for _, isl in ipairs(Islands) do
	local raw = { radius = isl.radius, townRadius = isl.townRadius, town = isl.town, spawns = {}, minis = {} }
	for k, sp in ipairs(isl.spawns or {}) do
		raw.spawns[k] = { offset = sp.offset, radius = sp.radius }
		sp.offset *= S
		sp.radius *= S
	end
	for k, sp in ipairs(isl.minis or {}) do
		raw.minis[k] = { offset = sp.offset, radius = sp.radius }
		sp.offset *= S
		sp.radius *= S
	end
	if isl.boss then
		raw.boss = { offset = isl.boss.offset, indoorY = isl.boss.indoorY, wakeRadius = isl.boss.wakeRadius }
		isl.boss.offset = isl.boss.offset and isl.boss.offset * S
		isl.boss.indoorY = isl.boss.indoorY and isl.boss.indoorY * S
		isl.boss.wakeRadius = isl.boss.wakeRadius and isl.boss.wakeRadius * S
	end
	if isl.arena then
		raw.arena = { offset = isl.arena.offset, radius = isl.arena.radius }
		isl.arena.offset = isl.arena.offset and isl.arena.offset * S
		isl.arena.radius = isl.arena.radius and isl.arena.radius * S
	end
	isl.raw = raw
	isl.x *= S
	isl.z = isl.z and isl.z * S
	isl.radius *= S
	isl.townRadius = isl.townRadius and isl.townRadius * S
	isl.town = isl.town and isl.town * S
end
for _, f in ipairs(Forts) do
	f.x *= S
	f.z *= S
end

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
-- the story route (no Origin islands): sea segments, NPC ships, whirlpools and the route currents follow it
local Route = {}
for _, isl in ipairs(Islands) do
	if not isl.origin then
		table.insert(Route, isl)
		isl.routeIndex = #Route
	end
end
for k, isl in ipairs(Route) do
	isl.nextId = Route[k + 1] and Route[k + 1].id or nil
end
for i = 2, #Islands do
	local isl = Islands[i]
	-- an Origin island faces Daybreak (where its players sail to), a route island the island before it
	local prev = isl.origin and Islands[1] or Route[(isl.routeIndex or 2) - 1]
	if isl.origin then
		isl.nextId = Islands[1].id
	end
	isl.yaw = math.atan2(prev.x - isl.x, (prev.z or 0) - (isl.z or 0))
	isl.localOffsets = { spawns = {}, boss = isl.boss and isl.boss.offset, arena = isl.arena and isl.arena.offset }
	for k, sp in ipairs(isl.spawns) do
		isl.localOffsets.spawns[k] = sp.offset
		sp.offset = turn(sp.offset, isl.yaw)
	end
	for _, sp in ipairs(isl.minis or {}) do
		sp.offset = turn(sp.offset, isl.yaw)
	end
	if isl.boss and isl.boss.offset then
		isl.boss.offset = turn(isl.boss.offset, isl.yaw)
	end
	if isl.arena and isl.arena.offset then
		isl.arena.offset = turn(isl.arena.offset, isl.yaw)
	end
end

-- Run fn with the island's hand-tuned (unscaled, unturned) numbers swapped in: the island builders lay out with these.
-- x / z stay (the builder works at the island's own x, z 0, and the finished map is scaled around that center).
local function WithRaw(isl, fn)
	local raw = isl.raw
	if not raw then
		return fn()
	end
	local saved = { radius = isl.radius, townRadius = isl.townRadius, town = isl.town, spawns = {}, minis = {} }
	isl.radius, isl.townRadius, isl.town = raw.radius, raw.townRadius, raw.town
	for k, sp in ipairs(isl.spawns or {}) do
		saved.spawns[k] = { sp.offset, sp.radius }
		sp.offset, sp.radius = raw.spawns[k].offset, raw.spawns[k].radius
	end
	for k, sp in ipairs(isl.minis or {}) do
		saved.minis[k] = { sp.offset, sp.radius }
		sp.offset, sp.radius = raw.minis[k].offset, raw.minis[k].radius
	end
	if isl.boss and raw.boss then
		saved.boss = { isl.boss.offset, isl.boss.indoorY, isl.boss.wakeRadius }
		isl.boss.offset, isl.boss.indoorY, isl.boss.wakeRadius = raw.boss.offset, raw.boss.indoorY, raw.boss.wakeRadius
	end
	if isl.arena and raw.arena then
		saved.arena = { isl.arena.offset, isl.arena.radius }
		isl.arena.offset, isl.arena.radius = raw.arena.offset, raw.arena.radius
	end
	local lo = isl.localOffsets
	isl.localOffsets = nil
	local ok, err = pcall(fn)
	isl.localOffsets = lo
	isl.radius, isl.townRadius, isl.town = saved.radius, saved.townRadius, saved.town
	for k, sp in ipairs(isl.spawns or {}) do
		sp.offset, sp.radius = saved.spawns[k][1], saved.spawns[k][2]
	end
	for k, sp in ipairs(isl.minis or {}) do
		sp.offset, sp.radius = saved.minis[k][1], saved.minis[k][2]
	end
	if saved.boss then
		isl.boss.offset, isl.boss.indoorY, isl.boss.wakeRadius = saved.boss[1], saved.boss[2], saved.boss[3]
	end
	if saved.arena then
		isl.arena.offset, isl.arena.radius = saved.arena[1], saved.arena[2]
	end
	if not ok then
		error(err, 0)
	end
end

-- Courier gull fare: 100 per step along the route (an Origin island costs the same as Daybreak)
local function TravelCost(isl)
	return 100 * (isl.routeIndex or 1)
end

return {
	WithRaw = WithRaw,
	Scale = S,
	List = Islands,
	Route = Route,
	TravelCost = TravelCost,
	ById = byId,
	RedLine = RedLine,
	Forts = Forts,
	StartIsland = "Daybreak",
	SeaName = "Azure East",
	CalmName = "Doldrums",
}
