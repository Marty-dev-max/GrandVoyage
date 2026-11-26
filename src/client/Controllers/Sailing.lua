-- Sailing (client): sail levels + steering, ship HUD, cannon aim arcs + aim circle, wind streaks that
-- show where you can sail, zone banners, ocean ambience and music switching.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService") -- InputObject.Position excludes the top-bar inset; ViewportPointToRay needs it
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)
local ShipParts = require(Shared.Config.ShipParts).Parts
local ShipHull = require(Shared.Modules.ShipHull)
local SeaZones = require(Shared.Modules.SeaZones)
local Net = require(Shared.Modules.Net)
local UI = require(script.Parent.Parent.UI.UIKit)
local Audio = require(script.Parent.Audio)
local Settings = require(script.Parent.Settings)
local Atmos = require(script.Parent.Atmos)
local State = require(script.Parent.Parent.State)

local Sailing = {}
local player = Players.LocalPlayer
local T = UI.Theme
local New = UI.New
local sailLevel = 0 -- -1 reverse, 0 stop, 1-3 sails
local lastThrottleInput = 0
local hud, aimMarker
local lastZone
local windFolder = Instance.new("Folder")
windFolder.Name = "WindFX"
windFolder.Parent = workspace

local function myShip()
	local ships = workspace:FindFirstChild("Ships")
	return ships and ships:FindFirstChild("Ship_" .. player.UserId)
end

local function seated(ship)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local seat = ship and ship:FindFirstChild("HelmSeat", true)
	return seat and h and seat.Occupant == h
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function aboard(ship)
	local r = root()
	local sr = ship and ship.PrimaryPart
	if not r or not sr then
		return false
	end
	return (Vector2.new(r.Position.X, r.Position.Z) - Vector2.new(sr.Position.X, sr.Position.Z)).Magnitude < sr.Size.Magnitude / 2 + 4
end

-- ===== HUD =====
local zoneInfo = {
	Lane = { text = "🌬️ SAILING LANE  •  strong wind", color = T.Ocean },
	Edge = { text = "⚠️ LANE EDGE  •  wind fading", color = T.Orange },
	CalmBelt = { text = "☠️ " .. string.upper(Islands.CalmName) .. "  •  NO WIND! LEVIATHANS!", color = T.Red },
	RedLine = { text = "⛰️ " .. string.upper(Islands.RedLine.name), color = T.Purple },
}

-- v0.25.113 (owner: the panel hid behind the character card, too much small text): a compact card ABOVE the character
-- card: name + HP, four big readouts (speed / wind / sails / guns), the zone chip, the reload bar, four buttons
local function buildHud()
	local f = New("Frame", { Name = "ShipHUD", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -192), Size = UDim2.fromOffset(340, 262), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = UI.Root })
	UI.Corner(f, 14)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 3)
	UI.Pad(f, 10)
	UI.List(f, nil, 6)
	local name = UI.Text(f, "Ship", 18, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 22), TextWrapped = false, LayoutOrder = 1 })
	local hp = UI.Bar(f, T.Green, UDim2.new(1, 0, 0, 20), "HP")
	hp.back.LayoutOrder = 2
	local stats = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 3, Parent = f })
	UI.List(stats, Enum.FillDirection.Horizontal, 4)
	local function cell(label, order)
		local c = New("Frame", { Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = T.PanelDeep, LayoutOrder = order, Parent = stats })
		UI.Corner(c, 6)
		UI.Stroke(c, T.Edge, 2)
		UI.Text(c, label, 10, T.TextSoft, "Display", { Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
		return UI.Text(c, "-", 17, T.Text, "Display", { Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	end
	local speedT, windT, sailT, gunT = cell("SPEED", 1), cell("WIND", 2), cell("SAILS", 3), cell("GUNS", 4)
	local zone = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Ocean, LayoutOrder = 4, Parent = f })
	UI.Corner(zone, 6)
	UI.Stroke(zone, T.Edge, 2)
	local zoneText = UI.Text(zone, "", 14, T.Text, "Bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local reload = UI.Bar(f, T.Orange, UDim2.new(1, 0, 0, 18), "READY")
	reload.back.LayoutOrder = 5
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 6, Parent = f })
	UI.List(row, Enum.FillDirection.Horizontal, 4)
	local function btn(text, color, w, order, fn)
		local _, holder = UI.Button(row, text, color, UDim2.fromOffset(w, 40), fn)
		holder.LayoutOrder = order
	end
	btn("SAIL -", T.OceanDark, 74, 1, function()
		sailLevel = math.max(-1, sailLevel - 1)
	end)
	btn("SAIL +", T.Ocean, 74, 2, function()
		sailLevel = math.min(3, sailLevel + 1)
	end)
	btn("🔥 FIRE", T.Red, 80, 3, function()
		Sailing.FireAtNearest()
	end)
	btn("⚓ DOCK", T.Green, 80, 4, function()
		local res = Net.Request("DockShip")
		UI.Toast(res.msg or (res.ok and "Docked" or "Cannot dock"), res.ok and "good" or "bad") -- v0.25.117 (owner): no bell
	end)
	-- v0.25.155 (Plan-Ships-v2 phase 3): special weapons (R), powder kegs (X), the lamps switch
	local row2 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 7, Parent = f })
	UI.List(row2, Enum.FillDirection.Horizontal, 4)
	local function btn2(text, color, w, order, fn)
		local b, holder = UI.Button(row2, text, color, UDim2.fromOffset(w, 34), fn)
		holder.LayoutOrder = order
		return b, holder
	end
	local specialB, specialH = btn2("R: HARPOON", T.Purple, 110, 1, function()
		Sailing.FireAtNearest("FireSpecial")
	end)
	local kegB, kegH = btn2("X: KEG", T.Orange, 100, 2, function()
		Sailing.DropKeg()
	end)
	local lightB = btn2("LAMPS AUTO", T.Gold, 106, 3, function()
		local ship = myShip()
		if ship then
			local nextMode = ({ auto = "on", on = "off", off = "auto" })[ship:GetAttribute("Lights") or "auto"]
			task.spawn(Net.Request, "ShipLights", { mode = nextMode })
		end
	end)
	hud = { frame = f, name = name, hp = hp, zone = zone, zoneText = zoneText, speedT = speedT, windT = windT, sailT = sailT, gunT = gunT, reload = reload,
		specialB = specialB, specialH = specialH, kegB = kegB, kegH = kegH, lightB = lightB }
end

-- v0.25.155 (#21): the TEST SAIL panel above the ship card: wind and time of day to try, then back to the builder
local testHud
local function buildTestHud()
	local f = New("Frame", { Name = "TestSailHUD", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -462), Size = UDim2.fromOffset(340, 132), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = UI.Root })
	UI.Corner(f, 12)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 3)
	UI.Pad(f, 8)
	UI.List(f, nil, 5)
	UI.Text(f, "TEST SAIL  -  nothing is paid, no damage", 12, T.Gold, "Display", { Size = UDim2.new(1, 0, 0, 14), TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 })
	local wind = 1
	local windRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = f })
	UI.List(windRow, Enum.FillDirection.Horizontal, 4).VerticalAlignment = Enum.VerticalAlignment.Center
	local windT
	local function setWind(w)
		wind = math.clamp(w, 0, 1.5)
		windT.Text = "WIND " .. math.floor(wind * 100 + 0.5) .. "%"
		task.spawn(Net.Request, "ShipTestWind", { wind = wind })
	end
	local _, h1 = UI.Button(windRow, "-", T.OceanDark, UDim2.fromOffset(44, 28), function()
		setWind(wind - 0.25)
	end)
	h1.LayoutOrder = 1
	windT = UI.Text(windRow, "WIND 100%", 14, T.Text, "Display", { Size = UDim2.fromOffset(150, 28), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 2 })
	local _, h2 = UI.Button(windRow, "+", T.Ocean, UDim2.fromOffset(44, 28), function()
		setWind(wind + 0.25)
	end)
	h2.LayoutOrder = 3
	local timeRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = f })
	UI.List(timeRow, Enum.FillDirection.Horizontal, 4)
	for i, c in ipairs({ { "DAY", 13 }, { "DUSK", 18.3 }, { "NIGHT", 23 }, { "LIVE", false } }) do
		local _, h = UI.Button(timeRow, c[1], T.Gold, UDim2.fromOffset(77, 28), function()
			Atmos.SetClock(c[2] or nil)
		end)
		h.LayoutOrder = i
	end
	local _, hb = UI.Button(f, "BACK TO SHIPYARD", T.Green, UDim2.new(1, 0, 0, 32), function()
		Atmos.SetClock(nil)
		local res = Net.Request("TestSailEnd")
		if not res.ok and res.msg then
			UI.Toast(res.msg, "bad")
		end
	end)
	hb.LayoutOrder = 4
	testHud = { frame = f, reset = function()
		wind = 1
		windT.Text = "WIND 100%"
	end }
end

local function sailText()
	if sailLevel < 0 then
		return "REVERSE"
	elseif sailLevel == 0 then
		return "furled"
	end
	return sailLevel .. "/3" -- (the pixel font has no block glyphs)
end

local wasVisible = false
local function updateHud(ship)
	if not hud then
		return
	end
	local show = ship ~= nil and aboard(ship)
	hud.frame.Visible = show
	local testing = ship ~= nil and ship:GetAttribute("Test") == true
	if testHud then
		if testing and not testHud.frame.Visible then
			testHud.reset()
		end
		testHud.frame.Visible = testing
	end
	if show and not wasVisible then
		UI.Pop(hud.frame, 0.7)
	end
	wasVisible = show
	if not show then
		return
	end
	local hp, max = ship:GetAttribute("HP") or 0, ship:GetAttribute("MaxHP") or 1
	hud.name.Text = (ship:GetAttribute("Test") and "TEST: " or "") .. (ship:GetAttribute("ShipName") or "Ship")
	local flood = ship:GetAttribute("Flood") or 0
	hud.hp:Set(hp / max, UI.Format(hp) .. " / " .. UI.Format(max) .. (flood >= 1 and "  LEAKING" or ""))
	-- v0.25.155: special weapons / kegs / lamps
	local specials = ship:GetAttribute("Specials") or 0
	hud.specialH.Visible = specials > 0
	if specials > 0 then
		local left = (ship:GetAttribute("SpecialEnd") or 0) - workspace:GetServerTimeNow()
		hud.specialB.Text = left > 0 and string.format("R: %.1fs", left) or "R: HARPOON"
	end
	local kegs = ship:GetAttribute("Kegs")
	hud.kegH.Visible = kegs ~= nil
	if kegs then
		hud.kegB.Text = "X: KEG " .. kegs
	end
	hud.lightB.Text = "LAMPS " .. string.upper(ship:GetAttribute("Lights") or "auto")
	hud.hp:SetColor(hp / max < 0.3 and T.Red or T.Green)
	local z = zoneInfo[ship:GetAttribute("Zone") or "Lane"] or zoneInfo.Lane
	hud.zoneText.Text = z.text
	hud.zone.BackgroundColor3 = z.color
	local wind = math.floor((ship:GetAttribute("Wind") or 1) * 100)
	hud.speedT.Text = tostring(ship:GetAttribute("Speed") or 0)
	hud.windT.Text = wind .. "%"
	hud.sailT.Text = sailLevel < 0 and "BACK" or (sailLevel == 0 and "OFF" or sailText())
	hud.gunT.Text = (ship:GetAttribute("Manned") or 0) .. "/" .. (ship:GetAttribute("Cannons") or 0)
	local left = (ship:GetAttribute("ReloadEnd") or 0) - workspace:GetServerTimeNow()
	if left > 0 then
		hud.reload:Set(math.clamp(1 - left / GameConfig.Ship.ReloadTime, 0, 1), string.format("RELOADING %.1fs", left))
	else
		hud.reload:Set(1, "READY  •  F / click water")
	end
end

-- ===== cannon fire =====
local function waterPoint(screenPos)
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	if math.abs(ray.Direction.Y) < 1e-3 then
		return nil
	end
	local t = (GameConfig.SeaLevel - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function fire(target)
	task.spawn(function()
		local res = Net.Request("FireCannons", { target = target })
		if not res.ok and res.msg and not res.throttled then
			UI.Toast(res.msg, "bad")
		end
	end)
end

-- what = "FireCannons" (F) or "FireSpecial" (R: harpoon guns / fire pots, v0.25.155)
function Sailing.FireAtNearest(what)
	local ship = myShip()
	if not ship or not ship.PrimaryPart then
		return
	end
	if not seated(ship) then
		UI.Toast("Take the helm to fire the cannons", "info")
		return
	end
	local fire = function(target)
		task.spawn(function()
			local res = Net.Request(what or "FireCannons", { target = target })
			if not res.ok and res.msg and not res.throttled then
				UI.Toast(res.msg, "bad")
			end
		end)
	end
	local best, bestD = nil, 280
	local pos = ship.PrimaryPart.Position
	for _, s in ipairs(workspace.Ships:GetChildren()) do
		if s ~= ship and s.PrimaryPart then
			local d = (s.PrimaryPart.Position - pos).Magnitude
			if d < bestD then
				best, bestD = s.PrimaryPart.Position + s.PrimaryPart.AssemblyLinearVelocity * (d / GameConfig.Ship.CannonballSpeed), d
			end
		end
	end
	local mobs = workspace:FindFirstChild("Monsters")
	if mobs then
		for _, m in ipairs(mobs:GetChildren()) do
			if m.PrimaryPart and m:GetAttribute("MonsterId") == "Leviathan" then
				local d = (m.PrimaryPart.Position - pos).Magnitude
				if d < bestD then
					best, bestD = m.PrimaryPart.Position, d
				end
			end
		end
	end
	if best then
		fire(Vector3.new(best.X, 0, best.Z))
	elseif aimMarker and aimMarker.Transparency < 1 then
		fire(aimMarker.Position)
	end
end

function Sailing.DropKeg()
	task.spawn(function()
		local res = Net.Request("DropKeg")
		if not res.ok and res.msg and not res.throttled then
			UI.Toast(res.msg, "bad")
		end
	end)
end

-- ===== cannon aim preview (v0.25.53, owner reference: broadside lines out of the ship's side, a bow gun's line
-- straight ahead, both dropping like the real ball) =====
-- The same cannons the server would fire (Ship volley: facing within ~75 deg of the target, best aligned first,
-- as many as are manned). One gun = one arc; more = the two outermost guns' arcs, parallel (the server fires a
-- player's broadside in parallel lanes). Arc = the ball's flight: sin curve, height clamp(dist * 0.12, 6, 40).
local aimFolder = Instance.new("Folder")
aimFolder.Name = "CannonAim"
local aimPool = {}
local AIM_STEPS = 18
local function aimSeg(i)
	local p = aimPool[i]
	if not p then
		p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Transparency = 0.3
		aimPool[i] = p
	end
	p.Parent = aimFolder
	return p
end
local function cannonsOf(ship)
	local list = {}
	for _, child in ipairs(ship:GetChildren()) do
		local def = ShipParts[child.Name]
		if def and def.cannon and not def.cannon.special and child.PrimaryPart then
			local barrel = child:FindFirstChild("Barrel", true)
			local muzzle = barrel and barrel:FindFirstChild("Muzzle")
			local arcs = child:GetAttribute("Arcs")
			table.insert(list, {
				pos = muzzle and muzzle.WorldPosition or child.PrimaryPart.Position,
				face = child.PrimaryPart.CFrame.LookVector,
				range = child:GetAttribute("Range") or def.cannon.range,
				fire = arcs and ShipHull.ArcParse(arcs) or nil, -- v0.25.153: v2 guns bear only inside their arcs
				faceB = child:GetAttribute("Face"),
				lob = def.cannon.lob,
			})
		end
	end
	return list
end
-- v0.25.155 (#31): with a crow's nest the aim shows the range: distance to the pointer / the gun's reach
local rangeGui
local tagged = false
local function rangeTag(mark, target, c)
	if not rangeGui then
		rangeGui = New("BillboardGui", { Name = "RangeTag", Size = UDim2.fromOffset(150, 34), StudsOffsetWorldSpace = Vector3.new(0, 7, 0), AlwaysOnTop = true, LightInfluence = 0 })
		UI.Text(rangeGui, "", 18, T.Gold, "Display", { Name = "T", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextStrokeTransparency = 0.2 })
	end
	local dist = Vector3.new(target.X - c.pos.X, 0, target.Z - c.pos.Z).Magnitude
	local t = rangeGui:FindFirstChild("T")
	t.Text = math.floor(dist) .. " / " .. math.floor(c.range)
	t.TextColor3 = dist <= c.range and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(255, 110, 90)
	rangeGui.Adornee = mark
	rangeGui.Parent = player:FindFirstChildOfClass("PlayerGui")
	tagged = true
end
local function drawAim(ship, target)
	local used = 0
	tagged = false
	if ship and target then
		local chosen = {}
		local look = ship.PrimaryPart and ship.PrimaryPart.CFrame.LookVector or Vector3.new(0, 0, -1)
		local fwd = Vector3.new(look.X, 0, look.Z)
		fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		for _, c in ipairs(cannonsOf(ship)) do
			local to = Vector3.new(target.X - c.pos.X, 0, target.Z - c.pos.Z)
			local face = Vector3.new(c.face.X, 0, c.face.Z)
			if to.Magnitude > 1 and c.fire then
				local b = math.deg(math.atan2(to:Dot(right), to:Dot(fwd)))
				if ShipHull.InArc(c.fire, b) then
					c.dot = 1 - math.abs(ShipHull.Wrap180(b - (c.faceB or b))) / 180
					table.insert(chosen, c)
				end
			elseif to.Magnitude > 1 and face.Magnitude > 0.01 then
				c.dot = face.Unit:Dot(to.Unit)
				if c.dot > 0.25 then
					table.insert(chosen, c)
				end
			end
		end
		table.sort(chosen, function(a, b)
			return a.dot > b.dot
		end)
		local n = math.min(#chosen, ship:GetAttribute("Manned") or #chosen)
		if n > 0 then
			local center = Vector3.zero
			for i = 1, n do
				center += chosen[i].pos / n
			end
			local lanes = { chosen[1] }
			if n > 1 then
				-- the outermost guns across the firing direction
				local dir = Vector3.new(target.X - center.X, 0, target.Z - center.Z).Unit
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local lo, hi = chosen[1], chosen[1]
				for i = 1, n do
					local d = side:Dot(chosen[i].pos - center)
					if d < side:Dot(lo.pos - center) then
						lo = chosen[i]
					end
					if d > side:Dot(hi.pos - center) then
						hi = chosen[i]
					end
				end
				lanes = lo == hi and { lo } or { lo, hi }
			end
			local ready = (ship:GetAttribute("ReloadEnd") or 0) <= workspace:GetServerTimeNow()
			local color = ready and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(160, 170, 190)
			for _, c in ipairs(lanes) do
				local land = target + (n > 1 and Vector3.new(c.pos.X - center.X, 0, c.pos.Z - center.Z) or Vector3.zero)
				local flatTo = Vector3.new(land.X - c.pos.X, 0, land.Z - c.pos.Z)
				if flatTo.Magnitude > c.range then
					land = c.pos + flatTo.Unit * c.range
				end
				land = Vector3.new(land.X, GameConfig.SeaLevel + 0.4, land.Z)
				local h = c.lob and math.clamp((land - c.pos).Magnitude * 0.45, 30, 140) or math.clamp((land - c.pos).Magnitude * 0.12, 6, 40)
				local prev = c.pos
				for k = 1, AIM_STEPS do
					local t = k / AIM_STEPS
					local pt = c.pos:Lerp(land, t) + Vector3.new(0, math.sin(t * math.pi) * h, 0)
					used += 1
					local seg = aimSeg(used)
					seg.Color = color
					seg.Size = Vector3.new(0.35, 0.35, (pt - prev).Magnitude)
					seg.CFrame = CFrame.lookAt((prev + pt) / 2, pt)
					prev = pt
				end
				-- where it lands: a flat square on the water
				used += 1
				local mark = aimSeg(used)
				mark.Color = color
				mark.Size = Vector3.new(6, 0.2, 6)
				mark.CFrame = CFrame.new(land)
				if c == lanes[1] and ship:GetAttribute("Spyglass") then
					rangeTag(mark, target, c)
				end
			end
		end
	end
	for i = used + 1, #aimPool do
		aimPool[i].Parent = nil
	end
	if rangeGui and not tagged then
		rangeGui.Parent = nil
	end
end

local function setCalmLook(on)
	Atmos.SetCalm(on) -- Atmos owns the light/atmosphere (day-night blend); it fades toward the Doldrums look
end

local function spinWindmills(dt)
	for _, m in ipairs(CollectionService:GetTagged("Spin")) do
		if m:IsA("Model") and m.PrimaryPart and m.Parent then
			m:PivotTo(m:GetPivot() * CFrame.Angles(0, 0, (m:GetAttribute("SpinSpeed") or 1) * dt))
		end
	end
end

-- v0.24.0 (owner): the jazz track belongs to the title menu / character creator only. In the world you hear the
-- place you are in: birds on an island by day, crickets at night, the sea's water lap (and the harbor at night) at sea.
local function updateAudio(zone, onIsland)
	local night = Atmos.IsNight()
	-- scene music (v0.25.8): boss fight > any fight (VFX marks State.lastCombat / lastBoss) > sea > island
	local now = os.clock()
	local track
	if now < (State.bossIntroUntil or 0) then
		track = nil -- v0.25.113: quiet while a boss intro plays (Controllers/BossIntro), the roar comes first
	elseif now - (State.lastBoss or -99) < 12 then
		track = "MusicBoss"
	elseif now - (State.lastCombat or -99) < 8 then
		track = "MusicBattle"
	elseif not onIsland then
		track = "MusicSea"
	else
		track = night and "MusicNight" or "MusicIsland"
	end
	Audio.Loop("music", track, 2.5)
	if onIsland and zone ~= "CalmBelt" then
		Audio.Loop("ambience", night and "AmbienceNight" or "AmbienceIsland", 3)
	else
		Audio.Loop("ambience", "AmbienceSea", 3)
	end
end

local pendingZone, pendingSince = nil, 0
local creak -- hull creak loop (Sound) while aboard your ship

-- v0.25.155 (#33 #34): every ship's lamps (Lights attribute: auto = lit at night) and gun-port lids (PortsOpen after a
-- shot, PortShut = the side that heels toward the water), drawn locally for all ships
local shipParts = setmetatable({}, { __mode = "k" }) -- ship model -> { lamps, lids }
local function partsOf(ship)
	local e = shipParts[ship]
	if not e then
		e = { lamps = {}, lids = {} }
		for _, d in ipairs(ship:GetDescendants()) do
			if d:IsA("Light") and d.Name == "ShipLamp" then
				table.insert(e.lamps, d)
			elseif d:IsA("BasePart") and (d.Name == "PortShut" or d.Name == "PortOpen") then
				table.insert(e.lids, d)
			end
		end
		shipParts[ship] = e
	end
	return e
end
local function updateShipLooks()
	local ships = workspace:FindFirstChild("Ships")
	if not ships then
		return
	end
	local night = Atmos.IsNight()
	for _, ship in ipairs(ships:GetChildren()) do
		local e = partsOf(ship)
		local mode = ship:GetAttribute("Lights") or "auto"
		local lit = mode == "on" or (mode == "auto" and night)
		for _, l in ipairs(e.lamps) do
			l.Enabled = lit
			local glass = l.Parent
			if glass and glass:IsA("BasePart") then
				glass.Material = lit and Enum.Material.Neon or Enum.Material.Glass
			end
		end
		local open = ship:GetAttribute("PortsOpen") == true
		local shut = ship:GetAttribute("PortShut") or 0
		for _, lid in ipairs(e.lids) do
			local isOpen = open and lid:GetAttribute("PortSide") ~= shut
			lid.Transparency = ((lid.Name == "PortOpen") == isOpen) and 0 or 1
		end
	end
end

function Sailing.Start()
	buildHud()
	buildTestHud()
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(updateShipLooks)
		end
	end)
	aimMarker = Instance.new("Part")
	aimMarker.Name = "AimMarker"
	aimMarker.Anchored = true
	aimMarker.CanCollide = false
	aimMarker.CanQuery = false
	aimMarker.Shape = Enum.PartType.Cylinder
	aimMarker.Size = Vector3.new(0.3, GameConfig.Ship.SplashRadius * 2, GameConfig.Ship.SplashRadius * 2)
	aimMarker.Material = Enum.Material.Neon
	aimMarker.Color = Color3.fromRGB(255, 80, 60)
	aimMarker.Transparency = 1
	aimMarker.Parent = windFolder
	aimFolder.Parent = windFolder

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local ship = myShip()
		if not ship or not aboard(ship) then
			return
		end
		-- v0.25.53 (owner): cannons + docking keys belong to the helm only; on deck the click / E / F fight (Combat)
		if not seated(ship) then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local p = waterPoint(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
			if p then
				fire(p)
			end
		elseif input.KeyCode == Enum.KeyCode.F then
			Sailing.FireAtNearest()
		elseif input.KeyCode == Enum.KeyCode.R then
			local p = not UI.IsMobile and waterPoint(UserInputService:GetMouseLocation())
			if p and (p - ship.PrimaryPart.Position).Magnitude < 300 then
				task.spawn(function()
					local res = Net.Request("FireSpecial", { target = p })
					if not res.ok and res.msg and not res.throttled then
						UI.Toast(res.msg, "bad")
					end
				end)
			else
				Sailing.FireAtNearest("FireSpecial")
			end
		elseif input.KeyCode == Enum.KeyCode.X then
			Sailing.DropKeg()
		elseif input.KeyCode == Enum.KeyCode.E then
			local res = Net.Request("DockShip")
			if res.msg then
				UI.Toast(res.msg, res.ok and "good" or "bad")
			end
		end
	end)

	local sendAcc, fxAcc, audioAcc = 0, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		spinWindmills(dt)
		local ship = myShip()
		if ship and seated(ship) then
			local seat = ship:FindFirstChild("HelmSeat", true)
			local th = seat.ThrottleFloat
			if th > 0.5 and lastThrottleInput <= 0.5 then
				sailLevel = math.min(3, sailLevel + 1)
			elseif th < -0.5 and lastThrottleInput >= -0.5 then
				sailLevel = math.max(-1, sailLevel - 1)
			end
			lastThrottleInput = th
			sendAcc += dt
			if sendAcc > 0.1 then
				sendAcc = 0
				local throttle = sailLevel < 0 and -0.4 or sailLevel / 3
				Net.Get("ShipInput"):FireServer(throttle, seat.SteerFloat)
			end
			player.CameraMaxZoomDistance = 260
		else
			player.CameraMaxZoomDistance = 120
		end
		local onBoard = ship ~= nil and ship.PrimaryPart ~= nil and aboard(ship)
		local helm = onBoard and seated(ship)
		-- (v0.25.53, owner: the green firing-sector rings are gone; the trajectory lines show where the balls go)
		local aimAt
		if helm and not UI.IsMobile then
			local p = waterPoint(UserInputService:GetMouseLocation())
			if p and (p - ship.PrimaryPart.Position).Magnitude < 300 then
				aimAt = p
			end
		end
		aimMarker.Transparency = 1 -- (v0.25.53: replaced by the trajectory preview)
		drawAim(helm and ship or nil, aimAt)
		updateHud(ship)
		-- v0.25.54 (owner: the sail-up beep sounded like an alert; wants wood creaking when sailing / turning): a hull
		-- creak loop on your ship, louder the faster it goes and the harder it turns, silent when still
		if onBoard then
			if not creak or creak.Parent ~= ship.PrimaryPart then
				if creak then
					creak:Destroy()
				end
				creak = Audio.Attach("ShipCreakLoop", ship.PrimaryPart, 90)
				if creak then
					creak.Volume = 0 -- fades in with the motion below
				end
			end
			if creak then
				local sp = (ship:GetAttribute("Speed") or 0) / math.max(1, ship:GetAttribute("MaxSpeed") or 1)
				local turn = math.abs(ship.PrimaryPart.AssemblyAngularVelocity.Y)
				local k = math.clamp(math.abs(sp) * 0.6 + turn * 1.6, 0, 1)
				creak.Volume += (0.55 * k - creak.Volume) * math.min(1, dt * 3)
				creak.PlaybackSpeed = 0.9 + 0.15 * k
			end
		elseif creak then
			creak:Destroy()
			creak = nil
		end
		-- wind: white streaks blowing east toward the Crimson Wall, only where there is wind
		fxAcc += dt
		local cam = workspace.CurrentCamera
		local focus = cam.Focus.Position
		local zone, wind = SeaZones.Get(Vector3.new(focus.X, 0, focus.Z))
		-- v0.25.8 (owner: the Calm Belt edge flashed): a new zone must hold for 1.5 s before the look/banner switch,
		-- the camera wobbling over a boundary used to flip it every frame
		if zone ~= pendingZone then
			pendingZone, pendingSince = zone, os.clock()
		end
		if zone ~= lastZone and (lastZone == nil or os.clock() - pendingSince >= 1.5) then
			if lastZone ~= nil and onBoard and (zone == "CalmBelt" or zone == "Edge" or lastZone == "CalmBelt") then
				local z = zoneInfo[zone]
				UI.Banner(zone == "CalmBelt" and "The Doldrums!" or (zone == "Edge" and "The wind is fading..." or "Wind is back!"), z and z.text, z and z.color)
			end
			setCalmLook(zone == "CalmBelt")
			lastZone = zone
		end
		if focus.Y < 120 and fxAcc > 0.22 then
			fxAcc = 0
			-- soft curved wind wisps (Atmos), a few at a time
			local count = math.floor(wind * 1.4 * (Settings.Knob("wind") or 1) + 0.5)
			Atmos.Wind(Vector3.new(focus.X, 0, focus.Z), Vector3.new(1, 0, -focus.Z / 4000).Unit, 0.6 + wind, count)
		end
		audioAcc += dt
		if audioAcc > 1 then
			audioAcc = 0
			local r = root()
			local onIsland = r and SeaZones.OnIslandLand(r.Position) and r.Position.Y > 3
			updateAudio(zone, onIsland)
		end
	end)
end

return Sailing
