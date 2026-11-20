class_name RaftLift
extends Node
## Lift minus weight sets the raft's resting height (GDD "Lift and weight").
##   lift          = sum over tethered pods of (capacity x gas)
##   surplus       = lift - weight
##   resting height = clamp(surplus x metres_per_kg, murk_floor, ceiling)
## Child of the Raft. Pods and weights find it with RaftLift.find(node).

## Weight of things on the raft other than the slab (sandbags, vent cord, tethers...).
var extra_weight := 0.0

@onready var raft: Raft = get_parent()


func _ready() -> void:
	# Set the target before the raft moves this tick.
	process_physics_priority = -20


## The RaftLift of the raft that `node` sits on, or null.
static func find(node: Node) -> RaftLift:
	var n := node
	while n != null:
		if n is Raft:
			return n.get_node_or_null("Lift") as RaftLift
		n = n.get_parent()
	return null


func pods() -> Array[TetheredPod]:
	var result: Array[TetheredPod] = []
	for node in raft.find_children("*", "TetheredPod", true, false):
		result.append(node)
	return result


func get_lift() -> float:
	var total := 0.0
	for pod in pods():
		total += pod.get_lift()
	return total


func get_capacity() -> float:
	var total := 0.0
	for pod in pods():
		total += pod.capacity
	return total


func get_weight() -> float:
	return Tuning.slab_weight + extra_weight


func get_resting_height() -> float:
	var surplus := get_lift() - get_weight()
	return clampf(surplus * Tuning.metres_per_kg, Tuning.murk_floor, Tuning.ceiling)


func is_in_murk() -> bool:
	return raft.get_base_height() < Tuning.murk_top


func add_weight(kg: float) -> void:
	extra_weight += kg


func remove_weight(kg: float) -> void:
	extra_weight = maxf(extra_weight - kg, 0.0)


## One pull of the vent cord: remove vent_pull_kg of lift, taken evenly from all pods.
func vent() -> void:
	var capacity := get_capacity()
	if capacity <= 0.0:
		return
	var gas_fraction := Tuning.vent_pull_kg / capacity
	for pod in pods():
		pod.gas = maxf(pod.gas - gas_fraction, 0.0)


func _physics_process(delta: float) -> void:
	var murk_extra := Tuning.leak_murk_extra_per_min if is_in_murk() else 0.0
	for pod in pods():
		pod.leak(delta, murk_extra)
	raft.target_height = get_resting_height()
