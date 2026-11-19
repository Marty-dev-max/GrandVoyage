-- QuestPath (client, v0.24.12, owner): a glowing yellow trail on the ground from you to the current quest objective
-- (State.questTarget, set by UI/Quest), on top of the light column at the objective (Readability beacon).
--  * The route comes from PathfindingService (walks around houses, cliffs and water); if no path is found it falls back
--    to a straight line. Recomputed when the target changes or you have moved a few studs.
--  * Drawn as small flat voxel tiles every few studs, snapped to the ground, with a brightness wave running toward the
--    objective. Only the first ~260 studs are drawn; hidden while sailing / swimming / flying and near the objective.
--  * Settings: follows the "navGuide" toggle (Settings -> Navigation guide).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Settings)

local QP = {}
local player = Players.LocalPlayer
local COLOR = Color3.fromRGB(255, 214, 64)
local SPACING = 3
local MAX_TILES = 88
local folder
local tiles = {}
local route = {} -- list of Vector3 (tile positions, from the player toward the target)
local lastFrom, lastTarget, busy

local function tile(i)
	local t = tiles[i]
	if not t then
		t = Instance.new("Part")
		t.Name = "QuestTile"
		t.Anchored = true
		t.CanCollide = false
		t.CanQuery = false
		t.CanTouch = false
		t.CastShadow = false
		t.Material = Enum.Material.Neon
		t.Color = COLOR
		t.Size = Vector3.new(0.9, 0.12, 0.9)
		t.Parent = folder
		tiles[i] = t
	end
	return t
end

local function rayParams()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	for _, name in ipairs({ "VoxelFX", "HeritageAnim", "Mobs", "Monsters", "Ships" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ex, f)
		end
	end
	p.FilterDescendantsInstances = ex
	p.IgnoreWater = false
	return p
end

-- points every SPACING studs along a polyline, snapped to the ground
local function resample(points)
	local out = {}
	local params = rayParams()
	local carry = 1.5 -- start a little ahead of the feet
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = b - a
		local len = seg.Magnitude
		local d = carry
		while d < len and #out < MAX_TILES do
			local p = a + seg * (d / len)
			local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			if hit then
				table.insert(out, { pos = hit.Position + Vector3.new(0, 0.07, 0), up = hit.Normal })
			end
			d += SPACING
		end
		carry = d - len
		if #out >= MAX_TILES then
			break
		end
	end
	return out
end

local function compute(from, target)
	busy = true
	local points
	if (target - from).Magnitude < 520 then
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok = pcall(function()
			path:ComputeAsync(from, target)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			points = {}
			for _, w in ipairs(path:GetWaypoints()) do
				table.insert(points, w.Position)
			end
		end
	end
	if not points then
		points = { from, target }
	end
	-- stop short of the objective (the beacon and the NPC are there)
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	local keep = { points[1] }
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if walked + len > total - 5 then
			local k = math.max(0, total - 5 - walked) / math.max(len, 0.01)
			table.insert(keep, a + (b - a) * k)
			break
		end
		table.insert(keep, b)
		walked += len
	end
	route = resample(keep)
	busy = false
end

local function hideFrom(n)
	for i = n, #tiles do
		tiles[i].Transparency = 1
	end
end

function QP.Start()
	folder = Instance.new("Folder")
	folder.Name = "QuestPath"
	folder.Parent = workspace
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local target = State.questTarget
		local show = root and hum and target and Settings.Values.navGuide ~= false
			and hum.SeatPart == nil and not hum.PlatformStand
			and hum:GetState() ~= Enum.HumanoidStateType.Swimming
			and (target - root.Position).Magnitude > 14
		if not show then
			hideFrom(1)
			route = {}
			lastTarget = nil
			return
		end
		local feet = root.Position - Vector3.new(0, 2.6, 0)
		acc += dt
		local moved = not lastFrom or (feet - lastFrom).Magnitude > 6
		if not busy and (target ~= lastTarget or (moved and acc > 0.6) or acc > 4) then
			acc = 0
			lastFrom, lastTarget = feet, target
			task.spawn(compute, feet, target)
		end
		-- draw: tiles behind the player (already walked) drop out; a bright wave runs toward the objective
		local t = os.clock()
		local n = 0
		for i, p in ipairs(route) do
			local flat = Vector3.new(p.pos.X - feet.X, 0, p.pos.Z - feet.Z).Magnitude
			if flat > 2.2 or i > 3 then
				n += 1
				local part = tile(n)
				local wave = (math.sin(i * 0.55 - t * 6) + 1) * 0.5
				part.Transparency = 0.15 + (1 - wave) * 0.45
				local s = 0.75 + wave * 0.25
				part.Size = Vector3.new(s, 0.12, s)
				local look = i < #route and (route[i + 1].pos - p.pos) or (p.pos - (route[i - 1] and route[i - 1].pos or feet))
				look = Vector3.new(look.X, 0, look.Z)
				local cf = look.Magnitude > 0.05 and CFrame.lookAt(p.pos, p.pos + look) or CFrame.new(p.pos)
				part.CFrame = cf * CFrame.Angles(0, math.rad(45), 0)
			end
		end
		hideFrom(n + 1)
	end)
end

return QP
