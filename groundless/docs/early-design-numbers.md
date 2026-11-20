# Groundless: early design numbers and open questions

Nov 20, 2026 · design pass for milestones 1 to 4. Every number here is a starting point to tune in milestone 2, not a final value. Put them all in one tunable resource (for example `scripts/tuning.gd` or a `Tuning` .tres) so they can be changed without touching code.

## 1. Starting numbers

### The lift model

Lift and weight share one unit: **kg**. A pod's lift is "kg it can hold up".

```
lift          = sum over pods of (pod capacity × pod gas)      gas is 0..1
surplus       = lift − weight
target height = clamp(surplus × METRES_PER_KG, MURK_FLOOR, CEILING)
```

Y = 0 is the top of the murk. The drift layer is roughly Y = 0 to 300 m.

### Tuning table

| Name | Start value | What it means / why |
| --- | --- | --- |
| **Height** | | |
| `METRES_PER_KG` | 1.5 m | Each kg of spare lift buys 1.5 m. One plank (15 kg) costs about 22 m of height, so a plank always shows on the dial. |
| `MURK_TOP` | 0 m | Below this is the murk. |
| `MURK_FLOOR` | −60 m | Lowest the raft can sink; soft-failure zone. |
| `CEILING` | 300 m | Top of the drift layer in the slice (high air is cut). |
| **Pod capacity** | | |
| Small pod | 40 kg | Common drift-pod. |
| Medium pod | 80 kg | Starting pods; pod grove. |
| Large pod | 150 kg | Rare; a reward at the pod grove. |
| Max pods per anchor point | 1 | Keeps lift readable as "pods overhead". |
| **Gas and leaks** | | |
| Healthy leak | 2% of gas per min | A full pod lasts about 50 min, longer than the slice. Slow background pressure, not panic. |
| Damaged leak (wilting, storm, leech hole) | 15% per min | Empty in under 7 min. This is the "fix it now" state. |
| Pod-leech drain while latched | 25% per min | Faster than a hole, so the player must act. |
| Murk extra leak | +3% per min | Stacks on top of everything while below Y = 0. |
| Catch a drift-pod as refill | +35% gas to one pod | The alternative to tethering it as a new pod. |
| Patch | Damaged → healthy | Doesn't refill gas. |
| **Weight** | | |
| Rock slab (4 pre-built tiles) | 200 kg | Fixed. |
| Plank tile | 15 kg | The core "growth costs lift" number. |
| Roof (per tile covered) | 10 kg | |
| Rain catcher, empty | 3 kg | Holds 10 L. |
| Water | 1 kg per litre | So a full catcher is 13 kg. |
| Sky-paddle | 4 kg | |
| Vent cord + ballast sack | 2 kg + 10 kg sand per sack | Dumping one sack instantly gains about 15 m of target height. |
| Pod tether | 1 kg | |
| **Controls** | | |
| Vent cord, one pull | −4 kg of lift (gas taken evenly from all pods) | About −6 m per pull. Several pulls for a big drop. |
| Ballast drop | Removes the sack's weight at once | Fast rise, costs the sand or water. |
| **Easing toward target height** | | |
| Easing | `vy = clamp((target − y) / 6.0, −3.0, +2.0)` | Time constant about 6 s. Rising is capped at 2 m/s and sinking at 3 m/s, so falls feel scarier than climbs. |
| Vertical smoothing | Lerp `vy` toward that value at 1.5 per second | Stops instant jerks when weight changes, which also helps the "player rides the raft" bug. |
| **Wind and drift** | | |
| Drift speed, drift layer | 3 m/s | A 400 m approach takes about 2 min 15 s. |
| Drift speed, murk | 1 m/s | Slow and dreadful. |
| Drift speed, storm | 6 m/s | The storm shoves you off course. |
| Wind direction change with height | 15° per 50 m | Height steers. Across the drift layer the wind swings about 90°. |
| **Steering** | | |
| Sky-paddle | 0.8 m/s sideways while paddling | Stamina limited: 8 s of paddling, 4 s rest. |
| Hand-cranked propeller | 1.6 m/s | Step 2 of the ladder. |
| **Spawning (reachability rule)** | | |
| Spawn distance | 400 m ahead, downwind | |
| Max sideways offset | 0.7 × 0.8 × 133 s ≈ 75 m | Paddle only. Doubles with the propeller. |
| Max vertical offset | ±40 m | Roughly what 2 to 3 vent pulls or sacks can close. |
| Drift-pod spawn | One every 30 to 60 s, upwind | Pod grove plume: one every 10 s. |
| **Player and hook** | | |
| Walk / sprint | 4 / 6 m/s | |
| Jump | 1.2 m high, about 2.5 m running gap | |
| Hook range | 12 m | |
| Anchor rope length | 15 m | |

### Sanity check: the opening

Slab 200 kg + paddle 4 + vent/ballast 12 = 216 kg. Three medium pods full = 240 kg, surplus 24 kg, target about 36 m above the murk.

One pod starts wilting (15% per min). In about 2 min it has lost enough that the raft sits at the murk line. The first drift-pod arrives within 45 s, and catching two of them (refills, or one tethered small pod) gets the player back to about 60 m. That's the "learn the hook to stop the fall" beat in under 3 minutes.

By the wreck, a player with 5 medium-pod equivalents (400 kg) can carry about 180 kg of building, roughly 8 to 10 planks plus a roof and catcher. That feels like a small, earned raft.

## 2. Getting from the anchored raft onto an island

### Options

| Option | Good | Bad |
| --- | --- | --- |
| Jump the gap | No new systems | Island lip is rarely at raft height, so it's frustrating and falls are common |
| Rope (hook line as a zipline or climb) | Reuses the hook | Rope-climbing needs a new movement mode; fiddly in first person |
| Plank bridge | Feels like Raft; uses the build system | Must be placed every visit; awkward when heights differ |
| **Reel in, match height, mantle** | Uses the lift controls the player just learned; no new art | Needs a simple ledge-mantle |

### Recommendation: reel in, match height, then step or mantle across

1. **Throw the hook** into the island. Reeling pulls the raft in until its nearest edge is about 1 m from the island lip, then the anchor holds it there.
2. **Match height** with the vent cord or ballast. The island lip shows a pale band of mist or roots, so the player can see the target.
3. **Cross.** Within ±0.5 m of the lip the player just walks across. Within 1.5 m above, a **mantle** (no animation: a short code-driven camera lift and push, about 0.4 s) lets them climb up. Higher than that, they need to fix the height.
4. **Fallback: hangroot.** Every island has a hangroot curtain on one side that works as a climbable ladder volume. If the raft has sunk below the lip, the player can still climb up. This also covers getting back down to a raft that sank while they explored.

Why: it turns boarding into a use of the core height mechanic rather than a new system, it needs only a mantle and a ladder volume (both small GDScript jobs, no rigs), and it fits pillar 1. A **plank bridge** can be a post-slice comfort upgrade for crossing larger gaps.

### Milestone 4 test

Anchor to each slice island from any approach angle and get aboard within 30 s without falling.

## 3. Name check: "Groundless" on Steam

**There is already a game called Groundless on Steam.**

- [Groundless (app 916780)](https://store.steampowered.com/app/916780/Groundless/) by Root121 Games, released Sep 6, 2018, $4.99. A small local-multiplayer 2v2 arena game about building and destroying the ground you stand on. It has only about 4 user reviews.
- Nearby names: [Grounded](https://store.steampowered.com/app/962130/GROUNDED/) (Obsidian, a big survival game, the same genre as yours) and Ungrounded, an upcoming first-person puzzle game ([app 2859490](https://store.steampowered.com/app/2859490)).
- There also appears to be an itch.io project named Groundless ([abcsdfwlo.itch.io/groundless](https://abcsdfwlo.itch.io/groundless/community)); the page couldn't be read.

**What it means:** Steam does allow two games with the same name, and the 2018 game is tiny and in a different genre. The real risks are search (players typing "Groundless" find the old game first, and "Grounded" sits right next to it in a survival search) and any trademark the other developer might hold. This check didn't search trademark registries.

**Recommendation:** keep "Groundless" as the working title. Decide on a final name before making a Steam page. If you keep it, a subtitle helps search (for example "Groundless: Drift"). If you change it, check each candidate on Steam, itch.io and a trademark search first.

## Decisions for Andrew

1. **Final name:** keep "Groundless" (maybe with a subtitle), or look for a new one before the Steam page?
2. **Leaks while anchored:** should pods keep leaking while the player is on an island? *Recommended: yes, but only at the healthy rate, with the rope keeping the raft within 15 m below the anchor.* That keeps a gentle "don't stay too long" pressure, and the hangroot fallback means it can't strand the player.

Everything else above is a recommendation that can go straight into milestone 2 and 4 builds unless you object.
