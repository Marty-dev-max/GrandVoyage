-- Store (v0.24.0, owner): BENEFITS + BOOSTS, each bought with Gems or Robux, for yourself or as a GIFT to a player in
-- the same server. Robux = Developer Products: create one per entry in Creator Hub (Monetization -> Developer
-- Products) at `robux` and paste its id into `productId` (0 = "coming soon" for the Robux button; Gems still work).
-- Effects (StoreService): FruitRemover removes the Cursed Fruit (kept as a token if you have none), ResetStats refunds every stat point (removed v0.24.8, back in v0.25.6 at the owner's request)
-- every stat point, BossRespawn brings every defeated MVP boss on the server back now, FruitNotifier shows WHICH
-- island a fruit appeared on (everyone else only hears that one appeared). Boosts stack their time.
return {
	Benefits = {
		{ id = "FruitRemover", name = "Fruit Remover", icon = "st_fruit_remover", gems = 300, robux = 99, productId = 3733424813, desc = "Spit out your Cursed Fruit to eat a new one." },
		{ id = "ResetStats", name = "Reset Stats", icon = "st_reset_stats", gems = 200, robux = 79, productId = 3733424822, desc = "Get back every stat point you spent and plan your build again." },
		{ id = "BossRespawn", name = "Boss Respawn", icon = "st_boss_respawn", gems = 400, robux = 149, productId = 3733424831, desc = "Every defeated MVP boss on this server comes back now." },
		-- v0.25.72 (owner): pick your own Toki color (forever, this character; you must have that Toki). Panels.TokiColor
		{ id = "TokiColorConqueror", name = "Conqueror Toki Color", icon = "toki_conq", gems = 320, robux = 129, productId = 3734898364, tokiColor = "Conqueror", desc = "Pick any color for your Conqueror Toki, forever (needs the Conqueror Toki)." },
		{ id = "TokiColorArmament", name = "Armament Toki Color", icon = "toki_arm", gems = 200, robux = 79, productId = 3734897888, tokiColor = "Armament", desc = "Pick any color for your Armament Toki, forever (needs the Armament Toki)." },
		{ id = "TokiColorObservation", name = "Observation Toki Color", icon = "toki_obs", gems = 200, robux = 79, productId = 3734898118, tokiColor = "Observation", desc = "Pick any color for your Observation Toki, forever (needs the Observation Toki)." },
		{ id = "FruitNotifier", name = "Fruit Notifier 1h", icon = "st_notifier", gems = 250, robux = 99, productId = 3733424839, minutes = 60, boost = "fruit", desc = "1 hour: see which island a fruit appears on." },
	},
	Boosts = {
		{ id = "Exp2x15", name = "2x EXP 15 min", icon = "st_exp", gems = 80, robux = 29, productId = 3733424871, minutes = 15, boost = "exp", desc = "Double EXP for 15 minutes." },
		{ id = "Exp2x30", name = "2x EXP 30 min", icon = "st_exp", gems = 150, robux = 49, productId = 3733424880, minutes = 30, boost = "exp", desc = "Double EXP for 30 minutes." },
		{ id = "Exp2x60", name = "2x EXP 1 hour", icon = "st_exp", gems = 280, robux = 89, productId = 3733424891, minutes = 60, boost = "exp", desc = "Double EXP for 1 hour." },
		{ id = "Drop2x30", name = "2x Drop 30 min", icon = "st_drop", gems = 150, robux = 49, productId = 3733424897, minutes = 30, boost = "drop", desc = "Double drop rates for 30 minutes." },
		{ id = "Drop2x60", name = "2x Drop 1 hour", icon = "st_drop", gems = 280, robux = 89, productId = 3733424906, minutes = 60, boost = "drop", desc = "Double drop rates for 1 hour." },
		{ id = "Drop2x120", name = "2x Drop 2 hours", icon = "st_drop", gems = 500, robux = 149, productId = 3733424915, minutes = 120, boost = "drop", desc = "Double drop rates for 2 hours." },
	},
}
