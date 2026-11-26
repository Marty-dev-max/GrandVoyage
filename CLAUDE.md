# LarpTales: Voxel Seas (code name Grand Voyage): project notes for Claude

Roblox MMORPG (Ragnarok-style systems in an original pirate-sea world). Luau + Rojo, server-authoritative.
Player-facing text and code are English. The owner (Roblox user Treezaa2, id 1527424396) talks in Thai: reply in Thai.
Design numbers live in `docs/GDD.md`; setup and feature map in `README.md`.
Owner references live in their Google Drive (Drive connector): folder "Ref" `1MgGIJaw871W757h7locqVBoYKwDXhpbJ`
(sub "Island" `1xOPpu910yCtZn8meRHO88Kc89yk-zvJc` = island concept art, "Vid" `1hN1CCwExWeazFCb7rMvAyN85b6iHHs6E` =
reference clips). Written specs taken from them: docs/Islands-Concept.md, docs/Plan-*.md. Images sent in chat are NOT
saved anywhere: what matters from them is written into these docs + CLAUDE.md version notes.

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

- UIPadding moves child GuiObjects too, not just text: anything placed inside a padded frame (bevel lines, icons)
  is offset by the padding (UI.Button fitBevel + icon x -26 compensate). The pixel font (Press Start 2P) has no
  arrows / pencil glyphs like ▾ ▴ ✎ (they draw as a box): use ASCII or a pixel icon. Live UI check: Studio MCP
  start_stop_play, click PLAY with user_mouse_input at the button's AbsolutePosition (GUI space, inset excluded), then
  keys (I, K, ...) + screen_capture. Never require client modules from execute_luau to drive the game: it gets a
  separate copy (Menu.Play there sent MenuPlay but left the real menu stuck).
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
- Hotbar (SUPERSEDED v0.25.71 by skill sets, see the v0.25.71 note; p.skillBar is kept in saves but unused by the client):
  `p.skillBar` = 12 fixed slots (keys 1-6, 7 8 9 0 - =), `p.itemBar` = 8 quick items (F1-F8; UNUSED since
  v0.25.55: F1 = HP potion, F2 = SP potion, see below), "" = empty slot;
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
  before finishers. Navigator = weather (until v0.25.51; now baton melee, see below): `VFX.StormCloud` (warm + cold puffs
  condense), ThunderCall / CycloneCall skill FX kept for the Storm Caller job 2. Own crits: gradient "CRITICAL!" number on an impact star + `VFX.ImpactFrame()`.
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
  * v0.25.23 (owner): Anim.Stop stops even when IsPlaying is false (a loading track kept the fly pose after landing).
    Prompt card = 1.35x, centered at the NPC nameplate's height (plate hidden while shown). ShiftLock = native feel:
    UserGameSettings.RotationType CameraRelative + AutoRotate (never snap root.CFrame: it jittered). MENU -> Ships =
    `SummonShip` (call the active ship at a dock <= 400 or where you swim; again = store) + `SetActiveShip`; the
    Shipwright window only edits / picks the active ship. Downed players drop out of Flight (PlatformStand tumble).
    Conch Bay mobs on the terrace streets (houseRows ignores ctx.free so spawn reservations keep the houses).
  * v0.25.24 (owner): `World/Marmalade.lua` (LAYOUTS seed 20261123): paved town + long boulevard (planters, lamps)
    from the south quay to the raised town hall (blue roof + dome) and clock tower, 3 house columns a side, forest hill
    with orange groves, winding coast paths, shore boulders, decor circus ship + gangplank (our own look). The base's
    grass mounds under the town are removed (match by Size/Material/CFrame: Lune's bake has no default Part.Position
    or Shape). island_local.py handles ramps (tilted top faces). Render: ONLY=marm.
  * v0.25.25 (owner): Flight lands on ANY ground contact unless Jump is held (the old vel.Y test kept you flying along
    the ground when the camera looked up = "fly pose after landing"). ShiftLock offsets the CAMERA in its own space at
    Camera+1 (Humanoid.CameraOffset is body space and wobbled with the one-frame-late body turn). Knockdown = ragdoll
    (server swaps body Motor6Ds for BallSocketConstraints, client ChangeState(Physics) + limb collisions), HP creeps
    back and you stand at Knockdown.StandAt (10%) after RecoverSeconds; no bleed-out. Low-HP red edge pulse in
    init.client. Island name billboards disabled (ChartsView). Harbor faces the next island: `island.yardAngle`
    (WorldBuilder.yardAngle) turns the shipyard group (with its own Shipwright NPC) and the east dock with
    `turnGroup`; layouts/standardNPCs no longer place a Shipwright (Daybreak keeps its own). Conch Bay + Marmalade
    drop the base's grass mounds; Marmalade's circus ship lies off the south shore (SHIP_Z) with a pier.
  * v0.25.26 (owner: fly pose + shift-lock shake came back after a while): Swim forced the humanoid into Swimming and
    nothing took it out on land (swim pose on land, swim turning vs Shift Lock): out of the water -> Freefall. Combat
    `turnTo` skips body snaps toward targets while MouseBehavior is LockCenter. Dash: `VFX.Afterimages(char, dur,
    every, color)` ghost copies of the visible blocks (own dash local + instant, others from the Dash FX `char`),
    more wind streaks, Speed 120 / Duration 0.14, FOV kick, hard stop (horizontal velocity zeroed) + skid puff.
  * v0.25.27 (owner): one Dash everywhere (Combat.Dash; in flight = Flight.Shove along the camera, same cooldown,
    trail and Dash FX; the barrel roll is gone). Afterimages keep the character's own colors; no hard stop (momentum).
    CharAnim sweeps Fly/FlyIdle/Swim/SwimIdle every 0.5 s while neither flying nor swimming. Shipyard snaps to the
    island side (east / north / west, never the south front) nearest the next island, parallel to the island; docks
    stay at local +-x. NPC plates: holder anchored bottom-center (distance UIScale shrinks toward the head), far
    icon >= 0.65 scale and on the bottom row.
  * v0.25.28 (owner): Anim's 3 s "asset did not load" swap stops the old track first, and Anim.Stop also stops every
    playing track whose Animation.Name matches (orphans kept the fly pose forever). UI v2 = pixel-art fantasy RPG UI
    (owner reference "Pixel UI & Icons"): indigo Theme + `T.Bevel` / `T.Trim`, `UI.Bevel(frame)` (light inner ring),
    `UI.Shade(c, k)` hue-shifted light/dark + `UI.RichFill(c)` for bars, window = bevel rings + gold rivets + title
    plaque centered on the top edge (AutomaticSize + UIPadding; the HTML snapshot renderer ignores both), buttons with
    a top shine line + bottom lip, item tiles (`UI.RarityStyle`) = dark slot tinted by rarity + bright rim + glow
    aura, menu tiles the same. Fonts: Display/Bold/Number = pixel, Semi/Body = Builder Sans Bold (PixelUI leaves
    BuilderSans text alone). AUTO/MANUAL + UI.Toggle = sliding switches.
  * v0.25.29 (owner): HUD.MENU entries carry `bg` (gradient pair), `fx` (particle theme) and `stripes` (Guild pennant);
    `UI.DressMenuTile(tile, it, n)` applies them to the HUD tiles and the MENU window tiles. UI.Sparkles opts: icons
    (pixel icon names), iconFrac, iconColor, plus, bubble, color2. Pixel icons: bag = backpack, new `shop` storefront
    ("🛍️" -> shop). HUD layout (PC, `HUD.bottomCard`): framed character card bottom-left (class • faction header, no
    big name) beside the hotbar (`HUD.hotbar` shifted right), quest tracker top-left with the party strip following
    the tracker/hunt card, framed currency pills top-right; phones / compact keep the old top-left card.
    v0.25.30: hotbar left-anchored at x 536 beside the card; bottom card only when canvas.X >= 536 + measured hotbar
    width + 24 (re-laid out on its AbsoluteSize change; pcall: the Lune harness has no AbsoluteSize); party strip =
    PARTY button only (HUD.partyWidth), 60 px under the collapsed quest button; no dark disc behind the portrait.
  * v0.25.31 (owner): gem icons = `fgem` (gen_pixel_icons.py: wide brilliant cut, table/bezel/pavilion facets);
    mini_gem + `gem_heap` use it; packs = Pile / Chest / Trophy of Gems (Pearls.Products names + st_gems_* icons).
  * v0.25.32 (owner): humanoid monsters = voxel characters like the players. `Config/MonsterLooks` (style names + hex
    colors per monster id, `race`/`variant` = Tidekin bodies for the fish-folk, `acc` list, `held` weapon, `attack` = R15
    player clip) -> `ModelFactory.VoxelMonster` (R15 rig from a normalized HumanoidDescription, VoxelChar.Apply,
    Accessory.Wear, ScaleTo style.scale; one template per id, cloned; attrs RealModel/R15Mob/AttackClip), tried first by
    MF.Monster. MonsterService plays Roblox's default R15 idle/walk (507766388 / 507777826) + AttackClip + Hurt for R15Mob.
    Accessories = `Config/Accessories` (blocks { limb, size x limb, offset x limb, color, material }) built by
    `Shared/Modules/Accessory` (Build/Wear) for players (WeaponService OUTFIT = Accessory.Cfg), monsters and previews:
    an item whose id has an accessory shows when worn (new headgear/capes/beards in Items.lua, dropped by their monster).
    Preview: `lune run tools/export_char.luau build/GrandVoyage.rbxlx out.json monsters [row]` + render_parts.py front|three.
  * v0.25.33 (owner): WILL POWER = the downed player's own RevivePrompt (E): one try per knockdown (char attr WillTried
    = Downed stamp), chance Knockdown.WillBase + WillPerLuk x LUK (cap WillMax), success stands at WillHp (50%);
    Interact shows your own card as "Get up / Will power x%". ExecuteWindup 4 s; an execute pushes "Executed" { by,
    level } -> init.client black cut "YOU DIED" + cause + MusicDefeat (Audio.SetMenuMusic override until respawn).
    Fruits: Bag "Use" -> `HoldFruit` (model welded to RightHand, char attr HeldFruit = uid) -> State.heldFruit; a click
    (Combat routes it) opens Panels.FruitChoice EAT / STORE (`StoreFruit` = put away) / DROP (`DropFruit`: world fruit
    for 2 min, others pick it up only if PearlService.CanTrade and the entry was not TradeLocked). Fruit spawn = its own
    PointLight + soft sparks (no beam). Fruit Notifier holders get push "FruitSpawn" -> `Controllers/FruitAlert`
    (FruitTwinkle + narrator Narr_Fruit<IslandId> from tools/gen_voice_elevenlabs.py, TTS fallback with
    AudioTextToSpeech while the ids are empty: audio upload quota spent until 6 Dec 2026; "? FRUIT ?" marker).
    v0.25.34: FruitAlert dresses every CursedFruit-tagged model for all players (looping `FruitHum` via
    `Audio.Attach(name, part, range)`, spawn flash + double blink every ~2 s with Highlight/light/sparkles);
    Dev "spawnfruit" passes the tester to FS.SpawnTreeFruit(tester) so they get the Notifier alert.
    v0.25.35 (owner): "FruitSpawn" goes to EVERY player ({ knows = false } without the boost): FruitTwinkle + gold
    screen-edge blink x3 + UI.Banner anywhere on the map; narrator + marker stay Notifier-only (knows = true).
  * v0.25.36 (owner): accessory items show themselves: `tools/gen_acc_icons.py` (export_char.luau `accessories` mode ->
    3/4 flat-shaded 32x32 pixel art on a plain head/torso stand, capes seen from behind) -> `acc_<ItemId>` icons, picked
    first by UI.ItemIconName; Bag stage = `UI.AccessoryView(parent, id, size)` (blocks via Accessory.Build on a stand,
    `UI.ModelViewOf(parent, model, ...)`). Vanity per piece: settings.hiddenGear[itemId] (SetAutoSettings `gearVisible`
    { id, show }, Bag detail toggle); `WeaponService.RefreshOutfit(player)` right after equip/unequip; UI.CharacterView
    re-copies the statue when GVOutfit models / HeldFruit change. Full-screen windows scale their body (UIScale k =
    fit of the framed design size, 1..1.6) instead of stretching. Rarity tiers in UI.RarityStyle: Rare+ Shine sweep,
    Epic+ pulsing aura (`pulses`) + rim Glow gradient, Legendary+ Sparkles, Secret = dark violet + rotating rainbow
    `Foil`; `UI.RarityText(label, rarity)` rainbow text for Mythic/Secret; `UI.FruitFx(frame, fruitId, n)` = fruit
    particles (pt_swirl/flame/cloud/hex/slice/drop icons). Bag tabs text only; stall button = `stall` icon + tooltip.
    Held fruit gripped from the side. ui_render.js scales UIScale around the AnchorPoint like Roblox.
  * v0.25.37 (owner, hero-select reference): Job Master = always full screen, only the X (UI.FullPref.Job, maxBtn hidden):
    class wheel left (cycle -3..3 around `sel`, click / arrows / wheel), CharacterView center holding c.weapons[1] on a
    podium with CHOOSE (first switch) / SWITCH / CURRENT, right = role + name + stat rings (top 3 of `build`, ranked) +
    type card (`typeDisc`: kanji core, green top = beats, red bottom = weak to). Background = bright gradient of the
    class color. Classes have `mtype`, `role`, `build` (PlayerService.AutoStats reads it). MonsterTypes (v0.25.38, owner:
    PHY removed, it was only toughness): 4-cycle `beats` AGI>STR>INT>DEX>AGI (one each, even with the opposite),
    `Mult(a, b)` = Bonus 1.2 / Penalty 0.85, used by CombatService both ways. Class colors follow their type (Navigator
    purple, Doctor magenta INT, Shipwright rust STR, Sharpshooter sky-blue DEX). Ex-PHY gunners: Rifleman DEX,
    Armored Gunner STR, both keep x2.5 range via Monsters LONG_RANGE.
    Round UI pieces set attribute PxKeep (PixelUI squares every other UICorner) and use a Round stroke join (a Miter
    join fills the corners = a square box around the circle; PixelUI skips PxKeep strokes). v0.25.39:
    UI.CharacterView(parent, props, { water, zoom }) frames the BODY only (before the weapon), refresh(weapon, tint);
    water = mirror (each block reflected across the plane: CFrame S*R*S, S = diag(1,-1,1), pairs updated in place())
    + ripple rings, light/ambient tinted; shiftX moves the statue off-center, onFrame(horizon) reports the water line.
    v0.25.40 Job Master: the view spans the whole window behind the columns, the sea is a UI gradient frame from the
    horizon down (class color), CLASS_FX pixel particles per class on the backdrop; no wheel-scroll class cycling.
    v0.25.41: CharacterView opts zoomStart / shiftY (Job Master 1.5 / 0.07 keeps the feet above the button), ripples
    = rings of small blocks (a cylinder is a solid disc). Item previews (Bag, Store) have no focuslines rays and no
    rarity jingle on open. Class card lines have fixed heights (the HTML renderer ignores AutomaticSize).
  * v0.25.42 (owner): shop cards = Panels `shopGrid` / `shopCard` / `byRarity` (Shop, Stall buyer, StallSetup: price box
    on each card + PICK, then OPEN STALL); Dev (Studio or CreatorId) skips the Gem stall gates in MarketService.StallOpen.
    `Controllers/NpcLife`: NPC blocks breathe + wave (limb = rest position in root space) via BulkMoveTo, `NpcLife.Face`
    from Quest.Dialog. UI.Bevel lives in a `BevelHolder` Folder (list layouts skipped it -> Guild content fell down).
    Ship crew: figure blocks weld to the figure's main part, which rides a `DeckWeld` (C0 in ship-root space);
    ShipService `crewStep` (Heartbeat) walks provoked crew across the deck to fight (one hit -> all crew, `ship.boarded`
    = no volleys, no steering), helmsman dead = ship stops, no gunners = no volleys. Crew tagged `ShipCrew` (client
    `Combat.mobList`). Hulls: CombatService target kind "ship" (`ShipService.NpcShipOf`, SHIP_HIT 0.6 x atk), manual
    swings hit an NPC hull in reach, aimed skills hit ships from anywhere. Combat `onShip(true)` = your own ship only.
  * v0.25.43 (owner): buy buttons green when affordable, red when not (Shop recolors on profile change). Stall booth:
    posts behind the seller, awning slopes toward buyers. Interact hides a prompt card when the camera is > 45 studs
    away and says "Manage" on your own `Stall_<UserId>`; the seller's trigger opens StallSetup = editor of the open stall
    (`StallAdd` / `StallRemove`, sold/removed slots stay qty 0 so buyer indexes hold; MarketService checkItem / payFee /
    escrow / giveBack shared with StallOpen). Stats header: name / class / levels centered; combat card fixed 3x4 grid.
  * v0.25.44 (owner): `Controllers/Hotkeys` = every rebindable key (Actions list: Skill1-12 default E R F Z X C then
    1-6, Dash Q, Auto T, Target Tab, Race V, window keys, Stats = Y), one ContextActionService binding at High priority
    (Roblox's camera sank I / O = dead Bag key), `Hotkeys.On(action, fn)` (fn returns false = pass the key on),
    overrides saved as Settings.Values.keys "Action=Key;..." (server allows 600 chars for "keys"). Skill keys pass E
    to a shown prompt card (`Interact.AnyShown`) and E/F to Sailing on your own ship. Settings tab "Hotkeys" (rebind +
    Reset all, pixel icon `keyboard`); Auto Battle settings = `Panels.AutoBattle` from the gear right of AUTO/MANUAL
    (removed from Loadout). Cinderwing = `greatWings` (VoxelChar: spread bird wing GREAT_SPREAD folded back 0.9 rad
    around a shoulder hinge; pieces GreatWing/GreatWingTip), HeritageAnim kind "great" unfolds (GREAT_FOLD) + slow deep
    flaps when flying/airborne. Preview: export_char.luau `cinder` mode (folded + spread, front + back).
    v0.25.45 (owner: looked like a butterfly, too big): GREAT_SPREAD = one tapered wing (scalloped trailing edge,
    single pointed tip), cell 0.38, top 2.5, folded 1.05 rad (GREAT_FOLD in HeritageAnim + export_char match).
    v0.25.46 (owner: still too wide, "the old one was fine"): REVERTED to the original `wings(...)` Cinderwing wings;
    greatWings + HeritageAnim "great" removed (export_char `cinder` mode left in, now a no-op). Do not bring them back.
    v0.25.47 (owner): monster types ClawCat AGI, OctofolkBrute INT, DepthsWarden DEX (Monsters TYPE_OF).
  * v0.25.48 (owner): hold-to-aim in manual mode (Combat startAim/stopAim, `Hotkeys.OnRelease(action, fn(cancelled))`):
    a held Melee/Ranged/GroundAoE/Dash key shows an AimLine + AimSpot (ClientFX) following `Combat.AimInfo` (pointer, or
    the screen center with Shift Lock), turns the body (AutoRotate off while aiming), casts on release. AimInfo's 4th
    return `dir3` aims at chest height above the pointed spot; CastSkill sends it as `dir`; CombatService `aim3` tilts
    the Melee/Ranged path + FX up/down (|Y| <= 0.8), ship hits and Dash stay flat. Auto mode / touch slots cast on press.
    v0.25.49: the CAS key-up never arrived in the owner's Studio (aim line stuck): the aim loop also releases when
    `UserInputService:IsKeyDown` says the key is up. Do not rely on CAS End alone.
  * v0.25.50 (owner): ShipService `SkillHit` / `SkillHitCircle` (skillHitList: an NPC ship you stand on is not "yours")
    called from every damage skill kind in CombatService (shipLine / shipCircle, shipDmg = 0.8 x atk x mult x hits).
    NpcLife: limbs split by side (arms |x| > 1, legs below HIP_Y), relaxed stance (arms out + soft elbows, feet apart,
    weight shift, breath), any NPC ProximityPrompt trigger -> facing until 14 studs away. Interact prompt BIG 0.9.
    WorldCull: EnvProp/EnvPart are cullable (Decor stays with Settings), Forts/Islets/RedLine/SeaFloor hide in 600-stud
    chunks. Graphics buttons quarter width (phones could only reach Low). ShiftLock LOCK button DisplayOrder 30 at
    (1,-20,1,-142), hidden while a window is open. FruitAlert `beacon`: SpawnedAt attr (FruitService) -> 60 s pillar +
    AlwaysOnTop diamond + `FruitSonar` ping every 2 s (ProSoundEffects 9119435202, fallback electronicpingshort) +
    square ground ripple. Touch hold-to-aim: HUD skill slot InputBegan -> `Combat.TouchAim` (startAim src = the touch:
    drag from the button = joystick dir, camera pitch = tilt), CastSkill(id, nil, aim) uses the last shown aim.
    docs/Plan-Job2.md: owner picks 22 Nov (Sea Cook A Ember Kicker / B Barrel Roller, Doctor B exploding apple,
    Shipwright A Ironclad / B Silent Chisel). Friend playtest = 29 Nov 2026.
  * v0.25.51 (owner: Navigator too strong): base Navigator = melee folding baton (WeaponInfo StormBaton range 10, basic
    attack physical, no SHOT_FLIGHT, VFX weaponFX.StormBaton = swing arc + ImpactSplit, PunchHit; Items line magic =
    false, label "Baton"), skills BatonFlurry (Melee 3 hits, `slow` -> skillOpts.slow) + TrickVault (Dash) + MirageVeil
    + Tailwind; build DEX/STR/AGI/VIT, role Trickster. ThunderCall/CycloneCall (+ their SkillFX/icons) are kept for the
    Storm Caller job 2; DataService load renames saved ids (RENAMED map: skills + skillBar + classBars). Job 2 rule
    (owner): every path keeps one class-identity skill (navigation / ship repair / healing / food) + its own combat
    style. Classes.SecondJobs = the planned path ids. "Haki" is One Piece: any willpower system needs our own names.
    v0.25.52 (owner): Navigator stays INT: build INT/DEX/VIT, baton basic attack + BatonFlurry/TrickVault use MATK
    (magic), Baton item line magic = true. Solo boss sim (22 Nov): bosses take 2.5-33 min solo and kill in ~20 s.
  * v0.25.53 (owner): only the HELM fires cannons (server FireCannons checks Humanoid.SeatPart = HelmSeat; client
    Sailing input returns unless seated; Combat `atHelm()` replaces onShip(true) for click/E/F blocking, so on deck you
    fight normally). Sailing `drawAim`: trajectory preview from the guns the server would pick (dot > 0.25, best first,
    Manned count): 1 gun = 1 arc, more = the two outermost guns' parallel arcs; arc = VFX.Projectile's sin curve,
    height clamp(dist*0.12, 6, 40); yellow ready / grey reloading. Player volleys fly in parallel lanes (volley: target
    + gun offset from the group middle; NPC volleys still converge). Green firing-sector rings removed. A sunk ship no
    longer warps players home (call it again: MENU > Ships).
  * v0.25.54 (owner: reward sounds shrill; sail beep sounded like an alert): Rarity* no longer pitch up per tier,
    Sounds `warm = true` -> Audio.Play adds an EqualizerSoundEffect (High -14 dB) (Rarity*, ChestOpen, CardDrop);
    Rare+ `prefer` RewardRare / RewardLegend (ElevenLabs wavs in assets/sfx, NOT uploaded: Roblox audio quota spent
    until 2026-12-06 21:47Z -> `upload_sfx.py --user 1527424396 --only RewardRare,RewardLegend,ShipCreakLoop` then).
    Sailing: no ShipCreak on sail changes; `creak` = Audio.Attach("ShipCreakLoop") on your ship root while aboard,
    volume eased to 0.55 x clamp(speed*0.6 + |yaw rate|*1.6) (licensed rope creak 9118714001 until ours is uploaded).
  * v0.25.55 (owner reference): hotbar potion slots F1 HP / F2 SP (HUD itemSlots with `kind`, gear -> `Panels.Potion`
    {kind}: Auto or a potion tile + drag slider 0-95% step 5, 0 = off). settings.hpItem/spItem ("Auto" | consumable
    with heal/healSp) + hpPct/spPct (defaults 50/30, Combat.POTION_PCT), validated in SetAutoSettings. Combat
    PotionsOwned / PotionPick (Auto = smallest that fills the gap, else biggest) / UsePotion; autoPotion runs in EVERY
    mode (tick), never while Downed. Old autoPotionPct + Loadout quick items removed. Items RoastShank (HP M), SeaGrog
    (SP M), CaptainsKeg (SP L) in the General Store; pixel icons meat_s/m/l, grog_s/m/l (barrel tankards, owner
    reference), fruit_unknown (FruitAlert beacon marker + white glow aura, replaces the blue diamond).
    v0.25.56 (owner references): meat_s = round manga meat on the bone, meat_m = three drumsticks, meat_l = big roast
    with a marbled cut face (gen_pixel_icons meat_s/meat_m/meat_l + bone()).
    v0.25.57: SP icons sized by tier so they read without the letter: grog_s small tankard, grog_m upright barrel,
    grog_l big keg on its side (owner references). v0.25.58: meat icons sized the same way (S half the slot, M two
    thirds, L the full slot).
  * v0.25.59 (owner): held fruit = the ground model at native size (holdModel no longer ScaleTo 1.35; grip offset by its
    size). Fruit spawn alerts are Notifier-only again (server pushes Announce + FruitSpawn only to BoostActive "fruit"
    / tester; client beacon is raised from the push by finding the CursedFruit model near d.pos, no longer in dress()).
    Sonar = ONE looped Audio.Attach("FruitSonar") on a Terrain attachment kept 30 studs out toward the fruit (pans
    with the camera), volume x facing ((look.dir+1)/2)^1.5 x distance x fade envelope, high-cut EQ. FruitSonar prefers
    FruitSonarLoop (ElevenLabs, assets/sfx, upload after 2026-12-06 with RewardRare/RewardLegend/ShipCreakLoop).
    v0.25.60 (owner): beacon pillar / ripples / marker aura cycle a pastel rainbow (`prism(t)`), never the fruit's color.
    v0.25.61 (owner): FS.SpawnTreeFruit() has no tester bypass any more (Dev "spawnfruit" leaked the island in chat):
    only BoostActive(pl, "fruit") players get the island Announce + FruitSpawn push; v0.25.62 (owner): everyone else
    gets a chat Announce that a fruit appeared "somewhere in the sea" (no place, no FruitAlert).
  * v0.25.63: `Net.OnPush(kind, fn(data))` is now supported next to `Net.OnPush(fn(kind, data))`. FruitAlert
    ("FruitSpawn", since v0.25.33) and Combat ("SkillDash" since v0.24.15, "Knock" since v0.25.17) used the 2-arg form
    while Net only had the 1-arg one, so those handlers NEVER ran (Notifier showed nothing; dash skills never slid the
    caster; boss knocks never pushed). Store gem pill reads the live "Pearls" attribute (+ AttributeChanged).
  * v0.25.64 (owner: deep meme "gigachad" narrator): tools/gen_voice_elevenlabs.py = Adam (premade; library voices
    like "David - The Movie Trailer" return 402 on this plan) + ffmpeg DEEPEN (asetrate 0.86, atempo 1.08, bass, echo),
    line "Yes. A Cursed Fruit has appeared... on X. Go get it." -> assets/sfx/Narr_Fruit*.wav (upload after 6 Dec with
    the other queued sounds). Interim TTS in FruitAlert.speak: Pitch -6, Speed 0.9, same line.
  * v0.25.65 FRUITS v2 phase 1 (owner spec: docs/Plan-Fruits-v2.md, the source of truth for the fruit rework; never
    use One Piece move names). CombatService `fruitBody` (in MonsterHit): Logia Blaze/Haze ignore monsters without
    `def.toki` (Monsters: MistCommodore, MarineElite), Bounce reflects "shot" blows back (MS.Damage on the shooter),
    Split ignores "slash"; `monsterDmgType(def)` = def.dmgType or MonsterLooks held weapon (Rifle/Pistol shot,
    Cutlass/Claws/BattleAxe/Trident slash, else blunt). Charge skills (`charge = true`): client startAim keeps t0 +
    VFX.Charge on the hand, CastSkill(id, target, aim, charge 0..1) sends `charge` (Auto = 0.25), server mult x (1 +
    CHARGE_BONUS 0.6 x charge), CHARGE_TIME 1.2 s. AoE / GroundAoE `ticks` + `tickEvery` (+ `delay`), Ranged `pull`
    (MS.Knockback toward the caster). New ids F_RecoilCannon, F_Emberflies, F_SmokeFist, F_SplitRunner (FruitFX
    aliases until their own pass); DataService RENAMED maps F_FireDash/F_SmokeBody/F_SplitEscape on hotbars. Ward is
    shown as "Shield Shield no Mi" (id stays Ward). Next phases per fruit: Bounce -> Blaze -> Haze -> Shield -> Split
    -> Slick (anims, FX, Slingshot Launch, Blaze flight, barrier stairs, Slick skate, channel wall/dome).
  * v0.25.66 FRUITS v2 phase 2 = Bounce: skills name clips with `anim` and `chargeAnim` (looped by Combat startAim
    while the key is held, stopped with a 0.2 fade into the release clip). AnimClips Bounce_* (Wind/Pistol/Gatling/
    WindBoth/Cannon/Balloon/PumpUp/SlingGrab/SlingFly, uploaded). FruitFX `RubberArm` (skin-colored block chain from
    the elbow to a fist/palm tip: out, hold or math.huge until `release()`, wobbly snap back) + `HideArm(char, side,
    seconds)` (LocalTransparencyModifier on the VoxelBody blocks welded to that forearm/hand; 0 = show now) +
    `SkinOf(char)` (hand block color). Balloon Body = welded voxel shell `GVBalloon` on UpperTorso; Pump Up = red
    Highlight `GVPumpUp` + steam. Skill fields `hitEvery`, `splash` (extra hits around the target / path width),
    `knockDist` / `knockPower`. CombatService.HasBuff; fruitBody: Balloon reflects blunt too (not bosses), FX-only
    "Skill" id F_BalloonBounce (CharAnim ignores Skill FX whose id is not a real skill). `Controllers/Slingshot` =
    Slingshot Launch (RMB aim, LMB grab, release = LinearVelocity arc; hotkey "Sling" U; Combat LMB ignored while
    Slingshot.Busy()), server `Sling` request (grab/go/cancel, Fruits.Slingshot) + FX "Sling" for other clients' arms.
    Pose previews without Studio/Blender: `lune run tools/export_pose.luau build/GrandVoyage.rbxlx x.json Clip@t ...`
    + `python3 tools/render_pose.py x.json out.png` (FK on VC.Rest; VC.Preview blocks carry attribute Limb).
  * v0.25.67-68 (owner): Stats table = points pill + "Reset Stats" (StoreBuyRobux ResetStats prompt), BASE white /
    BONUS green / NEXT COST yellow, fixed row layout (ROW0/ROWH, the footer no longer covers LUK). Bag + Stats
    character panels use Panels `classStage(panel, stage)` (Job Master look: class gradient, water below the horizon,
    CLASS_FX sparkles; CharacterView opts `plainLight` = no tint on the character, `tint` = initial water tint;
    returns refresh, setClass). Bag stall button = "🏪 OPEN STALL" under the detail card (EMOJI_ICON 🏪 = stall).
  * v0.25.69 (owner): Bounce PUMPED = Pump Up (F_GearUp) running (CombatService.Pumped / client Combat.Pumped via player
    attr PumpUntil in server time): skill `pumped` table overrides fields (setmetatable over the skill), strikes /1.6
    (fxData.speed -> CharAnim plays the clip faster), Ranged travel 0.06, cd x0.6, client charge 0.6 s; Pistol `line`
    (hits along the path). FruitFX `AirBlast`, Gatling = many RubberArms (`seg` opt). Slingshot pumped = straight
    rocket (Fruits.Slingshot PumpSpeed/PumpLift/PumpMult), server Sling "go" hits along the path. Fruit stat bonus:
    fruit `stats = { main, second }`, `Fruits.StatsFor(id, mastery)` (Main +1/10 Mastery max 10, Second +1/20 max 5)
    added in Formulas.Compute; `Formulas.StatSources(profile)` feeds the Stats BONUS tooltip. Toki (our "haki":
    Armament / Observation / Conqueror Toki, never the word Haki) spec: docs/Plan-Toki.md (not built yet).
  * v0.25.70 Toki (docs/Plan-Toki.md): `Config/Toki` (Kinds, Colors, Bonus, Conqueror Calm/Cow, Skills class "Toki"
    merged into SkillById, Unlock numbers for sea 2) + `Services/TokiService` (p.toki = { rolled, Conqueror = { color,
    advanced } }; 0.1% roll on DataService.Loaded per slot, Grant/Remove, CanSlot, Roar; attrs Toki / TokiColor_<Kind>).
    Formulas.TokiStats (Compute + StatSources), Formulas.Power(d, lvl) / MonsterPower(def) (PlayerService sets attr
    Power); MonsterService findAggroTarget skips Conqueror players with Power x Calm above the mob's (cowedBy), MS.Cow.
    CombatService kind "Roar" (skill.toki gates lv; no Skill FX, TokiRoar FX instead -> Controllers/TokiFX). Skills
    tab tier "Toki"; Stats left panel shows Power + Toki names in their color; Dev tab Toki buttons; Admin `toki`
    "Kind[:PlayerName]" / "none[:PlayerName]".
  * v0.25.71 (owner): HOTBAR = SKILL SETS (`Shared/Modules/SkillSets`: Sets Class / Fruit / Basic / Armament /
    Observation / Conqueror; Skills(p, n) -> { skill, ready } auto-filled from the class / fruit / Common / Toki skill
    lists, max 6; Open(p, n); Id(p, n, i); Auto(p, n) = settings.autoSets[n] ~= false). Hotkeys Set1-6 = keys 1-6
    (Combat.SetActiveSet; State.activeSet saved as Settings.Values.activeSet, default 3 = Basic), Skill1-6 = E R F Z X C
    cast Combat.BarId(i). HUD: main row = set buttons (gold = active, dim = locked, green dot = Auto), row above =
    the set's skills (always shown, no expand button). Auto Battle casts every ready skill of the Auto-on sets
    (autoSkills ticks are no longer used). Skills window tab "Sets" (renderSets: USE + AUTO ON/OFF per set; the old
    Loadout + drag-and-drop code is gone). Server SetAutoSettings `autoSets` (6 booleans). Set 3 becomes weapon arts in sea 2.
  * v0.25.72 (owner): Toki colors in the Store (Benefits `tokiColor = kind`, products 3734898364 Conqueror 129 R$ /
    3734897888 Armament 79 / 3734898118 Observation 79; Gems 320/200/200). StoreService grant sets
    p.tokiColorPick[kind] + push "OpenPanel" TokiColor; uselessNow(it, to) refuses without that Toki / when owned.
    `Panels.TokiColor(args.kind)` = tabs per owned Toki, preview, color wheel + brightness + Toki.Colors swatches,
    SAVE -> TokiService "SetTokiColor" (#RRGGBB, needs the unlock); locked = Gems / R$ buy buttons. Stats 🎨 button.
  * v0.25.73 (owner reference): Store = ONE scroll of sections (Gem Packs / Gem Shop / Benefits / Boosts) with
    headers; top tabs tween CanvasPosition to `sectionY[tab]` and light up from the scroll position (syncTab). Cards
    are built once per render: a click only re-highlights (rim) + redraws the detail panel (the old full re-render
    jumped the scroll to the top); `relayout()` sizes cells from the scroll's real width (100-px probe for the UIScales)
    on every AbsoluteSize change (first measure during the open tween gave 2 columns). Owned Toki colors: CHANGE COLOR.
  * v0.25.74 FRUITS v2 phase 3 = Blaze: AnimClips Blaze_Wind/Fist/Twister/Ember/Inferno (uploaded; Fist charge like
    Bounce), FruitFX F_FireFist (giant fist on the server's strike+travel), F_FlamePillar = spinning block funnel for
    the 5 ticks, F_Emberflies = 9 green fireflies that hover then burst orange per tick, F_Inferno = rising rings of
    fire blocks, `ArmFlame`. Blaze Flight: Flight.Allow("blaze") when Fruit == Blaze; Flight start/stop -> server
    "FlyState" (FruitService) -> char attr Flying; FruitFX.Start loop `dressFire` hides the lower-limb voxel blocks and
    adds px_flame emitters on every client.
  * v0.25.75 (owner: manual first, M1 rhythm matters): `WeaponInfo.M1[wType]` = { quick, finish, reset, shape }
    (norm makes plain-mashing DPS equal for every weapon: 1.1 x interval), `M1Mult(wType, n)`, `Rhythm` { Window 0.28,
    Perfect 1.2, Flawless 1.5, Link 1.25, LinkWindow 0.7 }. Server m1Gap/comboStep use the weapon's tempo; Attack
    `perfect` (client claims, server checks the hit came within gap + Window + 0.35) and FLAWLESS (perfect hits 2-4 ->
    finisher x1.5, knock 9 / power 2.4); BasicAttack FX perfect/flawless -> gold/pink flash for all. Client
    Combat.NotePress (fresh click / tap / attack button; an early press = no perfect next) + m1Swing(interval) returns
    perfect, flawless + `Combat.RhythmPop`; hold-repeat swings never perfect. CastSkill LINK: damage skill within
    LinkWindow after the 4th hit -> mult x1.25 + push "Link". Class skill cooldowns retuned (Classes.lua).
  * v0.25.76 FRUITS v2 phase 4 = Haze: clips Haze_Grip / Haze_Screen / Haze_Vanish (uploaded; Smoke Fist uses Blaze_*).
    Smoke Screen `smoke = 6` -> CombatService smokeZones (MonsterHit: a mob inside misses 50%, "LOST IN SMOKE").
    White Out (AoE `vanish`) sets player attr Invulnerable for the vanish (VanishAt stamp) and FruitFX vanishChar hides
    the caster on every client while a smoke twister follows the root. Smoke Grip FX = a snaking block arm + coil.
  * v0.25.77 (owner playtest): M1 CLEAVE (CombatService CLEAVE per melee weapon, up to CLEAVE_MAX extra targets in a
    front arc within reach). Beat cue: Combat m1Swing schedules a yellow outline Highlight ("BeatCue") on the target
    when the next hit's PERFECT window opens; perfect hits mark the target PerfectUntil (local attr) -> CreatureAnim
    flash turns yellow. Knockback + skill dashes use LinearVelocity Vector mode with Y clamped <= 0 (no more "launched
    into the sky": Smoke Grip pull, Trick Vault); MS.Knockback(mob, from, dist, power, durOverride). Navigator M1 =
    Baton_Smash1/Swing2/Rise3/Slam4 (two-handed club, VFX no slash arc), BatonFlurry = Baton_Twirl (hitEvery 0.22),
    TrickVault = Baton_Vault. Sea Cook HeatedLeg id = "Tabletop Tempest" (AoE 8 ticks, Cook_Tempest handstand spin);
    HeartyMeal = PartyBuff foodHeal (InventoryService multiplies heal / healSp). Skill `stun` (MS.Stun "DAZED"),
    SmokePellet stun + smoke zone + lingering SkillFX.Smoke (d.smoke). Doctor Adrenaline `syringe` (fxData.allies ->
    VFX syringes), BurstTonic = GroundAoE + delay 0.3 + SkillFX.Tonic thrown flask. Skill `travel` overrides the Ranged
    flight. Blaze Inferno = charged Ranged fireball (Blaze_BallCharge / BallThrow, FruitFX.ChargeBall over the head
    while held, F_Inferno flight + sea of fire, splash 14); Emberflies fx "None" (the shared Explosion's dark debris
    was the "black things"), sparks leave the chest and cling to monsters near the spot. Haze flight (Flight.Allow
    "haze"); FruitFX dressFire(kind) = Haze smoke legs + smoke line trail; fly loops BlazeFlyLoop (9112780193
    fireplace) / HazeFlyLoop.
  * v0.25.78 (owner): skill `split` ("h"/"v": OniSlash v, TornadoCut + FlyingSlash h) -> hitTarget sets mob.splitKill /
    splitDir -> MobDeath FX split -> CreatureAnim.SplitDeath (cut line, halves slide apart, then CreatureAnim.Shatter).
    Sounds SliceCut (Sword hits), HammerThud (Hammer hits), CannonBlast (ProSoundEffects ids; our audio upload quota is
    spent until 6 Dec). CannonDrop = two-hand throw (Blaze_BallThrow, delay 0.35, SkillFX.CannonThrow). Hammer icon
    redrawn centred (gen_skill_icons.hammer, shared by the pixel icon).
  * v0.25.79 FRUITS v2 phase 5 = Shield: skill kind "Channel" (shape Wall/Dome, sp start, spPerSec, maxHold, mult,
    pushRadius/radius, anim loop + releaseAnim). Server CombatService ChannelStart/ChannelEnd (channels[player], drains SP
    every 0.25 s, char attrs Channel/ChannelR, release = hits + knock in front/around + FX "<id>_End"), CastSkill
    refuses Channel; MonsterHit `barrierBlocks` (Wall = holder's front, Dome = victims inside from mobs outside) ->
    "BLOCKED" + F_BarrierBlock FX. Client Combat.ChannelStart(id, keyCode)/ChannelEnd (key up, IsKeyDown check, server
    attr gone; taps/Auto hold Fruits.Channel.TapHold). FruitFX dressBarrier (every client, from the attrs), release FX,
    Barrier Steps = local collidable "BarrierStep" panes under the feet at each jump apex while Space is held
    (Fruits.BarrierSteps MaxSteps/Life) + server "BarrierStep" -> FX for others. Clips Shield_Hold / Shield_DomeHold.
  * v0.25.80 (owner playtest): Skill FX get `strike` / `travel` (Ranged flight or GroundAoE `delay`) / `splash` from the
    server, so projectiles land with the hit. Sharpshooter musket SkillFX Musket / MusketBlast (BlazeShot splash 10) /
    MusketSmoke (SmokePellet delay 0.25); sound MusketShot. Doctor M1 = thrown voxel powder pouch (weaponFX.MedKit);
    Adrenaline halo of blocks = range (fxData.radius). SkillFX.Tempest (Tabletop Tempest wind). CombatService applyDot
    -> FX "Burning" (flames / green fumes on the mob for the dot). HeritageAnim BlkFlap only for real wings and never
    while a Blaze/Haze user flies. Haze flight hides the whole legs; Smoke Screen = Blaze_Fist punch + delay 0.3, cloud
    on landing. Emberflies heat green -> orange before each burst; Inferno ball ~2.4x, splash 18. Split deaths =
    LOCAL physics halves (one invisible box collider per half on its side of the cut, visible clones welded massless),
    originals hidden, fade at 2.4 s (no shatter). Shield: F_BarrierBash = "Ward Pistol" (glass orb + rings on the
    fist, knock 12); F_BarrierCrash -> F_GlassStairs "Glass Stairway" kind "Stairs" (Combat.StairsStart: hold + drag
    the pointer, local collidable steps via FruitFX.StairStep, batches -> server StairsStart/StairStep validate chain +
    reach -> FX F_GlassStairs_Step = everyone builds collidable copies; Fruits.GlassStairs Run/Rise/Width/Life/Reach;
    DataService RENAMED). Never "Barrier Crash"/"Barrierbility" (One Piece). Barrier = clear Glass panes + glinting
    diagonal streaks (FruitFX clearPane); Dome = hemisphere on the ground, full sphere in the air; server shoves
    non-boss mobs out of the dome every 0.25 s. Conqueror's Roar: 2.5 s aura (bolts, pixels, light) + RoarBurst1-4 by
    UserId % 4 + RoarArcLoop. Hammer icon drawn from the handle direction, fully inside the tile.
  * v0.25.81 (owner): ONE ammo = Musket Ball (Config/Ammo List = Musket, Legacy = old shots kept as sellable items,
    Starter 300 via CombatService.MusketStarter on load / first shot, p.musketStarter); out of balls = no M1 shot; humanoid
    monsters drop Ammo_Musket (Monsters.lua from MonsterLooks; HeldRifle/HeldPistol more); HUD ammo button = count only;
    weaponFX.Slingshot = musket ball + MusketShot. Voxel monster faces are Decals on Transparency-1 plates: CreatureAnim
    `seen`/`hide` include + hide them (faces floated after death). Roblox's camera resets LocalTransparencyModifier on
    your own character: FruitFX re-hides dressFire blocks every RenderStepped. Flying Slash `line` 6 + `pierce` (full
    range). Ward Pistol = charged Ranged `firstHit` (bursts on the first target or at range; FX.HoldOrb while held,
    glassOrb). Glass Stairway runs on SP (`spPerStep`, server per step) and steps hurt monsters (st.hit once each).
    Dome = voxelDome (glass cubes welded to one anchored hub) + server Heartbeat holds non-boss mobs at the rim (no
    shove). Barrier Steps use clearPane. Inferno = voxelFireBall (shell of churning cubes + px_flame emitter, BulkMoveTo)
    + billowing landing. Roar aura = rim ring + shocks every ~0.2 s across the radius, RoarArcLoop volume/pitch envelope.
  * v0.25.82 FRUITS v2 phase 6 = Split: FruitFX `limbPieces(char, limbs, seconds)` clones the VoxelBody blocks welded to
    those limbs (decals kept), hides the originals (hiddenUntil, re-hidden every frame) and returns g.move(cf)/destroy.
    F_SplitCannon "Rocket Forearm" (charged Ranged, travel 0.25, arm flies + returns), F_ChopRush "Phantom Hand"
    (hand + knife stabs from behind, hits 4 / hitEvery 0.18), F_SplitRunner (legs wheel along the dash), F_SplitFestival
    "Scatter Storm" (every piece orbits). Never "Split/Chop Cannon" or "... Festival" (One Piece Bara Bara moves).
  * v0.25.83 (Output errors): Combat.Start's mouse-hold flag is `mouseHeld` (a local named `holding` shadowed the
    module aim state, so skill key-up indexed a boolean and held aims never cast on release). WorldCull.show pcalls
    the re-parent (a stashed part destroyed meanwhile has a locked Parent and aborted the whole island).
  * v0.25.84 FRUITS v2 phase 7 = Slick (all 6 fruits done): clips Slick_Crouch (charge loop) / SlidePunch / Spin
    (handstand) / Pour / Skate in AnimClips (NOT uploaded yet: no lune/python on the owner's PC; runtime
    KeyframeSequenceProvider fallback works in Studio only). Slick Slide charge stretches the Dash range (0.7-1.3x).
    Oil Slick `oil = 7` -> CombatService oilZones (`inOil`): non-boss mobs inside are slowed (Fruits.SlickSkate OilSlow,
    `slowMob`) and miss with OilSlip ("SLIPPED!"). FruitFX: oilPool/oilDrops/oilSplash, `ChargeOil` (Combat startAim on
    chargeAnim Slick_Crouch), GVSlick Highlight for Slip Away. Slick Skate passive = FruitFX skateLoop: jump + hold Space
    (or Humanoid.Jump on touch) -> LinearVelocity skate (Speed 34, 46 on oil, Y <= 6 so ramps work), stops on walls,
    oil trail tiles; server "SkateState" -> char attr Skating -> other clients draw the trail.
  * v0.25.85 (owner approved previews): new fruit_v2 "ward" = round shield (lens front, blue rim, gold rivets, raised
    overlapping hex glass plates) and "split" = three slanted slices drifting apart (lilac flesh, rind, seed ring)
    in tools/blender/voxel_pets.py; GLBs uploaded in v0.25.103.
  * v0.25.86 (owner): hunts pay out inside ProgressService.Event (payHunt) and restart, no claim (HuntClaim kept for
    saves already full); Quest.lua HuntCard suggests the toughest unlocked island monster (NEW tag + START).
  * v0.25.87: menu logo = `tools/gen_logo.py` (own bitmap font + ship's wheel) -> GameConfig.LogoImage, drawn on a
    SurfaceGui board behind the character in Menu stepCamera (title screen only). Image upload WITHOUT an API key:
    serve assets/ with `python -m http.server 8765 --bind 127.0.0.1`, then Studio MCP `upload_image` with
    `http://127.0.0.1:8765/<path>.png` -> rbxassetid (Blender's python + PYTHONPATH %LOCALAPPDATA%\gv-pylib has PIL).
  * v0.25.88: pixel icons toki_arm / toki_obs / toki_conq (HUD SET_ICON), fruit_ward / fruit_split redrawn.
  * v0.25.89 (owner): `Controllers/Sprint` double-tap W (GameConfig.Sprint), WalkSpeed = player attr BaseSpeed
    (PlayerService) x Mult; Swim restores to BaseSpeed. F_SlickSpin = 8 ticks (Slick_Spin clip 8 x 120 deg).
    Slip Away buff: CombatService fruitBody ignores non-boss "blunt" monster blows ("SLIPPED OFF").
  * v0.25.90 (owner): TCG card face = `UI/CardArt.lua` (Build / Fitted; POWER = Formulas.MonsterPower, MonsterTypes
    badge, manga panel `Textures.card_manga` from tools/gen_card_art.py tinted by rarity, `UI.MonsterView` = the real
    voxel MonsterLooks model, effect box + slot, foil sweep), used by CardReveal and the Bag card detail.
  * v0.25.91 (owner): monster faces by kind: gen_faces.py eyes Thug/Stern/Beady/Crazed/Feral, mouths Snarl/Scowl/
    Painted, full-face `mark` overlays (Scar/Stubble/ClownPaint/WarPaint/Gills/Whiskers, Config/FaceImages mark*);
    MonsterLooks per-id eyes/mouth/mark/eyes1/eyes2; VoxelChar keeps look.mark through Looks.Sanitize. Re-running
    gen_faces.py rewrites old PNG bytes: `git checkout -- assets/faces` and keep only the new files.
  * v0.25.92 (owner): `UI/ItemReveal.lua`: Rare+ drops (Epic+ for Material/Consumable/Ammo, never cards) play a
    full-screen "<RARITY> GET!" (rarity wash, rays, 3D preview, CardBass + Rarity<id>), queued, tap skips; HUD.Loot.
  * v0.25.93 (owner): shipyard = `Controllers/Builder.lua` rewrite: own ScreenGui GVShipyard, UI.Root hidden, Scriptable
    free camera (RMB drag / wheel / WASD QE, clamped around the plot; CAS sinks movement + skill keys), left panel with
    HP / SPEED / CANNON / CREW (no weight), PLACE / DELETE modes (R rotate, X delete), category icon tabs, part cards
    (UI.ModelViewOf of ShipModel.BuildPart + cost chips, red = short), MATERIALS owned. Client canPlace mirrors
    BuildPlace for the ghost color + reason; delete = red Highlight on the `Index` model inside Build_<name>, click ->
    BuildRemove. Right click never deletes. GameConfig.Ship.WeightDrag 0.04 (was 0.085: sails matter more).
  * v0.25.94 (owner): Knuckles previews = `UI.FistModel()` (bare fist + tape wraps in blocks; UI.ModelView intercepts
    Weapons/Knuckles). The Wep_Knuckles glove mesh is no longer shown anywhere.
  * v0.25.95 (owner): card icons by monster type: gen_pixel_icons `type_card` -> card_STR/AGI/DEX/INT (Config/Icons);
    ItemDB card items carry `mtype`, UI.ItemIconName returns card_<mtype> for cards.
  * v0.25.96 (owner): Menu buildStage remodel: `barrel(cf, k)` (octagon slices bulging in the middle, iron hoops, lid)
    x2 + a keg on its side, rowboat (tapered rows, stripe, flush rails, floor, thwarts, oars, mast + furled sail +
    pennant). Preview without Play: loadstring the block..lookKey chunk of the synced Menu source in Studio Edit.
  * v0.25.97 (owner): one pixel icon per weapon grade `w_<WeaponType>_<Grade>` (gen_pixel_icons WEAPON_GRADE_ICONS,
    picked first by UI.ItemIconName for weapons); UI.ModelView("Weapons", "Shoes") returns nil (bare legs, callers fall
    back to the voxel icon); materials wood_gold / shard_pure / badge. Render a few icons without rewriting the rest:
    import gen_pixel_icons and call render(name) for just those names.
  * v0.25.98 (owner): `UI.WeaponView(parent, def, size, spin, props)` = the grade voxel icon (w_<Type>_<Grade>) for
    weapon previews (Bag, ItemReveal, Blacksmith), Wep_ mesh only without a grade icon. Held weapons are unchanged.
  * v0.25.99-100: title menu UPDATE LOG lines = `GameConfig.UpdateNotes` (box grows), tab labels sized by the square
    pixel font (UI.TabBar: width = icon 42 / plain 20 + chars x size), potion % left of the gear.
  * v0.25.101 (owner): Store detail = UIListLayout with the stage as `UIFlexItem` Fill (buttons/notes keep their height,
    the stage shrinks), store cards = one centred column; Toki Color benefits use toki_* icons; Bag egg tiles =
    UI.VoxelEgg; Pets empty state + Egg Odds cards; renderHunts measures height with a 100-px probe (UI.GetScale
    misses the full-screen window UIScale). UIListLayout without SortOrder sorts by Name: always pass LayoutOrder.
  * v0.25.102 (owner): acc_SailorVest is hand-drawn (gen_pixel_icons `sailor_vest`; gen_acc_icons HAND skips it).
    Cutlass guard + knuckle bow lie in the blade's plane (bow on the edge side, -z) in voxel_weapons sword() /
    sword_sheathed(). Models can be uploaded through Studio MCP `open_cloud_invoke` POST /assets/v1/assets (files
    fileContent .glb, then poll GET /assets/v1/operations/<id>); the owner approved assets/models3d (v0.25.103: new
    Wep_Sword / Wep_SwordSheathed + Fruit_Ward / Fruit_Split ids in Config/Models).
  * v0.25.104 (owner, docs/Plan-Weapons-v2.md = weapon ladder + roles spec): swords are BLOCK models built at runtime
    by `Shared/Modules/BladeModel` from the item's `blade` spec (form Katana/Cutlass/Wooden, shape, hilt = guard style,
    colors) in the old Wep_Sword frame (length Z, tip -Z, edge -Y, grip pivot; sheathed/scabbard center pivot).
    WeaponService mounts them (char attr WeaponItem), UI.WeaponView / Bag tiles / CharacterView show them. Items:
    `blade(id, name, tier, spec)` tiers Fathom (green, Forty Fathoms) / Tide (blue, Twenty Tides, boss drops) /
    Awakened (purple, Whitevow only); ItemDB.Blades[tier] lists ids. Never One Piece blade/grade names. Offline
    preview: tools/blade_preview.py (Python mirror, keep in sync) + render_parts.py.
  * v0.25.105 (owner): ASCEND = Blacksmith tab "Evolve" for every weapon type (GameConfig.Ascend: From Uncommon,
    MaxRarity Rare this update, NeedRefine green 10 / blue 12 / purple 15 / gold 15, Cost per rarity). Saved as entry.asc
    (steps); `ItemDB.ForEntry(entry)` = the def one rarity higher per step (ATK/MATK x(1 + 0.6 asc), lean stats +asc,
    slots +asc): use it instead of ItemDB.Get(entry.id) for bag entries. `ItemDB.AscendInfo`, server `Ascend` (refine -> 0).
    Items GREENS = 2 Uncommon weapons per other class (ItemDB.Greens). Owner: ladder names (Forty Fathoms ...) only in
    the Index; every other screen shows the rarity (Common .. Secret). Dev "New Weapons" (`weapons` cmd) grants them all.
  * v0.25.106 (owner): no Evolve tab: Forge shows the refine track (pips up to NeedRefine of an evolvable weapon, else
    Refine.Max) + "then EVOLVE to X"; at the top the button is EVOLVE (server Refine refuses past it). Forge/Cards draw
    into a 560x600 column with a UIScale fitted to the stage (100-px probe for the window UIScale). No sunburst behind
    the item. FORGE/EVOLVE play `UI/ForgeScene` (3 s ViewportFrame: still copy of the nearest Blacksmith NPC, tags/
    prompts stripped, `NpcLife.Rest` first; right arm + block hammer swung around the shoulder, 3 strikes = AnvilClang +
    neon sparks + shake), the server result shows after it.
  * v0.25.107 (owner): Tavern Keeper stands beside the Shipwright on every island (WorldBuilder shipyard group, turned
    with it; Daybreak at the east harbor); standardNPCs / ConchBay / Marmalade no longer place one. WORLD_VERSION 23.
  * v0.25.108 (owner): players see **Crew**, never "Guild" (code, saves, DataStore, Net names keep Guild*). Forming a crew
    picks no side; faction is per player (p.faction, attr Faction): `SetFaction` Marine/None only at the Marine Registrar
    (role "Marine", Conch Bay quay, Panels.Marine), Pirate from the Crew window (not while Marine; Lv GuildCreateLevel).
    `CrewInvite` { name } -> Prompt kind CrewInvite -> `CrewRespond`; crewmates auto-party (`PartyService.Join`) on load
    and on joining. No Guild Registrar NPC any more. WORLD_VERSION 24.
  * v0.25.109 (owner): no island name signs (dock signs removed, floating banner already off); `Controllers/IslandEnter`
    shows UI.Banner(name, subtitle + level range) when your character enters an island radius (again after 90 s away).
  * v0.25.110 (UI audit in Play): HUD.MENU entry = { icon, panelId, color, key, label }: Crew is { "🏴", "Guild", ..., "Crew" }
    (108 swapped them: tile + G opened nothing). UI.TabBar fits its row to the parent width (UIScale, 0.5..1). UI.Tooltip
    skips HUD objects while a window is open and drops the tip when its owner is hidden/removed. Map tiles 110x96 in an
    inner sea frame (labels are tile children, z spread over the farthest island). Studio MCP mouse coords = GUI
    AbsolutePosition (screenshot y - 58 here; window X buttons sit at negative y, clicks there still work).
  * v0.25.112 (owner): shop NPC walk-in rings: `WorldBuilder.ZONE_ROLES` (Blacksmith white-gray, Shop blue, Tavern pink,
    Shipwright green; ZONE_RADIUS 7) colors their glow disc, sets model attr ZoneColor and disables their Talk prompt;
    `Controllers/NpcZones` draws the neon block ring and sends `ZoneEnter` { role } on entering (retries 2 s: the server
    may still see you outside), server WB.NearNPC check -> shared `talkTo` (QuestService.OnTalk + OpenUI). Interact
    colors zone NPC plates and keeps their name up from afar. Other NPCs keep the prompt. Tavern Keeper sits 6 studs
    further from the Shipwright (rings overlapped). `World/DeFlicker.Run(world)` after Voxelize: coplanar same-facing
    overlapping Part faces get lifted STEP 0.04 per stack level (bigger face stays); ~1 s for the whole map. Keep it fast:
    Instance reads in hot loops/sort comparators and 16-stud grid cells made it 20 s and hit the server script timeout
    (Init aborted). Mesa grass caps 0.08 apart per lobe; VoxelChar OverallButton clears the Armor Vest plate.
    Quest guide = "Rowan"; Daybreak house sign "BLACKSMITH". `musket_ball` pixel icon (gen_pixel_icons lead_ball,
    IconVoxels) for Ammo_Musket; Blacksmith showcase shows blades as their pixel icon. WORLD_VERSION 26.
  * v0.25.113 (owner): HUD card = square level ring (buildRing squarePoint path), height HUD.cardH (106, 128 with boosts),
    Class/EXP lines Display font centered over the bars; `UI.Halftone(parent, color, {cells, size, pos, z})` = solid
    pixel-square wave burst (returns holder, setColor) behind the portrait (class color) and the style meter (rank color).
    Ship HUD (Sailing buildHud) 340x220 above the card: name, HP bar, SPEED/WIND/SAILS/GUNS cells, zone chip, reload bar,
    SAIL-/SAIL+/FIRE/DOCK. No Bay Serpent buoys/sign. `Controllers/BossIntro`: first time within 90 studs of a boss
    (risen sea bosses only): name slams center -> glides up -> bar slides in + fills from 0 -> BossRoar + rumble -> music
    (State.bossIntroUntil mutes Sailing.updateAudio, State.lastBoss starts MusicBoss). Shipyard plots = WoodPlanks + rails.
    Kit.Barrel = menu voxel barrel, Kit.Crate = framed crate (same single rng call). Chests (WorldBuilder chestModel):
    voxel box + trim bands, `Lid` Model with attribute Hinge (back top edge), `Lock` Model, gold `Hoard` inside; FX
    ChestOpen { model, id, by } -> VFX: padlock tumbles off, lid swings 105 deg, 16 local physics coins; non-openers see it
    close again; Quest.paintChests snaps the open pose after 2 s unless LidOpen. WORLD_VERSION 27.
    v0.25.114: sea bosses carry model attribute SeaState (hidden/rising/fight/diving, MonsterService seaInit/seaStep);
    BossIntro plays for them on rising/fight within SEA_NEAR 320 (flat), a failed intro (pcall) never leaves the music
    muted; the intro root frame is anchored top-center (its UIScale shrank toward the top-left = name off-center).
    v0.25.115 (owner): no Bell on SummonShip; sea-boss Telegraph FX carry `sea = true` (no BossRoar), SerpentSpit ->
    `WaterGush` (ProSoundEffects Water Hose Gun 3). DeFlicker: buckets by direction, stacks split where planes are > GAP
    0.12 apart, Grass faces first then biggest, same material+color overlaps ignored, each face climbs past every covered
    face within STEP of its target (sorted sweep, MAX_LIFT 0.32). WORLD_VERSION 28.
    v0.25.116 (owner): every Music entry in Sounds.lua x0.6. Owner screenshots with the Roblox top bar = the PUBLISHED game
    (check the version bottom-right); fixes reach it only after File > Publish to Roblox.
    v0.25.117 (owner): no Bell on DOCK either (Bell now only rings for party/duel/crew prompts).
    v0.25.118 (owner): no Bell on invite prompts either. `Controllers/PowerBoard`: local wooden board (13x16, SurfaceGui
    22 px/stud, PxKeep) right of every BossBoard NPC = top 50 players in the server by the Power attribute, refreshed
    every 3 s. Job Master = ZONE_ROLES red ring + NPC_LOOK["Job Master"] (crimson Captain Coat, white swept hair, scar,
    voxelHat "master" = red headband with tails). WORLD_VERSION 29.
    v0.25.119 (owner): Daybreak BossBoard at onPlaza(-2.7, 50) (in front of the small west-street house). PowerBoard
    SurfaceGui ResetOnSpawn = false (a PlayerGui gui is wiped when the character spawns: blank board in the live game).
    HUD status card x 60 / width 460 with content at x 110: it tucks under the ring (ring in front). WORLD_VERSION 30.
    v0.25.120 (owner): the Daybreak Power board is a map piece (Model tagged PowerBoard, part "Board", left of the
    Bounty Board NPC); Controllers/PowerBoard dresses tagged boards, builds a local one only for BossBoards without one.
    MAP IN STUDIO EDIT (owner wants to see/move things): after a WORLD_VERSION bump, Stop Play, check the Edit source
    synced, then execute_luau (Edit) `require(game.ServerScriptService.Server.World.WorldBuilder).Build()` (the MCP call
    may time out but finishes; check workspace.World WorldVersion), owner saves. Play then keeps it ("built in 0.02s").
    The owner's moves in Studio are lost at the next WORLD_VERSION bump: read their positions from Studio into World/*.lua
    first. Edit shows placeholders (Env meshes, plants, monsters are dressed only at runtime). WORLD_VERSION 31.
    v0.25.121 (owner): level ring = SEGMENTS 13 equal 13x13 square cells per half on one pitch (2h/8): 1 bottom cell by
    the badge, bottom corner, 7 up the side, top corner, 3 along the top. HUD close-up check in Play: multiply the ring
    frame's UIScale by ~3 from execute_luau (Client) and screen_capture.
    v0.25.122 (owner): ring h = RING_SIZE/2 - 18 (cells 12x12, pitch 14) hugs the gold portrait frame; card content x 96.
    v0.25.123 (owner, Plan-Weapons-v2 sec 0): General Store first card = Mystery Blade (GameConfig.BladeRoll Fee /
    TideChance / Seconds): `BladeLook` (near Shop, pays Fee, random id from ItemDB.Blades Fathom or Tide, kept per player)
    -> Panels.BladeOffer (ItemReveal for Rare, WeaponView, BUY `BladeBuy` = def.price / PASS `BladePass`).
    v0.25.124: MonsterService rollDrops also rolls a blade (GameConfig.BladeDrop: Fathom from mobs >= MobLevel at
    MobChance, Tide from isBoss at BossChance, x drop mult; boss blades Announce).
    v0.25.125: a bash heredoc turned "\n" into a real newline inside a Lua string -> Panels.lua failed to load = no menu,
    no HUD, plain avatar. Write Lua through files/Edit, never through shell-escaped strings, and read Output after sync.
    v0.25.126 (owner): UI.ModelViewOf spins models around their bounding-box middle (blades pivot at the grip);
    Blacksmith gear list keeps CanvasPosition across render(); fullscreen windows open FRAMED by default
    (UI.FullPref default true only for PearlShop; Job sets its own); Greenhorn title shows as "Larper" (id kept).
    v0.25.127: Panels.Index (MENU entry "Index"): tabs Blades (ItemDB.Blades by tier, FOUND = p.index.blades or in
    the bag) / Monsters / Bosses (Islands spawns + boss, p.index.kills from MonsterService die). Profile push sends
    `index`. No onProfile re-render (kills would rebuild every viewport).
    v0.25.128: Index blade cells = UI.WeaponView with ImageColor3 black until found (no stats shown).
    v0.25.129 (owner, Plan-Weapons-v2 sec 0 roles): Special titles FourTempests / SevenPrivateers (Admin cmd `role`
    "Id[:Player]" | "none[:Player]", Dev tab Role). `Services/MarineService`: salary every Marine.SalaryEvery
    (Salary[Rank+1], Rank = Marine titles met by merit); CombatService.DamagePlayer downs instead of kills when
    MarineService.CanCuff(killer, victim) (Marine with any equipped `seastone` item vs Faction Pirate); KD.Down ->
    MS.OnDowned adds "ArrestPrompt" (F, OnlyFaction = Marine: Interact disables it locally for others) -> MS.Jail:
    p.jailUntil (os.time, saved) + attr JailUntil, KD.StandUp, held in the Brig (ConchBay garrison cell, floor part
    tagged JailCell, WORLD_VERSION 32) by a 0.5 s loop + CharacterAdded; released in front of the bars.
    v0.25.130 (owner): `World/Honeyslope.lua` (LAYOUTS seed 20261124, WORLD_VERSION 33): cove jetty z 250-318 (the
    square base reaches ~r, a jetty inside r lies on land), roads (segments alternate 3 heights), green with a block
    giant tree (a BroadTree prop scaled 2.8 showed a black trunk), cottages + fenced plots, west fields + scarecrows,
    east hay + barn, manor hill (L.Tiers lobe + cap, hedge ring, gate), NW/NE cliff mesas, wood band d > 120 from the
    green. ClawCat spawn moved to (-120,-150) (changes the generic burn's rng use: later islands may shift).
    Edit-mode `require(WorldBuilder).Build()` returns the CACHED old module after Rojo edits (no rebuild): use Play to
    look (world rebuilds at runtime), or restart Studio before the Edit build. Aerial shots in Play: click PLAY, anchor
    the root over the island, BindToRenderStep a Scriptable camera, disable ScreenGuis, screen_capture.
    If Studio is already in Play when you start_stop_play, that is the OWNER's session: do not stop it or change its UI.
    v0.25.131 (owner): `World/Barracuda.lua` (LAYOUTS seed 20261125, island radius 160, WORLD_VERSION 34): a floating
    restaurant on its OWN round plank raft (api.base is not called: the voxelized base cylinder became a sandy cross;
    a big ctx.foam disc also voxelizes into a white plus, so none: Ocean's shore foam rings the raft). Round slabs =
    parallel plank strips clipped to the circle (`disc`; two overlapping squares read as a star), walls = facet `ring`.
    Mint 2-storey hall + balcony + east stairs, stepped orange/white striped roof, mast with striped sails, dining deck
    with umbrella tables, GALLEY house, lamps + bunting, deck sheds by the rim (r - 20: at r - 30 the mob spawn
    reserves refused them), south pier + rowboats. Cloth uses Plaster (Fabric renders dark/blue). Spawns moved inside.
    v0.25.132 (owner): `World/Mikan.lua` (LAYOUTS seed 20261126, WORLD_VERSION 35): Sawtooth Park = the Overlord's
    coral palace (walls + merlons, corner/gate towers with scallop `shell` crests instead of shark teeth, south main
    gate + sign, north WATER GATE with a grille and a canal to the sea, Kit.Pagoda hall 1.45 + shell crown, pool +
    pavilion), boss moved to the palace courtyard (20,-140), Dungeon NPC outside the gate; round rice paddies east
    (disc rings water/rice/water + tufts), tangerine groves west, plaza village (12-slot ring minus road mouths),
    wreck SW, jetty south, 3 corner hills (keep x/z + r within ~218: the grass square ends ~230 out), tropical woods
    (palms near the shore). OctofolkBrute spawn (-90,-120). Daylight shots: server clock phase 0..0.7 is day (24 min).
    v0.25.133 (owner): `World/Epilogue.lua` (LAYOUTS seed 20261127, WORLD_VERSION 36): NO execution platform (the old
    HarborCity theme had one): the square's landmark is a BELL TOWER + two fountains; arched gate "EPILOGUE TOWN" on the
    main street, ring road r 104 + radial streets, domed TOWN HALL (stepped `dome` of strip discs) north, red-dome church
    west, Marine HQ east, 4 rings of white houses (terracotta / blue roofs), market stalls, PvP arena built here
    (island.arena, PvPService reads its offset), Mist Commodore's broken square north, lighthouse east, 3 piers + quay.
    Bounty Board + Job Master stand on the square sides (the last island keeps them). Roads reserve small spots along
    their length: one circle per long segment blocked whole house rings. All six islands after Daybreak are hand-laid now.
    v0.25.134 (owner: islands felt fixed to a circle): `World/IslandShape` = organic outline on an 8-stud voxel grid
    (grass over a rock body, cliff ledges with rock blocks, 2-step sand beaches, see-through shallows, block surf
    "ShoreFoam" tagged Foam, sea stacks, trees/bushes/rocks on the new headlands). Land never shrinks below r - 14
    (every hand-laid prop stays on grass); docks (+-x) and the south harbor are kept at r; Daybreak's quay arc wider.
    `S.Radius(island, r, a)` also drives ctx.free. Own Random per island id + Kit.WithRng (shared Kit.rng untouched:
    buildBase still burns the old lobe draws). Ocean shore rings only for floating islands. GrassField also sways
    dressed EnvProp trees/bushes near the camera from their foot (Base attr, Collider part stays). WORLD_VERSION 37.
    Owner refs for the worldbuild pass (24 Nov): compact block houses with plank/stone walls, framed pixel windows
    + sills, stepped roofs, small lamps, enterable buildings with an NPC inside; dense house blocks along paved
    spines, trees on the edges/hills; boss nameplate with damage focus + drop chances; bosses inside big structures
    (clown boss in a circus tent); bring the execution platform back on Epilogue. This quality is the standard for
    every later sea.
    v0.25.135: bosses get a `BossInfo` billboard above the nameplate (MonsterService makeBossInfo): DMG FOCUS = the
    MonsterTypes type that beats the boss (x Bonus) + its own type, then drop chances (drops + card + Mystery Blade
    BladeDrop.BossChance), max 6 lines, rarest kept. Testing tip: a module required from execute_luau is a separate
    copy (MS.Spawn there parents to nil); wait for BossService (first spawn 60 + index x 20 s after start).
    v0.25.136 (owner: far islands should show faintly): outline math moved to `Shared/Modules/IslandOutline`
    (Radius / Beach / Near / Hash; World/IslandShape uses it). WorldCull builds a stand-in per island (24-stud
    outline rows, rock + grass + sand, tree clumps, a few roofs; folder workspace.FarIslands) shown only while that
    island's scenery is culled. Owner, next pass: important buildings designed properly (bigger, enterable, NPC
    inside), filler houses stay simple models; buildings bigger than now; redesign mountains as real ranges/ridges
    (they shape rivers, climate, borders) instead of round mesa blobs.
    v0.25.137 (owner clip: "damage focus" = the reference's Damage Progress): the BossInfo billboard is gone; bosses
    carry attrs BossDrops ("name|chance;...") + BossFocus (type id) + DmgShare ("Name|UserId|share;...", MonsterService
    shareUpdate, 0.4 s throttle) and HUD.updateBossPanel draws DAMAGE PROGRESS (yours gold, kept on row 6) + ITEM
    DROPS under the target bar. Reference findings + the next passes: docs/Plan-Worldbuild-v2.md. Video refs >10 MB:
    the owner downloads them to Downloads, frames are cut with Blender's sequencer (blender -b script: strips
    new_movie + render per frame, contact sheets with PIL).
    v0.25.138 (owner): the boss lines are floating outlined text (no panel background), rows 14 px Display font.
    v0.25.139 (owner): the BossIntro name + bar STAY at the top with live HP while the boss lives and you are near
    (State.bossBar; gone after 3 s beyond 170 studs / 420 for sea bosses); the HUD target bar hides for that boss and
    the boss text sits under the intro bar (y 200). DmgShare value = your damage / max HP (not a share of the total).
    HUD target bar hides beyond 70 studs (bosses 170), selection cleared beyond 90 / 220. Readability: no white reach
    ring and no red target ring in manual mode (Auto keeps both).
    v0.25.140 (owner, Plan-Worldbuild-v2 pass 1): ENTERABLE buildings: Kit.House opts.hollow = "tavern" | "smithy" |
    "shop" -> ground floor of 1-stud wall slabs with an open 6x7.6 doorway, plank floor (top y 1.4), ceiling beams,
    warm PointLights, `Kit.Interior(cf, w, d, kind, fh)` furnishing (L bar + stools + bottle shelves / forge + anvil +
    weapon rack / counter + goods shelves); `Kit.InteriorSpot(d)` = NPC local z at the back. No rng in interiors.
    Wall furniture: local -Z must face INTO the room. api.npc extra.Lift raises an NPC onto a floor. Daybreak HALLS
    (ring angle -> size/interior): Sunrise Tavern (+ a Tavern Keeper inside), Blacksmith, General Store (stall gone).
    WORLD_VERSION 38. Owner next (24 Nov): monster zones readable from the map itself (no labels), and a quest
    giver of its own on each island (not only Rowan). `python` in Git Bash is the Store stub (does nothing): use
    Blender's python for scripts.
    v0.25.141 (owner): Sunrise Tavern porch awning raised above the doorway (posts 9.6, stepped striped Plaster wedges
    at y 10.4), Kit.House opts.signLift (tavern sign 3.6 up, over the awning). WORLD_VERSION 39.
    v0.25.142 (owner: buying crew felt like a slave trade): RECRUIT crew. `Config/Recruits` (one seed -> name, race +
    variant, job Gunner/Rower/Carpenter/Cook, 1-3 stars, what they want = Doubloons or a job item, a line; Look(c) on the
    SERVER only (Looks.Random iterates pairs); Bonus(list) capped). `Services/RecruitService`: 4 sailors per Tavern
    Keeper (spots in the keeper's space, outside its ring), rotate every 15 min, prompt Talk (E) -> push OpenPanel
    Recruit -> `Panels.Recruit` (portrait = clone of the world model) -> `RecruitCrew` { key } (near check, bunks, pays
    coin or RemoveItem) -> p.recruits { seed, name, race, variant, prof, stars } + p.crew. `DismissRecruit` { seed } or
    { deckhand = true } (old unnamed crew = p.crew - #recruits). New saves start crew 0. Effects: Launch adds
    Bonus.speed to shipSpeed, ship.reloadMult; RecruitService 1 s tick: Carpenter `ShipService.Patch`, Cook heals players
    aboard. `addRecruits` (ShipService, forward-declared above Launch) welds their figures at posts (Gunner behind
    cannons, Rower at OarBench, rest on deck) with a name tag. `Controllers/RecruitLife` walks the tavern sailors around
    their spot locally (legs/arms swing, stop + face you within 8 studs). Daybreak: only the tavern's keeper (harbor one
    removed). UI.Button returns (button, HOLDER): position the holder. WORLD_VERSION 40.
    v0.25.143 (owner: monster spots should read from the map, no labels; quest givers all looked like Rowan):
    `World/MobZones.Build` (runtime, from MS.SpawnIslandMobs: needs raycasts) dresses every Islands spawn with radius
    >= 12 (sp.lair = false skips one, e.g. Daybreak Bandit Hill which has its own camp): 4-stud worn tiles on ground
    materials, a border open toward the island middle (camp stakes / rocks + bones), a lair at the back by THEME
    (camp tents+fire+flag for humanoids, den rock cave, grove giant stump for monkeys, wallow mud + broken fence for
    boars). Tiles = Sand material in dirt colors, only on plain Grass (farm plots, paths, raft, paving stay). Humanoid = MonsterLooks.ById. CanQuery off (mob ground rays + clicks pass). ModelFactory NPC_LOOK
    now takes shirt/pants/shoes names, hat (overrides the caller's; "none" = bare), race + variant; one entry per
    Quests.Guide name; new voxelHat kinds tophat / toque / headscarf. WORLD_VERSION 41.
    v0.25.144 (owner refs: block-column sea, white crests, dark troughs, LOW waves): `Shared/Modules/Waves` (3 sine
    trains, Amp 1.5, Damp = Doldrums 0.25 + fade near island edges, Now = GetServerTimeNow) is the ONE sea surface:
    ShipService stepShip heaves to the mean of 4 hull samples and pitches/rolls from their slope; client
    `Controllers/VoxelSea` draws it as CELL 4 block columns (N 40/52/64 by quality, off on Low) around the camera,
    toroidal recycling (only new cells raycast: land = hidden, shallow sand = clear turquoise), 0.5-stud steps, 12-band
    color ramp, edge fade into the flat Ocean parts which it lowers locally by Amp + 0.3. Narrator TTS Pitch -2.5 /
    Speed 0.95 (owner: deep is fine but hard to understand); gen_voice DEEPEN milder (regenerate the wavs before the
    6 Dec upload). Owner plans a cutscene after character creation -> PLAY (not started).
    v0.25.145 (owner: square patch following the camera looked bad, waves too low): Waves.Amp 3, SHORE 60; VoxelSea =
    TWO tiers (fine 4-stud cells every frame + coarse 12-stud cells every other frame out to ~290 studs, coarse hides
    where the fine one is), coarse rim fades height + color (FADES palette) into the flat sea, which is recolored
    locally to FLAT (SmoothPlastic, opaque) and lowered by Amp + 0.4. ~4600 parts on High, ~72 fps in Studio.
    v0.25.146 (owner refs: bosses inside big structures, execution platform back on Epilogue): Marmalade `bigTop`
    (BIGTOP local (0,-56) r 22 on the boulevard: 20 striped wall facets, tied-back entrance flaps toward +Z + sign,
    stepped striped roof, sawdust ring, blue bleachers on the back half, 4 hanging lamps) around Captain Confetti;
    boss `indoorY` (Islands) = BossService ground ray starts there (under the roof). Epilogue bossSquare: Mist
    Commodore's execution stage (brick plinth, deck H 7, front stairs into the square, rails, lantern posts, banners).
    WORLD_VERSION 42.
    v0.25.147 (owner ref: block-built circus big top, bigger/taller; the clown gang has taken the town): Marmalade
    BIGTOP = stadium tent (poles x +-22, rs 28, centre local (0,-40)) on a 2-stud grid: roof block per cell (concave
    curve, sag between the poles, block reaches its lowest neighbour), stripes by `redStripe` (odd counts: colors
    alternate at the seams, asserted), wall ring with the door at +Z, marquee sign CONFETTI CIRCUS; inside = the show
    (plank floor, ring, grid bleachers, stage + curtain, tightrope, trapeze, SpotLights, garlands, drums, fire hoop,
    cannon). `townStory`: barricade + KEEP OUT at z 60, Crew checkpoint camp on the crossroads (ClownGrunt spawn moved
    to (0,38), lair = false), wagons, crew bunting, empty lion cages, hashed confetti, Crew flag on the town hall.
    First column of houses skipped for cz < -2. Story-layout rules + mini-boss proposal: docs/Plan-Worldbuild-v2.md.
    WORLD_VERSION 43.
    v0.25.148 (owner): MINI BOSSES = Islands `minis` (NOT `spawns`: WorldBuilder reserves room per spawn, which would
    shift generated islands, and hunts/dailies/quest arrows read spawns): Monsters `mini` = slam | charge | summon
    (MonsterService miniSpecial every 11 s; summon = up to 2 noRespawn CircusLions), gold ELITE plate + attr Elite,
    def.respawn 6-8 min. BanditChief (Daybreak Bandit Hill), SpoiledEnsign (Conch T2 street), BeastTamer (Marmalade
    east cage); own items ChiefFurMantle / PamperedShades / TamerWhip (Config/Accessories, no acc_ icons yet).
    Captain Confetti specials = confettiSpecial: F_SplitCannon line + F_SplitFestival ring (FX "BossFruit" ->
    VFX handler -> FruitFX.Play with the boss model as `char`; FruitFX limbPieces works on R15Mob VoxelBody) + charge.
    Dash: FallingDown/Ragdoll disabled during the burst (+0.35 s), Heartbeat rays at knee/chest end it at a wall.
    Recruits v2: 5 tiers (Recruits.Tiers, StarWeights), all-random look, `skill` 80-125 + `trait` (other job x
    TraitShare), R.Effects/Record/ValidRecord, Rotate 600 + R.NextIn (windows count down from GetServerTimeNow);
    RecruitService stands models on the floor (ray under the spot, feet offset from the bounding box), stud-sized
    tags (MaxDistance 45), `MakeContract` { seed } -> CrewContract item with entry.recruit, `SignContract` { uid };
    ItemDB.ForEntry names a contract after its sailor (rarity = tier). DataService `crewV2`: crew = #recruits once.
    Kit.House ridge sits on the top Voxelize step (roofH x (n-0.5)/n). VoxelChar: every same-limb coplanar face pair
    (shirt x pants, pants x shoes, checked in Studio with VC.Preview) moved apart 0.01-0.04. Job Master aura lives in
    `bg` behind the view, plainLight. Map: sea gradient + hashed pixel crests, Crimson Wall = offset stone blocks.
    WORLD_VERSION 44.
    v0.25.149 (owner: clothes still flickered): real avatars are ~1.06x the R15 rest sizes, so gaps tuned at rest broke.
    VC.Apply now builds at REST (place() returns the rest pose) and scales each block with its limb (k = mean
    live/rest ratio); `Shared/Modules/Coplanar.Fix(items, fixed)` runs on every built look (buildAll = buildBlocks +
    Fix, rest space) and in Accessory.Wear (outfit vs VoxelBody + other outfits): a same-facing coplanar face pair of
    different color/material overlapping > 0.01 grows the smaller block 0.024 on that axis (4 passes, ~20 ms/char).
    Checked in Studio: every shirt x pants x shoes + every accessory = 0 left. Do not hand-tune 0.01 offsets any more.
    Recruit stage = white base + tier gradient + UI.Halftone + UI.Sparkles, gold ribbon text. VoxelSea FLAT = deep blue
    (12,54,102). Quest texts "Reach X". Courier Gull Post (FastTravel) stands in the turned shipyard group (Daybreak
    keeps its harbor one), layouts no longer place one; FastTravel lands 6 studs in front of the destination's post.
    Marine Registrar at Conch Bay (-13, 189) by the main stairs. WORLD_VERSION 45.
    v0.25.150 (owner refs: ships): no shipyard platform/crane/rails: boardwalk + mooring posts, the Plot part is
    invisible at y 9 and the design hovers over the water (Builder camera pitch -1.1..1.45 looks from below).
    `Config/ShipPresets` = Dinghy / Sloop / Galleon designs (builder helpers add/box/big, `P.Cost(design)` = beli + Wood
    by block count, other materials x150 beli, `P.Check(cells)` run by ShipyardService at start) -> Shipwright tab
    "Buy a Ship" -> `BuyShipPreset` { id, slot } (near Shipwright, no launched ship, refunds the slot's old parts).
    Player ships launch WYSIWYG (`dress = false`: no DressHull; SizeClass still set) with `ShipModel.FactionColorFn`
    (Marine = white/navy). ShipParts Stairs / Railing / Barrel; MaxParts 320; BuildPart = shaded hull blocks with seams,
    trims, rivets / corner posts, deck seams (Lantern no longer caught by the slab branch). Sails: tag "ShipSail" +
    attr Kind; ship attr "Sails" 0..3 from throttle (ShipService); `Controllers/SailCloth` hides the sail locally and
    draws 8x8 Fabric cells welded to it (rows by level, stepped billow toward the bow, flat emblem plateau, furled roll)
    + SurfaceGui emblem from `Config/SailArt` (16x16 hex-palette strings: ship attr SailArt, else Pirate skull / Marine
    anchor-star by Kind or ship Faction; SailColor attr overrides the cloth). Emblem editor in Crew = next version.
    WORLD_VERSION 46.
    v0.25.151: sail cloth + the server Sail part use Plaster (Fabric's MaterialService variant renders dark blue).
    Presets sit on a V keel (y0: PlankWedge r1 / r3 bilge sides + OakBlock keel, bow wedge), deck at y1, bulwarks y2,
    castles y2 + rails y3; masts start at y0 (through the keel). Checked in Play: furl/unfurl, emblems, Buy a Ship page.
    Rojo serves the MAIN checkout: merge before testing in Studio.
    v0.25.152 (owner: ship builder felt locked to a grid, wants a free Shipshaper-style editor): ship design v2 =
    `Shared/Modules/ShipHull` ({ v = 2, hull = { nodes = {{z, w, d, s}}, bow, stern, wall }, items = {{ id, x, y, z, r,
    sx, sy, sz, m }}, paint, paid }; x across, y 0 = deck top, z from the stern; m = mirrored pair). Hull = 1-stud voxel
    slices from Catmull-Rom node widths x section curve (V/U/F), raked bow/stern, stripe + deck + keel + bulwarks
    (model "Shell", Smash never breaks it). Physics-lite: waterline from layer volume, GM stars, problem sinks /
    floods / capsizes -> not valid. Cost = hull volume + items; ShipyardService `BuildSave` sanitizes the whole design
    and pays/refunds only the delta vs design.paid (BuildPlace/BuildRemove gone); BuildEnter converts v1 grid ships
    (ShipHull.FromV1, paid = their part costs). ShipStats.Parts(design) = Expand (mirror copies, model Index order) for
    cannons; ShipService sits the keel at SeaLevel - draft + list/trim/heel. Presets are v2 builders. Builder.lua =
    client-side preview with tabs HULL (drag node handles) / PARTS (place, drag, turn, scale, mirror, clone) / PAINT,
    live stats, SAVE / UNDO / LAUNCH / EXIT. Studio MCP clicks use GUI AbsolutePosition (screenshot y - 58).
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
   Owner (23 Nov): every fruit / skill pass also makes the existing animations + FX prettier and smoother (anticipation,
   follow-through, eased tweens, no popping particles).
4. Playtest fixes (fruit Dash feel, pet follow, swim animation, quest flow). Friend playtest target: end of November 2026.
