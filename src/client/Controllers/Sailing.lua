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

local function buildHud()
	local f = New("Frame", { Name = "ShipHUD", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(360, 252), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = UI.Root })
	UI.Corner(f, 18)
	New("UIGradient", { Color = ColorSequence.new(T.PanelTop, T.PanelDeep), Rotation = 90, Parent = f })
	UI.Stroke(f, T.Edge, 3)
	UI.Pad(f, 10)
	UI.List(f, nil, 6)
	local name = UI.Text(f, "⛵ Ship", 24, T.Text, "Display")
	local hp = UI.Bar(f, T.Green, UDim2.new(1, 0, 0, 22), "HP")
	local zone = New("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Ocean, Parent = f })
	UI.Corner(zone, 10)
	UI.Stroke(zone, T.Edge, 2)
	local zoneText = UI.Text(zone, "", 16, T.Text, "Bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local info = UI.Text(f, "", 15, T.TextSoft, "Semi", { Size = UDim2.new(1, 0, 0, 40) })
	local reload = UI.Bar(f, T.Orange, UDim2.new(1, 0, 0, 18), "🔥 READY")
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = f })
	UI.List(row, Enum.FillDirection.Horizontal, 6)
	UI.Button(row, "▲ Sail", T.Ocean, UDim2.fromOffset(78, 44), function()
		sailLevel = math.min(3, sailLevel + 1)
	end)
	UI.Button(row, "▼ Sail", T.OceanDark, UDim2.fromOffset(78, 44), function()
		sailLevel = math.max(-1, sailLevel - 1)
	end)
	UI.Button(row, "🔥 Fire", T.Red, UDim2.fromOffset(86, 44), function()
		Sailing.FireAtNearest()
	end)
	UI.Button(row, "⚓ Dock", T.Green, UDim2.fromOffset(86, 44), function()
		local res = Net.Request("DockShip")
		UI.Toast(res.msg or (res.ok and "Docked" or "Cannot dock"), res.ok and "good" or "bad")
		if res.ok then
			Audio.Play("Bell")
		end
	end)
	hud = { frame = f, name = name, hp = hp, zone = zone, zoneText = zoneText, info = info, reload = reload }
end

local function sailText()
	if sailLevel < 0 then
		return "REVERSE"
	elseif sailLevel == 0 then
		return "furled"
	end
	return string.rep("▮", sailLevel) .. string.rep("▯", 3 - sailLevel)
end

local wasVisible = false
local function updateHud(ship)
	if not hud then
		return
	end
	local show = ship ~= nil and aboard(ship)
	hud.frame.Visible = show
	if show and not wasVisible then
		UI.Pop(hud.frame, 0.7)
	end
	wasVisible = show
	if not show then
		return
	end
	local hp, max = ship:GetAttribute("HP") or 0, ship:GetAttribute("MaxHP") or 1
	hud.name.Text = "⛵ " .. (ship:GetAttribute("ShipName") or "Ship")
	hud.hp:Set(hp / max, UI.Format(hp) .. " / " .. UI.Format(max))
	hud.hp:SetColor(hp / max < 0.3 and T.Red or T.Green)
	local z = zoneInfo[ship:GetAttribute("Zone") or "Lane"] or zoneInfo.Lane
	hud.zoneText.Text = z.text
	hud.zone.BackgroundColor3 = z.color
	local wind = math.floor((ship:GetAttribute("Wind") or 1) * 100)
	hud.info.Text = string.format("Speed %d / %d  •  Wind %d%%  •  Sails %s\nCrew %d  •  Cannons manned %d / %d", ship:GetAttribute("Speed") or 0, ship:GetAttribute("MaxSpeed") or 0, wind, sailText(), ship:GetAttribute("Crew") or 0, ship:GetAttribute("Manned") or 0, ship:GetAttribute("Cannons") or 0)
	local left = (ship:GetAttribute("ReloadEnd") or 0) - workspace:GetServerTimeNow()
	if left > 0 then
		hud.reload:Set(1 - left / GameConfig.Ship.ReloadTime, string.format("RELOADING %.1fs", left))
	else
		hud.reload:Set(1, "🔥 READY  (click water / F)")
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

function Sailing.FireAtNearest()
	local ship = myShip()
	if not ship or not ship.PrimaryPart then
		return
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

-- ===== aim arcs (port / starboard firing sectors drawn on the water) =====
local arcs = { model = nil, ship = nil }
local function seg(parent, a, b, color)
	local mid = (a + b) / 2
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Size = Vector3.new(0.5, 0.15, (b - a).Magnitude)
	p.CFrame = CFrame.lookAt(mid, b)
	p.Parent = parent
end
local function buildArcs(ship)
	if arcs.model then
		arcs.model:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "AimArcs"
	local center = Instance.new("Part")
	center.Anchored = true
	center.Transparency = 1
	center.CanCollide = false
	center.CanQuery = false
	center.Size = Vector3.one
	center.Parent = m
	m.PrimaryPart = center
	-- cannon ranges per side from the ship's parts (cannons face along their own LookVector)
	local rootCf = ship.PrimaryPart.CFrame
	local range = { [1] = 0, [-1] = 0 }
	for _, child in ipairs(ship:GetChildren()) do
		local def = ShipParts[child.Name]
		if def and def.cannon and child.PrimaryPart then
			local look = rootCf:VectorToObjectSpace(child.PrimaryPart.CFrame.LookVector)
			local side = look.X >= 0 and 1 or -1
			range[side] = math.max(range[side], def.cannon.range)
		end
	end
	for side, r in pairs(range) do
		if r > 0 then
			local span = math.rad(75)
			local n = 14
			local prev
			for i = 0, n do
				local a = -span + 2 * span * i / n
				local dir = Vector3.new(side * math.cos(a), 0, math.sin(a))
				local p = dir * r
				if prev then
					seg(m, prev, p, Color3.fromRGB(120, 255, 150))
				end
				prev = p
			end
			for _, a in ipairs({ -span, span }) do
				seg(m, Vector3.new(side * 10, 0, 0), Vector3.new(side * math.cos(a), 0, math.sin(a)) * r, Color3.fromRGB(120, 255, 150))
			end
		end
	end
	m.Parent = windFolder
	arcs.model = m
	arcs.ship = ship
end
local function updateArcs(ship, show)
	if not show then
		if arcs.model then
			arcs.model:PivotTo(CFrame.new(0, -500, 0))
		end
		return
	end
	if arcs.ship ~= ship or not arcs.model then
		buildArcs(ship)
	end
	local cf = ship.PrimaryPart.CFrame
	local _, yaw = cf:ToOrientation()
	arcs.model:PivotTo(CFrame.new(cf.Position.X, 0.35, cf.Position.Z) * CFrame.Angles(0, yaw, 0))
	local ready = (ship:GetAttribute("ReloadEnd") or 0) <= workspace:GetServerTimeNow()
	local color = ready and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(160, 170, 190)
	for _, p in ipairs(arcs.model:GetChildren()) do
		if p:IsA("BasePart") and p ~= arcs.model.PrimaryPart then
			p.Color = color
		end
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
	if now - (State.lastBoss or -99) < 12 then
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

function Sailing.Start()
	buildHud()
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local ship = myShip()
		if not ship or not aboard(ship) then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local p = waterPoint(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
			if p then
				fire(p)
			end
		elseif input.KeyCode == Enum.KeyCode.F then
			Sailing.FireAtNearest()
		elseif input.KeyCode == Enum.KeyCode.E and not seated(ship) then
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
				Audio.Play("ShipCreak")
			elseif th < -0.5 and lastThrottleInput >= -0.5 then
				sailLevel = math.max(-1, sailLevel - 1)
				Audio.Play("ShipCreak")
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
		updateArcs(ship, onBoard and Settings.Values.rangeRings)
		if onBoard and not UI.IsMobile then
			local p = waterPoint(UserInputService:GetMouseLocation())
			if p and (p - ship.PrimaryPart.Position).Magnitude < 300 then
				aimMarker.Transparency = 0.45
				aimMarker.CFrame = CFrame.new(p.X, 0.3, p.Z) * CFrame.Angles(0, 0, math.pi / 2)
			else
				aimMarker.Transparency = 1
			end
		else
			aimMarker.Transparency = 1
		end
		updateHud(ship)
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
