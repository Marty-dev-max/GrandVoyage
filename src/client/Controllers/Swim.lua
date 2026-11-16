-- Swim (client): keeps the character floating at the sea surface, slows walking to a swim, shows a breath bar
-- and lets you jump out onto docks. The server (PlayerService) enforces the breath limit independently.
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
local breath = CFG.BreathSeconds
local float, normalSpeed
local bar, barFill, barText

local function groundBelow(root, hum)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local world = workspace:FindFirstChild("World")
	params.FilterDescendantsInstances = { player.Character, world and world:FindFirstChild("Ocean"), workspace:FindFirstChild("ReadabilityFX"), workspace:FindFirstChild("ClientFX") }
	params.RespectCanCollide = true
	local reach = hum.HipHeight + root.Size.Y / 2 + 1.6
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) ~= nil
end

local function buildBar()
	bar = New("Frame", { Name = "Breath", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.fromOffset(300, 26), BackgroundColor3 = T.PanelDeep, Visible = false, Parent = UI.Root })
	UI.Corner(bar, 13)
	UI.Stroke(bar, T.Edge, 3)
	barFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
	UI.Corner(barFill, 13)
	UI.Gradient(barFill, Color3.fromRGB(150, 230, 255), Color3.fromRGB(40, 140, 230), 90)
	barText = UI.Text(bar, "🫧 BREATH", 16, Color3.new(1, 1, 1), "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
end

local function setSwimming(on, root, hum)
	if on == swimming then
		return
	end
	swimming = on
	if on then
		normalSpeed = hum.WalkSpeed
		hum.WalkSpeed = CFG.Speed
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
	else
		if float then
			float:Destroy()
			float = nil
		end
		if normalSpeed then
			hum.WalkSpeed = normalSpeed
		end
		bar.Visible = false
	end
end
Swim.IsSwimming = function()
	return swimming
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
		local inWater = root.Position.Y < surface + 0.5 and not hum.Sit and not groundBelow(root, hum)
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
		if swimming then
			breath = math.max(0, breath - dt)
			local targetY = surface - CFG.SurfaceOffset + math.sin(os.clock() * 2) * 0.15
			float.LineVelocity = math.clamp((targetY - root.Position.Y) * 6, -25, 25)
			acc += dt
			if acc > 0.4 then
				acc = 0
				if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
					pcall(function()
						hum:ChangeState(Enum.HumanoidStateType.Swimming)
					end)
				end
			end
			local k = breath / CFG.BreathSeconds
			barFill.Size = UDim2.fromScale(k, 1)
			barText.Text = k < 0.25 and "🫧 OUT OF BREATH!" or "🫧 BREATH"
			barText.TextColor3 = k < 0.25 and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
		else
			breath = math.min(CFG.BreathSeconds, breath + dt * 6)
		end
	end)
	-- jump out of the water (onto docks and beaches)
	UserInputService.JumpRequest:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if swimming and root then
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
		end
	end)
	player.CharacterAdded:Connect(function()
		swimming = false
		float = nil
		breath = CFG.BreathSeconds
		if bar then
			bar.Visible = false
		end
	end)
end

return Swim
