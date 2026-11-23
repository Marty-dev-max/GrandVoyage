-- BossIntro (v0.25.113, owner): the first time you come near a boss (each spawned boss once), its name SLAMS into the
-- middle of the screen, then glides up to the top, a health bar slides in under it and fills from zero to full (so
-- the boss feels huge), and only then the boss music starts (State.bossIntroUntil keeps the music channel quiet,
-- Sailing.updateAudio reads it; State.lastBoss starts the boss track at the end). The boss roars right before the
-- music (owner, Bay Serpent first).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.Parent.UI.UIKit)
local Audio = require(script.Parent.Audio)
local State = require(script.Parent.Parent.State)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)

local BossIntro = {}
local New, Tween, T = UI.New, UI.Tween, UI.Theme

local NEAR = 90 -- studs from your character
local seen = setmetatable({}, { __mode = "k" })
local playing = false

local function play(model)
	playing = true
	local mon = Monsters[model:GetAttribute("MonsterId") or ""]
	local name = string.upper(mon and mon.name or model.Name)
	local lvl = model:GetAttribute("Level") or (mon and mon.level) or 1
	local DUR = 6
	State.bossIntroUntil = os.clock() + DUR

	local gui = New("ScreenGui", { Name = "BossIntro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 40, Parent = Players.LocalPlayer.PlayerGui })
	local root = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 1), Parent = gui }) -- UIScale shrinks toward the anchor: keep it centered
	local sc = New("UIScale", { Scale = UI.GetScale and UI.GetScale() or 1, Parent = root })
	local _ = sc
	-- a dark band behind the name while it sits in the middle
	local band = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1.2, 0, 0, 150), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = root })
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.3), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) }), Parent = band })
	local holder = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(900, 120), BackgroundTransparency = 1, Parent = root })
	local hs = New("UIScale", { Scale = 3, Parent = holder })
	local title = UI.Text(holder, name, 64, Color3.fromRGB(255, 90, 80), "Display", { Size = UDim2.new(1, 0, 0, 76), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTransparency = 1 })
	local stroke = New("UIStroke", { Color = Color3.fromRGB(30, 6, 10), Thickness = 5, Transparency = 1, Parent = title })
	local sub = UI.Text(holder, "BOSS  •  Lv." .. lvl, 22, Color3.fromRGB(255, 220, 120), "Display", { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTransparency = 1 })
	New("UIStroke", { Color = T.Edge, Thickness = 3, Parent = sub })

	-- 1) SLAM: drops in from huge, a hard boom, the screen jolts
	Tween(band, 0.15, { BackgroundTransparency = 0 })
	Tween(hs, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Tween(title, 0.12, { TextTransparency = 0 })
	Tween(stroke, 0.12, { Transparency = 0 })
	task.wait(0.16)
	Audio.Play("FinisherBoom", { volume = 0.9 })
	for i = 1, 6 do
		holder.Position = UDim2.new(0.5, math.random(-14, 14) / i, 0.45, math.random(-10, 10) / i)
		task.wait(0.03)
	end
	holder.Position = UDim2.fromScale(0.5, 0.45)
	Tween(sub, 0.25, { TextTransparency = 0 })
	task.wait(0.9)

	-- 2) the name glides up to the top of the screen and shrinks, the band fades
	Tween(band, 0.4, { BackgroundTransparency = 1 })
	Tween(holder, 0.45, { Position = UDim2.new(0.5, 0, 0, 120) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Tween(hs, 0.45, { Scale = 0.55 }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Tween(sub, 0.3, { TextTransparency = 1 })
	task.wait(0.45)

	-- 3) the health bar slides in under it and fills from 0 to full
	local barBox = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1.6, 0, 0, 162), Size = UDim2.fromOffset(520, 30), BackgroundColor3 = T.PanelDeep, Parent = root })
	UI.Stroke(barBox, T.Edge, 3)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(235, 60, 60), BorderSizePixel = 0, Parent = barBox })
	UI.Gradient(fill, Color3.fromRGB(255, 120, 110), Color3.fromRGB(190, 30, 40), 90)
	local maxHp = model:GetAttribute("MaxHP") or 1
	local num = UI.Text(barBox, "0 / " .. UI.Format(maxHp), 16, Color3.new(1, 1, 1), "Number", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	New("UIStroke", { Color = T.Edge, Thickness = 2, Parent = num })
	Tween(barBox, 0.3, { Position = UDim2.new(0.5, 0, 0, 162) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.3)
	local FILL = 1.2
	local t0, lastTick = os.clock(), 0
	while os.clock() - t0 < FILL do
		local k = (os.clock() - t0) / FILL
		k = 1 - (1 - k) ^ 2
		fill.Size = UDim2.fromScale(k, 1)
		num.Text = UI.Format(math.floor(maxHp * k)) .. " / " .. UI.Format(maxHp)
		if os.clock() - lastTick > 0.07 then
			lastTick = os.clock()
			Audio.Play("BlkTick", { volume = 0.35, pitch = 0.8 + k * 0.6 })
		end
		task.wait()
	end
	fill.Size = UDim2.fromScale(1, 1)
	num.Text = UI.Format(maxHp) .. " / " .. UI.Format(maxHp)
	Audio.Play("CardBass", { volume = 0.6 })

	-- 4) (owner) the boss ROARS before the music: loud roar from the boss + a global one, the camera rumbles
	State.bossIntroUntil = os.clock() + 2
	if model.Parent then
		Audio.Play("BossRoar", { pos = model:GetPivot().Position, volume = 1 })
	end
	Audio.Play("BossRoar", { volume = 0.7, pitch = 0.85 })
	local cam = workspace.CurrentCamera
	local s0 = os.clock()
	while os.clock() - s0 < 1.3 do
		local k = 1 - (os.clock() - s0) / 1.3
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * 0.5 * k, (math.random() - 0.5) * 0.5 * k, 0)
		task.wait()
	end
	-- 5) music in, the intro fades away (the HUD target bar takes over once you fight it)
	State.bossIntroUntil = 0
	State.lastBoss = os.clock()
	task.wait(1.1)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") then
			Tween(d, 0.4, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Tween(d, 0.4, { Transparency = 1 })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			Tween(d, 0.4, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.45)
	gui:Destroy()
	playing = false
end

function BossIntro.Start()
	task.spawn(function()
		while true do
			task.wait(0.3)
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local folder = workspace:FindFirstChild("Monsters")
			if root and folder and not playing then
				for _, m in ipairs(folder:GetChildren()) do
					if m:GetAttribute("Boss") and not seen[m] and (m:GetAttribute("HP") or 1) > 0 then
						local p = m:GetPivot().Position
						-- a sea boss waits under the water until it rises: no intro for a hidden one
						if p.Y > -4 and (p - root.Position).Magnitude < NEAR then
							seen[m] = true
							task.spawn(play, m)
							break
						end
					end
				end
			end
		end
	end)
end

return BossIntro
