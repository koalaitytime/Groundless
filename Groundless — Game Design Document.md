# Groundless — Game Design Document

Nov 19, 2026 · @Andrew

## Overview

Groundless is a first-person survival game set on a planet with no ground. The player wakes on a cracked slab of rock held aloft by glowing gas pods and must keep it in the air, grow it into a home, and drift between floating islands.

- **Working title:** Groundless
- **Genre:** first-person survival and building, light combat
- **Platform:** PC, keyboard and mouse (controller later)
- **Engine:** Godot 4
- **Inspiration:** Raft, moved from the ocean into an endless sky

### Design pillars

1. **Lift is life.** Every piece you build costs lift. Growth has to be earned, and altitude is your main tension.
2. **The sky is the ocean.** Wind currents carry resources to you. Height is how you steer.
3. **Build to survive the weather.** Every structure protects against something specific.
4. **Lonely and strange.** No people, unexplained giants in the distance, a world told through what was left behind.
5. **Small and achievable.** No skeletal animation. Everything that moves does so through physics, shaders or code.

## Scope

The first build is a vertical slice of the opening area only: 15 to 30 minutes of play, three islands, one storm, one creature. Earlier projects stalled on scope and animation, so this document treats both as hard limits.

### Vertical slice: what's in

- Wake on the slab raft, already sinking from a wilting pod
- Learn the hook and catch drift-pods to stop the fall
- Build 4 to 6 pieces: plank, pod tether, patch, rain catcher, sky-paddle, roof
- Thirst and hunger
- Islands of every kind (see Island types): two teaching standard islands (a pod grove and a hangroot island), more standard islands, the odd wreck or rare encounter, and one story island, the wreck
- One caustic rain storm that makes the first roof matter
- One creature: the pod-leech
- One distant shadow sighting
- Ends at the wreck story island, when the player finds something that points onward

### Cut list

These stay out of the slice. Anything added later must earn its way in.

- Skeletal animation and rigged creatures
- Heavy combat (light combat against shader-animated creatures only)
- Multiplayer
- Day/night cycle (permanent dusk for now)
- Fully generated island terrain (standard islands are assembled from a kit of handmade landforms instead; see Island types)
- Cutscenes
- Save system (the slice is short enough to play in one sitting)
- Warmth stat and the high-air band

## World

The planet has no ground: nothing here ever evolved on a surface. Everything floats, hangs or clings.

### Sky bands

| Band | Look | Gameplay |
| --- | --- | --- |
| High air (later) | Pale, clear, cold, harsh sun | Fast winds for long trips; needs warmth |
| Drift layer | Violet and gold dusk, stacked clouds | Islands, drift-pods, the comfortable zone |
| The murk | Dense blue-black cloud, lightning inside | Rare materials; slow drift, gas loss, dread |

The wind blows in a different direction at different heights. Changing height is how you catch the current you want.

### Island anatomy

- Flat-ish top, jagged cone of layered rock underneath
- Long curtains of roots dangling below
- Waterfalls that never land: they pour off the edge and break into mist, which also marks islands from far away

### Plants

| Plant | Description | Use |
| --- | --- | --- |
| Pod vine | Vines growing glowing amber gas bladders; ripe pods break loose and drift on the wind | Lift and gas; the source of drift-pod flotsam |
| Hangroot | Dangling root curtains under islands | Fiber and rope |
| Mist fan | Wide, fine fronds that comb water from clouds | Water; inspires the rain catcher |
| Shelf fungus | Grows on island undersides | Food; slightly risky to reach |

### Trees: bindwood

Gnarled trees whose roots wrap the rock like fingers and hold islands together. Trunks grow sideways out of cliff edges, with small pods at the branch tips. They are the main wood source and give islands their silhouette.

## Core loop

The player drifts, catches what the wind brings, builds, survives the weather and creatures, and explores islands for what drifting can't supply. Lift sits at the centre: catching pods adds it, building spends it.

&#91;embedded content: core loop · 5 steps around lift\]

In the slice, one pass around the loop takes a few minutes, and the player goes around it roughly once per island.

## Lift and weight

The raft settles at a resting height set by lift minus weight. It never rises or sinks forever: more lift means a higher resting height, more weight or a leak means a lower one, and the raft eases toward that target. No buoyancy physics is needed.

### The three numbers

- **Pod capacity:** the most lift the tied-on pods can give. Each pod tethered to the raft adds capacity, so lift is visible as the number of pods overhead.
- **Gas:** how full the pods are right now. Pods slowly wilt and leak; catching drift-pods refills them.
- **Weight:** everything built on the raft. Wood is heavy, reed and fiber are light, the rock slab is heavy. Carried inventory does not count.

### Controls

- **Vent cord:** releases gas to sink. Costs gas.
- **Ballast:** drop sandbags or stored water to rise fast. Water is heavy, so the player is always choosing between drinking it, keeping it, or dumping it.
- **Cut loose:** in a crisis, chop off a built piece and let it fall.

### Feedback

No HUD bars. A brass altitude dial on a post, pods that visibly sag as they lose gas, ropes that creak when the raft is heavy.

### The murk (soft failure)

Sinking into the murk is not instant death. The player drifts slowly, gets colder, loses gas and can lose items, but can climb back out by dumping ballast or cutting pieces loose.

### Optional idea

Pods are alive. Watering them could slow wilting, giving water a third use alongside drinking and ballast.

## Navigation and progression

Navigation starts crude and gets smoother with each unlock, like the oar in Raft. Currents and jetstreams only open up after the first few islands.

### Starting tools

- **Sideways:** the sky-paddle, a wide sheet of fabric on a pole swept to nudge the raft. Slow and tiring. The hook can also be thrown into an island to reel the raft in.
- **Up and down:** only the vent cord (sink) and ballast (rise). Both cost something and neither allows fine control, so every height change is a decision.

### Upgrade ladder

1. Sky-paddle
2. Hand-cranked propeller
3. Sail and rudder
4. Proper valve for fine height control
5. Burner for free up-and-down movement
6. Riding currents and jetstreams, once the player can hold a height

In the slice the player reaches steps 1 and possibly 2. Everything after is post-slice.

## Building and structures

Building is intentional: floor space costs lift, and every structure protects against something. The player builds to survive specific threats, not just to get bigger.

### Rules

- Raft-style grid of 1.5 m tiles. The rock slab counts as the first few pre-built tiles.
- Pods tether to anchor points on the slab or on planks.
- Craft by hand at first; a workbench comes later. A hotbar and a build menu; everything else is diegetic.
- Anchoring: throw the hook into an island and the raft holds there while the player explores.

### Slice build pieces (first pass)

| Piece | Weight | Purpose | Materials |
| --- | --- | --- | --- |
| Plank | Medium | Floor space | Wood, rope |
| Pod tether | Adds lift | Ties a caught pod onto an anchor point | Rope, a drift-pod |
| Patch | Light | Fixes a leaking pod | Pod skin, fiber |
| Rain catcher | Light (heavy when full) | Collects water, which is also ballast | Cloth, sticks |
| Sky-paddle | Light | Crude sideways steering | Wood, cloth |
| Vent cord and ballast sack | Light | Crude up-and-down control | Rope, cloth, sand or water |
| Roof | Medium | Shelter from caustic rain | Wood, fiber, pod skin |

### Later structures, each tied to a hazard

- Net canopy over pods (glass hail)
- Walls and railings (wind shear, falling)
- Enclosed rooms (spore drift)
- Lightning rod (murk lightning)
- Lights (ink fog)

## Survival

The slice tracks two stats, thirst and hunger. Warmth arrives later with the high air.

- **Thirst:** rain catchers and mist fans. Stored water competes with ballast.
- **Hunger:** shelf fungus at first, plus fungus that grows on the raft after spore drift (post-slice).
- **Falling off:** the screen fades and the player wakes back on the raft, cold, having lost whatever they were carrying. A safety tether unlocks later. A more creative version is an open question.
- **The murk:** soft failure, as described under Lift and weight.

## Hazards and weather

Alien weather is the main threat, and each hazard is answered by a structure. The slice has one: caustic rain.

| Hazard | Effect | Protection | In slice |
| --- | --- | --- | --- |
| Caustic rain | Burns the player and slowly eats wood | Roof | Yes |
| Glass hail | Crystal shards puncture pods | Net canopy over pods | No |
| Wind shear | Gusts blow loose items off and shove the player toward the edge | Walls and railings | No |
| Spore drift | Drains hunger and blurs vision; leaves edible fungus behind | Enclosed rooms | No |
| Murk lightning | Strikes the tallest thing on the raft | Lightning rod | No |
| Murk-tide | The murk rises and swallows the lower air | Enough lift to climb | No |
| Ink fog | Total darkness; creatures come out | Lights | No |

### The slice storm

The caustic rain storm shoves the raft off course, damages exposed pods and wood, burns the player outside, and fills rain catchers. The player should have just enough warning to finish a first roof.

## Creatures and combat

Combat is light, as in Raft: creatures harass the player and the raft now and then. Every creature floats, ripples or swarms, so none needs a skeleton.

| Creature | Behaviour | Animation method | In slice |
| --- | --- | --- | --- |
| Pod-leech | Pale jellyfish-like drifter that latches onto pods and drains gas; the Raft-shark role | Pulse shader (shared with pods) | Yes |
| Ribbon eels | Circle the raft and snatch loose items | Wave shader along the body | No |
| Lantern moths | Swarms drawn to light that shred cloth | Particles | No |
| Gliders | Flat, ray-like; dive at the player in certain zones | Wing ripple shader | No |

### Weapons

- Sharpened pole, then spear. The hook doubles as a weapon.
- Thrust and swing motions are done in code (tool movement), not with rigs.

### The giants

The vast shadows are never fought. They stay far off and unexplained in the slice; meeting one later is a major story moment.

## Islands and spawning

Islands are handmade and placed by a spawner. Spawn range grows with the player's steering, so islands start straight ahead and move further off the path as navigation improves.

### Island types

Islands should feel lively and worth exploring: elevation, caves, water and real landforms, not just a few trees on a flat top. There are four kinds (decided Nov 21, 2026):

| Type | Share of spawns | Size | What it is |
| --- | --- | --- | --- |
| Standard | Most (about 79%) | Medium, 40 to 80 m across | Assembled from a seed: an irregular base shape plus 3 to 5 landforms from the kit. The everyday island. |
| Wreck | About 1 in 6 (17%) | Small | Handmade. Salvage-heavy, with notes and red human traces. |
| Rare encounter | 3 to 5% (4%) | Varies | Handmade one-offs that are memorable on sight, such as a shell shed by a giant or a lone lantern tree. |
| Story island | Placed by progress, not chance | Large | Handmade. Carries the story beats; the slice ends on one. |

**The landform kit.** Standard islands are built from handmade pieces, so variety comes from combination while every piece is still authored: hill, cliff shelf with a ramp, cave mouth, spring with a pond and a waterfall over the edge, grove (bindwood and pod vines), rock arch, and a hangroot side. Each island's seed picks its base shape (two to four overlapping lobes) and its landforms. Art later replaces each kit piece once, and every island benefits.

### Slice islands

1. **Pod grove:** the first standard island always has a grove of pod vines; ripe pods break loose and drift downwind. Teaches the hook.
2. **Hangroot island:** the second always has a hangroot side and long root curtains. Fiber and rope.
3. Random islands follow by the shares above.
4. **The wreck (story island):** after the player has visited three islands, a large island appears with a broken airship deck snagged on a rock spire. Planks, cloth, a tool, a note, and the item that ends the slice.

Teaching islands and the story island come back if missed; random islands don't need to.

### Reachability rule

Islands spawn ahead, downwind, so the drift carries the player toward them. The offset is limited to what the player can close:

```latex
\text{time to pass} = \frac{\text{distance}}{\text{drift speed}} \qquad \text{max offset} = 0.7 \times \text{steer speed} \times \text{time to pass}
```

The same rule applies to vertical offset. Upgrading steering widens the spawn area automatically.

### Visibility rules

- Spawn within about 25 degrees above or below eye level until vertical steering improves.
- Draw the eye with waterfalls breaking into mist, plumes of drift-pods, circling birds and a faint sound.
- Missing an island is fine; the next one spawns a little sooner.

### Silhouette fade

One island shader with a reveal value from 0 to 1, driven by distance. At 0 the island is a flat dark shape against the sky; up close it blends to full colour, with fog in between. Distant islands use a low-detail mesh.

## Story and lore

The story is minimal and told through the world. There are no NPCs and no cutscenes.

- The player wakes on the raft with no memory of how they got there.
- The torn red cloth on the starting raft hints that someone was here before. Red always means a human trace.
- Notes left by that person are found on islands and in wreckage.
- The giant shadows are never explained in the slice.
- The slice ends at the wreck, where the player finds something that points onward, such as a chart or a compass that always points one way.

## Art direction

Soft painterly style: smooth, simple 3D forms with a painterly screen filter over everything, thick violet-grey fog, and colour reserved for living things and human traces.

### How the look is made

- **Models:** smooth, simple shapes with strong silhouettes and flat colours from the palette. No hand-painted textures.
- **Painterly filter:** a Kuwahara or oil-paint post-process gives every model the same brushstroke look automatically.
- **Fog and light:** thick distance fog, permanent dusk, emissive glow on pods.
- **Detail:** small touches (rope texture, wood grain, leaves) stop the minimal style looking unfinished up close.

### Three visual languages

| Language | Shape | Colour |
| --- | --- | --- |
| Life (pods, plants, trees, creatures) | Soft, round, veined | Warm amber glow; muted grey-green foliage |
| Rock | Jagged, layered like slate; flat tops, cone undersides | Cool violet-grey |
| Human traces (planks, rope, cloth) | Square-cut, lashed | Weathered wood; red only on cloth |

Anything glowing gold is lift, and the player should spot it from far away.

### Style line for every image prompt

```
Soft painterly style, smooth simple forms with subtle brushstroke texture, thick violet-grey dusk fog, muted desaturated world, warm amber glow only on living things, red only on human traces, weathered wood and rope, lonely and quiet.
```

### Reference

The approved target image (first-person view from the slab raft toward an island) sits below. The art pass is judged against it.

&#91;image: Approved style reference: first-person view from the slab raft toward a floating island in violet fog\]

## Audio and UI

Sound carries as much of the loneliness as the visuals, and the interface stays out of the way.

### Audio

- Constant wind, changing with height and storms
- Creaking rope and wood, louder as the raft gets heavier
- Soft hiss from leaking pods
- Distant low rumbles tied to the giant shadows
- Sparse music, saved for arrivals and discoveries

### UI

- Hotbar and build menu only
- Thirst and hunger shown minimally
- Diegetic feedback for everything else: the brass altitude dial, sagging pods, creaking ropes
- No minimap, no quest markers

## Technical foundation

Godot 4 with GDScript. Each system below is small enough for Claude to write and debug in one piece.

### Core systems

| System | Approach |
| --- | --- |
| Raft movement | The raft is a body moved by script (an AnimatableBody3D suits moving platforms). The player must ride along with it from day one; this is a classic bug source. |
| Lift | One script: target height from lift minus weight, raft eases toward it. |
| Wind | A function that returns a wind direction and speed for a given height. |
| Island spawner | Picks from the island pool and applies the reachability and visibility rules. Despawns islands far behind. |
| Island reveal | One shader with a 0 to 1 reveal value driven by distance. |
| Look | WorldEnvironment fog, emissive pod material, full-screen painterly post-process shader. |
| Creatures | Shader-driven motion plus simple steering scripts. |

### Rules for working with Claude

- Godot treats **Y as up**. Say "vertical" or "Y" in prompts, never "Z".
- 1 unit = 1 metre everywhere.
- The raft drifts forever, so far from the origin numbers lose precision. Plan to recentre the world around the raft from the start.

### Project hygiene

- Git for version control, with Git LFS for models and textures, pushed to a remote backup.
- Folder structure: `scenes/`, `scripts/`, `shaders/`, `assets/models/`, `assets/textures/`, `assets/audio/`, `docs/`.
- Naming: lowercase with underscores, type prefix where useful (`pod_large.glb`, `island_pod_grove.tscn`).

## Art pipeline

Blender via MCP builds most assets directly. Meshy is used only for organic pieces that need refinement. Everything passes through the same clean-up step, so the painterly filter makes it all match.

### Who builds what

| Asset | Source | Notes |
| --- | --- | --- |
| Rock slab raft | Blender MCP | Primitive shapes plus displacement |
| Pods (3 sizes) | Blender MCP | Simple teardrops; veins and glow come from the shader |
| Plank, paddle, rain catcher, roof pieces | Blender MCP | Simple geometry |
| Rope | Code | Generated along a curve in Godot |
| Cloth scraps | Blender MCP | Flat planes; flutter via shader |
| Hook | Blender MCP | Simple geometry |
| Islands (3) | Blender MCP, Meshy for detail | Blockout from shapes; Meshy for rock detail if needed |
| Bindwood trees | Meshy | Organic; needs refinement |
| Hangroot curtains | Meshy or Blender MCP | Test both |
| The wreck | Meshy | Concept #1 as the input image |
| Pod-leech | Blender MCP | Simple form; motion is a shader |
| Shadow silhouette | Blender MCP | Low-detail mesh behind fog |

### Clean-up checklist (every asset)

- [ ] Scale: 1 unit = 1 metre
- [ ] Origin at the base or attach point
- [ ] Reduce polygons to budget
- [ ] Recalculate normals; remove loose geometry
- [ ] Replace materials with flat palette colours (keep emissive on living things)
- [ ] Name per convention
- [ ] Export as .glb into `assets/models/`
- [ ] Check in Godot with fog and the painterly filter on

### Starting polygon budgets

- Small props: up to about 2,000 triangles
- Medium props and trees: up to about 8,000
- Islands: up to about 30,000, with a low-detail version for distance

### Consistency

Keep a prompt library in `docs/`: the style line, the approved reference image, and every prompt that produced an approved asset.

## Milestones

Build it ugly first: mechanics are proven with grey boxes before any final art. Each milestone has a test it must pass before the next one starts.

1. **Float and drift.** Grey slab, player walks on it while it drifts on the wind. *Done when:* walking on the moving raft never glitches.
2. **Hook, pods and lift.** Catch drift-pods, tether them, watch the resting height change; vent cord and ballast work. *Done when:* staying afloat feels tense but fair.
3. **Building.** Grid placement, the slice build pieces, weight adding up. *Done when:* every new plank feels like a cost.
4. **Islands and anchoring.** Spawner, reachability rules, reveal shader, hook anchoring, walking on islands. *Done when:* the player can reliably find and reach the teaching islands and the story island.
5. **Survival, storm and pod-leech.** Thirst, hunger, falling, caustic rain, the roof, the creature. *Done when:* the full 15 to 30 minute loop plays start to finish in grey boxes.
6. **Art and audio pass.** Real assets through the pipeline, fog, painterly filter, sound, and a living sky: flocks, drifting creatures and wind streaks so the open air feels alive between islands. *Done when:* a screenshot holds up next to the reference image.

## Open questions

- [ ] What exactly does the player find at the wreck that points onward?
- [ ] A more creative falling-off rule to replace the fade.
- [ ] Do pods need watering, giving water a third use?
- [ ] Exact recipes and numbers for lift, weight, leak rate and drift speed (tune in milestone 2).
- [ ] How the player gets onto an island from the anchored raft (jump, rope, plank bridge).
- [ ] Does "Groundless" clash with an existing game on Steam?
- [ ] Who left the red cloth and the notes?
