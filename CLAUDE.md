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
| Detailed creatures v3 (skin-modifier body + fur tufts + baked texture) | `python tools/blender/creatures.py -- --out assets/models3d --preview` (or open it in Blender's Scripting tab and Run Script to build it in the open scene), then upload_models.py as below |
| Map materials (stylized PBR MaterialVariants) + water layers | `python3 tools/gen_materials.py`, upload `assets/materials` -> `Config/MaterialMaps.lua` and `assets/water` -> `Config/WaterTextures.lua` with upload_images.py, then `python3 tools/gen_materials.py --project` (writes MaterialService into default.project.json) |
| Stylized environment kit (trees, pines, palms, bushes, boulders, cliff modules) | `python tools/blender/envkit.py -- --out assets/models3d --preview`, then upload_models.py |
| Voxel creatures (SDF shapes on a grid, per-voxel colors, greedy mesh) | `python tools/blender/voxel.py -- --out assets/models3d --preview` |
| Voxel monsters (all 32 + bosses, outfits/hats/weapons by spec) | `python tools/blender/voxel_monsters.py -- --out assets/models3d --preview [--only GuardWolf]`, then upload_models.py |
| Voxel pets (6 species x 3 stages) + fruits (6) | `python tools/blender/voxel_pets.py -- --out assets/models3d --preview`, then upload_models.py (same names as v2, they replace them) |
| Animations (players per weapon/class + monsters) | edit `src/shared/Config/AnimClips.lua`, `lune run tools/build_anims.luau`, then `ROBLOX_API_KEY=... python3 tools/upload_models.py assets/anims src/shared/Config/Animations.lua --type Animation` |
| Voxel class weapons (Wep_Sword, Wep_Knuckles, ...) | `python tools/blender/voxel_weapons.py -- --out assets/models3d --preview`, then upload_models.py (grip/size in `AssetService.WEAPONS`) |
| In-game 3D models v2 (pets x3 stages, fruits; superseded by voxel_pets.py) | `python tools/blender/build_models.py -- --out assets/models3d --preview [--only Gull_2]`, then `ROBLOX_API_KEY=... python3 tools/upload_models.py assets/models3d src/shared/Config/Models.lua` |

## Rules learned the hard way

- Never add custom fields or methods to Roblox Instances (`function btn:Foo()` errors and silently broke the whole HUD once).
  Use module functions such as `UI.SetButtonColor(btn, color)`.
- `InputObject.Position` excludes the top-bar inset: use `Camera:ScreenPointToRay`, or add `GuiService:GetGuiInset()` before
  `ViewportPointToRay`.
- The top-left HUD must stay under `GuiService.TopbarInset` (Roblox's own buttons live there). `HUD.Layout()` handles it.
- IP safety: everything is original naming (islands, monsters, items, NPCs). Never use One Piece names, characters or logos.
- All game logic and rewards are computed on the server. Client requests go through `Net.Handle(action, fn, minInterval)`
  (one RemoteFunction `Request`, a `Push` RemoteEvent, unreliable `FX`). Validate every payload.
- Combat ranges are measured to the target's BODY with `Shared.Modules.Reach.Gap(pos, model)` (bounding box), never to
  its root: huge voxel bosses have their HumanoidRootPart 20 studs up and were unreachable.
- Quests: report progress with `R.QuestService.Event(player, kind, target)`; successful requests listed in
  `QuestService.ACTION_EVENTS` are picked up automatically via `Net.AfterHandle`.
- Icons: pass an emoji or an icon name to `UI.Icon` / `UI.IconChip`; emoji with a rendered icon (see `EMOJI_ICON` in UIKit)
  show the image automatically. Items use `UI.ItemIconId(def)`. New icon = builder in `render_icons.py` + render + upload.
- 3D models: build with `tools/blender/gvkit.py` (one mesh, one 16x16 palette texture, inverted-hull outline baked in,
  faces Blender -Y). `AssetService` loads `Config/Models` ids with InsertService into `ReplicatedStorage.Assets.Pets/<Species>_<n>`
  `Assets.Fruits/<Id>` and `Assets.Monsters/<Id>` (from `Mon_<Id>`, wrapped in HumanoidRootPart + Humanoid) (normalized size + pivot);
  the owner does NOT want thick black outlines on models (outline=0); `UI.ModelView` shows them spinning in ViewportFrames. Dev tab -> Model Gallery.
- Map look: MaterialService base-material overrides (GV_Grass, GV_Rock, ...) texture every Part of that Material (Part.Color still
  tints them), so world code just picks semantic materials (Grass/Rock/Slate/Sand/Wood/WoodPlanks/Cobblestone, not SmoothPlastic).
  Light/air: `Controllers/Atmos.lua` owns Lighting on the client (day/night cycle from server time, sun by day + moon by night,
  per-time-of-day recipes, night lamps, Clouds, soft wind wisps on Beams, drifting leaves on islands); Sailing calls
  `Atmos.Wind` / `Atmos.SetCalm`. Dev tab -> Time of Day buttons.
  The sea is animated on the client by `Controllers/Ocean.lua` (scrolling wave/foam/glitter Textures + shore foam rings).
- World props: `Kit` builds trees/bushes (Model tagged `EnvProp`, attrs Kind/Base/Height) and boulders/cliff slabs (Part tagged
  `EnvPart`, attr Kind) as placeholders; `AssetService.DressWorld` swaps them for `Assets.Env/<Kind>_<n>` meshes at server start.
  Ground: Grass parts keep the painted GV_Grass texture; `World/Greenery.lua` scatters a modest number of plants
  (GrassTuft/Flowers/Fern/LeafPlant/Mushroom/Bush) on Grass parts; `Controllers/GrassField.lua` sways only the plants near the
  camera (BulkMoveTo). A dense 3D grass carpet lagged (v0.10.1): owner wants few plants, AV-like soft look. Do NOT use Terrain for ground: its 4-stud voxels swallowed
  paths/houses and left ridges (tried in v0.10.0).
  Mesas (owner wants clear layers + stylized 3D rock): rock cylinder + grass cylinder (collision, hidden once dressed via
  MesaId) + a ring of angular rock cliff slabs (`Cliff<Tone>_n`, tone Brown/Gray from `Kit.RockTone`, Red on the Red Line)
  + a separate grass layer mesh on top that overhangs the rim (`GrassCap_n`). Overlapping lobes read as connected hills.
  The smooth `Mesa_n` ledge meshes were rejected (looked like plastic, layers blended). Bump `WorldBuilder.WORLD_VERSION` when world code changes:
  a baked World with an older version is destroyed and rebuilt at runtime (the owner's published place keeps a baked World).
  Hand-made map edits in Studio belong in `workspace.Handmade` (never touched by rebuilds); layout changes go in World/*.lua.
  Owner rule (v0.22.2): only the current map may exist. `WB.RemoveStaleMaps` deletes every generated piece outside the kept
  World at server start, Handmade included (island folders found by their IslandSpawn/IslandBanner, maps by WorldVersion,
  stray NPC/Chest/Dock/Plot-tagged props); plain hand-made parts are kept.
- Owner decisions on art: voxel style for pets, fruits and monsters; textured (SurfaceAppearance-like) stylized look for the map.
- Animation = real Roblox animations, never hand-posed joints. v0.13-v0.14 posed Motor6D.C0 / attachments from client
  scripts and NOTHING moved in the owner's Studio (twice), so do not go back to that. Clips are data in
  `Config/AnimClips.lua` (degrees per part, R15 part names for players, voxel part names for monsters), built to
  KeyframeSequence .rbxm by `tools/build_anims.luau` (shared `Modules/AnimBuild`), uploaded as Animation assets owned by
  the owner (`Config/Animations` ids), played through the Animator by `Shared/Modules/Anim` (which falls back to a
  runtime-built copy via KeyframeSequenceProvider if an id is missing or does not load). Preview poses before uploading
  (side/front renders of the strike frame) since nobody can watch them here.
  Players: `Controllers/CharAnim.lua` plays the LOCAL character only (it replicates): per-weapon stance loop while
  `WeaponOut`, combo of basic attacks, skill clip by kind, Hurt; hitstop = track:AdjustSpeed on the strike frame.
  Monsters: MonsterService plays Mon_Idle + Mon_Walk (weight follows speed) + Mon_Attack / Mon_Hit on the server.
  AssetService still rigs voxel monster parts to the root with Motor6Ds at their joints (names Body/Head/LegL...).
  `Controllers/CreatureAnim.lua` only does the hit flash and death shatter. VFX timing reads each clip's `strike`.
  Weapons: `WeaponService` keeps gear visible at all times: HOLSTERED when calm (cutlass in its scabbard at the left
  hip, hammer across the back, folded 3-piece storm staff + Doctor's powder pouch on the belt), DRAWN in the hands for
  8 s after an attack/skill (`WeaponDraw` FX: the staff snaps out), WORN always (Sea Cook shin guards, Sharpshooter
  satchel + strap). Offsets per type live in DRAWN / HOLSTERED / WORN tables; sets char attributes Weapon / WeaponOut. Unarmed players fight
  with their class's weapon type (CombatService.weaponType). Dev tab -> Animation Check; Studio shows an anim status line.
  Pets animate by part name in `Controllers/Pets.lua` (Hinge attribute). Avatars: uniform R15 via
  `PlayerService.normalizeAvatar` (GameConfig.NormalizeAvatars; Game Settings avatar type must be R15).
- Hits land on the strike frame: CombatService picks the combo step (sent as `combo` in the BasicAttack FX so every client
  plays the same clip) and applies damage with `hitLater(strike [+ shot flight])`; skills use their clip's strike too.
  Never apply melee damage at request time again (monsters died before the fist arrived).
- Hotbar: `p.skillBar` = 12 fixed slots (keys 1-6, 7 8 9 0 - =), `p.itemBar` = 8 quick items (F1-F8), "" = empty slot;
  server helpers `PS.BarAdd` / `PS.BarRemoveIf` keep slot positions; each class keeps its own bar (`p.classBars`).
  Set up in Skills -> Loadout (tap skill/item, then slot; tap two slots to swap; green tick = Auto Battle may use it;
  per-player Auto Battle search range `settings.autoRadius`, read with `State.SearchRadius()`).
- Big windows (Bag, Skills, Quests, Map, Pets, Shop) open full screen with a button next to the X to shrink them:
  `UI.Window(id, title, size, color, icon, { fullscreen = true })`, layouts must stretch (scale sizes) and can listen to
  `win.resized`. The Pearl shop is labelled "Shop" (owner). Coin/hit sounds were lowered in pitch (owner found them
  shrill); kill streaks raise the coin / death pitch.
- Full screen mode (owner's reference clip): the window covers the screen edge to edge with a slim title bar, X and
  the shrink button top-right; shrunk it is a framed window again (`UI.Window` opts.fullscreen, `win.resized`).
- Bag = character statue (`UI.CharacterView`: a still clone of your avatar holding the equipped weapon, drag to turn)
  with gear slots around it; double-click gear with card slots -> Blacksmith Insert Card. Stats = same layout, plan
  points with -/+ then Apply (`AllocateStats`, all-or-nothing). Blacksmith (Panels.Refine) = sidebar Forge / Insert Card,
  gear list, item on a stage; Forge plays the anvil animation (3 hammer strikes, `AnvilClang` sound) and reveals the
  server result after it.
- Ammo (`Config/Ammo`, slingshot weapons): `p.ammo` picked with the bullet button by the hotbar (`SetAmmo`), 1 item
  used per basic attack in CombatService (falls back to free Pebble Shot), effects via hitTarget opts (critBonus,
  ignoreDef, slow, splash). Ammo items are sold in handfuls at the General Store.
- Titles (`Config/Titles`, `TitleService`): ladders Voyage (level, per sea) / Pirate (bounty) / Marine (merit ranks) /
  Class (Job 40) / Fruit (mastery) / Feats (achievement titles, ids = achievement ids) / Special (granted). Tier = rarity
  color; `soon = true` = next-sea titles shown locked. Once met a title stays in `p.titles`; default Greenhorn; `p.title = ""`
  = none. Picked in the Bag (title button above the statue). `Controllers/Titles.lua` draws every player's nameplate
  (title + Lv + name in FredokaOne, Roblox's tag hidden) and prefixes chat with the title in its color (TextChatService).
- `Controllers/Interact.lua`: every ProximityPrompt uses our styled card (Style = Custom, tap/click works too) and NPC
  nameplates are restyled on the client (baked map untouched). Chests shake + rattle (`ChestShake` FX) 0.85 s before
  the server opens them.
- Weapon type/range: `Shared/Modules/WeaponInfo` for server and client alike. TypeOf = the EQUIPPED weapon, else "Fists"
  (plain jab-cross for every class until a weapon is equipped, owner's rule); ClassWeapon = the class style (worn gear).
- Q = Dash (client-side LinearVelocity burst, server checks `GameConfig.Dash.Cooldown`, `Dash` FX). Hotbar order:
  Dash, skills 1-6, F1-F4, expand, [ammo], AUTO. Stats is a main menu tile with a red points badge (no long button).
- Window buttons (X + full screen) sit in one holder frame that we move (UI.Tactile remembers button positions), windows
  are capped to the screen (`UI.FitSize`), and tall columns scroll. Loadout supports drag and drop.
- Sea Cook = taekwondo (ready stance; front -> side -> spinning back -> axe kick combo; flying side kick skill).
  Doctor (renamed from Ship Doctor) throws medicinal powders (Powder Pouch weapon line, dust-cloud VFX), not a med kit.
  Stats window has an Auto upgrade toggle (`settings.autoStats`, PlayerService.AutoStats by class build).
- Swing speed: CombatService sends `speed` (clip length fitted into the attack interval); the client plays the clip at
  that speed and the server divides the strike delay by it. Stances pose the upper body only and soften while moving.
- Hit juice: red Highlight flash on monsters, HP bars (UI.Bar and the overhead mob bars via CreatureAnim) drop fast and
  leave a red chunk that drains after a beat, with a punch on big hits. Style meter (UI.ComboHit(amount, crit)): ranks
  D C B A S SS SSS (Dull..Sensational), fills per hit, drains when idle, total damage, flames from S. Loot pushes carry
  `pos`: coins burst out and fly to the money counter, items fly into the Bag tile (HUD.FlyLoot).
- Damage FX `kind` colors numbers (fire, burn, poison, ice, shock, pierce, star, pet, cannon, fruit elements);
  CombatService.applyDot does burn/poison ticks (Ember ammo, Blaze skills, Doctor powders). Ship repair shows +numbers.
- VFX are ParticleEmitter/Beam based with our own textures (`Config/Textures`); see the toolkit at the top of `Controllers/VFX.lua`.
- v0.21 combat feel: Brawler = freestyle street fight (7-hit Knuckles combo jab/cross/body blow/hook/knee/elbow/spinning
  backfist; a skill can name its own clip with `anim` in Config/Classes, e.g. JabRush -> Brawler_Flurry). Hit sounds by
  attacker weapon (PunchHit/PunchHeavy/SliceHit/ShotHit/ZapHit/PowderPoof) in VFX fxSounds.Damage; impacts
  `VFX.ImpactSplit` (shockwave + split streaks) for fists/kicks/hammer/pellets, `VFX.SliceLine` for swords, `VFX.Charge`
  before finishers. Navigator = weather: `VFX.StormCloud` (warm + cold puffs condense), basic attack throws a lightning
  ball, ThunderCall / CycloneCall skill FX. Own crits: gradient "CRITICAL!" number on an impact star + `VFX.ImpactFrame()`.
  Overhead mob bars are dressed like HUD bars (stroke, gloss, white flash, shake) in CreatureAnim.juiceBar.
- Class switch auto-equips the best owned class weapon (PlayerService). Loadout drag uses UIDragDetector.
- Card ladder (owner, v0.22.2): Common gray 1 star, Uncommon green 2, Rare blue 3, Epic purple 4, Mythic rainbow prismatic 5
  (`Rarity.Stars`, Mythic tier has `prismatic = true`: pastel rainbow that spins, `UI.PrismaticSequence` / `UI.SpinGradient`).
  Regular cards by monster level (<10 Common, <30 Uncommon, else Rare), MVP boss cards Epic, captains + Leviathan Mythic.
- Dev tab "New Player" (`Admin` cmd `resetall`, `DataService.ResetProfile`): fresh save in place (keeps receipts, perks, guild).
- Card drops play `UI/CardReveal.lua` (tension + orbs, whip flip + hitstop, rune rings + golden lightning, foil sheen,
  monster pops out of the frame, stars, RGB split from Mythic; intensity and pitch scale with rarity, tap skips).
- Style meter = vertical tube middle-right (left of the menu column; `UI.PlaceStyleMeter` from HUD.Layout), liquid on a
  spring, letter rides the level. The UI harness pumps `task.wait` loops (`pump`) to play the card reveal through.
- Daybreak (v0.22) is hand-laid in `World/Daybreak.lua` (island `layout = "Daybreak"`), layout spec + previews in
  `docs/Daybreak.md`: jungle camp spawn (west) -> Monkey Grove Lv1 -> Tiger Den Lv4 -> winding trail -> plaza village
  (Job Master) -> Boar Meadow Lv6 -> Bandit Hill Lv8 -> 3-dock harbor (east). Beach Crabs were removed (Hermit = eggs only).
  To keep every other island identical, WorldBuilder burns the old Daybreak generation into a detached model to
  advance the shared `Kit.rng`, then builds Daybreak inside `Kit.WithRng`. Never reorder rng calls of other islands.
  Preview any island: `lune run tools/export_island.luau build/GrandVoyage.rbxl <IslandId> x.json`, then
  `python tools/blender/render_island.py -- x.json assets/models3d /abs/out` (Cycles; Eevee needs EGL).
- Client controllers start through the protected `start()` in `init.client.lua` (core UI first, visuals in parallel):
  a controller that errors or yields must never block the others (it hid the quest tracker in v0.13.0).
- Windows close only with their red X or Esc; the dim backdrop just blocks clicks (owner request).
- Fruit users in the sea drown (HP drains, `Fruits.DrownPerSecond`) instead of being washed ashore (owner request).
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
daily quests + achievements + titles (`ProgressService`, fed by `QuestService.Event`), 3D-rendered icon pack,
models v2 for pets (18) and fruits (6) (`AssetService`), map art pass up to v0.10.3 (materials, animated ocean,
day/night lighting, wind wisps + leaves, stylized env kit: trees/pines/palms/bushes/boulders, layered rock-cliff hills with
grass caps, red Red Line cliffs, scattered plants with petal flowers, painted grass texture).
Bump `GameConfig.Version` on every change: the owner checks it bottom-right in game to confirm Rojo synced.
Keep `progress.md` (Thai, for the owner) up to date with every version: snapshot, awaiting-test list, version history, next up.
The owner updates by double-clicking `update.bat` (git pull) on Windows, then Stop/Play in Studio.
Owner's standing instruction (18 Nov 2026): push every finished change to `main` as well as the session branch
(`update.bat` only pulls `main`), without asking each time.
The owner tests in Studio and sends screenshots; previews of new art are rendered in Blender (bpy) from the real GLBs
(see docs/screenshots/*.png) before shipping. Owner feedback is visual and blunt: iterate until they say it is right.

## Next up

1. Wait for the owner's verdict on v0.10.3 (hills/flowers/grass); fix what they point at.
2. Voxel art pass: monsters DONE v0.11.0 (voxel_monsters.py; AssetService sizes = shape base x style.scale,
   MonsterService.RefreshModels swaps placeholder island mobs). Pets + fruits DONE v0.11.1 (voxel_pets.py).
   Still to do: animation + VFX week (see docs/PLAN-week.md).
3. Per-skill icons (render_icons.py), Seastone gear for Marines, fruit skill VFX polish.
4. Playtest fixes (fruit Dash feel, pet follow, swim animation, quest flow). Friend playtest target: end of November 2026.
