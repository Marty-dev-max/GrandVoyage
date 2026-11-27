-- Talents UI (remake R3): the Talents window (T) with tabs TALENTS (cards you hold + the waiting pick) and MASTERY
-- (the 5 Field Mastery tracks, their perks and how to train them), and the pick screen (3 cards, keep 1).
-- Server: TalentService (TalentState / TalentPick, push "Talents"), MasteryService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local TalentsCfg = require(Shared.Config.Talents)
local MasteryCfg = require(Shared.Config.Mastery)
local Rarity = require(Shared.Modules.Rarity)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.UIKit)
local Audio = require(script.Parent.Parent.Controllers.Audio)

local TL = {}
local T = UI.Theme
local New = UI.New

TL.state = nil -- last TalentState / "Talents" push
local tab = "Talents"
local redraw = {} -- window id -> render fn (re-run on a push while open)

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function fetch()
	local res = Net.Request("TalentState")
	if res.ok and res.data then
		TL.state = res.data
	end
	return TL.state
end

local function rarityColor(r)
	return Rarity.Get(r).color
end

-- one talent card: w x h frame with rarity rim, icon, name, rarity, effect, requirement
local function card(parent, t, w, h, order, big)
	local c = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.fromOffset(w, h), LayoutOrder = order or 0, Parent = parent })
	UI.Corner(c, 10)
	UI.RarityStyle(c, t.rarity)
	local col = rarityColor(t.rarity)
	local inner = New("Frame", { BackgroundColor3 = T.PanelDeep, BackgroundTransparency = 0.08, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 3, Parent = c })
	UI.Corner(inner, 8)
	New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 5), ZIndex = 4, Parent = inner })
	local isz = big and 72 or 44
	UI.Icon(inner, t.icon, isz, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, big and 16 or 10), ZIndex = 5 })
	local y = (big and 16 or 10) + isz + 6
	UI.Text(inner, string.upper(t.name), big and 18 or 13, col, "Display", { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, big and 24 or 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	y += big and 26 or 19
	UI.Text(inner, string.upper(t.rarity), big and 11 or 9, T.TextSoft, "Display", { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	y += big and 22 or 17
	UI.Text(inner, t.text, big and 17 or 13, T.Green, "Semi", { Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, big and 48 or 34), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 5 })
	if big then
		UI.Text(inner, "Needs: " .. TalentsCfg.NeedText(t), 12, T.TextSoft, "Semi", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -66), Size = UDim2.new(1, -16, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 5 })
	end
	return c, inner
end

-- ===================== PICK (3 cards, keep 1) =====================
function TL.Pick()
	local st = fetch()
	local win = UI.Window("TalentPick", "Pick a Talent", UDim2.fromOffset(900, 470), T.Purple, "skills")
	local body = win.body
	local function render()
		clear(body)
		st = TL.state
		if not st then
			return
		end
		local picks = st.picks or 0
		UI.Text(body, picks > 1 and ("Keep one card. " .. picks .. " picks waiting.") or "Keep one card. It stays with you for good.", 16, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		if picks <= 0 then
			UI.Text(body, "No pick waiting. You get one every level.", 18, T.Text, "Semi", { Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		if not st.offer or #st.offer == 0 then
			UI.Text(body, "No card unlocked for you yet. Raise an attribute or a Field Mastery, then come back.", 18, T.Text, "Semi", { Position = UDim2.fromOffset(40, 120), Size = UDim2.new(1, -80, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
			return
		end
		local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), Parent = body })
		UI.List(row, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center)
		for i, id in ipairs(st.offer) do
			local t = TalentsCfg.ById[id]
			if t then
				local _, inner = card(row, t, 260, 360, i, true)
				local btn, holder = UI.Button(inner, "PICK", rarityColor(t.rarity), UDim2.fromOffset(150, 46), function()
					local res = Net.Request("TalentPick", { id = id })
					if res.msg then
						UI.Toast(res.msg, res.ok and "good" or "bad")
					end
					if res.ok then
						Audio.Play("BlkLevelUp")
						TL.state = res.data or TL.state
						if (TL.state.picks or 0) > 0 and TL.state.offer then
							render()
						else
							UI.CloseWindow("TalentPick")
						end
						if redraw.Talents then
							redraw.Talents()
						end
					end
				end)
				local _ = btn
				holder.AnchorPoint = Vector2.new(0.5, 1)
				holder.Position = UDim2.new(0.5, 0, 1, -14)
				holder.ZIndex = 6
			end
		end
	end
	redraw.TalentPick = render
	render()
end

-- ===================== WINDOW (Talents / Mastery) =====================
local function renderTalents(body, st)
	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = body })
	local picks = st.picks or 0
	UI.Text(top, picks > 0 and (picks .. " pick" .. (picks > 1 and "s" or "") .. " waiting") or "You get a pick every level", 18, picks > 0 and T.Gold or T.TextSoft, "Display", { Position = UDim2.fromOffset(4, 14), Size = UDim2.new(1, -230, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
	if picks > 0 then
		local _, holder = UI.Button(top, "PICK A CARD", T.Purple, UDim2.fromOffset(210, 46), function()
			TL.Pick()
		end)
		holder.AnchorPoint = Vector2.new(1, 0)
		holder.Position = UDim2.new(1, -4, 0, 4)
	end
	local sc = UI.Scroll(body, UDim2.new(1, 0, 1, -62))
	sc.Position = UDim2.fromOffset(0, 62)
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = sc })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(196, 176), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
	local list = st.talents or {}
	if #list == 0 then
		UI.Text(sc, "No talents yet.", 16, T.TextSoft, "Semi", { Size = UDim2.fromOffset(300, 30) })
	end
	for i, id in ipairs(list) do
		local t = TalentsCfg.ById[id]
		if t then
			card(sc, t, 196, 176, i, false)
		end
	end
end

local function renderMastery(body, st)
	local sc = UI.Scroll(body, UDim2.new(1, 0, 1, 0))
	UI.List(sc, nil, 10)
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = sc })
	local m = st.mastery or {}
	for i, id in ipairs(MasteryCfg.Order) do
		local f = MasteryCfg.Fields[id]
		local e = m[id] or { lv = 1, xp = 0, next = MasteryCfg.ToNext(1) }
		local row = New("Frame", { BackgroundColor3 = T.PanelDeep, Size = UDim2.new(1, 0, 0, 132), LayoutOrder = i, Parent = sc })
		UI.Corner(row, 10)
		UI.Stroke(row, f.color:Lerp(T.Edge, 0.4), 2)
		UI.Icon(row, f.icon, 64, { Position = UDim2.fromOffset(12, 14) })
		UI.Text(row, string.upper(f.name), 18, f.color, "Display", { Position = UDim2.fromOffset(90, 10), Size = UDim2.fromOffset(260, 24), TextXAlignment = Enum.TextXAlignment.Left })
		local maxed = e.lv >= MasteryCfg.Max
		UI.Text(row, "Lv." .. e.lv .. " / " .. MasteryCfg.Max, 16, T.Text, "Number", { Position = UDim2.fromOffset(90, 36), Size = UDim2.fromOffset(160, 20), TextXAlignment = Enum.TextXAlignment.Left })
		local bar = UI.Bar(row, f.color, UDim2.fromOffset(240, 16), nil, 0)
		bar.back.Position = UDim2.fromOffset(90, 60)
		local ratio = maxed and 1 or math.clamp((e.xp or 0) / math.max(1, e.next or 1), 0, 1)
		pcall(function()
			bar:Set(ratio, maxed and "MAX" or ((e.xp or 0) .. " / " .. (e.next or 0)))
		end)
		UI.Text(row, f.how, 12, T.TextSoft, "Semi", { Position = UDim2.fromOffset(90, 82), Size = UDim2.fromOffset(260, 40), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
		-- perks: three chips, lit once reached
		local perks = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 360, 0, 10), Size = UDim2.new(1, -370, 1, -20), Parent = row })
		UI.List(perks, Enum.FillDirection.Horizontal, 8)
		for j, perk in ipairs(f.perks) do
			local on = e.lv >= perk.lv and not perk.soon
			local chip = New("Frame", { BackgroundColor3 = on and f.color:Lerp(T.PanelDeep, 0.55) or T.PanelDeep:Lerp(Color3.new(0, 0, 0), 0.3), Size = UDim2.new(1 / #f.perks, -6, 1, 0), LayoutOrder = j, Parent = perks })
			UI.Corner(chip, 8)
			UI.Stroke(chip, on and f.color or T.Edge, 2)
			-- Mastery v2: perks of later plan phases say SOON (docs/Plan-Mastery-v2.md)
			UI.Text(chip, "LV " .. perk.lv .. (perk.soon and "  SOON" or ""), 12, on and T.Gold or (perk.soon and T.Orange or T.TextSoft), "Display", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Text(chip, perk.name, 14, on and T.Text or T.TextSoft, "Display", { Position = UDim2.fromOffset(6, 26), Size = UDim2.new(1, -12, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Text(chip, perk.text, 12, on and T.Green or T.TextSoft, "Semi", { Position = UDim2.fromOffset(6, 50), Size = UDim2.new(1, -12, 1, -56), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })
		end
	end
end

function TL.Open()
	local st = fetch()
	local win = UI.Window("Talents", "Talents", UDim2.fromOffset(1000, 620), T.Purple, "skills")
	local body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	local function render()
		clear(body)
		st = TL.state
		if not st then
			UI.Text(body, "Loading...", 16, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 30) })
			return
		end
		UI.TabBar(body, { { "Talents", "🃏", "Talents" }, { "Mastery", "🔨", "Mastery" } }, tab, function(t)
			tab = t
			render()
		end)
		local inner = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), Parent = body })
		if tab == "Mastery" then
			renderMastery(inner, st)
		else
			renderTalents(inner, st)
		end
	end
	redraw.Talents = render
	render()
end

Net.OnPush("Talents", function(d)
	TL.state = d
	for id, fn in pairs(redraw) do
		if UI.IsOpen(id) then
			pcall(fn)
		end
	end
end)

return TL
