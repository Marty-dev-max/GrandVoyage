-- Classes: sea-faring jobs (different from Ragnarok: each one maps to a role aboard a ship)
-- hpMod/spMod = HP/SP multipliers, weapons = usable weapon types
-- skill.kind: Melee | Ranged | AoE | GroundAoE | Heal | PartyHeal | Buff | PartyBuff | ShipBuff | ShipRepair
local Classes = {
	-- Basic sailor skills every class can learn and use (not a selectable class)
	Common = {
		name = "Sailor Basics",
		tier = -1,
		hidden = true,
		hpMod = 1.0,
		spMod = 1.0,
		weapons = {},
		color = Color3.fromRGB(220, 220, 220),
		icon = "⚓",
		skills = {
			{ id = "FirstAid", name = "First Aid", kind = "Heal", sp = 5, cd = 6, range = 0, power = 30, maxLevel = 3, desc = "Patch yourself up." },
			-- v0.24.0 (owner): the starter attack skill. A heavy punch for every class, a heavy kick for kick fighters
			-- (Sea Cook / Shoes); `heavy` picks the clip by weapon (AnimClips.HeavyFor). id stays "Bash" for old saves.
			{ id = "Bash", name = "Heavy Attack", heavy = true, kind = "Melee", sp = 6, cd = 3, range = 9, mult = 1.6, maxLevel = 5, fx = "Smash", desc = "A heavy blow: a big punch, or a big kick for kick fighters." },
		},
	},
	-- Everyone starts as a Brawler. At Job Lv.10 you may switch class at a Job Master, or stay a Brawler for good.
	Brawler = {
		name = "Brawler",
		desc = "Fists and knuckles. Fast combos up close. Every voyage starts here, and true fighters never leave.",
		tier = 1,
		starter = true,
		hpMod = 1.2,
		spMod = 0.9,
		weapons = { "Knuckles" },
		color = Color3.fromRGB(235, 85, 70), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "STR", role = "Street Fighter", build = { STR = 5, AGI = 3, VIT = 3, DEX = 1 },
		icon = "👊",
		skills = {
			{ id = "JabRush", name = "Jab Rush", anim = "Brawler_Flurry", kind = "Melee", sp = 8, cd = 3, range = 9, mult = 1.9, maxLevel = 10, fx = "Burst", desc = "A flurry of quick jabs." },
			{ id = "RisingUppercut", name = "Rising Uppercut", anim = "Brawler_Uppercut", kind = "Melee", sp = 14, cd = 5, range = 9, mult = 2.6, maxLevel = 10, fx = "Smash", desc = "Launch the enemy skyward." },
			{ id = "GroundPound", name = "Ground Pound", kind = "AoE", sp = 18, cd = 8, range = 0, radius = 12, mult = 1.7, maxLevel = 10, fx = "Explosion", desc = "Punch the ground: shockwave around you." },
			{ id = "IronFist", name = "Iron Fist", kind = "Buff", sp = 22, cd = 30, duration = 15, buff = { atk = 0.2, aspd = 0.15 }, maxLevel = 5, fx = "AuraFire", desc = "ATK and attack speed up." },
		},
	},
	Swordsman = {
		name = "Swordsman",
		desc = "Front-line melee. Tough, high damage, can cut at range with blade waves.",
		tier = 1,
		hpMod = 1.35,
		spMod = 0.8,
		weapons = { "Sword" },
		color = Color3.fromRGB(90, 200, 120), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "AGI", role = "Blade Dancer", build = { STR = 5, VIT = 3, AGI = 2, DEX = 1 },
		ringColor = Color3.fromRGB(60, 215, 235), -- Job EXP ring half (green is taken by Base EXP)
		icon = "⚔️",
		skills = {
			{ id = "OniSlash", name = "Demon Cross", kind = "Melee", sp = 12, cd = 4, range = 10, mult = 2.4, maxLevel = 10, fx = "CrossSlash", desc = "Two crossing cuts." },
			{ id = "TornadoCut", name = "Tornado Cut", kind = "AoE", sp = 20, cd = 8, range = 0, radius = 14, mult = 1.7, maxLevel = 10, fx = "Tornado", desc = "Spin and slash everything nearby." },
			{ id = "FlyingSlash", name = "Flying Slash", kind = "Ranged", sp = 15, cd = 5, range = 40, mult = 1.9, maxLevel = 10, fx = "WaveSlash", desc = "Launch a blade wave." },
			{ id = "IronBody", name = "Iron Body", kind = "Buff", sp = 25, cd = 30, duration = 15, buff = { def = 0.35 }, maxLevel = 5, fx = "AuraGreen", desc = "Harden your body: DEF up." },
		},
	},
	Sniper = {
		name = "Sharpshooter",
		desc = "Long-range crits. Born to man the cannons.",
		tier = 1,
		hpMod = 0.95,
		spMod = 1.0,
		weapons = { "Slingshot" },
		color = Color3.fromRGB(70, 185, 240), -- v0.25.38: DEX (sky blue; Sea Cook is the deeper blue)
		mtype = "DEX", role = "Deadeye", build = { DEX = 5, AGI = 3, LUK = 2 },
		icon = "🎯",
		passive = { cannonDamage = 0.15 },
		skills = {
			{ id = "LeadPellet", name = "Lead Pellet", kind = "Ranged", sp = 8, cd = 2.5, range = 55, mult = 1.7, maxLevel = 10, fx = "Bullet", desc = "A fast, heavy shot." },
			{ id = "BlazeShot", name = "Blaze Shot", kind = "Ranged", sp = 22, cd = 7, range = 60, mult = 2.6, maxLevel = 10, fx = "Firebird", desc = "A shot that bursts into a flaming bird." },
			{ id = "SmokePellet", name = "Smoke Pellet", kind = "GroundAoE", sp = 18, cd = 10, range = 45, radius = 15, mult = 1.3, maxLevel = 10, fx = "Smoke", desc = "Choking cloud on the ground." },
			{ id = "EagleEye", name = "Eagle Eye", kind = "Buff", sp = 25, cd = 30, duration = 20, buff = { crit = 20 }, maxLevel = 5, fx = "AuraYellow", desc = "CRIT up." },
		},
	},
	Cook = {
		name = "Sea Cook",
		desc = "A kick-fighting cook: kicks only, plus meals that heal and buff the crew.",
		tier = 1,
		hpMod = 1.15,
		spMod = 1.0,
		weapons = { "Shoes" },
		color = Color3.fromRGB(80, 120, 230), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "DEX", role = "Kick Chef", build = { AGI = 4, STR = 4, VIT = 2, LUK = 1 },
		icon = "🍳",
		skills = {
			{ id = "HookKick", name = "Hook Kick", kind = "Melee", sp = 10, cd = 3, range = 9, mult = 2.1, maxLevel = 10, fx = "Kick", desc = "A snapping kick to the neck." },
			{ id = "BanquetKick", name = "Banquet Spin", kind = "AoE", sp = 18, cd = 7, range = 0, radius = 13, mult = 1.6, maxLevel = 10, fx = "SpinKick", desc = "Handstand spin kick." },
			{ id = "HeatedLeg", name = "Searing Leg", kind = "Buff", sp = 25, cd = 30, duration = 15, buff = { atk = 0.25 }, maxLevel = 5, fx = "AuraFire", desc = "ATK up." },
			{ id = "HeartyMeal", name = "Hearty Meal", kind = "PartyHeal", sp = 30, cd = 20, radius = 30, power = 120, maxLevel = 5, fx = "Food", desc = "Feed the crew nearby." },
		},
	},
	Navigator = {
		name = "Navigator",
		-- v0.25.51 (owner: too strong for a first job, storms from day one + a mid-range basic attack): a sailor who
		-- fights up close with the folding baton and tricks; the storms come back with the Storm Caller second job
		desc = "Reads the sea and wind. Fights up close with a folding baton and tricks. Speeds up your ship.",
		tier = 1,
		hpMod = 0.95,
		spMod = 1.15,
		weapons = { "StormBaton" },
		color = Color3.fromRGB(150, 90, 240), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "INT", role = "Trickster", build = { INT = 5, DEX = 3, VIT = 2 }, -- v0.25.52: INT again (owner: matches its type)
		icon = "🧭",
		passive = { shipSpeed = 0.1 },
		skills = {
			{ id = "BatonFlurry", name = "Baton Flurry", kind = "Melee", sp = 10, cd = 4, range = 9, mult = 0.75, hits = 3, slow = 0.6, magic = true, maxLevel = 10, fx = "Burst", desc = "Three quick raps with the folding baton. Dazed enemies slow down." },
			{ id = "TrickVault", name = "Trick Vault", kind = "Dash", sp = 12, cd = 7, range = 18, mult = 1.6, magic = true, maxLevel = 10, fx = "Burst", desc = "Plant the baton and vault forward, kicking through everything in your way." },
			{ id = "MirageVeil", name = "Mirage Veil", kind = "Buff", sp = 20, cd = 30, duration = 15, buff = { flee = 40 }, maxLevel = 5, fx = "AuraBlue", desc = "FLEE up." },
			{ id = "Tailwind", name = "Tailwind", kind = "ShipBuff", sp = 30, cd = 60, duration = 30, buff = { shipSpeed = 0.25 }, maxLevel = 5, fx = "Wind", desc = "Ship speed +25%." },
		},
	},
	Doctor = {
		name = "Doctor",
		desc = "Healer and party buffer who throws medicinal powders: healing dust for friends, stinging dust for foes.",
		tier = 1,
		hpMod = 1.0,
		spMod = 1.3,
		weapons = { "MedKit" },
		color = Color3.fromRGB(214, 96, 214), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "INT", role = "Field Medic", build = { INT = 5, VIT = 3, DEX = 2 },
		icon = "💉",
		skills = {
			{ id = "Heal", name = "Field Medicine", kind = "PartyHeal", sp = 18, cd = 4, radius = 35, power = 160, maxLevel = 10, fx = "Heal", desc = "Heal nearby crew." },
			{ id = "Scalpel", name = "Scalpel Toss", kind = "Ranged", sp = 8, cd = 2.5, range = 40, mult = 1.5, maxLevel = 10, fx = "Bullet", desc = "Throw a scalpel." },
			{ id = "Adrenaline", name = "Adrenaline Shot", kind = "PartyBuff", sp = 35, cd = 40, radius = 35, duration = 30, buff = { aspd = 0.2, atk = 0.1 }, maxLevel = 5, fx = "AuraPink", desc = "Party attack speed and ATK up." },
			{ id = "BurstTonic", name = "Burst Tonic", kind = "AoE", sp = 25, cd = 10, radius = 12, mult = 1.8, maxLevel = 10, fx = "Burst", desc = "An explosive flask." },
		},
	},
	Shipwright = {
		name = "Shipwright",
		desc = "Utility crafter. Repairs ships mid-battle, bigger stalls, better refine odds.",
		tier = 1,
		hpMod = 1.25,
		spMod = 0.9,
		weapons = { "Hammer" },
		color = Color3.fromRGB(214, 112, 58), -- v0.25.37: the color of its type (Config/MonsterTypes)
		mtype = "STR", role = "Hammer Smith", build = { STR = 4, VIT = 4, DEX = 2 },
		ringColor = Color3.fromRGB(225, 160, 95),
		icon = "🔨",
		passive = { refineBonus = 0.05, stallSlots = true, cannonDamage = 0.05 },
		skills = {
			{ id = "HammerSmash", name = "Hammer Smash", kind = "Melee", sp = 12, cd = 4, range = 9, mult = 2.3, maxLevel = 10, fx = "Smash", desc = "A crushing overhead blow." },
			{ id = "CannonDrop", name = "Cannonball Drop", kind = "GroundAoE", sp = 22, cd = 8, range = 40, radius = 13, mult = 1.9, maxLevel = 10, fx = "Explosion", desc = "Drop a live cannonball." },
			{ id = "FieldRepair", name = "Field Repair", kind = "ShipRepair", sp = 30, cd = 20, power = 0.12, maxLevel = 5, fx = "Repair", desc = "Repair the ship you stand on." },
			{ id = "SteelFrame", name = "Steel Frame", kind = "Buff", sp = 25, cd = 30, duration = 20, buff = { def = 0.25, atk = 0.1 }, maxLevel = 5, fx = "AuraGreen", desc = "DEF and ATK up." },
		},
	},
}

-- Second jobs (Grand Current update)
local SecondJobs = { -- planned paths (docs/Plan-Job2.md, owner picks 22 Nov 2026); shown in Skills -> Next
	Brawler = { "IronChampion", "StormFist" },
	Swordsman = { "BladeSaint", "TwinFang" },
	Sniper = { "Deadeye", "TrickShooter" },
	Cook = { "EmberKicker", "BarrelRoller" },
	Navigator = { "StormCaller", "TideDancer" },
	Doctor = { "MiracleDoctor", "Alchemist" },
	Shipwright = { "Ironclad", "SilentChisel" },
}

local skillById = {}
for classId, c in pairs(Classes) do
	c.id = classId
	for _, s in ipairs(c.skills) do
		s.class = classId
		skillById[s.id] = s
	end
end

-- fruit skills live in Config/Fruits but share the skill table (class = "Fruit")
local Fruits = require(script.Parent.Fruits)
for _, f in ipairs(Fruits.List) do
	for _, s in ipairs(f.skills) do
		skillById[s.id] = s
	end
end

return {
	Classes = Classes,
	SecondJobs = SecondJobs,
	SkillById = skillById,
	FirstJobs = { "Brawler", "Swordsman", "Sniper", "Cook", "Navigator", "Doctor", "Shipwright" },
	StarterClass = "Brawler",
}
