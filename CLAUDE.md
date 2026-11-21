# LarpTales: Voxel Seas (code name Grand Voyage): project notes for Claude

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
  v0.23.0 (owner): GrassCap is flush with the rock rim (no overhang); Daybreak hills use grass ramps with rock sides
  (Daybreak grassRamp) instead of Kit.Stairs.
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
- v0.22.3 owner rules: Brawler fights bare-fisted and Sea Cook bare-legged (weapon lines "Fist Style" / "Leg Style",
  ids still Knuckles_* / Shoes_*, nothing mounted by WeaponService or the Bag statue; never the name "Black Leg", that is One Piece).
  Monsters startle when attacked, hit OR miss (`MonsterService.Provoke`: target, face, `MobAlert` FX = "!" billboard +
  `MobAlert` sound, charge at 2x speed for 1.6 s). Manual mode = Auto Battle off (`Combat.ManualAttack`): no click-to-chase,
  click/tap/hold swings at the pointed or closest monster in reach, skills out of reach say "Too far". Spawn pads are invisible.
  Stat quest goal counts points raised (AllocateStats + AutoStats report `Stat` with the amount).
- v0.22.4: Pearls are called **Gems** for players (💎, icon "gem"); code/save keep the pearl names (p.pearls, PearlService,
  Config/Pearls, attribute "Pearls", ledger store) so nothing migrates. Island names are hidden ("???") until visited or
  until the quest reaches that island's "Sail to" step (`Shared/Modules/Charts`, client `Controllers/ChartsView`; the
  Sea Compass item + banner come from QuestService.chartNext). Quest saves carry `quest.v` (Quests.SaveVersion): v2
  inserted T12 Bay Serpent, QuestService.questOf shifts old steps >= 12 up one. Bay Serpent arena = at sea east of the
  Daybreak harbor (boss.arenaRadius 70, respawn 3 min). Ships get overhead HP bars (`Controllers/ShipBars`).
  Diving: `Controllers/Swim` (Ctrl / 🤿 to dive, Space to rise, breath only under water, Swim.SeaSeconds caps surface
  swimming; server mirrors both in PlayerService), `Controllers/Underwater` (tint, blur, bubbles, Atmos.SetUnderwater,
  Audio.SetUnderwater EQ muffling, AmbienceUnderwater loop, WaterPlunge/WaterSurface). Sea floor + reefs: WorldBuilder
  buildSeaFloor (own Random). Ambience loops come from `tools/gen_ambience.py` (numpy + scipy, 44.1 kHz, seamless).
  Kit.Flowers / Kit.Plant are EnvProps dressed with the Env meshes (no more ball flowers); no monster-area signposts.
  v0.22.8: the synthesized ambience crackled (owner): AmbienceSea / AmbienceIsland / AmbienceUnderwater / WaterPlunge /
  WaterSurface now use real ProSoundEffects recordings from the Creator Store (licensed for every Roblox game; ids set
  in Sounds.lua add(..., { id = })). Find more with apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=... +
  /v1/items/details (creator ProSoundEffects). Do not go back to synthesized noise loops.
- v0.22.5 Bay Serpent = full body: head is the monster (`Mon_BaySerpent`, parts Head + Jaw hinged at its back),
  body/tail pieces `Serp_Seg` / `Serp_Tail` (Assets.Serpent, tools/blender/serpent.py) chained along the head's trail by
  `Shared/Modules/SerpentChain` (server: BodyPts attribute -> Reach.Gap counts the whole body; client:
  `Controllers/SerpentBody` draws + slithers, body parts carry SerpentOf = MobUid for clicks). Monsters def.serpent
  enables it; MonsterService serpentAttack = telegraphed lunge bite / water spit / tail slam (Telegraph FX kind
  line|circle, SerpentBite/SerpentSpit/SerpentTail FX, Mon_SerpentBite/Mon_SerpentSpit clips). Daybreak paths: no
  coplanar overlaps (exact segment lengths, lower joints, per-path height step, clipped at the plaza ring), quay blocks
  alternate height (paths also alternate 0.05 per segment: bends overlap); no direction signposts on Daybreak (owner).
  Serpent v0.22.8: 13 overlapping segments (spacing 6.4 < 10.8 length), each faces along its neighbours, gentle wiggle;
  v0.22.9 concept review: paved street ring STREET_IN..STREET_OUT (42.5..57) around the plaza (trails clip at 57.5,
  door aprons, Sunrise Tavern porch + awning + tankard sign), jungle clearing closed except 3 trail mouths + lanterns,
  spawn faces the village, blendHill (mounds/bushes/outcrops, run after the trails and kept off them), darker lagoon,
  softer ocean glitter. Render review shots: ONLY=review render_island.py.
  v0.23.0 sea boss: Bay Serpent has NO arena (boss.sea): buoys + sign at its spot; BossService spawns it under water;
  MonsterService seaInit/seaStep (AlignPosition + AlignOrientation, Humanoid PlatformStand) hidden -> rising (player
  within wakeRadius) -> fight (circles the target's ship, rears 22 studs before each attack: spit / lunge bite / tail
  slam, hits ShipService.InLine/InCircle -> DamageShip + Smash = hull planks fly off, ShipDebris FX) -> diving (heal).
  Body swims at BodyY (attribute); SerpentBody curls the neck up after the head (rise).
  Manual mode swings at the air when nothing is in reach (`Swing` request -> BasicAttack FX with miss = true). Island music = MusicJazz (owner's track, assets/music).
- Lune's CFrame.lookAt is WRONG (flips Z). tools/bake.luau passes a fixed `CFrame.lookAt` (fromMatrix) to the world code;
  before v0.22.6 every lookAt-placed part of the baked map faced the wrong way (overlapping paths / quay). Any new
  Lune tool that runs game code must use the same shim. In-game Roblox lookAt is fine.
- Ships (v0.22.6): `ShipModel.DressHull` wraps every launched ship (player + NPC) in a real hull around the block deck:
  stepped V-hull, bulwarks + rail + stripe (gun ports at edge cannons), pointed prow + stem, transom; size class by
  length (Dinghy <= 12 rows, Sloop <= 16, Galleon) adds bowsprit / quarterdeck / stern castle + lanterns + figurehead.
  Paint by faction (ShipService HULL_STYLES). The shipyard builder preview stays plain blocks.
- Voxel avatars (v0.22.7, GameConfig.VoxelAvatars): `Services/VoxelAvatar.Apply(char)` after normalizeAvatar (which now
  also sets Head = 0 and drops layered clothing): cube "VoxelHead" with the face decal (Head hidden), every accessory
  rebuilt as welded blocks: shape by raycast sampling (rows merged), cap fallback when rays see a box/nothing, color
  from the item name (no texture access in Roblox), highlight/dark blocks + spikes on hair.
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

- **v0.24 voxel overhaul (owner, 18 Nov 2026): EVERYTHING is voxel from now on** (characters, map, ships, UI, FX). New art
  defaults to blocks. Reference clips: a voxel pirate game (only the genre/feel, never its names or assets).
  * Title menu (`UI/Menu.lua`, GameConfig.TitleMenu): PLAY / CHARACTER, 3 slots (`Looks.Slots`; slot 1 = old key `p_<id>`,
    others `p_<id>_s<n>`), creator with color wheel. `Players.CharacterAutoLoads = false`; `Net.SetGate` refuses every
    request not marked `open` (4th arg of Net.Handle) until `MenuPlay` loads a slot; `DataService.Loaded` fires then
    (hooks that ran on PlayerAdded now use it). Respawn = `PlayerService.Respawn` (LoadCharacterWithHumanoidDescription +
    `Shared/Modules/VoxelChar.Apply`), never `player:LoadCharacter()`.
  * Looks (`Config/Looks.lua`): styles + hex colors (Color 1/2 per part, skin). Faces = images from `tools/gen_faces.py`
    (`Config/FaceImages`, eye layers white/iris/iris2/over, mouths untinted). Heritages: Islander, Skyborn, Tidekin,
    Beastkin, Oni, Cinderwing (0.1%, locked look, FLAME/CALM via `HeritageMode`, key V since v0.24.8: G is Guild). Never use One Piece race names
    (Skypian, Fishman, Mink, Lunarian...). Spins: slot spins + account bank (`acct_<id>` key, `Config/Spins` products).
  * Preview any look offline: `lune run tools/export_char.luau build/GrandVoyage.rbxlx out.json lineup|styles` +
    `python3 tools/blender/render_parts.py -- out.json out.png three` (also ships: `tools/export_ship.luau`).
  * UI: `UI/PixelUI.lua` pixel font (Enum.Font.Arcade = Press Start 2P) + text scale 0.56 + square corners on every
    PlayerGui; UI sounds `Blk*` (`tools/gen_ui_sfx.py`, Sounds `prefer`). The UI harness snapshots the menu screens too.
  * FX: `Controllers/Voxels.lua` (Blocks = real cubes, Pixels = square particles); VFX swaps every texture for its
    `px_` twin (`tools/gen_vfx.py`). Monsters die by toppling then dissolving (`CreatureAnim.deathFall`, server keeps
    the body 2.6 s).
  * Map: `World/Voxelize.lua` runs at the end of WB.Build (balls -> cubes, cylinders -> posts / plus prisms, wedges ->
    invisible collider + visible block steps); env meshes from `tools/blender/voxel_env.py` (same Env_ names);
    pixel materials `tools/gen_pixel_materials.py` + `PX=1 python3 tools/gen_materials.py --project`.
  * Ships: stepped block prow, square beams; Dinghy <= 7 rows (starter 3x6), NPC crews (`ShipService.addCrew`);
    player shots lead the aimed ship and hit by hull footprint.
  * v0.24.6: in-game MENU button (Menu.Start one-time setup, Menu.Open re-runnable; server `MenuReturn` saves +
    releases the slot), creator orbit camera (drag/wheel/pinch), menu text grown + fitted (growText), PixelUI fits
    fixed-size text into its box (TextScaled + size cap 0.74x), HUD status/currency = soft fading panels, heritage mode
    slot left of Dash (HUD), generic `Controllers/Flight` (Flight.Allow(source); Cinderwing `fly = true`; hold Jump in
    air, Q = barrel roll), manual-mode aiming (`Combat.AimInfo`: skills fire along the pointer/crosshair, server takes
    `dir`), `Controllers/Crosshair` pixel "^" with Shift Lock, quiet pickup sounds + `BlkLevelUp` chime.
    Developer Products to create: `docs/DevProducts.md`.
  * v0.24.8: `Controllers/HeritageAnim` animates heritage blocks on every client (wings beat when flying/airborne +
    `BlkFlap`, Beastkin tails sway, ears twitch per side, Tidekin fins ripple; horns/back flame rigid): VoxelChar pieces
    named Wing/WingTip/Tail/TailTip/Ear/Fin are hidden locally and anchored copies are posed with BulkMoveTo.
    Slot 3 is locked until bought (`Spins.SlotUnlock` product, `DataService.GrantSlots` on `acct_<id>`, `MenuUnlockSlot`,
    push `SlotUnlocked`). Spins 29/85/140/429 R$. Reset Stats removed from the Store. Dev tab Heritage picker (Admin
    cmd `heritage` "Id:variant"). Party = horizontal strip under the character card (`HUD.partyBar`), quest below it.
    Creator: hold right mouse to orbit (MouseBehavior LockCurrentPosition). MonsterDie prefers soft `BlkMobPop`.
  * v0.24.9: player-facing name is **LarpTales: Voxel Seas** (`GameConfig.GameName`, menu logo `GameConfig.LogoLines`);
    files, Rojo project, DataStore names and log prefixes keep "GrandVoyage" (renaming them would lose saves).
    Store fixes: cancelled Robux prompt clears the pending gift (PromptProductPurchaseFinished), Boss Respawn refused
    while `BossService.DownCount() == 0` (token if it changes mid-purchase), receipt mark kept on a failed save (no
    double grant), gift recipient saved too; MenuUnlockSlot refuses an already-unlocked slot.
  * v0.24.10: every Developer Product ID is filled in (Store, Spins, Gem packs) (`Spins.SlotUnlock` = 3733442306 since v0.24.11). Creator Hub "Managed pricing" can change what a player pays, so Robux labels use `UI/Prices.Apply(productId,
    fallback, fn)` (GetProductInfo PriceInRobux, cached) instead of trusting the config `robux` number.
  * v0.24.12: menu edits (look, Heritage spins, bank spins) go to a server cache in DataService (`menuCache`,
    `bankTake`) written in the background (`FlushMenu`, one write per key per 6.5 s; the slot being played rides along
    with the Load write): DataStore's per-key write limit made quick respins lag. Client roulette starts instantly.
    Aura on a roll = pixel ParticleEmitters on the preview's body blocks. Menu stays faded until char "Voxelized".
    Cinderwing CALM flies 25% faster (Flight modeK). HUD: soft ring disc, `HUD.boostRow` under the EXP readouts
    (boost timers), party strip + quest moved below the level badge. `Controllers/QuestPath`: yellow tile trail to
    State.questTarget (PathfindingService, straight-line fallback). Knockback: `MonsterService.Knockback(mob, from,
    dist, power)` (LinearVelocity plane skid, AI paused, walls/cliffs/sea respected; bosses/huge only for power >= 2.4
    at 45%), CombatService opts.knock on combo finishers, crits (2.5), last hit of damage skills; `Knockback` FX = dust
    + scuff lines. Coin loot no longer plays the Legendary jingle; Coin -> `BlkCoin`, item pickup -> `Pickup`/`BlkPouch`.
  * v0.24.13 (owner): players see **Race** (never "Heritage") in every text; code, attributes, saves keep heritage.
  * v0.24.14: Store boosts are ACCOUNT-wide (`DataService.Boosts/AddBoost` on acct_<id>; old slot boosts migrate on
    load). Respinning a non-Islander race asks YES/NO (`Menu.Ask`). Creator orbit: left drag grabs the model, right drag
    looks like Roblox's camera (opposite yaw). Skill icons: `tools/gen_skill_icons.py` (32x32 pixel-art recipes per skill,
    bevel + outline + class/fruit tile, 8x) -> `Config/SkillIcons` (upload_images.py), used first by SkillLook.IconId;
    a new skill needs a recipe there. Seastone gear: items with `faction = "Marine"` + `seastone = { chance, seconds }`
    (SeastoneBracer in the General Store, SeastoneShackle from big Marine ships); InventoryService refuses non-Marines
    and fruit users; FruitService.TrySeastone uses the best equipped piece (no gear = no seal), `SeastoneSeal` FX.
  * v0.24.15: `Swim` / `SwimIdle` R15 clips (CharAnim plays them while Swim.IsSwimming). Pets: lazy follow (wait close,
    trot after at 7 studs, face the walk). Dash skills: server pushes `SkillDash` and the caster's client slides
    (LinearVelocity, 60 studs/s, matches the hit timing) instead of a server CFrame teleport. `Controllers/WorldCull`:
    untagged anchored scenery of far islands is parented to nil locally (distance by quality preset, batched, nearest
    first; instant restore when the camera/character is within 120 studs of a hidden island). Tagged things and
    anything inside a tagged model or holding a ProximityPrompt are never culled: tag new gameplay props.
  * v0.25.0: NPCs are VoxelChar previews (`ModelFactory.NPC`: outfit by title keyword table NPC_STYLE, hair/eyes/skin
    hashed from the name, voxel hats, NoVoxel, root = HumanoidRootPart 2.6 above the feet). WORLD_VERSION 13.
  * v0.25.1: `Controllers/FruitFX` (one function per fruit skill id, called from VFX handlers.Skill for "F_" ids).
    Bosses: pixel tile Telegraph (default kind) + `bossCharge` (line telegraph, LinearVelocity run, playersInLine hits,
    `BossCharge` FX) alternating with the slam. `MobSpawn` FX (fade-in via LocalTransparencyModifier), fruit spawn
    glow column + px emitter, `VFX.LootMagnet` (called by HUD.FlyLoot), `Controllers/Footsteps` (run dust, swim splash).
  * v0.25.2: PixelUI `untint`: a colored UIGradient on a text object with a background is moved into BackgroundColor3
    (gradient keeps only the shade ratio), otherwise the gradient tinted the text = "hollow" letters. `UI.Colored`
    (rich text) + `UI.StatColor`; class names in class color, guild in faction color. `UI.Announce` posts to the chat
    (RBXGeneral DisplaySystemMessage), banner only as fallback. Windows hide PlayerGui.TouchGui while open. Compass is
    fitted between the MENU button and `CurrencyRow` (Readability fitCompass). Quest.Dialog: NPC found by model name
    (tag NPC) -> camera close-up within 34 studs (restored on close / walking 8 studs), ViewportFrame portrait,
    cyan hologram when far, `Talk` blips (BlkTalk) pitched per speaker. Owner decisions: boss charge stays; Seastone
    gear required to seal; guild war answers in docs/GuildWar.md section 6.
  * v0.25.3: icons are PIXEL ART now: `tools/gen_pixel_icons.py` (transparent 32x32 recipes, same names as
    Config/Icons + new: dash flame calm auto manual graphics audio interface autobattle developer merit + monster
    materials) -> assets/icons -> upload_images.py -> Config/Icons. UI.Button turns a leading emoji with an icon into
    an image at the left. Never draw a straw hat (One Piece): "hat" is a tricorn. AUTO button reads AUTO / MANUAL.
  * v0.25.4 (owner): first class switch at Job Lv.5 (`GameConfig.JobChangeLevel`); Daybreak quests: T08 Job Lv.5 on
    tigers -> T09 Job Master -> new T09B Boar Hunt -> T10 bandits (Quests.SaveVersion 3 shifts saves at step >= 10).
    Boars passive, bandits `aggroRadius = 14` (Monsters def field read by findAggroTarget).
  * v0.25.5 (owner): fruits v2 = `fruit_v2(kind)` in tools/blender/voxel_pets.py (shape tells the power: flame
    tongues / cloud puffs / hex-grid crystal shell / rubber bubbles / floating slices / oil drop; crease shading from
    nearest-vs-second-nearest lobe distance). Pixel icons fruit_* match. Do not copy the reference fruits' exact swirl.
  * v0.25.6: `Controllers/ShiftLock` (Left Shift / mobile LOCK button; skipped when Roblox's own MouseLockSwitch is
    on; released while `UI.AnyOpen()`). MENU button hidden while a window is open. Reset Stats back in the Store
    (product 3733424822). PixelUI TEXT_SCALE 0.82, MIN_TEXT 12. "knuckles" icon = a fist. HUD target bar only while
    its HP changed in the last 6 s or for bosses. Bag slot "Pets". Daybreak SPAWN by the campfire (WORLD_VERSION 14).
    Studio anim status line removed.
  * v0.25.7: dialog portrait = half-body ViewportFrame bust (200x230) standing out of the box's left edge (text and name
    tag shift right). M1 = 4-hit strings for every weapon (AnimClips.Weapons combos have exactly 4 clips; GameConfig.M1
    Quick 0.7 / End 1.9 x attackInterval; server CombatService.m1Gap + client Combat m1Ready/m1Swing mirror it; the 4th
    = knockback finisher). Sounds: `tools/gen_sfx_elevenlabs.py` (ElevenLabs sound-generation, key injected by the
    proxy as xi-api-key, never send the header yourself; min 0.5 s) -> assets/sfx/*.wav -> `upload_sfx.py --only ...
    --force`; replaced entries in Sounds.lua have no prefer/pitch. ElevenLabs MCP in `.mcp.json` (loads next session),
    jsfxr presets via `node tools/sfx/gen_jsfxr.js <preset> <Name>` (npm install in tools/sfx first).
  * v0.25.8: QuestService pushes the quest on DataService.Loaded (the client's QuestState ran behind the menu gate).
    Sailing zone change needs 1.5 s (Calm Belt edge flashing). Scene music = Roblox licensed tracks (APMOfficial /
    DistrokidOfficial, find with toolbox-service marketplace/3 + items/details; ElevenLabs Music needs a paid plan):
    Sailing.updateAudio picks MusicBoss > MusicBattle (State.lastBoss / lastCombat set in VFX Damage) > MusicSea >
    MusicNight/MusicIsland. NPC ship segments start past a sea boss. M1 Quick 0.55 / End 2.0. Crosshair PX 2. Stats:
    colored derived stats, name in title tier color. Strap bands same angle. Loot flies into the character only
    (HUD.FlyLoot = LootMagnet + sounds). NPC nameplates: UIScale by distance (28/dist), MaxDistance 160, pixel icons.
  * v0.25.9 (owner): race parts per variant: Skyborn `shape` (sparrow/swallow/owl/angel, VoxelChar WING_SHAPES),
    Tidekin `fins` (reef crest / shark dorsal / lionfish back + arm spines / manta shoulder fins), Oni horns out of the
    forehead at z -2 (in front of the bangs) rising to y 10-12 (above the hair). Preview: export_char.luau `races` mode.
  * v0.25.10 (owner reference): Store window = tabs + Gems pill on top, big item cards left (UIGridLayout in a
    Scroll), detail card right (big icon stage, name, desc, big BUY buttons). Entries share one shape in
    Panels.PearlShop `entries()` (kind store / gemshop / pack); the picked card per tab is kept in `storePick`.
  * v0.25.11 (owner): islands spread north/south (`Islands` x + z; x still grows with level for SeaZones.Segment),
    Lane.HalfWidth 2000 (wide windy sea), World.HalfZ 3800, WORLD_VERSION 15. WorldBuilder builds a generic island at
    z 0 and then moves its parts + CFrame/Vector3 attributes by z (Daybreak stays at 0,0). Runtime code must add
    `(island.z or 0)` to every island offset (spawns, bosses, arenas, compass). `buildIslets`: sea stacks, sandbars,
    wrecks between islands (own Random + Kit.WithRng). Ocean water is tiled in z (parts max 2048). Map window = 2D.
  * v0.25.12 (owner): Store icons are pixel art `st_*` (gen_pixel_icons.py, tiny 3x5 font `text`/`badge`), entries name
    them in Config/Store / Pearls (`icon = "st_exp"`; packs read icon/name from client PearlsCfg.Products by index).
    `UI.VoxelEgg(parent, eggId, size)` = block egg in a ViewportFrame (returns vp, setTilt). Pearls.Shop `bulk = {1,10,30}`
    -> PearlShopBuy `qty`. HatchEgg `count` (<= 10, stack, roster room) returns `{ species, egg, capped }`;
    `Panels.HatchReveal` wobbles + pops each egg. PetS.Add(..., quiet) skips the per-pet banner.
  * v0.25.13 (owner): `UI.Sparkles(frame, color, n, {float, z, star})` = floating pixel squares + twinkle stars (one
    throttled RenderStepped per layer); every UI.Window gets corner glows (BgGlow) + two sparkle layers at ZIndex 20
    (body is 21), the title menu a full-screen layer. Store data is cached in Panels.PearlShop (`render(false)` redraws
    only: re-requesting on each click hit the Net throttle and the Gem packs vanished). Eggs `stack = true`;
    HatchEgg counts/removes across every entry (RemoveItem). PearlShopBuy checks bag room before Spend.
    VoxelEgg: surface blocks only, 2x2 spot blobs, highlight patch, Golden band + neon jewels. Wings `lift` (upper back).
  * v0.25.14 (owner): `Services/KnockdownService` + GameConfig.Knockdown: lethal MONSTER damage (DamagePlayer without
    info.killer) -> char attribute Downed, Health 1, PlatformStand, RevivePrompt (other players hold 3 s -> 30% HP),
    bleed-out kill. Combat.MonsterHit on a downed player -> TryExecute (Telegraph circle, kill after the wind-up);
    MS.Damage -> OnMobHit: another player's hit interrupts (knockback + re-target). CombatService `alive()` excludes
    downed players (no attacks, not a PvP target), no regen while downed. Client push "Downed" overlay + GiveUp request.
  * v0.25.15 (owner): worn gear = WeaponService `OUTFIT[itemId]` blocks ({ limb, size x limb, offset x limb, color };
    "Head" means VoxelHead) rebuilt when `OutfitKey` changes (1 s sync loop). Voxel item previews: `tools/gen_icon_voxels.py`
    (pixel icons -> Config/IconVoxels, run-length rows + palette, self-checked) -> `UI.VoxelIcon(parent, icon, size)`;
    Bag detail + Store stage use it; `UI.ItemIconName(def)`. Re-run the generator after changing pixel icons.
  * v0.25.16 (owner: sounds felt the same): ElevenLabs StepGrass/Wood/Sand/Stone (Footsteps plays by hit.Material,
    mutes Roblox's root "Running" sound), ImpactThump under every Damage FX + Crit layered on crits, Knockback FX ->
    FinisherBoom.
  * v0.25.17 (owner): HUD menu tiles get UI.Sparkles + UI.Shine. On a ship, Combat.CastSkill always aims (no target
    needed) and CombatService's aimed branch calls `ShipService.SkillHit` (hostile ships in the line). NPC crew =
    static monsters (MS.Spawn opts.def + opts.model, `ShipService.crewDef`: area island level + 5/tier, stats from the
    closest monster), unwelded before die() anchors them, `MS.Forget` when the ship goes. Boss/special monster hits push
    "Knock" (client LinearVelocity burst, or Flight.Shove in the air); flight landing ray ignores workspace.Monsters.
    Fly / FlyIdle clips (CharAnim prefers them over swimming). Combo swings crossfade (fade 0.1/speed). ShiftLock turns
    the body at Camera-1 (before the camera). Vanity: settings.hideGear (Bag GEAR ON/OFF) skips WeaponService OUTFIT.
  * v0.25.18 (owner): Hunts = `Config/Hunts` + ProgressService (HuntStart / HuntAbandon / HuntClaim, p.hunt
    { id, progress } fed by the Kill event, sent in the Profile push); Quests window tab "Hunts" (renderHunts two-pane
    layout), HUD HuntCard under the tracker (Quest.lua). `UI.Bar(..., start)` = initial ratio (progress bars pass 0).
    Monster types: `Config/MonsterTypes` (kanji + color), Monsters.lua TYPE_OF / STARS / STYLE set def.mtype, stars,
    atk/attackSpeed/moveSpeed/attackRange, hitBonus, critChance, stunChance (CombatService.MonsterHit + push "Stun").
    Nameplate: TypeBadge + stars in the subtitle. Keep non-monster tables out of Monsters (tests walk every entry).
  * v0.25.19 (owner): sea map tiles = island emblems `isl_<IslandId>` (tools/gen_island_icons.py, 64x56 pixel scenes
    with a blank ribbon the UI writes the name on; uncharted = dark ImageColor3 + "???"). gen_icon_voxels skips isl_/st_.
  * v0.25.20 (owner): hand-laid islands go through `WorldBuilder.LAYOUTS` (island.layout -> module + seed): burn the
    generic build (keeps Kit.rng), build the module on its own stream with `layoutApi` (base, makeCtx, npc,
    standardNPCs, dock, shipyard, placeChests, banner...), then the usual z shift. `World/ConchBay.lua` = first one
    (garrison plateau via L.Tiers, conch towers, market street, town grid, long pier). Renders: export_island +
    recenter x/z to 0 before render_island.py (its shots assume the origin). Daybreak SPAWN by Rowan (WORLD_VERSION 16).
    Client CharacterAdded resets CameraType/CameraSubject (camera stuck in the air after Reset).
  * v0.25.21 (owner): islands after the first get `island.yaw` (Islands.lua: local +Z faces the previous island) and
    their offsets are stored turned; `island.localOffsets` keeps the unturned ones, which WorldBuilder swaps in while
    building, then turns + moves the island with one CFrame T (parts + CFrame/Vector3 attributes). Render scripts must
    un-turn by -yaw. Bounty Board / Guild Registrar / Job Master only on Daybreak + Epilogue. ConchBay: own NPC spots,
    grandStairs (one straight flight + landing), scenery(), boss in the garrison yard. NPC plates: icon only beyond
    Interact NEAR (22 studs from your character). HUD: menu fold tab (▶/◀), quest tracker fold (◀ -> scroll button,
    Quest.collapsed hides the hunt card too), tracker texts truncate.
  * v0.25.22 (owner, concept overhead/aerial/market shots): Conch Bay is terraced: quay 7.6 (stalls, T pier) -> T1 +7
    -> T2 +14 -> garrison plateau +21 (open sand courtyard, two tapered blue towers with outside spiral stairs, the tall
    one on the axis so it shows from the market). Boxes are taught to ctx.height (`withRects`). Walk check without
    Studio: `python3 tools/island_local.py export.json local.json <x> <z> <yaw> "x,z x,z ..."` (also recenters + un-turns
    the export for render_island.py, ONLY=conch shots). Menu fold tab is placed from menu.Position (root UIScale).
  * Store (`Config/Store`, `StoreService`): Benefits + Boosts, Gems or Robux, for me / gift; Robux ids are 0 until the
    owner creates the products. Starter skill = Heavy Attack (`heavy = true`, `AnimClips.HeavyFor`).

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
