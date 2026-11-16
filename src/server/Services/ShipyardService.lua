-- ShipyardService: free-form grid ship building + crew hiring
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ShipPartsCfg = require(Shared.Config.ShipParts)
local ShipStats = require(Shared.Modules.ShipStats)
local ShipModel = require(Shared.Modules.ShipModel)
local Net = require(Shared.Modules.Net)

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

local function render(player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.model then
		s.model:Destroy()
	end
	local d = design(player, s.slot)
	s.model = ShipModel.BuildDesign(d, s.plot.origin)
	s.model.Name = "Build_" .. player.Name
	s.model.Parent = s.plot.folder
	local st = statsFor(player, d)
	Net.Push(player, "BuildState", {
		active = true,
		origin = s.plot.origin,
		slot = s.slot,
		design = d,
		stats = {
			weight = st.weight,
			hp = st.hp,
			thrust = st.thrust,
			oars = st.oars,
			cannons = #st.cannons,
			crewCap = st.crewCap,
			crew = st.crew,
			parts = st.partCount,
			speedLane = math.floor(ShipStats.Speed(st, 1)),
			speedCalm = math.floor(ShipStats.Speed(st, 0)),
			valid = st.valid,
		},
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

local function inBounds(v)
	local size = cfg.PlotSize
	return v.X >= 0 and v.Y >= 0 and v.Z >= 0 and v.X < size.X and v.Y < size.Y and v.Z < size.Z
end

local function occupancy(d)
	local occ = {}
	for i, p in ipairs(d.parts) do
		if ShipParts[p.id] then
			for _, c in ipairs(ShipStats.Cells(p)) do
				occ[ShipStats.CellKey(c)] = i
			end
		end
	end
	return occ
end

local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }

local function setup()
	Net.Handle("BuildEnter", function(player, data)
		local p = R.DataService.Get(player)
		local slot = math.clamp(math.floor(tonumber(data.slot) or p.activeShip or 1), 1, MAX_SLOTS)
		if R.ShipService.GetShipOf(player) then
			return false, "Dock your ship before editing"
		end
		local plot = R.WorldBuilder.FreePlotNear(player, plotOwner)
		if not plot then
			return false, "Go to a shipyard with a free slip"
		end
		Yard.ExitBuild(player)
		if not p.ships[slot] then
			p.ships[slot] = { name = "Ship " .. slot, parts = { { id = "Helm", x = 4, y = 0, z = 6, r = 0 } } }
		end
		p.activeShip = slot
		sessions[player] = { plot = plot, slot = slot }
		plotOwner[plot] = player
		R.PlayerService.TeleportTo(player, plot.standCf)
		render(player)
		R.PlayerService.MarkDirty(player)
		return true
	end, 1)

	Net.Handle("BuildExit", function(player)
		Yard.ExitBuild(player)
		return true
	end, 0.5)

	Net.Handle("BuildPlace", function(player, data)
		local s = sessions[player]
		if not s then
			return false, "Not in build mode"
		end
		local def = ShipParts[data.id]
		if not def then
			return false, "Invalid part"
		end
		local p = R.DataService.Get(player)
		local d = design(player, s.slot)
		local np = {
			id = def.id,
			x = math.floor(tonumber(data.x) or -1),
			y = math.floor(tonumber(data.y) or -1),
			z = math.floor(tonumber(data.z) or -1),
			r = math.floor(tonumber(data.r) or 0) % 4,
		}
		if #d.parts >= cfg.MaxParts then
			return false, "Part limit reached (" .. cfg.MaxParts .. ")"
		end
		if def.faction and p.faction ~= def.faction then
			return false, "Only for the " .. def.faction .. " faction"
		end
		if def.max then
			local n = 0
			for _, q in ipairs(d.parts) do
				if q.id == def.id then
					n += 1
				end
			end
			if n >= def.max then
				return false, "Max " .. def.max .. " of this part"
			end
		end
		local occ = occupancy(d)
		local cells = ShipStats.Cells(np)
		local touching = #d.parts == 0
		for _, c in ipairs(cells) do
			if not inBounds(c) then
				return false, "Outside the slip"
			end
			if occ[ShipStats.CellKey(c)] then
				return false, "Overlaps another part"
			end
			for _, dir in ipairs(dirs) do
				if occ[ShipStats.CellKey(c + dir)] then
					touching = true
				end
			end
		end
		if not touching then
			return false, "Must touch another part"
		end
		local ok, msg = R.InventoryService.Pay(player, def.cost)
		if not ok then
			return false, msg
		end
		table.insert(d.parts, np)
		render(player)
		return true
	end, 0.06)

	Net.Handle("BuildRemove", function(player, data)
		local s = sessions[player]
		if not s then
			return false
		end
		local d = design(player, s.slot)
		local key = ShipStats.CellKey(Vector3.new(math.floor(tonumber(data.x) or -1), math.floor(tonumber(data.y) or -1), math.floor(tonumber(data.z) or -1)))
		local idx = occupancy(d)[key]
		if not idx then
			return false
		end
		local removed = table.remove(d.parts, idx)
		R.InventoryService.Refund(player, ShipParts[removed.id].cost)
		render(player)
		return true
	end, 0.06)

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

	Net.Handle("RecruitCrew", function(player, data)
		local p = R.DataService.Get(player)
		if not R.WorldBuilder.NearNPC(player, "Tavern") then
			return false, "Hire crew at a tavern"
		end
		local d = p.ships[p.activeShip] or p.ships[1]
		local st = ShipStats.Compute(d, p.crew)
		local count = math.clamp(math.floor(tonumber(data.count) or 1), 1, 20)
		if p.crew + count > st.crewCap then
			return false, "Not enough bunks (max " .. st.crewCap .. "). Build more Crew Cabins."
		end
		local cost = cfg.CrewCost * count * (1 + math.floor(p.crew / 4) * 0.5)
		if not R.PlayerService.AddBeli(player, -math.floor(cost)) then
			return false, "Not enough Doubloons (🪙" .. math.floor(cost) .. ")"
		end
		p.crew += count
		player:SetAttribute("Crew", p.crew)
		R.PlayerService.MarkDirty(player)
		return true, "Hired +" .. count .. " crew (total " .. p.crew .. ")"
	end, 0.5)
end

function Yard.Start()
	setup()
	Players.PlayerRemoving:Connect(Yard.ExitBuild)
end

return Yard
