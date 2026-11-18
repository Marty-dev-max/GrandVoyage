-- ShipBars (client): an HP bar over every ship at sea (owner, v0.22.4), so you can see how a cannon duel is going.
-- Reads the ship model's HP / MaxHP attributes (ShipService.setAttrs). Enemy and NPC ships always show theirs within
-- range; your own ship shows it for a while after it takes damage (the sailing HUD has the full readout).
-- Same feel as the monster bars: fast drop, a red chunk that drains after a beat, white flash + shake on hits.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ShipBars = {}
local player = Players.LocalPlayer
local SHOW_OWN_FOR = 8 -- seconds after a hit
local bars = setmetatable({}, { __mode = "k" })

local function color(r)
	if r > 0.5 then
		return Color3.fromRGB(90, 220, 110)
	elseif r > 0.25 then
		return Color3.fromRGB(255, 200, 60)
	end
	return Color3.fromRGB(255, 80, 70)
end

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end

local function corner(p)
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = p })
end

local function build(ship)
	local root = ship.PrimaryPart
	if not root then
		return nil
	end
	-- just above the mast tops (NPC ships carry a name plate at +34: stay under it)
	local cf, size = ship:GetBoundingBox()
	local above = cf.Position.Y + size.Y / 2 - root.Position.Y + 3
	if ship:GetAttribute("NPC") then
		above = math.min(above, 29)
	end
	local bb = new("BillboardGui", {
		Name = "GVShipHP",
		Size = UDim2.fromOffset(190, 26),
		StudsOffsetWorldSpace = Vector3.new(0, math.max(10, above), 0),
		MaxDistance = 650,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Adornee = root,
		Parent = root,
	})
	local back = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(30, 26, 44), BorderSizePixel = 0, Parent = bb })
	corner(back)
	new("UIStroke", { Color = Color3.fromRGB(18, 14, 28), Thickness = 2.5, Parent = back })
	local chunk = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BorderSizePixel = 0, ZIndex = 1, Parent = back })
	corner(chunk)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 110), BorderSizePixel = 0, ZIndex = 2, Parent = back })
	corner(fill)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Rotation = 90, Parent = fill })
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4, Parent = back })
	corner(flash)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Text = "",
		FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
		Parent = back,
	})
	new("UIStroke", { Color = Color3.fromRGB(18, 14, 28), Thickness = 1.5, Parent = label })
	local scale = new("UIScale", { Parent = back })
	return { bb = bb, back = back, fill = fill, chunk = chunk, flash = flash, label = label, scale = scale, ratio = nil, token = 0, hitAt = 0 }
end

local function update(ship)
	local hp, max = ship:GetAttribute("HP"), ship:GetAttribute("MaxHP")
	if not hp or not max or max <= 0 then
		return
	end
	local st = bars[ship]
	if not st or not st.bb.Parent then
		st = build(ship)
		if not st then
			return
		end
		bars[ship] = st
	end
	local ratio = math.clamp(hp / max, 0, 1)
	local own = ship:GetAttribute("OwnerId") == player.UserId
	st.label.Text = string.format("%d / %d", math.max(0, math.floor(hp)), math.floor(max))
	st.fill.BackgroundColor3 = color(ratio)
	if st.ratio and ratio < st.ratio then
		st.hitAt = os.clock()
		st.token += 1
		local token = st.token
		TweenService:Create(st.fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(ratio, 1) }):Play()
		task.delay(0.35, function()
			if st.token == token then
				TweenService:Create(st.chunk, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(ratio, 1) }):Play()
			end
		end)
		st.scale.Scale = 1 + math.min(0.3, 0.1 + (st.ratio - ratio) * 1.5)
		TweenService:Create(st.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		st.flash.BackgroundTransparency = 0.2
		TweenService:Create(st.flash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	else
		st.fill.Size = UDim2.fromScale(ratio, 1)
		st.chunk.Size = UDim2.fromScale(ratio, 1)
	end
	st.ratio = ratio
	st.bb.Enabled = not own or os.clock() - st.hitAt < SHOW_OWN_FOR
end

local function watch(ship)
	if not ship:IsA("Model") then
		return
	end
	update(ship)
	ship:GetAttributeChangedSignal("HP"):Connect(function()
		update(ship)
	end)
	ship:GetAttributeChangedSignal("MaxHP"):Connect(function()
		update(ship)
	end)
end

function ShipBars.Start()
	local folder = workspace:WaitForChild("Ships", 60)
	if not folder then
		return
	end
	for _, s in ipairs(folder:GetChildren()) do
		task.spawn(watch, s)
	end
	folder.ChildAdded:Connect(function(s)
		task.wait(0.5) -- let the parts and attributes arrive
		watch(s)
	end)
	-- hide your own ship's bar again a while after the last hit
	task.spawn(function()
		while true do
			task.wait(1)
			for ship, st in pairs(bars) do
				if ship.Parent and st.bb.Parent and ship:GetAttribute("OwnerId") == player.UserId then
					st.bb.Enabled = os.clock() - st.hitAt < SHOW_OWN_FOR
				end
			end
		end
	end)
end

return ShipBars
