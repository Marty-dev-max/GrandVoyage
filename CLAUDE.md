# Grand Voyage: project notes for Claude

Roblox MMORPG (Ragnarok-style systems in an original pirate-sea world). Luau + Rojo, server-authoritative.
Player-facing text and code are English. The owner (Roblox user Treezaa2, id 1527424396) talks in Thai: reply in Thai.
Design numbers live in `docs/GDD.md`; setup and feature map in `README.md`.

## Working with Roblox Studio (local sessions)

1. `rokit install` (rojo, lune, selene from `rokit.toml`).
2. Open `build/GrandVoyage.rbxl` in Studio, install the Rojo plugin, run `rojo serve` here, click Connect in the plugin.
   Code edits in `src/` then sync into Studio live. The baked map (`workspace.World`) is NOT synced by Rojo:
   after changing `src/server/World/*`, rebuild with `tools/build.sh` and reopen the place (or rebuild the world in Studio).
3. Studio's built-in MCP server (Assistant settings -> MCP Servers -> quick connect Claude Code) lets you run Luau in Studio,
   start/stop playtests and read the Output. Use it to verify changes: start a playtest, read console errors, stop.
   Check the actual tool names in your tool list; Roblox has renamed them between versions.

## Commands

| What | Command |
|---|---|
| Build place (Rojo -> data tests -> bake map) | `tools/build.sh` |
| Data/config tests | `lune run tools/test.luau build/GrandVoyage.rbxlx` |
| Headless UI test (HUD + 16 windows, fails on runtime errors) | `lune run tools/ui_harness.luau build/GrandVoyage.rbxlx build/ui` (add `phone` as 3rd arg for phone layout) |
| Render UI snapshots to PNG | `node tools/ui_render.js build/ui docs/screenshots/daybreak.png` (needs Playwright) |
| Lint | `selene src` (custom std in `rbx.yml`) |
| Upload sounds | `ROBLOX_API_KEY=... python3 tools/upload_sfx.py --user 1527424396` (already done: ids are in `Config/Sounds.lua`) |
| Icon pack (3D-rendered, Blender) | `python tools/blender/render_icons.py -- --out assets/icons` (bpy module or `blender -b -P`), then `ROBLOX_API_KEY=... python3 tools/upload_images.py assets/icons src/shared/Config/Icons.lua` |
| VFX textures | `python3 tools/gen_vfx.py`, then `python3 tools/upload_images.py assets/vfx src/shared/Config/Textures.lua` |
| Blender models (old map/monster/ship pack) | `blender -b -P tools/blender/generate_assets.py -- --out assets/models --preview` |
| In-game 3D models v2 (pets x3 stages, fruits) | `python tools/blender/build_models.py -- --out assets/models3d --preview [--only Gull_2]`, then `ROBLOX_API_KEY=... python3 tools/upload_models.py assets/models3d src/shared/Config/Models.lua` |

## Rules learned the hard way

- Never add custom fields or methods to Roblox Instances (`function btn:Foo()` errors and silently broke the whole HUD once).
  Use module functions such as `UI.SetButtonColor(btn, color)`.
- `InputObject.Position` excludes the top-bar inset: use `Camera:ScreenPointToRay`, or add `GuiService:GetGuiInset()` before
  `ViewportPointToRay`.
- The top-left HUD must stay under `GuiService.TopbarInset` (Roblox's own buttons live there). `HUD.Layout()` handles it.
- IP safety: everything is original naming (islands, monsters, items, NPCs). Never use One Piece names, characters or logos.
- All game logic and rewards are computed on the server. Client requests go through `Net.Handle(action, fn, minInterval)`
  (one RemoteFunction `Request`, a `Push` RemoteEvent, unreliable `FX`). Validate every payload.
- Quests: report progress with `R.QuestService.Event(player, kind, target)`; successful requests listed in
  `QuestService.ACTION_EVENTS` are picked up automatically via `Net.AfterHandle`.
- Icons: pass an emoji or an icon name to `UI.Icon` / `UI.IconChip`; emoji with a rendered icon (see `EMOJI_ICON` in UIKit)
  show the image automatically. Items use `UI.ItemIconId(def)`. New icon = builder in `render_icons.py` + render + upload.
- 3D models: build with `tools/blender/gvkit.py` (one mesh, one 16x16 palette texture, inverted-hull outline baked in,
  faces Blender -Y). `AssetService` loads `Config/Models` ids with InsertService into `ReplicatedStorage.Assets.Pets/<Species>_<n>`
  and `Assets.Fruits/<Id>` (normalized size + pivot); `UI.ModelView` shows them spinning in ViewportFrames. Dev tab -> Model Gallery.
- VFX are ParticleEmitter/Beam based with our own textures (`Config/Textures`); see the toolkit at the top of `Controllers/VFX.lua`.
- UI is built only from `src/client/UI/UIKit.lua` helpers (Window, Section, TabBar, IconChip, Button, Bar, Card, Toast, Notice...).
  Hover makes buttons "jump"; keep that for new buttons by using `UI.Button` / `UI.Tactile`.

## Decisions already made with the owner

- **Cursed Fruits (all 6 in the first sea)**, original names in the form "<Word> <Word> no Mi" (owner's choice), a separate power layer (not a class):
  Fruit Mastery levels from using fruit skills, 4 skills + 1 passive each, damage scales with max(ATK, MATK).
  Fruit users cannot swim. Marines get Seastone gear that disables fruit powers for 3 s in PvP. One fruit at a time;
  uneaten fruits are tradable in stalls.

  | Name | Idea | Rarity | Kit |
  |---|---|---|---|
  | Bounce Bounce no Mi | rubber | Secret | stretch punch, bounce gatling, reflect projectiles, gear-up buff; blunt resist |
  | Blaze Blaze no Mi | fire Logia | Mythic | fire fist, flame pillar, fire dash, burn; Logia phase chance |
  | Haze Haze no Mi | smoke Logia | Legendary | smoke grip pull/root, smoke screen (enemies miss), smoke ride over water |
  | Ward Ward no Mi | barrier | Epic | barrier wall (blocks cannonballs too), barrier bash, party dome |
  | Split Split no Mi | split body | Epic | flying fist, split spin, slash resist |
  | Slick Slick no Mi | slippery | Rare | slip-away FLEE buff, slick spin knockback, evade passive |

  Drops: NPC ship sink 1-star 0.1% / 2-star 0.3% / 3-star 1%, Captain's Chest 0.5%, MVP boss 2%, plus a fruit tree spawn on
  a random island every 45 min. Fruit weights: Slick 35, Split 25, Ward 20, Haze 12, Blaze 6, Bounce 2.
  Server-wide announcement for Legendary and above. All numbers go in a config file.
- **Brawler** (fists/knuckles, combos, stuns) replaces Cabin Boy as the starting class and is a full class up to Job 40.
  At Job 10 players may switch at the Job Master; progress is saved per class; first switch free, later ones cost Doubloons.
  **Brawler Chef is renamed Sea Cook** (kicks + food buffs).
- **Pets ("Sea Companions")**: original sea creatures with 3-stage evolutions (Lv15 / Lv35 + materials), obtained BOTH by capture
  (bait when the wild one is at low HP) AND by hatching eggs from chests. Examples: gull chick -> Courier Gull -> Storm Albatross,
  hermit crab -> Shellguard -> Fortress Crab, puffer -> Spikepuff -> Urchin Lord, lantern fry -> Lanternfin -> Abyss Lantern,
  Baby Leviathan -> Sea Serpent -> Leviathan Wyrm (Secret, Doldrums).
- **Pearls** (premium-ish currency) with anti-inflation and anti-exploit rules:
  earned only from bounded sources (first-time chests, dailies, achievements, bosses; never from mob farming or Auto Battle),
  daily earn cap, sinks (5% market tax + listing fee, fruit storage, cosmetics, class switch, refine protection).
  Robux-bought Pearls are spendable in shops but NOT tradable. Trading needs Lv30 + Roblox account age >= 14 days,
  new items are trade-locked 24 h, per-item min/max price bands, no direct Pearl gifting (escrowed stalls only),
  a separate ledger DataStore for every Pearl change, auto-freeze on abnormal earn rates, idempotent `ProcessReceipt`.
  Real Game Passes are Robux-only; offer "Pearl versions" of the same perks instead.
- Monetization: both cosmetics and convenience. Friend playtest target: by the end of November 2026.

## Status

Done: Brawler + Sea Cook + per-class progress, all 6 Cursed Fruits, Pearls (shop, Pearl stalls, ledger, Robux receipts),
Sea Companions (capture, eggs, evolution, follow/attack), quests + tutorial, chests, swimming,
daily quests + achievements + titles (`ProgressService`, fed by `QuestService.Event`),
3D-rendered icon pack, Blender models v2 for all pets (18) and fruits (6) loaded at runtime (`AssetService`).
Bump `GameConfig.Version` on every change: the owner checks it bottom-right in game to confirm Rojo synced.
The owner updates by double-clicking `update.bat` (git pull) on Windows, then Stop/Play in Studio.

## Next up

1. Playtest in Studio and fix what breaks (fruit Dash feel, pet follow, swim animation, quest flow).
2. (done) Robux developer products are live: ids in `Config/Pearls.lua` (`Products`). The game is published;
   Studio Access to API Services is on, so DataStores save in Studio playtests.
3. Fruit skill VFX polish, Seastone gear items for Marines.
4. Art pass: Blender models for pets/fruits/monsters (`ReplicatedStorage.Assets.Pets/<Species>_<stage>` overrides the
   placeholder bodies), icon set.
