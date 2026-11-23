-- PowerBoard (v0.25.118, owner): a wooden leaderboard beside every Bounty Board NPC with the 50 strongest players in
-- this server, ranked by Power (player attribute set by PlayerService). Built locally on each client (display only),
-- two columns of 25, refreshed every few seconds; your own row is gold.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local PowerBoard = {}

local TOP, PER_COL = 50, 25
local boards = {} -- { rows = { {rank, name, power, bg} } }

local function fmt(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function build(npc)
	if npc:GetAttribute("Role") ~= "BossBoard" or npc:GetAttribute("HasPowerBoard") then
		return
	end
	local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	npc:SetAttribute("HasPowerBoard", true)
	local folder = workspace:FindFirstChild("PowerBoards") or Instance.new("Folder")
	folder.Name = "PowerBoards"
	folder.Parent = workspace
	-- to the NPC's right, facing the same way it looks; feet are 2.6 below the root
	local base = root.CFrame * CFrame.new(7.5, -2.6, 0.5)
	local W, H = 9, 11
	local function part(size, cf, color, mat)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, false, false
		p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.Wood
		p.Parent = folder
		return p
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(Vector3.new(0.6, H + 2.2, 0.6), base * CFrame.new(sx * (W / 2 + 0.2), (H + 2.2) / 2, 0.25), Color3.fromRGB(92, 60, 36))
	end
	local board = part(Vector3.new(W, H, 0.4), base * CFrame.new(0, 1.6 + H / 2, 0), Color3.fromRGB(60, 40, 28), Enum.Material.WoodPlanks)
	part(Vector3.new(W + 0.6, 0.5, 0.7), base * CFrame.new(0, 1.6 + H + 0.2, 0), Color3.fromRGB(140, 30, 40))
	part(Vector3.new(W + 0.4, 0.3, 0.6), base * CFrame.new(0, 1.45, 0), Color3.fromRGB(92, 60, 36))

	local sg = Instance.new("SurfaceGui")
	sg.Name = "PowerBoard"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.15
	sg.MaxDistance = 120
	sg.Adornee = board
	sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local px = Vector2.new(W * 60, H * 60)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(26, 22, 34)
	frame.BorderSizePixel = 0
	frame.Parent = sg
	local function label(parent, text, size, color, pos, sz, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Arcade
		t.Text = text
		t.TextSize = size
		t.TextColor3 = color
		t.TextXAlignment = align or Enum.TextXAlignment.Left
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.Position, t.Size = pos, sz
		t.Parent = parent
		return t
	end
	label(frame, "TOP 50 POWER", 34, Color3.fromRGB(255, 210, 90), UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 40), Enum.TextXAlignment.Center)
	label(frame, "STRONGEST IN THIS SERVER", 16, Color3.fromRGB(200, 190, 220), UDim2.fromOffset(0, 50), UDim2.new(1, 0, 0, 20), Enum.TextXAlignment.Center)
	local top0 = 82
	local rowH = math.floor((px.Y - top0 - 10) / PER_COL)
	local colW = math.floor((px.X - 30) / 2)
	local b = { rows = {} }
	for i = 1, TOP do
		local col = (i - 1) // PER_COL
		local r = (i - 1) % PER_COL
		local bg = Instance.new("Frame")
		bg.Position = UDim2.fromOffset(10 + col * (colW + 10), top0 + r * rowH)
		bg.Size = UDim2.fromOffset(colW, rowH - 2)
		bg.BackgroundColor3 = r % 2 == 0 and Color3.fromRGB(40, 34, 52) or Color3.fromRGB(34, 29, 45)
		bg.BorderSizePixel = 0
		bg.Visible = false
		bg.Parent = frame
		local fs = math.max(10, rowH - 8)
		local rank = label(bg, tostring(i), fs, i <= 3 and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(170, 160, 190), UDim2.fromOffset(4, 0), UDim2.new(0, 34, 1, 0))
		local name = label(bg, "", fs, Color3.new(1, 1, 1), UDim2.fromOffset(40, 0), UDim2.new(1, -120, 1, 0))
		local power = label(bg, "", fs, Color3.fromRGB(255, 120, 110), UDim2.new(1, -84, 0, 0), UDim2.new(0, 80, 1, 0), Enum.TextXAlignment.Right)
		b.rows[i] = { bg = bg, rank = rank, name = name, power = power }
	end
	table.insert(boards, b)
end

local function refresh()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local pw = pl:GetAttribute("Power")
		if type(pw) == "number" then
			table.insert(list, { pl = pl, power = pw })
		end
	end
	table.sort(list, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.pl.UserId < b.pl.UserId
	end)
	local me = Players.LocalPlayer
	for _, b in ipairs(boards) do
		for i, row in ipairs(b.rows) do
			local e = list[i]
			row.bg.Visible = e ~= nil
			if e then
				row.name.Text = e.pl.DisplayName
				row.name.TextColor3 = e.pl == me and Color3.fromRGB(255, 220, 110) or Color3.new(1, 1, 1)
				row.power.Text = fmt(e.power)
			end
		end
	end
end

function PowerBoard.Start()
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		build(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(m)
		task.defer(build, m)
	end)
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(3)
		end
	end)
end

return PowerBoard
