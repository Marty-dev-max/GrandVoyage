-- Footsteps (client, v0.25.1, owner: world juice): little puffs of dust at the feet of anyone running on the ground
-- (in the ground's own color, sand / dirt / grass...), and water splashes around anyone swimming at the surface.
-- Every character near the camera, a few times a second; Settings quality scales it through Controllers/Voxels.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Voxels = require(script.Parent.Voxels)
local Audio = require(script.Parent.Audio)

-- v0.25.16 (owner): footstep sounds by ground (our step replaces Roblox's default running tap)
local STEP = {
	[Enum.Material.Grass] = "StepGrass", [Enum.Material.LeafyGrass] = "StepGrass", [Enum.Material.Ground] = "StepGrass",
	[Enum.Material.Mud] = "StepGrass", [Enum.Material.Wood] = "StepWood", [Enum.Material.WoodPlanks] = "StepWood",
	[Enum.Material.Sand] = "StepSand", [Enum.Material.Sandstone] = "StepSand",
}

local FS = {}
local RANGE = 110
local last = {} -- character -> clock of the last puff
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local WATER1, WATER2 = Color3.fromRGB(225, 245, 255), Color3.fromRGB(140, 205, 240)

function FS.Start()
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local now = os.clock()
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and (root.Position - cam.CFrame.Position).Magnitude < RANGE then
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local swimming = hum:GetState() == Enum.HumanoidStateType.Swimming
				local gap = swimming and 0.28 or math.clamp(3.2 / math.max(speed, 1), 0.16, 0.35)
				if speed > 10 and now - (last[char] or 0) > gap then
					last[char] = now
					if swimming then
						local y = GameConfig.SeaLevel or 0
						local at = Vector3.new(root.Position.X, y + 0.3, root.Position.Z) - v.Unit * 1.2
						Voxels.Pixels(at, { count = 7, colors = { WATER1, WATER2 }, size = 0.3, speed = 5, up = 6, gravity = 22, life = 0.5, glow = 0.2, spread = 1.4 })
					elseif hum.FloorMaterial ~= Enum.Material.Air and hum.FloorMaterial ~= Enum.Material.Water then
						params.FilterDescendantsInstances = { char }
						local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
						if hit and hit.Instance then
							local running = root:FindFirstChild("Running")
							if running and running:IsA("Sound") then
								running.Volume = 0
							end
							Audio.Play(STEP[hit.Material] or "StepStone", { pos = hit.Position, volume = pl == Players.LocalPlayer and 1 or 0.6 })
							local c = hit.Instance.Color:Lerp(Color3.fromRGB(235, 225, 200), 0.4)
							local back = Vector3.new(-v.X, 0, -v.Z).Unit * 0.8
							Voxels.Pixels(hit.Position + back + Vector3.new(0, 0.25, 0), { count = speed > 22 and 6 or 3, colors = { c, c:Lerp(Color3.new(1, 1, 1), 0.25) }, size = 0.32, speed = 2.5, up = 1.5, gravity = 3, life = 0.45, glow = 0, spread = 0.9 })
						end
					end
				end
			end
		end
		for char in pairs(last) do
			if not char.Parent then
				last[char] = nil
			end
		end
	end)
end

return FS
