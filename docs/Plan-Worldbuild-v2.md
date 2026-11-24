# Worldbuild v2 (owner, 24 Nov 2026)

Source: owner's Drive "Ref/Island" concept images (top-down/aerial), "Ref/Vid" MedalTV clips (a voxel pirate
game, only the FEEL is used, never its names, map or assets) and two YouTube guides of the same genre.
This quality is the standard for every later sea (owner: later seas must look this good, with even more identity).

## Done
- v0.25.134 organic island outlines (World/IslandShape + Shared/Modules/IslandOutline): headlands, coves, rock
  cliffs, 2-step beaches, block surf, sea stacks. Trees + bushes sway in the wind (GrassField).
- v0.25.136 far islands show as hazy silhouettes on the horizon (WorldCull stand-ins).
- v0.25.137 boss HUD panel: DAMAGE PROGRESS (each player's share of the damage, yours in gold) + ITEM DROPS
  (chance per item, rarest kept) + DMG FOCUS (the type that beats the boss).

## What the references show
**Scale.** Buildings are big next to the character: 3-4 storey blocks with rows of arched windows, thick town/fort
walls (8-12 studs thick, walkable tops, square corner towers). Our houses read as toys: scale them up ~1.6-2x.

**Houses.** Compact block houses: timber-frame walls (dark beams over cream plaster) or stone/plank walls, framed
windows with a sill, a real door with a frame, stepped or hipped roofs with eaves, chimneys, a lamp on the corner.
Filler houses stay simple models (no interior). Each house sits on its own small grass yard with a low fence.

**Important buildings = designed + enterable, NPC inside.** Example from the clip: a tavern / recruiting office:
plank floor, an L-shaped bar counter, red round stools, bottle shelves on the wall, a bookcase, wanted posters, two
NPCs behind/at the bar who talk (dialog box). Ours: Tavern (Tavern Keeper), Blacksmith forge, General Store, Marine
office, Job Master hall, the boss buildings. Interiors are lit (warm PointLights), doorway = open frame you walk in.

**Bosses inside structures.** Big buildings host their boss: the circus boss inside a big striped tent, the Marine
captain in the garrison yard behind walls, the mist commodore on the execution square. Bring the EXECUTION PLATFORM
back on Epilogue (it is just a platform, it looks good) next to the bell tower. Boss respawn timer shown on the HUD.

**Town plan (aerial concept art).** Dense blocks of houses touching each other along a wide paved main street from
the harbor to the landmark (town hall / fort / palace) at the back; side streets on a grid or following terraces;
a market strip with striped awnings by the quay; plazas at crossings. Villages: a few cottages along a winding dirt
road with fenced vegetable plots, one big tree landmark, a manor on the hill.

**Trees.** Big flat canopies (umbrella / acacia-like, block layers) on branching trunks, some in pink/red/purple
tints; trees line streets and fill yards and walls, forest belts on the hills and island edges.

**Mountains (owner).** Replace the round mesa blobs with real ranges: ridges with peaks, valleys between them,
cliffs on the sea side; ranges shape where rivers run, where towns sit (valleys, coasts) and act as borders between
zones. Paths climb along ridges/switchbacks, not straight stair cylinders.

**Sea.** Region banner when entering a sea ("First Sea ..." style title + subtitle), distant islands always visible
as hazy silhouettes (done), light pillars for events (fruit spawn beacon exists).

## Next passes (in order)
1. Building kit v2 in Kit: `Kit.HouseV2` (bigger, timber/stone/plank variants, framed windows, door, roof styles,
   yard + fence) and `Kit.Hall` interiors (tavern, smithy, shop, office) with an NPC slot.
2. Mountains v2: ridge generator (spine polyline + noise peaks on the voxel grid, cliff sides, grass shelves).
3. Re-lay each island with v2 pieces following its concept art (Daybreak first), bosses moved into their
   structures, execution platform on Epilogue.

## Story-driven town layout (owner, 24 Nov: "the clown gang has taken the town")
Rules we follow when laying out an island so it tells its story without text:
1. One story per island, told in a walk: safe arrival (harbor, townsfolk, shops) -> the edge of trouble (a barricade,
   a sign) -> occupied ground (the gang's camp = the first mob spot) -> signs of what happened (props that imply an event:
   open empty cages = the lions got loose) -> the villain's lair (boss inside a landmark everyone can see from the harbor).
2. Mob levels follow the walk: weakest nearest the harbor, the boss at the far end of the main street.
3. The villain marks territory: their colors (Confetti Crew purple + gold) on flags, bunting, wagons, the flag on the
   town hall, litter (confetti) that thins out toward the safe harbor.
4. The landmark is visible from the arrival point and the main street points at it (sightline).
5. Every prop answers "who put this here and why"; props with no story stay out.
Marmalade v0.25.147 is the first island done this way; next: each island's concept gets the same 5-beat walk.

## Mini bosses (proposal, waiting for the owner)
One mini boss per island at the middle beat of the walk (e.g. Marmalade: the crew's checkpoint boss among the grunts),
stronger elite of the area mob (x3-4 HP, one telegraphed special), respawn 5-8 min, name bar but no boss intro/music,
drops: a guaranteed material for the island's gear + a small chance of the boss's item; counts for hunts/quests.

