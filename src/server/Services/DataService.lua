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
local Looks = require(Shared.Config.Looks)

local DataService = {}
local profiles = {}
local slotOf = {} -- player -> the character slot being played (v0.24.0)
local store
local useMemory = false
local memSlots = {} -- Studio without API access: userId -> { [slot] = data } (this session only)
local loadedEvent = Instance.new("BindableEvent")
-- fires (player, profile) once a character slot is loaded and the player enters the game
DataService.Loaded = loadedEvent.Event

-- slot 1 keeps the old single-save key so existing progress becomes "slot 1"
local function keyFor(userId, slot)
	if slot == 1 then
		return "p_" .. userId
	end
	return "p_" .. userId .. "_s" .. slot
end

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
		itemBar = { "MeatOnBone" }, -- quick item slots F1-F8 (item ids, "" = empty)
		classBars = {}, -- classId -> the skill bar you had in that class (restored when you switch back)
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
		look = Looks.Default(), -- character creator (Config/Looks)
		heritage = "Islander",
		heritageVariant = 1,
		heritageMode = "flame", -- Cinderwing only: "flame" (hits harder) | "calm" (moves faster)
		spins = Looks.Spins,
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
		warn("[DataService] DataStore unavailable: open the PUBLISHED place (File > Open from Roblox, not the local .rbxl) and enable Game Settings > Security > Studio Access to API Services. Using temporary data (nothing is saved).")
	end
end

function DataService.Load(player, slot)
	slot = slot or 1
	slotOf[player] = slot
	local key = keyFor(player.UserId, slot)
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
	if useMemory then
		memSlots[player.UserId] = memSlots[player.UserId] or {}
		data = memSlots[player.UserId][slot]
	end
	data = reconcile(data or template(), template())
	if useMemory then
		memSlots[player.UserId][slot] = data
	end
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
	-- v0.24.0: the old 5 x 11 starter "dinghy" was the size of a sloop; swap it for the new small one
	for i, sh in ipairs(data.ships or {}) do
		if sh.name == "Little Dinghy" and #(sh.parts or {}) == 63 then
			data.ships[i] = ShipStats.StarterDesign()
		end
	end
	if not loadedOk then
		-- Load failed: allow play but never overwrite the existing save
		data.__noSave = true
		warn("[DataService] could not load data for", player.Name, "- saving disabled this session")
	end
	profiles[player] = data
	return data
end

-- Dev tool (Settings -> Developer -> Reset to New Player): turn the loaded save into a brand-new one. The same table is
-- refilled so every service holding it sees the change. Kept: real-money records (receipts, perks: a Robux purchase must
-- never be granted twice) and the guild membership (guild member lists live in the guild store).
function DataService.ResetProfile(player)
	local data = profiles[player]
	if not data then
		return nil
	end
	local keep = { receipts = data.receipts, perks = data.perks, guildId = data.guildId, __noSave = data.__noSave, look = data.look, heritage = data.heritage, spins = data.spins }
	if data.guildId then
		keep.faction = data.faction
	end
	for k in pairs(data) do
		data[k] = nil
	end
	for k, v in pairs(template()) do
		data[k] = v
	end
	for k, v in pairs(keep) do
		data[k] = v
	end
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
	local key = keyFor(player.UserId, slotOf[player] or 1)
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
	slotOf[player] = nil
end

function DataService.Slot(player)
	return slotOf[player]
end

function DataService.FireLoaded(player)
	loadedEvent:Fire(player, profiles[player])
end

-- ===== account spin bank (bought Heritage spins, shared by every slot) =====
local memBank = {}
local function bankKey(userId)
	return "acct_" .. userId
end
function DataService.BankSpins(userId)
	if useMemory then
		return (memBank[userId] or {}).spins or 0
	end
	local ok, res = pcall(function()
		return store:GetAsync(bankKey(userId))
	end)
	return ok and res and res.spins or 0
end
-- add spins for a Robux receipt; idempotent on purchaseId. Returns true once the grant is stored.
function DataService.GrantBankSpins(userId, purchaseId, amount)
	if useMemory then
		local b = memBank[userId] or { spins = 0, receipts = {} }
		memBank[userId] = b
		if not b.receipts[purchaseId] then
			b.receipts[purchaseId] = true
			b.spins += amount
		end
		return true
	end
	local ok = pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.receipts = old.receipts or {}
			if old.receipts[purchaseId] then
				return old
			end
			old.receipts[purchaseId] = os.time()
			old.spins = (old.spins or 0) + amount
			return old
		end)
	end)
	return ok
end
-- take one spin from the bank; returns true when one was taken
function DataService.TakeBankSpin(userId)
	if useMemory then
		local b = memBank[userId]
		if b and b.spins > 0 then
			b.spins -= 1
			return true
		end
		return false
	end
	local took = false
	pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			if not old or (old.spins or 0) <= 0 then
				return nil
			end
			old.spins -= 1
			took = true
			return old
		end)
	end)
	return took
end
function DataService.RefundBankSpin(userId)
	if useMemory then
		local b = memBank[userId] or { spins = 0, receipts = {} }
		memBank[userId] = b
		b.spins += 1
		return
	end
	pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.spins = (old.spins or 0) + 1
			return old
		end)
	end)
end

-- ===== character slots (menu, before a slot is loaded) =====
-- A slot's summary for the menu cards
local function summary(data)
	if not data then
		return nil
	end
	return {
		look = Looks.Sanitize(data.look),
		heritage = data.heritage or "Islander",
		variant = data.heritageVariant or 1,
		spins = data.spins or 0,
		level = data.baseLevel or 1,
		class = data.class or "Brawler",
		jobLevel = data.jobLevel or 1,
		played = data.lastPlayed or 0,
	}
end

-- every slot of a player: { [1] = summary | false, ... } (reads each slot key; no session lock)
function DataService.ListSlots(player)
	local out = {}
	for slot = 1, Looks.Slots do
		local data
		if useMemory then
			data = memSlots[player.UserId] and memSlots[player.UserId][slot]
		else
			local ok, res = pcall(function()
				return store:GetAsync(keyFor(player.UserId, slot))
			end)
			if not ok then
				return nil, "Could not read your characters, try again"
			end
			data = res and res.data
		end
		out[slot] = summary(data) or false
	end
	return out
end

-- change a slot that is NOT being played (look, Heritage spin, or create it). fn(data) edits the table in place.
-- Returns the slot's new summary.
function DataService.EditSlot(player, slot, fn)
	if profiles[player] then
		return nil, "Already in game"
	end
	if useMemory then
		memSlots[player.UserId] = memSlots[player.UserId] or {}
		local data = memSlots[player.UserId][slot] or template()
		reconcile(data, template())
		local ok, err = pcall(fn, data)
		if not ok then
			return nil, err
		end
		memSlots[player.UserId][slot] = data
		return summary(data)
	end
	local result, failure
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player.UserId, slot), function(old)
			old = old or {}
			if old.lock and old.lock ~= game.JobId and os.time() - (old.lockTime or 0) < 600 then
				failure = "This character is still in use on another server"
				return nil
			end
			local data = reconcile(old.data or template(), template())
			local okFn, e = pcall(fn, data)
			if not okFn then
				failure = tostring(e)
				return nil
			end
			old.data = data
			result = summary(data)
			return old
		end)
	end)
	if not ok then
		warn("[DataService] slot edit failed", player.Name, err)
		return nil, "Save failed, try again"
	end
	if failure then
		return nil, failure
	end
	return result
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
