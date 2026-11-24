-- Recruits (v0.25.142, owner): crew are PEOPLE you recruit, not a number you buy. Sailors of every race hang around
-- the taverns (they stroll about); talk to one to size them up, then give them what they ask for (some want
-- Doubloons, some want an item) and they join your crew: they stand on your ship at their post and help.
-- Everything about a candidate comes from one seed, so the server and the client build the same person.
-- v0.25.148 (owner): 5 TIERS (Deckhand .. Legend), every look random (job shows on the tag, not the clothes), random
-- stats (Skill 80-125% on the job effect + a Trait = a small bonus of another job), new sailors every Rotate seconds
-- (the windows count down), and a recruit can be written into a Crew Contract item to sell / buy in stalls.
local Looks = require(script.Parent.Looks)

local R = {}

R.Rotate = 600 -- s: each tavern's sailors move on and new ones come in (windows show the countdown)
R.PerTavern = 4
R.WanderRadius = 2.5 -- studs around their spot (client side, Controllers/RecruitLife)
R.TalkRange = 22 -- server: how close you must be to the sailor's spot to recruit
R.TraitShare = 0.35 -- a trait is worth this much of a same-tier recruit of that job

-- what each job does on YOUR ship (per tier, x Skill, summed over the crew, capped)
R.Professions = {
	Gunner = { name = "Gunner", icon = "💣", desc = "Mans a cannon. Your cannons reload faster.", stat = "reload", per = 0.04, fmt = "-%d%% reload" },
	Rower = { name = "Rower", icon = "🚣", desc = "Pulls an oar. Your ship sails faster.", stat = "speed", per = 0.025, fmt = "+%d%% ship speed" },
	Carpenter = { name = "Carpenter", icon = "🔨", desc = "Patches the hull while you sail.", stat = "repair", per = 0.002, fmt = "+%.1f%% hull / s" },
	Cook = { name = "Cook", icon = "🍖", desc = "Feeds everyone aboard: heals HP over time.", stat = "heal", per = 0.006, fmt = "+%.1f%% HP / s" },
}
R.ProfOrder = { "Gunner", "Rower", "Carpenter", "Cook" }
R.Caps = { reload = 0.4, speed = 0.3, repair = 0.02, heal = 0.04 }

-- tiers (stars): name + color, how often they turn up, what they ask
R.Tiers = {
	{ name = "Deckhand", color = Color3.fromRGB(190, 190, 200) },
	{ name = "Able Sailor", color = Color3.fromRGB(110, 220, 110) },
	{ name = "Veteran", color = Color3.fromRGB(90, 170, 255) },
	{ name = "Elite", color = Color3.fromRGB(190, 110, 255) },
	{ name = "Legend", color = Color3.fromRGB(255, 200, 60) },
}
R.StarWeights = { 50, 28, 14, 6, 2 }

-- races seen in the first sea's taverns (weighted by repeats); never Cinderwing
R.Races = { "Islander", "Islander", "Islander", "Islander", "Skyborn", "Skyborn", "Tidekin", "Tidekin", "Beastkin", "Oni" }

-- original sailor names
R.First = { "Bram", "Tilda", "Osk", "Nell", "Corvin", "Mira", "Juno", "Fenn", "Rook", "Ysa", "Dag", "Pell", "Wren", "Huck",
	"Sable", "Toma", "Kip", "Odile", "Barro", "Lune", "Gage", "Ivy", "Moss", "Rhea", "Cobb", "Edda", "Finch", "Nico",
	"Tarn", "Opal", "Quill", "Basil", "Marlo", "Sunny", "Vesk", "Pip", "Hollis", "Greta" }
R.Last = { "Saltwhistle", "Ropeburn", "Gullfeather", "Barnacle", "Tidewell", "Brinehart", "Keelson", "Driftmoor",
	"Foghorn", "Stormwick", "Mastwood", "Pebbleton", "Shellby", "Copperhook", "Ashbourne", "Wavecrest", "Tarbuckle",
	"Sprattley", "Dunmore", "Lanternby" }

-- what they ask for: Doubloons, or an item that fits their job (qty by tier)
R.Coins = { 800, 2400, 6000, 14000, 30000 }
R.ItemAsks = {
	Gunner = { { "Gunpowder", { 4, 8, 14, 22, 32 } }, { "IronIngot", { 3, 6, 10, 16, 24 } } },
	Rower = { { "SeaGrog", { 3, 6, 10, 16, 24 } }, { "MeatOnBone", { 10, 20, 35, 55, 80 } } },
	Carpenter = { { "Wood", { 30, 60, 100, 160, 240 } }, { "IronIngot", { 3, 6, 10, 16, 24 } } },
	Cook = { { "MeatOnBone", { 10, 20, 35, 55, 80 } }, { "RoastShank", { 4, 8, 14, 22, 32 } }, { "TigerPelt", { 6, 12, 20, 32, 48 } } },
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

-- seconds until the sailors change (server and client share the epoch: os.time / GetServerTimeNow)
function R.NextIn(now)
	return R.Rotate - (now % R.Rotate)
end

function R.Tier(c)
	return R.Tiers[math.clamp(c and c.stars or 1, 1, #R.Tiers)]
end

-- the candidate a seed describes
function R.Candidate(seed)
	local rng = Random.new(seed)
	local c = { seed = seed }
	c.name = R.First[rng:NextInteger(1, #R.First)] .. " " .. R.Last[rng:NextInteger(1, #R.Last)]
	c.race = R.Races[rng:NextInteger(1, #R.Races)]
	c.variant = Looks.RollVariant(c.race, rng)
	c.prof = R.ProfOrder[rng:NextInteger(1, #R.ProfOrder)]
	local total = 0
	for _, w in ipairs(R.StarWeights) do
		total += w
	end
	local roll, stars = rng:NextNumber() * total, 1
	for i, w in ipairs(R.StarWeights) do
		roll -= w
		if roll <= 0 then
			stars = i
			break
		end
	end
	c.stars = stars
	c.skill = rng:NextInteger(80, 125)
	local others = {}
	for _, id in ipairs(R.ProfOrder) do
		if id ~= c.prof then
			table.insert(others, id)
		end
	end
	c.trait = others[rng:NextInteger(1, #others)]
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

-- their look: everything random from the seed (SERVER only: Looks.Random walks pairs, so clients could differ)
function R.Look(c)
	return Looks.Sanitize(Looks.Random(Random.new(c.seed + 99)))
end

-- what one recruit adds: { stat = value } (job effect x tier x Skill, plus the Trait)
function R.Effects(c)
	local out = {}
	local p = R.Professions[c.prof]
	local stars = c.stars or 1
	if p then
		out[p.stat] = p.per * stars * (c.skill or 100) / 100
	end
	local tp = c.trait and R.Professions[c.trait]
	if tp then
		out[tp.stat] = (out[tp.stat] or 0) + tp.per * stars * R.TraitShare
	end
	return out
end
local function fmt(prof, v)
	return string.format(R.Professions[prof].fmt, v * 100)
end
function R.EffectText(c)
	local p = R.Professions[c.prof]
	return p and fmt(c.prof, p.per * (c.stars or 1) * (c.skill or 100) / 100) or ""
end
function R.TraitText(c)
	local tp = c.trait and R.Professions[c.trait]
	return tp and (tp.name .. " trait: " .. fmt(c.trait, tp.per * (c.stars or 1) * R.TraitShare)) or "No trait"
end
function R.Bonus(list)
	local b = { reload = 0, speed = 0, repair = 0, heal = 0 }
	for _, c in ipairs(list or {}) do
		for stat, v in pairs(R.Effects(c)) do
			b[stat] += v
		end
	end
	for k, cap in pairs(R.Caps) do
		b[k] = math.min(b[k], cap)
	end
	return b
end

-- the saved record of a recruit (p.recruits entries, Crew Contract items)
function R.Record(c)
	return { seed = c.seed, name = c.name, race = c.race, variant = c.variant, prof = c.prof, stars = c.stars, skill = c.skill, trait = c.trait }
end
function R.ValidRecord(r)
	return type(r) == "table" and type(r.seed) == "number" and type(r.name) == "string" and R.Professions[r.prof] ~= nil
		and type(r.stars) == "number" and r.stars >= 1 and r.stars <= #R.Tiers
end

return R
