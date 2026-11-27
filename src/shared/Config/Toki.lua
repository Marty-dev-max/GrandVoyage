-- Toki (v0.25.70, owner; spec docs/Plan-Toki.md): fighting spirit, a power of the body (works with or without a fruit).
-- Our own system: in game it is ALWAYS "Toki", never the other word. Three kinds, each with a base and an advanced form:
--   Armament    base: VIT + WIL, hits Logia bodies            advanced (sea 3): Inner Break (hits pass inside = crit, ignore DEF) + WIL (remake: was LUK)
--   Observation base: END + WPN (FLEE / HIT)                  advanced (sea 3): Foresight (see blows coming, counter, dodge charges) + WIL (remake: was LUK)
--   Conqueror   base: all stats +3, the aura cows the weak    advanced (sea 3): controlled aura (picks who it hits) + coating + WIL (remake: was LUK)
-- First sea: only Conqueror exists (0.1% roll when a character is made, or granted by the developer). Armament /
-- Observation are earned in the second sea (numbers below are ready for it).
-- Profile: p.toki = { rolled = true, Conqueror = { color = "#rrggbb", advanced = false }, ... }
local T = {}

T.Kinds = {
	{ id = "Conqueror", name = "Conqueror Toki", icon = "👑", stats = "ALL", desc = "The will of a born ruler. Only the chosen have it: the weak cannot even stand before you." },
	{ id = "Armament", name = "Armament Toki", icon = "🛡️", stats = { "VIT", "WIL" }, desc = "Spirit hardened into armor. Your blows reach even bodies of fire and smoke." },
	{ id = "Observation", name = "Observation Toki", icon = "👁️", stats = { "END", "WPN" }, desc = "You feel every blow before it lands." },
}
T.ById = {}
for _, k in ipairs(T.Kinds) do
	T.ById[k.id] = k
end

-- the color your Toki shows in (random when you get it; a Store unlock lets you pick, one per kind)
T.Colors = {
	"#1A1A22", "#B0122B", "#E8C547", "#7A3CFF", "#2FD6FF", "#F4F4F8", "#2BD47D", "#FF6A1A",
	"#FF4FB4", "#3D5BFF", "#8B0F5A", "#00A6A6", "#C0C8D8", "#6B2E12", "#9EFF3D", "#FF2E2E",
}

-- stat bonuses (base / advanced). Advanced = sea 3.
T.Bonus = {
	Conqueror = { all = 3, advancedAll = 6, advancedLuk = 4 },
	Armament = { main = 5, advancedMain = 10, advancedLuk = 6 },
	Observation = { main = 5, advancedMain = 10, advancedLuk = 6 },
}

-- Conqueror Toki in the first sea
T.Conqueror = {
	Chance = 0.001, -- rolled once per character (new characters and old ones that never rolled)
	-- Power (Formulas.Power / MonsterPower) compares you with others: below Calm x yours a monster will not dare to
	-- attack you on its own; the Roar cows anyone below Cow x yours (monsters freeze, players are stunned briefly)
	Calm = 0.4,
	Cow = 0.6,
	MonsterStun = 3.0,
	PlayerStun = 1.2,
}
T.Skills = {
	{ id = "T_ConquerorRoar", name = "Conqueror's Roar", toki = "Conqueror", kind = "Roar", sp = 30, cd = 40, radius = 36, icon = "👑", fx = "Burst",
		desc = "Unleash your will: every enemy much weaker than you (by Power) freezes in fear, rivals in PvP are stunned for a moment." },
}
for _, s in ipairs(T.Skills) do
	s.class = "Toki"
	s.maxLevel = 1
end

-- how Armament / Observation are earned (second sea; not active yet)
T.Unlock = {
	Armament = { kills = 1000, dropChance = 0.01 }, -- kill 1000 monsters (any), then every kill has a 1% chance
	-- "reading" points: a monster misses you = 1, a monster hits you = 0.2 (fair to tanks); Logia pass-through = 0
	Observation = { points = 500, missPoints = 1, hitPoints = 0.2, missChance = 0.01, hitChance = 0.002 },
}

-- top-of-server titles for the beta (granted by hand): The Four Crowns (4 pirates) / Seven Sea Lords (7) / Admirals
T.TopTitles = { Crowns = "The Four Crowns", SeaLords = "Seven Sea Lords" }

function T.ColorOf(entry)
	local hex = entry and entry.color or T.Colors[2]
	local ok, c = pcall(Color3.fromHex, hex)
	return ok and c or Color3.fromRGB(176, 18, 43)
end

return T
