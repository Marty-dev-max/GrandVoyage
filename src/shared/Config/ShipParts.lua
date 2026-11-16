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
part("TreasureBlock", { name = "Treasure Wood Block", category = "Hull", weight = 12, hp = 320,
	color = Color3.fromRGB(230, 200, 140), material = "Wood", cost = { beli = 5000, TreasureWood = 1 } })
-- Sails
part("SmallMast", { name = "Small Mast", category = "Sail", weight = 25, hp = 80, size = Vector3.new(1, 4, 1),
	thrust = 30, color = Color3.fromRGB(250, 245, 230), cost = { beli = 500, Wood = 4, SailCloth = 3 } })
part("LargeMast", { name = "Large Mast", category = "Sail", weight = 55, hp = 160, size = Vector3.new(1, 6, 1),
	thrust = 72, color = Color3.fromRGB(250, 245, 230), cost = { beli = 2500, Wood = 8, SailCloth = 8 } })
part("JollySail", { name = "Jolly Roger Mast", category = "Sail", weight = 50, hp = 170, size = Vector3.new(1, 6, 1),
	thrust = 78, color = Color3.fromRGB(40, 40, 45), faction = "Pirate", cost = { beli = 8000, SailCloth = 10, TreasureMap = 1 } })
part("MarineSail", { name = "Marine Mast", category = "Sail", weight = 50, hp = 170, size = Vector3.new(1, 6, 1),
	thrust = 78, color = Color3.fromRGB(245, 248, 255), faction = "Marine", cost = { beli = 8000, SailCloth = 10, MarineBadge = 20 } })
part("OarBench", { name = "Oar Bench", category = "Sail", weight = 15, hp = 50, size = Vector3.new(1, 1, 1),
	oar = 7, color = Color3.fromRGB(170, 120, 75), cost = { beli = 300, Wood = 3 } })
-- Weapons
part("LightCannon", { name = "Light Cannon", category = "Weapon", weight = 30, hp = 90,
	cannon = { damage = 60, range = 230 }, color = Color3.fromRGB(60, 60, 65), cost = { beli = 1500, IronIngot = 2, Gunpowder = 2 } })
part("HeavyCannon", { name = "Heavy Cannon", category = "Weapon", weight = 65, hp = 140,
	cannon = { damage = 120, range = 270 }, color = Color3.fromRGB(45, 45, 50), cost = { beli = 6000, IronIngot = 6, Gunpowder = 5 } })
-- Cabins / decoration
part("CrewCabin", { name = "Crew Cabin", category = "Utility", weight = 45, hp = 160, size = Vector3.new(2, 2, 2),
	crew = 4, color = Color3.fromRGB(180, 120, 80), cost = { beli = 2000, Wood = 10 } })
part("RamHead", { name = "Ram Figurehead", category = "Utility", weight = 15, hp = 60, max = 1,
	speedBonus = 0.05, color = Color3.fromRGB(255, 255, 240), cost = { beli = 3000, Wood = 5 } })
part("LionHead", { name = "Lion Figurehead", category = "Utility", weight = 25, hp = 120, max = 1,
	speedBonus = 0.08, color = Color3.fromRGB(255, 200, 60), cost = { beli = 20000, TreasureWood = 1 } })
part("Lantern", { name = "Lantern", category = "Utility", weight = 3, hp = 10, slab = true,
	color = Color3.fromRGB(255, 220, 120), light = true, cost = { beli = 100 } })

return { Parts = P, Order = order, Categories = { "Core", "Hull", "Sail", "Weapon", "Utility" } }
