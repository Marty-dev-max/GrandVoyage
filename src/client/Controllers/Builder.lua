-- Builder (client): free-form ship building: place blocks on the grid, rotate, delete, see weight/speed, launch
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService") -- InputObject.Position excludes the top-bar inset; ViewportPointToRay needs it
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
local Parts = ShipPartsCfg.Parts
local selected = "PlankBlock"
local rotation = 0
local deleteMode = false
local ghost
local panel
local statsLabel
local lastCell

local function costText(cost)
	local parts = {}
	for k, v in pairs(cost) do
		if k == "beli" then
			table.insert(parts, 1, "🪙" .. v)
		else
			local d = ItemDB.Get(k)
			table.insert(parts, (d and d.name or k) .. " x" .. v)
		end
	end
	return table.concat(parts, ", ")
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	lastCell = nil
end

local function makeGhost(cell)
	clearGhost()
	local b = State.build
	local p = { id = selected, x = cell.X, y = cell.Y, z = cell.Z, r = rotation }
	ghost = ShipModel.BuildPart(p, b.origin * ShipModel.LocalCFrame(p))
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.7
	hl.OutlineColor = deleteMode and T.Red or T.Green
	hl.FillColor = deleteMode and T.Red or T.Green
	hl.Parent = ghost
	ghost.Parent = workspace
	lastCell = cell
end

-- Find the grid cell under the mouse / finger
local function cellFromScreen(pos)
	local b = State.build
	if not b.active or not b.origin then
		return nil
	end
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { player.Character }
	if ghost then
		table.insert(ex, ghost)
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return nil
	end
	local offset = deleteMode and -hit.Normal * (G * 0.45) or hit.Normal * (G * 0.45)
	local localPos = b.origin:PointToObjectSpace(hit.Position + offset)
	local cell = Vector3.new(math.floor(localPos.X / G), math.floor(localPos.Y / G), math.floor(-localPos.Z / G))
	local size = GameConfig.Ship.PlotSize
	if cell.X < 0 or cell.Y < 0 or cell.Z < 0 or cell.X >= size.X or cell.Y >= size.Y or cell.Z >= size.Z then
		return nil
	end
	return cell
end

local function act(cell)
	if not cell then
		return
	end
	task.spawn(function()
		local res
		if deleteMode then
			res = Net.Request("BuildRemove", { x = cell.X, y = cell.Y, z = cell.Z })
		else
			res = Net.Request("BuildPlace", { id = selected, x = cell.X, y = cell.Y, z = cell.Z, r = rotation })
		end
		if not res.ok and res.msg and not res.throttled then
			UI.Toast(res.msg, "bad")
		end
	end)
end

local function refreshStats()
	if not statsLabel then
		return
	end
	local st = State.build.stats
	if not st then
		return
	end
	statsLabel.Text = string.format(
		"⚖️ Weight %d   ❤️ HP %d   🧩 %d parts\n🌬️ Speed in wind %d   ☠️ Doldrums %d\n💣 Cannons %d   👥 Crew %d/%d   %s",
		st.weight,
		st.hp,
		st.parts,
		st.speedLane,
		st.speedCalm,
		st.cannons,
		st.crew,
		st.crewCap,
		st.valid and "✅ Seaworthy" or "❌ Needs a helm + sail"
	)
end

local function buildPanel()
	if panel then
		panel:Destroy()
	end
	panel = New("Frame", { Name = "BuildPanel", Position = UDim2.fromOffset(16, 150), Size = UDim2.fromOffset(340, 560), BackgroundColor3 = T.Panel, Parent = UI.Root })
	UI.Corner(panel, 18)
	UI.Stroke(panel, T.Text, 3)
	UI.Pad(panel, 10)
	UI.List(panel, nil, 8)
	UI.Text(panel, "🔨 SHIPYARD", 28, T.Gold, "Display")
	statsLabel = UI.Text(panel, "", 15, T.Text, "Semi", { Size = UDim2.new(1, 0, 0, 62) })
	local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = panel })
	UI.List(tabs, Enum.FillDirection.Horizontal, 4)
	local list = UI.Scroll(panel, UDim2.new(1, 0, 0, 300))
	UI.List(list, nil, 6)
	local function showCategory(cat)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, id in ipairs(ShipPartsCfg.Order) do
			local def = Parts[id]
			if def.category == cat then
				local card = UI.Card(list, UDim2.new(1, -10, 0, 58), id == selected and T.OceanDark or nil)
				UI.Pad(card, 6)
				local btn = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = card })
				UI.Text(card, def.name, 16, T.Text, "Display", { Size = UDim2.new(1, 0, 0, 20) })
				local extra = ""
				if def.thrust then
					extra = "  sail " .. def.thrust
				elseif def.oar then
					extra = "  oar " .. def.oar
				elseif def.cannon then
					extra = "  dmg " .. def.cannon.damage
				elseif def.crew then
					extra = "  crew +" .. def.crew
				end
				UI.Text(card, "weight " .. def.weight .. "  HP " .. def.hp .. extra .. "\n" .. costText(def.cost), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30) })
				btn.Activated:Connect(function()
					selected = id
					deleteMode = false
					clearGhost()
					showCategory(cat)
				end)
			end
		end
	end
	for _, cat in ipairs(ShipPartsCfg.Categories) do
		UI.Button(tabs, cat, T.OceanDark, UDim2.fromOffset(60, 32), function()
			showCategory(cat)
		end)
	end
	showCategory("Hull")
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = panel })
	UI.List(row, Enum.FillDirection.Horizontal, 6)
	UI.Button(row, "↻ Rotate (R)", T.Ocean, UDim2.fromOffset(100, 40), function()
		rotation = (rotation + 1) % 4
		clearGhost()
	end)
	local delBtn = UI.Button(row, "🗑 Delete (X)", T.Red, UDim2.fromOffset(100, 40), nil)
	delBtn.Activated:Connect(function()
		deleteMode = not deleteMode
		clearGhost()
		UI.Toast(deleteMode and "Delete mode" or "Place mode")
	end)
	UI.Button(row, "✏️ Name", T.Purple, UDim2.fromOffset(100, 40), function()
		local win = UI.Window("Rename", "Name Your Ship", UDim2.fromOffset(440, 230), T.Purple, "✏️")
		local box = New("TextBox", { Size = UDim2.new(1, 0, 0, 44), Text = State.build.design and State.build.design.name or "", FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, BackgroundColor3 = T.PanelDeep, Parent = win.body })
		UI.Corner(box, 10)
		local _, h = UI.Button(win.body, "Save", T.Green, UDim2.fromOffset(160, 44), function()
			Net.Request("BuildRename", { name = box.Text })
			win:Destroy()
		end)
		h.Position = UDim2.fromOffset(0, 60)
	end)
	local row2 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = panel })
	UI.List(row2, Enum.FillDirection.Horizontal, 6)
	UI.Button(row2, "⛵ Launch!", T.Green, UDim2.fromOffset(160, 44), function()
		local res = Net.Request("LaunchShip", { slot = State.build.slot })
		if not res.ok then
			UI.Toast(res.msg or "Cannot launch", "bad")
		else
			UI.Banner("Set Sail!", "W/S sails  •  A/D steer  •  click water to fire cannons", T.Ocean)
		end
	end)
	UI.Button(row2, "Exit Yard", T.Grey, UDim2.fromOffset(150, 44), function()
		Net.Request("BuildExit")
	end)
	refreshStats()
end

function Builder.OnState(data)
	State.build = data
	if data.active then
		if not panel then
			buildPanel()
		end
		refreshStats()
		clearGhost()
	else
		clearGhost()
		if panel then
			panel:Destroy()
			panel = nil
		end
	end
end

function Builder.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.build.active then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
			clearGhost()
		elseif input.KeyCode == Enum.KeyCode.X then
			deleteMode = not deleteMode
			clearGhost()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			act(cellFromScreen(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()))
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local was = deleteMode
			deleteMode = true
			act(cellFromScreen(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()))
			deleteMode = was
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not State.build.active or UI.IsMobile then
			return
		end
		local cell = cellFromScreen(UserInputService:GetMouseLocation())
		if cell then
			if not lastCell or cell ~= lastCell then
				makeGhost(cell)
			end
		else
			clearGhost()
		end
	end)
	-- ShipStats is kept here for future client-side previews
	local _ = ShipStats
end

return Builder
