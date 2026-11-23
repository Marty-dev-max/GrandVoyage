-- NpcLife (v0.25.42, owner: NPCs stood frozen): the voxel NPCs (ModelFactory.NPC = anchored VoxelChar blocks, no rig)
-- breathe in a relaxed stance (v0.25.50), now and then wave a customer over with the right arm, and turn to face you while you talk to them
-- (Quest.Dialog calls NpcLife.Face). Blocks are posed locally with BulkMoveTo, like HeritageAnim does for wings.
-- Which limb a block belongs to is read from its rest position in the root's space (VoxelChar REST layout, root 2.6
-- above the feet): right arm = x > 1 between the hand and the shoulder, everything above the hips breathes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local NpcLife = {}

local RANGE = 90 -- studs from the camera: farther NPCs keep their rest pose
local FACE_KEEP = 14 -- v0.25.50: an NPC you talked to keeps facing you until you walk this far away
local SHOULDER_Y, ELBOW_Y, HIP_Y = 1.95, 0.94, 0.1

local states = {} -- model -> state
local facing = {} -- model -> true while talking

local function build(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not model:FindFirstChild("VoxelHead", true) then
		return false -- not a voxel character (signs, boards...)
	end
	local rootCF = root.CFrame
	local st = { model = model, root = rootCF, parts = {}, rel = {}, kind = {}, side = {}, yaw = 0, seed = math.random() * 10, nextWave = os.clock() + math.random() * 6 + 2, waveStart = -10 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and d.Anchored then
			local rel = rootCF:ToObjectSpace(d.CFrame)
			local p = rel.Position
			-- limbs by side first (arms hang at x +-1.5 down past the hips, legs at +-0.5), then by height
			local kind, side = "body", p.X >= 0 and 1 or -1
			if math.abs(p.X) > 1.0 and p.Y < SHOULDER_Y + 0.3 then
				kind = p.Y >= ELBOW_Y and "upper" or "fore"
			elseif p.Y < HIP_Y then
				kind = "leg"
			end
			table.insert(st.parts, d)
			table.insert(st.rel, rel)
			table.insert(st.kind, kind)
			table.insert(st.side, side)
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
			-- body yaw toward the player while talking (released once you walk away)
			local goalYaw = 0
			if facing[model] and myRoot and (myRoot.Position - st.root.Position).Magnitude > FACE_KEEP then
				facing[model] = nil
			end
			if facing[model] and myRoot then
				local to = st.root:PointToObjectSpace(myRoot.Position)
				goalYaw = math.atan2(-to.X, -to.Z) -- the NPC looks down its -Z
			end
			st.yaw += (goalYaw - st.yaw) * math.min(1, dt * 6)
			-- a wave every few seconds, more often with someone close (not while talking: they look at you instead)
			if now >= st.nextWave then
				st.waveStart = facing[model] and -10 or now
				local near = myRoot and (myRoot.Position - st.root.Position).Magnitude < 30
				st.nextWave = now + (near and 4 or 7) + math.random() * 5
			end
			local w = now - st.waveStart
			local env = w < 2.2 and (smooth(w / 0.35) * smooth((2.2 - w) / 0.35)) or 0
			-- v0.25.50 (owner: they stood stiff and straight): a relaxed stance like a player's idle: arms a little
			-- out with soft elbows, feet apart, a slow weight shift side to side, chest rising with each breath
			local t = now + st.seed
			local breath = math.sin(t * 2.1)
			local shift = math.sin(t * 0.7) * 0.035
			local base = st.root * CFrame.Angles(0, st.yaw, 0)
			local torso = base * CFrame.new(0, HIP_Y, 0) * CFrame.Angles(0.02 * breath, 0, shift) * CFrame.new(0, -HIP_Y + 0.04 * breath, 0)
			local limb = {}
			for _, side in ipairs({ -1, 1 }) do
				local wave = side == 1 and env or 0
				local shoulder = Vector3.new(side * 1.5, SHOULDER_Y, 0)
				local elbow = Vector3.new(side * 1.5, ELBOW_Y, 0)
				local hip = Vector3.new(side * 0.5, HIP_Y, 0)
				local swing = 0.04 * math.sin(t * 2.1 + side) -- arms drift a touch with the breath
				local upper = torso * CFrame.new(shoulder) * CFrame.Angles(swing, 0, side * (0.13 + 2.5 * wave)) * CFrame.new(-shoulder)
				local fore = upper * CFrame.new(elbow) * CFrame.Angles(0.3 * (1 - wave), 0, math.sin(now * 9) * 0.45 * wave) * CFrame.new(-elbow)
				-- the leg on the side the weight moves to stays straight, the other one eases out
				local leg = base * CFrame.new(hip) * CFrame.Angles(0, 0, side * (0.06 + shift * side * 0.8)) * CFrame.new(-hip)
				limb[side] = { upper = upper, fore = fore, leg = leg }
			end
			local cfs = table.create(#st.parts)
			for i, rel in ipairs(st.rel) do
				local k = st.kind[i]
				local L = limb[st.side[i]]
				cfs[i] = (k == "body" and torso or L[k]) * rel
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

-- v0.25.106: put an NPC back in its rest layout right now (UI/ForgeScene clones it and poses the copy itself)
function NpcLife.Rest(model)
	local st = states[model]
	if st then
		local cfs = table.create(#st.parts)
		for i, rel in ipairs(st.rel) do
			cfs[i] = st.root * rel
		end
		workspace:BulkMoveTo(st.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function NpcLife.Start()
	-- v0.25.50 (owner: only some NPCs turned): every NPC prompt (shops, Job Master...) turns its NPC toward you,
	-- not only quest dialogs
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		local m = prompt:FindFirstAncestorWhichIsA("Model")
		while m and not CollectionService:HasTag(m, "NPC") do
			m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
		end
		if m then
			facing[m] = true
		end
	end)
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
