-- WeaponInfo: which weapon type a profile fights with, and how far each type reaches (studs, to the target's body).
-- Shared by the server (CombatService validates hits) and the client (chasing, range rings) so both agree:
-- v0.17 clients fell back to "Sword" (10 studs) when no weapon was equipped, so every class walked up to melee range.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Shared.Modules.ItemDB)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)

local W = {}
W.Range = { Knuckles = 9, Sword = 10, Shoes = 9, Hammer = 10, Slingshot = 48, StormBaton = 34, MedKit = 26 }

-- equipped weapon's type, else the class's own weapon style (a Brawler punches, a Sharpshooter shoots)
function W.TypeOf(p)
	if not p then
		return "Knuckles"
	end
	local e = p.equipment and p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
	local def = e and ItemDB.Get(e.id)
	if def and def.weaponType then
		return def.weaponType
	end
	local cls = ClassesCfg.Classes[p.class]
	return cls and cls.weapons and cls.weapons[1] or "Knuckles"
end

-- the range the client walks into (a little inside the server's limit so the hit is never refused)
function W.ClientRange(p)
	return (W.Range[W.TypeOf(p)] or 9) - 1
end

return W
