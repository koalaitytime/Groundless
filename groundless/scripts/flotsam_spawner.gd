class_name FlotsamSpawner
extends Node3D
## Spawns flotsam (drift-pods and material bundles) upwind of the raft so the wind carries
## it past. Flotsam rides the full wind while the heavy raft only reaches
## Tuning.raft_wind_fraction of it, so flotsam catches up with the raft from behind. Each
## piece is placed so it passes within hook range (sideways and vertical offsets from Tuning)
## after about drift_pod_arrival_time.
## In the "recentre" group, so flotsam (its children) moves with every recentre.

@export var raft: Raft

var _pod_timer := 0.0
var _material_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recentre")
	_rng.randomize()
	_pod_timer = Tuning.drift_pod_first_delay
	_material_timer = 3.0


func _physics_process(delta: float) -> void:
	if raft == null:
		return
	_pod_timer -= delta
	if _pod_timer <= 0.0:
		spawn("pod")
		_pod_timer = _rng.randf_range(Tuning.drift_pod_interval_min, Tuning.drift_pod_interval_max)
	_material_timer -= delta
	if _material_timer <= 0.0:
		spawn(_pick_material())
		_material_timer = _rng.randf_range(Tuning.flotsam_interval_min, Tuning.flotsam_interval_max)
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


## Spawn one piece of flotsam upwind. Returns it.
func spawn(kind := "pod") -> Flotsam:
	var base := raft.global_position
	var height := raft.get_base_height() + _rng.randf_range(-Tuning.drift_pod_max_vertical_offset, Tuning.drift_pod_max_vertical_offset)
	var relative: Vector3 = Wind.velocity_at(height) - Vector3(raft.velocity.x, 0.0, raft.velocity.z)
	if relative.length() < 0.2:
		relative = Wind.velocity_at(height).normalized() * 0.2
	var direction := relative.normalized()
	var side := direction.cross(Vector3.UP)
	var start := base - direction * relative.length() * Tuning.drift_pod_arrival_time
	start += side * _rng.randf_range(-Tuning.drift_pod_max_side_offset, Tuning.drift_pod_max_side_offset)
	start.y = height
	var item := Flotsam.new()
	item.kind = kind
	add_child(item)
	item.global_position = start
	return item


func _despawn_passed() -> void:
	for child in get_children():
		var item := child as Flotsam
		if item == null or item.hooked:
			continue
		var away := item.global_position - raft.global_position
		if away.length() > 150.0 or item.age > Tuning.drift_pod_arrival_time * 4.0:
			item.queue_free()
