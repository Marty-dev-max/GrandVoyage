-- NpcLife (v0.25.42, owner: NPCs stood frozen): the voxel NPCs (ModelFactory.NPC = anchored VoxelChar blocks, no rig)
-- breathe, now and then wave a customer over with the right arm, and turn to face you while you talk to them
-- (Quest.Dialog calls NpcLife.Face). Blocks are posed locally with BulkMoveTo, like HeritageAnim does for wings.
-- Which limb a block belongs to is read from its rest position in the root's space (VoxelChar REST layout, root 2.6
-- above the feet): right arm = x > 1 between the hand and the shoulder, everything above the hips breathes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local NpcLife = {}

local RANGE = 90 -- studs from the camera: farther NPCs keep their rest pose
local SHOULDER = Vector3.new(1.5, 2.0, 0)
local ELBOW = Vector3.new(1.5, 0.94, 0)

local states = {} -- model -> state
local facing = {} -- model -> true while talking

local function build(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not model:FindFirstChild("VoxelHead", true) then
		return false -- not a voxel character (signs, boards...)
	end
	local rootCF = root.CFrame
	local st = { model = model, root = rootCF, parts = {}, rel = {}, kind = {}, yaw = 0, nextWave = os.clock() + math.random() * 6 + 2, waveStart = -10 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and d.Anchored then
			local rel = rootCF:ToObjectSpace(d.CFrame)
			local p = rel.Position
			local kind = "body"
			if p.Y < 0.1 then
				kind = "legs" -- hips and below: stand still
			elseif p.X > 1.0 and p.Y < 2.2 then
				kind = p.Y >= ELBOW.Y and "upper" or "fore"
			end
			table.insert(st.parts, d)
			table.insert(st.rel, rel)
			table.insert(st.kind, kind)
		end
	end
	return st
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- talking: the whole NPC turns toward your character (and back when the talk ends)
function NpcLife.Face(model, on)
	if model then
		facing[model] = on and true or nil
	end
end

local function step(now, dt)
	local cam = workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not cam then
		return
	end
	for _, model in ipairs(CollectionService:GetTagged("NPC")) do
		local st = states[model]
		if st == nil and model.Parent and model:IsA("Model") then
			st = build(model)
			states[model] = st
		end
		if st and model.Parent and (st.root.Position - cam.CFrame.Position).Magnitude < RANGE then
			-- body yaw toward the player while talking
			local goalYaw = 0
			if facing[model] and myRoot then
				local to = st.root:PointToObjectSpace(myRoot.Position)
				goalYaw = math.atan2(-to.X, -to.Z) -- the NPC looks down its -Z
			end
			st.yaw += (goalYaw - st.yaw) * math.min(1, dt * 6)
			-- a wave every few seconds, more often with someone close
			if now >= st.nextWave then
				st.waveStart = now
				local near = myRoot and (myRoot.Position - st.root.Position).Magnitude < 30
				st.nextWave = now + (near and 4 or 7) + math.random() * 5
			end
			local w = now - st.waveStart
			local env = w < 2.2 and (smooth(w / 0.35) * smooth((2.2 - w) / 0.35)) or 0
			local raise = CFrame.new(SHOULDER) * CFrame.Angles(0, 0, 2.5 * env) * CFrame.new(-SHOULDER)
			local fore = raise * CFrame.new(ELBOW) * CFrame.Angles(0, 0, math.sin(now * 9) * 0.45 * env) * CFrame.new(-ELBOW)
			local bob = CFrame.new(0, math.sin(now * 2.1 + st.root.Position.X) * 0.05, 0)
			local base = st.root * CFrame.Angles(0, st.yaw, 0)
			local cfs = table.create(#st.parts)
			for i, rel in ipairs(st.rel) do
				local k = st.kind[i]
				if k == "legs" then
					cfs[i] = base * rel
				elseif k == "upper" then
					cfs[i] = base * bob * raise * rel
				elseif k == "fore" then
					cfs[i] = base * bob * fore * rel
				else
					cfs[i] = base * bob * rel
				end
			end
			workspace:BulkMoveTo(st.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	for m in pairs(states) do
		if not m.Parent then
			states[m] = nil
			facing[m] = nil
		end
	end
end

function NpcLife.Start()
	local acc, last = 0, os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		acc += now - last
		last = now
		if acc < 1 / 30 then
			return
		end
		local dt = acc
		acc = 0
		local ok, err = pcall(step, now, dt)
		if not ok then
			warn("[NpcLife]", err)
		end
	end)
end

return NpcLife
