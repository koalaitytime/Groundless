# Groundless

A floating-raft survival game in Godot 4.7 (GDScript, Forward+, Jolt Physics). The design lives in `Groundless — Game Design Document.md` at the repo root; read it before changing gameplay.

## Layout

- Repo root: this folder (`C:\Projects\Groundless`). Git with Git LFS.
- Godot project: `groundless/` (`res://` = `groundless/`).
  - `scenes/` `.tscn` files
  - `scripts/` `.gd` files
  - `shaders/` `.gdshader` files
  - `assets/models/` `.glb` exports (LFS)
  - `assets/textures/` images (LFS)
  - `assets/audio/` sound (LFS)
  - `docs/` notes, references
- Godot binary on this PC: `C:\Users\aluck\Downloads\Godot_v4.7.2-stable_win64_console.exe` (use `--headless` for checks).

## Conventions

- **Y is up.** Say "vertical" or "Y", never "Z", for height.
- **1 unit = 1 metre** everywhere, in Godot and in Blender exports.
- **Naming:** lowercase_with_underscores for files, nodes in code, and actions. Type prefix where useful: `pod_large.glb`, `island_pod_grove.tscn`, `raft_controller.gd`.
- **No skeletal animation.** Nothing gets a rig or skeleton. Motion comes from physics, shaders or code.
- **World recentring is planned from the start.** The raft drifts forever, so the world will be shifted back around the raft to keep coordinates near the origin. Don't store absolute world positions long-term or assume the origin is fixed; keep positions relative to the raft or to a recentre-aware root.
- **Raft is an AnimatableBody3D moved by script** (`scripts/raft.gd`). The player rides it by applying the raft's per-tick transform change itself (`scripts/player.gd`); the engine's platform velocity is off (`platform_floor_layers = 0`). Anything rideable joins the `rideable` group and must move before the player (lower `process_physics_priority`).
- **Recentring** is the `WorldOrigin` autoload: top-level nodes in the `recentre` group are shifted back on X/Z when the raft passes `threshold`. Never shift Y. Cache global positions only if you listen to `WorldOrigin.recentred`.
- **Wind** is the `Wind` autoload: `Wind.velocity_at(height)`.
- **Tuning numbers** all live in the `Tuning` autoload (`scripts/tuning.gd`), seeded from `groundless/docs/early-design-numbers.md`. Never hard-code a gameplay number elsewhere.
- **Lift** is `RaftLift` (the raft's `Lift` child): resting height = clamp((lift - weight) x metres_per_kg, murk_floor, ceiling). Y = 0 is the murk's top. Things that weigh something call `RaftLift.find(self).add_weight()`.
- **Physics layers:** 1 world, 2 flotsam (drift-pods and material bundles, hit by the hook), 3 interact (`Interactable` areas the look ray finds).
- **Building** is `RaftBuilder` (the raft's `Build` child): a grid of `Tuning.tile_size` tiles in raft-local X/Z; the slab is tiles -1..1. Plank and roof collision shapes go directly on the raft body. Recipes live in `Tuning.recipes`. Built pieces that weigh something remove their own weight in `on_cut()`.
- **Islands** are `Island` (StaticBody3D, grey-box built in code; origin = lip height, tops at Y 0). Kinds: `standard` (assembled from `island_seed`: 2 to 4 overlapping lobes plus 3 to 5 landforms from the kit: hill, cliff, cave, spring, grove, arch, and hangroot sides; `theme` forces grove or hangroot for the teaching islands), `wreck`, `rare_shell`, `rare_lantern`, `story_wreck`. Shapes are exposed as circles (`solid_circles_at`, `world_lobes`) for raft collision and mooring. `IslandSpawner` (the `Islands` node, in the `recentre` group): two teaching islands, then `Tuning.island_type_weights`, then the story island after `story_island_after_visits`. Every island mesh uses `shaders/island_reveal.gdshader` with an instance `reveal` uniform. The raft slides around islands via `Raft._keep_clear_of_islands()`.
- **Anchoring** is `RaftAnchor` (the raft's `Anchor` child): the hook hitting an `Island` anchors; the raft is moored: reeled to `anchor_gap` from the lip, hauled level with the lip whatever its lift (in `RaftLift`), and held still (no bob or sway) so the player walks across; `AnchorCleat` casts off and lift takes over again. `Tuning.leak_while_anchored` is on trial.
- **Boarding:** Space at a ledge 0.6 to 1.5 m above the feet mantles (code-driven); `Ladder` volumes (hangroot) are climbable.
- **Survival** is `Survival` (the player's `Survival` child): thirst, hunger, health; `black_out()` fades, drops `wake_item_loss` of carried materials and wakes the player on the raft (falling off and health 0 both use it).
- **Storm** is the `Storm` node (group `storm`): clear, warning, rain. Rain burns the player without cover overhead (ray up), drains pods whose anchor tile has no roof, fills rain catchers, and sets `Wind.storm_strength`. Blacking out ends the rain.
- **Pod-leech** is `PodLeech` (layer 2, spawned by `LeechSpawner`, the `Leeches` node): swims to a pod, latches and drains it; `hit()` from the hook or E knocks it off, `Tuning.leech_hits` pop it.
- Build work happens locally on Andrew's PC, never in the cloud.

## Tests

Run from `groundless/` (exit code 0 = pass):

```
C:\Users\aluck\Downloads\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 res://tests/ride_test.tscn
```

`res://tests/survival_test.tscn` is the milestone 5 check (thirst, hunger, health, drinking, eating, falling off, the storm's warning, burn, pod damage, roof shelter and wind, the pod-leech).

`res://tests/island_test.tscn` is the milestone 4 check (spawning order and reachability, reveal, raft vs islands, hook anchoring, reeling, rope height limit, leaking while anchored, mantle, hangroot climb, walking back aboard, cast off, missed islands, recentring, the wreck's ending).

`res://tests/gather_test.tscn` covers gathering (charged hook, early reel, clumps, grabbing by hand, wind nets, flotsam streams).

`res://tests/build_test.tscn` is the milestone 3 check (grid rules, costs, weight, walking on new planks, fixtures, roof, cutting loose, crafting, patching, sky-paddle, material flotsam).

`res://tests/lift_test.tscn` is the milestone 2 check (lift, weight, controls, murk, hook, drift-pod spawning).

`tests/ride_test.tscn` is the milestone 1 check: standing, walking, jumping and walking off the edge on an exaggerated drifting, turning, swaying raft with frequent recentres. Rerun it after touching the raft, player or recentring.

## Input actions

Defined in `project.godot` (physical keys):

| Action | Default |
| --- | --- |
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D |
| `jump` | Space (also mantles onto a ledge 0.6 to 1.5 m up, and climbs hangroot) |
| `interact` | E (use things; grab flotsam within reach; tear off a pod-leech) |
| `interact_alt` | Q (second action, e.g. dump a rain catcher) |
| `eat` | F (eat a shelf fungus) |
| `hotbar_1` … `hotbar_9` | 1 … 9 |
| `hotbar_next` / `hotbar_prev` | Mouse wheel down / up |
| `sprint` | Shift |
| `use_primary` | Left mouse (hook: hold to charge, release to throw, click again to reel in; hammer: place; sky-paddle: hold to paddle) |
| `remove_piece` | Right mouse (with the hammer: take a piece back, full refund) |
| `cut_loose` | X (with the hammer: crisis drop, no refund) |
| `build_menu` | Tab |

Also: Esc frees the mouse, click recaptures it, F3 toggles the debug readout.

## Assets

Every asset goes through the clean-up checklist in the GDD (scale, origin at base, poly budget, normals, flat palette materials, naming, `.glb` into `assets/models/`).
