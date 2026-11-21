-- Crosshair (client, v0.24.6, owner): in manual mode with Shift Lock, a pixel-art "^" (a mountain peak: a triangle
-- with no bottom edge) sits at the screen center instead of Roblox's cursor. Skills and swings aim through it
-- (Combat.AimInfo uses the screen center while the mouse is locked).
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local State = require(script.Parent.Parent.State)

local Crosshair = {}
local PX = 2 -- v0.25.8 (owner): smaller (was 4) -- one pixel of the sprite, in screen pixels
local SHAPE = {
	"...X...",
	"..X.X..",
	".X...X.",
	"X.....X",
}

function Crosshair.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui:SetAttribute("PxKeep", true)
	local w, h = #SHAPE[1], #SHAPE
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(w * PX, h * PX)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	-- dark outline first (each pixel grown by 1 on every side), then the white pixels on top
	for pass = 1, 2 do
		for y, row in ipairs(SHAPE) do
			for x = 1, w do
				if string.sub(row, x, x) == "X" then
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					if pass == 1 then
						f.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
						f.Position = UDim2.fromOffset((x - 1) * PX - 2, (y - 1) * PX - 2)
						f.Size = UDim2.fromOffset(PX + 4, PX + 4)
					else
						f.BackgroundColor3 = Color3.new(1, 1, 1)
						f.Position = UDim2.fromOffset((x - 1) * PX, (y - 1) * PX)
						f.Size = UDim2.fromOffset(PX, PX)
						f.ZIndex = 2
					end
					f.Parent = holder
				end
			end
		end
	end
	local shown = false
	RunService.RenderStepped:Connect(function()
		local want = not State.auto and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		if want ~= shown then
			shown = want
			gui.Enabled = want
			UserInputService.MouseIconEnabled = not want
		end
	end)
end

return Crosshair
