-- Greenery (server): living ground for the islands.
--   1. Every big Grass-material ground part gets a layer of Terrain grass on top: Roblox draws real grass blades on
--      Terrain grass (Terrain.Decoration) and sways them in the wind - the flat green sheet becomes a meadow.
--   2. Stylized plants (Assets.Env: grass tufts, flowers, ferns, leafy plants, mushrooms) are scattered on that grass,
--      in small natural clumps, never on paths/plazas (those are not Terrain grass).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)

local G = {}

local GRASS = Enum.Material.Grass
local LIFT = 0.3 -- terrain top sits slightly above the part top (no z-fighting)

local function insideProp(p)
	local m = p:FindFirstAncestorOfClass("Model")
	return m and (CollectionService:HasTag(m, "EnvProp")) or false
end

function G.GrassTerrain(world)
	local terrain = workspace.Terrain
	pcall(function()
		terrain.Decoration = true
	end)
	terrain:SetMaterialColor(GRASS, Color3.fromRGB(104, 172, 62))
	local fills = 0
	for _, p in ipairs(world:GetDescendants()) do
		if p:IsA("Part") and p.Material == GRASS and p.Transparency < 1 and p.CanCollide and not insideProp(p) then
			local cf, size = p.CFrame, p.Size
			if p.Shape == Enum.PartType.Cylinder and math.abs(cf.RightVector.Y) > 0.95 then
				local radius = math.min(size.Y, size.Z) / 2
				if radius >= 6 then
					local top = cf.Position.Y + size.X / 2
					terrain:FillCylinder(CFrame.new(cf.Position.X, top - 2 + LIFT, cf.Position.Z), 4, radius, GRASS)
					fills += 1
				end
			elseif p.Shape == Enum.PartType.Ball and size.X >= 12 then
				-- grassy hills
				terrain:FillBall(cf.Position, size.X / 2 + LIFT, GRASS)
				fills += 1
			elseif p.Shape == Enum.PartType.Block and cf.UpVector.Y > 0.95 and size.X >= 8 and size.Z >= 8 then
				local top = cf.Position.Y + size.Y / 2
				local flat = CFrame.new(cf.Position.X, top - 2 + LIFT, cf.Position.Z) * cf.Rotation
				terrain:FillBlock(flat, Vector3.new(size.X, 4, size.Z), GRASS)
				fills += 1
			end
		end
	end
	-- carve the grass back off paths, plazas, docks and floors that sit on the ground (terrain must not cover them):
	-- only where the terrain surface actually reaches above the part's top
	local onlyTerrain = RaycastParams.new()
	onlyTerrain.FilterType = Enum.RaycastFilterType.Include
	onlyTerrain.FilterDescendantsInstances = { terrain }
	local function covered(pos, top)
		local hit = workspace:Raycast(Vector3.new(pos.X, top + 6, pos.Z), Vector3.new(0, -7, 0), onlyTerrain)
		return hit ~= nil and hit.Position.Y > top - 0.05
	end
	for _, p in ipairs(world:GetDescendants()) do
		if p:IsA("Part") and p.Material ~= GRASS and p.Transparency < 1 and p.CanCollide and not insideProp(p) then
			local cf, size = p.CFrame, p.Size
			if p.Shape == Enum.PartType.Block and cf.UpVector.Y > 0.95 and size.X >= 3 and size.Z >= 3 then
				local top = cf.Position.Y + size.Y / 2
				if covered(cf.Position, top) then
					terrain:FillBlock(CFrame.new(cf.Position.X, top + 2, cf.Position.Z) * cf.Rotation, Vector3.new(size.X, 4, size.Z), Enum.Material.Air)
				end
			elseif p.Shape == Enum.PartType.Cylinder and math.abs(cf.RightVector.Y) > 0.95 and math.min(size.Y, size.Z) >= 4 then
				local top = cf.Position.Y + size.X / 2
				if covered(cf.Position, top) then
					terrain:FillCylinder(CFrame.new(cf.Position.X, top + 2, cf.Position.Z), 4, math.min(size.Y, size.Z) / 2, Enum.Material.Air)
				end
			end
		end
	end
	return fills
end

-- kind -> { weight, height range (studs) }
local PLANTS = {
	{ kind = "GrassTuft", weight = 44, h = { 1.4, 2.4 }, clump = { 3, 6 } },
	{ kind = "Flowers", weight = 22, h = { 1.1, 1.7 }, clump = { 1, 3 } },
	{ kind = "Fern", weight = 12, h = { 2.0, 3.0 }, clump = { 1, 2 } },
	{ kind = "LeafPlant", weight = 10, h = { 1.8, 2.8 }, clump = { 1, 2 } },
	{ kind = "Mushroom", weight = 6, h = { 0.9, 1.6 }, clump = { 1, 2 } },
	{ kind = "Bush", weight = 6, h = { 3.0, 4.5 }, clump = { 1, 1 } },
}

function G.Scatter(world, variantsOf, perIsland)
	local folder = Instance.new("Folder")
	folder.Name = "Greenery"
	folder.Parent = world
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, world }
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
		while count < (perIsland or 110) and tries < (perIsland or 110) * 4 do
			tries += 1
			local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * isl.radius * 0.95
			local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hit = workspace:Raycast(pos + Vector3.new(0, 400, 0), Vector3.new(0, -460, 0), params)
			if hit and hit.Instance == workspace.Terrain and hit.Material == GRASS and hit.Normal.Y > 0.8 then
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
						if h2 and h2.Instance == workspace.Terrain and h2.Material == GRASS then
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
