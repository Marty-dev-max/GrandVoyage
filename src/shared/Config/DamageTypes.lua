-- Damage types (remake R1, docs/Plan-Remake.md decisions): every player hit is Slash, Blunt, Pierce or Element
-- (blades cut, fists / kicks / hammers / batons smash, muskets pierce, Cursed Fruits and powders are Element).
-- Every monster resists one type and is weak to another: Weak x deals more, Resist x less. Which monster gets
-- which pair is a design call per island (docs/Plan-Remake.md R5): edit the Of table, nothing else.
local T = {}

T.Order = { "Slash", "Blunt", "Pierce", "Element" }
T.Info = {
	Slash = { name = "Slash", icon = "sword", color = Color3.fromRGB(120, 200, 255), desc = "Swords and blades" },
	Blunt = { name = "Blunt", icon = "knuckles", color = Color3.fromRGB(255, 170, 80), desc = "Fists, kicks, hammers, batons" },
	Pierce = { name = "Pierce", icon = "musket_ball", color = Color3.fromRGB(220, 220, 230), desc = "Muskets and shots" },
	Element = { name = "Element", icon = "flame", color = Color3.fromRGB(255, 110, 200), desc = "Cursed Fruits and powders" },
}
T.Weak, T.Resist = 1.3, 0.7

-- weapon type (WeaponInfo.TypeOf / item weaponType) -> damage type
T.Weapon = {
	Fists = "Blunt", Knuckles = "Blunt", Shoes = "Blunt", Hammer = "Blunt", StormBaton = "Blunt",
	Sword = "Slash",
	Slingshot = "Pierce",
	MedKit = "Element",
}
function T.OfWeapon(wType)
	return T.Weapon[wType or ""] or "Blunt"
end

-- monster id -> { resist, weak }. First pass (owner, 27 Nov 2026: build the system now, tune per island later).
-- Each island mixes them so no single weapon wins everywhere; the early island never resists the bare fist much.
T.Of = {
	-- Daybreak
	ForestMonkey = { "Pierce", "Blunt" }, -- small and quick: hard to shoot, one good punch drops it
	JungleTiger = { "Blunt", "Slash" }, -- thick muscle, soft hide
	WildBoar = { "Slash", "Pierce" }, -- tough hide turns blades, a spear-like shot goes in
	MountainBandit = { "Slash", "Blunt" }, -- parries blades with his own cutlass
	BanditChief = { "Blunt", "Pierce" }, -- big brute in a fur mantle
	BaySerpent = { "Slash", "Pierce" }, -- scales
	-- Conch Bay
	MarineRecruit = { "Slash", "Blunt" },
	GuardWolf = { "Blunt", "Slash" },
	MarineRifleman = { "Pierce", "Slash" }, -- keeps to cover, weak up close
	SpoiledEnsign = { "Blunt", "Pierce" }, -- padded coat
	AxeCaptain = { "Slash", "Pierce" }, -- the axe arm blocks blades
	-- Marmalade
	ClownGrunt = { "Blunt", "Slash" }, -- padded rubbery costume
	CircusAcrobat = { "Pierce", "Blunt" }, -- dodges shots
	CircusLion = { "Slash", "Pierce" }, -- the mane
	BeastTamer = { "Element", "Blunt" }, -- used to the fire hoop
	CaptainConfetti = { "Slash", "Blunt" }, -- a split body lets blades through
	RingMaster = { "Element", "Pierce" },
	-- Honeyslope / cats
	NightCatPirate = { "Pierce", "Blunt" },
	HypnoThug = { "Blunt", "Element" }, -- feels no pain, the mind is the weak spot
	ClawCat = { "Slash", "Pierce" }, -- claws parry blades
	SilentClaw = { "Pierce", "Element" },
	-- Iron Armada
	ArmadaRaider = { "Slash", "Element" }, -- iron armor heats up
	StarvedPirate = { "Element", "Slash" },
	ArmoredGunner = { "Pierce", "Blunt" }, -- iron plate dents under hammers
	ArmadaAdmiral = { "Slash", "Blunt" },
	-- Sawtooth seas
	SharkfolkBrawler = { "Slash", "Element" }, -- rough shark skin
	SawfolkRaider = { "Pierce", "Blunt" },
	OctofolkBrute = { "Blunt", "Slash" }, -- squishy
	SawtoothOverlord = { "Slash", "Pierce" },
	DepthsWarden = { "Pierce", "Element" },
	-- Epilogue
	BountyHunter = { "Pierce", "Slash" }, -- plate against bullets
	MarineElite = { "Slash", "Blunt" },
	MistSoldier = { "Pierce", "Element" }, -- shots pass through the mist
	MistCommodore = { "Slash", "Element" },
	-- Doldrums
	Leviathan = { "Pierce", "Element" },
}

function T.Pair(monsterId)
	local p = T.Of[monsterId or ""]
	if p then
		return p[1], p[2]
	end
	return nil, nil
end
-- multiplier + "weak" / "resist" / nil for a hit of type dtype on that monster
function T.Mult(dtype, monsterId)
	local res, weak = T.Pair(monsterId)
	if dtype and dtype == weak then
		return T.Weak, "weak"
	elseif dtype and dtype == res then
		return T.Resist, "resist"
	end
	return 1, nil
end

-- self-check: known types, resist ~= weak
for id, p in pairs(T.Of) do
	assert(T.Info[p[1]] and T.Info[p[2]] and p[1] ~= p[2], "DamageTypes bad pair for " .. id)
end

return T
