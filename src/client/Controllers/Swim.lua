-- Swim (client): keeps the character floating at the sea surface, slows walking to a swim, lets you DIVE (v0.22.4)
-- and jump out onto docks. Hold Ctrl (or the 🤿 button on phones, L2 on a gamepad) to dive, hold Space / Jump to
-- swim up, let go and you drift back up slowly. Breath only runs out under the surface; out of breath you are pushed
-- up. Swimming on top is limited too (Swim.SeaSeconds) so the sea is crossed by ship. The server (PlayerService)
-- enforces both limits independently. The underwater look and sound are in Controllers/Underwater.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local UI = require(script.Parent.Parent.UI.UIKit)
local Audio = require(script.Parent.Audio)

local Swim = {}
local player = Players.LocalPlayer
local CFG = GameConfig.Swim
local T = UI.Theme
local New = UI.New

local swimming = false
local sinkWarned = false
local function maxBreath()
	-- Tidekin heritage breathes 60% longer (server mirrors it in PlayerService)
	return CFG.BreathSeconds * (player:GetAttribute("Heritage") == "Tidekin" and 1.6 or 1)
end
local breath = CFG.BreathSeconds
local seaTime = 0
local depth = 0 -- studs below the normal floating height
local diveHeld = false
local riseUntil = 0
local outOfBreath = false
local float, normalSpeed
local bar, barFill, barText, diveBtn

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local world = workspace:FindFirstChild("World")
	params.FilterDescendantsInstances = { player.Character, world and world:FindFirstChild("Ocean"), workspace:FindFirstChild("ReadabilityFX"), workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("GVUnderwaterFX") }
	params.RespectCanCollide = true
	return params
end

local function groundBelow(root, hum)
	local reach = hum.HipHeight + root.Size.Y / 2 + 1.6
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams()) ~= nil
end

-- how deep you can go here: the sea floor (or a reef / island slope) minus a little room
local function maxDepthHere(root, hum)
	local base = GameConfig.SeaLevel - CFG.SurfaceOffset
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(CFG.MaxDepth + 20), 0), rayParams())
	local floorLimit = hit and (base - (hit.Position.Y + hum.HipHeight + root.Size.Y / 2 + 0.5)) or CFG.MaxDepth
	return math.clamp(math.min(CFG.MaxDepth, floorLimit), 0, CFG.MaxDepth)
end

local function buildBar()
	bar = New("Frame", { Name = "Breath", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.fromOffset(300, 26), BackgroundColor3 = T.PanelDeep, Visible = false, Parent = UI.Root })
	UI.Corner(bar, 13)
	UI.Stroke(bar, T.Edge, 3)
	barFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
	UI.Corner(barFill, 13)
	UI.Gradient(barFill, Color3.fromRGB(150, 230, 255), Color3.fromRGB(40, 140, 230), 90)
	barText = UI.Text(bar, "🫧 BREATH", 16, Color3.new(1, 1, 1), "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	-- phones: hold to dive (the jump button swims up)
	if UI.IsMobile then
		diveBtn = New("TextButton", { Name = "Dive", Text = "🤿", TextSize = 40, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -150, 1, -250), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(40, 140, 230), Visible = false, AutoButtonColor = false, Parent = UI.Root })
		UI.Corner(diveBtn, 42)
		UI.Stroke(diveBtn, T.Edge, 3)
		diveBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				diveHeld = true
			end
		end)
		diveBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				diveHeld = false
			end
		end)
	end
end

local function setSwimming(on, root, hum)
	if on == swimming then
		return
	end
	swimming = on
	if on then
		normalSpeed = hum.WalkSpeed
		hum.WalkSpeed = CFG.Speed
		depth = math.clamp(GameConfig.SeaLevel - CFG.SurfaceOffset - root.Position.Y, 0, CFG.MaxDepth)
		local att = root:FindFirstChild("RootAttachment") or New("Attachment", { Name = "RootAttachment", Parent = root })
		float = New("LinearVelocity", {
			Name = "SwimFloat",
			Attachment0 = att,
			VelocityConstraintMode = Enum.VelocityConstraintMode.Line,
			LineDirection = Vector3.yAxis,
			LineVelocity = 0,
			MaxForce = root.AssemblyMass * workspace.Gravity * 4,
			RelativeTo = Enum.ActuatorRelativeTo.World,
			Parent = root,
		})
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Swimming)
		end)
		Audio.Play("Splash", { pos = root.Position })
		bar.Visible = true
		UI.Pop(bar, 0.7)
		if diveBtn then
			diveBtn.Visible = true
		end
	else
		if float then
			float:Destroy()
			float = nil
		end
		if normalSpeed then
			hum.WalkSpeed = normalSpeed
		end
		bar.Visible = false
		depth = 0
		seaTime = 0
		if diveBtn then
			diveBtn.Visible = false
		end
	end
end
Swim.IsSwimming = function()
	return swimming
end
Swim.Depth = function()
	return depth
end

function Swim.Start()
	buildBar()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			return
		end
		local surface = GameConfig.SeaLevel
		-- deep enough counts as water even right above a reef or an island slope
		local inWater = root.Position.Y < surface + 0.5 and not hum.Sit and (not groundBelow(root, hum) or root.Position.Y < surface - 3)
		if inWater and player:GetAttribute("Fruit") then
			-- Cursed Fruit users sink like a stone and drown (the server drains their HP)
			if not sinkWarned then
				sinkWarned = true
				UI.Notice("🍎 FRUIT USERS CAN'T SWIM! YOU'RE DROWNING!", T.Red)
				Audio.Play("Splash", { pos = root.Position })
			end
			setSwimming(false, root, hum)
			return
		end
		sinkWarned = false
		setSwimming(inWater, root, hum)
		-- v0.25.26 (owner: the fly pose and the Shift Lock shake came back after a while): we force the humanoid into
		-- Swimming in the sea, but nothing took it out again. Stuck in Swimming on land it walked in Roblox's swim
		-- pose and its swim turning fought Shift Lock. Out of the water = Freefall, which lands normally.
		if not swimming and hum:GetState() == Enum.HumanoidStateType.Swimming and not char:GetAttribute("Downed") then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		if swimming then
			local maxD = maxDepthHere(root, hum)
			local rising = os.clock() < riseUntil or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			if outOfBreath then
				depth = math.max(0, depth - CFG.RiseSpeed * 1.4 * dt)
			elseif diveHeld and not rising then
				depth = math.min(maxD, depth + CFG.DiveSpeed * dt)
			elseif rising then
				depth = math.max(0, depth - CFG.RiseSpeed * dt)
			else
				depth = math.max(0, depth - CFG.Buoyancy * dt)
			end
			depth = math.min(depth, maxD)
			local bob = depth < 0.5 and math.sin(os.clock() * 2) * 0.15 or 0
			local targetY = surface - CFG.SurfaceOffset - depth + bob
			float.LineVelocity = math.clamp((targetY - root.Position.Y) * 6, -30, 30)
			acc += dt
			if acc > 0.4 then
				acc = 0
				if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
					pcall(function()
						hum:ChangeState(Enum.HumanoidStateType.Swimming)
					end)
				end
			end
			local submerged = depth > 1.2
			seaTime += dt
			if submerged then
				breath = math.max(0, breath - dt)
				if breath <= 0 and not outOfBreath then
					outOfBreath = true
					UI.Notice("🫧 OUT OF BREATH! SWIM UP!", T.Red)
				end
			else
				breath = math.min(maxBreath(), breath + dt * 6)
				if breath >= maxBreath() * 0.5 then
					outOfBreath = false
				end
			end
			-- one bar: breath while under (or refilling), otherwise how long you can keep swimming
			local k, label
			if submerged or breath < maxBreath() - 0.05 then
				k, label = breath / maxBreath(), "🫧 BREATH"
			else
				k, label = math.max(0, 1 - seaTime / CFG.SeaSeconds), "🏊 SWIM"
			end
			barFill.Size = UDim2.fromScale(k, 1)
			barText.Text = k < 0.25 and (submerged and "🫧 OUT OF BREATH!" or "🏊 TIRED: GET OUT!") or label
			barText.TextColor3 = k < 0.25 and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
		else
			breath = math.min(maxBreath(), breath + dt * 6)
			outOfBreath = false
		end
	end)
	-- dive: Ctrl (either), gamepad L2
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.RightControl or kc == Enum.KeyCode.ButtonL2 then
			diveHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kc = input.KeyCode
		if kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.RightControl or kc == Enum.KeyCode.ButtonL2 then
			diveHeld = false
		end
	end)
	-- Jump: under water it swims you up; at the surface it jumps out (onto docks and beaches)
	UserInputService.JumpRequest:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not swimming or not root then
			return
		end
		if depth > 1 then
			riseUntil = os.clock() + 0.35
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, CFG.JumpOutVelocity, v.Z)
		if float then
			float.Enabled = false
			task.delay(0.6, function()
				if float then
					float.Enabled = true
				end
			end)
		end
	end)
	player.CharacterAdded:Connect(function()
		swimming = false
		float = nil
		breath = maxBreath()
		depth, seaTime, outOfBreath, diveHeld = 0, 0, false, false
		if bar then
			bar.Visible = false
		end
		if diveBtn then
			diveBtn.Visible = false
		end
	end)
end

return Swim
