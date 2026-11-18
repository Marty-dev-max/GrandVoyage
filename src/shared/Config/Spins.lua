-- Heritage spin packs (v0.24.0, owner): sold for Robux as Developer Products from the character creator ("+" next to
-- your heritage -> BUY SPINS). Bought spins go to the ACCOUNT (DataService spin bank), so every character slot can
-- use them, even from the title menu before a slot is loaded.
-- To sell them: create 4 Developer Products in Creator Hub (Monetization -> Developer Products) at these prices and
-- paste each product id below. A pack with productId = 0 shows "coming soon" instead of the purchase prompt.
return {
	Products = {
		{ productId = 0, spins = 1, robux = 49, name = "1 SPIN" },
		{ productId = 0, spins = 3, robux = 129, name = "3 SPINS" },
		{ productId = 0, spins = 5, robux = 199, name = "5 SPINS" },
		{ productId = 0, spins = 15, robux = 499, name = "15 SPINS" },
	},
}
