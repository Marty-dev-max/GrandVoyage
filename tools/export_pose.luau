-- Pose previews (v0.25.66): a voxel character posed by clips from Config/AnimClips, for checking a strike frame
-- before uploading the animation (nobody can watch them play here).
--   lune run tools/export_pose.luau build/GrandVoyage.rbxlx out.json Bounce_Wind@0 Bounce_Pistol@0.08 ...
--   python3 tools/render_pose.py out.json out.png        (side + front views of every pose, in a row)
-- Forward kinematics on the R15 rest layout of VoxelChar (VC.Rest): part = parent * joint * Transform * joint^-1,
-- with the pose value read exactly like AnimBuild (offset, then Angles(rx, ry, rz) in degrees). Keys are linearly
-- interpolated between the two keyframes around t (Roblox eases them Cubic InOut; close enough for a check).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local RS = place:GetService("ReplicatedStorage")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then
		return cache[key]
	end
	local env = setmetatable({
		script = mod, require = req, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum, Instance = roblox.Instance,
		table = setmetatable({ clone = function(t) local o = {} for k, v in t do o[k] = v end return o end }, { __index = table }),
	}, { __index = getfenv() })
	local r = luau.load(mod.Source, { debugName = key, environment = env })()
	cache[key] = r
	return r
end
local VC = req(RS.Shared.Modules.VoxelChar)
local Looks = req(RS.Shared.Config.Looks)
local Clips = req(RS.Shared.Config.AnimClips)
local AnimBuild = req(RS.Shared.Modules.AnimBuild)
local PARENT = AnimBuild.R15_PARENT
local REST = VC.Rest

-- joint pivots in rest (world) space: where each part hangs from its parent
local JOINT = {
	LowerTorso = Vector3.new(0, 2.91, 0), UpperTorso = Vector3.new(0, 3.11, 0), Head = Vector3.new(0, 4.71, 0),
	RightUpperArm = Vector3.new(1.5, 4.5, 0), RightLowerArm = Vector3.new(1.5, 3.54, 0), RightHand = Vector3.new(1.5, 2.49, 0),
	LeftUpperArm = Vector3.new(-1.5, 4.5, 0), LeftLowerArm = Vector3.new(-1.5, 3.54, 0), LeftHand = Vector3.new(-1.5, 2.49, 0),
	RightUpperLeg = Vector3.new(0.5, 2.71, 0), RightLowerLeg = Vector3.new(0.5, 1.49, 0), RightFoot = Vector3.new(0.5, 0.3, 0),
	LeftUpperLeg = Vector3.new(-0.5, 2.71, 0), LeftLowerLeg = Vector3.new(-0.5, 1.49, 0), LeftFoot = Vector3.new(-0.5, 0.3, 0),
}
local ROOT = Vector3.new(0, 2.91, 0) -- HumanoidRootPart centre

local function sample(clip, t)
	local keys = clip.keys
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local k = b.t > a.t and math.clamp((t - a.t) / (b.t - a.t), 0, 1) or 0
	local pose = {}
	local names = {}
	for n in (a.pose or {}) do
		names[n] = true
	end
	for n in (b.pose or {}) do
		names[n] = true
	end
	for n in names do
		local va, vb = (a.pose or {})[n] or { 0, 0, 0 }, (b.pose or {})[n] or { 0, 0, 0 }
		local v = {}
		for i = 1, 6 do
			v[i] = (va[i] or 0) + ((vb[i] or 0) - (va[i] or 0)) * k
		end
		pose[n] = v
	end
	return pose
end

local rad = math.pi / 180
local function solve(pose)
	local world = { HumanoidRootPart = CFrame.new(ROOT) }
	local function get(name)
		if world[name] then
			return world[name]
		end
		local parent = PARENT[name]
		local pcf = get(parent)
		local pc = parent == "HumanoidRootPart" and ROOT or REST[parent][2]
		local jp = JOINT[name]
		local v = pose[name] or { 0, 0, 0 }
		local tr = CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0) * CFrame.Angles(v[1] * rad, v[2] * rad, v[3] * rad)
		world[name] = pcf * CFrame.new(jp - pc) * tr * CFrame.new(REST[name][2] - jp)
		return world[name]
	end
	for name in REST do
		get(name)
	end
	return world
end

local function cfArr(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local out = { parts = {}, labels = {} }
local look = Looks.Default()
local n = 0
for i = 2, #process.args do
	local spec = process.args[i]
	if i == 2 then
		continue -- out.json
	end
	local name, t = string.match(spec, "^([%w_]+)@?([%d%.]*)$")
	local clip = Clips[name]
	assert(clip and clip.keys, "no clip " .. tostring(name))
	t = tonumber(t) or clip.strike or 0
	local world = solve(sample(clip, t))
	local model = VC.Preview(look, nil)
	local off = CFrame.new(n * 7, 0, 0)
	for _, b in model:GetDescendants() do
		if b:IsA("BasePart") and b.Transparency < 0.98 then
			local limb = b:GetAttribute("Limb")
			local cf = b.CFrame
			if limb and world[limb] then
				cf = world[limb] * CFrame.new(REST[limb][2]):Inverse() * cf
			end
			local c = b.Color
			table.insert(out.parts, { pose = n, cf = cfArr(off * cf), size = { b.Size.X, b.Size.Y, b.Size.Z }, color = { c.R, c.G, c.B } })
		end
	end
	table.insert(out.labels, { x = n * 7, text = name .. "@" .. t })
	n += 1
end
fs.writeFile(process.args[2], serde.encode("json", out))
print("posed " .. n .. " -> " .. process.args[2])
