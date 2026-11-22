-- ShiftLock (client, v0.25.6, owner: "can't use Shift Lock"): our own over-the-shoulder lock on Left Shift. Roblox's
-- built-in one only works when each player turns "Shift Lock Switch" on in their Roblox settings (off by default),
-- so players who did that keep Roblox's (we stay out of the way). While locked: the mouse is held at the screen
-- center, the camera sits over the right shoulder and the character faces where the camera looks (Crosshair and
-- manual-mode aiming already follow MouseBehavior.LockCenter). Any open window releases the mouse.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UI = require(script.Parent.Parent.UI.UIKit)

local SL = {}
local player = Players.LocalPlayer
local GameSettings = UserSettings():GetService("UserGameSettings")
local SHOULDER = 1.75
local on = false

local function nativeLock()
	local ok, mode = pcall(function()
		return UserSettings():GetService("UserGameSettings").ControlMode
	end)
	return ok and mode == Enum.ControlMode.MouseLockSwitch
end

function SL.IsOn()
	return on
end

local function apply(state)
	on = state
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		GameSettings.RotationType = Enum.RotationType.MovementRelative
	end
end

function SL.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.LeftShift or nativeLock() then
			return
		end
		apply(not on)
	end)
	-- phones / tablets: a LOCK toggle above the jump button (no Shift key there)
	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "ShiftLockButton"
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		local btn = UI.Button(gui, "LOCK", UI.Theme.Grey, UDim2.fromOffset(110, 40), function()
			apply(not on)
		end)
		btn.Parent.AnchorPoint = Vector2.new(1, 1)
		btn.Parent.Position = UDim2.new(1, -24, 1, -230)
		task.spawn(function()
			local was
			while gui.Parent do
				if was ~= on then
					was = on
					UI.SetButtonColor(btn, on and UI.Theme.Green or UI.Theme.Grey)
				end
				task.wait(0.2)
			end
		end)
	end
	player.CharacterAdded:Connect(function()
		task.wait()
		apply(on)
	end)
	-- v0.25.23 (owner: still jerky): the same thing Roblox's own Shift Lock does. The humanoid turns itself to the
	-- camera (RotationType CameraRelative) inside the physics step, instead of us snapping root.CFrame every frame
	-- (that fought the physics and jittered). Set after the camera scripts so they cannot undo it.
	RunService:BindToRenderStep("GVShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
		if not on then
			return
		end
		if UI.AnyOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			GameSettings.RotationType = Enum.RotationType.MovementRelative
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		GameSettings.RotationType = Enum.RotationType.CameraRelative
		-- v0.25.25 (owner: still jerky): the shoulder offset goes on the CAMERA, in its own right-vector, like
		-- Roblox's mouse lock. Humanoid.CameraOffset is in the body's space: the body turns one physics step after
		-- the camera, so that offset swung the view every frame. The camera scripts rebuild the CFrame from the
		-- focus each frame, so this never accumulates.
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType == Enum.CameraType.Custom then
			cam.CFrame = cam.CFrame * CFrame.new(SHOULDER, 0, 0)
		end
	end)
end

return SL
