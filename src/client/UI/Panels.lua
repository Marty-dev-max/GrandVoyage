-- Panels: every window (bag, stats, skills, job, refine, shop, tavern, shipyard, map, bosses,
-- guild, dungeon, party, market, settings)
local UserInputService = game:GetService("UserInputService")
local TexturesCfg = require(game:GetService("ReplicatedStorage").Shared.Config.Textures)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local Prices = require(script.Parent.Prices)
local CardArt = require(script.Parent.CardArt)
local ForgeScene = require(script.Parent.ForgeScene)
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
local ChartsView = require(script.Parent.Parent.Controllers.ChartsView)

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
	-- owner (v0.25.105): ladder names (Forty Fathoms ...) live only in the Index; normal screens show the rarity
	if g and g.rarity == (def.baseRarity or def.rarity) then -- old grade lines only (new ladders don't match a grade)
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
	local def = ItemDB.ForEntry(entry)
	if not def then
		return
	end
	local b = New("TextButton", { Size = UDim2.fromOffset(84, 84), Text = "", AutoButtonColor = false, Parent = parent })
	UI.Corner(b, 12)
	local tier = UI.RarityStyle(b, def.rarity, selected)
	if def.kind == "Fruit" then
		UI.FruitFx(b, def.fruit, 4)
	end
	UI.Tactile(b)
	local iconId = UI.ItemIconId(def)
	if def.kind == "Egg" and UI.VoxelEgg(b, def.id, 56, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), ZIndex = 4 }) then
		-- v0.25.101 (owner): eggs show the block egg model itself, like the Store
	elseif def.blade and UI.WeaponView(b, def, 60, false, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 4 }) then
		-- v0.25.104 (owner): every sword shows its own block model
	elseif iconId then
		New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(56, 56), ZIndex = 4, Parent = b })
	else
		UI.Text(b, def.icon or kindIcon[def.kind] or "❔", 30, T.Text, "Display", { Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	-- v0.25.28: item names in the readable body font, fitted to the tile (the pixel font ran over the edges)
	local nm = UI.Text(b, def.name, 13, T.Text, "Semi", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -3), Size = UDim2.new(1, -6, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, TextScaled = true, ZIndex = 4 })
	New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = nm })
	UI.RarityText(nm, def.rarity)
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
-- held Cursed Fruit (v0.25.33): EAT / STORE / DROP card at the bottom of the screen
local fruitCard
function Panels.FruitChoice(uid, def)
	if fruitCard then
		fruitCard:Destroy()
	end
	local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = New("ScreenGui", { Name = "FruitChoice", ResetOnSpawn = true, DisplayOrder = 25, Parent = pg })
	fruitCard = gui
	local card = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(520, 116), BackgroundColor3 = T.Panel, Parent = gui })
	UI.Bevel(card)
	UI.Text(card, def.name, 20, Rarity.Get(def.rarity).color, "Display", { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
	local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 54), Parent = card })
	UI.List(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	local function done()
		State.heldFruit = nil
		if gui.Parent then
			gui:Destroy()
		end
	end
	UI.Button(row, "🍎 EAT", T.Pink, UDim2.fromOffset(150, 50), function()
		local cur = State.profile.fruit
		local warn = cur and ("\nYou will LOSE your current fruit power (" .. (FruitsCfg.ById[cur.id] and FruitsCfg.ById[cur.id].name or cur.id) .. ").") or ""
		gui.Enabled = false
		UI.Confirm("Eat the " .. def.name .. "?" .. warn .. "\nFruit users can never swim again.", function()
			local res = req("EatFruit", { uid = uid })
			if res.ok then
				UI.Banner("Cursed Fruit!", def.name, Rarity.Get(def.rarity).color, def.rarity)
				done()
			else
				gui.Enabled = true
			end
		end, function()
			gui.Enabled = true
		end, "Eat it", "Not yet")
	end)
	UI.Button(row, "🎒 STORE", T.Blue, UDim2.fromOffset(150, 50), function()
		req("StoreFruit", {})
		done()
	end)
	UI.Button(row, "⬇ DROP", T.Red, UDim2.fromOffset(150, 50), function()
		gui.Enabled = false
		UI.Confirm("Drop the " .. def.name .. " on the ground?\nOther players may pick it up (trade rules apply). It fades in 2 minutes.", function()
			req("DropFruit", { uid = uid })
			done()
		end, function()
			gui.Enabled = true
		end, "Drop it", "Keep it")
	end)
end

-- each class's particles drifting over the Job Master backdrop (pixel icons from Config/Icons)
local CLASS_FX = {
	Brawler = { icons = { "knuckles", "flame" } },
	Swordsman = { icons = { "sword" } },
	Sniper = { icons = { "slingshot" } },
	Cook = { icons = { "meat", "flame" } },
	Navigator = { icons = { "pt_cloud", "compass" }, bubble = true },
	Doctor = { icons = { "potion" }, plus = true },
	Shipwright = { icons = { "gear", "hammer" } },
}

-- v0.25.68 (owner): the Bag / Stats character stands in the class's sea like at the Job Master: a gradient in the
-- class color, the shallow water below the horizon, the class particles drifting; the character keeps its own colors
-- (no glow, no tint). Returns the CharacterView refresh and setClass(classId) for later class changes.
local function classStage(panel, stage, opts)
	panel.ClipsDescendants = true
	local bg = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = panel })
	local bgGrad = New("UIGradient", { Rotation = 115, Parent = bg })
	local water = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), ZIndex = 0, Parent = bg })
	local waterGrad = New("UIGradient", { Rotation = 90, Parent = water })
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), ZIndex = 0, Parent = water })
	local cid0 = State.profile and State.profile.class
	local c0 = Classes[cid0 or ""]
	local o = { water = true, plainLight = true, tint = c0 and c0.color, onFrame = function(h)
		-- the horizon in the stage's space -> the panel's space
		local ok = pcall(function()
			local y = stage.AbsolutePosition.Y + stage.AbsoluteSize.Y * h - panel.AbsolutePosition.Y
			local k = math.clamp(y / math.max(1, panel.AbsoluteSize.Y), 0.2, 0.95)
			water.Position = UDim2.fromScale(0, k)
			water.Size = UDim2.fromScale(1, 1 - k)
		end)
		if not ok then
			water.Position = UDim2.fromScale(0, h)
			water.Size = UDim2.fromScale(1, 1 - h)
		end
	end }
	for k, v in pairs(opts or {}) do
		o[k] = v
	end
	local _, refresh = UI.CharacterView(stage, nil, o)
	local fxLayer, shown
	local function setClass(cid)
		local c = Classes[cid or ""]
		if not c or cid == shown then
			return
		end
		shown = cid
		-- a little deeper than the Job Master so the gear tiles and the text stay readable on it
		bgGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c.color:Lerp(Color3.new(1, 1, 1), 0.2)), ColorSequenceKeypoint.new(0.55, c.color:Lerp(Color3.fromRGB(30, 26, 60), 0.2)), ColorSequenceKeypoint.new(1, c.color:Lerp(Color3.fromRGB(30, 26, 60), 0.55)) })
		waterGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c.color:Lerp(Color3.new(1, 1, 1), 0.45)), ColorSequenceKeypoint.new(0.35, c.color:Lerp(Color3.new(1, 1, 1), 0.1)), ColorSequenceKeypoint.new(1, c.color:Lerp(Color3.fromRGB(24, 20, 52), 0.55)) })
		if fxLayer then
			fxLayer:Destroy()
		end
		local fx = CLASS_FX[cid] or {}
		fxLayer = UI.Sparkles(bg, c.color:Lerp(Color3.new(1, 1, 1), 0.5), 16, { float = true, icons = fx.icons, iconFrac = 0.45, iconMin = 14, iconMax = 22, star = 0.5, plus = fx.plus, bubble = fx.bubble, color2 = Color3.new(1, 1, 1), z = 0 })
	end
	setClass(cid0)
	return refresh, setClass
end

function Panels.Inventory(args)
	local win = UI.Window("Inventory", "Inventory", UDim2.fromOffset(1180, 600), T.Ocean, "🎒", { fullscreen = true })
	-- left: your character wearing your gear, with the equipment slots around it (tap a slot to inspect it)
	local charPanel = UI.Card(win.body, UDim2.new(0.36, -10, 1, 0), T.PanelDeep)
	local left = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.38, -10, 1, 0), Parent = win.body })
	-- v0.25.68 (owner: the stall button rode above the title bar on big screens): it sits under the detail card now
	local right = UI.Card(win.body, UDim2.new(0.26, 0, 1, -60))
	right.Position = UDim2.new(0.74, 0, 0, 0)
	-- the statue fills the panel (behind the gear slots) so there is plenty of room to drag it round, even on phones
	local stage = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -90), Parent = charPanel })
	local refreshChar, setStageClass = classStage(charPanel, stage, { zoomStart = 1.25 }) -- smaller: the gear tiles covered the head
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
	UI.Icon(titleBtn, "scroll", 22, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 6 }) -- v0.25.99: the pixel font has no ✎
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
		local closeB = New("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Red, Text = "X", TextColor3 = Color3.new(1, 1, 1), FontFace = Font.fromEnum(Enum.Font.Arcade), TextSize = 20, ZIndex = 32, Parent = titlePicker })
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
		-- v0.25.41 (owner): no sunburst behind the item, it just floats in its glow with the particles
		local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3), ImageTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.85, 0.85), ZIndex = 3, Parent = head })
		UI.Sparkles(head, Color3.new(1, 1, 1), 14, { float = true, z = 4, star = 0.6 })
		if def.kind == "Fruit" then
			UI.FruitFx(head, def.fruit, 10)
		end
		New("UIAspectRatioConstraint", { Parent = glow })
		local iconId = UI.ItemIconId(def)
		local big = (def.kind == "Card" and CardArt.Fitted(head, def).holder)
			or (def.kind == "Fruit" and UI.ModelView(head, "Fruits", def.fruit, 200, 0.9, { ZIndex = 5 }))
			or (UI.AccessoryView(head, def.id, 200, { ZIndex = 5 }))
			or (def.weaponType and UI.WeaponView(head, def, 200, 0.7, { ZIndex = 5 }))
			or (def.kind == "Egg" and (UI.VoxelEgg(head, def.id, 200, { ZIndex = 5 })))
			or (UI.VoxelIcon(head, UI.ItemIconName(def), 200, { ZIndex = 5 }))
		if not big and iconId then
			big = New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, ZIndex = 5, Parent = head })
		elseif not big then
			big = UI.Text(head, def.icon or kindIcon[def.kind] or "", 64, T.Text, "Display", { TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		end
		big.AnchorPoint = Vector2.new(0.5, 0.5)
		big.Position = UDim2.fromScale(0.5, 0.43)
		big.Size = UDim2.fromScale(0.72, 0.72)
		if def.kind == "Card" then
			big.Size = UDim2.fromScale(1, 0.8) -- the card fits itself (above the name)
		else
			New("UIAspectRatioConstraint", { Parent = big })
		end
		UI.Pop(big, 0.5) -- (v0.25.41, owner: no rarity jingle when an item opens in the preview)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not head.Parent then
				conn:Disconnect()
				return
			end
			big.Position = UDim2.new(0.5, 0, 0.43, math.sin((os.clock() - t0) * 2.2) * 5)
		end)
		local big2 = 21
		local nameL = UI.Text(head, ItemDB.DisplayName(entry), big2, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, -16, 0, big2 + 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextWrapped = false })
		local tierL = UI.Text(head, string.upper(tier.id), 15, tier.color:Lerp(Color3.new(1, 1, 1), 0.4), "Display", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
		UI.RarityText(nameL, def.rarity)
		UI.RarityText(tierL, def.rarity)
		-- details (scrolls if long)
		local info = UI.Scroll(right, UDim2.new(1, 0, 0.45, -70))
		info.Position = UDim2.new(0, 0, 0.55, 2)
		UI.List(info, nil, 6)
		UI.Text(info, describe(entry, def), 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top })
		-- v0.25.36 (owner): vanity per piece: show or hide THIS worn piece on your character (stats stay)
		if def.slot and def.slot ~= "weapon" and require(ReplicatedStorage.Shared.Modules.Accessory).Has(def.id) then
			local hidden = State.profile.settings and State.profile.settings.hiddenGear or {}
			UI.Toggle(info, "Show on character", not hidden[def.id], function(on)
				State.profile.settings = State.profile.settings or {}
				State.profile.settings.hiddenGear = State.profile.settings.hiddenGear or {}
				State.profile.settings.hiddenGear[def.id] = (not on) or nil
				task.spawn(req, "SetAutoSettings", { gearVisible = { id = def.id, show = on } })
			end, "Hide it without losing its stats")
		end
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
			local function hatch(count)
				local res = req("HatchEgg", { uid = entry.uid, count = count })
				if res.ok and res.data then
					Panels.HatchReveal(res.data.egg, res.data.species)
					if res.data.capped then
						UI.Toast("Hatched " .. #res.data.species .. " (roster or eggs ran out)", "info")
					end
				end
			end
			act("🐣 Hatch", T.Gold, function()
				hatch(1)
			end)
			local have = 0
			for _, e in ipairs(State.profile.inventory or {}) do
				if e.id == entry.id then
					have += e.qty or 1
				end
			end
			if have > 1 then
				act("🐣 x" .. math.min(10, have), T.Orange, function()
					hatch(10)
				end)
			end
		end
		if def.kind == "Fruit" then
			-- v0.25.33 (owner): Use = hold it in your hand; a click then chooses Eat / Store / Drop (Panels.FruitChoice)
			act("Use", T.Pink, function()
				local res = req("HoldFruit", { uid = entry.uid })
				if res.ok then
					State.heldFruit = { uid = entry.uid, def = def, choose = function()
						Panels.FruitChoice(entry.uid, def)
					end }
					UI.CloseAll()
					UI.Toast("Click (or tap) to Eat, Store or Drop the " .. def.name, "info")
				end
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
				cap.MaxTextSize = 22
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
			local def = entry and ItemDB.ForEntry(entry)
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
		gearSlot(slotCols[2], "Pets", "🐾", nil, nil, function()
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
			{ "All", "", "All", T.Ocean },
			{ "Weapon", "", "Weapons", T.Red },
			{ "Armor", "", "Gear", T.Blue },
			{ "Consumable", "", "Food", T.Green },
			{ "Material", "", "Mats", T.Orange },
			{ "Card", "", "Cards", T.Purple },
		}, filter, function(f)
			filter = f
			render()
		end, 32)
		bar.AutomaticSize = Enum.AutomaticSize.X
		bar.Size = UDim2.fromOffset(0, 38)
		local list = {}
		for i, e in ipairs(p.inventory) do
			local def = ItemDB.ForEntry(e)
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
				detail(e, ItemDB.ForEntry(e))
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
			detail(e, ItemDB.ForEntry(e))
		end
	end
	onProfile(win, render)
	onProfile(win, function()
		setStageClass(State.profile and State.profile.class)
	end)
	-- the stall: a labelled button under the detail card (the market stall icon + OPEN STALL)
	local stallBtn, h = UI.Button(win.body, "🏪 OPEN STALL", T.Orange, UDim2.new(0.26, 0, 0, 50), function()
		Panels.StallSetup()
	end)
	UI.Tooltip(stallBtn, function()
		return "Open Stall: sell your items to other players", T.Orange
	end)
	h.AnchorPoint = Vector2.new(0, 1)
	h.Position = UDim2.new(0.74, 0, 1, 0)
end

-- ===================== STATS =====================
function Panels.Stats()
	-- like the Bag: your character on the left; on the right the attribute table. Plan points with - / +, then Apply
	-- (nothing is spent until you press it). Below, the combat numbers those attributes give you.
	local win = UI.Window("Stats", "Stats", UDim2.fromOffset(1100, 600), T.Purple, "📊", { fullscreen = true })
	local charPanel = UI.Card(win.body, UDim2.new(0.38, -10, 1, 0), T.PanelDeep)
	local stage = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 1, -160), Parent = charPanel })
	local refreshChar, setStageClass = classStage(charPanel, stage)
	-- v0.25.72: your Toki color (only shown when you have a Toki)
	local tokiBtn, tokiHolder = UI.Button(charPanel, "🎨", T.Gold, UDim2.fromOffset(46, 46), function()
		Panels.TokiColor()
	end)
	tokiHolder.AnchorPoint = Vector2.new(1, 0)
	tokiHolder.Position = UDim2.new(1, -10, 0, 10)
	tokiHolder.ZIndex = 6
	UI.Tooltip(tokiBtn, function()
		return "Toki color", T.Gold
	end)
	-- v0.25.43 (owner: the top looked empty): name centered, class on the 2nd line, levels on the 3rd, big and clear
	local CENTER = Enum.TextXAlignment.Center
	local nameLabel = UI.Text(charPanel, "", 30, T.Text, "Display", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 36), TextXAlignment = CENTER })
	local classLabel = UI.Text(charPanel, "", 22, T.Text, "Display", { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 26), TextXAlignment = CENTER })
	local subLabel = UI.Text(charPanel, "", 19, T.TextSoft, "Display", { Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 0, 24), TextXAlignment = CENTER })
	-- v0.25.70: Power (what Conqueror Toki compares) + your Toki in its own color
	local powerLabel = UI.Text(charPanel, "", 17, T.Gold, "Display", { Position = UDim2.fromOffset(14, 110), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = CENTER })
	powerLabel.RichText = true
	UI.Text(charPanel, "drag to turn", 12, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Center })
	-- scrolls when the window is short (small screens) instead of spilling out of the frame
	local right = UI.Scroll(win.body, UDim2.new(0.62, 0, 1, 0))
	right.Position = UDim2.new(0.38, 0, 0, 0)
	local desc = { STR = "Physical attack", AGI = "Attack speed / dodge", VIT = "HP / defense", INT = "Magic / SP", DEX = "Accuracy / ranged", LUK = "Crits / drops / will power" }
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
		tokiHolder.Visible = type(p.toki) == "table" and next(p.toki) ~= nil and (p.toki.Conqueror or p.toki.Armament or p.toki.Observation) ~= nil
		-- the name wears the equipped title's tier color; levels in the EXP / JOB ring colors
		local tdef = TitlesCfg.ById[p.title or ""]
		nameLabel.TextColor3 = tdef and Rarity.Get(tdef.tier).color or T.Text
		classLabel.Text = cls and cls.name or p.class
		classLabel.TextColor3 = Color3.new(1, 1, 1) -- on the class-colored backdrop (v0.25.68)
		setStageClass(p.class)
		subLabel.RichText = true
		do
			local parts = { UI.Colored("Power " .. Formulas.Power(d, p.baseLevel), T.Gold) }
			for _, k in ipairs(require(Shared.Config.Toki).Kinds) do
				local e = type(p.toki) == "table" and p.toki[k.id]
				if e then
					table.insert(parts, UI.Colored(k.name, require(Shared.Config.Toki).ColorOf(e)))
				end
			end
			powerLabel.Text = table.concat(parts, "   ")
		end
		subLabel.Text = UI.Colored("Base Lv." .. p.baseLevel, Color3.new(1, 1, 1)) .. "     " .. UI.Colored("Job Lv." .. p.jobLevel, T.Gold)
		if not drawn then
			drawn = true
			local wEntry = p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
			local wDef = wEntry and ItemDB.Get(wEntry.id)
			refreshChar((wDef and wDef.weaponType) or "Fists")
		end
		local left = p.statPoints - planCost(p)

		-- v0.25.67 (owner: cramped header, LUK row hidden under the buttons, unclear colors): a points pill + a
		-- Reset Stats button (opens the Store product) on top, column colors BASE white / BONUS green / NEXT COST yellow
		local ROW0, ROWH, ROWGAP = 92, 48, 6
		local tblH = ROW0 + 6 * (ROWH + ROWGAP) + 12 + 50 + 28
		local tbl = UI.Card(right, UDim2.new(1, -12, 0, tblH), T.Panel)
		UI.Pad(tbl, 14)
		local pill = New("Frame", { BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(250, 48), Parent = tbl })
		UI.Corner(pill, 10)
		New("UIStroke", { Color = left > 0 and T.Gold or T.Grey, Thickness = 2, Transparency = 0.2, Parent = pill })
		UI.Text(pill, "POINTS LEFT", 17, T.TextSoft, "Display", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -110, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
		UI.Text(pill, tostring(left), 30, left > 0 and T.Gold or T.Text, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 90, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center })
		local resetBtn, rh = UI.Button(tbl, "Reset Stats", T.Red, UDim2.fromOffset(190, 46), function()
			-- refunds every point you spent (Store benefit "ResetStats": the Robux prompt; Gems in the Store)
			pend = {}
			render()
			req("StoreBuyRobux", { id = "ResetStats" })
		end)
		rh.AnchorPoint = Vector2.new(1, 0)
		rh.Position = UDim2.new(1, 0, 0, 0)
		UI.Tooltip(resetBtn, function()
			return "Reset Stats: get back every stat point you spent and plan your build again (also in the Store for Gems).", T.Red
		end)
		-- column titles, in the same color as their numbers
		local cols = { { "ATTRIBUTE", 0, 0.32, T.TextSoft }, { "BASE", 0.32, 0.12, T.Text }, { "BONUS", 0.44, 0.12, T.Green }, { "NEXT COST", 0.56, 0.16, T.Gold } }
		for _, c in ipairs(cols) do
			UI.Text(tbl, c[1], 14, c[4], "Display", { Position = UDim2.new(c[2], c[2] == 0 and 12 or 0, 0, 62), Size = UDim2.new(c[3], 0, 0, 22), TextXAlignment = c[2] == 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		end
		for i, s in ipairs(Formulas.StatNames) do
			local y = ROW0 + (i - 1) * (ROWH + ROWGAP)
			local row = New("Frame", { BackgroundColor3 = i % 2 == 0 and T.PanelDeep or T.PanelTop, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ROWH), Parent = tbl })
			UI.Corner(row, 10)
			local base, n = p.stats[s], pend[s] or 0
			local bonus = (d[s] or base) - base
			local MID = Enum.TextYAlignment.Center
			UI.Text(row, s, 22, UI.StatColor[s] or T.Text, "Display", { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.32, -12, 0, 24), TextYAlignment = MID })
			UI.Text(row, desc[s], 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(12, 29), Size = UDim2.new(0.32, -12, 0, 15), TextYAlignment = MID })
			UI.Text(row, tostring(base) .. (n > 0 and ('<font color="#7CFF9B"> +' .. n .. "</font>") or ""), 22, T.Text, "Number", { Position = UDim2.fromScale(0.32, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = MID })
			local bl = UI.Text(row, bonus ~= 0 and ((bonus > 0 and "+" or "") .. bonus) or "0", 22, bonus < 0 and T.Red or T.Green, "Number", { Position = UDim2.fromScale(0.44, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = MID })
			if bonus == 0 then
				bl.TextTransparency = 0.5 -- nothing adds to it yet: the same green, dimmed
			end
			-- v0.25.69 (owner): hover the bonus to see where it comes from (gear, cards, fruit, later Toki)
			UI.Tooltip(bl, function()
				local lines, sum = { s .. " bonus" }, 0
				for _, src in ipairs((Formulas.StatSources(p))[s] or {}) do
					table.insert(lines, src[1] .. "  " .. (src[2] > 0 and "+" or "") .. src[2])
					sum += src[2]
				end
				if bonus - sum ~= 0 then
					table.insert(lines, "Other  " .. (bonus - sum > 0 and "+" or "") .. (bonus - sum))
				end
				if #lines == 1 then
					table.insert(lines, "Nothing yet: gear, cards and a Cursed Fruit can add to it")
				end
				return table.concat(lines, "\n"), T.Green
			end)
			local nextCost = Formulas.StatCost(base + n)
			local maxed = base + n >= Formulas.MaxStat
			local nl = UI.Text(row, maxed and "MAX" or tostring(nextCost), 22, maxed and T.TextSoft or T.Gold, "Number", { Position = UDim2.fromScale(0.56, 0), Size = UDim2.new(0.16, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = MID })
			if not maxed and nextCost > left then
				nl.TextTransparency = 0.5 -- not enough points left: dimmed
			end
			local function stepBtn(text, color, xOff, fn)
				local _, h = UI.Button(row, text, color, UDim2.fromOffset(44, 38), fn)
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
		local foot = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, ROW0 + 6 * (ROWH + ROWGAP) + 6), Size = UDim2.new(1, 0, 0, 48), Parent = tbl })
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
		local autoBtn = UI.Button(foot, autoOn and "Auto upgrade: ON" or "Auto upgrade: OFF", autoOn and T.Ocean or T.Grey, UDim2.new(0.5, -5, 1, 0), function()
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
		-- v0.25.43: fixed 3 x 4 grid; the AutomaticSize card lost its frame after a re-render (Reset plan)
		local cs = UI.Card(right, UDim2.new(1, -12, 0, 4 * 30 + 24), T.PanelDeep)
		cs.Position = UDim2.fromOffset(0, tblH + 12)
		UI.Pad(cs, 12)
		local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = cs })
		New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -12, 0, 26), CellPadding = UDim2.fromOffset(18, 4), Parent = grid })
		for _, l in ipairs({
			-- v0.25.8 (owner: too plain): each derived stat in its own color (same family as the attribute it comes from)
			{ "HP", d.maxHp, T.Green }, { "SP", d.maxSp, T.Blue }, { "ATK", d.atk, UI.StatColor.STR }, { "MATK", d.matk, UI.StatColor.INT },
			{ "DEF", d.def, UI.StatColor.VIT }, { "MDEF", d.mdef, Color3.fromRGB(190, 160, 255) },
			{ "HIT", d.hit, UI.StatColor.DEX }, { "FLEE", d.flee, UI.StatColor.AGI }, { "CRIT", string.format("%.1f%%", d.crit), UI.StatColor.LUK },
			{ "Attack every", string.format("%.2fs", d.attackInterval), Color3.fromRGB(255, 150, 120) }, { "Cannon dmg", "+" .. math.floor(d.cannonDamage * 100) .. "%", Color3.fromRGB(255, 120, 90) },
			{ "Ship speed", "+" .. math.floor(d.shipSpeed * 100) .. "%", Color3.fromRGB(110, 210, 255) },
		}) do
			local r = New("Frame", { BackgroundTransparency = 1, Parent = grid })
			UI.Text(r, l[1], 15, l[3], "Semi", { Size = UDim2.new(0.6, 0, 1, 0) })
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
-- right with Learn. Skill Sets tab (v0.25.71): the 6 hotbar sets (keys 1-6) with their skills and an Auto switch each.
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
	if tier == "Toki" then
		for _, s in ipairs(require(Shared.Config.Toki).Skills) do
			if type(p.toki) == "table" and p.toki[s.toki] then
				table.insert(out, { s, 1, 1, false })
			end
		end
	elseif tier == "Fruit" then
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

function Panels.Skills(args)
	if args and args.tab then
		skillsView.side = args.tab == "Loadout" and "Sets" or args.tab
	end
	local win = UI.Window("Skills", "Skills", UDim2.fromOffset(1000, 620), T.Gold, "✨", { fullscreen = true })
	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), Parent = win.body })
	UI.List(side, nil, 10)
	local content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(162, 0), Size = UDim2.new(1, -162, 1, 0), Parent = win.body })
	local render

	local function sidebar()
		clear(side)
		UI.List(side, nil, 10)
		for i, it in ipairs({ { "Skills", "✨", "Skill Tree" }, { "Sets", "⚔️", "Skill Sets" } }) do
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
		if type(p.toki) == "table" and next(p.toki) and (p.toki.Conqueror or p.toki.Armament or p.toki.Observation) then
			table.insert(tiers, { "Toki", "👑", "Toki", T.Gold })
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
			UI.Text(left, "🔒 Second jobs open with the Grand Current update.\n" .. (#names > 0 and ("Paths for your class: " .. table.concat(names, ", ")) or "Switch to a first job at the Job Master (Job Lv." .. GameConfig.JobChangeLevel .. ") to see its paths."), 18, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 120) })
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
			-- v0.25.71: skills are not placed by hand any more: every skill sits in its set (keys 1-6)
			local where = sk.fruit and "Set 2 (Fruit)" or (sk.toki and "the Toki sets (4-6)" or (sk.class == "Common" and "Set 3 (Basic)" or "Set 1 (Class)"))
			UI.Text(btns, "On the hotbar in " .. where, 14, T.TextSoft, "Semi", { Size = UDim2.new(0.5, -5, 0, 52), TextYAlignment = Enum.TextYAlignment.Center })
		end
	end

	-- ---------- skill sets (v0.25.71, owner) ----------
	-- the 6 sets on the hotbar (keys 1-6 pick one, E R F Z X C cast its skills) and whether Auto Battle uses each
	local function renderSets(p)
		local SkillSets = require(Shared.Modules.SkillSets)
		local Combat = require(script.Parent.Parent.Controllers.Combat)
		local Hotkeys = require(script.Parent.Parent.Controllers.Hotkeys)
		local scroll = UI.Scroll(content, UDim2.fromScale(1, 1))
		UI.List(scroll, nil, 10)
		UI.Text(scroll, "Keys " .. Hotkeys.Label("Set1") .. "-" .. Hotkeys.Label("Set6") .. " pick a set; " .. Combat.SKILL_KEY_LABELS[1] .. " " .. Combat.SKILL_KEY_LABELS[2] .. " " .. Combat.SKILL_KEY_LABELS[3] .. " " .. Combat.SKILL_KEY_LABELS[4] .. " " .. Combat.SKILL_KEY_LABELS[5] .. " " .. Combat.SKILL_KEY_LABELS[6]
			.. " cast its skills. AUTO uses every set that is switched on (only Fruit = farm Fruit Mastery).", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 0 })
		for n, set in ipairs(SkillSets.Sets) do
			local open = SkillSets.Open(p, n)
			local active = Combat.ActiveSet() == n
			local card = UI.Card(scroll, UDim2.new(1, -8, 0, 132), active and T.PanelTop or T.PanelDeep)
			card.LayoutOrder = n
			if active then
				UI.Stroke(card, T.Gold, 3)
			end
			local title = set.name
			if set.id == "Class" and Classes[p.class] then
				title = "Class: " .. Classes[p.class].name
			elseif set.id == "Fruit" and p.fruit and FruitsCfg.ById[p.fruit.id] then
				title = FruitsCfg.ById[p.fruit.id].name
			end
			UI.Text(card, Hotkeys.Label("Set" .. n) .. "  " .. title .. (open and "" or "  (locked)"), 18, open and T.Text or T.TextSoft, "Display", { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -290, 0, 24) })
			-- its skills, left to right = E R F Z X C
			local strip = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 80), Parent = card })
			UI.List(strip, Enum.FillDirection.Horizontal, 8)
			local list = SkillSets.Skills(p, n)
			if #list == 0 then
				UI.Text(strip, set.id == "Fruit" and "Eat a Cursed Fruit to fill this set." or (set.toki and "You do not have this Toki yet." or "No skills yet."), 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 30) })
			end
			for i, e in ipairs(list) do
				local cell = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 80), LayoutOrder = i, Parent = strip })
				local c = SkillLook.Color(e.skill)
				local ic = New("Frame", { BackgroundColor3 = c, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(52, 52), Parent = cell })
				UI.Corner(ic, 10)
				UI.Stroke(ic, T.Edge, 2)
				local img = SkillLook.IconId(e.skill)
				if img then
					New("ImageLabel", { BackgroundTransparency = 1, Image = img, ImageTransparency = e.ready and 0 or 0.6, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, Parent = ic })
				end
				UI.Text(ic, Combat.SKILL_KEY_LABELS[i], 11, T.Gold, "Display", { Position = UDim2.fromOffset(3, 2), Size = UDim2.fromOffset(20, 14), ZIndex = 3 })
				UI.Text(cell, e.skill.name, 11, e.ready and T.Text or T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
			end
			-- use this set now / let Auto use it
			local _, uh = UI.Button(card, active and "IN USE" or "USE", active and T.Grey or (open and T.Green or T.Grey), UDim2.fromOffset(110, 44), function()
				Combat.SetActiveSet(n)
				render()
			end)
			uh.AnchorPoint = Vector2.new(1, 0)
			uh.Position = UDim2.new(1, -144, 0, 12)
			local auto = SkillSets.Auto(p, n)
			local _, ah = UI.Button(card, auto and "AUTO ON" or "AUTO OFF", auto and T.Ocean or T.Grey, UDim2.fromOffset(126, 44), function()
				p.settings = p.settings or {}
				local a = {}
				for k = 1, #SkillSets.Sets do
					a[k] = SkillSets.Auto(p, k)
				end
				a[n] = not auto
				p.settings.autoSets = a
				State.Fire("profile")
				task.spawn(req, "SetAutoSettings", { autoSets = a })
			end)
			ah.AnchorPoint = Vector2.new(1, 0)
			ah.Position = UDim2.new(1, -8, 0, 12)
		end
	end

	render = function()
		local p = State.profile
		sidebar()
		clear(content)
		if not p then
			return
		end
		if skillsView.side == "Sets" then
			renderSets(p)
		else
			renderTree(p)
		end
	end
	render()
	onProfile(win, render)
	win.resized.Event:Connect(render)
end

-- ===================== JOB CHANGE =====================
-- v0.25.37 (owner reference: a hero-select screen), full screen: class emblems on a wheel at the left (pick one and
-- the wheel turns it to the middle), your character in the middle holding that class's weapon with CHOOSE / SWITCH
-- under it, the class name + its top three stats (rings, ranked 1-2-3) on the right, and its type disc (kanji in
-- the middle, green half = types it beats, red half = types it is weak to) bottom right.
local function roundCorner(f)
	f:SetAttribute("PxKeep", true) -- PixelUI squares every corner; these are meant to be round
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
end
-- a stroke for a round piece: a mitred join fills the corners and draws a square box around the circle
local function roundStroke(f, color, thick)
	local st = UI.Stroke(f, color, thick)
	st.LineJoinMode = Enum.LineJoinMode.Round
	return st
end

local function typeDisc(parent, typeId, color, size)
	local Types = require(Shared.Config.MonsterTypes)
	local ty = Types[typeId]
	local disc = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(size, size), Parent = parent })
	roundCorner(disc)
	-- top half green (beats), bottom half red (weak to): a hard stop in one gradient
	local GREEN, RED = Color3.fromRGB(120, 200, 110), Color3.fromRGB(236, 112, 96)
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GREEN), ColorSequenceKeypoint.new(0.495, GREEN), ColorSequenceKeypoint.new(0.505, RED), ColorSequenceKeypoint.new(1, RED) }), Parent = disc })
	roundStroke(disc, T.Edge, 3)
	local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(250, 244, 230), ZIndex = 3, Parent = disc })
	roundCorner(core)
	roundStroke(core, T.Edge, 2.5)
	if ty then
		UI.Text(core, ty.kanji, math.floor(size * 0.22), color or ty.color, "Semi", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	-- the small badges: beaten types on the green half, the ones that beat it on the red half
	local function badge(id, angle)
		local t = Types[id]
		local r = size * 0.37
		local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(math.rad(angle)) * r, 0.5, math.sin(math.rad(angle)) * r), Size = UDim2.fromOffset(size * 0.2, size * 0.2), BackgroundColor3 = t.color, ZIndex = 4, Parent = disc })
		roundCorner(b)
		roundStroke(b, Color3.new(1, 1, 1), 2)
		UI.Text(b, t.kanji, math.floor(size * 0.1), Color3.new(1, 1, 1), "Semi", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		UI.Tooltip(b, function()
			return t.name, t.color
		end)
	end
	if ty then
		local function spread(i, count)
			return count == 1 and 0 or (i == 1 and -40 or 40)
		end
		for i, id in ipairs(ty.beats) do
			badge(id, -90 + spread(i, #ty.beats))
		end
		local weak = Types.WeakTo(typeId)
		for i, id in ipairs(weak) do
			badge(id, 90 - spread(i, #weak))
		end
	end
	return disc
end

-- a ring of square segments filled to `k` (0..1), the stat and its rank in the middle (reference: Power/Accel/Speed)
local function statRing(parent, stat, rank, k, color, size)
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size + 22), Parent = parent })
	local N = 18
	for i = 1, N do
		local a = math.rad(i / N * 360 - 90)
		local on = i <= math.floor(k * N + 0.5)
		local seg = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * size * 0.42, 0, size / 2 + math.sin(a) * size * 0.42), Size = UDim2.fromOffset(size * 0.13, size * 0.13), Rotation = math.deg(a), BackgroundColor3 = on and color or T.PanelDeep, BorderSizePixel = 0, Parent = f })
		if on then
			roundStroke(seg, UI.Shade(color, -0.35), 1)
		end
	end
	UI.Text(f, tostring(rank), math.floor(size * 0.3), color, "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, size / 2 - size * 0.06), Size = UDim2.fromOffset(size * 0.6, size * 0.34), TextXAlignment = Enum.TextXAlignment.Center })
	UI.Text(f, stat, math.floor(size * 0.13), T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, size / 2 + size * 0.17), Size = UDim2.fromOffset(size * 0.6, size * 0.16), TextXAlignment = Enum.TextXAlignment.Center })
	return f
end

function Panels.JobMaster()
	UI.FullPref.Job = true -- always full screen: no shrink button, only the X (owner)
	local win = UI.Window("Job", "Job Master", UDim2.fromOffset(1180, 620), T.Green, "🎓", { fullscreen = true })
	if win.maxBtn then
		win.maxBtn.Visible = false
	end
	local list = ClassesCfg.FirstJobs
	local n = #list
	local sel = math.max(1, table.find(list, State.profile and State.profile.class or "") or 1)

	-- owner: the background is the class's own color, a bright gradient (not dark)
	local bg = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(-24, -14), Size = UDim2.new(1, 48, 1, 28), ZIndex = 0, Parent = win.body })
	local bgGrad = New("UIGradient", { Rotation = 115, Parent = bg })
	local bgGlow = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.39, 0.42), Size = UDim2.fromScale(0.9, 1.1), ZIndex = 0, Parent = bg })
	local _ = bgGlow
	-- v0.25.40 (owner): the shallow sea covers the whole screen below the horizon, a gradient in the class color
	local water = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.47), Size = UDim2.fromScale(1, 0.53), ZIndex = 0, Parent = bg })
	local waterGrad = New("UIGradient", { Rotation = 90, Parent = water })
	local shoreLine = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), ZIndex = 0, Parent = water })
	local _ = shoreLine
	local fxLayer -- class particles, remade per class
	-- left: the class wheel
	local wheel = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.2, 0, 1, 0), ClipsDescendants = true, ZIndex = 2, Parent = win.body })
	-- middle: the character on a podium, the button under it
	local mid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.2, 0), Size = UDim2.new(0.38, 0, 1, 0), ZIndex = 2, Parent = win.body })
	local aura = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.1, 0.9), Parent = mid })
	-- the character stands in the sea lit by the class color (reference), drag to turn 360, wheel to zoom. The view
	-- covers the whole window (the water must reach every edge) and puts the character in the middle column
	local stage = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-24, -14), Size = UDim2.new(1, 48, 1, 28), ZIndex = 1, Parent = win.body })
	local _, refreshChar = UI.CharacterView(stage, nil, { water = true, zoom = true, zoomStart = 1.5, shiftX = -0.11, shiftY = 0.07, onFrame = function(h)
		water.Position = UDim2.fromScale(0, h)
		water.Size = UDim2.fromScale(1, 1 - h)
	end })
	UI.Text(mid, "drag to turn  •  scroll to zoom", 12, Color3.new(1, 1, 1), "Semi", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.76, 4), Size = UDim2.fromOffset(260, 16), TextXAlignment = Enum.TextXAlignment.Center })
	local btnHolder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(260, 92), Parent = mid })
	-- right: name, description, stat rings, then the type card
	local right = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.6, 0), Size = UDim2.new(0.4, 0, 1, 0), ZIndex = 2, Parent = win.body })

	local items = {}
	local show
	local function place(animate)
		for i, it in ipairs(items) do
			local k = ((i - sel + math.floor(n / 2)) % n) - math.floor(n / 2) -- -3..3, the picked one at 0
			local a = math.abs(k)
			local size = math.max(52, 124 - a * 26)
			local goal = { Size = UDim2.fromOffset(size, size), Position = UDim2.new(0.5, 34 - a * a * 9, 0.5, k * 104) }
			it.btn.ZIndex = 10 - a
			if animate and a < math.floor(n / 2) then
				TweenService:Create(it.btn, TweenInfo.new(0.32, Enum.EasingStyle.Back), goal):Play()
			else
				it.btn.Size, it.btn.Position = goal.Size, goal.Position
			end
			it.btn.BackgroundTransparency = a >= 3 and 0.6 or 0
			it.ring.Thickness = a == 0 and 5 or 2.5
			it.ring.Color = a == 0 and Color3.new(1, 1, 1) or T.Edge
		end
	end
	for i, cid in ipairs(list) do
		local c = Classes[cid]
		local btn = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = c.color, Parent = wheel })
		roundCorner(btn)
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(UI.Shade(c.color, 0.25), UI.Shade(c.color, -0.3)), Parent = btn })
		local ring = roundStroke(btn, T.Edge, 2.5)
		UI.Icon(btn, c.icon, 40, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58), ZIndex = btn.ZIndex + 1 })
		UI.Tooltip(btn, function()
			return c.name, c.color
		end)
		btn.Activated:Connect(function()
			if sel ~= i then
				sel = i
				Audio.Play("UIClick")
				place(true)
				show(true)
			end
		end)
		items[i] = { btn = btn, ring = ring }
	end
	local lastWeapon
	show = function(animate)
		local p = State.profile
		if not p then
			return
		end
		local cid = list[sel]
		local c = Classes[cid]
		local Types = require(Shared.Config.MonsterTypes)
		local ty = Types[c.mtype or ""]
		aura.ImageColor3 = c.color:Lerp(Color3.new(1, 1, 1), 0.6)
		waterGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c.color:Lerp(Color3.new(1, 1, 1), 0.55)), ColorSequenceKeypoint.new(0.35, c.color:Lerp(Color3.new(1, 1, 1), 0.2)), ColorSequenceKeypoint.new(1, c.color:Lerp(Color3.fromRGB(24, 20, 52), 0.45)) })
		if fxLayer then
			fxLayer:Destroy()
		end
		local fx = CLASS_FX[cid] or {}
		fxLayer = UI.Sparkles(bg, c.color:Lerp(Color3.new(1, 1, 1), 0.5), 22, { float = true, icons = fx.icons, iconFrac = 0.45, iconMin = 16, iconMax = 26, star = 0.5, plus = fx.plus, bubble = fx.bubble, color2 = Color3.new(1, 1, 1), z = 0 })
		bgGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c.color:Lerp(Color3.new(1, 1, 1), 0.35)), ColorSequenceKeypoint.new(0.55, c.color), ColorSequenceKeypoint.new(1, c.color:Lerp(Color3.fromRGB(30, 26, 60), 0.35)) })
		-- the statue holds this class's weapon
		local w = c.weapons[1] or "Fists"
		if cid ~= lastWeapon then
			lastWeapon = cid
			refreshChar(w, c.color)
		end
		-- button: CHOOSE the first time, SWITCH after that; your own class says CURRENT
		clear(btnHolder)
		local switches = p.classSwitches or 0
		local cost = switches == 0 and 0 or p.baseLevel * GameConfig.ClassSwitchCostPerLevel
		local locked = switches == 0 and p.jobLevel < GameConfig.JobChangeLevel
		local current = cid == p.class
		local label = current and "CURRENT" or (locked and ("JOB LV." .. GameConfig.JobChangeLevel) or (switches == 0 and "CHOOSE" or "SWITCH"))
		local b = UI.Button(btnHolder, label, (current or locked) and T.Grey or c.color, UDim2.new(1, 0, 0, 60), function()
			if current or locked then
				return
			end
			local msg = (switches == 0 and "Choose " or "Switch to ") .. c.name .. "?" .. (cost > 0 and ("\nCost: " .. UI.Format(cost) .. " Doubloons") or "\nYour first switch is free.") .. "\nYour " .. Classes[p.class].name .. " progress is kept."
			UI.Confirm(msg, function()
				local res = req("ChangeJob", { class = cid })
				if res.ok then
					UI.Banner("Class Change!", c.name, c.color, "Legendary")
				end
			end, nil, switches == 0 and "Choose" or "Switch", "Cancel")
		end)
		b.Parent.Position = UDim2.fromOffset(0, 0)
		local saved = p.classProgress and p.classProgress[cid]
		local note = current and ("Job Lv." .. p.jobLevel) or (locked and ("Reach Job Lv." .. GameConfig.JobChangeLevel .. " to switch")
			or ((saved and ("Saved: Job Lv." .. saved.jobLevel .. "  •  ") or "") .. (cost == 0 and "Free" or (COIN .. " " .. UI.Format(cost)))))
		UI.Text(btnHolder, note, 14, Color3.new(1, 1, 1), "Semi", { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })

		-- right side
		clear(right)
		local role = UI.Text(right, string.upper(c.role or ""), 30, Color3.new(1, 1, 1), "Display", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 36), TextWrapped = false, TextScaled = true })
		New("UITextSizeConstraint", { MaxTextSize = 30, Parent = role })
		role.TextTransparency = 0.4
		local nameL = UI.Text(right, c.name, 56, T.Text, "Display", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 58), TextWrapped = false, TextScaled = true })
		New("UITextSizeConstraint", { MaxTextSize = 56, Parent = nameL })
		local descL = UI.Text(right, c.desc or "", 16, Color3.new(1, 1, 1), "Semi", { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 44) })
		UI.Stroke(descL, UI.Shade(c.color, -0.5), 1.5, Enum.ApplyStrokeMode.Contextual)
		-- top three stats of its build, ranked
		local build = {}
		for stat, wgt in pairs(c.build or {}) do
			table.insert(build, { stat, wgt })
		end
		table.sort(build, function(x, y)
			return x[2] > y[2] or (x[2] == y[2] and x[1] < y[1])
		end)
		local rings = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 150), Parent = right })
		UI.List(rings, Enum.FillDirection.Horizontal, 14)
		for r = 1, math.min(3, #build) do
			statRing(rings, build[r][1], r, build[r][2] / 5, UI.StatColor[build[r][1]] or c.color, r == 1 and 128 or 104)
		end
		-- the class card: type disc + weapon + skills
		local card = UI.Card(right, UDim2.new(1, 0, 1, -316), T.PanelDeep)
		card.Position = UDim2.fromOffset(0, 316)
		-- v0.25.41 (owner: empty space at the bottom): a bigger disc and bigger text, both centered in the card
		local disc = typeDisc(card, c.mtype, c.color, 184)
		disc.AnchorPoint = Vector2.new(0, 0.5)
		disc.Position = UDim2.new(0, 14, 0.5, 0)
		local col = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(212, 10), Size = UDim2.new(1, -224, 1, -20), Parent = card })
		local lay = UI.List(col, nil, 10)
		lay.VerticalAlignment = Enum.VerticalAlignment.Center
		-- fixed line heights (no AutomaticSize: every line has a known box, nothing can overlap)
		local function line(text, size, color, kind, order, lines)
			return UI.Text(col, text, size, color, kind, { RichText = true, Size = UDim2.new(1, 0, 0, math.ceil(size * 1.25 * lines)), TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = order })
		end
		line(ty and (ty.kanji .. "  " .. string.upper(ty.name)) or "", 24, c.color, "Display", 1, 1)
		local beats, weak = {}, {}
		for _, id in ipairs(ty and ty.beats or {}) do
			table.insert(beats, UI.Colored(Types[id].name, Types[id].color))
		end
		for _, id in ipairs(ty and Types.WeakTo(c.mtype) or {}) do
			table.insert(weak, UI.Colored(Types[id].name, Types[id].color))
		end
		line(UI.Colored("STRONG VS ", Color3.fromRGB(120, 200, 110)) .. table.concat(beats, ", ") .. "\n" .. UI.Colored("WEAK TO ", Color3.fromRGB(236, 112, 96)) .. table.concat(weak, ", "), 18, T.Text, "Semi", 2, 2)
		line(string.format("Deals +%d%% to the type it beats, %d%% less to the one it is weak to.", math.floor((Types.Bonus - 1) * 100 + 0.5), math.floor((1 - Types.Penalty) * 100 + 0.5)), 15, T.TextSoft, "Semi", 3, 2)
		local names = {}
		for _, sk in ipairs(c.skills) do
			table.insert(names, sk.name)
		end
		line(UI.Colored("Weapon: ", T.Gold) .. w .. "\n" .. UI.Colored("Skills: ", T.Gold) .. table.concat(names, " • "), 17, T.Text, "Semi", 4, 3)
		if animate then
			UI.Pop(nameL, 0.8)
		end
	end
	place(false)
	show(false)
	onProfile(win, function()
		show(false)
	end)
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
	local fitCol = function() end

	local function count(id)
		local n = 0
		for _, x in ipairs(State.profile.inventory) do
			if x.id == id then
				n += x.qty or 1
			end
		end
		return n
	end

	-- the item on its pedestal: glow ring + the 3D weapon (or the item's icon). v0.25.106 (owner): no sunburst rays
	local function showcase(parent, def, y, size)
		local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(size, size), Parent = parent })
		local tier = ItemDB.Rarity(def)
		local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), BackgroundColor3 = tier.color:Lerp(T.PanelDeep, 0.55), Parent = holder })
		UI.Corner(ring, size)
		UI.Stroke(ring, tier.color:Lerp(Color3.new(1, 1, 1), 0.3), 4)
		New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = tier.color, ImageTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = holder })
		-- v0.25.112 (owner): blades show their pixel art here (the thin 3D katana read badly on the stage)
		local view = def.weaponType and not def.blade and UI.WeaponView(holder, def, math.floor(size * 0.8), 0.7, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		if not view then
			local img = UI.ItemIconId(def)
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, ResampleMode = Enum.ResamplerMode.Pixelated, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), Parent = holder })
			end
		end
		return holder
	end

	local function centerText(parent, text, size, color, font, y, w, h)
		return UI.Text(parent, text, size, color, font, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(w, h), TextXAlignment = Enum.TextXAlignment.Center })
	end

	-- material / coin tiles in a centered row
	local function costRow(parent, y, cost)
		local mats = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(300, 78), Parent = parent })
		UI.List(mats, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
		local all = true
		local order = 0
		for k, v in pairs(cost) do
			local beli = k == "beli"
			local have = beli and (State.profile.beli or 0) or count(k)
			local enough = have >= v
			all = all and enough
			order += 1
			local t = New("Frame", { Size = UDim2.fromOffset(78, 78), BackgroundColor3 = T.Panel, LayoutOrder = beli and 99 or order, Parent = mats })
			UI.Corner(t, 12)
			UI.Stroke(t, enough and T.Edge or T.Red, 3)
			local img = beli and UI.IconId("coin") or UI.ItemIconId(ItemDB.Get(k))
			if img then
				New("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.14, 0.04), Parent = t })
			end
			UI.Text(t, beli and UI.Short(v) or (have .. "/" .. v), 14, enough and T.Text or T.Red, "Number", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, -4, 0, 16), TextXAlignment = Enum.TextXAlignment.Right })
		end
		return all
	end

	-- v0.25.106 (owner): Forge shows how far the item is up its rarity's refine track (one pip per level) and what comes
	-- at the end; at the top of the track the FORGE button becomes EVOLVE (Ascend: next rarity, refine back to +0).
	-- Everything sits in a fixed 560x600 column scaled to the stage (no overlaps on small screens); FORGE / EVOLVE play
	-- the Blacksmith cutscene (UI/ForgeScene) and the result shows after it.
	local function renderForge(p, e, def, col)
		local cur = e.refine or 0
		local canEvo, nextR, need, cost = ItemDB.AscendInfo(e)
		local cap = canEvo and need or GameConfig.Refine.Max
		local tier = ItemDB.Rarity(def)
		showcase(col, def, 100, 190)
		centerText(col, ItemDB.DisplayName(e), 24, T.Text, "Display", 202, 540, 28)
		-- refine track
		local track = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 238), Size = UDim2.fromOffset(540, 20), Parent = col })
		UI.List(track, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
		local pw = math.min(30, math.floor((540 - 4 * (cap - 1)) / cap))
		for i = 1, cap do
			local pip = New("Frame", { Size = UDim2.fromOffset(pw, 18), BackgroundColor3 = i <= cur and tier.color or T.PanelDeep, LayoutOrder = i, Parent = track })
			UI.Stroke(pip, i == cur + 1 and T.Gold or T.Edge, 2)
		end
		local goal
		if canEvo then
			local to = Rarity.Get(nextR)
			goal = string.format('+%d / +%d  then EVOLVE to <font color="#%s">%s</font>', cur, need, to.color:ToHex(), string.upper(nextR))
		else
			goal = "+" .. cur .. " / +" .. cap .. (def.kind == "Weapon" and nextR and ("  •  " .. nextR) or "")
		end
		centerText(col, goal, 15, T.Text, "Bold", 264, 540, 20)

		local function play(action, payload, after)
			if busy then
				return
			end
			busy = true
			local res
			task.spawn(function()
				res = Net.Request(action, payload)
			end)
			ForgeScene.Play(stage, def, function()
				while res == nil do
					task.wait()
				end
				busy = false
				after(res)
				if stage.Parent then
					render()
				end
			end)
		end

		if canEvo and cur >= need then
			local to = Rarity.Get(nextR)
			centerText(col, string.format('<font color="#%s">%s</font>  >  <font color="#%s">%s</font>', tier.color:ToHex(), string.upper(tier.id), to.color:ToHex(), string.upper(to.id)), 28, T.Text, "Display", 300, 540, 34)
			local payOk = costRow(col, 346, cost)
			centerText(col, "Refine goes back to +0  •  ATK +" .. math.floor(GameConfig.Ascend.AtkStep * 100) .. "%  •  +1 card slot", 15, T.TextSoft, "Bold", 436, 540, 20)
			local _, vh = UI.Button(col, "🔥 EVOLVE", payOk and T.Orange or T.Grey, UDim2.fromOffset(300, 60), function()
				if not payOk then
					UI.Toast("Not enough materials", "bad")
					return
				end
				UI.Confirm("Evolve " .. ItemDB.DisplayName(e) .. " to " .. string.upper(nextR) .. "?\nIts refine goes back to +0.", function()
					play("Ascend", { uid = e.uid }, function(res)
						if res.data and res.data.result == "evolved" then
							Audio.Play("RefineSuccess")
							local ne = Formulas.FindItem(State.profile, e.uid) or e
							UI.Banner("Evolved!", ItemDB.DisplayName(ne), to.color, nextR)
						else
							UI.Toast(res.msg or "Could not evolve", "bad")
						end
					end)
				end, nil, "Evolve", "Cancel")
			end)
			vh.AnchorPoint = Vector2.new(0.5, 1)
			vh.Position = UDim2.new(0.5, 0, 1, -10)
			return
		end
		if cur >= cap then
			centerText(col, "Already at +" .. cap .. "!", 26, T.Gold, "Display", 310, 400, 34)
			return
		end
		local cls = Classes[p.class]
		local chance = math.min(1, GameConfig.Refine.Chance[cur + 1] + (cls and cls.passive and cls.passive.refineBonus or 0))
		local mat, qty, beliCost = ItemDB.RefineMaterial(cur)
		centerText(col, "+" .. cur .. "  >  +" .. (cur + 1), 30, T.Gold, "Display", 296, 300, 36)
		costRow(col, 340, { [mat] = qty, beli = beliCost })
		local barHolder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 428), Size = UDim2.fromOffset(360, 24), Parent = col })
		local cBar = UI.Bar(barHolder, chance >= 1 and T.Green or (chance >= 0.4 and T.Gold or T.Red), UDim2.fromOffset(360, 24), "Success " .. math.floor(chance * 100) .. "%")
		cBar:Set(chance)
		local risk = cur < GameConfig.Refine.Safe and '<font color="#7CFF9B">Safe: cannot fail</font>' or (cur >= GameConfig.Refine.BreakFrom and '<font color="#FF5C6C">Risk: failure may SHATTER the item</font>' or '<font color="#FFB347">Risk: failure drops 1 level</font>')
		centerText(col, risk, 15, T.Text, "Bold", 460, 480, 20)
		local _, gh = UI.Button(col, useGuard and "🛡 Charm: ON" or "🛡 Charm: OFF", useGuard and T.Purple or T.Grey, UDim2.fromOffset(170, 56), function()
			useGuard = not useGuard
			render()
		end)
		gh.AnchorPoint = Vector2.new(1, 1)
		gh.Position = UDim2.new(0.5, -10, 1, -12)
		UI.Tooltip(gh:FindFirstChildWhichIsA("TextButton") or gh, function()
			return "Willpower Charm: a failed forge does not drop or break the item (uses one charm)", T.Purple
		end)
		local _, fh = UI.Button(col, "🔨 FORGE", T.Orange, UDim2.fromOffset(260, 60), function()
			play("Refine", { uid = e.uid, useGuard = useGuard }, function(res)
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
			end)
		end)
		fh.AnchorPoint = Vector2.new(0, 1)
		fh.Position = UDim2.new(0.5, 0, 1, -10)
	end

	-- Insert Card: the item in the middle, a socket per card slot around it; tap "+" to choose a card that fits
	local pickingSlot
	local function renderCards(p, e, def, col)
		showcase(col, def, 260, 230)
		UI.Text(col, ItemDB.DisplayName(e), 24, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 392), Size = UDim2.new(1, -20, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
		local slots = def.slots or 0
		if slots == 0 then
			UI.Text(col, "This item has no card slots.", 18, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 430), Size = UDim2.fromOffset(400, 24), TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		for k = 1, slots do
			-- sockets sit on an arc above / beside the item
			local a = math.rad(-90 + (k - (slots + 1) / 2) * 70)
			local pos = UDim2.new(0.5, math.cos(a) * 190, 0, 260 + math.sin(a) * 160)
			local cardId = e.cards and e.cards[k]
			local cdef = cardId and ItemDB.Get(cardId)
			local b = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(92, 92), BackgroundColor3 = cdef and Color3.new(1, 1, 1) or T.Panel, Rotation = 45, Parent = col })
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
				UI.Text(col, cdef.name, 13, T.Gold, "Bold", { AnchorPoint = Vector2.new(0.5, 0), Position = pos + UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(160, 16), TextXAlignment = Enum.TextXAlignment.Center })
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

	local listScroll
	render = function()
		local keepY = listScroll and listScroll.CanvasPosition.Y or 0
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
		listScroll = list
		task.defer(function()
			list.CanvasPosition = Vector2.new(0, keepY)
		end)
		UI.List(list, nil, 8)
		New("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = list }) -- v0.25.106: tile rims were clipped
		local first
		for _, e in ipairs(p.inventory) do
			local def = ItemDB.ForEntry(e)
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
		local def = ItemDB.ForEntry(e)
		-- a 560x600 design column scaled to fit the stage (the window's own UIScale measured with a 100-px probe)
		local col = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 600), Parent = stage })
		local colScale = New("UIScale", { Parent = col })
		fitCol = function()
			local probe = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 100), Parent = stage })
			local anc = probe.AbsoluteSize.X / 100
			probe:Destroy()
			local s = stage.AbsoluteSize
			if anc > 0 and s.X > 0 and s.Y > 0 then
				colScale.Scale = math.min(s.X / anc / 580, s.Y / anc / 612, 1.3)
			end
		end
		pcall(fitCol)
		if tab == "Forge" then
			renderForge(p, e, def, col)
		else
			renderCards(p, e, def, col)
		end
	end
	render()
	onProfile(win, function()
		if not busy then
			render()
		end
	end)
	win.resized.Event:Connect(render)
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		pcall(fitCol)
	end)
end

-- ===================== SHOP =====================
-- v0.25.42 (owner reference "SHOP" board): one item card for the Shop, a player's stall and the stall setup:
-- rarity tile, icon, name, quantity badge, a price (or a price box) and a row of buttons along the bottom
local function shopGrid(parent, size)
	local grid = UI.Scroll(parent, size)
	New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 214), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = grid })
	return grid
end
local function byRarity(list, defOf)
	table.sort(list, function(x, y)
		local rx, ry = ItemDB.Rarity(defOf(x)).rank, ItemDB.Rarity(defOf(y)).rank
		if rx ~= ry then
			return rx > ry
		end
		return (x.i or 0) < (y.i or 0)
	end)
	return list
end
-- o = { def, entry?, order, qty?, price? (text), priceBox? (default text), buttons = { { label, color, fn }, ... } }
-- returns the card and the price TextBox (when asked for one)
local function shopCard(parent, o)
	local def = o.def
	local card = New("Frame", { LayoutOrder = o.order or 0, Parent = parent })
	UI.Corner(card, 12)
	UI.RarityStyle(card, def.rarity)
	if def.kind == "Fruit" then
		UI.FruitFx(card, def.fruit, 4)
	end
	local iconId = UI.ItemIconId(def)
	if iconId then
		New("ImageLabel", { BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(82, 82), ZIndex = 4, Parent = card })
	else
		UI.Text(card, def.icon or kindIcon[def.kind] or "❔", 44, T.Text, "Display", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	if o.qty and o.qty > 1 then
		UI.Text(card, "x" .. o.qty, 14, T.Text, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(60, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	end
	local nm = UI.Text(card, o.entry and ItemDB.DisplayName(o.entry) or def.name, 15, T.Text, "Semi", { Position = UDim2.fromOffset(6, 94), Size = UDim2.new(1, -12, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4 })
	UI.RarityText(nm, def.rarity)
	local box
	if o.priceBox then
		box = New("TextBox", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.new(1, -20, 0, 28), PlaceholderText = "Price", Text = o.priceBox, FontFace = UI.Fonts.Number, TextSize = 16, TextColor3 = T.Gold, BackgroundColor3 = T.PanelDeep, ZIndex = 5, Parent = card })
		UI.Corner(box, 6)
		UI.Stroke(box, T.Edge, 2)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local digits = box.Text:gsub("%D", "")
			if digits ~= box.Text then
				box.Text = digits
			end
		end)
	elseif o.price then
		UI.Text(card, o.price, 15, T.Gold, "Number", { Position = UDim2.fromOffset(6, 134), Size = UDim2.new(1, -12, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	local row = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 38), ZIndex = 4, Parent = card })
	UI.List(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	local n = #(o.buttons or {})
	local btns = {}
	for _, bt in ipairs(o.buttons or {}) do
		table.insert(btns, (UI.Button(row, bt[1], bt[2], UDim2.new(1 / n, n > 1 and -3 or 0, 1, 0), bt[3])))
	end
	UI.Tooltip(card, function()
		return "<b>" .. def.name .. "</b>  " .. string.upper(ItemDB.Rarity(def).id) .. (def.desc and ("\n" .. def.desc) or ""), ItemDB.Rarity(def).color
	end)
	return card, box, btns
end

function Panels.Shop()
	-- grid of item cards (icon, name, price, BUY, and a bulk button beside it for stackable things), rarest first
	local win = UI.Window("Shop", "Shop", UDim2.fromOffset(820, 600), T.Green, "🛍️")
	local grid = shopGrid(win.body)
	local items = {}
	for i, id in ipairs(ItemDB.Shop) do
		local def = ItemDB.Get(id)
		if def then
			table.insert(items, { def = def, i = i })
		end
	end
	byRarity(items, function(x)
		return x.def
	end)
	local buys = {} -- { button, cost }
	-- v0.25.123 (owner): the blade merchant shows one random blade for a fee; BUY or PASS without knowing its tier
	local fee = GameConfig.BladeRoll.Fee
	local _, _, lookBtns = shopCard(grid, { def = { id = "MysteryBlade", name = "Mystery Blade", kind = "Weapon", weaponType = "Sword", grade = "Keen", rarity = "Common", desc = "Pay to see one blade from the merchant's chest. Most are plain good steel, a few are famous. Can you tell which?" }, order = 0, price = COIN .. " " .. UI.Format(fee), buttons = { { "LOOK", T.Gold, function()
		Panels.BladeOffer()
	end } } })
	table.insert(buys, { lookBtns[1], fee })
	for order, it in ipairs(items) do
		local def, id = it.def, it.def.id
		-- ammo comes in handfuls
		local q1, q2 = 1, 10
		if def.kind == "Ammo" then
			q1, q2 = 20, 99
		end
		local buttons = { { "BUY", T.Green, function()
			req("ShopBuy", { id = id, qty = q1 }, "Purchase")
		end } }
		if def.stack then
			table.insert(buttons, { "x" .. q2, T.Green, function()
				req("ShopBuy", { id = id, qty = q2 }, "Purchase")
			end })
		end
		local _, _, btns = shopCard(grid, { def = def, order = order, qty = q1 > 1 and q1 or nil, price = COIN .. " " .. UI.Format(def.price * q1), buttons = buttons }) -- ammo: BUY = one handful (badge xN)
		table.insert(buys, { btns[1], def.price * q1 })
		if btns[2] then
			table.insert(buys, { btns[2], def.price * q2 })
		end
	end
	-- v0.25.43 (owner): buy buttons are green when you can afford them, red when you can't
	local function recolor()
		local have = State.profile and State.profile.beli or 0
		for _, b in ipairs(buys) do
			UI.SetButtonColor(b[1], have >= b[2] and T.Green or T.Red)
		end
	end
	recolor()
	onProfile(win, recolor)
end

function Panels.BladeOffer()
	local res = req("BladeLook")
	local def = res.ok and res.data and ItemDB.Get(res.data.id)
	if not def then
		return
	end
	require(script.Parent.ItemReveal).Play(def) -- famous (Rare+) blades get the full reveal first
	local win = UI.Window("BladeOffer", "Blade Merchant", UDim2.fromOffset(460, 520), ItemDB.Rarity(def).color, "⚔️")
	UI.List(win.body, nil, 8, Enum.HorizontalAlignment.Center)
	local stage = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.fromOffset(260, 220), LayoutOrder = 1, Parent = win.body })
	UI.Corner(stage, 12)
	UI.RarityStyle(stage, def.rarity)
	local vp = UI.WeaponView(stage, def, 220, true)
	if vp then
		vp.AnchorPoint = Vector2.new(0.5, 0.5)
		vp.Position = UDim2.fromScale(0.5, 0.5)
	end
	local nm = UI.Text(win.body, def.name, 22, T.Text, "Display", { Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2 })
	UI.RarityText(nm, def.rarity)
	local lean = def.dex and ("DEX +" .. def.dex .. "  LUK +" .. def.luk) or ("STR +" .. (def.str or 0) .. "  VIT +" .. (def.vit or 0))
	UI.Text(win.body, string.format("%s  •  ATK %d  •  %s\nCard slots %d  •  Needs Lv.%d", def.typeLabel or "Sword", def.atk, lean, def.slots or 0, def.reqLevel or 1), 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3 })
	UI.Text(win.body, COIN .. " " .. UI.Format(def.price), 20, T.Gold, "Number", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4 })
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 50), LayoutOrder = 5, Parent = win.body })
	UI.List(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	local have = State.profile and State.profile.beli or 0
	UI.Button(row, "BUY", have >= def.price and T.Green or T.Red, UDim2.fromOffset(170, 48), function()
		if req("BladeBuy", nil, "Purchase").ok then
			win:Destroy()
		end
	end)
	UI.Button(row, "PASS", T.Panel, UDim2.fromOffset(170, 48), function()
		req("BladePass")
		win:Destroy()
	end)
end

-- ===================== TAVERN =====================
-- v0.25.142 (owner): crew are recruited, not bought. The Tavern Keeper shows your crew; sailors walking around the
-- tavern are talked to one by one (Panels.Recruit, opened by the server when you press E on one).
local Recruits = require(Shared.Config.Recruits)

local function wantText(w)
	if w.kind == "coin" then
		return COIN .. " " .. UI.Format(w.amount)
	end
	local def = ItemDB.Get(w.id)
	return w.qty .. "x " .. (def and def.name or w.id)
end

local function canGive(w)
	local p = State.profile
	if w.kind == "coin" then
		return (p.beli or 0) >= w.amount
	end
	local n = 0
	for _, e in ipairs(p.inventory or {}) do
		if e.id == w.id then
			n += e.qty or 1
		end
	end
	return n >= w.qty
end

function Panels.Tavern()
	local win = UI.Window("Tavern", "Tavern", UDim2.fromOffset(620, 520), T.Red, "🍺")
	local p = State.profile
	local design = p.ships[p.activeShip] or p.ships[1]
	local st = ShipStats.Compute(design, p.crew)
	UI.List(win.body, nil, 8)
	UI.Section(win.body, "🧑‍✈️", "Your Crew", T.Red, p.crew .. " / " .. st.crewCap .. " bunks").LayoutOrder = 1
	local list = p.recruits or {}
	local old = math.max(0, (p.crew or 0) - #list)
	local b = Recruits.Bonus(list)
	UI.Text(win.body, string.format("Talk to the sailors around here (E) to recruit them.  Crew bonus: reload -%d%%  speed +%d%%  hull +%.1f%%/s  heal +%.1f%%/s",
		b.reload * 100, b.speed * 100, b.repair * 100, b.heal * 100), 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 })
	local scroll = UI.Scroll(win.body, UDim2.new(1, 0, 1, -110))
	scroll.LayoutOrder = 3
	UI.List(scroll, nil, 6)
	for i, r in ipairs(list) do
		local prof = Recruits.Professions[r.prof] or {}
		local row = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.new(1, -8, 0, 48), LayoutOrder = i, Parent = scroll })
		UI.Corner(row, 8)
		UI.Text(row, (prof.icon or "") .. " " .. r.name, 16, T.Text, "Display", { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.6, 0, 0, 20) })
		UI.Text(row, (r.race or "") .. "  •  " .. (prof.name or "") .. "  " .. string.rep("*", r.stars or 1) .. "  •  " .. Recruits.EffectText(r), 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(0.75, 0, 0, 18) })
		local _, btn = UI.Button(row, "DISMISS", T.Panel, UDim2.fromOffset(110, 36), function()
			if req("DismissRecruit", { seed = r.seed }).ok then
				win:Destroy()
				Panels.Tavern()
			end
		end)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -8, 0.5, 0)
	end
	if old > 0 then
		UI.Text(scroll, "+ " .. old .. " deckhand" .. (old > 1 and "s" or "") .. " (from before: they man cannons and oars)", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = 999 })
	elseif #list == 0 then
		UI.Text(scroll, "No one yet. Sailors looking for a ship hang around this tavern: walk up and press E.", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 999 })
	end
end

-- one sailor: who they are, their job, what they want for joining (args from the server's OpenPanel push)
function Panels.Recruit(c)
	if type(c) ~= "table" or not c.key then
		return
	end
	local prof = Recruits.Professions[c.prof] or {}
	local win = UI.Window("Recruit", c.name, UDim2.fromOffset(560, 470), T.Red, prof.icon or "🍺")
	local stage = New("Frame", { BackgroundColor3 = T.PanelDeep, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(200, 260), Parent = win.body })
	UI.Corner(stage, 12)
	if typeof(c.model) == "Instance" and c.model.Parent then
		local m = c.model:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
				d:Destroy()
			end
		end
		local vp = UI.ModelViewOf(stage, m, 200, 0.5)
		vp.Position = UDim2.fromOffset(0, 30)
	end
	local x = 216
	local function line(text, size, color, font, y, h)
		return UI.Text(win.body, text, size, color, font, { Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x, 0, h or 22) })
	end
	line(c.name, 22, T.Text, "Display", 0, 28)
	line((c.race or "") .. "  •  " .. (prof.name or "") .. "  " .. string.rep("*", c.stars or 1), 16, T.Gold, "Display", 32)
	line("\"" .. (c.line or "") .. "\"", 15, T.TextSoft, "Semi", 60, 44).TextWrapped = true
	line(prof.desc or "", 14, T.Text, "Semi", 110, 40).TextWrapped = true
	line("On your ship: " .. Recruits.EffectText(c), 15, Color3.fromRGB(150, 230, 150), "Semi", 152)
	line("Wants:", 15, T.TextSoft, "Semi", 190)
	line(wantText(c.want), 20, canGive(c.want) and T.Gold or Color3.fromRGB(255, 120, 110), "Number", 212, 26)
	local p = State.profile
	local design = p.ships[p.activeShip] or p.ships[1]
	local st = ShipStats.Compute(design, p.crew)
	line("Bunks: " .. p.crew .. " / " .. st.crewCap, 14, T.TextSoft, "Semi", 244)
	local ok = not c.have and canGive(c.want) and p.crew < st.crewCap
	local _, btn = UI.Button(win.body, c.have and "IN YOUR CREW" or "RECRUIT", ok and T.Green or T.Red, UDim2.fromOffset(260, 52), function()
		if c.have then
			return
		end
		if req("RecruitCrew", { key = c.key }, "Purchase").ok then
			win:Destroy()
		end
	end)
	btn.Position = UDim2.new(0, x, 0, 290)
	local _, bye = UI.Button(win.body, "LATER", T.Panel, UDim2.fromOffset(140, 52), function()
		win:Destroy()
	end)
	bye.Position = UDim2.new(0, x + 272, 0, 290)
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
			UI.Text(card, string.format("%d parts • HP %d • %d cannons\nSpeed: %d in wind / %d in the Doldrums", st.partCount, st.hp, #st.cannons, ShipStats.Speed(st, 1), ShipStats.Speed(st, 0)), 15, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -250, 0, 40) })
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
		-- v0.25.23 (owner): the Shipwright only edits; MENU -> Ships calls the ACTIVE ship out or puts it away
		if d and slot ~= p.activeShip then
			local _, h2 = UI.Button(card, "⭐ Use", T.Green, UDim2.fromOffset(116, 44), function()
				if req("SetActiveShip", { slot = slot }).ok then
					p.activeShip = slot
					win:Destroy()
					Panels.Shipwright()
				end
			end)
			h2.Position = UDim2.new(1, -118, 0, 20)
		end
	end
end

-- MENU -> Ships: call the active ship (at the nearest dock, or where you swim) or put it away
function Panels.SummonShip()
	local res = req("SummonShip") -- v0.25.115 (owner): no bell when you set sail
	if res.ok and not res.msg then
		UI.Banner("Set Sail!", "W/S sails  •  A/D steer  •  click water to fire cannons", T.Ocean)
	end
end

-- ===================== MAP / FAST TRAVEL =====================
function Panels.FastTravel()
	local win = UI.Window("Map", Islands.SeaName, UDim2.fromOffset(1000, 480), T.Ocean, "🗺️", { fullscreen = true })
	-- the sea strip sits in the middle of the window (full screen used to leave it stuck to the top)
	-- v0.25.11: islands drawn where they are (x east, -z north), Doldrums bands top and bottom
	local strip = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, -70), Parent = win.body })
	local minX, maxX = -500, Islands.RedLine.x
	-- v0.25.110 (owner: tiles ran into each other and the Doldrums bands): islands live in an inner sea frame that keeps
	-- a whole tile + its two label lines between the bands, and z is spread over the farthest island's z
	local maxZ = 1
	for _, isl in ipairs(Islands.List) do
		maxZ = math.max(maxZ, math.abs(isl.z or 0))
	end
	local function mapPos(x, z)
		return math.clamp(0.05 + (x - minX) / (maxX - minX) * 0.83, 0.05, 0.88), 0.5 + math.clamp(z / maxZ, -1, 1) * 0.5
	end
	UI.Corner(strip, 16)
	UI.Gradient(strip, Color3.fromRGB(110, 210, 245), Color3.fromRGB(50, 150, 210), 90)
	UI.Stroke(strip, T.Edge, 3)
	for _, top in ipairs({ true, false }) do
		local calm = New("Frame", { BackgroundColor3 = Color3.fromRGB(30, 90, 115), Size = UDim2.new(1, 0, 0, 42), Position = top and UDim2.new() or UDim2.new(0, 0, 1, -42), Parent = strip })
		UI.Corner(calm, 16)
		UI.Text(calm, "☠  " .. string.upper(Islands.CalmName) .. "  •  no wind, Leviathans", 16, Color3.fromRGB(190, 230, 240), "Bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	end
	local TW, TH = 110, 96
	local sea = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42 + TH / 2 + 4), Size = UDim2.new(1, 0, 1, -(84 + TH + 44)), Parent = strip })
	local p = State.profile
	local n = #Islands.List
	for i, isl in ipairs(Islands.List) do
		local x, y = mapPos(isl.x, isl.z or 0)
		local unlocked = p.unlocked[isl.id]
		local charted = ChartsView.Known(isl.id)
		-- v0.25.19 (owner): each island is its pixel-art emblem (tools/gen_island_icons.py) with our name on the ribbon;
		-- uncharted islands are a dark silhouette with "???"
		local dot = New("ImageButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(TW, TH), BackgroundTransparency = 1,
			Image = UI.IconId("isl_" .. isl.id) or "", ScaleType = Enum.ScaleType.Fit, ImageColor3 = charted and (unlocked and Color3.new(1, 1, 1) or Color3.fromRGB(170, 170, 185)) or Color3.fromRGB(40, 45, 60), AutoButtonColor = false, Parent = sea })
		UI.Tactile(dot)
		UI.Text(dot, charted and isl.name or "???", 13, Color3.fromRGB(255, 244, 214), "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.785, 0), Size = UDim2.new(0.74, 0, 0.15, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextScaled = true })
		UI.Text(dot, "Lv." .. isl.levels[1] .. "-" .. isl.levels[2] .. (unlocked and "" or "  🔒"), 13, Rarity.LevelColor(player:GetAttribute("Level") or 1, isl.levels[1]), "Number", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(140, 16), TextXAlignment = Enum.TextXAlignment.Center })
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
			UI.Text(dot, "🧰 " .. found .. "/" .. total, 15, found == total and T.Gold or T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 20), Size = UDim2.fromOffset(100, 18), TextXAlignment = Enum.TextXAlignment.Center })
		end
		dot.Activated:Connect(function()
			if not unlocked then
				UI.Toast(charted and "Not discovered yet: sail there first" or "Uncharted: finish this island's story and your compass will point the way", "bad")
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
	UI.Text(win.body, "Islands lie north and south of the route east: pick a heading, steer around sea stacks and stop at sandbars and wrecks. Stay in the windy sea: the Doldrums at the edges have no wind and Leviathans. Past the last island, " .. Islands.RedLine.peakName .. " leads to the " .. Islands.RedLine.nextSea .. " (next update).", 16, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 64), TextXAlignment = Enum.TextXAlignment.Center })
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
				UI.Text(card, "Lv." .. b.level .. "  •  " .. ChartsView.NameOf(b.island) .. "  •  " .. (b.alive and "ALIVE NOW!" or string.format("respawns in %d:%02d", math.max(0, left) // 60, math.max(0, left) % 60)), 15, b.alive and T.Gold or T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 26) })
			end
		end
		local gw = State.guildWar
		if gw then
			UI.Section(list, "⚔️", "Crew War", gw.active and T.Red or T.Gold, gw.active and "IN PROGRESS!" or "Saturdays")
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
	-- v0.25.108 (owner): CREW (shipmates). Forming one picks no side; invite online players by name; crewmates share a
	-- party when they come online. Your own side: Jolly Roger here, Marines at the Marine Registrar (Conch Bay).
	local win = UI.Window("Guild", "Crew", UDim2.fromOffset(820, 580), T.Purple, "🏴")
	task.spawn(Net.Request, "GuildInfo")
	local body = win.body
	local function factionLine(parent)
		local f = player:GetAttribute("Faction") or "None"
		local label = f == "Marine" and "⚓ Marine" or (f == "Pirate" and "☠️ Pirate" or "Civilian")
		-- v0.25.110: the side on its own line, the Pirate button under it (the button covered the text in the narrow card)
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, f == "None" and 70 or 26), Parent = parent })
		UI.Text(row, "Your side: " .. label, 17, f == "Marine" and T.Marine or (f == "Pirate" and T.Pirate or T.TextSoft), "Bold", { Size = UDim2.new(1, 0, 0, 24) })
		if f == "None" then
			local _, h = UI.Button(row, "☠️ RAISE THE JOLLY ROGER", T.Pirate, UDim2.new(1, 0, 0, 40), function()
				UI.Confirm("Become a Pirate? Every NPC ship becomes fair game and beating Marines raises your bounty.\nMarines enlist at the Marine Registrar in Conch Bay instead.", function()
					req("SetFaction", { faction = "Pirate" })
				end, nil, "Pirate!", "Not yet")
			end)
			h.Position = UDim2.fromOffset(0, 28)
		end
		return row
	end
	local function render()
		clear(body)
		local oldLayout = body:FindFirstChildOfClass("UIListLayout")
		if oldLayout then
			oldLayout:Destroy()
		end
		local g = State.guild
		if g then
			UI.List(body, nil, 8)
			UI.Text(body, "🏴 " .. g.name .. "  Lv." .. g.level, 30, T.Gold, "Display", { LayoutOrder = 1 })
			local f = factionLine(body)
			-- invite by name
			local inv = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 3, Parent = body })
			local box = New("TextBox", { Size = UDim2.new(1, -170, 1, 0), PlaceholderText = "Player name", Text = "", ClearTextOnFocus = false, FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, PlaceholderColor3 = T.TextSoft, BackgroundColor3 = T.PanelDeep, Parent = inv })
			UI.Corner(box, 10)
			UI.Stroke(box, T.Edge, 2.5)
			local _, ih = UI.Button(inv, "📨 INVITE", T.Green, UDim2.fromOffset(160, 46), function()
				if #box.Text >= 2 then
					local res = req("CrewInvite", { name = box.Text })
					if res.ok then
						box.Text = ""
					end
				end
			end)
			ih.AnchorPoint = Vector2.new(1, 0)
			ih.Position = UDim2.fromScale(1, 0)
			local sec = UI.Section(body, "👥", "Crewmates", T.Purple)
			if typeof(sec) == "Instance" then
				sec.LayoutOrder = 4
			end
			local list = UI.Scroll(body, UDim2.new(1, 0, 0, 250))
			list.LayoutOrder = 5
			UI.List(list, nil, 4)
			for uid, m in pairs(g.members) do
				local online = Players:GetPlayerByUserId(tonumber(uid) or 0) ~= nil
				local row = UI.Card(list, UDim2.new(1, -12, 0, 46))
				UI.Pad(row, 8)
				UI.Text(row, (m.rank == "Leader" and "👑 " or "• ") .. m.name .. "  [" .. m.rank .. "]" .. (online and '  <font color="#7CFF9B">online</font>' or ""), 17, T.Text, "Bold")
				if g.leader == player.UserId and tonumber(uid) ~= player.UserId then
					local _, h = UI.Button(row, "Kick", T.Red, UDim2.fromOffset(74, 32), function()
						req("GuildKick", { userId = uid })
					end)
					h.Position = UDim2.new(1, -76, 0, -2)
				end
			end
			local _, lh = UI.Button(body, "Leave Crew", T.Red, UDim2.fromOffset(190, 46), function()
				UI.Confirm("Leave the crew?", function()
					req("GuildLeave")
				end, nil, "Leave", "Stay")
			end)
			lh.LayoutOrder = 6
			if f then
				f.LayoutOrder = 2
			end
			return
		end
		local left = UI.Card(body, UDim2.new(0.48, 0, 1, 0))
		UI.Pad(left, 14)
		UI.List(left, nil, 8)
		UI.Section(left, "🏗️", "Form a Crew", T.Gold)
		UI.Text(left, "Requires Lv." .. GameConfig.GuildCreateLevel .. "  •  " .. COIN .. " " .. UI.Format(GameConfig.GuildCreateCost), 15, T.TextSoft, "Semi")
		local box = New("TextBox", { Size = UDim2.new(1, 0, 0, 44), PlaceholderText = "Crew name", Text = "", ClearTextOnFocus = false, FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, PlaceholderColor3 = T.TextSoft, BackgroundColor3 = T.PanelDeep, Parent = left })
		UI.Corner(box, 10)
		UI.Stroke(box, T.Edge, 2.5)
		UI.Text(left, "A crew is your band of shipmates: invite players by name, and crewmates join the same party when they come online. Forming a crew picks no side.", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 80) })
		UI.Button(left, "Form Crew", T.Green, UDim2.new(1, 0, 0, 48), function()
			req("GuildCreate", { name = box.Text }, "Purchase")
		end)
		factionLine(left)
		local right = UI.Scroll(body, UDim2.new(0.5, 0, 1, 0))
		right.Position = UDim2.new(0.5, 0, 0, 0)
		UI.List(right, nil, 6)
		UI.Section(right, "🤝", "Join a Crew", T.Green)
		task.spawn(function()
			local res = Net.Request("GuildList")
			if #(res.data or {}) == 0 then
				UI.Text(right, "No crews yet: form the first one!", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -12, 0, 30) })
			end
			for _, g2 in ipairs(res.data or {}) do
				local row = UI.Card(right, UDim2.new(1, -12, 0, 52))
				UI.Pad(row, 8)
				UI.Text(row, "🏴 " .. g2.name .. "  (" .. g2.count .. ")", 17, T.Text, "Bold")
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
	local fconn = player:GetAttributeChangedSignal("Faction"):Connect(render)
	win.frame.Destroying:Connect(function()
		conn:Disconnect()
		fconn:Disconnect()
	end)
end

-- v0.25.108 (owner): the Marine Registrar in Conch Bay: enlist in the Marines or resign (back to Civilian)
function Panels.Marine()
	local win = UI.Window("Marine", "Marine Registrar", UDim2.fromOffset(620, 440), T.Marine, "⚓")
	local body = win.body
	local function render()
		clear(body)
		UI.List(body, nil, 10)
		local f = player:GetAttribute("Faction") or "None"
		UI.Text(body, f == "Marine" and "⚓ You serve in the Marines." or (f == "Pirate" and "☠️ You fly the Jolly Roger." or "You are a Civilian."), 22, f == "Marine" and T.Marine or (f == "Pirate" and T.Pirate or T.Text), "Display", { LayoutOrder = 1 })
		UI.Text(body, "Marines: Marine NPC ships leave you alone. Catch pirates for Merit and a cut of their bounty. Seastone gear and the Marine Mast. Requires Lv." .. GameConfig.GuildCreateLevel .. "; wanted pirates cannot enlist.", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 90), LayoutOrder = 2 })
		local _, h
		if f == "Marine" then
			_, h = UI.Button(body, "RESIGN", T.Red, UDim2.fromOffset(260, 56), function()
				UI.Confirm("Leave the Marines and become a Civilian?", function()
					req("SetFaction", { faction = "None" })
				end, nil, "Resign", "Stay")
			end)
		else
			_, h = UI.Button(body, "⚓ ENLIST", T.Marine, UDim2.fromOffset(260, 56), function()
				req("SetFaction", { faction = "Marine" })
			end)
		end
		h.LayoutOrder = 3
	end
	render()
	local conn = player:GetAttributeChangedSignal("Faction"):Connect(render)
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

-- ===================== AUTO BATTLE (v0.25.44, owner: the gear next to the AUTO / MANUAL switch) =====================
function Panels.AutoBattle()
	local win = UI.Window("AutoBattle", "Auto Battle", UDim2.fromOffset(560, 250), T.Green, "autobattle")
	local ab = GameConfig.AutoBattle
	local function render()
		clear(win.body)
		local p = State.profile
		if not p then
			return
		end
		p.settings = p.settings or {}
		local function stepper(y, label, value, onStep, hint)
			local row = UI.Card(win.body, UDim2.new(1, 0, 0, 70), T.PanelDeep)
			row.Position = UDim2.fromOffset(0, y)
			UI.Text(row, label, 18, T.Text, "Bold", { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(0.55, 0, 0, 26) })
			UI.Text(row, hint, 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(0.55, 0, 0, 18) })
			for k, d in ipairs({ -1, 1 }) do
				local _, h = UI.Button(row, d < 0 and "-" or "+", d < 0 and T.Pink or T.Green, UDim2.fromOffset(48, 44), function()
					onStep(d)
				end)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, k == 1 and -142 or -10, 0.5, -2)
			end
			UI.Text(row, value, 22, T.Gold, "Number", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2.fromOffset(78, 30), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local radius = State.SearchRadius()
		stepper(0, "Search range", radius .. "", function(d)
			local v = math.clamp(radius + d * 5, ab.MinRadius, ab.SearchRadius)
			p.settings.autoRadius = v
			State.Fire("profile")
			task.spawn(req, "SetAutoSettings", { autoRadius = v })
		end, "how far Auto Battle looks for monsters (studs)")
		-- (v0.25.55: "Eat below" moved to the gear on the F1 / F2 potion slots, Panels.Potion)
		UI.Text(win.body, "Auto Battle never wanders more than " .. ab.LeashRadius .. " studs from where it started. Pick the skill sets it may use in Skills -> Skill Sets (AUTO ON / OFF). Potions: the gear on the F1 / F2 slots.", 14, T.TextSoft, "Semi", { Position = UDim2.fromOffset(4, 80), Size = UDim2.new(1, -8, 0, 60) })
	end
	render()
	onProfile(win, render)
end

-- ===================== POTION SLOT (v0.25.55, owner reference) =====================
-- The gear on the F1 (HP) / F2 (SP) hotbar slot: pick Auto or one potion, and the HP / SP % it drinks below by itself
-- (0 = off). Settings hpItem / spItem / hpPct / spPct (SetAutoSettings); Combat.PotionPick / autoPotion read them.
function Panels.Potion(args)
	local kind = args and args.kind == "sp" and "sp" or "hp"
	local Combat = require(script.Parent.Parent.Controllers.Combat)
	local label = kind == "hp" and "HP" or "SP"
	local color = kind == "hp" and T.Red or T.Ocean
	local win = UI.Window("Potion", label .. " potion", UDim2.fromOffset(500, 300), color, kind == "hp" and "meat_s" or "grog_s")
	local potions = {}
	for _, id in ipairs(ItemDB.Shop) do
		if Combat.PotionPower(ItemDB.Get(id), kind) then
			table.insert(potions, id)
		end
	end
	local function render()
		clear(win.body)
		local p = State.profile
		if not p then
			return
		end
		p.settings = p.settings or {}
		local pick = p.settings[kind .. "Item"] or "Auto"
		local pct = p.settings[kind .. "Pct"] or Combat.POTION_PCT[kind]
		UI.Text(win.body, "Choose the " .. label .. " potion to use", 15, T.Text, "Bold", { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
		local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 92), Parent = win.body })
		UI.List(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
		local _, byId = Combat.PotionsOwned(kind)
		local function choose(id)
			p.settings[kind .. "Item"] = id
			State.Fire("profile")
			task.spawn(req, "SetAutoSettings", { [kind .. "Item"] = id })
			render()
		end
		for _, id in ipairs({ "Auto", table.unpack(potions) }) do
			local on = pick == id
			local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = on and Color3.fromRGB(255, 244, 214) or Color3.fromRGB(232, 222, 200), Size = UDim2.fromOffset(86, 86), Parent = row })
			UI.Corner(b, 12)
			UI.Stroke(b, on and T.Green or T.Edge, on and 4 or 2)
			UI.Tactile(b)
			if id == "Auto" then
				UI.Text(b, "Auto", 18, T.Edge, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			else
				local def = ItemDB.Get(id)
				New("ImageLabel", { BackgroundTransparency = 1, Image = UI.ItemIconId(def) or "", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -24), Parent = b })
				local n = byId[id] and byId[id].qty or 0
				local q = UI.Text(b, tostring(n), 15, n > 0 and Color3.new(1, 1, 1) or T.Red, "Number", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
				New("UIStroke", { Color = T.Edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = q })
				UI.Tooltip(b, function()
					return "<b>" .. def.name .. "</b>\n" .. (def.desc or ""), color
				end)
			end
			b.Activated:Connect(function()
				choose(id)
			end)
		end
		-- auto drink threshold: drag the knob (steps of 5%), all the way left = off
		UI.Text(win.body, "Auto drink when " .. label, 14, T.Text, "Bold", { Position = UDim2.fromOffset(6, 136), Size = UDim2.new(0.62, 0, 0, 22), TextWrapped = false })
		local valueText = UI.Text(win.body, "", 14, T.Gold, "Bold", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 136), Size = UDim2.new(0.36, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
		local track = New("Frame", { BackgroundColor3 = T.PanelDeep, Position = UDim2.fromOffset(6, 168), Size = UDim2.new(1, -12, 0, 22), Active = true, Parent = win.body })
		UI.Corner(track, 8)
		UI.Stroke(track, T.Edge, 2)
		local fill = New("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = track })
		UI.Corner(fill, 8)
		for _, t in ipairs({ 0.25, 0.5, 0.75 }) do
			New("Frame", { BackgroundColor3 = T.Edge, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(t, -1, 0.2, 0), Size = UDim2.new(0, 2, 0.6, 0), Parent = track })
		end
		local knob = New("Frame", { BackgroundColor3 = T.Gold, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 32), ZIndex = 3, Parent = track })
		UI.Corner(knob, 4)
		UI.Stroke(knob, T.Edge, 2)
		local function show(v)
			fill.Size = UDim2.fromScale(v / 100, 1)
			knob.Position = UDim2.fromScale(v / 100, 0.5)
			valueText.Text = v > 0 and ("Below " .. v .. "%") or "Off"
		end
		show(pct)
		local dragging, value = false, pct
		local function setFrom(x)
			local k = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
			value = math.clamp(math.floor(k * 20 + 0.5) * 5, 0, 95)
			show(value)
		end
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFrom(input.Position.X)
			end
		end)
		local UIS = game:GetService("UserInputService")
		local moved = UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFrom(input.Position.X)
			end
		end)
		local ended = UIS.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				p.settings[kind .. "Pct"] = value
				State.Fire("profile")
				task.spawn(req, "SetAutoSettings", { [kind .. "Pct"] = value })
			end
		end)
		track.Destroying:Connect(function()
			moved:Disconnect()
			ended:Disconnect()
		end)
		UI.Text(win.body, "Drinks by itself in Auto Battle and in manual play. Auto = the smallest potion that fills the gap.", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(6, 200), Size = UDim2.new(1, -12, 0, 36) })
	end
	render()
end

-- ===================== MARKET (buyer) =====================
function Panels.Stall(args)
	local res = Net.Request("StallView", { sellerId = args.sellerId })
	if not res.ok then
		UI.Toast(res.msg or "This stall is closed", "bad")
		return
	end
	local data = res.data
	local win = UI.Window("Stall", data.title, UDim2.fromOffset(820, 600), T.Orange, "🏪")
	local pearlStall = data.currency == "pearls"
	local CUR = pearlStall and PearlsCfg.Icon or COIN
	local have = pearlStall and (State.profile.pearls or 0) or State.profile.beli
	UI.Text(win.body, "Seller: " .. data.seller .. "   •   You have " .. CUR .. " " .. UI.Format(have) .. (pearlStall and " tradable Gems" or ""), 16, T.TextSoft, "Semi")
	local grid = shopGrid(win.body, UDim2.new(1, 0, 1, -32))
	grid.Position = UDim2.fromOffset(0, 32)
	local items = {}
	for i, it in ipairs(data.items) do
		if it.qty > 0 and ItemDB.ForEntry(it) then
			it.i = i
			table.insert(items, it)
		end
	end
	byRarity(items, function(x)
		return ItemDB.Get(x.id)
	end)
	for order, it in ipairs(items) do
		shopCard(grid, { def = ItemDB.ForEntry(it), entry = it, order = order, qty = it.qty, price = CUR .. " " .. UI.Format(it.price), buttons = { { "BUY", have >= it.price and T.Green or T.Red, function()
			local r = req("StallBuy", { sellerId = args.sellerId, index = it.index, qty = 1 }, "Purchase")
			if r.ok then
				win:Destroy()
				Panels.Stall(args)
			end
		end } } })
	end
end

-- ===================== MARKET (seller) =====================
function Panels.StallSetup()
	local win = UI.Window("StallSetup", "Your Stall", UDim2.fromOffset(820, 620), T.Orange, "🏪")
	if State.stall and State.stall.open then
		-- v0.25.43 (owner): manage an open stall (also from its counter): your listed items first (REMOVE takes one
		-- back), then your bag (set a price, ADD lists it), CLOSE STALL at the bottom returns everything unsold
		local body = win.body
		local function alive()
			return win.frame.Parent ~= nil
		end
		local function render()
			if not alive() then
				return
			end
			local st = State.stall
			if not st or not st.open then
				win:Destroy()
				return
			end
			clear(body)
			local cur = st.currency == "pearls" and PearlsCfg.Icon or COIN
			local listed = 0
			for _, it in ipairs(st.items or {}) do
				if it.qty > 0 then
					listed += 1
				end
			end
			UI.Text(body, st.title, 22, T.Gold, "Display", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(0.55, 0, 0, 30) })
			UI.Text(body, listed .. " listed  •  ADD bag items to sell more", 14, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 10), Size = UDim2.new(0.45, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
			local grid = shopGrid(body, UDim2.new(1, 0, 1, -104))
			grid.Position = UDim2.fromOffset(0, 40)
			local order = 0
			for _, it in ipairs(st.items or {}) do
				local def = ItemDB.ForEntry(it)
				if it.qty > 0 and def then
					order += 1
					local card = shopCard(grid, { def = def, entry = it, order = order, qty = it.qty, price = cur .. " " .. UI.Format(it.price), buttons = { { "REMOVE", T.Red, function()
						req("StallRemove", { index = it.index })
					end } } })
					UI.Text(card, "ON SALE", 12, T.Green, "Display", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(80, 16), ZIndex = 5 })
				end
			end
			local p = State.profile
			local bag = {}
			for i, e in ipairs(p.inventory) do
				local def = ItemDB.ForEntry(e)
				if def and not equippedUid(e.uid) then
					table.insert(bag, { e = e, def = def, i = i })
				end
			end
			byRarity(bag, function(x)
				return x.def
			end)
			for _, b in ipairs(bag) do
				order += 1
				local box
				local _, bx = shopCard(grid, { def = b.def, entry = b.e, order = order, qty = b.e.qty or 1, priceBox = tostring(b.def.price or 100), buttons = { { "ADD", T.Green, function()
					req("StallAdd", { uid = b.e.uid, price = tonumber(box.Text) or 0, qty = b.e.qty or 1 })
				end } } })
				box = bx
			end
			local _, h = UI.Button(body, "CLOSE STALL", T.Red, UDim2.new(1, 0, 0, 52), function()
				req("StallClose")
				win:Destroy()
			end)
			h.Position = UDim2.new(0, 0, 1, -54)
		end
		render()
		local conn = State.Changed:Connect(function(k)
			if k == "stall" or k == "profile" then
				render()
			end
		end)
		win.frame.Destroying:Connect(function()
			conn:Disconnect()
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
				UI.Toast("Gem stalls: Lv." .. PearlsCfg.Trade.MinLevel .. "+, " .. math.floor(PearlsCfg.Trade.TaxRate * 100) .. "% tax, " .. math.floor(PearlsCfg.Trade.ListingFeeRate * 100) .. "% listing fee, items held " .. PearlsCfg.Trade.LockHours .. "h can't be listed", "info")
			end
		end, 36)
	end
	drawCurrency()
	-- v0.25.42 (owner): the same cards as the Shop: set a price on a card, Pick it, then OPEN STALL. The header row
	-- sits inside the body (it used to poke up into the title plaque)
	local title = New("TextBox", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(0.6, -8, 0, 40), PlaceholderText = "Stall name, e.g. Cheap Cards!", Text = "", FontFace = UI.Fonts.Bold, TextSize = 20, TextColor3 = T.Text, PlaceholderColor3 = T.TextSoft, BackgroundColor3 = T.PanelDeep, Parent = win.body })
	UI.Corner(title, 10)
	UI.Stroke(title, T.Edge, 2.5)
	curRow.Position = UDim2.new(0.6, 0, 0, 4)
	curRow.Size = UDim2.new(0.4, 0, 0, 44)
	local grid = shopGrid(win.body, UDim2.new(1, 0, 1, -118))
	grid.Position = UDim2.fromOffset(0, 54)
	local chosen = {}
	local p = State.profile
	local list = {}
	for i, e in ipairs(p.inventory) do
		local def = ItemDB.ForEntry(e)
		if def and not equippedUid(e.uid) then
			table.insert(list, { e = e, def = def, i = i })
		end
	end
	byRarity(list, function(x)
		return x.def
	end)
	for order, it in ipairs(list) do
		local e = it.e
		local pickBtn, price -- (set right below; the click comes later)
		local _, box, btns = shopCard(grid, { def = it.def, entry = e, order = order, qty = e.qty or 1, priceBox = tostring(it.def.price or 100), buttons = { { "PICK", T.Grey, function()
			local on = not chosen[e.uid]
			chosen[e.uid] = on and price or nil
			UI.SetButtonColor(pickBtn, on and T.Green or T.Grey)
			pickBtn.Text = on and "LISTED" or "PICK"
		end } } })
		pickBtn, price = btns[1], box
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
function Panels.Settings(args)
	if args and args.cat then
		settingsCategory = args.cat
	end
	local win = UI.Window("Settings", "Settings", UDim2.fromOffset(820, 600), T.Accent, "⚙️")
	local side = UI.Card(win.body, UDim2.new(0, 190, 1, 0), T.PanelDeep)
	UI.Pad(side, 8)
	UI.List(side, nil, 6)
	local list = UI.Scroll(win.body, UDim2.new(1, -204, 1, 0))
	list.Position = UDim2.fromOffset(204, 0)
	local cats = { { "Graphics", "🖥️" }, { "Audio", "🔊" }, { "Interface", "🪟" }, { "Hotkeys", "⌨️" } }
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
				-- quarter widths (v0.25.50: four 132 px buttons ran off a phone window, so only Low could be picked)
				UI.Button(row, q, v.quality == q and T.Green or T.Grey, UDim2.new(0.25, -6, 0, 46), function()
					Settings.Set("quality", q)
					render()
				end)
			end
			UI.Text(list, "Phones start on Low: pick any preset your device can run.\nLow: hides props, shadows and post effects\nMedium: hides small props\nHigh: everything on (PC)\nUltra: + depth of field, denser wind\nLow/Medium draw only the sea around you, High/Ultra also the next island.", 14, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 118) })
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
		elseif settingsCategory == "Hotkeys" then
			-- v0.25.44 (owner): rebind keys: tap a key cap, then press the new key (Esc cancels). Taking a key that is
			-- in use swaps the two actions
			local Hotkeys = require(script.Parent.Parent.Controllers.Hotkeys)
			local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 46), Parent = list })
			UI.Text(top, "Tap a key, then press the new one.", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, -200, 1, 0) })
			local _, rh = UI.Button(top, "Reset all", T.Red, UDim2.fromOffset(180, 40), function()
				Hotkeys.Reset()
				render()
			end)
			rh.AnchorPoint = Vector2.new(1, 0)
			rh.Position = UDim2.new(1, 0, 0, 2)
			-- two per row (plain frames: scale-sized grid cells do not show in the snapshot renderer)
			local row
			for i, a in ipairs(Hotkeys.Actions) do
				if i % 2 == 1 then
					row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 46), Parent = list })
				end
				local r = UI.Card(row, UDim2.new(0.5, -6, 1, 0), T.Panel)
				r.Position = UDim2.new(i % 2 == 1 and 0 or 0.5, i % 2 == 1 and 0 or 6, 0, 0)
				UI.Text(r, a[2], 16, T.Text, "Bold", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0) })
				local btn, h
				btn, h = UI.Button(r, Hotkeys.Label(a[1]), T.Gold, UDim2.fromOffset(88, 36), function()
					btn.Text = "..."
					UI.SetButtonColor(btn, T.Accent)
					local conn
					conn = UserInputService.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.Keyboard then
							return
						end
						conn:Disconnect()
						if input.KeyCode ~= Enum.KeyCode.Escape then
							if not Hotkeys.Set(a[1], input.KeyCode.Name) then
								UI.Toast(input.KeyCode.Name .. " can't be used", "bad")
							end
						end
						render()
					end)
				end)
				h.AnchorPoint = Vector2.new(1, 0.5)
				h.Position = UDim2.new(1, -6, 0.5, -2)
			end
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
			devGrid("Player", "🧪", T.Accent, { { "New Player", "resetall" }, { "Reset Lv1", "resetlevel" }, { "Lv70", "level" }, { "Job Lv.10", "joblevel" }, { "+1M " .. COIN, "beli" }, { "Materials", "items" }, { "New Weapons", "weapons" }, { "+1000 " .. PearlsCfg.Icon, "pearls" }, { "Next Quest", "questnext" } })
			-- heritages (and their variants) to test on this character (respawns with the new look)
			local LooksCfg = require(ReplicatedStorage.Shared.Config.Looks)
			local herButtons = {}
			for _, h in ipairs(LooksCfg.Heritages) do
				for vi, v in ipairs(h.variants or { { name = h.name } }) do
					table.insert(herButtons, { (#h.variants > 1) and v.name or h.name, "heritage", h.id .. ":" .. vi })
				end
			end
			devGrid("Race", "🧬", T.Orange, herButtons)
			local fruitButtons = {}
			for _, f in ipairs(FruitsCfg.List) do
				table.insert(fruitButtons, { f.icon .. " " .. f.id, "fruit", f.id })
			end
			table.insert(fruitButtons, { "+Mastery", "mastery" })
			table.insert(fruitButtons, { "Remove Fruit", "removefruit" })
			table.insert(fruitButtons, { "Spawn Tree Fruit", "spawnfruit" })
			devGrid("Cursed Fruits", "🍎", T.Pink, fruitButtons)
			devGrid("Role", "🏴", T.Red, { { "Four Tempests", "role", "FourTempests" }, { "Seven Privateers", "role", "SevenPrivateers" }, { "Remove Role", "role", "none" } })
			devGrid("Toki", "👑", T.Gold, { { "Conqueror Toki", "toki", "Conqueror" }, { "Remove Toki", "toki", "none" } })
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
			-- v0.25.28: dark slot tinted by the tile's color, colored rim, the icon glowing on an aura
			UI.Gradient(tile, T.PanelTop:Lerp(it[3], 0.45), T.PanelDeep:Lerp(it[3], 0.18), 90)
			UI.Stroke(tile, T.Edge, 3)
			UI.Bevel(tile, UI.Shade(it[3], 0.2), 2, 0.1)
			New("ImageLabel", { BackgroundTransparency = 1, Image = TexturesCfg.glow, ImageColor3 = UI.Shade(it[3], 0.3), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(120, 120), Parent = tile })
			UI.DressMenuTile(tile, it, 14)
			UI.Icon(tile, it[1], 88, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
			UI.Text(tile, string.upper(it[5]), 22, Color3.new(1, 1, 1), "Display", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
			if it[4] then
				local key = New("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = T.PanelDeep, Parent = tile })
				UI.Corner(key, 8)
				UI.Stroke(key, T.Edge, 2)
				UI.Text(key, require(script.Parent.Parent.Controllers.Hotkeys).Label(it[2]), 16, T.Gold, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
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

-- ===================== HUNTS (v0.25.18) =====================
-- repeatable "Defeat <monster> x40" for every island monster (Config/Hunts, ProgressService). Owner reference layout:
-- list on the left, the picked hunt on the right (monster, progress, reward cards, buttons).
local HuntsCfg = require(Shared.Config.Hunts)
local MonstersCfg = require(Shared.Config.Monsters)
local huntList -- { { id, def, pos } } sorted by level
local function hunts()
	if not huntList then
		huntList = {}
		local seen = {}
		for _, isl in ipairs(Islands.List) do
			for _, sp in ipairs(isl.spawns) do
				local def = MonstersCfg[sp.monster]
				if def and not seen[def.id] then
					seen[def.id] = true
					table.insert(huntList, { id = def.id, def = def, pos = Vector3.new(isl.x + sp.offset.X, 8, (isl.z or 0) + sp.offset.Y) })
				end
			end
		end
		table.sort(huntList, function(a, b2)
			return a.def.level < b2.def.level
		end)
	end
	return huntList
end
local huntPick
local function rewardCard(parent, icon, amount, label, color)
	local c = UI.Card(parent, UDim2.new(1 / 3, -6, 1, 0), color:Lerp(T.Panel, 0.55))
	local chip = UI.IconChip(c, icon, color, 44)
	chip.Position = UDim2.fromOffset(8, 8)
	UI.Text(c, amount, 17, T.Text, "Display", { Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -64, 0, 24), TextWrapped = false })
	UI.Text(c, label, 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(60, 32), Size = UDim2.new(1, -64, 0, 18), TextWrapped = false })
	return c
end
local function renderHunts(body, p, rerender, close)
	-- v0.25.101 (the buttons fell below the frame): measure the visible height in this frame's own units with a 100-px
	-- probe (UI.GetScale missed the full-screen window's UIScale)
	local probe = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 1), Parent = body })
	local okH, absH = pcall(function()
		local k = probe.AbsoluteSize.X / 100
		return k > 0 and body.AbsoluteSize.Y / k or nil
	end)
	probe:Destroy()
	local H = math.max(360, ((okH and absH and absH > 0) and absH or 520) - 8)
	local split = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, H), Parent = body })
	local left = UI.Scroll(split, UDim2.new(0.42, -6, 1, 0))
	UI.List(left, nil, 6)
	UI.Pad(left, 4)
	local right = UI.Card(split, UDim2.new(0.58, -6, 1, 0), T.Panel)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	local active = type(p.hunt) == "table" and p.hunt or nil
	local list = hunts()
	huntPick = huntPick or (active and active.id) or (list[1] and list[1].id)
	local picked
	for i, h in ipairs(list) do
		local need = math.max(1, h.def.level - HuntsCfg.LevelLead)
		local isActive = active and active.id == h.id
		local on = h.id == huntPick
		if on then
			picked = h
		end
		local row = UI.Card(left, UDim2.new(1, -8, 0, 64), on and T.Gold:Lerp(T.Panel, 0.55) or T.Panel)
		row.LayoutOrder = i
		if on then
			UI.Stroke(row, T.Gold, 3)
		end
		UI.Text(row, "[Repeat] Hunt " .. h.def.name, 15, T.Text, "Display", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.68, -12, 0, 22), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		local status = isActive and ((active.progress or 0) .. " / " .. HuntsCfg.Count) or (p.baseLevel >= need and "Available" or ("Lv." .. need))
		UI.Text(row, status, 13, isActive and T.Gold or (p.baseLevel >= need and T.Orange or T.TextSoft), "Display", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.new(0.32, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
		local bar = UI.Bar(row, T.Gold, UDim2.new(1, -24, 0, 12), "", 0)
		bar.back.Position = UDim2.fromOffset(12, 40)
		bar:Set(isActive and (active.progress or 0) / HuntsCfg.Count or 0)
		local hit = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = row.ZIndex + 5, Parent = row })
		hit.Activated:Connect(function()
			huntPick = h.id
			rerender()
		end)
	end
	if not picked then
		return
	end
	-- right: the picked hunt
	local def = picked.def
	local need = math.max(1, def.level - HuntsCfg.LevelLead)
	local isActive = active and active.id == picked.id
	local prog = isActive and (active.progress or 0) or 0
	UI.Pad(right, 14)
	UI.Text(right, "[Repeat] Hunt " .. def.name, 22, T.Text, "Display", { Size = UDim2.new(1, -170, 0, 30), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local req2 = New("Frame", { BackgroundColor3 = T.PanelDeep, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(160, 30), Parent = right })
	UI.Text(req2, "Requires Lv." .. need, 13, p.baseLevel >= need and T.Text or T.Red, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	local info = UI.Card(right, UDim2.new(1, 0, 0, 110), T.Ocean:Lerp(T.Panel, 0.7))
	info.Position = UDim2.fromOffset(0, 40)
	local portrait = UI.Card(info, UDim2.fromOffset(94, 94), T.Green:Lerp(T.Panel, 0.4))
	portrait.Position = UDim2.fromOffset(8, 8)
	if not (UI.ModelAsset("Monsters", def.id) and UI.ModelView(portrait, "Monsters", def.id, 90, 0.5, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })) then
		UI.Icon(portrait, "skull", 70, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	UI.Text(portrait, "Lv." .. def.level, 12, T.Text, "Display", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(60, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
	UI.Text(info, "Defeat " .. UI.Colored(def.name, T.Orange) .. " x" .. HuntsCfg.Count, 17, T.Text, "Display", { RichText = true, Position = UDim2.fromOffset(114, 18), Size = UDim2.new(1, -124, 0, 26), TextWrapped = false })
	local ty = def.mtype and require(Shared.Config.MonsterTypes)[def.mtype]
	UI.Text(info, (ty and (UI.Colored("[" .. ty.kanji .. "] " .. ty.name, ty.color) .. "   ") or "") .. UI.Colored(string.rep("★", def.stars or 1), T.Gold), 14, T.Text, "Display", { RichText = true, Position = UDim2.fromOffset(114, 46), Size = UDim2.new(1, -124, 0, 20), TextWrapped = false })
	UI.Text(info, "Defeat " .. HuntsCfg.Count .. " " .. def.name .. " • repeatable, no limit", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(114, 70), Size = UDim2.new(1, -124, 0, 36) })
	UI.Text(right, "Progress", 17, T.Text, "Display", { Position = UDim2.fromOffset(0, 166), Size = UDim2.fromOffset(140, 26) })
	local bar = UI.Bar(right, T.Gold, UDim2.new(1, -150, 0, 24), prog .. " / " .. HuntsCfg.Count, 0)
	bar.back.Position = UDim2.fromOffset(150, 167)
	bar:Set(prog / HuntsCfg.Count)
	UI.Text(right, "Rewards", 17, T.Text, "Display", { Position = UDim2.fromOffset(0, 208), Size = UDim2.fromOffset(200, 26) })
	local rewards = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 238), Size = UDim2.new(1, 0, 0, 64), Parent = right })
	UI.List(rewards, Enum.FillDirection.Horizontal, 8)
	local b = def.beli or { 0, 0 }
	rewardCard(rewards, "⭐", UI.Format(math.floor(def.exp * HuntsCfg.Count * HuntsCfg.ExpMult)), "EXP", T.Purple)
	rewardCard(rewards, "🪙", UI.Format(math.floor((b[1] + b[2]) / 2 * HuntsCfg.Count * HuntsCfg.BeliMult)), "Doubloons", T.Gold)
	local it = HuntsCfg.Items[1]
	local itDef = it and ItemDB.Get(it[1])
	if itDef then
		rewardCard(rewards, UI.ItemIconName(itDef) or "potion", "x" .. it[2], itDef.name, T.Green)
	end
	local btns = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 58), Parent = right })
	if isActive and prog >= HuntsCfg.Count then
		UI.Button(btns, "CLAIM REWARD", T.Green, UDim2.new(1, 0, 1, 0), function()
			if req("HuntClaim", nil, "RarityEpic").ok then
				rerender()
			end
		end)
	elseif isActive then
		New("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 1, 0), CellPadding = UDim2.fromOffset(10, 0), Parent = btns })
		UI.Button(btns, "Abandon Quest", T.Red, UDim2.new(1, 0, 1, 0), function()
			if req("HuntAbandon").ok then
				rerender()
			end
		end)
		UI.Button(btns, "Guide Me", T.Green, UDim2.new(1, 0, 1, 0), function()
			State.questTarget = picked.pos
			UI.Toast("Follow the yellow trail to the " .. def.name .. "s", "info")
			close()
		end)
	else
		UI.Button(btns, active and "Switch to this quest" or "Start this hunt", p.baseLevel >= need and T.Orange or T.Grey, UDim2.new(1, 0, 1, 0), function()
			if req("HuntStart", { id = picked.id }).ok then
				rerender()
			end
		end)
	end
end

function Panels.Quests(args)
	local win = UI.Window("Quests", "Quests", UDim2.fromOffset(880, 600), T.Gold, "📜", { fullscreen = true })
	local tab = args and args.tab or "Hunts"
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
		UI.TabBar(tabs, { { "Hunts", "⚔️", "Hunts", T.Orange }, { "Story", "📖", "Story", T.Gold }, { "Daily", "📅", "Daily", T.Green }, { "Ach", "🏆", "Achievements", T.Purple } }, tab, function(id)
			tab = id
			render()
		end, 40)
		UI.List(body, nil, 8)
		if tab == "Hunts" then
			renderHunts(body, p, render, function()
				UI.CloseWindow("Quests")
			end)
		elseif tab == "Daily" then
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
				local bar = UI.Bar(card, T.Green, UDim2.new(1, -250, 0, 16), e.progress .. " / " .. e.count, 0)
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
				UI.Text(card, state .. "  " .. ChartsView.Name(isl or islandId) .. (islandId == "Daybreak" and "  (tutorial)" or ""), 20, T.Text, "Display", { Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -32, 0, 24) })
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
	local render, empty
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
		if empty then
			empty:Destroy()
			empty = nil
		end
		if #pets == 0 then
			-- v0.25.101 (owner: the hint sat squeezed in one grid cell): a centred empty card over the grid area
			empty = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(0.6, -10, 1, -48), Parent = win.body })
			UI.List(empty, nil, 14, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
			local eggs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(240, 110), LayoutOrder = 1, Parent = empty })
			UI.List(eggs, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
			UI.VoxelEgg(eggs, "SeaEgg", 100)
			UI.VoxelEgg(eggs, "GoldenEgg", 100)
			UI.Text(empty, "NO COMPANIONS YET", 20, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2 })
			for i, line in ipairs({ { "egg", "Hatch eggs from chests or the Store" }, { "bait", "Buy Sea Bait at the General Store, bring a wild creature under 35% HP, then press Capture" } }) do
				local row = New("Frame", { BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.3, Size = UDim2.new(0.85, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 + i, Parent = empty })
				UI.Corner(row, 10)
				New("UIPadding", { PaddingLeft = UDim.new(0, 56), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = row })
				UI.Icon(row, line[1], 36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -46, 0.5, 0) }) -- (x is inside the 56 px padding)
				UI.Text(row, line[2], 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Center })
			end
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
			-- v0.25.101: each egg as its model + one row per companion, most likely first (emoji in the text drew boxes)
			for i, id in ipairs({ "SeaEgg", "GoldenEgg" }) do
				local egg = PetsCfg.Eggs[id]
				if egg then
					local card = New("Frame", { BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = right })
					UI.Corner(card, 10)
					New("UIPadding", { PaddingLeft = UDim.new(0, 96), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = card })
					UI.VoxelEgg(card, id, 80, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -90, 0.5, 0) })
					local col = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
					UI.List(col, nil, 3)
					UI.Text(col, egg.name, 16, Rarity.Get(egg.rarity).color, "Display", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0 })
					local list = {}
					for sid, w in pairs(egg.weights) do
						table.insert(list, { sid = sid, w = w })
					end
					table.sort(list, function(a, b)
						return a.w > b.w
					end)
					for k, it in ipairs(list) do
						local sp = PetsCfg.ById[it.sid]
						local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = k, Parent = col })
						UI.Text(r, sp and sp.stages[1] or it.sid, 14, sp and Rarity.Get(sp.rarity).color or T.Text, "Semi", { Size = UDim2.new(0.7, 0, 1, 0) })
						UI.Text(r, it.w .. "%", 14, T.Text, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.3, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
					end
				end
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
			New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = evo })
			for st = 1, 3 do
				local cell = New("Frame", { BackgroundColor3 = st == pet.stage and sp.color or T.Panel, BackgroundTransparency = st == pet.stage and 0.55 or 0.4, Size = UDim2.fromOffset(56, 56), LayoutOrder = st * 2, Parent = evo })
				UI.Corner(cell, 10)
				local vp = UI.ModelView(cell, "Pets", sp.id .. "_" .. st, 56, false)
				if vp and st > pet.stage then
					vp.ImageColor3 = Color3.fromRGB(40, 40, 60) -- not evolved yet: silhouette
				end
				if st < 3 then
					UI.Text(evo, ">", 18, T.TextSoft, "Display", { Size = UDim2.fromOffset(18, 56), LayoutOrder = st * 2 + 1, TextXAlignment = Enum.TextXAlignment.Center })
				end
			end
		end
		UI.Text(right, table.concat(sp.stages, "  >  "), 13, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center })
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

-- ===================== HATCH REVEAL (v0.25.12) =====================
-- One window for 1..10 eggs: each voxel egg wobbles, then pops into its companion (model or icon) in rarity color.
function Panels.HatchReveal(eggId, species)
	local n = #species
	if n == 0 then
		return
	end
	local cols = math.min(n, 5)
	local cell = 150
	local win = UI.Window("HatchReveal", n > 1 and ("Hatched x" .. n) or "Hatched!", UDim2.fromOffset(cols * (cell + 10) + 40, math.ceil(n / cols) * (cell + 40) + 120), T.Gold, "🥚")
	local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(cell, cell + 30), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	for i, id in ipairs(species) do
		local sp = PetsCfg.ById[id]
		local tier = Rarity.Get(sp and sp.rarity or "Common")
		local card = UI.Card(grid, nil, T.Panel)
		card.LayoutOrder = i
		local egg, tilt = UI.VoxelEgg(card, eggId, cell - 20, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
		local delay0 = 0.35 + (i - 1) * 0.22
		task.delay(delay0, function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.7 and egg.Parent do
				local k = (os.clock() - t0) / 0.7
				tilt(math.sin(k * 30) * 0.25 * k)
				task.wait()
			end
			if not card.Parent then
				return
			end
			egg:Destroy()
			card:FindFirstChild("CardGradient").Color = ColorSequence.new(tier.color:Lerp(Color3.new(1, 1, 1), 0.15), tier.color:Lerp(T.Panel, 0.5))
			local key = id .. "_1"
			if not (UI.ModelAsset("Pets", key) and UI.ModelView(card, "Pets", key, cell - 30, 0.8, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8) })) then
				UI.Icon(card, sp and sp.icon or "🥚", cell - 50, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18) })
			end
			UI.Text(card, sp and sp.stages[1] or id, 14, T.Text, "Display", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -6), Size = UDim2.new(1, -8, 0, 34), TextXAlignment = Enum.TextXAlignment.Center })
			Audio.Play(tier.rank >= 3 and ("Rarity" .. tier.id) or "BlkPouch")
		end)
	end
end

-- ===================== PEARL SHOP =====================
-- Store (v0.24.0): GEMS (the Gem shop + Robux Gem packs) | BENEFITS | BOOSTS (Config/Store). Every benefit and boost
-- costs Gems or Robux and can be bought FOR ME or as a GIFT for a player in this server.
local storeTab = "Gems"
local function buyFor(it, currency, after)
	local Players = game:GetService("Players")
	local me = Players.LocalPlayer
	local others = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= me then
			table.insert(others, pl)
		end
	end
	local function go(toUserId)
		local res
		if currency == "gems" then
			res = req("StoreBuyGems", { id = it.id, to = toUserId }, "Purchase")
		else
			res = req("StoreBuyRobux", { id = it.id, to = toUserId })
		end
		if after then
			after(res)
		end
	end
	-- the chooser: for me / gift to someone
	local win = UI.Window("StoreGift", it.name, UDim2.fromOffset(420, math.min(560, 200 + #others * 46)), T.Purple, it.icon or "🎁")
	local body = win.body
	UI.List(body, nil, 8, Enum.HorizontalAlignment.Center)
	local priceText = UI.Text(body, (currency == "gems" and (PearlsCfg.Icon .. " " .. it.gems) or ("R$ " .. it.robux)) .. "  -  who is it for?", 15, T.Gold, "Display", { TextXAlignment = Enum.TextXAlignment.Center })
	if currency ~= "gems" then
		Prices.Apply(it.productId, it.robux, function(r)
			priceText.Text = "R$ " .. r .. "  -  who is it for?"
		end)
	end
	UI.Button(body, "FOR ME", T.Green, UDim2.fromOffset(300, 44), function()
		UI.CloseWindow("StoreGift")
		go(nil)
	end)
	UI.Text(body, #others > 0 and "GIFT TO A PLAYER:" or "No one else is in this server to gift", 12, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center })
	local list = UI.Scroll(body, UDim2.new(1, 0, 0, math.min(320, #others * 46)))
	UI.List(list, nil, 6, Enum.HorizontalAlignment.Center)
	for _, pl in ipairs(others) do
		UI.Button(list, "🎁 " .. pl.DisplayName, T.Purple, UDim2.fromOffset(300, 40), function()
			UI.CloseWindow("StoreGift")
			go(pl.UserId)
		end)
	end
end

-- v0.25.9 (owner reference): big item cards on the left, a large preview + description + big BUY buttons on the
-- right, currency pill next to the tabs. One shape for every entry: { icon, name, desc, color, kind, ... }.
local storePick = nil -- the picked card (entry id), kept while the window is reopened
function Panels.PearlShop(args)
	if args and args.tab then
		storeTab = args.tab
	end
	local win = UI.Window("PearlShop", "Store", UDim2.fromOffset(820, 580), T.Ocean, "🛍️", { fullscreen = true })
	local body = win.body
	local StoreCfg = require(ReplicatedStorage.Shared.Config.Store)
	local TokiCfg = require(Shared.Config.Toki)
	-- v0.25.73 (owner reference: one long store): every category in ONE scroll, a section title above each; the tabs
	-- jump to their section and light up as you scroll past it. Picking a card only redraws the detail panel (the
	-- whole grid used to rebuild = the scroll jumped back to the top), and the card size follows the scroll's real
	-- width whenever it changes (it was measured once while the window was still opening = only 2 columns).
	local TABS = { { "Gems", "💎", "GEMS", T.Ocean }, { "Benefits", "🎟️", "BENEFITS", T.Purple }, { "Boosts", "⚡", "BOOSTS", T.Orange } }
	local render

	local info, d = { boosts = {}, tokens = {}, gems = 0 }, nil
	local function fetch()
		local res = Net.Request("StoreInfo")
		if res.ok then
			info = res.data
		end
		local pr = Net.Request("PearlInfo")
		if pr.ok then
			d = pr.data
		end
	end

	-- the sections, top to bottom: { tab, title, icon, color, entries }
	local function sections()
		local p = State.profile
		local packs, shop, benefits, boosts = {}, {}, {}, {}
		for i, prod in ipairs(d and d.products or {}) do
			local cfg = PearlsCfg.Products[i] or {}
			table.insert(packs, { kind = "pack", id = "pack" .. prod.productId, icon = cfg.icon or "💎", name = cfg.name or prod.name, sub = "Gems", desc = PearlsCfg.Icon .. " " .. prod.pearls .. " Gems. Robux Gems are shop-only (not tradable).", prod = prod, color = T.Ocean })
		end
		for _, it in ipairs(PearlsCfg.Shop) do
			table.insert(shop, { kind = "gemshop", id = it.id, icon = it.icon, name = it.name, sub = "Gem Shop", desc = it.desc, it = it, owned = it.once and d and d.perks and d.perks[it.perk], color = Color3.fromRGB(40, 170, 160),
				egg = it.item and PetsCfg.Eggs[it.item] and it.item })
		end
		for _, pair in ipairs({ { StoreCfg.Benefits, benefits, T.Purple, "Benefit" }, { StoreCfg.Boosts, boosts, T.Orange, "Boost" } }) do
			for _, it in ipairs(pair[1]) do
				local active = it.boost and info.boosts and (info.boosts[it.boost] or 0) > os.time()
				local owned = it.tokiColor and p and p.tokiColorPick and p.tokiColorPick[it.tokiColor]
				table.insert(pair[2], { kind = "store", id = it.id, icon = it.icon, name = it.name, sub = pair[4], desc = it.desc, it = it, color = pair[3], owned = owned,
					active = active and math.ceil(((info.boosts[it.boost] or 0) - os.time()) / 60), tokens = info.tokens and info.tokens[it.id] or 0 })
			end
		end
		return {
			{ tab = "Gems", title = "Gem Packs", icon = "💎", color = T.Ocean, list = packs },
			{ tab = "Gems", title = "Gem Shop", icon = "🥚", color = Color3.fromRGB(40, 170, 160), list = shop },
			{ tab = "Benefits", title = "Benefits", icon = "🎟️", color = T.Purple, list = benefits },
			{ tab = "Boosts", title = "Boosts", icon = "⚡", color = T.Orange, list = boosts },
		}
	end

	local function bigButton(parent, text, color, onClick)
		local btn = UI.Button(parent, text, color, UDim2.new(1, 0, 0, 46), onClick)
		UI.Shine(btn, math.random())
		return btn
	end

	local function detail(panel, e)
		clear(panel)
		UI.Pad(panel, 20) -- v0.25.101: inside the bevel ring
		UI.List(panel, nil, 10, Enum.HorizontalAlignment.Center)
		-- frameless stage (owner reference): the item floats in a soft color glow with twinkles (v0.25.41: no rays)
		-- v0.25.101 (owner: buttons + notes fell out of the frame): the stage takes whatever height is left (flex fill),
		-- everything under it keeps its own height, so the panel always fits
		local stage = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = panel })
		New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = stage })
		New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = e.color:Lerp(Color3.new(1, 1, 1), 0.35), ImageTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.15, 1.15), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = stage })
		UI.Sparkles(stage, Color3.new(1, 1, 1), 12, { star = 0.8 })
		if e.egg then
			UI.VoxelEgg(stage, e.egg, 150, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY })
		elseif not UI.VoxelIcon(stage, e.icon, 150, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.85, 0.85), SizeConstraint = Enum.SizeConstraint.RelativeYY }) then
			UI.Icon(stage, e.icon, 150, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.75, 0.75), SizeConstraint = Enum.SizeConstraint.RelativeYY })
		end
		UI.Text(panel, e.sub, 13, e.color:Lerp(Color3.new(1, 1, 1), 0.45), "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 16) })
		UI.Text(panel, e.name, 24, T.Text, "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 34) })
		local status = e.active and ("ACTIVE: " .. e.active .. " min left (buying adds time)") or (e.owned and "Owned") or nil
		UI.Text(panel, e.desc .. (status and ("\n" .. status) or ""), 14, status and T.Green or T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		if e.kind == "store" and e.it.tokiColor and e.owned then
			-- v0.25.73 (owner: "where do I change it again?"): bought once = change it here (or Stats -> palette)
			bigButton(panel, "CHANGE COLOR", T.Gold, function()
				Panels.TokiColor({ kind = e.it.tokiColor })
			end)
		elseif e.kind == "store" then
			local it = e.it
			bigButton(panel, "BUY  " .. PearlsCfg.Icon .. " " .. it.gems, T.Green, function()
				buyFor(it, "gems", function(r)
					if r and r.ok then
						render()
					end
				end)
			end)
			local onSale = it.productId and it.productId ~= 0
			local rb = bigButton(panel, "BUY  R$ " .. it.robux, onSale and T.Green or T.Grey, function()
				if not onSale then
					UI.Toast("Robux purchase coming soon (use Gems)", "info")
					return
				end
				buyFor(it, "robux")
			end)
			Prices.Apply(it.productId, it.robux, function(r)
				rb.Text = "BUY  R$ " .. r
			end)
			if e.tokens > 0 then
				bigButton(panel, "USE (" .. e.tokens .. ")", T.Gold, function()
					if req("StoreUseToken", { id = it.id }).ok then
						render()
					end
				end)
			end
		elseif e.kind == "gemshop" and e.it.bulk then
			-- v0.25.12 (owner): buy 1 / 10 / 30 at a time
			local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 66), Parent = panel })
			New("UIGridLayout", { CellSize = UDim2.new(1 / #e.it.bulk, -6, 0, 60), CellPadding = UDim2.fromOffset(8, 0), Parent = row })
			for _, q in ipairs(e.it.bulk) do
				UI.Button(row, "x" .. q .. "\n" .. PearlsCfg.Icon .. " " .. (e.it.price * q), q == 1 and T.Green or q == 10 and T.Orange or T.Purple, UDim2.new(1, 0, 1, 0), function()
					if req("PearlShopBuy", { id = e.it.id, qty = q }, "Purchase").ok then
						render()
					end
				end)
			end
		elseif e.kind == "gemshop" then
			bigButton(panel, e.owned and "OWNED" or ("BUY  " .. PearlsCfg.Icon .. " " .. e.it.price), e.owned and T.Grey or T.Green, function()
				if not e.owned and req("PearlShopBuy", { id = e.it.id }, "Purchase").ok then
					render()
				end
			end)
		else
			local onSale = e.prod.productId ~= 0
			local bb = bigButton(panel, onSale and "BUY" or "COMING SOON", onSale and T.Green or T.Grey, function()
				if onSale then
					req("PearlBuyProduct", { productId = e.prod.productId })
				else
					UI.Toast("Coming soon", "info")
				end
			end)
			if onSale then
				Prices.Apply(e.prod.productId, nil, function(r)
					if r then
						bb.Text = "BUY  R$ " .. r
					end
				end)
			end
		end
		if d and (e.kind == "pack" or e.kind == "gemshop") then
			UI.Text(panel, string.format("Tradable %s • Shop-only %s\nEarned today %d / %d", UI.Format(d.pearls), UI.Format(d.bound), d.earnedToday, d.cap)
				.. (d.canTrade and "" or ("\n🔒 " .. (d.tradeWhy or ""))), 12, T.TextSoft, "Semi", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		end
	end

	-- one card (reference style): a vivid gradient that darkens toward the bottom where the name sits, a bright rim,
	-- a glow + drifting particles behind the item, a moving shine; ACTIVE / OWNED badge in the corner
	local function card(parent, e, order)
		local c = e.color
		local f = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent })
		UI.Corner(f, 12)
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c:Lerp(Color3.new(1, 1, 1), 0.35)), ColorSequenceKeypoint.new(0.5, c), ColorSequenceKeypoint.new(1, c:Lerp(Color3.fromRGB(14, 10, 30), 0.65)) }), Parent = f })
		local rim = UI.Stroke(f, c:Lerp(Color3.new(1, 1, 1), 0.55), 3)
		New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.95, 0.95), SizeConstraint = Enum.SizeConstraint.RelativeXX, Parent = f })
		UI.Sparkles(f, Color3.new(1, 1, 1), 5, { star = 0.8, float = true })
		UI.Shine(f, order * 0.13)
		-- v0.25.101 (owner: the item sat high with an empty gap above the name): icon + name + sub + price are one
		-- centred column in the middle of the card
		local col = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -16), Parent = f })
		UI.List(col, nil, 2, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
		if e.egg then
			UI.VoxelEgg(col, e.egg, 90, { Size = UDim2.fromScale(0.66, 0.66), SizeConstraint = Enum.SizeConstraint.RelativeXX, LayoutOrder = 1 })
		else
			UI.Icon(col, e.icon, 90, { Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeXX, LayoutOrder = 1 })
		end
		New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 6), LayoutOrder = 2, Parent = col })
		UI.Text(col, e.name, 15, T.Text, "Display", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3 })
		UI.Text(col, e.sub, 11, Color3.new(1, 1, 1), "Semi", { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4 }).TextTransparency = 0.3
		local price = e.kind == "pack" and "R$" or e.kind == "gemshop" and (e.owned and "Owned" or (PearlsCfg.Icon .. " " .. e.it.price)) or (PearlsCfg.Icon .. " " .. e.it.gems)
		if e.kind == "store" and e.owned then
			price = "Owned" -- (no ✓ in the pixel font)
		end
		local priceLbl = UI.Text(col, e.active and "ACTIVE" or price, 14, (e.active or e.owned) and T.Green or T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 5 })
		if e.kind == "pack" and e.prod.productId ~= 0 then
			Prices.Apply(e.prod.productId, nil, function(r)
				if r and priceLbl.Parent then
					priceLbl.Text = "R$ " .. r
				end
			end)
		end
		return f, rim
	end

	local cards = {} -- id -> { frame, rim, color }
	local scroll, panel, tabRefs, sectionY
	local function highlight(id)
		for cid, ref in pairs(cards) do
			local on = cid == id
			ref.rim.Color = on and T.Gold or ref.color:Lerp(Color3.new(1, 1, 1), 0.55)
			ref.rim.Thickness = on and 5 or 3
		end
	end
	local function showTab(tab)
		for id, ref in pairs(tabRefs or {}) do
			ref.line.Visible = id == tab
			UI.SetButtonColor(ref.btn, id == tab and ref.color or T.Grey)
		end
	end

	render = function(refetch)
		if refetch ~= false then
			fetch()
		end
		if not win.frame.Parent then
			return
		end
		local keepY = scroll and scroll.CanvasPosition.Y or nil
		clear(body)
		cards = {}
		-- top: category tabs (jump to their section) + the Gems pill
		local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = body })
		local tabBar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 1, 0), Parent = top })
		UI.List(tabBar, Enum.FillDirection.Horizontal, 8)
		tabRefs = {}
		for i, t in ipairs(TABS) do
			local btn, h = UI.Button(tabBar, t[2] .. " " .. t[3], T.Grey, UDim2.fromOffset(170, 42), function()
				storeTab = t[1]
				showTab(t[1])
				local y = sectionY and sectionY[t[1]]
				if y and scroll then
					game:GetService("TweenService"):Create(scroll, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, y) }):Play()
				end
			end)
			h.LayoutOrder = i
			local line = New("Frame", { BackgroundColor3 = T.Gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.new(0.7, 0, 0, 4), Visible = false, ZIndex = btn.ZIndex + 2, Parent = h })
			tabRefs[t[1]] = { btn = btn, line = line, color = t[4] }
		end
		local pill = New("Frame", { BackgroundColor3 = T.OceanDark, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(190, 42), Parent = top })
		UI.Stroke(pill, T.Edge, 2.5)
		UI.Icon(pill, "💎", 34, { Position = UDim2.fromOffset(6, 4) })
		-- v0.25.63: the live "Pearls" attribute (set by the server the moment it spends)
		local gemsText = UI.Text(pill, "", 20, T.Text, "Display", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -52, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false })
		local function showGems()
			gemsText.Text = UI.Format(Players.LocalPlayer:GetAttribute("Pearls") or (d and (d.pearls + d.bound)) or info.gems or 0)
		end
		showGems()
		local gemConn = Players.LocalPlayer:GetAttributeChangedSignal("Pearls"):Connect(showGems)
		gemsText.Destroying:Connect(function()
			gemConn:Disconnect()
		end)
		-- left: every section in one scroll; right: the detail of the picked card
		local split = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 1, -60), Parent = body })
		scroll = UI.Scroll(split, UDim2.new(0.62, -8, 1, 0))
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
		panel = UI.Card(split, UDim2.new(0.38, 0, 1, 0), T.Panel)
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.fromScale(1, 0)
		local secs = sections()
		local blocks = {} -- { header, grid, layout, n }
		local pickedEntry
		for si, sec in ipairs(secs) do
			if #sec.list > 0 then
				local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 46), Parent = scroll })
				UI.Icon(header, sec.icon, 30, { Position = UDim2.fromOffset(4, 8) })
				UI.Text(header, sec.title, 24, T.Text, "Display", { Position = UDim2.fromOffset(42, 6), Size = UDim2.new(1, -50, 0, 32), TextYAlignment = Enum.TextYAlignment.Center })
				-- a glowing streak behind the title (reference)
				local streak = New("Frame", { BackgroundColor3 = sec.color, BorderSizePixel = 0, Position = UDim2.fromOffset(36, 34), Size = UDim2.new(0.6, 0, 0, 4), Parent = header })
				New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = streak })
				local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 10), Parent = scroll })
				local layout = New("UIGridLayout", { CellSize = UDim2.fromOffset(180, 220), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
				for i, e in ipairs(sec.list) do
					local f, rim = card(grid, e, si * 100 + i)
					cards[e.id] = { frame = f, rim = rim, color = e.color }
					f.Activated:Connect(function()
						storePick = e.id
						storeTab = sec.tab
						highlight(e.id)
						detail(panel, e)
					end)
					if e.id == storePick then
						pickedEntry = e
					end
				end
				table.insert(blocks, { tab = sec.tab, header = header, grid = grid, layout = layout, n = #sec.list })
			end
		end
		-- size every section from the scroll's real width (again whenever it changes). A 100-px probe tells how much the
		-- UIScales above (screen + full-screen window) magnify offsets
		local probe = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 1), Position = UDim2.fromOffset(0, -10), Parent = scroll })
		local function relayout()
			local W = 500
			pcall(function()
				local k = probe.AbsoluteSize.X / 100
				if k > 0 and scroll.AbsoluteSize.X > 0 then
					W = scroll.AbsoluteSize.X / k
				end
			end)
			W -= 24
			local perRow = math.max(2, math.floor((W + 10) / 190))
			local cellW = math.floor((W - (perRow - 1) * 10) / perRow)
			local cellH = math.floor(cellW * 1.2)
			local y = 0
			sectionY = {}
			for _, b in ipairs(blocks) do
				sectionY[b.tab] = sectionY[b.tab] or y
				b.header.Position = UDim2.fromOffset(4, y)
				y += 50
				local rows = math.ceil(b.n / perRow)
				b.layout.CellSize = UDim2.fromOffset(cellW, cellH)
				b.grid.Position = UDim2.fromOffset(4, y)
				b.grid.Size = UDim2.new(1, -12, 0, rows * (cellH + 10))
				y += rows * (cellH + 10) + 12
			end
			scroll.CanvasSize = UDim2.fromOffset(0, y + 20)
		end
		relayout()
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
		-- the tab of the section you are looking at lights up
		local function syncTab()
			local cy = scroll.CanvasPosition.Y + 30
			local cur = TABS[1][1]
			for _, t in ipairs(TABS) do
				if sectionY and sectionY[t[1]] and sectionY[t[1]] <= cy then
					cur = t[1]
				end
			end
			showTab(cur)
		end
		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(syncTab)
		if keepY then
			scroll.CanvasPosition = Vector2.new(0, keepY)
		elseif args and args.tab and sectionY[args.tab] then
			scroll.CanvasPosition = Vector2.new(0, sectionY[args.tab])
		end
		syncTab()
		pickedEntry = pickedEntry or (secs[1].list[1] or secs[3].list[1])
		if pickedEntry then
			highlight(pickedEntry.id)
			detail(panel, pickedEntry)
		end
	end
	render()
end

-- ===================== TOKI COLOR (v0.25.72, owner) =====================
-- Pick your own color for a Toki you have (color wheel + brightness + the Toki palette), once its Store unlock is bought
-- (p.tokiColorPick[kind]; Gems or Robux right here). Saved with "SetTokiColor"; the Roar FX and the Stats label use it.
local tokiColorKind
function Panels.TokiColor(args)
	local TokiCfg = require(Shared.Config.Toki)
	local UIImages = require(Shared.Config.UIImages)
	local UIS = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local win = UI.Window("TokiColor", "Toki Color", UDim2.fromOffset(640, 560), T.Gold, "👑")
	if args and args.kind then
		tokiColorKind = args.kind
	end
	local pending -- the color being tried (hex), before SAVE
	local hsv = { 0, 0, 1 }
	local conns = {}
	win.frame.Destroying:Connect(function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
	end)
	local render
	render = function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		table.clear(conns)
		clear(win.body)
		local p = State.profile
		if not p then
			return
		end
		local owned = {}
		for _, k in ipairs(TokiCfg.Kinds) do
			if type(p.toki) == "table" and p.toki[k.id] then
				table.insert(owned, { k.id, k.icon, k.name, TokiCfg.ColorOf(p.toki[k.id]) })
			end
		end
		if #owned == 0 then
			UI.Text(win.body, "You have no Toki yet. Conqueror Toki is born with 1 in 1000 characters; Armament and Observation come in the second sea.", 16, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 60) })
			return
		end
		local valid = false
		for _, o in ipairs(owned) do
			valid = valid or o[1] == tokiColorKind
		end
		if not valid then
			tokiColorKind = owned[1][1]
		end
		local kind = tokiColorKind
		UI.TabBar(win.body, owned, kind, function(id)
			tokiColorKind = id
			pending = nil
			render()
		end)
		local unlocked = p.tokiColorPick and p.tokiColorPick[kind]
		local current = p.toki[kind].color or TokiCfg.Colors[2]
		local shown = pending or current
		local col = TokiCfg.ColorOf({ color = shown })
		-- left: the preview
		local left = UI.Card(win.body, UDim2.new(0.38, -8, 1, -56), T.PanelDeep)
		left.Position = UDim2.fromOffset(0, 50)
		local sw = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = col, Parent = left })
		UI.Corner(sw, 18)
		UI.Stroke(sw, Color3.new(1, 1, 1), 4)
		UI.Icon(sw, "crown", 80, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		UI.Text(left, TokiCfg.ById[kind].name, 18, col:Lerp(Color3.new(1, 1, 1), 0.35), "Display", { Position = UDim2.fromOffset(10, 184), Size = UDim2.new(1, -20, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		UI.Text(left, shown .. (pending and "  (not saved)" or ""), 14, T.TextSoft, "Semi", { Position = UDim2.fromOffset(10, 212), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
		if unlocked then
			local _, sh = UI.Button(left, "SAVE", pending and T.Green or T.Grey, UDim2.new(1, -24, 0, 50), function()
				if pending then
					local res = req("SetTokiColor", { kind = kind, color = pending }, "Equip")
					if res.ok then
						pending = nil
					end
				end
			end)
			sh.AnchorPoint = Vector2.new(0.5, 1)
			sh.Position = UDim2.new(0.5, 0, 1, -12)
		else
			-- locked: buy the color choice here (same Store item)
			local it
			for _, e in ipairs(require(Shared.Config.Store).Benefits) do
				if e.tokiColor == kind then
					it = e
				end
			end
			UI.Text(left, "Random color. Unlock the color choice to pick your own, forever.", 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(12, 240), Size = UDim2.new(1, -24, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
			if it then
				local _, gh = UI.Button(left, PearlsCfg.Icon .. " " .. it.gems, T.Ocean, UDim2.new(1, -24, 0, 46), function()
					req("StoreBuyGems", { id = it.id }, "Purchase")
				end)
				gh.AnchorPoint = Vector2.new(0.5, 1)
				gh.Position = UDim2.new(0.5, 0, 1, -66)
				local rb, rh = UI.Button(left, "R$ " .. it.robux, T.Green, UDim2.new(1, -24, 0, 46), function()
					req("StoreBuyRobux", { id = it.id })
				end)
				rh.AnchorPoint = Vector2.new(0.5, 1)
				rh.Position = UDim2.new(0.5, 0, 1, -12)
				Prices.Apply(it.productId, it.robux, function(r)
					if rb.Parent then
						rb.Text = "R$ " .. r
					end
				end)
			end
		end
		-- right: wheel + brightness + the Toki palette
		local right = UI.Card(win.body, UDim2.new(0.62, 0, 1, -56), T.PanelDeep)
		right.Position = UDim2.new(0.38, 0, 0, 50)
		local wheel = New("ImageButton", { Image = UIImages.colorwheel or "", BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(220, 220), ImageTransparency = unlocked and 0 or 0.7, Parent = right })
		wheel:SetAttribute("PxKeep", true)
		local slider = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 246), Size = UDim2.fromOffset(240, 16), Parent = right })
		New("UIGradient", { Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(hsv[1], hsv[2], 1)), Parent = slider })
		local presets = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 276), Size = UDim2.new(1, -28, 0, 80), Parent = right })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(40, 34), CellPadding = UDim2.fromOffset(6, 6), Parent = presets })
		local function try(hex)
			if not unlocked then
				UI.Toast("Unlock the color choice first", "bad")
				return
			end
			pending = hex
			render()
		end
		for _, hex in ipairs(TokiCfg.Colors) do
			local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TokiCfg.ColorOf({ color = hex }), Parent = presets })
			UI.Stroke(b, hex == shown and Color3.new(1, 1, 1) or T.Edge, hex == shown and 3 or 2)
			UI.Tactile(b, true)
			b.Activated:Connect(function()
				try(hex)
			end)
		end
		local function screenPoint(input)
			return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		end
		local drag
		local function pick(input)
			if drag == "wheel" then
				local c = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
				local d = (screenPoint(input) - c) / (wheel.AbsoluteSize.X / 2)
				hsv[1] = (math.atan2(-d.Y, d.X) / (2 * math.pi)) % 1
				hsv[2] = math.min(1, d.Magnitude)
				if hsv[3] < 0.08 then
					hsv[3] = 1
				end
			elseif drag == "slider" then
				hsv[3] = math.clamp((screenPoint(input).X - slider.AbsolutePosition.X) / math.max(1, slider.AbsoluteSize.X), 0, 1)
			end
			pending = "#" .. Color3.fromHSV(hsv[1], hsv[2], hsv[3]):ToHex():upper()
		end
		for _, o in ipairs({ { wheel, "wheel" }, { slider, "slider" } }) do
			o[1].InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if not unlocked then
						UI.Toast("Unlock the color choice first", "bad")
						return
					end
					drag = o[2]
					pick(input)
				end
			end)
		end
		table.insert(conns, UIS.InputChanged:Connect(function(input)
			if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				pick(input)
				sw.BackgroundColor3 = TokiCfg.ColorOf({ color = pending })
			end
		end))
		table.insert(conns, UIS.InputEnded:Connect(function(input)
			if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				drag = nil
				render()
			end
		end))
		UI.Text(right, unlocked and "Drag on the wheel, set the brightness, or tap a swatch. Then SAVE." or "Locked: buy the color choice (left).", 13, T.TextSoft, "Semi", { Position = UDim2.new(0, 14, 1, -40), Size = UDim2.new(1, -28, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
	end
	render()
	onProfile(win, render)
end

-- ===================== INDEX (v0.25.127, owner: docs/Plan-Weapons-v2.md) =====================
-- Blade Ledger (every blade: stats, where it comes from, found yet) + Monsters + Bosses (how many you defeated).
-- p.index = { blades = { [id] = true }, kills = { [monsterId] = n } } (InventoryService / MonsterService).
local BLADE_LEDGER = {
	{ "Fathom", "Forty Fathoms", "General Store (Mystery Blade), monsters Lv.8+" },
	{ "Tide", "Twenty Tides", "Mystery Blade (rare), MVP bosses" },
	{ "Awakened", "Twenty Tides, Awakened", "Coming soon" },
}
local indexTab = "Blades"
local Types = require(Shared.Config.MonsterTypes)
function Panels.Index()
	local win = UI.Window("Index", "Index", UDim2.fromOffset(980, 600), T.Gold, "📖", { fullscreen = true })
	local body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	local render
	render = function()
		clear(body)
		local p = State.profile
		if not p then
			return
		end
		local ix = p.index or {}
		local kills = ix.kills or {}
		local have = {}
		for id in pairs(ix.blades or {}) do
			have[id] = true
		end
		for _, e in ipairs(p.inventory or {}) do
			have[e.id] = true -- blades owned before the Index existed
		end
		UI.TabBar(body, { { "Blades", "⚔️", "Blades" }, { "Monsters", "💀", "Monsters" }, { "Bosses", "👑", "Bosses" } }, indexTab, function(t)
			indexTab = t
			render()
		end)
		local sc = UI.Scroll(body, UDim2.new(1, 0, 1, -50))
		sc.Position = UDim2.fromOffset(0, 50)
		UI.List(sc, nil, 10)
		New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = sc })
		local order = 0
		local function section(title, sub, count)
			order += 1
			local head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = sc })
			UI.Text(head, title, 20, T.Gold, "Display", { Size = UDim2.new(1, -140, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Text(head, sub, 13, T.TextSoft, "Semi", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -140, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Text(head, count, 16, T.Text, "Number", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(140, 22), TextXAlignment = Enum.TextXAlignment.Right })
			order += 1
			local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = sc })
			New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 196), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
			return grid
		end
		local function cell(grid, i, rarity, lit)
			local c = New("Frame", { BackgroundColor3 = T.PanelDeep, LayoutOrder = i, Parent = grid })
			UI.Corner(c, 10)
			if lit and rarity then
				UI.RarityStyle(c, rarity)
			else
				UI.Stroke(c, T.Edge, 2)
			end
			return c
		end
		local function line(c, y, text, size, color, kind)
			return UI.Text(c, text, size, color, kind or "Semi", { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, size + 6), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		end
		if indexTab == "Blades" then
			for _, tier in ipairs(BLADE_LEDGER) do
				local ids = ItemDB.Blades[tier[1]] or {}
				local n = 0
				for _, id in ipairs(ids) do
					n += have[id] and 1 or 0
				end
				local grid = section(tier[2], tier[3], n .. " / " .. #ids)
				for i, id in ipairs(ids) do
					local def = ItemDB.Get(id)
					local got = have[id]
					local c = cell(grid, i, def.rarity, got)
					-- v0.25.128 (owner): each blade's own block model; not found yet = a black silhouette, no stats
					UI.WeaponView(c, def, 96, false, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ImageColor3 = got and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), ZIndex = 4 })
					local nm = line(c, 96, got and def.name or "???", 14, T.Text)
					if got then
						UI.RarityText(nm, def.rarity)
						line(c, 118, "ATK " .. def.atk .. "  " .. (def.typeLabel or "Sword"), 12, T.TextSoft)
						line(c, 136, def.dex and ("DEX +" .. def.dex .. " LUK +" .. (def.luk or 0)) or ("STR +" .. (def.str or 0) .. " VIT +" .. (def.vit or 0)), 12, T.TextSoft)
					end
					line(c, 166, got and "FOUND" or "NOT FOUND", 13, got and T.Green or T.TextSoft, "Display")
				end
			end
		else
			local bosses = indexTab == "Bosses"
			for _, isl in ipairs(Islands.List) do
				local ids = {}
				if bosses then
					if isl.boss then
						table.insert(ids, isl.boss.id)
					end
				else
					for _, sp in ipairs(isl.spawns or {}) do
						if not table.find(ids, sp.monster) then
							table.insert(ids, sp.monster)
						end
					end
				end
				local defs = {}
				for _, id in ipairs(ids) do
					local d = MonstersCfg[id]
					if d then
						table.insert(defs, d)
					end
				end
				if #defs > 0 then
					local n = 0
					for _, d in ipairs(defs) do
						n += (kills[d.id] or 0) > 0 and 1 or 0
					end
					local lv = isl.levels and ("Lv." .. isl.levels[1] .. "-" .. isl.levels[2]) or ""
					local grid = section(ChartsView.Name(isl), lv, n .. " / " .. #defs)
					for i, d in ipairs(defs) do
						local k = kills[d.id] or 0
						local c = cell(grid, i, bosses and "Epic" or "Common", k > 0)
						if k > 0 then
							UI.MonsterView(c, d.id, 96, false, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), ZIndex = 4 })
						else
							line(c, 26, "?", 44, T.TextSoft, "Display")
						end
						line(c, 100, k > 0 and d.name or "???", 14, T.Text)
						local ty = Types[d.mtype or ""]
						local tl = line(c, 122, "Lv." .. d.level .. (ty and ("  " .. d.mtype) or ""), 12, ty and ty.color or T.TextSoft)
						tl.TextColor3 = ty and ty.color or T.TextSoft
						line(c, 144, string.rep("★", d.stars or 1), 12, T.Gold)
						line(c, 166, k > 0 and ("Defeated " .. UI.Format(k)) or "Not met yet", 12, k > 0 and T.Green or T.TextSoft, "Display")
					end
				end
			end
		end
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
