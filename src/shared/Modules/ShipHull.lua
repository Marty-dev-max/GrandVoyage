-- ShipHull (v0.25.152, owner: "too fixed to squares, like Build a Boat": free ship shaping like the Shipshaper clip):
-- design v2 = a hull shaped by nodes + fittings placed anywhere (snap 0.5 stud, 15 deg turns, scaled, mirrored)
-- + paint zones. Shared by the server (launch, save checks, cost) and the client (builder preview, stats).
--
--   design = { v = 2, name, hull = H, items = { I... }, paint = { hull, bottom, stripe, deck, rail, sail = "#RRGGBB" },
--              paid = { beli = n, Wood = n, ... } (what went into this ship: a save pays / refunds only the difference) }
--   H = { nodes = { { z, w, d, s }... }  z = studs from the stern (first node 0), w = half beam at the deck,
--         d = depth deck -> keel, s = section "V" | "U" | "F" (flat); bow / stern = rake (the deck line juts past
--         the end nodes), wall = bulwark height (0 = none) }
--   I = { id, x, y, z, r, sx, sy, sz, m }  ship space in studs: x across (0 = centre line, + = starboard), y = the
--         item's BOTTOM (0 = main deck top), z from the stern toward the bow; r = yaw degrees; m = mirrored copy at -x.
-- Ship space -> model: originCf * CFrame.new(x, y, -z) (model -Z = bow, as in v1).
-- The hull is voxel slices: 1-stud layers, each layer a run of blocks whose half width follows the node profile
-- (Catmull-Rom) times the section curve. Physics-lite: weight vs displaced volume gives the waterline (draft),
-- the centre of gravity vs buoyancy + waterline beam gives stability stars, list and trim.
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local ShipParts = require(Shared.Config.ShipParts).Parts

local H = {}
local G = GameConfig.Ship.GridSize
local cfg = GameConfig.Ship

H.MaxLength = 96
H.MaxBeam = 30 -- full beam
H.MaxDepth = 12
H.MaxNodes = 12
H.MaxItems = 200 -- after mirroring
H.MaxWall = 4
-- per stud^3 of hull (calibrated on the v1 Plank Block: 10 weight / 70 hp / 40 beli + 1 Wood per 64 stud^3)
H.Density = 10 / 64
H.HpPerVol = 1.6
H.BeliPerVol = 0.6
H.WoodPerVol = 1 / 48
H.Water = H.Density * 4 -- an empty hull floats a quarter deep
H.MinFreeboard = 0.6
H.FormStability = 2.2 -- blocky hulls: the waterplane counts extra (pure physics made every dinghy capsize)
H.StarGM = { 0.5, 1.5, 3, 5 } -- GM (studs) for 2..5 stars

-- v0.25.153 (Plan-Ships-v2 #16): what the hull is made of. dens / hp / beli / wood scale the per-volume numbers,
-- iron = IronIngot per stud^3 (iron-banded hulls), mat = Roblox material of the hull layers, shade = color tint
H.Materials = {
	Pine = { name = "PINE", dens = 1, hp = 1, beli = 1, wood = 1, mat = "WoodPlanks", shade = 0 },
	Oak = { name = "OAK", dens = 1.35, hp = 1.8, beli = 2, wood = 1.5, mat = "Wood", shade = -0.12 },
	Iron = { name = "IRON", dens = 1.9, hp = 2.8, beli = 2.5, wood = 1, iron = 1 / 90, mat = "Wood", shade = -0.05, bands = true },
}
H.MaterialOrder = { "Pine", "Oak", "Iron" }
function H.MaterialOf(hull)
	return H.Materials[hull and hull.material or "Pine"] or H.Materials.Pine
end
-- sails / oars: the best one counts fully, each next one a bit less (#26: piling on more stops paying off)
H.SailFalloff = 0.85
H.OarFalloff = 0.9
-- cannons: the bore (sx) and barrel (sz) scale range 0.7..1.6
H.CannonScale = { min = 0.7, max = 1.6 }
-- groups for the weight breakdown (#20)
H.Groups = { "Hull", "Guns", "Sails", "Cabins", "Other" }

H.Sections = { "V", "U", "F" }
H.SectionName = { V = "V KEEL", U = "ROUND", F = "FLAT" }
H.Zones = { "hull", "bottom", "stripe", "deck", "rail", "sail" }
H.ZoneName = { hull = "HULL", bottom = "BOTTOM", stripe = "STRIPE", deck = "DECK", rail = "RAILS", sail = "SAILS" }
H.DefaultPaint = { hull = "#96623A", bottom = "#6E3028", stripe = "#E8C050", deck = "#D6A56E", rail = "#5C3C26", sail = "#F6F1E2" }
H.MarinePaint = { hull = "#F0F1F6", bottom = "#283C78", stripe = "#E8C050", deck = "#D6A56E", rail = "#2C4A96", sail = "#F5F8FF" }
H.Palette = {
	"#F6F1E2", "#D6A56E", "#96623A", "#5C3C26", "#3A2A20", "#1E1E24",
	"#6E3028", "#B83A32", "#E07A2E", "#E8C050", "#7FB548", "#2E7D4F",
	"#5FB8D8", "#2C4A96", "#283C78", "#7A4FA8", "#E07AA8", "#9AA0AA",
}

-- how items may be scaled: "xyz" = each axis (blocks, cabins), "xy" = sail width + mast height, "x" = rail length,
-- "u" = one uniform size. { axes, min, max }
local BLOCKS = { PlankBlock = true, PlankSlab = true, OakBlock = true, IronPlate = true, TreasureBlock = true, PlankWedge = true }
function H.ScaleRule(id)
	local def = ShipParts[id]
	if not def then
		return nil
	end
	if BLOCKS[id] then
		return { axes = "xyz", min = 0.25, max = 6 }
	elseif def.cannon then
		return { axes = "xz", min = H.CannonScale.min, max = H.CannonScale.max }
	elseif def.rudder or def.keel or def.spar then
		return { axes = "yz", min = 0.5, max = 2.5 }
	elseif def.conform then
		return { axes = "yz", min = 0.5, max = 6 } -- width follows the hull (H.Expand)
	elseif def.flagLine then
		return { axes = "yz", min = 0.5, max = 3 }
	elseif def.wall then
		return { axes = "xy", min = 0.5, max = 3 }
	elseif id == "Stairs" or id == "CrewCabin" then
		return { axes = "xyz", min = 0.5, max = 2.5 }
	elseif id == "Railing" then
		return { axes = "xy", min = 0.5, max = 4 }
	elseif def.thrust then
		return { axes = "xy", min = 0.6, max = 1.8 }
	end
	return { axes = "u", min = 0.75, max = 1.5 }
end

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end
local function snap(v, step)
	return math.floor(v / step + 0.5) * step
end
local function hex(c, fallback)
	if type(c) == "string" and #c == 7 and c:match("^#%x%x%x%x%x%x$") then
		return c:upper()
	end
	return fallback
end
function H.Color(s, fallback)
	local ok, c = pcall(Color3.fromHex, s or "")
	return ok and c or fallback or Color3.new(1, 0, 1)
end

-- ===== bow / stern styles (#3 #4) =====
-- p = how the stem / stern post rakes with height (1 straight, 2 curved, 4 a long spoon), taper = plan-view shape of
-- the last taper length (u 0 at the tip .. 1), square = the stern keeps this share of the widest beam (transom),
-- flare = upper layers widen toward the stern (galleon counter)
local function quarter(u)
	return math.sqrt(math.max(0, 1 - (1 - u) ^ 2))
end
H.BowStyles = { "standard", "clipper", "round", "spoon" }
H.SternStyles = { "standard", "transom", "round", "galleon" }
H.StyleName = { standard = "STANDARD", clipper = "CLIPPER", round = "ROUND", spoon = "SPOON", transom = "TRANSOM", galleon = "GALLEON" }
local BOW_STYLE = {
	standard = { p = 2 },
	clipper = { p = 1, taper = function(u)
		return u
	end },
	round = { p = 2, taper = quarter },
	spoon = { p = 4, taper = quarter },
}
local STERN_STYLE = {
	standard = { p = 2 },
	transom = { p = 1, square = 0.75 },
	round = { p = 2, taper = quarter },
	galleon = { p = 0.6, square = 0.8, flare = 0.12 },
}

-- ===== the profile =====
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
-- section curve: half width fraction at height fraction t (0 = keel, 1 = deck)
local SECTION = {
	V = function(t)
		return 0.14 + 0.86 * t
	end,
	U = function(t)
		return 0.14 + 0.86 * math.sqrt(math.max(0, 1 - (1 - t) ^ 2))
	end,
	F = function(t)
		return math.min(1, 0.72 + 1.1 * t)
	end,
}

-- sampler(zs) -> half width, depth, section mix (fV, fU, fF weights) at a profile position 0..L
function H.Sampler(hull)
	local n = hull.nodes
	local L = n[#n].z
	return function(zs)
		zs = clamp(zs, 0, L)
		local i = 1
		while i < #n - 1 and n[i + 1].z < zs do
			i += 1
		end
		local a, b = n[i], n[i + 1]
		local t = (b.z - a.z) > 0 and (zs - a.z) / (b.z - a.z) or 0
		local p0, p3 = n[i - 1] or a, n[i + 2] or b
		local w = math.max(0, catmull(p0.w, a.w, b.w, p3.w, t))
		local d = math.max(0.5, catmull(p0.d, a.d, b.d, p3.d, t))
		return w, d, a.s or "V", b.s or "V", t
	end, L
end

-- slices: { L, D (max depth), zMin, zMax, layers = { { y0, y1, runs = { { z0, z1, hw } } } } } (bottom -> top)
function H.Slices(hull)
	local sample, L = H.Sampler(hull)
	local D = 0
	for _, nd in ipairs(hull.nodes) do
		D = math.max(D, nd.d)
	end
	local bowR, sternR = hull.bow or 0, hull.stern or 0
	local bs, ss = BOW_STYLE[hull.bowStyle] or BOW_STYLE.standard, STERN_STYLE[hull.sternStyle] or STERN_STYLE.standard
	local wMax = 0
	for _, nd in ipairs(hull.nodes) do
		wMax = math.max(wMax, nd.w)
	end
	local TL = clamp(L * 0.22, 3, 14)
	local out = { L = L, D = D, layers = {}, zMin = 0, zMax = L }
	local nLayers = math.ceil(D - 1e-6)
	for j = nLayers, 1, -1 do
		local y1 = -(j - 1)
		local y0 = math.max(-D, -j)
		local ym = (y0 + y1) / 2
		local tl = 1 + ym / D -- 0 at the keel, ~1 at the deck
		local zA, zB = -sternR * math.max(tl, 0) ^ ss.p, L + bowR * math.max(tl, 0) ^ bs.p
		out.zMin, out.zMax = math.min(out.zMin, zA), math.max(out.zMax, zB)
		local runs = {}
		local cur
		local steps = math.max(1, math.floor(zB - zA + 0.5))
		local step = (zB - zA) / steps
		for k = 0, steps - 1 do
			local zc = zA + (k + 0.5) * step
			local zs = (zc - zA) / (zB - zA) * L
			local w, d, sa, sb, t = sample(zs)
			local hw = 0
			if -ym <= d then
				local f = 1 + ym / d
				local s = SECTION[sa](f) * (1 - t) + SECTION[sb](f) * t
				local raw = w * s
				local dB, dS = zB - zc, zc - zA
				if bs.taper and dB < TL then
					raw *= bs.taper(dB / TL)
				end
				if ss.taper and dS < TL then
					raw *= ss.taper(dS / TL)
				end
				if ss.square and dS < TL and tl > 0.35 then
					raw = math.max(raw, wMax * ss.square * s)
				end
				if ss.flare and dS < TL then
					raw *= 1 + ss.flare * tl * (1 - dS / TL)
				end
				hw = snap(math.min(raw, H.MaxBeam / 2), 0.5)
			end
			if hw >= 0.5 then
				local z0 = zA + k * step
				if cur and cur.hw == hw and math.abs(cur.z1 - z0) < 1e-6 then
					cur.z1 = z0 + step
				else
					cur = { z0 = z0, z1 = z0 + step, hw = hw }
					table.insert(runs, cur)
				end
			else
				cur = nil
			end
		end
		table.insert(out.layers, { y0 = y0, y1 = y1, runs = runs })
	end
	return out
end

local function layerVolume(layer)
	local v = 0
	for _, r in ipairs(layer.runs) do
		v += 2 * r.hw * (r.z1 - r.z0) * (layer.y1 - layer.y0)
	end
	return v
end

local function topHalfWidth(sl)
	local top = sl.layers[#sl.layers]
	local runs = top and top.runs or {}
	return function(z)
		for _, r in ipairs(runs) do
			if z >= r.z0 and z <= r.z1 then
				return r.hw
			end
		end
		return 0
	end
end

-- conform superstructures: how far in from the hull edge they stand (a castle on a castle steps in more)
local function conformInset(def, it)
	if def.conform == "house" then
		return (it.y or 0) > 0.5 and 1.5 or 1
	elseif def.conform == "rail" then
		return (it.y or 0) > 0.5 and 1.4 or 0.6
	end
	return 0.6
end
H.ConformInset = conformInset

-- the hull's deck rows under a conform item: { { z0, z1, hw } } (hw = the item's own half width there)
function H.ConformRows(design, it)
	local def = ShipParts[it.id]
	local sl = H.Slices(design.hull)
	local top = sl.layers[#sl.layers]
	local half = def.size.Z * G * (it.sz or 1) / 2
	local z0, z1 = it.z - half, it.z + half
	local inset = conformInset(def, it)
	local rows = {}
	for _, r in ipairs(top and top.runs or {}) do
		local a, b = math.max(r.z0, z0), math.min(r.z1, z1)
		if b - a > 0.05 and r.hw - inset >= 0.5 then
			table.insert(rows, { z0 = a, z1 = b, hw = r.hw - inset })
		end
	end
	if #rows == 0 then
		rows = { { z0 = z0, z1 = z1, hw = def.size.X * G / 2 } } -- off the hull: its nominal width
	end
	return rows
end

-- ===== items =====
local function itemSize(it)
	local def = ShipParts[it.id]
	return def.size * G * Vector3.new(it.sx or 1, it.sy or 1, it.sz or 1)
end
H.ItemSize = itemSize

-- every item plus its mirror copy: { id, x, y, z, r, sx, sy, sz, src = index in design.items, mirror = bool }
function H.Expand(design)
	local out = {}
	local hwAt
	for i, it in ipairs(design.items or {}) do
		local def = ShipParts[it.id]
		if def and def.conform then
			-- v0.25.154 (#5): centred, its width = the narrowest hull row it covers (stats + arcs; the model follows every row)
			hwAt = hwAt or topHalfWidth(H.Slices(design.hull))
			local half = def.size.Z * G * (it.sz or 1) / 2
			local w = math.huge
			for z = it.z - half, it.z + half + 1e-6, 1 do
				local hw = hwAt(z)
				if hw > 0 then
					w = math.min(w, hw)
				end
			end
			local width = w < math.huge and math.max(1, 2 * (w - conformInset(def, it))) or def.size.X * G
			table.insert(out, { id = it.id, x = 0, y = it.y, z = it.z, r = 0, sx = width / (def.size.X * G), sy = it.sy or 1, sz = it.sz or 1, src = i, conform = true })
		elseif def then
			table.insert(out, { id = it.id, x = it.x, y = it.y, z = it.z, r = it.r or 0, sx = it.sx or 1, sy = it.sy or 1, sz = it.sz or 1, src = i })
			if it.m and math.abs(it.x) >= 0.5 then
				table.insert(out, { id = it.id, x = -it.x, y = it.y, z = it.z, r = (360 - (it.r or 0)) % 360, sx = it.sx or 1, sy = it.sy or 1, sz = it.sz or 1, src = i, mirror = true })
			end
		end
	end
	return out
end

-- the item's centre CFrame in model space (origin = ship-space origin)
function H.ItemCFrame(it)
	local size = itemSize(it)
	local yaw = CFrame.Angles(0, math.rad(it.r or 0), 0)
	return CFrame.new(it.x, it.y + size.Y / 2, -it.z) * yaw, size
end

local function weightScale(it)
	local rule = H.ScaleRule(it.id)
	if rule and rule.axes == "u" then
		return it.sx or 1
	elseif rule and rule.axes == "xz" then
		return (it.sx or 1) ^ 2 * (it.sz or 1) -- cannons: bore area x barrel length
	end
	return (it.sx or 1) * (it.sy or 1) * (it.sz or 1)
end
H.WeightScale = weightScale

-- a cannon's numbers after its bore (sx) / barrel (sz) scaling: bigger bore = harder hits, longer barrel = more
-- reach + a faster shot (slightly less punch), as in the reference clip
function H.CannonStats(it)
	local c = ShipParts[it.id].cannon
	local bore, len = it.sx or 1, it.sz or 1
	return {
		damage = c.damage * bore ^ 1.5 * (1.15 - 0.15 * len),
		range = c.range * (0.6 + 0.4 * len),
		speed = (c.speed or 1) * (0.7 + 0.3 * len),
		reload = (c.reload or 1) * (0.8 + 0.2 * bore),
		trav = c.trav or 40,
		lob = c.lob == true,
	}
end

local function groupOf(def)
	if def.cannon then
		return "Guns"
	elseif def.thrust or def.oar then
		return "Sails"
	elseif def.crew and def.id ~= "Helm" then
		return "Cabins"
	elseif def.category == "Hull" then
		return "Hull"
	end
	return "Other"
end
H.GroupOf = groupOf

-- ===== physics-lite =====
function H.Physics(design)
	local sl = H.Slices(design.hull)
	local hullVol, hullMomY = 0, 0
	for _, layer in ipairs(sl.layers) do
		local v = layerVolume(layer)
		hullVol += v
		hullMomY += v * (layer.y0 + layer.y1) / 2
	end
	-- bulwarks: thin walls along the deck edge (weight only)
	local wall = design.hull.wall or 0
	local top = sl.layers[#sl.layers]
	local wallVol = 0
	if top and wall > 0 then
		for _, r in ipairs(top.runs) do
			wallVol += 2 * 0.5 * wall * (r.z1 - r.z0)
		end
	end
	local dens = H.Density * H.MaterialOf(design.hull).dens
	local W = (hullVol + wallVol) * dens
	local mx, my, mz = 0, hullMomY * dens + wallVol * dens * wall / 2, 0
	-- hull z centroid
	local hz = 0
	for _, layer in ipairs(sl.layers) do
		for _, r in ipairs(layer.runs) do
			hz += 2 * r.hw * (r.z1 - r.z0) * (layer.y1 - layer.y0) * (r.z0 + r.z1) / 2
		end
	end
	mz = hz * dens
	local groups = { Hull = W, Guns = 0, Sails = 0, Cabins = 0, Other = 0 }
	local sailMoment, thrust, keelArea = 0, 0, 0
	for _, it in ipairs(H.Expand(design)) do
		local def = ShipParts[it.id]
		local w = def.weight * weightScale(it)
		local size = itemSize(it)
		W += w
		mx += w * it.x
		my += w * (it.y + size.Y / 2)
		mz += w * it.z
		local g = groupOf(def)
		groups[g] += w
		if def.thrust then
			local t = def.thrust * (it.sx or 1) * (it.sy or 1)
			thrust += t
			sailMoment += t * (it.y + size.Y * 0.6)
		end
		if def.keel then
			keelArea += size.Y * size.Z
		end
	end
	local r = { weight = W, hullVol = hullVol, hullWeight = (hullVol + wallVol) * dens, length = sl.zMax - sl.zMin, depth = sl.D, slices = sl, groups = groups, keelArea = keelArea }
	r.xg, r.yg, r.zg = mx / math.max(W, 1), my / math.max(W, 1), mz / math.max(W, 1)
	-- waterline: fill layers from the keel until the displaced water weighs as much as the ship
	local need = W / H.Water
	local cum, momY, momZ = 0, 0, 0
	r.waterY = nil
	local wlLayer
	for _, layer in ipairs(sl.layers) do
		local v = layerVolume(layer)
		local zc = 0
		for _, run in ipairs(layer.runs) do
			zc += 2 * run.hw * (run.z1 - run.z0) * (layer.y1 - layer.y0) * (run.z0 + run.z1) / 2
		end
		if v > 0 and cum + v >= need then
			local f = (need - cum) / v
			local yw = layer.y0 + (layer.y1 - layer.y0) * f
			momY += (need - cum) * (layer.y0 + yw) / 2
			momZ += zc * f
			cum = need
			r.waterY = yw
			wlLayer = layer
			break
		end
		cum += v
		momY += v * (layer.y0 + layer.y1) / 2
		momZ += zc
	end
	if not r.waterY then
		r.sinks = true
		r.waterY = 0
		wlLayer = top
		r.yb, r.zb = momY / math.max(cum, 1), momZ / math.max(cum, 1)
	else
		r.yb, r.zb = momY / math.max(need, 1), momZ / math.max(need, 1)
	end
	r.draft = r.waterY + sl.D
	r.freeboard = -r.waterY
	r.floods = not r.sinks and r.freeboard < H.MinFreeboard
	-- stability: metacentric height GM = KB + BM - KG (BM = waterplane inertia / displaced volume)
	local inertia, wlLen, wlBeam = 0, 0, 0
	for _, run in ipairs(wlLayer and wlLayer.runs or {}) do
		local b = 2 * run.hw
		inertia += b * b * b * (run.z1 - run.z0) / 12
		wlLen += run.z1 - run.z0
		wlBeam = math.max(wlBeam, b)
	end
	local disp = math.max(need, 1)
	r.gm = r.yb + inertia / disp * H.FormStability - r.yg
	r.capsizes = r.gm < 0
	r.stars = 0
	if not r.capsizes then
		r.stars = 1
		for _, g in ipairs(H.StarGM) do
			r.stars += r.gm >= g and 1 or 0
		end
	end
	local gm = math.max(r.gm, 0.25)
	r.list = -math.atan(r.xg / gm) -- starboard heavy -> starboard side down (negative roll)
	r.list = clamp(r.list, -0.3, 0.3)
	local gml = math.max(wlLen, 4) ^ 2 / (12 * math.max(r.draft, 1))
	r.trim = clamp(-math.atan((r.zg - r.zb) / gml), -0.12, 0.12) -- bow heavy -> bow down
	-- wind heel under sail (#22): tall sails on a tender hull lean over; keels resist it (their side area against the
	-- waterline length)
	r.heel = clamp(sailMoment / math.max(W * gm, 1) * 0.05 / (1 + keelArea / math.max(wlLen, 8) * 0.8), 0, 0.22)
	r.thrust = thrust
	r.wlLength, r.wlBeam = wlLen, wlBeam
	r.fineness = wlBeam > 0 and wlLen / wlBeam or 3
	return r
end

-- ===== cost =====
local function addCost(into, cost, k)
	for key, v in pairs(cost) do
		into[key] = (into[key] or 0) + v * k
	end
end
function H.Cost(design)
	local sl = H.Slices(design.hull)
	local vol = 0
	for _, layer in ipairs(sl.layers) do
		vol += layerVolume(layer)
	end
	local mat = H.MaterialOf(design.hull)
	local c = { beli = vol * H.BeliPerVol * mat.beli, Wood = vol * H.WoodPerVol * mat.wood }
	if mat.iron then
		c.IronIngot = vol * mat.iron
	end
	for _, it in ipairs(H.Expand(design)) do
		addCost(c, ShipParts[it.id].cost, math.max(1, weightScale(it)))
	end
	for k, v in pairs(c) do
		c[k] = math.ceil(v - 1e-6)
		if c[k] <= 0 then
			c[k] = nil
		end
	end
	return c
end

-- what a save costs (+) or refunds (-) against what went into the ship so far: pay, refund, gift left.
-- v0.25.154: `gift` = the part of `paid` that came free (starter boat, rebuilt old ships). Shrinking the ship uses the
-- gift up first, so a free boat taken apart pays nothing out; only what the player really paid comes back.
function H.Delta(newCost, paid, gift)
	paid, gift = paid or {}, gift or {}
	local pay, refund, left = {}, {}, {}
	local keys = {}
	for k in pairs(newCost) do
		keys[k] = true
	end
	for k in pairs(paid) do
		keys[k] = true
	end
	for k in pairs(keys) do
		local c, p = newCost[k] or 0, paid[k] or 0
		local g = math.min(gift[k] or 0, p)
		if c > p then
			pay[k] = c - p
		elseif c < p then
			-- real money in the ship before minus real money left in it after
			local back = (p - g) - (c - math.min(g, c))
			if back > 0 then
				refund[k] = back
			end
		end
		if math.min(g, c) > 0 then
			left[k] = math.min(g, c)
		end
	end
	return pay, refund, left
end

-- what taking the whole ship apart (or replacing it) pays back: paid minus what came free
function H.RealPaid(design)
	local out = {}
	for k, v in pairs(design.paid or {}) do
		local r = v - math.min(v, (design.gift or {})[k] or 0)
		if r > 0 then
			out[k] = r
		end
	end
	return out
end

-- ===== sanitize (server trust boundary; the client runs it too so its preview matches) =====
local function num(v, a, b, step, default)
	v = tonumber(v)
	if not v or v ~= v then
		v = default
	end
	v = clamp(v, a, b)
	return step and snap(v, step) or v
end

function H.Sanitize(raw, faction)
	if type(raw) ~= "table" or type(raw.hull) ~= "table" or type(raw.hull.nodes) ~= "table" then
		return nil, "Bad design"
	end
	local nodes = {}
	for i, nd in ipairs(raw.hull.nodes) do
		if i > H.MaxNodes then
			break
		end
		if type(nd) == "table" then
			local s = (nd.s == "U" or nd.s == "F") and nd.s or "V"
			table.insert(nodes, { z = num(nd.z, 0, H.MaxLength, 1, 0), w = num(nd.w, 0.5, H.MaxBeam / 2, 0.5, 4), d = num(nd.d, 1, H.MaxDepth, 0.5, 3), s = s })
		end
	end
	if #nodes < 2 then
		return nil, "A hull needs at least 2 points"
	end
	table.sort(nodes, function(a, b)
		return a.z < b.z
	end)
	local z0 = nodes[1].z
	for i, nd in ipairs(nodes) do
		nd.z -= z0
		if i > 1 and nd.z < nodes[i - 1].z + 2 then
			nd.z = nodes[i - 1].z + 2
		end
	end
	if nodes[#nodes].z > H.MaxLength then
		return nil, "Too long (max " .. H.MaxLength .. " studs)"
	end
	if nodes[#nodes].z < 8 then
		return nil, "Too short (min 8 studs)"
	end
	local h = raw.hull
	local hull = { nodes = nodes, bow = num(h.bow, 0, 16, 1, 0), stern = num(h.stern, 0, 10, 1, 0), wall = num(h.wall, 0, H.MaxWall, 0.5, 1), material = H.Materials[h.material] and h.material or "Pine" }
	-- v0.25.154: bow / stern style (#3 #4), hull details (#15), name on the stern (#17, noName = hidden)
	hull.bowStyle = BOW_STYLE[h.bowStyle] and h.bowStyle ~= "standard" and h.bowStyle or nil
	hull.sternStyle = STERN_STYLE[h.sternStyle] and h.sternStyle ~= "standard" and h.sternStyle or nil
	for _, k in ipairs({ "seams", "rivets", "trim", "noName" }) do
		hull[k] = h[k] == true or nil
	end
	local L = nodes[#nodes].z
	local items = {}
	local count, perId = 0, {}
	for _, it in ipairs(type(raw.items) == "table" and raw.items or {}) do
		local def = type(it) == "table" and ShipParts[it.id]
		if def and not (def.faction and def.faction ~= faction) then
			local rule = H.ScaleRule(def.id)
			local m = it.m == true
			local x = num(it.x, -H.MaxBeam / 2 - 12, H.MaxBeam / 2 + 12, 0.25, 0)
			if def.conform then
				x = 0 -- #11: superstructures stay symmetric
			end
			if math.abs(x) < 0.5 then
				m = false
			end
			local n = m and 2 or 1
			if def.max then
				m = false
				n = 1
				if (perId[def.id] or 0) >= def.max then
					n = 0
				end
			end
			if n > 0 and count + n <= H.MaxItems then
				local sx = num(it.sx, rule.min, rule.max, 0.05, 1)
				local sy, sz = sx, sx
				if rule.axes == "xyz" then
					sy, sz = num(it.sy, rule.min, rule.max, 0.05, 1), num(it.sz, rule.min, rule.max, 0.05, 1)
				elseif rule.axes == "xy" then
					sy, sz = num(it.sy, rule.min, rule.max, 0.05, 1), 1
				elseif rule.axes == "xz" then
					sy, sz = 1, num(it.sz, rule.min, rule.max, 0.05, 1)
				elseif rule.axes == "yz" then
					sx, sy, sz = 1, num(it.sy, rule.min, rule.max, 0.05, 1), num(it.sz, rule.min, rule.max, 0.05, 1)
				end
				table.insert(items, {
					id = def.id,
					x = x,
					y = num(it.y, -H.MaxDepth - 2, 40, 0.25, 0),
					z = num(it.z, -24, L + 30, 0.25, 0),
					r = def.conform and 0 or num(it.r, 0, 345, 15, 0) % 360,
					sx = sx, sy = sy, sz = sz,
					m = m or nil,
				})
				count += n
				perId[def.id] = (perId[def.id] or 0) + n
			end
		end
	end
	local paint = {}
	local rp = type(raw.paint) == "table" and raw.paint or {}
	for _, k in ipairs(H.Zones) do
		paint[k] = hex(rp[k], H.DefaultPaint[k])
	end
	return { v = 2, name = raw.name, hull = hull, items = items, paint = paint }
end

-- ===== firing arcs (#25) =====
-- Bearings are degrees in ship space: 0 = toward the bow, 90 = starboard, -90 = port. A cannon turned r faces
-- bearing -r. Its traverse arc is facing +- trav; inside it, every 5 degrees a shot line is traced at muzzle height
-- for ARC_REACH studs: it is blocked by another part standing across it or by the bulwark (unless the gun sits at a
-- gun port). Mortars lob over everything. Result per cannon (H.Expand index): { face, trav, fire = { { lo, hi }... } }
local ARC_STEP, ARC_REACH = 5, 24
local function wrap180(a)
	return (a + 180) % 360 - 180
end
H.Wrap180 = wrap180


function H.Arcs(design)
	local list = H.Expand(design)
	local sl = H.Slices(design.hull)
	local hwAt = topHalfWidth(sl)
	local wall = design.hull.wall or 0
	local boxes = {}
	for i, it in ipairs(list) do
		local def = ShipParts[it.id]
		local size = itemSize(it)
		local hx, hz = size.X / 2, size.Z / 2
		if (def.thrust and not def.jib) or def.spyglass then
			hx, hz = 0.5, 0.5 -- only the mast / crow's nest post stands in the way, the rest is up high
		elseif def.conform == "rail" or def.conform == "awning" or def.flagLine then
			hx, hz = 0, 0 -- open rails / canvas overhead / flag strings: the guns shoot through
		end
		local a = math.rad(it.r or 0)
		boxes[i] = { x = it.x, z = it.z, y0 = it.y, y1 = it.y + size.Y, hx = hx, hz = hz, c = math.cos(a), s = math.sin(a),
			bow = def.jib or def.spar or def.figurehead } -- a bow chaser shoots past these
	end
	local out = {}
	for i, it in ipairs(list) do
		local def = ShipParts[it.id]
		if def.cannon then
			local cs = H.CannonStats(it)
			local face = wrap180(-(it.r or 0))
			local size = itemSize(it)
			local yM = it.y + size.Y * 0.45
			local hw0 = hwAt(it.z)
			local port = math.abs(it.y) < 1 and math.abs(it.x) > 1 and math.abs(it.x) > hw0 - 4
			-- v0.25.157 (owner): a harpoon / fire pot on the bow fires forward over the stem (a bow chaser)
			local chaser = def.cannon.special and math.abs(it.x) < 3 and it.z > sl.L - 10
			local fire, cur = {}, nil
			local trav = math.min(cs.trav, 180)
			local n = math.floor(trav * 2 / ARC_STEP + 0.5)
			for k = 0, n do
				local b = face - trav + k * (trav * 2 / math.max(n, 1))
				local clear = true
				if not cs.lob then
					local dx, dz = math.sin(math.rad(b)), math.cos(math.rad(b))
					local inside = math.abs(it.x) <= hw0
					for d = 1, ARC_REACH do
						local px, pz = it.x + dx * d, it.z + dz * d
						-- the bulwark (or the deck edge itself when the gun stands below the deck line)
						local hw = hwAt(pz)
						local nowInside = math.abs(px) <= hw
						if inside and not nowInside then
							local atPort = (port and math.abs(pz - it.z) <= 1.6) or (chaser and pz > it.z)
							if yM < wall and not atPort then
								clear = false
								break
							end
							if yM < 0 then
								clear = false -- below the deck: the hull side itself
								break
							end
						end
						inside = nowInside
						for j, bx in ipairs(boxes) do
							if j ~= i and not (chaser and bx.bow) and bx.y0 < yM + 0.3 and bx.y1 > yM - 0.2 then
								local ox, oz = px - bx.x, -(pz - bx.z)
								local lx = ox * bx.c - oz * bx.s
								local lz = ox * bx.s + oz * bx.c
								if math.abs(lx) <= bx.hx and math.abs(lz) <= bx.hz then
									clear = false
									break
								end
							end
						end
						if not clear then
							break
						end
					end
				end
				if clear then
					if cur then
						cur[2] = b
					else
						cur = { b, b }
						table.insert(fire, cur)
					end
				else
					cur = nil
				end
			end
			out[i] = { face = face, trav = trav, fire = fire }
		end
	end
	return out
end

-- v0.25.155 (#34): the side (1 starboard, -1 port) of the gun port a deck-edge cannon fires through, nil = none
-- (same rule as the bulwark gaps in BuildHull)
function H.PortSide(design, it)
	local def = ShipParts[it.id]
	if not (def and def.cannon) or math.abs(it.y) >= 1 or math.abs(it.x) <= 1 then
		return nil
	end
	if math.abs(it.x) > topHalfWidth(H.Slices(design.hull))(it.z) - 4 then
		return it.x > 0 and 1 or -1
	end
	return nil
end

-- is a bearing (degrees) inside one of the fire spans (spans may run past +-180)?
function H.InArc(fire, bearing)
	for _, sp in ipairs(fire or {}) do
		local d = (bearing - sp[1]) % 360
		if d <= (sp[2] - sp[1]) + 1e-6 then
			return true
		end
	end
	return false
end
function H.ArcString(fire)
	local t = {}
	for _, sp in ipairs(fire or {}) do
		table.insert(t, string.format("%d:%d", math.floor(sp[1] + 0.5), math.floor(sp[2] + 0.5)))
	end
	return table.concat(t, ";")
end
function H.ArcParse(s)
	local out = {}
	for a, b in string.gmatch(s or "", "(%-?%d+):(%-?%d+)") do
		table.insert(out, { tonumber(a), tonumber(b) })
	end
	return out
end

-- v0.25.153: ships saved before rudders existed get one at the stern (free; DataService + the builder call this)
function H.EnsureRudder(design)
	if type(design) ~= "table" or design.v ~= 2 then
		return false
	end
	for _, it in ipairs(design.items or {}) do
		if it.id == "Rudder" then
			return false
		end
	end
	local nd = design.hull.nodes[1]
	table.insert(design.items, { id = "Rudder", x = 0, y = -(nd and nd.d or 3), z = -(design.hull.stern or 0) * 0.3 - 0.5, r = 0, sx = 1, sy = 1, sz = 1 })
	if type(design.paid) == "table" then
		addCost(design.paid, ShipParts.Rudder.cost, 1) -- free: SAVE must not bill it
		design.gift = design.gift or {}
		addCost(design.gift, ShipParts.Rudder.cost, 1) -- ...nor pay it out when taken apart
	end
	return true
end

-- ===== stats for ShipStats.Compute =====
function H.Compute(design)
	local ph = H.Physics(design)
	local mat = H.MaterialOf(design.hull)
	local r = { weight = ph.weight, hp = math.floor(ph.hullVol * H.HpPerVol * mat.hp), thrust = 0, oars = 0, oarPower = 0, cannons = {}, crewCap = 0, speedBonus = 0, helm = 0, rudder = 0, partCount = 0, value = 0, specials = 0, kegs = 0, pumps = 0, spyglass = false }
	local sails, oars = {}, {}
	local rudderK = 1
	local arcs = H.Arcs(design)
	for idx, it in ipairs(H.Expand(design)) do
		local def = ShipParts[it.id]
		local k = weightScale(it)
		r.partCount += 1
		r.hp += math.floor(def.hp * math.max(1, k))
		if def.thrust then
			table.insert(sails, def.thrust * (it.sx or 1) * (it.sy or 1))
		end
		if def.oar then
			table.insert(oars, def.oar)
		end
		if def.cannon and def.cannon.special then
			r.specials += 1 -- v0.25.155: harpoon / fire pot, fired on their own key, not in the broadside
		elseif def.cannon then
			local cs = H.CannonStats(it)
			table.insert(r.cannons, { part = it, index = idx, damage = cs.damage, range = cs.range, speed = cs.speed, reload = cs.reload, lob = cs.lob, arcs = arcs[idx] })
		end
		r.kegs += def.kegs or 0
		r.pumps += def.pump and 1 or 0
		r.spyglass = r.spyglass or def.spyglass == true
		if def.crew then
			r.crewCap += math.max(1, math.floor(def.crew * k + 0.5))
		end
		r.speedBonus += def.speedBonus or 0
		if it.id == "Helm" then
			r.helm += 1
		end
		if def.rudder then
			r.rudder += 1
			rudderK = clamp(0.55 + 0.45 * (it.sy or 1) * (it.sz or 1), 0.6, 1.5)
		end
	end
	-- #26: the best sail / bench counts fully, each next one less; ShipStats.Speed then takes the stronger of the two
	table.sort(sails, function(a, b)
		return a > b
	end)
	for i, t in ipairs(sails) do
		r.thrust += t * H.SailFalloff ^ (i - 1)
	end
	table.sort(oars, function(a, b)
		return a > b
	end)
	r.oarList = oars
	r.oars = #oars
	r.oarPower = oars[1] or 0
	r.value = (H.Cost(design).beli or 0)
	-- long, slim hulls run faster; tubby ones slower (Shipshaper: hull shape matters)
	r.speedBonus += clamp((ph.fineness - 3.2) * 0.06, -0.15, 0.15)
	r.rudderK = rudderK
	r.lengthTurn = clamp(40 / math.max(ph.length, 10), 0.6, 1.3) * (r.rudder > 0 and rudderK or 0.25)
	r.phys = ph
	if r.helm < 1 then
		r.problem = "Needs a helm (Core parts)"
	elseif r.rudder < 1 then
		r.problem = "Needs a rudder at the stern (Core parts)"
	elseif #sails == 0 and #oars == 0 then
		r.problem = "Needs a sail or an oar bench to move"
	elseif ph.sinks then
		r.problem = "Too heavy: it would sink. Make the hull bigger or deeper"
	elseif ph.floods then
		r.problem = "Too heavy: water floods the deck. Deepen or widen the hull"
	elseif ph.capsizes then
		r.problem = "Unstable: it would capsize. Widen the hull or lower heavy parts"
	end
	return r
end

-- ===== bounds (studs, ship space) =====
function H.Bounds(design)
	local sl = H.Slices(design.hull)
	local hw = 0
	for _, nd in ipairs(design.hull.nodes) do
		hw = math.max(hw, nd.w)
	end
	local minV = Vector3.new(-hw, -sl.D, sl.zMin)
	local maxV = Vector3.new(hw, (design.hull.wall or 0), sl.zMax)
	for _, it in ipairs(H.Expand(design)) do
		local size = itemSize(it)
		local e = math.max(size.X, size.Z) / 2
		minV = minV:Min(Vector3.new(it.x - e, it.y, it.z - e))
		maxV = maxV:Max(Vector3.new(it.x + e, it.y + size.Y, it.z + e))
	end
	return minV, maxV
end

-- ===== building =====
local function mk(parent, size, color, cf, material, name)
	local p = Instance.new("Part")
	p.Name = name or "Hull"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Anchored = true
	p.Parent = parent
	return p
end
local function shade(c, k)
	return k >= 0 and c:Lerp(Color3.new(1, 1, 1), k) or c:Lerp(Color3.new(0, 0, 0), -k)
end

-- paint for this build: design.paint, overridden per zone by colorFn({ id = "Paint:<zone>" }) (Marine livery)
function H.PaintOf(design, colorFn)
	local out = {}
	for _, k in ipairs(H.Zones) do
		local c = colorFn and colorFn({ id = "Paint:" .. k })
		out[k] = typeof(c) == "Color3" and c or H.Color((design.paint or {})[k] or H.DefaultPaint[k])
	end
	return out
end

local GOLD = Color3.fromRGB(232, 192, 80)

-- the hull ("Shell" model: never broken off by ShipService.Smash, which only takes "Hull" / "Wedge" models)
function H.BuildHull(design, originCf, colorFn, parent)
	local hull = design.hull
	local paint = H.PaintOf(design, colorFn)
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	local sl = H.Slices(hull)
	local nL = #sl.layers
	local bottomTop = -sl.D * 0.42
	local mat = H.MaterialOf(hull)
	local hullMat = Enum.Material[mat.mat] or Enum.Material.Wood
	local iron = Color3.fromRGB(64, 66, 72)
	local function detail(size, color, cf, material)
		local p = mk(shell, size, color, cf, material, "Detail")
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		return p
	end
	for j, layer in ipairs(sl.layers) do
		local top = j == nL
		local h = layer.y1 - layer.y0
		local base = top and paint.stripe or (layer.y1 <= bottomTop + 0.01 and paint.bottom or paint.hull)
		base = shade(base, ((j % 2 == 0) and -0.07 or 0) + (top and 0 or mat.shade))
		for _, r in ipairs(layer.runs) do
			local len = r.z1 - r.z0
			local zc = (r.z0 + r.z1) / 2
			if top then
				-- top layer = stripe band + the deck on it (WoodPlanks shows boards through MaterialService)
				local bh = math.max(h - 0.3, 0.2)
				mk(shell, Vector3.new(2 * r.hw, bh, len), base, originCf * CFrame.new(0, layer.y0 + bh / 2, -zc), hullMat)
				mk(shell, Vector3.new(2 * r.hw, h - bh, len), paint.deck, originCf * CFrame.new(0, layer.y1 - (h - bh) / 2, -zc), Enum.Material.WoodPlanks, "Deck")
			else
				mk(shell, Vector3.new(2 * r.hw, h, len), base, originCf * CFrame.new(0, (layer.y0 + layer.y1) / 2, -zc), hullMat)
				-- #15 plank seams: a dark line where two strakes meet
				if hull.seams then
					detail(Vector3.new(2 * r.hw + 0.06, 0.12, len + 0.02), shade(base, -0.4), originCf * CFrame.new(0, layer.y1 - 0.06, -zc), hullMat)
				end
			end
			if top and hull.rivets then
				local z = math.ceil(r.z0 / 2) * 2
				while z <= r.z1 - 0.3 do
					for _, side in ipairs({ -1, 1 }) do
						detail(Vector3.new(0.3, 0.3, 0.3), iron, originCf * CFrame.new(side * r.hw, layer.y0 + 0.35, -z), Enum.Material.Metal)
					end
					z += 2
				end
			end
			if top and hull.trim then
				detail(Vector3.new(2 * r.hw + 0.14, 0.22, len + 0.02), GOLD, originCf * CFrame.new(0, layer.y0 + 0.11, -zc), Enum.Material.SmoothPlastic)
			end
			-- iron-banded hulls (#16): dark iron straps every 4 studs, a hair proud of the planks
			if mat.bands and not top then
				local z = math.ceil(r.z0 / 4) * 4
				while z <= r.z1 - 0.5 do
					local band = mk(shell, Vector3.new(2 * r.hw + 0.12, h + 0.02, 0.5), iron, originCf * CFrame.new(0, (layer.y0 + layer.y1) / 2, -z), Enum.Material.Metal, "Band")
					band.CanCollide = false
					band.CanQuery = false
					z += 4
				end
			end
		end
	end
	-- #17: the ship's name on the stern, gold letters on a rail-colored board
	local topL = sl.layers[nL]
	local stern = topL and topL.runs[1]
	if stern and not hull.noName and type(design.name) == "string" and #design.name > 0 then
		local w = math.max(1.5, 2 * stern.hw * 0.8)
		local board = detail(Vector3.new(w, 0.8, 0.1), paint.rail, originCf * CFrame.new(0, -0.45, -stern.z0 + 0.06), Enum.Material.Wood)
		board.Name = "NameBoard"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- +Z = astern
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.Text = string.upper(design.name)
		t.TextColor3 = GOLD
		t.TextStrokeTransparency = 0.2
		t.Parent = gui
		gui.Parent = board
	end
	-- keel strip under the bottom layer
	local bottom = sl.layers[1]
	if bottom and #bottom.runs > 0 then
		local z0, z1 = bottom.runs[1].z0, bottom.runs[#bottom.runs].z1
		mk(shell, Vector3.new(0.8, 0.5, z1 - z0), paint.rail, originCf * CFrame.new(0, bottom.y0 - 0.25, -(z0 + z1) / 2)).CanCollide = false
	end
	-- bulwarks: side walls on the top layer's runs, fillers where the width steps, a transom aft and a breastwork fore,
	-- a rail cap on top; gaps where a cannon stands at the edge (gun ports)
	local wall = hull.wall or 0
	local topLayer = sl.layers[nL]
	if wall > 0 and topLayer and #topLayer.runs > 0 then
		local ports = { [-1] = {}, [1] = {} }
		for _, it in ipairs(H.Expand(design)) do
			if ShipParts[it.id].cannon and math.abs(it.y) < 1 and math.abs(it.x) > 1 then
				table.insert(ports[it.x > 0 and 1 or -1], { it.z - 1.4, it.z + 1.4, math.abs(it.x) })
			end
		end
		local runs = topLayer.runs
		local function segment(side, hw, z0, z1)
			-- cut the port gaps out of [z0, z1]
			local cuts = {}
			for _, pt in ipairs(ports[side]) do
				if pt[3] > hw - 4 and pt[2] > z0 and pt[1] < z1 then
					table.insert(cuts, pt)
				end
			end
			table.sort(cuts, function(a, b)
				return a[1] < b[1]
			end)
			local a = z0
			local pieces = {}
			for _, c in ipairs(cuts) do
				if c[1] > a then
					table.insert(pieces, { a, c[1] })
				end
				a = math.max(a, c[2])
			end
			if z1 > a then
				table.insert(pieces, { a, z1 })
			end
			for _, pc in ipairs(pieces) do
				local len = pc[2] - pc[1]
				if len > 0.05 then
					local zc = (pc[1] + pc[2]) / 2
					mk(shell, Vector3.new(0.5, wall, len), paint.hull, originCf * CFrame.new(side * (hw - 0.25), wall / 2, -zc), Enum.Material.Wood, "Wall")
					mk(shell, Vector3.new(0.8, 0.3, len), paint.rail, originCf * CFrame.new(side * (hw - 0.3), wall + 0.15, -zc), Enum.Material.Wood, "Rail")
				end
			end
		end
		for i, r in ipairs(runs) do
			for _, side in ipairs({ -1, 1 }) do
				segment(side, r.hw, r.z0, r.z1)
				local nxt = runs[i + 1]
				if nxt and math.abs(nxt.z0 - r.z1) < 1e-6 and nxt.hw ~= r.hw then
					local a, b = math.min(r.hw, nxt.hw) - 0.5, math.max(r.hw, nxt.hw)
					mk(shell, Vector3.new(b - a, wall, 0.5), paint.hull, originCf * CFrame.new(side * (a + b) / 2, wall / 2, -r.z1), Enum.Material.Wood, "Wall")
					mk(shell, Vector3.new(b - a + 0.1, 0.3, 0.8), paint.rail, originCf * CFrame.new(side * (a + b) / 2, wall + 0.15, -r.z1), Enum.Material.Wood, "Rail")
				end
			end
		end
		-- v0.25.155 (#34): a lid on every gun port, shut (flush with the bulwark) and open (swung up and out, red
		-- inside); clients show one of the two (Controllers/Sailing: open after a shot, shut on the low side in a heel)
		local hwAt = topHalfWidth(sl)
		for _, side in ipairs({ -1, 1 }) do
			for _, pt in ipairs(ports[side]) do
				local z = (pt[1] + pt[2]) / 2
				local hw = hwAt(z)
				if hw > 0 and pt[3] > hw - 4 then
					local len = pt[2] - pt[1]
					local shut = mk(shell, Vector3.new(0.4, wall, len), shade(paint.hull, -0.12), originCf * CFrame.new(side * (hw - 0.2), wall / 2, -z), Enum.Material.WoodPlanks, "PortShut")
					local open = mk(shell, Vector3.new(0.4, wall, len), Color3.fromRGB(176, 52, 44), originCf * CFrame.new(side * hw, wall, -z) * CFrame.Angles(0, 0, side * math.rad(75)) * CFrame.new(-side * 0.2, -wall / 2, 0), Enum.Material.WoodPlanks, "PortOpen")
					for _, lid in ipairs({ shut, open }) do
						lid.CanCollide = false
						lid.CanQuery = false
						lid:SetAttribute("PortSide", side)
					end
					open.Transparency = 1
				end
			end
		end
		local first, last = runs[1], runs[#runs]
		mk(shell, Vector3.new(2 * first.hw, wall, 0.5), paint.hull, originCf * CFrame.new(0, wall / 2, -(first.z0 + 0.25)), Enum.Material.Wood, "Wall")
		mk(shell, Vector3.new(2 * first.hw, 0.3, 0.8), paint.rail, originCf * CFrame.new(0, wall + 0.15, -(first.z0 + 0.3)), Enum.Material.Wood, "Rail")
		mk(shell, Vector3.new(2 * last.hw, wall, 0.5), paint.hull, originCf * CFrame.new(0, wall / 2, -(last.z1 - 0.25)), Enum.Material.Wood, "Wall")
		mk(shell, Vector3.new(2 * last.hw, 0.3, 0.8), paint.rail, originCf * CFrame.new(0, wall + 0.15, -(last.z1 - 0.3)), Enum.Material.Wood, "Rail")
	end
	shell.Parent = parent
	return shell
end

-- #5 #10: a superstructure that follows the hull rows (house = block per row, rail = both edges, awning = canvas)
local function buildConform(it, originCf, colorFn, design)
	local def = ShipParts[it.id]
	local paint = H.PaintOf(design, colorFn)
	local model = Instance.new("Model")
	model.Name = it.id
	local rows = H.ConformRows(design, it)
	local Hh = def.size.Y * G * (it.sy or 1)
	local y0 = it.y
	local color = (colorFn and colorFn({ id = it.id })) or def.color
	local main
	local function part(size, c, cf, material, collide)
		local p = mk(model, size, c, originCf * cf, material or Enum.Material.Wood, "Part")
		p.CanCollide = collide ~= false
		main = main or p
		return p
	end
	if def.conform == "house" then
		local L = H.Slices(design.hull).L
		for i, r in ipairs(rows) do
			local len, zc = r.z1 - r.z0, (r.z0 + r.z1) / 2
			part(Vector3.new(2 * r.hw, Hh, len), i % 2 == 0 and shade(color, -0.05) or color, CFrame.new(0, y0 + Hh / 2, -zc), Enum.Material.WoodPlanks)
			part(Vector3.new(2 * r.hw + 0.12, 0.3, len + 0.02), paint.rail, CFrame.new(0, y0 + Hh - 0.15, -zc), Enum.Material.Wood, false)
			-- lit windows along both sides
			if Hh >= 2.5 then
				local z = math.ceil((r.z0 + 1) / 4) * 4
				while z <= r.z1 - 1 do
					for _, side in ipairs({ -1, 1 }) do
						local wdw = part(Vector3.new(0.12, 1, 1.2), Color3.fromRGB(255, 224, 150), CFrame.new(side * (r.hw + 0.04), y0 + Hh * 0.55, -z), Enum.Material.Neon, false)
						wdw.CanQuery = false
					end
					z += 4
				end
			end
		end
		-- a door on the end that faces the middle of the ship
		local a, b = rows[1], rows[#rows]
		local toBow = it.z < L / 2
		local endZ = toBow and b.z1 or a.z0
		local dh = math.min(Hh - 0.4, 3.4)
		if dh > 1.5 then
			local d = part(Vector3.new(1.6, dh, 0.14), Color3.fromRGB(90, 55, 30), CFrame.new(0, y0 + dh / 2, -(endZ + (toBow and 0.06 or -0.06))), Enum.Material.Wood, false)
			d.CanQuery = false
		end
	elseif def.conform == "rail" then
		for _, r in ipairs(rows) do
			local len, zc = r.z1 - r.z0, (r.z0 + r.z1) / 2
			for _, side in ipairs({ -1, 1 }) do
				part(Vector3.new(0.3, 0.25, len + 0.02), color, CFrame.new(side * (r.hw - 0.15), y0 + Hh - 0.12, -zc), Enum.Material.Wood)
				local z = math.ceil(r.z0 / 2) * 2
				while z <= r.z1 do
					part(Vector3.new(0.22, Hh - 0.2, 0.22), shade(color, -0.15), CFrame.new(side * (r.hw - 0.15), y0 + (Hh - 0.2) / 2, -z), Enum.Material.Wood, false)
					z += 2
				end
			end
		end
	else -- awning: striped canvas on four posts
		local a, b = rows[1], rows[#rows]
		for _, pt in ipairs({ { a.hw, a.z0 + 0.2 }, { -a.hw, a.z0 + 0.2 }, { b.hw, b.z1 - 0.2 }, { -b.hw, b.z1 - 0.2 } }) do
			part(Vector3.new(0.3, Hh, 0.3), Color3.fromRGB(130, 85, 50), CFrame.new(pt[1], y0 + Hh / 2, -pt[2]), Enum.Material.Wood, false)
		end
		for _, r in ipairs(rows) do
			local z = r.z0
			while z < r.z1 - 0.05 do
				local z2 = math.min(r.z1, math.floor(z / 2 + 1) * 2)
				local stripe = math.floor(z / 2 + 0.001) % 2 == 0
				local c = part(Vector3.new(2 * r.hw + 0.6, 0.25, z2 - z), stripe and paint.sail or paint.stripe, CFrame.new(0, y0 + Hh + 0.12, -(z + z2) / 2), Enum.Material.Plaster, false)
				c.CanQuery = false
				z = z2
			end
		end
	end
	main.Name = "Main"
	model.PrimaryPart = main
	return model
end

-- one item (or its mirror copy) as a part model at its spot; `design` lets conform superstructures follow the hull
function H.BuildItem(it, originCf, colorFn, buildPart, design)
	if ShipParts[it.id].conform and design then
		local m = buildConform(it, originCf, colorFn, design)
		m:SetAttribute("Item", it.src)
		m:SetAttribute("Mirror", false)
		return m, itemSize(it)
	end
	local rule = H.ScaleRule(it.id)
	local cf, size = H.ItemCFrame(it)
	local p = { id = it.id, x = math.floor(it.x), y = math.floor(it.y), z = math.floor(it.z), r = 0 }
	local color = colorFn and colorFn(p) or nil
	local m
	if rule.axes == "u" then
		local unit = ShipParts[it.id].size * G
		m = buildPart(p, originCf * CFrame.new(it.x, it.y + unit.Y / 2, -it.z) * CFrame.Angles(0, math.rad(it.r or 0), 0), color)
		if math.abs((it.sx or 1) - 1) > 0.01 then
			m.WorldPivot = originCf * CFrame.new(it.x, it.y, -it.z) * CFrame.Angles(0, math.rad(it.r or 0), 0)
			m:ScaleTo(it.sx)
		end
	else
		p.sx, p.sy, p.sz = it.sx, it.sy, it.sz
		m = buildPart(p, originCf * cf, color)
	end
	m:SetAttribute("Item", it.src)
	m:SetAttribute("Mirror", it.mirror == true)
	return m, size
end

-- the whole ship: hull + items. Item models carry Index (position in H.Expand = ShipStats.Parts) + Item (design.items index)
function H.Build(design, originCf, colorFn, buildPart)
	local model = Instance.new("Model")
	model.Name = design.name or "Ship"
	H.BuildHull(design, originCf, colorFn, model)
	for i, it in ipairs(H.Expand(design)) do
		local ok, m = pcall(H.BuildItem, it, originCf, colorFn, buildPart, design)
		if ok and m then
			m:SetAttribute("Index", i)
			m.Parent = model
		end
	end
	local paint = H.PaintOf(design, colorFn)
	model:SetAttribute("SailColor", paint.sail:ToHex())
	return model
end

-- ===== making designs =====
function H.Clone(design)
	local function deep(t)
		if type(t) ~= "table" then
			return t
		end
		local c = {}
		for k, v in pairs(t) do
			c[k] = deep(v)
		end
		return c
	end
	return deep(design)
end

function H.New(name)
	return {
		v = 2,
		name = name or "Ship",
		hull = { nodes = { { z = 0, w = 4.5, d = 3.5, s = "F" }, { z = 12, w = 5.5, d = 4, s = "U" }, { z = 24, w = 1.5, d = 3, s = "V" } }, bow = 3, stern = 1, wall = 1.5 },
		items = { { id = "Helm", x = 0, y = 0, z = 4, r = 0, sx = 1, sy = 1, sz = 1 }, { id = "Rudder", x = 0, y = -3.5, z = -0.8, r = 0, sx = 1, sy = 1, sz = 1 } },
		paint = table.clone(H.DefaultPaint),
	}
end

-- v1 grid design -> v2 (shortcut: the hull is fitted from the deck rows' width and depth; blocks below the deck are
-- replaced by that hull, everything above it becomes free items. Good enough for the old 4-stud boats)
function H.FromV1(d1)
	local rows = {}
	local count = {}
	for _, p in ipairs(d1.parts or {}) do
		local def = ShipParts[p.id]
		if def and BLOCKS[p.id] then
			count[p.y] = (count[p.y] or 0) + 1
		end
	end
	local deckY, best = 0, -1
	for y, n in pairs(count) do
		if n > best or (n == best and y > deckY) then
			deckY, best = y, n
		end
	end
	local minZ, maxZ = math.huge, -math.huge
	for _, p in ipairs(d1.parts or {}) do
		if BLOCKS[p.id] and p.y <= deckY then
			local r = rows[p.z] or { x0 = math.huge, x1 = -math.huge, y0 = math.huge }
			r.x0, r.x1, r.y0 = math.min(r.x0, p.x), math.max(r.x1, p.x), math.min(r.y0, p.y)
			rows[p.z] = r
			minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
		end
	end
	if minZ == math.huge then
		local d = H.New(d1.name)
		return d
	end
	local cx, n = 0, 0
	for _, r in pairs(rows) do
		cx += (r.x0 + r.x1 + 1) / 2 * G
		n += 1
	end
	cx /= n
	local nodes = {}
	local span = maxZ - minZ
	local stepRows = math.max(1, math.ceil(span / 8))
	local zList = {}
	for z = minZ, maxZ, stepRows do
		table.insert(zList, z)
	end
	if zList[#zList] ~= maxZ then
		table.insert(zList, maxZ)
	end
	for _, z in ipairs(zList) do
		local r = rows[z]
		if r then
			table.insert(nodes, { z = (z - minZ) * G, w = math.max(1, (r.x1 - r.x0 + 1) * G / 2), d = math.max(2, (deckY + 1 - r.y0) * G * 0.75), s = "U" })
		end
	end
	if #nodes < 2 then
		table.insert(nodes, { z = math.max(8, (nodes[1] and nodes[1].z or 0) + 8), w = 2, d = 2, s = "V" })
	end
	local deckTop = (deckY + 1) * G
	local items = {}
	for _, p in ipairs(d1.parts or {}) do
		local def = ShipParts[p.id]
		if def and not (BLOCKS[p.id] and p.y <= deckY) then
			local fp = (p.r or 0) % 2 == 1 and Vector3.new(def.size.Z, def.size.Y, def.size.X) or def.size
			table.insert(items, {
				id = p.id,
				x = snap((p.x + fp.X / 2) * G - cx, 0.25),
				y = p.y * G - deckTop,
				z = (p.z + fp.Z / 2) * G - (minZ + 0.5) * G,
				r = ((p.r or 0) * 90) % 360,
				sx = 1, sy = 1, sz = 1,
			})
		end
	end
	local d2 = { v = 2, name = d1.name, hull = { nodes = nodes, bow = 2, stern = 0, wall = 0 }, items = items, paint = table.clone(H.DefaultPaint) }
	H.EnsureRudder(d2)
	return d2
end

return H
