-- AnimBuild: turns a clip from Config/AnimClips into a KeyframeSequence.
-- Pure: the caller passes `env` = { Instance = ..., CFrame = ..., Enum = ... } so the same code runs in Roblox
-- (Shared/Modules/Anim.lua, fallback when a clip has no uploaded id) and in Lune (tools/build_anims.luau).
local AnimBuild = {}

-- Pose tree: every pose sits under the pose of the part its joint hangs from
local R15_PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
}
AnimBuild.R15_PARENT = R15_PARENT

local function parentOf(rig, name)
	if rig == "R15" then
		return R15_PARENT[name]
	end
	return name ~= "HumanoidRootPart" and "HumanoidRootPart" or nil -- monsters: every part hangs off the root
end

function AnimBuild.Build(name, clip, env)
	local Instance, CFrame, Enum = env.Instance, env.CFrame, env.Enum
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = clip.loop == true
	kfs.Priority = Enum.AnimationPriority[clip.priority or "Action"]
	-- every part the clip ever moves gets a pose in every keyframe (missing = back to rest)
	local animated = {}
	for _, key in ipairs(clip.keys) do
		for part in pairs(key.pose or {}) do
			animated[part] = true
		end
	end
	local rad = math.pi / 180
	for _, key in ipairs(clip.keys) do
		local kf = Instance.new("Keyframe")
		kf.Time = key.t
		local poses = {}
		local function poseFor(part)
			if poses[part] then
				return poses[part]
			end
			local p = Instance.new("Pose")
			p.Name = part
			p.Weight = 0 -- container only, unless it is animated (below)
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			poses[part] = p
			local parent = parentOf(clip.rig, part)
			p.Parent = parent and poseFor(parent) or kf
			return p
		end
		for part in pairs(animated) do
			local v = (key.pose or {})[part] or { 0, 0, 0 }
			local p = poseFor(part)
			p.Weight = 1
			p.CFrame = CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0) * CFrame.Angles(v[1] * rad, v[2] * rad, v[3] * rad)
		end
		kf.Parent = kfs
	end
	return kfs
end

-- seconds from the start to the last key (the clip's length)
function AnimBuild.Length(clip)
	return clip.keys[#clip.keys].t
end

return AnimBuild
