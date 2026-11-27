-- Stamina (remake R1, docs/Plan-Movement-Combat-v3.md sec 4): one gauge for movement (dash, sprint; climbing and
-- wall running next). Kept on the client: it only gates your own movement, the server still checks the dash
-- cooldown. Regenerates GameConfig.Stamina.Regen / s once nothing used it for RegenDelay s.
-- The bars (stamina + the server's Posture from the char attribute) sit just below the screen centre and fade out
-- when there is nothing to show (owner: keep the screen uncluttered).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local Stamina = {}
local CFG = GameConfig.Stamina
local player = Players.LocalPlayer
local value, lastUse, shortAt = CFG.Max, -99, -99

-- Endurance raises the bar and its regen (PlayerService.Recompute sets the player attributes from Formulas)
local function maxNow()
	return player:GetAttribute("MaxStamina") or CFG.Max
end
local function regenNow()
	return player:GetAttribute("StaminaRegen") or CFG.Regen
end

function Stamina.Max()
	return maxNow()
end

function Stamina.Value()
	return value
end

-- pay `n` at once (dash); false = not enough (the bar flashes red)
function Stamina.Use(n)
	if value < n then
		shortAt = os.clock()
		return false
	end
	value -= n
	lastUse = os.clock()
	return true
end

-- pay `n` of a running cost (sprint per frame); false once empty
function Stamina.Drain(n)
	value = math.max(0, value - n)
	lastUse = os.clock()
	if value <= 0 then
		shortAt = os.clock()
	end
	return value > 0
end

function Stamina.Start()
	local UI = require(script.Parent.Parent.UI.UIKit)
	local group = Instance.new("CanvasGroup")
	group.Name = "GVStamina"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.new(0.5, 0, 0.63, 0)
	group.Size = UDim2.fromOffset(170, 26)
	group.GroupTransparency = 1
	group.Parent = UI.Root
	local stam = UI.Bar(group, Color3.fromRGB(130, 220, 90), UDim2.new(1, 0, 0, 10), "", 1)
	local post = UI.Bar(group, Color3.fromRGB(255, 150, 60), UDim2.new(1, -30, 0, 7), "", 0)
	post.back.Position = UDim2.fromOffset(15, 16)
	local shown, postShown = 0, 0
	local stamRed, postRed = false, false
	player.CharacterAdded:Connect(function()
		value = maxNow()
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now - lastUse > CFG.RegenDelay then
			local mx = maxNow()
			value = math.min(mx, value + regenNow() * dt)
		end
		local char = player.Character
		local posture = char and char:GetAttribute("Posture") or 0
		local maxP = GameConfig.Guard.PostureMax
		-- steps of 2% (UI.Bar tweens every change; a per-frame drain would start a tween every frame)
		stam:Set(math.floor(value / maxNow() * 50 + 0.5) / 50)
		post:Set(math.floor(math.clamp(posture / maxP, 0, 1) * 50 + 0.5) / 50)
		-- red while short of stamina, else green; orange posture turns red near a guard break
		local short = now - shortAt < 0.4
		local danger = posture / maxP > 0.75
		if short ~= stamRed then
			stamRed = short
			stam:SetColor(short and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(130, 220, 90))
		end
		if danger ~= postRed then
			postRed = danger
			post:SetColor(danger and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 150, 60))
		end
		local want = (value < maxNow() - 0.5 or short or posture > 0) and 0 or 1
		local k = 1 - math.exp(-dt * (want == 0 and 14 or 4))
		shown += (want - shown) * k
		postShown += ((posture > 0 and 0 or 1) - postShown) * k
		group.GroupTransparency = shown
		post.back.Visible = postShown < 0.95
		group.Visible = shown < 0.99 and not UI.AnyOpen()
	end)
end

return Stamina
