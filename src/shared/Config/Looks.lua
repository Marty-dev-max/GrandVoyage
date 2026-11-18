-- Looks (v0.24.0, owner): the character creator. A look is data: style numbers + free colors (hex "RRGGBB"),
-- validated on the server (Looks.Sanitize) and built into blocks by Shared/Modules/VoxelChar for real characters and
-- the menu preview alike.
--  * Hair, shirt, pants, shoes: voxel styles, each painted with Color 1 + Color 2 (picked on a color wheel)
--  * Eyes: anime-style images (tools/gen_faces.py -> Config/FaceImages) in layers; the iris takes Color 1 + Color 2
--  * Mouth: a finished image (no colors). Skin: one free color.
-- All styles and names are this game's own.
local L = {}

L.Slots = 3 -- character slots per Roblox account (slot 1 = the old single save, so nobody loses progress)
L.Spins = 3 -- Heritage spins a new character gets

-- quick-pick swatches under the color wheel
L.Presets = {
	"1C1A22", "462C1E", "7A4A28", "C48646", "ECC878", "F6ECCE", "F4F4F4", "96989F", "545662", "C42A2E", "EC5A3C", "F6962E",
	"FAD63C", "A0DE46", "3EAA50", "1C6840", "3CD2AA", "46CEEC", "3880EC", "243A96", "181F46", "7850DC", "BA78F6", "F078C8",
	"FAAABE", "961E46", "60181E", "8C6E46", "6E8C5A", "5A8296",
}
L.SkinPresets = {
	"FFE2C4", "F6D0AA", "EABE96", "D6A478", "BE8860", "A06C48", "7C5236", "5C3C28", "FAECDE", "E2C8AA", "C8E6FA", "B4E6C8",
}

L.Hair = {
	"Messy", "Spiky", "Short", "Long", "Ponytail", "Bowl", "Crest", "Bun", "Swept", "Twin Tails", "Fluffy", "Undercut",
	"Side Part", "Long Straight", "Wolf Cut", "Pompadour", "Buzz", "Hero Spikes", "Eye Cover", "Braids", "Topknot", "Afro",
	"Curtain Bangs", "Princess Cut", "Mullet", "Locs", "Shaggy Long", "Bald",
}
L.Shirts = {
	"Tee", "Tank", "Long Sleeve", "Sailor Stripes", "Open Vest", "Captain Coat", "Hoodie", "Wrap Top", "Dojo Gi",
	"Open Jacket", "Polo", "Belted Tunic", "Scarf Tee", "Armor Vest", "Bandage Wrap", "Cook Apron",
}
L.Pants = {
	"Long Pants", "Shorts", "Rolled Cuffs", "Baggy", "Sash Pants", "Skirt", "Cargo", "Side Stripe", "Wide Hakama",
	"Knee Pads", "Overalls", "Capri",
}
L.Shoes = { "Sandals", "Boots", "Sneakers", "Barefoot", "Tall Boots", "Wraps", "Slippers", "Clogs", "Buckle Boots", "Sock Sandals" }

-- face images (Config/FaceImages: eye<N>_white|iris|iris2|over, mouth<N>)
L.Eyes = {
	"Bright", "Gentle", "Sharp", "Fierce", "Sleepy", "Sparkle", "Cat", "Calm", "Happy", "Wink", "Tired", "Starry",
	"Lovestruck", "Determined", "Shy", "Cool", "Spiral", "Shocked", "Closed", "Round",
}
L.Mouths = {
	"Smile", "Grin", "Smirk", "Open", "Flat", "Frown", "Cat", "Fang", "Shout", "Tongue", "Small Smile", "Nervous",
	"Toothy", "Pout", "Laugh", "Clench", "Happy",
}

-- Heritages (the game's own peoples): rolled with spins on the server. Each has looks VARIANTS rolled with it
-- (weights; rarer variants exist) and small perks (Formulas.Compute). Cinderwing (0.1%) is special: its look is
-- locked (dark brown skin, white hair, big black wings + a flame on the back) and it switches between two modes:
-- FLAME (hits much harder) and CALM (moves much faster). Winged heritages can glide (hold Jump in the air).
L.Heritages = {
	{ id = "Islander", name = "Islander", chance = 69.9, color = Color3.fromRGB(236, 220, 190),
		desc = "Born on the Azure islands. Steady and balanced.", perk = "+5% max HP, +5% EXP",
		variants = { { name = "Islander", weight = 1 } } },
	{ id = "Skyborn", name = "Skyborn", chance = 15, color = Color3.fromRGB(150, 220, 255),
		desc = "Folk of the high clouds, with small feathered wings.", perk = "Glide, +15% jump, +5% speed, +5% FLEE", glide = true,
		variants = {
			{ name = "White Wings", weight = 60, wing = "F8F8FF", tip = "BEE6FF" },
			{ name = "Dusk Wings", weight = 25, wing = "8C8CA0", tip = "D2D2E6" },
			{ name = "Golden Wings", weight = 12, wing = "FFDC6E", tip = "FFF5C8" },
			{ name = "Prism Wings", weight = 3, wing = "C8B4FF", tip = "8CFFF0" },
		} },
	{ id = "Tidekin", name = "Tidekin", chance = 10, color = Color3.fromRGB(60, 210, 190),
		desc = "Children of the reef, with a fin crest.", perk = "+60% breath, +8% max SP, +5% DEF",
		variants = {
			{ name = "Reef Fin", weight = 55, fin = "3CC8BE" },
			{ name = "Coral Fin", weight = 25, fin = "F07864" },
			{ name = "Deep Fin", weight = 15, fin = "2846A0" },
			{ name = "Pearl Fin", weight = 5, fin = "F0EBFF" },
		} },
	{ id = "Beastkin", name = "Beastkin", chance = 3, color = Color3.fromRGB(246, 170, 60),
		desc = "Wild folk with sharp ears and a tail.", perk = "+5% ATK, +5% speed",
		variants = {
			{ name = "Cat Ears", weight = 40, ears = "cat" },
			{ name = "Rabbit Ears", weight = 25, ears = "rabbit" },
			{ name = "Bear Ears", weight = 20, ears = "bear" },
			{ name = "Fox Ears", weight = 15, ears = "fox" },
		} },
	{ id = "Oni", name = "Oni", chance = 2, color = Color3.fromRGB(240, 70, 60),
		desc = "Horned mountain folk of old island tales.", perk = "+8% ATK, +6% DEF",
		variants = {
			{ name = "Twin Horns", weight = 50, horns = "twin", horn = "F0E6D2" },
			{ name = "Crimson Horn", weight = 30, horns = "single", horn = "C82832" },
			{ name = "Black Curved Horns", weight = 20, horns = "curved", horn = "28242C" },
		} },
	{ id = "Cinderwing", name = "Cinderwing", chance = 0.1, color = Color3.fromRGB(255, 120, 40), mythic = true,
		desc = "A near-lost people: great black wings and a living flame on the back.",
		perk = "Glide, +10% HP. FLAME: +25% ATK/MATK. CALM: +20% speed, +10% FLEE", glide = true, modes = true,
		lock = { skin = "6E4630", hair1 = "F4F4F4", hair2 = "D2D4DE" },
		variants = { { name = "Cinderwing", weight = 1 } } },
}
L.HeritageById = {}
for _, h in ipairs(L.Heritages) do
	L.HeritageById[h.id] = h
end

-- roll a variant index for a heritage (server)
function L.RollVariant(id, rng)
	local h = L.HeritageById[id]
	if not h or not h.variants then
		return 1
	end
	rng = rng or Random.new()
	local total = 0
	for _, v in ipairs(h.variants) do
		total += v.weight
	end
	local r = rng:NextNumber() * total
	for i, v in ipairs(h.variants) do
		r -= v.weight
		if r <= 0 then
			return i
		end
	end
	return 1
end

function L.Variant(id, index)
	local h = L.HeritageById[id or ""]
	return h and h.variants and (h.variants[index or 1] or h.variants[1]) or nil
end

-- the categories the creator shows (style list + which colors it takes)
L.Categories = {
	{ key = "hair", label = "HAIR", list = L.Hair, colors = { "hair1", "hair2" } },
	{ key = "eyes", label = "EYES", list = L.Eyes, colors = { "eyes1", "eyes2" } },
	{ key = "mouth", label = "MOUTH", list = L.Mouths, colors = {} },
	{ key = "shirt", label = "SHIRT", list = L.Shirts, colors = { "shirt1", "shirt2" } },
	{ key = "pants", label = "PANTS", list = L.Pants, colors = { "pants1", "pants2" } },
	{ key = "shoes", label = "SHOES", list = L.Shoes, colors = { "shoes1", "shoes2" } },
	{ key = "skin", label = "SKIN", list = nil, colors = { "skin" } },
}
L.ColorKeys = { "hair1", "hair2", "eyes1", "eyes2", "shirt1", "shirt2", "pants1", "pants2", "shoes1", "shoes2", "skin" }
L.ColorLabels = {
	hair1 = "HAIR 1", hair2 = "HAIR 2", eyes1 = "EYES 1", eyes2 = "EYES 2", shirt1 = "SHIRT 1", shirt2 = "SHIRT 2",
	pants1 = "PANTS 1", pants2 = "PANTS 2", shoes1 = "SHOES 1", shoes2 = "SHOES 2", skin = "SKIN",
}

local STYLE_LIMITS = { hair = #L.Hair, eyes = #L.Eyes, mouth = #L.Mouths, shirt = #L.Shirts, pants = #L.Pants, shoes = #L.Shoes }
L.Limits = STYLE_LIMITS

function L.Default()
	return {
		hair = 1, eyes = 1, mouth = 1, shirt = 1, pants = 1, shoes = 1,
		hair1 = "462C1E", hair2 = "7A4A28", eyes1 = "3880EC", eyes2 = "243A96", shirt1 = "F4F4F4", shirt2 = "243A96",
		pants1 = "243A96", pants2 = "181F46", shoes1 = "462C1E", shoes2 = "1C1A22", skin = "F6D0AA",
	}
end

-- ===== colors =====
function L.Hex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
function L.FromHex(h)
	if type(h) ~= "string" or not string.match(h, "^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end
function L.Color(look, key)
	return L.FromHex(look[key]) or L.FromHex(L.Default()[key]) or Color3.new(1, 1, 1)
end

-- older test saves (palette numbers) -> hex
local OLD = { hair1 = "hair1", hair2 = "hair2", eyes_c = "eyes1", shirt_c = "shirt1", pants_c = "pants1", shoes_c = "shoes1" }

-- any table from a client -> a clean look (unknown keys dropped, numbers clamped, colors must be hex)
function L.Sanitize(look)
	local out = L.Default()
	if type(look) ~= "table" then
		return out
	end
	for k, max in pairs(STYLE_LIMITS) do
		local n = tonumber(look[k])
		if n and n == n then
			out[k] = math.clamp(math.floor(n), 1, max)
		end
	end
	for _, k in ipairs(L.ColorKeys) do
		local v = look[k]
		if type(v) == "string" then
			v = string.upper(v)
			if L.FromHex(v) then
				out[k] = v
			end
		end
	end
	for old, new in pairs(OLD) do
		local n = tonumber(look[old])
		if n and L.Presets[n] and type(look[new]) ~= "string" then
			out[new] = L.Presets[n]
		end
	end
	return out
end

-- a random look (new slots start from one, and the creator's dice button)
function L.Random(rng)
	rng = rng or Random.new()
	local look = {}
	for k, max in pairs(STYLE_LIMITS) do
		look[k] = rng:NextInteger(1, max)
	end
	look.hair = rng:NextInteger(1, #L.Hair - 1) -- no bald by chance
	for _, k in ipairs(L.ColorKeys) do
		look[k] = L.Presets[rng:NextInteger(1, #L.Presets)]
	end
	look.skin = L.SkinPresets[rng:NextInteger(1, 7)]
	-- hair 2 a shade of hair 1 most of the time, so random hair looks natural
	if rng:NextNumber() < 0.7 then
		look.hair2 = L.Hex(L.FromHex(look.hair1):Lerp(Color3.new(1, 1, 1), 0.25))
	end
	return look
end

function L.RollHeritage(rng)
	rng = rng or Random.new()
	local total = 0
	for _, h in ipairs(L.Heritages) do
		total += h.chance
	end
	local r = rng:NextNumber() * total
	for _, h in ipairs(L.Heritages) do
		r -= h.chance
		if r <= 0 then
			return h.id
		end
	end
	return L.Heritages[1].id
end

return L
