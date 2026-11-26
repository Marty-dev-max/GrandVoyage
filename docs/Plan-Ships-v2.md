# Plan: Ship system remake (from the owner's reference clip, 26 Nov 2026)

Reference: a ship-builder tutorial clip (YouTube 618iPJOVZ9k, 3 parts: editor, physics, handling). We take the
MECHANICS and feel only (never its names, art or assets). It is a steam/ironclad game: every system below is mapped
to our pirate sail era. Status = what v0.25.152 already has (have / part / none). The owner picks numbers; the
picked ones become the remake scope (column "Pick").

| # | System in the clip | Our version (pirate era) | Status | Pick |
|---|---|---|---|---|
| **A** | **Hull shaping** | | | |
| 1 | Drag hull nodes/gizmos to shape the ship | node handles (width / depth / position) | have | |
| 2 | Add/delete nodes by holding the mouse or a "+" on the hull | +/- POINT buttons only | part | |
| 3 | Different cross sections for bow / middle / stern | V/U/flat per node + bow/stern rake | part | |
| 4 | Pick a section, hover + scroll wheel cycles options with live preview (bow styles, stern styles) | clipper / round / spoon bow, transom / round / galleon stern | none | |
| **B** | **Placing items** | | | |
| 5 | Superstructures stretch and CONFORM to the hull (wrap its curve) | cabins / forecastle / quarterdeck / stern castle that follow the hull width | none | |
| 6 | Parts browser by category, drag onto a valid spot | PARTS tab cards | have | |
| 7 | Right-click "free-form" menu: offers only what fits where you point (side: gun port, lettering, hatch; middle: mast, gun mount; bow: bowsprit) | context menu on the ship | none | |
| 8 | 3D handles on every item: drag, stretch, rotate in the world | side card steppers + drag move | part | |
| 9 | Merge superstructures (balconies, variations) | | none | |
| 10 | Edge tools: run a rail along an edge, extrusions / coverings | rails + awnings along the deck edge | none | |
| 11 | Symmetry: items come in pairs, delete one = asymmetric, CLONE brings it back; hull + big superstructures must stay symmetric | MIRROR toggle | part | |
| 12 | Masts with adjustable sails, bowsprit, signal flags, flags on lines | mast + sail width only | part | |
| 13 | Every ship needs a rudder + propulsion | helm + sail/oar required; no rudder part | part | |
| **C** | **Looks** | | | |
| 14 | Instant color pattern generator, paint zones, save / delete themes | RANDOM + 6 zones, no saved themes | part | |
| 15 | Hull details: rivets, lines | plank seams, iron bands, gold trim | none | |
| 16 | Hull MATERIAL changes HP and weight (planks vs metal) | Pine / Oak / Iron-banded hull: HP, weight, cost | none | |
| 17 | Lettering (ship name on the hull) | name plate on the stern | none | |
| **D** | **Physics** | | | |
| 18 | Weight of every item by size and place, center of gravity | weight + GM, list/trim from items | have | |
| 19 | Overloaded ships list, flood or sink; raise the freeboard to fix | problems sinks / floods / capsizes | have | |
| 20 | Stability stars + tonnage + weight breakdown by category (hull, guns...) | stars + tons, no breakdown | part | |
| 21 | Editor only estimates; the real test is at sea ("ship in a bottle" test, change wind / time of day) | LAUNCH only, no test basin | part | |
| 22 | Wind makes sailing ships heel; keels (resize, twin keels, move) reduce heel | heel number only, no keel part | part | |
| 23 | Easy physics vs full physics mode | one mode | none | |
| **E** | **Performance** | | | |
| 24 | Gun size / barrel length = damage, shell speed, weight | cannon sizes (Swivel / Long Gun / Carronade / Mortar) with stats | none | |
| 25 | Gun firing arcs: blue = can fire, orange = can only turn; blocked by own parts | arcs drawn in the editor and used by the server | none | |
| 26 | Propulsion: strongest mode wins (not added up), extra engines have diminishing returns | sails vs oars: the better one counts, the other is dead weight | none | |
| 27 | "Power" items shown in green add power by their size and add weight | more sail area / rigging, oar benches, figurehead buffs | none | |
| 28 | Power readout (horsepower) | SAIL AREA / ROW POWER readout | none | |
| **F** | **Working items (each gets a HUD button + key)** | | | |
| 29 | Torpedo launcher (button + key T) | harpoon gun / fire-pot thrower | none | |
| 30 | Mines, depth charges | powder keg dropped astern | none | |
| 31 | Rangefinder = range readout while aiming | crow's nest / spyglass: range in the cannon aim | none | |
| 32 | Bilge pumps pump water out | pumps lower flooding damage | none | |
| 33 | Lamps, floodlight, searchlight that work (toggle) | lanterns + a searchlight lantern at night | part (lantern decor) | |
| 34 | Broadside hatches open/close, close when heeling | gun ports that open to fire, shut when heeling | none | |
| 35 | Windows, balconies, entry ports, ladders, ropes | decor set | part | |
| **G** | **Sailing** | | | |
| 36 | Click on the ocean to steer, or WASD | WASD only | part | |
| 37 | Speed gauges, furl sails | SAIL- / SAIL+ | have | |
| 38 | Multiplayer modes with era rules, balance checks | crew war / ship duel modes (docs/GuildWar.md) | none | |
