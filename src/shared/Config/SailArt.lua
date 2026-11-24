-- SailArt (v0.25.150, owner): the emblem in the middle of every sail. 16 x 16 pixels, one character per pixel:
-- "0" = see-through (the sail cloth shows), "1".."f" = Palette[n]. Pirates start with a skull and crossbones (a
-- generic Jolly Roger), Marines carry the fleet's own anchor-and-star mark (ours, not any show's logo).
-- The sail emblem editor (Crew window) writes the same format.
local A = {}

A.Size = 16
A.Palette = {
	Color3.fromRGB(22, 22, 26), -- 1 black
	Color3.fromRGB(246, 244, 236), -- 2 white
	Color3.fromRGB(255, 200, 60), -- 3 gold
	Color3.fromRGB(40, 70, 150), -- 4 navy
	Color3.fromRGB(200, 40, 44), -- 5 red
	Color3.fromRGB(255, 130, 40), -- 6 orange
	Color3.fromRGB(70, 190, 80), -- 7 green
	Color3.fromRGB(70, 170, 240), -- 8 sky
	Color3.fromRGB(150, 70, 210), -- 9 purple
	Color3.fromRGB(255, 130, 190), -- a pink
	Color3.fromRGB(130, 84, 50), -- b brown
	Color3.fromRGB(140, 140, 150), -- c grey
	Color3.fromRGB(250, 230, 120), -- d pale yellow
	Color3.fromRGB(20, 110, 100), -- e teal
	Color3.fromRGB(110, 20, 30), -- f wine
}

local function art(rows)
	assert(#rows == A.Size)
	for _, r in ipairs(rows) do
		assert(#r == A.Size, r)
	end
	return table.concat(rows)
end

A.Pirate = art({
	"0000000000000000",
	"0000011111100000",
	"0000122222210000",
	"0001222222221000",
	"0001211221121000",
	"0001211221121000",
	"0001222112221000",
	"0000122222210000",
	"0000121221210000",
	"0000111111110000",
	"0110000000000110",
	"1221100000011221",
	"0112211001122110",
	"0000112222110000",
	"0112211001122110",
	"1221100000011221",
})

A.Marine = art({
	"0000000330000000",
	"0000003333000000",
	"0000333333330000",
	"0000003333000000",
	"0000033003300000",
	"0000000000000000",
	"0000000440000000",
	"0000004004000000",
	"0000000440000000",
	"0000444444440000",
	"0000000440000000",
	"0000000440000000",
	"0400000440000040",
	"0440000440000440",
	"0044400440044400",
	"0000444444440000",
})

-- a valid 256-char art string, or nil
function A.Valid(s)
	return type(s) == "string" and #s == A.Size * A.Size and s:match("^[0-9a-f]+$") ~= nil
end

-- pixel color at (x, y) 0-based, or nil when see-through
function A.At(s, x, y)
	local ch = s:sub(y * A.Size + x + 1, y * A.Size + x + 1)
	local n = tonumber(ch, 16)
	return n and n > 0 and A.Palette[n] or nil
end

return A
