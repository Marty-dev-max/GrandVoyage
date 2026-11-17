-- Build every clip in src/shared/Config/AnimClips.lua into assets/anims/<Name>.rbxm (a KeyframeSequence).
-- Then upload: ROBLOX_API_KEY=... python3 tools/upload_models.py assets/anims src/shared/Config/Animations.lua --type Animation
--   lune run tools/build_anims.luau
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local Clips = require("../src/shared/Config/AnimClips")
local AnimBuild = require("../src/shared/Modules/AnimBuild")

local env = { Instance = roblox.Instance, CFrame = roblox.CFrame, Enum = roblox.Enum }
local n = 0
for name, clip in pairs(Clips) do
	if type(clip) == "table" and clip.keys then
		local kfs = AnimBuild.Build(name, clip, env)
		fs.writeFile("assets/anims/" .. name .. ".rbxm", roblox.serializeModel({ kfs }))
		n += 1
	end
end
print("built " .. n .. " animations into assets/anims")
