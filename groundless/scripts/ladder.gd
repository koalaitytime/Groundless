class_name Ladder
extends Node3D
## A climbable volume, such as a hangroot curtain. The player climbs while inside it.
## The box is centred on this node, `size` in local metres. Its top is where climbing ends.

@export var size := Vector3(2.0, 10.0, 1.6)


func _ready() -> void:
	add_to_group("ladder")


func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5


func top_y() -> float:
	return (global_transform * Vector3(0, size.y * 0.5, 0)).y
