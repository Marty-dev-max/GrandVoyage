-- ShipPresets (v0.25.150, owner refs: a voxel dinghy, a decked sloop with stairs and rails, a big three-mast ship):
-- ready-made designs sold by every Shipwright. A preset costs exactly its blocks (ShipParts costs; materials other
-- than Wood are paid in Doubloons, MAT_BELI each), lands in one of your ship slots and is edited like any build.
local Shared = script.Parent.Parent
local ShipHull = require(Shared.Modules.ShipHull)

local P = {}
P.MAT_BELI = 150 -- Doubloons per unit of SailCloth / IronIngot / Gunpowder / ... inside a preset

-- v0.25.152 (owner: free-form building like the Shipshaper clip): presets are v2 designs (Modules/ShipHull):
-- a node hull + free items in studs (x across, y = item bottom above the main deck, z from the stern; m = mirrored)
local function new(name, nodes, hull, paint)
	local d = { v = 2, name = name, hull = { nodes = {}, bow = hull.bow, stern = hull.stern, wall = hull.wall }, items = {}, paint = table.clone(ShipHull.DefaultPaint) }
	for _, nd in ipairs(nodes) do
		table.insert(d.hull.nodes, { z = nd[1], w = nd[2], d = nd[3], s = nd[4] })
	end
	for k, v in pairs(paint or {}) do
		d.paint[k] = v
	end
	function d.add(id, x, y, z, r, opts)
		opts = opts or {}
		table.insert(d.items, { id = id, x = x, y = y, z = z, r = r or 0, sx = opts.sx or opts.s or 1, sy = opts.sy or opts.s or 1, sz = opts.sz or opts.s or 1, m = opts.m })
	end
	return d
end

local function finish(d)
	d.add = nil
	ShipHull.EnsureRudder(d) -- v0.25.153: every ship needs one
	return d
end

-- Dinghy: one mast, a helm aft, an oar bench, two light guns (port + starboard), low rails (ref: small open rowboat)
local function dinghy(name)
	local d = new(name or "Dinghy", { { 0, 4.5, 4, "F" }, { 11, 5.5, 4.5, "U" }, { 26, 1.5, 3, "V" } }, { bow = 3, stern = 1, wall = 1.5 })
	d.add("Helm", 0, 0, 3)
	d.add("SmallMast", 0, 0, 12)
	d.add("OarBench", 0, 0, 17)
	d.add("LightCannon", 2.5, 0, 8, 270, { m = true })
	d.add("Barrel", -2.5, 0, 20)
	return finish(d)
end

-- Sloop: raised stern deck (helm) up a stair, main + fore mast, four guns, a ram at the waterline
local function sloop()
	local d = new("Sloop", { { 0, 6.5, 5, "F" }, { 14, 8, 6, "U" }, { 30, 7.5, 5.5, "U" }, { 44, 1.5, 4, "V" } }, { bow = 5, stern = 1, wall = 2 },
		{ stripe = "#B83A32" })
	d.add("PlankBlock", 0, 0, 5, 0, { sx = 3, sy = 0.5, sz = 2.5 }) -- stern deck 12 x 2 x 10
	d.add("Helm", 0, 2, 3)
	d.add("Stairs", 0, 0, 12, 0, { sy = 0.5 }) -- climbs toward the stern
	d.add("Lantern", 5, 2, 1, 0, { m = true })
	d.add("Railing", 5.75, 2, 5, 90, { sx = 2.5, m = true })
	d.add("Railing", 4, 2, 9.75, 0, { sx = 0.9, m = true })
	d.add("LargeMast", 0, 0, 22)
	d.add("SmallMast", 0, 0, 34)
	d.add("LightCannon", 5, 0, 17, 270, { m = true })
	d.add("LightCannon", 5, 0, 28, 270, { m = true })
	d.add("OarBench", 0, 0, 27)
	d.add("Barrel", 3, 0, 39, 0, { m = true })
	d.add("RamHead", 0, -2.5, 47)
	d.add("Jib", 0, 0, 42) -- v0.25.153: power part on the bow
	return finish(d)
end

-- Galleon: stern castle + forecastle with stairs and rails, two big masts and a fore mast, 8 guns, crew cabins,
-- a lion figurehead (ref: big three-mast voxel ship)
local function galleon()
	local d = new("Galleon", { { 0, 9, 6, "F" }, { 16, 12, 7.5, "U" }, { 44, 12, 7.5, "U" }, { 62, 8, 6, "U" }, { 72, 2, 4.5, "V" } }, { bow = 8, stern = 2, wall = 2.5 },
		{ hull = "#5C3C26", stripe = "#E8C050", rail = "#3A2A20" })
	-- stern castle 20 wide, 3 up, 16 long + helm, lanterns, rails (open at the stair)
	d.add("PlankBlock", 0, 0, 8, 0, { sx = 5, sy = 0.75, sz = 4 })
	d.add("Helm", 0, 3, 5)
	d.add("Stairs", 0, 0, 18, 0, { sy = 0.75 })
	d.add("Lantern", 9, 3, 1, 0, { m = true })
	d.add("Railing", 9.75, 3, 8, 90, { sx = 4, m = true })
	d.add("Railing", 6, 3, 15.75, 0, { sx = 1.5, m = true })
	-- forecastle 16 wide, 3 up, 10 long + stair (climbs toward the bow) + rails
	d.add("PlankBlock", 0, 0, 66, 0, { sx = 4, sy = 0.75, sz = 2.5 })
	d.add("Stairs", 0, 0, 59, 180, { sy = 0.75 })
	d.add("Railing", 7.75, 3, 66, 90, { sx = 2.5, m = true })
	d.add("LargeMast", 0, 0, 30, 0, { sy = 1.2 })
	d.add("LargeMast", 0, 0, 46, 0, { sy = 1.1 })
	d.add("SmallMast", 0, 3, 67)
	d.add("CrewCabin", 6, 0, 40, 0, { m = true })
	d.add("HeavyCannon", 9.5, 0, 25, 270, { m = true })
	d.add("HeavyCannon", 9.5, 0, 34, 270, { m = true })
	d.add("LightCannon", 8.5, 0, 51, 270, { m = true })
	d.add("LightCannon", 7.5, 0, 56, 270, { m = true })
	d.add("OarBench", 0, 0, 24)
	d.add("OarBench", 0, 0, 54)
	d.add("Barrel", 3, 0, 52, 0, { m = true })
	d.add("LionHead", 0, 0, 79)
	d.add("Jib", 0, 0, 70, 0, { sy = 1.2 })
	d.add("Keel", 0, -9.5, 22, 0, { sz = 1.6 }) -- ballast keel under the midships (v0.25.153)
	d.hull.material = "Oak"
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

-- the free starter boat (nothing paid into it, so taking it apart refunds nothing)
function P.Starter()
	local d = dinghy("Little Dinghy")
	d.paid = {}
	return d
end

-- what a design costs to buy outright: { beli = n, Wood = n } (other materials paid in Doubloons)
function P.Cost(design)
	local raw = ShipHull.Cost(design)
	local beli, wood = 0, 0
	for k, v in pairs(raw) do
		if k == "beli" then
			beli += v
		elseif k == "Wood" then
			wood += v
		else
			beli += v * P.MAT_BELI
		end
	end
	return { beli = beli, Wood = wood }
end

-- self-check: every preset survives the server's sanitize, floats, stays upright and can sail
function P.Check()
	local ShipStats = require(Shared.Modules.ShipStats)
	local problems = {}
	for _, e in ipairs(P.List) do
		local clean, msg = ShipHull.Sanitize(e.design, "None")
		if not clean then
			table.insert(problems, e.id .. ": " .. tostring(msg))
		else
			if #ShipHull.Expand(clean) ~= #ShipHull.Expand(e.design) then
				table.insert(problems, e.id .. ": sanitize dropped items")
			end
			local st = ShipStats.Compute(clean, 0)
			if not st.valid then
				table.insert(problems, e.id .. ": " .. (st.problem or "not valid"))
			end
		end
	end
	return problems
end

return P
