extends Node
## Autoload "Tuning". Every gameplay number in one place, so tuning never means hunting
## through scripts. Starting values come from docs/early-design-numbers.md.
## Units: metres, seconds, kg. Lift and weight share kg: a pod's lift is the kg it holds up.

@export_group("Height")
## Each kg of spare lift (lift minus weight) raises the resting height by this much.
@export var metres_per_kg := 1.5
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
@export var pod_capacity_small := 40.0
@export var pod_capacity_medium := 80.0
@export var pod_capacity_large := 150.0
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
@export var hook_range := 12.0
@export var hook_throw_speed := 24.0
@export var hook_reel_speed := 10.0
@export var hook_reel_speed_loaded := 6.0
