-- ChartsView (client): island names you have not charted yet read "???" (owner, v0.22.4). Masks the big floating
-- island banners in the world; windows ask ChartsView.Known / ChartsView.Name. See Shared/Modules/Charts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charts = require(ReplicatedStorage.Shared.Modules.Charts)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local State = require(script.Parent.Parent.State)

local ChartsView = {}

local function step()
	return State.quest and State.quest.step or 1
end

function ChartsView.Known(islandId)
	local p = State.profile
	return Charts.Known(islandId, p and p.unlocked, step())
end

function ChartsView.Name(isl)
	if type(isl) == "string" then
		isl = Islands.ById[isl]
	end
	if not isl then
		return Charts.Unknown
	end
	return ChartsView.Known(isl.id) and isl.name or Charts.Unknown
end

-- by display name (the boss board sends island names)
function ChartsView.NameOf(displayName)
	for _, isl in ipairs(Islands.List) do
		if isl.name == displayName then
			return ChartsView.Name(isl)
		end
	end
	return displayName
end

-- banner = Part with attribute IslandBanner; its BillboardGui holds name / subtitle / "Levels" labels
local function dressBanner(part)
	local id = part:GetAttribute("IslandBanner")
	local isl = id and Islands.ById[id]
	local bb = part:FindFirstChildWhichIsA("BillboardGui")
	if not isl or not bb then
		return
	end
	-- v0.25.25 (owner): no island name floating over the islands any more (the part stays: map cleanup finds
	-- island folders by it)
	bb.Enabled = false
	local known = ChartsView.Known(id)
	local labels = {}
	for _, c in ipairs(bb:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	for _, l in ipairs(labels) do
		local orig = l:GetAttribute("OrigText")
		if orig == nil then
			l:SetAttribute("OrigText", l.Text)
			orig = l.Text
		end
		if known or l.Name == "Levels" then -- the level range is fine to know
			l.Text = orig
		elseif orig == isl.name then
			l.Text = Charts.Unknown
		else
			l.Text = Charts.UnknownSubtitle
		end
	end
end

local function banners()
	local out = {}
	local world = workspace:FindFirstChild("World")
	for _, d in ipairs(world and world:GetDescendants() or {}) do
		if d:IsA("BasePart") and d:GetAttribute("IslandBanner") then
			table.insert(out, d)
		end
	end
	return out
end

local cached
function ChartsView.Refresh()
	if not cached or #cached == 0 or not cached[1].Parent then
		cached = banners()
	end
	for _, b in ipairs(cached) do
		dressBanner(b)
	end
end

function ChartsView.Start()
	State.Changed:Connect(function(kind)
		if kind == "profile" or kind == "quest" then
			ChartsView.Refresh()
		end
	end)
	ChartsView.Refresh()
	-- the World may stream in / be rebuilt after the client starts
	task.delay(5, ChartsView.Refresh)
	task.delay(20, ChartsView.Refresh)
end

return ChartsView
