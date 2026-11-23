-- Cursed Fruits ("<Word> <Word> no Mi"). Original names and designs.
-- A fruit is a power layer on top of your class: eat one, then grow its Fruit Mastery (Lv1-100) by using its skills.
-- Skills unlock at Mastery 1 / 10 / 25 / 50. Damage scales with the better of your ATK and MATK, so every class can use any fruit.
-- Fruit users cannot swim. Marine attacks in PvP can apply Seastone, which shuts fruit powers off for a few seconds.
-- Skills use the normal skill format (see Config/Classes); extra fields: hits = multi-hit count, Dash kind = dash forward.
local F = {}

F.List = {
	{
		id = "Bounce", name = "Bounce Bounce no Mi", type = "Paramecia", rarity = "Secret", weight = 2,
		stats = { "STR", "VIT" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(175, 70, 215), swirl = Color3.fromRGB(255, 120, 190), icon = "🍇", -- v0.25.33: purple, pink inside
		desc = "Your body turns to rubber: stretch, bounce, and shrug off blunt hits.",
		-- v0.25.65 (owner, docs/Plan-Fruits-v2.md): Rubber Hide reflects gunshots (CombatService fruitBody), Slingshot
		-- Launch = hold RMB to aim + hold LMB to grab, release to fling yourself
		passive = { defPct = 0.15, maxHpPct = 0.1 }, passiveText = "Rubber Hide: bullets bounce back at the shooter • Slingshot Launch: hold right mouse to aim, hold left mouse to grab, let go to fling yourself (or hold U) • +15% DEF, +10% Max HP",
		skills = {
			{ id = "F_StretchPistol", name = "Stretch Pistol", kind = "Ranged", sp = 10, cd = 3, range = 32, mult = 2.3, charge = true, anim = "Bounce_Pistol", chargeAnim = "Bounce_Wind", pumped = { line = 4.5, range = 40 }, mastery = 1, fx = "Burst", desc = "Hold to wind the arm back, release: a stretching long-range punch." },
			{ id = "F_BounceGatling", name = "Bounce Gatling", kind = "Melee", sp = 18, cd = 6, range = 14, mult = 0.5, hits = 8, hitEvery = 0.07, pumped = { hits = 12, hitEvery = 0.045 }, anim = "Bounce_Gatling", mastery = 10, fx = "Burst", desc = "A storm of stretching rubber punches, too fast to see." },
			{ id = "F_RecoilCannon", name = "Recoil Cannon", kind = "Ranged", sp = 24, cd = 9, range = 24, mult = 3.2, charge = true, anim = "Bounce_Cannon", chargeAnim = "Bounce_WindBoth", splash = 8, knockDist = 26, knockPower = 3, pumped = { splash = 12, knockDist = 34 }, mastery = 25, fx = "Burst", desc = "Hold to stretch both arms far back, release: a two-palm blast that sends enemies flying." },
			{ id = "F_BalloonBody", name = "Balloon Body", kind = "Buff", sp = 20, cd = 25, duration = 12, buff = { def = 0.5 }, anim = "Bounce_Balloon", mastery = 35, fx = "AuraPink", desc = "Puff up like a balloon: DEF way up, and blunt blows and bullets from any side bounce back at the attacker." },
			{ id = "F_GearUp", name = "Pump Up", kind = "Buff", sp = 35, cd = 45, duration = 18, buff = { atk = 0.35, aspd = 0.3 }, anim = "Bounce_PumpUp", mastery = 50, fx = "AuraFire", desc = "Pump your blood: steam pours off you, ATK and attack speed way up, and every Bounce move turns into a blast of compressed air: faster, shorter cooldowns, and Slingshot Launch rockets you straight through enemies." },
		},
	},
	{
		id = "Blaze", name = "Blaze Blaze no Mi", type = "Logia", rarity = "Mythic", weight = 6,
		stats = { "INT", "DEX" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(255, 110, 40), swirl = Color3.fromRGB(255, 220, 80), icon = "🔥",
		desc = "Become fire itself. Attacks often pass right through you.",
		passive = { flee = 25, atkPct = 0.05 }, passiveText = "Flame Body (Logia): monsters without Toki pass right through you • Blaze Flight: hold Space • +25 FLEE, +5% ATK",
		skills = {
			{ id = "F_FireFist", name = "Blaze Fist", kind = "Ranged", sp = 14, cd = 4, range = 48, mult = 2.6, charge = true, anim = "Blaze_Fist", chargeAnim = "Blaze_Wind", mastery = 1, fx = "Firebird", desc = "Hold: the arm bursts into flame. Release: a giant fist of fire." },
			{ id = "F_FlamePillar", name = "Flame Twister", kind = "GroundAoE", sp = 22, cd = 8, range = 45, radius = 14, mult = 0.6, ticks = 5, tickEvery = 0.35, anim = "Blaze_Twister", mastery = 10, fx = "Tornado", desc = "A twister of fire spins up from the ground, burning again and again." },
			{ id = "F_Emberflies", name = "Emberflies", kind = "GroundAoE", sp = 18, cd = 9, range = 40, radius = 12, mult = 0.7, ticks = 4, tickEvery = 0.18, delay = 1.0, anim = "Blaze_Ember", mastery = 25, fx = "None", desc = "Green sparks drift onto your foes, then burst into fire, hit after hit." },
			-- v0.25.77 (owner): both arms up, a giant fireball grows (hold), then hurled the way you aim; bursts into a sea of fire
			{ id = "F_Inferno", name = "Inferno", kind = "Ranged", sp = 40, cd = 20, range = 50, mult = 2.4, splash = 18, travel = 0.4, charge = true, anim = "Blaze_BallThrow", chargeAnim = "Blaze_BallCharge", mastery = 50, fx = "None", desc = "Hold: a giant fireball grows over your head. Release: hurl it, and it bursts into a sea of fire." },
		},
	},
	{
		id = "Haze", name = "Haze Haze no Mi", type = "Logia", rarity = "Legendary", weight = 12,
		stats = { "INT", "AGI" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(200, 205, 215), swirl = Color3.fromRGB(120, 125, 140), icon = "💨",
		desc = "Become smoke. Choke, blind and slip away.",
		passive = { flee = 25 }, passiveText = "Smoke Body (Logia): monsters without Toki pass right through you • Smoke Flight: hold Space in the air • +25 FLEE",
		skills = {
			{ id = "F_SmokeFist", name = "Smoke Fist", kind = "Ranged", sp = 12, cd = 4, range = 44, mult = 2.4, charge = true, anim = "Blaze_Fist", chargeAnim = "Blaze_Wind", mastery = 1, fx = "Smoke", desc = "Hold to gather smoke in your fist, release: a heavy fist of smoke." },
			{ id = "F_SmokeScreen", name = "Smoke Screen", kind = "GroundAoE", sp = 20, cd = 9, range = 40, radius = 16, mult = 1.5, smoke = 6, delay = 0.3, anim = "Blaze_Fist", mastery = 10, fx = "None", desc = "Punch a fist of smoke at the spot you pick: it bursts into a choking cloud: for 6 s monsters inside it miss half their blows." },
			{ id = "F_SmokeGrip", name = "Smoke Grip", kind = "Ranged", sp = 16, cd = 7, range = 36, mult = 2.0, pull = true, anim = "Haze_Grip", mastery = 25, fx = "Smoke", desc = "A long arm of smoke coils around the enemy and drags it to you." },
			{ id = "F_WhiteOut", name = "White Out", kind = "AoE", sp = 38, cd = 20, radius = 18, mult = 0.55, ticks = 6, tickEvery = 0.4, vanish = 2.6, anim = "Haze_Vanish", mastery = 50, fx = "Tornado", desc = "You vanish into a whirling tornado of smoke: nothing can hit you while it spins." },
		},
	},
	{
		-- v0.25.65 (owner): renamed; id stays "Ward" (saves)
		id = "Ward", name = "Shield Shield no Mi", type = "Paramecia", rarity = "Epic", weight = 20,
		stats = { "VIT", "INT" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(120, 220, 255), swirl = Color3.fromRGB(230, 250, 255), icon = "🛡️",
		desc = "Create unbreakable barriers to shield your crew.",
		passive = { defPct = 0.12 }, passiveText = "Barrier Steps: jump and keep holding Space to build stairs of barrier under your feet • +12% DEF",
		skills = {
			{ id = "F_BarrierBash", name = "Ward Pistol", kind = "Ranged", sp = 10, cd = 3, range = 30, mult = 2.4, splash = 6, travel = 0.3, firstHit = true, charge = true, knockDist = 12, knockPower = 2.2, anim = "Blaze_Fist", chargeAnim = "Blaze_Wind", mastery = 1, fx = "None", desc = "Hold: a ball of barrier forms round your fist. Let go and punch it out: it bursts on the first enemy it meets (or where it stops), throwing everyone near it back." },
			-- v0.25.79 Channel skills (owner): HOLD the key = the barrier stands and SP drains each second; let go (or run out of
			-- SP / time) = it bursts outward. Auto / a tap holds it for TapHold seconds.
			{ id = "F_BarrierWall", name = "Barrier Wall", kind = "Channel", shape = "Wall", sp = 8, spPerSec = 7, maxHold = 6, cd = 10, mult = 1.8, pushRadius = 9, anim = "Shield_Hold", releaseAnim = "Bounce_Cannon", mastery = 10, fx = "None", desc = "Hold: a wall of barrier in front of you blocks every blow from that side (SP drains). Let go: it slams forward and knocks enemies back." },
			{ id = "F_GlassStairs", name = "Glass Stairway", kind = "Stairs", sp = 6, spPerStep = 1.5, cd = 12, maxSteps = 120, maxHold = 40, mult = 1.4, mastery = 25, fx = "None", desc = "Hold and drag the pointer: barrier steps build out wherever you drag (up into the sky, over the sea) for as long as your SP lasts. Steps that burst out under or into enemies hurt them. Anyone can walk on them for a while." },
			{ id = "F_BarrierDome", name = "Barrier Dome", kind = "Channel", shape = "Dome", radius = 14, sp = 12, spPerSec = 10, maxHold = 8, cd = 25, mult = 0.8, anim = "Shield_DomeHold", releaseAnim = "Skill_PowerUp", mastery = 50, fx = "None", desc = "Hold: a glass dome closes over you and your crew; nothing outside can hit anyone inside (SP drains). Let go: it bursts outward." },
		},
	},
	{
		id = "Split", name = "Split Split no Mi", type = "Paramecia", rarity = "Epic", weight = 25,
		stats = { "AGI", "DEX" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(110, 200, 120), swirl = Color3.fromRGB(240, 240, 120), icon = "✂️",
		desc = "Split your body into pieces. Blades pass between them.",
		passive = { flee = 12, maxHpPct = 0.05 }, passiveText = "Split Body: blades, claws and axes pass between your pieces • +12 FLEE, +5% Max HP",
		skills = {
			{ id = "F_SplitCannon", name = "Split Cannon", kind = "Ranged", sp = 10, cd = 3, range = 40, mult = 2.2, charge = true, mastery = 1, fx = "Bullet", desc = "Hold to wind up, release: your forearm flies off and punches across the field." },
			{ id = "F_ChopRush", name = "Chop Rush", kind = "Melee", sp = 16, cd = 6, range = 12, mult = 0.75, hits = 4, mastery = 10, fx = "Slash", desc = "Your hand flies off behind you and swoops back to stab, again and again." },
			{ id = "F_SplitRunner", name = "Split Runner", kind = "Dash", sp = 18, cd = 9, range = 26, mult = 1.9, mastery = 25, fx = "Burst", desc = "Your legs spin off as a wheel and run down everything in the way." },
			{ id = "F_SplitFestival", name = "Split Festival", kind = "AoE", sp = 34, cd = 18, radius = 16, mult = 0.45, ticks = 7, tickEvery = 0.3, mastery = 50, fx = "Tornado", desc = "Every piece of you whirls around in a wild circle, hitting over and over." },
		},
	},
	{
		id = "Slick", name = "Slick Slick no Mi", type = "Paramecia", rarity = "Rare", weight = 35,
		stats = { "AGI", "LUK" }, -- v0.25.69: main / second stat bonus, grows with Fruit Mastery (F.StatBonus)
		color = Color3.fromRGB(255, 225, 120), swirl = Color3.fromRGB(255, 255, 220), icon = "✨",
		desc = "Your skin turns slippery: attacks slide right off.",
		passive = { flee = 15 }, passiveText = "Slick Skate: hold Space to slide forward • +15 FLEE",
		skills = {
			{ id = "F_SlickSlide", name = "Slick Slide", kind = "Dash", sp = 10, cd = 5, range = 22, mult = 1.5, charge = true, mastery = 1, fx = "Burst", desc = "Hold to crouch down, release: slide forward into a punch." },
			{ id = "F_SlipAway", name = "Slip Away", kind = "Buff", sp = 18, cd = 25, duration = 12, buff = { flee = 45 }, mastery = 10, fx = "AuraYellow", desc = "Nothing can grab you: FLEE way up." },
			{ id = "F_SlickSpin", name = "Slick Spin", kind = "AoE", sp = 18, cd = 8, radius = 11, mult = 1.6, mastery = 25, fx = "Tornado", desc = "Drop into a handstand and spin-kick everything around you." },
			{ id = "F_OilSlick", name = "Oil Slick", kind = "GroundAoE", sp = 26, cd = 12, range = 40, radius = 15, mult = 1.9, mastery = 50, fx = "Smoke", desc = "Flood the ground with slippery oil." },
		},
	},
}

-- v0.25.69 (owner): every fruit adds to two attributes (the Bonus column of Stats), the main one up to +Main and the
-- second up to +Second: +1 per MainPer / SecondPer levels of Fruit Mastery (rounded up, so Mastery 1 already gives +1).
-- Damage still scales with max(ATK, MATK): the bonus only makes a fruit that suits your build stronger.
F.StatBonus = { Main = 10, MainPer = 10, Second = 5, SecondPer = 20 }
function F.StatsFor(fruitId, mastery)
	local f = F.ById[fruitId or ""]
	local out = {}
	if not f or not f.stats then
		return out
	end
	local m = math.max(0, mastery or 0)
	local B = F.StatBonus
	out[f.stats[1]] = math.min(B.Main, math.ceil(m / B.MainPer))
	out[f.stats[2]] = (out[f.stats[2]] or 0) + math.min(B.Second, math.ceil(m / B.SecondPer))
	return out
end

F.ById = {}
for _, f in ipairs(F.List) do
	F.ById[f.id] = f
	if f.stats then
		f.passiveText = f.passiveText .. " • +" .. f.stats[1] .. " / +" .. f.stats[2] .. " (grow with Mastery, up to +" .. F.StatBonus.Main .. " / +" .. F.StatBonus.Second .. ")"
	end
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

-- Slingshot Launch (Bounce passive, v0.25.66): hold right mouse to aim a spot, hold left mouse = both arms stretch out
-- and grab it, let go = fling yourself there (Controllers/Slingshot; server CombatService "Sling" checks it)
F.Channel = { TapHold = 2.5 } -- Channel skills cast from Auto Battle / a tap stand this long
-- Barrier Steps (Shield passive): one step under your feet each time you top out a jump with Space held, at most MaxSteps
-- before you touch the ground again; each fades after Life seconds
F.BarrierSteps = { MaxSteps = 14, Life = 3.5 }
-- v0.25.80 Glass Stairway (F_GlassStairs): one step every Run studs along the drag, each rising at most Rise; they last Life s
F.GlassStairs = { Run = 2.4, Rise = 1.3, Width = 5, Life = 12, Reach = 90 }
F.Slingshot = { Range = 70, MinDist = 8, Cooldown = 2.5, Speed = 95, GrabSeconds = 4,
	-- pumped (Pump Up running, v0.25.69): a straight rocket at PumpSpeed that ends PumpLift studs above the spot (so you
	-- do not slam into it) and keeps flying a little; everything in the way takes PumpMult x your attack
	PumpSpeed = 170, PumpLift = 5, PumpMult = 1.6, PumpCooldownMult = 0.5 }

-- Fruit users sink: they last this long in the sea before the waves drag them ashore
F.SinkSeconds = 1.5
F.DrownPerSecond = 0.07 -- fraction of max HP a fruit user loses every second under the sea (no wash-ashore)
-- Seastone: Marine PvP hits have this chance to disable fruit skills for this long
F.Seastone = { Chance = 0.2, Seconds = 3 }

return F
