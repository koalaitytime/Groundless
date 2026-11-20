class_name Flotsam
extends Area3D
## Something riding the wind: a ripe drift-pod, or a bundle of wood, rope, cloth or fiber.
## Catch it with the hook. Sits on physics layer 2 ("flotsam"), which the hook's ray checks.

const LAYER := 2

## "pod", "wood", "rope", "cloth" or "fiber". Set before adding to the tree.
@export var kind := "pod"

var hooked := false
var age := 0.0

var _time := randf() * 10.0
var _bob_offset := 0.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	# Generous catch radius so the hook feels fair.
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.9
	var shape := CollisionShape3D.new()
	shape.shape = sphere_shape
	add_child(shape)
	add_child(_make_visual())


func _make_visual() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	var mesh: Mesh
	match kind:
		"pod":
			material.albedo_color = Color(0.8, 0.5, 0.15)
			material.emission_enabled = true
			material.emission = Color(0.95, 0.52, 0.14)
			material.emission_energy_multiplier = 0.8
			var sphere := SphereMesh.new()
			sphere.radius = 0.38
			sphere.height = 0.9
			mesh = sphere
		"wood":
			material.albedo_color = Color(0.45, 0.32, 0.2)
			var box := BoxMesh.new()
			box.size = Vector3(1.2, 0.15, 0.25)
			mesh = box
		"rope":
			material.albedo_color = Color(0.7, 0.6, 0.42)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.3
			mesh = torus
		"cloth":
			material.albedo_color = Color(0.78, 0.72, 0.66)
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.8, 0.6)
			mesh = plane
		_:  # fiber
			material.albedo_color = Color(0.45, 0.55, 0.3)
			var bundle := CylinderMesh.new()
			bundle.top_radius = 0.12
			bundle.bottom_radius = 0.12
			bundle.height = 0.7
			mesh = bundle
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation = Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)
	return instance


func _physics_process(delta: float) -> void:
	age += delta
	if hooked:
		return
	_time += delta
	var wind: Vector3 = Wind.velocity_at(global_position.y)
	var bob := sin(_time * 1.3) * 0.25
	global_position += wind * delta + Vector3.UP * (bob - _bob_offset)
	_bob_offset = bob
	rotation.y += delta * 0.4
