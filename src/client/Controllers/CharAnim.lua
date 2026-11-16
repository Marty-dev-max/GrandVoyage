-- CharAnim (client): procedural attack poses for R15 characters + hit feel (hitstop, camera shake).
-- Poses are layered on the Motor6D.C0 of each joint (Roblox's walk/idle animation keeps writing Transform underneath),
-- so a punch plays while running. Every client poses every character from the server's FX (BasicAttack / Skill /
-- Damage), so everyone sees the same moves. Avatars are uniform R15 (PlayerService.normalizeAvatar).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)

local CharAnim = {}

local A = CFrame.Angles
local JOINTS = {
	Waist = "UpperTorso", Neck = "Head",
	RightShoulder = "RightUpperArm", LeftShoulder = "LeftUpperArm", RightElbow = "RightLowerArm", LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg", LeftHip = "LeftUpperLeg", RightKnee = "RightLowerLeg", LeftKnee = "LeftLowerLeg",
}

-- a clip = keyframes { t (s), pose = { joint = CFrame } }; joints left out of a key go back to rest.
-- Axes (R15, character faces -Z): +X on a shoulder/hip swings the limb FORWARD, +Y on the waist turns the right side
-- forward, -X on the waist leans forward.
local CLIPS = {
	JabR = { { t = 0 }, { t = 0.06, pose = { RightShoulder = A(0.7, 0, 0.2), RightElbow = A(1.4, 0, 0), Waist = A(0, -0.25, 0) } },
		{ t = 0.13, pose = { RightShoulder = A(1.55, 0, 0), RightElbow = A(0.05, 0, 0), Waist = A(-0.1, 0.45, 0), LeftShoulder = A(0.4, 0, 0) } },
		{ t = 0.3 } },
	JabL = { { t = 0 }, { t = 0.06, pose = { LeftShoulder = A(0.7, 0, -0.2), LeftElbow = A(1.4, 0, 0), Waist = A(0, 0.25, 0) } },
		{ t = 0.13, pose = { LeftShoulder = A(1.55, 0, 0), LeftElbow = A(0.05, 0, 0), Waist = A(-0.1, -0.45, 0), RightShoulder = A(0.4, 0, 0) } },
		{ t = 0.3 } },
	Uppercut = { { t = 0 }, { t = 0.09, pose = { RightShoulder = A(0.2, 0, 0.3), RightElbow = A(1.8, 0, 0), Waist = A(0.15, -0.4, 0), RightHip = A(0.3, 0, 0), RightKnee = A(-0.5, 0, 0) } },
		{ t = 0.18, pose = { RightShoulder = A(2.5, 0, 0), RightElbow = A(0.6, 0, 0), Waist = A(0.2, 0.4, 0), Neck = A(0.2, 0, 0) } },
		{ t = 0.4 } },
	Kick = { { t = 0 }, { t = 0.08, pose = { RightHip = A(0.6, 0, 0), RightKnee = A(-1.5, 0, 0), Waist = A(0.2, 0, 0), LeftShoulder = A(0.5, 0, -0.4) } },
		{ t = 0.16, pose = { RightHip = A(1.5, 0, 0), RightKnee = A(-0.05, 0, 0), Waist = A(0.35, 0.2, 0), LeftShoulder = A(0.3, 0, -0.9), RightShoulder = A(-0.4, 0, 0.6) } },
		{ t = 0.36 } },
	SlashA = { { t = 0 }, { t = 0.09, pose = { RightShoulder = A(2.7, 0, 0.3), RightElbow = A(0.6, 0, 0), Waist = A(0.1, -0.5, 0) } },
		{ t = 0.17, pose = { RightShoulder = A(0.6, 0, -0.5), RightElbow = A(0.1, 0, 0), Waist = A(-0.2, 0.55, 0), LeftShoulder = A(0.4, 0, 0) } },
		{ t = 0.38 } },
	SlashB = { { t = 0 }, { t = 0.08, pose = { RightShoulder = A(1.2, 0, 1.3), Waist = A(0, 0.5, 0) } },
		{ t = 0.16, pose = { RightShoulder = A(1.3, 0, -0.6), Waist = A(-0.1, -0.5, 0) } },
		{ t = 0.36 } },
	Slam = { { t = 0 }, { t = 0.14, pose = { RightShoulder = A(2.9, 0, 0), LeftShoulder = A(2.9, 0, 0), Waist = A(0.3, 0, 0) } },
		{ t = 0.24, pose = { RightShoulder = A(0.7, 0, 0), LeftShoulder = A(0.7, 0, 0), Waist = A(-0.45, 0, 0), RightHip = A(0.3, 0, 0), RightKnee = A(-0.6, 0, 0) } },
		{ t = 0.5 } },
	Shoot = { { t = 0 }, { t = 0.07, pose = { RightShoulder = A(1.6, 0, 0), LeftShoulder = A(1.4, 0, 0.5), Waist = A(0, 0.3, 0), Neck = A(0, -0.2, 0) } },
		{ t = 0.14, pose = { RightShoulder = A(1.8, 0, 0), LeftShoulder = A(1.4, 0, 0.5), Waist = A(0.1, 0.3, 0) } },
		{ t = 0.34 } },
	Cast = { { t = 0 }, { t = 0.15, pose = { RightShoulder = A(2.6, 0, 0.3), LeftShoulder = A(2.6, 0, -0.3), Waist = A(0.2, 0, 0), Neck = A(0.25, 0, 0) } },
		{ t = 0.3, pose = { RightShoulder = A(1.5, 0, 0), LeftShoulder = A(1.5, 0, 0), Waist = A(-0.15, 0, 0) } },
		{ t = 0.55 } },
	Buff = { { t = 0 }, { t = 0.18, pose = { RightShoulder = A(0.3, 0, 1.2), LeftShoulder = A(0.3, 0, -1.2), RightElbow = A(1.6, 0, 0), LeftElbow = A(1.6, 0, 0), Waist = A(0.15, 0, 0), RightHip = A(0, 0, 0.2), LeftHip = A(0, 0, -0.2) } },
		{ t = 0.5, pose = { RightShoulder = A(0.2, 0, 1.0), LeftShoulder = A(0.2, 0, -1.0), RightElbow = A(1.8, 0, 0), LeftElbow = A(1.8, 0, 0), Neck = A(0.2, 0, 0) } },
		{ t = 0.75 } },
	Hurt = { { t = 0 }, { t = 0.07, pose = { Waist = A(0.3, 0, 0.1), Neck = A(0.25, 0, 0), RightShoulder = A(-0.3, 0, 0.3), LeftShoulder = A(-0.3, 0, -0.3) } }, { t = 0.25 } },
}

local WEAPON_CLIPS = {
	Knuckles = { "JabR", "JabL", "Uppercut" }, -- Brawler 3-hit combo
	Shoes = { "Kick", "JabR", "Kick" }, -- Sea Cook
	Sword = { "SlashA", "SlashB" },
	Hammer = { "Slam" },
	Slingshot = { "Shoot" }, StormBaton = { "Shoot" }, MedKit = { "Shoot" },
}
local SKILL_CLIPS = { Melee = "Uppercut", Dash = "JabR", Ranged = "Shoot", AoE = "Slam", GroundAoE = "Cast", Heal = "Buff", PartyHeal = "Buff", Buff = "Buff", PartyBuff = "Buff" }

local chars = {} -- character -> { joints = {name = {motor, base}}, clip, start, combo, freezeUntil }

local function state(char)
	local st = chars[char]
	if st then
		return st
	end
	st = { joints = {}, combo = 0, start = 0 }
	for name, partName in pairs(JOINTS) do
		local part = char:FindFirstChild(partName)
		local m = part and part:FindFirstChild(name)
		if m and m:IsA("Motor6D") then
			st.joints[name] = { motor = m, base = m.C0 }
		end
	end
	local n = 0
	for _ in pairs(st.joints) do
		n += 1
	end
	if n == 0 then
		warn("[CharAnim] " .. char.Name .. " has no R15 joints (is the avatar type R15?)")
		return nil
	end
	print("[CharAnim] posing " .. char.Name .. " with " .. n .. " R15 joints")
	chars[char] = st
	char.Destroying:Connect(function()
		chars[char] = nil
	end)
	return st
end

function CharAnim.Play(char, clipName)
	if typeof(char) ~= "Instance" then
		return
	end
	local st = state(char)
	if st then
		-- the avatar body is rebuilt after spawn (uniform R15): its joints are new objects -> re-read them
		for _, j in pairs(st.joints) do
			if not j.motor.Parent then
				chars[char] = nil
				st = state(char)
				break
			end
		end
	end
	local clip = CLIPS[clipName]
	if st and clip then
		st.clip, st.start = clip, os.clock()
	end
end

local function sample(clip, t)
	local prev, nxt = clip[1], clip[#clip]
	for i = 1, #clip - 1 do
		if t >= clip[i].t and t <= clip[i + 1].t then
			prev, nxt = clip[i], clip[i + 1]
			break
		end
	end
	local span = nxt.t - prev.t
	local k = span > 0 and math.clamp((t - prev.t) / span, 0, 1) or 1
	k = k * k * (3 - 2 * k)
	return prev.pose or {}, nxt.pose or {}, k
end

local function apply(st, now)
	local clip = st.clip
	if not clip then
		return
	end
	local t = now - st.start
	if st.freezeUntil and now < st.freezeUntil then
		t = st.frozenT or t -- hitstop: hold the pose
	end
	if t >= clip[#clip].t then
		for _, j in pairs(st.joints) do
			j.motor.C0 = j.base
		end
		st.clip = nil
		return
	end
	local a, b, k = sample(clip, t)
	for name, j in pairs(st.joints) do
		local pa, pb = a[name] or CFrame.identity, b[name] or CFrame.identity
		j.motor.C0 = j.base * pa:Lerp(pb, k)
	end
end

-- ===== camera shake (local player) =====
local shake = 0
local function addShake(amount)
	shake = math.min(1.2, shake + amount)
end

function CharAnim.Start()
	Net.OnFX(function(kind, d)
		if type(d) ~= "table" then
			return
		end
		if kind == "BasicAttack" and typeof(d.char) == "Instance" then
			local list = WEAPON_CLIPS[d.weapon or "Knuckles"] or WEAPON_CLIPS.Knuckles
			local st = state(d.char)
			if st then
				-- a combo: keep cycling while attacks come within 1.2 s
				st.combo = (os.clock() - (st.lastHit or 0) < 1.2) and (st.combo % #list) + 1 or 1
				st.lastHit = os.clock()
				CharAnim.Play(d.char, list[st.combo])
			end
		elseif kind == "Skill" and typeof(d.char) == "Instance" then
			local sk = ClassesCfg.SkillById[d.skill or ""]
			CharAnim.Play(d.char, SKILL_CLIPS[sk and sk.kind or ""] or "Cast")
		elseif kind == "Damage" then
			if d.toPlayer and typeof(d.char) == "Instance" then
				CharAnim.Play(d.char, "Hurt")
				if d.char == Players.LocalPlayer.Character then
					addShake(0.35)
				end
			elseif d.src == Players.LocalPlayer.UserId then
				-- my hit landed: hitstop (hold my pose a moment) + a small shake, bigger on crits
				local st = Players.LocalPlayer.Character and chars[Players.LocalPlayer.Character]
				if st and st.clip then
					st.frozenT = os.clock() - st.start
					st.freezeUntil = os.clock() + (d.crit and 0.09 or 0.05)
					st.start += d.crit and 0.09 or 0.05
				end
				addShake(d.crit and 0.55 or 0.18)
			end
		end
	end)

	RunService.Stepped:Connect(function()
		local now = os.clock()
		for char, st in pairs(chars) do
			if char.Parent then
				apply(st, now)
			end
		end
	end)

	RunService:BindToRenderStep("GVShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0.001 then
			return
		end
		local cam = workspace.CurrentCamera
		local s = shake * shake * 0.6
		local t = os.clock() * 40
		cam.CFrame = cam.CFrame * CFrame.new(math.noise(t, 1) * s, math.noise(t, 2) * s, 0) * CFrame.Angles(0, 0, math.noise(t, 3) * s * 0.04)
		shake = math.max(0, shake - dt * 3.5)
	end)
end

return CharAnim
