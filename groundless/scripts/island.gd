class_name Island
extends StaticBody3D
## A grey-box floating island, built in code from its `kind` (milestone 6 swaps in real art).
## Origin is the centre of the lip: the walkable top is at Y = 0, a cylinder of `radius`.
## Underneath hangs a jagged cone. Hangroot curtains hang off the sides and are climbable
## (Ladder). A pale band marks the lip so the player can see the height to match, and a
## mist plume pours off one edge to draw the eye from far away.
## Every mesh uses the reveal shader; `reveal` follows the distance to the raft.

signal boarded(island: Island)

const REVEAL_SHADER := preload("res://shaders/island_reveal.gdshader")

## "pod_grove", "weeping_rock" or "wreck". Set before adding to the tree.
@export_enum("pod_grove", "weeping_rock", "wreck") var kind := "pod_grove"

var radius := 12.0
## Depth of the cone underneath, from the lip down to its tip.
var depth := 20.0
## The player has stood on it.
var visited := false
var reveal := 1.0

var _meshes: Array[GeometryInstance3D] = []
var _materials := {}
var _plume_timer := 0.0


func _ready() -> void:
	add_to_group("island")
	add_to_group("anchorable")
	match kind:
		"pod_grove":
			radius = 13.0
		"weeping_rock":
			radius = 7.0
		"wreck":
			radius = 9.0
	depth = radius * 1.6 + 2.0
	_build_body()
	match kind:
		"pod_grove":
			_build_pod_grove()
		"weeping_rock":
			_build_weeping_rock()
		"wreck":
			_build_wreck()


## Radius of the island's solid part at a given height (world Y). 0 outside it.
func radius_at(world_y: float) -> float:
	var below := global_position.y - world_y
	if below < -1.0 or below > depth:
		return 0.0
	if below <= 2.0:
		return radius
	return lerpf(radius * 0.92, 0.6, (below - 2.0) / (depth - 2.0))


func mark_boarded() -> void:
	if not visited:
		visited = true
		boarded.emit(self)


# --- Reveal --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var raft := get_tree().get_first_node_in_group("rideable") as Node3D
	if raft:
		var d := global_position.distance_to(raft.global_position)
		var target := 1.0 - smoothstep(Tuning.island_reveal_near, Tuning.island_reveal_far, d)
		if absf(target - reveal) > 0.005:
			reveal = target
			for mesh in _meshes:
				mesh.set_instance_shader_parameter("reveal", reveal)
	if kind == "pod_grove":
		_plume(delta)


## The pod grove sheds ripe pods that drift downwind: a plume you can see from afar.
func _plume(delta: float) -> void:
	_plume_timer -= delta
	if _plume_timer > 0.0:
		return
	_plume_timer = 10.0
	var spawner := get_tree().get_first_node_in_group("flotsam_spawner") as FlotsamSpawner
	if spawner == null:
		return
	var pod := Flotsam.new()
	var list: Array[String] = ["pod"]
	pod.contents = list
	spawner.add_child(pod)
	pod.global_position = global_position + Vector3(randf_range(-radius, radius) * 0.5, 3.0, randf_range(-radius, radius) * 0.5)


# --- Building blocks -----------------------------------------------------------------

func _material(colour: Color, glow := 0.0) -> ShaderMaterial:
	var key := "%s_%s" % [colour.to_html(), glow]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = REVEAL_SHADER
		m.set_shader_parameter("base_color", colour)
		if glow > 0.0:
			m.set_shader_parameter("emission_color", colour)
			m.set_shader_parameter("emission_strength", glow)
		_materials[key] = m
	return _materials[key]


func _mesh(mesh: Mesh, colour: Color, position_: Vector3, parent: Node3D = self, glow := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(colour, glow)
	instance.position = position_
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


func _box(size: Vector3, colour: Color, position_: Vector3, parent: Node3D = self, solid := false) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := _mesh(box, colour, position_, parent)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_shape(shape, position_)
	return instance


func _add_shape(shape: Shape3D, position_: Vector3, basis_ := Basis.IDENTITY) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(basis_, position_)
	add_child(collision)
	return collision


func _cylinder(top: float, bottom: float, height: float, colour: Color, position_: Vector3, parent: Node3D = self, glow := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	return _mesh(mesh, colour, position_, parent, glow)


func _sphere(r: float, colour: Color, position_: Vector3, parent: Node3D = self, glow := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.2
	return _mesh(mesh, colour, position_, parent, glow)


func _build_body() -> void:
	var rock := Color(0.42, 0.38, 0.42)
	# Walkable top slab.
	_cylinder(radius, radius * 0.92, 2.0, Color(0.36, 0.42, 0.3) if kind == "pod_grove" else rock, Vector3(0, -1.0, 0))
	var top_shape := CylinderShape3D.new()
	top_shape.radius = radius
	top_shape.height = 2.0
	_add_shape(top_shape, Vector3(0, -1.0, 0))
	# Jagged cone underneath.
	var cone_height := depth - 2.0
	_cylinder(radius * 0.92, 0.6, cone_height, rock.darkened(0.15), Vector3(0, -2.0 - cone_height * 0.5, 0))
	var cone_shape := CylinderShape3D.new()
	cone_shape.radius = radius * 0.55
	cone_shape.height = cone_height * 0.8
	_add_shape(cone_shape, Vector3(0, -2.0 - cone_height * 0.4, 0))
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var spike := _cylinder(0.9, 0.1, cone_height * 0.5, rock.darkened(0.25), Vector3(cos(a), 0, sin(a)) * radius * 0.6 + Vector3(0, -2.0 - cone_height * 0.35, 0))
		spike.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	# Pale lip band: the height to match when boarding.
	_cylinder(radius + 0.06, radius + 0.06, 0.22, Color(0.85, 0.8, 0.72), Vector3(0, -0.13, 0))
	# A few rocks on top.
	for i in 3:
		var a := TAU * i / 3.0 + 1.1
		_box(Vector3(1.2, 0.5, 0.9), rock, Vector3(cos(a), 0, sin(a)) * radius * 0.5 + Vector3(0, 0.25, 0), self, true)
	# Mist plume pouring off one edge (drawn without the reveal shader: it's mist).
	var mist_material := StandardMaterial3D.new()
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.albedo_color = Color(0.92, 0.9, 0.95, 0.22)
	mist_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mist := CylinderMesh.new()
	mist.top_radius = 0.6
	mist.bottom_radius = 3.0
	mist.height = 70.0
	mist.material = mist_material
	var mist_instance := MeshInstance3D.new()
	mist_instance.mesh = mist
	mist_instance.position = Vector3(radius + 0.5, -35.0, 0)
	add_child(mist_instance)
	# Hangroot curtains, each a ladder.
	var count := 6 if kind == "weeping_rock" else 3
	var length := 22.0 if kind == "weeping_rock" else 8.0
	for i in count:
		_add_hangroot(TAU * i / count + 0.3, length)


func _add_hangroot(angle: float, length: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(cos(angle), 0, sin(angle)) * (radius + 0.15)
	holder.rotation.y = -angle + PI * 0.5
	add_child(holder)
	var roots := Color(0.5, 0.42, 0.3)
	for j in 5:
		_box(Vector3(0.08, length * randf_range(0.7, 1.0), 0.08), roots, Vector3(-0.8 + j * 0.4, -length * 0.45, 0.0), holder)
	var ladder := Ladder.new()
	ladder.size = Vector3(2.2, length + 0.4, 1.8)
	ladder.position = Vector3(0, -length * 0.5 + 0.2, 0.5)
	holder.add_child(ladder)


func _resource(gives: Dictionary, uses: int, label: String, at: Vector3, hit: Vector3, hit_offset_ := Vector3(0, 0.6, 0)) -> ResourceNode:
	var node := ResourceNode.new()
	node.gives = gives
	node.uses = uses
	node.label = label
	node.hit_size = hit
	node.hit_offset = hit_offset_
	node.position = at
	add_child(node)
	return node


func _build_pod_grove() -> void:
	var vine := Color(0.3, 0.45, 0.25)
	var pod := Color(0.95, 0.55, 0.15)
	for i in 4:
		var a := TAU * i / 4.0
		var at := Vector3(cos(a), 0, sin(a)) * radius * 0.7
		var node := _resource({"pod": 1}, 1, "ripe pod", at, Vector3(0.8, 2.6, 0.8), Vector3(0, 1.3, 0))
		_box(Vector3(0.15, 2.0, 0.15), vine, Vector3(0, 1.0, 0), node)
		_sphere(0.4, pod, Vector3(0, 2.3, 0), node, 1.2)
	for i in 2:
		var a := TAU * i / 2.0 + 0.8
		var at := Vector3(cos(a), 0, sin(a)) * radius * 0.35
		var node := _resource({"wood": 2}, 3, "bindwood", at, Vector3(1.0, 3.0, 1.0), Vector3(0, 1.5, 0))
		var trunk := _box(Vector3(0.5, 4.0, 0.5), Color(0.38, 0.28, 0.2), Vector3(0, 2.0, 0), node)
		trunk.rotation.z = 0.25
		_sphere(1.4, Color(0.3, 0.42, 0.26), Vector3(0.5, 4.2, 0), node)
	_resource({"fiber": 2}, 2, "vine fiber", Vector3(radius * 0.2, 0, -radius * 0.55), Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0))
	_sphere(0.6, vine, Vector3(radius * 0.2, 0.4, -radius * 0.55))


func _build_weeping_rock() -> void:
	_box(Vector3(2.0, 5.0, 2.0), Color(0.45, 0.4, 0.45), Vector3(-1.5, 2.5, 1.0), self, true)
	for i in 3:
		var a := TAU * i / 3.0 + 0.9
		var at := Vector3(cos(a), 0, sin(a)) * (radius - 0.8)
		var node := _resource({"fiber": 2, "rope": 1}, 3, "hangroot", at, Vector3(1.4, 1.2, 1.4))
		_box(Vector3(1.0, 0.4, 1.0), Color(0.5, 0.42, 0.3), Vector3(0, 0.2, 0), node)


func _build_wreck() -> void:
	var wood := Color(0.48, 0.36, 0.24)
	# The rock spire the airship snagged on, and its broken deck.
	_box(Vector3(2.0, 14.0, 2.0), Color(0.4, 0.36, 0.4), Vector3(3.5, 7.0, -3.0), self, true)
	var deck := _box(Vector3(7.0, 0.3, 3.5), wood, Vector3(-0.5, 0.6, 1.0), self, true)
	deck.rotation.z = 0.08
	_box(Vector3(0.3, 4.0, 0.3), wood, Vector3(-3.0, 2.6, 1.0), self, true)  # broken mast
	# Torn red cloth: red always means someone was here.
	var flag := _box(Vector3(0.05, 1.0, 1.4), Color(0.75, 0.12, 0.1), Vector3(-3.0, 4.0, 1.75))
	flag.rotation.x = 0.2
	var planks := _resource({"wood": 3}, 3, "loose planks", Vector3(-2.5, 0.0, -2.5), Vector3(1.6, 0.8, 1.2))
	_box(Vector3(1.5, 0.3, 1.0), wood, Vector3(0, 0.15, 0), planks)
	var cloth := _resource({"cloth": 2}, 2, "sailcloth", Vector3(1.0, 0.0, 3.8), Vector3(1.4, 0.8, 1.0))
	_box(Vector3(1.2, 0.2, 0.8), Color(0.8, 0.75, 0.65), Vector3(0, 0.1, 0), cloth)
	var rope := _resource({"rope": 2}, 1, "rope coil", Vector3(2.5, 0.75, 1.5), Vector3(0.8, 0.6, 0.8))
	_cylinder(0.35, 0.35, 0.25, Color(0.7, 0.6, 0.42), Vector3(0, 0.12, 0), rope)
	var toolbox := _resource({"sky_paddle": 1}, 1, "tool chest", Vector3(-5.0, 0.0, -1.5), Vector3(1.0, 0.8, 0.8))
	_box(Vector3(0.9, 0.5, 0.6), Color(0.35, 0.25, 0.18), Vector3(0, 0.25, 0), toolbox)

	var note := StoryItem.new()
	note.label = "note"
	note.text = "\"The winds turned again last night. Three of us left now, and the pods are failing.\nIf anyone finds this: don't follow the shadows. Follow the needle.\""
	note.hit_size = Vector3(0.6, 0.4, 0.6)
	note.hit_offset = Vector3(0, 0.2, 0)
	note.position = Vector3(0.5, 0.75, -0.5)
	add_child(note)
	_box(Vector3(0.3, 0.02, 0.4), Color(0.9, 0.86, 0.75), Vector3(0, 0.02, 0), note)

	var compass := StoryItem.new()
	compass.label = "brass compass"
	compass.ends_slice = true
	compass.text = "The compass needle swings, then settles. It points one way only, out into the haze, and it doesn't move when you turn.\n\nEnd of the vertical slice. Thanks for playing."
	compass.hit_size = Vector3(0.6, 0.5, 0.6)
	compass.hit_offset = Vector3(0, 0.25, 0)
	compass.position = Vector3(-1.5, 0.78, 1.5)
	add_child(compass)
	_cylinder(0.18, 0.18, 0.08, Color(0.8, 0.62, 0.28), Vector3(0, 0.04, 0), compass, 0.4)
