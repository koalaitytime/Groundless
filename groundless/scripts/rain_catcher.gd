class_name RainCatcher
extends Interactable
## A cloth basin on legs. Collects water from caustic rain and, slowly, from passing mist.
## E drinks a litre; Q dumps it all. Water weighs 1 kg per litre, so a full catcher is
## ballast too: drink it, keep it, or dump it to rise.

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


func _physics_process(delta: float) -> void:
	if collision_layer == 0:
		return  # Cut loose.
	var storm := get_tree().get_first_node_in_group("storm") as Storm
	if storm and storm.is_raining():
		set_water(water + Tuning.rain_fill_per_sec * delta)
	else:
		set_water(water + Tuning.mist_fill_per_min / 60.0 * delta)


func get_prompt(_player: Player) -> String:
	if water < Tuning.drink_litres:
		return "Rain catcher: %.1f L (collecting)" % water
	return "Rain catcher: %.1f L\n[E] Drink   [Q] Dump it all (lose %.0f kg)" % [water, water]


func interact(player: Player) -> void:
	if water >= Tuning.drink_litres:
		set_water(water - Tuning.drink_litres)
		player.survival.drink(Tuning.drink_amount)


func alt_interact(_player: Player) -> void:
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
