-- Builder (client): the shipyard. v0.25.152 rework (owner, Shipshaper reference clip: "too fixed to squares, like
-- Build a Boat"): free-form ships = design v2 (Shared/Modules/ShipHull).
--   * HULL: the hull is a row of points along the keel. Drag the yellow handles to widen it, blue to deepen it, white
--     to slide a point along the ship, red for the bow / stern rake; steppers in the panel do the same. Each point has
--     its own section (V keel / round / flat), blended along the hull. + POINT / - POINT.
--   * PARTS: pick a part card, click a deck or a roof to place it anywhere (0.5 stud snap, R = turn 15 deg, M = mirror
--     to the other side). Click a placed part to select it: drag it around, turn, resize (blocks per axis, masts =
--     sail width + height), raise / lower, mirror, clone, delete (X / Delete).
--   * PAINT: hull, bottom, stripe, deck, rails, sails from a palette, or RANDOM. Marines keep their livery.
--   * Live stats: HP, speed, guns, crew, weight, draft, freeboard, stability stars, and why it would sink / flood /
--     capsize. Everything is edited locally (a preview on the slip); SAVE sends the design: the server checks it and
--     charges (or refunds) only the difference. Ctrl+Z / UNDO.
-- Camera: right-drag turns, wheel zooms, WASD moves, Q / E down / up.
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
local ShipHull = require(Shared.Modules.ShipHull)
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

local work, saved -- the design being edited (local) / the last saved one (server)
local undoStack = {}
local tab = "hull"
local category = "Hull"
local pick = nil -- part id being placed, nil = select mode
local selItem = nil -- index in work.items
local selNode = 2
local mirror = true
local rot = 0
local zone = "hull"
local gui, ui = nil, {}
local view = {} -- hull, items, handles, water, ghost, selHl
local dirty = { hull = false, items = false }
local last = { hull = 0, items = 0 }
local drag = nil
local adoptSave = false
local cam = { yaw = 0, pitch = 0.55, dist = 80, target = Vector3.zero, turning = false }
local CAT_ICON = { Core = "ship", Hull = "wood", Sail = "cloth", Weapon = "gunpowder", Utility = "anchor" }
local SINK_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space,
	Enum.KeyCode.R, Enum.KeyCode.X, Enum.KeyCode.Z, Enum.KeyCode.C, Enum.KeyCode.F, Enum.KeyCode.T, Enum.KeyCode.V, Enum.KeyCode.Tab, Enum.KeyCode.LeftShift,
	Enum.KeyCode.M, Enum.KeyCode.Delete, Enum.KeyCode.G }
local HANDLE = { w = Color3.fromRGB(255, 214, 60), d = Color3.fromRGB(70, 160, 255), z = Color3.fromRGB(245, 245, 245), rake = Color3.fromRGB(255, 80, 70) }

local renderTab, refreshStats, rebuildAll

-- ===== helpers =====
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

local function iconOf(id)
	if id == "beli" then
		return "coin"
	end
	return UI.ItemIconName(ItemDB.Get(id)) or "ore"
end

local function status(text, color)
	if ui.status then
		ui.status.Text = text or ""
		ui.status.TextColor3 = color or T.TextSoft
	end
end

local function colorFn()
	return ShipModel.FactionColorFn(State.profile and State.profile.faction)
end

local function nodes()
	return work.hull.nodes
end

local function hullLength()
	local n = nodes()
	return n[#n].z
end

local function maxDepth()
	local D = 0
	for _, nd in ipairs(nodes()) do
		D = math.max(D, nd.d)
	end
	return D
end

-- ship space -> world: the stern sits near the slip's back end, the deck a fixed height over the plot origin
local function shipCf()
	local o = State.build.origin
	return o * CFrame.new(PLOT.X * G / 2, 6, -4)
end

local function toShip(worldPos)
	local lp = shipCf():PointToObjectSpace(worldPos)
	return Vector3.new(lp.X, lp.Y, -lp.Z)
end

local function snap(v, s)
	return math.floor(v / s + 0.5) * s
end

local function snapshot()
	table.insert(undoStack, ShipHull.Clone(work))
	if #undoStack > 40 then
		table.remove(undoStack, 1)
	end
end

local function changed(hull, items)
	dirty.hull = dirty.hull or hull
	dirty.items = dirty.items or items or hull -- gun ports in the walls follow the cannons
end

local function isDirty()
	if not saved or not work then
		return false
	end
	local a = ShipHull.Sanitize(work, State.profile and State.profile.faction)
	local b = ShipHull.Sanitize(saved, State.profile and State.profile.faction)
	if not a or not b then
		return true
	end
	local HttpService = game:GetService("HttpService")
	return HttpService:JSONEncode(a) ~= HttpService:JSONEncode(b)
end

-- ===== preview =====
local function clear(key)
	if view[key] then
		view[key]:Destroy()
		view[key] = nil
	end
end

local function nonQuery(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
end

local function rebuildHull()
	clear("hull")
	clear("handles")
	clear("water")
	local cf = shipCf()
	local ok, shell = pcall(ShipHull.BuildHull, work, cf, colorFn(), nil)
	if ok and shell then
		shell.Name = "GVBuildHull"
		nonQuery(shell)
		shell.Parent = workspace
		view.hull = shell
	end
	-- handles
	local f = Instance.new("Folder")
	f.Name = "GVBuildHandles"
	local function handle(kind, node, side, pos, color)
		local p = Instance.new("Part")
		p.Name = "Handle"
		p.Size = Vector3.new(1.1, 1.1, 1.1)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic -- Neon bloomed into blobs at night
		p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
		p.CFrame = cf * CFrame.new(pos.X, pos.Y, -pos.Z)
		p:SetAttribute("Kind", kind)
		p:SetAttribute("Node", node)
		p:SetAttribute("Side", side)
		if node == selNode and kind ~= "rake" then
			p.Size = Vector3.new(1.5, 1.5, 1.5)
		end
		local box = Instance.new("SelectionBox")
		box.Adornee = p
		box.Color3 = Color3.new(0, 0, 0)
		box.LineThickness = 0.06
		box.Parent = p
		p.Parent = f
	end
	if tab == "hull" then
		local wall = work.hull.wall or 0
		for i, nd in ipairs(nodes()) do
			handle("w", i, 1, Vector3.new(nd.w, 0.8, nd.z), HANDLE.w)
			handle("w", i, -1, Vector3.new(-nd.w, 0.8, nd.z), HANDLE.w)
			handle("d", i, 0, Vector3.new(0, -nd.d - 0.8, nd.z), HANDLE.d)
			if i > 1 then
				handle("z", i, 0, Vector3.new(0, wall + 2.5, nd.z), HANDLE.z)
			end
		end
		handle("rake", 0, 1, Vector3.new(0, 0.8, hullLength() + (work.hull.bow or 0)), HANDLE.rake)
		handle("rake", 0, -1, Vector3.new(0, 0.8, -(work.hull.stern or 0)), HANDLE.rake)
	end
	f.Parent = workspace
	view.handles = f
	-- waterline: where this ship would float
	local st = ShipStats.Compute(work, State.profile and State.profile.crew or 0)
	local ph = st.phys
	if ph then
		local w = Instance.new("Part")
		w.Name = "GVWaterline"
		w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false
		w.Material = Enum.Material.Glass
		w.Color = ph.sinks and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(60, 170, 255)
		w.Transparency = 0.55
		local sl = ph.slices
		w.Size = Vector3.new(ShipHull.MaxBeam + 10, 0.1, sl.zMax - sl.zMin + 10)
		w.CFrame = cf * CFrame.new(0, ph.waterY, -(sl.zMin + sl.zMax) / 2)
		w.Parent = workspace
		view.water = w
	end
	last.hull = os.clock()
	dirty.hull = false
end

local function paintSelection()
	clear("selHl")
	if not (selItem and view.items) then
		return
	end
	local hl = Instance.new("Folder")
	for _, m in ipairs(view.items:GetChildren()) do
		if m:GetAttribute("Item") == selItem then
			New("Highlight", { FillColor = Color3.fromRGB(255, 214, 60), OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.6,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = m, Parent = hl })
		end
	end
	hl.Parent = view.items
	view.selHl = hl
end

local function rebuildItems()
	clear("selHl")
	clear("items")
	local cf = shipCf()
	local m = Instance.new("Model")
	m.Name = "GVBuildItems"
	for i, it in ipairs(ShipHull.Expand(work)) do
		local ok, im = pcall(ShipHull.BuildItem, it, cf, colorFn(), ShipModel.BuildPart)
		if ok and im then
			im:SetAttribute("Index", i)
			nonQuery(im)
			im.Parent = m
		end
	end
	m:SetAttribute("SailColor", ShipHull.PaintOf(work, colorFn()).sail:ToHex())
	m:SetAttribute("Faction", State.profile and State.profile.faction)
	m.Parent = workspace
	view.items = m
	paintSelection()
	last.items = os.clock()
	dirty.items = false
end

function rebuildAll()
	rebuildHull()
	rebuildItems()
	refreshStats()
end

-- ===== pointing =====
local function rayAt(screenPos)
	return workspace.CurrentCamera:ViewportPointToRay(screenPos.X, screenPos.Y)
end

local function cast(screenPos, include)
	local ray = rayAt(screenPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return workspace:Raycast(ray.Origin, ray.Direction * 600, params), ray
end

local function itemModels(idx)
	local out = {}
	for _, m in ipairs(view.items and view.items:GetChildren() or {}) do
		if m:GetAttribute("Item") == idx then
			table.insert(out, m)
		end
	end
	return out
end

-- a deck / roof spot under the pointer, in ship space (nil + why when there is none)
local function surfaceSpot(screenPos, skipItem)
	local include = { view.hull }
	for _, m in ipairs(view.items and view.items:GetChildren() or {}) do
		if m:IsA("Model") and (not skipItem or m:GetAttribute("Item") ~= skipItem) then
			table.insert(include, m)
		end
	end
	local hit = cast(screenPos, include)
	if not hit then
		return nil
	end
	if hit.Normal:Dot(shipCf().UpVector) < 0.6 then
		return nil, "Place it on a deck or a roof"
	end
	local sp = toShip(hit.Position)
	return Vector3.new(snap(sp.X, 0.5), snap(sp.Y, 0.25), snap(sp.Z, 0.5))
end

local function itemUnder(screenPos)
	local hit = cast(screenPos, { view.items })
	local m = hit and hit.Instance:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Item") == nil do
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	return m and m:GetAttribute("Item")
end

-- t along the line p0 + a*t that comes closest to the pointer ray
local function axisParam(ray, p0, a)
	local u = ray.Direction.Unit
	local w0 = p0 - ray.Origin
	local b = a:Dot(u)
	local den = 1 - b * b
	if den < 1e-3 then
		return nil
	end
	return (b * u:Dot(w0) - a:Dot(w0)) / den
end

-- ===== ghost (placing) =====
local ghostKey
local function clearGhost()
	clear("ghost")
	ghostKey = nil
end

local function newItem(spot)
	local x = spot.X
	local m = mirror and math.abs(x) >= 0.5 and not Parts[pick].max
	return { id = pick, x = x, y = spot.Y, z = spot.Z, r = rot, sx = 1, sy = 1, sz = 1, m = m or nil }
end

local function showGhost(spot)
	local it = newItem(spot)
	local key = table.concat({ it.id, it.x, it.y, it.z, it.r, tostring(it.m) }, ":")
	if key == ghostKey then
		return
	end
	clearGhost()
	ghostKey = key
	local g = Instance.new("Model")
	g.Name = "GVBuildGhost"
	local list = { { id = it.id, x = it.x, y = it.y, z = it.z, r = it.r, sx = 1, sy = 1, sz = 1, src = 0 } }
	if it.m then
		table.insert(list, { id = it.id, x = -it.x, y = it.y, z = it.z, r = (360 - it.r) % 360, sx = 1, sy = 1, sz = 1, src = 0, mirror = true })
	end
	for _, e in ipairs(list) do
		local ok, m = pcall(ShipHull.BuildItem, e, shipCf(), colorFn(), ShipModel.BuildPart)
		if ok and m then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = math.max(d.Transparency, 0.45)
					d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
				end
			end
			m.Parent = g
		end
	end
	local c = Color3.fromRGB(80, 255, 120)
	New("Highlight", { FillColor = c, OutlineColor = c, FillTransparency = 0.5, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = g })
	g.Parent = workspace
	view.ghost = g
end

-- ===== editing actions =====
local function selectItem(idx)
	selItem = idx
	paintSelection()
	if renderTab then
		renderTab()
	end
end

local function placeAt(spot)
	local count = #ShipHull.Expand(work)
	local it = newItem(spot)
	if count + (it.m and 2 or 1) > ShipHull.MaxItems then
		status("Part limit reached (" .. ShipHull.MaxItems .. ")", T.Red)
		return
	end
	local def = Parts[pick]
	if def.faction and State.profile and State.profile.faction ~= def.faction then
		status("Only for the " .. def.faction .. " faction", T.Red)
		return
	end
	if def.max then
		local n = 0
		for _, q in ipairs(work.items) do
			n += q.id == def.id and 1 or 0
		end
		if n >= def.max then
			status("Only " .. def.max .. " of this part", T.Red)
			return
		end
	end
	snapshot()
	table.insert(work.items, it)
	changed(false, true)
	refreshStats()
	status("Placed " .. def.name .. (it.m and " (mirrored)" or ""), T.Green)
end

local function deleteSelected()
	if not selItem or not work.items[selItem] then
		return
	end
	snapshot()
	local it = table.remove(work.items, selItem)
	selItem = nil
	changed(false, true)
	refreshStats()
	renderTab()
	status("Removed " .. Parts[it.id].name, T.Red)
end

local function editSelected(fn)
	local it = selItem and work.items[selItem]
	if not it then
		return
	end
	snapshot()
	fn(it, ShipHull.ScaleRule(it.id))
	changed(false, true)
	refreshStats()
	renderTab()
end

local function rotate(step)
	if selItem and not pick then
		editSelected(function(it)
			it.r = ((it.r or 0) + step) % 360
		end)
	else
		rot = (rot + step) % 360
		clearGhost()
	end
end

local function undo()
	local prev = table.remove(undoStack)
	if not prev then
		status("Nothing to undo", T.TextSoft)
		return
	end
	work = prev
	if selItem and not work.items[selItem] then
		selItem = nil
	end
	selNode = math.clamp(selNode, 1, #nodes())
	changed(true, true)
	refreshStats()
	renderTab()
end

local function editHull(fn)
	snapshot()
	fn(work.hull)
	changed(true, true)
	refreshStats()
	renderTab()
end

-- ===== saving =====
local function save(after)
	local res = Net.Request("BuildSave", { design = work })
	if res.ok then
		adoptSave = true
		status("Saved", T.Green)
		if after then
			after()
		end
	elseif not res.throttled then
		status(res.msg or "Could not save", T.Red)
	end
	return res.ok
end

-- ===== panel =====
local function chip(parent, icon, text, color, size)
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size), AutomaticSize = Enum.AutomaticSize.X, Parent = parent })
	UI.List(f, Enum.FillDirection.Horizontal, 3).VerticalAlignment = Enum.VerticalAlignment.Center
	UI.Icon(f, icon, size)
	UI.Text(f, text, size - 2, color or T.Text, "Number", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size), TextWrapped = false })
	return f
end

local function clearKids(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return a == "beli" or (b ~= "beli" and a < b)
	end)
	return keys
end

function refreshStats()
	if not (ui.stats and work) then
		return
	end
	local p = State.profile or {}
	local st = ShipStats.Compute(work, p.crew or 0, { shipSpeed = State.derived and State.derived.shipSpeed })
	local ph = st.phys
	local vals = {
		hp = UI.Format(st.hp),
		speed = tostring(math.floor(ShipStats.Speed(st, 1))),
		guns = tostring(#st.cannons),
		crew = st.crewCap .. "",
		tons = tostring(math.floor(st.weight / 10 + 0.5)),
		draft = string.format("%.1f", ph.draft),
		free = ph.sinks and "SUNK" or string.format("%.1f", ph.freeboard),
		stab = ph.stars > 0 and string.rep("*", ph.stars) or "X",
	}
	for k, v in pairs(vals) do
		ui.stats[k].Text = v
	end
	ui.stats.stab.TextColor3 = ph.stars >= 3 and T.Green or ph.stars >= 1 and T.Gold or T.Red
	ui.stats.free.TextColor3 = (ph.sinks or ph.floods) and T.Red or T.Text
	local msg = st.problem or (st.helm ~= 1 and "Needs a helm") or (st.thrust + st.oars <= 0 and "Needs a sail or an oar bench") or "READY TO SAIL"
	ui.ready.Text = string.upper(msg)
	ui.ready.TextColor3 = st.valid and T.Green or T.Red
	-- what SAVE costs / gives back
	clearKids(ui.cost)
	local d = isDirty()
	local pay, refund = {}, {}
	if d then
		pay, refund = ShipHull.Delta(ShipHull.Cost(work), saved and (saved.paid or ShipHull.Cost(saved)) or {})
	end
	local can = true
	if next(pay) then
		UI.Text(ui.cost, "SAVE COSTS", 11, T.Gold, "Display", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), TextWrapped = false })
		for _, k in ipairs(sortedKeys(pay)) do
			local short = owned(k) < pay[k]
			can = can and not short
			chip(ui.cost, iconOf(k), UI.Format(pay[k]), short and T.Red or T.Text, 18)
		end
	end
	if next(refund) then
		UI.Text(ui.cost, "REFUND", 11, T.Green, "Display", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), TextWrapped = false })
		for _, k in ipairs(sortedKeys(refund)) do
			chip(ui.cost, iconOf(k), "+" .. UI.Format(refund[k]), T.Green, 18)
		end
	end
	if not d then
		UI.Text(ui.cost, "ALL SAVED", 11, T.TextSoft, "Display", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), TextWrapped = false })
	end
	if ui.saveBtn then
		UI.SetButtonColor(ui.saveBtn, (d and can) and T.Green or (d and T.Red or T.Grey))
	end
	if ui.nameBox and not ui.nameBox:IsFocused() then
		ui.nameBox.Text = work.name or "Ship"
	end
end

-- a "LABEL  -  value  +" row
local function stepper(parent, order, label, value, onMinus, onPlus)
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = parent })
	UI.Text(row, label, 12, T.TextSoft, "Display", { Size = UDim2.new(0.42, 0, 1, 0), TextWrapped = false })
	local _, m = UI.Button(row, "-", T.Grey, UDim2.fromOffset(38, 30), onMinus)
	m.Position = UDim2.new(0.42, 0, 0, 0)
	UI.Text(row, value, 14, T.Text, "Number", { Position = UDim2.new(0.42, 44, 0, 0), Size = UDim2.new(0.58, -88, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	local _, pl = UI.Button(row, "+", T.Grey, UDim2.fromOffset(38, 30), onPlus)
	pl.AnchorPoint = Vector2.new(1, 0)
	pl.Position = UDim2.new(1, 0, 0, 0)
	return row
end

local function buttonRow(parent, order, h)
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h or 40), LayoutOrder = order, Parent = parent })
	UI.List(row, Enum.FillDirection.Horizontal, 6)
	return row
end

local function fmt(v)
	return (math.abs(v - math.floor(v)) < 0.01) and tostring(math.floor(v)) or string.format("%.1f", v)
end

local function hullTab(body)
	local n = nodes()
	selNode = math.clamp(selNode, 1, #n)
	local nd = n[selNode]
	local o = 0
	local function nexto()
		o += 1
		return o
	end
	local hint = UI.Text(body, "Drag the handles on the hull: YELLOW = width, BLUE = depth, WHITE = slide a point, RED = bow / stern rake.", 11, T.TextSoft, "Semi",
		{ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nexto() })
	hint.TextWrapped = true
	local r1 = buttonRow(body, nexto(), 36)
	UI.Button(r1, "<", T.Ocean, UDim2.fromOffset(44, 32), function()
		selNode = selNode > 1 and selNode - 1 or #n
		changed(true, false)
		renderTab()
	end)
	UI.Text(r1, "POINT " .. selNode .. "/" .. #n, 13, T.Gold, "Display", { Size = UDim2.fromOffset(150, 32), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	UI.Button(r1, ">", T.Ocean, UDim2.fromOffset(44, 32), function()
		selNode = selNode < #n and selNode + 1 or 1
		changed(true, false)
		renderTab()
	end)
	local r2 = buttonRow(body, nexto(), 36)
	UI.Button(r2, "+ POINT", T.Green, UDim2.new(0.5, -3, 1, -4), function()
		if #n >= ShipHull.MaxNodes then
			status("At most " .. ShipHull.MaxNodes .. " points", T.Red)
			return
		end
		-- split the longest gap next to the selected point
		local i = selNode < #n and selNode or selNode - 1
		local a, b = n[i], n[i + 1]
		if b.z - a.z < 4 then
			status("Points too close: slide one away first", T.Red)
			return
		end
		editHull(function()
			table.insert(n, i + 1, { z = snap((a.z + b.z) / 2, 1), w = snap((a.w + b.w) / 2, 0.5), d = snap((a.d + b.d) / 2, 0.5), s = a.s })
			selNode = i + 1
		end)
	end)
	UI.Button(r2, "- POINT", T.Red, UDim2.new(0.5, -3, 1, -4), function()
		if #n <= 2 then
			status("A hull needs 2 points", T.Red)
			return
		end
		editHull(function()
			table.remove(n, selNode)
			n[1].z = 0
			selNode = math.clamp(selNode, 1, #n)
		end)
	end)
	local r3 = buttonRow(body, nexto(), 34)
	for _, s in ipairs(ShipHull.Sections) do
		local b = UI.Button(r3, ShipHull.SectionName[s], nd.s == s and T.Gold or T.Grey, UDim2.new(1 / 3, -4, 1, -4), function()
			editHull(function()
				nd.s = s
			end)
		end)
		b.TextScaled = true
	end
	stepper(body, nexto(), "WIDTH", fmt(nd.w * 2), function()
		editHull(function()
			nd.w = math.max(0.5, nd.w - 0.5)
		end)
	end, function()
		editHull(function()
			nd.w = math.min(ShipHull.MaxBeam / 2, nd.w + 0.5)
		end)
	end)
	stepper(body, nexto(), "DEPTH", fmt(nd.d), function()
		editHull(function()
			nd.d = math.max(1, nd.d - 0.5)
		end)
	end, function()
		editHull(function()
			nd.d = math.min(ShipHull.MaxDepth, nd.d + 0.5)
		end)
	end)
	if selNode > 1 then
		stepper(body, nexto(), "POSITION", fmt(nd.z), function()
			editHull(function()
				nd.z = math.max(n[selNode - 1].z + 2, nd.z - 1)
			end)
		end, function()
			local cap = n[selNode + 1] and n[selNode + 1].z - 2 or ShipHull.MaxLength
			editHull(function()
				nd.z = math.min(cap, nd.z + 1)
			end)
		end)
	end
	local h = work.hull
	stepper(body, nexto(), "BOW RAKE", fmt(h.bow or 0), function()
		editHull(function()
			h.bow = math.max(0, (h.bow or 0) - 1)
		end)
	end, function()
		editHull(function()
			h.bow = math.min(16, (h.bow or 0) + 1)
		end)
	end)
	stepper(body, nexto(), "STERN RAKE", fmt(h.stern or 0), function()
		editHull(function()
			h.stern = math.max(0, (h.stern or 0) - 1)
		end)
	end, function()
		editHull(function()
			h.stern = math.min(10, (h.stern or 0) + 1)
		end)
	end)
	stepper(body, nexto(), "BULWARK", fmt(h.wall or 0), function()
		editHull(function()
			h.wall = math.max(0, (h.wall or 0) - 0.5)
		end)
	end, function()
		editHull(function()
			h.wall = math.min(ShipHull.MaxWall, (h.wall or 0) + 0.5)
		end)
	end)
	UI.Text(body, "Length " .. fmt(hullLength() + (h.bow or 0) + (h.stern or 0)) .. " studs  •  max " .. ShipHull.MaxLength, 11, T.TextSoft, "Semi",
		{ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = nexto() })
end

local function partsTab(body)
	local top = buttonRow(body, 1, 38)
	local selB = UI.Button(top, "SELECT", pick and T.Grey or T.Gold, UDim2.new(0.34, -4, 1, -4), function()
		pick = nil
		clearGhost()
		renderTab()
	end)
	selB.TextScaled = true
	local mb = UI.Button(top, mirror and "MIRROR ON" or "MIRROR OFF", mirror and T.Ocean or T.Grey, UDim2.new(0.4, -4, 1, -4), function()
		mirror = not mirror
		clearGhost()
		renderTab()
	end)
	mb.TextScaled = true
	UI.Button(top, "TURN", T.Ocean, UDim2.new(0.26, -4, 1, -4), function()
		rotate(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -15 or 15)
	end)
	local tabs = buttonRow(body, 2, 34)
	for _, cat in ipairs(ShipPartsCfg.Categories) do
		local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(0.2, -5, 1, 0), BackgroundColor3 = cat == category and T.Gold:Lerp(T.PanelDeep, 0.4) or T.PanelDeep, Parent = tabs })
		UI.Stroke(b, T.Edge, 2)
		UI.Icon(b, CAT_ICON[cat] or "gear", 22, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		UI.Tooltip(b, function()
			return cat == "Hull" and "Blocks (stretch them into decks, castles, cabins)" or cat
		end)
		b.Activated:Connect(function()
			category = cat
			renderTab()
		end)
	end
	local list = UI.Scroll(body, UDim2.new(1, 0, 1, -84))
	list.LayoutOrder = 3
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 120), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = list })
	for i, id in ipairs(ShipPartsCfg.Order) do
		local def = Parts[id]
		if def.category == category and not (def.faction and State.profile and State.profile.faction ~= def.faction) then
			local on = id == pick
			local card = New("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, BackgroundColor3 = on and T.Gold:Lerp(T.PanelDeep, 0.55) or T.PanelDeep, Parent = list })
			UI.Corner(card, 8)
			UI.Stroke(card, on and T.Gold or T.Edge, on and 3 or 2)
			UI.Tactile(card)
			local m = ShipModel.BuildPart({ id = id, x = 0, y = 0, z = 0, r = 0 }, CFrame.new())
			local vp = UI.ModelViewOf(card, m, 66, 0.6)
			vp.AnchorPoint = Vector2.new(0.5, 0)
			vp.Position = UDim2.new(0.5, 0, 0, 2)
			UI.Text(card, def.name, 12, T.Text, "Display", { Position = UDim2.fromOffset(4, 68), Size = UDim2.new(1, -8, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true })
			local costRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 32), Parent = card })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(60, 15), CellPadding = UDim2.fromOffset(2, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = costRow })
			for _, k in ipairs(sortedKeys(def.cost)) do
				local v = def.cost[k]
				if v > 0 then
					chip(costRow, iconOf(k), k == "beli" and UI.Format(v) or ("x" .. v), owned(k) >= v and T.Text or T.Red, 14)
				end
			end
			card.Activated:Connect(function()
				pick = id
				selItem = nil
				paintSelection()
				clearGhost()
				renderTab()
				status("Click a deck or a roof to place " .. def.name .. "  •  R turns  •  M mirror", T.Green)
			end)
		end
	end
end

local function paintTab(body)
	local faction = State.profile and State.profile.faction
	if faction == "Marine" then
		local t = UI.Text(body, "Marine ships sail in the Marine livery (white hull, navy rails). Deck color can still be changed.", 12, T.TextSoft, "Semi",
			{ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 0 })
		t.TextWrapped = true
	end
	local zones = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 1, Parent = body })
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 38), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = zones })
	for i, z in ipairs(ShipHull.Zones) do
		local b = New("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, BackgroundColor3 = T.PanelDeep, Parent = zones })
		UI.Stroke(b, z == zone and T.Gold or T.Edge, z == zone and 3 or 2)
		local sw = New("Frame", { BackgroundColor3 = ShipHull.Color(work.paint[z]), Position = UDim2.fromOffset(5, 7), Size = UDim2.fromOffset(24, 24), Parent = b })
		UI.Stroke(sw, Color3.new(0, 0, 0), 1)
		UI.Text(b, ShipHull.ZoneName[z], 11, z == zone and T.Gold or T.Text, "Display", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -36, 1, 0), TextWrapped = false })
		b.Activated:Connect(function()
			zone = z
			renderTab()
		end)
	end
	local pal = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 132), LayoutOrder = 2, Parent = body })
	New("UIGridLayout", { CellSize = UDim2.new(1 / 6, -6, 0, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pal })
	for i, hex in ipairs(ShipHull.Palette) do
		local on = work.paint[zone] == hex
		local b = New("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, BackgroundColor3 = ShipHull.Color(hex), Parent = pal })
		UI.Stroke(b, on and T.Gold or Color3.new(0, 0, 0), on and 3 or 1)
		UI.Tactile(b)
		b.Activated:Connect(function()
			snapshot()
			work.paint[zone] = hex
			changed(true, zone == "sail")
			refreshStats()
			renderTab()
		end)
	end
	local row = buttonRow(body, 3, 44)
	UI.Button(row, "RANDOM", T.Ocean, UDim2.new(0.5, -3, 1, -4), function()
		snapshot()
		local pal2 = ShipHull.Palette
		for _, z in ipairs(ShipHull.Zones) do
			work.paint[z] = pal2[math.random(#pal2)]
		end
		work.paint.sail = math.random() < 0.6 and "#F6F1E2" or work.paint.sail
		changed(true, true)
		refreshStats()
		renderTab()
	end)
	UI.Button(row, "DEFAULT", T.Grey, UDim2.new(0.5, -3, 1, -4), function()
		snapshot()
		work.paint = table.clone(ShipHull.DefaultPaint)
		changed(true, true)
		refreshStats()
		renderTab()
	end)
end

-- the selected part: turn / size / raise / mirror / clone / delete (right side of the screen)
local function itemCard()
	if ui.itemCard then
		ui.itemCard:Destroy()
		ui.itemCard = nil
	end
	local it = selItem and work.items[selItem]
	if not (it and gui) then
		return
	end
	local rule = ShipHull.ScaleRule(it.id)
	local card = UI.Card(gui, UDim2.fromOffset(280, 0), T.Panel)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -12, 0, 12)
	UI.Pad(card, 10)
	UI.List(card, nil, 6)
	ui.itemCard = card
	UI.Text(card, Parts[it.id].name, 16, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, TextWrapped = false })
	local o = 1
	local function nexto()
		o += 1
		return o
	end
	stepper(card, nexto(), "TURN", (it.r or 0) .. "", function()
		editSelected(function(x)
			x.r = ((x.r or 0) - 15) % 360
		end)
	end, function()
		editSelected(function(x)
			x.r = ((x.r or 0) + 15) % 360
		end)
	end)
	local function scaleRow(label, key)
		stepper(card, nexto(), label, fmt(it[key] or 1) .. "x", function()
			editSelected(function(x, r)
				x[key] = math.max(r.min, snap((x[key] or 1) - 0.25, 0.05))
				if r.axes == "u" then
					x.sy, x.sz = x.sx, x.sx
				end
			end)
		end, function()
			editSelected(function(x, r)
				x[key] = math.min(r.max, snap((x[key] or 1) + 0.25, 0.05))
				if r.axes == "u" then
					x.sy, x.sz = x.sx, x.sx
				end
			end)
		end)
	end
	if rule.axes == "u" then
		scaleRow("SIZE", "sx")
	else
		scaleRow(Parts[it.id].thrust and "SAIL W" or "WIDTH", "sx")
		scaleRow(Parts[it.id].thrust and "MAST H" or "HEIGHT", "sy")
		if rule.axes == "xyz" then
			scaleRow("LENGTH", "sz")
		end
	end
	stepper(card, nexto(), "HEIGHT POS", fmt(it.y), function()
		editSelected(function(x)
			x.y = x.y - 0.5
		end)
	end, function()
		editSelected(function(x)
			x.y = x.y + 0.5
		end)
	end)
	local r1 = buttonRow(card, nexto(), 40)
	local mb = UI.Button(r1, it.m and "MIRROR ON" or "MIRROR OFF", it.m and T.Ocean or T.Grey, UDim2.new(0.5, -3, 1, -4), function()
		if Parts[it.id].max then
			status("Only one of this part", T.Red)
			return
		end
		editSelected(function(x)
			x.m = not x.m or nil
		end)
	end)
	mb.TextScaled = true
	UI.Button(r1, "CLONE", T.Green, UDim2.new(0.5, -3, 1, -4), function()
		if Parts[it.id].max then
			status("Only one of this part", T.Red)
			return
		end
		snapshot()
		local c = table.clone(it)
		c.z = c.z + 3
		table.insert(work.items, c)
		selItem = #work.items
		changed(false, true)
		refreshStats()
		renderTab()
	end)
	local r2 = buttonRow(card, nexto(), 40)
	UI.Button(r2, "DELETE", T.Red, UDim2.new(0.5, -3, 1, -4), deleteSelected)
	UI.Button(r2, "DONE", T.Grey, UDim2.new(0.5, -3, 1, -4), function()
		selectItem(nil)
	end)
	UI.Text(card, "Drag the part to move it  •  R turn  •  X delete", 10, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nexto(), TextWrapped = false })
end

function renderTab()
	if not ui.body then
		return
	end
	clearKids(ui.body)
	for name, b in pairs(ui.tabs) do
		UI.SetButtonColor(b, name == tab and T.Gold or T.Grey)
	end
	if tab == "hull" then
		hullTab(ui.body)
	elseif tab == "parts" then
		partsTab(ui.body)
	else
		paintTab(ui.body)
	end
	itemCard()
end

local function buildPanel()
	if gui then
		gui:Destroy()
	end
	ui = {}
	gui = New("ScreenGui", { Name = "GVShipyard", ResetOnSpawn = false, DisplayOrder = 25, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local vs = workspace.CurrentCamera.ViewportSize
	New("UIScale", { Scale = math.clamp(vs.Y / 820, 0.6, 1.15), Parent = gui })
	local panel = UI.Card(gui, UDim2.new(0, 380, 1, -24), T.Panel)
	panel.Position = UDim2.fromOffset(12, 12)
	UI.Pad(panel, 10)
	UI.List(panel, nil, 6)

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = panel })
	UI.Icon(top, "ship", 30)
	UI.Text(top, "SHIPYARD", 20, T.Gold, "Display", { Position = UDim2.fromOffset(36, 0), Size = UDim2.fromOffset(150, 30), TextWrapped = false })
	ui.nameBox = New("TextBox", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(160, 28), ClearTextOnFocus = false,
		Text = "", PlaceholderText = "Ship name", FontFace = UI.Fonts.Body, TextScaled = true, TextColor3 = T.Text, BackgroundColor3 = T.PanelDeep, Parent = top })
	UI.Stroke(ui.nameBox, T.Edge, 2)
	ui.nameBox.FocusLost:Connect(function()
		local n = ui.nameBox.Text
		if #n > 0 and work and n ~= work.name then
			if Net.Request("BuildRename", { name = n }).ok then
				work.name = n
			end
		end
	end)

	-- stats 2 x 4
	local stats = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 2, Parent = panel })
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -5, 0, 39), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
	ui.stats = {}
	local defs = {
		{ "hp", "HP", T.Red }, { "speed", "SPEED", T.Ocean }, { "guns", "GUNS", T.Orange or T.Gold }, { "crew", "BUNKS", T.Green },
		{ "tons", "TONS", T.Gold }, { "draft", "DRAFT", T.Ocean }, { "free", "FREEBRD", T.Ocean }, { "stab", "STABLE", T.Green },
	}
	for i, s in ipairs(defs) do
		local box = New("Frame", { LayoutOrder = i, BackgroundColor3 = s[3]:Lerp(T.PanelDeep, 0.72), Parent = stats })
		UI.Stroke(box, s[3], 2)
		UI.Text(box, s[2], 9, s[3]:Lerp(Color3.new(1, 1, 1), 0.4), "Display", { Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 11), TextWrapped = false })
		ui.stats[s[1]] = UI.Text(box, "0", 15, T.Text, "Number", { Position = UDim2.fromOffset(3, 16), Size = UDim2.new(1, -6, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true })
	end
	ui.ready = UI.Text(panel, "", 11, T.Green, "Display", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3 })
	ui.ready.TextWrapped = true

	-- HULL / PARTS / PAINT
	local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = panel })
	UI.List(tabs, Enum.FillDirection.Horizontal, 6)
	ui.tabs = {}
	for _, t in ipairs({ { "hull", "HULL" }, { "parts", "PARTS" }, { "paint", "PAINT" } }) do
		ui.tabs[t[1]] = UI.Button(tabs, t[2], T.Grey, UDim2.new(1 / 3, -4, 1, -4), function()
			tab = t[1]
			pick = tab == "parts" and pick or nil
			clearGhost()
			changed(true, false) -- handles show only on the HULL tab
			renderTab()
		end)
	end

	ui.body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -362), LayoutOrder = 5, ClipsDescendants = true, Parent = panel })
	UI.List(ui.body, nil, 5)

	ui.cost = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 6, Parent = panel })
	UI.List(ui.cost, Enum.FillDirection.Horizontal, 6).VerticalAlignment = Enum.VerticalAlignment.Center
	ui.status = UI.Text(panel, "", 12, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 7 })

	local b1 = buttonRow(panel, 8, 46)
	ui.saveBtn = UI.Button(b1, "SAVE", T.Green, UDim2.new(0.6, -3, 1, -6), function()
		save()
	end)
	UI.Button(b1, "UNDO", T.Grey, UDim2.new(0.4, -3, 1, -6), undo)
	local b2 = buttonRow(panel, 9, 46)
	UI.Button(b2, "⛵ LAUNCH", T.Ocean, UDim2.new(0.6, -3, 1, -6), function()
		local function go()
			local res = Net.Request("LaunchShip", { slot = State.build.slot })
			if not res.ok then
				status(res.msg or "Cannot launch", T.Red)
			else
				UI.Banner("Set Sail!", "W/S sails  •  A/D steer  •  click water to fire cannons", T.Ocean)
			end
		end
		if isDirty() then
			save(go)
		else
			go()
		end
	end)
	UI.Button(b2, "EXIT", T.Grey, UDim2.new(0.4, -3, 1, -6), function()
		if isDirty() then
			UI.Confirm("Leave without saving?\nYour changes are lost.", function()
				Net.Request("BuildExit")
			end, nil, "Leave", "Stay")
		else
			Net.Request("BuildExit")
		end
	end)

	local hint = UI.Text(gui, UI.IsMobile and "Drag: turn  •  Pinch: zoom  •  Tap: place / select"
		or "Right-drag: turn  •  Wheel: zoom  •  WASD / Q E: move  •  R: turn part  •  M: mirror  •  X: delete  •  Ctrl+Z: undo",
		12, T.Text, "Semi", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 190, 1, -10), Size = UDim2.fromOffset(720, 16), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	hint.BackgroundTransparency = 0.5
	hint.BackgroundColor3 = T.PanelDeep
	renderTab()
	refreshStats()
end

-- ===== mouse: handles, placing, selecting, dragging =====
local function handleUnder(screenPos)
	if not view.handles then
		return nil
	end
	local hit = cast(screenPos, { view.handles })
	return hit and hit.Instance
end

local function startHandleDrag(h, screenPos)
	local kind, ni, side = h:GetAttribute("Kind"), h:GetAttribute("Node"), h:GetAttribute("Side")
	local cf = shipCf()
	local axis
	if kind == "w" then
		axis = cf.RightVector * side
	elseif kind == "d" then
		axis = -cf.UpVector
	else
		axis = cf.LookVector * (kind == "rake" and side or 1)
	end
	local t0 = axisParam(rayAt(screenPos), h.Position, axis)
	if not t0 then
		return
	end
	if ni and ni > 0 then
		selNode = ni
	end
	local nd = ni and ni > 0 and nodes()[ni]
	drag = { kind = "handle", hk = kind, node = ni, side = side, p0 = h.Position, axis = axis, t0 = t0, before = ShipHull.Clone(work),
		v0 = kind == "w" and nd.w or kind == "d" and nd.d or kind == "z" and nd.z or (side > 0 and (work.hull.bow or 0) or (work.hull.stern or 0)) }
	renderTab()
end

local function updateHandleDrag(screenPos)
	local t = axisParam(rayAt(screenPos), drag.p0, drag.axis)
	if not t then
		return
	end
	local v = drag.v0 + (t - drag.t0)
	local n = nodes()
	local nd = drag.node and drag.node > 0 and n[drag.node]
	local before = nd and (nd.w .. nd.d .. nd.z) or ((work.hull.bow or 0) .. ":" .. (work.hull.stern or 0))
	if drag.hk == "w" then
		nd.w = math.clamp(snap(v, 0.5), 0.5, ShipHull.MaxBeam / 2)
	elseif drag.hk == "d" then
		nd.d = math.clamp(snap(v, 0.5), 1, ShipHull.MaxDepth)
	elseif drag.hk == "z" then
		local lo = n[drag.node - 1].z + 2
		local hi = n[drag.node + 1] and n[drag.node + 1].z - 2 or ShipHull.MaxLength
		nd.z = math.clamp(snap(v, 1), lo, hi)
	elseif drag.side > 0 then
		work.hull.bow = math.clamp(snap(v, 1), 0, 16)
	else
		work.hull.stern = math.clamp(snap(v, 1), 0, 10)
	end
	local now = nd and (nd.w .. nd.d .. nd.z) or ((work.hull.bow or 0) .. ":" .. (work.hull.stern or 0))
	if now ~= before then
		drag.moved = true
		changed(true, false)
	end
end

local function updateItemDrag(screenPos)
	local it = work.items[drag.idx]
	if not it then
		drag = nil
		return
	end
	local spot = surfaceSpot(screenPos, drag.idx)
	if spot and (spot.X ~= it.x or spot.Y ~= it.y or spot.Z ~= it.z) then
		if not drag.moved then
			table.insert(undoStack, drag.before)
		end
		drag.moved = true
		it.x, it.y, it.z = spot.X, spot.Y, spot.Z
		if math.abs(it.x) < 0.5 then
			it.m = nil
		end
		changed(false, true)
	end
end

local function pointerDown(screenPos)
	if not work then
		return
	end
	local h = tab == "hull" and handleUnder(screenPos)
	if h then
		startHandleDrag(h, screenPos)
		return
	end
	if tab == "parts" and pick then
		local spot, why = surfaceSpot(screenPos)
		if spot then
			placeAt(spot)
		elseif why then
			status(why, T.Red)
		end
		return
	end
	local idx = itemUnder(screenPos)
	if idx then
		if tab ~= "parts" then
			tab = "parts"
			changed(true, false)
		end
		selectItem(idx)
		drag = { kind = "item", idx = idx, before = ShipHull.Clone(work) }
	elseif selItem then
		selectItem(nil)
	end
end

local function pointerUp()
	if not drag then
		return
	end
	if drag.kind == "handle" and drag.moved then
		table.insert(undoStack, drag.before)
		renderTab()
	end
	if drag.moved then
		refreshStats()
		if drag.kind == "item" then
			renderTab()
		end
	end
	drag = nil
end

local function hover(screenPos)
	if drag then
		if drag.kind == "handle" then
			updateHandleDrag(screenPos)
		else
			updateItemDrag(screenPos)
		end
		return
	end
	if tab == "parts" and pick then
		local spot, why = surfaceSpot(screenPos)
		if spot then
			showGhost(spot)
		else
			clearGhost()
			if why then
				status(why, T.Red)
			end
		end
	end
end

-- ===== free camera =====
local function plotCenter()
	return shipCf() * Vector3.new(0, 0, -(hullLength() / 2))
end

local function sinkKeys(_, st, input)
	if st == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
		local k = input.KeyCode
		if k == Enum.KeyCode.R then
			rotate(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -15 or 15)
		elseif k == Enum.KeyCode.X or k == Enum.KeyCode.Delete then
			deleteSelected()
		elseif k == Enum.KeyCode.M then
			if selItem and not pick then
				editSelected(function(x)
					x.m = not x.m or nil
				end)
			else
				mirror = not mirror
				clearGhost()
				renderTab()
			end
		elseif k == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			undo()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function startCamera()
	local o = State.build.origin
	cam.target = plotCenter()
	local look = o.LookVector
	cam.yaw = math.atan2(-look.X, -look.Z) + math.rad(140)
	cam.pitch, cam.dist = 0.5, math.clamp(hullLength() * 1.5 + 20, 45, 150)
	pcall(UI.CloseAll) -- the Shipwright window (and its blur) must not stay behind the builder
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
	if not UserInputService:GetFocusedTextBox() and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		local K = UserInputService
		local fwd = Vector3.new(-math.sin(cam.yaw), 0, -math.cos(cam.yaw))
		local right = Vector3.new(math.cos(cam.yaw), 0, -math.sin(cam.yaw))
		mv += (K:IsKeyDown(Enum.KeyCode.W) and fwd or Vector3.zero) - (K:IsKeyDown(Enum.KeyCode.S) and fwd or Vector3.zero)
		mv += (K:IsKeyDown(Enum.KeyCode.D) and right or Vector3.zero) - (K:IsKeyDown(Enum.KeyCode.A) and right or Vector3.zero)
		mv += Vector3.new(0, (K:IsKeyDown(Enum.KeyCode.E) and 1 or 0) - (K:IsKeyDown(Enum.KeyCode.Q) and 1 or 0), 0)
	end
	local center = plotCenter()
	local half = Vector3.new(ShipHull.MaxBeam, 30, ShipHull.MaxLength) / 2 + Vector3.new(30, 10, 30)
	local rel = State.build.origin:VectorToObjectSpace(cam.target + mv * dt * 45 - center)
	rel = Vector3.new(math.clamp(rel.X, -half.X, half.X), math.clamp(rel.Y, -half.Y, half.Y), math.clamp(rel.Z, -half.Z, half.Z))
	cam.target = center + State.build.origin:VectorToWorldSpace(rel)
	c.CFrame = CFrame.new(cam.target) * CFrame.Angles(0, cam.yaw, 0) * CFrame.Angles(-cam.pitch, 0, 0) * CFrame.new(0, 0, cam.dist)
end

local function teardown()
	clearGhost()
	for _, k in ipairs({ "hull", "items", "handles", "water", "selHl" }) do
		clear(k)
	end
	if gui then
		gui:Destroy()
		gui = nil
		ui = {}
	end
end

function Builder.OnState(data)
	local was = State.build.active
	State.build = data
	if data.active then
		local fresh = not was or adoptSave or not work
		saved = ShipHull.Clone(data.design)
		if saved.v ~= 2 then
			saved = ShipHull.FromV1(saved) -- the server converts on enter; this only guards an old push
		end
		if fresh then
			work = ShipHull.Clone(saved)
			if not was then
				undoStack = {}
				selItem, pick, selNode = nil, nil, 2
			end
		end
		adoptSave = false
		if not gui then
			buildPanel()
		end
		if not was then
			startCamera()
		end
		rebuildAll()
		renderTab()
	else
		teardown()
		work, saved = nil, nil
		drag = nil
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
			pointerDown(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			pick = nil
			clearGhost()
			selectItem(nil)
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cam.turning = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointerUp()
		elseif input.UserInputType == Enum.UserInputType.Touch and touchStart and State.build.active and not processed then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if (p - touchStart).Magnitude < 12 then -- a tap, not a camera drag (InputObject.Position has no top-bar inset)
				local inset = game:GetService("GuiService"):GetGuiInset()
				pointerDown(p + inset)
				pointerUp()
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
			cam.pitch = math.clamp(cam.pitch + input.Delta.Y * 0.006, -1.1, 1.45)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			cam.dist = math.clamp(cam.dist * (1 - input.Position.Z * 0.1), 14, 200)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchStart and not processed then
			cam.yaw -= input.Delta.X * 0.01
			cam.pitch = math.clamp(cam.pitch + input.Delta.Y * 0.008, -1.1, 1.45)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, st)
		if State.build.active and st == Enum.UserInputState.Change then
			cam.dist = math.clamp(cam.dist / math.max(scale, 0.5) ^ 0.15, 14, 200)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not State.build.active or not State.build.origin or not work then
			return
		end
		stepCamera(dt)
		if not UI.IsMobile and not cam.turning then
			hover(UserInputService:GetMouseLocation())
		end
		-- the preview follows the edits at most ~12 times a second
		local now = os.clock()
		if dirty.hull and now - last.hull > 0.08 then
			rebuildHull()
			refreshStats()
		end
		if dirty.items and now - last.items > 0.08 then
			rebuildItems()
		end
	end)
	State.Changed:Connect(function(kind)
		if kind == "profile" and State.build.active and work then
			refreshStats()
			if tab == "parts" then
				renderTab()
			end
		end
	end)
end

return Builder
