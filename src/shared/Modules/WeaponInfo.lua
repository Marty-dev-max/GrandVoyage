-- WeaponInfo: which weapon type a profile fights with, and how far each type reaches (studs, to the target's body).
-- Shared by the server (CombatService validates hits) and the client (chasing, range rings) so both agree.
-- No weapon equipped = "Fists": plain punches for every class (the owner: a class only fights with its weapon style
-- once you equip that weapon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Shared.Modules.ItemDB)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)

local W = {}
W.Range = { Fists = 8, Knuckles = 9, Sword = 10, Shoes = 9, Hammer = 10, Slingshot = 48, StormBaton = 10, MedKit = 26 }

-- v0.25.75 (owner: manual play first, the M1 rhythm matters): every weapon has its own tempo. quick = gap between
-- hits of the 4-hit string (x attack interval), finish = the pause after the 4th, reset = how long the string waits
-- for the next hit, shape = damage per hit (the 4th = finisher). Damage is normalised so every weapon deals the same
-- per second at plain mashing (TARGET x attack interval); rhythm (PERFECT / FLAWLESS, CombatService) adds on top.
local TARGET = 1.1
W.M1 = {
	Fists = { quick = 0.52, finish = 1.9, reset = 1.1, shape = { 1, 1, 1.05, 1.6 } },
	Knuckles = { quick = 0.42, finish = 1.55, reset = 0.95, shape = { 0.85, 0.9, 1, 1.8 } }, -- Brawler: fast light jabs, big finisher
	Shoes = { quick = 0.52, finish = 1.8, reset = 1.05, shape = { 1, 1, 1.1, 1.9 } }, -- Sea Cook: kicks, the axe kick lands hard
	Sword = { quick = 0.6, finish = 2.0, reset = 1.15, shape = { 1, 1.05, 1, 1.8 } },
	Hammer = { quick = 0.85, finish = 2.5, reset = 1.5, shape = { 1.1, 1.1, 1.2, 2.2 } }, -- Shipwright: slow, heavy
	StormBaton = { quick = 0.46, finish = 1.7, reset = 1.0, shape = { 0.9, 0.9, 1, 1.6 } }, -- Navigator: quick taps
	Slingshot = { quick = 0.62, finish = 2.0, reset = 1.3, shape = { 1, 1, 1, 1.5 } },
	MedKit = { quick = 0.6, finish = 2.0, reset = 1.3, shape = { 1, 1, 1, 1.4 } },
}
for _, m in pairs(W.M1) do
	local sum = 0
	for _, v in ipairs(m.shape) do
		sum += v
	end
	m.norm = TARGET * (3 * m.quick + m.finish) / sum
end
W.Rhythm = { Window = 0.28, Perfect = 1.2, Flawless = 1.5, Link = 1.25, LinkWindow = 0.7 }
function W.M1Of(wType)
	return W.M1[wType or ""] or W.M1.Fists
end
-- damage multiplier of hit n (1..4) of the string
function W.M1Mult(wType, n)
	local m = W.M1Of(wType)
	return (m.shape[n] or 1) * m.norm
end

-- the equipped weapon's type; bare hands = "Fists"
function W.TypeOf(p)
	if not p then
		return "Fists"
	end
	local e = p.equipment and p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
	local def = e and ItemDB.ForEntry(e)
	return def and def.weaponType or "Fists"
end

-- the weapon style the class is built around (for gear it always wears, icons...)
function W.ClassWeapon(p)
	local cls = p and ClassesCfg.Classes[p.class]
	return cls and cls.weapons and cls.weapons[1] or "Knuckles"
end

-- the range the client walks into (a little inside the server's limit so the hit is never refused)
function W.ClientRange(p)
	return (W.Range[W.TypeOf(p)] or 9) - 1
end

return W
