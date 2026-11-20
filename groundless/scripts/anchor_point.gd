class_name AnchorPoint
extends Interactable
## A stake on the raft that one pod can be tethered to.
## Empty + carrying a drift-pod: tether it (adds a small pod's capacity, full of gas).
## Occupied + carrying a drift-pod: refill this pod's gas instead.
## Damaged pod + carrying a patch: patch it.

## Pod tethered here at the start. 0 = empty anchor.
@export var start_capacity := 0.0
@export_range(0.0, 1.0) var start_gas := 1.0
@export var start_damaged := false

var pod: TetheredPod
var _lift: RaftLift


func _ready() -> void:
	hit_size = Vector3(0.45, 0.6, 0.45)
	hit_offset = Vector3(0, 0.3, 0)
	super()
	add_child(make_box(Vector3(0.12, 0.45, 0.12), Color(0.42, 0.33, 0.24), Vector3(0, 0.225, 0)))
	_lift = RaftLift.find(self)
	if start_capacity > 0.0:
		tether(start_capacity, start_gas, start_damaged)


func tether(capacity: float, gas: float, damaged := false) -> void:
	pod = TetheredPod.new()
	pod.capacity = capacity
	pod.gas = gas
	pod.damaged = damaged
	pod.position = Vector3(0, 0.45, 0)
	add_child(pod)
	if _lift:
		_lift.add_weight(Tuning.tether_weight)


func get_prompt(player: Player) -> String:
	if pod == null:
		if player.held_pods > 0:
			return "[E] Tether drift-pod here"
		return "Empty anchor point"
	var status := "Pod %d%%%s" % [roundi(pod.gas * 100.0), "  (wilting)" if pod.damaged else ""]
	if pod.damaged and player.items.get("patch", 0) > 0:
		return "%s\n[E] Patch the pod (stops the fast leak)" % status
	if player.held_pods > 0 and pod.gas < 0.99:
		return "%s\n[E] Refill with drift-pod (+%d%%)" % [status, roundi(Tuning.refill_gas * 100.0)]
	return status


func interact(player: Player) -> void:
	if pod and pod.damaged and player.items.get("patch", 0) > 0:
		pod.damaged = false
		player.items.patch -= 1
		return
	if player.held_pods <= 0:
		return
	if pod == null:
		tether(Tuning.pod_capacity_small, 1.0)
	elif pod.gas < 0.99:
		pod.refill(Tuning.refill_gas)
	else:
		return
	player.held_pods -= 1


## Called when this anchor is cut loose: its pod goes with it.
func on_cut() -> void:
	if pod and _lift:
		_lift.remove_weight(Tuning.tether_weight)
	collision_layer = 0
