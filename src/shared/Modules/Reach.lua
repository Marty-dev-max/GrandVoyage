-- Reach: distance from a point to a model's BODY (its bounding box), not to its root part.
-- Big monsters (a 40-stud sea serpent) have their HumanoidRootPart high up in the middle of the body; measuring to the
-- root made them unreachable (attacks refused, the client kept dropping and re-picking the target).
local Reach = {}

-- serpent bodies (v0.22.5): the server publishes the body pieces' centers as the BodyPts attribute
-- ("x,y,z;..."), so hitting the tail counts as hitting the serpent, on the server and the client alike
local bodyCache = setmetatable({}, { __mode = "k" })
local function bodyGap(pos, model)
	local s = model:GetAttribute("BodyPts")
	if not s or s == "" then
		return math.huge
	end
	local c = bodyCache[model]
	if not c or c.s ~= s then
		local pts = {}
		for x, y, z in string.gmatch(s, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
			table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
		end
		c = { s = s, pts = pts }
		bodyCache[model] = c
	end
	local r = model:GetAttribute("BodyRadius") or 5
	local best = math.huge
	for _, p in ipairs(c.pts) do
		best = math.min(best, (p - pos).Magnitude - r)
	end
	return math.max(0, best)
end

-- 0 when the point is inside/touching the box
function Reach.Gap(pos, model)
	if not model then
		return math.huge
	end
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then
		local p = model.PrimaryPart
		return p and (p.Position - pos).Magnitude or math.huge
	end
	local rel = cf:PointToObjectSpace(pos)
	local h = size / 2
	local dx = math.max(math.abs(rel.X) - h.X, 0)
	local dy = math.max(math.abs(rel.Y) - h.Y, 0)
	local dz = math.max(math.abs(rel.Z) - h.Z, 0)
	local gap = math.sqrt(dx * dx + dy * dy + dz * dz)
	if gap > 0 and model:GetAttribute("BodyPts") then
		gap = math.min(gap, bodyGap(pos, model))
	end
	return gap
end

-- the point of the model's body closest to pos (where to walk to / aim at)
function Reach.Closest(pos, model)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then
		return model.PrimaryPart and model.PrimaryPart.Position or pos
	end
	local rel = cf:PointToObjectSpace(pos)
	local h = size / 2
	return cf:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -h.X, h.X), math.clamp(rel.Y, -h.Y, h.Y), math.clamp(rel.Z, -h.Z, h.Z)))
end

return Reach
