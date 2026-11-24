-- SailCloth (v0.25.150, owner refs: furled at first, unfurled by the sail level you set, curved like a sail full of
-- wind, the emblem in the middle). Every ship sail part (tag "ShipSail", built by ShipModel) is hidden locally and
-- redrawn as a grid of cloth blocks welded to it:
--  * the ship model's attribute "Sails" (0..3, ShipService) picks how many rows hang down from the yard (none = a
--    furled roll), the builder's ship (no attribute) shows them full;
--  * cells bulge toward the bow in a stepped curve (deepest in the middle), the emblem area is a flat plateau;
--  * emblem = Config/SailArt (ship attribute "SailArt" when set, else Pirate skull / Marine mark by faction or by a
--    faction mast), drawn with run-length Frames on a SurfaceGui panel in front of the plateau (and one behind it).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SailArt = require(ReplicatedStorage.Shared.Config.SailArt)

local SailCloth = {}

local COLS, ROWS = 8, 8
local LEVEL_ROWS = { [0] = 0, 3, 6, 8 } -- rows unrolled per sail level (the emblem rows 2..5 show from level 2)
local EM0, EM1 = 2, 5 -- emblem cells (cols and rows, inclusive)
local DEPTH = 0.3
local STEP = 0.3 -- bulge steps (blocky curve)
local SPEED = 6 -- rows per second while furling / unfurling
local MARINE_CLOTH = Color3.fromRGB(246, 247, 252)
local MARINE_BAND = Color3.fromRGB(44, 74, 150)

local folder
local sails = {} -- sail part -> state

local function shipOf(sail)
	local mast = sail.Parent
	return mast and mast.Parent
end

local function targetRows(st)
	local ship = shipOf(st.sail)
	local lvl = ship and ship:GetAttribute("Sails")
	if lvl == nil then
		return ROWS -- builder preview / anything without a sail level: full sail
	end
	return LEVEL_ROWS[math.clamp(math.floor(lvl), 0, 3)] or ROWS
end

local function emblemOf(st)
	local ship = shipOf(st.sail)
	local custom = ship and ship:GetAttribute("SailArt")
	if SailArt.Valid(custom) then
		return custom
	end
	local kind = st.sail:GetAttribute("Kind")
	local faction = (kind ~= nil and kind ~= "") and kind or (ship and ship:GetAttribute("Faction"))
	if faction == "Pirate" then
		return SailArt.Pirate
	elseif faction == "Marine" then
		return SailArt.Marine
	end
	return nil
end

local function clothColor(st)
	local ship = shipOf(st.sail)
	local hex = ship and ship:GetAttribute("SailColor")
	if type(hex) == "string" then
		local ok, c = pcall(Color3.fromHex, hex)
		if ok then
			return c
		end
	end
	if (st.sail:GetAttribute("Kind") or "") == "" and ship and ship:GetAttribute("Faction") == "Marine" then
		return MARINE_CLOTH
	end
	return st.sail.Color
end

local function newPart(size, color, name)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Plaster -- Fabric's MaterialService variant renders dark blue
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	return p
end

local function weldTo(sail, part, c0)
	part.CFrame = sail.CFrame * c0
	local w = Instance.new("Weld")
	w.Part0 = sail
	w.Part1 = part
	w.C0 = c0
	w.Parent = part
	part.Parent = folder
	return w
end

-- the emblem as Frames: each row merges runs of the same color
local function drawArt(gui, art)
	local n = SailArt.Size
	for y = 0, n - 1 do
		local x = 0
		while x < n do
			local c = SailArt.At(art, x, y)
			if c then
				local x1 = x
				while x1 + 1 < n and SailArt.At(art, x1 + 1, y) == c do
					x1 += 1
				end
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = c
				f.Position = UDim2.fromScale(x / n, y / n)
				f.Size = UDim2.fromScale((x1 - x + 1) / n, 1 / n)
				f.Parent = gui
				x = x1 + 1
			else
				x += 1
			end
		end
	end
end

local function bulge(st, c, r, rows)
	if rows <= 0 then
		return 0
	end
	local sx = math.sin(math.pi * (c + 0.5) / COLS)
	local sy = math.sin(math.pi * (math.min(r, rows - 1) + 0.5) / rows) ^ 0.7
	if st.art and rows >= EM1 + 1 and c >= EM0 and c <= EM1 and r >= EM0 and r <= EM1 then
		-- flat plateau under the emblem, as deep as the middle of the sail
		sx, sy = 1, math.sin(math.pi * ((EM0 + EM1) / 2 + 0.5) / rows) ^ 0.7
	end
	return math.floor(st.depth * sx * sy / STEP + 0.5) * STEP
end

local function layout(st)
	local rows = math.floor(st.rows + 0.5)
	local W, H = st.sail.Size.X, st.sail.Size.Y
	local cw, ch = W / COLS, H / ROWS
	for _, cell in ipairs(st.cells) do
		local shown = cell.r < rows
		cell.part.Transparency = shown and 0 or 1
		if shown then
			local z = bulge(st, cell.c, cell.r, rows)
			cell.weld.C0 = CFrame.new(-W / 2 + (cell.c + 0.5) * cw, H / 2 - (cell.r + 0.5) * ch, -z)
		end
	end
	-- the furled roll under the yard: thick when furled, a thin hem when the sail is out
	local k = 1 - rows / ROWS
	st.roll.Size = Vector3.new(W + 0.2, 0.35 + 0.75 * k, 0.4 + 0.6 * k)
	st.roll.Transparency = 0
	if st.panels then
		local show = rows >= EM1 + 1
		local zE = bulge(st, EM0, EM0, rows)
		local pw = (EM1 - EM0 + 1) * cw
		local ph = (EM1 - EM0 + 1) * ch
		local cx = -W / 2 + (EM0 + EM1 + 1) / 2 * cw
		local cy = H / 2 - (EM0 + EM1 + 1) / 2 * ch
		st.panels[1].weld.C0 = CFrame.new(cx, cy, -zE - DEPTH / 2 - 0.03)
		st.panels[2].weld.C0 = CFrame.new(cx, cy, -zE + DEPTH / 2 + 0.03)
		for _, pn in ipairs(st.panels) do
			pn.part.Size = Vector3.new(pw, ph, 0.04)
			pn.gui.Enabled = show
		end
	end
end

local function build(sail)
	if sails[sail] then
		return
	end
	local W, H = sail.Size.X, sail.Size.Y
	local st = { sail = sail, cells = {}, rows = 0, depth = W * 0.16 }
	st.art = emblemOf(st)
	st.rows = targetRows(st)
	local cloth = clothColor(st)
	local ship = shipOf(sail)
	local marine = (sail:GetAttribute("Kind") or "") == "" and ship and ship:GetAttribute("Faction") == "Marine" and not (ship:GetAttribute("SailColor"))
	local cw, ch = W / COLS, H / ROWS
	for r = 0, ROWS - 1 do
		for c = 0, COLS - 1 do
			-- slight shade toward the edges (deeper in the middle), a navy band along the foot for the Marines
			local edge = 1 - math.sin(math.pi * (c + 0.5) / COLS)
			local col = cloth:Lerp(Color3.new(0, 0, 0), 0.1 * edge)
			if marine and r == ROWS - 1 then
				col = MARINE_BAND
			end
			local part = newPart(Vector3.new(cw + 0.02, ch + 0.02, DEPTH), col, "Cloth")
			local w = weldTo(sail, part, CFrame.new(-W / 2 + (c + 0.5) * cw, H / 2 - (r + 0.5) * ch, 0))
			table.insert(st.cells, { part = part, weld = w, c = c, r = r })
		end
	end
	st.roll = newPart(Vector3.new(W + 0.2, 1, 1), cloth:Lerp(Color3.new(0, 0, 0), 0.12), "SailRoll")
	weldTo(sail, st.roll, CFrame.new(0, H / 2 + 0.25, 0))
	if st.art then
		st.panels = {}
		for i, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local part = newPart(Vector3.new(1, 1, 0.04), cloth, "Emblem")
			part.Transparency = 1
			local w = weldTo(sail, part, CFrame.new())
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 1
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 24
			gui.Parent = part
			drawArt(gui, st.art)
			st.panels[i] = { part = part, weld = w, gui = gui }
		end
	end
	sail.LocalTransparencyModifier = 1
	sails[sail] = st
	layout(st)
end

local function drop(sail)
	local st = sails[sail]
	if not st then
		return
	end
	sails[sail] = nil
	for _, cell in ipairs(st.cells) do
		cell.part:Destroy()
	end
	st.roll:Destroy()
	for _, pn in ipairs(st.panels or {}) do
		pn.part:Destroy()
	end
end

function SailCloth.Start()
	folder = Instance.new("Folder")
	folder.Name = "GVSailCloth"
	folder.Parent = workspace
	local function added(sail)
		if not sail:IsA("BasePart") then
			return
		end
		-- wait until the ship model is in place (the tag replicates with the part)
		task.defer(function()
			if sail:IsDescendantOf(workspace) then
				local ok, err = pcall(build, sail)
				if not ok then
					warn("[SailCloth]", err)
				end
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("ShipSail"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("ShipSail"):Connect(drop)
	for _, s in ipairs(CollectionService:GetTagged("ShipSail")) do
		added(s)
	end
	-- furl / unfurl toward the ship's sail level; a sail that left the world is dropped
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then
			return
		end
		local step = acc
		acc = 0
		for sail, st in pairs(sails) do
			if not sail:IsDescendantOf(workspace) then
				drop(sail)
			else
				local want = targetRows(st)
				if math.abs(st.rows - want) > 0.01 then
					local before = math.floor(st.rows + 0.5)
					st.rows = st.rows < want and math.min(want, st.rows + SPEED * step) or math.max(want, st.rows - SPEED * step)
					if math.floor(st.rows + 0.5) ~= before then
						layout(st)
					end
				end
			end
		end
	end)
end

return SailCloth
