-- GameConfig: core constants. Tune game balance here.
return {
	GameName = "Grand Voyage",
	-- bump on every change: shown bottom-right in game and printed in Output, so you can tell which code is running
	Version = "0.8.0",
	SagaName = "Azure East Saga",
	DataStoreName = "GV_Player_v1",
	GuildStoreName = "GV_Guild_v1",
	AutoSaveInterval = 120,

	-- ===== Sea / sailing lane =====
	SeaLevel = 0,
	Lane = {
		HalfWidth = 520, -- |Z| <= this = full wind
		EdgeWidth = 110, -- edge zone, wind fades (warning)
		-- |Z| > HalfWidth + EdgeWidth = Doldrums (no wind + Leviathans)
	},
	World = {
		MinX = -1400,
		MaxX = 13600,
		HalfZ = 3000,
	},
	CalmBelt = {
		SeaKingSpawnInterval = 4, -- seconds
		MaxSeaKingsPerShip = 5,
		SeaKingDamagePerHit = 90,
		WindFactor = 0, -- sails do nothing in the Doldrums
	},

	-- ===== Levels =====
	MaxBaseLevel = 70, -- Azure East level cap
	MaxJobLevel = 40,
	JobChangeLevel = 10, -- Job Lv needed before your first class switch
	ClassSwitchCostPerLevel = 400, -- later switches cost Base Lv x this many Doubloons (the first one is free)
	GrandLineLevel = 70, -- level required to climb Backflow Peak
	GrandLineOpen = false, -- opens in the next update
	StartBeli = 1000,
	InventorySlots = 100,

	-- ===== Refining =====
	Refine = {
		Max = 15,
		Safe = 4,
		-- success chance going from +N to +N+1 (index = N+1)
		Chance = { 1, 1, 1, 1, 0.6, 0.5, 0.4, 0.3, 0.2, 0.15, 0.1, 0.09, 0.08, 0.06, 0.05 },
		BreakFrom = 10, -- from +10, a failure may break the item
		BreakChance = 0.35,
		AtkPerRefine = 0.06, -- +6% weapon ATK per level (multiplies grade)
		DefPerRefine = 1.5,
	},

	-- ===== Ships =====
	Ship = {
		GridSize = 4,
		PlotSize = Vector3.new(9, 6, 21), -- shipyard plot cells X,Y,Z
		MaxParts = 140,
		MaxSpeed = 78,
		WeightDrag = 0.085,
		BaseTurnRate = 0.7, -- radians/second
		BaseCrewCapacity = 2,
		CrewCost = 800,
		ReloadTime = 3.2,
		CannonballSpeed = 180,
		SplashRadius = 16,
		SinkRepairPct = 0.15,
		DockRange = 110,
	},

	-- ===== PvP / Guild =====
	PvPMinLevel = 20,
	GuildCreateCost = 50000,
	GuildCreateLevel = 20,
	GuildMaxMembers = 30,
	GuildWar = {
		-- server time (UTC): Saturday 13:00 UTC
		Schedule = { { wday = 7, hour = 13, minute = 0 } },
		Duration = 45 * 60,
		CoreHP = 60000,
	},

	-- ===== Market =====
	Market = {
		TaxRate = 0.02,
		MaxStallItems = 6,
		ShipwrightStallItems = 12,
		MaxPrice = 999999999,
	},

	-- ===== Auto Battle =====
	AutoBattle = {
		SearchRadius = 90,
		LeashRadius = 160,
	},

	-- ===== Swimming =====
	-- You can swim, but only so far: run out of breath and the waves carry you back ashore. Ships are still the way
	-- to cross the sea. The server enforces BreathSeconds, so exploiters cannot swim forever.
	Swim = {
		Speed = 12,
		BreathSeconds = 45,
		SurfaceOffset = 1.4, -- root part sits this far below the sea surface (head above water)
		JumpOutVelocity = 58, -- enough to climb onto a dock
	},

	RespawnTime = 5,
}
