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

-- weapon -> combo clips (in order), stance, and the clips each skill kind uses
C.Weapons = {
	-- freestyle street fighting: jab, cross, body blow, hook, knee, elbow, spinning backfist (the uppercut is a skill now)
	Knuckles = { combo = { "Brawler_Jab", "Brawler_Cross", "Brawler_BodyBlow", "Brawler_Hook", "Brawler_Knee", "Brawler_Elbow", "Brawler_Backfist" }, stance = "Brawler_Stance", Melee = "Brawler_Uppercut", AoE = "Skill_GroundPunch" },
	-- bare hands (no weapon equipped): simple jab-cross punches, no stance
	Fists = { combo = { "Brawler_Jab", "Brawler_Cross" }, Melee = "Brawler_Uppercut", AoE = "Skill_GroundPunch" },
	Shoes = { combo = { "Cook_FrontKick", "Cook_SideKick", "Cook_BackKick", "Cook_AxeKick" }, stance = "Cook_Stance", Melee = "Cook_FlyingKick", AoE = "Skill_Spin" },
	Sword = { combo = { "Sword_Slash", "Sword_Backhand", "Sword_Thrust" }, stance = "Sword_Stance", Melee = "Sword_Thrust", AoE = "Skill_Spin" },
	Hammer = { combo = { "Hammer_Smash", "Hammer_Sweep" }, stance = "Hammer_Stance", Melee = "Hammer_Smash", AoE = "Hammer_Smash" },
	Slingshot = { combo = { "Sling_Shoot" }, stance = "Sling_Stance", Ranged = "Sling_Shoot", Melee = "Sling_Shoot" },
	StormBaton = { combo = { "Baton_Strike" }, stance = "Baton_Stance", Ranged = "Baton_Strike", Melee = "Baton_Strike" },
	MedKit = { combo = { "Med_Toss" }, Ranged = "Med_Toss", Melee = "Med_Toss" },
}
-- Heavy Attack (the starter skill): a big kick for kick fighters, a big punch for everyone else
function C.HeavyFor(weaponType)
	return weaponType == "Shoes" and "Cook_AxeKick" or "Brawler_Hook"
end
C.SkillKinds = { Melee = "Brawler_Uppercut", Dash = "Brawler_Cross", Ranged = "Skill_Cast", AoE = "Skill_GroundPunch", GroundAoE = "Skill_Cast",
	Heal = "Skill_Bless", PartyHeal = "Skill_Bless", Buff = "Skill_PowerUp", PartyBuff = "Skill_PowerUp" }

return C
