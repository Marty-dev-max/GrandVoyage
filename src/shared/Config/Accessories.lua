-- Accessories (v0.25.32, owner): ONE library of voxel accessory models, shared by players and monsters.
-- A humanoid monster wears these blocks (Config/MonsterLooks); the same id is an item (Config/Items) that drops from it
-- or is sold, and wearing that item puts the very same model on your character (WeaponService -> Modules/Accessory).
--
-- An accessory = a list of blocks { limb, size, offset, color [, material] }:
--   limb   = an R15 part name ("Head" means the voxel head cube),
--   size   = Vector3 multiplied by the limb's size, offset = Vector3 multiplied by the limb's size (from its center;
--            0.5 = that face: +Y up, -Z = the front / face side), so it fits any scaled character.
--   Hands hang down in the rest pose: a held weapon points along -Z (forward) from the hand.
local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material

local A = {}

-- ===== worn gear that existed before (moved from WeaponService.OUTFIT) =====
A.Bandana = { { "Head", V(1.32, 0.2, 1.32), V(0, 0.22, 0), C(210, 50, 55) }, { "Head", V(0.26, 0.26, 0.26), V(0, 0.2, 0.7), C(190, 40, 45) }, { "Head", V(0.12, 0.42, 0.08), V(0.1, -0.05, 0.72), C(190, 40, 45) } }
A.SunHat = { { "Head", V(1.9, 0.08, 1.9), V(0, 0.62, 0), C(240, 234, 214) }, { "Head", V(1.05, 0.32, 1.05), V(0, 0.8, 0), C(240, 234, 214) }, { "Head", V(1.08, 0.1, 1.08), V(0, 0.7, 0), C(70, 150, 220) }, { "Head", V(0.2, 0.2, 0.2), V(0.45, 0.74, -0.42), C(255, 120, 170) } }
A.MarineCap = { { "Head", V(1.3, 0.28, 1.3), V(0, 0.68, 0), C(245, 245, 250) }, { "Head", V(1.32, 0.1, 1.32), V(0, 0.58, 0), C(40, 60, 130) }, { "Head", V(0.9, 0.06, 0.45), V(0, 0.56, -0.75), C(40, 60, 130) }, { "Head", V(0.2, 0.14, 0.05), V(0, 0.68, -0.66), C(255, 200, 60) } }
A.ClownNose = { { "Head", V(0.22, 0.22, 0.22), V(0, -0.05, -0.56), C(240, 40, 40) } }
A.SailorVest = { { "UpperTorso", V(0.42, 1.02, 1.08), V(-0.3, 0, 0), C(60, 110, 200) }, { "UpperTorso", V(0.42, 1.02, 1.08), V(0.3, 0, 0), C(60, 110, 200) }, { "UpperTorso", V(1.06, 0.12, 1.1), V(0, 0.46, 0), C(245, 245, 250) } }
A.MarineCoat = { { "UpperTorso", V(1.08, 1.04, 1.1), Vector3.zero, C(240, 240, 245) }, { "UpperTorso", V(0.12, 1.05, 0.06), V(0, 0, -0.54), C(40, 60, 130) }, { "UpperTorso", V(0.3, 0.08, 0.4), V(0.42, 0.52, 0), C(255, 200, 60) }, { "UpperTorso", V(0.3, 0.08, 0.4), V(-0.42, 0.52, 0), C(255, 200, 60) }, { "LowerTorso", V(1.0, 2.6, 0.12), V(0, -0.9, 0.55), C(240, 240, 245) } }
A.CaptainCoat = { { "UpperTorso", V(1.08, 1.04, 1.1), Vector3.zero, C(165, 38, 45) }, { "UpperTorso", V(0.1, 1.05, 0.06), V(-0.12, 0, -0.54), C(255, 200, 60) }, { "UpperTorso", V(0.1, 1.05, 0.06), V(0.12, 0, -0.54), C(255, 200, 60) }, { "UpperTorso", V(0.32, 0.1, 0.42), V(0.42, 0.52, 0), C(255, 200, 60) }, { "UpperTorso", V(0.32, 0.1, 0.42), V(-0.42, 0.52, 0), C(255, 200, 60) }, { "LowerTorso", V(1.0, 2.8, 0.12), V(0, -1.0, 0.55), C(150, 32, 40) } }
A.SharkscaleMail = { { "UpperTorso", V(1.06, 1.03, 1.08), Vector3.zero, C(90, 120, 150) }, { "UpperTorso", V(1.07, 0.1, 1.09), V(0, 0.2, 0), C(60, 85, 110) }, { "UpperTorso", V(1.07, 0.1, 1.09), V(0, -0.15, 0), C(60, 85, 110) }, { "UpperTorso", V(1.07, 0.1, 1.09), V(0, -0.4, 0), C(130, 165, 195) } }
A.CompassCharm = { { "UpperTorso", V(0.22, 0.22, 0.06), V(0.25, 0.15, -0.56), C(255, 200, 60) } }
A.TangerinePin = { { "UpperTorso", V(0.2, 0.2, 0.06), V(-0.28, 0.25, -0.56), C(255, 150, 40) } }
A.SharkToothNecklace = { { "UpperTorso", V(0.1, 0.16, 0.06), V(-0.2, 0.38, -0.56), C(250, 248, 235) }, { "UpperTorso", V(0.1, 0.2, 0.06), V(0, 0.36, -0.56), C(250, 248, 235) }, { "UpperTorso", V(0.1, 0.16, 0.06), V(0.2, 0.38, -0.56), C(250, 248, 235) } }
A.SeastoneBracer = { { "RightLowerArm", V(1.15, 0.45, 1.15), Vector3.zero, C(60, 70, 90) } }
A.SeastoneShackle = { { "RightLowerArm", V(1.18, 0.5, 1.18), Vector3.zero, C(50, 58, 78) }, { "LeftLowerArm", V(1.18, 0.5, 1.18), Vector3.zero, C(50, 58, 78) } }

-- ===== monster accessories (v0.25.32): the signature look of each humanoid monster, wearable as items =====
-- Clown wig: two big puffs over the ears and a tuft on top (Clown Grunt, Circus Acrobat, Captain Confetti)
local function wig(c)
	return {
		{ "Head", V(0.42, 0.55, 0.85), V(-0.66, 0.12, 0.1), c }, { "Head", V(0.42, 0.55, 0.85), V(0.66, 0.12, 0.1), c },
		{ "Head", V(0.3, 0.32, 0.6), V(-0.8, 0.42, 0.12), c:Lerp(Color3.new(1, 1, 1), 0.2) }, { "Head", V(0.3, 0.32, 0.6), V(0.8, 0.42, 0.12), c:Lerp(Color3.new(1, 1, 1), 0.2) },
		{ "Head", V(0.55, 0.28, 0.55), V(0, 0.66, 0.08), c }, { "Head", V(0.3, 0.2, 0.3), V(0.08, 0.86, 0.05), c:Lerp(Color3.new(1, 1, 1), 0.25) },
	}
end
A.ClownWig = wig(C(255, 96, 60))
A.ConfettiWig = wig(C(150, 70, 230)) -- Captain Confetti's purple wig
A.CatEars = {
	{ "Head", V(0.3, 0.34, 0.18), V(-0.32, 0.66, 0.06), C(40, 34, 48) }, { "Head", V(0.3, 0.34, 0.18), V(0.32, 0.66, 0.06), C(40, 34, 48) },
	{ "Head", V(0.14, 0.18, 0.05), V(-0.32, 0.64, -0.04), C(240, 150, 175) }, { "Head", V(0.14, 0.18, 0.05), V(0.32, 0.64, -0.04), C(240, 150, 175) },
}
A.IronHelmet = {
	{ "Head", V(1.14, 0.44, 1.14), V(0, 0.44, 0), C(150, 150, 162), M.Metal }, { "Head", V(1.18, 0.12, 1.18), V(0, 0.26, 0), C(100, 100, 112), M.Metal },
	{ "Head", V(0.12, 0.46, 0.08), V(0, 0.08, -0.58), C(120, 120, 132), M.Metal }, { "Head", V(0.16, 0.22, 0.16), V(0, 0.74, 0), C(200, 60, 60) },
}
A.HypnoGoggles = {
	{ "Head", V(1.1, 0.14, 1.1), V(0, 0.12, 0), C(40, 30, 50) },
	{ "Head", V(0.36, 0.36, 0.08), V(-0.24, 0.1, -0.56), C(200, 110, 240), M.Neon }, { "Head", V(0.36, 0.36, 0.08), V(0.24, 0.1, -0.56), C(200, 110, 240), M.Neon },
	{ "Head", V(0.16, 0.16, 0.05), V(-0.24, 0.1, -0.61), C(250, 245, 255) }, { "Head", V(0.16, 0.16, 0.05), V(0.24, 0.1, -0.61), C(250, 245, 255) },
}
A.GlowVisor = { { "Head", V(0.94, 0.14, 0.07), V(0, 0.12, -0.56), C(255, 210, 60), M.Neon }, { "Head", V(1.1, 0.1, 1.1), V(0, 0.22, 0), C(30, 24, 40) } }
A.RingmasterHat = {
	{ "Head", V(1.45, 0.08, 1.45), V(0, 0.56, 0), C(30, 24, 34) }, { "Head", V(0.92, 0.8, 0.92), V(0, 0.98, 0), C(30, 24, 34) },
	{ "Head", V(0.95, 0.15, 0.95), V(0, 0.66, 0), C(220, 40, 60) }, { "Head", V(0.2, 0.2, 0.05), V(0.3, 0.68, -0.48), C(255, 200, 60), M.Neon },
}
A.AdmiralCrown = {
	{ "Head", V(1.14, 0.38, 1.14), V(0, 0.42, 0), C(200, 170, 70), M.Metal }, { "Head", V(1.02, 0.22, 1.02), V(0, 0.7, 0), C(255, 205, 70) },
	{ "Head", V(0.16, 0.24, 0.16), V(-0.42, 0.9, -0.42), C(255, 205, 70) }, { "Head", V(0.16, 0.24, 0.16), V(0.42, 0.9, -0.42), C(255, 205, 70) },
	{ "Head", V(0.16, 0.24, 0.16), V(-0.42, 0.9, 0.42), C(255, 205, 70) }, { "Head", V(0.16, 0.24, 0.16), V(0.42, 0.9, 0.42), C(255, 205, 70) },
	{ "Head", V(0.18, 0.18, 0.06), V(0, 0.7, -0.53), C(220, 40, 60), M.Neon },
}
-- beards: chin block + sideburns (a few hair colors)
local function beard(c)
	return { { "Head", V(0.86, 0.32, 0.3), V(0, -0.42, -0.42), c }, { "Head", V(0.18, 0.4, 0.62), V(-0.46, -0.18, -0.2), c }, { "Head", V(0.18, 0.4, 0.62), V(0.46, -0.18, -0.2), c }, { "Head", V(0.5, 0.12, 0.1), V(0, -0.12, -0.54), c:Lerp(Color3.new(0, 0, 0), 0.15) } }
end
A.BeardBrown = beard(C(110, 76, 48))
A.BeardDark = beard(C(60, 42, 30))
A.BeardGrey = beard(C(200, 200, 210))
-- capes: a panel down the back from the shoulders to the knees, gold clasps
local function cape(c)
	return {
		{ "UpperTorso", V(1.04, 1.05, 0.12), V(0, -0.02, 0.58), c }, { "LowerTorso", V(1.04, 5.4, 0.12), V(0, -2.75, 0.64), c:Lerp(Color3.new(0, 0, 0), 0.12) },
		{ "UpperTorso", V(1.06, 0.12, 1.12), V(0, 0.48, 0), c:Lerp(Color3.new(1, 1, 1), 0.15) },
		{ "UpperTorso", V(0.14, 0.14, 0.06), V(-0.3, 0.38, -0.56), C(255, 205, 70) }, { "UpperTorso", V(0.14, 0.14, 0.06), V(0.3, 0.38, -0.56), C(255, 205, 70) },
	}
end
A.CapeNavy = cape(C(40, 70, 150))
A.CapePurple = cape(C(120, 40, 200))
A.CapeShadow = cape(C(30, 24, 40))
A.CapeCrimson = cape(C(150, 30, 40))
A.CapeSlate = cape(C(90, 90, 110))
A.CapeGold = cape(C(240, 190, 60))

-- ===== weapons in hand (monsters only for now; players draw their own weapons) =====
local STEEL, WOOD, DARK, GOLD = C(200, 206, 218), C(120, 82, 50), C(50, 52, 60), C(255, 200, 60)
A.HeldClub = { { "RightHand", V(0.3, 0.9, 2.4), V(0, 0, -1.2), WOOD }, { "RightHand", V(0.6, 2.2, 1.1), V(0, 0, -2.7), WOOD:Lerp(Color3.new(0, 0, 0), 0.15) } }
A.HeldCutlass = { { "RightHand", V(0.6, 1.1, 0.14), V(0, 0, -0.32), GOLD }, { "RightHand", V(0.14, 0.6, 3.4), V(0, 0, -2.05), STEEL, M.Metal }, { "RightHand", V(0.16, 0.9, 0.5), V(0, -0.3, -3.6), STEEL, M.Metal } }
A.HeldRifle = { { "RightHand", V(0.22, 0.7, 3.8), V(0, 0.5, -1.7), DARK, M.Metal }, { "RightHand", V(0.4, 1.6, 1.6), V(0, -0.2, 0.3), WOOD } }
A.HeldPistol = { { "RightHand", V(0.24, 0.9, 1.3), V(0, 0.5, -0.7), DARK, M.Metal }, { "RightHand", V(0.3, 1.4, 0.4), V(0, -0.1, -0.05), WOOD } }
local function claws(hand)
	return { { hand, V(0.08, 0.5, 0.9), V(-0.3, -0.2, -0.85), STEEL, M.Metal }, { hand, V(0.08, 0.5, 1.05), V(0, -0.2, -0.95), STEEL, M.Metal }, { hand, V(0.08, 0.5, 0.9), V(0.3, -0.2, -0.85), STEEL, M.Metal } }
end
A.HeldClaws = claws("RightHand")
for _, b in ipairs(claws("LeftHand")) do
	table.insert(A.HeldClaws, b)
end
A.HeldBattleAxe = { { "RightHand", V(0.26, 0.9, 3.6), V(0, 0, -1.6), WOOD }, { "RightHand", V(0.2, 5.4, 1.6), V(0, 1.6, -3.1), STEEL, M.Metal }, { "RightHand", V(0.22, 5.6, 0.2), V(0, 1.6, -3.95), C(240, 244, 250), M.Metal } }
-- Depths Warden's trident (shaft along -Z, crossbar + three prongs)
local TIDE = C(90, 200, 200)
A.HeldTrident = { { "RightHand", V(0.2, 0.7, 6.2), V(0, 0, -1.6), C(60, 90, 110), M.Metal }, { "RightHand", V(1.3, 0.7, 0.22), V(0, 0, -4.7), TIDE, M.Metal },
	{ "RightHand", V(0.18, 0.7, 1.2), V(-0.55, 0, -5.35), TIDE, M.Metal }, { "RightHand", V(0.2, 0.7, 1.5), V(0, 0, -5.5), TIDE, M.Metal }, { "RightHand", V(0.18, 0.7, 1.2), V(0.55, 0, -5.35), TIDE, M.Metal } }

return A
