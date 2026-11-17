-- Titles (client): every player's overhead nameplate and chat color.
--  * Nameplate: the equipped title (tier color; Legendary+ shimmer, Secret cycles colors) over the player's name in the
--    game font, with a level badge. Roblox's own name tag is hidden so there is only one.
--  * Chat: messages are prefixed with the title, and the name takes the title's color (TextChatService).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Modules.Rarity)

local Titles = {}
local shown = {} -- player -> { gui, key, head, grad }
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local EDGE = Color3.fromRGB(24, 20, 36)

-- a title's color (and whether it shimmers / cycles)
function Titles.Look(tier)
	local r = Rarity.Get(tier or "Common")
	return r.color, (r.rank or 1) >= 5, tier == "Secret"
end

local function make(pl, head)
	local title, tier = pl:GetAttribute("Title"), pl:GetAttribute("TitleRarity")
	local bb = Instance.new("BillboardGui")
	bb.Name = "GV_Nameplate"
	bb.Size = UDim2.fromOffset(260, title and 64 or 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	bb.Adornee = head
	local grad
	if title then
		local color, shimmer = Titles.Look(tier)
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 26)
		t.FontFace = FONT
		t.TextSize = 20
		t.Text = title
		t.TextColor3 = shimmer and Color3.new(1, 1, 1) or color
		t.Parent = bb
		local st = Instance.new("UIStroke")
		st.Color = EDGE
		st.Thickness = 2
		st.Parent = t
		if shimmer then
			grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.65)), ColorSequenceKeypoint.new(1, color) })
			grad.Parent = t
		end
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, title and 26 or 0)
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = bb
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 5)
	list.Parent = row
	local lv = pl:GetAttribute("Level")
	if lv then
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.fromOffset(0, 20)
		badge.AutomaticSize = Enum.AutomaticSize.X
		badge.BackgroundColor3 = EDGE
		badge.BackgroundTransparency = 0.25
		badge.FontFace = FONT
		badge.TextSize = 14
		badge.TextColor3 = Color3.fromRGB(255, 214, 90)
		badge.Text = " Lv." .. lv .. " "
		badge.Parent = row
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = badge
	end
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromOffset(0, 32)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.FontFace = FONT
	name.TextSize = 26
	name.Text = pl.DisplayName
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = row
	local ns = Instance.new("UIStroke")
	ns.Color = EDGE
	ns.Thickness = 2.5
	ns.Parent = name
	bb.Parent = head
	return bb, grad
end

local function keyOf(pl)
	return tostring(pl:GetAttribute("Title")) .. "|" .. tostring(pl:GetAttribute("TitleRarity")) .. "|" .. tostring(pl:GetAttribute("Level"))
end

function Titles.Start()
	-- chat: title prefix + name in the title's color
	pcall(function()
		TextChatService.OnIncomingMessage = function(message)
			local props = Instance.new("TextChatMessageProperties")
			local src = message.TextSource
			local pl = src and Players:GetPlayerByUserId(src.UserId)
			if pl then
				local title, tier = pl:GetAttribute("Title"), pl:GetAttribute("TitleRarity")
				if title then
					local color = Titles.Look(tier)
					local hex = color:ToHex()
					props.PrefixText = string.format('<font color="#%s">[%s]</font> <font color="#%s">%s</font>', hex, title, hex, message.PrefixText)
				end
			end
			return props
		end
	end)

	local acc, t = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		-- shimmer: slide the highlight across Legendary+ titles; Secret cycles through colors
		for pl, cur in pairs(shown) do
			if cur.grad then
				cur.grad.Offset = Vector2.new(math.sin(t * 1.6) * 0.7, 0)
				if pl:GetAttribute("TitleRarity") == "Secret" then
					local c = Color3.fromHSV((t * 0.15) % 1, 0.65, 1)
					cur.grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, c) })
				end
			end
		end
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local head = char and char:FindFirstChild("Head")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- ours replaces Roblox's name tag
			end
			local cur = shown[pl]
			local key = keyOf(pl)
			if cur and (cur.key ~= key or not cur.gui.Parent or cur.head ~= head) then
				cur.gui:Destroy()
				shown[pl] = nil
				cur = nil
			end
			if head and not cur then
				local gui, grad = make(pl, head)
				shown[pl] = { gui = gui, key = key, head = head, grad = grad }
			end
		end
		for pl, cur in pairs(shown) do
			if not pl.Parent then
				cur.gui:Destroy()
				shown[pl] = nil
			end
		end
	end)
end

return Titles
