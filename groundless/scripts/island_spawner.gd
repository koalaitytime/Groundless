class_name IslandSpawner
extends Node3D
## Places islands ahead of the raft, downwind, so the drift carries the player toward them
## (GDD "Islands and spawning"). The slice islands come in a fixed order; an island only
## counts once the player has stood on it, so a missed island comes back (sooner).
## Offsets follow the reachability rule:
##   time to pass = distance / drift speed
##   max sideways offset = island_offset_factor x steer speed x time to pass
## Steer speed is the sky-paddle's if the player has one, else a small hook-nudge speed.
## In the "recentre" group, so islands (its children) move with every recentre.

signal island_spawned(island: Island)

const SEQUENCE := ["pod_grove", "weeping_rock", "wreck"]

@export var raft: Raft
@export var player: Player

## Index into SEQUENCE of the next island the player hasn't visited.
var sequence_index := 0
## The island the player is heading for now, or null between islands.
var current: Island
var spawned_count := 0

var _timer := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recentre")
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if raft == null:
		return
	if current != null and is_instance_valid(current):
		if _is_done_with(current):
			_timer = Tuning.island_next_delay if current.visited else Tuning.island_missed_delay
			current = null
	else:
		current = null
		_timer -= delta
		if _timer <= 0.0:
			spawn_next()
	_despawn_far()


## The raft has left this island behind (visited or not) and isn't anchored to it.
func _is_done_with(island: Island) -> bool:
	var anchor := raft.get_node_or_null("Anchor") as RaftAnchor
	if anchor and anchor.is_anchored() and anchor.island == island:
		return false
	var to_island := island.global_position - raft.global_position
	to_island.y = 0.0
	var drift := raft.get_horizontal_velocity()
	var behind := drift.length() > 0.1 and to_island.dot(drift.normalized()) < -(island.radius + 40.0)
	return behind or to_island.length() > Tuning.island_spawn_distance * 1.5


func next_kind() -> String:
	if sequence_index < SEQUENCE.size():
		return SEQUENCE[sequence_index]
	return SEQUENCE[_rng.randi_range(0, SEQUENCE.size() - 1)]


## Spawn the next island ahead of the raft. Returns it.
func spawn_next() -> Island:
	var first := spawned_count == 0
	var distance := Tuning.island_first_spawn_distance if first else Tuning.island_spawn_distance
	var drift := raft.get_horizontal_velocity()
	if drift.length() < 0.3:
		drift = Wind.velocity_at(raft.get_base_height()) * Tuning.raft_wind_fraction
	var ahead := drift.normalized()
	var side := ahead.cross(Vector3.UP)
	var time_to_pass := distance / maxf(drift.length(), 0.5)
	var max_side := max_side_offset(time_to_pass)
	var max_vertical := Tuning.island_first_vertical_offset if first else Tuning.island_max_vertical_offset

	var island := Island.new()
	island.kind = next_kind()
	add_child(island)
	var position_ := raft.global_position + ahead * distance + side * _rng.randf_range(-max_side, max_side)
	position_.y = clampf(raft.get_base_height() + _rng.randf_range(-max_vertical, max_vertical), Tuning.murk_top + 15.0, Tuning.ceiling - 20.0)
	island.global_position = position_
	island.boarded.connect(_on_boarded)
	current = island
	spawned_count += 1
	island_spawned.emit(island)
	return island


func max_side_offset(time_to_pass: float) -> float:
	var steer := Tuning.island_steer_without_paddle
	if player and player.items.get("sky_paddle", 0) > 0:
		steer = Tuning.paddle_speed
	return Tuning.island_offset_factor * steer * time_to_pass


func _on_boarded(island: Island) -> void:
	if sequence_index < SEQUENCE.size() and island.kind == SEQUENCE[sequence_index]:
		sequence_index += 1


func _despawn_far() -> void:
	var anchor := raft.get_node_or_null("Anchor") as RaftAnchor
	for child in get_children():
		var island := child as Island
		if island == null or island == current:
			continue
		if anchor and anchor.is_anchored() and anchor.island == island:
			continue
		if island.global_position.distance_to(raft.global_position) > Tuning.island_spawn_distance * 1.75:
			island.queue_free()
