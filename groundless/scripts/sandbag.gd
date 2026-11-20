class_name Sandbag
extends Interactable
## Ballast. Drop it over the side to shed Tuning.sandbag_weight at once and rise.

var _lift: RaftLift
var _dropped := false
var _fall_velocity := Vector3.ZERO
var _fall_time := 0.0


func _ready() -> void:
	hit_size = Vector3(0.6, 0.4, 0.45)
	hit_offset = Vector3(0, 0.18, 0)
	super()
	add_child(make_box(Vector3(0.5, 0.3, 0.36), Color(0.62, 0.55, 0.4), Vector3(0, 0.15, 0)))
	_lift = RaftLift.find(self)
	if _lift:
		_lift.add_weight(Tuning.sandbag_weight)


func get_prompt(_player: Player) -> String:
	return "" if _dropped else "[E] Drop sandbag (rise)"


func interact(_player: Player) -> void:
	if _dropped:
		return
	_dropped = true
	collision_layer = 0
	if _lift:
		_lift.remove_weight(Tuning.sandbag_weight)
		_fall_velocity = _lift.raft.velocity
	# Leave the raft and fall through the sky.
	top_level = true
	WorldOrigin.recentred.connect(_on_recentred)


func _physics_process(delta: float) -> void:
	if not _dropped:
		return
	_fall_time += delta
	_fall_velocity.y -= 9.8 * delta
	global_position += _fall_velocity * delta
	if _fall_time > 6.0:
		queue_free()


func _on_recentred(shift: Vector3) -> void:
	global_position -= shift


## Called when cut loose with the hammer.
func on_cut() -> void:
	if not _dropped and _lift:
		_lift.remove_weight(Tuning.sandbag_weight)
	_dropped = true
	collision_layer = 0
