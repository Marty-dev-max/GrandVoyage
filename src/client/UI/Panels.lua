-- Panels: every window (bag, stats, skills, job, refine, shop, tavern, shipyard, map, bosses,
-- guild, dungeon, party, market, settings)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ClassesCfg = require(Shared.Config.Classes)
local Islands = require(Shared.Config.Islands)
local Dungeons = require(Shared.Config.Dungeons)
local ItemDB = require(Shared.Modules.ItemDB)
local Formulas = require(Shared.Modules.Formulas)
local ShipStats = require(Shared.Modules.ShipStats)
local Rarity = require(Shared.Modules.Rarity)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.UIKit)
local State = require(script.Parent.Parent.State)
local Audio = require(script.Parent.Parent.Controllers.Audio)
local Settings = require(script.Parent.Parent.Controllers.Settings)
local Atmos = require(script.Parent.Parent.Controllers.Atmos)
local CharAnim = require(script.Parent.Parent.Controllers.CharAnim)
local CreatureAnim = require(script.Parent.Parent.Controllers.CreatureAnim)

local Panels = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New
local Classes = ClassesCfg.Classes
local COIN = UI.CurrencyIcon
local FruitsCfg = require(ReplicatedStorage.Shared.Config.Fruits)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)
local PearlsCfg = require(ReplicatedStorage.Shared.Config.Pearls)
local PetsCfg = require(ReplicatedStorage.Shared.Config.Pets)
local DailiesCfg = require(ReplicatedStorage.Shared.Config.Dailies)
local AchievementsCfg = require(ReplicatedStorage.Shared.Config.Achievements)
local QuestsCfg = require(ReplicatedStorage.Shared.Config.Quests)
local TitlesCfg = require(ReplicatedStorage.Shared.Config.Titles)
local TitleStyle = require(script.Parent.TitleStyle)

local function req(action, payload, okSound)
	local res = Net.Request(action, payload)
	if res.msg and not res.throttled then
		UI.Toast(res.msg, res.ok and "good" or "bad")
	end
	if res.ok and okSound then
		Audio.Play(okSound)
	end
	return res
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function onProfile(win, fn)
	local conn = State.Changed:Connect(function(k)
		if k == "profile" then
			fn()
		end
	end)
	win.frame.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

local kindIcon = { Ammo = "🔸", Weapon = "⚔️", Armor = "🧥", Headgear = "🎩", Accessory = "💍", Consumable = "🍖", Material = "🪵", Card = "🃏" }

local function equippedUid(uid)
	if not State.profile then
		return false
	end
	for _, u in pairs(State.profile.equipment) do
		if u == uid then
			return true
		end
	end
	return false
end

local function describe(entry, def)
	local lines = {}
	local tier = ItemDB.Rarity(def)
	table.insert(lines, string.format('<font color="#%s"><b>%s</b></font>  %s', tier.color:ToHex(), string.upper(tier.id), def.kind))
	local g = ItemDB.Grade(def)
	if g then
		table.insert(lines, "Grade: " .. g.name .. "  (x" .. g.mult .. ")")
	end
	if def.atk and def.atk > 0 then
		table.insert(lines, "ATK " .. def.atk)
	end
	if def.matk and def.matk > 0 then
		table.insert(lines, "MATK " .. def.matk)
	end
	if def.def then
		table.insert(lines, "DEF " .. def.def)
	end
	for _, k in ipairs({ "str", "agi", "vit", "int", "dex", "luk" }) do
		if def[k] then
			table.insert(lines, string.upper(k) .. " +" .. def[k])
		end
	end
	if def.reqLevel then
		table.insert(lines, "Requires Lv." .. def.reqLevel .. (def.typeLabel and ("  •  " .. def.typeLabel) or ""))
	end
	if def.kind == "Card" then
		table.insert(lines, "Socket: " .. def.cardSlot)
	end
	if def.desc then
		table.insert(lines, def.desc)
	end
	if def.slots and def.slots > 0 then
		local cards = {}
		for _, c in ipairs(entry.cards or {}) do
			local cd = ItemDB.Get(c)
			table.insert(cards, cd and cd.name or c)
		end
		table.insert(lines, "Card slots " .. #(entry.cards or {}) .. "/" .. def.slots .. (#cards > 0 and (": " .. table.concat(cards, ", ")) or ""))
	end
	table.insert(lines, "Value " .. COIN .. " " .. UI.Format(def.price or 0))
	return table.concat(lines, "\n")
end

-- Rarity tile (Anime-Vanguards style card)
local function itemTile(parent, entry, onClick, selected)
	local def = ItemDB.Get(entry.id)
	if not def then
		return
	end
	local b = New("TextButton", { Size = UDim2.fromOffset(84, 84), Text = "", AutoButtonColor = false, Parent = parent })
	UI.Corner(b, 12)
	local tier = UI.RarityStyle(b, def.rarity, selected)
	UI.Tactile(b)
	local iconId = UI.ItemIconId(def)
	if iconId then
		New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(56, 56), ZIndex = 4, Parent = b })
	else
		UI.Text(b, def.icon or kindIcon[def.kind] or "❔", 30, T.Text, "Display", { Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	UI.Text(b, def.name, 12, T.Text, "Bold", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -3), Size = UDim2.new(1, -6, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 4 })
	if (entry.qty or 1) > 1 then
		UI.Text(b, "x" .. entry.qty, 14, T.Text, "Number", { Position = UDim2.new(1, -44, 0, 2), Size = UDim2.fromOffset(40, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	end
	if (entry.refine or 0) > 0 then
		UI.Text(b, "+" .. entry.refine, 16, T.Gold, "Display", { Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(36, 18), ZIndex = 4 })
	end
	if equippedUid(entry.uid) then
		local e = New("Frame", { BackgroundColor3 = T.Green, Position = UDim2.new(1, -22, 1, -44), Size = UDim2.fromOffset(20, 20), ZIndex = 5, Parent = b })
		UI.Corner(e, 10)
		UI.Stroke(e, T.Edge, 2)
		UI.Text(e, "E", 14, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	end
	UI.Tooltip(b, function()
		return "<b>" .. ItemDB.DisplayName(entry) .. "</b>\n" .. describe(entry, def), tier.color
	end)
	b.Activated:Connect(function()
		onClick(entry, def)
	end)
	return b
end

-- ===================== INVENTORY =====================
function Panels.Inventory(args)
	local win = UI.Window("Inventory", "Inventory", UDim2.fromOffset(1180, 600), T.Ocean, "🎒", { fullscreen = true })
	-- left: your character wearing your gear, with the equipment slots around it (tap a slot to inspect it)
	local charPanel = UI.Card(win.body, UDim2.new(0.36, -10, 1, 0), T.PanelDeep)
	local left = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.38, -10, 1, 0), Parent = win.body })
	local right = UI.Card(win.body, UDim2.new(0.26, 0, 1, 0))
	right.Position = UDim2.new(0.74, 0, 0, 0)
	-- the statue fills the panel (behind the gear slots) so there is plenty of room to drag it round, even on phones
	local stage = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -90), Parent = charPanel })
	New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = T.Ocean:Lerp(Color3.new(1, 1, 1), 0.4), ImageTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1.1, 0.9), Parent = stage })
	local _, refreshChar = UI.CharacterView(stage)
	UI.Text(charPanel, "drag to turn", 12, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Center })
	local slotCols = {}
	for k, side in ipairs({ 0, 1 }) do
		local col = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(side, 0), Position = UDim2.new(side, side == 0 and 10 or -10, 0, 12), Size = UDim2.new(0, 84, 1, -24), Parent = charPanel })
		UI.List(col, nil, 14)
		slotCols[k] = col
	end
	local lastWeaponType
	-- title: shown above the statue; tap to choose one (Config/Titles)
	local titleBtn = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = charPanel })
	UI.Corner(titleBtn, 12)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = titleBtn })
	local titleStroke = UI.Stroke(titleBtn, T.Gold, 3)
	local titleText = UI.Text(titleBtn, "", 18, T.Text, "Display", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextWrapped = false })
	UI.Text(titleBtn, "✎", 18, T.TextSoft, "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(20, 44), ZIndex = 6 })
	UI.Tactile(titleBtn)
	UI.Tooltip(titleBtn, function()
		return "Your title: shown above your head and in chat. Tap to change it.", T.Gold
	end)
	local titlePicker
	local titleCat = "Voyage"
	local function openTitles()
		if titlePicker then
			titlePicker:Destroy()
		end
		local p = State.profile
		if not p then
			return
		end
		titlePicker = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), ClipsDescendants = true, ZIndex = 30, Parent = charPanel })
		UI.Corner(titlePicker, 14)
		New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = titlePicker })
		UI.Stroke(titlePicker, T.Gold, 3)
		UI.Text(titlePicker, "TITLES", 22, T.Gold, "Display", { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(200, 28), ZIndex = 31 })
		local closeB = New("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Red, Text = "X", TextColor3 = Color3.new(1, 1, 1), FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), TextSize = 20, ZIndex = 32, Parent = titlePicker })
		UI.Corner(closeB, 8)
		closeB.Activated:Connect(function()
			titlePicker:Destroy()
			titlePicker = nil
		end)
		-- categories scroll sideways when the panel is narrow (they used to spill into the bag)
		local tabs = New("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, BorderSizePixel = 0, ZIndex = 31, Parent = titlePicker })
		local cats = {}
		for _, c in ipairs(TitlesCfg.Categories) do
			table.insert(cats, { c, "", c, T.Gold })
		end
		local tb = UI.TabBar(tabs, cats, titleCat, function(c)
			titleCat = c
			openTitles()
		end, 30)
		tb.AutomaticSize = Enum.AutomaticSize.X
		tb.Size = UDim2.fromOffset(0, 36)
		for _, d in ipairs(tb:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 32
			end
		end
		local list = UI.Scroll(titlePicker, UDim2.new(1, -16, 1, -100))
		list.Position = UDim2.fromOffset(8, 92)
		list.ZIndex = 31
		UI.List(list, nil, 6)
		local current = p.title == nil and TitlesCfg.Default or p.title
		local function row(name, color, sub, owned, equipped, onPick, order, tierId)
			local r = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -10, 0, 52), BackgroundColor3 = owned and T.Panel or T.PanelDeep, LayoutOrder = order, ZIndex = 32, Parent = list })
			UI.Corner(r, 10)
			UI.Stroke(r, equipped and T.Gold or T.Edge, equipped and 3.5 or 2)
			local nl = UI.Text(r, name, 18, owned and color or T.TextSoft, "Display", { Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -110, 0, 24), ZIndex = 33, TextWrapped = false })
			if tierId then
				-- the preview looks exactly like the nameplate (locked ones are just dimmed)
				TitleStyle.Apply(nl, tierId)
				if not owned then
					nl.TextTransparency = 0.45
				end
			end
			UI.Text(r, sub, 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -110, 0, 20), ZIndex = 33 })
			UI.Text(r, equipped and "WEARING" or (owned and "WEAR" or "🔒"), 14, equipped and T.Green or (owned and T.Gold or T.TextSoft), "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(90, 52), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 33 })
			if owned and not equipped then
				UI.Tactile(r)
				r.Activated:Connect(onPick)
			end
		end
		row("No title", T.Text, "Show only your name", true, current == "", function()
			req("SetTitle", {})
			titlePicker:Destroy()
			titlePicker = nil
		end, 0)
		for k, t in ipairs(TitlesCfg.List) do
			if t.category == titleCat then
				local owned = p.titles and p.titles[t.id] == true
				local tier = Rarity.Get(t.tier)
				row(t.name, tier.color, string.upper(t.tier) .. "  •  " .. (t.soon and not owned and "coming with the next sea" or t.desc), owned, current == t.id, function()
					req("SetTitle", { id = t.id }, "Equip")
					if titlePicker then
						titlePicker:Destroy()
						titlePicker = nil
					end
				end, k, t.tier)
			end
		end
	end
	titleBtn.Activated:Connect(openTitles)
	UI.Pad(right, 12)
	-- the filter tabs scroll sideways on small screens instead of piling on top of each other
	local filterRow = New("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, BorderSizePixel = 0, Parent = left })
	local grid = UI.Scroll(left, UDim2.new(1, 0, 1, -44))
	grid.Position = UDim2.fromOffset(0, 44)
	New("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), Parent = grid })
	local selectedUid
	local filter = "All"
	local render
	local lastClick = { uid = nil, t = 0 }
	local function placeholder()
		clear(right)
		UI.List(right, nil, 8, Enum.HorizontalAlignment.Center)
		New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = right })
		local chip = UI.IconChip(right, "🔍", T.Ocean, 72)
		chip.Rotation = -6
		UI.Text(right, "SELECT AN ITEM", 22, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center })
		UI.Text(right, "Click any tile to see its stats, equip, use or sell it.", 15, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40) })
	end
	placeholder()

	local function detail(entry, def)
		clear(right)
		local oldList = right:FindFirstChildOfClass("UIListLayout")
		if oldList then
			oldList:Destroy() -- (the empty-state placeholder stacks with a list; the detail view places things itself)
		end
		selectedUid = entry.uid
		local tier = ItemDB.Rarity(def)
		-- top ~55%: the item big on spinning rarity rays (3D model for weapons and fruits), then the details, then the
		-- actions along the bottom (one = centered, two or more = side by side across the full width)
		local head = New("Frame", { Size = UDim2.new(1, 0, 0.55, -10), ClipsDescendants = true, Parent = right })
		UI.Corner(head, 12)
		UI.RarityStyle(head, def.rarity, true)
		local rays = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.focuslines, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.5), ImageTransparency = 0.45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.6, 1.6), ZIndex = 3, Parent = head })
		New("UIAspectRatioConstraint", { Parent = rays })
		local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3), ImageTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.85, 0.85), ZIndex = 3, Parent = head })
		New("UIAspectRatioConstraint", { Parent = glow })
		local iconId = UI.ItemIconId(def)
		local big = (def.kind == "Fruit" and UI.ModelView(head, "Fruits", def.fruit, 200, 0.9, { ZIndex = 5 }))
			or (def.weaponType and UI.ModelView(head, "Weapons", def.weaponType, 200, 0.7, { ZIndex = 5 }))
		if not big and iconId then
			big = New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, ZIndex = 5, Parent = head })
		elseif not big then
			big = UI.Text(head, def.icon or kindIcon[def.kind] or "", 64, T.Text, "Display", { TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		end
		big.AnchorPoint = Vector2.new(0.5, 0.5)
		big.Position = UDim2.fromScale(0.5, 0.43)
		big.Size = UDim2.fromScale(0.72, 0.72)
		New("UIAspectRatioConstraint", { Parent = big })
		UI.Pop(big, 0.5)
		if tier.rank >= 4 then
			Audio.Play("Rarity" .. tier.id)
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not head.Parent then
				conn:Disconnect()
				return
			end
			rays.Rotation = (rays.Rotation + dt * 18) % 360
			big.Position = UDim2.new(0.5, 0, 0.43, math.sin((os.clock() - t0) * 2.2) * 5)
		end)
		local big2 = win.full and 26 or 21
		UI.Text(head, ItemDB.DisplayName(entry), big2, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, -16, 0, big2 + 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextWrapped = false })
		UI.Text(head, string.upper(tier.id), 15, tier.color:Lerp(Color3.new(1, 1, 1), 0.4), "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
		-- details (scrolls if long)
		local info = UI.Scroll(right, UDim2.new(1, 0, 0.45, -70))
		info.Position = UDim2.new(0, 0, 0.55, 2)
		UI.Text(info, describe(entry, def), win.full and 17 or 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top })
		-- actions
		local actions = {}
		local function act(label, color, fn)
			table.insert(actions, { label, color, fn })
		end
		if def.slot then
			if equippedUid(entry.uid) then
				act("Unequip", T.OceanDark, function()
					req("UnequipItem", { slot = def.slot }, "Equip")
				end)
			else
				act("Equip", T.Green, function()
					req("EquipItem", { uid = entry.uid }, "Equip")
				end)
			end
		end
		if def.kind == "Consumable" and not def.special then
			act("Use", T.Green, function()
				req("UseItem", { uid = entry.uid })
			end)
		end
		if def.kind == "Egg" then
			act("🐣 Hatch", T.Gold, function()
				local res = req("HatchEgg", { uid = entry.uid }, "RarityEpic")
				if res.ok then
					Panels.Open("Pets")
				end
			end)
		end
		if def.kind == "Fruit" then
			act("🍎 Eat", T.Pink, function()
				local cur = State.profile.fruit
				local warn = cur and ("\nYou will LOSE your current fruit power (" .. (FruitsCfg.ById[cur.id] and FruitsCfg.ById[cur.id].name or cur.id) .. ").") or ""
				UI.Confirm("Eat the " .. def.name .. "?" .. warn .. "\nFruit users can never swim again.", function()
					local res = req("EatFruit", { uid = entry.uid })
					if res.ok then
						UI.Banner("Cursed Fruit!", def.name, Rarity.Get(def.rarity).color, def.rarity)
					end
				end, nil, "Eat it", "Not yet")
			end)
		end
		if def.kind == "Card" then
			act("Insert", T.Gold, function()
				Panels.Refine({ tab = "Cards" })
			end)
		elseif def.slots and def.slots > 0 then
			act("Cards", T.Gold, function()
				Panels.Refine({ tab = "Cards", uid = entry.uid })
			end)
		end
		act("Sell", T.Red, function()
			req("ShopSell", { uid = entry.uid, qty = entry.qty or 1 }, "Coin")
		end)
		local bar = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 58), Parent = right })
		UI.List(bar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
		local n = #actions
		for _, a in ipairs(actions) do
			local w = n == 1 and UDim2.new(0.6, 0, 1, -6) or UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 1, -6)
			local btn = UI.Button(bar, a[1], a[2], w, a[3])
			local cap = btn:FindFirstChildOfClass("UITextSizeConstraint")
			if cap then
				cap.MaxTextSize = win.full and 28 or 22
			end
		end
	end

	-- an equipment slot around the character: the item's icon, or a faded hint of what goes there
	local function gearSlot(col, label, hintIcon, entry, def, onClick)
		local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 104), Parent = col })
		local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder })
		UI.Corner(b, 14)
		if def then
			UI.RarityStyle(b, def.rarity, entry and entry.uid == selectedUid)
			local img = UI.ItemIconId(def)
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.78, 0.78), Position = UDim2.fromScale(0.11, 0.11), ZIndex = 4, Parent = b })
			else
				UI.Text(b, def.icon or "❔", 34, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
			end
			if entry and (entry.refine or 0) > 0 then
				UI.Text(b, "+" .. entry.refine, 15, T.Gold, "Display", { Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(34, 16), ZIndex = 5 })
			end
			if entry and def.slots and def.slots > 0 then
				-- card sockets: filled = gold dot
				local dots = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(def.slots * 13, 11), ZIndex = 5, Parent = b })
				UI.List(dots, Enum.FillDirection.Horizontal, 3)
				for k = 1, def.slots do
					local d = New("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = (entry.cards and entry.cards[k]) and T.Gold or T.PanelDeep, ZIndex = 6, Parent = dots })
					UI.Corner(d, 5)
					UI.Stroke(d, T.Edge, 1.5)
				end
			end
		else
			New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = b })
			UI.Stroke(b, T.Edge, 2.5)
			local hint = UI.Icon(b, hintIcon, 52, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			if hint and hint:IsA("ImageLabel") then
				hint.ImageTransparency = 0.7
			elseif hint and hint:IsA("TextLabel") then
				hint.TextTransparency = 0.7
			end
		end
		UI.Text(holder, label, 12, T.TextSoft, "Bold", { Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
		UI.Tactile(b)
		b.Activated:Connect(onClick)
	end

	local function drawEquip(p)
		local tid = p.title == nil and TitlesCfg.Default or p.title
		local tdef = TitlesCfg.ById[tid or ""]
		if tdef and p.titles and p.titles[tdef.id] then
			local tier = Rarity.Get(tdef.tier)
			titleText.Text = "« " .. tdef.name .. " »"
			TitleStyle.Apply(titleText, tdef.tier)
			titleStroke.Color = tier.color
		else
			titleText.Text = "No title  •  tap to pick"
			TitleStyle.Apply(titleText, "Common")
			titleText.TextColor3 = T.TextSoft
			titleStroke.Color = T.Edge
		end
		for _, col in ipairs(slotCols) do
			clear(col)
			UI.List(col, nil, 14)
		end
		local function slotOf(slot, label, hint, col, filterKind)
			local entry = p.equipment[slot] and Formulas.FindItem(p, p.equipment[slot])
			local def = entry and ItemDB.Get(entry.id)
			gearSlot(col, label, hint, entry, def, function()
				if entry then
					detail(entry, def)
				else
					filter = filterKind
					render()
				end
			end)
			return def
		end
		slotOf("headgear", "Headgear", "🎩", slotCols[1], "Armor")
		local wdef = slotOf("weapon", "Weapon", "⚔️", slotCols[1], "Weapon")
		local fdef = p.fruit and ItemDB.Get("Fruit_" .. p.fruit.id)
		gearSlot(slotCols[1], "Fruit", "🍎", nil, fdef, function()
			Panels.Open("Skills")
		end)
		slotOf("armor", "Armor", "🛡️", slotCols[2], "Armor")
		slotOf("accessory", "Accessory", "💍", slotCols[2], "Armor")
		local pet
		for _, x in ipairs(p.pets and p.pets.list or p.pets or {}) do
			if type(x) == "table" and x.uid == p.activePet then
				pet = x
			end
		end
		gearSlot(slotCols[2], "Companion", "🐾", nil, nil, function()
			Panels.Open("Pets")
		end)
		if pet and slotCols[2]:FindFirstChildWhichIsA("Frame", false) then
			local holders = {}
			for _, c in ipairs(slotCols[2]:GetChildren()) do
				if c:IsA("Frame") then
					table.insert(holders, c)
				end
			end
			local petHolder = holders[#holders]
			local btn = petHolder and petHolder:FindFirstChildWhichIsA("TextButton")
			if btn then
				local view = UI.ModelView(btn, "Pets", (pet.species or "") .. "_" .. (pet.stage or 1), 80, 0.6, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 })
				if view then
					for _, c in ipairs(btn:GetChildren()) do
						if c:IsA("ImageLabel") or c:IsA("TextLabel") then
							c.Visible = false
						end
					end
				end
			end
		end
		-- the statue holds the equipped weapon (bare hands when none)
		local wType = (wdef and wdef.weaponType) or "Fists"
		if wType ~= lastWeaponType or not charPanel:GetAttribute("Drawn") then
			lastWeaponType = wType
			charPanel:SetAttribute("Drawn", true)
			refreshChar(wType)
		end
	end

	render = function()
		clear(grid)
		clear(filterRow)
		local p = State.profile
		if not p then
			return
		end
		drawEquip(p)
		local bar = UI.TabBar(filterRow, {
			{ "All", "🎒", "All", T.Ocean },
			{ "Weapon", "⚔️", "Weapons", T.Red },
			{ "Armor", "🛡️", "Gear", T.Blue },
			{ "Consumable", "🍖", "Food", T.Green },
			{ "Material", "🪵", "Mats", T.Orange },
			{ "Card", "🃏", "Cards", T.Purple },
		}, filter, function(f)
			filter = f
			render()
		end, 32)
		bar.AutomaticSize = Enum.AutomaticSize.X
		bar.Size = UDim2.fromOffset(0, 38)
		local list = {}
		for i, e in ipairs(p.inventory) do
			local def = ItemDB.Get(e.id)
			if def and (filter == "All" or def.kind == filter or (filter == "Armor" and (def.kind == "Headgear" or def.kind == "Accessory"))) then
				table.insert(list, { e = e, def = def, i = i })
			end
		end
		-- highest rarity first, like a gacha inventory
		table.sort(list, function(a, b)
			local ra, rb = ItemDB.Rarity(a.def).rank, ItemDB.Rarity(b.def).rank
			if ra ~= rb then
				return ra > rb
			end
			return a.i < b.i
		end)
		for order, it in ipairs(list) do
			local tile = itemTile(grid, it.e, function(entry, def)
				-- double-click gear with card slots: straight to the Insert Card page
				local now = os.clock()
				if lastClick.uid == entry.uid and now - lastClick.t < 0.4 and def.slots and def.slots > 0 then
					lastClick.uid = nil
					Panels.Refine({ tab = "Cards", uid = entry.uid })
					return
				end
				lastClick.uid, lastClick.t = entry.uid, now
				detail(entry, def)
			end, it.e.uid == selectedUid)
			if tile then
				tile.LayoutOrder = order
			end
		end
		if selectedUid then
			local e = Formulas.FindItem(p, selectedUid)
			if e then
				detail(e, ItemDB.Get(e.id))
			else
				selectedUid = nil
				placeholder()
			end
		end
	end
	render()
	-- open straight on an item (used by the UI harness and by "show me" links)
	if args and args.select and State.profile then
		local e = Formulas.FindItem(State.profile, args.select)
		if e then
			detail(e, ItemDB.Get(e.id))
		end
	end
	onProfile(win, render)
	local _, h = UI.Button(win.header, "🏪 Open Stall", T.Orange, UDim2.fromOffset(170, 42), function()
		Panels.StallSetup()
	end)
	h.AnchorPoint = Vector2.new(1, 0.5)
	h.Position = UDim2.new(1, -128, 0.5, -2)
	h.ZIndex = 30
end

-- ===================== STATS =====================
function Panels.Stats()
	-- like the Bag: your character on the left; on the right the attribute table. Plan points with - / +, then Apply
	-- (nothing is spent until you press it). Below, the combat numbers those attributes give you.
	local win = UI.Window("Stats", "Stats", UDim2.fromOffset(1100, 600), T.Purple, "📊", { fullscreen = true })
	local charPanel = UI.Card(win.body, UDim2.new(0.38, -10, 1, 0), T.PanelDeep)
	local stage = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -96), Parent = charPanel })
	New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = T.Purple:Lerp(Color3.new(1, 1, 1), 0.4), ImageTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.9, 0.9), Parent = stage })
	local _, refreshChar = UI.CharacterView(stage)
	local nameLabel = UI.Text(charPanel, "", 24, T.Text, "Display", { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28) })
	local subLabel = UI.Text(charPanel, "", 15, T.TextSoft, "Semi", { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 20) })
	UI.Text(charPanel, "drag to turn", 12, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Center })
	-- scrolls when the window is short (small screens) instead of spilling out of the frame
	local right = UI.Scroll(win.body, UDim2.new(0.62, 0, 1, 0))
	right.Position = UDim2.new(0.38, 0, 0, 0)
	local desc = { STR = "Physical attack", AGI = "Attack speed / dodge", VIT = "HP / defense", INT = "Magic / SP", DEX = "Accuracy / ranged", LUK = "Crits / drops" }
	local pend = {}
	local drawn = false

	local function planCost(p)
		local total = 0
		for _, s in ipairs(Formulas.StatNames) do
			for k = 0, (pend[s] or 0) - 1 do
				total += Formulas.StatCost(p.stats[s] + k)
			end
		end
		return total
	end

	local render
	render = function()
		clear(right)
		local p, d = State.profile, State.derived
		if not p or not d then
			return
		end
		local cls = Classes[p.class]
		nameLabel.Text = player.DisplayName
		subLabel.Text = (cls and (cls.icon .. " " .. cls.name) or p.class) .. "   •   Base Lv." .. p.baseLevel .. "   Job Lv." .. p.jobLevel
		if not drawn then
			drawn = true
			local wEntry = p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
			local wDef = wEntry and ItemDB.Get(wEntry.id)
			refreshChar((wDef and wDef.weaponType) or "Fists")
		end
		local left = p.statPoints - planCost(p)

		local tbl = UI.Card(right, UDim2.new(1, -12, 0, 470), T.Panel)
		UI.Pad(tbl, 14)
		-- header: points left + reset plan
		UI.Text(tbl, "POINTS LEFT", 16, T.TextSoft, "Display", { Size = UDim2.fromOffset(140, 30) })
		UI.Text(tbl, tostring(left), 30, left > 0 and T.Gold or T.Text, "Number", { Position = UDim2.fromOffset(140, -2), Size = UDim2.fromOffset(90, 34) })
		local _, rh = UI.Button(tbl, "↺ Reset plan", T.Grey, UDim2.fromOffset(150, 36), function()
			pend = {}
			render()
		end)
		rh.AnchorPoint = Vector2.new(1, 0)
		rh.Position = UDim2.new(1, 0, 0, -2)
		-- column titles
		local cols = { { "ATTRIBUTE", 0, 0.3 }, { "BASE", 0.3, 0.12 }, { "BONUS", 0.42, 0.12 }, { "NEXT COST", 0.54, 0.14 } }
		for _, c in ipairs(cols) do
			UI.Text(tbl, c[1], 13, T.TextSoft, "Display", { Position = UDim2.new(c[2], 0, 0, 46), Size = UDim2.new(c[3], 0, 0, 18), TextXAlignment = c[2] == 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
		end
		for i, s in ipairs(Formulas.StatNames) do
			local y = 70 + (i - 1) * 56
			local row = New("Frame", { BackgroundColor3 = i % 2 == 0 and T.PanelDeep or T.PanelTop, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 50), Parent = tbl })
			UI.Corner(row, 10)
			local base, n = p.stats[s], pend[s] or 0
			local bonus = (d[s] or base) - base
			UI.Text(row, s, 22, T.Text, "Display", { Position = UDim2.fromOffset(12, 2), Size = UDim2.new(0.3, -12, 0, 26) })
			UI.Text(row, desc[s], 11, T.TextSoft, "Semi", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.3, -12, 0, 14) })
			UI.Text(row, tostring(base) .. (n > 0 and ('<font color="#7CFF9B"> +' .. n .. "</font>") or ""), 20, T.Text, "Number", { Position = UDim2.fromScale(0.3, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
			UI.Text(row, bonus ~= 0 and ((bonus > 0 and "+" or "") .. bonus) or "0", 20, bonus > 0 and T.Green or T.TextSoft, "Number", { Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
			local nextCost = Formulas.StatCost(base + n)
			local maxed = base + n >= Formulas.MaxStat
			UI.Text(row, maxed and "MAX" or tostring(nextCost), 20, (not maxed and nextCost <= left) and T.Gold or T.Red, "Number", { Position = UDim2.fromScale(0.54, 0), Size = UDim2.new(0.14, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
			local function stepBtn(text, color, xOff, fn)
				local _, h = UI.Button(row, text, color, UDim2.fromOffset(44, 40), fn)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, xOff, 0.5, -2)
			end
			stepBtn("−", n > 0 and T.Pink or T.Grey, -56, function()
				if n > 0 then
					pend[s] = n - 1
					render()
				end
			end)
			stepBtn("+", (not maxed and nextCost <= left) and T.Green or T.Grey, -6, function()
				if not maxed and nextCost <= left then
					pend[s] = n + 1
					render()
				else
					UI.Toast(maxed and (s .. " is at the maximum") or "Not enough points", "bad")
				end
			end)
		end
		-- bottom row: Apply (half) + Auto upgrade toggle (half); both stay inside the frame on any width
		local any = planCost(p) > 0
		local foot = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 48), Parent = tbl })
		UI.List(foot, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
		UI.Button(foot, any and "Apply" or "Plan with +", any and T.Green or T.Grey, UDim2.new(0.5, -5, 1, 0), function()
			if not any then
				return
			end
			local res = req("AllocateStats", { add = pend }, "LevelUp")
			if res.ok then
				pend = {}
			end
		end)
		local autoOn = p.settings and p.settings.autoStats == true
		local autoBtn = UI.Button(foot, (autoOn and "☑" or "☐") .. " Auto upgrade", autoOn and T.Ocean or T.Grey, UDim2.new(0.5, -5, 1, 0), function()
			local v = not autoOn
			p.settings = p.settings or {}
			p.settings.autoStats = v
			render()
			task.spawn(req, "SetAutoSettings", { autoStats = v })
		end)
		UI.Tooltip(autoBtn, function()
			return "Auto upgrade: spends new stat points for you, in the build that suits your class (" .. ((Classes[p.class] and Classes[p.class].name) or p.class) .. "). Untick to plan them yourself.", T.Ocean
		end)

		-- combat numbers
		-- combat numbers: the card grows with however many rows the grid needs at this width
		local cs = UI.Card(right, UDim2.new(1, -12, 0, 0), T.PanelDeep)
		cs.AutomaticSize = Enum.AutomaticSize.Y
		cs.Position = UDim2.fromOffset(0, 482)
		UI.Pad(cs, 12)
		local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cs })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(250, 26), CellPadding = UDim2.fromOffset(18, 4), Parent = grid })
		for _, l in ipairs({
			{ "HP", d.maxHp }, { "SP", d.maxSp }, { "ATK", d.atk }, { "MATK", d.matk }, { "DEF", d.def }, { "MDEF", d.mdef },
			{ "HIT", d.hit }, { "FLEE", d.flee }, { "CRIT", string.format("%.1f%%", d.crit) },
			{ "Attack every", string.format("%.2fs", d.attackInterval) }, { "Cannon dmg", "+" .. math.floor(d.cannonDamage * 100) .. "%" }, { "Ship speed", "+" .. math.floor(d.shipSpeed * 100) .. "%" },
		}) do
			local r = New("Frame", { BackgroundTransparency = 1, Parent = grid })
			UI.Text(r, l[1], 15, T.TextSoft, "Semi", { Size = UDim2.new(0.6, 0, 1, 0) })
			UI.Text(r, tostring(l[2]), 16, T.Text, "Number", { Size = UDim2.new(1, -4, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
	render()
	onProfile(win, render)
	win.resized.Event:Connect(render)
end

-- ===================== SKILLS =====================
-- ===================== SKILLS (full screen: skill tree + loadout) =====================
-- Skills tab: tiers (Basic / class / Cursed Fruit / next job) as a grid of skill nodes, the picked skill's details on the
-- right with Learn. Loadout tab: tap a skill or an item, then a slot (tap two slots to swap): 12 skill slots
-- (keys 1-6, 7-=), 8 quick items (F1-F8), which skills Auto Battle may use, and the Auto Battle search range.
local SkillLook = require(script.Parent.SkillLook)
local skillsView = { side = "Skills", tier = nil, pick = nil }

local function skillNode(parent, sk, lv, maxLv, picked, locked, onClick)
	local c = SkillLook.Color(sk)
	local node = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 150), Parent = parent })
	local ring = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.new(1, 1, 1), Parent = node })
	UI.Corner(ring, 46)
	New("UIGradient", { Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c:Lerp(Color3.new(0, 0, 0), 0.35)), Rotation = 90, Parent = ring })
	UI.Stroke(ring, picked and T.Gold or T.Edge, picked and 5 or 3)
	local img = SkillLook.IconId(sk)
	if img then
		New("ImageLabel", { BackgroundTransparency = 1, Image = img, ImageTransparency = locked and 0.55 or 0, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 70), Parent = ring })
	end
	if locked then
		UI.Text(ring, "🔒", 30, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	end
	local badge = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.fromOffset(64, 24), BackgroundColor3 = T.PanelDeep, Parent = node })
	UI.Corner(badge, 12)
	UI.Stroke(badge, T.Edge, 2)
	UI.Text(badge, lv .. "/" .. maxLv, 15, lv > 0 and T.Gold or T.TextSoft, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	UI.Text(node, sk.name, 14, T.Text, "Bold", { Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
	UI.Tactile(ring)
	ring.Activated:Connect(onClick)
	return node
end

local function statLine(parent, label, value, order)
	local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = parent })
	UI.Text(r, "◆ " .. label, 15, T.TextSoft, "Semi", { Size = UDim2.new(0.6, 0, 1, 0) })
	UI.Text(r, value, 15, T.Text, "Bold", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
end

-- the skills a tier tab shows: { skill, level, max, locked }
local function tierSkills(p, tier)
	local out = {}
	if tier == "Fruit" then
		local fruit = p.fruit and FruitsCfg.ById[p.fruit.id]
		for _, s in ipairs(fruit and fruit.skills or {}) do
			local open = p.fruit.mastery >= s.mastery
			table.insert(out, { s, open and 1 or 0, 1, not open })
		end
	elseif tier == "Basic" then
		for _, s in ipairs(Classes.Common.skills) do
			table.insert(out, { s, p.skills[s.id] or 0, s.maxLevel, false })
		end
	elseif Classes[tier] then
		for _, s in ipairs(Classes[tier].skills) do
			table.insert(out, { s, p.skills[s.id] or 0, s.maxLevel, false })
		end
	end
	return out
end

local function setBar(p, bar)
	p.skillBar = bar -- optimistic: the hotbar redraws right away
	State.Fire("profile")
	task.spawn(req, "SetSkillBar", { bar = bar })
end
local function setItemBar(p, bar)
	p.itemBar = bar
	State.Fire("profile")
	task.spawn(req, "SetItemBar", { bar = bar })
end
local function padded(bar, n)
	local out = {}
	for i = 1, n do
		out[i] = (bar and bar[i]) or ""
	end
	return out
end

function Panels.Skills(args)
	if args and args.tab then
		skillsView.side = args.tab
	end
	local win = UI.Window("Skills", "Skills", UDim2.fromOffset(1000, 620), T.Gold, "✨", { fullscreen = true })
	-- drag and drop (Loadout): press a skill / item / slot, move, release over a slot. Dragging a slot off the bar
	-- empties it. A press that does not move stays a tap (tap-then-tap still works, e.g. on phones).
	local UIS = game:GetService("UserInputService")
	local drag, lastDrop = nil, 0
	local dropTargets = {}
	local onDrop -- set by the loadout: function(payload, target or nil)
	local function inside(btn, pt)
		local a, sz = btn.AbsolutePosition, btn.AbsoluteSize
		return pt.X >= a.X and pt.X <= a.X + sz.X and pt.Y >= a.Y and pt.Y <= a.Y + sz.Y
	end
	local function ghostAt(d, pt)
		local sc = UI.GetScale()
		if not d.ghost then
			local g = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = d.color or T.Panel, BackgroundTransparency = 0.15, ZIndex = 90, Parent = UI.Root })
			UI.Corner(g, 12)
			UI.Stroke(g, T.Gold, 3)
			if d.img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = d.img, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ScaleType = Enum.ScaleType.Fit, ZIndex = 91, Parent = g })
			end
			d.ghost = g
		end
		d.ghost.Position = UDim2.fromOffset(pt.X / sc, pt.Y / sc)
		d.pt = pt
	end
	local function finishDrag(d, pt)
		if d.ghost then
			d.ghost:Destroy()
		end
		lastDrop = os.clock()
		local inset = 0
		pcall(function()
			inset = game:GetService("GuiService"):GetGuiInset().Y
		end)
		-- the drop point, tried as-is and shifted by the top-bar inset (input APIs disagree about it)
		local hit
		for _, probe in ipairs({ pt, pt + Vector2.new(0, inset) }) do
			for _, t in ipairs(dropTargets) do
				if not hit and t.btn.Parent and inside(t.btn, probe) then
					hit = t
				end
			end
		end
		if onDrop then
			onDrop(d.payload, hit)
		end
	end
	-- Roblox's own UIDragDetector does the pointer capture (mouse and touch, also inside scrolling lists); the tile
	-- itself never moves (CustomOffset), a ghost follows the pointer instead
	local function draggable(btn, payload, img, color)
		local ok = pcall(function()
			local det = Instance.new("UIDragDetector")
			det.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
			det.Parent = btn
			local d
			det.DragStart:Connect(function(pos)
				d = { payload = payload, img = img, color = color, start = pos, moved = false }
			end)
			det.DragContinue:Connect(function(pos)
				if d and (d.moved or (pos - d.start).Magnitude > 8) then
					d.moved = true
					ghostAt(d, pos)
				end
			end)
			det.DragEnd:Connect(function(pos)
				local dd = d
				d = nil
				if dd and dd.moved then
					finishDrag(dd, pos)
				end
			end)
		end)
		if not ok then
			-- (older engines / the UI harness): track the pointer ourselves
			btn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					drag = { payload = payload, start = Vector2.new(input.Position.X, input.Position.Y), img = img, color = color }
				end
			end)
		end
	end
	local conns = {}
	table.insert(conns, UIS.InputChanged:Connect(function(input)
		if not drag or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		local pt = Vector2.new(input.Position.X, input.Position.Y)
		local sc = UI.GetScale()
		if not drag.ghost and (pt - drag.start).Magnitude > 10 then
			local g = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = drag.color or T.Panel, BackgroundTransparency = 0.15, ZIndex = 90, Parent = UI.Root })
			UI.Corner(g, 12)
			UI.Stroke(g, T.Gold, 3)
			if drag.img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = drag.img, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ScaleType = Enum.ScaleType.Fit, ZIndex = 91, Parent = g })
			end
			drag.ghost = g
		end
		if drag.ghost then
			-- InputObject positions leave out the top-bar inset (mouse and touch alike); our UI root does not
			local inset = 0
			pcall(function()
				inset = game:GetService("GuiService"):GetGuiInset().Y
			end)
			drag.ghost.Position = UDim2.fromOffset(pt.X / sc, (pt.Y + inset) / sc)
			drag.pt = Vector2.new(pt.X, pt.Y + inset)
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(input)
		if not drag or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		local d = drag
		drag = nil
		if d.ghost then
			d.ghost:Destroy()
			lastDrop = os.clock()
			local hit
			for _, t in ipairs(dropTargets) do
				if t.btn.Parent and inside(t.btn, d.pt or d.start) then
					hit = t
				end
			end
			if onDrop then
				onDrop(d.payload, hit)
			end
		end
	end))
	win.frame.Destroying:Connect(function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
	end)
	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), Parent = win.body })
	UI.List(side, nil, 10)
	local content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(162, 0), Size = UDim2.new(1, -162, 1, 0), Parent = win.body })
	local render

	local function sidebar()
		clear(side)
		UI.List(side, nil, 10)
		for i, it in ipairs({ { "Skills", "✨", "Skill Tree" }, { "Loadout", "⚔️", "Loadout" } }) do
			local on = skillsView.side == it[1]
			local _, h = UI.Button(side, it[2] .. " " .. it[3], on and T.Gold or T.Grey, UDim2.new(1, -6, 0, 50), function()
				skillsView.side = it[1]
				render()
			end)
			h.LayoutOrder = i
		end
		local p = State.profile
		if p then
			local pts = UI.Card(side, UDim2.new(1, -6, 0, 70), T.PanelDeep)
			pts.LayoutOrder = 10
			UI.Text(pts, "SKILL POINTS", 13, T.TextSoft, "Display", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18) })
			UI.Text(pts, tostring(p.skillPoints or 0), 30, (p.skillPoints or 0) > 0 and T.Gold or T.Text, "Number", { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 36) })
		end
	end

	-- ---------- skill tree ----------
	local function renderTree(p)
		local tiers = { { "Basic", "⚓", "Basic", T.Grey }, { p.class, Classes[p.class] and Classes[p.class].icon or "⚔️", Classes[p.class] and Classes[p.class].name or p.class, Classes[p.class] and Classes[p.class].color } }
		if p.fruit then
			local f = FruitsCfg.ById[p.fruit.id]
			table.insert(tiers, { "Fruit", f and f.icon or "🍎", f and f.name or "Fruit", f and f.color })
		end
		table.insert(tiers, { "Next", "🔒", "Job 2", T.Grey })
		local valid = false
		for _, t in ipairs(tiers) do
			valid = valid or t[1] == skillsView.tier
		end
		if not valid then
			skillsView.tier = p.class
		end
		UI.TabBar(content, tiers, skillsView.tier, function(id)
			skillsView.tier = id
			skillsView.pick = nil
			render()
		end, 40)
		local left = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(0.6, -10, 1, -54), Parent = content })
		local right = UI.Card(content, UDim2.new(0.4, 0, 1, -54), T.Panel)
		right.Position = UDim2.new(0.6, 0, 0, 54)
		if skillsView.tier == "Next" then
			local names = {}
			for _, id in ipairs(ClassesCfg.SecondJobs[p.class] or {}) do
				table.insert(names, id)
			end
			UI.Text(left, "🔒 Second jobs open with the Grand Current update.\n" .. (#names > 0 and ("Paths for your class: " .. table.concat(names, ", ")) or "Switch to a first job at the Job Master (Job Lv.10) to see its paths."), 18, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 120) })
			UI.Pad(right, 14)
			UI.Text(right, "Coming soon", 22, T.Text, "Display")
			return
		end
		local list = tierSkills(p, skillsView.tier)
		if not skillsView.pick or not ClassesCfg.SkillById[skillsView.pick] then
			skillsView.pick = list[1] and list[1][1].id
		end
		local grid = UI.Scroll(left)
		New("UIGridLayout", { CellSize = UDim2.fromOffset(120, 154), CellPadding = UDim2.fromOffset(14, 10), Parent = grid })
		New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), Parent = grid })
		for _, e in ipairs(list) do
			local sk, lv, maxLv, locked = e[1], e[2], e[3], e[4]
			skillNode(grid, sk, lv, maxLv, sk.id == skillsView.pick, locked, function()
				skillsView.pick = sk.id
				render()
			end)
		end
		-- detail panel
		local sk = skillsView.pick and ClassesCfg.SkillById[skillsView.pick]
		if not sk then
			return
		end
		UI.Pad(right, 14)
		local lv = sk.fruit and ((p.fruit and p.fruit.mastery >= (sk.mastery or 1)) and 1 or 0) or (p.skills[sk.id] or 0)
		local maxLv = sk.fruit and 1 or sk.maxLevel
		local head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), Parent = right })
		local chip = New("Frame", { Size = UDim2.fromOffset(78, 78), BackgroundColor3 = SkillLook.Color(sk), Parent = head })
		UI.Corner(chip, 14)
		UI.Stroke(chip, T.Edge, 3)
		local img = SkillLook.IconId(sk)
		if img then
			New("ImageLabel", { BackgroundTransparency = 1, Image = img, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), ScaleType = Enum.ScaleType.Fit, Parent = chip })
		end
		UI.Text(head, sk.name, 24, T.Text, "Display", { Position = UDim2.fromOffset(90, 2), Size = UDim2.new(1, -90, 0, 30) })
		UI.Text(head, (sk.fruit and ("Mastery " .. (sk.mastery or 1)) or ("Lv." .. lv .. " / " .. maxLv)) .. "   •   " .. (SkillLook.IsSupport(sk) and "Support" or "Attack") .. " • " .. sk.kind, 15, T.Gold, "Bold", { Position = UDim2.fromOffset(90, 36), Size = UDim2.new(1, -90, 0, 20) })
		local info = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -170), Parent = right })
		UI.List(info, nil, 4)
		UI.Text(info, sk.desc or "", 16, T.Text, "Semi", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 0 })
		local o = 1
		local function line(a, b)
			statLine(info, a, b, o)
			o += 1
		end
		line("SP cost", tostring(sk.sp))
		line("Cooldown", sk.cd .. " s")
		if sk.range and sk.range > 0 then
			line("Range", sk.range .. " studs")
		end
		if sk.radius then
			line("Area", sk.radius .. " studs")
		end
		if sk.mult then
			local now = sk.mult * (1 + 0.1 * math.max(lv - 1, 0))
			line("Damage", string.format("x%.2f", now) .. ((not sk.fruit and lv < maxLv and lv > 0) and string.format("  ->  x%.2f", sk.mult * (1 + 0.1 * lv)) or ""))
		end
		if sk.duration then
			line("Lasts", sk.duration .. " s")
		end
		if sk.hits then
			line("Hits", tostring(sk.hits))
		end
		local btns = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 60), Parent = right })
		UI.List(btns, Enum.FillDirection.Horizontal, 10)
		if not sk.fruit then
			local can = lv < maxLv and (p.skillPoints or 0) > 0
			UI.Button(btns, lv >= maxLv and "MAX" or (lv == 0 and "Learn" or "Level up +1"), can and T.Green or T.Grey, UDim2.new(0.5, -5, 0, 52), function()
				if can then
					req("LearnSkill", { skillId = sk.id }, "LevelUp")
				else
					UI.Toast(lv >= maxLv and "Already max level" or "No skill points left", "bad")
				end
			end)
		end
		if lv > 0 then
			local onBar = table.find(p.skillBar, sk.id) ~= nil
			UI.Button(btns, onBar and "On hotbar ✓" or "Put on hotbar", onBar and T.Grey or T.Ocean, UDim2.new(0.5, -5, 0, 52), function()
				if not onBar then
					local bar = padded(p.skillBar, GameConfig.SkillBarSize)
					for i = 1, #bar do
						if bar[i] == "" then
							bar[i] = sk.id
							setBar(p, bar)
							return
						end
					end
					UI.Toast("Hotbar is full: rearrange it in Loadout", "bad")
				end
			end)
		end
	end

	-- ---------- loadout ----------
	local sel -- { kind = "skill"|"item", id } or { kind = "slot", bar = "skill"|"item", i }
	local function renderLoadout(p)
		dropTargets = {}
		local left = UI.Scroll(content, UDim2.new(0.55, -10, 1, 0))
		UI.List(left, nil, 8)
		local right = UI.Scroll(content, UDim2.new(0.45, 0, 1, 0))
		right.Position = UDim2.new(0.55, 0, 0, 0)
		UI.List(right, nil, 10)
		-- slot size follows the column width so 6 slots always fit inside the card
		local okW, absW = pcall(function()
			return content.AbsoluteSize.X
		end)
		local colW = (okW and absW or 0) * 0.45
		local SL = (colW > 100) and math.clamp(math.floor((colW - 44 - 5 * 6) / 6), 38, 56) or 56

		local tilePayload
		local function tileDrag(b, img, color)
			if tilePayload then
				draggable(b, tilePayload, img, color)
			end
		end
		local function tile(parent, img, title, color, picked, onClick, extra)
			local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 128), Parent = parent })
			local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(96, 96), BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder })
			UI.Corner(b, 14)
			New("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.4)), Rotation = 90, Parent = b })
			UI.Stroke(b, picked and T.Gold or T.Edge, picked and 5 or 3)
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.06), ScaleType = Enum.ScaleType.Fit, Parent = b })
			end
			UI.Text(holder, title, 13, T.Text, "Bold", { Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
			UI.Tactile(b)
			b.Activated:Connect(function()
				if os.clock() - lastDrop > 0.2 then
					onClick()
				end
			end)
			tileDrag(b, img, color)
			if extra then
				extra(b)
			end
			return holder
		end
		local function gridIn(parent, n)
			local rows = math.max(1, math.ceil(n / 5))
			local g = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, rows * 136), Parent = parent })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(96, 128), CellPadding = UDim2.fromOffset(10, 8), Parent = g })
			return g
		end

		-- skills you can put on the bar now
		local attack, support = {}, {}
		local function consider(s)
			local usable = s.fruit and (p.fruit and p.fruit.id == s.fruit and p.fruit.mastery >= (s.mastery or 1)) or ((p.skills[s.id] or 0) > 0)
			if usable then
				table.insert(SkillLook.IsSupport(s) and support or attack, s)
			end
		end
		for _, s in ipairs(Classes.Common.skills) do
			consider(s)
		end
		for _, s in ipairs(Classes[p.class] and Classes[p.class].skills or {}) do
			consider(s)
		end
		local fruit = p.fruit and FruitsCfg.ById[p.fruit.id]
		for _, s in ipairs(fruit and fruit.skills or {}) do
			consider(s)
		end
		for _, group in ipairs({ { "⚔️", "Attack skills", attack, T.Red }, { "✨", "Support skills", support, T.Green } }) do
			UI.Section(left, group[1], group[2], group[4], "drag onto a slot")
			local g = gridIn(left, #group[3])
			for _, s in ipairs(group[3]) do
				local picked = sel and sel.kind == "skill" and sel.id == s.id
				tilePayload = { kind = "skill", id = s.id }
				tile(g, SkillLook.IconId(s), s.name, SkillLook.Color(s), picked, function()
					sel = picked and nil or { kind = "skill", id = s.id }
					render()
				end, function(b)
					-- auto toggle chip: may Auto Battle use this skill?
					local on = p.autoSkills[s.id] == true
					local chipBtn = New("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = on and T.Green or T.Grey, Text = on and "✓" or "✕", TextColor3 = Color3.new(1, 1, 1), FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), TextSize = 18, AutoButtonColor = false, ZIndex = 4, Parent = b })
					UI.Corner(chipBtn, 15)
					UI.Stroke(chipBtn, T.Edge, 2)
					chipBtn.Activated:Connect(function()
						local a = table.clone(p.autoSkills)
						a[s.id] = (not on) or nil
						p.autoSkills = a
						render()
						task.spawn(req, "SetAutoSettings", { autoSkills = a })
					end)
					UI.Tooltip(chipBtn, function()
						return on and "Auto Battle uses this skill (tap to stop)" or "Auto Battle skips this skill (tap to allow)", on and T.Green or T.Grey
					end)
				end)
			end
		end
		-- consumables in the bag
		local items, seen = {}, {}
		for _, e in ipairs(p.inventory or {}) do
			local def = ItemDB.Get(e.id)
			if def and def.kind == "Consumable" and not def.special and not seen[e.id] then
				seen[e.id] = true
				table.insert(items, def)
			end
		end
		UI.Section(left, "🍖", "Quick items", T.Ocean, #items == 0 and "no food or potions in your bag" or "drag onto an F slot")
		local ig = gridIn(left, #items)
		for _, def in ipairs(items) do
			local picked = sel and sel.kind == "item" and sel.id == def.id
			local qty = 0
			for _, e in ipairs(p.inventory) do
				if e.id == def.id then
					qty += e.qty or 1
				end
			end
			tilePayload = { kind = "item", id = def.id }
			tile(ig, UI.ItemIconId(def), def.name .. " x" .. qty, T.Ocean, picked, function()
				sel = picked and nil or { kind = "item", id = def.id }
				render()
			end)
		end

		-- the hotbar layout
		local card = UI.Card(right, UDim2.new(1, -12, 0, 84 + 4 * (SL + 6) + 26), T.PanelDeep)
		card.LayoutOrder = 1
		UI.Pad(card, 12)
		UI.Text(card, "HOTBAR", 20, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 24) })
		UI.Text(card, "Drag a skill or item onto a slot (or tap it, then a slot). Drag a slot off to empty it.", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18) })
		local Combat = require(script.Parent.Parent.Controllers.Combat)
		local function slotRow(y, bar, from, to, keyFn, look)
			local r = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, SL + 4), Parent = card })
			UI.List(r, Enum.FillDirection.Horizontal, 6)
			for i = from, to do
				local picked = sel and sel.kind == "slot" and sel.bar == bar and sel.i == i
				local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(SL, SL), BackgroundColor3 = Color3.new(1, 1, 1), Parent = r })
				UI.Corner(b, 10)
				local img, col = look(i)
				New("UIGradient", { Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.15), col:Lerp(Color3.new(0, 0, 0), 0.45)), Rotation = 90, Parent = b })
				UI.Stroke(b, picked and T.Gold or T.Edge, picked and 4 or 2.5)
				if img then
					New("ImageLabel", { BackgroundTransparency = 1, Image = img, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ScaleType = Enum.ScaleType.Fit, Parent = b })
				end
				UI.Text(b, keyFn(i), 12, T.Gold, "Display", { Position = UDim2.fromOffset(4, 1), Size = UDim2.fromOffset(24, 14) })
				UI.Tactile(b)
				table.insert(dropTargets, { btn = b, bar = bar, i = i })
				if img then
					draggable(b, { kind = "slot", bar = bar, i = i }, img, col)
				end
				b.Activated:Connect(function()
					if os.clock() - lastDrop < 0.2 then
						return
					end
					local list = bar == "skill" and padded(p.skillBar, GameConfig.SkillBarSize) or padded(p.itemBar, GameConfig.ItemBarSize)
					local function commit()
						sel = nil
						if bar == "skill" then
							setBar(p, list)
						else
							setItemBar(p, list)
						end
						render()
					end
					if sel and sel.kind == (bar == "skill" and "skill" or "item") then
						-- place it (a skill lives in one slot only: move it)
						for k = 1, #list do
							if list[k] == sel.id then
								list[k] = ""
							end
						end
						list[i] = sel.id
						commit()
					elseif sel and sel.kind == "slot" and sel.bar == bar then
						list[i], list[sel.i] = list[sel.i], list[i]
						commit()
					else
						sel = { kind = "slot", bar = bar, i = i }
						render()
					end
				end)
			end
		end
		local function skillLook(i)
			local s = ClassesCfg.SkillById[p.skillBar[i] or ""]
			return s and SkillLook.IconId(s), s and SkillLook.Color(s) or T.Panel
		end
		local function itemLook(i)
			local def = p.itemBar and ItemDB.Get(p.itemBar[i] or "")
			return def and UI.ItemIconId(def), def and T.Ocean or T.Panel
		end
		local rowH = SL + 6
		UI.Text(card, "SKILLS", 14, T.Text, "Display", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 16) })
		slotRow(66, "skill", 1, 6, function(i)
			return Combat.SKILL_KEY_LABELS[i]
		end, skillLook)
		slotRow(66 + rowH, "skill", 7, 12, function(i)
			return Combat.SKILL_KEY_LABELS[i]
		end, skillLook)
		local iy = 66 + 2 * rowH + 6
		UI.Text(card, "QUICK ITEMS", 14, T.Text, "Display", { Position = UDim2.fromOffset(0, iy), Size = UDim2.new(1, 0, 0, 16) })
		slotRow(iy + 18, "item", 1, 4, function(i)
			return "F" .. i
		end, itemLook)
		slotRow(iy + 18 + rowH, "item", 5, 8, function(i)
			return "F" .. i
		end, itemLook)
		-- drag and drop: same rules as tapping (place / move / swap), plus "drag a slot off the bar to empty it"
		onDrop = function(payload, target)
			local function listOf(bar)
				return bar == "skill" and padded(p.skillBar, GameConfig.SkillBarSize) or padded(p.itemBar, GameConfig.ItemBarSize)
			end
			local function save(bar, list)
				if bar == "skill" then
					setBar(p, list)
				else
					setItemBar(p, list)
				end
			end
			sel = nil
			if payload.kind == "slot" then
				local list = listOf(payload.bar)
				if not target then
					list[payload.i] = ""
				elseif target.bar == payload.bar then
					list[payload.i], list[target.i] = list[target.i], list[payload.i]
				else
					render()
					return
				end
				save(payload.bar, list)
			elseif target and target.bar == payload.kind then
				local list = listOf(target.bar)
				for k = 1, #list do
					if list[k] == payload.id then
						list[k] = ""
					end
				end
				list[target.i] = payload.id
				save(target.bar, list)
			end
			render()
		end

		-- clear the picked slot
		if sel and sel.kind == "slot" then
			local _, h = UI.Button(card, "Clear slot", T.Red, UDim2.fromOffset(130, 40), function()
				local isSkill = sel.bar == "skill"
				local list = isSkill and padded(p.skillBar, GameConfig.SkillBarSize) or padded(p.itemBar, GameConfig.ItemBarSize)
				list[sel.i] = ""
				sel = nil
				if isSkill then
					setBar(p, list)
				else
					setItemBar(p, list)
				end
				render()
			end)
			h.AnchorPoint = Vector2.new(1, 0)
			h.Position = UDim2.new(1, 0, 0, 0)
		end

		-- Auto Battle range + potion threshold
		local ab = GameConfig.AutoBattle
		local auto = UI.Card(right, UDim2.new(1, -12, 0, 150), T.PanelDeep)
		auto.LayoutOrder = 2
		UI.Pad(auto, 12)
		UI.Text(auto, "AUTO BATTLE", 20, T.Green, "Display", { Size = UDim2.new(1, 0, 0, 24) })
		local function stepper(y, label, value, onStep, hint)
			UI.Text(auto, label, 16, T.Text, "Bold", { Position = UDim2.fromOffset(0, y + 8), Size = UDim2.new(0.5, 0, 0, 24) })
			UI.Text(auto, hint, 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, y + 30), Size = UDim2.new(0.5, 0, 0, 16) })
			for k, d in ipairs({ -1, 1 }) do
				local _, h = UI.Button(auto, d < 0 and "-" or "+", d < 0 and T.Pink or T.Green, UDim2.fromOffset(44, 40), function()
					onStep(d)
				end)
				h.AnchorPoint = Vector2.new(1, 0)
				h.Position = UDim2.new(1, k == 1 and -128 or 0, 0, y + 4)
			end
			UI.Text(auto, value, 22, T.Gold, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, y + 8), Size = UDim2.fromOffset(74, 30), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local radius = State.SearchRadius()
		stepper(30, "Search range", radius .. "", function(d)
			local v = math.clamp(radius + d * 5, ab.MinRadius, ab.SearchRadius)
			p.settings = p.settings or {}
			p.settings.autoRadius = v
			State.Fire("profile")
			task.spawn(req, "SetAutoSettings", { autoRadius = v })
		end, "how far Auto Battle looks for monsters (studs)")
		local pct = p.settings and p.settings.autoPotionPct or 35
		stepper(86, "Eat below", pct .. "%", function(d)
			local v = math.clamp(pct + d * 5, 0, 90)
			p.settings.autoPotionPct = v
			State.Fire("profile")
			task.spawn(req, "SetAutoSettings", { autoPotionPct = v })
		end, "HP % where Auto Battle eats food")
	end

	render = function()
		local p = State.profile
		sidebar()
		clear(content)
		if not p then
			return
		end
		if skillsView.side == "Loadout" then
			renderLoadout(p)
		else
			renderTree(p)
		end
	end
	render()
	onProfile(win, render)
	win.resized.Event:Connect(render)
end

-- ===================== JOB CHANGE =====================
function Panels.JobMaster()
	local win = UI.Window("Job", "Job Master", UDim2.fromOffset(1000, 620), T.Green, "🎓")
	local function render()
		clear(win.body)
		local p = State.profile
		if not p then
			return
		end
		local switches = p.classSwitches or 0
		local cost = switches == 0 and 0 or p.baseLevel * GameConfig.ClassSwitchCostPerLevel
		local locked = switches == 0 and p.jobLevel < GameConfig.JobChangeLevel
		local info = locked and ("Reach Job Lv." .. GameConfig.JobChangeLevel .. " to switch (you are Job Lv." .. p.jobLevel .. ")")
			or (cost == 0 and "Your first switch is free. Every class keeps its own progress." or ("Switching costs " .. COIN .. " " .. UI.Format(cost) .. ". Every class keeps its own progress."))
		local head = UI.Section(win.body, "🎓", "Choose Your Class", T.Green, info)
		head.Size = UDim2.new(1, 0, 0, 40)
		local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), Parent = win.body })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(234, 244), CellPadding = UDim2.fromOffset(10, 10), Parent = grid })
		for _, cid in ipairs(ClassesCfg.FirstJobs) do
			local c = Classes[cid]
			local current = cid == p.class
			local saved = p.classProgress and p.classProgress[cid]
			local card = UI.Card(grid, nil, c.color:Lerp(T.Panel, current and 0.35 or 0.6))
			if current then
				local st = card:FindFirstChildOfClass("UIStroke")
				if st then
					st.Color = T.Gold
					st.Thickness = 4
				end
			end
			UI.Pad(card, 10)
			UI.List(card, nil, 4)
			local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = card })
			UI.IconChip(top, c.icon, c.color, 38)
			UI.Text(top, c.name, 20, T.Text, "Display", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 0, 22), TextWrapped = false })
			local status = current and ("CURRENT  •  Job Lv." .. p.jobLevel) or (saved and ("Saved: Job Lv." .. saved.jobLevel) or ("Weapon: " .. c.weapons[1]))
			UI.Text(top, status, 12, current and T.Gold or T.TextSoft, "Display", { Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -46, 0, 16), TextWrapped = false })
			UI.Text(card, c.desc or "", 13, T.Text, "Semi", { Size = UDim2.new(1, 0, 0, 52) })
			local names = {}
			for _, s in ipairs(c.skills) do
				table.insert(names, s.name)
			end
			UI.Text(card, table.concat(names, " • "), 11, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 44) })
			local label = current and "Current Class" or (locked and "🔒 Job Lv." .. GameConfig.JobChangeLevel or (saved and "Switch Back" or "Become " .. c.name))
			local btn = UI.Button(card, label, current and T.Grey or (locked and T.Grey or c.color), UDim2.new(1, 0, 0, 40), function()
				if current or locked then
					return
				end
				local msg = "Switch to " .. c.name .. "?" .. (cost > 0 and ("\nCost: " .. UI.Format(cost) .. " Doubloons") or "\nYour first switch is free.") .. "\nYour " .. Classes[p.class].name .. " progress is kept."
				UI.Confirm(msg, function()
					local res = req("ChangeJob", { class = cid })
					if res.ok then
						UI.Banner("Class Change!", c.name, c.color, "Legendary")
					end
				end, nil, "Switch", "Cancel")
			end)
			local _ = btn
		end
	end
	render()
	onProfile(win, render)
end

-- ===================== REFINE / CARDS =====================
function Panels.Refine(opts)
	-- Blacksmith, full screen: sidebar Forge / Insert Card, your gear on the left, the picked piece on a glowing stage.
	-- Forge = refine (+1) with the anvil animation; Insert Card = the item in the middle with a "+" socket per card slot.
	-- Double-clicking gear with card slots in the Bag opens straight on Insert Card.
	opts = opts or {}
	local win = UI.Window("Refine", "Blacksmith", UDim2.fromOffset(1100, 620), T.Orange, "🔨", { fullscreen = true })
	local tab = (opts.tab == "Cards") and "Cards" or "Forge"
	local selected = opts.uid
	local useGuard = false
	local equippedOnly = false
	local busy = false
	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 160, 1, 0), Parent = win.body })
	local listPane = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(172, 0), Size = UDim2.new(0.34, -100, 1, 0), Parent = win.body })
	local stage = UI.Card(win.body, UDim2.new(0.66, -84, 1, 0), T.PanelDeep)
	stage.AnchorPoint = Vector2.new(1, 0)
	stage.Position = UDim2.fromScale(1, 0)
	stage.ClipsDescendants = true
	local render

	local function count(id)
		local n = 0
		for _, x in ipairs(State.profile.inventory) do
			if x.id == id then
				n += x.qty or 1
			end
		end
		return n
	end

	-- the item on its pedestal: spinning rays + glow + the 3D weapon (or the item's icon)
	local function showcase(parent, def, y, size)
		local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(size, size), Parent = parent })
		local tier = ItemDB.Rarity(def)
		local rays = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.focuslines, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.5), ImageTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), Parent = holder })
		local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), BackgroundColor3 = tier.color:Lerp(T.PanelDeep, 0.55), Parent = holder })
		UI.Corner(ring, size)
		UI.Stroke(ring, tier.color:Lerp(Color3.new(1, 1, 1), 0.3), 4)
		New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color, ImageTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = holder })
		local view = def.weaponType and UI.ModelView(holder, "Weapons", def.weaponType, math.floor(size * 0.8), 0.7, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		if not view then
			local img = UI.ItemIconId(def)
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), Parent = holder })
			end
		end
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not rays.Parent then
				conn:Disconnect()
				return
			end
			rays.Rotation = (rays.Rotation + dt * 14) % 360
		end)
		return holder
	end

	-- the anvil: a hammer strikes three times (clang + sparks + shake), then the result shows
	local function anvilAnimation(onDone)
		local layer = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = stage })
		local anvil = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(260, 150), ZIndex = 41, Parent = layer })
		local function block(pos, size, color, z)
			local f = New("Frame", { BackgroundColor3 = color, Position = pos, Size = size, ZIndex = z or 42, Parent = anvil })
			UI.Corner(f, 6)
			UI.Stroke(f, T.Edge, 3)
			return f
		end
		local iron = Color3.fromRGB(70, 74, 88)
		block(UDim2.fromOffset(30, 0), UDim2.fromOffset(200, 42), Color3.fromRGB(96, 100, 118)) -- face
		block(UDim2.fromOffset(0, 6), UDim2.fromOffset(40, 26), Color3.fromRGB(96, 100, 118)) -- horn
		block(UDim2.fromOffset(85, 40), UDim2.fromOffset(90, 60), iron) -- waist
		block(UDim2.fromOffset(50, 98), UDim2.fromOffset(160, 40), iron) -- foot
		local glowBar = block(UDim2.fromOffset(95, -16), UDim2.fromOffset(80, 18), Color3.fromRGB(255, 150, 60), 43) -- hot metal
		local pivot = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 70, 0.62, -120), Size = UDim2.fromOffset(10, 10), Rotation = -60, ZIndex = 44, Parent = layer })
		local hammer = UI.Icon(pivot, "hammer", 120, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(0, 0) })
		if hammer then
			hammer.ZIndex = 45
		end
		local function sparks()
			for _ = 1, 12 do
				local s = New("Frame", { BackgroundColor3 = Color3.fromRGB(255, 210, 90), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, -86), Size = UDim2.fromOffset(6, 6), ZIndex = 46, Parent = layer })
				UI.Corner(s, 3)
				local a = math.random() * math.pi - math.pi
				local d = 60 + math.random() * 120
				UI.Tween(s, 0.45, { Position = UDim2.new(0.5, math.cos(a) * d, 0.62, -86 + math.sin(a) * d * 0.8), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) })
			end
		end
		task.spawn(function()
			for i = 1, 3 do
				UI.Tween(pivot, 0.16, { Rotation = -70 }, Enum.EasingStyle.Quad)
				task.wait(0.18)
				UI.Tween(pivot, 0.08, { Rotation = 25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.08)
				Audio.Play("AnvilClang", { pitch = 0.95 + i * 0.05 })
				sparks()
				glowBar.BackgroundColor3 = Color3.fromRGB(255, 230, 150)
				UI.Tween(glowBar, 0.25, { BackgroundColor3 = Color3.fromRGB(255, 150, 60) })
				anvil.Position = UDim2.new(0.5, 0, 0.62, 4)
				UI.Tween(anvil, 0.12, { Position = UDim2.fromScale(0.5, 0.62) })
				task.wait(0.2)
			end
			task.wait(0.15)
			layer:Destroy()
			onDone()
		end)
	end

	local function renderForge(p, e, def)
		local cur = e.refine or 0
		showcase(stage, def, 170, 250)
		UI.Text(stage, ItemDB.DisplayName(e), 26, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 300), Size = UDim2.new(1, -20, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
		if cur >= GameConfig.Refine.Max then
			UI.Text(stage, "Already at +" .. GameConfig.Refine.Max .. "!", 26, T.Gold, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 350), Size = UDim2.fromOffset(400, 34), TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		local cls = Classes[p.class]
		local chance = math.min(1, GameConfig.Refine.Chance[cur + 1] + (cls and cls.passive and cls.passive.refineBonus or 0))
		local mat, qty, cost = ItemDB.RefineMaterial(cur)
		local md = ItemDB.Get(mat)
		UI.Text(stage, "+" .. cur .. "  ➜  +" .. (cur + 1), 36, T.Gold, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 334), Size = UDim2.fromOffset(300, 40), TextXAlignment = Enum.TextXAlignment.Center })
		-- materials
		local mats = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 382), Size = UDim2.fromOffset(300, 84), Parent = stage })
		UI.List(mats, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
		local function matTile(img, text, enough)
			local t = New("Frame", { Size = UDim2.fromOffset(78, 78), BackgroundColor3 = T.Panel, Parent = mats })
			UI.Corner(t, 12)
			UI.Stroke(t, enough and T.Edge or T.Red, 3)
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.14, 0.04), Parent = t })
			end
			UI.Text(t, text, 14, enough and T.Text or T.Red, "Number", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, -4, 0, 16), TextXAlignment = Enum.TextXAlignment.Right })
		end
		local have = count(mat)
		matTile(UI.ItemIconId(md), have .. "/" .. qty, have >= qty)
		matTile(UI.IconId("coin"), UI.Short(cost), (State.profile.beli or 0) >= cost)
		local cBar = UI.Bar(stage, chance >= 1 and T.Green or (chance >= 0.4 and T.Gold or T.Red), UDim2.fromOffset(360, 24), "Success " .. math.floor(chance * 100) .. "%")
		cBar:Set(chance)
		local barFrame = stage:FindFirstChild("Bar") or stage:GetChildren()[#stage:GetChildren()]
		if barFrame and barFrame:IsA("GuiObject") then
			barFrame.AnchorPoint = Vector2.new(0.5, 0)
			barFrame.Position = UDim2.new(0.5, 0, 0, 476)
		end
		local risk = cur < GameConfig.Refine.Safe and '<font color="#7CFF9B">Safe: cannot fail</font>' or (cur >= GameConfig.Refine.BreakFrom and '<font color="#FF5C6C">Risk: failure may SHATTER the item</font>' or '<font color="#FFB347">Risk: failure drops 1 level</font>')
		UI.Text(stage, risk, 16, T.Text, "Bold", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 508), Size = UDim2.fromOffset(420, 20), TextXAlignment = Enum.TextXAlignment.Center })
		local _, gh = UI.Button(stage, useGuard and "🛡 Charm: ON" or "🛡 Charm: OFF", useGuard and T.Purple or T.Grey, UDim2.fromOffset(170, 50), function()
			useGuard = not useGuard
			render()
		end)
		gh.AnchorPoint = Vector2.new(1, 1)
		gh.Position = UDim2.new(0.5, -110, 1, -16)
		UI.Tooltip(gh:FindFirstChildWhichIsA("TextButton") or gh, function()
			return "Willpower Charm: a failed forge does not drop or break the item (uses one charm)", T.Purple
		end)
		local _, fh = UI.Button(stage, "🔨 FORGE", T.Orange, UDim2.fromOffset(300, 64), function()
			if busy then
				return
			end
			busy = true
			-- ask the server right away, reveal the result after the anvil animation
			local res
			task.spawn(function()
				res = Net.Request("Refine", { uid = e.uid, useGuard = useGuard })
			end)
			anvilAnimation(function()
				while res == nil do
					task.wait()
				end
				busy = false
				local r = res.data and res.data.result
				if r == "success" then
					Audio.Play("RefineSuccess")
					local ne = Formulas.FindItem(State.profile, e.uid) or e
					UI.Banner("Success!", ItemDB.DisplayName(ne), T.Gold, (ne.refine or 0) >= 10 and "Mythic" or ((ne.refine or 0) >= 7 and "Legendary" or nil))
				elseif r == "fail" then
					Audio.Play("RefineFail")
					UI.Banner("Failed...", res.msg, T.Grey)
				elseif r == "broken" then
					Audio.Play("RefineBreak")
					UI.Banner("Shattered!", res.msg, T.Red)
					selected = nil
				else
					UI.Toast(res.msg or "Could not forge", "bad")
				end
				render()
			end)
		end)
		fh.AnchorPoint = Vector2.new(0, 1)
		fh.Position = UDim2.new(0.5, -90, 1, -10)
	end

	-- Insert Card: the item in the middle, a socket per card slot around it; tap "+" to choose a card that fits
	local pickingSlot
	local function renderCards(p, e, def)
		showcase(stage, def, 260, 230)
		UI.Text(stage, ItemDB.DisplayName(e), 24, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 392), Size = UDim2.new(1, -20, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
		local slots = def.slots or 0
		if slots == 0 then
			UI.Text(stage, "This item has no card slots.", 18, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 430), Size = UDim2.fromOffset(400, 24), TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		for k = 1, slots do
			-- sockets sit on an arc above / beside the item
			local a = math.rad(-90 + (k - (slots + 1) / 2) * 70)
			local pos = UDim2.new(0.5, math.cos(a) * 190, 0, 260 + math.sin(a) * 160)
			local cardId = e.cards and e.cards[k]
			local cdef = cardId and ItemDB.Get(cardId)
			local b = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(92, 92), BackgroundColor3 = cdef and Color3.new(1, 1, 1) or T.Panel, Rotation = 45, Parent = stage })
			UI.Corner(b, 16)
			if cdef then
				UI.RarityStyle(b, cdef.rarity, true)
			end
			UI.Stroke(b, pickingSlot == k and T.Gold or T.Edge, pickingSlot == k and 5 or 3)
			local inner = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = -45, Parent = b })
			if cdef then
				local img = UI.ItemIconId(cdef)
				if img then
					New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.125, 0.125), ZIndex = 4, Parent = inner })
				end
				UI.Text(stage, cdef.name, 13, T.Gold, "Bold", { AnchorPoint = Vector2.new(0.5, 0), Position = pos + UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(160, 16), TextXAlignment = Enum.TextXAlignment.Center })
			else
				UI.Text(inner, "+", 46, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
				UI.Tactile(b)
				b.Activated:Connect(function()
					pickingSlot = (pickingSlot == k) and nil or k
					render()
				end)
			end
		end
		-- card picker: cards in the bag that fit this item
		if pickingSlot then
			local pick = UI.Card(stage, UDim2.new(0.42, 0, 1, -20), T.Panel)
			pick.AnchorPoint = Vector2.new(1, 0)
			pick.Position = UDim2.new(1, -10, 0, 10)
			pick.ZIndex = 30
			UI.Pad(pick, 10)
			UI.Text(pick, "PICK A CARD", 18, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 22) })
			local sc = UI.Scroll(pick, UDim2.new(1, 0, 1, -28))
			sc.Position = UDim2.fromOffset(0, 28)
			UI.List(sc, nil, 6)
			local n = 0
			for _, c in ipairs(p.inventory) do
				local cd = ItemDB.Get(c.id)
				if cd and cd.kind == "Card" and (cd.cardSlot == def.slot or cd.cardSlot == def.kind or cd.cardSlot == "Any") then
					n += 1
					local row = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -8, 0, 64), Parent = sc })
					UI.Corner(row, 10)
					UI.RarityStyle(row, cd.rarity)
					UI.Tactile(row)
					local img = UI.ItemIconId(cd)
					if img then
						New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(52, 52), ZIndex = 4, Parent = row })
					end
					UI.Text(row, cd.name .. "  x" .. (c.qty or 1), 15, T.Text, "Bold", { Position = UDim2.fromOffset(64, 4), Size = UDim2.new(1, -70, 0, 20), ZIndex = 4 })
					UI.Text(row, cd.desc or "", 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(64, 24), Size = UDim2.new(1, -70, 0, 36), ZIndex = 4 })
					row.Activated:Connect(function()
						UI.Confirm("Insert " .. cd.name .. " into " .. ItemDB.DisplayName(e) .. "?\nCards cannot be taken out again.", function()
							local res = req("InsertCard", { cardUid = c.uid, targetUid = e.uid })
							if res.ok then
								Audio.Play("AnvilClang", { pitch = 1.3 })
								UI.Banner("Card inserted!", cd.name, T.Gold, cd.rarity)
							end
							pickingSlot = nil
							render()
						end, nil, "Insert", "Cancel")
					end)
				end
			end
			if n == 0 then
				UI.Text(sc, "No cards for this kind of gear in your bag. Monsters drop them now and then.", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 60) })
			end
		end
	end

	render = function()
		clear(side)
		clear(listPane)
		clear(stage)
		local p = State.profile
		if not p then
			return
		end
		-- sidebar
		UI.List(side, nil, 10)
		for i, it in ipairs({ { "Forge", "🔨", "Forge" }, { "Cards", "🃏", "Insert Card" } }) do
			local _, h = UI.Button(side, it[2] .. " " .. it[3], tab == it[1] and T.Orange or T.Grey, UDim2.new(1, -6, 0, 50), function()
				tab = it[1]
				pickingSlot = nil
				render()
			end)
			h.LayoutOrder = i
		end
		-- gear list
		local _, eh = UI.Button(listPane, (equippedOnly and "☑" or "☐") .. " Equipped only", equippedOnly and T.Ocean or T.Grey, UDim2.new(1, 0, 0, 38), function()
			equippedOnly = not equippedOnly
			render()
		end)
		eh.Position = UDim2.fromOffset(0, 0)
		local list = UI.Scroll(listPane, UDim2.new(1, 0, 1, -48))
		list.Position = UDim2.fromOffset(0, 48)
		UI.List(list, nil, 8)
		local first
		for _, e in ipairs(p.inventory) do
			local def = ItemDB.Get(e.id)
			local fits = def and ((tab == "Forge" and def.refinable) or (tab == "Cards" and def.slots and def.slots > 0))
			if fits and (not equippedOnly or equippedUid(e.uid)) then
				first = first or e.uid
				local isSel = selected == e.uid
				local b = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -10, 0, 86), Parent = list })
				UI.Corner(b, 12)
				UI.RarityStyle(b, def.rarity, isSel)
				UI.Tactile(b)
				local img = UI.ItemIconId(def)
				if img then
					New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(70, 70), ZIndex = 4, Parent = b })
				end
				UI.Text(b, ItemDB.DisplayName(e), 17, T.Text, "Display", { Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -92, 0, 22), ZIndex = 4, TextWrapped = false })
				UI.Text(b, (def.reqLevel and ("Lv." .. def.reqLevel .. "  •  ") or "") .. (def.typeLabel or def.kind) .. (equippedUid(e.uid) and "  •  equipped" or ""), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(86, 30), Size = UDim2.new(1, -92, 0, 16), ZIndex = 4 })
				if def.slots and def.slots > 0 then
					local dots = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(86, 54), Size = UDim2.fromOffset(120, 22), ZIndex = 4, Parent = b })
					UI.List(dots, Enum.FillDirection.Horizontal, 6)
					for k = 1, def.slots do
						local filled = e.cards and e.cards[k]
						local d = New("Frame", { Size = UDim2.fromOffset(20, 20), Rotation = 45, BackgroundColor3 = filled and T.Gold or T.PanelDeep, ZIndex = 5, Parent = dots })
						UI.Corner(d, 4)
						UI.Stroke(d, T.Edge, 2)
					end
				end
				b.Activated:Connect(function()
					selected = e.uid
					pickingSlot = nil
					render()
				end)
			end
		end
		if not first then
			UI.Text(list, tab == "Forge" and "Nothing to forge: weapons and armor can be forged." or "No gear with card slots yet.", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 50) })
		end
		local e = selected and Formulas.FindItem(p, selected)
		if not e and first then
			selected = first
			e = Formulas.FindItem(p, first)
		end
		if not e then
			return
		end
		local def = ItemDB.Get(e.id)
		if tab == "Forge" then
			renderForge(p, e, def)
		else
			renderCards(p, e, def)
		end
	end
	render()
	onProfile(win, function()
		if not busy then
			render()
		end
	end)
	win.resized.Event:Connect(render)
end

-- ===================== SHOP =====================
function Panels.Shop()
	local win = UI.Window("Shop", "General Store", UDim2.fromOffset(640, 580), T.Green, "🛒")
	local list = UI.Scroll(win.body)
	UI.List(list, nil, 6)
	UI.Section(list, "🧺", "Supplies", T.Green)
	for _, id in ipairs(ItemDB.Shop) do
		local def = ItemDB.Get(id)
		local card = New("Frame", { Size = UDim2.new(1, -12, 0, 60), Parent = list })
		UI.Corner(card, 12)
		UI.RarityStyle(card, def.rarity)
		UI.Pad(card, 8)
		UI.Text(card, (kindIcon[def.kind] or "") .. " " .. def.name, 18, T.Text, "Display", { Size = UDim2.new(1, -230, 0, 22), ZIndex = 4 })
		UI.Text(card, COIN .. " " .. UI.Format(def.price) .. (def.desc and ("  •  " .. def.desc) or ""), 14, T.Text, "Semi", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -230, 0, 20), ZIndex = 4 })
		-- ammo comes in handfuls
		local q1, q2 = 1, 10
		if def.kind == "Ammo" then
			q1, q2 = 20, 99
		end
		local _, h = UI.Button(card, q1 == 1 and "Buy" or ("x" .. q1), T.Green, UDim2.fromOffset(100, 40), function()
			req("ShopBuy", { id = id, qty = q1 }, "Purchase")
		end)
		h.Position = UDim2.new(1, -210, 0, 2)
		h.ZIndex = 5
		if def.stack then
			local _, h2 = UI.Button(card, "x" .. q2, T.Ocean, UDim2.fromOffset(96, 40), function()
				req("ShopBuy", { id = id, qty = q2 }, "Purchase")
			end)
			h2.Position = UDim2.new(1, -100, 0, 2)
			h2.ZIndex = 5
		end
	end
end

-- ===================== TAVERN =====================
function Panels.Tavern()
	local win = UI.Window("Tavern", "Tavern", UDim2.fromOffset(560, 360), T.Red, "🍺")
	local p = State.profile
	local design = p.ships[p.activeShip] or p.ships[1]
	local st = ShipStats.Compute(design, p.crew)
	UI.List(win.body, nil, 10)
	UI.Section(win.body, "🧑‍✈️", "Crew", T.Red, p.crew .. " / " .. st.crewCap .. " bunks")
	UI.Text(win.body, "Each crew member mans 1 cannon and rows 1 oar bench.\nBuild Crew Cabins at the shipyard for more bunks.", 16, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 44) })
	local cost = math.floor(GameConfig.Ship.CrewCost * (1 + math.floor(p.crew / 4) * 0.5))
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Parent = win.body })
	UI.List(row, Enum.FillDirection.Horizontal, 10)
	UI.Button(row, "Hire 1  (" .. COIN .. UI.Format(cost) .. ")", T.Green, UDim2.fromOffset(250, 50), function()
		req("RecruitCrew", { count = 1 }, "Purchase")
		win:Destroy()
		Panels.Tavern()
	end)
	UI.Button(row, "Hire 4", T.Ocean, UDim2.fromOffset(170, 50), function()
		req("RecruitCrew", { count = 4 }, "Purchase")
		win:Destroy()
		Panels.Tavern()
	end)
end

-- ===================== SHIPYARD =====================
function Panels.Shipwright()
	local win = UI.Window("Shipyard", "Shipyard", UDim2.fromOffset(760, 520), T.OceanDark, "⚓")
	local p = State.profile
	UI.List(win.body, nil, 10)
	UI.Section(win.body, "⛵", "Your Ships", T.Ocean, "3 slots")
	for slot = 1, 3 do
		local d = p.ships[slot]
		local card = UI.Card(win.body, UDim2.new(1, 0, 0, 108), slot == p.activeShip and T.OceanDark:Lerp(T.Panel, 0.5) or nil)
		UI.Pad(card, 10)
		if d then
			local st = ShipStats.Compute(d, p.crew, { shipSpeed = State.derived and State.derived.shipSpeed })
			UI.Text(card, "⛵ " .. d.name .. (slot == p.activeShip and '  <font color="#FFD54A">(active)</font>' or ""), 22, T.Text, "Display", { Size = UDim2.new(1, -250, 0, 26) })
			UI.Text(card, string.format("%d parts • weight %d • HP %d • %d cannons\nSpeed: %d in wind / %d in the Doldrums", st.partCount, st.weight, st.hp, #st.cannons, ShipStats.Speed(st, 1), ShipStats.Speed(st, 0)), 15, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -250, 0, 40) })
			if p.shipSunk and slot == p.activeShip then
				UI.Text(card, "⚠️ Sunk: repairs are charged when you launch", 14, T.Red, "Bold", { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, -250, 0, 18) })
			end
		else
			UI.Text(card, "Empty slot: build a new ship", 22, T.TextSoft, "Display")
		end
		local _, h1 = UI.Button(card, d and "🔨 Edit" or "🔨 Build", T.Orange, UDim2.fromOffset(116, 44), function()
			local res = req("BuildEnter", { slot = slot })
			if res.ok then
				win:Destroy()
			end
		end)
		h1.Position = UDim2.new(1, -240, 0, 20)
		if d then
			local _, h2 = UI.Button(card, "⛵ Launch", T.Green, UDim2.fromOffset(116, 44), function()
				local res = req("LaunchShip", { slot = slot }, "Bell")
				if res.ok then
					win:Destroy()
					UI.Banner("Set Sail!", "W/S sails  •  A/D steer  •  click water to fire cannons", T.Ocean)
				end
			end)
			h2.Position = UDim2.new(1, -118, 0, 20)
		end
	end
end

-- ===================== MAP / FAST TRAVEL =====================
function Panels.FastTravel()
	local win = UI.Window("Map", Islands.SeaName, UDim2.fromOffset(1000, 480), T.Ocean, "🗺️", { fullscreen = true })
	-- the sea strip sits in the middle of the window (full screen used to leave it stuck to the top)
	local strip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, -36), Size = UDim2.new(1, 0, 0, 280), Parent = win.body })
	UI.Corner(strip, 16)
	UI.Gradient(strip, Color3.fromRGB(110, 210, 245), Color3.fromRGB(50, 150, 210), 90)
	UI.Stroke(strip, T.Edge, 3)
	for _, top in ipairs({ true, false }) do
		local calm = New("Frame", { BackgroundColor3 = Color3.fromRGB(30, 90, 115), Size = UDim2.new(1, 0, 0, 42), Position = top and UDim2.new() or UDim2.new(0, 0, 1, -42), Parent = strip })
		UI.Corner(calm, 16)
		UI.Text(calm, "☠  " .. string.upper(Islands.CalmName) .. "  •  no wind, Leviathans", 16, Color3.fromRGB(190, 230, 240), "Bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	end
	local p = State.profile
	local n = #Islands.List
	for i, isl in ipairs(Islands.List) do
		local x = (i - 0.5) / (n + 1)
		local unlocked = p.unlocked[isl.id]
		local dot = New("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = strip })
		UI.Corner(dot, 55)
		UI.Gradient(dot, unlocked and isl.palette.grass:Lerp(Color3.new(1, 1, 1), 0.2) or Color3.fromRGB(150, 160, 170), unlocked and isl.palette.sand or Color3.fromRGB(100, 110, 120), 90)
		UI.Stroke(dot, unlocked and T.Gold or T.Edge, 3.5)
		UI.Tactile(dot)
		UI.Text(dot, isl.name, 16, T.Text, "Display", { Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
		UI.Text(dot, "Lv." .. isl.levels[1] .. "-" .. isl.levels[2], 14, Rarity.LevelColor(player:GetAttribute("Level") or 1, isl.levels[1]), "Number", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
		if not unlocked then
			UI.Text(dot, "🔒", 22, T.Text, "Display", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local found, total = 0, 0
		for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Chest")) do
			if m:GetAttribute("Island") == isl.id then
				total += 1
				if p.chests and p.chests[m:GetAttribute("ChestId")] then
					found += 1
				end
			end
		end
		if total > 0 then
			UI.Text(strip, "🧰 " .. found .. "/" .. total, 15, found == total and T.Gold or T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0.5, 60), Size = UDim2.fromOffset(100, 18), TextXAlignment = Enum.TextXAlignment.Center })
		end
		dot.Activated:Connect(function()
			if not unlocked then
				UI.Toast("Not discovered yet: sail there first", "bad")
				return
			end
			UI.Confirm("Fly by courier gull to " .. isl.name .. "?\nCost " .. COIN .. " " .. (100 * i), function()
				req("FastTravel", { island = isl.id })
				win:Destroy()
			end, nil, "Travel", "Cancel")
		end)
	end
	local rl = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(1 / (n + 1), -10, 1, 0), BackgroundColor3 = Color3.fromRGB(196, 72, 56), Parent = strip })
	UI.Corner(rl, 16)
	UI.Stroke(rl, T.Edge, 3)
	UI.Text(rl, string.upper(Islands.RedLine.name) .. "\n⛰\nLv." .. GameConfig.GrandLineLevel, 18, T.Text, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	UI.Text(win.body, "Islands lie in a straight line: sail east to reach the next one. Stay in the windy lane: the Doldrums at the edges have no wind and Leviathans. Past " .. Islands.List[n].name .. ", " .. Islands.RedLine.peakName .. " leads to the " .. Islands.RedLine.nextSea .. " (next update).", 16, T.TextSoft, "Semi", { Position = UDim2.new(0, 0, 0.5, 112), Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center })
end
Panels.Map = Panels.FastTravel

-- ===================== BOSS BOARD =====================
function Panels.BossBoard()
	local win = UI.Window("Boss", "Bosses & Bounties", UDim2.fromOffset(780, 580), T.Red, "👑")
	task.spawn(Net.Request, "GetBossBoard")
	task.spawn(Net.Request, "GetGuildWar")
	local list = UI.Scroll(win.body, UDim2.new(0.6, 0, 1, 0))
	local poster = New("Frame", { BackgroundColor3 = Color3.fromRGB(244, 226, 186), Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.new(0.62, 0, 0, 0), Parent = win.body })
	UI.Corner(poster, 6)
	UI.Stroke(poster, Color3.fromRGB(110, 76, 40), 4)
	UI.Pad(poster, 12)
	UI.List(poster, nil, 6, Enum.HorizontalAlignment.Center)
	local p = State.profile
	local ink = Color3.fromRGB(70, 44, 24)
	local function posterText(text, size, kind)
		local t = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size + 6), Text = text, TextSize = size, FontFace = UI.Fonts[kind], TextColor3 = ink, TextWrapped = true, Parent = poster })
		return t
	end
	posterText(p.faction == "Marine" and "MARINE" or "WANTED", 44, "Display")
	posterText(p.faction == "Marine" and "SERVICE RECORD" or "DEAD OR ALIVE", 16, "Bold")
	local photo = New("ImageLabel", { Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.fromRGB(220, 200, 160), Parent = poster })
	UI.Stroke(photo, ink, 3)
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then
			photo.Image = url
		end
	end)
	posterText(string.upper(player.DisplayName), 24, "Display")
	posterText(p.faction == "Marine" and ("Merit " .. UI.Format(player:GetAttribute("Merit") or 0)) or (COIN .. " " .. UI.Format(p.bounty)), 28, "Number")
	posterText((p.faction == "None" and "Civilian" or p.faction) .. (player:GetAttribute("GuildName") and ("  •  " .. player:GetAttribute("GuildName")) or ""), 15, "Bold")
	local function render()
		clear(list)
		UI.List(list, nil, 6)
		UI.Section(list, "👑", "MVP Bosses", T.Red)
		local board = State.bossBoard
		if board then
			for _, b in ipairs(board.list) do
				local card = UI.Card(list, UDim2.new(1, -12, 0, 62), b.alive and Color3.fromRGB(110, 30, 44) or nil)
				UI.Pad(card, 8)
				UI.Text(card, "☠ " .. b.name, 19, b.alive and T.Red or T.Text, "Display", { Size = UDim2.new(1, 0, 0, 22) })
				local left = b.nextSpawn - board.serverTime - (os.clock() - (board.receivedAt or os.clock()))
				UI.Text(card, "Lv." .. b.level .. "  •  " .. b.island .. "  •  " .. (b.alive and "ALIVE NOW!" or string.format("respawns in %d:%02d", math.max(0, left) // 60, math.max(0, left) % 60)), 15, b.alive and T.Gold or T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 26) })
			end
		end
		local gw = State.guildWar
		if gw then
			UI.Section(list, "⚔️", "Guild War", gw.active and T.Red or T.Gold, gw.active and "IN PROGRESS!" or "Saturdays")
			for _, f in ipairs(gw.forts) do
				UI.Text(list, "🏰 " .. f.name .. "  •  held by " .. f.owner, 16, f.faction == "Marine" and T.Marine or (f.faction == "Pirate" and T.Pirate or T.TextSoft), "Bold")
			end
		end
	end
	render()
	local conn = State.Changed:Connect(function(k)
		if k == "bossBoard" or k == "guildWar" then
			render()
		end
	end)
	win.frame.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

-- ===================== GUILD =====================
function Panels.Guild()
	local win = UI.Window("Guild", "Guild", UDim2.fromOffset(820, 580), T.Purple, "🏴")
	task.spawn(Net.Request, "GuildInfo")
	local body = win.body
	local function render()
		clear(body)
		local oldLayout = body:FindFirstChildOfClass("UIListLayout")
		if oldLayout then
			oldLayout:Destroy()
		end
		local g = State.guild
		if g then
			local color = g.faction == "Marine" and T.Marine or T.Pirate
			UI.List(body, nil, 8)
			UI.Text(body, (g.faction == "Marine" and "⚓ " or "☠️ ") .. g.name .. "  Lv." .. g.level, 32, color, "Display")
			UI.Text(body, "Faction: " .. g.faction, 18, T.TextSoft, "Semi")
			UI.Section(body, "👥", "Members", color)
			local list = UI.Scroll(body, UDim2.new(1, 0, 0, 280))
			UI.List(list, nil, 4)
			for uid, m in pairs(g.members) do
				local row = UI.Card(list, UDim2.new(1, -12, 0, 46))
				UI.Pad(row, 8)
				UI.Text(row, (m.rank == "Leader" and "👑 " or "• ") .. m.name .. "  [" .. m.rank .. "]", 17, T.Text, "Bold")
				if g.leader == player.UserId and tonumber(uid) ~= player.UserId then
					local _, h = UI.Button(row, "Kick", T.Red, UDim2.fromOffset(74, 32), function()
						req("GuildKick", { userId = uid })
					end)
					h.Position = UDim2.new(1, -76, 0, -2)
				end
			end
			UI.Button(body, "Leave Guild", T.Red, UDim2.fromOffset(190, 46), function()
				UI.Confirm("Leave the guild? You will become a Civilian again.", function()
					req("GuildLeave")
				end, nil, "Leave", "Stay")
			end)
			return
		end
		local left = UI.Card(body, UDim2.new(0.48, 0, 1, 0))
		UI.Pad(left, 14)
		UI.List(left, nil, 8)
		UI.Section(left, "🏗️", "Found a Guild", T.Gold)
		UI.Text(left, "Requires Lv." .. GameConfig.GuildCreateLevel .. "  •  " .. COIN .. " " .. UI.Format(GameConfig.GuildCreateCost), 15, T.TextSoft, "Semi")
		local box = New("TextBox", { Size = UDim2.new(1, 0, 0, 44), PlaceholderText = "Guild name", Text = "", FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, PlaceholderColor3 = T.TextSoft, BackgroundColor3 = T.PanelDeep, Parent = left })
		UI.Corner(box, 10)
		UI.Stroke(box, T.Edge, 2.5)
		local faction = "Pirate"
		local fRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100), Parent = left })
		UI.List(fRow, Enum.FillDirection.Horizontal, 8)
		local mBtn = UI.Button(fRow, "⚓ MARINE", T.Grey, UDim2.fromOffset(170, 92))
		local pBtn = UI.Button(fRow, "☠️ PIRATE", T.Pirate, UDim2.fromOffset(170, 92))
		local desc = UI.Text(left, "", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 96) })
		local function updateF()
			UI.SetButtonColor(mBtn, faction == "Marine" and T.Marine or T.Grey)
			UI.SetButtonColor(pBtn, faction == "Pirate" and T.Pirate or T.Grey)
			desc.Text = faction == "Marine" and "Marines: Marine NPC ships leave you alone. Catch pirates for Merit and a cut of their bounty. Unlocks the Marine Mast." or "Pirates: every NPC ship is fair game. Beating Marines and sinking their ships raises your bounty. Unlocks the Jolly Roger Mast."
		end
		mBtn.Activated:Connect(function()
			faction = "Marine"
			updateF()
		end)
		pBtn.Activated:Connect(function()
			faction = "Pirate"
			updateF()
		end)
		updateF()
		UI.Button(left, "Found Guild", T.Green, UDim2.new(1, 0, 0, 48), function()
			req("GuildCreate", { name = box.Text, faction = faction }, "Purchase")
		end)
		local right = UI.Scroll(body, UDim2.new(0.5, 0, 1, 0))
		right.Position = UDim2.new(0.5, 0, 0, 0)
		UI.List(right, nil, 6)
		UI.Section(right, "🤝", "Join a Guild", T.Green)
		task.spawn(function()
			local res = Net.Request("GuildList")
			for _, g2 in ipairs(res.data or {}) do
				local row = UI.Card(right, UDim2.new(1, -12, 0, 52), g2.faction == "Marine" and T.Marine:Lerp(T.Panel, 0.6) or T.Pirate:Lerp(T.Panel, 0.6))
				UI.Pad(row, 8)
				UI.Text(row, (g2.faction == "Marine" and "⚓ " or "☠️ ") .. g2.name .. "  (" .. g2.count .. ")", 17, T.Text, "Bold")
				local _, h = UI.Button(row, "Join", T.Green, UDim2.fromOffset(84, 34), function()
					req("GuildJoin", { id = g2.id })
				end)
				h.Position = UDim2.new(1, -86, 0, -2)
			end
		end)
	end
	render()
	local conn = State.Changed:Connect(function(k)
		if k == "guild" then
			render()
		end
	end)
	win.frame.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

-- ===================== DUNGEON =====================
function Panels.Dungeon(args)
	local d = Dungeons[args and args.dungeonId or "CircusTent"]
	if not d then
		return
	end
	local win = UI.Window("Dungeon", d.name, UDim2.fromOffset(560, 400), T.Purple, "🏰")
	UI.List(win.body, nil, 10)
	UI.Text(win.body, "Min Lv." .. d.minLevel .. "  •  Party up to " .. d.maxParty .. "  •  " .. (d.timeLimit // 60) .. " min limit  •  " .. (d.cooldown // 60) .. " min cooldown", 16, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 40) })
	UI.Section(win.body, "🌊", #d.waves .. " Waves + Boss", T.Purple)
	UI.Text(win.body, "Rewards: " .. COIN .. " " .. UI.Format(d.reward.beli) .. "  •  " .. UI.Format(d.reward.exp) .. " EXP  •  refine materials", 16, T.Gold, "Bold")
	UI.Button(win.body, "⚔️ ENTER (whole party)", T.Red, UDim2.new(1, 0, 0, 56), function()
		local res = req("DungeonEnter", { id = args.dungeonId })
		if res.ok then
			win:Destroy()
		end
	end)
end

-- ===================== PARTY / PLAYERS =====================
function Panels.Party()
	local win = UI.Window("Party", "Party & Players", UDim2.fromOffset(660, 560), T.Green, "👥")
	local body = win.body
	local function render()
		clear(body)
		UI.List(body, nil, 6)
		UI.Section(body, "👥", "Your Party", T.Green, "shared EXP")
		if #State.party == 0 then
			UI.Text(body, "You are not in a party.", 16, T.TextSoft, "Semi")
		else
			for _, m in ipairs(State.party) do
				UI.Text(body, (m.leader and "👑 " or "• ") .. m.name, 17, T.Text, "Bold")
			end
			UI.Button(body, "Leave Party", T.Red, UDim2.fromOffset(170, 42), function()
				req("PartyLeave")
			end)
		end
		UI.Section(body, "🌐", "Players Here", T.Ocean)
		local list = UI.Scroll(body, UDim2.new(1, 0, 0, 280))
		UI.List(list, nil, 4)
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= player then
				local row = UI.Card(list, UDim2.new(1, -12, 0, 48))
				UI.Pad(row, 8)
				local f = pl:GetAttribute("Faction") or "None"
				UI.Text(row, pl.DisplayName .. "  Lv." .. (pl:GetAttribute("Level") or 1) .. "  " .. (pl:GetAttribute("ClassName") or ""), 16, f == "Marine" and T.Marine or (f == "Pirate" and T.Pirate or T.Text), "Bold")
				local _, h1 = UI.Button(row, "Invite", T.Green, UDim2.fromOffset(78, 32), function()
					req("PartyInvite", { userId = pl.UserId })
				end)
				h1.Position = UDim2.new(1, -164, 0, -2)
				local _, h2 = UI.Button(row, "Duel", T.Red, UDim2.fromOffset(78, 32), function()
					req("DuelRequest", { userId = pl.UserId })
				end)
				h2.Position = UDim2.new(1, -80, 0, -2)
			end
		end
	end
	render()
	local conn = State.Changed:Connect(function(k)
		if k == "party" then
			render()
		end
	end)
	win.frame.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

-- ===================== MARKET (buyer) =====================
function Panels.Stall(args)
	local res = Net.Request("StallView", { sellerId = args.sellerId })
	if not res.ok then
		UI.Toast(res.msg or "This stall is closed", "bad")
		return
	end
	local data = res.data
	local win = UI.Window("Stall", data.title, UDim2.fromOffset(640, 540), T.Orange, "🏪")
	local pearlStall = data.currency == "pearls"
	local CUR = pearlStall and PearlsCfg.Icon or COIN
	local have = pearlStall and (State.profile.pearls or 0) or State.profile.beli
	UI.Text(win.body, "Seller: " .. data.seller .. "   •   You have " .. CUR .. " " .. UI.Format(have) .. (pearlStall and " tradable Pearls" or ""), 16, T.TextSoft, "Semi")
	local list = UI.Scroll(win.body, UDim2.new(1, 0, 1, -32))
	list.Position = UDim2.fromOffset(0, 32)
	UI.List(list, nil, 6)
	for _, it in ipairs(data.items) do
		if it.qty > 0 then
			local def = ItemDB.Get(it.id)
			local card = New("Frame", { Size = UDim2.new(1, -12, 0, 64), Parent = list })
			UI.Corner(card, 12)
			UI.RarityStyle(card, def and def.rarity)
			UI.Pad(card, 8)
			UI.Text(card, ItemDB.DisplayName(it) .. "  x" .. it.qty, 18, T.Text, "Display", { Size = UDim2.new(1, -150, 0, 22), ZIndex = 4 })
			UI.Text(card, CUR .. " " .. UI.Format(it.price) .. " each", 15, T.Text, "Number", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -150, 0, 20), ZIndex = 4 })
			local _, h = UI.Button(card, "Buy", T.Green, UDim2.fromOffset(120, 42), function()
				local r = req("StallBuy", { sellerId = args.sellerId, index = it.index, qty = 1 }, "Purchase")
				if r.ok then
					win:Destroy()
					Panels.Stall(args)
				end
			end)
			h.Position = UDim2.new(1, -122, 0, 2)
			h.ZIndex = 5
		end
	end
end

-- ===================== MARKET (seller) =====================
function Panels.StallSetup()
	local win = UI.Window("StallSetup", "Your Stall", UDim2.fromOffset(740, 580), T.Orange, "🏪")
	if State.stall.open then
		UI.List(win.body, nil, 6)
		UI.Text(win.body, State.stall.title, 26, T.Gold, "Display")
		for _, it in ipairs(State.stall.items or {}) do
			UI.Text(win.body, ItemDB.DisplayName(it) .. " x" .. it.qty .. "   " .. (it.currency == "pearls" and PearlsCfg.Icon or COIN) .. " " .. UI.Format(it.price), 17, T.Text, "Bold")
		end
		UI.Button(win.body, "Close Stall (returns unsold items)", T.Red, UDim2.fromOffset(340, 48), function()
			req("StallClose")
			win:Destroy()
		end)
		return
	end
	local currency = "beli"
	local curRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.38, 0, 0, 44), Parent = win.body })
	local function drawCurrency()
		for _, c in ipairs(curRow:GetChildren()) do
			c:Destroy()
		end
		UI.TabBar(curRow, { { "beli", COIN, "Doubloons", T.Gold }, { "pearls", PearlsCfg.Icon, "Pearls", T.Ocean } }, currency, function(id)
			currency = id
			drawCurrency()
			if id == "pearls" then
				UI.Toast("Pearl stalls: Lv." .. PearlsCfg.Trade.MinLevel .. "+, " .. math.floor(PearlsCfg.Trade.TaxRate * 100) .. "% tax, " .. math.floor(PearlsCfg.Trade.ListingFeeRate * 100) .. "% listing fee, items held " .. PearlsCfg.Trade.LockHours .. "h can't be listed", "info")
			end
		end, 36)
	end
	drawCurrency()
	local title = New("TextBox", { Size = UDim2.new(0.6, 0, 0, 44), PlaceholderText = "Stall name, e.g. Cheap Cards!", Text = "", FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, PlaceholderColor3 = T.TextSoft, BackgroundColor3 = T.PanelDeep, Parent = win.body })
	UI.Corner(title, 10)
	UI.Stroke(title, T.Edge, 2.5)
	local list = UI.Scroll(win.body, UDim2.new(1, 0, 1, -120))
	list.Position = UDim2.fromOffset(0, 54)
	UI.List(list, nil, 4)
	local chosen = {}
	local p = State.profile
	for _, e in ipairs(p.inventory) do
		local def = ItemDB.Get(e.id)
		if def and not equippedUid(e.uid) then
			local row = New("Frame", { Size = UDim2.new(1, -12, 0, 50), Parent = list })
			UI.Corner(row, 10)
			UI.RarityStyle(row, def.rarity)
			UI.Pad(row, 6)
			UI.Text(row, ItemDB.DisplayName(e) .. " x" .. (e.qty or 1), 16, T.Text, "Bold", { Size = UDim2.new(1, -270, 1, 0), ZIndex = 4 })
			local price = New("TextBox", { Position = UDim2.new(1, -262, 0, 2), Size = UDim2.fromOffset(130, 34), PlaceholderText = "Price", Text = tostring(def.price or 100), FontFace = UI.Fonts.Number, TextSize = 18, TextColor3 = T.Text, BackgroundColor3 = T.PanelDeep, ZIndex = 5, Parent = row })
			UI.Corner(price, 8)
			local btn, h = UI.Button(row, "Pick", T.Grey, UDim2.fromOffset(118, 34), nil)
			h.Position = UDim2.new(1, -122, 0, 2)
			h.ZIndex = 5
			btn.Activated:Connect(function()
				if chosen[e.uid] then
					chosen[e.uid] = nil
					UI.SetButtonColor(btn, T.Grey)
					btn.Text = "Pick"
				else
					chosen[e.uid] = price
					UI.SetButtonColor(btn, T.Green)
					btn.Text = "✓ Listed"
				end
			end)
		end
	end
	local _, h = UI.Button(win.body, "OPEN STALL", T.Green, UDim2.new(1, 0, 0, 52), function()
		local items = {}
		for uid, box in pairs(chosen) do
			local e = Formulas.FindItem(p, uid)
			table.insert(items, { uid = uid, price = tonumber(box.Text) or 0, qty = e and e.qty or 1 })
		end
		local res = req("StallOpen", { title = title.Text ~= "" and title.Text or (player.DisplayName .. "'s Stall"), items = items, currency = currency }, "Purchase")
		if res.ok then
			win:Destroy()
		end
	end)
	h.Position = UDim2.new(0, 0, 1, -54)
end

-- ===================== SETTINGS =====================
-- Anime-Vanguards-style: category sidebar on the left, toggle rows on the right
local settingsCategory = "Graphics"
function Panels.Settings()
	local win = UI.Window("Settings", "Settings", UDim2.fromOffset(820, 600), T.Accent, "⚙️")
	local side = UI.Card(win.body, UDim2.new(0, 190, 1, 0), T.PanelDeep)
	UI.Pad(side, 8)
	UI.List(side, nil, 6)
	local list = UI.Scroll(win.body, UDim2.new(1, -204, 1, 0))
	list.Position = UDim2.fromOffset(204, 0)
	local cats = { { "Graphics", "🖥️" }, { "Audio", "🔊" }, { "Interface", "🧭" }, { "Auto Battle", "🤖" } }
	if RunService:IsStudio() or game.CreatorId == player.UserId then
		table.insert(cats, { "Developer", "🛠️" })
	end
	local render
	local function sidebar()
		clear(side)
		for _, c in ipairs(cats) do
			UI.Button(side, c[2] .. "  " .. c[1], settingsCategory == c[1] and T.Accent or T.Grey, UDim2.new(1, 0, 0, 44), function()
				settingsCategory = c[1]
				sidebar()
				render()
			end)
		end
	end
	local function slider(key, label)
		local v = Settings.Values
		local r = UI.Card(list, UDim2.new(1, -8, 0, 52), T.Panel)
		UI.Text(r, label, 17, T.Text, "Bold", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.32, 0, 1, 0) })
		local bar = UI.Bar(r, T.Accent, UDim2.new(0.38, 0, 0, 20), math.floor(v[key] * 100) .. "%")
		bar.back.Position = UDim2.new(0.34, 0, 0, 16)
		bar:Set(v[key])
		local _, m = UI.Button(r, "-", T.Pink, UDim2.fromOffset(44, 38), function()
			Settings.Set(key, math.max(0, math.floor((v[key] - 0.1) * 10 + 0.5) / 10))
			render()
		end)
		m.Position = UDim2.new(0.75, 0, 0, 6)
		local _, pl = UI.Button(r, "+", T.Green, UDim2.fromOffset(44, 38), function()
			Settings.Set(key, math.min(1, math.floor((v[key] + 0.1) * 10 + 0.5) / 10))
			render()
		end)
		pl.Position = UDim2.new(0.75, 52, 0, 6)
	end
	render = function()
		clear(list)
		UI.List(list, nil, 8)
		local v = Settings.Values
		local catIcon = "⚙️"
		for _, c in ipairs(cats) do
			if c[1] == settingsCategory then
				catIcon = c[2]
			end
		end
		UI.Section(list, catIcon, settingsCategory, T.Accent)
		if settingsCategory == "Graphics" then
			local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = list })
			UI.List(row, Enum.FillDirection.Horizontal, 8)
			for _, q in ipairs(Settings.Presets) do
				UI.Button(row, q, v.quality == q and T.Green or T.Grey, UDim2.fromOffset(132, 46), function()
					Settings.Set("quality", q)
					render()
				end)
			end
			UI.Text(list, "Low: hides props, shadows and post effects (phones)\nMedium: hides small props\nHigh: everything on (PC)\nUltra: + depth of field, denser wind", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 76) })
			UI.Toggle(list, "Damage Numbers", v.damageNumbers, function(on)
				Settings.Set("damageNumbers", on)
			end, "Floating numbers and crit starbursts")
		elseif settingsCategory == "Audio" then
			for _, a in ipairs({ { "master", "Master" }, { "music", "Music" }, { "sfx", "Effects" }, { "ui", "Interface" }, { "ambience", "Ocean & Wind" } }) do
				slider(a[1], a[2])
			end
		elseif settingsCategory == "Interface" then
			UI.Toggle(list, "Range Rings", v.rangeRings, function(on)
				Settings.Set("rangeRings", on)
			end, "Attack/skill range under you and cannon arcs on the water")
			UI.Toggle(list, "Navigation Guide", v.navGuide, function(on)
				Settings.Set("navGuide", on)
			end, "Dotted line and distance to the next island while sailing")
			local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = list })
			UI.List(row, Enum.FillDirection.Horizontal, 8)
			for _, sc in ipairs({ { 0.85, "UI Small" }, { 1, "UI Normal" }, { 1.15, "UI Large" } }) do
				UI.Button(row, sc[2], math.abs(v.uiScale - sc[1]) < 0.01 and T.Accent or T.Grey, UDim2.fromOffset(150, 46), function()
					Settings.Set("uiScale", sc[1])
					render()
				end)
			end
		elseif settingsCategory == "Auto Battle" then
			local p = State.profile
			local pct = p and p.settings.autoPotionPct or 35
			local r = UI.Card(list, UDim2.new(1, -8, 0, 56), T.Panel)
			UI.Text(r, "Eat food below " .. pct .. "% HP", 18, T.Text, "Bold", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0) })
			for i, delta in ipairs({ -10, 10 }) do
				local _, h = UI.Button(r, (delta > 0 and "+" or "") .. delta .. "%", delta > 0 and T.Green or T.Pink, UDim2.fromOffset(84, 40), function()
					req("SetAutoSettings", { autoPotionPct = math.clamp(pct + delta, 0, 90) })
					task.wait(0.4)
					render()
				end)
				h.Position = UDim2.new(1, -184 + (i - 1) * 92, 0, 8)
			end
			UI.Text(list, "Press T or the AUTO button to toggle. Auto Battle fights within your search range (now " .. State.SearchRadius() .. " studs, change it in Skills -> Loadout) and never wanders more than " .. GameConfig.AutoBattle.LeashRadius .. " studs from where it started. Pick which skills it uses in Skills -> Loadout (green tick = Auto).", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 80) })
		elseif settingsCategory == "Developer" then
			UI.Text(list, "Only works in Studio or for the game's owner.", 13, T.TextSoft, "Semi")
			local function devGrid(title, icon, color, buttons)
				UI.Section(list, icon, title, color)
				local rows = math.ceil(#buttons / 3)
				local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * 54), Parent = list })
				New("UIGridLayout", { CellSize = UDim2.fromOffset(176, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
				for _, c in ipairs(buttons) do
					UI.Button(grid, c[1], color, nil, function()
						req("Admin", { cmd = c[2], value = c[3] })
					end)
				end
			end
			devGrid("Player", "🧪", T.Accent, { { "Reset Lv1", "resetlevel" }, { "Lv70", "level" }, { "Job Lv.10", "joblevel" }, { "+1M " .. COIN, "beli" }, { "Materials", "items" }, { "+1000 " .. PearlsCfg.Icon, "pearls" }, { "Next Quest", "questnext" } })
			local fruitButtons = {}
			for _, f in ipairs(FruitsCfg.List) do
				table.insert(fruitButtons, { f.icon .. " " .. f.id, "fruit", f.id })
			end
			table.insert(fruitButtons, { "+Mastery", "mastery" })
			table.insert(fruitButtons, { "Remove Fruit", "removefruit" })
			table.insert(fruitButtons, { "Spawn Tree Fruit", "spawnfruit" })
			devGrid("Cursed Fruits", "🍎", T.Pink, fruitButtons)
			devGrid("Pets & World", "🐾", T.Green, { { "Eggs + Bait", "eggs" }, { "Pet +15 Lv", "petlevel" }, { "Reset Chests", "chestreset" }, { "Model Gallery", "models" }, { "Guild War", "gw_start" }, { "End War", "gw_end" } })
			-- time of day preview (client only)
			UI.Section(list, "🌅", "Time of Day", T.Gold)
			local tgrid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 108), Parent = list })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(176, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = tgrid })
			for _, c in ipairs({ { "Sunrise", 6.4 }, { "Noon", 13 }, { "Golden Hour", 16.8 }, { "Sunset", 18.3 }, { "Night (moon)", 23 }, { "Live cycle", false } }) do
				UI.Button(tgrid, c[1], T.Gold, nil, function()
					Atmos.SetClock(c[2] or nil)
				end)
			end
			-- animation self-check: what the animation controllers see (send a screenshot of this if poses do not play)
			UI.Section(list, "🥊", "Animation Check", T.Pink)
			local info = UI.Text(list, "", 15, T.Text, "Semi", { Size = UDim2.new(1, 0, 0, 84) })
			local function refresh()
				local c, m = CharAnim.Stats, CreatureAnim.Survey()
				local a = require(game:GetService("ReplicatedStorage").Shared.Modules.Anim).Stats
				info.Text = string.format("Me: %s, played %d (last %s), last FX %s\nAnims: loaded %d, local copies %d, failed %d\nMonsters near: %d rigged, %d plain, %d animating",
					c.kind, c.posed, c.lastClip, c.lastFX, a.loaded, a.fallback, a.failed, m.rigged, m.plain, m.animated)
			end
			refresh()
			local agrid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Parent = list })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(176, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = agrid })
			for _, c in ipairs({ { "Test Punch", "Brawler_Uppercut" }, { "Test Kick", "Cook_AxeKick" }, { "Refresh", false } }) do
				UI.Button(agrid, c[1], T.Pink, nil, function()
					if c[2] then
						CharAnim.Play(game:GetService("Players").LocalPlayer.Character, c[2])
					end
					task.delay(0.1, refresh)
				end)
			end
		end
	end
	sidebar()
	render()
end

local windowIds = { Shipwright = "Shipyard", FastTravel = "Map", Map = "Map", BossBoard = "Boss", JobMaster = "Job", Refine = "Refine", Blacksmith = "Refine" }

-- ===================== MENU HUB (everything that is not on the main tiles) =====================
function Panels.MenuHub()
	local win = UI.Window("MenuHub", "Menu", UDim2.fromOffset(640, 410), Color3.fromRGB(110, 90, 180), "anchor")
	local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(188, 152), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	for i, it in ipairs(Panels.MenuItems or {}) do
		if not it.main then
			local tile = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = grid })
			UI.Corner(tile, 16)
			UI.Gradient(tile, it[3]:Lerp(Color3.new(1, 1, 1), 0.25), it[3]:Lerp(Color3.new(0, 0, 0), 0.3), 90)
			UI.Stroke(tile, T.Edge, 3)
			UI.Icon(tile, it[1], 88, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
			UI.Text(tile, string.upper(it[5]), 22, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
			if it[4] then
				local key = New("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = T.PanelDeep, Parent = tile })
				UI.Corner(key, 8)
				UI.Stroke(key, T.Edge, 2)
				UI.Text(key, it[4], 16, T.Gold, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			end
			UI.Tactile(tile)
			tile.Activated:Connect(function()
				UI.CloseWindow("MenuHub")
				Panels.Open(it[2])
			end)
		end
	end
end

-- ===================== QUESTS JOURNAL (story / daily / achievements) =====================
local function secondsToReset()
	local t = os.date("!*t")
	return 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
end

local function achValue(p, a)
	local st = p.ach or {}
	if a.counter then
		return (st.counters or {})[a.counter] or 0
	end
	local function count(t)
		local n = 0
		for _ in pairs(t or {}) do
			n += 1
		end
		return n
	end
	local qstep = State.quest and State.quest.step or 1
	if a.state == "islands" then
		return count(p.unlocked)
	elseif a.state == "chests" then
		return count(p.chests)
	elseif a.state == "fruit" then
		return p.fruit and 1 or 0
	elseif a.state == "mastery" then
		return p.fruit and p.fruit.mastery or 0
	elseif a.state == "pets" then
		return #(p.pets or {})
	elseif a.state == "petStage" then
		local m = 0
		for _, pet in ipairs(p.pets or {}) do
			m = math.max(m, pet.stage or 1)
		end
		return m
	elseif a.state == "tutorial" then
		return qstep > QuestsCfg.TutorialEnd and 1 or 0
	elseif a.state == "story" then
		return qstep > #QuestsCfg.Main and 1 or 0
	elseif a.state == "level" then
		return p.baseLevel
	elseif a.state == "beli" then
		return p.beli
	end
	return 0
end

function Panels.Quests(args)
	local win = UI.Window("Quests", "Quests", UDim2.fromOffset(880, 600), T.Gold, "📜", { fullscreen = true })
	local tab = args and args.tab or "Daily"
	local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = win.body })
	local body = UI.Scroll(win.body, UDim2.new(1, 0, 1, -52))
	body.Position = UDim2.fromOffset(0, 52)
	local render
	render = function()
		clear(tabs)
		clear(body)
		local p = State.profile
		if not p then
			return
		end
		UI.TabBar(tabs, { { "Story", "📖", "Story", T.Gold }, { "Daily", "📅", "Daily", T.Green }, { "Ach", "🏆", "Achievements", T.Purple } }, tab, function(id)
			tab = id
			render()
		end, 40)
		UI.List(body, nil, 8)
		if tab == "Daily" then
			local left = secondsToReset()
			UI.Section(body, "📅", "Today's Dailies", T.Green, string.format("resets in %dh %02dm", left // 3600, (left % 3600) // 60))
			local d = p.daily
			if not d or not d.list then
				UI.Text(body, "Loading today's dailies...", 15, T.TextSoft, "Semi")
				return
			end
			local beli = math.floor(DailiesCfg.Reward.beliPerLevel * p.baseLevel ^ 0.85)
			local allClaimed = true
			for i, e in ipairs(d.list) do
				local tpl
				for _, t in ipairs(DailiesCfg.Pool) do
					if t.id == e.id then
						tpl = t
					end
				end
				local done = e.progress >= e.count
				allClaimed = allClaimed and e.claimed
				local card = UI.Card(body, UDim2.new(1, -12, 0, 84), (done and T.Green or T.Panel):Lerp(T.Panel, done and 0.7 or 0))
				local chip = UI.IconChip(card, tpl and tpl.icon or "📅", T.Green, 52)
				chip.Position = UDim2.fromOffset(12, 16)
				local text = tpl and string.format(tpl.text, e.count, e.targetName or "") or e.id
				UI.Text(card, text, 19, T.Text, "Display", { Position = UDim2.fromOffset(76, 10), Size = UDim2.new(1, -250, 0, 24), TextWrapped = false })
				local bar = UI.Bar(card, T.Green, UDim2.new(1, -250, 0, 16), e.progress .. " / " .. e.count)
				bar.back.Position = UDim2.fromOffset(76, 38)
				bar:Set(e.progress / e.count)
				UI.Text(card, COIN .. " " .. UI.Format(beli) .. "   •   " .. PearlsCfg.Icon .. " " .. DailiesCfg.Reward.pearls .. "   •   EXP", 13, T.Gold, "Bold", { Position = UDim2.fromOffset(76, 58), Size = UDim2.new(1, -250, 0, 18) })
				local label = e.claimed and "Claimed ✓" or (done and "Claim!" or "In progress")
				local _, h = UI.Button(card, label, (done and not e.claimed) and T.Green or T.Grey, UDim2.fromOffset(150, 46), function()
					if done and not e.claimed then
						local res = req("DailyClaim", { index = i }, "Coin")
						if res.ok then
							render()
						end
					end
				end)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, -16, 0.5, 0)
			end
			local bonus = UI.Card(body, UDim2.new(1, -12, 0, 64), T.Gold:Lerp(T.Panel, 0.75))
			local chip = UI.IconChip(bonus, "🎁", T.Gold, 44)
			chip.Position = UDim2.fromOffset(12, 10)
			local items = {}
			for _, it in ipairs(DailiesCfg.Bonus.items) do
				local def = ItemDB.Get(it[1])
				table.insert(items, it[2] .. "x " .. (def and def.name or it[1]))
			end
			UI.Text(bonus, "Daily bonus: claim all 3  →  " .. PearlsCfg.Icon .. " " .. DailiesCfg.Bonus.pearls .. " + " .. table.concat(items, ", "), 16, T.Text, "Display", { Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -240, 1, 0) })
			local ready = allClaimed and not d.bonusClaimed
			local _, h = UI.Button(bonus, d.bonusClaimed and "Claimed ✓" or "Claim Bonus", ready and T.Gold or T.Grey, UDim2.fromOffset(150, 44), function()
				if ready then
					local res = req("DailyBonus", nil, "RarityEpic")
					if res.ok then
						render()
					end
				end
			end)
			h.AnchorPoint = Vector2.new(1, 0.5)
			h.Position = UDim2.new(1, -16, 0.5, 0)
		elseif tab == "Ach" then
			local st = p.ach or {}
			local done, claimedN = st.done or {}, st.claimed or {}
			local n = 0
			for _ in pairs(done) do
				n += 1
			end
			UI.Section(body, "🏆", "Achievements", T.Purple, n .. " / " .. #AchievementsCfg.List)
			-- title picker
			local titleRow = UI.Card(body, UDim2.new(1, -12, 0, 54), T.Purple:Lerp(T.Panel, 0.75))
			local cur = TitlesCfg.ById[(p.title == nil and TitlesCfg.Default) or p.title or ""]
			UI.Text(titleRow, "Title:  " .. (cur and ("« " .. cur.name .. " »") or "none") .. "   (all titles: Bag -> title button)", 16, T.Text, "Display", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -200, 1, 0) })
			if cur then
				local _, h = UI.Button(titleRow, "Hide title", T.Grey, UDim2.fromOffset(150, 40), function()
					req("SetTitle", {})
				end)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, -12, 0.5, 0)
			end
			-- unlocked & unclaimed first, then in progress, then claimed
			local order = {}
			for i, a in ipairs(AchievementsCfg.List) do
				local rank = (done[a.id] and not claimedN[a.id]) and 0 or (done[a.id] and 2 or 1)
				table.insert(order, { a = a, rank = rank, i = i })
			end
			table.sort(order, function(x, y)
				if x.rank ~= y.rank then
					return x.rank < y.rank
				end
				return x.i < y.i
			end)
			for _, o in ipairs(order) do
				local a = o.a
				local isDone = done[a.id] == true
				local card = New("Frame", { Size = UDim2.new(1, -12, 0, 74), BackgroundColor3 = Color3.new(1, 1, 1), Parent = body })
				UI.Corner(card, 12)
				if isDone then
					UI.RarityStyle(card, a.rarity or "Rare")
				else
					UI.Gradient(card, T.PanelTop, T.PanelDeep, 90)
					UI.Stroke(card, T.Edge, 2.5)
				end
				local chip = UI.IconChip(card, a.icon, isDone and Rarity.Get(a.rarity or "Rare").color or T.Grey, 48)
				chip.Position = UDim2.fromOffset(12, 13)
				chip.ZIndex = 4
				UI.Text(card, a.name .. (a.title and ('  <font color="#FFD54A">title: ' .. a.title .. "</font>") or ""), 18, T.Text, "Display", { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -250, 0, 22), ZIndex = 4, TextWrapped = false })
				UI.Text(card, a.desc .. "   •   " .. PearlsCfg.Icon .. " " .. a.pearls, 13, T.Text, "Semi", { Position = UDim2.fromOffset(72, 32), Size = UDim2.new(1, -250, 0, 16), ZIndex = 4 })
				local v = math.min(achValue(p, a), a.count)
				if not isDone then
					local bar = UI.Bar(card, T.Purple, UDim2.new(1, -250, 0, 12), UI.Format(v) .. " / " .. UI.Format(a.count))
					bar.back.Position = UDim2.fromOffset(72, 52)
					bar:Set(v / a.count)
				end
				local label, color, action
				if isDone and not claimedN[a.id] then
					label, color, action = "Claim " .. PearlsCfg.Icon .. a.pearls, T.Green, function()
						req("AchievementClaim", { id = a.id }, "RarityEpic")
					end
				elseif isDone and a.title and p.title ~= a.id then
					label, color, action = "Wear Title", T.Purple, function()
						req("SetTitle", { id = a.id })
					end
				elseif isDone then
					label, color = (p.title == a.id) and "Wearing ✓" or "Done ✓", T.Grey
				else
					label, color = "Locked", T.Grey
				end
				local _, h = UI.Button(card, label, color, UDim2.fromOffset(150, 42), function()
					if action then
						action()
					end
				end)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, -12, 0.5, 0)
				h.ZIndex = 5
			end
		else
			-- Story: chapters by island
			local q = State.quest
			local cur = q and q.step or 1
			UI.Section(body, "📖", "Azure East Saga", T.Gold, math.min(cur - 1, #QuestsCfg.Main) .. " / " .. #QuestsCfg.Main .. " steps")
			local chapters, orderIds = {}, {}
			for i, s in ipairs(QuestsCfg.Main) do
				if not chapters[s.island] then
					chapters[s.island] = { first = i, last = i }
					table.insert(orderIds, s.island)
				end
				chapters[s.island].last = i
			end
			for _, islandId in ipairs(orderIds) do
				local ch = chapters[islandId]
				local isl = Islands.ById[islandId]
				local total = ch.last - ch.first + 1
				local doneN = math.clamp(cur - ch.first, 0, total)
				local state = doneN >= total and "✅" or (doneN > 0 or cur == ch.first) and "▶" or "🔒"
				local card = UI.Card(body, UDim2.new(1, -12, 0, 64), (state == "▶" and T.Gold or T.Panel):Lerp(T.Panel, state == "▶" and 0.7 or 0))
				UI.Text(card, state .. "  " .. (isl and isl.name or islandId) .. (islandId == "Daybreak" and "  (tutorial)" or ""), 20, T.Text, "Display", { Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -32, 0, 24) })
				local bar = UI.Bar(card, T.Gold, UDim2.new(1, -32, 0, 14), doneN .. " / " .. total)
				bar.back.Position = UDim2.fromOffset(16, 38)
				bar:Set(doneN / total)
				if state == "▶" and QuestsCfg.Main[cur] then
					UI.Text(body, "   Now: " .. QuestsCfg.Main[cur].title .. "  —  " .. QuestsCfg.Main[cur].text, 15, T.Gold, "Bold")
				end
			end
		end
	end
	render()
	onProfile(win, render)
end

-- ===================== PETS =====================
function Panels.Pets()
	-- like the Bag: a grid of square tiles (the pet itself), name on hover, sorted the way you like
	local win = UI.Window("Pets", "Sea Companions", UDim2.fromOffset(980, 600), T.Green, "🐾", { fullscreen = true })
	local selected
	local sortBy = "Recent"
	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, -10, 0, 40), Parent = win.body })
	local left = UI.Scroll(win.body, UDim2.new(0.6, -10, 1, -48))
	left.Position = UDim2.fromOffset(0, 48)
	New("UIGridLayout", { CellSize = UDim2.fromOffset(96, 96), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), Parent = left })
	local right = UI.Card(win.body, UDim2.new(0.4, 0, 1, 0))
	right.Position = UDim2.new(0.6, 0, 0, 0)
	UI.Pad(right, 12)
	local render
	render = function()
		clear(left)
		clear(right)
		clear(top)
		local p = State.profile
		if not p then
			return
		end
		local pets = p.pets or {}
		local bar = UI.TabBar(top, { { "Recent", "🕒", "Recent", T.Ocean }, { "Rarity", "⭐", "Rarity", T.Gold }, { "Level", "📈", "Level", T.Green } }, sortBy, function(id)
			sortBy = id
			render()
		end, 32)
		bar.Size = UDim2.new(1, -90, 1, 0)
		UI.Text(top, #pets .. "/" .. PetsCfg.MaxPets, 18, T.Text, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(80, 24), TextXAlignment = Enum.TextXAlignment.Right })
		if #pets == 0 then
			local tip = UI.Text(left, "No companions yet.\n• Hatch eggs from chests (or the Shop)\n• Buy Sea Bait at the General Store, weaken a Beach Crab or Wild Boar below 35% HP, then press 🪤 Capture", 14, T.TextSoft, "Semi", { Size = UDim2.fromOffset(420, 90) })
			local _ = tip
		end
		local order = {}
		for i, pet in ipairs(pets) do
			if PetsCfg.ById[pet.species] then
				table.insert(order, { pet = pet, i = i, rank = Rarity.Get(PetsCfg.ById[pet.species].rarity).rank or 0 })
			end
		end
		table.sort(order, function(a, b)
			if sortBy == "Rarity" and a.rank ~= b.rank then
				return a.rank > b.rank
			elseif sortBy == "Level" and a.pet.level ~= b.pet.level then
				return a.pet.level > b.pet.level
			end
			return a.i > b.i -- newest first
		end)
		for k, o in ipairs(order) do
			local pet = o.pet
			local sp = PetsCfg.ById[pet.species]
			local isActive = p.activePet == pet.uid
			local tile = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = k, Parent = left })
			UI.Corner(tile, 14)
			UI.RarityStyle(tile, sp.rarity, pet.uid == selected)
			UI.Tactile(tile)
			local key = sp.id .. "_" .. pet.stage
			local view = UI.ModelAsset("Pets", key) and UI.ModelView(tile, "Pets", key, 84, false, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
			if not view then
				local chip = UI.IconChip(tile, sp.icon, sp.color, 56)
				chip.AnchorPoint = Vector2.new(0.5, 0.5)
				chip.Position = UDim2.fromScale(0.5, 0.5)
				chip.ZIndex = 4
			end
			UI.Text(tile, "Lv." .. pet.level, 13, T.Text, "Number", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -5, 1, -3), Size = UDim2.fromOffset(50, 15), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
			if isActive then
				UI.Text(tile, "⭐", 18, T.Gold, "Display", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(22, 22), ZIndex = 5 })
			end
			UI.Tooltip(tile, function()
				return "<b>" .. sp.stages[pet.stage] .. "</b>" .. (isActive and "  (summoned)" or "") .. "\nLv." .. pet.level .. "  •  Stage " .. pet.stage .. "/3  •  " .. sp.rarity, Rarity.Get(sp.rarity).color
			end)
			tile.Activated:Connect(function()
				selected = pet.uid
				render()
			end)
		end
		-- detail
		local pet = selected and (function()
			for _, x in ipairs(pets) do
				if x.uid == selected then
					return x
				end
			end
			return nil
		end)() or (p.activePet and (function()
			for _, x in ipairs(pets) do
				if x.uid == p.activePet then
					return x
				end
			end
			return nil
		end)())
		UI.List(right, nil, 8, Enum.HorizontalAlignment.Center)
		if not pet then
			UI.Section(right, "🥚", "Egg Odds", T.Gold)
			for id, egg in pairs(PetsCfg.Eggs) do
				local parts = {}
				for sid, w in pairs(egg.weights) do
					table.insert(parts, sid .. " " .. w .. "%")
				end
				table.sort(parts)
				UI.Text(right, egg.icon .. " " .. egg.name .. ": " .. table.concat(parts, " • "), 13, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 34) })
				local _ = id
			end
			return
		end
		local sp = PetsCfg.ById[pet.species]
		-- 3D showcase of the Blender model (falls back to the icon chip until AssetService has loaded it)
		local key = sp.id .. "_" .. pet.stage
		if UI.ModelAsset("Pets", key) then
			local head = New("Frame", { Size = UDim2.new(1, 0, 0, 170), ClipsDescendants = true, Parent = right })
			UI.Corner(head, 12)
			UI.RarityStyle(head, sp.rarity, true)
			New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = sp.color:Lerp(Color3.new(1, 1, 1), 0.4), ImageTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(190, 190), ZIndex = 3, Parent = head })
			UI.ModelView(head, "Pets", key, 170, 0.7, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 })
		else
			local chip = UI.IconChip(right, sp.icon, sp.color, 96)
			chip.Rotation = -5
		end
		UI.Text(right, sp.stages[pet.stage], 26, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center })
		-- evolution line: small static models (current stage highlighted), names underneath
		if UI.ModelAsset("Pets", sp.id .. "_1") then
			local evo = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), Parent = right })
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = evo })
			for st = 1, 3 do
				local cell = New("Frame", { BackgroundColor3 = st == pet.stage and sp.color or T.Panel, BackgroundTransparency = st == pet.stage and 0.55 or 0.4, Size = UDim2.fromOffset(56, 56), LayoutOrder = st * 2, Parent = evo })
				UI.Corner(cell, 10)
				local vp = UI.ModelView(cell, "Pets", sp.id .. "_" .. st, 56, false)
				if vp and st > pet.stage then
					vp.ImageColor3 = Color3.fromRGB(40, 40, 60) -- not evolved yet: silhouette
				end
				if st < 3 then
					UI.Text(evo, "➜", 18, T.TextSoft, "Display", { Size = UDim2.fromOffset(18, 56), LayoutOrder = st * 2 + 1, TextXAlignment = Enum.TextXAlignment.Center })
				end
			end
		end
		UI.Text(right, table.concat(sp.stages, "  ➜  "), 13, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center })
		local need = PetsCfg.ExpToNext(pet.level)
		local bar = UI.Bar(right, T.Green, UDim2.new(1, 0, 0, 18), pet.level >= PetsCfg.MaxLevel and "MAX" or ("Lv." .. pet.level .. "  " .. pet.exp .. "/" .. need))
		bar:Set(pet.level >= PetsCfg.MaxLevel and 1 or pet.exp / need)
		local bonusKey, values = next(sp.bonus)
		local v = values[pet.stage]
		local shown = (bonusKey == "crit") and ("+" .. v) or ("+" .. math.floor(v * 100) .. "%")
		UI.Text(right, "Bonus: " .. shown .. " " .. sp.bonusText .. "   •   attacks what you attack", 15, T.Gold, "Bold", { TextXAlignment = Enum.TextXAlignment.Center })
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100), Parent = right })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(180, 44), CellPadding = UDim2.fromOffset(8, 8), Parent = row })
		local isActive = p.activePet == pet.uid
		UI.Button(row, isActive and "Unsummon" or "⭐ Summon", isActive and T.Grey or T.Green, nil, function()
			req("PetSetActive", { uid = (not isActive) and pet.uid or nil })
		end)
		if pet.stage < 3 then
			local lvNeed = PetsCfg.EvolveAt[pet.stage]
			local cost = PetsCfg.EvolveCost[pet.stage]
			local beli = math.floor(cost.beli * (PetsCfg.RarityMult[sp.rarity] or 1))
			local ready = pet.level >= lvNeed
			UI.Button(row, ready and "✨ Evolve" or ("Evolve at Lv." .. lvNeed), ready and T.Purple or T.Grey, nil, function()
				if not ready then
					return
				end
				UI.Confirm("Evolve into " .. sp.stages[pet.stage + 1] .. "?\nCost: " .. UI.Format(beli) .. " Doubloons + " .. cost.material .. "x " .. (ItemDB.Get(sp.material) and ItemDB.Get(sp.material).name or sp.material), function()
					req("PetEvolve", { uid = pet.uid }, "LevelUp")
				end, nil, "Evolve", "Cancel")
			end)
		end
		if not isActive then
			UI.Button(row, "Release", T.Red, nil, function()
				UI.Confirm("Release " .. sp.stages[pet.stage] .. " back into the sea? This cannot be undone.", function()
					selected = nil
					req("PetRelease", { uid = pet.uid })
				end, nil, "Release", "Keep")
			end)
		end
	end
	render()
	onProfile(win, render)
end

-- ===================== PEARL SHOP =====================
function Panels.PearlShop()
	local win = UI.Window("PearlShop", "Shop", UDim2.fromOffset(820, 580), T.Ocean, "🛍️", { fullscreen = true })
	local body = win.body
	local function render()
		clear(body)
		local res = Net.Request("PearlInfo")
		if not res.ok or not win.frame.Parent then
			return
		end
		local d = res.data
		UI.List(body, nil, 8)
		local _, right = UI.Section(body, PearlsCfg.Icon, "Your Pearls", T.Ocean, UI.Format(d.pearls + d.bound))
		local _ = right
		UI.Text(body, string.format("Tradable %s   •   Shop-only %s   •   Earned today %d / %d", UI.Format(d.pearls), UI.Format(d.bound), d.earnedToday, d.cap), 14, T.TextSoft, "Semi")
		UI.Text(body, d.canTrade and "✅ You can buy and sell items for Pearls in stalls." or ("🔒 " .. (d.tradeWhy or "")), 14, d.canTrade and T.Green or T.Gold, "Bold")
		UI.Section(body, "🛍️", "Pearl Shop", T.Gold)
		-- one row of cards that always fits the window: card width follows the item count
		local n = #PearlsCfg.Shop
		local perRow = math.min(n, 5)
		local cellW = math.floor((788 - (perRow - 1) * 8) / perRow)
		local rows = math.ceil(n / perRow)
		local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * 202 - 8), Parent = body })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(cellW, 194), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
		for _, it in ipairs(PearlsCfg.Shop) do
			local owned = it.once and d.perks and d.perks[it.perk]
			local card = UI.Card(grid, nil, T.OceanDark:Lerp(T.Panel, 0.65))
			UI.Pad(card, 10)
			UI.List(card, nil, 4, Enum.HorizontalAlignment.Center)
			UI.IconChip(card, it.icon, T.Ocean, 48)
			UI.Text(card, it.name, 16, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
			UI.Text(card, it.desc, 11, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 38) })
			UI.Button(card, owned and "Owned" or (PearlsCfg.Icon .. " " .. it.price), owned and T.Grey or T.Ocean, UDim2.new(1, 0, 0, 38), function()
				if owned then
					return
				end
				local r = req("PearlShopBuy", { id = it.id }, "Purchase")
				if r.ok then
					render()
				end
			end)
		end
		UI.Section(body, "💎", "Get Pearls", T.Purple, "Robux Pearls are shop-only")
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = body })
		UI.List(row, Enum.FillDirection.Horizontal, 8)
		for _, prod in ipairs(d.products) do
			local onSale = prod.productId ~= 0
			UI.Button(row, (onSale and "" or "🔒 ") .. prod.name .. "  " .. PearlsCfg.Icon .. prod.pearls, onSale and T.Purple or T.Grey, UDim2.fromOffset(250, 40), function()
				if not onSale then
					UI.Toast("Coming soon", "info")
					return
				end
				req("PearlBuyProduct", { productId = prod.productId })
			end)
		end
		UI.Text(body, "Earn Pearls from first-time chests, exploring whole islands, story quests and MVP bosses (max " .. d.cap .. " per day).", 13, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 34) })
	end
	render()
end

function Panels.Open(name, args)
	local f = Panels[name]
	if f then
		f(args)
	end
end

function Panels.Toggle(name)
	local id = windowIds[name] or name
	if UI.IsOpen(id) then
		UI.CloseWindow(id)
	else
		Panels.Open(name)
	end
end
Panels.Blacksmith = Panels.Refine

return Panels
