class_name Flotsam
extends Area3D
## Something riding the wind: a ripe drift-pod, a bundle of wood, rope, cloth or fiber, or a
## tangled clump of several. Catch it with the hook, a wind net, or grab it by hand (E).
## Sits on physics layer 2 ("flotsam").

const LAYER := 2

## What catching this gives: each entry is "pod", "wood", "rope", "cloth" or "fiber".
## Set before adding to the tree. More than one entry makes a clump.
var contents: Array[String] = ["pod"]
## Stream pieces glint so a stream reads from far away.
var glint := false
var hooked := false
var age := 0.0

var _time := randf() * 10.0
var _bob_offset := 0.0
var _glint_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	# Generous catch radius so the hook feels fair.
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.9 if contents.size() == 1 else 1.2
	var shape := CollisionShape3D.new()
	shape.shape = sphere_shape
	add_child(shape)
	var offsets := [Vector3.ZERO, Vector3(0.35, 0.2, 0.1), Vector3(-0.3, -0.15, 0.25), Vector3(0.05, 0.3, -0.35)]
	for i in contents.size():
		var visual := Flotsam.make_visual(contents[i])
		visual.position = offsets[i % offsets.size()]
		add_child(visual)
	if glint:
		_glint_material = StandardMaterial3D.new()
		_glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_material.albedo_color = Color(1.0, 0.92, 0.7)
		var spark := SphereMesh.new()
		spark.radius = 0.1
		spark.height = 0.2
		spark.material = _glint_material
		var spark_instance := MeshInstance3D.new()
		spark_instance.mesh = spark
		spark_instance.position = Vector3(0, 0.45, 0)
		add_child(spark_instance)


## Human-readable list, e.g. "wood + rope".
func describe() -> String:
	var names: Array[String] = []
	for k in contents:
		names.append("drift-pod" if k == "pod" else k)
	return " + ".join(names)


func give_to(player: Player) -> void:
	for k in contents:
		player.add_item(k)


static func make_visual(kind: String) -> MeshInstance3D:
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
		"fungus":
			material.albedo_color = Color(0.85, 0.62, 0.42)
			var cap := SphereMesh.new()
			cap.radius = 0.3
			cap.height = 0.3
			cap.is_hemisphere = true
			mesh = cap
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
	if _glint_material:
		var pulse := 0.6 + 0.4 * sin(_time * 5.0)
		_glint_material.albedo_color = Color(1.0, 0.92, 0.7) * pulse
