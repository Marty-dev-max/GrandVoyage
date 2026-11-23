-- BladeModel (v0.25.104, owner: every sword is a real model in many colors): swords built from blocks at runtime from a
-- spec in Items.lua (def.blade), so a new color is one line of config and no upload.
-- Same frame as the old Wep_Sword mesh (WeaponService offsets stay valid): length along Z, tip at -Z, cutting edge -Y,
-- the flats face +-X, pivot on the grip ("drawn"); "sheathed" (blade in its scabbard) and "scabbard" (empty) pivot on
-- their center like the old SwordSheathed / Scabbard meshes.
-- spec = { form = "Katana" | "Cutlass" | "Wooden", shape?, hilt?, blade, edge, guard, wrap, wrap2?, pommel?, scabbard?, glow? }
-- (colors hex; shape = SHAPES key; hilt = guard style: Katana square|round|flower|oval|bar, Cutlass bow|basket|shell|cross|ring)
local BladeModel = {}

local hex = Color3.fromHex
local A = CFrame.Angles

local function block(m, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = m
	return p
end

-- form shape numbers: blade start (z, toward the tip), blade length, width at the guard / at the tip, curve (tip rises
-- toward the spine), grip length
local FORMS = {
	Katana = { z0 = -0.5, len = 3.5, w0 = 0.22, w1 = 0.2, curve = 0.2, grip = 0.95, thick = 0.07 },
	Cutlass = { z0 = -0.45, len = 3.3, w0 = 0.3, w1 = 0.42, curve = 0.32, grip = 0.85, thick = 0.08 },
	Wooden = { z0 = -0.5, len = 3.4, w0 = 0.24, w1 = 0.22, curve = 0.14, grip = 0.95, thick = 0.12 },
}
-- owner (v0.25.104): blades of a form differ by blade shape, guard style and the colors of grip + scabbard
-- shape = multipliers on the form's numbers (len, w0, w1, curve)
local SHAPES = {
	straight = { curve = 0.25 },
	deep = { curve = 1.8 },
	slim = { w0 = 0.8, w1 = 0.75, len = 1.06 },
	broad = { w0 = 1.25, w1 = 1.35 },
	long = { len = 1.15, w1 = 0.9 },
	hooked = { curve = 2.1, w1 = 1.1 },
	falchion = { w0 = 1.1, w1 = 1.6, curve = 0.6 },
}
local SEG = 8

-- the blade: SEG blocks following the curve, a bright edge strip on the -Y side, a short angled tip
local function blade(m, f, spec)
	local bladeC = hex(spec.blade)
	local edgeC = hex(spec.edge or spec.blade)
	local wood = spec.form == "Wooden"
	local mat = wood and Enum.Material.Wood or Enum.Material.SmoothPlastic
	local segLen = f.len / SEG
	local function at(t)
		return f.curve * t * t -- y offset of the spine line at t (0 = guard, 1 = tip)
	end
	-- voxel steps: axis-aligned blocks touching end to end (rotated, overlapping blocks z-fought and looked like
	-- stacked plates), the curve = a small rise per block; the last two blocks narrow to the point along the spine
	local glow = spec.glow and Enum.Material.Neon or nil
	local lastTop, lastW = 0, 0
	for i = 0, SEG - 1 do
		local tm = (i + 0.5) / SEG
		local w = f.w0 + (f.w1 - f.w0) * tm
		local y, z = at(tm), f.z0 - (i + 0.5) * segLen
		if i == SEG - 1 then
			w = w * 0.62
			y = y + w * 0.3
		end
		local cf = CFrame.new(0, y, z)
		lastTop, lastW = y + w / 2, w
		block(m, "Blade", Vector3.new(f.thick, w, segLen), cf, bladeC, mat)
		if not wood then
			block(m, "Edge", Vector3.new(f.thick + 0.012, 0.07, segLen), cf * CFrame.new(0, -w / 2 + 0.03, 0), edgeC, glow)
		end
	end
	local tw = lastW * 0.5
	local tcf = CFrame.new(0, lastTop - tw / 2, f.z0 - f.len - segLen * 0.25)
	block(m, "Blade", Vector3.new(f.thick, tw, segLen * 0.5), tcf, wood and bladeC or edgeC, wood and mat or glow)
	if spec.form == "Katana" then
		-- the collar (gold) where the blade meets the guard
		block(m, "Collar", Vector3.new(f.thick + 0.06, f.w0 + 0.06, 0.1), CFrame.new(0, 0, f.z0 + 0.02), hex(spec.pommel or "D9A441"))
	end
end

local function hilt(m, f, spec)
	local guardC = hex(spec.guard)
	local wrapC = hex(spec.wrap)
	local wrap2 = hex(spec.wrap2 or spec.wrap):Lerp(Color3.new(), spec.wrap2 and 0 or 0.25)
	local pommelC = hex(spec.pommel or spec.guard)
	local zg = f.z0 + 0.08 -- guard plane
	local light = guardC:Lerp(Color3.new(1, 1, 1), 0.22)
	local dark = guardC:Lerp(Color3.new(), 0.2)
	local function g(size, y, z, c)
		block(m, "Guard", size, CFrame.new(0, y, zg + (z or 0)), c or guardC)
	end
	local style = spec.hilt
	if spec.form == "Wooden" then
		block(m, "Guard", Vector3.new(0.34, 0.4, 0.08), CFrame.new(0, 0, zg), guardC, Enum.Material.Wood)
	elseif spec.form == "Cutlass" then
		local bow = function() -- knuckle bow on the edge side from the guard down to the pommel
			g(Vector3.new(0.1, 0.12, f.grip + 0.1), -0.32, (f.grip + 0.1) / 2)
			g(Vector3.new(0.1, 0.18, 0.1), -0.24, f.grip + 0.08)
		end
		if style == "basket" then
			-- plates closing around the hand on both sides
			g(Vector3.new(0.12, 0.66, 0.1), -0.05, 0)
			bow()
			for _, x in ipairs({ -0.16, 0.16 }) do
				block(m, "Guard", Vector3.new(0.05, 0.36, 0.5), CFrame.new(x, -0.16, zg + 0.27), dark)
				block(m, "Guard", Vector3.new(0.06, 0.06, 0.5), CFrame.new(x * 1.15, -0.02, zg + 0.27), light)
			end
		elseif style == "shell" then
			-- a big round shell over the hand + bow
			g(Vector3.new(0.12, 0.5, 0.1), -0.05, 0)
			bow()
			g(Vector3.new(0.44, 0.36, 0.06), -0.12, 0.07, dark)
			g(Vector3.new(0.34, 0.46, 0.06), -0.12, 0.07, dark)
			g(Vector3.new(0.18, 0.18, 0.08), -0.12, 0.08, light)
		elseif style == "cross" then
			-- open crossbar, quillons curled toward the tip, no bow
			g(Vector3.new(0.12, 0.74, 0.1), 0, 0)
			g(Vector3.new(0.12, 0.1, 0.16), 0.36, -0.1, light)
			g(Vector3.new(0.12, 0.1, 0.16), -0.36, -0.1, light)
		elseif style == "ring" then
			-- bow + a thumb ring loop on the spine side
			g(Vector3.new(0.12, 0.58, 0.1), -0.05, 0)
			bow()
			g(Vector3.new(0.08, 0.06, 0.26), 0.3, 0.1, light)
			g(Vector3.new(0.08, 0.22, 0.06), 0.3, 0.22, light)
		else -- "bow" (default): crossbar + knuckle bow + small shell
			g(Vector3.new(0.12, 0.62, 0.1), -0.05, 0)
			bow()
			g(Vector3.new(0.3, 0.3, 0.06), -0.1, 0.07, dark)
		end
	else -- Katana tsuba styles
		if style == "round" then
			-- stepped disc (two crossed bars + a core)
			g(Vector3.new(0.5, 0.34, 0.08), 0)
			g(Vector3.new(0.34, 0.54, 0.08), 0)
			g(Vector3.new(0.44, 0.46, 0.08), 0)
			g(Vector3.new(0.24, 0.3, 0.1), 0, 0, light)
		elseif style == "flower" then
			-- four lobes
			g(Vector3.new(0.3, 0.34, 0.08), 0)
			for _, o in ipairs({ { 0, 0.22 }, { 0, -0.22 }, { 0.2, 0 }, { -0.2, 0 } }) do
				block(m, "Guard", Vector3.new(0.16, 0.16, 0.08), CFrame.new(o[1], o[2], zg), light)
			end
		elseif style == "oval" then
			-- long in the blade's plane, thin across
			g(Vector3.new(0.3, 0.62, 0.08), 0)
			g(Vector3.new(0.22, 0.5, 0.1), 0, 0, light)
		elseif style == "bar" then
			-- a plain slim bar, almost no guard
			g(Vector3.new(0.2, 0.36, 0.06), 0)
		else -- "square" (default) with a lighter inner plate
			g(Vector3.new(0.46, 0.5, 0.08), 0)
			g(Vector3.new(0.36, 0.4, 0.1), 0, 0, light)
		end
	end
	-- grip: alternating wrap bands, then the pommel cap
	local n = 6
	local seg = f.grip / n
	for i = 0, n - 1 do
		local z = zg + 0.04 + seg * (i + 0.5)
		local big = i % 2 == 0
		block(m, "Grip", Vector3.new(big and 0.22 or 0.19, big and 0.26 or 0.23, seg + 0.01), CFrame.new(0, 0, z), big and wrapC or wrap2, Enum.Material.Fabric)
	end
	block(m, "Pommel", Vector3.new(0.25, 0.29, 0.12), CFrame.new(0, 0, zg + 0.04 + f.grip + 0.05), pommelC)
end

local function scabbard(m, f, spec)
	local c = hex(spec.scabbard or "3A2A22")
	local trim = hex(spec.pommel or spec.guard)
	local len = f.len + 0.08
	local zc = f.z0 - len / 2
	block(m, "Scabbard", Vector3.new(f.thick + 0.12, math.max(f.w0, f.w1) + 0.12, len), CFrame.new(0, f.curve * 0.3, zc) * A(math.rad(-3), 0, 0), c)
	block(m, "Scabbard", Vector3.new(f.thick + 0.16, math.max(f.w0, f.w1) + 0.16, 0.14), CFrame.new(0, 0.02, f.z0 - 0.1), trim) -- mouth
	block(m, "Scabbard", Vector3.new(f.thick + 0.16, math.max(f.w0, f.w1) + 0.12, 0.18), CFrame.new(0, f.curve * 0.62, f.z0 - len + 0.1), trim) -- chape
end

-- mode: "drawn" (default) | "sheathed" | "scabbard" | "preview" (drawn, framed diagonally with the flat to the camera)
function BladeModel.Build(spec, mode)
	local base = FORMS[spec.form] or FORMS.Katana
	local f = table.clone(base)
	for k, v in pairs(SHAPES[spec.shape] or {}) do
		f[k] = base[k] * v
	end
	local m = Instance.new("Model")
	m.Name = "Blade"
	hilt(m, f, spec)
	if mode == "sheathed" or mode == "scabbard" then
		scabbard(m, f, spec)
	else
		blade(m, f, spec)
	end
	if mode == "sheathed" or mode == "scabbard" then
		-- same pivot for both, so the empty scabbard hangs exactly where the sheathed sword did
		local cf = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(cf.Position)
		if mode == "scabbard" then
			for _, p in ipairs(m:GetChildren()) do
				if p.Name ~= "Scabbard" then
					p:Destroy()
				end
			end
		end
	elseif mode == "preview" then
		-- ViewportFrames look down +Z: turn the flat to the camera and stand the blade on a diagonal
		m.WorldPivot = (A(0, 0, math.rad(-45)) * A(0, math.rad(90), 0)):Inverse()
	else
		m.WorldPivot = CFrame.new()
	end
	return m
end

return BladeModel
