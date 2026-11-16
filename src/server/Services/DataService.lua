-- DataService: player save/load via DataStore (simple session lock + autosave)
-- Without Studio API access enabled, falls back to in-memory data (nothing is saved)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ShipStats = require(Shared.Modules.ShipStats)
local Islands = require(Shared.Config.Islands)

local DataService = {}
local profiles = {}
local store
local useMemory = false

local function template()
	return {
		version = 1,
		class = "Brawler",
		classProgress = {}, -- classId -> { jobLevel, jobExp } for classes you switched away from
		classSwitches = 0,
		baseLevel = 1,
		baseExp = 0,
		jobLevel = 1,
		jobExp = 0,
		statPoints = 5,
		skillPoints = 1,
		stats = { STR = 1, AGI = 1, VIT = 1, INT = 1, DEX = 1, LUK = 1 },
		skills = { Bash = 1, FirstAid = 1 },
		skillBar = { "Bash", "FirstAid" },
		autoSkills = { Bash = true },
		beli = GameConfig.StartBeli,
		inventory = {
			{ uid = "starter_w", id = "Knuckles_Plain", qty = 1, refine = 0, cards = {} },
			{ uid = "starter_a", id = "SailorVest", qty = 1, refine = 0, cards = {} },
			{ uid = "starter_m", id = "MeatOnBone", qty = 10 },
			{ uid = "starter_wood", id = "Wood", qty = 40 },
			{ uid = "starter_cloth", id = "SailCloth", qty = 6 },
		},
		equipment = { weapon = "starter_w", armor = "starter_a" },
		faction = "None",
		guildId = nil,
		bounty = 0,
		merit = 0,
		ships = { ShipStats.StarterDesign() },
		activeShip = 1,
		shipSunk = false,
		crew = 2,
		unlocked = { [Islands.StartIsland] = true },
		lastIsland = Islands.StartIsland,
		dungeonCooldowns = {},
		quest = { step = 1, progress = 0 }, -- main story (Config/Quests)
		chests = {}, -- exploration chests opened (chest id -> true)
		settings = { autoPotionPct = 35, autoPotionItem = "MeatOnBone" },
		created = os.time(),
	}
end

-- Fill missing fields (for new data added in later updates)
local function reconcile(data, tpl)
	for k, v in pairs(tpl) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

function DataService.NewUid()
	return HttpService:GenerateGUID(false)
end

function DataService.Init()
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
		store:GetAsync("__probe")
	end)
	if not ok then
		useMemory = true
		warn("[DataService] DataStore unavailable (enable Game Settings > Security > Studio Access to API Services). Using temporary data.")
	end
end

function DataService.Load(player)
	local key = "p_" .. player.UserId
	local data
	local loadedOk = useMemory
	if not useMemory then
		for attempt = 1, 5 do
			local locked = false
			local ok, err = pcall(function()
				store:UpdateAsync(key, function(old)
					old = old or {}
					-- Session lock: if another server holds a lock younger than 10 minutes, wait (last attempt steals it)
					if old.lock and old.lock ~= game.JobId and os.time() - (old.lockTime or 0) < 600 and attempt < 5 then
						locked = true
						return nil
					end
					old.lock = game.JobId
					old.lockTime = os.time()
					data = old.data
					return old
				end)
			end)
			if ok and not locked then
				loadedOk = true
				break
			end
			warn("[DataService] load retry", attempt, err or "session locked")
			task.wait(math.min(2 ^ attempt, 10))
			if not player.Parent then
				return nil
			end
		end
	end
	data = reconcile(data or template(), template())
	-- v2: the old "Novice" (Cabin Boy) starter class became the Brawler; give old saves a pair of knuckles
	if data.class == "Novice" then
		data.class = "Brawler"
		local uid = "migr_knuckles"
		local has = false
		for _, e in ipairs(data.inventory) do
			if e.uid == uid then
				has = true
			end
		end
		if not has then
			table.insert(data.inventory, { uid = uid, id = "Knuckles_Plain", qty = 1, refine = 0, cards = {} })
		end
		data.equipment.weapon = uid
	end
	if not loadedOk then
		-- Load failed: allow play but never overwrite the existing save
		data.__noSave = true
		warn("[DataService] could not load data for", player.Name, "- saving disabled this session")
	end
	profiles[player] = data
	return data
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Save(player, release)
	local data = profiles[player]
	if not data or data.__noSave then
		return false
	end
	if useMemory then
		return true -- Studio without API access: nothing to save
	end
	local key = "p_" .. player.UserId
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			old = old or {}
			if old.lock and old.lock ~= game.JobId then
				return nil -- another server owns this save; do not overwrite
			end
			old.data = data
			old.lock = (not release) and game.JobId or nil
			old.lockTime = os.time()
			return old
		end)
	end)
	if not ok then
		warn("[DataService] save failed", player.Name, err)
	end
	return ok
end

function DataService.Release(player)
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutoSaveInterval)
			for _, p in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, p, false)
			end
		end
	end)
	game:BindToClose(function()
		local threads = 0
		for _, p in ipairs(Players:GetPlayers()) do
			threads += 1
			task.spawn(function()
				DataService.Save(p, true)
				threads -= 1
			end)
		end
		local t = os.clock()
		while threads > 0 and os.clock() - t < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
