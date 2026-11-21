-- PixelUI (v0.24.0, owner): the voxel / pixel-art pass over every GUI in the game.
--  * Font: Press Start 2P for everything (UIKit's UI.Fonts all point at it).
--  * Text: Press Start 2P is about twice as wide as the old rounded font, so fixed TextSizes are scaled by TEXT_SCALE
--    once (attribute PxDone). TextScaled text fits itself.
--  * Corners: every UICorner becomes square (blocky panels, buttons and chips); strokes get mitred (sharp) joins.
-- It watches PlayerGui (all ScreenGuis, including ones made later) and anything passed to PixelUI.Watch (e.g.
-- nameplate BillboardGuis in the world). Mark an object with attribute PxKeep = true to leave it untouched.
local Players = game:GetService("Players")

local PixelUI = {}
-- v0.24.6 (owner: text looked too small, and out of proportion when the UI scale changes): fixed-size text becomes
-- "fit to its box" (TextScaled with a size cap at TEXT_SCALE x the old size), so it is as big as the box allows at
-- every UI scale and never spills out of it. Auto-sized labels keep a plain scaled TextSize.
PixelUI.TEXT_SCALE = 0.82 -- v0.25.6 (owner: Bag/Skills text hard to read): 0.74 -> 0.82, min 10 -> 12
PixelUI.MIN_TEXT = 12
PixelUI.Font = Font.fromEnum(Enum.Font.Arcade) -- Press Start 2P

local function keep(obj)
	local p = obj
	for _ = 1, 6 do
		if not p then
			return false
		end
		if p:GetAttribute("PxKeep") then
			return true
		end
		p = p.Parent
	end
	return false
end

local watchGradient

function PixelUI.Apply(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		if obj:GetAttribute("PxDone") or keep(obj) then
			return
		end
		obj:SetAttribute("PxDone", true)
		obj.FontFace = PixelUI.Font
		if not obj.TextScaled then
			local target = math.max(PixelUI.MIN_TEXT, math.floor(obj.TextSize * PixelUI.TEXT_SCALE + 0.5))
			obj.TextSize = target
			if obj.AutomaticSize == Enum.AutomaticSize.None and not obj:IsA("TextBox") and not obj:FindFirstChildOfClass("UITextSizeConstraint") then
				local c = Instance.new("UITextSizeConstraint")
				c.MaxTextSize = target
				c.MinTextSize = math.min(11, target)
				c:SetAttribute("PxDone", true)
				c.Parent = obj
				obj.TextScaled = true
			end
		end
		-- pixel fonts look best with a hard 1px dark outline instead of a soft stroke
		obj.LineHeight = math.max(obj.LineHeight, 1.15)
	elseif obj:IsA("UICorner") then
		if not keep(obj) then
			obj.CornerRadius = UDim.new(0, 0)
		end
	elseif obj:IsA("UIStroke") then
		obj.LineJoinMode = Enum.LineJoinMode.Miter
	elseif obj:IsA("UIGradient") then
		task.defer(watchGradient, obj) -- after the creator has set its parent and colors
	elseif obj:IsA("UITextSizeConstraint") then
		if not obj:GetAttribute("PxDone") then
			obj:SetAttribute("PxDone", true)
			obj.MaxTextSize = math.max(PixelUI.MIN_TEXT + 1, math.floor(obj.MaxTextSize * 0.8 + 0.5))
			obj.MinTextSize = math.max(10, math.floor(obj.MinTextSize * 0.7 + 0.5))
		end
	end
end

-- v0.25.2 (owner: text looked "hollow"): a UIGradient tints the WHOLE object, its text included, so a colored button
-- fill turned white letters into the button's color and only the outline showed. For a text object with a visible
-- background, the gradient's color moves into BackgroundColor3 and the gradient keeps only the light/shade ratio:
-- the background renders exactly the same (bg x c = (bg x top) x (c / top)) and the text stays near white.
-- Gradients on text with no background (colored titles, crit numbers) are meant for the text and are left alone.
local function untint(g)
	local obj = g.Parent
	if not obj or not (obj:IsA("TextButton") or obj:IsA("TextLabel")) or obj.BackgroundTransparency >= 0.99 or keep(obj) then
		return
	end
	local kps = g.Color.Keypoints
	local top = kps[1].Value
	for _, k in ipairs(kps) do
		local v = k.Value
		if v.R + v.G + v.B > top.R + top.G + top.B then
			top = v
		end
	end
	if top.R > 0.97 and top.G > 0.97 and top.B > 0.97 then
		return -- already neutral
	end
	local base = obj:GetAttribute("PxBaseBG")
	if base == nil then
		base = obj.BackgroundColor3
		obj:SetAttribute("PxBaseBG", base)
	end
	local out = {}
	for i, k in ipairs(kps) do
		local v = k.Value
		out[i] = ColorSequenceKeypoint.new(k.Time, Color3.new(math.min(1, v.R / math.max(top.R, 0.01)), math.min(1, v.G / math.max(top.G, 0.01)), math.min(1, v.B / math.max(top.B, 0.01))))
	end
	obj.BackgroundColor3 = Color3.new(base.R * top.R, base.G * top.G, base.B * top.B)
	g.Color = ColorSequence.new(out)
end
function watchGradient(g)
	if g:GetAttribute("PxGrad") then
		return
	end
	g:SetAttribute("PxGrad", true)
	untint(g)
	-- recolored later (UI.SetButtonColor, hovers): normalize again (the second pass sees a neutral one and stops)
	g:GetPropertyChangedSignal("Color"):Connect(function()
		untint(g)
	end)
end

local watched = {}
function PixelUI.Watch(container)
	if watched[container] then
		return
	end
	watched[container] = true
	for _, d in ipairs(container:GetDescendants()) do
		PixelUI.Apply(d)
	end
	container.DescendantAdded:Connect(PixelUI.Apply)
	-- a corner radius set later in code (e.g. the window's full screen toggle) is squared again
	container.DescendantAdded:Connect(function(d)
		if d:IsA("UICorner") then
			d:GetPropertyChangedSignal("CornerRadius"):Connect(function()
				if d.CornerRadius ~= UDim.new(0, 0) and not keep(d) then
					d.CornerRadius = UDim.new(0, 0)
				end
			end)
		end
	end)
end

function PixelUI.Start()
	PixelUI.Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
end

return PixelUI
