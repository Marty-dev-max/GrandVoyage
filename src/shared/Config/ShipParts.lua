-- ShipParts: free-form ship building blocks (Build-a-Boat style). Every part has weight.
-- size = grid cells (X,Y,Z), each GameConfig.Ship.GridSize studs
-- thrust = sail power (needs wind), oar = rowing power (needs crew, works in the Doldrums)
-- cannon = one cannon, crew = extra crew capacity
local P = {}
local order = {}
local function part(id, def)
	def.id = id
	def.size = def.size or Vector3.new(1, 1, 1)
	def.hp = def.hp or 50
	def.cost = def.cost or {}
	P[id] = def
	table.insert(order, id)
end

part("Helm", { name = "Helm", category = "Core", weight = 20, hp = 150, size = Vector3.new(1, 1, 1),
	required = true, max = 1, crew = 2, color = Color3.fromRGB(150, 95, 55), cost = { beli = 0 } })
-- v0.25.153 (Plan-Ships-v2 #13): every ship needs a rudder at the stern; a bigger blade turns faster
part("Rudder", { name = "Rudder", category = "Core", weight = 14, hp = 90, size = Vector3.new(0.25, 1, 0.75),
	required = true, max = 1, rudder = true, color = Color3.fromRGB(120, 80, 45), material = "Wood", cost = { beli = 200, Wood = 2 } })
-- Hull
part("PlankBlock", { name = "Plank Block", category = "Hull", weight = 10, hp = 70,
	color = Color3.fromRGB(196, 140, 88), material = "WoodPlanks", cost = { beli = 40, Wood = 1 } })
part("PlankSlab", { name = "Deck Slab", category = "Hull", weight = 5, hp = 35, slab = true,
	color = Color3.fromRGB(214, 165, 110), material = "WoodPlanks", cost = { beli = 25, Wood = 1 } })
part("PlankWedge", { name = "Bow Wedge", category = "Hull", weight = 8, hp = 60, wedge = true,
	color = Color3.fromRGB(196, 140, 88), material = "WoodPlanks", cost = { beli = 40, Wood = 1 } })
part("OakBlock", { name = "Oak Block", category = "Hull", weight = 16, hp = 140,
	color = Color3.fromRGB(140, 95, 60), material = "Wood", cost = { beli = 150, Wood = 3 } })
part("IronPlate", { name = "Iron Plating", category = "Hull", weight = 38, hp = 300,
	color = Color3.fromRGB(120, 125, 135), material = "DiamondPlate", cost = { beli = 600, IronIngot = 2 } })
-- v0.25.150 (owner refs: decked sloop with stairs + rails): walkable stairs (climb toward the part's +Z) and a railing
part("Stairs", { name = "Deck Stairs", category = "Hull", weight = 7, hp = 50, stairs = true,
	color = Color3.fromRGB(205, 155, 100), material = "WoodPlanks", cost = { beli = 40, Wood = 1 } })
part("Railing", { name = "Railing", category = "Hull", weight = 3, hp = 25, railing = true,
	color = Color3.fromRGB(150, 100, 62), material = "Wood", cost = { beli = 20, Wood = 1 } })
-- v0.25.153 (Plan-Ships-v2 #22): a ballast keel under the hull: heavy and low (steadier), cuts the heel from the wind
part("Keel", { name = "Keel", category = "Hull", weight = 40, hp = 120, size = Vector3.new(0.25, 0.5, 3), keel = true,
	color = Color3.fromRGB(70, 50, 36), material = "Wood", cost = { beli = 400, Wood = 3, IronIngot = 1 } })
part("TreasureBlock", { name = "Treasure Wood Block", category = "Hull", weight = 12, hp = 320,
	color = Color3.fromRGB(230, 200, 140), material = "Wood", cost = { beli = 5000, TreasureWood = 1 } })
-- v0.25.154 (Plan-Ships-v2 #5 #9 #10): superstructures that FOLLOW THE HULL: conform = "house" (castle / deckhouse
-- block whose width is the hull's at every stud, minus an inset), "rail" (rails along both deck edges), "awning"
-- (striped canvas on posts). Always on the centre line; the builder scales HEIGHT + LENGTH, the width comes from the
-- hull (ShipHull.Expand). Stack a shorter castle on a castle for tiers, add a Balcony to its stern.
part("Deckhouse", { name = "Castle Deck", category = "Hull", weight = 30, hp = 160, size = Vector3.new(2, 0.75, 2), conform = "house",
	color = Color3.fromRGB(176, 128, 84), material = "WoodPlanks", cost = { beli = 300, Wood = 6 } })
part("EdgeRail", { name = "Edge Rail", category = "Hull", weight = 6, hp = 30, size = Vector3.new(2, 0.375, 2), conform = "rail",
	color = Color3.fromRGB(150, 100, 62), material = "Wood", cost = { beli = 60, Wood = 2 } })
part("Balcony", { name = "Balcony", category = "Hull", weight = 14, hp = 60, size = Vector3.new(1.5, 1, 1), balcony = true,
	color = Color3.fromRGB(150, 100, 62), material = "WoodPlanks", cost = { beli = 300, Wood = 4 } })
-- Sails
part("SmallMast", { name = "Small Mast", category = "Sail", weight = 25, hp = 80, size = Vector3.new(1, 4, 1),
	thrust = 30, color = Color3.fromRGB(250, 245, 230), cost = { beli = 500, Wood = 4, SailCloth = 3 } })
part("LargeMast", { name = "Large Mast", category = "Sail", weight = 55, hp = 160, size = Vector3.new(1, 6, 1),
	thrust = 72, color = Color3.fromRGB(250, 245, 230), cost = { beli = 2500, Wood = 8, SailCloth = 8 } })
part("JollySail", { name = "Jolly Roger Mast", category = "Sail", weight = 50, hp = 170, size = Vector3.new(1, 6, 1),
	thrust = 78, color = Color3.fromRGB(40, 40, 45), faction = "Pirate", cost = { beli = 8000, SailCloth = 10, TreasureMap = 1 } })
part("MarineSail", { name = "Marine Mast", category = "Sail", weight = 50, hp = 170, size = Vector3.new(1, 6, 1),
	thrust = 78, color = Color3.fromRGB(245, 248, 255), faction = "Marine", cost = { beli = 8000, SailCloth = 10, MarineBadge = 20 } })
-- v0.25.153 (Plan-Ships-v2 #27): a jib on the bow adds sail area cheaply (sails: the best one counts fully, every next
-- one a bit less; ShipHull.Compute)
part("Jib", { name = "Jib Sail", category = "Sail", weight = 12, hp = 50, size = Vector3.new(0.25, 3, 1.5), thrust = 22, jib = true,
	color = Color3.fromRGB(250, 245, 230), cost = { beli = 600, Wood = 2, SailCloth = 3 } })
-- v0.25.154 (#12): bowsprit = a spar out over the bow (a little extra speed: the jib sets further out)
part("Bowsprit", { name = "Bowsprit", category = "Sail", weight = 10, hp = 40, size = Vector3.new(0.25, 0.25, 2), spar = true, speedBonus = 0.02, max = 1,
	color = Color3.fromRGB(130, 85, 50), material = "Wood", cost = { beli = 400, Wood = 3 } })
part("OarBench", { name = "Oar Bench", category = "Sail", weight = 15, hp = 50, size = Vector3.new(1, 1, 1),
	oar = 7, color = Color3.fromRGB(170, 120, 75), cost = { beli = 300, Wood = 3 } })
-- Weapons
-- v0.25.153 (Plan-Ships-v2 #24 #25): cannon = { damage, range, trav = half traverse arc (deg), reload x, speed x (shot),
-- bore / len = barrel look, lob = fires over its own ship (mortar) }. Builder scales bore (sx) and barrel length (sz):
-- a fatter bore hits harder and weighs more, a longer barrel reaches further and flies faster (ShipHull.CannonStats)
part("Swivel", { name = "Swivel Gun", category = "Weapon", weight = 10, hp = 50, size = Vector3.new(0.5, 1, 0.5),
	cannon = { damage = 28, range = 170, trav = 120, reload = 0.5, speed = 1.2, bore = 0.22, len = 0.7, swivel = true },
	color = Color3.fromRGB(150, 120, 70), cost = { beli = 600, IronIngot = 1, Gunpowder = 1 } })
part("LightCannon", { name = "Light Cannon", category = "Weapon", weight = 30, hp = 90,
	cannon = { damage = 60, range = 230, trav = 40, reload = 1, speed = 1, bore = 0.4, len = 1.05 }, color = Color3.fromRGB(60, 60, 65), cost = { beli = 1500, IronIngot = 2, Gunpowder = 2 } })
part("LongGun", { name = "Long Gun", category = "Weapon", weight = 55, hp = 110,
	cannon = { damage = 75, range = 340, trav = 32, reload = 1.15, speed = 1.35, bore = 0.36, len = 1.6 }, color = Color3.fromRGB(70, 74, 82), cost = { beli = 4500, IronIngot = 5, Gunpowder = 4 } })
part("Carronade", { name = "Carronade", category = "Weapon", weight = 45, hp = 120,
	cannon = { damage = 165, range = 150, trav = 40, reload = 1.1, speed = 0.8, bore = 0.6, len = 0.8 }, color = Color3.fromRGB(40, 40, 44), cost = { beli = 4000, IronIngot = 4, Gunpowder = 4 } })
part("HeavyCannon", { name = "Heavy Cannon", category = "Weapon", weight = 65, hp = 140,
	cannon = { damage = 120, range = 270, trav = 35, reload = 1.3, speed = 1, bore = 0.5, len = 1.25 }, color = Color3.fromRGB(45, 45, 50), cost = { beli = 6000, IronIngot = 6, Gunpowder = 5 } })
part("Mortar", { name = "Mortar", category = "Weapon", weight = 90, hp = 160,
	cannon = { damage = 210, range = 380, trav = 180, reload = 2.2, speed = 0.7, bore = 0.75, len = 0.7, lob = true }, color = Color3.fromRGB(55, 52, 50), cost = { beli = 9000, IronIngot = 8, Gunpowder = 6 } })
-- Cabins / decoration
part("CrewCabin", { name = "Crew Cabin", category = "Utility", weight = 45, hp = 160, size = Vector3.new(2, 2, 2),
	crew = 4, color = Color3.fromRGB(180, 120, 80), cost = { beli = 2000, Wood = 10 } })
part("RamHead", { name = "Ram Figurehead", category = "Utility", weight = 15, hp = 60, max = 1,
	speedBonus = 0.05, color = Color3.fromRGB(255, 255, 240), cost = { beli = 3000, Wood = 5 } })
part("LionHead", { name = "Lion Figurehead", category = "Utility", weight = 25, hp = 120, max = 1,
	speedBonus = 0.08, color = Color3.fromRGB(255, 200, 60), cost = { beli = 20000, TreasureWood = 1 } })
part("Barrel", { name = "Barrel", category = "Utility", weight = 6, hp = 20,
	color = Color3.fromRGB(160, 108, 64), cost = { beli = 60, Wood = 1 } })
part("Lantern", { name = "Lantern", category = "Utility", weight = 3, hp = 10, slab = true,
	color = Color3.fromRGB(255, 220, 120), light = true, cost = { beli = 100 } })
part("Awning", { name = "Awning", category = "Utility", weight = 8, hp = 20, size = Vector3.new(2, 1.1, 2), conform = "awning",
	color = Color3.fromRGB(246, 241, 226), cost = { beli = 250, Wood = 2, SailCloth = 2 } })
-- v0.25.154 (#12 #35): decor. wall = true parts stick to walls and hull sides (they face out of the face you click)
part("Flag", { name = "Flag", category = "Decor", weight = 2, hp = 10, size = Vector3.new(0.25, 1.5, 0.25), flag = true,
	color = Color3.fromRGB(190, 50, 45), cost = { beli = 80, SailCloth = 1 } })
part("FlagLine", { name = "Signal Flags", category = "Decor", weight = 2, hp = 10, size = Vector3.new(0.25, 1, 3), flagLine = true,
	color = Color3.fromRGB(230, 70, 60), cost = { beli = 120, SailCloth = 1 } })
part("Window", { name = "Window", category = "Decor", weight = 2, hp = 10, size = Vector3.new(0.5, 0.5, 0.1), wall = true,
	color = Color3.fromRGB(110, 72, 42), cost = { beli = 60, Wood = 1 } })
part("EntryPort", { name = "Entry Port", category = "Decor", weight = 3, hp = 15, size = Vector3.new(0.6, 0.9, 0.1), wall = true,
	color = Color3.fromRGB(110, 72, 42), cost = { beli = 80, Wood = 1 } })
part("Ladder", { name = "Ladder", category = "Decor", weight = 3, hp = 15, size = Vector3.new(0.4, 1, 0.1), wall = true, ladder = true,
	color = Color3.fromRGB(150, 100, 62), cost = { beli = 40, Wood = 1 } })
part("Hatch", { name = "Hatch", category = "Decor", weight = 4, hp = 20, size = Vector3.new(0.75, 0.1, 0.75),
	color = Color3.fromRGB(120, 82, 50), cost = { beli = 60, Wood = 1 } })
part("RopeCoil", { name = "Rope Coil", category = "Decor", weight = 2, hp = 10, size = Vector3.new(0.5, 0.15, 0.5),
	color = Color3.fromRGB(205, 175, 120), cost = { beli = 30 } })
part("Crate", { name = "Crate", category = "Decor", weight = 6, hp = 25, size = Vector3.new(0.6, 0.6, 0.6),
	color = Color3.fromRGB(180, 130, 80), cost = { beli = 50, Wood = 1 } })

return { Parts = P, Order = order, Categories = { "Core", "Hull", "Sail", "Weapon", "Utility", "Decor" } }
