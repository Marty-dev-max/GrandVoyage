-- TokiService (v0.25.70): Toki = fighting spirit (Config/Toki, docs/Plan-Toki.md). First sea: Conqueror Toki only:
-- rolled once per character at 0.1% (new and old characters alike, when the slot loads) or granted by the developer.
-- p.toki = { rolled = true, Conqueror = { color = "#hex", advanced = false } }; attributes for clients: Toki = "Conqueror,..",
-- TokiColor_<Kind> = hex. Conqueror's Roar (skill T_ConquerorRoar, CombatService kind "Roar") cows anyone much weaker
-- by Power; monsters below Calm x your Power do not attack you on their own (MonsterService findAggroTarget).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Modules.Net)
local Formulas = require(Shared.Modules.Formulas)
local TokiCfg = require(Shared.Config.Toki)

local TS = {}
local R

function TS.Init(registry)
	R = registry
end

local function ensure(p)
	if type(p.toki) ~= "table" then
		p.toki = {}
	end
	return p.toki
end

function TS.Has(p, kind)
	return p ~= nil and type(p.toki) == "table" and p.toki[kind] ~= nil
end

-- can this skill go on the bar (and be cast)? = you have its Toki
function TS.CanSlot(p, skillId)
	for _, s in ipairs(TokiCfg.Skills) do
		if s.id == skillId then
			return TS.Has(p, s.toki)
		end
	end
	return false
end

function TS.SetAttributes(player, p)
	local list = {}
	for _, k in ipairs(TokiCfg.Kinds) do
		local e = type(p.toki) == "table" and p.toki[k.id]
		player:SetAttribute("TokiColor_" .. k.id, e and e.color or nil)
		if e then
			table.insert(list, k.id)
		end
	end
	player:SetAttribute("Toki", #list > 0 and table.concat(list, ",") or nil)
end

local function randomColor()
	return TokiCfg.Colors[math.random(1, #TokiCfg.Colors)]
end

-- give (or take away with kind = nil-like "none") a Toki; announce = the big moment for a 0.1% roll
function TS.Grant(player, kind, why)
	local p = R.DataService.Get(player)
	local def = TokiCfg.ById[kind]
	if not p or not def then
		return false
	end
	local t = ensure(p)
	if t[kind] then
		return false
	end
	t[kind] = { color = randomColor(), advanced = false, at = os.time(), why = why }
	TS.SetAttributes(player, p)
	R.PlayerService.Recompute(player)
	R.PlayerService.MarkDirty(player)
	Net.Push(player, "Banner", { title = string.upper(def.name), subtitle = why == "born" and "You were born with the will of a ruler. One in a thousand." or "Your spirit awakens.", rarity = "Mythic" })
	if kind == "Conqueror" then
		Net.PushAll("Announce", { text = "👑 " .. player.DisplayName .. " carries the Conqueror Toki!", rarity = "Mythic" })
	end
	return true
end

function TS.Remove(player, kind)
	local p = R.DataService.Get(player)
	if not p or type(p.toki) ~= "table" or not p.toki[kind] then
		return false
	end
	p.toki[kind] = nil
	TS.SetAttributes(player, p)
	R.PlayerService.Recompute(player)
	R.PlayerService.MarkDirty(player)
	return true
end

-- Conqueror's Roar: everything much weaker than you (by Power) is cowed
function TS.Roar(player, skill)
	local p = R.DataService.Get(player)
	local root = R.PlayerService.Root(player)
	local d = R.PlayerService.Derived(player)
	if not p or not root or not d or not TS.Has(p, "Conqueror") then
		return false, "You do not have the Conqueror Toki"
	end
	local cfg = TokiCfg.Conqueror
	local mine = Formulas.Power(d, p.baseLevel)
	local cowed, resisted = {}, {}
	for _, mob in ipairs(R.MonsterService.InRadius(root.Position, skill.radius or 36)) do
		if not mob.dead and not mob.def.isBoss and not mob.def.isLeviathan and Formulas.MonsterPower(mob.def) < mine * cfg.Cow then
			R.MonsterService.Cow(mob, cfg.MonsterStun)
			table.insert(cowed, mob.model)
		elseif mob.model then
			table.insert(resisted, mob.model)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = pl ~= player and R.PlayerService.Root(pl)
		if r and (r.Position - root.Position).Magnitude <= (skill.radius or 36) and R.PvPService.CanFight(player, pl) then
			local pp = R.DataService.Get(pl)
			local pd = R.PlayerService.Derived(pl)
			if pp and pd and Formulas.Power(pd, pp.baseLevel) < mine * cfg.Cow then
				Net.Push(pl, "Stun", { seconds = cfg.PlayerStun })
				Net.FX("Miss", { pos = r.Position + Vector3.new(0, 3, 0), text = "COWED!" }, r.Position, 200)
			end
		end
	end
	local e = p.toki.Conqueror
	Net.FX("TokiRoar", { char = player.Character, color = e and e.color, radius = skill.radius or 36, cowed = cowed, resisted = resisted }, root.Position, 450)
	return true
end

function TS.Start()
	-- v0.25.72: pick your own Toki color (bought in the Store: p.tokiColorPick[kind])
	Net.Handle("SetTokiColor", function(player, data)
		local p = R.DataService.Get(player)
		local kind = type(data) == "table" and data.kind
		local hex = type(data) == "table" and data.color
		if not p or type(kind) ~= "string" or not TS.Has(p, kind) then
			return false, "You do not have that Toki"
		end
		if not (p.tokiColorPick and p.tokiColorPick[kind]) then
			return false, "Unlock the color choice in the Store first"
		end
		if type(hex) ~= "string" or not string.match(hex, "^#%x%x%x%x%x%x$") then
			return false, "Bad color"
		end
		p.toki[kind].color = string.upper(hex)
		TS.SetAttributes(player, p)
		R.PlayerService.MarkDirty(player)
		return true, (TokiCfg.ById[kind] and TokiCfg.ById[kind].name or kind) .. " color saved"
	end, 0.5)
	R.DataService.Loaded:Connect(function(player)
		local p = R.DataService.Get(player)
		if not p then
			return
		end
		local t = ensure(p)
		if not t.rolled then
			-- once per character: one in a thousand is born with it
			t.rolled = true
			R.PlayerService.MarkDirty(player)
			if math.random() < TokiCfg.Conqueror.Chance then
				task.delay(4, function()
					if player.Parent then
						TS.Grant(player, "Conqueror", "born")
					end
				end)
			end
		end
		TS.SetAttributes(player, p)
	end)
end

return TS
