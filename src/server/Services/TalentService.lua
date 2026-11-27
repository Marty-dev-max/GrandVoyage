-- TalentService (remake R3): Talent cards (Config/Talents). Every base level up = one pick (p.talentPicks). While a
-- pick is waiting the server keeps an offer of up to 3 cards (p.talentOffer, saved: leaving does not reroll it) drawn
-- by rarity weight from the talents you qualify for (TOTAL attributes, Field Mastery levels, level) and do not own.
-- No qualifying card = the pick waits until one unlocks (Refresh on stat / mastery / level changes).
-- Requests: TalentState (talents, picks, offer, mastery), TalentPick { id }. Push "Talents" = the same state.
-- Player attribute TalentPicks drives the HUD button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local TalentsCfg = require(Shared.Config.Talents)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local TS = {}
local R

function TS.Init(registry)
	R = registry
end

local function ctxOf(player, p)
	local d = R.PlayerService.Derived(player) or Formulas.Compute(p)
	local stats = {}
	for _, k in ipairs(Formulas.StatNames) do
		stats[k] = d[k] or 0
	end
	return { stats = stats, mastery = R.MasteryService.Levels(p), level = p.baseLevel or 1 }
end

local function owned(p, id)
	return table.find(p.talents or {}, id) ~= nil
end

-- weighted draw of up to n eligible cards
local function roll(player, p, n)
	local ctx = ctxOf(player, p)
	local pool = {}
	for _, t in ipairs(TalentsCfg.List) do
		if not owned(p, t.id) and TalentsCfg.Meets(t, ctx) then
			table.insert(pool, t)
		end
	end
	local out = {}
	while #out < n and #pool > 0 do
		local total = 0
		for _, t in ipairs(pool) do
			total += TalentsCfg.Rarity[t.rarity].weight
		end
		local r = math.random() * total
		for i, t in ipairs(pool) do
			r -= TalentsCfg.Rarity[t.rarity].weight
			if r <= 0 or i == #pool then
				table.insert(out, t.id)
				table.remove(pool, i)
				break
			end
		end
	end
	return out
end

function TS.State(p)
	return {
		talents = p.talents or {},
		picks = p.talentPicks or 0,
		offer = p.talentOffer,
		mastery = R.MasteryService.State(p),
	}
end

local function push(player, p)
	player:SetAttribute("TalentPicks", p.talentPicks or 0)
	player:SetAttribute("TalentOffer", p.talentOffer ~= nil)
	Net.Push(player, "Talents", TS.State(p))
end

-- make sure a waiting pick has an offer (none = it waits for a card to unlock), then tell the client
function TS.Refresh(player)
	local p = R.PlayerService.Profile(player)
	if not p then
		return
	end
	p.talents = p.talents or {}
	p.talentPicks = p.talentPicks or 0
	if p.talentOffer then
		-- drop cards that became owned some other way (or were removed from the config)
		local keep = {}
		for _, id in ipairs(p.talentOffer) do
			if TalentsCfg.ById[id] and not owned(p, id) then
				table.insert(keep, id)
			end
		end
		p.talentOffer = #keep > 0 and keep or nil
	end
	if p.talentPicks > 0 and not p.talentOffer then
		local offer = roll(player, p, TalentsCfg.Offer)
		p.talentOffer = #offer > 0 and offer or nil
	elseif p.talentPicks <= 0 then
		p.talentOffer = nil
	end
	R.PlayerService.MarkDirty(player)
	push(player, p)
end

-- PlayerService.GiveExp: `n` base levels gained
function TS.OnLevelUp(player, n)
	local p = R.PlayerService.Profile(player)
	if not p or n <= 0 then
		return
	end
	p.talentPicks = (p.talentPicks or 0) + n
	R.PlayerService.Notify(player, "New Talent card to pick! (press T)", "level")
	TS.Refresh(player)
end

function TS.Start()
	R.DataService.Loaded:Connect(function(player)
		TS.Refresh(player)
	end)
	Net.Handle("TalentState", function(player)
		local p = R.PlayerService.Profile(player)
		if not p then
			return false
		end
		return { ok = true, data = TS.State(p) }
	end, 0.3)
	Net.Handle("TalentPick", function(player, data)
		local p = R.PlayerService.Profile(player)
		local id = type(data) == "table" and data.id
		if not p or type(id) ~= "string" or not TalentsCfg.ById[id] then
			return false, "Unknown talent"
		end
		if (p.talentPicks or 0) <= 0 or not p.talentOffer or not table.find(p.talentOffer, id) then
			return false, "That card is not on offer"
		end
		if owned(p, id) then
			return false, "You already have it"
		end
		table.insert(p.talents, id)
		p.talentPicks -= 1
		p.talentOffer = nil
		R.PlayerService.Recompute(player)
		TS.Refresh(player)
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("LevelUp", { pos = root.Position, job = true }, root.Position, 200)
		end
		return { ok = true, msg = "Talent learned: " .. TalentsCfg.ById[id].name, data = TS.State(p) }
	end, 0.4)
end

return TS
