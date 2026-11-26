-- DataService: player save/load via DataStore (simple session lock + autosave)
-- Without Studio API access enabled, falls back to in-memory data (nothing is saved)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ShipStats = require(Shared.Modules.ShipStats)
local ShipHull = require(Shared.Modules.ShipHull)
local Islands = require(Shared.Config.Islands)
local Looks = require(Shared.Config.Looks)

local DataService = {}
local profiles = {}
local slotOf = {} -- player -> the character slot being played (v0.24.0)
local store
local useMemory = false
local memSlots = {} -- Studio without API access: userId -> { [slot] = data } (this session only)
-- v0.24.12 menu cache: a DataStore key takes one write per ~6 s, so writing every Heritage spin made quick respins
-- queue up for seconds. Menu edits (look, spins) now change a cached copy of the slot and are written in the
-- background (FlushMenu: at most every WRITE_GAP s per key, before the slot is loaded to play, on leave/shutdown).
local menuCache = {} -- player -> { [slot] = { data = table, dirty = bool, lastWrite = clock } }
local WRITE_GAP = 6.5
local bankKnown, bankTake = {}, {} -- userId -> spins on record / spins taken but not written yet
local unlockedKnown = {} -- "userId:slot" -> true (a bought slot unlock is permanent)
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
		crew = 0, -- v0.25.142: new players recruit their first sailors (tutorial step) instead of starting with 2
		recruits = {}, -- v0.25.142: named crew (Config/Recruits); crew - #recruits = old unnamed deckhands
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
	-- menu edits of THIS slot ride along with the load write (one write, no 6 s key gap); the rest is flushed now
	local pend = menuCache[player] and menuCache[player][slot]
	local pendDirty = pend ~= nil and pend.dirty
	if pend then
		pend.dirty = false
	end
	DataService.FlushMenu(player, true)
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
					if pendDirty then
						old.data = pend.data
					end
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
	-- v0.25.51 (owner: Navigator was too strong): its storm skills became baton tricks (the storms return with the
	-- Storm Caller second job); learned levels and hotbar slots follow the new ids
	-- v0.25.65 fruit v2 (docs/Plan-Fruits-v2.md): replaced fruit skills keep their hotbar slot
	local RENAMED = { ThunderCall = "BatonFlurry", CycloneCall = "TrickVault", F_FireDash = "F_Emberflies", F_SmokeBody = "F_SmokeFist", F_SplitEscape = "F_SplitRunner", F_BarrierCrash = "F_GlassStairs" }
	local bars = { data.skillBar }
	for _, bar in pairs(data.classBars or {}) do
		table.insert(bars, bar)
	end
	for old, new in pairs(RENAMED) do
		if data.skills and data.skills[old] then
			data.skills[new] = math.max(data.skills[new] or 0, data.skills[old])
			data.skills[old] = nil
		end
		for _, bar in ipairs(bars) do
			for i, id in ipairs(bar) do
				if id == old then
					bar[i] = new
				end
			end
		end
	end
	-- v0.25.148 (owner): crew starts at 0: the old unnamed deckhands are gone, only recruited sailors count
	if not data.crewV2 then
		data.crewV2 = true
		data.crew = #(data.recruits or {})
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
	-- v0.25.153: rudders became required; free-form ships saved before get one at the stern
	for _, sh in ipairs(data.ships or {}) do
		pcall(ShipHull.EnsureRudder, sh)
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
-- account record: { spins, receipts, slots = { [slotIndex] = true } } (bought slot unlocks)
function DataService.Account(userId)
	if useMemory then
		return memBank[userId] or { spins = 0, receipts = {}, slots = {} }
	end
	local ok, res = pcall(function()
		return store:GetAsync(bankKey(userId))
	end)
	return (ok and res) or { spins = 0, receipts = {}, slots = {} }
end
-- Store boosts are ACCOUNT-wide (v0.24.14, owner): { exp = untilTime, drop = ..., fruit = ... } on acct_<id>,
-- cached for the session
local acctBoosts = {}
function DataService.Boosts(userId)
	if not acctBoosts[userId] then
		if useMemory then
			memBank[userId] = memBank[userId] or { spins = 0, receipts = {}, slots = {} }
			memBank[userId].boosts = memBank[userId].boosts or {}
			acctBoosts[userId] = memBank[userId].boosts
		else
			local acc = DataService.Account(userId)
			acctBoosts[userId] = acc.boosts or {}
		end
	end
	return acctBoosts[userId]
end
-- add `seconds` to a boost (stacks on the time left); returns true once stored
function DataService.AddBoost(userId, kind, seconds)
	local b = DataService.Boosts(userId)
	b[kind] = math.max(b[kind] or 0, os.time()) + seconds
	if useMemory then
		return true
	end
	local untilT = b[kind]
	return pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.boosts = old.boosts or {}
			old.boosts[kind] = math.max(old.boosts[kind] or 0, untilT)
			return old
		end)
	end)
end
function DataService.DropAccountCache(userId)
	acctBoosts[userId] = nil
end

function DataService.SlotUnlocked(userId, slot)
	local SpinsCfg = require(Shared.Config.Spins)
	local locked = SpinsCfg.SlotUnlock and table.find(SpinsCfg.SlotUnlock.slots, slot)
	if not locked then
		return true
	end
	if unlockedKnown[userId .. ":" .. slot] then
		return true
	end
	local acc = DataService.Account(userId)
	local open = acc.slots ~= nil and acc.slots[tostring(slot)] == true
	if open then
		unlockedKnown[userId .. ":" .. slot] = true
	end
	return open
end
-- unlock slots for a Robux receipt (idempotent on purchaseId)
function DataService.GrantSlots(userId, purchaseId, slotList)
	if useMemory then
		local b = memBank[userId] or { spins = 0, receipts = {}, slots = {} }
		memBank[userId] = b
		b.slots = b.slots or {}
		for _, sl in ipairs(slotList) do
			b.slots[tostring(sl)] = true
		end
		return true
	end
	return pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.receipts = old.receipts or {}
			old.slots = old.slots or {}
			if old.receipts[purchaseId] then
				return old
			end
			old.receipts[purchaseId] = os.time()
			for _, sl in ipairs(slotList) do
				old.slots[tostring(sl)] = true
			end
			return old
		end)
		for _, sl in ipairs(slotList) do
			unlockedKnown[userId .. ":" .. sl] = true
		end
	end)
end

function DataService.BankSpins(userId)
	if useMemory then
		return (memBank[userId] or {}).spins or 0
	end
	if bankKnown[userId] == nil then
		local ok, res = pcall(function()
			return store:GetAsync(bankKey(userId))
		end)
		if not ok then
			return 0
		end
		bankKnown[userId] = res and res.spins or 0
	end
	return math.max(0, bankKnown[userId] - (bankTake[userId] or 0))
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
	local stored
	local ok = pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.receipts = old.receipts or {}
			if old.receipts[purchaseId] then
				stored = old.spins or 0
				return old
			end
			old.receipts[purchaseId] = os.time()
			old.spins = (old.spins or 0) + amount
			stored = old.spins
			return old
		end)
	end)
	if ok and stored then
		bankKnown[userId] = stored -- the record now (spins taken here but not written are still in bankTake)
	end
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
	if DataService.BankSpins(userId) <= 0 then
		return false
	end
	bankTake[userId] = (bankTake[userId] or 0) + 1 -- written by FlushBank
	return true
end
function DataService.RefundBankSpin(userId)
	if useMemory then
		local b = memBank[userId] or { spins = 0, receipts = {} }
		memBank[userId] = b
		b.spins += 1
		return
	end
	if (bankTake[userId] or 0) > 0 then
		bankTake[userId] -= 1
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
-- write the spins taken from the bank since the last write
local bankWrite = {}
function DataService.FlushBank(userId)
	local take = bankTake[userId] or 0
	if useMemory or take <= 0 then
		return true
	end
	local stored
	local ok = pcall(function()
		store:UpdateAsync(bankKey(userId), function(old)
			old = old or { spins = 0, receipts = {} }
			old.spins = math.max(0, (old.spins or 0) - take)
			stored = old.spins
			return old
		end)
	end)
	bankWrite[userId] = os.clock()
	if ok then
		bankTake[userId] = math.max(0, (bankTake[userId] or 0) - take)
		bankKnown[userId] = stored
	end
	return ok
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
		local cached = menuCache[player] and menuCache[player][slot]
		if useMemory then
			data = memSlots[player.UserId] and memSlots[player.UserId][slot]
		elseif cached then
			data = cached.data
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
	menuCache[player] = menuCache[player] or {}
	local c = menuCache[player][slot]
	if not c then
		-- first touch of this slot in the menu: read it once (and respect another server's session lock)
		local ok, old = pcall(function()
			return store:GetAsync(keyFor(player.UserId, slot))
		end)
		if not ok then
			warn("[DataService] slot read failed", player.Name, old)
			return nil, "Could not read your character, try again"
		end
		old = old or {}
		if old.lock and old.lock ~= game.JobId and os.time() - (old.lockTime or 0) < 600 then
			return nil, "This character is still in use on another server"
		end
		c = { data = reconcile(old.data or template(), template()), dirty = false, lastWrite = 0, fresh = old.data == nil }
		menuCache[player][slot] = c
	end
	local okFn, e = pcall(fn, c.data)
	if not okFn then
		return nil, tostring(e)
	end
	c.dirty = true
	if c.fresh then
		-- a brand-new slot is written right away so it exists even if the server stops
		c.fresh = false
		task.spawn(DataService.FlushMenu, player)
	end
	return summary(c.data)
end

-- write dirty cached menu slots (+ the bank). now = true ignores the per-key write gap (play / leave / shutdown)
local flushing = {}
function DataService.FlushMenu(player, now)
	if flushing[player] then
		if not now then
			return true -- the background pass is already writing
		end
		local t = os.clock()
		while flushing[player] and os.clock() - t < 12 do
			task.wait(0.1)
		end
	end
	flushing[player] = true
	local cache = menuCache[player]
	local ok = true
	if cache and not useMemory then
		for slot, c in pairs(cache) do
			if c.dirty and (now or os.clock() - c.lastWrite >= WRITE_GAP) then
				c.dirty = false
				c.lastWrite = os.clock()
				local data = c.data
				local fine, err = pcall(function()
					store:UpdateAsync(keyFor(player.UserId, slot), function(old)
						old = old or {}
						if old.lock and old.lock ~= game.JobId and os.time() - (old.lockTime or 0) < 600 then
							return nil
						end
						old.data = data
						return old
					end)
				end)
				if not fine then
					c.dirty = true
					ok = false
					warn("[DataService] menu slot write failed", player.Name, err)
				end
			end
		end
	end
	if now or os.clock() - (bankWrite[player.UserId] or 0) >= WRITE_GAP then
		ok = DataService.FlushBank(player.UserId) and ok
	end
	if now then
		menuCache[player] = nil -- the next menu edit reads the slot again (it may be played meanwhile)
	end
	flushing[player] = nil
	return ok
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			for _, pl in ipairs(Players:GetPlayers()) do
				if menuCache[pl] or (bankTake[pl.UserId] or 0) > 0 then
					task.spawn(DataService.FlushMenu, pl, false)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		DataService.FlushMenu(pl, true)
		bankKnown[pl.UserId], bankTake[pl.UserId], bankWrite[pl.UserId] = nil, nil, nil
		acctBoosts[pl.UserId] = nil
	end)
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
				DataService.FlushMenu(p, true)
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
