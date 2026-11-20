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
- Build work happens locally on Andrew's PC, never in the cloud.

## Tests

Run from `groundless/` (exit code 0 = pass):

```
C:\Users\aluck\Downloads\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 res://tests/ride_test.tscn
```

`tests/ride_test.tscn` is the milestone 1 check: standing, walking, jumping and walking off the edge on an exaggerated drifting, turning, swaying raft with frequent recentres. Rerun it after touching the raft, player or recentring.

## Input actions

Defined in `project.godot` (physical keys):

| Action | Default |
| --- | --- |
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D |
| `jump` | Space |
| `interact` | E |
| `hotbar_1` … `hotbar_9` | 1 … 9 |
| `hotbar_next` / `hotbar_prev` | Mouse wheel down / up |

Also: Esc frees the mouse, click recaptures it, F3 toggles the debug readout.

## Assets

Every asset goes through the clean-up checklist in the GDD (scale, origin at base, poly budget, normals, flat palette materials, naming, `.glb` into `assets/models/`).
