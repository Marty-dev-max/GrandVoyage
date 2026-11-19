-- Flight (client, v0.24.6, owner): free flight for whoever is allowed to fly. Generic: a heritage (Config/Looks
-- `fly = true`, Cinderwing today) or any later source calls Flight.Allow(source, true).
--  * Take off: in the air, HOLD Jump (Space / the jump button) for a moment. Hold Jump to climb, Ctrl to dive (C is the Stats window).
--  * Steer: you fly where the camera looks (move keys / thumbstick are camera-relative, pitch included). With Shift Lock
--    the body always faces the camera, so you fly exactly along the crosshair.
--  * Q while flying = barrel roll (a full roll with a speed burst) instead of the ground Dash.
--  * Lands by itself on touching the ground while not climbing; dropping into the sea ends it too (swim).
-- The character is PlatformStand while flying; LinearVelocity + AlignOrientation move it (client-owned physics).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)

local Flight = {}
local player = Players.LocalPlayer
local SPEED = 52
local CLIMB = 34
local TAKEOFF_HOLD = 0.28

local allowed = {} -- source -> true
local flying = false
local holdStart
local att, lv, ao
local roll = { t0 = 0, dur = 0.55, dir = 1, active = false }

local function char()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return c, h, r
end

function Flight.Allow(source, on)
	allowed[source] = on or nil
end

function Flight.CanFly()
	return next(allowed) ~= nil
end

function Flight.IsFlying()
	return flying
end

local function stop()
	if not flying then
		return
	end
	flying = false
	for _, o in ipairs({ lv, ao, att }) do
		if o then
			o:Destroy()
		end
	end
	lv, ao, att = nil, nil, nil
	local _, h = char()
	if h then
		h.PlatformStand = false
		h:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end
Flight.Stop = stop

local function start()
	local _, h, r = char()
	if not h or not r or h.Health <= 0 or flying then
		return
	end
	flying = true
	h.PlatformStand = true
	att = Instance.new("Attachment")
	att.Name = "FlightAtt"
	att.Parent = r
	lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.new(0, 8, 0)
	lv.Parent = r
	ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = 1e6
	ao.Responsiveness = 18
	ao.CFrame = r.CFrame.Rotation
	ao.Parent = r
end

-- Q while flying: barrel roll. Returns true when it handled the key (so the ground Dash does not fire)
function Flight.Roll()
	if not flying or roll.active then
		return flying
	end
	roll.active = true
	roll.t0 = os.clock()
	roll.dir = (UserInputService:IsKeyDown(Enum.KeyCode.A) and -1) or 1
	return true
end

local function shiftLocked()
	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

function Flight.Start()
	-- heritage-based permission (Cinderwing)
	local function refresh()
		local h = Looks.HeritageById[player:GetAttribute("Heritage") or ""]
		Flight.Allow("heritage", h ~= nil and h.fly == true)
		if not Flight.CanFly() then
			stop()
		end
	end
	player:GetAttributeChangedSignal("Heritage"):Connect(refresh)
	refresh()
	player.CharacterAdded:Connect(function()
		flying = false
		lv, ao, att = nil, nil, nil
	end)

	RunService.RenderStepped:Connect(function()
		local _, h, r = char()
		if not h or not r or h.Health <= 0 then
			if flying then
				stop()
			end
			return
		end
		local jumpHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) or h.Jump
		if not flying then
			local airborne = h.FloorMaterial == Enum.Material.Air
			if Flight.CanFly() and airborne and jumpHeld then
				holdStart = holdStart or os.clock()
				if os.clock() - holdStart >= TAKEOFF_HOLD then
					holdStart = nil
					start()
				end
			else
				holdStart = nil
			end
			return
		end
		-- flying
		local cam = workspace.CurrentCamera
		local look = cam.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.zAxis
		local right = cam.CFrame.RightVector
		local md = h.MoveDirection
		local f = md:Dot(flatLook)
		local s = md:Dot(Vector3.new(right.X, 0, right.Z).Unit)
		local up = (jumpHeld and 1 or 0) - ((UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) and 1 or 0)
		local vel = (look * f + right * s) * SPEED + Vector3.yAxis * up * CLIMB
		local boost = 1
		local rollAngle = 0
		if roll.active then
			local k = (os.clock() - roll.t0) / roll.dur
			if k >= 1 then
				roll.active = false
			else
				rollAngle = roll.dir * k * math.pi * 2
				boost = 1.9 - k * 0.9
			end
		end
		lv.VectorVelocity = vel * boost
		-- body: faces the camera with Shift Lock, else the way it flies; leans forward with speed
		local horiz = Vector3.new(vel.X, 0, vel.Z)
		local face = shiftLocked() and flatLook or (horiz.Magnitude > 2 and horiz.Unit or Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit)
		local speedK = math.clamp(vel.Magnitude / SPEED, 0, 1)
		local pitch = -math.rad(65) * speedK * math.clamp(1 - math.abs(up) * 0.5, 0.3, 1)
		if shiftLocked() and f > 0.2 then
			pitch = -math.rad(70) + math.asin(math.clamp(look.Y, -1, 1)) * 0.6
		end
		ao.CFrame = CFrame.lookAt(Vector3.zero, face) * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, rollAngle)
		-- land: close to the ground and not climbing; end over water
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local hit = workspace:Raycast(r.Position, Vector3.new(0, -4, 0), params)
		if (hit and up <= 0 and vel.Y <= 1) or r.Position.Y < GameConfig.SeaLevel + 1.5 then
			stop()
		end
	end)
end

return Flight
