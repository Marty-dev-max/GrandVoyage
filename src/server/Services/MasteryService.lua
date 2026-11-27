-- MasteryService (remake R3): Field Job Mastery. Doing the work raises that field (Config/Mastery):
--   Shipwright = ship repairs (ShipService.RepairNearby), Navigator = sailing at the helm (1 s loop here),
--   Cook = food / drinks (InventoryService UseItem) + party food buffs (CombatService), Doctor = heals on others
--   (CombatService.HealPlayer healer) + revives (KnockdownService), Gunner = cannonballs that hit (ShipService impact).
-- Saved as p.mastery[field] = { lv, xp }. Perks reach the game through Formulas.Compute (MasteryCfg.Bonus).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local MasteryCfg = require(Shared.Config.Mastery)
local Net = require(Shared.Modules.Net)

local MS = {}
local R

function MS.Init(registry)
	R = registry
end

local function entry(p, field)
	p.mastery = p.mastery or {}
	local m = p.mastery[field]
	if type(m) ~= "table" then
		m = { lv = 1, xp = 0 }
		p.mastery[field] = m
	end
	return m
end

function MS.Level(p, field)
	return MasteryCfg.Level(p, field)
end

-- { Shipwright = 3, ... } for TalentService / the client
function MS.Levels(p)
	local out = {}
	for _, id in ipairs(MasteryCfg.Order) do
		out[id] = MasteryCfg.Level(p, id)
	end
	return out
end

function MS.Add(player, field, xp)
	local p = R.PlayerService.Profile(player)
	if not p or not MasteryCfg.Fields[field] or not xp or xp <= 0 or xp ~= xp then
		return
	end
	local m = entry(p, field)
	if m.lv >= MasteryCfg.Max then
		return
	end
	m.xp += xp
	local up = false
	while m.lv < MasteryCfg.Max and m.xp >= MasteryCfg.ToNext(m.lv) do
		m.xp -= MasteryCfg.ToNext(m.lv)
		m.lv += 1
		up = true
		local f = MasteryCfg.Fields[field]
		R.PlayerService.Notify(player, f.name .. " Mastery Lv." .. m.lv .. "!", "level")
		for _, perk in ipairs(f.perks) do
			if perk.lv == m.lv then
				R.PlayerService.Notify(player, "New perk: " .. perk.name .. " (" .. perk.text .. ")", "good")
			end
		end
	end
	if m.lv >= MasteryCfg.Max then
		m.xp = 0
	end
	R.PlayerService.MarkDirty(player)
	if up then
		R.PlayerService.Recompute(player)
		R.TalentService.Refresh(player) -- Mastery Talents may have joined the pool
	end
end

-- the state the Talents window shows
function MS.State(p)
	local out = {}
	for _, id in ipairs(MasteryCfg.Order) do
		local m = p.mastery and p.mastery[id]
		local lv = m and m.lv or 1
		out[id] = { lv = lv, xp = math.floor(m and m.xp or 0), next = MasteryCfg.ToNext(lv) }
	end
	return out
end

function MS.Start()
	local G = MasteryCfg.Gain
	-- Navigator: every second seated at a moving ship's helm
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local seat = hum and hum.SeatPart
				local ship = seat and seat.Name == "HelmSeat" and R.ShipService.GetShipOf(player)
				if ship and ship.seat == seat and not ship.test and math.abs(ship.speed or 0) >= G.HelmMinSpeed then
					MS.Add(player, "Navigator", G.HelmPerSec)
				end
			end
		end
	end)
end

return MS
