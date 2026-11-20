class_name VentCord
extends Interactable
## Pull to release gas and sink. Each pull removes Tuning.vent_pull_kg of lift.

var _lift: RaftLift
var _handle: Node3D
var _tween: Tween


func _ready() -> void:
	hit_size = Vector3(0.35, 1.2, 0.35)
	hit_offset = Vector3(0, 1.1, 0)
	super()
	_lift = RaftLift.find(self)
	if _lift:
		_lift.add_weight(Tuning.vent_cord_weight)
	# A post with an arm, a cord hanging from it, and a wooden handle.
	add_child(make_box(Vector3(0.1, 2.0, 0.1), Color(0.4, 0.32, 0.24), Vector3(0, 1.0, -0.3)))
	add_child(make_box(Vector3(0.08, 0.08, 0.4), Color(0.4, 0.32, 0.24), Vector3(0, 1.95, -0.12)))
	_handle = Node3D.new()
	add_child(_handle)
	_handle.add_child(make_box(Vector3(0.02, 0.9, 0.02), Color(0.6, 0.52, 0.4), Vector3(0, 1.5, 0)))
	_handle.add_child(make_box(Vector3(0.18, 0.06, 0.06), Color(0.35, 0.25, 0.18), Vector3(0, 1.03, 0)))


func get_prompt(_player: Player) -> String:
	return "[E] Pull vent cord (sink)"


func interact(_player: Player) -> void:
	if _lift:
		_lift.vent()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_handle, "position:y", -0.25, 0.12)
	_tween.tween_property(_handle, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
