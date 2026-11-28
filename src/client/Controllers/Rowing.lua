-- Rowing (R5, owner ref photo: a rowing dinghy). Every oar bench carries a resting pair of oars in its oarlocks
-- (ShipHull.RowStation: model "Oars" with OarL / OarR shafts + BladeL / BladeR, attachments OarlockL / OarlockR on the
-- bench part). When someone sits in a bench's HelmSeat (a ship without a wheel is steered from its first oar bench),
-- every client hides that resting pair locally and draws a held pair instead:
--  * the handle follows the rower's hand (the Row clip in CharAnim moves it), the shaft pivots in the oarlock and is
--    as long as the resting oar (so it scales with the ship);
--  * the blade goes into the water while the hands push toward the bow and comes out on the way back (read from the
--    hand's own motion, so it matches what every client sees, no clip timing needed), turned square in the water and
--    flat (feathered) above it.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Waves = require(ReplicatedStorage.Shared.Modules.Waves)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Rowing = {}

local WOOD, BLADE = Color3.fromRGB(205, 140, 80), Color3.fromRGB(150, 82, 44)
-- blade tip height over the water: in the stroke it digs in, on the way back it skims above the waves
local TIP_IN, TIP_OUT = -0.7, 1.3
local EASE = 9 -- per second, for the lift and the blade turn

local seats = {} -- HelmSeat -> state { bench, held = { L = {shaft, blade}, R = ... }, lift, turn, lastHand }
local folder
local VoxelSea

local function water(x, z)
	if VoxelSea and VoxelSea.On then
		return GameConfig.SeaLevel + Waves.Height(x, z, Waves.Now())
	end
	return GameConfig.SeaLevel
end

local function mk(size, color, mat)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = mat
	p.Parent = folder
	return p
end

local function setResting(bench, hidden)
	local oars = bench:FindFirstChild("Oars")
	if not oars then
		return
	end
	for _, p in ipairs(oars:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function dropHeld(st)
	if st.held then
		for _, pair in pairs(st.held) do
			pair.shaft:Destroy()
			pair.blade:Destroy()
		end
		st.held = nil
	end
	if st.bench.Parent then
		setResting(st.bench, false)
	end
end

local function track(seat)
	if seats[seat] or not seat:IsA("VehicleSeat") then
		return
	end
	local bench = seat.Parent
	if not (bench and bench.Name == "OarBench") then
		return
	end
	seats[seat] = { bench = bench, lift = 0, turn = 0 }
	seat.AncestryChanged:Connect(function()
		if not seat:IsDescendantOf(workspace) and seats[seat] then
			dropHeld(seats[seat])
			seats[seat] = nil
		end
	end)
end

local function hand(char, tag)
	local h = char:FindFirstChild(tag == "L" and "LeftHand" or "RightHand")
	return h and h.Position
end

local function step(dt)
	for seat, st in pairs(seats) do
		local hum = seat.Occupant
		local char = hum and hum.Parent
		local main = st.bench.PrimaryPart
		if not (char and main and hum.Health > 0) then
			if st.held then
				dropHeld(st)
			end
			continue
		end
		if not st.held then
			st.held = {}
			for _, tag in ipairs({ "L", "R" }) do
				local rest = st.bench:FindFirstChild("Oars") and st.bench.Oars:FindFirstChild("Oar" .. tag)
				local restBlade = st.bench:FindFirstChild("Oars") and st.bench.Oars:FindFirstChild("Blade" .. tag)
				local len = rest and rest.Size.Z or 7
				st.held[tag] = {
					shaft = mk(rest and rest.Size or Vector3.new(0.28, 0.28, len), WOOD, Enum.Material.Wood),
					blade = mk(restBlade and restBlade.Size or Vector3.new(0.75, 0.16, 1.7), BLADE, Enum.Material.WoodPlanks),
					len = len,
				}
			end
			setResting(st.bench, true)
		end
		-- stroke or recovery: the hands' speed toward the bow (the seat faces the bow)
		local fwd = seat.CFrame.LookVector
		local rh, lh = hand(char, "R"), hand(char, "L")
		local mid = rh and lh and (rh + lh) / 2
		if mid then
			local rel = seat.CFrame:PointToObjectSpace(mid) -- in seat space, so the boat's own motion drops out
			local v = st.lastRel and (st.lastRel.Z - rel.Z) / math.max(dt, 1 / 240) or 0 -- + = toward the bow (-Z)
			st.lastRel = rel
			local want = v > 0.4 and 1 or (v < -0.4 and 0 or 0.5) -- 1 = blade in the water
			local k = 1 - math.exp(-EASE * dt)
			st.lift += (want - st.lift) * k
			st.turn += ((want == 1 and 1 or 0) - st.turn) * k
		end
		for tag, pair in pairs(st.held) do
			local at = main:FindFirstChild("Oarlock" .. tag)
			local h = hand(char, tag)
			if at and h then
				local lock = at.WorldPosition
				local up = seat.CFrame.UpVector
				-- the handle: the hand's place across and along the boat; its height is solved so the blade tip reaches
				-- the water (the shaft pivots in the oarlock, so a short inboard part lifts a long outboard part)
				local hLocal = h - lock
				local flat = hLocal - up * hLocal:Dot(up)
				local a = math.max(flat.Magnitude, 0.5)
				local tipDir = -flat.Unit
				local guess = lock + tipDir * (pair.len - a)
				local drop = lock.Y - (water(guess.X, guess.Z) + TIP_OUT + (TIP_IN - TIP_OUT) * st.lift)
				local dy = 0.5
				for _ = 1, 4 do
					local inboard = math.sqrt(a * a + dy * dy)
					dy = math.clamp(drop * inboard / math.max(pair.len - inboard, 1), -1, 6)
				end
				local handle = lock + flat + up * dy
				local dir = lock - handle
				if dir.Magnitude < 0.2 then
					dir = seat.CFrame.RightVector * (tag == "R" and 1 or -1)
				end
				dir = dir.Unit
				local cf = CFrame.lookAt(handle + dir * pair.len / 2, handle + dir * pair.len, up)
				pair.shaft.CFrame = cf
				-- square in the water, flat (feathered) on the way back
				pair.blade.CFrame = cf * CFrame.new(0, 0, -pair.len / 2 + pair.blade.Size.Z / 2) * CFrame.Angles(0, 0, st.turn * math.pi / 2)
			end
		end
	end
end

function Rowing.Start()
	VoxelSea = require(script.Parent.VoxelSea)
	folder = Instance.new("Folder")
	folder.Name = "GVHeldOars"
	folder.Parent = workspace
	task.spawn(function()
		local ships = workspace:WaitForChild("Ships", 60)
		if not ships then
			return
		end
		for _, d in ipairs(ships:GetDescendants()) do
			if d.Name == "HelmSeat" then
				track(d)
			end
		end
		ships.DescendantAdded:Connect(function(d)
			if d.Name == "HelmSeat" then
				task.defer(track, d) -- its parent bench is set by then
			end
		end)
	end)
	RunService.RenderStepped:Connect(step)
end

-- CharAnim: is this humanoid rowing (sat on an oar bench seat)?
function Rowing.BenchOf(hum)
	local seat = hum and hum.SeatPart
	return seat and seat.Name == "HelmSeat" and seat.Parent and seat.Parent.Name == "OarBench" and seat or nil
end

return Rowing
