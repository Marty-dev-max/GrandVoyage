-- ShipPresets (v0.25.150, owner refs: a voxel dinghy, a decked sloop with stairs and rails, a big three-mast ship):
-- ready-made designs sold by every Shipwright. A preset costs exactly its blocks (ShipParts costs; materials other
-- than Wood are paid in Doubloons, MAT_BELI each), lands in one of your ship slots and is edited like any build.
-- Grid: x across (center 4), y up, z toward the bow (higher z = further forward), r = quarter turns.
local Shared = script.Parent.Parent
local ShipParts = require(Shared.Config.ShipParts).Parts
local GameConfig = require(Shared.Config.GameConfig)

local P = {}
P.MAT_BELI = 150 -- Doubloons per unit of SailCloth / IronIngot / Gunpowder / ... inside a preset

local function new(name)
	local d = { name = name, parts = {} }
	local occ = {}
	function d.add(id, x, y, z, r)
		local key = x .. "," .. y .. "," .. z
		if occ[key] then
			return
		end
		occ[key] = true
		table.insert(d.parts, { id = id, x = x, y = y, z = z, r = r or 0 })
	end
	function d.box(id, x0, x1, y0, y1, z0, z1)
		for x = x0, x1 do
			for y = y0, y1 do
				for z = z0, z1 do
					d.add(id, x, y, z)
				end
			end
		end
	end
	-- multi-cell parts reserve every cell they cover first, so filler never lands inside them
	function d.big(id, x, y, z, r)
		local s = ShipParts[id].size
		if (r or 0) % 2 == 1 then
			s = Vector3.new(s.Z, s.Y, s.X)
		end
		for dx = 0, s.X - 1 do
			for dy = 0, s.Y - 1 do
				for dz = 0, s.Z - 1 do
					occ[(x + dx) .. "," .. (y + dy) .. "," .. (z + dz)] = true
				end
			end
		end
		table.insert(d.parts, { id = id, x = x, y = y, z = z, r = r or 0 })
	end
	return d
end

local function finish(d)
	d.add, d.box, d.big = nil, nil, nil
	return d
end

-- Dinghy: 3 wide x 7 long on a keel, one mast, an oar bench, two light guns, low rails (ref: small open rowboat)
local function dinghy()
	local d = new("Dinghy")
	d.big("SmallMast", 4, 2, 7)
	d.add("Helm", 4, 2, 4)
	d.add("OarBench", 4, 2, 9)
	d.add("LightCannon", 3, 2, 6, 1)
	d.add("LightCannon", 5, 2, 6, 3)
	d.add("Barrel", 3, 2, 7)
	-- keel, deck, bow
	d.box("OakBlock", 4, 4, 0, 0, 5, 9)
	d.box("PlankBlock", 3, 5, 1, 1, 4, 9)
	d.add("PlankWedge", 4, 1, 10)
	for _, z in ipairs({ 4, 5, 8, 9 }) do
		d.add("Railing", 3, 2, z, 1)
		d.add("Railing", 5, 2, z, 1)
	end
	return finish(d)
end

-- Sloop: 5 wide x 12 long on a V keel, bulwarks with gun ports, a raised stern deck (helm) up a stair, main + fore
-- mast, rails on the stern deck, a ram at the waterline (ref: decked sloop with stairs and rails)
local function sloop()
	local d = new("Sloop")
	d.big("LargeMast", 4, 0, 9)
	d.big("SmallMast", 4, 2, 12)
	d.add("Helm", 4, 3, 4)
	d.add("Stairs", 4, 2, 6) -- r 0 climbs toward the stern (lower z)
	d.add("Lantern", 3, 3, 3)
	d.add("Lantern", 5, 3, 3)
	for _, z in ipairs({ 7, 10 }) do
		d.add("LightCannon", 2, 2, z, 1)
		d.add("LightCannon", 6, 2, z, 3)
	end
	d.add("OarBench", 3, 2, 9)
	d.add("OarBench", 5, 2, 9)
	d.add("RamHead", 4, 1, 14)
	d.add("Barrel", 3, 2, 12)
	d.add("Barrel", 5, 2, 12)
	-- keel: a V (sloped bilge wedges either side), pointed under the bow
	for z = 4, 12 do
		d.add("PlankWedge", 3, 0, z, 1)
		d.add("OakBlock", 4, 0, z)
		d.add("PlankWedge", 5, 0, z, 3)
	end
	d.add("PlankWedge", 4, 0, 13)
	-- deck, tapering at the bow
	d.box("PlankBlock", 2, 6, 1, 1, 3, 12)
	d.box("PlankBlock", 3, 5, 1, 1, 13, 13)
	d.add("PlankWedge", 3, 1, 14)
	d.add("PlankWedge", 5, 1, 14)
	-- stern deck + bulwarks
	d.box("PlankBlock", 3, 5, 2, 2, 3, 5)
	for z = 3, 12 do
		d.add("PlankBlock", 2, 2, z)
		d.add("PlankBlock", 6, 2, z)
	end
	-- rails around the stern deck (open where the stair comes up)
	for z = 3, 5 do
		d.add("Railing", 2, 3, z, 1)
		d.add("Railing", 6, 3, z, 1)
	end
	d.add("Railing", 3, 3, 5)
	d.add("Railing", 5, 3, 5)
	d.add("Railing", 4, 3, 3)
	return finish(d)
end

-- Galleon: 7 wide x 18 long on a V keel, gun deck with 8 cannons, stern castle + forecastle with stairs and rails,
-- two big masts and a fore mast, crew cabins, a lion figurehead (ref: big three-mast voxel ship)
local function galleon()
	local d = new("Galleon")
	d.big("LargeMast", 4, 0, 8)
	d.big("LargeMast", 4, 0, 12)
	d.big("SmallMast", 4, 2, 17)
	d.big("CrewCabin", 2, 2, 7)
	d.big("CrewCabin", 5, 2, 7)
	-- stern castle deck x2..6 z1..5 at y2: helm + lanterns on top, stair down to the main deck
	d.add("Helm", 4, 3, 3)
	d.add("Stairs", 4, 2, 6) -- r 0 climbs toward the stern (lower z)
	d.add("Lantern", 2, 3, 1)
	d.add("Lantern", 6, 3, 1)
	-- forecastle x2..6 z16..17 at y2, stair up toward the bow
	d.add("Stairs", 4, 2, 15, 2) -- r 2 climbs toward the bow
	d.add("LionHead", 4, 2, 18)
	-- guns in the bulwarks: heavy amidships, light fore and aft
	for i, z in ipairs({ 5, 9, 11, 14 }) do
		local id = (i == 2 or i == 3) and "HeavyCannon" or "LightCannon"
		d.add(id, 1, 2, z, 1)
		d.add(id, 7, 2, z, 3)
	end
	for _, z in ipairs({ 10, 13 }) do
		d.add("OarBench", 3, 2, z)
		d.add("OarBench", 5, 2, z)
	end
	d.add("Barrel", 4, 2, 10)
	d.add("Barrel", 3, 2, 14)
	d.add("Barrel", 5, 2, 14)
	-- keel: a V (sloped bilge wedges either side), flat transom aft, pointed under the bow
	for z = 2, 16 do
		d.add("PlankWedge", 2, 0, z, 1)
		d.add("PlankWedge", 6, 0, z, 3)
	end
	d.box("OakBlock", 3, 5, 0, 0, 1, 16)
	for x = 3, 5 do
		d.add("PlankWedge", x, 0, 17)
	end
	-- main deck, tapering at the bow
	d.box("PlankBlock", 1, 7, 1, 1, 1, 15)
	d.box("PlankBlock", 2, 6, 1, 1, 16, 17)
	for x = 3, 5 do
		d.add("PlankWedge", x, 1, 18)
	end
	-- castles + bulwarks
	d.box("PlankBlock", 2, 6, 2, 2, 1, 5)
	d.box("PlankBlock", 2, 6, 2, 2, 16, 17)
	for z = 1, 15 do
		d.add("OakBlock", 1, 2, z)
		d.add("OakBlock", 7, 2, z)
	end
	-- rails: stern castle (open at the stair), forecastle (open at the stair)
	for z = 1, 5 do
		d.add("Railing", 1, 3, z, 1)
		d.add("Railing", 7, 3, z, 1)
	end
	for _, x in ipairs({ 2, 3, 5, 6 }) do
		d.add("Railing", x, 3, 5)
	end
	for z = 16, 17 do
		d.add("Railing", 2, 3, z, 1)
		d.add("Railing", 6, 3, z, 1)
	end
	for _, x in ipairs({ 3, 5 }) do
		d.add("Railing", x, 3, 16)
	end
	return finish(d)
end

P.List = {
	{ id = "Dinghy", name = "Dinghy", desc = "A nimble little boat for one or two sailors.", design = dinghy() },
	{ id = "Sloop", name = "Sloop", desc = "A decked sloop: raised helm, four guns, two masts.", design = sloop() },
	{ id = "Galleon", name = "Galleon", desc = "A war galleon: eight guns, two castles, three masts.", design = galleon() },
}
P.ById = {}
for _, e in ipairs(P.List) do
	P.ById[e.id] = e
end

-- what a design costs to buy outright: { beli = n, Wood = n }
function P.Cost(design)
	local beli, wood = 0, 0
	for _, p in ipairs(design.parts) do
		local def = ShipParts[p.id]
		for k, v in pairs(def and def.cost or {}) do
			if k == "beli" then
				beli += v
			elseif k == "Wood" then
				wood += v
			else
				beli += v * P.MAT_BELI
			end
		end
	end
	return { beli = beli, Wood = wood }
end

-- self-check (every preset fits the slip, no two parts share a cell, one helm, part limit)
function P.Check(cells)
	local size = GameConfig.Ship.PlotSize
	local problems = {}
	for _, e in ipairs(P.List) do
		local occ, helms = {}, 0
		for i, p in ipairs(e.design.parts) do
			if p.id == "Helm" then
				helms += 1
			end
			for _, c in ipairs(cells(p)) do
				local k = c.X .. "," .. c.Y .. "," .. c.Z
				if c.X < 0 or c.Y < 0 or c.Z < 0 or c.X >= size.X or c.Y >= size.Y or c.Z >= size.Z then
					table.insert(problems, e.id .. ": " .. p.id .. " outside at " .. k)
				elseif occ[k] then
					table.insert(problems, e.id .. ": " .. p.id .. " overlaps " .. e.design.parts[occ[k]].id .. " at " .. k)
				end
				occ[k] = i
			end
		end
		if helms ~= 1 then
			table.insert(problems, e.id .. ": " .. helms .. " helms")
		end
		if #e.design.parts > GameConfig.Ship.MaxParts then
			table.insert(problems, e.id .. ": " .. #e.design.parts .. " parts > MaxParts")
		end
	end
	return problems
end

return P
