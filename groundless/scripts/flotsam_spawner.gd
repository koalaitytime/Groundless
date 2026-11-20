class_name FlotsamSpawner
extends Node3D
## Spawns flotsam upwind of the raft so the wind carries it past.
## Flotsam rides the full wind while the heavy raft only reaches Tuning.raft_wind_fraction
## of it, so flotsam catches up with the raft from behind. Each piece is placed so it passes
## near the raft after about Tuning.drift_pod_arrival_time.
##
## Three sources:
##  - drift-pods on their own timer, near the raft's height
##  - scattered material bundles (sometimes tangled clumps), near the raft's height
##  - flotsam streams: for a while, a steady ribbon of pieces at one height above or below
##    the raft. Change height to ride into it.
## In the "recentre" group, so flotsam (its children) moves with every recentre.

@export var raft: Raft

## Active streams: each {"height": float, "time_left": float, "timer": float}.
var streams: Array[Dictionary] = []

var _pod_timer := 0.0
var _material_timer := 0.0
var _stream_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recentre")
	add_to_group("flotsam_spawner")
	_rng.randomize()
	_pod_timer = Tuning.drift_pod_first_delay
	_material_timer = 3.0
	_stream_timer = 20.0


func _physics_process(delta: float) -> void:
	if raft == null:
		return
	_pod_timer -= delta
	if _pod_timer <= 0.0:
		spawn(["pod"])
		_pod_timer = _rng.randf_range(Tuning.drift_pod_interval_min, Tuning.drift_pod_interval_max)
	_material_timer -= delta
	if _material_timer <= 0.0:
		spawn(random_material_contents())
		_material_timer = _rng.randf_range(Tuning.flotsam_interval_min, Tuning.flotsam_interval_max)
	_update_streams(delta)
	_despawn_passed()


func _pick_material() -> String:
	var total := 0.0
	for k in Tuning.flotsam_kind_weights:
		total += Tuning.flotsam_kind_weights[k]
	var roll := _rng.randf() * total
	for k in Tuning.flotsam_kind_weights:
		roll -= Tuning.flotsam_kind_weights[k]
		if roll <= 0.0:
			return k
	return "wood"


## One material, or a clump of several (Tuning.clump_chance).
func random_material_contents() -> Array[String]:
	var contents: Array[String] = [_pick_material()]
	if _rng.randf() < Tuning.clump_chance:
		var size := _rng.randi_range(Tuning.clump_size_min, Tuning.clump_size_max)
		while contents.size() < size:
			contents.append(_pick_material())
	return contents


## Spawn one piece of flotsam upwind. `contents` may be a single kind ("rope") or a list.
## `height` defaults to near the raft's height. Returns the new Flotsam.
func spawn(contents: Variant = "pod", height: Variant = null, half_width := -1.0, half_thickness := -1.0, glint := false) -> Flotsam:
	if half_width < 0.0:
		half_width = Tuning.drift_pod_max_side_offset
	if half_thickness < 0.0:
		half_thickness = Tuning.drift_pod_max_vertical_offset
	var centre_height: float = raft.get_base_height() if height == null else height
	var h := centre_height + _rng.randf_range(-half_thickness, half_thickness)
	var relative: Vector3 = Wind.velocity_at(h) - raft.get_horizontal_velocity()
	if relative.length() < 0.2:
		relative = Wind.velocity_at(h).normalized() * 0.2
	var direction := relative.normalized()
	var side := direction.cross(Vector3.UP)
	var start := raft.global_position - direction * relative.length() * Tuning.drift_pod_arrival_time
	start += side * _rng.randf_range(-half_width, half_width)
	start.y = h
	var item := Flotsam.new()
	var list: Array[String] = []
	if contents is String:
		list.append(contents)
	else:
		list.assign(contents)
	item.contents = list
	item.glint = glint
	add_child(item)
	item.global_position = start
	return item


## Start a stream at a given height (or a random one above or below the raft).
func start_stream(height: Variant = null) -> Dictionary:
	if height == null:
		var offset := _rng.randf_range(Tuning.stream_height_offset_min, Tuning.stream_height_offset_max)
		if _rng.randf() < 0.5:
			offset = -offset
		height = clampf(raft.get_base_height() + offset, Tuning.murk_top + 5.0, Tuning.ceiling - 5.0)
	var stream := {
		"height": height,
		"time_left": _rng.randf_range(Tuning.stream_duration_min, Tuning.stream_duration_max),
		"timer": 0.0,
	}
	streams.append(stream)
	return stream


func _update_streams(delta: float) -> void:
	_stream_timer -= delta
	if _stream_timer <= 0.0 and streams.size() < 2:
		start_stream()
		_stream_timer = _rng.randf_range(Tuning.stream_interval_min, Tuning.stream_interval_max)
	for stream in streams.duplicate():
		stream.time_left -= delta
		if stream.time_left <= 0.0:
			streams.erase(stream)
			continue
		stream.timer -= delta
		if stream.timer <= 0.0:
			stream.timer = Tuning.stream_spawn_interval * _rng.randf_range(0.7, 1.3)
			var contents: Variant = ["pod"] if _rng.randf() < Tuning.stream_pod_chance else random_material_contents()
			spawn(contents, stream.height, Tuning.stream_half_width, Tuning.stream_half_thickness, true)


func _despawn_passed() -> void:
	for child in get_children():
		var item := child as Flotsam
		if item == null or item.hooked:
			continue
		var away := item.global_position - raft.global_position
		if away.length() > 150.0 or item.age > Tuning.drift_pod_arrival_time * 4.0:
			item.queue_free()
