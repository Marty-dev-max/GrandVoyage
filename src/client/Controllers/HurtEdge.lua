-- HurtEdge (remake R1, M6; owner: no blood, a thin red gradient vignette that is "just visible"): every HP loss of
-- your own character flashes the screen edges red, stronger the bigger the hit (damage / max HP), fading in
-- GameConfig.HurtEdge.Fade s. The low-HP pulse in init.client stays as it is.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local HurtEdge = {}
local CFG = GameConfig.HurtEdge
local player = Players.LocalPlayer

function HurtEdge.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HurtEdge"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 28
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local edges = {}
	-- thinner than the low-HP edges: 12% top/bottom, 9% sides, transparent toward the middle
	for _, e in ipairs({ { UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0.88), -90 }, { UDim2.fromScale(0.09, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.09, 1), UDim2.fromScale(0.91, 0), 180 } }) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(220, 20, 20)
		f.BackgroundTransparency = 1
		f.Size, f.Position = e[1], e[2]
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = gui
		table.insert(edges, f)
	end
	local level, conn = 0, nil -- 0 = off .. 1 = strongest
	local function watch(char)
		if conn then
			conn:Disconnect()
		end
		local h = char:WaitForChild("Humanoid", 10)
		if not h then
			return
		end
		local last = h.Health
		conn = h.HealthChanged:Connect(function(hp)
			local lost = last - hp
			last = hp
			if lost > 0 and h.MaxHealth > 0 then
				-- a 2% scratch shows faintly, a quarter of your HP or more shows at full strength
				level = math.max(level, math.clamp(0.25 + lost / h.MaxHealth * 3, 0.25, 1))
			end
		end)
	end
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
	RunService.RenderStepped:Connect(function(dt)
		if level <= 0 then
			if gui.Enabled then
				gui.Enabled = false
			end
			return
		end
		level = math.max(0, level - dt / CFG.Fade)
		gui.Enabled = true
		local tr = CFG.Weakest + (CFG.Strongest - CFG.Weakest) * level
		tr = 1 - (1 - tr) * math.min(1, level * 1.5) -- eases out at the end instead of popping off
		for _, f in ipairs(edges) do
			f.BackgroundTransparency = tr
		end
	end)
end

return HurtEdge
