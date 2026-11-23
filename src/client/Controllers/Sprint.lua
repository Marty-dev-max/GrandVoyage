-- Sprint (v0.25.89, owner): double-tap W (or the forward key you hold) to run; keep W held to keep running.
-- The server owns the walk speed (player attribute BaseSpeed = Formulas moveSpeed); while running this controller
-- sets WalkSpeed to BaseSpeed x GameConfig.Sprint.Mult every frame and puts it back when you stop.
-- Not while swimming, flying, downed or vending (those set their own speeds).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local Sprint = {}
local CFG = GameConfig.Sprint
local player = Players.LocalPlayer
local running, lastTap = false, 0

function Sprint.IsRunning()
	return running
end

local function blocked(char)
	local ok, swimming = pcall(function()
		return require(script.Parent.Swim).IsSwimming()
	end)
	local okF, flying = pcall(function()
		return require(script.Parent.Flight).IsFlying()
	end)
	return (ok and swimming) or (okF and flying) or char:GetAttribute("Downed") or player:GetAttribute("Vending")
end

function Sprint.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.W then
			return
		end
		local now = os.clock()
		if now - lastTap <= CFG.TapWindow then
			running = true
		end
		lastTap = now
	end)
	local wasRunning, fov = false, 0
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			running = false
			return
		end
		if running and (not UserInputService:IsKeyDown(Enum.KeyCode.W) or hum.MoveDirection.Magnitude < 0.1 or blocked(char)) then
			running = false
		end
		local base = player:GetAttribute("BaseSpeed")
		if running and base then
			hum.WalkSpeed = base * CFG.Mult
		elseif wasRunning and base and not blocked(char) then
			hum.WalkSpeed = base
		end
		wasRunning = running
		-- a small FOV push while running
		local cam = workspace.CurrentCamera
		local want = running and CFG.Fov or 0
		local k = 1 - math.exp(-dt * 8)
		local nf = fov + (want - fov) * k
		if cam and cam.CameraType == Enum.CameraType.Custom then
			cam.FieldOfView += nf - fov
		end
		fov = nf
	end)
end

return Sprint
