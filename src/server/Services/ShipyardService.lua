-- ShipyardService: free-form ship building (v0.25.152: v2 node hulls + free items, Modules/ShipHull) + presets
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ShipPartsCfg = require(Shared.Config.ShipParts)
local ShipStats = require(Shared.Modules.ShipStats)
local ShipModel = require(Shared.Modules.ShipModel)
local Net = require(Shared.Modules.Net)
local ShipPresets = require(Shared.Config.ShipPresets)
local ShipHull = require(Shared.Modules.ShipHull)

local ShipParts = ShipPartsCfg.Parts
local Yard = {}
local R
local sessions = {} -- player -> { plot, slot, model }
local plotOwner = {} -- plot -> player
local cfg = GameConfig.Ship
local MAX_SLOTS = 3

function Yard.Init(registry)
	R = registry
end

local function design(player, slot)
	local p = R.DataService.Get(player)
	return p.ships[slot]
end

local function statsFor(player, d)
	local p = R.DataService.Get(player)
	local derived = R.PlayerService.Derived(player) or {}
	return ShipStats.Compute(d, p.crew, { shipSpeed = derived.shipSpeed, shipHp = derived.shipHp })
end

-- v0.25.152: the builder edits a local copy and previews it on the client (free-form v2 designs), so nothing is
-- built on the slip here; the state push carries the saved design
local function render(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = design(player, s.slot)
	local st = statsFor(player, d)
	Net.Push(player, "BuildState", {
		active = true,
		origin = s.plot.origin,
		slot = s.slot,
		design = d,
		stats = { hp = st.hp, cannons = #st.cannons, crewCap = st.crewCap, crew = st.crew, speedLane = math.floor(ShipStats.Speed(st, 1)), valid = st.valid, problem = st.problem },
	})
end

function Yard.ExitBuild(player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.model then
		s.model:Destroy()
	end
	plotOwner[s.plot] = nil
	sessions[player] = nil
	if player.Parent then
		Net.Push(player, "BuildState", { active = false })
	end
end

local testing = {} -- v0.25.155 (#21): player -> { slot, standCf } while a test sail is out

local function enter(player, slot)
	local p = R.DataService.Get(player)
	if R.ShipService.GetShipOf(player) then
		return false, "Dock your ship before editing"
	end
	local plot = R.WorldBuilder.FreePlotNear(player, plotOwner)
	if not plot then
		return false, "Go to a shipyard with a free slip"
	end
	Yard.ExitBuild(player)
	if not p.ships[slot] then
		-- v0.25.154 (owner review of the first build): an empty slot starts as a free Dinghy that can sail at once
		-- (it used to be a bare hull with a helm and no sail)
		p.ships[slot] = ShipPresets.Starter("Ship " .. slot)
	elseif ShipPresets.IsOld(p.ships[slot]) then
		-- an old grid ship (DataService rebuilds them on load; this catches one that slipped through)
		p.ships[slot] = ShipPresets.Rebuild(p.ships[slot])
	end
	p.activeShip = slot
	sessions[player] = { plot = plot, slot = slot }
	plotOwner[plot] = player
	R.PlayerService.TeleportTo(player, plot.standCf)
	render(player)
	R.PlayerService.MarkDirty(player)
	return true
end

local function setup()
	Net.Handle("BuildEnter", function(player, data)
		local p = R.DataService.Get(player)
		return enter(player, math.clamp(math.floor(tonumber(type(data) == "table" and data.slot) or p.activeShip or 1), 1, MAX_SLOTS))
	end, 1)

	-- v0.25.155 (Plan-Ships-v2 #21): TEST SAIL the design you are editing, unsaved and unpaid, from the yard's dock.
	-- It cannot be hurt, fights nobody and stays near the yard (ShipService.Launch testDesign); the wind is yours to
	-- set (ShipTestWind). TestSailEnd puts you back in the builder with your edits.
	Net.Handle("TestSail", function(player, data)
		local s = sessions[player]
		if not s then
			return false, "Not in build mode"
		end
		local p = R.DataService.Get(player)
		local clean, msg = ShipHull.Sanitize(type(data) == "table" and data.design, p.faction)
		if not clean then
			return false, msg
		end
		clean.name = design(player, s.slot).name
		local st = statsFor(player, clean)
		if not st.valid then
			return false, st.problem or "This ship cannot sail yet"
		end
		local dock = R.WorldBuilder.NearestDock(s.plot.part.Position)
		if not dock then
			return false, "No dock near this yard"
		end
		local slot, standCf = s.slot, s.plot.standCf
		Yard.ExitBuild(player)
		local ok, why = R.ShipService.Launch(player, slot, dock.launchCf, clean)
		if not ok then
			enter(player, slot)
			return false, why
		end
		testing[player] = { slot = slot, standCf = standCf }
		return true
	end, 2)

	Net.Handle("TestSailEnd", function(player)
		local t = testing[player]
		testing[player] = nil
		R.ShipService.EndTest(player)
		if not t then
			return false, "No test sail out"
		end
		R.PlayerService.TeleportTo(player, t.standCf)
		task.wait(0.3)
		return enter(player, t.slot)
	end, 1)

	Net.Handle("BuildExit", function(player)
		Yard.ExitBuild(player)
		return true
	end, 0.5)

	-- the whole edited design at once: sanitized, then only the cost difference is paid (or refunded) against what
	-- already went into this ship (design.paid)
	Net.Handle("BuildSave", function(player, data)
		local s = sessions[player]
		if not s then
			return false, "Not in build mode"
		end
		local p = R.DataService.Get(player)
		local old = design(player, s.slot)
		local clean, msg = ShipHull.Sanitize(data.design, p.faction)
		if not clean then
			return false, msg
		end
		clean.name = old.name
		local cost = ShipHull.Cost(clean)
		local pay, refund, gift = ShipHull.Delta(cost, old.paid or ShipHull.Cost(old), old.gift)
		if next(pay) then
			local ok, why = R.InventoryService.Pay(player, pay)
			if not ok then
				return false, why
			end
		end
		if next(refund) then
			R.InventoryService.Refund(player, refund)
		end
		clean.paid = cost
		clean.gift = next(gift) and gift or nil
		p.ships[s.slot] = clean
		p.shipSunk = p.shipSunk and s.slot == p.activeShip
		R.PlayerService.MarkDirty(player)
		render(player)
		return true
	end, 0.5)

	Net.Handle("BuildRename", function(player, data)
		local s = sessions[player]
		local name = type(data.name) == "string" and data.name:sub(1, 24) or ""
		if not s or #name < 1 then
			return false
		end
		local ok, filtered = pcall(function()
			return game:GetService("TextService"):FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		design(player, s.slot).name = ok and filtered or "Ship"
		render(player)
		R.PlayerService.MarkDirty(player)
		return true
	end, 2)

	-- v0.25.154 (#14): saved paint themes (up to 8 color sets on the profile), list / save / delete
	Net.Handle("ShipTheme", function(player, data)
		local p = R.DataService.Get(player)
		p.shipThemes = type(p.shipThemes) == "table" and p.shipThemes or {}
		local list = p.shipThemes
		local op = type(data) == "table" and data.op
		if op == "save" then
			if #list >= 8 then
				return false, "8 themes at most: delete one first"
			end
			local t = {}
			for _, z in ipairs(ShipHull.Zones) do
				local hex = type(data.paint) == "table" and data.paint[z]
				if type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then
					return false, "Bad colors"
				end
				t[z] = hex:upper()
			end
			table.insert(list, t)
			R.PlayerService.MarkDirty(player)
		elseif op == "delete" then
			local i = math.floor(tonumber(data.i) or 0)
			if not list[i] then
				return false, "No such theme"
			end
			table.remove(list, i)
			R.PlayerService.MarkDirty(player)
		end
		return true, nil, list
	end, 0.4)

end

-- v0.25.150 (owner): buy a ready-made Dinghy / Sloop / Galleon at the Shipwright. It costs its blocks, goes into the
-- slot you pick and replaces what was there (that ship's parts are refunded first, like deleting them one by one).
local function setupPresets()
	local problems = ShipPresets.Check()
	for _, msg in ipairs(problems) do
		warn("[ShipPresets] " .. msg)
	end
	Net.Handle("BuyShipPreset", function(player, data)
		local preset = type(data) == "table" and ShipPresets.ById[data.id]
		local slot = type(data) == "table" and math.floor(tonumber(data.slot) or 0)
		if not preset or not slot or slot < 1 or slot > MAX_SLOTS then
			return false, "Pick a ship and a slot"
		end
		if not R.WorldBuilder.NearNPC(player, "Shipwright", 40) then
			return false, "Talk to a Shipwright"
		end
		if R.ShipService.GetShipOf(player) then
			return false, "Put your ship away first (MENU > Ships)"
		end
		if sessions[player] then
			return false, "Leave the builder first"
		end
		local p = R.DataService.Get(player)
		local ok, msg = R.InventoryService.Pay(player, ShipPresets.Cost(preset.design))
		if not ok then
			return false, msg
		end
		local old = p.ships[slot]
		if old and old.v == 2 then
			R.InventoryService.Refund(player, ShipHull.RealPaid(old)) -- a free boat's gift is not paid out
		elseif old then
			for _, part in ipairs(old.parts or {}) do
				local def = ShipParts[part.id]
				if def then
					R.InventoryService.Refund(player, def.cost)
				end
			end
		end
		local d = ShipHull.Clone(preset.design)
		d.paid = ShipHull.Cost(d) -- as if its materials were paid (they were, in Doubloons)
		p.ships[slot] = d
		p.activeShip = slot
		p.shipSunk = false
		R.PlayerService.MarkDirty(player)
		return true, preset.name .. " is yours! Edit it any time here"
	end, 1)
end

function Yard.Start()
	setup()
	setupPresets()
	Players.PlayerRemoving:Connect(function(player)
		testing[player] = nil
		Yard.ExitBuild(player)
	end)
end

return Yard
