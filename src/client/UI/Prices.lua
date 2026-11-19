-- Prices (client, v0.24.10): the Robux price a button shows comes from Roblox, not only from our config.
-- Creator Hub "Managed pricing" (price optimization / regional prices) can make Roblox charge a player a different
-- price than the one we set (the owner was charged 25 R$ in Thailand), so labels ask MarketplaceService for the
-- product's price and fall back to the config `robux` number until (or if) that fails.
--   Prices.Apply(productId, fallback, function(robux) label.Text = "R$ " .. robux end)
local MarketplaceService = game:GetService("MarketplaceService")

local Prices = {}
local cache = {} -- productId -> robux
local waiting = {} -- productId -> { apply... }

local function fetch(productId)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
	end)
	if not ok or type(info) ~= "table" then
		ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
	end
	local price = ok and type(info) == "table" and tonumber(info.PriceInRobux) or nil
	return price
end

function Prices.Apply(productId, fallback, apply)
	pcall(apply, cache[productId] or fallback)
	if not productId or productId == 0 or cache[productId] then
		return
	end
	local list = waiting[productId]
	if list then
		table.insert(list, apply)
		return
	end
	waiting[productId] = { apply }
	task.spawn(function()
		local price = fetch(productId)
		local fns = waiting[productId]
		waiting[productId] = nil
		if price then
			cache[productId] = price
			for _, fn in ipairs(fns) do
				pcall(fn, price) -- the label may be gone by now
			end
		end
	end)
end

return Prices
