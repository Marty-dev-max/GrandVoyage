-- PixelUI (v0.24.0, owner): the voxel / pixel-art pass over every GUI in the game.
--  * Font: Press Start 2P for everything (UIKit's UI.Fonts all point at it).
--  * Text: Press Start 2P is about twice as wide as the old rounded font, so fixed TextSizes are scaled by TEXT_SCALE
--    once (attribute PxDone). TextScaled text fits itself.
--  * Corners: every UICorner becomes square (blocky panels, buttons and chips); strokes get mitred (sharp) joins.
-- It watches PlayerGui (all ScreenGuis, including ones made later) and anything passed to PixelUI.Watch (e.g.
-- nameplate BillboardGuis in the world). Mark an object with attribute PxKeep = true to leave it untouched.
local Players = game:GetService("Players")

local PixelUI = {}
PixelUI.TEXT_SCALE = 0.56
PixelUI.MIN_TEXT = 8
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

function PixelUI.Apply(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		if obj:GetAttribute("PxDone") or keep(obj) then
			return
		end
		obj:SetAttribute("PxDone", true)
		obj.FontFace = PixelUI.Font
		if not obj.TextScaled then
			obj.TextSize = math.max(PixelUI.MIN_TEXT, math.floor(obj.TextSize * PixelUI.TEXT_SCALE + 0.5))
		end
		-- pixel fonts look best with a hard 1px dark outline instead of a soft stroke
		obj.LineHeight = math.max(obj.LineHeight, 1.15)
	elseif obj:IsA("UICorner") then
		if not keep(obj) then
			obj.CornerRadius = UDim.new(0, 0)
		end
	elseif obj:IsA("UIStroke") then
		obj.LineJoinMode = Enum.LineJoinMode.Miter
	elseif obj:IsA("UITextSizeConstraint") then
		if not obj:GetAttribute("PxDone") then
			obj:SetAttribute("PxDone", true)
			obj.MaxTextSize = math.max(PixelUI.MIN_TEXT + 1, math.floor(obj.MaxTextSize * PixelUI.TEXT_SCALE + 0.5))
			obj.MinTextSize = math.max(6, math.floor(obj.MinTextSize * PixelUI.TEXT_SCALE + 0.5))
		end
	end
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
