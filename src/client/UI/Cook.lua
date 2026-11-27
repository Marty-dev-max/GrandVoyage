-- Cooking window (Mastery v2 M2). Opened by a campfire's "Cook" prompt (server push OpenPanel Cook).
-- Top: Cook Mastery level + XP and the four ingredients you carry. Grid: every recipe (Config/Recipes) with what it
-- needs (green = you have it), locked ones show the Cook level they need. COOK -> CookStart -> Timing Bar ->
-- CookFinish -> the dish with 1-3 stars.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local MasteryCfg = require(Shared.Config.Mastery)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.UIKit)
local TB = require(script.Parent.TimingBar)
local State = require(script.Parent.Parent.State)

local Cook = {}
local T = UI.Theme
local New = UI.New
local COLOR = MasteryCfg.Fields.Cook.color

local function count(id)
	local n = 0
	for _, e in ipairs(State.profile and State.profile.inventory or {}) do
		if e.id == id then
			n += e.qty or 1
		end
	end
	return n
end

local function cookLevel()
	local m = State.profile and State.profile.mastery and State.profile.mastery.Cook
	return (m and m.lv) or 1, (m and m.xp) or 0
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function Cook.Open()
	local win = UI.Window("Cook", "Cooking", UDim2.fromOffset(980, 620), COLOR, "meat_m")
	local body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	local busy = false
	local render

	local function cook(recipe)
		if busy or TB.Busy() then
			return
		end
		busy = true
		local res = Net.Request("CookStart", { recipe = recipe.id })
		if not res.ok or not res.data then
			busy = false
			UI.Toast(res.msg or "Can't cook that", "bad")
			return
		end
		local def = ItemDB.Get(recipe.id)
		local t = TB.Run(res.data, { title = "Cooking " .. (def and def.name or recipe.id) .. "...", color = COLOR })
		local fin = Net.Request("CookFinish", { token = res.data.token, t = t })
		busy = false
		if fin.msg then
			UI.Toast(fin.msg, fin.ok and "good" or "bad")
		end
		task.delay(0.4, function()
			if UI.IsOpen("Cook") then
				render()
			end
		end)
	end

	render = function()
		clear(body)
		local lv, xp = cookLevel()
		-- header: level + ingredients
		local head = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.new(1, 0, 0, 74), Parent = body })
		UI.Corner(head, 10)
		UI.Stroke(head, COLOR:Lerp(T.Edge, 0.4), 2)
		UI.Icon(head, "meat_m", 52, { Position = UDim2.fromOffset(12, 11) })
		UI.Text(head, "COOK LV." .. lv, 18, COLOR, "Display", { Position = UDim2.fromOffset(74, 12), Size = UDim2.fromOffset(220, 24), TextXAlignment = Enum.TextXAlignment.Left })
		local maxed = lv >= MasteryCfg.Max
		local bar = UI.Bar(head, COLOR, UDim2.fromOffset(200, 14), nil, 0)
		bar.back.Position = UDim2.fromOffset(74, 44)
		pcall(function()
			bar:Set(maxed and 1 or math.clamp(xp / MasteryCfg.ToNext(lv), 0, 1), maxed and "MAX" or (math.floor(xp) .. " / " .. MasteryCfg.ToNext(lv)))
		end)
		local ings = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 11), Size = UDim2.fromOffset(560, 52), Parent = head })
		UI.List(ings, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
		for i, id in ipairs(Recipes.Ingredients) do
			local def = ItemDB.Get(id)
			local chip = New("Frame", { BackgroundColor3 = T.Panel, Size = UDim2.fromOffset(130, 52), LayoutOrder = i, Parent = ings })
			UI.Corner(chip, 8)
			UI.Icon(chip, UI.ItemIconName(def) or "bag", 36, { Position = UDim2.fromOffset(6, 8) })
			UI.Text(chip, def and def.name or id, 11, T.TextSoft, "Semi", { Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Text(chip, "x" .. count(id), 16, T.Text, "Number", { Position = UDim2.fromOffset(46, 24), Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Left })
		end
		UI.Text(body, "Better timing = tastier food (2-3 stars: stronger heals + a buff). Ingredients: General Store, beasts, ships at sea.", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(4, 80), Size = UDim2.new(1, -8, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
		-- recipes
		local sc = UI.Scroll(body, UDim2.new(1, 0, 1, -106))
		sc.Position = UDim2.fromOffset(0, 106)
		New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = sc })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(222, 236), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
		for _, r in ipairs(Recipes.List) do
			local def = ItemDB.Get(r.id)
			local open = lv >= r.lv
			local can = open
			local c = New("Frame", { BackgroundColor3 = T.PanelDeep, LayoutOrder = r.order, Parent = sc })
			UI.Corner(c, 10)
			UI.Stroke(c, open and COLOR:Lerp(T.Edge, 0.3) or T.Edge, 2)
			local ic = UI.Icon(c, UI.ItemIconName(def) or "meat_s", 56, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10) })
			if ic and ic:IsA("ImageLabel") and not open then
				ic.ImageTransparency = 0.6
			end
			UI.Text(c, def and def.name or r.id, 15, open and T.Text or T.TextSoft, "Display", { Position = UDim2.fromOffset(6, 70), Size = UDim2.new(1, -12, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			UI.Text(c, (r.tier == "Feast" and "PARTY FEAST" or ("SIZE " .. r.tier)), 11, COLOR, "Display", { Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
			local needs = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 112), Size = UDim2.new(1, -16, 0, 60), Parent = c })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(98, 26), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = needs })
			for i, need in ipairs(Recipes.NeedsList(r)) do
				local have = count(need.id)
				local ok = have >= need.n
				can = can and ok
				local idef = ItemDB.Get(need.id)
				local row = New("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = needs })
				UI.Icon(row, UI.ItemIconName(idef) or "bag", 24, { Position = UDim2.fromOffset(0, 1) })
				UI.Text(row, have .. "/" .. need.n, 13, ok and T.Green or T.Red, "Number", { Position = UDim2.fromOffset(28, 3), Size = UDim2.fromOffset(68, 20), TextXAlignment = Enum.TextXAlignment.Left })
			end
			if open then
				local _, holder = UI.Button(c, "COOK", can and T.Green or Color3.fromRGB(110, 110, 120), UDim2.fromOffset(150, 40), function()
					if can then
						task.spawn(cook, r)
					else
						UI.Toast("Not enough ingredients", "bad")
					end
				end)
				holder.AnchorPoint = Vector2.new(0.5, 1)
				holder.Position = UDim2.new(0.5, 0, 1, -12)
			else
				UI.Text(c, "COOK LV." .. r.lv, 16, T.Gold, "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.new(1, -12, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
			end
		end
	end
	render()
	-- the bag changed (bought, looted, cooked): redraw the counts, at most every half second
	local pending = false
	local conn
	conn = State.Changed:Connect(function(kind)
		if not UI.IsOpen("Cook") then
			conn:Disconnect()
			return
		end
		if kind == "profile" and not pending and not busy then
			pending = true
			task.delay(0.5, function()
				pending = false
				if UI.IsOpen("Cook") and not busy then
					render()
				end
			end)
		end
	end)
end

return Cook
