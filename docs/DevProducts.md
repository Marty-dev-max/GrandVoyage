# Developer Products to create (for the owner / ChatGPT)

Create every row below in **Creator Hub → your experience → Monetization → Developer Products → Create a Developer
Product**: use the exact Name, Description and Price. Then copy each new **Product ID** into the file and line given in
the last column (replace the `0`). Push the change (or send the IDs to Claude) and the Robux buttons go live.
Prices are suggestions: change them freely, but keep the `robux = ...` number in the config file the same as the price
you set (the game shows that number on the button).

**Status (v0.24.10):** the 3 Gem packs, 4 spin packs, 3 benefits and 6 boosts exist and their IDs are in the config.
"Unlock Slot 3" = 3733442306 (v0.24.11): every product is in place. "Reset Stats" (3733424822) is sold again since v0.25.6: if it was
archived or disabled in Creator Hub, turn it back on.

**Managed pricing:** with "Managed pricing: Enabled", Roblox may charge some players a different price than the one set
(price optimization / regional prices; the owner paid 25 R$ in Thailand). The game reads each product's price from
Roblox for its buttons (`src/client/UI/Prices.lua`), falling back to the `robux` number in the config. Turn Managed
pricing off on a product if it must always cost exactly the listed price.

## Race spins (character creator, "+" button) — `src/shared/Config/Spins.lua`

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| 1 Race Spin | One spin to roll your character's race. Usable on any character slot. | 29 | `{ productId = 0, spins = 1, ...` |
| 3 Race Spins | Three spins to roll your character's race. Usable on any character slot. | 85 | `{ productId = 0, spins = 3, ...` |
| 5 Race Spins | Five spins to roll your character's race. Usable on any character slot. | 140 | `{ productId = 0, spins = 5, ...` |
| 15 Race Spins | Fifteen spins to roll your character's race. Usable on any character slot. | 429 | `{ productId = 0, spins = 15, ...` |

## Character slot 3 unlock — `src/shared/Config/Spins.lua` (`SlotUnlock`)

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| Unlock Slot 3 | Unlock a third character slot on your account, forever. | 99 | `SlotUnlock = { productId = 0, ...` |

## Store: Benefits — `src/shared/Config/Store.lua` (list `Benefits`)

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| Fruit Remover | Remove your Cursed Fruit so you can eat a new one. | 99 | `id = "FruitRemover"` line, `productId = 0` |
| Boss Respawn | Every defeated MVP boss on your server comes back right away. | 149 | `id = "BossRespawn"` line |
| Fruit Notifier (1 hour) | For 1 hour, see which island a Cursed Fruit appears on. | 99 | `id = "FruitNotifier"` line |

## Store: Boosts — `src/shared/Config/Store.lua` (list `Boosts`)

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| 2x EXP (15 min) | Double EXP for 15 minutes. Stacks with more time. | 29 | `id = "Exp2x15"` line |
| 2x EXP (30 min) | Double EXP for 30 minutes. Stacks with more time. | 49 | `id = "Exp2x30"` line |
| 2x EXP (1 hour) | Double EXP for 1 hour. Stacks with more time. | 89 | `id = "Exp2x60"` line |
| 2x Drop (30 min) | Double drop rates for 30 minutes. Stacks with more time. | 49 | `id = "Drop2x30"` line |
| 2x Drop (1 hour) | Double drop rates for 1 hour. Stacks with more time. | 89 | `id = "Drop2x60"` line |
| 2x Drop (2 hours) | Double drop rates for 2 hours. Stacks with more time. | 149 | `id = "Drop2x120"` line |

Every Store product can also be bought as a **gift** for another player in the same server: the game asks "FOR ME" or
a player's name before the Robux prompt, so no separate gift products are needed.

## Checklist for whoever does it

1. Experience must be published (the products belong to its universe).
2. Create the 14 products above (4 spins + 1 slot unlock + 3 benefits + 6 boosts).
3. Paste each ID into the matching `productId = 0` in `Spins.lua` / `Store.lua`.
4. Game Settings → Security → keep "Allow HTTP Requests" as is; nothing else is needed (receipts are handled in
   `PearlService.processReceipt` → `StoreService.Receipt` / spin bank).
5. Test in a live server with a test purchase: the item should arrive once, never twice.
