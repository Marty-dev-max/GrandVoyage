-- GameConfig: core constants. Tune game balance here.
return {
	GameName = "LarpTales: Voxel Seas", -- player-facing name (v0.24.9, owner); code/files/DataStores keep the GrandVoyage names
	LogoLines = { "LARPTALES", "VOXEL SEAS" },
	LogoImage = 133908417032160, -- v0.25.87: pixel logo board floating behind the menu character (tools/gen_logo.py); nil = text logo
	-- bump on every change: shown bottom-right in game and printed in Output, so you can tell which code is running
	Version = "0.1.8-remake",
	SagaName = "Azure East Saga",
	-- title menu UPDATE LOG lines (newest first, at most 6: more ran off the top of the screen, v0.25.156)
	UpdateNotes = {
		"New characters pick an Origin (5) and a starting weapon (6); races give stat points",
		"Damage types: Slash, Blunt, Pierce, Element. Monsters show weak (+) and resist (-)",
		"New stats: Vitality, Endurance, Willpower, Weaponry, Martial Arts, Fruit Mastery (300 cap)",
		"Parkour: climb, wall run, ledge hang, vault, slide, roll",
		"HP / SP / EXP are slim tubes; hotbar hides when calm",
		"Hold F to block, tap F just before a hit to parry",
	},
	DataStoreName = "GV_Player_r1",
	GuildStoreName = "GV_Guild_r1",
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
	-- + WillPerWil x Willpower (capped at WillMax; remake: was LUK) to get up at once with WillHp of max HP
	Knockdown = { Enabled = true, RecoverSeconds = 14, StandAt = 0.1, ExecuteWindup = 4, ReviveHold = 3, ReviveHp = 0.3,
		WillBase = 0.1, WillPerWil = 0.005, WillMax = 0.6, WillHp = 0.5 },
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
	-- v0.25.123 (owner, Plan-Weapons-v2 section 0): the General Store shows ONE random blade for a small fee, you BUY or
	-- PASS without being told its tier (only its color). Mostly Forty Fathoms (green), sometimes Twenty Tides (blue).
	-- v0.25.129 (owner): Marines are paid (Salary[rank + 1], rank = Marine titles met by merit) and cuff downed pirates
	-- with Seastone gear into the Conch Bay Brig (MarineService)
	Marine = {
		SalaryEvery = 600,
		Salary = { 300, 450, 650, 900, 1200, 1600, 2100, 2800, 3600, 4600, 6000, 8000, 10000 },
		CuffHold = 2,
		JailBase = 60, JailPerBounty = 1 / 5000, JailMax = 300, -- seconds in the Brig: 60 + bounty / 5000, max 5 min
		ArrestMerit = 25, ArrestBountyShare = 0.1,
	},
	BladeRoll = { Fee = 250, TideChance = 0.06, Seconds = 120 },
	-- v0.25.124: random blade drops (Plan-Weapons-v2): green from monsters of MobLevel+, blue from MVP bosses
	BladeDrop = { MobChance = 0.002, MobLevel = 8, BossChance = 0.12 },
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
		MaxParts = 320, -- v0.25.150: the Galleon preset is ~250 parts
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
	Dash = { Cooldown = 1.0, Speed = 120, Duration = 0.14 }, -- v0.25.26: faster, shorter burst; remake R1: 1 s cooldown, stamina (Stamina.Dash) is the real limit
	-- v0.25.89 (owner): double-tap W to run (Controllers/Sprint): WalkSpeed = BaseSpeed x Mult while W stays held
	Sprint = { Mult = 1.55, TapWindow = 0.3, Fov = 6 },
	-- remake (owner): no Auto Battle (the HUD switch is gone, T does nothing); F1 / F2 auto potions stay
	AutoBattle = false,
	-- remake HUD: the hotbar fades out after this many calm seconds (no fight, no key, no click)
	HotbarFade = { Calm = 5, Touch = 0.55 },
	-- ===== Remake R1 core feel (docs/Plan-Movement-Combat-v3.md sec 3-4; Controllers/Stamina + Guard, Services/GuardService) =====
	-- Stamina (client-side, movement only): dash, sprint, climbing / wall running later. Empty = no dash, sprint stops.
	Stamina = { Max = 100, Regen = 30, RegenDelay = 0.8, Dash = 22, SprintPerSec = 8 },
	-- Remake R1 attributes (Formulas.StatNames): Start points at Lv1 + PerLevel each level, 1 point per +1, one attribute
	-- caps at MaxStat, all six together at MaxTotal. Endurance adds StaminaPerEnd max Stamina and RegenPerEnd x regen.
	Stats = { Start = 6, PerLevel = 3, MaxStat = 100, MaxTotal = 300, StaminaPerEnd = 1, RegenPerEnd = 0.006 },
	-- Block (hold F): blows from the front deal BlockMult and fill Posture; full Posture = guard break (stunned).
	-- Parry: a blow landing within ParryWindow (+ ParryGrace for ping) of pressing F does nothing and stuns the
	-- attacker; pressing again within ParryCooldown gives no parry window (no spamming).
	Guard = { BlockMult = 0.3, FrontDot = 0.2, WalkMult = 0.55, ParryWindow = 0.2, ParryGrace = 0.12, ParryCooldown = 0.7,
		ParryStun = 1.0, ParryStunBoss = 0.45, ParryStunPvP = 0.6, ParryHeal = 25,
		PostureMax = 100, PostureFlat = 8, PostureK = 1.6, PostureBoss = 1.5, PostureDrain = 22, DrainDelay = 1.2,
		BreakStun = 1.2 },
	-- Dash i-frames: blows that land within IFrames (+ Grace for ping) of a dash miss ("DODGE")
	Dodge = { IFrames = 0.15, Grace = 0.12 },
	-- Fall damage (owner: a very high fall knocks you down, it never kills outright): drops above Safe studs cost
	-- PerStud x max HP per stud (capped at Max); DownAt or more = knocked down. Bounce (rubber) users take none.
	Fall = { Safe = 24, PerStud = 0.011, Max = 0.9, DownAt = 110, FallVel = 6 },
	-- hit edges (owner: thin red gradient, "just visible", no blood): alpha from damage / max HP, fades in Fade s
	HurtEdge = { Strongest = 0.45, Weakest = 0.85, Fade = 0.4 },
	-- Parkour (remake R1, S1-S7 + S10; Controllers/Parkour, server checks in GuardService). Speeds in studs/s, costs in stamina.
	-- Space in the air at a wall = climb (W up, S down, A/D sideways, Space = flip off), beside a wall while running fast
	-- = wall run (Space = jump off, chain to the next wall), falling past a ledge while pushing into the wall = hang
	-- (W / Space = climb up, S = let go). Space into a low wall = vault (running into it vaults by itself).
	-- Ctrl while running = slide (Space = slide jump). Dash key just before landing a big fall = roll (less damage).
	Parkour = {
		ClimbSpeed = 11, ClimbSide = 8, ClimbPerSec = 16, ClimbStart = 8,
		WallRunTime = 1.2, WallRunPerSec = 18, WallRunUp = 7, WallRunMinSpeed = 20,
		WallJumpOut = 30, WallJumpUp = 44, WallJumpCarry = 0.35,
		HangPerSec = 4, MantleTime = 0.38,
		VaultMin = 1.3, VaultMax = 4.8, VaultTime = 0.4, VaultDepth = 6, VaultReach = 3.2,
		SlideCost = 12, SlideTime = 0.8, SlideBoost = 1.45, SlideJump = 1.15,
		RollWindow = 0.8, RollMult = 0.35, RollDownMult = 1.6, RollNear = 18, RollLead = 0.3, RollFall = 75, RollAuto = 90, -- RollFall: landing speed (studs/s) that counts as a fall (a plain jump lands at ~56); RollAuto: running fast rolls by itself above it
		GrabGrace = 0.6, -- the server skips a fall that ends on a wall grab (checked: a wall within GrabWall studs)
		GrabWall = 4.5,
	},
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
