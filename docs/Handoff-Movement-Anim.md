# Handoff: movement animation rework (written 27 Nov 2026, game at v0.25.160)

Read CLAUDE.md first (it loads by itself). This file is the short map of what already moves the character, so the
new session does not have to dig. Owner talks Thai; friend playtest 29 Nov 2026.

## What plays what today

| Movement | Who drives it | Where |
|---|---|---|
| Idle / walk / run / jump / fall / climb (players) | Roblox's default `Animate` LocalScript with the player's own avatar animation pack (we never replace it; `PlayerService.normalizeAvatar` only resets body scales/parts) | Roblox built-in |
| Sprint (double-tap W) | WalkSpeed = player attr `BaseSpeed` x `GameConfig.Sprint.Mult`; NO own run clip | `src/client/Controllers/Sprint.lua` |
| Combat stance / M1 combos / skills / Hurt | `CharAnim` plays clips on the LOCAL character (replicates to others) | `src/client/Controllers/CharAnim.lua` |
| Swim / SwimIdle / Fly / FlyIdle | `CharAnim` loop (every 0.5 s also sweeps stale Fly/Swim tracks) | `CharAnim.lua` ~l.174-205 |
| Swimming physics | `src/client/Controllers/Swim.lua` (forces Swimming state; out of water -> Freefall) | |
| Flight physics | `src/client/Controllers/Flight.lua` (`Flight.Allow(source)`: Cinderwing, Blaze, Haze) | |
| Dash (Q) | `Combat.Dash`: LinearVelocity burst + `VFX.Afterimages`, no own clip | `src/client/Controllers/Combat.lua` |
| Slick skate | `FruitFX` skateLoop + clip `Slick_Skate` | `src/client/Controllers/FruitFX.lua` |
| Footstep sounds + run dust | by `hit.Material` | `src/client/Controllers/Footsteps.lua` |
| Shift Lock | native feel (RotationType CameraRelative) | `src/client/Controllers/ShiftLock.lua` |
| Race parts (wings, tails, ears, fins) | anchored copies posed with BulkMoveTo | `src/client/Controllers/HeritageAnim.lua` |
| NPC idle breathing / waving | BulkMoveTo on NPC blocks | `src/client/Controllers/NpcLife.lua` |
| Humanoid (R15) monsters | Roblox default R15 idle/walk ids 507766388 / 507777826 + AttackClip | `MonsterService.lua` l.167 (`R15_LOOPS`) |
| Voxel monsters | `Mon_Idle` / `Mon_Walk` (weight follows speed) / `Mon_Attack` / `Mon_Hit` on the server | `MonsterService.lua` |

## The clip pipeline (keep using it)

1. Clips are DATA in `src/shared/Config/AnimClips.lua` (degrees per R15 part, optional stud offset, `loop`,
   `priority`, `length`, `strike`). Header of that file explains the axes (character faces -Z, +rx swings a limb
   forward, -rx bends a knee, LowerTorso offset moves the whole body).
2. `lune run tools/build_anims.luau` -> `assets/anims/<Name>.rbxm` (KeyframeSequence via `Shared/Modules/AnimBuild`).
3. Upload as Animation assets owned by the owner (user 1527424396): `ROBLOX_API_KEY=... python3 tools/upload_models.py
   assets/anims src/shared/Config/Animations.lua --type Animation`.
4. `Shared/Modules/Anim.lua` plays ids from `Config/Animations`; a clip without an id (or one that fails to load in
   3 s) is built at runtime with KeyframeSequenceProvider (works in Studio only, NOT in the live game).
5. Preview poses without Studio: `lune run tools/export_pose.luau build/GrandVoyage.rbxlx x.json Clip@t ...` +
   `python3 tools/render_pose.py x.json out.png`.

Not uploaded yet (no id in Config/Animations): `Slick_Crouch`, `Slick_Pour`, `Slick_Skate`, `Slick_SlidePunch`.
The owner's PC has no lune / python on PATH: use Blender's python
(`C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe`); `python` in Git Bash is the Store stub.
Studio MCP `open_cloud_invoke` POST /assets/v1/assets uploaded models before (v0.25.102); try it for Animation
.rbxm too, otherwise ask the owner for an API key run.

## Rules learned the hard way (do not repeat)

- NEVER pose joints by hand from scripts (Motor6D.C0 / Transform): v0.13-v0.14 did it twice and nothing moved in the
  owner's Studio. Real Animation assets through the Animator only.
- `Anim.Stop` must stop tracks even when not IsPlaying and every track with the same Animation.Name (orphans kept
  the fly pose forever, v0.25.23 / v0.25.28).
- Stuck fly/swim pose came back several times: Flight lands on any ground contact unless Jump is held (v0.25.25);
  Swim forces Freefall out of water (v0.25.26); CharAnim sweeps Fly/Swim tracks every 0.5 s (v0.25.27).
- Do not snap `root.CFrame` for turning (Shift Lock jitter, v0.25.23); Combat `turnTo` skips body snaps while
  MouseBehavior is LockCenter.
- Roblox's camera resets LocalTransparencyModifier on your own character every frame (re-hide in RenderStepped).
- Avatars are uniform R15 (Game Settings avatar type must stay R15); real avatars are ~1.06x the R15 rest sizes.
- Voxel characters: `Shared/Modules/VoxelChar.Apply` welds block bodies onto the R15 limbs, so any R15 animation moves them.
- Testing in Play: client modules required from execute_luau are a SEPARATE copy (do not drive the game through
  them); MCP simulated mouse drags do not register in the shipyard; never send Escape via MCP.
- Rojo serves the MAIN checkout: merge the session branch into main (ff) before testing in Studio.

## Likely starting points for "new movement animation system"

- Own locomotion set (idle / walk / run / sprint / jump / fall / land) for the voxel look instead of the player's
  Roblox pack: either replace the `Animate` script's animation ids per character (StringValues under
  `Animate.walk.WalkAnim` etc. / HumanoidDescription animation fields) or a custom controller that blends by speed
  (like MonsterService does with Mon_Walk weight). Sprint has no clip yet.
- Per-weapon movement (stance while walking already softens: "Stances pose the upper body only and soften while moving").
- Landing / dash / turn anticipation clips (owner wants smooth, eased motion: anticipation + follow-through).
- Keep `strike` timing intact for combat clips (CombatService hits land on the strike frame).
