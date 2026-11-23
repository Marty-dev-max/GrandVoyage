-- ItemReveal (v0.25.92, owner: a "got a rare item" moment like their reference clip, background by rarity): when a
-- Rare+ item drops (gear, fruits, eggs, accessories; Epic+ for materials / potions / ammo) the screen flashes in the
-- rarity color, rays spin behind the item, the item pops in as a turning 3D model with sparkles, then "<RARITY> GET!"
-- + its name slam in. ~2 s, tap/click to skip, queued one at a time. Cards keep their own CardReveal.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.UIKit)
local Audio = require(script.Parent.Parent.Controllers.Audio)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)

local ItemReveal = {}
local New, Tween = UI.New, UI.Tween
local queue, busy = {}, false
local SMALL = { Material = true, Consumable = true, Ammo = true }

function ItemReveal.Worth(def)
	if not def or def.kind == "Card" then
		return false
	end
	local rank = UI.Rarity.Get(def.rarity).rank
	return rank >= (SMALL[def.kind] and 4 or 3)
end

local function preview(parent, def, size)
	return (def.kind == "Fruit" and UI.ModelView(parent, "Fruits", def.fruit, size, 1.4))
		or UI.AccessoryView(parent, def.id, size)
		or (def.weaponType and UI.WeaponView(parent, def, size, 1.2))
		or (def.kind == "Egg" and UI.VoxelEgg(parent, def.id, size))
		or UI.VoxelIcon(parent, UI.ItemIconName(def), size)
		or UI.Icon(parent, UI.ItemIconName(def) or "🎁", size)
end

local function play(def)
	local tier = UI.Rarity.Get(def.rarity)
	local k = math.clamp((tier.rank - 3) / 4, 0, 1) -- Rare 0 .. Secret 1
	local g = New("ScreenGui", { Name = "GVItemReveal", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 59, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = UI.Root.Parent })
	local alive, skip = true, false
	-- background: rarity gradient wash from the centre (light) to the edges (deep)
	local bg = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = g })
	local grad = New("UIGradient", { Color = ColorSequence.new(tier.top, tier.bottom), Rotation = 90, Parent = bg })
	if tier.prismatic or tier.rainbow then
		grad.Color = UI.PrismaticSequence
		UI.SpinGradient(grad)
	end
	Tween(bg, 0.25, { BackgroundTransparency = 0.25 - 0.15 * k })
	local flash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 20, Parent = g })
	Tween(flash, 0.35, { BackgroundTransparency = 1 })
	local rays = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.focuslines, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(900, 900), ZIndex = 2, Parent = g })
	local rays2 = rays:Clone()
	rays2.ImageColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3)
	rays2.Size = UDim2.fromOffset(620, 620)
	rays2.Parent = g
	local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex.glow, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(380, 380), ZIndex = 3, Parent = g })
	UI.Sparkles(bg, Color3.new(1, 1, 1), 18 + math.floor(k * 18), { float = true, z = 4, star = 0.6 })
	-- the item
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(260, 260), ZIndex = 5, Parent = g })
	local view = preview(holder, def, 260)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1, 1)
	view.ZIndex = 6
	local sc = New("UIScale", { Scale = 0.1, Parent = holder })
	Tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	-- "<RARITY> GET!" + name
	local title = UI.Text(g, string.upper(tier.id) .. " GET!", 44, Color3.new(1, 1, 1), "Display", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(700, 52),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 8 })
	UI.Stroke(title, tier.bottom:Lerp(Color3.new(0, 0, 0), 0.5), 4, Enum.ApplyStrokeMode.Contextual)
	UI.RarityText(title, def.rarity)
	local tsc = New("UIScale", { Scale = 0, Parent = title })
	local name = UI.Text(g, def.name or def.id, 24, Color3.new(1, 1, 1), "Display", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromOffset(700, 30),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTransparency = 1, ZIndex = 8 })
	-- sound: bass hit, then the rarity reward chime
	Audio.Play("CardBass", { pitch = 0.9 + k * 0.1 })
	task.delay(0.18, function()
		Audio.Play("Rarity" .. tier.id)
		tsc.Scale = 1.8
		Tween(tsc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(name, 0.3, { TextTransparency = 0 })
	end)
	local conn = UserInputService.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			skip = true
		end
	end)
	local t0 = os.clock()
	local step = RunService.RenderStepped:Connect(function(dt)
		if not alive then
			return
		end
		rays.Rotation += dt * 18
		rays2.Rotation -= dt * 30
		holder.Position = UDim2.new(0.5, 0, 0.42, math.sin((os.clock() - t0) * 2.4) * 6)
	end)
	local hold = 1.8 + 0.6 * k
	while os.clock() - t0 < hold and not (skip and os.clock() - t0 > 0.5) do
		task.wait()
	end
	alive = false
	step:Disconnect()
	conn:Disconnect()
	Tween(sc, 0.25, { Scale = 0.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, o in ipairs({ bg, rays, rays2, glow }) do
		Tween(o, 0.3, o:IsA("ImageLabel") and { ImageTransparency = 1 } or { BackgroundTransparency = 1 })
	end
	Tween(title, 0.25, { TextTransparency = 1 })
	Tween(name, 0.25, { TextTransparency = 1 })
	task.wait(0.32)
	g:Destroy()
end

function ItemReveal.Play(def)
	if not ItemReveal.Worth(def) then
		return
	end
	table.insert(queue, def)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(play, table.remove(queue, 1))
			if not ok then
				warn("[ItemReveal] " .. tostring(err))
				local left = UI.Root.Parent and UI.Root.Parent:FindFirstChild("GVItemReveal")
				if left then
					left:Destroy()
				end
			end
		end
		busy = false
	end)
end

return ItemReveal
