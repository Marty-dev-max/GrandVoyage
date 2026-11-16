-- ItemDB: single lookup for Items + Cards, plus rarity helpers
local Config = script.Parent.Parent.Config
local ItemsCfg = require(Config.Items)
local Cards = require(Config.Cards)
local Monsters = require(Config.Monsters)
local Rarity = require(script.Parent.Rarity)

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
	}
end

function ItemDB.Get(id)
	return ItemsCfg.Items[id] or cardItems[id]
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
	local def = ItemDB.Get(entry.id)
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
ItemDB.RefineMaterial = ItemsCfg.RefineMaterial
ItemDB.Cards = Cards
ItemDB.RarityModule = Rarity

return ItemDB
