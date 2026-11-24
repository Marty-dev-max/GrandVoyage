-- RecruitLife (v0.25.142, owner): the sailors looking for a ship (RecruitService, tag "Recruit") stroll around their
-- spot in the tavern: walk to a random point (legs and arms swing), stand a few seconds, walk again. When you come
-- close they stop and turn to you (press E to talk). Everything is local: the server keeps them anchored at home.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Recruits = require(ReplicatedStorage.Shared.Config.Recruits)

local RecruitLife = {}

local RANGE = 110 -- studs from the camera
local SPEED = 3.2
local HIP_Y, SHOULDER_Y = 0.1, 1.95
local states = {}

local function build(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local home = model:GetAttribute("Home")
	if not root or typeof(home) ~= "Vector3" then
		return nil
	end
	local cf = root.CFrame
	local _, yaw = cf:ToEulerAnglesYXZ()
	local st = { model = model, root = root, parts = {}, rel = {}, kind = {}, side = {}, pos = cf.Position, yaw = yaw,
		home = Vector3.new(home.X, cf.Position.Y, home.Z), waitUntil = os.clock() + math.random() * 3, phase = 0 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = cf:ToObjectSpace(d.CFrame)
			local p = rel.Position
			local kind = "body"
			if d == root then
				kind = "root"
			elseif math.abs(p.X) > 1.0 and p.Y < SHOULDER_Y + 0.3 then
				kind = "arm"
			elseif p.Y < HIP_Y then
				kind = "leg"
			end
			table.insert(st.parts, d)
			table.insert(st.rel, rel)
			table.insert(st.kind, kind)
			table.insert(st.side, p.X >= 0 and 1 or -1)
		end
	end
	return st
end

local function step(st, dt, me)
	local now = os.clock()
	local moving = false
	local near = me and (Vector2.new(me.X - st.pos.X, me.Z - st.pos.Z).Magnitude < 8)
	if near then
		-- stop and look at the player walking up to talk
		local d = me - st.pos
		local want = math.atan2(-d.X, -d.Z)
		st.yaw += math.atan2(math.sin(want - st.yaw), math.cos(want - st.yaw)) * math.min(1, dt * 6)
		st.target = nil
	elseif now >= st.waitUntil then
		if not st.target then
			local a, r = math.random() * math.pi * 2, math.random() * Recruits.WanderRadius
			st.target = st.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		local d = st.target - st.pos
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude < 0.2 then
			st.target = nil
			st.waitUntil = now + 2 + math.random() * 4
		else
			moving = true
			local stepLen = math.min(d.Magnitude, SPEED * dt)
			st.pos += d.Unit * stepLen
			local want = math.atan2(-d.X, -d.Z)
			st.yaw += math.atan2(math.sin(want - st.yaw), math.cos(want - st.yaw)) * math.min(1, dt * 8)
		end
	end
	st.phase = moving and (st.phase + dt * 9) or (st.phase * math.max(0, 1 - dt * 6))
	local swing = math.sin(st.phase) * (moving and 0.55 or 0)
	local bob = moving and math.abs(math.cos(st.phase)) * 0.12 or math.sin(now * 2 + st.home.X) * 0.03
	local rootCF = CFrame.new(st.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, st.yaw, 0)
	local cfs = table.create(#st.parts)
	for i, rel in ipairs(st.rel) do
		local k, side = st.kind[i], st.side[i]
		if k == "leg" then
			local pivot = CFrame.new(side * 0.5, HIP_Y, 0)
			cfs[i] = rootCF * pivot * CFrame.Angles(swing * side, 0, 0) * pivot:Inverse() * rel
		elseif k == "arm" then
			local pivot = CFrame.new(side * 1.5, SHOULDER_Y, 0)
			cfs[i] = rootCF * pivot * CFrame.Angles(-swing * side * 0.8, 0, 0) * pivot:Inverse() * rel
		else
			cfs[i] = rootCF * rel
		end
	end
	workspace:BulkMoveTo(st.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function RecruitLife.Start()
	CollectionService:GetInstanceRemovedSignal("Recruit"):Connect(function(m)
		states[m] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local char = Players.LocalPlayer.Character
		local me = char and char:FindFirstChild("HumanoidRootPart")
		me = me and me.Position
		for _, m in ipairs(CollectionService:GetTagged("Recruit")) do
			local st = states[m]
			if st == nil then
				st = build(m) or false
				states[m] = st
			end
			if st and st.root.Parent and (cam.CFrame.Position - st.pos).Magnitude < RANGE then
				step(st, math.min(dt, 0.1), me)
			end
		end
	end)
end

return RecruitLife
