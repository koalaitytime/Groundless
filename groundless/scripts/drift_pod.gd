class_name DriftPod
extends Area3D
## A ripe pod that broke loose and rides the wind. Catch it with the hook.
## Sits on physics layer 2 ("pods"), which the hook's ray checks.

const LAYER := 2

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

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.5, 0.15)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.52, 0.14)
	material.emission_energy_multiplier = 0.8
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.9
	mesh.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	add_child(ball)


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
