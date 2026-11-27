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
				R.PlayerService.Notify(player, (perk.soon and "Perk reached (coming soon): " or "New perk: ") .. perk.name .. " (" .. perk.text .. ")", "good")
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

-- ===== Timing Bar (Mastery v2 M1): one press, green = 3, yellow = 2, else 1 =====
-- The server places the zones and keeps the start time; the client sends how long it ran before the press. That time
-- may be up to Timing.Lag older than the server's own clock (ping) but never newer: a press sent long after the bar
-- ended can't be passed off as an early one. It is only a sanity check (the client knows the zones, so a cheater
-- could always claim green); keep Lag wide so players with high ping are not judged late.
local timings = {} -- [player] = { token, t0, green = {a, b}, yellow = {a, b}, field, data }

function MS.TimingStart(player, field, data)
	local p = R.PlayerService.Profile(player)
	if not p then
		return nil
	end
	local T = MasteryCfg.Timing
	local gw = MasteryCfg.GreenWidth(MasteryCfg.Level(p, field))
	local center = 0.2 + math.random() * 0.6
	local g = { math.max(0, center - gw / 2), math.min(1, center + gw / 2) }
	local y = { math.max(0, g[1] - T.Yellow), math.min(1, g[2] + T.Yellow) }
	local token = tostring(math.random(1, 1e9))
	timings[player] = { token = token, t0 = os.clock(), green = g, yellow = y, field = field, data = data }
	return { token = token, green = g, yellow = y, sweep = T.Sweep, timeout = T.Timeout }
end

-- returns quality 1..3 and the data given to TimingStart (nil if there is no such run)
function MS.TimingFinish(player, token, clientT)
	local run = timings[player]
	if not run or run.token ~= token then
		return nil
	end
	timings[player] = nil
	local T = MasteryCfg.Timing
	local serverT = os.clock() - run.t0
	local t = tonumber(clientT)
	if not t or t ~= t or t > serverT + 0.05 or t < serverT - T.Lag or serverT > T.Timeout + T.Lag then
		t = nil -- no believable press: plain result
	end
	local q = 1
	if t then
		local x = MasteryCfg.Needle(t)
		if x >= run.green[1] and x <= run.green[2] then
			q = 3
		elseif x >= run.yellow[1] and x <= run.yellow[2] then
			q = 2
		end
	end
	return q, run.data
end

function MS.Start()
	Players.PlayerRemoving:Connect(function(player)
		timings[player] = nil
	end)
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
					-- Mastery v2 M5: riding a sea current with the flow trains faster
					-- M6: steering through a storm trains faster still
					MS.Add(player, "Navigator", G.HelmPerSec + ((ship.curAlong or 0) > 0.4 and G.CurrentPerSec or 0) + ((ship.stormK or 0) > 0.2 and G.StormPerSec or 0))
				end
			end
		end
	end)
end

return MS
