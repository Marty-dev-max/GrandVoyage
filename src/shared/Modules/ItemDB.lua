-- ItemDB: single lookup for Items + Cards, plus rarity helpers
local Config = script.Parent.Parent.Config
local ItemsCfg = require(Config.Items)
local Cards = require(Config.Cards)
local Monsters = require(Config.Monsters)
local Rarity = require(script.Parent.Rarity)
local GameConfig = require(Config.GameConfig)
local Recruits = require(Config.Recruits)

local ItemDB = {}
local cardItems = {}
for id, c in pairs(Cards) do
	local mon = Monsters[c.monster]
	local baseName = mon and mon.name or c.monster
	cardItems[id] = {
		id = id,
		name = baseName .. " Card",
		kind = "Card",
		cardSlot = c.slot,
		bonus = c.bonus,
		desc = c.desc,
		rarity = c.rarity,
		stack = true,
		price = 5000,
		isBossCard = mon ~= nil and mon.isBoss == true,
		monster = c.monster,
		mtype = mon and mon.mtype, -- v0.25.95: card icon by monster type (card_STR ...)
	}
end

function ItemDB.Get(id)
	return ItemsCfg.Items[id] or cardItems[id]
end

-- v0.25.105 Ascend: an evolved weapon (entry.asc = steps) is its item one rarity higher per step, with more ATK,
-- lean stats and card slots (GameConfig.Ascend). Use this instead of Get(entry.id) wherever a bag entry is shown or counted.
local ascCache = {}
-- v0.25.148: a Crew Contract shows the sailor it holds (name, tier = rarity, job + stats in the description)
local contractCache = {}
local function contractDef(def, r)
	local key = r.seed .. "#" .. tostring(r.stars) .. "#" .. tostring(r.skill)
	local c = contractCache[key]
	if not c then
		local prof = Recruits.Professions[r.prof]
		c = table.clone(def)
		c.name = "Contract: " .. r.name
		c.rarity = Rarity.Order[math.clamp(r.stars or 1, 1, 5)]
		c.desc = Recruits.Tier(r).name .. " " .. (prof and prof.name or "") .. " (" .. (r.race or "") .. ")  Skill " .. (r.skill or 100) .. "%\n"
			.. Recruits.EffectText(r) .. "  •  " .. Recruits.TraitText(r) .. "\nSign it at a Tavern Keeper to add them to your crew."
		contractCache[key] = c
	end
	return c
end

function ItemDB.ForEntry(entry)
	if entry and entry.id == "CrewContract" and type(entry.recruit) == "table" and Recruits.ValidRecord(entry.recruit) then
		return contractDef(ItemDB.Get(entry.id), entry.recruit)
	end
	local def = entry and ItemDB.Get(entry.id)
	local asc = entry and tonumber(entry.asc) or 0
	if not def or asc <= 0 then
		return def
	end
	local key = entry.id .. "#" .. asc
	local c = ascCache[key]
	if not c then
		local A = GameConfig.Ascend
		c = table.clone(def)
		local r = table.find(Rarity.Order, def.rarity or "Common") or 1
		c.rarity = Rarity.Order[math.min(r + asc, #Rarity.Order)]
		c.baseRarity = def.rarity
		c.asc = asc
		local k = 1 + A.AtkStep * asc
		c.atk = def.atk and math.floor(def.atk * k)
		c.matk = def.matk and math.floor(def.matk * k)
		c.slots = math.min((def.slots or 0) + asc, A.MaxSlots)
		for _, s in ipairs({ "VIT", "END", "WIL", "WPN", "MAR", "FRU" }) do -- remake attributes (Formulas.StatNames)
			if def[s] then
				c[s] = def[s] + asc
			end
		end
		ascCache[key] = c
	end
	return c
end

-- can this bag entry evolve? true, next rarity, refine needed, cost table | false, reason
function ItemDB.AscendInfo(entry)
	local def = ItemDB.ForEntry(entry)
	if not def or def.kind ~= "Weapon" then
		return false, "Only weapons can evolve"
	end
	local A = GameConfig.Ascend
	local r = Rarity.Get(def.rarity).rank
	if r < Rarity.Get(A.From).rank then
		return false, "Evolving starts at Uncommon (green)"
	end
	if r >= Rarity.Get(A.MaxRarity).rank then
		return false, "Highest rarity this update"
	end
	return true, Rarity.Order[r + 1], A.NeedRefine[def.rarity] or 99, A.Cost[def.rarity] or {}
end

function ItemDB.Grade(def)
	return def and def.grade and ItemsCfg.GradeById[def.grade] or nil
end

function ItemDB.Rarity(def)
	return Rarity.Get(def and def.rarity or "Common")
end

function ItemDB.IsStackable(def)
	return def ~= nil and def.stack == true
end

function ItemDB.DisplayName(entry)
	local def = ItemDB.ForEntry(entry)
	if not def then
		return entry.id
	end
	local n = def.name
	if entry.refine and entry.refine > 0 then
		n = "+" .. entry.refine .. " " .. n
	end
	if def.slots and def.slots > 0 then
		n = n .. " [" .. (entry.cards and #entry.cards or 0) .. "/" .. def.slots .. "]"
	end
	return n
end

ItemDB.Grades = ItemsCfg.Grades
ItemDB.Shop = ItemsCfg.Shop
ItemDB.Blades = ItemsCfg.Blades
ItemDB.BladeTiers = ItemsCfg.BladeTiers
ItemDB.Greens = ItemsCfg.Greens
ItemDB.RefineMaterial = ItemsCfg.RefineMaterial
ItemDB.Cards = Cards
ItemDB.RarityModule = Rarity

return ItemDB
