# Developer Products to create (for the owner / ChatGPT)

Create every row below in **Creator Hub → your experience → Monetization → Developer Products → Create a Developer
Product**: use the exact Name, Description and Price. Then copy each new **Product ID** into the file and line given in
the last column (replace the `0`). Push the change (or send the IDs to Claude) and the Robux buttons go live.
Prices are suggestions: change them freely, but keep the `robux = ...` number in the config file the same as the price
you set (the game shows that number on the button).

The 3 Gem packs already exist (IDs are set in `src/shared/Config/Pearls.lua`), nothing to do for them.

## Heritage spins (character creator, "+" button) — `src/shared/Config/Spins.lua`

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| 1 Heritage Spin | One spin to roll your character's heritage. Usable on any character slot. | 49 | `{ productId = 0, spins = 1, ...` |
| 3 Heritage Spins | Three spins to roll your character's heritage. Usable on any character slot. | 129 | `{ productId = 0, spins = 3, ...` |
| 5 Heritage Spins | Five spins to roll your character's heritage. Usable on any character slot. | 199 | `{ productId = 0, spins = 5, ...` |
| 15 Heritage Spins | Fifteen spins to roll your character's heritage. Usable on any character slot. | 499 | `{ productId = 0, spins = 15, ...` |

## Store: Benefits — `src/shared/Config/Store.lua` (list `Benefits`)

| Name | Description | Price (R$) | Paste ID into |
|---|---|---|---|
| Fruit Remover | Remove your Cursed Fruit so you can eat a new one. | 99 | `id = "FruitRemover"` line, `productId = 0` |
| Reset Stats | Refund every stat point you have spent. | 79 | `id = "ResetStats"` line |
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
2. Create the 14 products above (4 spins + 4 benefits + 6 boosts).
3. Paste each ID into the matching `productId = 0` in `Spins.lua` / `Store.lua`.
4. Game Settings → Security → keep "Allow HTTP Requests" as is; nothing else is needed (receipts are handled in
   `PearlService.processReceipt` → `StoreService.Receipt` / spin bank).
5. Test in a live server with a test purchase: the item should arrive once, never twice.
