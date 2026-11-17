-- Greenery (server): stylized plants on the island grass.
--   (Terrain grass was tried and dropped: its 4-stud voxels swallowed paths/houses and left ridges. Grass blades are
--    now client-side 3D patches around the player: Controllers/GrassField.lua.)
--   Stylized plants (Assets.Env: grass tufts, flowers, ferns, leafy plants, mushrooms) are scattered on that grass,
--      in small natural clumps, never on paths/plazas (those are not Terrain grass).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)

local G = {}

local GRASS = Enum.Material.Grass

local function insideProp(p)
	local m = p:FindFirstAncestorOfClass("Model")
	return m and (CollectionService:HasTag(m, "EnvProp")) or false
end

-- kind -> { weight, height range (studs) }
local PLANTS = {
	{ kind = "GrassTuft", weight = 46, h = { 2.0, 3.4 }, clump = { 2, 4 } },
	{ kind = "Flowers", weight = 22, h = { 1.1, 1.7 }, clump = { 1, 3 } },
	{ kind = "Fern", weight = 12, h = { 2.0, 3.0 }, clump = { 1, 2 } },
	{ kind = "LeafPlant", weight = 12, h = { 2.4, 4.0 }, clump = { 1, 2 } },
	{ kind = "Mushroom", weight = 6, h = { 0.9, 1.6 }, clump = { 1, 2 } },
	{ kind = "Bush", weight = 6, h = { 3.0, 4.5 }, clump = { 1, 1 } },
}

function G.Scatter(world, variantsOf, perIsland)
	local folder = Instance.new("Folder")
	folder.Name = "Greenery"
	folder.Parent = world
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world, workspace:FindFirstChild("Handmade") }
	local total = 0
	for _, p in ipairs(PLANTS) do
		total += p.weight
	end
	local placed = 0
	for _, isl in ipairs(Islands.List) do
		local rng = Random.new(#isl.id * 977 + math.floor(isl.x))
		local center = Vector3.new(isl.x, 0, isl.z or 0)
		local tries = 0
		local count = 0
		local want = isl.plants or perIsland or 110
		while count < want and tries < want * 4 do
			tries += 1
			local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * isl.radius * 0.95
			local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hit = workspace:Raycast(pos + Vector3.new(0, 400, 0), Vector3.new(0, -460, 0), params)
			if hit and hit.Material == GRASS and hit.Normal.Y > 0.8 and not insideProp(hit.Instance) then
				-- pick a plant kind by weight
				local roll, pick = rng:NextNumber(0, total), PLANTS[1]
				for _, pl in ipairs(PLANTS) do
					roll -= pl.weight
					if roll <= 0 then
						pick = pl
						break
					end
				end
				local list = variantsOf(pick.kind)
				if #list > 0 then
					for _ = 1, rng:NextInteger(pick.clump[1], pick.clump[2]) do
						local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
						local h2 = workspace:Raycast(hit.Position + off + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
						if h2 and h2.Material == GRASS and h2.Normal.Y > 0.8 and not insideProp(h2.Instance) then
							local src = list[rng:NextInteger(1, #list)]
							local c = src:Clone()
							c:PivotTo(CFrame.new(h2.Position - Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
							c:ScaleTo(c:GetScale() * rng:NextNumber(pick.h[1], pick.h[2]) / 10)
							for _, part in ipairs(c:GetDescendants()) do
								if part:IsA("BasePart") then
									part.CanCollide = false
									part.CanQuery = false
									part.CanTouch = false
									part.CastShadow = pick.kind == "Bush"
								end
							end
							c.Parent = folder
							placed += 1
						end
					end
					count += 1
				end
			end
		end
	end
	return placed
end

return G
