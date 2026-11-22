-- Heritage (client, v0.24.0): what your heritage (Config/Looks) does in the world.
--  * Glide: winged heritages (Skyborn, Cinderwing) hold Jump in mid-air to fall slowly.
--  * Cinderwing modes: V (G is the Guild window) (or the chip on the right edge) switches FLAME (hits harder) <-> CALM (moves faster);
--    the server owns the switch (HeritageMode request), this only asks and shows it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)
local UI = require(script.Parent.Parent.UI.UIKit)
local Voxels = require(script.Parent.Voxels)

local Heritage = {}
local player = Players.LocalPlayer
local GLIDE_FALL = 9 -- studs/s: the slowest a glider falls

local chip, chipText
local function her()
	return Looks.HeritageById[player:GetAttribute("Heritage") or ""]
end

local function refreshChip()
	if not chip then
		return
	end
	chip.Visible = false
	local calm = player:GetAttribute("HeritageMode") == "calm"
	chipText.Text = calm and "CALM [V]" or "FLAME [V]"
	chip.BackgroundColor3 = calm and Color3.fromRGB(70, 150, 230) or Color3.fromRGB(240, 110, 40)
end

local busy = false
local function toggle()
	local h = her()
	if not h or not h.modes or busy then
		return
	end
	busy = true
	local res = Net.Request("HeritageMode")
	if res.msg then
		UI.Toast(res.msg, res.ok and "good" or "bad")
	end
	busy = false
end

function Heritage.Start()
	-- mode chip (only shown for Cinderwing)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeritageHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	chip = Instance.new("TextButton") -- (v0.24.6: the mode lives in the HUD slot left of Dash; this chip stays hidden)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -14, 0.36, 0)
	chip.Size = UDim2.fromOffset(150, 40)
	chip.AutoButtonColor = false
	chip.Text = ""
	chip.Visible = false
	chip.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(10, 8, 16)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = chip
	chipText = Instance.new("TextLabel")
	chipText.BackgroundTransparency = 1
	chipText.Size = UDim2.fromScale(1, 1)
	chipText.FontFace = UI.Fonts.Display
	chipText.TextSize = 18
	chipText.TextColor3 = Color3.new(1, 1, 1)
	chipText.TextStrokeTransparency = 0
	chipText.Parent = chip
	UI.Tactile(chip)
	chip.Activated:Connect(toggle)
	-- Store boost timers (2x EXP / 2x Drop / Fruit Notifier): small chips under the mode chip
	-- boost timers live in the HUD row under the EXP readouts (HUD.boostRow, v0.24.12); built in a holder first and
	-- moved there once the HUD is up (never yield Start)
	local boostCol = Instance.new("Frame")
	boostCol.BackgroundTransparency = 1
	boostCol.Position = UDim2.new(0, 520, 0, 24)
	boostCol.Size = UDim2.fromOffset(170, 120)
	boostCol.Parent = gui
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 4)
	lay.Parent = boostCol
	task.spawn(function()
		local HUDmod = require(script.Parent.Parent.UI.HUD)
		local t0 = os.clock()
		while not HUDmod.boostRow and os.clock() - t0 < 15 do
			task.wait(0.2)
		end
		if HUDmod.boostRow then
			for _, c in ipairs(boostCol:GetChildren()) do
				if c:IsA("TextLabel") then
					c.Parent = HUDmod.boostRow
				end
			end
		end
	end)
	local BOOSTS = { { "BoostExp", "2x EXP", Color3.fromRGB(255, 206, 70) }, { "BoostDrop", "2x DROP", Color3.fromRGB(120, 220, 120) }, { "BoostFruit", "FRUIT RADAR", Color3.fromRGB(240, 120, 200) } }
	local chips = {}
	for i, b in ipairs(BOOSTS) do
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.Size = UDim2.fromOffset(b[1] == "BoostFruit" and 128 or 100, 20)
		l.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
		l.BackgroundTransparency = 0.35
		l.BorderSizePixel = 0
		l.TextColor3 = b[3]
		l.FontFace = UI.Fonts.Display
		l.TextSize = 11
		local st = Instance.new("UIStroke")
		st.Color = b[3]
		st.Transparency = 0.4
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = l
		l.Visible = false
		l.Parent = boostCol
		chips[b[1]] = { label = l, name = b[2] }
	end
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			for attr, c in pairs(chips) do
				local untilT = player:GetAttribute(attr)
				local left = untilT and (untilT - now) or 0
				c.label.Visible = left > 0
				if left > 0 then
					c.label.Text = string.format("%s %d:%02d", c.name, math.floor(left / 60), math.floor(left % 60))
				end
			end
			task.wait(1)
		end
	end)
	player:GetAttributeChangedSignal("Heritage"):Connect(refreshChip)
	player:GetAttributeChangedSignal("HeritageMode"):Connect(refreshChip)
	refreshChip()

	require(script.Parent.Hotkeys).On("Race", function()
		toggle()
	end)

	-- glide
	RunService.Heartbeat:Connect(function()
		local h = her()
		if not h or not h.glide then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then
			return
		end
		if hum:GetState() == Enum.HumanoidStateType.Freefall and (UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump) then
			local v = root.AssemblyLinearVelocity
			if v.Y < -GLIDE_FALL then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -GLIDE_FALL, v.Z)
			end
		end
	end)

	-- mode switch burst (every client nearby)
	Net.OnFX(function(kind, d)
		if kind ~= "HeritageMode" or type(d) ~= "table" or typeof(d.pos) ~= "Vector3" then
			return
		end
		if d.mode == "calm" then
			Voxels.Pixels(d.pos, { count = 40, colors = { Color3.fromRGB(180, 230, 255), Color3.fromRGB(255, 255, 255) }, size = 0.3, speed = 18, gravity = 0, life = 0.6, glow = 0.6, spread = 3 })
		else
			Voxels.Blocks(d.pos + Vector3.new(0, 1, 0), { count = 18, colors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 245, 190) }, size = { 0.3, 0.7 }, speed = 8, up = 16, neon = true, collide = false, life = 0.8 })
			Voxels.Pixels(d.pos, { count = 40, colors = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 230, 120) }, size = 0.35, speed = 12, gravity = -16, life = 0.8, glow = 1, spread = 2, texture = "px_flame" })
		end
	end)
end

return Heritage
