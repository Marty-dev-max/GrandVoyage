-- IslandEnter (v0.25.109, owner): no island name signs in the world; stepping onto an island's area shows its name in
-- the middle of the screen (UI.Banner, like Level Up). Checked twice a second from your character's position; an island
-- greets you again only after you were away from it for a while.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local UI = require(script.Parent.Parent.UI.UIKit)

local IslandEnter = {}

local AGAIN = 90 -- seconds away before the same island greets you again

local function islandAt(pos)
	for _, isl in ipairs(Islands.List) do
		local dx, dz = pos.X - isl.x, pos.Z - (isl.z or 0)
		if dx * dx + dz * dz < (isl.radius * 1.05) ^ 2 then
			return isl
		end
	end
	return nil
end

function IslandEnter.Start()
	local current, leftAt = nil, {}
	task.spawn(function()
		while true do
			task.wait(0.5)
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local isl = root and islandAt(root.Position)
			if isl ~= current then
				if current then
					leftAt[current.id] = os.clock()
				end
				current = isl
				if isl and (not leftAt[isl.id] or os.clock() - leftAt[isl.id] > AGAIN) then
					local lv = isl.levels and ("Lv." .. isl.levels[1] .. " - " .. isl.levels[2]) or nil
					UI.Banner(isl.name, (isl.subtitle and (isl.subtitle .. (lv and "  •  " or "")) or "") .. (lv or ""), UI.Theme.Gold)
				end
			end
		end
	end)
end

return IslandEnter
