-- Menu (v0.24.0, owner): the title screen you see before playing.
--  * Title: GRAND VOYAGE logo, PLAY (enters the game with the selected character slot) and CHARACTER.
--  * Character: the account's character slots (Config/Looks.Slots) as cards with a live voxel preview. Pick one to
--    open the creator.
--  * Creator: hair / eyes / mouth / shirt / pants / shoes / skin steppers, color targets + palette, Heritage spin
--    (rolled by the server), a dice for a random look, DONE saves the slot.
-- The scene is a small voxel pier built on the client off Daybreak's west shore; the camera is scripted while the
-- menu is open. Every other ScreenGui is hidden until Play. Music: the jazz track (Audio.SetMenuMusic).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local VoxelChar = require(ReplicatedStorage.Shared.Modules.VoxelChar)
local UI = require(script.Parent.UIKit)
local Audio = require(script.Parent.Parent.Controllers.Audio)

local Menu = {}
local player = Players.LocalPlayer
local New = UI.New
local T = UI.Theme
local F = UI.Fonts

Menu.IsOpen = false
local gui, scaleObj, screens = nil, nil, {}
local hidden = {} -- ScreenGui -> Enabled it wants once the menu closes
local hideConns = {}
local slots = {} -- [i] = summary | false
local bankSpins = 0 -- bought spins on the account (any slot can use them)
local current = 1 -- selected slot
local editing -- { slot, look, heritage, spins }
local stage, preview, previewKey
local yaw = 0
local camMode = "title"
local camConn
local blur
local dragging, lastDrag = false, 0

-- the pier sits off Daybreak's west shore, looking east at the island
local STAGE_CF = CFrame.new(-430, 3.2, 26) * CFrame.Angles(0, math.pi / 2, 0)

local PIXEL = {
	panel = Color3.fromRGB(20, 22, 38),
	panelHi = Color3.fromRGB(34, 38, 62),
	edge = Color3.fromRGB(8, 8, 16),
	line = Color3.fromRGB(120, 130, 190),
	cream = Color3.fromRGB(246, 236, 206),
	gold = Color3.fromRGB(255, 206, 70),
	green = Color3.fromRGB(150, 236, 120),
}

-- ===== pixel widgets =====
local function pixelFrame(parent, props)
	local f = New("Frame", {
		BackgroundColor3 = PIXEL.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Parent = parent,
	})
	New("UIStroke", { Color = PIXEL.edge, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Miter, Parent = f })
	-- hard pixel drop shadow
	New("Frame", { Name = "PxShadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(6, 6), ZIndex = 0, Parent = f })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	return f
end

local function label(parent, text, size, color, props)
	local t = New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = F.Display,
		TextSize = size,
		TextColor3 = color or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, size + 6),
		Parent = parent,
	})
	t:SetAttribute("PxDone", true) -- sizes here are already for the pixel font
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return t
end

-- wavy rule like the reference's dividers: a row of small pixel blocks
local function rule(parent, width, color, order)
	local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 6), LayoutOrder = order or 0, Parent = parent })
	for i = 0, math.floor(width / 8) - 1 do
		New("Frame", { BackgroundColor3 = color or PIXEL.line, BorderSizePixel = 0, Size = UDim2.fromOffset(6, 3), Position = UDim2.fromOffset(i * 8, (i % 2) * 3), Parent = r })
	end
	return r
end

local function pixelButton(parent, text, color, size, onClick, props)
	color = color or PIXEL.cream
	local holder = New("Frame", { BackgroundTransparency = 1, Size = size, Parent = parent })
	New("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(4, 5), Parent = holder })
	local light = (color.R + color.G + color.B) / 3 > 0.6
	local btn = New("TextButton", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		FontFace = F.Display,
		TextSize = 16,
		TextColor3 = light and Color3.fromRGB(30, 26, 40) or Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = holder,
	})
	btn:SetAttribute("PxDone", true)
	New("UIStroke", { Color = PIXEL.edge, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	-- bevel: light top strip + dark bottom strip
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Parent = btn })
	New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), Parent = btn })
	UI.Tactile(btn)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	return btn, holder
end

-- the menu's text, one size step up from the build sizes (owner: the text looked small in the big frames)
local MENU_TEXT = 1.35
local function growText(root)
	for _, d in ipairs(root:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("MenuGrown") then
			d:SetAttribute("MenuGrown", true)
			if not d.TextScaled then
				-- grown, but fitted to its box so nothing spills over its neighbours
				local size = math.floor(d.TextSize * MENU_TEXT + 0.5)
				d.TextSize = size
				if d.AutomaticSize == Enum.AutomaticSize.None then
					local c = Instance.new("UITextSizeConstraint")
					c.MaxTextSize = size
					c.MinTextSize = 7
					c.Parent = d
					d.TextScaled = true
				end
			end
		end
	end
end

-- ===== scene =====
local function block(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = STAGE_CF * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function buildStage()
	local m = Instance.new("Model")
	m.Name = "MenuStage"
	local wood = { Color3.fromRGB(150, 98, 60), Color3.fromRGB(134, 86, 52), Color3.fromRGB(164, 110, 68) }
	-- deck: planks running across (local X), the character stands at the origin
	for i = -6, 8 do
		block(m, Vector3.new(16, 0.5, 1.6), CFrame.new(0, -0.25, i * 1.62), wood[(i % 3) + 1], Enum.Material.WoodPlanks)
	end
	-- posts down into the sea + a back rail
	for _, x in ipairs({ -7.6, 7.6 }) do
		for _, z in ipairs({ -9.5, 0, 13 }) do
			block(m, Vector3.new(1, 9, 1), CFrame.new(x, -3.8, z), Color3.fromRGB(96, 62, 40), Enum.Material.Wood)
		end
		block(m, Vector3.new(0.8, 3.2, 0.8), CFrame.new(x, 1.6, 13), Color3.fromRGB(110, 70, 44), Enum.Material.Wood)
	end
	block(m, Vector3.new(16, 0.5, 0.5), CFrame.new(0, 2.6, 13), Color3.fromRGB(120, 78, 48), Enum.Material.Wood)
	block(m, Vector3.new(16, 0.4, 0.4), CFrame.new(0, 1.4, 13), Color3.fromRGB(120, 78, 48), Enum.Material.Wood)
	-- crates + barrels on the left, rope coil + lantern on the right
	local crate = Color3.fromRGB(176, 128, 74)
	block(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(-5.2, 1.2, 9) * CFrame.Angles(0, 0.2, 0), crate, Enum.Material.WoodPlanks)
	block(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(-5.6, 1.2, 6.2) * CFrame.Angles(0, -0.1, 0), crate:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.WoodPlanks)
	block(m, Vector3.new(2, 2, 2), CFrame.new(-5.3, 3.4, 8.2) * CFrame.Angles(0, 0.5, 0), crate:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.WoodPlanks)
	for _, z in ipairs({ 2.5, 4.4 }) do
		block(m, Vector3.new(1.8, 2.2, 1.8), CFrame.new(-6.4, 1.1, z), Color3.fromRGB(124, 76, 44), Enum.Material.Wood)
		block(m, Vector3.new(1.9, 0.25, 1.9), CFrame.new(-6.4, 1.6, z), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
		block(m, Vector3.new(1.9, 0.25, 1.9), CFrame.new(-6.4, 0.5, z), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	end
	block(m, Vector3.new(2, 0.6, 2), CFrame.new(5.4, 0.3, 7), Color3.fromRGB(196, 170, 120))
	block(m, Vector3.new(1.2, 0.62, 1.2), CFrame.new(5.4, 0.32, 7), Color3.fromRGB(120, 100, 70))
	block(m, Vector3.new(0.6, 6, 0.6), CFrame.new(6.6, 3, 11), Color3.fromRGB(70, 50, 36), Enum.Material.Wood)
	block(m, Vector3.new(1.6, 0.4, 0.4), CFrame.new(6, 5.8, 11), Color3.fromRGB(70, 50, 36), Enum.Material.Wood)
	local lamp = block(m, Vector3.new(0.8, 1, 0.8), CFrame.new(5.4, 5.2, 11), Color3.fromRGB(255, 200, 110), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = lamp
	-- a small sand islet with a voxel palm behind the pier
	block(m, Vector3.new(14, 3, 12), CFrame.new(-14, -1.4, 22), Color3.fromRGB(236, 206, 140), Enum.Material.Sand)
	block(m, Vector3.new(10, 3, 8), CFrame.new(-14, -0.6, 22), Color3.fromRGB(242, 216, 154), Enum.Material.Sand)
	local trunk = Color3.fromRGB(140, 96, 60)
	for i = 0, 7 do
		block(m, Vector3.new(1.1, 1.3, 1.1), CFrame.new(-14 + i * 0.32, 1.5 + i * 1.25, 22 + i * 0.12), i % 2 == 0 and trunk or trunk:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood)
	end
	local leaf = Color3.fromRGB(70, 170, 70)
	local top = Vector3.new(-14 + 7 * 0.32, 1.5 + 8 * 1.25, 22 + 0.9)
	for k = 0, 5 do
		local a = k * math.pi / 3
		for j = 1, 4 do
			local d = j * 1.25
			block(m, Vector3.new(1.4, 0.6, 1.4), CFrame.new(top + Vector3.new(math.cos(a) * d, -j * j * 0.18, math.sin(a) * d)), j % 2 == 0 and leaf or leaf:Lerp(Color3.new(1, 1, 0.6), 0.12), Enum.Material.Grass)
		end
	end
	block(m, Vector3.new(1.6, 1.2, 1.6), CFrame.new(top), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	-- a moored voxel dinghy beside the pier
	local hull = Color3.fromRGB(120, 76, 46)
	for i, w in ipairs({ 2.4, 3.6, 4.2, 4.2, 4.2, 3.6, 2.4, 1.2 }) do
		block(m, Vector3.new(w, 1.2, 1.2), CFrame.new(12.5, -0.4, -2 + i * 1.2), hull, Enum.Material.WoodPlanks)
		block(m, Vector3.new(math.max(0.6, w - 1), 0.4, 1.2), CFrame.new(12.5, -1.2, -2 + i * 1.2), hull:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.WoodPlanks)
	end
	block(m, Vector3.new(3.6, 0.3, 1), CFrame.new(12.5, 0, 3.2), Color3.fromRGB(176, 128, 74), Enum.Material.WoodPlanks)
	m.Parent = workspace
	return m
end

local function lookKey(look, heritage, variant)
	local parts = { heritage or "", tostring(variant or 1) }
	for _, k in ipairs({ "hair", "eyes", "mouth", "shirt", "pants", "shoes" }) do
		table.insert(parts, tostring(look[k]))
	end
	for _, k in ipairs(Looks.ColorKeys) do
		table.insert(parts, tostring(look[k]))
	end
	return table.concat(parts, ",")
end

local function showPreview(look, heritage, variant)
	local key = lookKey(look, heritage, variant)
	if preview and previewKey == key then
		return
	end
	if preview then
		preview:Destroy()
	end
	previewKey = key
	preview = VoxelChar.Preview(look, heritage, variant)
	preview.Parent = stage or workspace
end

local function selectedLook()
	if editing then
		return editing.look, editing.heritage, editing.variant
	end
	local s = slots[current]
	if s then
		return s.look, s.heritage, s.variant
	end
	return Looks.Default(), nil, 1
end

local function heritageLabel(id, variant)
	local h = Looks.HeritageById[id or "Islander"]
	local v = Looks.Variant(id, variant)
	if not h then
		return "?"
	end
	if v and v.name ~= h.name then
		return string.upper(h.name) .. " (" .. string.upper(v.name) .. ")"
	end
	return string.upper(h.name)
end

-- ===== camera =====
local CAMS = {
	title = { pos = Vector3.new(4.5, 5.2, -17), at = Vector3.new(1.2, 4.2, 0), fov = 50 },
	slots = { pos = Vector3.new(0, 7, -22), at = Vector3.new(0, 5.5, 0), fov = 50 },
	edit = { pos = Vector3.new(0.4, 4.4, -10.5), at = Vector3.new(0.4, 3.6, 0), fov = 42 },
}
local camPos, camAt
-- creator camera: free orbit around the character (drag = turn around it / look up-down, wheel or pinch = zoom)
local orbit = { yaw = 0, pitch = 0.12, dist = 10.5 }
local ORBIT_AT = Vector3.new(0, 3.4, 0)
local function stepCamera(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local c = CAMS[camMode] or CAMS.title
	local t = os.clock()
	local sway = Vector3.new(math.sin(t * 0.25) * 0.5, math.sin(t * 0.33) * 0.25, 0)
	local wantPos = STAGE_CF:PointToWorldSpace(c.pos + sway)
	local wantAt = STAGE_CF:PointToWorldSpace(c.at)
	if camMode == "edit" then
		local cp = math.cos(orbit.pitch)
		local off = Vector3.new(math.sin(orbit.yaw) * cp, math.sin(orbit.pitch), -math.cos(orbit.yaw) * cp) * orbit.dist
		-- the character sits a little right of the screen center so the left panel never covers it
		wantAt = STAGE_CF:PointToWorldSpace(ORBIT_AT)
		wantPos = STAGE_CF:PointToWorldSpace(ORBIT_AT + off)
	end
	local k = 1 - math.exp(-dt * (camMode == "edit" and 12 or 4))
	camPos = camPos and camPos:Lerp(wantPos, k) or wantPos
	camAt = camAt and camAt:Lerp(wantAt, k) or wantAt
	cam.CFrame = CFrame.lookAt(camPos, camAt)
	cam.FieldOfView += (c.fov - cam.FieldOfView) * k
	if preview then
		local bob = math.sin(t * 2.2) * 0.04
		preview:PivotTo(STAGE_CF * CFrame.new(0, bob, 0) * CFrame.Angles(0, camMode == "edit" and 0 or yaw, 0))
	end
	if not dragging then
		-- drift back to facing the camera after a turn
		if math.abs(yaw) > 0.001 and os.clock() - (lastDrag or 0) > 2.5 then
			yaw *= math.exp(-dt * 1.5)
		end
	end
end

-- ===== GUI hiding while the menu is open =====
local function hideOtherGuis()
	local pg = player:WaitForChild("PlayerGui")
	local function hide(g)
		if g == gui or not g:IsA("ScreenGui") or hidden[g] ~= nil or g:GetAttribute("MenuKeep") then
			return
		end
		hidden[g] = g.Enabled
		g.Enabled = false
		table.insert(hideConns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if Menu.IsOpen and g.Enabled then
				hidden[g] = true
				g.Enabled = false
			end
		end))
	end
	for _, g in ipairs(pg:GetChildren()) do
		hide(g)
	end
	table.insert(hideConns, pg.ChildAdded:Connect(function(g)
		if Menu.IsOpen then
			task.defer(hide, g)
		end
	end))
end

local function restoreGuis()
	for _, c in ipairs(hideConns) do
		c:Disconnect()
	end
	hideConns = {}
	for g, was in pairs(hidden) do
		if g.Parent then
			g.Enabled = was
		end
	end
	hidden = {}
end

-- ===== screens =====
local function show(name)
	for n, f in pairs(screens) do
		f.Visible = n == name
	end
	camMode = (name == "edit" and "edit") or (name == "slots" and "slots") or "title"
	if name == "title" then
		editing = nil
	end
	local look, her, var = selectedLook()
	showPreview(look, her, var)
end

local refreshTitle, refreshSlots, refreshEdit

local function slotLine(i)
	local s = slots[i]
	if not s then
		return "SLOT " .. i .. "  -  NEW CHARACTER"
	end
	local cls = Classes.Classes[s.class]
	return string.format("SLOT %d  -  LV.%d %s", i, s.level, string.upper(cls and cls.name or s.class))
end

local function buildTitle()
	local f = New("Frame", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	screens.title = f
	-- logo: GRAND / VOYAGE in chunky pixel letters with a hard shadow
	local logo = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(760, 170), Parent = f })
	for i, word in ipairs({ "GRAND", "VOYAGE" }) do
		local size = i == 1 and 64 or 52
		local y = i == 1 and 0 or 78
		label(logo, word, size, Color3.fromRGB(10, 14, 40), { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, y + 6), Size = UDim2.new(1, 0, 0, size + 8) })
		local t = label(logo, word, size, i == 1 and PIXEL.cream or PIXEL.gold, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, size + 8) })
		New("UIStroke", { Color = PIXEL.edge, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Miter, Parent = t })
	end
	label(logo, string.upper(GameConfig.SagaName), 14, Color3.fromRGB(190, 220, 255), { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 20) })

	local col = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Size = UDim2.fromOffset(300, 220), Parent = f })
	UI.List(col, Enum.FillDirection.Vertical, 16, Enum.HorizontalAlignment.Center)
	local play = pixelButton(col, "PLAY", PIXEL.cream, UDim2.fromOffset(260, 58), function()
		Menu.Play()
	end, { LayoutOrder = 1 })
	play.TextSize = 24
	local slotText = label(col, "", 11, Color3.fromRGB(210, 220, 240), { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16) })
	pixelButton(col, "CHARACTER", PIXEL.panelHi, UDim2.fromOffset(260, 50), function()
		show("slots")
		refreshSlots()
	end, { LayoutOrder = 3 })
	-- corner notes like the reference: version + what's new
	local notes = pixelFrame(f, { BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(340, 120) })
	New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), Parent = notes })
	notes.PxShadow:Destroy() -- (a list layout would place it as an item)
	notes.Position = UDim2.new(0, 24, 1, -24)
	UI.List(notes, Enum.FillDirection.Vertical, 6)
	label(notes, "UPDATE LOG", 12, PIXEL.gold, { LayoutOrder = 1 })
	rule(notes, 160, PIXEL.line, 2)
	label(notes, "VERSION " .. GameConfig.Version, 11, PIXEL.cream, { LayoutOrder = 3 })
	label(notes, "Voxel world, character slots and a character creator!", 9, Color3.fromRGB(180, 190, 220), { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26) })
	refreshTitle = function()
		slotText.Text = slotLine(current)
	end
end

local function buildSlots()
	local f = New("Frame", { Name = "Slots", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })
	screens.slots = f
	label(f, "CHARACTERS", 30, PIXEL.cream, { TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(600, 40) })
	label(f, "Pick a slot to play or to edit its look", 11, Color3.fromRGB(190, 200, 230), { TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(600, 18) })
	local row = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(Looks.Slots * 250, 380), Parent = f })
	UI.List(row, Enum.FillDirection.Horizontal, 24, Enum.HorizontalAlignment.Center)
	local cards = {}
	for i = 1, Looks.Slots do
		local card = pixelFrame(row, { Size = UDim2.fromOffset(220, 370), LayoutOrder = i })
		local title = label(card, "SLOT " .. i, 14, PIXEL.gold, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 20) })
		local vp = New("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(40, 70, 110), BorderSizePixel = 0, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 200), Ambient = Color3.fromRGB(170, 170, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = card })
		New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 180, 240), Color3.fromRGB(40, 60, 110)), Rotation = 90, Parent = vp })
		local info = label(card, "", 10, Color3.fromRGB(220, 226, 246), { Position = UDim2.fromOffset(14, 248), Size = UDim2.new(1, -28, 0, 40) })
		local btns = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 1, -66), Size = UDim2.new(1, -28, 0, 52), Parent = card })
		UI.List(btns, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
		local playBtn = pixelButton(btns, "PLAY", PIXEL.green, UDim2.fromOffset(90, 44), function()
			current = i
			Menu.Play()
		end, { LayoutOrder = 1 })
		local editBtn = pixelButton(btns, "EDIT", PIXEL.cream, UDim2.fromOffset(90, 44), function()
			Menu.Edit(i)
		end, { LayoutOrder = 2 })
		cards[i] = { title = title, vp = vp, info = info, play = playBtn, edit = editBtn, card = card }
	end
	pixelButton(f, "BACK", PIXEL.cream, UDim2.fromOffset(200, 46), function()
		show("title")
		refreshTitle()
	end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40) })
	refreshSlots = function()
		for i, c in ipairs(cards) do
			local s = slots[i]
			c.vp:ClearAllChildren()
			local look = s and s.look or Looks.Default()
			local model = VoxelChar.Preview(look, s and s.heritage, s and s.variant)
			model.Parent = c.vp
			model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.4, -13.5), Vector3.new(0, 3.3, 0))
			cam.Parent = c.vp
			c.vp.CurrentCamera = cam
			if s then
				local cls = Classes.Classes[s.class]
				c.info.Text = string.format("LV.%d  %s\n%s", s.level, string.upper(cls and cls.name or s.class), heritageLabel(s.heritage, s.variant))
				c.play.Text = "PLAY"
				c.edit.Text = "EDIT"
			else
				c.info.Text = "EMPTY SLOT\nCreate a new pirate"
				c.play.Text = "PLAY"
				c.edit.Text = "CREATE"
				local faces = {}
				for _, p in ipairs(model:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Color = Color3.fromRGB(30, 40, 70)
					elseif p:IsA("Decal") then
						table.insert(faces, p)
					end
				end
				for _, sg in ipairs(faces) do
					sg:Destroy()
				end
			end
			c.title.TextColor3 = (i == current) and PIXEL.green or PIXEL.gold
			c.title.Text = (i == current) and ("SLOT " .. i .. "  <") or ("SLOT " .. i)
		end
	end
end

-- ===== creator =====
local GuiService = game:GetService("GuiService")
local okUI, UIImages = pcall(require, ReplicatedStorage.Shared.Config.UIImages)
UIImages = okUI and UIImages or {}

local function buildEdit()
	local f = New("Frame", { Name = "Edit", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })
	screens.edit = f
	local category = "hair"
	local target = "hair1"

	-- ===== left: styles + heritage =====
	-- dark backing plates so the text reads over the 3D scene
	pixelFrame(f, { Position = UDim2.fromOffset(16, 28), Size = UDim2.fromOffset(404, 690), BackgroundTransparency = 0.3, ZIndex = 0 })
	pixelFrame(f, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 28), Size = UDim2.fromOffset(354, 620), BackgroundTransparency = 0.3, ZIndex = 0 })
	local left = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 40), Size = UDim2.fromOffset(380, 760), Parent = f })
	UI.List(left, Enum.FillDirection.Vertical, 6)
	label(left, "CUSTOMIZE", 24, PIXEL.cream, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30) })
	label(left, "Drag to look around, wheel / pinch to zoom", 9, Color3.fromRGB(190, 200, 230), { LayoutOrder = 2 })
	rule(left, 340, PIXEL.line, 3)
	local rows = {}
	for i, cat in ipairs(Looks.Categories) do
		local row = pixelFrame(left, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 10 + i, BackgroundColor3 = PIXEL.panelHi })
		local pick = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(0, 96, 1, 0), Parent = row })
		local name = label(row, cat.label, 11, PIXEL.cream, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 90, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
		local value = label(row, "", 9, PIXEL.gold, { Position = UDim2.fromOffset(134, 0), Size = UDim2.new(0, 196, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false })
		value:SetAttribute("MenuGrown", true)
		value.TextScaled = true
		New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7, Parent = value })
		local function choose()
			category = cat.key
			target = cat.colors[1] or target
			refreshEdit()
		end
		pick.Activated:Connect(choose)
		if cat.list then
			local function bump(d)
				if not editing then
					return
				end
				local max = #cat.list
				editing.look[cat.key] = ((editing.look[cat.key] - 1 + d) % max) + 1
				category = cat.key
				target = cat.colors[1] or target
				refreshEdit()
			end
			pixelButton(row, "<", PIXEL.cream, UDim2.fromOffset(26, 24), function()
				bump(-1)
			end, { Position = UDim2.new(0, 100, 0.5, -12) })
			pixelButton(row, ">", PIXEL.cream, UDim2.fromOffset(26, 24), function()
				bump(1)
			end, { Position = UDim2.new(1, -34, 0.5, -12) })
		else
			local b = pixelButton(row, "PICK COLOR", PIXEL.cream, UDim2.fromOffset(196, 24), choose, { Position = UDim2.new(0, 134, 0.5, -12) })
			b.TextSize = 9
			value.Visible = false
		end
		rows[cat.key] = { frame = row, name = name, value = value, cat = cat }
	end
	rule(left, 340, PIXEL.line, 30)
	-- heritage
	label(left, "HERITAGE", 14, PIXEL.cream, { LayoutOrder = 31, Size = UDim2.new(1, 0, 0, 18) })
	local chances = New("Frame", { BackgroundTransparency = 1, LayoutOrder = 32, Size = UDim2.new(1, 0, 0, 44), Parent = left })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(186, 14), CellPadding = UDim2.fromOffset(4, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chances })
	for i, h in ipairs(Looks.Heritages) do
		label(chances, string.format("%s %s%%", string.upper(h.name), tostring(h.chance)), 8, h.color, { LayoutOrder = i })
	end
	local herRow = pixelFrame(left, { LayoutOrder = 33, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = PIXEL.panelHi })
	local herName = label(herRow, "", 11, PIXEL.gold, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16) })
	local herPerk = label(herRow, "", 8, Color3.fromRGB(200, 210, 236), { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 34) })
	local spinRow = New("Frame", { BackgroundTransparency = 1, LayoutOrder = 34, Size = UDim2.new(1, 0, 0, 40), Parent = left })
	UI.List(spinRow, Enum.FillDirection.Horizontal, 10)
	local spinBtn = pixelButton(spinRow, "SPIN", PIXEL.cream, UDim2.fromOffset(120, 38), function()
		Menu.Spin()
	end, { LayoutOrder = 1 })
	local spinsText = label(spinRow, "", 11, PIXEL.cream, { LayoutOrder = 2, Size = UDim2.fromOffset(170, 38), TextYAlignment = Enum.TextYAlignment.Center })
	local plus = pixelButton(spinRow, "+", PIXEL.green, UDim2.fromOffset(38, 38), function()
		Menu.BuySpins()
	end, { LayoutOrder = 3 })
	plus.TextSize = 20
	pixelButton(left, "RANDOM LOOK", PIXEL.panelHi, UDim2.fromOffset(200, 34), function()
		if editing then
			editing.look = Looks.Random()
			refreshEdit()
		end
	end, { LayoutOrder = 40 })

	-- ===== right: color picker (targets, wheel, brightness, presets) =====
	local right = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 40), Size = UDim2.fromOffset(330, 760), Parent = f })
	UI.List(right, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	local colorTitle = label(right, "COLOR", 18, PIXEL.cream, { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 24) })
	local targets = New("Frame", { BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.fromOffset(330, 34), Parent = right })
	UI.List(targets, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	local targetBtns = {}
	for i, label_ in ipairs({ "COLOR 1", "COLOR 2" }) do
		local b = pixelButton(targets, label_, PIXEL.panelHi, UDim2.fromOffset(120, 32), function()
			local cat
			for _, c in ipairs(Looks.Categories) do
				if c.key == category then
					cat = c
				end
			end
			if cat and cat.colors[i] then
				target = cat.colors[i]
				refreshEdit()
			end
		end, { LayoutOrder = i })
		b.TextSize = 10
		targetBtns[i] = b
	end
	local panel = pixelFrame(right, { LayoutOrder = 3, Size = UDim2.fromOffset(330, 470), BackgroundColor3 = Color3.fromRGB(10, 10, 16) })
	local wheel = New("ImageButton", { Image = UIImages.colorwheel or "", BackgroundTransparency = 1, AutoButtonColor = false, Position = UDim2.fromOffset(35, 18), Size = UDim2.fromOffset(260, 260), Parent = panel })
	local wheelDim = New("ImageLabel", { Image = UIImages.colorwheel or "", BackgroundTransparency = 1, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = wheel })
	local marker = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Parent = wheel })
	New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Parent = marker })
	local slider = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(25, 298), Size = UDim2.fromOffset(280, 14), Parent = panel })
	local sliderGrad = New("UIGradient", { Parent = slider })
	local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(16, 22), Position = UDim2.fromScale(1, 0.5), Parent = slider })
	New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = knob })
	local hexText = label(panel, "", 10, PIXEL.cream, { Position = UDim2.fromOffset(25, 320), Size = UDim2.fromOffset(280, 16), TextXAlignment = Enum.TextXAlignment.Center })
	local lockNote = label(panel, "", 9, Color3.fromRGB(255, 160, 90), { Position = UDim2.fromOffset(14, 120), Size = UDim2.fromOffset(302, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Visible = false })
	local presets = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 346), Size = UDim2.fromOffset(300, 116), Parent = panel })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(42, 26), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = presets })

	local hsv = { 0, 0, 1 }
	local function locked()
		local h = editing and Looks.HeritageById[editing.heritage or ""]
		return h and h.lock and h.lock[target] ~= nil
	end
	local function applyColor()
		if not editing or locked() then
			return
		end
		editing.look[target] = Looks.Hex(Color3.fromHSV(hsv[1], hsv[2], hsv[3]))
		Audio.Play("BlkTick", { volume = 0.5, pitch = 0.7 + hsv[3] * 0.6 })
		refreshEdit()
	end
	local function setPresetList(list)
		for _, c in ipairs(presets:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, hex in ipairs(list) do
			local col = Looks.FromHex(hex)
			local sw = New("TextButton", { Text = "", BackgroundColor3 = col, BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i, Parent = presets })
			New("UIStroke", { Color = PIXEL.edge, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = sw })
			UI.Tactile(sw, true)
			sw.Activated:Connect(function()
				if editing and not locked() then
					Audio.Play("BlkDrop", { volume = 0.6 })
					editing.look[target] = hex
					hsv = { col:ToHSV() }
					refreshEdit()
				end
			end)
		end
	end
	local presetKind
	local function screenPoint(input)
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	local dragWheel, dragSlider = false, false
	local function pickWheel(input)
		local c = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local d = (screenPoint(input) - c) / (wheel.AbsoluteSize.X / 2)
		local r = math.min(1, d.Magnitude)
		hsv[1] = (math.atan2(-d.Y, d.X) / (2 * math.pi)) % 1
		hsv[2] = r
		if hsv[3] < 0.08 then
			hsv[3] = 1
		end
		applyColor()
	end
	local function pickSlider(input)
		local x = (screenPoint(input).X - slider.AbsolutePosition.X) / math.max(1, slider.AbsoluteSize.X)
		hsv[3] = math.clamp(x, 0, 1)
		applyColor()
	end
	wheel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragWheel = true
			pickWheel(input)
		end
	end)
	slider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragSlider = true
			pickSlider(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if dragWheel then
			pickWheel(input)
		elseif dragSlider then
			pickSlider(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragWheel, dragSlider = false, false
		end
	end)

	-- bottom: back / done
	local bottom = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(440, 56), Parent = f })
	UI.List(bottom, Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center)
	pixelButton(bottom, "BACK", PIXEL.panelHi, UDim2.fromOffset(150, 48), function()
		show("slots")
		refreshSlots()
	end, { LayoutOrder = 1 })
	local doneBtn = pixelButton(bottom, "DONE", PIXEL.cream, UDim2.fromOffset(200, 52), function()
		Menu.Done()
	end, { LayoutOrder = 2 })
	doneBtn.TextSize = 20

	local lastTarget
	refreshEdit = function()
		if not editing then
			return
		end
		local look = editing.look
		local catDef
		for key, r in pairs(rows) do
			local on = key == category
			r.frame.BackgroundColor3 = on and Color3.fromRGB(70, 60, 120) or PIXEL.panelHi
			r.name.TextColor3 = on and PIXEL.gold or PIXEL.cream
			if r.cat.list then
				local n = look[key]
				r.value.Text = string.format("%s %d/%d", string.upper(r.cat.list[n] or "?"), n, #r.cat.list)
			end
			if on then
				catDef = r.cat
			end
		end
		-- heritage box
		local h = Looks.HeritageById[editing.heritage or "Islander"]
		herName.Text = "YOU'RE " .. heritageLabel(editing.heritage, editing.variant) .. "!"
		herName.TextColor3 = h and h.color or PIXEL.gold
		herPerk.Text = h and (h.perk .. ". " .. h.desc) or ""
		local total = (editing.spins or 0) + bankSpins
		spinsText.Text = string.format("%d SPINS LEFT", total)
		spinBtn.Text = total > 0 and "SPIN" or "NO SPINS"
		-- color targets for this category
		local colors = catDef and catDef.colors or {}
		colorTitle.Text = (catDef and catDef.label or "") .. " COLOR"
		for i, b in ipairs(targetBtns) do
			local key = colors[i]
			b.Parent.Visible = key ~= nil
			if key then
				b.Text = key == "skin" and "SKIN" or ("COLOR " .. i)
				local on = key == target
				b.BackgroundColor3 = on and PIXEL.cream or PIXEL.panelHi
				b.TextColor3 = on and Color3.fromRGB(30, 26, 40) or Color3.new(1, 1, 1)
			end
		end
		local hasColor = #colors > 0
		panel.Visible = hasColor
		if hasColor and not table.find(colors, target) then
			target = colors[1]
		end
		if hasColor then
			local col = Looks.Color(look, target)
			if target ~= lastTarget then
				hsv = { col:ToHSV() }
				lastTarget = target
			end
			local a = hsv[1] * 2 * math.pi
			marker.Position = UDim2.fromScale(0.5 + math.cos(a) * hsv[2] * 0.5, 0.5 - math.sin(a) * hsv[2] * 0.5)
			marker.BackgroundColor3 = col
			marker.BackgroundTransparency = 0
			wheelDim.ImageTransparency = hsv[3]
			sliderGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(hsv[1], hsv[2], 1))
			knob.Position = UDim2.fromScale(hsv[3], 0.5)
			hexText.Text = "#" .. Looks.Hex(col)
			local kind = target == "skin" and "skin" or "colors"
			if kind ~= presetKind then
				presetKind = kind
				setPresetList(kind == "skin" and Looks.SkinPresets or Looks.Presets)
			end
			local isLocked = locked() == true
			lockNote.Visible = isLocked
			lockNote.Text = isLocked and (string.upper(h.name) .. " LOOK IS LOCKED") or ""
			wheel.ImageTransparency = isLocked and 0.8 or 0
		end
		showPreview(editing.look, editing.heritage, editing.variant)
	end
end

-- ===== actions =====
function Menu.Edit(i)
	current = i
	local s = slots[i]
	editing = {
		slot = i,
		look = s and table.clone(s.look) or Looks.Random(),
		heritage = s and s.heritage or "Islander",
		variant = s and s.variant or 1,
		spins = s and s.spins or Looks.Spins,
	}
	yaw = 0
	orbit.yaw, orbit.pitch, orbit.dist = 0, 0.12, 10.5
	show("edit")
	refreshEdit()
end

local spinning = false
function Menu.Spin()
	if not editing or spinning then
		return
	end
	if (editing.spins or 0) + bankSpins <= 0 then
		UI.Toast("No spins left: tap + to get more", "bad")
		Menu.BuySpins()
		return
	end
	spinning = true
	local res = Net.Request("MenuSpin", { slot = editing.slot, look = editing.look })
	if not res.ok then
		spinning = false
		UI.Toast(res.msg or "Spin failed", "bad")
		return
	end
	local final, finalVariant = res.data.heritage, res.data.variant
	-- quick roulette through the names, landing on the server's roll
	task.spawn(function()
		local steps = 14
		for k = 1, steps do
			editing.heritage = Looks.Heritages[(k % (#Looks.Heritages - 1)) + 1].id
			editing.variant = 1
			refreshEdit()
			Audio.Play("BlkTick", { pitch = 0.8 + k * 0.04 })
			task.wait(0.04 + k * 0.012)
		end
		editing.heritage = final
		editing.variant = finalVariant or 1
		editing.spins = res.data.summary.spins
		bankSpins = res.data.bank or bankSpins
		slots[editing.slot] = res.data.summary
		refreshEdit()
		local h = Looks.HeritageById[final]
		Audio.Play((h and h.chance <= 2) and "LevelUp" or "BlkReward")
		UI.Toast("You're " .. heritageLabel(final, finalVariant) .. "!", "good")
		if h and h.chance <= 2 then
			UI.Banner(string.upper(h.name) .. "!", h.chance .. "% heritage  •  " .. h.perk, h.color, h.mythic and "Mythic" or "Legendary")
		end
		spinning = false
	end)
end

-- BUY SPINS (Config/Spins developer products; the server grants them to the account spin bank)
local MarketplaceService = game:GetService("MarketplaceService")
local SpinsCfg = require(ReplicatedStorage.Shared.Config.Spins)
local buyFrame
function Menu.BuySpins()
	if buyFrame and buyFrame.Parent then
		buyFrame.Visible = true
		return
	end
	buyFrame = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1, -1), ZIndex = 40, Parent = gui })
	local box = pixelFrame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 420), ZIndex = 41 })
	box.Parent = buyFrame
	box.Position = UDim2.new(0.375, 0, 0.375, 0)
	local col = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), ZIndex = 42, Parent = box })
	UI.List(col, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	label(col, "BUY SPINS", 22, PIXEL.cream, { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 28), ZIndex = 42 })
	label(col, "Heritage spins for every character!", 9, PIXEL.gold, { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), ZIndex = 42 })
	rule(col, 300, PIXEL.line, 3)
	for i, pack in ipairs(SpinsCfg.Products) do
		local b = pixelButton(col, string.format("%s  -  R$ %d", pack.name, pack.robux), PIXEL.green, UDim2.fromOffset(320, 42), function()
			if not pack.productId or pack.productId == 0 then
				UI.Toast("Spin packs are coming soon!", "info")
				return
			end
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, pack.productId)
			end)
		end, { LayoutOrder = 10 + i })
		b.TextSize = 13
	end
	pixelButton(col, "BACK", PIXEL.cream, UDim2.fromOffset(180, 42), function()
		buyFrame.Visible = false
	end, { LayoutOrder = 30 })
	for _, d in ipairs(buyFrame:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 41)
		end
	end
	growText(buyFrame)
end

function Menu.Done()
	if not editing then
		return
	end
	local res = Net.Request("MenuSaveLook", { slot = editing.slot, look = editing.look })
	if not res.ok then
		UI.Toast(res.msg or "Save failed", "bad")
		return
	end
	slots[editing.slot] = res.data
	current = editing.slot
	editing = nil
	show("title")
	refreshTitle()
	UI.Toast("Character saved", "good")
end

local playing = false
local fade
function Menu.Play()
	if playing then
		return
	end
	playing = true
	local res = Net.Request("MenuPlay", { slot = current })
	if not res.ok then
		playing = false
		UI.Toast(res.msg or "Could not start", "bad")
		return
	end
	UI.Tween(fade, 0.35, { BackgroundTransparency = 0 })
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.6) -- let the server teleport + dress the character
		Menu.Close()
	end)
end

function Menu.Close()
	if not Menu.IsOpen then
		return
	end
	Menu.IsOpen = false
	playing = false
	editing = nil
	if Menu.menuButton then
		Menu.menuButton.Enabled = true
	end
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	if hum then
		cam.CameraSubject = hum
	end
	if stage then
		stage:Destroy()
		stage, preview = nil, nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
	for _, f in pairs(screens) do
		f.Visible = false
	end
	restoreGuis()
	Audio.SetMenuMusic(nil, 2.5)
	UI.Tween(fade, 0.6, { BackgroundTransparency = 1 }).Completed:Connect(function()
		gui:Destroy()
	end)
	if Menu.OnPlay then
		task.spawn(Menu.OnPlay)
	end
end

-- drag to turn the character
local function hookDrag()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not Menu.IsOpen then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton2 or ((t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and not processed) then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging or not Menu.IsOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if camMode == "edit" then
				orbit.yaw -= input.Delta.X * 0.01
				orbit.pitch = math.clamp(orbit.pitch + input.Delta.Y * 0.008, -0.35, 1.25)
			else
				yaw += input.Delta.X * 0.012
			end
			lastDrag = os.clock()
		end
	end)
	-- zoom (creator): mouse wheel and pinch
	UserInputService.InputChanged:Connect(function(input, processed)
		if Menu.IsOpen and camMode == "edit" and input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			orbit.dist = math.clamp(orbit.dist - input.Position.Z * 1.2, 4, 22)
		end
	end)
	local pinch = UserInputService.TouchPinch
	if not pinch then
		return
	end
	pinch:Connect(function(_, scale, _, state)
		if Menu.IsOpen and camMode == "edit" and state == Enum.UserInputState.Change then
			orbit.dist = math.clamp(orbit.dist / math.max(0.5, scale ^ 0.08), 4, 22)
		end
	end)
end

local setupDone = false
function Menu.Open()
	if Menu.IsOpen or not GameConfig.TitleMenu then
		return
	end
	Menu.IsOpen = true
	screens = {}
	camPos, camAt = nil, nil
	if Menu.menuButton then
		Menu.menuButton.Enabled = false
	end
	gui = New("ScreenGui", { Name = "TitleMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	scaleObj = New("UIScale", { Parent = gui })
	local function rescale()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scaleObj.Scale = math.clamp(math.min(v.Y / 820, v.X / 1300), 0.42, 1.3)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	-- frames are laid out in "design pixels": the holder is the screen divided by the scale
	hideOtherGuis()
	fade = New("Frame", { Name = "Fade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1, -1), ZIndex = 50, Parent = gui })
	stage = buildStage()
	blur = Instance.new("DepthOfFieldEffect")
	blur.FarIntensity = 0.35
	blur.FocusDistance = 14
	blur.InFocusRadius = 12
	blur.NearIntensity = 0
	blur.Parent = Lighting
	buildTitle()
	buildSlots()
	buildEdit()
	if not setupDone then
		setupDone = true
		hookDrag()
	end
	-- design size: the screens are authored at 1300x820 and centered
	for _, f in pairs(screens) do
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(1300, 820)
	end
	local function fitScreens()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1300, 820)
		local s = scaleObj.Scale
		for _, f in pairs(screens) do
			f.Size = UDim2.fromOffset(math.max(900, v.X / s), math.max(620, v.Y / s))
		end
	end
	fitScreens()
	scaleObj:GetPropertyChangedSignal("Scale"):Connect(fitScreens)
	growText(gui)
	Audio.SetMenuMusic("MusicJazz", 2)
	camConn = RunService.RenderStepped:Connect(stepCamera)
	show("title")
	refreshTitle()
	UI.Tween(fade, 1.2, { BackgroundTransparency = 1 })
	Menu.LoadSlots()
end

-- one-time: pushes + the in-game MENU button (top-left, next to Roblox's buttons) that brings you back here
function Menu.Start()
	if not GameConfig.TitleMenu then
		return
	end
	Net.OnPush(function(kind, d)
		if kind == "SpinsBought" and type(d) == "table" then
			bankSpins = tonumber(d.bank) or bankSpins
			UI.Toast("+" .. tostring(d.spins) .. " heritage spins!", "good")
			if buyFrame then
				buyFrame.Visible = false
			end
			if editing and refreshEdit then
				refreshEdit()
			end
		end
	end)
	local btnGui = New("ScreenGui", { Name = "MenuButton", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	btnGui:SetAttribute("MenuKeep", true)
	Menu.menuButton = btnGui
	local GuiService = game:GetService("GuiService")
	local b = pixelButton(btnGui, "MENU", PIXEL.panelHi, UDim2.fromOffset(84, 34), function()
		UI.Confirm("Back to the title menu? Your progress is saved.", function()
			local res = Net.Request("MenuReturn")
			if res.ok then
				Menu.Open()
			else
				UI.Toast(res.msg or "Could not return to the menu", "bad")
			end
		end)
	end)
	b.TextSize = 14
	local function place()
		local inset = GuiService.TopbarInset
		local h = inset.Max.Y - inset.Min.Y
		h = h > 0 and h or 58
		b.Parent.Position = UDim2.fromOffset(inset.Min.X + 8, math.max(4, (h - 34) / 2))
	end
	place()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	end)
	Menu.Open()
end

-- the account's slots (title + slot cards)
function Menu.LoadSlots()
	task.spawn(function()
		local res
		for _ = 1, 5 do
			res = Net.Request("MenuSlots")
			if res.ok then
				break
			end
			task.wait(2)
		end
		if not res or not res.ok then
			UI.Toast((res and res.msg) or "Could not load your characters", "bad")
			return
		end
		slots = res.data.slots or {}
		bankSpins = res.data.bank or 0
		local best, bestT = 1, -1
		for i = 1, Looks.Slots do
			local s = slots[i]
			if s and (s.played or 0) > bestT then
				best, bestT = i, s.played or 0
			end
		end
		current = best
		if Menu.IsOpen then
			refreshTitle()
			if not editing then
				show(screens.slots.Visible and "slots" or "title")
			end
			refreshSlots()
		end
	end)
end

return Menu
