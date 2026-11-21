extends Node
## Autoload "Tuning". Every gameplay number in one place, so tuning never means hunting
## through scripts. Starting values come from docs/early-design-numbers.md.
## Units: metres, seconds, kg. Lift and weight share kg: a pod's lift is the kg it holds up.
## Building pressure was relaxed after the milestone 3 playtest: pieces are lighter, pods
## stronger, and each kg costs 1 m instead of 1.5 m.

@export_group("Height")
## Each kg of spare lift (lift minus weight) raises the resting height by this much.
@export var metres_per_kg := 1.0
## Y of the murk's top surface. Below this is the murk.
@export var murk_top := 0.0
## Lowest the raft can sink.
@export var murk_floor := -60.0
## Highest resting height (top of the drift layer).
@export var ceiling := 300.0

@export_group("Easing toward resting height")
## Seconds. Vertical speed target is (resting - y) / this.
@export var height_time_constant := 6.0
@export var max_rise_speed := 2.0
@export var max_sink_speed := 3.0
## How quickly vertical speed moves toward its target (lerp rate per second).
@export var vertical_smoothing := 1.5

@export_group("Pods")
@export var pod_capacity_small := 50.0
@export var pod_capacity_medium := 100.0
@export var pod_capacity_large := 180.0
## Gas lost per minute, as a fraction of a full pod.
@export var leak_healthy_per_min := 0.02
@export var leak_damaged_per_min := 0.15
@export var leak_murk_extra_per_min := 0.03
## Gas a caught drift-pod adds to one tethered pod.
@export var refill_gas := 0.35

@export_group("Weight")
@export var slab_weight := 200.0
@export var vent_cord_weight := 2.0
@export var sandbag_weight := 10.0
@export var tether_weight := 1.0

@export_group("Controls")
## Lift removed by one pull of the vent cord, taken evenly from all pods.
@export var vent_pull_kg := 4.0

@export_group("Wind and drift")
## Wind speed in the drift layer.
@export var drift_speed := 3.0
## Wind speed in the murk.
@export var murk_drift_speed := 1.0
## Wind direction change per metre of height, in degrees (15 per 50 m).
@export var wind_turn_degrees_per_metre := 0.3
## The heavy raft only reaches this fraction of the wind speed. Drift-pods ride it fully,
## so the wind carries them to the raft.
@export var raft_wind_fraction := 0.8

@export_group("Drift-pods")
## Seconds between drift-pod spawns.
@export var drift_pod_interval_min := 30.0
@export var drift_pod_interval_max := 60.0
## The first drift-pod spawns this soon after the start.
@export var drift_pod_first_delay := 8.0
## Seconds a new drift-pod takes to reach the raft.
@export var drift_pod_arrival_time := 35.0
## How far off the raft's centre line a drift-pod passes, sideways and vertically.
@export var drift_pod_max_side_offset := 7.0
@export var drift_pod_max_vertical_offset := 5.0

@export_group("Player and hook")
@export var walk_speed := 4.0
@export var sprint_speed := 6.0
@export var jump_height := 1.2
## Rope length: the hook can't fly farther than this.
@export var hook_range := 20.0
## Throw speed at no charge and at full charge. Hold the button to charge.
@export var hook_throw_speed_min := 8.0
@export var hook_throw_speed_max := 26.0
@export var hook_charge_time := 0.8
## How far the player can reach to grab flotsam by hand, in metres.
@export var grab_reach := 2.8
@export var hook_reel_speed := 10.0
@export var hook_reel_speed_loaded := 6.0

@export_group("Flotsam")
## Seconds between material flotsam spawns (drift-pods have their own timer above).
@export var flotsam_interval_min := 10.0
@export var flotsam_interval_max := 18.0
## Relative chance of each material.
@export var flotsam_kind_weights := {"wood": 4.0, "fiber": 2.5, "rope": 2.0, "cloth": 1.5, "fungus": 1.0}
## Chance a piece of material flotsam is a tangled clump of several items. 0 turns clumps off.
@export_range(0.0, 1.0) var clump_chance := 0.3
@export var clump_size_min := 2
@export var clump_size_max := 3

@export_group("Flotsam streams")
## Ribbons of flotsam drifting at one height. Steer your height into one to gather.
@export var stream_interval_min := 40.0
@export var stream_interval_max := 70.0
## How long a stream keeps flowing, in seconds.
@export var stream_duration_min := 70.0
@export var stream_duration_max := 120.0
## How far above or below the raft a new stream appears, in metres.
@export var stream_height_offset_min := 8.0
@export var stream_height_offset_max := 25.0
## Half-thickness of a stream, in metres, and how wide it passes either side of the raft.
@export var stream_half_thickness := 1.5
@export var stream_half_width := 4.0
## Seconds between pieces in a stream.
@export var stream_spawn_interval := 1.6
## Chance a stream piece is a drift-pod rather than material.
@export var stream_pod_chance := 0.12

@export_group("Building")
@export var tile_size := 1.5
## How far away the player can place and cut pieces, in metres.
@export var build_reach := 6.0
@export var plank_weight := 6.0
@export var roof_weight := 4.0
@export var rain_catcher_weight := 2.0
@export var wind_net_weight := 3.0
## Items a wind net holds before it must be emptied.
@export var wind_net_capacity := 8
## What the player wakes up with, salvaged from the slab.
@export var starting_items := {"wood": 6, "rope": 3, "cloth": 2, "fiber": 2}
## Build menu. kind: floor (extends the raft), fixture (one per tile), roof (one per tile),
## item (crafted into the inventory). Weights are set above or by the piece itself.
@export var recipes := {
	"plank": {"name": "Plank", "kind": "floor", "cost": {"wood": 2, "rope": 1}},
	"anchor": {"name": "Pod anchor", "kind": "fixture", "cost": {"wood": 1, "rope": 1}},
	"roof": {"name": "Roof", "kind": "roof", "cost": {"wood": 2, "fiber": 2, "cloth": 1}},
	"rain_catcher": {"name": "Rain catcher", "kind": "fixture", "cost": {"wood": 1, "cloth": 1}},
	"ballast_sack": {"name": "Ballast sack", "kind": "fixture", "cost": {"cloth": 2}},
	"wind_net": {"name": "Wind net", "kind": "fixture", "cost": {"wood": 2, "rope": 2, "fiber": 2}},
	"sky_paddle": {"name": "Sky-paddle", "kind": "item", "cost": {"wood": 2, "cloth": 1}},
	"patch": {"name": "Patch", "kind": "item", "cost": {"fiber": 2, "pod": 1}},
}

@export_group("Sky-paddle")
## Sideways speed the paddle gives the raft while paddling.
@export var paddle_speed := 0.8
## Seconds of paddling before the player is tired, then seconds of rest.
@export var paddle_stamina := 8.0
@export var paddle_rest := 4.0

@export_group("Islands")
## How far ahead (downwind) a new island appears, in metres. The first is closer.
@export var island_spawn_distance := 400.0
@export var island_first_spawn_distance := 220.0
## Reachability: max sideways offset = this x steer speed x time to pass (GDD).
@export var island_offset_factor := 0.7
## Sideways steer speed without a sky-paddle (nudging with the hook), m/s.
@export var island_steer_without_paddle := 0.08
## Most an island's lip sits above or below the raft when it appears, in metres.
@export var island_max_vertical_offset := 40.0
## The first island's lip is within this many metres of the raft's height.
@export var island_first_vertical_offset := 4.0
## Seconds after an island is passed or left before the next one appears.
@export var island_next_delay := 20.0
## Island types by chance, after the two teaching islands (GDD "Island types").
@export var island_type_weights := {"standard": 0.79, "wreck": 0.17, "rare": 0.04}
## The story island (the wreck) appears once the player has visited this many islands.
@export var story_island_after_visits := 3
## A missed island comes back sooner.
@export var island_missed_delay := 8.0
## Reveal: an island is a dark silhouette beyond the far distance, full colour inside near.
@export var island_reveal_far := 320.0
@export var island_reveal_near := 90.0

@export_group("Anchoring")
## Mooring (after the milestone 4 playtest): once anchored, the rope hauls the raft level
## with the island's lip and holds it there whatever the pods are doing, so the player can
## walk straight across. Lift only matters again after casting off.
## How fast the raft is reeled toward the island, m/s.
@export var anchor_reel_speed := 1.5
## Gap left between the raft's nearest edge and the island's lip, in metres. Small enough
## to step across.
@export var anchor_gap := 0.2
## Seconds: how quickly a moored raft is hauled to the lip's height (time constant).
@export var moor_height_time := 2.0
## Fastest a moored raft is hauled up or down, m/s.
@export var moor_vertical_speed := 2.5
## Leaking while anchored: true = pods keep leaking, but only at the healthy rate (even
## damaged ones); false = no leaking while anchored. Andrew is trying this out.
@export var leak_while_anchored := true

@export_group("Boarding")
## Highest ledge the player can mantle onto, above their feet, in metres.
@export var mantle_max_height := 1.5
@export var mantle_time := 0.4
@export var climb_speed := 2.5

@export_group("Survival")
## Minutes for a full thirst or hunger bar to run empty.
@export var thirst_minutes := 12.0
@export var hunger_minutes := 20.0
## Health lost per second while thirst or hunger is empty.
@export var starving_damage := 0.5
## Health regained per second while neither thirst nor hunger is below this.
@export var health_regen := 0.5
@export var health_regen_above := 25.0
## What one drink or meal gives (out of 100).
@export var drink_amount := 30.0
@export var spring_drink_amount := 40.0
@export var fungus_food := 35.0
## Litres one drink takes from a rain catcher.
@export var drink_litres := 1.0
## Fraction of each carried material lost when you fall off or pass out (Andrew prefers forgiving).
@export var wake_item_loss := 0.5
## Thirst, hunger and health you wake up with after passing out.
@export var wake_stats := 35.0

@export_group("Storm")
## Seconds until the first storm, and between storms after that.
@export var storm_first_delay := 480.0
@export var storm_interval_min := 600.0
@export var storm_interval_max := 900.0
## Warning before the rain starts: enough to finish a first roof.
@export var storm_warning := 90.0
@export var storm_duration := 75.0
## Wind speed in a storm, and how far it swings the wind's direction, in degrees.
@export var storm_drift_speed := 6.0
@export var storm_wind_turn_degrees := 40.0
## Health lost per second standing in caustic rain without cover.
@export var rain_burn := 2.0
## Gas lost per minute by a pod with no roof over its anchor, and the chance per second the
## rain eats a hole in it (it becomes damaged and needs a patch).
@export var rain_pod_gas_per_min := 0.06
@export var rain_pod_damage_chance := 0.006
## Litres per second a rain catcher collects in rain, and per minute from passing mist.
@export var rain_fill_per_sec := 0.15
@export var mist_fill_per_min := 0.4

@export_group("Pod-leech")
@export var leech_first_delay := 240.0
@export var leech_interval_min := 180.0
@export var leech_interval_max := 300.0
## Swimming speed relative to the raft, m/s.
@export var leech_speed := 1.4
## Gas drained per minute from the pod it latches onto (GDD: 25%).
@export var leech_drain_per_min := 0.25
## Hits to kill one. The first knocks it off its pod.
@export var leech_hits := 2

@export_group("Rain and wood")
## Condition (out of 100) a plank with no roof over it loses per second of caustic rain.
## A full storm takes about 60, so an unroofed plank survives one storm but not two.
@export var rain_plank_wear := 0.8
## Roofs take the rain for what's under them, wearing at this rate instead.
@export var rain_roof_wear := 0.4
## Wood one repair costs (it restores the piece to full condition).
@export var repair_wood := 1
