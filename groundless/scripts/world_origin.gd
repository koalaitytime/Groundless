extends Node
## Autoload "WorldOrigin". Keeps the raft near the origin so float precision never degrades.
##
## When the focus (the raft) drifts more than `threshold` metres from the origin on X/Z,
## every node in the "recentre" group is shifted back by the same amount in one physics tick.
## Put only top-level nodes in the group (a child of a member moves with its parent).
## Height (Y) is never shifted: wind and lift depend on it.
## Anything that caches global positions should listen to `recentred` and subtract the shift.

signal recentred(shift: Vector3)

## Horizontal distance from the origin that triggers a recentre, in metres.
@export var threshold := 1024.0

## The node to keep near the origin. The raft sets this.
var focus: Node3D
## Total shift applied so far. absolute position = local position + origin_offset.
var origin_offset := Vector3.ZERO


func _ready() -> void:
	# Run after the raft and player have moved this tick.
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	if focus == null or not is_instance_valid(focus):
		return
	var p := focus.global_position
	if Vector2(p.x, p.z).length() >= threshold:
		recentre(Vector3(p.x, 0.0, p.z))


func recentre(shift: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("recentre"):
		if node is Node3D:
			node.global_position -= shift
	origin_offset += shift
	recentred.emit(shift)


func to_absolute(local_position: Vector3) -> Vector3:
	return local_position + origin_offset
