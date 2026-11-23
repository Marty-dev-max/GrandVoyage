-- Builder (client): the shipyard (v0.25.93 rework, owner): full-screen free-roam building.
--   * camera flies freely around the slip: right-drag (or one-finger drag) turns, wheel / pinch zooms, WASD moves,
--     Q / E down / up. The character stays put (movement keys are sunk) and the HUD is hidden.
--   * left panel: ship stats (HP, speed, cannons, crew; no weight), PLACE / DELETE mode buttons, part categories,
--     part cards with a turning 3D model + material costs (red = not enough), the materials you own, LAUNCH / EXIT.
--   * PLACE: green ghost block where it fits (red when it cannot go there, the reason shows in the status line).
--     DELETE: the part under the pointer glows red, click removes it (refunded). Right click no longer deletes.
-- The server (ShipyardService) still checks every placement.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ShipPartsCfg = require(Shared.Config.ShipParts)
local ShipStats = require(Shared.Modules.ShipStats)
local ShipModel = require(Shared.Modules.ShipModel)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.Parent.UI.UIKit)
local State = require(script.Parent.Parent.State)

local Builder = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New
local G = GameConfig.Ship.GridSize
local PLOT = GameConfig.Ship.PlotSize
local Parts = ShipPartsCfg.Parts
local selected = "PlankBlock"
local rotation = 0
local deleteMode = false
local category = "Hull"
local ghost, ghostKey, hlTarget
local gui, ui = nil, {}
local cam = { yaw = 0, pitch = 0.55, dist = 80, target = Vector3.zero, turning = false }
local CAT_ICON = { Core = "ship", Hull = "wood", Sail = "cloth", Weapon = "gunpowder", Utility = "anchor" }
local SINK_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space,
	Enum.KeyCode.R, Enum.KeyCode.X, Enum.KeyCode.Z, Enum.KeyCode.C, Enum.KeyCode.F, Enum.KeyCode.T, Enum.KeyCode.V, Enum.KeyCode.Tab, Enum.KeyCode.LeftShift }

-- materials any part can cost (shown in the Materials panel)
local MATERIALS = {}
for _, id in ipairs(ShipPartsCfg.Order) do
	for k in pairs(Parts[id].cost) do
		if k ~= "beli" and not table.find(MATERIALS, k) then
			table.insert(MATERIALS, k)
		end
	end
end
table.sort(MATERIALS)

local function owned(id)
	local p = State.profile
	if not p then
		return 0
	end
	if id == "beli" then
		return p.beli or 0
	end
	local n = 0
	for _, e in ipairs(p.inventory or {}) do
		if e.id == id then
			n += e.qty or 1
		end
	end
	return n
end

local function affordable(def)
	for k, v in pairs(def.cost) do
		if owned(k) < v then
			return false, "Not enough " .. (k == "beli" and "Doubloons" or ((ItemDB.Get(k) or {}).name or k))
		end
	end
	return true
end

local function status(text, color)
	if ui.status then
		ui.status.Text = text or ""
		ui.status.TextColor3 = color or T.TextSoft
	end
end

-- ===== placement rules (mirror of ShipyardService BuildPlace) =====
local DIRS = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
local function occupancy()
	local occ = {}
	for i, p in ipairs((State.build.design or {}).parts or {}) do
		if Parts[p.id] then
			for _, c in ipairs(ShipStats.Cells(p)) do
				occ[ShipStats.CellKey(c)] = i
			end
		end
	end
	return occ
end
local function inBounds(v)
	return v.X >= 0 and v.Y >= 0 and v.Z >= 0 and v.X < PLOT.X and v.Y < PLOT.Y and v.Z < PLOT.Z
end
local function canPlace(cell)
	local def = Parts[selected]
	local d = State.build.design or { parts = {} }
	if #d.parts >= GameConfig.Ship.MaxParts then
		return false, "Part limit reached"
	end
	if def.faction and State.profile and State.profile.faction ~= def.faction then
		return false, "Only for the " .. def.faction .. " faction"
	end
	if def.max then
		local n = 0
		for _, q in ipairs(d.parts) do
			n += q.id == def.id and 1 or 0
		end
		if n >= def.max then
			return false, "Only " .. def.max .. " of this part"
		end
	end
	local occ = occupancy()
	local touching = #d.parts == 0
	for _, c in ipairs(ShipStats.Cells({ id = selected, x = cell.X, y = cell.Y, z = cell.Z, r = rotation })) do
		if not inBounds(c) then
			return false, "Outside the slip"
		end
		if occ[ShipStats.CellKey(c)] then
			return false, "Something is already there"
		end
		for _, dir in ipairs(DIRS) do
			touching = touching or occ[ShipStats.CellKey(c + dir)] ~= nil
		end
	end
	if not touching then
		return false, "Must touch another part"
	end
	return affordable(def)
end

-- ===== ghost (place) / red highlight (delete) =====
local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if hlTarget then
		hlTarget:Destroy()
		hlTarget = nil
	end
	ghostKey = nil
end

local function showGhost(cell, ok)
	local key = ShipStats.CellKey(cell) .. ":" .. rotation .. ":" .. selected .. ":" .. tostring(ok)
	if key == ghostKey then
		return
	end
	clearGhost()
	ghostKey = key
	local p = { id = selected, x = cell.X, y = cell.Y, z = cell.Z, r = rotation }
	ghost = ShipModel.BuildPart(p, State.build.origin * ShipModel.LocalCFrame(p))
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.5)
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
		end
	end
	local c = ok and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 70)
	New("Highlight", { FillColor = c, OutlineColor = c, FillTransparency = 0.45, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = ghost })
	ghost.Parent = workspace
end

local function partUnder(hitInst)
	local m = hitInst and hitInst:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Index") == nil do
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	if m and m.Parent and m.Parent.Name == "Build_" .. player.Name then
		return m
	end
	return nil
end

local function rayFrom(screenPos)
	local ray = workspace.CurrentCamera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, ghost }
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

-- what the pointer aims at: place -> (cell), delete -> (model, part entry)
local function aim(screenPos)
	local b = State.build
	if not b.active or not b.origin then
		return nil
	end
	local hit = rayFrom(screenPos)
	if not hit then
		return nil
	end
	if deleteMode then
		local m = partUnder(hit.Instance)
		local p = m and b.design and b.design.parts[m:GetAttribute("Index")]
		return p and m, p
	end
	local lp = b.origin:PointToObjectSpace(hit.Position + hit.Normal * (G * 0.45))
	local cell = Vector3.new(math.floor(lp.X / G), math.floor(lp.Y / G), math.floor(-lp.Z / G))
	return inBounds(cell) and cell or nil
end

local function refreshAim(screenPos)
	if not State.build.active then
		return
	end
	local a, p = aim(screenPos)
	if deleteMode then
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		local key = a and ("del" .. a:GetAttribute("Index")) or nil
		if key ~= ghostKey then
			clearGhost()
			ghostKey = key
			if a then
				hlTarget = New("Highlight", { FillColor = Color3.fromRGB(255, 40, 40), OutlineColor = Color3.fromRGB(255, 220, 220), FillTransparency = 0.25,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = a, Parent = a })
				status("Click to remove " .. Parts[p.id].name .. " (refunded)", T.Red)
			else
				status("Point at a part to remove it", T.TextSoft)
			end
		end
		return
	end
	if not a then
		clearGhost()
		return
	end
	local ok, why = canPlace(a)
	showGhost(a, ok)
	status(ok and ("Click to place " .. Parts[selected].name) or why, ok and T.Green or T.Red)
end

local function act(screenPos)
	local a, p = aim(screenPos)
	if not a then
		return
	end
	task.spawn(function()
		local res
		if deleteMode then
			res = Net.Request("BuildRemove", { x = p.x, y = p.y, z = p.z })
		else
			local ok, why = canPlace(a)
			if not ok then
				status(why, T.Red)
				return
			end
			res = Net.Request("BuildPlace", { id = selected, x = a.X, y = a.Y, z = a.Z, r = rotation })
		end
		if res and not res.ok and res.msg and not res.throttled then
			status(res.msg, T.Red)
		end
	end)
end

-- ===== panel =====
local function chip(parent, icon, text, color, size)
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size), AutomaticSize = Enum.AutomaticSize.X, Parent = parent })
	UI.List(f, Enum.FillDirection.Horizontal, 3).VerticalAlignment = Enum.VerticalAlignment.Center
	UI.Icon(f, icon, size)
	UI.Text(f, text, size - 2, color or T.Text, "Number", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size), TextWrapped = false })
	return f
end

local function iconOf(id)
	if id == "beli" then
		return "coin"
	end
	return UI.ItemIconName(ItemDB.Get(id)) or "ore"
end

local renderParts, refreshStats, refreshMaterials

local function setMode(del)
	deleteMode = del
	clearGhost()
	if ui.placeBtn then
		UI.SetButtonColor(ui.placeBtn, del and T.Grey or T.Green)
		UI.SetButtonColor(ui.delBtn, del and T.Red or T.Grey)
	end
	status(del and "DELETE: point at a part" or "PLACE: pick a part, click the slip", del and T.Red or T.Green)
end

function refreshStats()
	local st = State.build.stats
	if not (ui.stats and st) then
		return
	end
	for k, v in pairs({ hp = st.hp, speed = st.speedLane, cannons = st.cannons, crew = st.crew .. "/" .. st.crewCap }) do
		ui.stats[k].Text = tostring(v)
	end
	ui.ready.Text = st.valid and "READY TO SAIL" or "NEEDS A HELM + A SAIL OR OARS"
	ui.ready.TextColor3 = st.valid and T.Green or T.Red
	if ui.nameBox and not ui.nameBox:IsFocused() then
		ui.nameBox.Text = State.build.design and State.build.design.name or "Ship"
	end
end

function refreshMaterials()
	if not ui.mats then
		return
	end
	for _, c in ipairs(ui.mats:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	chip(ui.mats, "coin", UI.Format(owned("beli")), T.Gold, 20)
	for _, id in ipairs(MATERIALS) do
		local n = owned(id)
		chip(ui.mats, iconOf(id), tostring(n), n > 0 and T.Text or T.TextSoft, 20)
	end
end

function renderParts()
	local list = ui.list
	if not list then
		return
	end
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, id in ipairs(ShipPartsCfg.Order) do
		local def = Parts[id]
		if def.category == category then
			local pick = id == selected and not deleteMode
			local card = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = pick and T.Gold:Lerp(T.PanelDeep, 0.55) or T.PanelDeep, Parent = list })
			UI.Corner(card, 8)
			UI.Stroke(card, pick and T.Gold or T.Edge, pick and 3 or 2)
			UI.Tactile(card)
			local m = ShipModel.BuildPart({ id = id, x = 0, y = 0, z = 0, r = 0 }, CFrame.new())
			local vp = UI.ModelViewOf(card, m, 72, 0.6)
			vp.AnchorPoint = Vector2.new(0.5, 0)
			vp.Position = UDim2.new(0.5, 0, 0, 2)
			UI.Text(card, def.name, 12, T.Text, "Display", { Position = UDim2.fromOffset(4, 74), Size = UDim2.new(1, -8, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true })
			local costRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 92), Size = UDim2.new(1, -8, 0, 36), Parent = card })
			local grid = New("UIGridLayout", { CellSize = UDim2.fromOffset(60, 16), CellPadding = UDim2.fromOffset(2, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = costRow })
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			local keys = {}
			for k in pairs(def.cost) do
				table.insert(keys, k)
			end
			table.sort(keys, function(a, b)
				return a == "beli" or (b ~= "beli" and a < b)
			end)
			for _, k in ipairs(keys) do
				local v = def.cost[k]
				if v > 0 then
					chip(costRow, iconOf(k), k == "beli" and UI.Format(v) or ("x" .. v), owned(k) >= v and T.Text or T.Red, 15)
				end
			end
			card.Activated:Connect(function()
				selected = id
				setMode(false)
				renderParts()
			end)
		end
	end
end

local function buildPanel()
	if gui then
		gui:Destroy()
	end
	ui = {}
	gui = New("ScreenGui", { Name = "GVShipyard", ResetOnSpawn = false, DisplayOrder = 25, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local vs = workspace.CurrentCamera.ViewportSize
	New("UIScale", { Scale = math.clamp(vs.Y / 760, 0.62, 1.15), Parent = gui })
	local panel = UI.Card(gui, UDim2.new(0, 380, 1, -24), T.Panel)
	panel.Position = UDim2.fromOffset(12, 12)
	UI.Pad(panel, 10)
	UI.List(panel, nil, 7)

	-- title + name
	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, Parent = panel })
	UI.Icon(top, "ship", 32)
	UI.Text(top, "SHIPYARD", 22, T.Gold, "Display", { Position = UDim2.fromOffset(38, 0), Size = UDim2.fromOffset(150, 32), TextWrapped = false })
	ui.nameBox = New("TextBox", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(160, 28), ClearTextOnFocus = false,
		Text = "", PlaceholderText = "Ship name", FontFace = UI.Fonts.Body, TextScaled = true, TextColor3 = T.Text, BackgroundColor3 = T.PanelDeep, Parent = top })
	UI.Stroke(ui.nameBox, T.Edge, 2)
	ui.nameBox.FocusLost:Connect(function()
		local n = ui.nameBox.Text
		if #n > 0 and State.build.design and n ~= State.build.design.name then
			Net.Request("BuildRename", { name = n })
		end
	end)

	-- stats: HP, speed, cannons, crew
	local stats = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2, Parent = panel })
	UI.List(stats, Enum.FillDirection.Horizontal, 6)
	ui.stats = {}
	for _, s in ipairs({ { "hp", "❤️", "HP", T.Red }, { "speed", "ship", "SPEED", T.Ocean }, { "cannons", "gunpowder", "CANNON", T.Orange or T.Gold }, { "crew", "party", "CREW", T.Green } }) do
		local box = New("Frame", { Size = UDim2.new(0.25, -5, 1, 0), BackgroundColor3 = s[4]:Lerp(T.PanelDeep, 0.7), Parent = stats })
		UI.Stroke(box, s[4], 2)
		UI.Icon(box, s[2], 18, { Position = UDim2.fromOffset(3, 3) })
		UI.Text(box, s[3], 9, s[4]:Lerp(Color3.new(1, 1, 1), 0.4), "Display", { Position = UDim2.fromOffset(23, 5), Size = UDim2.new(1, -25, 0, 12), TextWrapped = false })
		ui.stats[s[1]] = UI.Text(box, "0", 17, T.Text, "Number", { Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true })
	end
	ui.ready = UI.Text(panel, "", 12, T.Green, "Display", { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3 })

	-- PLACE / DELETE / ROTATE
	local modes = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 4, Parent = panel })
	UI.List(modes, Enum.FillDirection.Horizontal, 6)
	ui.placeBtn = UI.Button(modes, "PLACE", T.Green, UDim2.new(0.38, -4, 1, -6), function()
		setMode(false)
		renderParts()
	end)
	ui.delBtn = UI.Button(modes, "DELETE", T.Grey, UDim2.new(0.38, -4, 1, -6), function()
		setMode(true)
		renderParts()
	end)
	UI.Button(modes, "↻ R", T.Ocean, UDim2.new(0.24, -4, 1, -6), function()
		rotation = (rotation + 1) % 4
		clearGhost()
	end)

	-- categories
	local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 5, Parent = panel })
	UI.List(tabs, Enum.FillDirection.Horizontal, 4)
	for _, cat in ipairs(ShipPartsCfg.Categories) do
		local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = T.PanelDeep, Parent = tabs })
		UI.Stroke(b, T.Edge, 2)
		UI.Icon(b, CAT_ICON[cat] or "gear", 22, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		UI.Tooltip(b, function()
			return cat
		end)
		local function paint()
			b.BackgroundColor3 = cat == category and T.Gold:Lerp(T.PanelDeep, 0.4) or T.PanelDeep
		end
		paint()
		b.Activated:Connect(function()
			category = cat
			for _, c in ipairs(tabs:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundColor3 = T.PanelDeep
				end
			end
			paint()
			renderParts()
		end)
	end

	-- part cards
	ui.list = UI.Scroll(panel, UDim2.new(1, 0, 1, -352))
	ui.list.LayoutOrder = 6
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 132), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.list })
	New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = ui.list })

	-- materials you own
	UI.Text(panel, "MATERIALS", 12, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 7 })
	ui.mats = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 8, Parent = panel })
	UI.Stroke(ui.mats, T.Edge, 2)
	UI.Pad(ui.mats, 5)
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -4, 0, 20), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.mats })

	-- status + launch / exit
	ui.status = UI.Text(panel, "", 12, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 9 })
	local bottom = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 10, Parent = panel })
	UI.List(bottom, Enum.FillDirection.Horizontal, 8)
	UI.Button(bottom, "⛵ LAUNCH", T.Green, UDim2.new(0.6, -4, 1, -6), function()
		local res = Net.Request("LaunchShip", { slot = State.build.slot })
		if not res.ok then
			status(res.msg or "Cannot launch", T.Red)
		else
			UI.Banner("Set Sail!", "W/S sails  •  A/D steer  •  click water to fire cannons", T.Ocean)
		end
	end)
	UI.Button(bottom, "EXIT", T.Grey, UDim2.new(0.4, -4, 1, -6), function()
		Net.Request("BuildExit")
	end)

	-- controls hint (bottom centre of the screen)
	local hint = UI.Text(gui, UI.IsMobile and "Drag: turn  •  Pinch: zoom  •  Tap: place / delete" or "Right-drag: turn  •  Wheel: zoom  •  WASD / Q E: move  •  R: rotate  •  X: delete mode",
		12, T.Text, "Semi", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 190, 1, -10), Size = UDim2.fromOffset(640, 16), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	hint.BackgroundTransparency = 0.5
	hint.BackgroundColor3 = T.PanelDeep

	setMode(false)
	renderParts()
	refreshStats()
	refreshMaterials()
end

-- ===== free camera =====
local function plotCenter()
	local o = State.build.origin
	return o * Vector3.new(PLOT.X * G / 2, G * 1.5, -PLOT.Z * G / 2)
end

local function sinkKeys(_, st, input)
	if st == Enum.UserInputState.Begin then
		if input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
			clearGhost()
		elseif input.KeyCode == Enum.KeyCode.X then
			setMode(not deleteMode)
			renderParts()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function startCamera()
	local o = State.build.origin
	cam.target = plotCenter()
	local look = o.LookVector
	cam.yaw = math.atan2(-look.X, -look.Z) + math.rad(140)
	cam.pitch, cam.dist = 0.5, 95
	ContextActionService:BindActionAtPriority("GVBuildKeys", sinkKeys, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(SINK_KEYS))
	UI.Root.Enabled = false -- full screen: the HUD hides while building
end

local function stopCamera()
	ContextActionService:UnbindAction("GVBuildKeys")
	local c = workspace.CurrentCamera
	c.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	cam.turning = false
	UI.Root.Enabled = true
end

local function stepCamera(dt)
	local c = workspace.CurrentCamera
	c.CameraType = Enum.CameraType.Scriptable
	local mv = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		local K = UserInputService
		local fwd = Vector3.new(-math.sin(cam.yaw), 0, -math.cos(cam.yaw))
		local right = Vector3.new(math.cos(cam.yaw), 0, -math.sin(cam.yaw))
		mv += (K:IsKeyDown(Enum.KeyCode.W) and fwd or Vector3.zero) - (K:IsKeyDown(Enum.KeyCode.S) and fwd or Vector3.zero)
		mv += (K:IsKeyDown(Enum.KeyCode.D) and right or Vector3.zero) - (K:IsKeyDown(Enum.KeyCode.A) and right or Vector3.zero)
		mv += Vector3.new(0, (K:IsKeyDown(Enum.KeyCode.E) and 1 or 0) - (K:IsKeyDown(Enum.KeyCode.Q) and 1 or 0), 0)
	end
	local center = plotCenter()
	local half = Vector3.new(PLOT.X * G, PLOT.Y * G, PLOT.Z * G) / 2 + Vector3.new(30, 10, 30)
	local rel = State.build.origin:VectorToObjectSpace(cam.target + mv * dt * 45 - center)
	rel = Vector3.new(math.clamp(rel.X, -half.X, half.X), math.clamp(rel.Y, -half.Y, half.Y), math.clamp(rel.Z, -half.Z, half.Z))
	cam.target = center + State.build.origin:VectorToWorldSpace(rel)
	c.CFrame = CFrame.new(cam.target) * CFrame.Angles(0, cam.yaw, 0) * CFrame.Angles(-cam.pitch, 0, 0) * CFrame.new(0, 0, cam.dist)
end

function Builder.OnState(data)
	local was = State.build.active
	State.build = data
	if data.active then
		if not gui then
			buildPanel()
		end
		if not was then
			startCamera()
		end
		refreshStats()
		refreshMaterials()
		renderParts()
		clearGhost()
	else
		clearGhost()
		if gui then
			gui:Destroy()
			gui = nil
			ui = {}
		end
		if was then
			stopCamera()
		end
	end
end

function Builder.Start()
	local touchStart
	UserInputService.InputBegan:Connect(function(input, processed)
		if not State.build.active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cam.turning = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif processed then
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			act(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cam.turning = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.UserInputType == Enum.UserInputType.Touch and touchStart and State.build.active and not processed then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if (p - touchStart).Magnitude < 12 then -- a tap, not a camera drag (InputObject.Position has no top-bar inset)
				local inset = game:GetService("GuiService"):GetGuiInset()
				refreshAim(p + inset)
				act(p + inset)
			end
			touchStart = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not State.build.active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and cam.turning then
			cam.yaw -= input.Delta.X * 0.008
			cam.pitch = math.clamp(cam.pitch + input.Delta.Y * 0.006, 0.08, 1.45)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			cam.dist = math.clamp(cam.dist * (1 - input.Position.Z * 0.1), 18, 180)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchStart and not processed then
			cam.yaw -= input.Delta.X * 0.01
			cam.pitch = math.clamp(cam.pitch + input.Delta.Y * 0.008, 0.08, 1.45)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, st)
		if State.build.active and st == Enum.UserInputState.Change then
			cam.dist = math.clamp(cam.dist / math.max(scale, 0.5) ^ 0.15, 18, 180)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not State.build.active or not State.build.origin then
			return
		end
		stepCamera(dt)
		if not UI.IsMobile and not cam.turning then
			refreshAim(UserInputService:GetMouseLocation())
		end
	end)
	State.Changed:Connect(function(kind)
		if kind == "profile" and State.build.active then
			refreshMaterials()
			renderParts()
		end
	end)
end

return Builder
