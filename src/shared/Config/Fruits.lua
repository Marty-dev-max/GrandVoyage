-- Cursed Fruits ("<Word> <Word> no Mi"). Original names and designs.
-- A fruit is a power layer on top of your class: eat one, then grow its Fruit Mastery (Lv1-100) by using its skills.
-- Skills unlock at Mastery 1 / 10 / 25 / 50. Damage scales with the better of your ATK and MATK, so every class can use any fruit.
-- Fruit users cannot swim. Marine attacks in PvP can apply Seastone, which shuts fruit powers off for a few seconds.
-- Skills use the normal skill format (see Config/Classes); extra fields: hits = multi-hit count, Dash kind = dash forward.
local F = {}

F.List = {
	{
		id = "Bounce", name = "Bounce Bounce no Mi", type = "Paramecia", rarity = "Secret", weight = 2,
		color = Color3.fromRGB(255, 120, 200), swirl = Color3.fromRGB(150, 60, 220), icon = "🍇",
		desc = "Your body turns to rubber: stretch, bounce, and shrug off blunt hits.",
		passive = { defPct = 0.15, maxHpPct = 0.1 }, passiveText = "Rubber body: +15% DEF, +10% Max HP",
		skills = {
			{ id = "F_StretchPistol", name = "Stretch Pistol", kind = "Ranged", sp = 10, cd = 3, range = 32, mult = 2.3, mastery = 1, fx = "Burst", desc = "A stretching long-range punch." },
			{ id = "F_BounceGatling", name = "Bounce Gatling", kind = "Melee", sp = 18, cd = 6, range = 12, mult = 0.75, hits = 5, mastery = 10, fx = "Burst", desc = "A storm of rubber punches." },
			{ id = "F_BalloonBody", name = "Balloon Body", kind = "Buff", sp = 20, cd = 25, duration = 12, buff = { def = 0.5 }, mastery = 25, fx = "AuraPink", desc = "Inflate: DEF way up." },
			{ id = "F_GearUp", name = "Gear Up", kind = "Buff", sp = 35, cd = 45, duration = 18, buff = { atk = 0.35, aspd = 0.3 }, mastery = 50, fx = "AuraFire", desc = "Pump your blood: ATK and attack speed way up." },
		},
	},
	{
		id = "Blaze", name = "Blaze Blaze no Mi", type = "Logia", rarity = "Mythic", weight = 6,
		color = Color3.fromRGB(255, 110, 40), swirl = Color3.fromRGB(255, 220, 80), icon = "🔥",
		desc = "Become fire itself. Attacks often pass right through you.",
		passive = { flee = 25, atkPct = 0.05 }, passiveText = "Logia body: +25 FLEE, +5% ATK",
		skills = {
			{ id = "F_FireFist", name = "Fire Fist", kind = "Ranged", sp = 14, cd = 4, range = 48, mult = 2.6, mastery = 1, fx = "Firebird", desc = "Hurl a fist of flame." },
			{ id = "F_FlamePillar", name = "Flame Pillar", kind = "GroundAoE", sp = 22, cd = 8, range = 45, radius = 14, mult = 2.2, mastery = 10, fx = "Explosion", desc = "A column of fire erupts from the ground." },
			{ id = "F_FireDash", name = "Fire Dash", kind = "Dash", sp = 16, cd = 7, range = 26, mult = 1.8, mastery = 25, fx = "Burst", desc = "Rocket forward in flames, burning everything you pass." },
			{ id = "F_Inferno", name = "Inferno", kind = "AoE", sp = 40, cd = 20, radius = 20, mult = 3.0, mastery = 50, fx = "Explosion", desc = "Explode into a sea of fire." },
		},
	},
	{
		id = "Haze", name = "Haze Haze no Mi", type = "Logia", rarity = "Legendary", weight = 12,
		color = Color3.fromRGB(200, 205, 215), swirl = Color3.fromRGB(120, 125, 140), icon = "💨",
		desc = "Become smoke. Choke, blind and slip away.",
		passive = { flee = 25 }, passiveText = "Logia body: +25 FLEE",
		skills = {
			{ id = "F_SmokeGrip", name = "Smoke Grip", kind = "Ranged", sp = 12, cd = 4, range = 36, mult = 2.1, mastery = 1, fx = "Smoke", desc = "A smoke fist grabs and chokes." },
			{ id = "F_SmokeScreen", name = "Smoke Screen", kind = "GroundAoE", sp = 20, cd = 9, range = 40, radius = 16, mult = 1.5, mastery = 10, fx = "Smoke", desc = "A choking cloud." },
			{ id = "F_SmokeBody", name = "Smoke Body", kind = "Buff", sp = 22, cd = 30, duration = 15, buff = { flee = 50 }, mastery = 25, fx = "AuraBlue", desc = "Dissolve into smoke: FLEE way up." },
			{ id = "F_WhiteOut", name = "White Out", kind = "AoE", sp = 38, cd = 20, radius = 18, mult = 2.6, mastery = 50, fx = "Tornado", desc = "A smoke storm around you." },
		},
	},
	{
		id = "Ward", name = "Ward Ward no Mi", type = "Paramecia", rarity = "Epic", weight = 20,
		color = Color3.fromRGB(120, 220, 255), swirl = Color3.fromRGB(230, 250, 255), icon = "🛡️",
		desc = "Create unbreakable barriers to shield your crew.",
		passive = { defPct = 0.12 }, passiveText = "Barrier skin: +12% DEF",
		skills = {
			{ id = "F_BarrierBash", name = "Barrier Bash", kind = "Melee", sp = 10, cd = 3, range = 10, mult = 2.2, mastery = 1, fx = "Smash", desc = "Ram a barrier into the enemy." },
			{ id = "F_BarrierWall", name = "Barrier Wall", kind = "PartyBuff", sp = 24, cd = 25, radius = 30, duration = 12, buff = { def = 0.35 }, mastery = 10, fx = "AuraBlue", desc = "Shield the crew around you: DEF up." },
			{ id = "F_BarrierCrash", name = "Barrier Crash", kind = "Ranged", sp = 16, cd = 6, range = 34, mult = 2.4, mastery = 25, fx = "Bullet", desc = "Launch a barrier like a battering ram." },
			{ id = "F_BarrierDome", name = "Barrier Dome", kind = "PartyBuff", sp = 40, cd = 50, radius = 30, duration = 8, buff = { def = 0.7 }, mastery = 50, fx = "AuraGreen", desc = "An unbreakable dome: DEF massively up." },
		},
	},
	{
		id = "Split", name = "Split Split no Mi", type = "Paramecia", rarity = "Epic", weight = 25,
		color = Color3.fromRGB(110, 200, 120), swirl = Color3.fromRGB(240, 240, 120), icon = "✂️",
		desc = "Split your body into pieces. Blades pass between them.",
		passive = { flee = 12, maxHpPct = 0.05 }, passiveText = "Split body: +12 FLEE, +5% Max HP",
		skills = {
			{ id = "F_SplitCannon", name = "Split Cannon", kind = "Ranged", sp = 10, cd = 3, range = 40, mult = 2.2, mastery = 1, fx = "Bullet", desc = "Fire your fist across the field." },
			{ id = "F_ChopRush", name = "Chop Rush", kind = "Melee", sp = 16, cd = 6, range = 12, mult = 0.75, hits = 4, mastery = 10, fx = "Slash", desc = "Floating hands strike from all sides." },
			{ id = "F_SplitEscape", name = "Split Escape", kind = "Buff", sp = 20, cd = 28, duration = 12, buff = { flee = 40 }, mastery = 25, fx = "AuraGreen", desc = "Scatter your body: FLEE up." },
			{ id = "F_SplitFestival", name = "Split Festival", kind = "AoE", sp = 34, cd = 18, radius = 16, mult = 2.4, mastery = 50, fx = "Tornado", desc = "Every piece of you attacks at once." },
		},
	},
	{
		id = "Slick", name = "Slick Slick no Mi", type = "Paramecia", rarity = "Rare", weight = 35,
		color = Color3.fromRGB(255, 225, 120), swirl = Color3.fromRGB(255, 255, 220), icon = "✨",
		desc = "Your skin turns slippery: attacks slide right off.",
		passive = { flee = 15 }, passiveText = "Slippery skin: +15 FLEE",
		skills = {
			{ id = "F_SlickSlide", name = "Slick Slide", kind = "Dash", sp = 10, cd = 5, range = 22, mult = 1.5, mastery = 1, fx = "Burst", desc = "Slide forward, knocking enemies aside." },
			{ id = "F_SlipAway", name = "Slip Away", kind = "Buff", sp = 18, cd = 25, duration = 12, buff = { flee = 45 }, mastery = 10, fx = "AuraYellow", desc = "Nothing can grab you: FLEE way up." },
			{ id = "F_SlickSpin", name = "Slick Spin", kind = "AoE", sp = 18, cd = 8, radius = 11, mult = 1.6, mastery = 25, fx = "Tornado", desc = "Spin on the spot, sliding enemies away." },
			{ id = "F_OilSlick", name = "Oil Slick", kind = "GroundAoE", sp = 26, cd = 12, range = 40, radius = 15, mult = 1.9, mastery = 50, fx = "Smoke", desc = "Flood the ground with slippery oil." },
		},
	},
}

F.ById = {}
for _, f in ipairs(F.List) do
	F.ById[f.id] = f
	for _, s in ipairs(f.skills) do
		s.fruit = f.id
		s.class = "Fruit"
		s.maxLevel = 1
	end
end

-- Mastery: EXP per fruit-skill use, EXP needed for the next level = Base + PerLevel * level
F.Mastery = { Max = 100, ExpPerCast = 2, ExpPerKill = 6, Base = 20, PerLevel = 4, DamagePerLevel = 0.01 }

-- Drop chances (per event) and the natural fruit-tree spawn
F.Drops = {
	Ship = { [1] = 0.001, [2] = 0.003, [3] = 0.01 }, -- NPC ship sunk, by tier
	CaptainChest = 0.005,
	Boss = 0.02, -- MVP
	TreeInterval = 45 * 60, -- a fruit appears on a random island this often (per server)
	TreeLifetime = 15 * 60,
	AnnounceRank = 5, -- Legendary and above are announced server-wide
}

-- Fruit users sink: they last this long in the sea before the waves drag them ashore
F.SinkSeconds = 1.5
-- Seastone: Marine PvP hits have this chance to disable fruit skills for this long
F.Seastone = { Chance = 0.2, Seconds = 3 }

return F
