-- Client bootstrap: starts UI + controllers and handles server pushes
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local State = require(script.State)
local Settings = require(script.Controllers.Settings)
local Audio = require(script.Controllers.Audio)
local UI = require(script.UI.UIKit)
local Panels = require(script.UI.Panels)
local HUD = require(script.UI.HUD)
local Combat = require(script.Controllers.Combat)
local Sailing = require(script.Controllers.Sailing)
local Builder = require(script.Controllers.Builder)
local VFX = require(script.Controllers.VFX)
local Readability = require(script.Controllers.Readability)
local Swim = require(script.Controllers.Swim)
local PetsCtl = require(script.Controllers.Pets)
local Titles = require(script.Controllers.Titles)
local Ocean = require(script.Controllers.Ocean)
local Atmos = require(script.Controllers.Atmos)
local GrassField = require(script.Controllers.GrassField)
local CreatureAnim = require(script.Controllers.CreatureAnim)
local CharAnim = require(script.Controllers.CharAnim)
local Interact = require(script.Controllers.Interact)
local ChartsView = require(script.Controllers.ChartsView)
local ShipBars = require(script.Controllers.ShipBars)
local Underwater = require(script.Controllers.Underwater)
local SerpentBody = require(script.Controllers.SerpentBody)
local Quest = require(script.UI.Quest)
local Menu = require(script.UI.Menu)
local PixelUI = require(script.UI.PixelUI)
local Heritage = require(script.Controllers.Heritage)
local Flight = require(script.Controllers.Flight)
local Crosshair = require(script.Controllers.Crosshair)
local HeritageAnim = require(script.Controllers.HeritageAnim)
local QuestPath = require(script.Controllers.QuestPath)
local WorldCull = require(script.Controllers.WorldCull)
local FruitFX = require(script.Controllers.FruitFX)
local Footsteps = require(script.Controllers.Footsteps)
local ShiftLock = require(script.Controllers.ShiftLock)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local panelForRole = {
	Blacksmith = "Refine",
	Shop = "Shop",
	Tavern = "Tavern",
	FastTravel = "FastTravel",
	Shipwright = "Shipwright",
	BossBoard = "BossBoard",
	JobMaster = "JobMaster",
	Guild = "Guild",
	Dungeon = "Dungeon",
	Stall = "Stall",
}

local settingsLoaded = false
local lastLevel
-- v0.25.14 knockdown overlay: red vignette, DOWNED + bleed-out countdown, GIVE UP button
local downedGui
local function showDowned(d)
	if downedGui then
		downedGui:Destroy()
		downedGui = nil
	end
	if not d.downed then
		return
	end
	local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	downedGui = Instance.new("ScreenGui")
	downedGui.Name = "Downed"
	downedGui.IgnoreGuiInset = true
	downedGui.ResetOnSpawn = true
	downedGui.DisplayOrder = 30
	downedGui.Parent = pg
	local vig = Instance.new("Frame")
	vig.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	vig.BackgroundTransparency = 0.7
	vig.Size = UDim2.fromScale(1, 1)
	vig.Parent = downedGui
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.fromScale(0.5, 0.2)
	box.Size = UDim2.fromOffset(520, 170)
	box.Parent = downedGui
	UI.List(box, nil, 8, Enum.HorizontalAlignment.Center)
	UI.Text(box, "DOWNED", 46, Color3.fromRGB(255, 90, 90), "Display", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 54) })
	local sub = UI.Text(box, "", 17, Color3.new(1, 1, 1), "Semi", { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 44) })
	UI.Button(box, "GIVE UP", UI.Theme.Red, UDim2.fromOffset(220, 44), function()
		Net.Request("GiveUp")
	end)
	local gui, t0 = downedGui, os.clock()
	task.spawn(function()
		while gui.Parent do
			local left = math.max(0, math.ceil((d.seconds or 25) - (os.clock() - t0)))
			sub.Text = "An ally can hold REVIVE on you. Bleeding out in " .. left .. "s"
			vig.BackgroundTransparency = 0.62 + 0.1 * math.sin(os.clock() * 4)
			task.wait(0.1)
		end
	end)
end

local handlers = {
	Downed = showDowned,
	Profile = function(d)
		State.profile = d.profile
		State.derived = d.derived
		if not settingsLoaded and d.profile.settings then
			settingsLoaded = true
			Settings.Load(d.profile.settings.client)
		end
		if lastLevel and d.profile.baseLevel > lastLevel then
			UI.Banner("Level Up!", "Base Lv." .. d.profile.baseLevel .. "  •  +stat points", UI.Theme.Gold, "Legendary")
		end
		lastLevel = d.profile.baseLevel
		State.Fire("profile")
	end,
	Toast = function(d)
		UI.Toast(d.text, d.kind)
	end,
	Announce = function(d)
		UI.Announce(d.text, d.rarity or (d.kind == "mvp" and "Legendary") or (d.kind == "boss" and "Mythic") or nil)
	end,
	Banner = function(d)
		-- short gameplay beats (waves, war start/end) use the green notice bar like Anime Vanguards
		if d.title and (d.title:find("WAVE") or d.title:find("BOSS") or d.title:find("WAR")) then
			UI.Notice(d.title .. (d.subtitle and ("  •  " .. d.subtitle) or ""), d.title:find("BOSS") and UI.Theme.Red or UI.Theme.Green)
		else
			UI.Banner(d.title, d.subtitle)
		end
	end,
	Loot = function(d)
		HUD.Loot(d)
	end,
	ExpGain = function(d)
		HUD.ExpGain(d)
	end,
	Quest = function(d)
		Quest.OnQuest(d)
	end,
	QuestComplete = function(d)
		Quest.OnComplete(d)
	end,
	QuestDialog = function(d)
		Quest.OnDialog(d)
	end,
	Notice = function(d)
		UI.Notice(d.text, UI.Theme[d.color or "Green"] or UI.Theme.Green)
	end,
	Achievement = function(d)
		UI.Banner("Achievement!", d.icon .. " " .. d.name .. (d.title and ("  •  title: " .. d.title) or ""), UI.Rarity.Get(d.rarity).color, d.rarity)
		UI.Toast("🏆 " .. d.name .. " unlocked: claim it in Quests (J)", "good")
	end,
	TitleUnlocked = function(d)
		local Rarity = require(ReplicatedStorage.Shared.Modules.Rarity)
		UI.Banner("New Title!", "« " .. tostring(d.name) .. " »  •  wear it from your Bag", Rarity.Get(d.tier or "Rare").color, d.tier)
	end,
	PearlGain = function(d)
		UI.Toast("+" .. d.amount .. " 💎 Gems" .. (d.capped and "  (daily cap reached)" or ""), "good")
	end,
	ChestOpened = function(d)
		Quest.OnChest(d)
	end,
	IslandDiscovered = function(d)
		UI.Banner(d.name, "🏝️ New island discovered!  •  " .. (d.subtitle or ""), UI.Theme.Gold, "Epic")
	end,
	Party = function(d)
		State.Set("party", d.members or {})
	end,
	Guild = function(d)
		State.Set("guild", d.guild)
	end,
	BossBoard = function(d)
		d.receivedAt = os.clock()
		State.Set("bossBoard", d)
	end,
	GuildWar = function(d)
		State.Set("guildWar", d)
	end,
	BuildState = function(d)
		Builder.OnState(d)
	end,
	StallState = function(d)
		State.Set("stall", d)
	end,
	OpenUI = function(d)
		local panel = panelForRole[d.panel]
		if panel then
			Panels.Open(panel, d)
		end
	end,
	Prompt = function(d)
		Audio.Play("Bell")
		UI.Confirm(d.text, function()
			Net.Request(d.kind == "Duel" and "DuelRespond" or "PartyRespond", { accept = true })
		end, function()
			Net.Request(d.kind == "Duel" and "DuelRespond" or "PartyRespond", { accept = false })
		end)
	end,
}

Net.OnPush(function(kind, data)
	local h = handlers[kind]
	if h then
		local ok, err = pcall(h, data or {})
		if not ok then
			warn("[Client] push", kind, err)
		end
	end
end)

-- every controller starts protected: one that errors or waits (for a folder, an asset) can never block the rest
-- (v0.13.0: the quest tracker vanished because it started after the animation controllers)
local function start(name, mod)
	local ok, err = pcall(mod.Start)
	if not ok then
		warn("[GrandVoyage] " .. name .. " failed to start: " .. tostring(err))
	end
end
-- v0.24.0: the voxel/pixel UI pass and the title menu come first (the menu hides every other GUI until Play)
start("PixelUI", PixelUI)
start("Menu", Menu)
-- core gameplay UI next, in order, on its own thread: with the title menu there is no character until Play, and a
-- controller waiting for one must never hold up the others
task.spawn(function()
	start("Settings", Settings)
	start("HUD", HUD)
	start("Combat", Combat)
	start("Quest", Quest)
end)
-- the rest (visuals, world feel) in parallel
for _, c in ipairs({
	{ "Sailing", Sailing }, { "Builder", Builder }, { "VFX", VFX }, { "Readability", Readability }, { "Swim", Swim },
	{ "Pets", PetsCtl }, { "Titles", Titles }, { "Ocean", Ocean }, { "Atmos", Atmos }, { "GrassField", GrassField },
	{ "CreatureAnim", CreatureAnim }, { "CharAnim", CharAnim }, { "Interact", Interact }, { "ChartsView", ChartsView }, { "ShipBars", ShipBars }, { "Underwater", Underwater }, { "SerpentBody", SerpentBody }, { "Heritage", Heritage }, { "Flight", Flight }, { "Crosshair", Crosshair }, { "HeritageAnim", HeritageAnim }, { "QuestPath", QuestPath }, { "WorldCull", WorldCull }, { "FruitFX", FruitFX }, { "Footsteps", Footsteps }, { "ShiftLock", ShiftLock },
}) do
	task.spawn(start, c[1], c[2])
end
local function entered()
	Net.Request("GetState")
	task.spawn(Net.Request, "GetBossBoard")
	task.delay(1.5, function()
		UI.Banner(GameConfig.GameName, GameConfig.SagaName .. "  •  Set sail across the " .. Islands.SeaName .. "!", UI.Theme.Gold, "Legendary")
	end)
end
if Menu.IsOpen then
	Menu.OnPlay = entered -- after PLAY on the title menu
else
	entered()
end
print("[GrandVoyage] client ready  v" .. GameConfig.Version, Players.LocalPlayer.Name)
