-- Server bootstrap: require every service, then Init -> Start in order
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Services = script.Services
local registry = {
	WorldBuilder = require(script.World.WorldBuilder),
}
local order = {
	"AssetService",
	"DataService",
	"PlayerService",
	"OriginService",
	"MasteryService",
	"TalentService",
	"InventoryService",
	"CombatService",
	"KnockdownService",
	"GuardService",
	"WeaponService",
	"MonsterService",
	"PartyService",
	"PvPService",
	"BossService",
	"DungeonService",
	"GuildService",
	"GuildWarService",
	"ShipyardService",
	"ShipService",
	"RecruitService",
	"MarketService",
	"QuestService",
	"ChestService",
	"FruitService",
	"TokiService",
	"PearlService",
	"StoreService",
	"PetService",
	"ProgressService",
	"TitleService",
	"MarineService",
}
for _, name in ipairs(order) do
	registry[name] = require(Services[name])
end

Net.Get("Request") -- creates remotes
local t0 = os.clock()
registry.WorldBuilder.Init(registry)
print(string.format("[GrandVoyage] world built in %.2fs", os.clock() - t0))
for _, name in ipairs(order) do
	registry[name].Init(registry)
end
Net.StartServer()
for _, name in ipairs(order) do
	local ok, err = pcall(registry[name].Start)
	if not ok then
		warn("[GrandVoyage] " .. name .. ".Start failed: " .. tostring(err))
	end
end
print("[GrandVoyage] server ready  v" .. require(ReplicatedStorage.Shared.Config.GameConfig).Version)
