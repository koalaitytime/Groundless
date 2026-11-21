class_name Interactable
extends Area3D
## Base for things the player can use with the interact key while looking at them.
## Sits on physics layer 3 ("interact"). The player's look ray finds it.

const LAYER := 4  # Physics layer 3 as a bit value.

## Size of the box the look ray can hit, in metres.
@export var hit_size := Vector3(0.5, 0.5, 0.5)
@export var hit_offset := Vector3.ZERO


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var box := BoxShape3D.new()
	box.size = hit_size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = hit_offset
	add_child(shape)


## Text shown while the player looks at this. Empty means nothing to show.
func get_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Second action (Q). Most things don't have one.
func alt_interact(_player: Player) -> void:
	pass


static func make_box(size: Vector3, colour: Color, offset := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	return instance
