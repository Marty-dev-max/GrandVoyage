-- Timing Bar (Mastery v2 M1): the one-press minigame every Field Mastery uses (cooking first).
-- TB.Run(run, opts) shows a bar with the server's zones (run.green / run.yellow, 0..1), a needle sweeping back and
-- forth (Config/Mastery Needle), and waits for ONE press (click / tap / Space / E / Enter). Returns the seconds it
-- ran before the press (nil on timeout) and the zone hit ("green" | "yellow" | "plain"); the server judges for real
-- (MasteryService.TimingFinish). Yields.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MasteryCfg = require(ReplicatedStorage.Shared.Config.Mastery)
local UI = require(script.Parent.UIKit)
local Audio = require(script.Parent.Parent.Controllers.Audio)

local TB = {}
local T = UI.Theme
local New = UI.New

local W, H = 520, 34
local running = false

function TB.Busy()
	return running
end

-- opts: title (text above the bar), color (frame accent)
function TB.Run(run, opts)
	opts = opts or {}
	if running then
		return nil
	end
	running = true
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = New("ScreenGui", { Name = "GVTimingBar", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 70, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local box = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(W + 40, H + 96), BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.05, Parent = g })
	UI.Corner(box, 12)
	UI.Stroke(box, opts.color or T.Gold, 3)
	UI.Text(box, opts.title or "Stop it in the green!", 18, T.Text, "Display", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
	local bar = New("Frame", { Position = UDim2.fromOffset(20, 44), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(70, 60, 90), Parent = box })
	UI.Stroke(bar, Color3.fromRGB(20, 16, 30), 3)
	local function zone(a, b, color)
		return New("Frame", { BorderSizePixel = 0, Position = UDim2.new(a, 0, 0, 0), Size = UDim2.new(b - a, 0, 1, 0), BackgroundColor3 = color, Parent = bar })
	end
	zone(run.yellow[1], run.yellow[2], Color3.fromRGB(240, 196, 60))
	zone(run.green[1], run.green[2], Color3.fromRGB(80, 220, 110))
	local needle = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 6, 1, 16), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = bar })
	UI.Stroke(needle, Color3.fromRGB(20, 16, 30), 2)
	local hint = UI.Text(box, UserInputService.TouchEnabled and "TAP!" or "CLICK / SPACE", 14, T.TextSoft, "Display", { Position = UDim2.fromOffset(0, H + 58), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })

	local t0 = os.clock()
	local pressedAt
	local conns = {}
	local function press()
		if not pressedAt then
			pressedAt = os.clock() - t0
		end
	end
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end))
	-- the keys are sunk above Hotkeys (E = skill 1, Space = jump) while the bar runs
	ContextActionService:BindActionAtPriority("GVTimingBar", function(_, state)
		if state == Enum.UserInputState.Begin then
			press()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	table.insert(conns, RunService.RenderStepped:Connect(function()
		if pressedAt then
			return
		end
		local t = os.clock() - t0
		needle.Position = UDim2.new(MasteryCfg.Needle(t), 0, 0.5, 0)
		if t > (run.timeout or MasteryCfg.Timing.Timeout) then
			pressedAt = false
		end
	end))
	while pressedAt == nil do
		task.wait()
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	ContextActionService:UnbindAction("GVTimingBar")
	local t = pressedAt or nil
	local hit = "plain"
	if t then
		local x = MasteryCfg.Needle(t)
		needle.Position = UDim2.new(x, 0, 0.5, 0)
		if x >= run.green[1] and x <= run.green[2] then
			hit = "green"
		elseif x >= run.yellow[1] and x <= run.yellow[2] then
			hit = "yellow"
		end
	end
	hint.Text = hit == "green" and "PERFECT!" or (hit == "yellow" and "GOOD" or (t and "OK" or "TOO SLOW"))
	hint.TextColor3 = hit == "green" and T.Green or (hit == "yellow" and T.Gold or T.TextSoft)
	pcall(function()
		Audio.Play(hit == "green" and "BlkLevelUp" or "BlkCoin")
	end)
	task.delay(0.7, function()
		g:Destroy()
	end)
	running = false
	return t, hit
end

return TB
