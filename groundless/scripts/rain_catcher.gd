class_name RainCatcher
extends Interactable
## A cloth basin on legs. Collects water (rain comes with the storm in milestone 5).
## Water weighs 1 kg per litre, so a full catcher is ballast you can dump.

const CAPACITY_LITRES := 10.0

var water := 0.0
var _lift: RaftLift


func _ready() -> void:
	hit_size = Vector3(1.0, 0.8, 1.0)
	hit_offset = Vector3(0, 0.4, 0)
	super()
	var wood := Color(0.42, 0.33, 0.24)
	for corner in [Vector3(-0.4, 0, -0.4), Vector3(0.4, 0, -0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, 0.4)]:
		add_child(make_box(Vector3(0.06, 0.6, 0.06), wood, corner + Vector3(0, 0.3, 0)))
	add_child(make_box(Vector3(0.95, 0.08, 0.95), Color(0.78, 0.72, 0.66), Vector3(0, 0.6, 0)))
	_lift = RaftLift.find(self)
	if _lift:
		_lift.add_weight(Tuning.rain_catcher_weight)


func get_prompt(_player: Player) -> String:
	if water <= 0.0:
		return "Rain catcher (empty)"
	return "Rain catcher: %.1f L\n[E] Dump the water (lose %.0f kg)" % [water, water]


func interact(_player: Player) -> void:
	if water > 0.0:
		set_water(0.0)


func set_water(litres: float) -> void:
	litres = clampf(litres, 0.0, CAPACITY_LITRES)
	if _lift:
		_lift.add_weight(litres - water)
	water = litres


func on_cut() -> void:
	if _lift:
		_lift.remove_weight(Tuning.rain_catcher_weight + water)
	collision_layer = 0
