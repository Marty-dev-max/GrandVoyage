-- Guard (remake R1, docs/Plan-Movement-Combat-v3.md sec 3): hold Block (F by default; a BLOCK button on touch
-- screens) to raise the guard. The server (Services/GuardService) decides what a blow does: tapping F just before
-- it lands = Parry, holding = Block (x0.3 damage, fills Posture), too much = guard break.
-- While blocking you walk slowly and cannot sprint. Released when the key comes up (the CAS key-up can go missing:
-- the loop also checks UserInputService:IsKeyDown, v0.25.49), on a dash, a guard break or when the server refuses.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Anim = require(ReplicatedStorage.Shared.Modules.Anim)
local State = require(script.Parent.Parent.State)
local Hotkeys = require(script.Parent.Hotkeys)

local Guard = {}
local player = Players.LocalPlayer
local holding = nil -- { key = KeyCode | nil (touch), conn }

local function hum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Guard.IsBlocking()
	return holding ~= nil
end

local function canGuard(h)
	if not h or h.Health <= 0 or h.Sit or h.Parent:GetAttribute("Downed") or h:GetAttribute("Stunned") then
		return false
	end
	if h:GetState() == Enum.HumanoidStateType.Swimming then
		return false
	end
	local okF, flying = pcall(function()
		return require(script.Parent.Flight).IsFlying()
	end)
	return not (okF and flying)
end

function Guard.Lower(fromServer)
	if not holding then
		return
	end
	local h = hum()
	if holding.conn then
		holding.conn:Disconnect()
	end
	holding = nil
	State.blocking = false
	if not fromServer then
		task.spawn(Net.Request, "Guard", { on = false })
	end
	if h then
		Anim.Stop(h, "Guard_Block", 0.12)
		local base = player:GetAttribute("BaseSpeed")
		if base and h.Health > 0 and not h:GetAttribute("Stunned") then
			h.WalkSpeed = base
		end
	end
end

-- key = the KeyCode to watch (nil for the touch button, which calls Guard.Stop itself)
function Guard.Raise(key)
	local h = hum()
	if holding or State.build.active or not canGuard(h) then
		return
	end
	holding = { key = key }
	State.blocking = true
	task.spawn(function()
		local res = Net.Request("Guard", { on = true })
		if holding and type(res) == "table" and res.ok == false and not res.throttled then
			Guard.Lower(true) -- guard broken / downed
		end
	end)
	Anim.Play(h, "Guard_Block", { fade = 0.08 })
	local slow = GameConfig.Guard.WalkMult
	holding.conn = RunService.RenderStepped:Connect(function()
		local hh = hum()
		if not holding or hh ~= h or not canGuard(hh) or (holding.key and not UserInputService:IsKeyDown(holding.key)) then
			Guard.Lower()
			return
		end
		local base = player:GetAttribute("BaseSpeed")
		if base then
			h.WalkSpeed = base * slow
		end
	end)
end

local function atHelm(h)
	return h ~= nil and h.SeatPart ~= nil and h.SeatPart.Name == "HelmSeat"
end

function Guard.Start()
	Hotkeys.On("Block", function()
		local h = hum()
		if State.build.active or atHelm(h) then
			return false -- the helm's own F (fire) / the shipyard keep the key
		end
		local k = Hotkeys.Key("Block")
		Guard.Raise(k and Enum.KeyCode[k])
	end)
	Hotkeys.OnRelease("Block", function()
		if holding and holding.key then
			Guard.Lower()
		end
	end)
	Net.OnPush("GuardBreak", function()
		Guard.Lower(true)
	end)
	player.CharacterAdded:Connect(function()
		Guard.Lower(true)
	end)
	-- touch screens: a hold-to-block button above the LOCK button (ShiftLock)
	if UserInputService.TouchEnabled then
		local UI = require(script.Parent.Parent.UI.UIKit)
		local gui = Instance.new("ScreenGui")
		gui.Name = "GuardButton"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 30
		gui.Parent = player:WaitForChild("PlayerGui")
		local btn = UI.Button(gui, "BLOCK", UI.Theme.Grey, UDim2.fromOffset(96, 36), function() end)
		btn.Parent.AnchorPoint = Vector2.new(1, 1)
		btn.Parent.Position = UDim2.new(1, -20, 1, -186)
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				Guard.Raise(nil)
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				Guard.Lower()
			end
		end)
		task.spawn(function()
			while gui.Parent do
				gui.Enabled = not UI.AnyOpen()
				task.wait(0.2)
			end
		end)
	end
end

return Guard
