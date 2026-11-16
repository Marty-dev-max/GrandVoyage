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

local kindIcon = { Weapon = "⚔️", Armor = "🧥", Headgear = "🎩", Accessory = "💍", Consumable = "🍖", Material = "🪵", Card = "🃏" }

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
function Panels.Inventory()
	local win = UI.Window("Inventory", "Inventory", UDim2.fromOffset(940, 580), T.Ocean, "🎒")
	local left = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, -8, 1, 0), Parent = win.body })
	local right = UI.Card(win.body, UDim2.new(0.4, 0, 1, 0))
	right.Position = UDim2.new(0.6, 0, 0, 0)
	UI.Pad(right, 12)
	local filterRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = left })
	local grid = UI.Scroll(left, UDim2.new(1, 0, 1, -44))
	grid.Position = UDim2.fromOffset(0, 44)
	New("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), Parent = grid })
	local selectedUid
	local filter = "All"
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
		selectedUid = entry.uid
		UI.List(right, nil, 8)
		local tier = ItemDB.Rarity(def)
		-- showcase (Anime Vanguards style): the item floats over spinning rarity-colored rays
		local head = New("Frame", { Size = UDim2.new(1, 0, 0, 190), ClipsDescendants = true, Parent = right })
		UI.Corner(head, 12)
		UI.RarityStyle(head, def.rarity, true)
		local rays = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.focuslines, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.5), ImageTransparency = 0.45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(300, 300), ZIndex = 3, Parent = head })
		New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3), ImageTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(170, 170), ZIndex = 3, Parent = head })
		local iconId = UI.ItemIconId(def)
		local big
		local model = def.kind == "Fruit" and UI.ModelView(head, "Fruits", def.fruit, 150, 0.9, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 5 })
		if model then
			big = model
		elseif iconId then
			big = New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(124, 124), ZIndex = 5, Parent = head })
		else
			big = UI.Text(head, def.icon or kindIcon[def.kind] or "", 64, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(124, 124), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		end
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
			big.Position = UDim2.new(0.5, 0, 0.42, math.sin((os.clock() - t0) * 2.2) * 5)
		end)
		UI.Text(head, ItemDB.DisplayName(entry), 21, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(1, -16, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextWrapped = false })
		UI.Text(head, string.upper(tier.id), 14, tier.color:Lerp(Color3.new(1, 1, 1), 0.4), "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -16, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
		UI.Text(right, describe(entry, def), 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 120), TextYAlignment = Enum.TextYAlignment.Top })
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110), Parent = right })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = row })
		if def.slot then
			if equippedUid(entry.uid) then
				UI.Button(row, "Unequip", T.OceanDark, nil, function()
					req("UnequipItem", { slot = def.slot }, "Equip")
				end)
			else
				UI.Button(row, "Equip", T.Green, nil, function()
					req("EquipItem", { uid = entry.uid }, "Equip")
				end)
			end
		end
		if def.kind == "Consumable" and not def.special then
			UI.Button(row, "Use", T.Green, nil, function()
				req("UseItem", { uid = entry.uid })
			end)
		end
		if def.kind == "Egg" then
			UI.Button(row, "🐣 Hatch", T.Gold, nil, function()
				local res = req("HatchEgg", { uid = entry.uid }, "RarityEpic")
				if res.ok then
					Panels.Open("Pets")
				end
			end)
		end
		if def.kind == "Fruit" then
			UI.Button(row, "🍎 Eat", T.Pink, nil, function()
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
			UI.Button(row, "Socket", T.Gold, nil, function()
				Panels.Refine({ tab = "Cards", cardUid = entry.uid })
			end)
		end
		UI.Button(row, "Sell", T.Red, nil, function()
			req("ShopSell", { uid = entry.uid, qty = entry.qty or 1 }, "Coin")
		end)
	end

	local function render()
		clear(grid)
		clear(filterRow)
		local p = State.profile
		if not p then
			return
		end
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
		bar.Size = UDim2.fromScale(1, 1)
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
			local tile = itemTile(grid, it.e, detail, it.e.uid == selectedUid)
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
	onProfile(win, render)
	local _, h = UI.Button(win.header, "🏪 Open Stall", T.Orange, UDim2.fromOffset(170, 42), function()
		Panels.StallSetup()
	end)
	h.AnchorPoint = Vector2.new(1, 0.5)
	h.Position = UDim2.new(1, -66, 0.5, -2)
	h.ZIndex = 30
end

-- ===================== STATS =====================
function Panels.Stats()
	local win = UI.Window("Stats", "Stats", UDim2.fromOffset(700, 560), T.Purple, "📊")
	local left = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.56, 0, 1, 0), Parent = win.body })
	local right = UI.Card(win.body, UDim2.new(0.42, 0, 1, 0))
	right.Position = UDim2.new(0.58, 0, 0, 0)
	UI.Pad(right, 14)
	local desc = { STR = "Physical attack", AGI = "Attack speed / dodge", VIT = "HP / defense", INT = "Magic / SP", DEX = "Accuracy / ranged", LUK = "Crits / drops" }
	local function render()
		clear(left)
		clear(right)
		local p, d = State.profile, State.derived
		if not p or not d then
			return
		end
		UI.List(left, nil, 8)
		UI.Section(left, "🎯", "Attributes", T.Purple, p.statPoints .. " points")
		for _, s in ipairs(Formulas.StatNames) do
			local row = UI.Card(left, UDim2.new(1, 0, 0, 56))
			UI.Pad(row, 8)
			UI.Text(row, s .. "  " .. p.stats[s] .. ' <font color="#7CFF9B">+' .. (d[s] - p.stats[s]) .. "</font>", 22, T.Text, "Display", { Size = UDim2.new(0.6, 0, 0, 24) })
			UI.Text(row, desc[s] .. "  •  costs " .. Formulas.StatCost(p.stats[s]), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(0.62, 0, 0, 16) })
			local _, h1 = UI.Button(row, "+1", T.Green, UDim2.fromOffset(54, 38), function()
				req("AllocateStat", { stat = s, amount = 1 })
			end)
			h1.Position = UDim2.new(1, -122, 0, 0)
			local _, h2 = UI.Button(row, "+10", T.Ocean, UDim2.fromOffset(60, 38), function()
				req("AllocateStat", { stat = s, amount = 10 })
			end)
			h2.Position = UDim2.new(1, -62, 0, 0)
		end
		UI.List(right, nil, 6)
		local cls = Classes[p.class]
		UI.Section(right, cls and cls.icon or "🧭", cls and cls.name or p.class, cls and cls.color or T.Gold)
		UI.Text(right, "Base Lv." .. p.baseLevel .. "   Job Lv." .. p.jobLevel, 16, T.TextSoft, "Semi")
		UI.Section(right, "📈", "Combat", T.Red)
		local lines = {
			{ "HP", d.maxHp },
			{ "SP", d.maxSp },
			{ "ATK", d.atk },
			{ "MATK", d.matk },
			{ "DEF", d.def },
			{ "MDEF", d.mdef },
			{ "HIT", d.hit },
			{ "FLEE", d.flee },
			{ "CRIT", string.format("%.1f%%", d.crit) },
			{ "Attack every", string.format("%.2fs", d.attackInterval) },
			{ "Cannon dmg", "+" .. math.floor(d.cannonDamage * 100) .. "%" },
			{ "Ship speed", "+" .. math.floor(d.shipSpeed * 100) .. "%" },
		}
		for _, l in ipairs(lines) do
			local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = right })
			UI.Text(r, l[1], 17, T.TextSoft, "Semi", { Size = UDim2.new(0.6, 0, 1, 0) })
			UI.Text(r, tostring(l[2]), 18, T.Text, "Number", { Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
	render()
	onProfile(win, render)
end

-- ===================== SKILLS =====================
function Panels.Skills()
	local win = UI.Window("Skills", "Skills", UDim2.fromOffset(720, 580), T.Gold, "✨")
	local list = UI.Scroll(win.body, UDim2.new(1, 0, 1, 0))
	local function render()
		clear(list)
		local p = State.profile
		if not p then
			return
		end
		UI.List(list, nil, 8)
		UI.Section(list, "✨", "Skill Tree", T.Gold, p.skillPoints .. " points")
		UI.Text(list, "● Auto = Auto Battle uses this skill", 14, Color3.fromRGB(155, 231, 166), "Semi")
		-- Cursed Fruit section
		local fruit = p.fruit and FruitsCfg.ById[p.fruit.id]
		if fruit then
			UI.Section(list, fruit.icon, fruit.name, fruit.color, "Mastery " .. p.fruit.mastery .. "/" .. FruitsCfg.Mastery.Max)
			local need = FruitsCfg.Mastery.Base + FruitsCfg.Mastery.PerLevel * p.fruit.mastery
			local mb = UI.Bar(list, fruit.color, UDim2.new(1, -12, 0, 16), p.fruit.mastery >= FruitsCfg.Mastery.Max and "MAX" or (p.fruit.exp .. " / " .. need))
			mb:Set(p.fruit.mastery >= FruitsCfg.Mastery.Max and 1 or p.fruit.exp / need)
			UI.Text(list, fruit.type .. "  •  " .. fruit.passiveText .. "  •  Cannot swim", 13, T.TextSoft, "Semi")
			for _, s in ipairs(fruit.skills) do
				local open = p.fruit.mastery >= s.mastery
				local card = UI.Card(list, UDim2.new(1, -12, 0, 70), fruit.color:Lerp(T.Panel, open and 0.7 or 0.88))
				UI.Pad(card, 10)
				UI.Text(card, (open and "" or "🔒 ") .. s.name .. '  <font color="#FFD54A">Mastery ' .. s.mastery .. "</font>", 19, open and T.Text or T.TextSoft, "Display", { Size = UDim2.new(1, -120, 0, 22) })
				UI.Text(card, s.kind .. " • " .. s.sp .. " SP • " .. s.cd .. "s\n" .. (s.desc or ""), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -120, 0, 32) })
				if open then
					local auto = p.autoSkills[s.id]
					local _, h2 = UI.Button(card, auto and "● Auto" or "○ Auto", auto and T.Ocean or T.Grey, UDim2.fromOffset(100, 40), function()
						local a = table.clone(p.autoSkills)
						a[s.id] = not auto or nil
						req("SetAutoSettings", { autoSkills = a })
					end)
					h2.Position = UDim2.new(1, -100, 0, 4)
				end
			end
		else
			local card = UI.Card(list, UDim2.new(1, -12, 0, 58), T.Panel)
			UI.Pad(card, 10)
			UI.Text(card, "🍎 No Cursed Fruit yet", 18, T.Text, "Display")
			UI.Text(card, "Sink ships, open Captain's Chests, beat MVP bosses, or find one growing on an island.", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 18) })
		end
		local classes = { p.class, "Common" }
		for _, cid in ipairs(classes) do
			UI.Section(list, Classes[cid].icon or "🧭", Classes[cid].name, Classes[cid].color)
			for _, s in ipairs(Classes[cid].skills) do
				local lv = p.skills[s.id] or 0
				local card = UI.Card(list, UDim2.new(1, -12, 0, 84), Classes[cid].color:Lerp(T.Panel, 0.7))
				UI.Pad(card, 10)
				UI.Text(card, s.name .. '  <font color="#FFD54A">Lv.' .. lv .. "/" .. s.maxLevel .. "</font>", 20, T.Text, "Display", { Size = UDim2.new(1, -220, 0, 24) })
				local info = s.kind .. " • " .. s.sp .. " SP • " .. s.cd .. "s"
				if s.mult then
					info ..= " • x" .. string.format("%.1f", s.mult * (1 + 0.1 * math.max(lv - 1, 0)))
				end
				if s.range and s.range > 0 then
					info ..= " • range " .. s.range
				end
				UI.Text(card, info .. "\n" .. (s.desc or ""), 14, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -220, 0, 36) })
				local _, h = UI.Button(card, "Learn +1", T.Green, UDim2.fromOffset(100, 40), function()
					req("LearnSkill", { skillId = s.id })
				end)
				h.Position = UDim2.new(1, -208, 0, 10)
				if lv > 0 then
					local auto = p.autoSkills[s.id]
					local _, h2 = UI.Button(card, auto and "● Auto" or "○ Auto", auto and T.Ocean or T.Grey, UDim2.fromOffset(100, 40), function()
						local a = table.clone(p.autoSkills)
						a[s.id] = not auto or nil
						req("SetAutoSettings", { autoSkills = a })
					end)
					h2.Position = UDim2.new(1, -100, 0, 10)
				end
			end
		end
	end
	render()
	onProfile(win, render)
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
	opts = opts or {}
	local win = UI.Window("Refine", "Blacksmith", UDim2.fromOffset(820, 580), T.Orange, "🔨")
	local tab = opts.tab or "Refine"
	local selected
	local useGuard = false
	local cardUid = opts.cardUid
	local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = win.body })
	UI.List(tabs, Enum.FillDirection.Horizontal, 8)
	local list = UI.Scroll(win.body, UDim2.new(0.5, -6, 1, -54))
	list.Position = UDim2.fromOffset(0, 54)
	local right = UI.Card(win.body, UDim2.new(0.5, -6, 1, -54))
	right.Position = UDim2.new(0.5, 6, 0, 54)
	UI.Pad(right, 14)
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
	local function renderRight()
		clear(right)
		UI.List(right, nil, 8)
		local p = State.profile
		local e = selected and Formulas.FindItem(p, selected)
		if not e then
			UI.Text(right, tab == "Refine" and "Pick a piece of equipment to refine." or "Pick a card, then the equipment to socket it into.", 18, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 60) })
			return
		end
		local def = ItemDB.Get(e.id)
		local head = New("Frame", { Size = UDim2.new(1, 0, 0, 64), Parent = right })
		UI.Corner(head, 12)
		UI.RarityStyle(head, def.rarity, true)
		UI.Text(head, ItemDB.DisplayName(e), 22, T.Text, "Display", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 4 })
		if tab == "Refine" then
			local cur = e.refine or 0
			if cur >= GameConfig.Refine.Max then
				UI.Text(right, "Already at +" .. GameConfig.Refine.Max .. "!", 24, T.Gold, "Display")
				return
			end
			local cls = Classes[p.class]
			local chance = math.min(1, GameConfig.Refine.Chance[cur + 1] + (cls.passive and cls.passive.refineBonus or 0))
			local mat, qty, cost = ItemDB.RefineMaterial(cur)
			local md = ItemDB.Get(mat)
			UI.Text(right, "+" .. cur .. "  ➜  +" .. (cur + 1), 40, T.Gold, "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 46) })
			local cBar = UI.Bar(right, chance >= 1 and T.Green or (chance >= 0.4 and T.Gold or T.Red), UDim2.new(1, 0, 0, 26), "Success " .. math.floor(chance * 100) .. "%")
			cBar:Set(chance)
			UI.Text(right, "Needs " .. md.name .. " x" .. qty .. "  (have " .. count(mat) .. ")\nCost " .. COIN .. " " .. UI.Format(cost), 16, T.Text, "Semi", { Size = UDim2.new(1, 0, 0, 40) })
			local risk = cur < GameConfig.Refine.Safe and '<font color="#7CFF9B">Safe: cannot fail</font>' or (cur >= GameConfig.Refine.BreakFrom and '<font color="#FF5C6C">Risk: failure may SHATTER the item</font>' or '<font color="#FFB347">Risk: failure drops 1 level</font>')
			UI.Text(right, risk, 16, T.Text, "Bold")
			UI.Button(right, useGuard and "🛡 Willpower Charm: ON" or "🛡 Willpower Charm: OFF", useGuard and T.Purple or T.Grey, UDim2.new(1, 0, 0, 42), function()
				useGuard = not useGuard
				renderRight()
			end)
			UI.Button(right, "🔥 REFINE!", T.Orange, UDim2.new(1, 0, 0, 58), function()
				local res = Net.Request("Refine", { uid = e.uid, useGuard = useGuard })
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
					UI.Toast(res.msg or "Could not refine", "bad")
				end
			end)
		else
			local cd = cardUid and Formulas.FindItem(p, cardUid)
			local cdef = cd and ItemDB.Get(cd.id)
			UI.Text(right, describe(e, def), 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 150) })
			if cdef then
				local cardHead = New("Frame", { Size = UDim2.new(1, 0, 0, 56), Parent = right })
				UI.Corner(cardHead, 12)
				UI.RarityStyle(cardHead, cdef.rarity)
				UI.Text(cardHead, "🃏 " .. cdef.name .. "\n" .. (cdef.desc or ""), 15, T.Text, "Bold", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), ZIndex = 4 })
				UI.Button(right, "🃏 SOCKET CARD", T.Gold, UDim2.new(1, 0, 0, 52), function()
					local res = req("InsertCard", { cardUid = cardUid, targetUid = e.uid })
					if res.ok then
						UI.Banner("Card Socketed!", cdef.name, T.Gold, cdef.rarity)
					end
					cardUid = nil
					render()
				end)
			else
				UI.Text(right, "Pick a card from the list first.", 16, T.TextSoft, "Semi")
			end
		end
	end
	render = function()
		clear(list)
		clear(tabs)
		UI.TabBar(tabs, { { "Refine", "🔨", "Refine", T.Orange }, { "Cards", "🃏", "Socket Cards", T.Gold } }, tab, function(id)
			tab = id
			selected = nil
			render()
		end, 40)
		UI.List(list, nil, 6)
		local p = State.profile
		if not p then
			return
		end
		local function entryButton(e, label, isSel, onPick)
			local def = ItemDB.Get(e.id)
			local b = New("TextButton", { Size = UDim2.new(1, -10, 0, 44), Text = "", AutoButtonColor = false, Parent = list })
			UI.Corner(b, 10)
			UI.RarityStyle(b, def.rarity, isSel)
			UI.Tactile(b)
			UI.Text(b, (isSel and "▶ " or "") .. label, 17, T.Text, "Bold", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 4 })
			b.Activated:Connect(onPick)
		end
		if tab == "Cards" then
			UI.Section(list, "🃏", "Your Cards", T.Purple)
			for _, e in ipairs(p.inventory) do
				local def = ItemDB.Get(e.id)
				if def and def.kind == "Card" then
					entryButton(e, def.name .. " x" .. (e.qty or 1) .. "  [" .. def.cardSlot .. "]", cardUid == e.uid, function()
						cardUid = e.uid
						render()
					end)
				end
			end
			UI.Section(list, "🛡️", "Gear With Free Slots", T.Gold)
		end
		for _, e in ipairs(p.inventory) do
			local def = ItemDB.Get(e.id)
			local ok = def and ((tab == "Refine" and def.refinable) or (tab == "Cards" and def.slots and def.slots > #(e.cards or {})))
			if ok then
				entryButton(e, ItemDB.DisplayName(e), selected == e.uid, function()
					selected = e.uid
					renderRight()
				end)
			end
		end
		renderRight()
	end
	render()
	onProfile(win, render)
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
		local _, h = UI.Button(card, "Buy", T.Green, UDim2.fromOffset(100, 40), function()
			req("ShopBuy", { id = id, qty = 1 }, "Purchase")
		end)
		h.Position = UDim2.new(1, -210, 0, 2)
		h.ZIndex = 5
		if def.stack then
			local _, h2 = UI.Button(card, "x10", T.Ocean, UDim2.fromOffset(96, 40), function()
				req("ShopBuy", { id = id, qty = 10 }, "Purchase")
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
	local win = UI.Window("Map", Islands.SeaName, UDim2.fromOffset(1000, 480), T.Ocean, "🗺️")
	local strip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 280), Parent = win.body })
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
	UI.Text(win.body, "Islands lie in a straight line: sail east to reach the next one. Stay in the windy lane: the Doldrums at the edges have no wind and Leviathans. Past " .. Islands.List[n].name .. ", " .. Islands.RedLine.peakName .. " leads to the " .. Islands.RedLine.nextSea .. " (next update).", 16, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 60) })
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
			UI.Text(list, "Press T or the AUTO button to toggle. Auto Battle fights within " .. GameConfig.AutoBattle.SearchRadius .. " studs and never wanders more than " .. GameConfig.AutoBattle.LeashRadius .. " studs from where it started. Pick which skills it uses in the Skills window (● Auto).", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 80) })
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
			devGrid("Player", "🧪", T.Accent, { { "Lv70", "level" }, { "Job Lv.10", "joblevel" }, { "+1M " .. COIN, "beli" }, { "Materials", "items" }, { "+1000 " .. PearlsCfg.Icon, "pearls" }, { "Next Quest", "questnext" } })
			local fruitButtons = {}
			for _, f in ipairs(FruitsCfg.List) do
				table.insert(fruitButtons, { f.icon .. " " .. f.id, "fruit", f.id })
			end
			table.insert(fruitButtons, { "+Mastery", "mastery" })
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
	local win = UI.Window("Quests", "Quests", UDim2.fromOffset(880, 600), T.Gold, "📜")
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
			local cur = p.title and AchievementsCfg.ById[p.title]
			UI.Text(titleRow, "Title shown above your head:  " .. (cur and ("« " .. cur.title .. " »") or "none"), 16, T.Text, "Display", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -200, 1, 0) })
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
	local win = UI.Window("Pets", "Sea Companions", UDim2.fromOffset(880, 580), T.Green, "🐾")
	local selected
	local left = UI.Scroll(win.body, UDim2.new(0.5, -6, 1, 0))
	local right = UI.Card(win.body, UDim2.new(0.5, -6, 1, 0))
	right.Position = UDim2.new(0.5, 6, 0, 0)
	UI.Pad(right, 12)
	local function render()
		clear(left)
		clear(right)
		local p = State.profile
		if not p then
			return
		end
		local pets = p.pets or {}
		UI.List(left, nil, 6)
		UI.Section(left, "🐾", "Your Companions", T.Green, #pets .. "/" .. PetsCfg.MaxPets)
		if #pets == 0 then
			UI.Text(left, "No companions yet.\n• Hatch eggs from chests (or the Pearl Shop)\n• Buy Sea Bait at the General Store, weaken a Beach Crab or Wild Boar below 35% HP, then press 🪤 Capture", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 90) })
		end
		for _, pet in ipairs(pets) do
			local sp = PetsCfg.ById[pet.species]
			if sp then
				local isActive = p.activePet == pet.uid
				local card = New("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -12, 0, 62), BackgroundColor3 = Color3.new(1, 1, 1), Parent = left })
				UI.Corner(card, 12)
				UI.RarityStyle(card, sp.rarity)
				UI.Tactile(card)
				local chip = UI.IconChip(card, sp.icon, sp.color, 44)
				chip.Position = UDim2.fromOffset(8, 9)
				chip.ZIndex = 4
				UI.Text(card, sp.stages[pet.stage] .. (isActive and "  ⭐" or ""), 18, T.Text, "Display", { Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -70, 0, 22), ZIndex = 4, TextWrapped = false })
				UI.Text(card, "Lv." .. pet.level .. "  •  Stage " .. pet.stage .. "/3  •  " .. sp.rarity, 13, T.Text, "Semi", { Position = UDim2.fromOffset(60, 32), Size = UDim2.new(1, -70, 0, 18), ZIndex = 4 })
				card.Activated:Connect(function()
					selected = pet.uid
					render()
				end)
			end
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
	local win = UI.Window("PearlShop", "Pearls", UDim2.fromOffset(820, 580), T.Ocean, PearlsCfg.Icon)
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
