-- Slingshot (client, v0.25.66): the Bounce Bounce no Mi passive "Slingshot Launch" (docs/Plan-Fruits-v2.md).
--   hold right mouse  = aim: a pink marker on the spot under the pointer (red = too far / nothing to grab)
--   hold left mouse   = both rubber arms stretch out and grab that spot (Bounce_SlingGrab, braced and leaning back)
--   let go of left    = fling yourself after your arms (Bounce_SlingFly, a ballistic arc, arms shortening as you fly)
-- Keyboard / Shift Lock alternative: hold the "Sling" hotkey (default U) = grab where you aim, let go = launch.
-- The server ("Sling" request in CombatService) checks the fruit, range and cooldown and shows the arms to everyone
-- (FX "Sling" grab / go / cancel); this client owns its character's physics, so it moves itself (like Dash).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Modules.Net)
local Anim = require(Shared.Modules.Anim)
local Fruits = require(Shared.Config.Fruits)
local Hotkeys = require(script.Parent.Hotkeys)

local Sling = {}
local player = Players.LocalPlayer
local CFG = Fruits.Slingshot
local PINK, BAD = Color3.fromRGB(255, 130, 190), Color3.fromRGB(255, 70, 70)

local phase -- nil | "aim" | "grab" | "fly"
local marker, ring
local grabTo, grabAt, arms
local lastGo = 0
local viaKey = false

local function FruitFX()
	return require(script.Parent.FruitFX)
end
local function char()
	return player.Character
end
local function hum()
	local c = char()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
	local c = char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

function Sling.Busy()
	return phase ~= nil
end

local function canUse()
	local h, r, c = hum(), root(), char()
	if not h or not r or h.Health <= 0 or player:GetAttribute("Fruit") ~= "Bounce" then
		return false
	end
	if c:GetAttribute("Downed") or h.SeatPart or player:GetAttribute("Vending") then
		return false
	end
	local ok, flying = pcall(function()
		return require(script.Parent.Flight).IsFlying()
	end)
	if ok and flying then
		return false
	end
	local ok2, swimming = pcall(function()
		return require(script.Parent.Swim).IsSwimming()
	end)
	return not (ok2 and swimming)
end

local function makeMarker()
	local fx = workspace:FindFirstChild("ClientFX") or workspace
	marker = Instance.new("Part")
	marker.Name = "SlingAim"
	marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch, marker.CastShadow = true, false, false, false, false
	marker.Material = Enum.Material.Neon
	marker.Size = Vector3.new(1.2, 1.2, 1.2)
	marker.Transparency = 0.25
	marker.Parent = fx
	ring = marker:Clone()
	ring.Name = "SlingRing"
	ring.Size = Vector3.new(4, 0.15, 4)
	ring.Transparency = 0.55
	ring.Parent = fx
end
local function clearMarker()
	if marker then
		marker:Destroy()
		ring:Destroy()
		marker, ring = nil, nil
	end
end

-- the spot under the pointer (or the screen centre with Shift Lock); nil when nothing grabbable is in range
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function aimPoint()
	local cam, r = workspace.CurrentCamera, root()
	if not cam or not r then
		return nil
	end
	local loc
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or viaKey and UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		loc = cam.ViewportSize / 2
	else
		loc = UserInputService:GetMouseLocation() -- includes the top-bar inset: ViewportPointToRay wants exactly that
	end
	local ray = cam:ViewportPointToRay(loc.X, loc.Y)
	local skip = { char() }
	for _, n in ipairs({ "ClientFX", "FruitFX", "VFX" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(skip, f)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return nil, ray.Origin + ray.Direction * 60
	end
	local d = (hit.Position - r.Position).Magnitude
	if d > CFG.Range or d < CFG.MinDist then
		return nil, hit.Position
	end
	return hit.Position, hit.Position
end

local function stopAnims()
	local h = hum()
	if h then
		Anim.Stop(h, "Bounce_SlingGrab", 0.12)
		Anim.Stop(h, "Bounce_SlingFly", 0.2)
		h.AutoRotate = true
	end
end
local function releaseArms(t)
	if arms then
		for _, a in ipairs(arms) do
			a.release(t)
		end
		arms = nil
	end
	local c = char()
	if c then
		FruitFX().HideArm(c, "Right", 0)
		FruitFX().HideArm(c, "Left", 0)
	end
end
local function cancel(tell)
	if phase == "grab" and tell then
		task.spawn(Net.Request, "Sling", { phase = "cancel" })
	end
	phase = nil
	viaKey = false
	clearMarker()
	releaseArms(0.15)
	stopAnims()
end

-- both arms out to `to` and held there (until released); also used for other players' grabs
local function armsTo(c, to, hold)
	local list = {}
	local r = c:FindFirstChild("HumanoidRootPart")
	local side = Vector3.xAxis
	if r then
		local d = (to - r.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude > 0.1 then
			side = d.Unit:Cross(Vector3.yAxis)
		end
	end
	for _, s in ipairs({ { "Right", 1 }, { "Left", -1 } }) do
		FruitFX().HideArm(c, s[1], hold)
		table.insert(list, FruitFX().RubberArm({ char = c, side = s[1], to = to + side * s[2] * 0.7, tOut = 0.16, hold = math.huge, tBack = 0.18, palm = true, thick = 0.8 }))
	end
	return list
end

local function grab()
	local to = aimPoint()
	if not to then
		require(script.Parent.Parent.UI.UIKit).Toast("Nothing to grab there", "bad")
		return
	end
	if os.clock() - lastGo < CFG.Cooldown then
		return
	end
	local h, r = hum(), root()
	phase, grabTo, grabAt = "grab", to, os.clock()
	arms = armsTo(char(), to, CFG.GrabSeconds + 2)
	h.AutoRotate = false
	local flat = (to - r.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.5 then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
	end
	Anim.Play(h, "Bounce_SlingGrab", { fade = 0.08 })
	task.spawn(function()
		local res = Net.Request("Sling", { phase = "grab", to = to })
		if phase == "grab" and grabTo == to and not (res and res.ok) then
			if res and res.msg then
				require(script.Parent.Parent.UI.UIKit).Toast(res.msg, "bad")
			end
			cancel(false)
		end
	end)
end

-- the fling: a ballistic arc from here to just above the grabbed spot, driven by a LinearVelocity
local function launch()
	local h, r, c = hum(), root(), char()
	if phase ~= "grab" or not h or not r or not grabTo then
		return cancel(true)
	end
	phase = "fly"
	clearMarker()
	lastGo = os.clock()
	task.spawn(Net.Request, "Sling", { phase = "go" })
	Anim.Stop(h, "Bounce_SlingGrab", 0.05)
	Anim.Play(h, "Bounce_SlingFly", { fade = 0.08 })
	local start = r.Position
	local target = grabTo + Vector3.new(0, 3, 0)
	local delta = target - start
	local dist = delta.Magnitude
	local T = math.clamp(dist / CFG.Speed, 0.25, 1.0)
	local arc = math.clamp(dist * 0.12, 2, 12)
	local flat = delta * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.5 then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
	end
	local att = Instance.new("Attachment")
	att.Name = "SlingAtt"
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.Parent = r
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	pcall(function()
		local V = require(script.Parent.VFX)
		V.Afterimages(c, T, 0.05)
		V.Ring(start - Vector3.new(0, 2.6, 0), 6, Color3.new(1, 1, 1), 0.35)
	end)
	local wall = RaycastParams.new()
	wall.FilterType = Enum.RaycastFilterType.Exclude
	wall.FilterDescendantsInstances = { c, workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("FruitFX") }
	wall.RespectCanCollide = true
	local t0 = os.clock()
	local conn
	local function done()
		conn:Disconnect()
		lv:Destroy()
		att:Destroy()
		if r.Parent then
			-- keep a little momentum so the landing does not feel like a wall
			r.AssemblyLinearVelocity = (flat.Magnitude > 0.1 and flat.Unit * 18 or Vector3.zero) + Vector3.new(0, -6, 0)
		end
		releaseArms(0.12)
		stopAnims()
		phase = nil
		viaKey = false
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if t >= T or not r.Parent or h.Health <= 0 or c:GetAttribute("Downed") then
			return done()
		end
		local s = t / T
		local v = delta / T + Vector3.new(0, 4 * arc * (1 - 2 * s) / T, 0)
		-- a wall / cliff ahead stops the flight there (no tunnelling through scenery)
		if workspace:Raycast(r.Position, v * math.max(dt, 1 / 60) * 2 + v.Unit * 1.5, wall) then
			return done()
		end
		lv.VectorVelocity = v
	end)
end

function Sling.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if not processed and not phase and canUse() then
				phase = "aim"
				makeMarker()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if phase == "aim" and not processed then
				grab()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if phase == "aim" and not viaKey then
				cancel(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if phase == "grab" and not viaKey then
				launch()
			end
		end
	end)
	Hotkeys.On("Sling", function()
		if phase or not canUse() then
			return false
		end
		viaKey = true
		phase = "aim"
		makeMarker()
		grab()
		if phase ~= "grab" then
			cancel(false)
		end
	end)
	Hotkeys.OnRelease("Sling", function(cancelled)
		if phase == "grab" and viaKey then
			if cancelled then
				cancel(true)
			else
				launch()
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not phase then
			return
		end
		if (phase == "aim" or phase == "grab") and not canUse() then
			return cancel(true)
		end
		if phase == "grab" then
			if os.clock() - grabAt > CFG.GrabSeconds then
				return cancel(true) -- held too long: the arms let go
			end
			-- the key-up can get lost (see Combat v0.25.49): check the real key state too
			if viaKey then
				local k = Hotkeys.Key("Sling")
				if not k or not Enum.KeyCode[k] or not UserInputService:IsKeyDown(Enum.KeyCode[k]) then
					return launch()
				end
			elseif not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				return launch()
			end
		end
		if marker then
			local pos, raw = aimPoint()
			local at = phase == "grab" and grabTo or pos or raw
			if at then
				local col = (phase == "grab" or pos) and PINK or BAD
				marker.Color, ring.Color = col, col
				marker.CFrame = CFrame.new(at) * CFrame.Angles(0, os.clock() * 3, 0)
				ring.CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0))
				local k = 1 + math.sin(os.clock() * 8) * 0.12
				ring.Size = Vector3.new(4 * k, 0.15, 4 * k)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		if phase then
			cancel(false)
		end
	end)
	-- other players' rubber arms
	local others = {}
	Net.OnFX(function(kind, d)
		if kind ~= "Sling" or type(d) ~= "table" or typeof(d.char) ~= "Instance" or d.char == char() then
			return
		end
		local c = d.char
		if d.phase == "grab" and typeof(d.to) == "Vector3" then
			for _, a in ipairs(others[c] or {}) do
				a.release(0.05)
			end
			others[c] = armsTo(c, d.to, CFG.GrabSeconds + 3)
		elseif d.phase == "go" then
			-- the arms keep hold of the spot while the body flies after them, then let go
			local list = others[c]
			others[c] = nil
			local r = c:FindFirstChild("HumanoidRootPart")
			local dist = r and typeof(d.to) == "Vector3" and (d.to - r.Position).Magnitude or 30
			task.delay(math.clamp(dist / CFG.Speed, 0.25, 1.0), function()
				for _, a in ipairs(list or {}) do
					a.release(0.12)
				end
				FruitFX().HideArm(c, "Right", 0)
				FruitFX().HideArm(c, "Left", 0)
			end)
		elseif d.phase == "cancel" then
			for _, a in ipairs(others[c] or {}) do
				a.release(0.15)
			end
			others[c] = nil
			FruitFX().HideArm(c, "Right", 0)
			FruitFX().HideArm(c, "Left", 0)
		end
	end)
end

return Sling
