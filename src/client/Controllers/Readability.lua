-- Readability helpers (Hunting-Together style "easy to read" play):
--  * range ring under the player (attack range, or the hovered skill's range)
--  * target ring under the selected enemy, "!" over enemies targeting you
--  * enemy nameplates colored by level difference (green easy -> red deadly)
--  * compass strip with markers + screen-edge arrows (next island, live bosses, hostile ships)
--  * dotted navigation line + distance to the next island while sailing
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Monsters = require(Shared.Config.Monsters)
local ClassesCfg = require(Shared.Config.Classes)
local Rarity = require(Shared.Modules.Rarity)
local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Settings)
local UI = require(script.Parent.Parent.UI.UIKit)

local R = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New
R.HoverSkill = nil

local fx = Instance.new("Folder")
fx.Name = "ReadabilityFX"
fx.Parent = workspace

-- ===== world rings =====
local function makeRing(radius, color, thickness, segments, transparency, dashed, noFill)
	local m = Instance.new("Model")
	m.Name = "Ring"
	local center = Instance.new("Part")
	center.Anchored = true
	center.CanCollide = false
	center.CanQuery = false
	center.Transparency = 1
	center.Size = Vector3.one
	center.Parent = m
	m.PrimaryPart = center
	segments = segments or 40
	local arc = 2 * math.pi * radius / segments
	for i = 0, segments - 1, (dashed and 2 or 1) do
		local a = (i + 0.5) / segments * math.pi * 2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transparency or 0.25
		p.Size = Vector3.new(thickness or 0.35, 0.12, arc * 0.72)
		p.CFrame = CFrame.Angles(0, -a, 0) * CFrame.new(radius, 0, 0)
		p.Parent = m
	end
	if noFill then
		m.Parent = fx
		return m
	end
	local fill = Instance.new("Part")
	fill.Shape = Enum.PartType.Cylinder
	fill.Anchored = true
	fill.CanCollide = false
	fill.CanQuery = false
	fill.CastShadow = false
	fill.Material = Enum.Material.Neon
	fill.Color = color
	fill.Transparency = 0.9
	fill.Size = Vector3.new(0.08, radius * 2, radius * 2)
	fill.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	fill.Parent = m
	m.Parent = fx
	return m
end

local rings = {}
-- search ring is big and thin: no fill (it would tint the whole field), lighter dashes
local RING_STYLE = { search = { transparency = 0.45, noFill = true } }
local function ring(key, radius, color, thickness)
	radius = math.max(2, math.floor(radius + 0.5))
	local r = rings[key]
	if r and (r.radius ~= radius or r.color ~= color) then
		r.model:Destroy()
		r = nil
	end
	if not r then
		local style = RING_STYLE[key] or {}
		r = { model = makeRing(radius, color, thickness, math.max(24, math.floor(radius * (style.noFill and 1.1 or 2.2))), style.transparency, key == "player" or key == "search", style.noFill), radius = radius, color = color }
		rings[key] = r
	end
	return r.model
end
local function hideRing(key)
	if rings[key] then
		rings[key].model:PivotTo(CFrame.new(0, -500, 0))
	end
end

local function groundY(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos, Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or pos.Y - 3
end

local function weaponRange()
	return require(game:GetService("ReplicatedStorage").Shared.Modules.WeaponInfo).ClientRange(State.profile)
end

-- ===== nameplates / aggro =====
local aggroMarks = {}
local function updateMobs()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Monsters")
	if not root or not folder then
		return
	end
	local myLevel = player:GetAttribute("Level") or 1
	-- Declutter: a crowd of crabs used to stack their names into an unreadable pile. Show a nameplate only for
	-- bosses, the target, monsters attacking you, hurt monsters and the 3 nearest within 40 studs.
	local near = {}
	for _, m in ipairs(folder:GetChildren()) do
		local pp = m.PrimaryPart
		if pp then
			local d = (pp.Position - root.Position).Magnitude
			if d < 40 then
				table.insert(near, { m = m, d = d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local nearest = {}
	for i = 1, math.min(3, #near) do
		nearest[near[i].m] = true
	end
	local plateScale = UI.GetScale() < 0.8 and 0.72 or 1
	for _, m in ipairs(folder:GetChildren()) do
		local pp = m.PrimaryPart
		local plate0 = pp and pp:FindFirstChild("Nameplate")
		if plate0 then
			local hurt = (m:GetAttribute("HP") or 1) < (m:GetAttribute("MaxHP") or 1)
			plate0.Enabled = m:GetAttribute("Boss") == true or m == State.target or m:GetAttribute("TargetId") == player.UserId or hurt or nearest[m] == true
			local base = plate0:GetAttribute("BaseSize")
			if not base then
				base = Vector2.new(plate0.Size.X.Offset, plate0.Size.Y.Offset)
				plate0:SetAttribute("BaseSize", base)
			end
			plate0.Size = UDim2.fromOffset(base.X * plateScale, base.Y * plateScale)
		end
		if pp and (pp.Position - root.Position).Magnitude < 180 then
			local plate = pp:FindFirstChild("Nameplate")
			local lvl = m:GetAttribute("Level") or 1
			local col = Rarity.LevelColor(myLevel, lvl)
			if plate then
				local title = plate:FindFirstChild("Title")
				local sub = plate:FindFirstChild("Subtitle")
				if title and not m:GetAttribute("Boss") then
					title.TextColor3 = col
				end
				if sub then
					sub.TextColor3 = col
					local d = lvl - myLevel
					sub.Text = "Lv." .. lvl .. (d >= 9 and "  ☠" or (d >= 4 and "  !" or ""))
				end
			end
			local targetingMe = m:GetAttribute("TargetId") == player.UserId
			local mark = aggroMarks[m]
			if targetingMe and not mark then
				mark = New("BillboardGui", { Name = "Aggro", Size = UDim2.fromOffset(40, 50), StudsOffsetWorldSpace = Vector3.new(0, 6 + (Monsters[m:GetAttribute("MonsterId") or ""] and Monsters[m:GetAttribute("MonsterId")].style.scale or 1) * 3, 0), AlwaysOnTop = true, Adornee = pp, Parent = fx })
				UI.Text(mark, "!", 44, T.Red, "Display", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
				UI.Pop(mark:FindFirstChildOfClass("TextLabel"), 0.3)
				aggroMarks[m] = mark
			elseif not targetingMe and mark then
				mark:Destroy()
				aggroMarks[m] = nil
			end
		end
	end
	for m, mark in pairs(aggroMarks) do
		if not m.Parent then
			mark:Destroy()
			aggroMarks[m] = nil
		end
	end
end

-- ===== compass / arrows / nav =====
local compass, compassMarks, navLabel, arrowHolder
local markerPool = {}
local arrows = {}

local function nextIsland(fromX)
	local p = State.profile
	local best
	-- R5: west of Daybreak (an Origin island) the way on is Daybreak itself
	local start = Islands.Route[1]
	if fromX < start.x - start.radius then
		return start
	end
	for _, isl in ipairs(Islands.Route) do
		if isl.x > fromX + 150 then
			if not best then
				best = isl
			end
			if p and not p.unlocked[isl.id] then
				return isl
			end
		end
	end
	return best
end

-- v0.25.2 (owner, phone): keep the compass between the MENU button (left) and the currency row (right); on narrow
-- screens it covered both. Measured in screen pixels, converted to the root's UIScale units.
local function fitCompass()
	if not compass then
		return
	end
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	local menuGui = pg and pg:FindFirstChild("MenuButton")
	local menuBtn = menuGui and menuGui.Enabled and menuGui:FindFirstChildWhichIsA("GuiObject")
	local cur = UI.Root:FindFirstChild("CurrencyRow")
	local scaleObj = UI.Root:FindFirstChildOfClass("UIScale")
	local sc = scaleObj and scaleObj.Scale or 1
	local left = menuBtn and (menuBtn.AbsolutePosition.X + menuBtn.AbsoluteSize.X + 10) or 0
	local right = cur and (cur.AbsolutePosition.X - 10) or workspace.CurrentCamera.ViewportSize.X
	local want = 440 * sc
	local room = right - left
	if room >= want and left < workspace.CurrentCamera.ViewportSize.X / 2 - want / 2 then
		compass.Position = UDim2.new(0.5, 0, 0, 14)
		compass.Size = UDim2.fromOffset(440, 28)
	else
		local w = math.max(160 * sc, math.min(want, room))
		compass.Size = UDim2.fromOffset(w / sc, 28)
		compass.Position = UDim2.fromOffset((left + room / 2) / sc, 14)
	end
end

local function buildCompass()
	-- slim, see-through compass (it used to be a heavy dark bar with little on it)
	compass = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(440, 28), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ClipsDescendants = true, Parent = UI.Root })
	UI.Corner(compass, 20)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = compass })
	New("UIGradient", { Name = "Fade", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 0.6) }), Parent = compass }).Enabled = false
	UI.Stroke(compass, T.Edge, 2.5)
	compassMarks = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = compass })
	local tick = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(3, 10), BackgroundColor3 = T.Gold, Parent = compass })
	UI.Corner(tick, 2)
	navLabel = UI.Text(UI.Root, "", 16, T.Gold, "Bold", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(520, 20), TextXAlignment = Enum.TextXAlignment.Center })
	arrowHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = UI.Root })
end

local function compassMark(i, text, color)
	local m = markerPool[i]
	if not m then
		m = UI.Text(compassMarks, "", 15, T.Text, "Display", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 22), TextXAlignment = Enum.TextXAlignment.Center })
		markerPool[i] = m
	end
	m.Text = text
	m.TextColor3 = color
	m.Visible = true
	return m
end

local function arrow(i, text, color)
	local a = arrows[i]
	if not a then
		a = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.new(1, 1, 1), Parent = arrowHolder })
		UI.Corner(a, 23)
		New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = a })
		a:SetAttribute("x", 0)
		local st = UI.Stroke(a, color, 3)
		st.Name = "Ring"
		local lbl = UI.Text(a, "", 22, T.Text, "Display", { Name = "Icon", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local pointer = UI.Text(a, "▲", 18, color, "Display", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20), TextXAlignment = Enum.TextXAlignment.Center })
		arrows[i] = a
		local _ = lbl
		local _2 = pointer
	end
	a.Icon.Text = text
	a.Ring.Color = color
	a.Pointer.TextColor3 = color
	a.Visible = true
	return a
end

local navDots = {}
local function navDot(i)
	local d = navDots[i]
	if not d then
		d = Instance.new("Part")
		d.Shape = Enum.PartType.Cylinder
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CastShadow = false
		d.Material = Enum.Material.Neon
		d.Color = Color3.fromRGB(255, 220, 90)
		d.Size = Vector3.new(0.3, 3.2, 3.2)
		d.Parent = fx
		navDots[i] = d
	end
	return d
end

local function myShip()
	local ships = workspace:FindFirstChild("Ships")
	return ships and ships:FindFirstChild("Ship_" .. player.UserId)
end

local lastFit = 0
local function updateNav()
	if os.clock() - lastFit > 0.5 then
		lastFit = os.clock()
		pcall(fitCompass)
	end
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, m in pairs(markerPool) do
		m.Visible = false
	end
	for _, a in pairs(arrows) do
		a.Visible = false
	end
	if not root then
		return
	end
	local look = cam.CFrame.LookVector
	local heading = math.atan2(look.X, -look.Z) -- 0 = north (-Z)
	local pos = root.Position
	local marks = {}
	-- cardinal letters (east = toward the Crimson Wall)
	for _, c in ipairs({ { "N", 0 }, { "E", math.pi / 2 }, { "S", math.pi }, { "W", -math.pi / 2 } }) do
		table.insert(marks, { text = c[1], color = c[1] == "E" and T.Gold or T.TextSoft, angle = c[2] })
	end
	local targets = {}
	local nxt = nextIsland(pos.X)
	if nxt then
		local tp = Vector3.new(nxt.x - nxt.radius - 60, 0, 0)
		table.insert(targets, { pos = tp, text = "🏝", color = T.Gold, label = nxt.name })
	else
		table.insert(targets, { pos = Vector3.new(Islands.RedLine.x, 0, 0), text = "⛰", color = T.Purple, label = Islands.RedLine.name })
	end
	if State.questTarget then
		table.insert(targets, 1, { pos = State.questTarget, text = "📜", color = T.Green, label = State.questLabel })
	end
	local board = State.bossBoard
	if board then
		for _, b in ipairs(board.list) do
			if b.alive then
				for _, isl in ipairs(Islands.List) do
					if isl.name == b.island and isl.boss then
						table.insert(targets, { pos = Vector3.new(isl.x + isl.boss.offset.X, 0, (isl.z or 0) + isl.boss.offset.Y), text = "☠", color = T.Red, label = b.name })
					end
				end
			end
		end
	end
	local ships = workspace:FindFirstChild("Ships")
	if ships then
		for _, s in ipairs(ships:GetChildren()) do
			if s.PrimaryPart and s ~= myShip() and (s:GetAttribute("NPC") or s:GetAttribute("OwnerId")) then
				local d = (s.PrimaryPart.Position - pos).Magnitude
				if d < 700 then
					table.insert(targets, { pos = s.PrimaryPart.Position, text = "⛵", color = s:GetAttribute("Faction") == "Marine" and T.Marine or T.Pirate })
				end
			end
		end
	end
	for _, t in ipairs(targets) do
		local dir = t.pos - pos
		table.insert(marks, { text = t.text, color = t.color, angle = math.atan2(dir.X, -dir.Z) })
	end
	for i, mk in ipairs(marks) do
		local rel = (mk.angle - heading + math.pi) % (2 * math.pi) - math.pi
		if math.abs(rel) < math.pi / 2 then
			local m = compassMark(i, mk.text, mk.color)
			m.Position = UDim2.new(0.5 + rel / math.pi, 0, 0.5, 0)
		end
	end
	-- screen-edge arrows for off-screen targets
	local vp = cam.ViewportSize
	local scale = UI.Root:FindFirstChildOfClass("UIScale").Scale
	local ai = 0
	for _, t in ipairs(targets) do
		local sp, onScreen = cam:WorldToViewportPoint(t.pos + Vector3.new(0, 10, 0))
		if not onScreen then
			ai += 1
			local dir = Vector2.new(sp.X - vp.X / 2, sp.Y - vp.Y / 2)
			if sp.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, -1)
			end
			dir = dir.Unit
			-- keep arrows inside the play area: below the player card / pills, above the skill bar, clear of the menu
			local l, r = 230 * scale, vp.X - 230 * scale
			local t, b = 330 * scale, vp.Y - 150 * scale
			local c = Vector2.new((l + r) / 2, (t + b) / 2)
			local half = Vector2.new((r - l) / 2, (b - t) / 2)
			local k = math.min(math.abs(half.X / dir.X), math.abs(half.Y / dir.Y))
			local p = c + dir * k
			local a = arrow(ai, t.text, t.color)
			a.Position = UDim2.fromOffset(p.X / scale, p.Y / scale)
			a.Pointer.Position = UDim2.new(0.5, dir.X * 30, 0.5, dir.Y * 30)
			a.Pointer.Rotation = math.deg(math.atan2(dir.X, -dir.Y))
		end
	end
	-- quest beacon: a tall soft light column at the objective, visible from far away
	if State.questTarget and (State.questTarget - pos).Magnitude > 18 then
		if not R.beacon then
			R.beacon = Instance.new("Part")
			R.beacon.Name = "QuestBeacon"
			R.beacon.Anchored = true
			R.beacon.CanCollide = false
			R.beacon.CanQuery = false
			R.beacon.CastShadow = false
			R.beacon.Material = Enum.Material.Neon
			R.beacon.Color = Color3.fromRGB(120, 255, 160)
			R.beacon.Transparency = 0.6
			R.beacon.Shape = Enum.PartType.Cylinder
			R.beacon.Size = Vector3.new(120, 2.2, 2.2)
			R.beacon.Parent = fx
		end
		R.beacon.CFrame = CFrame.new(State.questTarget + Vector3.new(0, 58, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		R.beacon.Transparency = 0.55 + math.sin(os.clock() * 3) * 0.1
	elseif R.beacon then
		R.beacon.CFrame = CFrame.new(0, -500, 0)
	end
	-- nav line while sailing
	local ship = myShip()
	local showNav = Settings.Values.navGuide and nxt and ship and ship.PrimaryPart
	local count = 0
	if showNav then
		local from = ship.PrimaryPart.Position
		local to = Vector3.new(nxt.x - nxt.radius - 60, 0, 0)
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local dist = dir.Magnitude
		navLabel.Text = "🏝 " .. nxt.name .. "  •  " .. UI.Format(dist) .. " m  •  Lv." .. nxt.levels[1] .. "+"
		dir = dist > 0 and dir.Unit or Vector3.zero
		local phase = (os.clock() * 18) % 22
		for i = 1, 14 do
			local d = 30 + (i - 1) * 22 + phase
			if d < dist then
				count = i
				local p = from + dir * d
				local dot = navDot(i)
				dot.CFrame = CFrame.new(p.X, 0.45, p.Z) * CFrame.Angles(0, 0, math.pi / 2)
				dot.Transparency = 0.15 + i / 18
			end
		end
	else
		navLabel.Text = ""
	end
	for i = count + 1, #navDots do
		navDots[i].CFrame = CFrame.new(0, -500, 0)
	end
end

-- NPC nameplates are fixed-pixel in the baked map, so far-away ones piled up into one unreadable label.
-- Resize them in studs (they shrink with distance) and fade them out sooner.
local function fixNpcPlate(m)
	local plate = m.PrimaryPart and m.PrimaryPart:FindFirstChild("Nameplate")
	if plate and plate:IsA("BillboardGui") then
		plate.Size = UDim2.new(11, 0, 3, 0)
		plate.MaxDistance = 120
	end
end

function R.Start()
	local CollectionService = game:GetService("CollectionService")
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		fixNpcPlate(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(fixNpcPlate)
	buildCompass()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- player range ring
		if root and hum and Settings.Values.rangeRings and not State.build.active then
			local skill = R.HoverSkill and ClassesCfg.SkillById[R.HoverSkill]
			local radius, color = weaponRange(), Color3.fromRGB(255, 255, 255)
			if skill then
				radius = (skill.kind == "AoE" or skill.kind == "PartyHeal" or skill.kind == "PartyBuff") and (skill.radius or 10) or (skill.range or 10)
				color = Color3.fromRGB(255, 210, 80)
			end
			-- v0.25.139 (owner): manual mode shows no white reach ring (only the yellow one while aiming a skill)
			local show = skill ~= nil or State.auto
			if show then
				local y = root.Position.Y - hum.HipHeight - root.Size.Y / 2 + 0.15
				ring("player", radius, color):PivotTo(CFrame.new(root.Position.X, y, root.Position.Z) * CFrame.Angles(0, os.clock() * 0.4, 0))
				-- outer ring: how far Auto Battle looks for the next monster (manual mode has no search: hidden)
				if State.auto then
					ring("search", State.SearchRadius(), Color3.fromRGB(110, 235, 140), 0.7):PivotTo(CFrame.new(root.Position.X, y + 0.05, root.Position.Z) * CFrame.Angles(0, -os.clock() * 0.15, 0))
				else
					hideRing("search")
				end
			else
				hideRing("player")
				hideRing("search")
			end
		else
			hideRing("player")
			hideRing("search")
		end
		-- target ring
		local tgt = State.target
		if tgt and tgt.Parent and tgt.PrimaryPart and State.auto then -- v0.25.139: no red target ring in manual
			local pp = tgt.PrimaryPart
			local mon = Monsters[tgt:GetAttribute("MonsterId") or ""]
			local radius = 3 + (mon and mon.style.scale or 1) * 2
			local y = groundY(pp.Position, { tgt, fx, char })
			local pulse = 1 + math.sin(os.clock() * 6) * 0.06
			ring("target", radius, Color3.fromRGB(255, 70, 80), 0.5):PivotTo(CFrame.new(pp.Position.X, y + 0.2, pp.Position.Z) * CFrame.Angles(0, -os.clock(), 0))
			rings.target.model:ScaleTo(pulse)
		else
			hideRing("target")
		end
		acc += dt
		if acc > 0.25 then
			acc = 0
			pcall(updateMobs)
		end
		pcall(updateNav)
	end)
end

return R
