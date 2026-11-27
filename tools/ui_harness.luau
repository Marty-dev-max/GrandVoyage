-- UI harness: runs the real client UI code headlessly in Lune with mocked Roblox services,
-- builds the HUD, opens every window, reports runtime errors, and dumps each screen's GUI tree
-- to JSON (rendered to PNG by tools/ui_render.js).
--   lune run tools/ui_harness.luau build/GrandVoyage.rbxlx out_dir
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local placePath = process.args[1] or "build/GrandVoyage.rbxlx"
local outDir = process.args[2] or "build/ui"
-- third arg "phone" simulates a phone in landscape: small viewport, touch only, Roblox top bar inset
local PHONE = process.args[3] == "phone"
local VIEW = PHONE and roblox.Vector2.new(844, 390) or roblox.Vector2.new(1600, 900)
local TOPBAR = PHONE and 48 or 58
fs.writeDir(outDir)
local place = roblox.deserializePlace(fs.readFile(placePath))
local Instance, Vector2, Vector3, UDim2, Color3 = roblox.Instance, roblox.Vector2, roblox.Vector3, roblox.UDim2, roblox.Color3

-- ===== signals =====
local function Signal()
	local s = { conns = {} }
	function s:Connect(f)
		table.insert(self.conns, f)
		return { Disconnect = function() end, Connected = true }
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, f in self.conns do
			-- Lune throws on reading .Parent of destroyed Instances (Roblox returns nil); ignore that here
			local ok, err = pcall(f, ...)
			if not ok and not string.find(tostring(err), "destroyed") then
				print("[signal error]", err)
			end
		end
	end
	function s:Wait() end
	return s
end
local dummy = Signal()
for _, ev in { "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click", "Activated", "Destroying", "FocusLost", "InputBegan", "InputEnded", "Changed", "Triggered", "Touched", "Died", "OnClientEvent", "OnClientInvoke", "Completed", "ChildAdded", "AncestryChanged" } do
	roblox.implementProperty("Instance", ev, function()
		return dummy
	end)
end
local bindSig = Signal()
roblox.implementProperty("BindableEvent", "Event", function()
	return bindSig
end)
roblox.implementMethod("BindableEvent", "Fire", function(_, ...)
	bindSig:Fire(...)
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
	return dummy
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function()
	return dummy
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, n)
	return self:FindFirstChild(n)
end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementMethod("Camera", "ViewportPointToRay", function()
	return { Origin = Vector3.new(0, 50, 0), Direction = Vector3.new(0, -1, 0) }
end)
roblox.implementMethod("Camera", "WorldToViewportPoint", function()
	return Vector3.new(800, 450, 10), true
end)
roblox.implementProperty("Camera", "ViewportSize", function()
	return VIEW
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock()
end)
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)
roblox.implementMethod("Model", "PivotTo", function() end)
roblox.implementMethod("Model", "GetPivot", function()
	return roblox.CFrame.new()
end)
roblox.implementMethod("Model", "ScaleTo", function() end)

local realWs = place:GetService("Workspace")
local camera = {
	ViewportSize = VIEW,
	CFrame = roblox.CFrame.new(0, 50, 50),
	Focus = roblox.CFrame.new(),
	FieldOfView = 70,
	GetPropertyChangedSignal = function()
		return dummy
	end,
	ViewportPointToRay = function()
		return { Origin = Vector3.new(0, 50, 0), Direction = Vector3.new(0, -1, 0) }
	end,
	WorldToViewportPoint = function()
		return Vector3.new(800, 450, 10), true
	end,
}
local ws = realWs

-- ===== player =====
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local attrs = {}
local player = setmetatable({
	UserId = 1527424396,
	DisplayName = "Treezaa2",
	Name = "Treezaa2",
	Character = nil,
	CharacterAdded = Signal(),
	CameraMaxZoomDistance = 120,
	Parent = true,
}, {})
function player:GetAttribute(k)
	return attrs[k]
end
function player:SetAttribute(k, v)
	attrs[k] = v
end
function player:WaitForChild(n)
	return n == "PlayerGui" and playerGui or nil
end
function player:FindFirstChild(n)
	return n == "PlayerGui" and playerGui or nil
end
function player:GetAttributeChangedSignal()
	return dummy
end

-- ===== services =====
local renderStepped = Signal()
local services = {
	Players = { LocalPlayer = player, PlayerAdded = dummy, PlayerRemoving = dummy },
	RunService = { RenderStepped = renderStepped, Heartbeat = renderStepped, Stepped = renderStepped, IsStudio = function() return true end, IsServer = function() return false end, IsClient = function() return true end },
	GuiService = { TopbarInset = { Max = Vector2.new(VIEW.X, TOPBAR), Min = Vector2.new(120, 0) }, GetPropertyChangedSignal = function() return dummy end, GetGuiInset = function() return Vector2.new(0, TOPBAR), Vector2.new(0, 0) end },
	UserInputService = { TouchEnabled = PHONE, KeyboardEnabled = not PHONE, MouseEnabled = not PHONE, TouchTapInWorld = dummy, JumpRequest = dummy, InputBegan = dummy, InputEnded = dummy, InputChanged = dummy, TouchPinch = dummy, GetMouseLocation = function() return Vector2.new(0, 0) end },
	TweenService = {
		Create = function(_, inst, _info, props)
			return {
				Play = function()
					for k, v in props do
						pcall(function()
							inst[k] = v
						end)
					end
				end,
				Cancel = function() end,
				Completed = dummy,
			}
		end,
	},
	CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return dummy end, AddTag = function() end, HasTag = function() return false end },
	StarterGui = { SetCoreGuiEnabled = function() end, SetCore = function() end },
	Debris = { AddItem = function() end },
	MarketplaceService = { PromptProductPurchase = function() end, PromptGamePassPurchase = function() end },
	Lighting = place:GetService("Lighting"),
	SoundService = place:GetService("SoundService"),
	ReplicatedStorage = place:GetService("ReplicatedStorage"),
	Workspace = ws,
}
-- parenting to the proxy is not possible; parent workspace objects to the real Workspace
local _ = realWs
function services.Players:GetPlayers()
	return { player }
end
function services.Players:GetPlayerByUserId()
	return nil
end
function services.Players:GetUserThumbnailAsync()
	return ""
end
local game = setmetatable({}, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, name)
				return services[name] or place:GetService(name)
			end
		end
		if k == "CreatorId" then
			return 1527424396
		end
		return place[k]
	end,
})

-- ===== network =====
local RS = place:GetService("ReplicatedStorage")
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = RS
for _, n in { { "RemoteFunction", "Request" }, { "RemoteEvent", "Push" }, { "RemoteEvent", "FX" }, { "RemoteEvent", "ShipInput" } } do
	local r = Instance.new(n[1])
	r.Name = n[2]
	r.Parent = remotes
end
local fakeResponses = {
	StallView = { ok = true, data = { title = "Cheap Cards!", seller = "Pirate King", items = { { index = 1, id = "WildBoarCard", qty = 2, price = 5000 }, { index = 2, id = "Sword_Keen", refine = 5, cards = {}, qty = 1, price = 90000 } } } },
	PearlInfo = { ok = true, data = { pearls = 840, bound = 120, earnedToday = 75, cap = 300, canTrade = true, perks = {}, products = { { productId = 0, pearls = 100, name = "Pouch of Pearls" }, { productId = 0, pearls = 550, name = "Chest of Pearls" } } } },
	MenuSlots = { ok = true, data = { bank = 2, locked = { false, false, true }, slots = { { look = { hair = 18, eyes = 6, mouth = 2, shirt = 6, pants = 1, shoes = 2, hair1 = "F4F4F4" }, heritage = "Skyborn", variant = 3, spins = 1, level = 12, class = "Brawler", jobLevel = 9, played = 5 }, false, false } } },
	MenuSpin = { ok = true, data = { heritage = "Cinderwing", variant = 1, bank = 1, summary = { look = {}, heritage = "Cinderwing", variant = 1, spins = 0, level = 1, class = "Brawler", jobLevel = 1, played = 0 } } },
	MenuSaveLook = { ok = true, data = { look = {}, heritage = "Islander", variant = 1, spins = 3, level = 1, class = "Brawler", jobLevel = 1, played = 0 } },
	StoreInfo = { ok = true, data = { gems = 960, boosts = { exp = os.time() + 600 }, tokens = { FruitRemover = 1 } } },
	GuildList = { ok = true, data = { { id = "a", name = "Sea Wolves", faction = "Pirate", count = 12 }, { id = "b", name = "Blue Anchor", faction = "Marine", count = 8 } } },
}
roblox.implementMethod("RemoteFunction", "InvokeServer", function(_, action)
	return fakeResponses[action] or { ok = true }
end)
roblox.implementMethod("RemoteEvent", "FireServer", function() end)

-- ===== task (no real scheduling: loops park forever, delays are dropped) =====
local errors = {}
local trackWaits, sleepers = false, {}
local fakeTask = {
	spawn = function(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			print("[task.spawn error]", err)
		end
	end,
	defer = function(f, ...)
		pcall(f, ...)
	end,
	delay = function() end,
	wait = function()
		if trackWaits then
			table.insert(sleepers, coroutine.running())
		end
		coroutine.yield()
	end,
}
-- resume the tracked sleepers (each task.wait() = one frame) until cond() or the time runs out
local function pump(seconds, cond)
	local t0 = os.clock()
	while #sleepers > 0 and os.clock() - t0 < seconds and not (cond and cond()) do
		local list = sleepers
		sleepers = {}
		for _, co in list do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					print("[task error]", err)
					table.insert(errors, "task: " .. tostring(err))
				end
			end
		end
	end
end

-- ===== module loader =====
local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] ~= nil then
		return cache[key]
	end
	local env = setmetatable({
		script = mod, require = req, game = game, workspace = ws, task = fakeTask, tick = os.clock,
		Instance = Instance, Vector2 = Vector2, Vector3 = Vector3, CFrame = roblox.CFrame, Color3 = Color3, UDim = roblox.UDim, UDim2 = UDim2,
		Enum = roblox.Enum, Font = roblox.Font, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
		TweenInfo = { new = function(...) return { ... } end }, RaycastParams = { new = function() return {} end },
		PhysicalProperties = roblox.PhysicalProperties, Random = { new = function() return { NextNumber = function(_, a, b) return (a or 0) + math.random() * ((b or 1) - (a or 0)) end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
		warn = function(...) print("[warn]", ...) end,
	}, { __index = getfenv() })
	env.__cam = camera
	local src = string.gsub(mod.Source, "workspace%.CurrentCamera", "__cam")
	local fn = luau.load(src, { debugName = key, environment = env })
	local r = fn()
	cache[key] = r
	return r
end

local client = place:GetService("StarterPlayer").StarterPlayerScripts.Client
local function mod(path)
	local m = client
	for part in string.gmatch(path, "[^%.]+") do
		m = m:FindFirstChild(part)
	end
	return req(m)
end

-- ===== fake player data =====
local Shared = RS.Shared
local Formulas = req(Shared.Modules.Formulas)
local State = mod("State")
local profile = {
	class = "Swordsman", baseLevel = 34, baseExp = 0, jobLevel = 22, jobExp = 0, statPoints = 6, skillPoints = 3,
	stats = { VIT = 28, END = 22, WIL = 6, WPN = 34, MAR = 0, FRU = 0 },
	skills = { Bash = 3, FirstAid = 1, OniSlash = 5, TornadoCut = 3, FlyingSlash = 2, IronBody = 1 },
	skillBar = { "OniSlash", "TornadoCut", "FlyingSlash", "IronBody", "FirstAid" },
	autoSkills = { OniSlash = true, TornadoCut = true, F_FireFist = true },
	fruit = { id = "Blaze", mastery = 27, exp = 40 },
	toki = { rolled = true, Conqueror = { color = "#7A3CFF" } }, tokiColorPick = { Conqueror = true },
	daily = { day = "20261116", bonusClaimed = false, list = { { id = "HuntLocal", kind = "Kill", target = "MarineRifleman", targetName = "Marine Rifleman", count = 30, progress = 30, claimed = false }, { id = "Skills", kind = "Skill", count = 40, progress = 12, claimed = false }, { id = "Sink", kind = "Sink", count = 3, progress = 3, claimed = true } } },
	ach = { counters = { Kill = 640, Sink = 12, Refine = 9 }, done = { Hunter1 = true, Sink1 = true, Fruit1 = true, Pet1 = true, Level30 = true, Crabs = true }, claimed = { Hunter1 = true, Fruit1 = true } }, title = "Crabs",
	pets = { { uid = "pet1", species = "Lantern", level = 22, exp = 300, stage = 2 }, { uid = "pet2", species = "Hermit", level = 9, exp = 40, stage = 1 } }, activePet = "pet1",
	classProgress = { Brawler = { jobLevel = 10, jobExp = 0 } }, classSwitches = 1,
	inventory = {
		{ uid = "fr1", id = "Fruit_Haze", qty = 1 },
		{ uid = "w", id = "Sword_Master", qty = 1, refine = 7, cards = { "WildBoarCard" } },
		{ uid = "a", id = "MarineCoat", qty = 1, refine = 4, cards = {} },
		{ uid = "h", id = "SunHat", qty = 1, refine = 0, cards = {} },
		{ uid = "c1", id = "CaptainConfettiCard", qty = 1 },
		{ uid = "c2", id = "LeviathanCard", qty = 1 },
		{ uid = "c3", id = "PirateCaptainCard", qty = 1 },
		{ uid = "m1", id = "MeatOnBone", qty = 24 },
		{ uid = "m2", id = "TidecoreShard", qty = 5 },
		{ uid = "m3", id = "TreasureWood", qty = 1 },
		{ uid = "m4", id = "Wood", qty = 120 },
		{ uid = "m5", id = "RefineGuard", qty = 1 },
		{ uid = "w2", id = "Sword_Grand", qty = 1, refine = 0, cards = {} },
	},
	equipment = { weapon = "w", armor = "a", headgear = "h" },
	beli = 1284500, faction = "Pirate", bounty = 38000000, merit = 0,
	ships = { req(Shared.Modules.ShipStats).StarterDesign() }, activeShip = 1, shipSunk = false, crew = 4,
	unlocked = { Daybreak = true, ConchBay = true, Marmalade = true, Honeyslope = true },
	settings = { autoPotionPct = 35 }, guildId = "a",
}
local derived = Formulas.Compute(profile, {})
for k, v in { Level = 34, JobLevel = 22, BaseExp = 26000, BaseExpNext = 45000, JobExp = 9000, JobExpNext = 21000, Beli = profile.beli, Faction = "Pirate", Bounty = profile.bounty, Merit = 0, StatPoints = 6, SkillPoints = 3, Class = "Swordsman", ClassName = "Swordsman", SP = 120, MaxSP = derived.maxSp, GuildName = "Sea Wolves", Buffs = "IronBody" } do
	attrs[k] = v
end
State.profile = profile
State.derived = derived
State.party = { { name = "Treezaa2", leader = true }, { name = "NamiFan", leader = false } }
State.guild = { id = "a", name = "Sea Wolves", faction = "Pirate", level = 3, leader = 1527424396, members = { ["1527424396"] = { name = "Treezaa2", rank = "Leader" }, ["2"] = { name = "NamiFan", rank = "Member" } } }
State.bossBoard = { list = { { island = "Conch Bay", name = "Axe-Arm Captain", level = 22, alive = true, nextSpawn = 0 }, { island = "Marmalade Town", name = "Captain Confetti", level = 32, alive = false, nextSpawn = 600 } }, serverTime = 0, receivedAt = os.clock() }
State.guildWar = { active = false, forts = { { name = "Fort Driftwood", owner = "Sea Wolves", faction = "Pirate" }, { name = "Fort Tidebreak", owner = "-", faction = "None" } } }

-- ===== dump =====
local function enumName(e)
	return e and e.Name or nil
end
local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end
local function color(c)
	return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
end
local function seq(s)
	local out = {}
	for _, k in s.Keypoints do
		table.insert(out, { k.Time, k.Value ~= nil and (typeof(k.Value) == "number" and k.Value or color(k.Value)) or 0 })
	end
	return out
end
local function dump(inst)
	local n = { cls = inst.ClassName, name = inst.Name, children = {}, mods = {} }
	local function try(k, f)
		local ok, v = pcall(function()
			return inst[k]
		end)
		if ok and v ~= nil then
			n[k] = f and f(v) or v
		end
	end
	if inst:IsA("GuiObject") then
		try("Size", udim2)
		try("Position", udim2)
		try("AnchorPoint", function(v) return { v.X, v.Y } end)
		try("Visible")
		try("BackgroundColor3", color)
		try("BackgroundTransparency")
		try("ZIndex")
		try("LayoutOrder")
		try("Rotation")
		try("ClipsDescendants")
		try("AutomaticSize", enumName)
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			try("Image")
			try("ImageColor3", color)
			try("ImageTransparency")
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			try("Text")
			try("TextColor3", color)
			try("TextSize")
			try("TextScaled")
			try("TextXAlignment", enumName)
			try("TextYAlignment", enumName)
			try("TextTransparency")
			try("TextWrapped")
			try("TextStrokeTransparency")
			try("TextStrokeColor3", color)
			try("FontFace", function(v) return v.Family end)
			try("PlaceholderText")
		end
	elseif inst:IsA("UICorner") then
		n.radius = { inst.CornerRadius.Scale, inst.CornerRadius.Offset }
	elseif inst:IsA("UIStroke") then
		n.color = color(inst.Color)
		n.thickness = inst.Thickness
		n.mode = inst.ApplyStrokeMode.Name
		n.transparency = inst.Transparency
		n.enabled = inst.Enabled
	elseif inst:IsA("UIGradient") then
		n.colorSeq = seq(inst.Color)
		n.transSeq = seq(inst.Transparency)
		n.rotation = inst.Rotation
		n.enabled = inst.Enabled
	elseif inst:IsA("UIPadding") then
		n.pad = { inst.PaddingTop.Offset, inst.PaddingRight.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset }
	elseif inst:IsA("UIListLayout") then
		n.dir = inst.FillDirection.Name
		n.padding = inst.Padding.Offset
		n.halign = inst.HorizontalAlignment.Name
		n.valign = inst.VerticalAlignment.Name
	elseif inst:IsA("UIGridLayout") then
		n.cell = { inst.CellSize.X.Offset, inst.CellSize.Y.Offset }
		n.cellPad = { inst.CellPadding.X.Offset, inst.CellPadding.Y.Offset }
	elseif inst:IsA("UIScale") then
		n.scale = inst.Scale
	elseif inst:IsA("UITextSizeConstraint") then
		n.max = inst.MaxTextSize
	end
	for _, c in inst:GetChildren() do
		table.insert(n.children, dump(c))
	end
	return n
end

local UI = mod("UI.UIKit")
local shots = {}
local function snapshot(name, root)
	for _ = 1, 4 do
		renderStepped:Fire(0.1)
	end
	fs.writeFile(outDir .. "/" .. name .. ".json", serde.encode("json", dump(root or UI.Root)))
	table.insert(shots, name)
	print("[snap]", name)
end

local function step(label, f)
	local ok, err = pcall(f)
	if not ok then
		table.insert(errors, label .. ": " .. tostring(err))
		print("[ERROR]", label, err)
	end
	return ok
end

local Settings = mod("Controllers.Settings")
local Panels = mod("UI.Panels")
local HUD = mod("UI.HUD")
local Readability = mod("Controllers.Readability")
step("Settings.Start", Settings.Start)
step("HUD.Start", HUD.Start)
step("Readability.Start", Readability.Start)
step("Sailing.Start", mod("Controllers.Sailing").Start)
step("Builder.Start", mod("Controllers.Builder").Start)
step("Combat.Start", mod("Controllers.Combat").Start)
step("VFX.Start", mod("Controllers.VFX").Start)
local Quest = mod("UI.Quest")
step("Swim.Start", mod("Controllers.Swim").Start)
step("Pets.Start", mod("Controllers.Pets").Start)
step("Titles.Start", mod("Controllers.Titles").Start)
step("Quest.Start", Quest.Start)
step("Quest.OnQuest", function()
	Quest.OnQuest({ step = 2, total = 40, progress = 3, id = "T02", tutorial = true, speaker = "Old Salt Rowan", dialog = { "Beach Crabs keep pinching my nets. Clear a few out for me." } })
	Quest.OnComplete({ title = "Ahoy, Greenhorn!" })
end)
step("VFX library", function()
	local V = mod("Controllers.VFX")
	local P = Vector3.new(0, 10, 0)
	local c = Color3.fromRGB(255, 120, 40)
	V.Flash(P, c, 4)
	V.Sparks(P, c, 8, 8)
	V.Burst(P, 6, c, 0.3)
	V.Ring(P, 10, c, 0.4)
	V.Crack(P, 6)
	V.Smoke(P, nil, 6, 4)
	V.Flames(P, c, 8, 3)
	V.Focus(P, c)
	V.Slash(roblox.CFrame.new(P), c, 8)
	V.Beam(P, P + Vector3.new(0, 30, 0), c, 1, 0.3)
	V.Explosion(P, 8)
	V.Projectile(P, P + Vector3.new(20, 0, 0), c, 1, 0.2, 2)
	-- Aura reads Part.Position (not readable in Lune); check its emitter properties directly instead
	local e = roblox.Instance.new("ParticleEmitter")
	e.Shape = roblox.Enum.ParticleEmitterShape.Cylinder
	e.ShapeStyle = roblox.Enum.ParticleEmitterShapeStyle.Surface
	e.RotSpeed = roblox.NumberRange.new(-200, 200)
end)
step("HUD.Loot", function()
	trackWaits = true
	HUD.Loot({ beli = 1250, items = { { id = "TidecoreShard", qty = 1 }, { id = "CaptainConfettiCard", qty = 1, card = true } } })
end)
-- play the card reveal through (tension -> flip -> shockwave -> face) and snapshot it once the face is up
step("CardReveal", function()
	local function revealGui()
		return playerGui:FindFirstChild("GVCardReveal")
	end
	pump(4, function()
		local g = revealGui()
		local face = g and g:FindFirstChild("Face", true)
		return face ~= nil and face.Visible
	end)
	local g = revealGui()
	assert(g and g:FindFirstChild("Face", true), "card reveal never reached the face")
	local t0 = os.clock()
	pump(0.5, function()
		return os.clock() - t0 > 0.45
	end)
	-- finish the tweens the harness does not run: show the stars and art at full size
	for _, d in g:GetDescendants() do
		if d:IsA("UIScale") then
			d.Scale = 1
		elseif d:IsA("TextLabel") and d.Text == "★" then
			d.TextTransparency = 0
		end
	end
	fs.writeFile(outDir .. "/card_reveal.json", serde.encode("json", dump(g)))
	table.insert(shots, "card_reveal")
	print("[snap] card_reveal")
	pump(6, function()
		return revealGui() == nil
	end)
	assert(revealGui() == nil, "card reveal did not clean up")
	trackWaits = false
end)
snapshot("hud")
-- the style meter climbs to S rank (fire) without errors
step("UI.ComboHit", function()
	for i = 1, 26 do
		UI.ComboHit(1200 + i * 37, i % 5 == 0)
	end
	for _ = 1, 4 do
		renderStepped:Fire(0.016)
	end
end)
snapshot("hud_combo")
-- the ammo picker builds without errors (it closes itself on the next refresh: the test hero is no slingshot user)
step("HUD.AmmoPicker", function()
	HUD.ToggleAmmoPicker()
	HUD.ToggleAmmoPicker()
end)
step("HUD.ExpGain", function()
	HUD.ExpGain({ base = 1840, job = 920, pos = Vector3.new(0, 5, 0) })
	local t0 = os.clock()
	while os.clock() - t0 < 0.42 do
	end
	renderStepped:Fire(0.016)
end)
fs.writeFile(outDir .. "/hud_exp.json", serde.encode("json", dump(UI.Root)))
table.insert(shots, "hud_exp")
-- clear transient banners so they do not cover the window snapshots
for _, d in UI.Root:GetDescendants() do
	if d.Name == "Banner" or d.Name == "OrbLayer" then
		pcall(function()
			d.Visible = false
		end)
	end
end

local panels = {
	{ "Inventory" }, { "Inventory", { select = "w", tab = "Detail" } }, { "Stats" }, { "TokiColor" }, { "Skills" }, { "Skills", { tab = "Sets" } }, { "JobMaster" }, { "Refine" }, { "Shop" }, { "Tavern" }, { "Shipwright" },
	{ "Map" }, { "BossBoard" }, { "Guild" }, { "Dungeon", { dungeonId = "CircusTent" } }, { "Party" },
	{ "Stall", { sellerId = 2 } }, { "StallSetup" }, { "PearlShop" }, { "PearlShop", { tab = "Benefits" } }, { "PearlShop", { tab = "Boosts" } }, { "Pets" }, { "Quests" }, { "Quests", { tab = "Ach" } }, { "Quests", { tab = "Story" } }, { "MenuHub" }, { "Settings" }, { "Settings", { tab = "Hotkeys", cat = "Hotkeys" } }, { "AutoBattle" }, { "Potion", { kind = "hp" } }, { "Potion", { kind = "sp" } },
}
for _, p in panels do
	step("CloseAll", UI.CloseAll)
	if step("Panel " .. p[1], function()
		Panels.Open(p[1], p[2])
	end) then
		snapshot("panel_" .. p[1] .. ((p[2] and p[2].tab) and ("_" .. p[2].tab) or ""))
	end
end
-- v0.25.43: an open stall's editor (listed items + bag + CLOSE STALL)
step("CloseAll", UI.CloseAll)
State.stall = { open = true, title = "Cheap Cards!", currency = "beli", items = { { index = 1, id = "SteelOre", qty = 5, price = 250 }, { index = 2, id = "PirateFeast", qty = 0, price = 900 } } }
if step("Panel StallManage", function()
	Panels.Open("StallSetup")
end) then
	snapshot("panel_StallManage")
end
State.stall = { open = false }
-- v0.24.0 title menu: title, character slots, creator (+ color target / spin / buy spins)
do
	local Menu = mod("UI.Menu")
	step("Menu.Start", Menu.Start)
	snapshot("menu_title", playerGui:FindFirstChild("TitleMenu"))
	step("Menu.Slots", function()
		for _, f in playerGui:GetDescendants() do
			if f.Name == "Slots" and f:IsA("Frame") then
				f.Visible = true
			elseif (f.Name == "Title" or f.Name == "Edit") and f:IsA("Frame") then
				f.Visible = false
			end
		end
	end)
	snapshot("menu_slots", playerGui:FindFirstChild("TitleMenu"))
	step("Menu.Edit", function()
		Menu.Edit(1)
	end)
	snapshot("menu_edit", playerGui:FindFirstChild("TitleMenu"))
	step("Menu.Spin", Menu.Spin)
	step("Menu.BuySpins", Menu.BuySpins)
	snapshot("menu_buyspins", playerGui:FindFirstChild("TitleMenu"))
	step("Menu.Done", Menu.Done)
	step("Menu.Close", Menu.Close)
end
fs.writeFile(outDir .. "/index.json", serde.encode("json", { shots = shots, errors = errors, view = { VIEW.X, VIEW.Y }, topbar = TOPBAR }))
print(#errors == 0 and "UI HARNESS: NO RUNTIME ERRORS" or ("UI HARNESS ERRORS: " .. #errors))
if #errors > 0 then
	process.exit(1)
end
