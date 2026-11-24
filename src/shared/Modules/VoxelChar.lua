-- VoxelChar (v0.24.0): builds a character look (Config/Looks) out of blocks.
--  * VoxelChar.Apply(char, look, heritage): on a real R15 character (server). The R15 body parts are hidden and blocks
--    are welded onto them (sizes from the parts, so animations still drive everything), plus a cube head with the
--    anime face images (Config/FaceImages: layered eyes tinted with Eyes Color 1/2, a mouth), voxel hair, clothes
--    (every piece painted with its Color 1 + Color 2) and the Heritage feature (wings / fin / ears + tail).
--  * VoxelChar.Preview(look, heritage): a standalone anchored model in the R15 rest pose (menu, creator, slot cards).
--    Its pivot is between the feet; move it with :PivotTo.
local Looks = require(script.Parent.Parent.Config.Looks)
local Coplanar = require(script.Parent.Coplanar)
local okFaces, FaceImages = pcall(require, script.Parent.Parent.Config.FaceImages)
if not okFaces then
	FaceImages = {}
end

local VC = {}

VC.HEAD = 1.75 -- cube head size (studs): big and chunky like the voxel reference
local G = 8 -- hair grid per head side

-- standard R15 sizes + rest centers (feet at y = 0), used by the preview
local REST = {
	LeftFoot = { Vector3.new(1, 0.3, 1), Vector3.new(-0.5, 0.15, 0) },
	RightFoot = { Vector3.new(1, 0.3, 1), Vector3.new(0.5, 0.15, 0) },
	LeftLowerLeg = { Vector3.new(1, 1.19, 1), Vector3.new(-0.5, 0.895, 0) },
	RightLowerLeg = { Vector3.new(1, 1.19, 1), Vector3.new(0.5, 0.895, 0) },
	LeftUpperLeg = { Vector3.new(1, 1.22, 1), Vector3.new(-0.5, 2.1, 0) },
	RightUpperLeg = { Vector3.new(1, 1.22, 1), Vector3.new(0.5, 2.1, 0) },
	LowerTorso = { Vector3.new(2, 0.4, 1), Vector3.new(0, 2.91, 0) },
	UpperTorso = { Vector3.new(2, 1.6, 1), Vector3.new(0, 3.91, 0) },
	LeftUpperArm = { Vector3.new(1, 1.17, 1), Vector3.new(-1.5, 4.125, 0) },
	RightUpperArm = { Vector3.new(1, 1.17, 1), Vector3.new(1.5, 4.125, 0) },
	LeftLowerArm = { Vector3.new(1, 1.05, 1), Vector3.new(-1.5, 3.015, 0) },
	RightLowerArm = { Vector3.new(1, 1.05, 1), Vector3.new(1.5, 3.015, 0) },
	LeftHand = { Vector3.new(1, 0.3, 1), Vector3.new(-1.5, 2.34, 0) },
	RightHand = { Vector3.new(1, 0.3, 1), Vector3.new(1.5, 2.34, 0) },
	Head = { Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.31, 0) },
}
VC.BODY_PARTS = {}
for name in pairs(REST) do
	table.insert(VC.BODY_PARTS, name)
end

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function dark(c, k)
	return c:Lerp(BLACK, k or 0.3)
end
local function light(c, k)
	return c:Lerp(WHITE, k or 0.3)
end

-- deterministic hash noise (highlight blocks, jagged hair)
local function hash(a, b, c)
	local h = (a * 73856093 + b * 19349663 + c * 83492791) % 1000
	return h / 1000
end

-- ===== hair styles: f(x, y, z) -> nil | 1 | 2 (Color 1 / Color 2). x 0..7 left->right (facing the camera), y 0..7
-- bottom->top, z 0..7 front->back. The head cube is 0..7 on every axis; hair lives outside it.
local function cap(x, y, z)
	return y == 8 and x >= -1 and x <= 8 and z >= -1 and z <= 8 and not ((x == -1 or x == 8) and (z == -1 or z == 8))
end
local function sides(x, y, z, down)
	return (x == -1 or x == 8) and z >= 0 and z <= 8 and y >= down and y <= 7
end
local function back(x, y, z, down)
	return z == 8 and x >= -1 and x <= 8 and y >= down and y <= 7
end
local function bangs(x, y, z, cols, row)
	return z == -1 and y == (row or 7) and x >= 0 and x <= 7 and (cols == nil or cols[x] == true)
end
local function set(...)
	local t = {}
	for _, v in ipairs({ ... }) do
		t[v] = true
	end
	return t
end
local function inHead(x, z)
	return x >= 0 and x <= 7 and z >= 0 and z <= 7
end
local function base(x, y, z, sideDown, backDown, bangCols)
	return cap(x, y, z) or sides(x, y, z, sideDown) or back(x, y, z, backDown) or (bangCols ~= false and bangs(x, y, z, bangCols))
end

local HAIR = {
	-- 1 Messy
	function(x, y, z)
		if base(x, y, z, 5, 4, set(0, 1, 2, 4, 5, 7)) or (y == 6 and z == -1 and (x == 0 or x == 7)) then
			return 1
		end
		if y == 9 and inHead(x, z) and hash(x, y, z) < 0.5 then
			return hash(x, y + 3, z) < 0.25 and 2 or 1
		end
	end,
	-- 2 Spiky
	function(x, y, z)
		if base(x, y, z, 6, 5, set(1, 3, 4, 6)) then
			return 1
		end
		if inHead(x, z) then
			if (x % 3 == 1) and (z % 3 == 1) and (y == 9 or y == 10) then
				return y == 10 and 2 or 1
			end
			if x >= 3 and x <= 4 and z >= 3 and z <= 4 and y >= 9 and y <= 11 then
				return y == 11 and 2 or 1
			end
		end
	end,
	-- 3 Short
	function(x, y, z)
		if base(x, y, z, 6, 5, set(0, 1, 2)) then
			return 1
		end
	end,
	-- 4 Long
	function(x, y, z)
		if cap(x, y, z) or sides(x, y, z, 1) or bangs(x, y, z) or (y == 6 and z == -1 and (x == 0 or x == 7)) then
			return 1
		end
		if z == 8 and x >= -1 and x <= 8 and y >= -2 and y <= 7 then
			return y <= 0 and 2 or 1
		end
	end,
	-- 5 Ponytail
	function(x, y, z)
		if base(x, y, z, 6, 5, set(0, 1, 6, 7)) then
			return 1
		end
		if (z == 9 or z == 10) and x >= 3 and x <= 4 and y >= 1 and y <= 7 then
			return y == 6 and 2 or 1
		end
	end,
	-- 6 Bowl
	function(x, y, z)
		if base(x, y, z, 4, 3, nil) or (y == 6 and z == -1 and x >= 0 and x <= 7) then
			return 1
		end
	end,
	-- 7 Crest
	function(x, y, z)
		if x >= 3 and x <= 4 and z >= -1 and z <= 8 and y >= 8 and y <= 10 then
			if y == 10 and (z <= 0 or z >= 8) then
				return nil
			end
			return y == 10 and 2 or 1
		end
		if sides(x, y, z, 6) and z >= 3 then
			return 1
		end
	end,
	-- 8 Bun
	function(x, y, z)
		if base(x, y, z, 5, 4, set(0, 1, 6, 7)) then
			return 1
		end
		if x >= 2 and x <= 5 and z >= 3 and z <= 6 and (y == 9 or y == 10) and not ((x == 2 or x == 5) and (z == 3 or z == 6)) then
			return y == 9 and 2 or 1
		end
	end,
	-- 9 Swept
	function(x, y, z)
		if base(x, y, z, 6, 5, set(0, 1, 2, 3, 4, 5)) or (y == 6 and z == -1 and x >= 0 and x <= 2) then
			return 1
		end
		if y == 9 and x >= -1 and x <= 3 and z >= -1 and z <= 6 then
			return x <= 0 and 2 or 1
		end
	end,
	-- 10 Twin Tails
	function(x, y, z)
		if base(x, y, z, 5, 4, nil) then
			return 1
		end
		if (x == -2 or x == 9) and z >= 3 and z <= 4 and y >= 0 and y <= 7 then
			return y <= 1 and 2 or 1
		end
	end,
	-- 11 Fluffy
	function(x, y, z)
		if y < 3 then
			return nil
		end
		local cx, cy, cz = x - 3.5, y - 4.5, z - 3.8
		if cx * cx / 30 + cy * cy / 34 + cz * cz / 30 > 1 or (z < 0 and y < 7) then
			return nil
		end
		return hash(x, y, z) < 0.18 and 2 or 1
	end,
	-- 12 Undercut: a long top swept forward, shaved sides
	function(x, y, z)
		if y >= 8 and y <= 9 and x >= 0 and x <= 7 and z >= -1 and z <= 6 then
			return (y == 9 and z <= 0) and 2 or 1
		end
		if sides(x, y, z, 7) or back(x, y, z, 6) then
			return 2
		end
	end,
	-- 13 Side Part
	function(x, y, z)
		if base(x, y, z, 5, 4, set(0, 1, 2, 3, 4)) or (y == 6 and z == -1 and x <= 2 and x >= 0) then
			return 1
		end
		if y == 9 and z >= -1 and z <= 5 and x >= 0 and x <= 4 then
			return 1
		end
	end,
	-- 14 Long Straight
	function(x, y, z)
		if cap(x, y, z) or bangs(x, y, z) then
			return 1
		end
		if (x == -1 or x == 8) and z >= -1 and z <= 8 and y >= -1 and y <= 7 then
			return y <= 0 and 2 or 1
		end
		if z == 8 and x >= -1 and x <= 8 and y >= -4 and y <= 7 then
			return y <= -2 and 2 or 1
		end
	end,
	-- 15 Wolf Cut: shaggy jagged layers
	function(x, y, z)
		if cap(x, y, z) then
			return 1
		end
		if (sides(x, y, z, 2) or back(x, y, z, 1)) and (y >= 5 or hash(x, y, z) < 0.62) then
			return y <= 3 and 2 or 1
		end
		if z == -1 and x >= 0 and x <= 7 and (y == 7 or (y == 6 and x % 2 == 0)) then
			return 1
		end
	end,
	-- 16 Pompadour
	function(x, y, z)
		if base(x, y, z, 6, 5, false) then
			return 1
		end
		if x >= 0 and x <= 7 and z >= -2 and z <= 2 and (y == 9 or y == 10) and not (y == 10 and (x == 0 or x == 7)) then
			return (y == 10 and z <= -1) and 2 or 1
		end
		if z == -2 and y == 8 and x >= 1 and x <= 6 then
			return 1
		end
	end,
	-- 17 Buzz
	function(x, y, z)
		if y == 8 and inHead(x, z) then
			return 1
		end
		if (x == -1 or x == 8) and z >= 1 and z <= 7 and y == 7 then
			return 1
		end
		if z == 8 and x >= 0 and x <= 7 and y >= 6 and y <= 7 then
			return 1
		end
	end,
	-- 18 Hero Spikes: big anime-style spikes
	function(x, y, z)
		if base(x, y, z, 5, 4, false) then
			return 1
		end
		if z == -1 and ((x == 1 and y >= 6) or (x == 4 and y >= 5) or (x == 6 and y >= 6)) and y <= 8 then
			return 1
		end
		local roots = { { 1, 1, 3 }, { 5, 1, 4 }, { 3, 4, 5 }, { 0, 5, 3 }, { 6, 5, 3 }, { 3, 7, 3 } }
		for _, r in ipairs(roots) do
			local h = r[3]
			local dy = y - 8
			if dy >= 1 and dy <= h then
				local w = dy <= h - 2 and 1 or 0
				if math.abs(x - r[1]) <= w and math.abs(z - r[2]) <= w then
					return dy >= h - 1 and 2 or 1
				end
			end
		end
	end,
	-- 19 Eye Cover: a long fringe over one eye
	function(x, y, z)
		if base(x, y, z, 4, 3, false) then
			return 1
		end
		if z == -1 and x >= 0 and x <= 3 and y >= 3 and y <= 7 then
			return y <= 3 and 2 or 1
		end
		if z == -1 and y == 7 and x >= 4 and x <= 7 then
			return 1
		end
	end,
	-- 20 Braids
	function(x, y, z)
		if base(x, y, z, 5, 4, set(0, 1, 6, 7)) then
			return 1
		end
		if (x == -2 or x == 9) and z >= 1 and z <= 2 and y >= -4 and y <= 6 then
			return (y % 3 == 0) and 2 or 1
		end
	end,
	-- 21 Topknot
	function(x, y, z)
		if cap(x, y, z) or sides(x, y, z, 6) or back(x, y, z, 5) then
			return 1
		end
		if x >= 3 and x <= 4 and z >= 4 and z <= 5 and y >= 9 and y <= 11 then
			return y == 9 and 2 or 1
		end
	end,
	-- 22 Afro
	function(x, y, z)
		if y < 2 then
			return nil
		end
		local cx, cy, cz = x - 3.5, y - 5.5, z - 4
		if cx * cx / 42 + cy * cy / 40 + cz * cz / 42 > 1 or (z < 0 and y < 7) then
			return nil
		end
		return hash(x, y, z) < 0.12 and 2 or 1
	end,
	-- 23 Curtain Bangs
	function(x, y, z)
		if base(x, y, z, 4, 3, set(0, 1, 2, 5, 6, 7)) or (y == 6 and z == -1 and (x <= 1 or x >= 6) and x >= 0 and x <= 7) then
			return 1
		end
		if y == 5 and z == -1 and (x == 0 or x == 7) then
			return 2
		end
	end,
	-- 24 Princess Cut: blunt bangs, cheek-length side locks, long back
	function(x, y, z)
		if cap(x, y, z) or bangs(x, y, z) or (y == 6 and z == -1 and x >= 0 and x <= 7) then
			return 1
		end
		if (x == -1 or x == 8) and z >= -1 and z <= 1 and y >= 2 and y <= 7 then
			return y == 2 and 2 or 1
		end
		if sides(x, y, z, 1) or (z == 8 and x >= -1 and x <= 8 and y >= -3 and y <= 7) then
			return y <= -2 and 2 or 1
		end
	end,
	-- 25 Mullet
	function(x, y, z)
		if base(x, y, z, 6, 4, set(0, 1, 2, 5, 6, 7)) then
			return 1
		end
		if z == 8 and x >= 0 and x <= 7 and y >= -3 and y <= 3 then
			return y <= -2 and 2 or 1
		end
	end,
	-- 26 Locs
	function(x, y, z)
		if cap(x, y, z) then
			return 1
		end
		local strand = ((x == -1 or x == 8) and z >= 0 and z <= 8 and z % 2 == 0) or (z == 8 and x >= -1 and x <= 8 and x % 2 == 1)
		if strand and y >= -3 + (x + z) % 3 and y <= 7 then
			return y <= -1 + (x + z) % 3 and 2 or 1
		end
		if z == -1 and y == 7 and x % 2 == 0 and x >= 0 and x <= 7 then
			return 1
		end
	end,
	-- 27 Shaggy Long
	function(x, y, z)
		if cap(x, y, z) then
			return 1
		end
		if (sides(x, y, z, -1) or (z == 8 and x >= -1 and x <= 8 and y >= -3 and y <= 7)) and (y >= 4 or hash(x, y, z) < 0.7) then
			return y <= 0 and 2 or 1
		end
		if z == -1 and x >= 0 and x <= 7 and (y == 7 or (y == 6 and hash(x, y, z) < 0.5)) then
			return 1
		end
	end,
	-- 28 Bald
	function()
		return nil
	end,
}
local NO_LUMP = { [7] = true, [12] = true, [17] = true, [28] = true }

-- ===== block helpers =====
local function newBlock(size, color, name)
	local p = Instance.new("Part")
	p.Name = name or "Vox"
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	return p
end

-- build every block of a look. place(partName) -> CFrame, Size of that body part; emit(block, partName, cframe)
VC.Rest = REST -- limb rest poses (tools/export_char.luau dresses previews with Accessory.Build)
local LITE = false -- set by VC.Preview(..., { lite = true }): fewer hair blocks (NPC crews)
local function buildBlocks(look, heritage, variant, mode, place, emit)
	local mark = type(look) == "table" and look.mark or nil
	look = Looks.Sanitize(look)
	look.mark = mark -- monsters only (MonsterLooks); Sanitize drops unknown keys
	local her = Looks.HeritageById[heritage or ""]
	if her and her.lock then
		-- a locked heritage look (Cinderwing): these colors cannot be changed
		for k, v in pairs(her.lock) do
			look[k] = v
		end
	end
	local var = Looks.Variant(heritage, variant) or {}
	local C = function(k)
		return Looks.Color(look, k)
	end
	local skin = C("skin")
	local hair1, hair2 = C("hair1"), C("hair2")
	local s1, s2 = C("shirt1"), C("shirt2")
	local p1, p2 = C("pants1"), C("pants2")
	local f1, f2 = C("shoes1"), C("shoes2")

	local function block(partName, size, rel, color, name)
		local cf, psize = place(partName)
		if not cf then
			return nil
		end
		local b = newBlock(size, color, name)
		emit(b, partName, cf * rel, psize)
		return b
	end
	local function sizeOf(partName)
		local _, s = place(partName)
		return s
	end
	-- a block covering a whole part (slightly inflated so the R15 mesh never peeks through)
	local function cover(partName, color, grow, name)
		local ps = sizeOf(partName)
		if not ps then
			return
		end
		grow = grow or 0.04
		return block(partName, Vector3.new(math.max(ps.X, 1) + grow, ps.Y + 0.02, math.max(ps.Z, 1) + grow), CFrame.new(), color, name or partName)
	end
	-- a band around a part at height y (part space), thickness h
	local function band(partName, y, h, color, grow, name)
		local ps = sizeOf(partName)
		if not ps then
			return
		end
		grow = grow or 0.1
		return block(partName, Vector3.new(math.max(ps.X, 1) + grow, h, math.max(ps.Z, 1) + grow), CFrame.new(0, y, 0), color, name or "Band")
	end

	local ut, lt = sizeOf("UpperTorso"), sizeOf("LowerTorso")
	local front = ut and -(ut.Z / 2) - 0.03 or -0.53 -- the chest's front face (-Z)
	local backZ = ut and (ut.Z / 2) + 0.03 or 0.53

	-- ===== shirt: region colors + extras =====
	local SH = look.shirt
	local torsoC, uArmC, lArmC = s1, s1, skin
	local lowerTorsoShirt = nil
	if SH == 2 then
		uArmC = skin
	elseif SH == 3 or SH == 6 or SH == 7 or SH == 9 or SH == 10 then
		lArmC = s1
	elseif SH == 5 or SH == 15 then
		torsoC, uArmC = skin, skin
	end
	if SH == 10 then
		torsoC = s2 -- open jacket: the shirt under it
	end
	if SH == 6 or SH == 12 then
		lowerTorsoShirt = s1
	end
	cover("UpperTorso", torsoC)
	for _, side in ipairs({ "Left", "Right" }) do
		cover(side .. "UpperArm", uArmC)
		cover(side .. "LowerArm", lArmC)
		cover(side .. "Hand", skin)
	end
	if ut then
		local W, Hh, D = ut.X, ut.Y, ut.Z
		if SH == 1 or SH == 13 then
			block("UpperTorso", Vector3.new(0.5, 0.2, 0.06), CFrame.new(0, Hh / 2 - 0.1, front), skin, "Neck")
			for _, side in ipairs({ "Left", "Right" }) do
				band(side .. "UpperArm", -0.45, 0.16, s2, 0.1, "SleeveHem")
			end
			if SH == 13 then
				block("UpperTorso", Vector3.new(W * 0.8, 0.32, D + 0.24), CFrame.new(0, Hh / 2 - 0.12, 0), s2, "Scarf")
				block("UpperTorso", Vector3.new(0.34, 0.9, 0.16), CFrame.new(0.45, Hh / 2 - 0.6, front - 0.08), s2, "ScarfTail")
			end
		elseif SH == 2 then
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.3, 0.14, D + 0.08), CFrame.new(sx * 0.55, Hh / 2 - 0.07, 0), s2, "Strap")
			end
			block("UpperTorso", Vector3.new(W + 0.06, 0.12, D + 0.06), CFrame.new(0, -Hh / 2 + 0.06, 0), s2, "Hem")
		elseif SH == 3 then
			for _, side in ipairs({ "Left", "Right" }) do
				local la = sizeOf(side .. "LowerArm")
				if la then
					band(side .. "LowerArm", -la.Y / 2 + 0.09, 0.18, s2, 0.1, "Cuff")
				end
			end
			block("UpperTorso", Vector3.new(0.6, 0.16, 0.06), CFrame.new(0, Hh / 2 - 0.08, front), s2, "Collar")
		elseif SH == 4 then
			for i = 0, 2 do
				block("UpperTorso", Vector3.new(W + 0.06, 0.15, D + 0.06), CFrame.new(0, -0.45 + i * 0.42, 0), s2, "Stripe")
			end
			block("UpperTorso", Vector3.new(1.1, 0.55, 0.06), CFrame.new(0, Hh / 2 - 0.28, backZ), s2, "Collar")
			for _, side in ipairs({ "Left", "Right" }) do
				band(side .. "UpperArm", 0.05, 0.14, s2, 0.1, "Stripe")
			end
		elseif SH == 5 then
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.62, Hh + 0.06, D + 0.08), CFrame.new(sx * (W / 2 - 0.3), 0, 0), s1, "Vest")
				block("UpperTorso", Vector3.new(0.1, Hh + 0.04, 0.1), CFrame.new(sx * (W / 2 - 0.62), 0, front - 0.02), s2, "Trim")
			end
			block("UpperTorso", Vector3.new(W - 1.1, Hh, 0.06), CFrame.new(0, 0, backZ), s1, "VestBack")
		elseif SH == 6 then
			for i = 0, 2 do
				block("UpperTorso", Vector3.new(0.17, 0.17, 0.08), CFrame.new(0.2, 0.42 - i * 0.42, front), s2, "Button")
			end
			block("UpperTorso", Vector3.new(0.12, Hh, 0.06), CFrame.new(0, 0, front), dark(s1, 0.35), "Seam")
			for _, side in ipairs({ "Left", "Right" }) do
				local la = sizeOf(side .. "LowerArm")
				if la then
					band(side .. "LowerArm", -la.Y / 2 + 0.12, 0.24, s2, 0.12, "Cuff")
				end
			end
		elseif SH == 7 then
			block("UpperTorso", Vector3.new(1.5, 0.65, 0.4), CFrame.new(0, Hh / 2 - 0.12, backZ + 0.16), dark(s1, 0.12), "Hood")
			block("UpperTorso", Vector3.new(1.2, 0.42, 0.06), CFrame.new(0, -0.42, front), dark(s1, 0.15), "Pocket")
			for _, sx in ipairs({ -0.25, 0.25 }) do
				block("UpperTorso", Vector3.new(0.08, 0.5, 0.06), CFrame.new(sx, Hh / 2 - 0.4, front - 0.01), s2, "String")
			end
		elseif SH == 8 then
			block("UpperTorso", Vector3.new(0.32, Hh * 1.18, D + 0.08), CFrame.new(0.1, 0, 0) * CFrame.Angles(0, 0, math.rad(32)), s2, "Sash")
		elseif SH == 9 then
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.18, Hh * 0.75, 0.06), CFrame.new(sx * 0.22, Hh * 0.12, front) * CFrame.Angles(0, 0, sx * math.rad(28)), s2, "Lapel")
			end
			block("UpperTorso", Vector3.new(0.42, 0.4, 0.05), CFrame.new(0, Hh / 2 - 0.25, front - 0.005), skin, "VNeck")
		elseif SH == 10 then
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.55, Hh + 0.06, D + 0.1), CFrame.new(sx * (W / 2 - 0.27), 0, 0), s1, "Jacket")
			end
			block("UpperTorso", Vector3.new(W - 1.0, Hh, 0.08), CFrame.new(0, 0, backZ), s1, "JacketBack")
			block("UpperTorso", Vector3.new(W + 0.14, 0.2, D + 0.14), CFrame.new(0, Hh / 2 - 0.09, 0), dark(s1, 0.2), "JacketCollar")
		elseif SH == 11 then
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.42, 0.2, 0.1), CFrame.new(sx * 0.3, Hh / 2 - 0.1, front - 0.02), s2, "Collar")
			end
			block("UpperTorso", Vector3.new(0.16, 0.55, 0.06), CFrame.new(0, Hh / 2 - 0.36, front), s2, "Placket")
		elseif SH == 12 then
			block("UpperTorso", Vector3.new(0.4, 0.3, 0.06), CFrame.new(0, Hh / 2 - 0.15, front), skin, "Neck")
		elseif SH == 14 then
			block("UpperTorso", Vector3.new(W * 0.8, Hh * 0.55, 0.14), CFrame.new(0, 0.2, front - 0.06), s2, "Plate")
			block("UpperTorso", Vector3.new(W * 0.8, Hh * 0.55, 0.14), CFrame.new(0, 0.2, backZ + 0.06), s2, "BackPlate")
			for _, side in ipairs({ "Left", "Right" }) do
				local ua = sizeOf(side .. "UpperArm")
				if ua then
					block(side .. "UpperArm", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, ua.Y / 2 - 0.18, 0), s2, "Pauldron")
				end
			end
		elseif SH == 15 then
			for i = 0, 2 do
				block("UpperTorso", Vector3.new(W * 1.1, 0.2, D + 0.08), CFrame.new(0, -0.5 + i * 0.5, 0) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 18 or -18)), s1, "Wrap")
			end
			for _, side in ipairs({ "Left", "Right" }) do
				band(side .. "LowerArm", 0.15, 0.16, s2, 0.08, "ArmWrap")
				band(side .. "LowerArm", -0.2, 0.16, s2, 0.08, "ArmWrap")
			end
		elseif SH == 16 then
			block("UpperTorso", Vector3.new(1.3, Hh * 0.75, 0.08), CFrame.new(0, -Hh * 0.12, front - 0.02), s2, "Apron")
			for _, sx in ipairs({ -0.42, 0.42 }) do
				block("UpperTorso", Vector3.new(0.12, 0.5, 0.06), CFrame.new(sx, Hh / 2 - 0.2, front - 0.02), s2, "ApronStrap")
			end
		end
	end

	-- ===== pants =====
	local PA = look.pants
	local skirt = PA == 6
	local shorts = PA == 2
	local legGrow = (PA == 4 and 0.18) or (PA == 9 and 0.24) or 0.04
	cover("LowerTorso", lowerTorsoShirt or p1)
	if lt then
		local W = lt.X
		if PA == 1 or PA == 3 or PA == 4 or PA == 7 or PA == 8 or PA == 10 or PA == 12 then
			block("LowerTorso", Vector3.new(W + 0.08, 0.16, lt.Z + 0.08), CFrame.new(0, lt.Y / 2 - 0.08, 0), p2, "Belt")
			block("LowerTorso", Vector3.new(0.24, 0.18, 0.1), CFrame.new(0, lt.Y / 2 - 0.08, -lt.Z / 2 - 0.05), Color3.fromRGB(232, 196, 90), "Buckle")
		elseif PA == 5 then
			block("LowerTorso", Vector3.new(W + 0.12, 0.32, lt.Z + 0.12), CFrame.new(), p2, "Sash")
			block("LowerTorso", Vector3.new(0.3, 0.7, 0.1), CFrame.new(0.6, -0.4, -lt.Z / 2 - 0.07), p2, "SashTail")
		elseif PA == 9 then
			block("LowerTorso", Vector3.new(W + 0.12, 0.26, lt.Z + 0.12), CFrame.new(), p2, "Waist")
		end
		if skirt then
			block("LowerTorso", Vector3.new(2.2, 1.0, 1.2), CFrame.new(0, -0.55, 0), p1, "Skirt")
			block("LowerTorso", Vector3.new(2.24, 0.14, 1.24), CFrame.new(0, -0.99, 0), p2, "SkirtHem")
		end
		if SH == 6 then
			block("LowerTorso", Vector3.new(2.1, 1.2, 0.2), CFrame.new(0, -0.6, lt.Z / 2 + 0.1), s1, "CoatTail")
			for _, sx in ipairs({ -1, 1 }) do
				block("LowerTorso", Vector3.new(0.2, 1.1, 1.0), CFrame.new(sx * 1.05, -0.55, 0.05), s1, "CoatSide")
			end
		elseif SH == 12 then
			block("LowerTorso", Vector3.new(2.16, 0.7, 1.14), CFrame.new(0, -0.3, 0), s1, "Tunic")
			block("LowerTorso", Vector3.new(2.2, 0.16, 1.18), CFrame.new(0, lt.Y / 2 - 0.06, 0), s2, "TunicBelt")
		elseif SH == 16 then
			block("LowerTorso", Vector3.new(1.3, 1.0, 0.08), CFrame.new(0, -0.35, -lt.Z / 2 - 0.05), s2, "ApronSkirt")
		end
		if PA == 11 and ut then
			-- overalls: bib + straps over the shirt
			block("UpperTorso", Vector3.new(1.3, ut.Y * 0.55, 0.08), CFrame.new(0, -ut.Y * 0.22, front - 0.03), p1, "Bib")
			for _, sx in ipairs({ -1, 1 }) do
				block("UpperTorso", Vector3.new(0.2, ut.Y + 0.04, ut.Z + 0.12), CFrame.new(sx * 0.5, 0, 0), p1, "OverallStrap")
				block("UpperTorso", Vector3.new(0.16, 0.16, 0.08), CFrame.new(sx * 0.5, ut.Y * 0.05, front - (SH == 14 and 0.17 or 0.09)), p2, "OverallButton") -- in front of an armor plate, not in its face (flicker)
			end
		end
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		cover(side .. "UpperLeg", skirt and skin or p1, legGrow)
		local lowerC = (shorts or skirt) and skin or p1
		cover(side .. "LowerLeg", lowerC, legGrow)
		local ul, ll = sizeOf(side .. "UpperLeg"), sizeOf(side .. "LowerLeg")
		if shorts and ul then
			band(side .. "UpperLeg", -ul.Y / 2 + 0.08, 0.16, p2, 0.1, "Hem")
		elseif PA == 3 and ll then
			band(side .. "LowerLeg", -ll.Y / 2 + 0.36, 0.26, p2, 0.12, "Cuff")
		elseif PA == 7 and ul then
			block(side .. "UpperLeg", Vector3.new(0.12, 0.5, 0.6), CFrame.new(sx * 0.53, -0.1, 0), p2, "Pocket")
		elseif PA == 8 and ul and ll then
			block(side .. "UpperLeg", Vector3.new(0.1, ul.Y, 0.3), CFrame.new(sx * 0.53, 0, 0), p2, "Stripe")
			block(side .. "LowerLeg", Vector3.new(0.1, ll.Y - 0.02, 0.3), CFrame.new(sx * 0.53, 0, 0), p2, "Stripe")
		elseif PA == 9 and ll then
			block(side .. "LowerLeg", Vector3.new(1.45, ll.Y * 0.6, 1.45), CFrame.new(0, -ll.Y * 0.2, 0), p1, "Flare")
		elseif PA == 10 and ll then
			block(side .. "LowerLeg", Vector3.new(1.14, 0.4, 0.2), CFrame.new(0, ll.Y / 2 - 0.25, -0.55), p2, "KneePad")
		elseif PA == 12 and ll then
			block(side .. "LowerLeg", Vector3.new(1.06, ll.Y * 0.48, 1.06), CFrame.new(0, -ll.Y * 0.26, 0), skin, "Shin")
			band(side .. "LowerLeg", 0, 0.14, p2, 0.13, "Cuff")
		end

		-- ===== shoes =====
		local SO = look.shoes
		local footC = (SO == 1 or SO == 4 or SO == 6 or SO == 8) and skin or f1
		if SO == 10 then
			footC = f2 -- socks under the sandal
		end
		cover(side .. "Foot", footC, 0.06)
		local ft = sizeOf(side .. "Foot")
		if ft then
			if SO == 1 or SO == 10 then
				block(side .. "Foot", Vector3.new(1.1, 0.14, 0.3), CFrame.new(0, 0.1, -0.15), f1, "Strap")
				block(side .. "Foot", Vector3.new(1.12, 0.08, 1.12), CFrame.new(0, -ft.Y / 2 + 0.04, 0), SO == 10 and f1 or f2, "Sole")
			elseif SO == 3 then
				block(side .. "Foot", Vector3.new(1.1, 0.1, 1.1), CFrame.new(0, -ft.Y / 2 + 0.05, 0), f2, "Sole")
				block(side .. "Foot", Vector3.new(0.5, 0.06, 0.4), CFrame.new(0, ft.Y / 2 + 0.01, -0.2), light(f2, 0.3), "Laces")
			elseif SO == 2 or SO == 5 or SO == 9 then
				block(side .. "Foot", Vector3.new(1.1, 0.1, 1.1), CFrame.new(0, -ft.Y / 2 + 0.05, 0), dark(f2, 0.2), "Sole")
			elseif SO == 7 then
				block(side .. "Foot", Vector3.new(1.08, 0.12, 0.7), CFrame.new(0, 0.06, -0.15), f2, "SlipperTop")
			elseif SO == 8 then
				block(side .. "Foot", Vector3.new(1.0, 0.3, 1.1), CFrame.new(0, -ft.Y / 2 - 0.12, 0), f1, "Clog")
				block(side .. "Foot", Vector3.new(0.2, 0.14, 0.5), CFrame.new(0, 0.1, -0.2), f2, "Strap")
			end
		end
		if ll then
			if SO == 2 or SO == 9 then
				block(side .. "LowerLeg", Vector3.new(1.1, ll.Y * 0.45 + 0.04, 1.1), CFrame.new(0, -ll.Y * 0.275 - 0.02, 0), f1, "Boot")
				band(side .. "LowerLeg", -ll.Y * 0.05, 0.14, f2, 0.14, "BootCuff")
				if SO == 9 then
					block(side .. "LowerLeg", Vector3.new(0.3, 0.22, 0.1), CFrame.new(0, -ll.Y * 0.28, -0.58), f2, "Buckle")
				end
			elseif SO == 5 then
				block(side .. "LowerLeg", Vector3.new(1.1, ll.Y + 0.06, 1.1), CFrame.new(), f1, "TallBoot")
				band(side .. "LowerLeg", ll.Y / 2 - 0.09, 0.18, f2, 0.16, "BootCuff")
			elseif SO == 6 then
				for i = 0, 2 do
					band(side .. "LowerLeg", -ll.Y / 2 + 0.1 + i * 0.22, 0.12, i == 2 and f2 or f1, 0.08, "Wrap")
				end
			elseif SO == 10 then
				block(side .. "LowerLeg", Vector3.new(1.08, ll.Y * 0.35 + 0.04, 1.08), CFrame.new(0, -ll.Y * 0.325 - 0.02, 0), f2, "Sock")
			end
		end
	end

	-- ===== head: cube + face images + hair =====
	local hcf, hsize = place("Head")
	if not hcf then
		return
	end
	local H = VC.HEAD
	local headCF = hcf * CFrame.new(0, (H - hsize.Y) / 2 - 0.05, 0)
	local u = H / G
	local cube = newBlock(Vector3.new(H, H, H), skin, "VoxelHead")
	emit(cube, "Head", headCF, hsize)
	-- face: each image layer is a Decal on its own paper-thin invisible plate in front of the cube (v0.24.6: decals
	-- also render inside ViewportFrames, SurfaceGuis do not: the Bag / Stats statue and slot cards showed no face).
	-- (u, v) = top-left of the layer on the face in 0..1, (w, h) its size; layers stack outward by z.
	local function faceLayer(key, u, v, w, h, tint, z)
		local id = FaceImages[key]
		if not id then
			return
		end
		local plate = newBlock(Vector3.new(w * H, h * H, 0.02), WHITE, "FaceLayer")
		plate.Transparency = 1
		plate.CastShadow = false
		local d = Instance.new("Decal")
		d.Name = "FaceDecal"
		d.Face = Enum.NormalId.Front
		d.Texture = id
		d.Color3 = tint or WHITE
		d.ZIndex = z
		d:SetAttribute("Img", key) -- (offline preview renders read this)
		d.Parent = plate
		-- the head's front is -Z and screen-left is +X
		local lx = H / 2 - (u + w / 2) * H
		local ly = H / 2 - (v + h / 2) * H
		emit(plate, "Head", headCF * CFrame.new(lx, ly, -H / 2 - 0.012 - z * 0.004), hsize)
	end
	local e = "eye" .. look.eyes
	faceLayer(e .. "_white", 0.04, 0.24, 0.92, 0.46, nil, 1)
	faceLayer(e .. "_iris", 0.04, 0.24, 0.92, 0.46, C("eyes1"), 2)
	faceLayer(e .. "_iris2", 0.04, 0.24, 0.92, 0.46, C("eyes2"), 3)
	faceLayer(e .. "_over", 0.04, 0.24, 0.92, 0.46, nil, 4)
	faceLayer("mouth" .. look.mouth, 0.27, 0.64, 0.46, 0.23, nil, 5)
	if type(look.mark) == "string" then
		faceLayer("mark" .. look.mark, 0, 0, 1, 1, nil, 6) -- v0.25.91: monster face marks (scar, stubble, clown paint ...)
	end

	local style = HAIR[look.hair] or HAIR[1]
	local lumpy = not NO_LUMP[look.hair] and not LITE
	local function cellCF(ix, iy, iz, len)
		-- ix 0..7 is left->right as seen from the front: the front is -Z, so screen-left is +X
		local cx = (ix + len / 2) * u - H / 2
		return headCF * CFrame.new(-cx, -H / 2 + (iy + 0.5) * u, -H / 2 + (iz + 0.5) * u)
	end
	local function emitRuns(fn, colorOf, name)
		for iy = -5, 14 do
			for iz = -3, 11 do
				local ix = -3
				while ix <= 10 do
					local v = fn(ix, iy, iz)
					if v then
						local start = ix
						while ix <= 10 and fn(ix, iy, iz) == v do
							ix += 1
						end
						local len = ix - start
						local b = newBlock(Vector3.new(len * u + 0.01, u + 0.01, u + 0.01), colorOf(v, start, iy, iz), name)
						emit(b, "Head", cellCF(start, iy, iz, len), hsize)
					else
						ix += 1
					end
				end
			end
		end
	end
	emitRuns(function(x, y, z)
		if x >= 0 and x <= 7 and y >= 0 and y <= 7 and z >= 0 and z <= 7 then
			return nil -- never inside the head cube
		end
		local v = style(x, y, z)
		-- a second, lumpy layer on top of every cap so hair reads thick and chunky
		if lumpy and not v and y == 9 and inHead(x, z) and style(x, 8, z) and hash(x, 9, z) < 0.62 then
			v = 1
		end
		if v == 1 and not LITE and hash(x, y, z) > 0.9 then
			v = 3 -- a few lighter highlight blocks
		end
		return v
	end, function(v)
		return v == 2 and hair2 or (v == 3 and light(hair1, 0.22) or hair1)
	end, "Hair")

	-- ===== Heritage feature (variant colors / shapes from Config/Looks) =====
	-- wings: a solid stepped silhouette of blocks on the back (rows from the spine outward), tips in color 2
	local SMALL_WING = { "..XX", ".XXX", "XXX.", "XX.." }
	local GREAT_WING = { "....XXX", "...XXXX", "..XXXXX", ".XXXXX.", "XXXXX..", "XXX....", ".XX...." }
	-- Skyborn wing shapes by variant (rows top -> bottom, columns spine -> tip)
	local WING_SHAPES = {
		sparrow = SMALL_WING,
		swallow = { "......XX", "....XXXX", "..XXXXX.", "XXXX....", "XX......" }, -- long, pointed, swept back
		owl = { ".XXXX.", "XXXXXX", "XXXXXX", "XXXXX.", ".XXX..", "..X..." }, -- broad and round
		angel = { ".....X", "....XX", "...XXX", "..XXX.", ".XXXX.", "XXXX..", "XXX...", ".X...." }, -- tall, upswept
	}
	local function wings(c1, c2, big, name, shape)
		if not ut then
			return
		end
		local pattern = WING_SHAPES[shape or ""] or (big and GREAT_WING or SMALL_WING)
		local cell = big and 0.42 or 0.36
		local topY = (big and 1.9 or 0.95)
		-- v0.25.13 (owner): wings sat low and drooped; root them on the upper back (shoulder blades)
		local lift = big and 0.25 or 0.45
		for _, sx in ipairs({ -1, 1 }) do
			for r, rowStr in ipairs(pattern) do
				local i = 1
				while i <= #rowStr do
					if string.sub(rowStr, i, i) == "X" then
						local j = i
						while j + 1 <= #rowStr and string.sub(rowStr, j + 1, j + 1) == "X" do
							j += 1
						end
						local len = j - i + 1
						local tip = j == #rowStr or string.sub(rowStr, j + 1, j + 1) ~= "X"
						local xMid = 0.25 + (i - 1 + len / 2) * cell
						local y = topY - (r - 1) * cell
						block("UpperTorso", Vector3.new(len * cell, cell, 0.2), CFrame.new(sx * xMid, y + lift, ut.Z / 2 + 0.22) * CFrame.Angles(0, sx * math.rad(-16), 0), c1, name)
						if tip then
							block("UpperTorso", Vector3.new(cell, cell, 0.24), CFrame.new(sx * (0.25 + (j - 0.5) * cell), y + lift, ut.Z / 2 + 0.22) * CFrame.Angles(0, sx * math.rad(-16), 0), c2, name .. "Tip")
						end
						i = j + 1
					else
						i += 1
					end
				end
			end
		end
	end
	if heritage == "Skyborn" then
		wings(Looks.FromHex(var.wing or "F8F8FF") or WHITE, Looks.FromHex(var.tip or "BEE6FF") or WHITE, var.shape == "angel", "Wing", var.shape)
	elseif heritage == "Cinderwing" and ut then
		wings(Color3.fromRGB(26, 22, 28), Color3.fromRGB(62, 54, 70), true, "Wing")
		-- the flame on the back: neon blocks in a rising column (FLAME mode lights it, CALM mode dims it)
		local lit = mode ~= "calm"
		local flame = { { 0.9, 0.7, 0.25, Color3.fromRGB(255, 120, 30) }, { 0.7, 0.6, 0.8, Color3.fromRGB(255, 170, 40) }, { 0.5, 0.5, 1.25, Color3.fromRGB(255, 220, 90) }, { 0.3, 0.4, 1.6, Color3.fromRGB(255, 245, 190) } }
		for _, f in ipairs(flame) do
			local b = block("UpperTorso", Vector3.new(f[1], f[2], f[1] * 0.8), CFrame.new(0, f[3] - 0.2, ut.Z / 2 + 0.55), f[4], "BackFlame")
			if b then
				b.Material = Enum.Material.Neon
				b.Transparency = lit and 0.05 or 0.85
				b.CastShadow = false
			end
		end
	elseif heritage == "Tidekin" then
		local fin = Looks.FromHex(var.fin or "3CC8BE") or Color3.fromRGB(60, 200, 190)
		local kind = var.fins or "reef"
		local finL = light(fin, 0.25)
		emitRuns(function(x, y, z)
			if kind == "reef" then
				local top = 8 + ((z >= 3 and z <= 5) and 2 or 1) + (lumpy and 1 or 0)
				if x >= 3 and x <= 4 and z >= 1 and z <= 7 and y >= 8 and y <= top then
					return 1
				end
			end
			-- ear fins on every fish kind (small on sharks)
			if (x == -2 or x == 9) and y >= 3 and y <= (kind == "shark" and 4 or 5) and z >= 3 and z <= 4 then
				return 2
			end
		end, function(v)
			return v == 2 and finL or fin
		end, "Fin")
		local back = ut and ut.Z / 2 or 0.5
		if kind == "shark" and ut then
			-- one tall swept-back dorsal fin
			for i, h in ipairs({ 1.4, 1.1, 0.8, 0.5 }) do
				block("UpperTorso", Vector3.new(0.22, h, 0.3), CFrame.new(0, 0.1 + h / 2 - 0.3, back + 0.15 + (i - 1) * 0.28), i == 1 and finL or fin, "FinBack")
			end
		elseif kind == "lionfish" and ut then
			-- a row of striped spines down the back + spines on both forearms
			for i = -2, 2 do
				block("UpperTorso", Vector3.new(0.14, 0.9 - math.abs(i) * 0.15, 0.14), CFrame.new(i * 0.32, 0.5, back + 0.25) * CFrame.Angles(math.rad(-25), 0, 0), i % 2 == 0 and fin or WHITE, "FinBack")
			end
			for _, arm in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
				local sx = arm == "LeftLowerArm" and -1 or 1
				for k = 0, 2 do
					block(arm, Vector3.new(0.5, 0.12, 0.12), CFrame.new(sx * 0.6, 0.3 - k * 0.3, 0.2) * CFrame.Angles(0, 0, sx * math.rad(-20)), k % 2 == 0 and fin or WHITE, "FinArm")
				end
			end
		elseif kind == "manta" and ut then
			-- wide flat triangles from the shoulder blades
			for _, sx in ipairs({ -1, 1 }) do
				for i, w in ipairs({ 1.6, 1.2, 0.8 }) do
					block("UpperTorso", Vector3.new(w, 0.3, 0.16), CFrame.new(sx * (0.6 + w / 2), 0.55 - (i - 1) * 0.3, back + 0.12) * CFrame.Angles(0, sx * math.rad(-12), 0), i == 1 and fin or finL, "FinBack")
				end
			end
		end
	elseif heritage == "Beastkin" then
		local up = lumpy and 1 or 0
		local kind = var.ears or "cat"
		emitRuns(function(x, y, z)
			local dy = y - (9 + up)
			local left = x >= 0 and x <= 1
			local right = x >= 6 and x <= 7
			if not (left or right) or z < 3 or z > 4 then
				return nil
			end
			local inner = (left and x == 1) or (right and x == 6)
			if kind == "rabbit" then
				if dy >= 0 and dy <= 4 and (dy < 4 or inner) then
					return (inner and dy >= 1 and dy <= 3) and 2 or 1
				end
			elseif kind == "bear" then
				if dy == 0 then
					return inner and 2 or 1
				end
			elseif kind == "fox" then
				if dy >= 0 and dy <= 2 and (dy < 2 or not inner) then
					return (inner and dy == 0) and 2 or (dy == 2 and 3 or 1)
				end
			else
				if dy >= 0 and dy <= 1 then
					return (dy == 0 and inner) and 2 or 1
				end
			end
		end, function(v)
			return v == 2 and Color3.fromRGB(246, 160, 170) or (v == 3 and Color3.fromRGB(250, 250, 250) or hair1)
		end, "Ear")
		if lt then
			local tipC = kind == "fox" and Color3.fromRGB(250, 250, 250) or hair2
			if kind == "rabbit" or kind == "bear" then
				block("LowerTorso", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.05, lt.Z / 2 + 0.3), kind == "rabbit" and Color3.fromRGB(250, 250, 250) or hair1, "Tail")
			else
				block("LowerTorso", Vector3.new(0.35, 0.35, 0.7), CFrame.new(0, 0, lt.Z / 2 + 0.35), hair1, "Tail")
				block("LowerTorso", Vector3.new(0.35, 0.7, 0.35), CFrame.new(0, 0.35, lt.Z / 2 + 0.75), hair1, "Tail")
				block("LowerTorso", Vector3.new(0.38, 0.38, 0.38), CFrame.new(0, 0.85, lt.Z / 2 + 0.8), tipC, "TailTip")
			end
		end
	elseif heritage == "Oni" then
		local horn = Looks.FromHex(var.horn or "F0E6D2") or WHITE
		local kind = var.horns or "twin"
		-- v0.25.9 (owner): horns grow out of the FOREHEAD and curve up. z -2 = in front of the bangs (hair sits at
		-- z -1), y 6-7 = forehead, hair tops out around y 9 so the upper part must reach y 10+ to read.
		emitRuns(function(x, y, z)
			if kind == "single" then
				if x >= 3 and x <= 4 then
					if y >= 6 and y <= 9 and z == -2 then
						return 1
					elseif y >= 10 and y <= 11 and z == -1 then
						return 1
					elseif y == 12 and z == -1 then
						return 2
					end
				end
			elseif kind == "curved" then
				-- ram-like: from the temples, out to the sides, then up and back
				local function at(l, r)
					return x == l or x == r
				end
				if y >= 6 and y <= 7 and z == -2 and (x <= 1 or x >= 6) and x >= 0 and x <= 7 then
					return 1
				elseif y == 8 and z == -2 and (at(-1, 8) or at(0, 7)) then
					return 1
				elseif y == 9 and z == -1 and at(-2, 9) then
					return 1
				elseif y == 10 and z == -1 and at(-2, 9) then
					return 1
				elseif y == 11 and z == 0 and at(-2, 9) then
					return 2
				end
			else
				-- twin: two horns from the forehead, up and slightly back, narrowing to a tip
				if (x == 1 or x == 2 or x == 5 or x == 6) and y >= 6 and y <= 8 and z == -2 then
					return 1
				elseif (x == 1 or x == 2 or x == 5 or x == 6) and y >= 9 and y <= 10 and z == -1 then
					return 1
				elseif (x == 2 or x == 5) and y == 11 and z == -1 then
					return 2
				end
			end
		end, function(v)
			return v == 2 and light(horn, 0.35) or horn
		end, "Horn")
	end
end

-- v0.25.149: every look is built in REST space (place() gives the rest pose), then blocks whose faces share a plane
-- with a block of another color are pushed apart (Coplanar), then emitted. Real characters scale the result (Apply).
local function buildAll(look, heritage, variant, mode, place, emit)
	local q = {}
	buildBlocks(look, heritage, variant, mode, place, function(b, partName, cf)
		table.insert(q, { b, cf, partName })
	end)
	Coplanar.Fix(q)
	for _, e in ipairs(q) do
		emit(e[1], e[3], e[2])
	end
end

-- ===== real characters (server) =====
function VC.Apply(char, look, heritage, variant, mode)
	local old = char:FindFirstChild("VoxelBody")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "VoxelBody"
	local parts = {}
	for _, name in ipairs(VC.BODY_PARTS) do
		parts[name] = char:FindFirstChild(name)
	end
	-- v0.25.149 (owner: clothes flickered on real characters only): build at the R15 rest sizes, then scale each block
	-- with its limb (avatars are ~1.06x rest). Building from the live sizes broke every gap tuned at rest sizes.
	buildAll(look, heritage, variant, mode, function(name)
		local r = REST[name]
		if not r or not parts[name] then
			return nil
		end
		return CFrame.new(r[2]), r[1]
	end, function(b, partName, cf)
		local p, r = parts[partName], REST[partName]
		local k = (p.Size.X / r[1].X + p.Size.Y / r[1].Y + p.Size.Z / r[1].Z) / 3
		local rel = CFrame.new(r[2]):ToObjectSpace(cf)
		b.Size *= k
		b.CFrame = p.CFrame * CFrame.new(rel.Position * k) * rel.Rotation
		local w = Instance.new("WeldConstraint")
		w.Part0 = parts[partName]
		w.Part1 = b
		w.Parent = b
		b.Parent = model
	end)
	model.Parent = char
	-- hide the R15 body under the blocks (and its face decal / any clothing images)
	for _, p in pairs(parts) do
		p.Transparency = 1
		for _, d in ipairs(p:GetChildren()) do
			if d:IsA("Decal") then
				d.Transparency = 1
			end
		end
	end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") or c:IsA("Accessory") then
			c:Destroy()
		end
	end
	char:SetAttribute("Voxelized", true)
	return model
end

-- ===== standalone preview (client menu) =====
function VC.Preview(look, heritage, variant, mode, opts)
	LITE = opts ~= nil and opts.lite == true
	local model = Instance.new("Model")
	model.Name = "VoxelPreview"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	buildAll(look, heritage, variant, mode, function(name)
		local r = REST[name]
		if not r then
			return nil
		end
		return CFrame.new(r[2]), r[1]
	end, function(b, limb, cf)
		b.Anchored = true
		b.CFrame = cf
		b:SetAttribute("Limb", limb) -- the body part it belongs to (tools/export_pose.luau poses previews by it)
		b.Parent = model
	end)
	model.WorldPivot = CFrame.new()
	LITE = false
	return model
end

-- Cinderwing FLAME / CALM: light or dim the back flame of a built character (server, after a mode switch)
function VC.SetFlame(char, lit)
	local body = char:FindFirstChild("VoxelBody")
	if not body then
		return
	end
	for _, b in ipairs(body:GetChildren()) do
		if b.Name == "BackFlame" then
			b.Transparency = lit and 0.05 or 0.85
		end
	end
end

VC.HairCount = #HAIR
return VC
