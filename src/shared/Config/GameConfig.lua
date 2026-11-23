-- GameConfig: core constants. Tune game balance here.
return {
	GameName = "LarpTales: Voxel Seas", -- player-facing name (v0.24.9, owner); code/files/DataStores keep the GrandVoyage names
	LogoLines = { "LARPTALES", "VOXEL SEAS" },
	LogoImage = 133908417032160, -- v0.25.87: pixel logo board floating behind the menu character (tools/gen_logo.py); nil = text logo
	-- bump on every change: shown bottom-right in game and printed in Output, so you can tell which code is running
	Version = "0.25.106",
	SagaName = "Azure East Saga",
	-- title menu UPDATE LOG lines (newest first, keep 3-4 short ones)
	UpdateNotes = {
		"Store fits every screen, egg models in the Bag",
		"Every weapon grade has its own look",
		"Shipyard rebuilt: free camera, part cards",
		"All 6 Cursed Fruits reworked",
		"Hunts, Toki and skill sets",
	},
	DataStoreName = "GV_Player_v1",
	GuildStoreName = "GV_Guild_v1",
	AutoSaveInterval = 120,

	-- every avatar is reset to the same R15 proportions + default body parts (face/hair/clothes kept); needs the
	-- experience's Avatar type set to R15 in Game Settings
	NormalizeAvatars = true,
	-- every player's avatar in the voxel style: cube head with their face, blocky body, hair/hats rebuilt from blocks
	VoxelAvatars = true,
	-- v0.24.0 (owner): title menu with PLAY / CHARACTER, character slots and a voxel character creator
	-- (Config/Looks). Players spawn only after Play, built from their slot's look (VoxelAvatars then no longer applies).
	TitleMenu = true,

	-- ===== Day / night (client Controllers/Atmos.lua; same clock on every client via server time) =====
	DayNight = {
		CycleMinutes = 24, -- one full day
		DayShare = 0.7, -- 70% of the cycle is daytime (06:00-18:00), nights pass faster
	},

	-- ===== Sea / sailing lane =====
	SeaLevel = 0,
	Lane = {
		HalfWidth = 2000, -- |Z| <= this = full wind (v0.25.11: wide sea, islands spread north/south)
		EdgeWidth = 160, -- edge zone, wind fades (warning)
		-- |Z| > HalfWidth + EdgeWidth = Doldrums (no wind + Leviathans)
	},
	World = {
		MinX = -1400,
		MaxX = 13400,
		HalfZ = 3800,
	},
	-- v0.25.14 (owner): lethal monster hits knock you down; monsters execute, allies interrupt or revive
	-- v0.25.25 (owner): downed = ragdoll; HP creeps back and you get up at StandAt (RecoverSeconds from 1 HP)
	-- v0.25.33 (owner): ExecuteWindup 4 s; WILL POWER = the downed player presses E once per knockdown: chance WillBase
	-- + WillPerLuk x LUK (capped at WillMax) to get up at once with WillHp of max HP
	Knockdown = { Enabled = true, RecoverSeconds = 14, StandAt = 0.1, ExecuteWindup = 4, ReviveHold = 3, ReviveHp = 0.3,
		WillBase = 0.1, WillPerLuk = 0.005, WillMax = 0.6, WillHp = 0.5 },
	CalmBelt = {
		SeaKingSpawnInterval = 4, -- seconds
		MaxSeaKingsPerShip = 5,
		SeaKingDamagePerHit = 90,
		WindFactor = 0, -- sails do nothing in the Doldrums
	},

	-- ===== Levels =====
	MaxBaseLevel = 70, -- Azure East level cap
	MaxJobLevel = 40,
	-- M1 strings (v0.25.6, owner): every basic attack is a 4-hit string; hits 1-3 come at Quick x the attack interval,
	-- the 4th is the knockback finisher and is followed by End x the interval (same damage per second overall)
	M1 = { Hits = 4, Quick = 0.55, End = 2.0, Reset = 1.2 }, -- v0.25.8: faster strings (owner), avg 0.91x interval
	JobChangeLevel = 5, -- Job Lv needed before your first class switch (v0.25.4, owner: was 10, too grindy at Lv4)
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
	-- v0.25.105 Ascend (evolve) at the Blacksmith: a weapon at NeedRefine[its rarity] climbs one rarity, refine back to +0.
	-- Owner's table: green +10 -> blue, blue +12 -> purple, purple +15 -> gold, gold +15 (+ trial) -> Eclipsed.
	-- This update stops at Rare (blue); MaxRarity moves up with the next updates.
	Ascend = {
		From = "Uncommon",
		MaxRarity = "Rare",
		NeedRefine = { Uncommon = 10, Rare = 12, Epic = 15, Legendary = 15 },
		AtkStep = 0.6, -- +60% weapon ATK/MATK per step
		MaxSlots = 4,
		Cost = {
			Uncommon = { beli = 25000, PureTidecore = 2 },
			Rare = { beli = 120000, PureTidecore = 5 },
			Epic = { beli = 500000, PureTidecore = 12 },
			Legendary = { beli = 2000000, PureTidecore = 25 },
		},
	},

	-- ===== Ships =====
	Ship = {
		GridSize = 4,
		PlotSize = Vector3.new(9, 6, 21), -- shipyard plot cells X,Y,Z
		MaxParts = 140,
		MaxSpeed = 78,
		WeightDrag = 0.04, -- v0.25.93 (owner): speed comes mostly from sails, weight matters less
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
		SearchRadius = 90, -- the default; each player can set their own between MinRadius and SearchRadius
		MinRadius = 15,
		LeashRadius = 160,
	},
	-- Dash (Q): a quick burst in the direction you move (or face); the server enforces the cooldown
	Dash = { Cooldown = 2.5, Speed = 120, Duration = 0.14 }, -- v0.25.26: faster, shorter burst + hard stop (~same distance)
	-- v0.25.89 (owner): double-tap W to run (Controllers/Sprint): WalkSpeed = BaseSpeed x Mult while W stays held
	Sprint = { Mult = 1.55, TapWindow = 0.3, Fov = 6 },
	-- hotbar: 12 skill slots (keys 1-6, then 7 8 9 0 - =) and 8 quick item slots (F1-F8); empty slot = ""
	SkillBarSize = 6, -- v0.25.71: E R F Z X C = the 6 skills of the picked set (Shared/Modules/SkillSets)
	ItemBarSize = 8,

	-- ===== Swimming =====
	-- You can swim, but only so far: run out of breath and the waves carry you back ashore. Ships are still the way
	-- to cross the sea. The server enforces BreathSeconds, so exploiters cannot swim forever.
	Swim = {
		Speed = 12,
		-- v0.22.4 diving: breath only runs out UNDER the surface; swimming on top is limited by SeaSeconds instead
		-- (you still cannot swim from island to island: sail)
		BreathSeconds = 30,
		SeaSeconds = 90,
		MaxDepth = 40, -- studs below the surface
		DiveSpeed = 11,
		RiseSpeed = 13,
		Buoyancy = 2.5, -- drift back up when you let go
		SeaFloorY = -44, -- the island bases reach down to here
		SurfaceOffset = 1.4, -- root part sits this far below the sea surface (head above water)
		JumpOutVelocity = 58, -- enough to climb onto a dock
	},

	RespawnTime = 5,
}
