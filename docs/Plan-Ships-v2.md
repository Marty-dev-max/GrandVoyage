# Plan: Ship system remake (from the owner's reference clip, 26 Nov 2026)

Reference: a ship-builder tutorial clip (YouTube 618iPJOVZ9k, 3 parts: editor, physics, handling). We take the
MECHANICS and feel only (never its names, art or assets). It is a steam/ironclad game: every system below is mapped
to our pirate sail era. Status = what v0.25.152 already has (have / part / none). The owner picks numbers; the
picked ones become the remake scope (column "Pick").

| # | System in the clip | Our version (pirate era) | Status | Pick |
|---|---|---|---|---|
| **A** | **Hull shaping** | | | |
| 1 | Drag hull nodes/gizmos to shape the ship | node handles (width / depth / position) | have | YES |
| 2 | Add/delete nodes by holding the mouse or a "+" on the hull | +/- POINT buttons only | part | YES |
| 3 | Different cross sections for bow / middle / stern | V/U/flat per node + bow/stern rake | part | YES |
| 4 | Pick a section, hover + scroll wheel cycles options with live preview (bow styles, stern styles) | clipper / round / spoon bow, transom / round / galleon stern | none | YES |
| **B** | **Placing items** | | | |
| 5 | Superstructures stretch and CONFORM to the hull (wrap its curve) | cabins / forecastle / quarterdeck / stern castle that follow the hull width | none | YES |
| 6 | Parts browser by category, drag onto a valid spot | PARTS tab cards | have | YES |
| 7 | Right-click "free-form" menu: offers only what fits where you point (side: gun port, lettering, hatch; middle: mast, gun mount; bow: bowsprit) | context menu on the ship | none | YES |
| 8 | 3D handles on every item: drag, stretch, rotate in the world | side card steppers + drag move | part | YES |
| 9 | Merge superstructures (balconies, variations) | | none | YES |
| 10 | Edge tools: run a rail along an edge, extrusions / coverings | rails + awnings along the deck edge | none | YES |
| 11 | Symmetry: items come in pairs, delete one = asymmetric, CLONE brings it back; hull + big superstructures must stay symmetric | MIRROR toggle | part | YES |
| 12 | Masts with adjustable sails, bowsprit, signal flags, flags on lines | mast + sail width only | part | YES |
| 13 | Every ship needs a rudder + propulsion | helm + sail/oar required; no rudder part | part | YES |
| **C** | **Looks** | | | |
| 14 | Instant color pattern generator, paint zones, save / delete themes | RANDOM + 6 zones, no saved themes | part | YES |
| 15 | Hull details: rivets, lines | plank seams, iron bands, gold trim | none | YES |
| 16 | Hull MATERIAL changes HP and weight (planks vs metal) | Pine / Oak / Iron-banded hull: HP, weight, cost | none | YES |
| 17 | Lettering (ship name on the hull) | name plate on the stern | none | YES |
| **D** | **Physics** | | | |
| 18 | Weight of every item by size and place, center of gravity | weight + GM, list/trim from items | have | YES |
| 19 | Overloaded ships list, flood or sink; raise the freeboard to fix | problems sinks / floods / capsizes | have | YES |
| 20 | Stability stars + tonnage + weight breakdown by category (hull, guns...) | stars + tons, no breakdown | part | YES |
| 21 | Editor only estimates; the real test is at sea ("ship in a bottle" test, change wind / time of day) | LAUNCH only, no test basin | part | YES |
| 22 | Wind makes sailing ships heel; keels (resize, twin keels, move) reduce heel | heel number only, no keel part | part | YES |
| 23 | Easy physics vs full physics mode | one mode | none | YES |
| **E** | **Performance** | | | |
| 24 | Gun size / barrel length = damage, shell speed, weight | cannon sizes (Swivel / Long Gun / Carronade / Mortar) with stats | none | YES |
| 25 | Gun firing arcs: blue = can fire, orange = can only turn; blocked by own parts | arcs drawn in the editor and used by the server | none | YES |
| 26 | Propulsion: strongest mode wins (not added up), extra engines have diminishing returns | sails vs oars: the better one counts, the other is dead weight | none | YES |
| 27 | "Power" items shown in green add power by their size and add weight | more sail area / rigging, oar benches, figurehead buffs | none | YES |
| 28 | Power readout (horsepower) | SAIL AREA / ROW POWER readout | none | YES |
| **F** | **Working items (each gets a HUD button + key)** | | | |
| 29 | Torpedo launcher (button + key T) | harpoon gun / fire-pot thrower | none | YES |
| 30 | Mines, depth charges | powder keg dropped astern | none | YES |
| 31 | Rangefinder = range readout while aiming | crow's nest / spyglass: range in the cannon aim | none | YES |
| 32 | Bilge pumps pump water out | pumps lower flooding damage | none | YES |
| 33 | Lamps, floodlight, searchlight that work (toggle) | lanterns + a searchlight lantern at night | part (lantern decor) | YES |
| 34 | Broadside hatches open/close, close when heeling | gun ports that open to fire, shut when heeling | none | YES |
| 35 | Windows, balconies, entry ports, ladders, ropes | decor set | part | YES |
| **G** | **Sailing** | | | |
| 36 | Click on the ocean to steer, or WASD | WASD only | part | YES |
| 37 | Speed gauges, furl sails | SAIL- / SAIL+ | have | YES |
| 38 | Multiplayer modes with era rules, balance checks | crew war / ship duel modes (docs/GuildWar.md) | none | no (later) |

## Owner pick (27 Nov 2026): everything except 38

Built in three versions (each pushed on its own):

- **Phase 1 = rules** (v0.25.153, DONE 27 Nov): rudder required + turn rate from its size (13), hull material Pine / Oak / Iron-banded
  (16), weight breakdown by category (20), keel parts + wind heel at sea (22), cannon kinds Swivel / Long Gun /
  Carronade / Mortar with bore + barrel scaling (24), firing arcs computed from the design (blocked by own parts) and
  used by the server (25), propulsion = the stronger of sails or oars with diminishing returns (26), power parts
  (jib, topsail, oar benches) shown green (27), SAIL AREA / ROW POWER readouts (28).
- **Phase 2 = editor**: hold / "+" to add and remove hull points (2), bow + stern styles cycled with the wheel (3, 4),
  superstructures that follow the hull (5), right-click menu of parts that fit the spot (7), in-world stretch + turn
  handles (8), stacking superstructures for balconies (9), rails / awnings along the deck edge (10), symmetry rules +
  CLONE (11), bowsprit, flags, flag lines (12), saved paint themes (14), hull details (15), name on the stern (17),
  decor set (35).
- **Phase 3 = at sea**: harpoon gun + fire-pot thrower (29), powder kegs (30), crow's nest range readout (31), bilge
  pumps (32), working lanterns + searchlight (33), gun ports that close when heeling (34), click the sea to steer
  (36), TEST SAIL with wind / time controls (21), Easy / Full ship physics setting (23).
