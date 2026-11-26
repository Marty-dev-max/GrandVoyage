-- ShipStats: weight / speed / HP / cannons from a ship design
-- design.parts = { { id="PlankBlock", x=0,y=0,z=0, r=0 }, ... }  (x,y,z = grid cell, r = 0..3 quarter turns)
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local ShipParts = require(Shared.Config.ShipParts).Parts

local S = {}
local cfg = GameConfig.Ship

function S.Footprint(partDef, r)
	local sz = partDef.size
	if r % 2 == 1 then
		return Vector3.new(sz.Z, sz.Y, sz.X)
	end
	return sz
end

-- List of cells a part occupies
function S.Cells(p)
	local def = ShipParts[p.id]
	local fp = S.Footprint(def, p.r or 0)
	local cells = {}
	for dx = 0, fp.X - 1 do
		for dy = 0, fp.Y - 1 do
			for dz = 0, fp.Z - 1 do
				table.insert(cells, Vector3.new(p.x + dx, p.y + dy, p.z + dz))
			end
		end
	end
	return cells
end

function S.CellKey(v)
	return v.X .. "," .. v.Y .. "," .. v.Z
end

-- bonus = { shipSpeed=0.1, shipHp=0.15 } from cards/class
-- v0.25.152: every part entry of a design, in model Index order (v2 = items + their mirror copies)
function S.Parts(design)
	if design.v == 2 then
		return require(Shared.Modules.ShipHull).Expand(design)
	end
	return design.parts or {}
end

function S.Compute(design, crew, bonus)
	bonus = bonus or {}
	if design.v == 2 then
		local r = require(Shared.Modules.ShipHull).Compute(design)
		r.hp = math.floor(r.hp * (1 + (bonus.shipHp or 0)))
		r.crewCap = math.max(r.crewCap, cfg.BaseCrewCapacity)
		r.crew = math.min(crew or 0, r.crewCap)
		r.speedBonus += bonus.shipSpeed or 0
		r.turnRate = cfg.BaseTurnRate * 300 / (300 + r.weight * 0.25) * r.lengthTurn
		r.cannonsManned = math.min(#r.cannons, r.crew)
		r.valid = r.helm == 1 and r.thrust + r.oars > 0 and not r.problem
		return r
	end
	local r = {
		weight = 0,
		hp = 0,
		thrust = 0,
		oars = 0,
		oarPower = 0,
		cannons = {},
		crewCap = 0,
		speedBonus = 0,
		helm = 0,
		partCount = 0,
		value = 0,
	}
	for _, p in ipairs(design.parts or {}) do
		local def = ShipParts[p.id]
		if def then
			r.partCount += 1
			r.weight += def.weight
			r.hp += def.hp
			r.thrust += def.thrust or 0
			if def.oar then
				r.oars += 1
				r.oarPower = def.oar
			end
			if def.cannon then
				table.insert(r.cannons, { part = p, damage = def.cannon.damage, range = def.cannon.range })
			end
			r.crewCap += def.crew or 0
			r.speedBonus += def.speedBonus or 0
			if p.id == "Helm" then
				r.helm += 1
			end
			r.value += (def.cost and def.cost.beli) or 0
		end
	end
	r.hp = math.floor(r.hp * (1 + (bonus.shipHp or 0)))
	r.crewCap = math.max(r.crewCap, cfg.BaseCrewCapacity)
	r.crew = math.min(crew or 0, r.crewCap)
	r.speedBonus += bonus.shipSpeed or 0
	r.turnRate = cfg.BaseTurnRate * 300 / (300 + r.weight * 0.25)
	r.cannonsManned = math.min(#r.cannons, r.crew)
	r.valid = r.helm == 1 and r.thrust + r.oars > 0
	return r
end

-- Top speed for a given wind (studs/s)
function S.Speed(stats, windFactor, extraBonus)
	local sail = stats.thrust * windFactor * (1 + stats.speedBonus + (extraBonus or 0))
	local oarFactor = windFactor <= 0.01 and 0.4 or 1
	local oar = math.min(stats.oars, stats.crew) * stats.oarPower * oarFactor
	local t = sail + oar
	if t <= 0 then
		return 0
	end
	return cfg.MaxSpeed * t / (t + stats.weight * cfg.WeightDrag)
end

-- Starter ship for new players (v0.25.152: a free-form v2 dinghy, Config/ShipPresets)
function S.StarterDesign()
	return require(Shared.Config.ShipPresets).Starter()
end

return S
