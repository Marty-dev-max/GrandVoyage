-- WeaponInfo: which weapon type a profile fights with, and how far each type reaches (studs, to the target's body).
-- Shared by the server (CombatService validates hits) and the client (chasing, range rings) so both agree.
-- No weapon equipped = "Fists": plain punches for every class (the owner: a class only fights with its weapon style
-- once you equip that weapon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Shared.Modules.ItemDB)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)

local W = {}
W.Range = { Fists = 8, Knuckles = 9, Sword = 10, Shoes = 9, Hammer = 10, Slingshot = 48, StormBaton = 34, MedKit = 26 }

-- the equipped weapon's type; bare hands = "Fists"
function W.TypeOf(p)
	if not p then
		return "Fists"
	end
	local e = p.equipment and p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
	local def = e and ItemDB.Get(e.id)
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
