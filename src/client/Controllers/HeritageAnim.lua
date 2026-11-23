-- HeritageAnim (client, v0.24.8, owner): heritage body parts move. Every client animates every character it sees:
--  * Wings (Skyborn, Cinderwing): fold-and-sway at rest, beat fast while flying / gliding (a whoosh on each down
--    stroke for the local player's own wings, positional for others)
--  * Tails (Beastkin): a lazy sway, quicker while running; ears twitch now and then
--  * Fins (Tidekin): a gentle ripple
--  * Horns (Oni) and the Cinderwing back flame stay rigid (they are not limbs)
-- How: the real welded blocks (VoxelChar) are hidden on this client (LocalTransparencyModifier) and local anchored
-- copies are posed every frame around a hinge on the body part they hang from. Nothing changes on the server, so this
-- works for other players' characters too (client-posed joints never replicate; see CLAUDE.md).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.Audio)

local HA = {}
local player = Players.LocalPlayer
local KINDS = { Wing = "wing", WingTip = "wing", Tail = "tail", TailTip = "tail", Ear = "ear", Fin = "fin" }
local BODY = { wing = "UpperTorso", tail = "LowerTorso", ear = "Head", fin = "Head" }
local rigs = {} -- character -> { body, rig }
local folder

local function build(char)
	local body = char:FindFirstChild("VoxelBody")
	if not body then
		return nil
	end
	local rig = { char = char, pieces = {}, phase = math.random() * 6, lastBeat = 0 }
	for _, p in ipairs(body:GetChildren()) do
		local kind = p:IsA("BasePart") and KINDS[p.Name]
		local host = kind and char:FindFirstChild(BODY[kind])
		if host then
			local copy = p:Clone()
			for _, c in ipairs(copy:GetChildren()) do
				if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
					c:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Parent = folder
			p.LocalTransparencyModifier = 1
			table.insert(rig.pieces, { kind = kind, src = p, copy = copy, host = host, rel = host.CFrame:ToObjectSpace(p.CFrame) })
		end
	end
	if #rig.pieces == 0 then
		return nil
	end
	for _, pc in ipairs(rig.pieces) do
		if pc.kind == "wing" then
			rig.hasWing = true
		end
	end
	-- hinge points (in the host's space): wings at the spine, tail at its base, ears/fins where they sit
	for _, pc in ipairs(rig.pieces) do
		local r = pc.rel.Position
		if pc.kind == "wing" then
			pc.side = r.X >= 0 and 1 or -1
			pc.hinge = Vector3.new(pc.side * 0.35, r.Y * 0.4, r.Z)
		elseif pc.kind == "tail" then
			pc.hinge = Vector3.new(0, 0, 0.5)
		else
			pc.side = r.X >= 0 and 1 or -1
			pc.hinge = r - Vector3.new(0, 0.15, 0)
		end
	end
	return rig
end

local function clear(rig)
	for _, pc in ipairs(rig.pieces) do
		pc.copy:Destroy()
		if pc.src.Parent then
			pc.src.LocalTransparencyModifier = 0
		end
	end
end

local function airborne(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }
	return workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params) == nil
end

local function pose(rig, t)
	local char = rig.char
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
	local mine = char == player.Character
	local flying = (mine and require(script.Parent.Flight).IsFlying()) or (hum and hum.PlatformStand) or false
	local air = flying or (rig.airCheck or false)
	local parts, cfs = {}, {}
	local beatRate = flying and 9 or (air and 7 or 1.6)
	local beatAmp = flying and 0.75 or (air and 0.55 or 0.12)
	local wingA = math.sin(t * beatRate + rig.phase) * beatAmp + (air and 0.15 or -0.05)
	-- a whoosh on each down stroke (only real wings, and not while a fruit carries you: v0.25.80 owner, Blaze / Haze
	-- flight has its own crackle / hiss loop)
	local owner = Players:GetPlayerFromCharacter(char)
	local fruitFly = owner and (owner:GetAttribute("Fruit") == "Blaze" or owner:GetAttribute("Fruit") == "Haze")
	if beatAmp > 0.4 and rig.hasWing and not fruitFly then
		local cyc = math.floor((t * beatRate + rig.phase) / (2 * math.pi))
		if cyc ~= rig.lastBeat then
			rig.lastBeat = cyc
			Audio.Play("BlkFlap", { pos = root and root.Position, volume = mine and 0.9 or 0.5, pitch = 0.9 + math.random() * 0.2 })
		end
	end
	local tailA = math.sin(t * (speed > 4 and 7 or 2.4) + rig.phase) * (speed > 4 and 0.45 or 0.3)
	-- ears: each ear twitches on its own rhythm (a quick flick every few seconds) over a slow breathing sway
	local function earTwitch(side)
		local cycle = (t + rig.phase * 3 + (side > 0 and 1.3 or 0)) % 3.2
		local flick = cycle < 0.22 and math.sin(cycle / 0.22 * math.pi * 2) * 0.35 or 0
		return flick + math.sin(t * 1.6 + rig.phase + side) * 0.05
	end
	local finA = math.sin(t * 2.2 + rig.phase) * 0.12
	for _, pc in ipairs(rig.pieces) do
		local host = pc.host
		if host.Parent then
			local rot
			if pc.kind == "wing" then
				rot = CFrame.Angles(0, -pc.side * wingA, pc.side * wingA * 0.35)
			elseif pc.kind == "tail" then
				rot = CFrame.Angles(math.abs(tailA) * 0.2, tailA, 0)
			elseif pc.kind == "ear" then
				local tw = earTwitch(pc.side or 1)
				rot = CFrame.Angles(tw, 0, (pc.side or 1) * (tw * 0.6 + math.abs(tailA) * 0.05))
			else
				rot = CFrame.Angles(0, 0, finA * (pc.side or 1))
			end
			local hingeCF = CFrame.new(pc.hinge)
			table.insert(parts, pc.copy)
			table.insert(cfs, host.CFrame * hingeCF * rot * hingeCF:Inverse() * pc.rel)
			-- keep the real block hidden (respawns / camera transparency can reset it)
			pc.src.LocalTransparencyModifier = 1
			pc.copy.LocalTransparencyModifier = host.LocalTransparencyModifier
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function HA.Start()
	folder = Instance.new("Folder")
	folder.Name = "HeritageAnim"
	folder.Parent = workspace
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		acc += dt
		local slow = acc > 0.25
		if slow then
			acc = 0
		end
		local cam = workspace.CurrentCamera
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			if char and char:GetAttribute("Voxelized") then
				-- entry = { body = the VoxelBody it was built from, rig = rig | nil (nothing to animate) }
				local entry = rigs[char]
				local body = char:FindFirstChild("VoxelBody")
				if entry and entry.body ~= body then
					if entry.rig then
						clear(entry.rig)
					end
					entry = nil
					rigs[char] = nil
				end
				if not entry and body then
					entry = { body = body, rig = build(char) }
					rigs[char] = entry
				end
				local rig = entry and entry.rig
				if rig then
					local root = char:FindFirstChild("HumanoidRootPart")
					local near = root and cam and (root.Position - cam.CFrame.Position).Magnitude < 260
					if near then
						if slow then
							rig.airCheck = airborne(char)
						end
						pose(rig, t)
					end
				end
			end
		end
		-- characters that left: drop their copies
		for char, entry in pairs(rigs) do
			if not char.Parent then
				if entry.rig then
					clear(entry.rig)
				end
				rigs[char] = nil
			end
		end
	end)
end

return HA
