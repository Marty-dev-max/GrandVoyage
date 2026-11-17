# Game Design Document: Grand Voyage (Azure East Saga)

## 1. Pillars

- **Core loop:** farm monsters on an island (Auto Battle available) → EXP, materials, cards → refine and socket gear → upgrade your ship → sail to the next island (NPC fleets and PvP on the way) → bosses and dungeons → Guild War.
- **World:** islands in a straight line along X. The sea between them is an open sailing lane about 1,000 studs wide.
- **Look:** bright low-poly cartoon islands (Hunting Together readability) with an anime-RPG UI layer (Anime Vanguards polish): rarity colors everywhere, chunky outlined display font, tactile motion and sound on every interaction.
- **Readability first:** range rings, target rings, level-colored names, compass, edge arrows and a nav line make the game playable at a glance.

## 2. The Azure East

| # | Island | X | Levels | MVP boss | Highlights |
|---|---|---|---|---|---|
| 1 | Daybreak Island (Windmill Village) | 0 | 1–10 | Bay Serpent (sea arena) | jungle camp start, Forest Monkey 1 → Jungle Tiger 4 → Wild Boar 6 → Mountain Bandit 8, 3 windmills on hills, plaza + fountain, lighthouse, 3-dock harbor (layout: `docs/Daybreak.md`) |
| 2 | Conch Bay (Marine Outpost 135) | 1800 | 10–20 | Axe-Arm Captain | Walled marine compound, tower with a giant axe-captain statue, training yard |
| 3 | Marmalade Town | 3600 | 20–30 | Captain Confetti | Orange-roofed empty streets, Big Top Pub with a circus tent on the roof, giant dog statue, rubble, bunting; dungeon *Big Top Nightmare* |
| 4 | Honeyslope Village | 5400 | 30–40 | Silent Claw Captain | Hilltop manor on a plateau, the long slope, sheep pen, north cliffs, lookout tree |
| 5 | Barracuda Bistro | 7200 | 40–50 | Iron Armada Admiral (sea arena) | Fish-shaped floating restaurant: fish head, tail fins, side battle fins, masts, dining deck |
| 6 | Mikan Isles | 9000 | 50–60 | Sawtooth Overlord | Tangerine groves, pinwheel windmill, Sawtooth Park compound with pagoda and shark-mouth gate; dungeon *Sawtooth Depths* |
| 7 | Epilogue Town | 10800 | 60–70 | Mist Commodore | Big harbor city on cobbled streets, execution platform plaza, clock tower, Marine HQ, PvP arena, lighthouse, market street, Job Master |
| — | Crimson Wall / Backflow Peak | 12800 | Lv70 | — | Water flowing *up* the wall to the Grand Current (next update) |

Guild War forts: Fort Driftwood (x4500), Fort Tidebreak (x6300), Fort Gullwatch (x9900).

**Tiers (Anime Vanguards-style layer cake):** every island rises in steps. Reddish rock mesas with strata bands,
thick grass caps that drape over the cliff edge, an accent-colored rim, and stone stairs between levels. Landmarks
sit on the highest tier (the windmill hill, the walled marine outpost, the hilltop manor, Sawtooth Park, the harbor
lighthouse cliff), and a ring of rim cliffs turns each island into a bowl around its town. Monster fields stay flat.

Every island shares a layout grammar so players learn it once: plaza with fountain and NPC ring in the center, dirt paths
east and west to the two docks, shipyard platform south-east, monster fields in the four quadrants, and the landmark to the west.

### Sea zones (`Modules/SeaZones.lua`)

| Zone | |Z| from lane center | Wind | What the player sees |
|---|---|---|---|
| Lane | 0–520 | 100% | Clear turquoise water, many white wind streaks blowing east |
| Edge | 520–630 | 100% → 25% | Fewer streaks, yellow/red buoys, "The wind is fading..." banner |
| Doldrums | > 630 | 0% | Dark glassy water, thick haze, no streaks, a Leviathan every 4 s (max 5), escalating damage |

Sails do nothing in the Doldrums; only oar benches work (at 40%).

## 3. Classes (roles aboard a ship, not RO copies)

| Class | Role | Weapon | Passive | Signature skills |
|---|---|---|---|---|
| Cabin Boy | Starter | any Plain | — | First Aid, Deck Swab Strike |
| Swordsman | Melee DPS / tank | Sword | — | Demon Cross, Tornado Cut, Flying Slash, Iron Body |
| Sharpshooter | Ranged crits | Slingshot | Cannons +15% | Lead Pellet, Blaze Shot, Smoke Pellet, Eagle Eye |
| Brawler Chef | Kick melee + support | Battle Boots | — | Hook Kick, Banquet Spin, Searing Leg, Hearty Meal |
| Navigator | Weather magic + ship | Storm Baton | Ship speed +10% | Thunder Call, Cyclone Call, Mirage Veil, Tailwind |
| Doctor | Healer (medicinal powders) | Powder Pouch | — | Field Medicine, Adrenaline Shot, Burst Tonic |
| Shipwright | Utility / merchant | Hammer | Refine +5%, 12-slot stall, cannons +5% | Hammer Smash, Cannonball Drop, Field Repair |

Class change at Job Lv.10. Second jobs are planned in `Classes.SecondJobs`.

## 4. Stats (`Modules/Formulas.lua`)

- Stat points per level = floor(Lv/5)+3; raising a stat costs floor((value−1)/10)+2.
- Max HP = (100 + Lv×20 + VIT×14 + Lv×VIT×0.6) × class modifier.
- ATK = STR×2.2 + DEX×0.4 + LUK×0.3 + Lv + weapon ATK × grade × (1 + 6% × refine).
- Damage = ATK × skill multiplier × 100/(100+DEF); crits deal ×1.5 and ignore DEF.
- Hit chance = clamp(80 + HIT − FLEE, 5, 95)%.
- Attack interval = max(0.35, 1.5 × (1 − AGI×0.6% − DEX×0.15%)) seconds.
- EXP to next level = 30×Lv^2.1 + 60×Lv. Death costs 1% EXP.

## 5. Rarity, items, cards, refining

**Rarity tiers** (`Modules/Rarity.lua`): Common (grey), Uncommon (green), Rare (blue), Epic (purple), Legendary (gold), Mythic (red),
Secret (animated rainbow). Legendary and above get an animated shine; each tier has its own reveal sound with more notes as the tier rises.

**Weapon grades:** Plain ×1.0 (0 slots, Common) → Keen ×1.25 (1, Rare) → Masterwork ×1.55 (2, Epic) → Grandmaster ×1.9 (3, Legendary) → Supreme ×2.4 (4, Mythic, Grand Current).

**Refine odds:** +1 to +4 100% · +5 60% · +6 50% · +7 40% · +8 30% · +9 20% · +10 15% · +11 to +15 10% down to 5%.
Failing above +4 drops a level; from +10 there is a 35% shatter chance. The Willpower Charm prevents both.
Materials: Steel Ore (+1 to +5), Tidecore Shard (+6 to +10), Pure Tidecore (+11 to +15). +7 and higher are announced server-wide.

**Cards:** every monster has one (0.2%, bosses 1%, LUK helps a little). Regular cards are Rare/Epic, boss cards Legendary,
the tier-3 captain cards Mythic, and the Leviathan card is Secret. Drops trigger a rarity banner and sound.

## 6. Ships

- Slip of 9×6×21 cells (4 studs each); parts must touch; max 140 parts; deleting refunds in full.
- **Speed** = 78 × T / (T + weight × 0.085), with T = sail thrust × wind × bonus + (manned oar benches × oar power).
- **Turning** = 0.7 × 300/(300 + weight×0.25) rad/s.
- **Cannons:** each volley fires min(cannons, crew) guns that face the target (±75°). Reload 3.2 s. Cannonballs travel, so lead moving ships. Firing arcs are drawn on the water (green = ready).
- **Crew:** hired at taverns (cost rises every 4 crew); bunks come from Crew Cabins (+4 each, base 2).
- Sinking costs 15% of the ship's value to repair. Every 25% HP lost knocks parts off the ship.
- Faction parts: Jolly Roger Mast (Pirate), Marine Mast (Marine).

Starter ship: weight 694, one small mast → about 30 studs/s in the lane, 3.5 in the Doldrums.

## 7. NPC fleets

| Tier | Marine (shipbuilding materials) | Pirate (Doubloons and treasure) |
|---|---|---|
| ★ | Patrol Sloop: iron, gunpowder, badges | Dinghy: timber, sail cloth, food |
| ★★ | Frigate: + Tidecore Shards, Marine Greatcoat | Brigantine: + Treasure Maps |
| ★★★ | Battleship: + Pure Tidecore, Marine Captain card (Mythic) | Galleon: + Treasure-Tree Wood, Pirate Captain card (Mythic) |

They spawn only in sea segments near players, at most 3 per segment, and get stronger the farther east you go.
AI: acquire a target within 340, close in, turn broadside, lead shots, avoid the Doldrums and islands. Marine NPCs ignore Marine players.
Marine and Pirate NPC ships fight each other.

## 8. Factions, guilds and PvP

- The faction is chosen when founding a guild (Lv20, 50,000 Doubloons). Members inherit it; leaving makes you a Civilian.
- **Pirates** gain Bounty for beating Marines, sinking Marine ships and killing bosses.
- **Marines** gain Merit plus 5% of a pirate's bounty when they catch one.
- PvP is allowed in duels (non-lethal), the Epilogue arena, Marine vs Pirate ships at sea (Lv20+), and fort zones during Guild War. PvP damage is ×0.6.
- **Guild War** runs Saturdays for 45 minutes on 3 forts. Breaking a fort's Giant Signal Conch captures it; holders get 100,000 Doubloons and materials.

## 9. Market

Stalls can be opened in town (plaza radius +40). You stand still while vending. 6 slots (Shipwright: 12), 2% tax,
items held in escrow and returned when the stall closes or you leave.

## 10. UX & presentation

- **HUD:** a split **level ring** around the portrait: the left half is Base EXP (green), the right half is Job EXP in the
  class color (`Classes.ringColor` overrides it when the class color is too close to green or too dark), with the Base
  level in a gold badge underneath. EXP from a kill **flies into the ring** as orbs (server push `ExpGain {base, job, pos}`):
  the orbs burst out of the monster, swoop along a curve into the tip of each half, and the ring pulses and fills as they land,
  with a "+123 EXP" / "+45 JOB" float. Next to the ring: name, class, HP bar (recolors, ghost trail), SP bar, EXP%/JOB%.
  Doubloons and Bounty/Merit pills, a pulsing points button, a two-column **icon menu** (colored tiles with a big icon,
  label and key badge), an 8-slot skill bar with cooldown countdowns and SP warnings, AUTO button, level-colored target frame,
  rarity loot feed (bottom left).
- **Look (from the reference clips):** near-black panels with a slanted purple header tab and a red square close button, Fredoka One display text with thick outlines, a Settings window with a category sidebar and pill toggles, green "notice" bars for gameplay beats (waves, Auto Battle on/off, Guild War).
- **Combat feedback (Hunting Together):** white dashed range ring under the player, red starburst behind crit numbers, a right-side "x123 COMBO" counter with a decay bar.
- **Clean screen (v0.9.1):** one compact currency row (Doubloons / Bounty / Pearls), 6 main menu tiles (Bag, Skills, Quests,
  Map, Pets, Pearls) + a MENU hub (key L) for Stats, Ships, Guild, Party, Bosses, Settings; collapsible quest tracker;
  skill slots show icons and hide empty slots past the 4th; banners queue one at a time; notices sit under the target frame;
  loot feed keeps 4 lines for 3 s; slim see-through compass; min text size 13 on phones.
- **Windows:** every window has a slanted color tab with a tilted icon chip, speed stripes and a faded icon watermark;
  every block inside starts with a **section header** (icon chip + title + accent rule + info on the right, `UI.Section`),
  and tabs are icon pills sized to their label (`UI.TabBar`). Empty detail panes show a "Select an item" placeholder.
- **Motion:** hovering any button makes it **jump** (hops up off its shadow, bounces, stays slightly raised; items placed by
  a layout hop with scale instead), pressing squashes it down, and every interaction plays a sound. Windows slide up with a
  blurred, dimmed backdrop. Banners punch in and toasts slide in from the right.
- **Readability:** range ring (hover a skill to preview its range), red target ring, "!" over enemies targeting you, nameplates colored by level difference (grey/green/yellow/orange/red with ☠ for deadly), compass strip, screen-edge arrows (next island, live bosses, nearby ships), dotted nav line plus distance while sailing.
- **Graphics presets:** Low hides all Decor, shadows and post effects and thins wind/VFX (phones). Medium hides small decor. High is the PC default. Ultra adds depth of field and denser wind.
- **Audio:** UI / SFX / Music / Ambience groups with sliders. Music and ambience switch between island and sea.

## 11. Quests, exploration and swimming

- **Main story** (`Config/Quests.lua`, `QuestService`): one chain of 40 steps. Steps 1-12 are the Daybreak tutorial
  (click to attack, skills, Auto Battle, stats, equipment, Job Lv.10, class change, launching the ship, sailing to Conch Bay),
  then 4-7 steps per island. Each island has a quest guide NPC (tricorn hat, "📜 Quests"). Goals: Talk, Kill, Skill, Auto,
  Stat, Equip, Refine, Buy, Hire, Launch, Sink, Dungeon, Chest, Reach, JobLevel, Level, Class. The tracker under the player card
  shows the goal, progress, a hint and the distance; the objective gets a compass mark, an edge arrow and a green light beam.
  The tutorial can be skipped. Services report progress through `QuestService.Event`, and successful client requests are
  picked up automatically through `Net.AfterHandle`.
- **Exploration chests** (`Config/Chests.lua`, `ChestService`): about 6 per island. The Captain's Chest (Legendary) sits on the
  highest mesa, Golden/Silver on the next tiers, Wooden ones on the shore and a Silver one somewhere in the open. Each player
  opens each chest once (saved), rewards scale with the island level, and finding every chest on an island pays a bonus.
  The Map shows 🧰 found/total per island.
- **Swimming**: jump in and you float and swim (speed 12) with a 45-second breath bar; Space jumps you out onto a dock. When your
  breath runs out the waves wash you ashore. The server tracks swim time on its own, so ships stay the way to cross the sea.
- **Targeting**: clicks use the correct screen ray (the old ray ignored the top-bar inset and aimed too high) and fall back to the
  nearest monster on screen within 70 px. Targets that are too far (search radius + 30) or that you cannot get closer to for
  3.5 s are dropped. Auto Battle prefers monsters that are attacking you. Two rings: white = attack range, blue = search radius
  (green while Auto Battle is on).

## 12. Brawler, Cursed Fruits, Pearls, Sea Companions

- **Brawler** (`Classes.Brawler`, Knuckles) is the starting class and a full class to Job 40. From Job 10 you can switch at a
  Job Master. Progress is saved per class (`classProgress`); the first switch is free, later ones cost Base Lv x 400
  Doubloons (or a Class Switch Voucher). Skills of other classes stay learned but only the current class + Sailor Basics
  (First Aid, Deck Swab Strike) can be used. Brawler Chef is now the **Sea Cook**. Old "Novice" saves become Brawlers.
- **Cursed Fruits** (`Config/Fruits.lua`, `FruitService`): Bounce Bounce no Mi (Secret), Blaze Blaze no Mi (Mythic, Logia),
  Haze Haze no Mi (Legendary, Logia), Ward Ward no Mi (Epic), Split Split no Mi (Epic), Slick Slick no Mi (Rare).
  Uneaten fruits are tradable items. Eating one gives a passive and 4 skills unlocked at Fruit Mastery 1/10/25/50; mastery
  grows by using fruit skills (and kills right after). Damage uses the better of ATK/MATK and +1% per mastery level.
  New skill mechanics: multi-hit (`hits`) and Dash. Sources: NPC ship sinks 0.1/0.3/1% by tier, Captain's Chest 0.5%, MVP 2%,
  and a glowing fruit that appears on a random island every 45 min (server announcement). Fruit users sink in the sea.
  Marine PvP hits have a 20% chance to apply Seastone (fruit skills sealed 3 s).
- **Pearls** 🦪 (`Config/Pearls.lua`, `PearlService`): earned only from first-time chests, exploring whole islands, story
  quests and MVP bosses, capped at 300/day. Spent in the Pearl Shop (Willpower Charm, Captain's Log EXP boost, Class Switch
  Voucher, Sea Egg, Bigger Stall). Stalls can sell for Pearls: seller and buyer need Lv30 + a 14-day-old Roblox account,
  items obtained in the last 24 h cannot be listed, prices must stay within 0.25x-4x of the reference price, 5% tax and a
  1% listing fee are burned. Every change goes to a ledger DataStore; abnormal hourly income freezes Pearl trading.
  Robux Pearls (developer products, ids in config) are shop-only and granted through an idempotent `ProcessReceipt`.
- **Sea Companions** (`Config/Pets.lua`, `PetService`, client `Controllers/Pets`): Hermit, Boarlet, Gull, Puffer, Lantern,
  Leviathan, 3 stages each (evolve at Lv15/35 with Doubloons + a material). Get them by hatching Sea/Golden Eggs (chests,
  Pearl Shop; odds shown in game) or by taming: Sea Bait on a Wild Boar or Leviathan below 35% HP (🪤 Capture
  button). The active pet follows you, attacks what you hit, earns 50% of your Base EXP and gives a stage-scaled bonus.

## 13. Daily quests, achievements and titles

- **Dailies** (`Config/Dailies.lua`, `ProgressService`): 3 per day (reset 00:00 UTC), picked by level from a pool
  (hunt a monster near your level, hunt anything, use skills, sink ships, refine, use fruit skills, clear a dungeon).
  Each pays Doubloons (300 x Lv^0.85), 10% of a level's EXP and 10 Pearls; claiming all 3 adds a bonus (25 Pearls + 3 Sea Bait).
- **Achievements** (`Config/Achievements.lua`): 23 one-time goals (hunting, MVPs, ship sinks, exploring, chests, fruit
  mastery, pets, refining, story, levels, 7 daily streak days, 1M Doubloons). They pay Pearls outside the daily cap (they
  are bounded) and some unlock a **title** shown above your head («Tiger Tamer», «Legend of the Azure East», ...).
- Every progress event goes through `QuestService.Event`, which forwards to `ProgressService` (one funnel).
- UI: the **Quests** window (📜, key J) with Story / Daily / Achievements tabs and Claim buttons.

## 14. Roadmap

1. **Now (v0.4):** full systems, tiered low-poly islands, AV-style UI with split EXP/Job level ring, flying EXP orbs, hover-jump motion and icon-sectioned windows, audio pack + uploader, settings, readability, Blender asset generator, headless UI test + renderer.
2. **Art pass:** Blender models (monsters, ship parts, landmarks), particle VFX, Figma icon set, real music.
3. **Polish:** tutorial quest chain, dailies, login rewards, bounty leaderboard, cross-server market (MemoryStore).
4. **Grand Current update:** new place via TeleportService, second jobs, Cursed Fruits, compass navigation, weather.
5. **Live ops:** cross-server Guild War (reserved servers), season pass, analytics.
