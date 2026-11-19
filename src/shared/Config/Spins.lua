-- Heritage spin packs (v0.24.0, owner): sold for Robux as Developer Products from the character creator ("+" next to
-- your heritage -> BUY SPINS). Bought spins go to the ACCOUNT (DataService spin bank), so every character slot can
-- use them, even from the title menu before a slot is loaded.
-- To sell them: create 4 Developer Products in Creator Hub (Monetization -> Developer Products) at these prices and
-- paste each product id below. A pack with productId = 0 shows "coming soon" instead of the purchase prompt.
return {
	Products = {
		{ productId = 3733424684, spins = 1, robux = 29, name = "1 SPIN" },
		{ productId = 3733424776, spins = 3, robux = 85, name = "3 SPINS" },
		{ productId = 3733424787, spins = 5, robux = 140, name = "5 SPINS" },
		{ productId = 3733424798, spins = 15, robux = 429, name = "15 SPINS" },
	},
	-- v0.24.8 (owner): character slot 3 is locked until bought once (account-wide). Same Creator Hub steps as above.
	SlotUnlock = { productId = 3733442306, robux = 99, name = "Unlock Slot 3", slots = { 3 } },
}
