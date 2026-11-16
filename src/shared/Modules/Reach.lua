-- Reach: distance from a point to a model's BODY (its bounding box), not to its root part.
-- Big monsters (a 40-stud sea serpent) have their HumanoidRootPart high up in the middle of the body; measuring to the
-- root made them unreachable (attacks refused, the client kept dropping and re-picking the target).
local Reach = {}

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
	return math.sqrt(dx * dx + dy * dy + dz * dz)
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
