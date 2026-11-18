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
local handlers = {
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
-- core gameplay UI first, in order
start("Settings", Settings)
start("HUD", HUD)
start("Combat", Combat)
start("Quest", Quest)
-- the rest (visuals, world feel) in parallel
for _, c in ipairs({
	{ "Sailing", Sailing }, { "Builder", Builder }, { "VFX", VFX }, { "Readability", Readability }, { "Swim", Swim },
	{ "Pets", PetsCtl }, { "Titles", Titles }, { "Ocean", Ocean }, { "Atmos", Atmos }, { "GrassField", GrassField },
	{ "CreatureAnim", CreatureAnim }, { "CharAnim", CharAnim }, { "Interact", Interact }, { "ChartsView", ChartsView }, { "ShipBars", ShipBars }, { "Underwater", Underwater }, { "SerpentBody", SerpentBody },
}) do
	task.spawn(start, c[1], c[2])
end
Net.Request("GetState")
task.spawn(Net.Request, "GetBossBoard")

task.delay(1.5, function()
	UI.Banner(GameConfig.GameName, GameConfig.SagaName .. "  •  Set sail across the " .. Islands.SeaName .. "!", UI.Theme.Gold, "Legendary")
end)
print("[GrandVoyage] client ready  v" .. GameConfig.Version, Players.LocalPlayer.Name)
