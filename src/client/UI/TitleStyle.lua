-- TitleStyle: one look for a title wherever it shows (nameplates, the Bag title button, the title picker preview):
-- the tier's color; Legendary and Mythic get a white shimmer sliding across; Secret cycles through every color.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Modules.Rarity)

local TitleStyle = {}
local live = setmetatable({}, { __mode = "k" }) -- UIGradient -> { color, secret }

function TitleStyle.Color(tier)
	return Rarity.Get(tier or "Common").color
end

-- style a TextLabel as this tier (safe to call again when the tier changes)
function TitleStyle.Apply(label, tier)
	local r = Rarity.Get(tier or "Common")
	local old = label:FindFirstChild("TitleShimmer")
	if old then
		old:Destroy()
	end
	local fancy = (r.rank or 1) >= 5
	label.TextColor3 = fancy and Color3.new(1, 1, 1) or r.color
	if fancy then
		local g = Instance.new("UIGradient")
		g.Name = "TitleShimmer"
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, r.color), ColorSequenceKeypoint.new(0.5, r.color:Lerp(Color3.new(1, 1, 1), 0.65)), ColorSequenceKeypoint.new(1, r.color) })
		g.Parent = label
		live[g] = { color = r.color, secret = tier == "Secret" }
	end
end

local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	for g, info in pairs(live) do
		if g.Parent then
			g.Offset = Vector2.new(math.sin(t * 1.6) * 0.7, 0)
			if info.secret then
				local c = Color3.fromHSV((t * 0.15) % 1, 0.65, 1)
				g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, c) })
			end
		end
	end
end)

return TitleStyle
