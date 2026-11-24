-- Recruits (v0.25.142, owner): crew are PEOPLE you recruit, not a number you buy. Sailors of every race hang around
-- the taverns (they stroll about); talk to one to size them up, then give them what they ask for (some want
-- Doubloons, some want an item) and they join your crew: they stand on your ship at their post and help.
-- Everything about a candidate comes from one seed, so the server and the client build the same person.
local Looks = require(script.Parent.Looks)

local R = {}

R.Rotate = 900 -- s: each tavern's sailors move on and new ones come in
R.PerTavern = 4
R.WanderRadius = 3.5 -- studs around their spot (client side, Controllers/RecruitLife)
R.TalkRange = 22 -- server: how close you must be to the sailor's spot to recruit

-- what each job does on YOUR ship (per star, summed over the crew, capped)
R.Professions = {
	Gunner = { name = "Gunner", icon = "💣", outfit = { "Sailor Stripes", "Rolled Cuffs", "Boots" },
		desc = "Mans a cannon. Your cannons reload faster.", stat = "reload", per = 0.04, fmt = "-%d%% reload" },
	Rower = { name = "Rower", icon = "🚣", outfit = { "Open Vest", "Shorts", "Sandals" },
		desc = "Pulls an oar. Your ship sails faster.", stat = "speed", per = 0.025, fmt = "+%d%% ship speed" },
	Carpenter = { name = "Carpenter", icon = "🔨", outfit = { "Tank", "Overalls", "Buckle Boots" },
		desc = "Patches the hull while you sail.", stat = "repair", per = 0.002, fmt = "+%.1f%% hull / s" },
	Cook = { name = "Cook", icon = "🍖", outfit = { "Cook Apron", "Long Pants", "Clogs" },
		desc = "Feeds everyone aboard: heals HP over time.", stat = "heal", per = 0.006, fmt = "+%.1f%% HP / s" },
}
R.ProfOrder = { "Gunner", "Rower", "Carpenter", "Cook" }
R.Caps = { reload = 0.3, speed = 0.2, repair = 0.012, heal = 0.03 }

-- races seen in the first sea's taverns (weighted by repeats); never Cinderwing
R.Races = { "Islander", "Islander", "Islander", "Islander", "Skyborn", "Skyborn", "Tidekin", "Tidekin", "Beastkin", "Oni" }
R.StarWeights = { 60, 30, 10 }

-- original sailor names
R.First = { "Bram", "Tilda", "Osk", "Nell", "Corvin", "Mira", "Juno", "Fenn", "Rook", "Ysa", "Dag", "Pell", "Wren", "Huck",
	"Sable", "Toma", "Kip", "Odile", "Barro", "Lune", "Gage", "Ivy", "Moss", "Rhea", "Cobb", "Edda", "Finch", "Nico" }
R.Last = { "Saltwhistle", "Ropeburn", "Gullfeather", "Barnacle", "Tidewell", "Brinehart", "Keelson", "Driftmoor",
	"Foghorn", "Stormwick", "Mastwood", "Pebbleton", "Shellby", "Copperhook", "Ashbourne", "Wavecrest" }

-- what they ask for: Doubloons, or an item that fits their job (qty by stars)
R.Coins = { 800, 2400, 6000 }
R.ItemAsks = {
	Gunner = { { "Gunpowder", { 4, 8, 14 } }, { "IronIngot", { 3, 6, 10 } } },
	Rower = { { "SeaGrog", { 3, 6, 10 } }, { "MeatOnBone", { 10, 20, 35 } } },
	Carpenter = { { "Wood", { 30, 60, 100 } }, { "IronIngot", { 3, 6, 10 } } },
	Cook = { { "MeatOnBone", { 10, 20, 35 } }, { "RoastShank", { 4, 8, 14 } }, { "TigerPelt", { 6, 12, 20 } } },
}
R.Lines = {
	Gunner = { "Point me at a hull and I'll put a hole in it.", "Powder's in my blood, captain.", "I can hear a cannon cool down." },
	Rower = { "No wind? No problem. These arms don't tire.", "I rowed across the Calm Belt once. Twice, actually.", "Give me a bench and a beat." },
	Carpenter = { "A ship's only as good as her planks.", "I patch holes faster than they shoot 'em.", "Hammer, nails, and a bit of tar." },
	Cook = { "Nobody fights well on an empty belly.", "My stew has brought sailors back from the brink.", "You bring the fish, I'll bring the flavor." },
}

local function hash(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end
R.Hash = hash

-- the seed of tavern `tavernKey` (a stable string), slot `slot`, rotation `rot`
function R.Seed(tavernKey, slot, rot)
	return (hash(tavernKey) * 131 + rot * 17 + slot * 7919) % 2147483000
end

-- the candidate a seed describes
function R.Candidate(seed)
	local rng = Random.new(seed)
	local c = { seed = seed }
	c.name = R.First[rng:NextInteger(1, #R.First)] .. " " .. R.Last[rng:NextInteger(1, #R.Last)]
	c.race = R.Races[rng:NextInteger(1, #R.Races)]
	c.variant = Looks.RollVariant(c.race, rng)
	c.prof = R.ProfOrder[rng:NextInteger(1, #R.ProfOrder)]
	local roll, stars = rng:NextNumber() * 100, 1
	for i, w in ipairs(R.StarWeights) do
		roll -= w
		if roll <= 0 then
			stars = i
			break
		end
	end
	c.stars = stars
	if rng:NextNumber() < 0.5 then
		c.want = { kind = "coin", amount = R.Coins[stars] }
	else
		local asks = R.ItemAsks[c.prof]
		local a = asks[rng:NextInteger(1, #asks)]
		c.want = { kind = "item", id = a[1], qty = a[2][stars] }
	end
	local lines = R.Lines[c.prof]
	c.line = lines[rng:NextInteger(1, #lines)]
	return c
end

-- their look: random face/hair/colors from the seed, clothes from the job
function R.Look(c)
	local rng = Random.new(c.seed + 99)
	local look = Looks.Random(rng)
	local o = R.Professions[c.prof].outfit
	look.shirt = table.find(Looks.Shirts, o[1]) or look.shirt
	look.pants = table.find(Looks.Pants, o[2]) or look.pants
	look.shoes = table.find(Looks.Shoes, o[3]) or look.shoes
	return Looks.Sanitize(look)
end

-- what one recruit adds (for the card) and the crew's total (capped), keyed by stat
function R.Effect(c)
	local p = R.Professions[c.prof]
	return p.stat, p.per * (c.stars or 1)
end
function R.EffectText(c)
	local p = R.Professions[c.prof]
	local _, v = R.Effect(c)
	return string.format(p.fmt, v * 100)
end
function R.Bonus(list)
	local b = { reload = 0, speed = 0, repair = 0, heal = 0 }
	for _, c in ipairs(list or {}) do
		if R.Professions[c.prof] then
			local stat, v = R.Effect(c)
			b[stat] += v
		end
	end
	for k, cap in pairs(R.Caps) do
		b[k] = math.min(b[k], cap)
	end
	return b
end

return R
