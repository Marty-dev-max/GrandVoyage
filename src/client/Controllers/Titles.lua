-- Titles (client): shows each player's chosen achievement title above their head, colored by rarity.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Modules.Rarity)

local Titles = {}
local shown = {} -- player -> { gui, text }

local function make(head, text, rarityId)
	local bb = Instance.new("BillboardGui")
	bb.Name = "GV_Title"
	bb.Size = UDim2.new(8, 0, 1, 0)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 90
	bb.AlwaysOnTop = false
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	t.TextScaled = true
	t.Text = "« " .. text .. " »"
	t.TextColor3 = Rarity.Get(rarityId).color
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = head
	return bb
end

function Titles.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, pl in ipairs(Players:GetPlayers()) do
			local title = pl:GetAttribute("Title")
			local head = pl.Character and pl.Character:FindFirstChild("Head")
			local cur = shown[pl]
			if cur and (cur.text ~= title or not cur.gui.Parent or cur.head ~= head) then
				cur.gui:Destroy()
				shown[pl] = nil
				cur = nil
			end
			if title and head and not cur then
				shown[pl] = { gui = make(head, title, pl:GetAttribute("TitleRarity")), text = title, head = head }
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
