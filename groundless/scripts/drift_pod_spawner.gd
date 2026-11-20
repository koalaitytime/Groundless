class_name DriftPodSpawner
extends Node3D
## Spawns drift-pods upwind of the raft so the wind carries them past it.
## Drift-pods ride the full wind while the heavy raft only reaches Tuning.raft_wind_fraction
## of it, so pods catch up with the raft from behind. Each one is placed so it passes within
## hook range (sideways and vertical offsets from Tuning) after about drift_pod_arrival_time.
## In the "recentre" group, so pods (its children) move with every recentre.

@export var raft: Raft

var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recentre")
	_rng.randomize()
	_timer = Tuning.drift_pod_first_delay


func _physics_process(delta: float) -> void:
	if raft == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		spawn()
		_timer = _rng.randf_range(Tuning.drift_pod_interval_min, Tuning.drift_pod_interval_max)
	_despawn_passed()


## Spawn one drift-pod upwind. Returns it.
func spawn() -> DriftPod:
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
	var pod := DriftPod.new()
	add_child(pod)
	pod.global_position = start
	return pod


func _despawn_passed() -> void:
	for child in get_children():
		var pod := child as DriftPod
		if pod == null or pod.hooked:
			continue
		var away := pod.global_position - raft.global_position
		if away.length() > 150.0 or pod.age > Tuning.drift_pod_arrival_time * 4.0:
			pod.queue_free()
