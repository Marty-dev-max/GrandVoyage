# Animation + VFX week (Mon 16 - Sun 22 Nov 2026)

Goal: everything that moves looks alive before the friend playtest (end of November). Every day ends with a pushed
version the owner can test (bump `GameConfig.Version`), plus a preview render/clip when possible.

| Day | Focus | Deliverable |
|---|---|---|
| Mon 16 | Voxel pets (18 stages) + fruits (6) | Done in v0.11.1 |
| Tue 17 | **Creature animation system**: voxel models exported in parts (head / body / legs / arms / tail / wings); client-side procedural animation, no rigs. Idle breathing bob, walk cycle (leg swing + body bounce), attack lunge/swing, hit flinch (white flash + knockback), death shatter into voxel cubes. Pets: hop, flap, swim wiggle. Serpents: segment sway. | All monsters/pets animated |
| Wed 18 | **Player combat animation**: procedural Motor6D poses on R15 avatars. Brawler 3-hit punch combo, Sea Cook kicks, sword slashes, slingshot/baton cast, skill wind-ups, hit react, victory/level-up pose. | Attacks feel like attacks |
| Thu 19 | **VFX pass 1 (class skills + hits)**: AV-style impact bursts per element, slash arcs, speed lines, crit flash + screen shake, damage numbers polish, heal/buff auras, level-up pillar | Combat juice |
| Fri 20 | **VFX pass 2 (Cursed Fruits + bosses)**: Blaze fire fist / flame pillar, Haze smoke grip / screen, Ward barrier walls, Bounce stretch punch, Split flying fist, Slick slide; boss telegraphs + slam shockwaves | Fruit skills look legendary |
| Sat 21 | **World juice**: voxel spawn/death effects, chest open, fruit tree glow, pickup magnets, footstep dust, splash when swimming; hook up sounds | Small feedback everywhere |
| Sun 22 | **Performance + playtest fixes**: mobile check (Low quality path), effect pooling, bug fixes from the owner's tests | Stable build for friends |

Notes
- Animation is procedural (CFrame offsets on mesh parts / Motor6D.Transform) so no animation assets have to be uploaded.
- VFX stay ParticleEmitter/Beam based with our own textures (`Config/Textures`, `tools/gen_vfx.py`).
- The owner reviews visuals; anything they reject gets redone before moving on.
