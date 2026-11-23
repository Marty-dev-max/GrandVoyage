-- Animation clips as plain data (no Roblox types), the single source for:
--   tools/build_anims.luau -> assets/anims/<Name>.rbxm (KeyframeSequence) -> upload_models.py --type Animation -> Config/Animations
--   Shared/Modules/Anim.lua at runtime (plays the uploaded ids; builds a local KeyframeSequence when an id is missing).
--
-- A pose value is { rx, ry, rz [, x, y, z] }: degrees, then an optional offset in studs. It is the joint's Transform,
-- keyed by the name of the part the joint moves (R15: UpperTorso = waist, RightUpperArm = shoulder, RightLowerArm = elbow...).
-- R15 axes (character faces -Z): +rx on an arm/leg swings it FORWARD; +rx on an elbow bends it; -rx on a knee bends it;
-- -rx on UpperTorso leans forward; +ry on UpperTorso/LowerTorso turns the right side forward; +rz on the right arm lifts it
-- outward, -rz on the left arm lifts it outward. Offsets on LowerTorso move the whole body (y down = crouch, -z = lunge).
-- Parts a key leaves out return to rest (identity) at that key; parts never named in a clip are left to other animations.
-- Monster clips ("Mon" rig) pose the voxel parts (Body, Head, LegL/LegR, LegFL/FR/BL/BR, ArmL/ArmR, Tail, WingL/WingR),
-- which all hang off the HumanoidRootPart; a pose for a part a monster does not have is simply ignored.
-- `strike` is when the blow lands (VFX and hitstop sync to it).

local C = {}

-- ===== Brawler (Knuckles): guard stance, jab -> cross -> hook -> uppercut =====
local GUARD = {
	RightUpperArm = { 40, 0, 18 }, RightLowerArm = { 115, 0, 0 },
	LeftUpperArm = { 48, 0, -18 }, LeftLowerArm = { 115, 0, 0 },
	UpperTorso = { -8, -15, 0 }, Head = { 6, 12, 0 },
}
local function with(base, over)
	local t = table.clone(base)
	for k, v in pairs(over or {}) do
		t[k] = v
	end
	return t
end

C.Brawler_Stance = { rig = "R15", loop = true, priority = "Idle", length = 1.2, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.6, pose = with(GUARD, { UpperTorso = { -10, -15, 0 }, RightUpperArm = { 42, 0, 18 }, LeftUpperArm = { 50, 0, -18 } }) },
	{ t = 1.2, pose = GUARD },
} }
C.Brawler_Jab = { rig = "R15", priority = "Action", strike = 0.07, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.07, pose = with(GUARD, { LeftUpperArm = { 88, 0, -4 }, LeftLowerArm = { 4, 0, 0 }, UpperTorso = { -10, -28, 0 } }) },
	{ t = 0.24, pose = GUARD },
} }
C.Brawler_Cross = { rig = "R15", priority = "Action", strike = 0.09, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.04, pose = with(GUARD, { UpperTorso = { -6, -25, 0 } }) },
	{ t = 0.09, pose = with(GUARD, { RightUpperArm = { 90, 0, 4 }, RightLowerArm = { 4, 0, 0 }, UpperTorso = { -12, 38, 0 }, LowerTorso = { 0, 12, 0 }, LeftUpperArm = { 40, 0, -22 } }) },
	{ t = 0.28, pose = GUARD },
} }
C.Brawler_Hook = { rig = "R15", priority = "Action", strike = 0.12, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.06, pose = with(GUARD, { UpperTorso = { -4, 30, 0 }, LeftUpperArm = { 60, 0, -35 } }) },
	{ t = 0.12, pose = with(GUARD, { LeftUpperArm = { 80, 0, -70 }, LeftLowerArm = { 85, 0, 0 }, UpperTorso = { -10, -45, 0 }, LowerTorso = { 0, -12, 0 } }) },
	{ t = 0.32, pose = GUARD },
} }
C.Brawler_Uppercut = { rig = "R15", priority = "Action", strike = 0.18, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.09, pose = { RightUpperArm = { 10, 0, 15 }, RightLowerArm = { 105, 0, 0 }, LeftUpperArm = { 45, 0, -20 }, LeftLowerArm = { 110, 0, 0 },
		UpperTorso = { 12, -28, 0 }, LowerTorso = { 0, 0, 0, 0, -0.55, 0 },
		RightUpperLeg = { 28, 0, 0 }, RightLowerLeg = { -40, 0, 0 }, LeftUpperLeg = { 28, 0, 0 }, LeftLowerLeg = { -40, 0, 0 } } },
	{ t = 0.18, pose = { RightUpperArm = { 160, 0, 0 }, RightLowerArm = { 35, 0, 0 }, LeftUpperArm = { 30, 0, -25 }, LeftLowerArm = { 100, 0, 0 },
		UpperTorso = { 14, 32, 0 }, LowerTorso = { 0, 0, 0, 0, 0.35, 0 }, Head = { 14, 0, 0 } } },
	{ t = 0.42, pose = GUARD },
} }

-- ===== Brawler freestyle (street fighting): body blow, elbow, knee, spinning backfist, punch flurry =====
local CROUCH = { LowerTorso = { 0, 0, 0, 0, -0.35, 0 }, RightUpperLeg = { 22, 0, 0 }, RightLowerLeg = { -30, 0, 0 }, LeftUpperLeg = { 22, 0, 0 }, LeftLowerLeg = { -30, 0, 0 } }
C.Brawler_BodyBlow = { rig = "R15", priority = "Action", strike = 0.13, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.06, pose = with(with(GUARD, CROUCH), { UpperTorso = { 8, 28, 0 }, LeftUpperArm = { 35, 0, -30 } }) },
	{ t = 0.13, pose = with(with(GUARD, CROUCH), { LeftUpperArm = { 55, 0, -55 }, LeftLowerArm = { 80, 0, 0 }, UpperTorso = { -16, -38, 0 }, LowerTorso = { 0, -12, 0, 0, -0.4, 0 } }) },
	{ t = 0.32, pose = GUARD },
} }
C.Brawler_Elbow = { rig = "R15", priority = "Action", strike = 0.12, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.06, pose = with(GUARD, { RightUpperArm = { 40, 0, 72 }, RightLowerArm = { 140, 0, 0 }, UpperTorso = { 0, -28, 0 } }) },
	{ t = 0.12, pose = with(GUARD, { RightUpperArm = { 82, 0, 18 }, RightLowerArm = { 150, 0, 0 }, UpperTorso = { -10, 48, 0 }, LowerTorso = { 0, 14, 0 } }) },
	{ t = 0.3, pose = GUARD },
} }
C.Brawler_Knee = { rig = "R15", priority = "Action", strike = 0.15, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.07, pose = with(GUARD, { LeftUpperArm = { 95, 0, -8 }, RightUpperArm = { 95, 0, 8 }, LeftLowerArm = { 40, 0, 0 }, RightLowerArm = { 40, 0, 0 } }) },
	{ t = 0.15, pose = with(GUARD, { RightUpperLeg = { 112, 0, 0 }, RightLowerLeg = { -130, 0, 0 }, LeftUpperArm = { 70, 0, -10 }, RightUpperArm = { 70, 0, 10 }, LeftLowerArm = { 70, 0, 0 }, RightLowerArm = { 70, 0, 0 }, UpperTorso = { -16, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.1, -0.3 } }) },
	{ t = 0.34, pose = GUARD },
} }
C.Brawler_Backfist = { rig = "R15", priority = "Action", strike = 0.22, keys = {
	{ t = 0, pose = GUARD },
	{ t = 0.08, pose = with(GUARD, { LowerTorso = { 0, -110, 0 }, Head = { 0, -50, 0 }, RightUpperArm = { 30, 0, 30 }, RightLowerArm = { 125, 0, 0 } }) },
	{ t = 0.18, pose = with(GUARD, { LowerTorso = { 0, -230, 0 }, Head = { 0, -30, 0 }, RightUpperArm = { 20, 0, 60 }, RightLowerArm = { 60, 0, 0 } }) },
	{ t = 0.22, pose = with(GUARD, { LowerTorso = { 0, -270, 0 }, Head = { 0, 60, 0 }, RightUpperArm = { 8, 0, 92 }, RightLowerArm = { 4, 0, 0 }, UpperTorso = { 0, 0, -10 } }) },
	{ t = 0.36, pose = with(GUARD, { LowerTorso = { 0, -359, 0 } }) },
	{ t = 0.44, pose = GUARD },
} }
local JAB_L = with(GUARD, { LeftUpperArm = { 88, 0, -4 }, LeftLowerArm = { 4, 0, 0 }, UpperTorso = { -8, -24, 0 } })
local JAB_R = with(GUARD, { RightUpperArm = { 88, 0, 4 }, RightLowerArm = { 4, 0, 0 }, UpperTorso = { -8, 24, 0 } })
C.Brawler_Flurry = { rig = "R15", priority = "Action", strike = 0.32, keys = {
	{ t = 0, pose = GUARD }, { t = 0.05, pose = JAB_L }, { t = 0.1, pose = JAB_R }, { t = 0.15, pose = JAB_L }, { t = 0.2, pose = JAB_R },
	{ t = 0.25, pose = GUARD },
	{ t = 0.32, pose = with(GUARD, { RightUpperArm = { 92, 0, 0 }, RightLowerArm = { 2, 0, 0 }, UpperTorso = { -14, 42, 0 }, LowerTorso = { 0, 14, 0, 0, 0, -0.4 } }) },
	{ t = 0.5, pose = GUARD },
} }

-- ===== Sea Cook (Shoes): taekwondo. Ready stance (side-on, fists up, bouncing), then
--       front kick (ap chagi) -> side kick (yeop chagi) -> spinning back kick (dwit chagi) -> axe kick (naeryo chagi);
--       the flying side kick (twimyo yeop chagi) is the big skill kick. Right leg kicks; the left leg leads.
local TKD = {
	LowerTorso = { 0, -35, 0, 0, -0.25, 0 }, UpperTorso = { -4, 12, 0 }, Head = { 0, 22, 0 },
	LeftUpperArm = { 62, 0, -12 }, LeftLowerArm = { 95, 0, 0 }, RightUpperArm = { 38, 0, 18 }, RightLowerArm = { 125, 0, 0 },
	LeftUpperLeg = { 22, 0, -4 }, LeftLowerLeg = { -28, 0, 0 }, RightUpperLeg = { -14, 0, 6 }, RightLowerLeg = { -22, 0, 0 },
}
-- stances only pose the upper body (arms up in guard): the legs keep walking / idling normally (v0.19 posed the legs
-- too and the character stood frozen in the stance even while running)
local TKD_UPPER = { UpperTorso = { -4, 12, 0 }, Head = { 0, 8, 0 }, LeftUpperArm = { 62, 0, -12 }, LeftLowerArm = { 95, 0, 0 }, RightUpperArm = { 38, 0, 18 }, RightLowerArm = { 125, 0, 0 } }
C.Cook_Stance = { rig = "R15", loop = true, priority = "Idle", length = 0.8, keys = {
	{ t = 0, pose = TKD_UPPER },
	{ t = 0.4, pose = with(TKD_UPPER, { UpperTorso = { -6, 12, 0 }, LeftUpperArm = { 66, 0, -12 }, RightUpperArm = { 42, 0, 18 } }) },
	{ t = 0.8, pose = TKD_UPPER },
} }
C.Cook_FrontKick = { rig = "R15", priority = "Action", strike = 0.15, keys = {
	{ t = 0, pose = TKD },
	{ t = 0.07, pose = with(TKD, { LowerTorso = { 0, -10, 0, 0, -0.1, 0 }, RightUpperLeg = { 95, 0, 0 }, RightLowerLeg = { -115, 0, 0 }, UpperTorso = { 6, 5, 0 } }) },
	{ t = 0.15, pose = with(TKD, { LowerTorso = { 0, -5, 0, 0, 0, -0.3 }, RightUpperLeg = { 100, 0, 0 }, RightLowerLeg = { -4, 0, 0 }, UpperTorso = { 14, 0, 0 }, LeftLowerLeg = { -10, 0, 0 } }) },
	{ t = 0.24, pose = with(TKD, { RightUpperLeg = { 90, 0, 0 }, RightLowerLeg = { -110, 0, 0 } }) },
	{ t = 0.36, pose = TKD },
} }
C.Cook_SideKick = { rig = "R15", priority = "Action", strike = 0.17, keys = {
	{ t = 0, pose = TKD },
	{ t = 0.08, pose = with(TKD, { LowerTorso = { 0, 60, 0, 0, -0.15, 0 }, RightUpperLeg = { 65, 0, 45 }, RightLowerLeg = { -120, 0, 0 }, UpperTorso = { 0, 10, -8 } }) },
	{ t = 0.17, pose = with(TKD, { LowerTorso = { 0, 85, -10, 0, 0, 0 }, RightUpperLeg = { 8, 0, 88 }, RightLowerLeg = { -2, 0, 0 }, UpperTorso = { 0, 5, -28 }, Head = { 0, -60, 20 }, LeftUpperLeg = { 0, 0, -8 }, LeftLowerLeg = { -8, 0, 0 } }) },
	{ t = 0.27, pose = with(TKD, { LowerTorso = { 0, 60, 0 }, RightUpperLeg = { 60, 0, 45 }, RightLowerLeg = { -115, 0, 0 } }) },
	{ t = 0.4, pose = TKD },
} }
C.Cook_BackKick = { rig = "R15", priority = "Action", strike = 0.21, keys = {
	{ t = 0, pose = TKD },
	{ t = 0.09, pose = with(TKD, { LowerTorso = { 0, -120, 0, 0, -0.2, 0 }, Head = { 0, -50, 0 }, RightUpperLeg = { 50, 0, 0 }, RightLowerLeg = { -110, 0, 0 } }) },
	{ t = 0.21, pose = with(TKD, { LowerTorso = { 0, -180, 0, 0, 0, 0.2 }, UpperTorso = { -28, 0, 0 }, Head = { -10, -70, 0 }, RightUpperLeg = { -85, 0, 0 }, RightLowerLeg = { -4, 0, 0 }, LeftUpperLeg = { 15, 0, 0 } }) },
	{ t = 0.31, pose = with(TKD, { LowerTorso = { 0, -270, 0 }, RightUpperLeg = { 20, 0, 0 }, RightLowerLeg = { -60, 0, 0 } }) },
	{ t = 0.44, pose = with(TKD, { LowerTorso = { 0, -359, 0, 0, -0.25, 0 } }) },
	{ t = 0.5, pose = TKD },
} }
C.Cook_AxeKick = { rig = "R15", priority = "Action", strike = 0.22, keys = {
	{ t = 0, pose = TKD },
	{ t = 0.13, pose = with(TKD, { LowerTorso = { 0, -15, 0, 0, 0.1, 0 }, RightUpperLeg = { 140, 0, 12 }, RightLowerLeg = { -4, 0, 0 }, UpperTorso = { 18, 0, 0 } }) },
	{ t = 0.22, pose = with(TKD, { LowerTorso = { 0, -15, 0, 0, -0.45, -0.3 }, RightUpperLeg = { 25, 0, 0 }, RightLowerLeg = { -10, 0, 0 }, UpperTorso = { -18, 0, 0 } }) },
	{ t = 0.44, pose = TKD },
} }
C.Cook_FlyingKick = { rig = "R15", priority = "Action2", strike = 0.32, keys = {
	{ t = 0, pose = TKD },
	{ t = 0.1, pose = with(TKD, { LowerTorso = { 0, -20, 0, 0, -0.7, 0 }, LeftUpperLeg = { 50, 0, 0 }, LeftLowerLeg = { -90, 0, 0 }, RightUpperLeg = { 50, 0, 0 }, RightLowerLeg = { -90, 0, 0 } }) },
	{ t = 0.22, pose = with(TKD, { LowerTorso = { 0, 60, 0, 0, 1.8, -0.6 }, LeftUpperLeg = { 85, 0, 0 }, LeftLowerLeg = { -125, 0, 0 }, RightUpperLeg = { 60, 0, 45 }, RightLowerLeg = { -120, 0, 0 } }) },
	{ t = 0.32, pose = with(TKD, { LowerTorso = { 0, 88, -12, 0, 2.2, -1.2 }, UpperTorso = { 0, 5, -25 }, Head = { 0, -60, 20 }, LeftUpperLeg = { 80, 0, 0 }, LeftLowerLeg = { -125, 0, 0 }, RightUpperLeg = { 6, 0, 90 }, RightLowerLeg = { -2, 0, 0 } }) },
	{ t = 0.46, pose = with(TKD, { LowerTorso = { 0, 40, 0, 0, 0.6, -0.6 }, RightUpperLeg = { 40, 0, 30 }, RightLowerLeg = { -90, 0, 0 } }) },
	{ t = 0.6, pose = with(TKD, { LowerTorso = { 0, -35, 0, 0, -0.6, 0 }, LeftLowerLeg = { -50, 0, 0 }, RightLowerLeg = { -45, 0, 0 } }) },
	{ t = 0.72, pose = TKD },
} }

-- ===== Swordsman (Sword): blade forward, overhead slash -> backhand -> thrust =====
local EN_GARDE = { RightUpperArm = { 35, 0, 12 }, RightLowerArm = { 40, 0, 0 }, LeftUpperArm = { 10, 0, -12 }, UpperTorso = { -4, 18, 0 } }
C.Sword_Stance = { rig = "R15", loop = true, priority = "Idle", length = 1.4, keys = {
	{ t = 0, pose = EN_GARDE },
	{ t = 0.7, pose = with(EN_GARDE, { RightUpperArm = { 38, 0, 12 }, UpperTorso = { -6, 18, 0 } }) },
	{ t = 1.4, pose = EN_GARDE },
} }
C.Sword_Slash = { rig = "R15", priority = "Action", strike = 0.16, keys = {
	{ t = 0, pose = EN_GARDE },
	{ t = 0.09, pose = { RightUpperArm = { 160, 0, 28 }, RightLowerArm = { 30, 0, 0 }, UpperTorso = { 6, -28, 0 }, LeftUpperArm = { 20, 0, -20 } } },
	{ t = 0.16, pose = { RightUpperArm = { 45, 0, -38 }, RightLowerArm = { 6, 0, 0 }, UpperTorso = { -16, 38, 0 }, LeftUpperArm = { -10, 0, -25 } } },
	{ t = 0.38, pose = EN_GARDE },
} }
C.Sword_Backhand = { rig = "R15", priority = "Action", strike = 0.15, keys = {
	{ t = 0, pose = EN_GARDE },
	{ t = 0.08, pose = { RightUpperArm = { 75, 0, -55 }, RightLowerArm = { 70, 0, 0 }, UpperTorso = { 0, 45, 0 } } },
	{ t = 0.15, pose = { RightUpperArm = { 85, 0, 75 }, RightLowerArm = { 5, 0, 0 }, UpperTorso = { -10, -38, 0 }, LeftUpperArm = { 20, 0, -30 } } },
	{ t = 0.36, pose = EN_GARDE },
} }
C.Sword_Thrust = { rig = "R15", priority = "Action", strike = 0.17, keys = {
	{ t = 0, pose = EN_GARDE },
	{ t = 0.1, pose = { RightUpperArm = { 55, 0, 12 }, RightLowerArm = { 95, 0, 0 }, UpperTorso = { 0, -22, 0 }, LeftUpperArm = { 35, 0, -15 } } },
	{ t = 0.17, pose = { RightUpperArm = { 90, 0, 0 }, RightLowerArm = { 0, 0, 0 }, UpperTorso = { -16, 32, 0 }, LowerTorso = { 0, 0, 0, 0, -0.2, -0.7 },
		RightUpperLeg = { 38, 0, 0 }, RightLowerLeg = { -25, 0, 0 }, LeftUpperLeg = { -22, 0, 0 }, LeftUpperArm = { -20, 0, -30 } } },
	{ t = 0.42, pose = EN_GARDE },
} }

-- ===== Shipwright (Hammer): hammer on the shoulder, overhead smash -> sweep =====
local SHOULDER = { RightUpperArm = { 55, 0, 25 }, RightLowerArm = { 125, 0, 0 }, UpperTorso = { 2, 8, 0 } }
C.Hammer_Stance = { rig = "R15", loop = true, priority = "Idle", length = 1.6, keys = {
	{ t = 0, pose = SHOULDER },
	{ t = 0.8, pose = with(SHOULDER, { UpperTorso = { 4, 8, 0 } }) },
	{ t = 1.6, pose = SHOULDER },
} }
C.Hammer_Smash = { rig = "R15", priority = "Action", strike = 0.26, keys = {
	{ t = 0, pose = SHOULDER },
	{ t = 0.15, pose = { RightUpperArm = { 170, 0, 8 }, RightLowerArm = { 30, 0, 0 }, LeftUpperArm = { 165, 0, -8 }, LeftLowerArm = { 30, 0, 0 }, UpperTorso = { 16, 0, 0 } } },
	{ t = 0.26, pose = { RightUpperArm = { 55, 0, 0 }, RightLowerArm = { 5, 0, 0 }, LeftUpperArm = { 50, 0, 0 }, LeftLowerArm = { 5, 0, 0 }, UpperTorso = { -32, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.6, 0 }, RightUpperLeg = { 30, 0, 0 }, RightLowerLeg = { -40, 0, 0 }, LeftUpperLeg = { 30, 0, 0 }, LeftLowerLeg = { -40, 0, 0 } } },
	{ t = 0.56, pose = SHOULDER },
} }
C.Hammer_Sweep = { rig = "R15", priority = "Action", strike = 0.2, keys = {
	{ t = 0, pose = SHOULDER },
	{ t = 0.11, pose = { RightUpperArm = { 70, 0, -40 }, RightLowerArm = { 30, 0, 0 }, LeftUpperArm = { 70, 0, -10 }, LeftLowerArm = { 40, 0, 0 }, UpperTorso = { 0, 65, 0 } } },
	{ t = 0.2, pose = { RightUpperArm = { 85, 0, 60 }, RightLowerArm = { 5, 0, 0 }, LeftUpperArm = { 80, 0, 30 }, LeftLowerArm = { 20, 0, 0 }, UpperTorso = { -8, -60, 0 }, LowerTorso = { 0, -15, 0 } } },
	{ t = 0.46, pose = SHOULDER },
} }

-- ===== Sniper (Slingshot): draw and release =====
local SLING_READY = { LeftUpperArm = { 40, 0, -10 }, LeftLowerArm = { 30, 0, 0 }, RightUpperArm = { 20, 0, 10 }, RightLowerArm = { 50, 0, 0 } }
C.Sling_Stance = { rig = "R15", loop = true, priority = "Idle", length = 1.4, keys = { { t = 0, pose = SLING_READY }, { t = 0.7, pose = with(SLING_READY, { UpperTorso = { 3, 0, 0 } }) }, { t = 1.4, pose = SLING_READY } } }
C.Sling_Shoot = { rig = "R15", priority = "Action", strike = 0.13, keys = {
	{ t = 0, pose = SLING_READY },
	{ t = 0.1, pose = { LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, RightUpperArm = { 85, 0, -32 }, RightLowerArm = { 125, 0, 0 }, UpperTorso = { 0, -25, 0 }, Head = { 0, 20, 0 } } },
	{ t = 0.13, pose = { LeftUpperArm = { 92, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, RightUpperArm = { 70, 0, 25 }, RightLowerArm = { 50, 0, 0 }, UpperTorso = { 4, -25, 0 }, Head = { 0, 20, 0 } } },
	{ t = 0.36, pose = SLING_READY },
} }

-- ===== Navigator (StormBaton): staff strike that throws lightning =====
local STAFF = { RightUpperArm = { 25, 0, 10 }, RightLowerArm = { 70, 0, 0 } }
C.Baton_Stance = { rig = "R15", loop = true, priority = "Idle", length = 1.6, keys = { { t = 0, pose = STAFF }, { t = 0.8, pose = with(STAFF, { RightUpperArm = { 28, 0, 10 } }) }, { t = 1.6, pose = STAFF } } }
C.Baton_Strike = { rig = "R15", priority = "Action", strike = 0.18, keys = {
	{ t = 0, pose = STAFF },
	{ t = 0.1, pose = { RightUpperArm = { 140, 0, 12 }, RightLowerArm = { 35, 0, 0 }, UpperTorso = { 8, -15, 0 }, LeftUpperArm = { 30, 0, -30 } } },
	{ t = 0.18, pose = { RightUpperArm = { 88, 0, 0 }, RightLowerArm = { 0, 0, 0 }, UpperTorso = { -12, 25, 0 }, LeftUpperArm = { 40, 0, -35 }, LeftLowerArm = { 30, 0, 0 } } },
	{ t = 0.42, pose = STAFF },
} }

-- ===== Doctor (MedKit): underhand toss =====
C.Med_Toss = { rig = "R15", priority = "Action", strike = 0.17, keys = {
	{ t = 0 },
	{ t = 0.1, pose = { RightUpperArm = { -45, 0, 12 }, RightLowerArm = { 15, 0, 0 }, UpperTorso = { 6, 18, 0 } } },
	{ t = 0.17, pose = { RightUpperArm = { 75, 0, 0 }, RightLowerArm = { 20, 0, 0 }, UpperTorso = { -8, -12, 0 } } },
	{ t = 0.38 },
} }

-- ===== skills (shared by every class) =====
C.Skill_Spin = { rig = "R15", priority = "Action", strike = 0.2, keys = {
	{ t = 0 },
	{ t = 0.1, pose = { LowerTorso = { 0, -120, 0 }, RightUpperArm = { 0, 0, 85 }, LeftUpperArm = { 0, 0, -85 }, RightUpperLeg = { 0, 0, 25 } } },
	{ t = 0.2, pose = { LowerTorso = { 0, -240, 0 }, RightUpperArm = { 0, 0, 85 }, LeftUpperArm = { 0, 0, -85 }, RightUpperLeg = { 0, 0, 25 } } },
	{ t = 0.3, pose = { LowerTorso = { 0, -359, 0 }, RightUpperArm = { 0, 0, 85 }, LeftUpperArm = { 0, 0, -85 } } },
	{ t = 0.45 },
} }
C.Skill_GroundPunch = { rig = "R15", priority = "Action", strike = 0.24, keys = {
	{ t = 0 },
	{ t = 0.14, pose = { RightUpperArm = { 175, 0, 15 }, RightLowerArm = { 20, 0, 0 }, UpperTorso = { 18, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.4, 0 } } },
	{ t = 0.24, pose = { RightUpperArm = { 70, 0, 0 }, RightLowerArm = { 0, 0, 0 }, UpperTorso = { -40, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -1.0, 0 },
		RightUpperLeg = { 45, 0, 0 }, RightLowerLeg = { -70, 0, 0 }, LeftUpperLeg = { 10, 0, 0 }, LeftLowerLeg = { -80, 0, 0 } } },
	{ t = 0.55 },
} }
C.Skill_Cast = { rig = "R15", priority = "Action", strike = 0.3, keys = {
	{ t = 0 },
	{ t = 0.15, pose = { RightUpperArm = { 150, 0, 20 }, LeftUpperArm = { 150, 0, -20 }, UpperTorso = { 14, 0, 0 }, Head = { 14, 0, 0 } } },
	{ t = 0.3, pose = { RightUpperArm = { 88, 0, 5 }, LeftUpperArm = { 88, 0, -5 }, UpperTorso = { -14, 0, 0 } } },
	{ t = 0.58 },
} }
C.Skill_PowerUp = { rig = "R15", priority = "Action", strike = 0.2, keys = {
	{ t = 0 },
	{ t = 0.2, pose = { RightUpperArm = { 20, 0, 70 }, LeftUpperArm = { 20, 0, -70 }, RightLowerArm = { 100, 0, 0 }, LeftLowerArm = { 100, 0, 0 },
		UpperTorso = { 12, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -0.35, 0 }, RightUpperLeg = { 15, 0, 15 }, LeftUpperLeg = { 15, 0, -15 }, RightLowerLeg = { -20, 0, 0 }, LeftLowerLeg = { -20, 0, 0 } } },
	{ t = 0.55, pose = { RightUpperArm = { 15, 0, 60 }, LeftUpperArm = { 15, 0, -60 }, RightLowerArm = { 110, 0, 0 }, LeftLowerArm = { 110, 0, 0 }, UpperTorso = { 16, 0, 0 }, Head = { 15, 0, 0 } } },
	{ t = 0.8 },
} }
C.Skill_Bless = { rig = "R15", priority = "Action", strike = 0.25, keys = {
	{ t = 0 },
	{ t = 0.25, pose = { RightUpperArm = { 150, 0, 35 }, LeftUpperArm = { 150, 0, -35 }, RightLowerArm = { 10, 0, 0 }, LeftLowerArm = { 10, 0, 0 }, UpperTorso = { 10, 0, 0 }, Head = { 20, 0, 0 } } },
	{ t = 0.6, pose = { RightUpperArm = { 140, 0, 45 }, LeftUpperArm = { 140, 0, -45 }, UpperTorso = { 8, 0, 0 }, Head = { 15, 0, 0 } } },
	{ t = 0.85 },
} }
C.Hurt = { rig = "R15", priority = "Action2", keys = {
	{ t = 0 },
	{ t = 0.07, pose = { UpperTorso = { 18, 0, 6 }, Head = { 15, 0, 0 }, RightUpperArm = { -15, 0, 20 }, LeftUpperArm = { -15, 0, -20 } } },
	{ t = 0.26 },
} }

-- ===== swimming (v0.24.14, owner): front crawl while moving, treading water when still (Controllers/CharAnim) =====
-- the arms windmill half a cycle apart (up -> forward -> down -> back -> over the top), legs flutter twice per stroke
local function crawl(r, l, kick, twist)
	return {
		RightUpperArm = { r, 0, 12 }, LeftUpperArm = { l, 0, -12 },
		RightLowerArm = { 20, 0, 0 }, LeftLowerArm = { 20, 0, 0 },
		UpperTorso = { -28, twist, 0 }, Head = { 18, -twist * 0.6, 0 },
		RightUpperLeg = { kick, 0, 0 }, LeftUpperLeg = { -kick, 0, 0 },
		RightLowerLeg = { -18, 0, 0 }, LeftLowerLeg = { -18, 0, 0 },
	}
end
C.Swim = { rig = "R15", loop = true, priority = "Action", length = 1.1, keys = {
	{ t = 0, pose = crawl(180, 0, 22, 14) },
	{ t = 0.275, pose = crawl(90, -90, -22, 6) },
	{ t = 0.55, pose = crawl(0, -180, 22, -14) },
	{ t = 0.825, pose = crawl(-90, -270, -22, -6) },
	{ t = 1.1, pose = crawl(-180, -360, 22, 14) },
} }
local function tread(k)
	return {
		RightUpperArm = { 25 + 10 * k, 0, 55 + 12 * k }, LeftUpperArm = { 25 - 10 * k, 0, -(55 - 12 * k) },
		RightLowerArm = { 35, 0, 0 }, LeftLowerArm = { 35, 0, 0 },
		RightUpperLeg = { 30 * k, 0, 6 }, LeftUpperLeg = { -30 * k, 0, -6 },
		RightLowerLeg = { -50 - 15 * k, 0, 0 }, LeftLowerLeg = { -50 + 15 * k, 0, 0 },
		UpperTorso = { -6, 0, 0 }, Head = { 6, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.12 * k, 0 },
	}
end
C.SwimIdle = { rig = "R15", loop = true, priority = "Action", length = 1.6, keys = {
	{ t = 0, pose = tread(1) }, { t = 0.8, pose = tread(-1) }, { t = 1.6, pose = tread(1) },
} }

-- flight (v0.25.17, owner: flying looked stiff or borrowed the swim stroke). Flight.lua tilts the whole body forward
-- with speed, so these only pose limbs: Fly = glide (arms swept back, chin up, legs fluttering), FlyIdle = hover.
local function glide(k)
	return {
		RightUpperArm = { -25 + 6 * k, 0, 16 }, LeftUpperArm = { -25 - 6 * k, 0, -16 },
		RightLowerArm = { 12, 0, 0 }, LeftLowerArm = { 12, 0, 0 },
		UpperTorso = { -10, 0, 0 }, Head = { -30, 0, 0 },
		RightUpperLeg = { 10 * k, 0, 4 }, LeftUpperLeg = { -10 * k, 0, -4 },
		RightLowerLeg = { -14 - 8 * k, 0, 0 }, LeftLowerLeg = { -14 + 8 * k, 0, 0 },
	}
end
C.Fly = { rig = "R15", loop = true, priority = "Action", length = 0.9, keys = {
	{ t = 0, pose = glide(1) }, { t = 0.45, pose = glide(-1) }, { t = 0.9, pose = glide(1) },
} }
local function hover(k)
	return {
		RightUpperArm = { 10, 0, 42 + 8 * k }, LeftUpperArm = { 10, 0, -(42 + 8 * k) },
		RightLowerArm = { 25, 0, 0 }, LeftLowerArm = { 25, 0, 0 },
		RightUpperLeg = { 22 + 4 * k, 0, 4 }, LeftUpperLeg = { 6 - 4 * k, 0, -4 },
		RightLowerLeg = { -45, 0, 0 }, LeftLowerLeg = { -22, 0, 0 },
		UpperTorso = { -4, 0, 0 }, Head = { 4, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.15 * k, 0 },
	}
end
C.FlyIdle = { rig = "R15", loop = true, priority = "Action", length = 1.8, keys = {
	{ t = 0, pose = hover(1) }, { t = 0.9, pose = hover(-1) }, { t = 1.8, pose = hover(1) },
} }

-- ===== monsters (one universal set: every voxel monster has some of these parts) =====
C.Mon_Idle = { rig = "Mon", loop = true, priority = "Idle", length = 2.4, keys = {
	{ t = 0, pose = { Body = { 0, 0, 0 }, Head = { 0, 8, 0 }, Tail = { 0, 14, 0 }, WingL = { 0, 0, 12 }, WingR = { 0, 0, -12 }, ArmL = { 4, 0, 0 }, ArmR = { 4, 0, 0 } } },
	{ t = 0.6, pose = { Body = { -2, 0, 0 }, Head = { 4, 0, 0 }, Tail = { 0, 0, 0 }, WingL = { 0, 0, -10 }, WingR = { 0, 0, 10 }, ArmL = { 0, 0, 0 }, ArmR = { 0, 0, 0 } } },
	{ t = 1.2, pose = { Body = { 0, 0, 0 }, Head = { 0, -8, 0 }, Tail = { 0, -14, 0 }, WingL = { 0, 0, 12 }, WingR = { 0, 0, -12 }, ArmL = { 4, 0, 0 }, ArmR = { 4, 0, 0 } } },
	{ t = 1.8, pose = { Body = { -2, 0, 0 }, Head = { 4, 0, 0 }, Tail = { 0, 0, 0 }, WingL = { 0, 0, -10 }, WingR = { 0, 0, 10 }, ArmL = { 0, 0, 0 }, ArmR = { 0, 0, 0 } } },
	{ t = 2.4, pose = { Body = { 0, 0, 0 }, Head = { 0, 8, 0 }, Tail = { 0, 14, 0 }, WingL = { 0, 0, 12 }, WingR = { 0, 0, -12 }, ArmL = { 4, 0, 0 }, ArmR = { 4, 0, 0 } } },
} }
local function stride(s)
	return { LegL = { 38 * s, 0, 0 }, LegR = { -38 * s, 0, 0 }, LegFL = { 34 * s, 0, 0 }, LegBR = { 34 * s, 0, 0 }, LegFR = { -34 * s, 0, 0 }, LegBL = { -34 * s, 0, 0 },
		ArmL = { -28 * s, 0, 0 }, ArmR = { 28 * s, 0, 0 }, Body = { 0, 4 * s, 3 * s }, Head = { 0, -5 * s, 0 }, Tail = { 0, 22 * s, 0 },
		WingL = { 0, 0, 38 * s }, WingR = { 0, 0, -38 * s } }
end
local PASS = { Body = { -3, 0, 0 }, Head = { 3, 0, 0 }, WingL = { 0, 0, -30 }, WingR = { 0, 0, 30 } }
C.Mon_Walk = { rig = "Mon", loop = true, priority = "Movement", length = 0.6, keys = {
	{ t = 0, pose = stride(1) }, { t = 0.15, pose = PASS }, { t = 0.3, pose = stride(-1) }, { t = 0.45, pose = PASS }, { t = 0.6, pose = stride(1) },
} }
C.Mon_Attack = { rig = "Mon", priority = "Action", strike = 0.24, keys = {
	{ t = 0 },
	{ t = 0.14, pose = { ArmR = { 150, 0, 0 }, ArmL = { 90, 0, 0 }, Body = { 10, 0, 0 }, Head = { 14, 0, 0 }, LegFL = { -35, 0, 0 }, LegFR = { -35, 0, 0 }, Tail = { 0, 35, 0 }, WingL = { 0, 0, 45 }, WingR = { 0, 0, -45 } } },
	{ t = 0.24, pose = { ArmR = { 55, 0, 0 }, ArmL = { 35, 0, 0 }, Body = { -16, 0, 0 }, Head = { -24, 0, 0 }, LegFL = { 40, 0, 0 }, LegFR = { 40, 0, 0 }, Tail = { 0, -30, 0 }, WingL = { 0, 0, -40 }, WingR = { 0, 0, 40 } } },
	{ t = 0.52 },
} }
-- Bay Serpent (v0.22.5; parts Head + Jaw, Jaw hinged at its back): rear back with the jaw gaping, then snap / spit.
-- +X tips the front up (rear back), -X snaps it down; the jaw opens with -X.
C.Mon_SerpentBite = { rig = "Mon", priority = "Action", strike = 0.25, keys = {
	{ t = 0 },
	{ t = 0.18, pose = { Head = { 16, 0, 0 }, Jaw = { -38, 0, 0 } } },
	{ t = 0.25, pose = { Head = { -14, 0, 0 }, Jaw = { -42, 0, 0 } } },
	{ t = 0.36, pose = { Head = { -10, 0, 0 }, Jaw = { 0, 0, 0 } } },
	{ t = 0.75 },
} }
C.Mon_SerpentSpit = { rig = "Mon", priority = "Action", strike = 0.5, keys = {
	{ t = 0 },
	{ t = 0.4, pose = { Head = { 22, 0, 0 }, Jaw = { -20, 0, 0 } } },
	{ t = 0.5, pose = { Head = { -8, 0, 0 }, Jaw = { -40, 0, 0 } } },
	{ t = 0.95, pose = { Head = { -6, 0, 0 }, Jaw = { -36, 0, 0 } } },
	{ t = 1.2 },
} }
C.Mon_Hit = { rig = "Mon", priority = "Action2", keys = {
	{ t = 0 },
	{ t = 0.07, pose = { Body = { 14, 0, 0 }, Head = { 18, 0, 0 }, ArmL = { -20, 0, 0 }, ArmR = { -20, 0, 0 }, Tail = { 0, 15, 0 } } },
	{ t = 0.26 },
} }

-- ===== Cursed Fruit: Bounce Bounce (v0.25.66, docs/Plan-Fruits-v2.md) =====
-- Skills name these with `anim`; `chargeAnim` loops while a charge skill's key is held (Controllers/Combat startAim).
-- The stretching arms themselves are FX (Controllers/FruitFX): the real forearm + hand hide while the rubber arm is out.
local WIND_R = { -- right arm flung far back, left arm points at the target, weight on the back leg
	RightUpperArm = { -78, 0, 22 }, RightLowerArm = { 12, 0, 0 }, LeftUpperArm = { 75, 0, -8 }, LeftLowerArm = { 12, 0, 0 },
	UpperTorso = { -6, -42, 0 }, Head = { 0, 34, 0 }, LowerTorso = { 0, -14, 0, 0, -0.3, 0.15 },
	RightUpperLeg = { -12, 0, 6 }, RightLowerLeg = { -28, 0, 0 }, LeftUpperLeg = { 30, 0, -4 }, LeftLowerLeg = { -32, 0, 0 },
}
local PISTOL = { -- straight right punch, shoulder thrown into it
	RightUpperArm = { 90, 0, 2 }, RightLowerArm = { 0, 0, 0 }, LeftUpperArm = { 28, 0, -28 }, LeftLowerArm = { 95, 0, 0 },
	UpperTorso = { -12, 40, 0 }, Head = { 0, -26, 0 }, LowerTorso = { 0, 14, 0, 0, -0.25, -0.25 },
	RightUpperLeg = { -18, 0, 4 }, RightLowerLeg = { -12, 0, 0 }, LeftUpperLeg = { 34, 0, -4 }, LeftLowerLeg = { -30, 0, 0 },
}
C.Bounce_Wind = { rig = "R15", loop = true, priority = "Action", length = 0.3, keys = {
	{ t = 0, pose = WIND_R },
	{ t = 0.15, pose = with(WIND_R, { RightUpperArm = { -86, 0, 26 }, UpperTorso = { -6, -46, 0 } }) },
	{ t = 0.3, pose = WIND_R },
} }
C.Bounce_Pistol = { rig = "R15", priority = "Action", strike = 0.08, keys = {
	{ t = 0, pose = WIND_R },
	{ t = 0.08, pose = PISTOL },
	{ t = 0.42, pose = with(PISTOL, { UpperTorso = { -10, 34, 0 } }) },
	{ t = 0.62 },
} }
-- Bounce Gatling: both fists pumping in turn (8 punches in 0.56 s), low wide stance
local GAT_LEGS = { LowerTorso = { 0, 0, 0, 0, -0.35, 0 }, RightUpperLeg = { -8, 0, 10 }, RightLowerLeg = { -22, 0, 0 }, LeftUpperLeg = { 26, 0, -10 }, LeftLowerLeg = { -30, 0, 0 } }
local GAT_R = with(GAT_LEGS, { RightUpperArm = { 90, 0, 4 }, RightLowerArm = { 0, 0, 0 }, LeftUpperArm = { 40, 0, -18 }, LeftLowerArm = { 115, 0, 0 }, UpperTorso = { -12, 24, 0 }, Head = { 0, -18, 0 } })
local GAT_L = with(GAT_LEGS, { LeftUpperArm = { 90, 0, -4 }, LeftLowerArm = { 0, 0, 0 }, RightUpperArm = { 40, 0, 18 }, RightLowerArm = { 115, 0, 0 }, UpperTorso = { -12, -24, 0 }, Head = { 0, 18, 0 } })
do
	local keys = { { t = 0, pose = with(GAT_LEGS, GUARD) } }
	for i = 1, 8 do
		table.insert(keys, { t = 0.07 * i - 0.03, pose = i % 2 == 1 and GAT_R or GAT_L })
	end
	table.insert(keys, { t = 0.78 })
	C.Bounce_Gatling = { rig = "R15", priority = "Action", strike = 0.04, keys = keys }
end
-- Recoil Cannon: both arms stretched far back (crouched like a drawn slingshot), then a two-palm shove
local WIND_BOTH = {
	RightUpperArm = { -72, 0, 26 }, LeftUpperArm = { -72, 0, -26 }, RightLowerArm = { 15, 0, 0 }, LeftLowerArm = { 15, 0, 0 },
	UpperTorso = { -20, 0, 0 }, Head = { 18, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -0.55, 0.2 },
	RightUpperLeg = { 34, 0, 6 }, RightLowerLeg = { -55, 0, 0 }, LeftUpperLeg = { -14, 0, -6 }, LeftLowerLeg = { -30, 0, 0 },
}
local CANNON = {
	RightUpperArm = { 88, 0, -8 }, LeftUpperArm = { 88, 0, 8 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 0, 0, 0 },
	RightHand = { -70, 0, 0 }, LeftHand = { -70, 0, 0 },
	UpperTorso = { -16, 0, 0 }, Head = { 10, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -0.35, -0.45 },
	RightUpperLeg = { 36, 0, 4 }, RightLowerLeg = { -40, 0, 0 }, LeftUpperLeg = { -26, 0, -4 }, LeftLowerLeg = { -10, 0, 0 },
}
C.Bounce_WindBoth = { rig = "R15", loop = true, priority = "Action", length = 0.3, keys = {
	{ t = 0, pose = WIND_BOTH },
	{ t = 0.15, pose = with(WIND_BOTH, { RightUpperArm = { -80, 0, 30 }, LeftUpperArm = { -80, 0, -30 } }) },
	{ t = 0.3, pose = WIND_BOTH },
} }
C.Bounce_Cannon = { rig = "R15", priority = "Action", strike = 0.1, keys = {
	{ t = 0, pose = WIND_BOTH },
	{ t = 0.1, pose = CANNON },
	{ t = 0.48, pose = with(CANNON, { UpperTorso = { -12, 0, 0 } }) },
	{ t = 0.72 },
} }
-- Balloon Body: a huge breath in (lean back, arms out), then puffed up with the arms held wide
local PUFFED = { RightUpperArm = { 8, 0, 70 }, LeftUpperArm = { 8, 0, -70 }, RightLowerArm = { 20, 0, 0 }, LeftLowerArm = { 20, 0, 0 },
	UpperTorso = { 6, 0, 0 }, Head = { 8, 0, 0 }, RightUpperLeg = { 0, 0, 14 }, LeftUpperLeg = { 0, 0, -14 } }
C.Bounce_Balloon = { rig = "R15", priority = "Action", strike = 0.45, keys = {
	{ t = 0 },
	{ t = 0.28, pose = { UpperTorso = { 22, 0, 0 }, Head = { 26, 0, 0 }, RightUpperArm = { -10, 0, 38 }, LeftUpperArm = { -10, 0, -38 },
		RightLowerArm = { 30, 0, 0 }, LeftLowerArm = { 30, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.1, 0 } } },
	{ t = 0.45, pose = PUFFED },
	{ t = 0.75, pose = PUFFED },
	{ t = 0.95 },
} }
-- Pump Up: a low crouch, fists at the hips pumping twice, then a flex as the steam bursts out
local PUMP = with(CROUCH, { RightUpperArm = { -18, 0, 28 }, LeftUpperArm = { -18, 0, -28 }, RightLowerArm = { 95, 0, 0 }, LeftLowerArm = { 95, 0, 0 },
	UpperTorso = { -22, 0, 0 }, Head = { 18, 0, 0 } })
local PUMP_DEEP = with(PUMP, { LowerTorso = { 0, 0, 0, 0, -0.6, 0 }, RightUpperLeg = { 40, 0, 8 }, LeftUpperLeg = { 40, 0, -8 }, RightLowerLeg = { -60, 0, 0 }, LeftLowerLeg = { -60, 0, 0 }, UpperTorso = { -30, 0, 0 } })
C.Bounce_PumpUp = { rig = "R15", priority = "Action", strike = 0.5, keys = {
	{ t = 0 },
	{ t = 0.12, pose = PUMP }, { t = 0.24, pose = PUMP_DEEP }, { t = 0.36, pose = PUMP }, { t = 0.48, pose = PUMP_DEEP },
	{ t = 0.62, pose = { RightUpperArm = { 0, 0, 88 }, LeftUpperArm = { 0, 0, -88 }, RightLowerArm = { 0, 0, 100 }, LeftLowerArm = { 0, 0, -100 },
		UpperTorso = { 10, 0, 0 }, Head = { 12, 0, 0 }, RightUpperLeg = { 0, 0, 12 }, LeftUpperLeg = { 0, 0, -12 } } },
	{ t = 0.9, pose = { RightUpperArm = { 0, 0, 85 }, LeftUpperArm = { 0, 0, -85 }, RightLowerArm = { 0, 0, 95 }, LeftLowerArm = { 0, 0, -95 }, UpperTorso = { 8, 0, 0 } } },
	{ t = 1.1 },
} }
-- Slingshot Launch: braced and leaning back while both arms hold the far point, then flying arms-first after them
C.Bounce_SlingGrab = { rig = "R15", loop = true, priority = "Action", length = 0.4, keys = {
	{ t = 0, pose = { RightUpperArm = { 98, 0, -6 }, LeftUpperArm = { 98, 0, 6 }, UpperTorso = { 16, 0, 0 }, Head = { -10, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.45, 0.35 }, RightUpperLeg = { 30, 0, 4 }, RightLowerLeg = { -55, 0, 0 }, LeftUpperLeg = { -10, 0, -4 }, LeftLowerLeg = { -25, 0, 0 } } },
	{ t = 0.2, pose = { RightUpperArm = { 100, 0, -6 }, LeftUpperArm = { 100, 0, 6 }, UpperTorso = { 20, 0, 0 }, Head = { -12, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.5, 0.4 }, RightUpperLeg = { 32, 0, 4 }, RightLowerLeg = { -58, 0, 0 }, LeftUpperLeg = { -12, 0, -4 }, LeftLowerLeg = { -25, 0, 0 } } },
	{ t = 0.4, pose = { RightUpperArm = { 98, 0, -6 }, LeftUpperArm = { 98, 0, 6 }, UpperTorso = { 16, 0, 0 }, Head = { -10, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.45, 0.35 }, RightUpperLeg = { 30, 0, 4 }, RightLowerLeg = { -55, 0, 0 }, LeftUpperLeg = { -10, 0, -4 }, LeftLowerLeg = { -25, 0, 0 } } },
} }
local SLING_FLY = { LowerTorso = { -70, 0, 0 }, RightUpperArm = { 165, 0, 6 }, LeftUpperArm = { 165, 0, -6 }, Head = { 40, 0, 0 },
	RightUpperLeg = { -12, 0, 4 }, LeftUpperLeg = { -22, 0, -4 }, LeftLowerLeg = { -35, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }
C.Bounce_SlingFly = { rig = "R15", loop = true, priority = "Action", length = 0.4, keys = {
	{ t = 0, pose = SLING_FLY },
	{ t = 0.2, pose = with(SLING_FLY, { RightUpperLeg = { -20, 0, 4 }, LeftUpperLeg = { -14, 0, -4 }, LeftLowerLeg = { -20, 0, 0 }, RightLowerLeg = { -30, 0, 0 } }) },
	{ t = 0.4, pose = SLING_FLY },
} }

-- ===== Cursed Fruit: Blaze Blaze (v0.25.74, docs/Plan-Fruits-v2.md phase 3) =====
local BLAZE_WIND = with(WIND_R, { RightUpperArm = { -42, 0, 32 }, RightLowerArm = { 105, 0, 0 }, UpperTorso = { -12, -52, 0 }, Head = { 0, 40, 0 },
	LeftUpperArm = { 70, 0, -14 }, LeftLowerArm = { 25, 0, 0 }, LowerTorso = { 0, -16, 0, 0, -0.45, 0.15 } })
local BLAZE_PUNCH = with(PISTOL, { UpperTorso = { -16, 46, 0 }, LowerTorso = { 0, 18, 0, 0, -0.4, -0.45 }, RightUpperLeg = { -26, 0, 4 }, LeftUpperLeg = { 44, 0, -4 }, LeftLowerLeg = { -40, 0, 0 } })
C.Blaze_Wind = { rig = "R15", loop = true, priority = "Action", length = 0.3, keys = {
	{ t = 0, pose = BLAZE_WIND },
	{ t = 0.15, pose = with(BLAZE_WIND, { UpperTorso = { -12, -56, 0 }, RightUpperArm = { -46, 0, 34 } }) },
	{ t = 0.3, pose = BLAZE_WIND },
} }
C.Blaze_Fist = { rig = "R15", priority = "Action", strike = 0.08, keys = {
	{ t = 0, pose = BLAZE_WIND },
	{ t = 0.08, pose = BLAZE_PUNCH },
	{ t = 0.4, pose = with(BLAZE_PUNCH, { UpperTorso = { -12, 40, 0 } }) },
	{ t = 0.62 },
} }
-- Flame Twister: a crouch, then the right hand thrust up at the sky (the twister rises from the ground)
local SKY = { RightUpperArm = { 178, 0, 8 }, RightLowerArm = { 0, 0, 0 }, LeftUpperArm = { 25, 0, -55 }, LeftLowerArm = { 30, 0, 0 },
	UpperTorso = { 12, 0, 0 }, Head = { 24, 0, 0 }, RightUpperLeg = { 0, 0, 10 }, LeftUpperLeg = { 0, 0, -10 } }
C.Blaze_Twister = { rig = "R15", priority = "Action", strike = 0.3, keys = {
	{ t = 0 },
	{ t = 0.16, pose = with(CROUCH, { RightUpperArm = { -20, 0, 20 }, LeftUpperArm = { -20, 0, -20 }, UpperTorso = { -18, 0, 0 } }) },
	{ t = 0.3, pose = SKY },
	{ t = 0.75, pose = with(SKY, { RightUpperArm = { 174, 0, 12 } }) },
	{ t = 0.95 },
} }
-- Emberflies: a finger pointed at the enemy (the sparks drift off it)
local POINT = { RightUpperArm = { 88, 0, -2 }, RightLowerArm = { 0, 0, 0 }, RightHand = { 0, 0, 0 }, LeftUpperArm = { -10, 0, -18 }, LeftLowerArm = { 30, 0, 0 },
	UpperTorso = { -4, 28, 0 }, Head = { 0, -22, 0 }, LowerTorso = { 0, 10, 0 } }
C.Blaze_Ember = { rig = "R15", priority = "Action", strike = 0.2, keys = {
	{ t = 0 },
	{ t = 0.12, pose = with(POINT, { RightUpperArm = { 70, 0, -2 } }) },
	{ t = 0.2, pose = POINT },
	{ t = 0.6, pose = POINT },
	{ t = 0.8 },
} }
-- Inferno: arms crossed in front, then flung wide as the sea of fire bursts out
local FLUNG = { RightUpperArm = { 30, 0, 115 }, LeftUpperArm = { 30, 0, -115 }, RightLowerArm = { 10, 0, 0 }, LeftLowerArm = { 10, 0, 0 },
	UpperTorso = { 16, 0, 0 }, Head = { 22, 0, 0 }, RightUpperLeg = { 0, 0, 16 }, LeftUpperLeg = { 0, 0, -16 }, LowerTorso = { 0, 0, 0, 0, -0.15, 0 } }
C.Blaze_Inferno = { rig = "R15", priority = "Action", strike = 0.35, keys = {
	{ t = 0 },
	{ t = 0.2, pose = with(CROUCH, { RightUpperArm = { 62, 0, -38 }, LeftUpperArm = { 62, 0, 38 }, RightLowerArm = { 95, 0, 0 }, LeftLowerArm = { 95, 0, 0 }, UpperTorso = { -22, 0, 0 } }) },
	{ t = 0.35, pose = FLUNG },
	{ t = 0.85, pose = FLUNG },
	{ t = 1.05 },
} }

-- ===== Cursed Fruit: Haze Haze (v0.25.76, phase 4). Smoke Fist reuses Blaze_Wind / Blaze_Fist =====
-- Smoke Grip: the arm shoots out at the target, then yanks back hard (the smoke arm drags the enemy in)
local REACH = { RightUpperArm = { 92, 0, -4 }, RightLowerArm = { 0, 0, 0 }, RightHand = { -20, 0, 0 }, LeftUpperArm = { 20, 0, -30 }, LeftLowerArm = { 60, 0, 0 },
	UpperTorso = { -14, 30, 0 }, Head = { 0, -24, 0 }, LowerTorso = { 0, 12, 0, 0, -0.2, -0.3 }, RightUpperLeg = { -14, 0, 0 }, LeftUpperLeg = { 30, 0, 0 }, LeftLowerLeg = { -30, 0, 0 } }
local YANK = { RightUpperArm = { 20, 0, 30 }, RightLowerArm = { 120, 0, 0 }, RightHand = { 40, 0, 0 }, LeftUpperArm = { 40, 0, -20 }, LeftLowerArm = { 70, 0, 0 },
	UpperTorso = { 10, -30, 0 }, Head = { 6, 20, 0 }, LowerTorso = { 0, -14, 0, 0, -0.3, 0.35 }, RightUpperLeg = { 30, 0, 0 }, RightLowerLeg = { -50, 0, 0 }, LeftUpperLeg = { -14, 0, 0 } }
C.Haze_Grip = { rig = "R15", priority = "Action", strike = 0.12, keys = {
	{ t = 0 },
	{ t = 0.12, pose = REACH },
	{ t = 0.34, pose = REACH },
	{ t = 0.46, pose = YANK },
	{ t = 0.7, pose = YANK },
	{ t = 0.9 },
} }
-- Smoke Screen: a wide sweep of both arms (the cloud rolls out)
C.Haze_Screen = { rig = "R15", priority = "Action", strike = 0.28, keys = {
	{ t = 0 },
	{ t = 0.14, pose = { RightUpperArm = { 60, 0, -50 }, LeftUpperArm = { 60, 0, 50 }, RightLowerArm = { 40, 0, 0 }, LeftLowerArm = { 40, 0, 0 }, UpperTorso = { -10, 0, 0 } } },
	{ t = 0.28, pose = { RightUpperArm = { 70, 0, 80 }, LeftUpperArm = { 70, 0, -80 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, UpperTorso = { -6, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -0.25, 0 },
		RightUpperLeg = { 14, 0, 12 }, LeftUpperLeg = { 14, 0, -12 }, RightLowerLeg = { -22, 0, 0 }, LeftLowerLeg = { -22, 0, 0 } } },
	{ t = 0.6, pose = { RightUpperArm = { 60, 0, 85 }, LeftUpperArm = { 60, 0, -85 }, UpperTorso = { -4, 0, 0 } } },
	{ t = 0.8 },
} }
-- White Out: arms crossed tight, a spin as the body dissolves into the twister
C.Haze_Vanish = { rig = "R15", priority = "Action", strike = 0.25, keys = {
	{ t = 0 },
	{ t = 0.12, pose = with(CROUCH, { RightUpperArm = { 70, 0, -45 }, LeftUpperArm = { 70, 0, 45 }, RightLowerArm = { 110, 0, 0 }, LeftLowerArm = { 110, 0, 0 }, UpperTorso = { -20, 0, 0 } }) },
	{ t = 0.25, pose = { LowerTorso = { 0, -180, 0, 0, 0.3, 0 }, RightUpperArm = { 20, 0, 70 }, LeftUpperArm = { 20, 0, -70 }, Head = { 15, 0, 0 } } },
	{ t = 0.4, pose = { LowerTorso = { 0, -359, 0, 0, 0.3, 0 }, RightUpperArm = { 20, 0, 70 }, LeftUpperArm = { 20, 0, -70 } } },
	{ t = 0.6 },
} }

-- ===== v0.25.77 (owner): Navigator swings the baton TWO-HANDED like a club (not a sword): left hand on the shaft =====
local TWO_UP = { RightUpperArm = { 150, 0, 30 }, RightLowerArm = { 40, 0, 0 }, LeftUpperArm = { 140, 0, 35 }, LeftLowerArm = { 50, 0, 0 } }
C.Baton_Smash1 = { rig = "R15", priority = "Action", strike = 0.16, keys = { -- diagonal chop from over the right shoulder
	{ t = 0, pose = STAFF },
	{ t = 0.09, pose = with(TWO_UP, { UpperTorso = { 10, 30, 0 }, LowerTorso = { 0, 10, 0 } }) },
	{ t = 0.16, pose = { RightUpperArm = { 55, 0, -20 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 60, 0, 32 }, LeftLowerArm = { 25, 0, 0 }, UpperTorso = { -22, -32, 0 }, LowerTorso = { 0, -10, 0, 0, -0.2, -0.15 } } },
	{ t = 0.4, pose = STAFF },
} }
C.Baton_Swing2 = { rig = "R15", priority = "Action", strike = 0.15, keys = { -- flat backhand sweep, right to left
	{ t = 0, pose = STAFF },
	{ t = 0.08, pose = { RightUpperArm = { 80, 0, 60 }, RightLowerArm = { 30, 0, 0 }, LeftUpperArm = { 75, 0, 55 }, LeftLowerArm = { 50, 0, 0 }, UpperTorso = { -4, 45, 0 }, LowerTorso = { 0, 15, 0 } } },
	{ t = 0.15, pose = { RightUpperArm = { 85, 0, -50 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 82, 0, -30 }, LeftLowerArm = { 25, 0, 0 }, UpperTorso = { -8, -48, 0 }, LowerTorso = { 0, -18, 0 } } },
	{ t = 0.4, pose = STAFF },
} }
C.Baton_Rise3 = { rig = "R15", priority = "Action", strike = 0.16, keys = { -- low to high rising swing
	{ t = 0, pose = STAFF },
	{ t = 0.08, pose = with(CROUCH, { RightUpperArm = { -30, 0, 25 }, RightLowerArm = { 20, 0, 0 }, LeftUpperArm = { -20, 0, 35 }, LeftLowerArm = { 30, 0, 0 }, UpperTorso = { -20, 20, 0 } }) },
	{ t = 0.16, pose = { RightUpperArm = { 160, 0, 10 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 150, 0, 25 }, LeftLowerArm = { 25, 0, 0 }, UpperTorso = { 14, -10, 0 }, Head = { 10, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.15, 0 } } },
	{ t = 0.42, pose = STAFF },
} }
C.Baton_Slam4 = { rig = "R15", priority = "Action", strike = 0.24, keys = { -- the finisher: a huge two-hand overhead slam
	{ t = 0, pose = STAFF },
	{ t = 0.14, pose = with(TWO_UP, { RightUpperArm = { 175, 0, 8 }, LeftUpperArm = { 170, 0, 12 }, UpperTorso = { 16, 0, 0 }, Head = { 14, 0, 0 }, LowerTorso = { 0, 0, 0, 0, 0.25, 0 } }) },
	{ t = 0.24, pose = { RightUpperArm = { 40, 0, -8 }, LeftUpperArm = { 42, 0, 12 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 10, 0, 0 }, UpperTorso = { -40, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.85, -0.2 }, RightUpperLeg = { 45, 0, 4 }, RightLowerLeg = { -70, 0, 0 }, LeftUpperLeg = { -5, 0, -4 }, LeftLowerLeg = { -60, 0, 0 } } },
	{ t = 0.55, pose = STAFF },
} }
-- Baton Flurry: the baton whirled round you three times (three hits)
local TWIRL = { RightUpperArm = { 80, 0, 70 }, RightLowerArm = { 0, 0, 0 }, LeftUpperArm = { 40, 0, -50 }, LowerTorso = { 0, 0, 0, 0, -0.2, 0 }, RightUpperLeg = { 10, 0, 12 }, LeftUpperLeg = { 10, 0, -12 } }
C.Baton_Twirl = { rig = "R15", priority = "Action", strike = 0.12, keys = {
	{ t = 0, pose = STAFF },
	{ t = 0.06, pose = TWIRL },
	{ t = 0.14, pose = with(TWIRL, { LowerTorso = { 0, -120, 0, 0, -0.2, 0 } }) },
	{ t = 0.22, pose = with(TWIRL, { LowerTorso = { 0, -240, 0, 0, -0.2, 0 } }) },
	{ t = 0.3, pose = with(TWIRL, { LowerTorso = { 0, -359, 0, 0, -0.2, 0 } }) },
	{ t = 0.38, pose = with(TWIRL, { LowerTorso = { 0, -479, 0, 0, -0.2, 0 } }) },
	{ t = 0.46, pose = with(TWIRL, { LowerTorso = { 0, -599, 0, 0, -0.2, 0 } }) },
	{ t = 0.54, pose = with(TWIRL, { LowerTorso = { 0, -719, 0, 0, -0.2, 0 } }) },
	{ t = 0.75, pose = STAFF },
} }
-- Trick Vault: the baton planted behind, then a one-legged flying kick forward along the dash
local VAULT_KICK = { RightUpperLeg = { 95, 0, 0 }, RightLowerLeg = { -5, 0, 0 }, LeftUpperLeg = { -30, 0, 0 }, LeftLowerLeg = { -70, 0, 0 },
	UpperTorso = { 20, 0, 0 }, RightUpperArm = { -60, 0, 25 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 50, 0, -40 }, Head = { -10, 0, 0 } }
C.Baton_Vault = { rig = "R15", priority = "Action", strike = 0.1, keys = {
	{ t = 0, pose = { RightUpperArm = { -40, 0, 20 }, RightLowerArm = { 20, 0, 0 }, UpperTorso = { -15, 0, 0 }, LowerTorso = { 0, 0, 0, 0, -0.3, 0 }, RightUpperLeg = { 20, 0, 0 }, RightLowerLeg = { -40, 0, 0 } } },
	{ t = 0.1, pose = VAULT_KICK },
	{ t = 0.45, pose = VAULT_KICK },
	{ t = 0.65 },
} }
-- ===== v0.25.77 Sea Cook "Tabletop Tempest": a handstand, legs spread, spinning fast to sweep everything around =====
local HANDSTAND = { LowerTorso = { 180, 0, 0, 0, 2.3, 0 }, RightUpperArm = { 180, 0, 0 }, LeftUpperArm = { 180, 0, 0 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 0, 0, 0 },
	RightUpperLeg = { 0, 0, 70 }, LeftUpperLeg = { 0, 0, -70 }, RightLowerLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, Head = { -20, 0, 0 } }
do
	local keys = { { t = 0 }, { t = 0.12, pose = HANDSTAND } }
	for i = 1, 8 do
		local h = table.clone(HANDSTAND)
		h.LowerTorso = { 180, i * 120, 0, 0, 2.3, 0 }
		table.insert(keys, { t = 0.12 + i * 0.1, pose = h })
	end
	table.insert(keys, { t = 1.12 })
	C.Cook_Tempest = { rig = "R15", priority = "Action", strike = 0.2, keys = keys }
end
-- ===== v0.25.77 Blaze Inferno (owner): both arms up feeding a giant fireball, then hurled forward =====
local BALL_UP = { RightUpperArm = { 170, 0, 18 }, LeftUpperArm = { 170, 0, -18 }, RightLowerArm = { 25, 0, 0 }, LeftLowerArm = { 25, 0, 0 }, UpperTorso = { 14, 0, 0 }, Head = { 22, 0, 0 },
	RightUpperLeg = { 0, 0, 10 }, LeftUpperLeg = { 0, 0, -10 } }
C.Blaze_BallCharge = { rig = "R15", loop = true, priority = "Action", length = 0.4, keys = {
	{ t = 0, pose = BALL_UP },
	{ t = 0.2, pose = with(BALL_UP, { RightUpperArm = { 166, 0, 22 }, LeftUpperArm = { 166, 0, -22 }, UpperTorso = { 16, 0, 0 } }) },
	{ t = 0.4, pose = BALL_UP },
} }
C.Blaze_BallThrow = { rig = "R15", priority = "Action", strike = 0.14, keys = {
	{ t = 0, pose = BALL_UP },
	{ t = 0.14, pose = { RightUpperArm = { 80, 0, -10 }, LeftUpperArm = { 80, 0, 10 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, UpperTorso = { -24, 0, 0 },
		LowerTorso = { 0, 0, 0, 0, -0.3, -0.35 }, RightUpperLeg = { 34, 0, 4 }, RightLowerLeg = { -45, 0, 0 }, LeftUpperLeg = { -20, 0, -4 } } },
	{ t = 0.5, pose = { RightUpperArm = { 75, 0, -10 }, LeftUpperArm = { 75, 0, 10 }, UpperTorso = { -18, 0, 0 } } },
	{ t = 0.7 },
} }

-- weapon -> combo clips (in order), stance, and the clips each skill kind uses
C.Weapons = {
	-- freestyle street fighting: jab, cross, body blow, hook, knee, elbow, spinning backfist (the uppercut is a skill now)
	-- 4-hit strings (GameConfig.M1): the 4th clip is the knockback finisher
	Knuckles = { combo = { "Brawler_Jab", "Brawler_Cross", "Brawler_Hook", "Brawler_Backfist" }, stance = "Brawler_Stance", Melee = "Brawler_Uppercut", AoE = "Skill_GroundPunch" },
	-- bare hands (no weapon equipped): simple jab-cross punches, no stance
	Fists = { combo = { "Brawler_Jab", "Brawler_Cross", "Brawler_Jab", "Brawler_Hook" }, Melee = "Brawler_Uppercut", AoE = "Skill_GroundPunch" },
	Shoes = { combo = { "Cook_FrontKick", "Cook_SideKick", "Cook_BackKick", "Cook_AxeKick" }, stance = "Cook_Stance", Melee = "Cook_FlyingKick", AoE = "Skill_Spin" },
	Sword = { combo = { "Sword_Slash", "Sword_Backhand", "Sword_Slash", "Sword_Thrust" }, stance = "Sword_Stance", Melee = "Sword_Thrust", AoE = "Skill_Spin" },
	Hammer = { combo = { "Hammer_Sweep", "Hammer_Sweep", "Hammer_Sweep", "Hammer_Smash" }, stance = "Hammer_Stance", Melee = "Hammer_Smash", AoE = "Hammer_Smash" },
	Slingshot = { combo = { "Sling_Shoot", "Sling_Shoot", "Sling_Shoot", "Sling_Shoot" }, stance = "Sling_Stance", Ranged = "Sling_Shoot", Melee = "Sling_Shoot" },
	StormBaton = { combo = { "Baton_Smash1", "Baton_Swing2", "Baton_Rise3", "Baton_Slam4" }, stance = "Baton_Stance", Ranged = "Baton_Smash1", Melee = "Baton_Smash1" },
	MedKit = { combo = { "Med_Toss", "Med_Toss", "Med_Toss", "Med_Toss" }, Ranged = "Med_Toss", Melee = "Med_Toss" },
}
-- Heavy Attack (the starter skill): a big kick for kick fighters, a big punch for everyone else
function C.HeavyFor(weaponType)
	return weaponType == "Shoes" and "Cook_AxeKick" or "Brawler_Hook"
end
C.SkillKinds = { Melee = "Brawler_Uppercut", Dash = "Brawler_Cross", Ranged = "Skill_Cast", AoE = "Skill_GroundPunch", GroundAoE = "Skill_Cast",
	Heal = "Skill_Bless", PartyHeal = "Skill_Bless", Buff = "Skill_PowerUp", PartyBuff = "Skill_PowerUp" }

return C
