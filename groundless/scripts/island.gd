class_name Island
extends StaticBody3D
## A floating island, grey-box, built in code (milestone 6 swaps kit pieces for real art).
##
## Kinds (GDD "Island types"):
##  - "standard": assembled from a seed: an irregular base of 2 to 4 overlapping lobes plus
##    3 to 5 landforms from the kit (hill, cliff shelf, cave mouth, spring, grove, rock arch)
##    and hangroot sides. `theme` forces a landform for the teaching islands
##    ("grove" or "hangroot").
##  - "wreck": small, handmade, salvage and a note.
##  - "rare_shell", "rare_lantern": handmade rare encounters.
##  - "story_wreck": the large story island that ends the slice.
##
## Origin is at lip height: every lobe's walkable top is at local Y = 0. Under each lobe hangs
## a jagged cone. A pale band marks the lip so the player can see the height to match.
## Every mesh uses the reveal shader; `reveal` follows the distance to the raft.
## Solid shapes are described as circles (lobes below the lip, landforms above it) so the
## script-moved raft can be kept out of them and moored against them.

signal boarded(island: Island)

const REVEAL_SHADER := preload("res://shaders/island_reveal.gdshader")
const KIT := ["hill", "cliff", "cave", "spring", "grove", "arch"]
const ROCK := Color(0.42, 0.38, 0.42)
const GRASS := Color(0.36, 0.44, 0.3)
const WOOD := Color(0.48, 0.36, 0.24)

## Set these before adding to the tree.
@export_enum("standard", "wreck", "rare_shell", "rare_lantern", "story_wreck") var kind := "standard"
@export var theme := ""
@export var island_seed := 0

## Base lobes, island-local: {"centre": Vector3 (y = 0), "radius": float, "depth": float}.
var lobes: Array[Dictionary] = []
## Solid landforms above the lip, island-local: {"centre": Vector3, "radius": float, "height": float, "type": String}.
var features: Array[Dictionary] = []
## Landforms from the kit that made it onto this island.
var landforms: Array[String] = []
## Radius of a circle around the origin that covers every lobe.
var radius := 0.0
## The player has stood on it.
var visited := false
var reveal := 1.0

var _rng := RandomNumberGenerator.new()
var _meshes: Array[GeometryInstance3D] = []
var _materials := {}
var _plume_timer := 0.0
var _has_grove := false


func _ready() -> void:
	add_to_group("island")
	_rng.seed = island_seed if island_seed != 0 else randi()
	match kind:
		"standard":
			_build_standard()
		"wreck":
			_build_small_wreck()
		"rare_shell":
			_build_rare_shell()
		"rare_lantern":
			_build_rare_lantern()
		"story_wreck":
			_build_story_wreck()
	for lobe in lobes:
		radius = maxf(radius, lobe.centre.length() + lobe.radius)
	_build_mist_plume()


# --- Shape queries (world space) -----------------------------------------------------

## Solid circles at a world height: lobes (from lip down their cone) and landforms above
## the lip. Each is {"centre": Vector3 world, "radius": float}.
func solid_circles_at(world_y: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var below := global_position.y - world_y
	for lobe in lobes:
		var r := _lobe_radius_below(lobe, below)
		if r > 0.0:
			result.append({"centre": to_global(lobe.centre), "radius": r})
	var above := -below
	for f in features:
		if above >= -0.5 and above <= f.height:
			result.append({"centre": to_global(f.centre), "radius": f.radius})
	return result


func _lobe_radius_below(lobe: Dictionary, below: float) -> float:
	if below < -1.0 or below > lobe.depth:
		return 0.0
	if below <= 2.0:
		return lobe.radius
	return lerpf(lobe.radius * 0.92, 0.6, (below - 2.0) / (lobe.depth - 2.0))


## Lobes in world space: [{"centre": Vector3, "radius": float}].
func world_lobes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lobe in lobes:
		result.append({"centre": to_global(lobe.centre), "radius": lobe.radius})
	return result


## Is a world point (X/Z) over the island's top?
func covers(world_point: Vector3) -> bool:
	for lobe in world_lobes():
		var d := Vector2(world_point.x - lobe.centre.x, world_point.z - lobe.centre.z)
		if d.length() <= lobe.radius:
			return true
	return false


func mark_boarded() -> void:
	if not visited:
		visited = true
		boarded.emit(self)


# --- Reveal and plume --------------------------------------------------------------

func _process(delta: float) -> void:
	var raft := get_tree().get_first_node_in_group("rideable") as Node3D
	if raft:
		var d := maxf(global_position.distance_to(raft.global_position) - radius * 0.5, 0.0)
		var target := 1.0 - smoothstep(Tuning.island_reveal_near, Tuning.island_reveal_far, d)
		if absf(target - reveal) > 0.005:
			reveal = target
			for mesh in _meshes:
				mesh.set_instance_shader_parameter("reveal", reveal)
	if _has_grove:
		_plume(delta)


## A grove sheds ripe pods that drift downwind: a plume you can see from afar.
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
	pod.global_position = global_position + Vector3(_rng.randf_range(-8, 8), 4.0, _rng.randf_range(-8, 8))


# --- Mesh helpers ------------------------------------------------------------------

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


func _mesh(mesh: Mesh, colour: Color, at: Vector3, parent: Node3D = self, glow := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(colour, glow)
	instance.position = at
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


## A box, optionally solid. `basis_` rotates both the mesh and its collision.
func _box(size: Vector3, colour: Color, at: Vector3, parent: Node3D = self, solid := false, basis_ := Basis.IDENTITY) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := _mesh(box, colour, at, parent)
	instance.basis = basis_
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var parent_xform := (parent.transform if parent != self else Transform3D.IDENTITY)
		_add_shape(shape, parent_xform * Transform3D(basis_, at))
	return instance


func _add_shape(shape: Shape3D, xform: Transform3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = xform
	add_child(collision)
	return collision


func _cylinder(top: float, bottom: float, height: float, colour: Color, at: Vector3, parent: Node3D = self, glow := 0.0, solid := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	var instance := _mesh(mesh, colour, at, parent, glow)
	if solid:
		var parent_xform := (parent.transform if parent != self else Transform3D.IDENTITY)
		_add_shape(mesh.create_convex_shape(), parent_xform * Transform3D(Basis.IDENTITY, at))
	return instance


func _sphere(r: float, colour: Color, at: Vector3, parent: Node3D = self, glow := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.2
	return _mesh(mesh, colour, at, parent, glow)


func _water_material(alpha := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.62, 0.8, alpha)
	m.roughness = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- Base shape --------------------------------------------------------------------

func _add_lobe(centre: Vector3, r: float, top_colour: Color) -> void:
	var depth := r * 1.4 + 3.0
	lobes.append({"centre": centre, "radius": r, "depth": depth})
	_cylinder(r, r * 0.92, 2.0, top_colour, centre + Vector3(0, -1.0, 0))
	var top_shape := CylinderShape3D.new()
	top_shape.radius = r
	top_shape.height = 2.0
	_add_shape(top_shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, -1.0, 0)))
	var cone_height := depth - 2.0
	_cylinder(r * 0.92, 0.6, cone_height, ROCK.darkened(0.15), centre + Vector3(0, -2.0 - cone_height * 0.5, 0))
	var cone_shape := CylinderShape3D.new()
	cone_shape.radius = r * 0.55
	cone_shape.height = cone_height * 0.8
	_add_shape(cone_shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, -2.0 - cone_height * 0.4, 0)))
	var spikes := 3 + int(r / 6.0)
	for i in spikes:
		var a := TAU * i / spikes + _rng.randf() * 0.5
		var spike := _cylinder(r * 0.08 + 0.4, 0.1, cone_height * _rng.randf_range(0.4, 0.7), ROCK.darkened(0.25), centre + Vector3(cos(a), 0, sin(a)) * r * 0.6 + Vector3(0, -2.0 - cone_height * 0.35, 0))
		spike.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	# Pale lip band, just under the top so it only shows on the outside edge.
	_cylinder(r + 0.06, r + 0.06, 0.22, Color(0.85, 0.8, 0.72), centre + Vector3(0, -0.13, 0))


## A point on the outer edge of a lobe (not inside another lobe), and its outward angle.
func _edge_point() -> Dictionary:
	for attempt in 30:
		var lobe: Dictionary = lobes[_rng.randi_range(0, lobes.size() - 1)]
		var a := _rng.randf() * TAU
		var p: Vector3 = lobe.centre + Vector3(cos(a), 0, sin(a)) * lobe.radius
		var inside_other := false
		for other in lobes:
			if other != lobe and Vector2(p.x - other.centre.x, p.z - other.centre.z).length() < other.radius - 0.5:
				inside_other = true
		if not inside_other:
			return {"point": p, "angle": a, "lobe": lobe}
	return {"point": lobes[0].centre + Vector3(lobes[0].radius, 0, 0), "angle": 0.0, "lobe": lobes[0]}


## A free spot on the top for a landform of `r`, keeping `edge_margin` from the lip.
func _free_spot(r: float, edge_margin := 3.0) -> Variant:
	for attempt in 40:
		var lobe: Dictionary = lobes[_rng.randi_range(0, lobes.size() - 1)]
		var room: float = lobe.radius - r - edge_margin
		if room <= 0.0:
			continue
		var a := _rng.randf() * TAU
		var p: Vector3 = lobe.centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.0, room)
		var clear := true
		for f in features:
			if p.distance_to(f.centre) < r + f.radius + 2.0:
				clear = false
				break
		if clear:
			return p
	return null


func _add_hangroot(edge: Dictionary, length: float) -> void:
	var holder := Node3D.new()
	holder.position = edge.point + Vector3(cos(edge.angle), 0, sin(edge.angle)) * 0.15
	holder.rotation.y = -edge.angle + PI * 0.5
	add_child(holder)
	var roots := Color(0.5, 0.42, 0.3)
	for j in 6:
		_box(Vector3(0.08, length * _rng.randf_range(0.7, 1.0), 0.08), roots, Vector3(-1.0 + j * 0.4, -length * 0.45, 0.0), holder)
	var ladder := Ladder.new()
	ladder.size = Vector3(2.6, length + 0.4, 1.8)
	ladder.position = Vector3(0, -length * 0.5 + 0.2, 0.5)
	holder.add_child(ladder)
	# Gather fiber and rope where the roots meet the lip.
	var node := _resource({"fiber": 2, "rope": 1}, 2, "hangroot", edge.point - Vector3(cos(edge.angle), 0, sin(edge.angle)) * 1.0, Vector3(1.4, 1.0, 1.4), Vector3(0, 0.5, 0))
	_box(Vector3(1.0, 0.35, 1.0), roots, Vector3(0, 0.17, 0), node)


func _build_mist_plume() -> void:
	# Every island trails a mist plume off one edge so it can be spotted from far away.
	var edge := _edge_point()
	var mist_material := StandardMaterial3D.new()
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.albedo_color = Color(0.92, 0.9, 0.95, 0.18)
	mist_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mist := CylinderMesh.new()
	mist.top_radius = 0.8
	mist.bottom_radius = 4.0
	mist.height = 80.0
	mist.material = mist_material
	var mist_instance := MeshInstance3D.new()
	mist_instance.mesh = mist
	mist_instance.position = edge.point + Vector3(cos(edge.angle), 0, sin(edge.angle)) * 1.0 + Vector3(0, -40.0, 0)
	add_child(mist_instance)


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


func _scatter(count: int) -> void:
	# Small rocks and fiber bushes so the top never reads as empty.
	for i in count:
		var spot: Variant = _free_spot(0.8, 1.5)
		if spot == null:
			continue
		if _rng.randf() < 0.5:
			_box(Vector3(_rng.randf_range(0.6, 1.6), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.6, 1.4)), ROCK, spot + Vector3(0, 0.25, 0), self, true)
		else:
			var bush := _resource({"fiber": 1}, 2, "fiber bush", spot, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45, 0))
			_sphere(0.55, Color(0.38, 0.5, 0.3), Vector3(0, 0.4, 0), bush)


# --- Standard islands: base + kit --------------------------------------------------

func _build_standard() -> void:
	var main_r := _rng.randf_range(14.0, 22.0)
	_add_lobe(Vector3.ZERO, main_r, GRASS)
	for i in _rng.randi_range(1, 3):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(8.0, 14.0)
		_add_lobe(Vector3(cos(a), 0, sin(a)) * main_r * _rng.randf_range(0.6, 0.85), r, GRASS)

	var chosen: Array[String] = []
	if theme == "grove":
		chosen.append("grove")
	var pool: Array = KIT.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var count := _rng.randi_range(3, 5)
	for k in pool:
		if chosen.size() >= count:
			break
		if not chosen.has(k):
			chosen.append(k)
	for k in chosen:
		_add_landform(k)

	var curtains := 5 if theme == "hangroot" else _rng.randi_range(1, 3)
	var length := 22.0 if theme == "hangroot" else 10.0
	for i in curtains:
		_add_hangroot(_edge_point(), length)
	_scatter(6)


func _add_landform(type: String) -> void:
	var before := _meshes.size()
	_place_landform(type)
	if _meshes.size() > before:
		landforms.append(type)


func _place_landform(type: String) -> void:
	match type:
		"hill":
			var r := _rng.randf_range(5.0, 8.0)
			var spot: Variant = _free_spot(r)
			if spot == null:
				return
			var h := r * 0.5
			_cylinder(r * 0.3, r, h, GRASS.darkened(0.08), spot + Vector3(0, h * 0.5, 0), self, 0.0, true)
			features.append({"centre": spot, "radius": r, "height": h, "type": type})
			var vine := _resource({"pod": 1}, 1, "ripe pod", spot + Vector3(0, h, 0), Vector3(0.8, 2.6, 0.8), Vector3(0, 1.3, 0))
			_box(Vector3(0.15, 2.0, 0.15), Color(0.3, 0.45, 0.25), Vector3(0, 1.0, 0), vine)
			_sphere(0.4, Color(0.95, 0.55, 0.15), Vector3(0, 2.3, 0), vine, 1.2)
		"cliff":
			var spot: Variant = _free_spot(5.5)
			if spot == null:
				return
			var h := _rng.randf_range(2.5, 4.0)
			var turn := Basis(Vector3.UP, _rng.randf() * TAU)
			var holder := Node3D.new()
			holder.position = spot
			holder.basis = turn
			add_child(holder)
			_box(Vector3(8.0, h, 6.0), ROCK, Vector3(0, h * 0.5, 0), holder, true)
			# Ramp up the side.
			var run := h / tan(deg_to_rad(28.0))
			var ramp_len := sqrt(run * run + h * h)
			var slope := Basis(Vector3.RIGHT, atan2(h, run))
			_box(Vector3(2.2, 0.3, ramp_len), ROCK.lightened(0.05), Vector3(-2.9, h * 0.5, 3.0 + run * 0.5), holder, true, slope)
			var wood := _resource({"wood": 2}, 2, "bindwood", holder.transform * Vector3(1.5, h, -1.0), Vector3(1.0, 3.0, 1.0), Vector3(0, 1.5, 0))
			_box(Vector3(0.45, 3.5, 0.45), Color(0.38, 0.28, 0.2), Vector3(0, 1.75, 0), wood)
			_sphere(1.3, Color(0.3, 0.42, 0.26), Vector3(0.3, 3.8, 0), wood)
			features.append({"centre": spot, "radius": 5.5, "height": h, "type": type})
		"cave":
			var spot: Variant = _free_spot(5.5)
			if spot == null:
				return
			var holder := Node3D.new()
			holder.position = spot
			holder.basis = Basis(Vector3.UP, _rng.randf() * TAU)
			add_child(holder)
			# A rock mass with a walk-in mouth: two walls, a back and a roof.
			var dark := ROCK.darkened(0.2)
			_box(Vector3(3.0, 4.5, 7.0), ROCK, Vector3(-3.0, 2.25, 0), holder, true)
			_box(Vector3(3.0, 4.5, 7.0), ROCK, Vector3(3.0, 2.25, 0), holder, true)
			_box(Vector3(3.0, 4.5, 1.5), dark, Vector3(0, 2.25, -2.75), holder, true)
			_box(Vector3(9.0, 2.0, 7.5), ROCK, Vector3(0, 3.5, 0), holder, true)
			var cache := _resource({"rope": 1, "cloth": 1}, 2, "old cache", holder.transform * Vector3(0, 0, -1.4), Vector3(1.0, 0.8, 0.8), Vector3(0, 0.4, 0))
			_box(Vector3(0.8, 0.5, 0.6), WOOD.darkened(0.3), Vector3(0, 0.25, 0), cache)
			features.append({"centre": spot, "radius": 5.0, "height": 4.5, "type": type})
		"spring":
			var spot: Variant = _free_spot(3.0, 4.0)
			if spot == null:
				return
			var pond := CylinderMesh.new()
			pond.top_radius = 2.6
			pond.bottom_radius = 2.6
			pond.height = 0.06
			pond.material = _water_material()
			var pond_instance := MeshInstance3D.new()
			pond_instance.mesh = pond
			pond_instance.position = spot + Vector3(0, 0.04, 0)
			add_child(pond_instance)
			_cylinder(3.0, 3.1, 0.35, ROCK.lightened(0.1), spot + Vector3(0, 0.0, 0))
			# Stream to the nearest edge, then a waterfall that never lands.
			var edge := _nearest_edge(spot)
			var to_edge: Vector3 = edge.point - spot
			var stream := BoxMesh.new()
			stream.size = Vector3(0.9, 0.05, to_edge.length())
			stream.material = _water_material(0.5)
			var stream_instance := MeshInstance3D.new()
			stream_instance.mesh = stream
			stream_instance.position = spot + to_edge * 0.5 + Vector3(0, 0.05, 0)
			stream_instance.look_at_from_position(stream_instance.position, edge.point + Vector3(0, 0.05, 0))
			add_child(stream_instance)
			var fall := BoxMesh.new()
			fall.size = Vector3(1.0, 45.0, 0.15)
			fall.material = _water_material(0.35)
			var fall_instance := MeshInstance3D.new()
			fall_instance.mesh = fall
			fall_instance.position = edge.point + to_edge.normalized() * 0.4 + Vector3(0, -22.5, 0)
			fall_instance.rotation.y = atan2(to_edge.x, to_edge.z)
			add_child(fall_instance)
			var fungus := _resource({"fiber": 1}, 2, "spring reeds", spot + Vector3(2.4, 0, 0), Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0))
			_box(Vector3(0.6, 0.9, 0.6), Color(0.4, 0.55, 0.32), Vector3(0, 0.45, 0), fungus)
		"grove":
			var spot: Variant = _free_spot(6.0)
			if spot == null:
				return
			_has_grove = true
			for i in 4:
				var a := TAU * i / 4.0 + _rng.randf() * 0.5
				var vine := _resource({"pod": 1}, 1, "ripe pod", spot + Vector3(cos(a), 0, sin(a)) * 4.5, Vector3(0.8, 2.6, 0.8), Vector3(0, 1.3, 0))
				_box(Vector3(0.15, 2.0, 0.15), Color(0.3, 0.45, 0.25), Vector3(0, 1.0, 0), vine)
				_sphere(0.4, Color(0.95, 0.55, 0.15), Vector3(0, 2.3, 0), vine, 1.2)
			for i in 3:
				var a := TAU * i / 3.0 + 0.6
				var tree := _resource({"wood": 2}, 3, "bindwood", spot + Vector3(cos(a), 0, sin(a)) * 2.0, Vector3(1.0, 3.0, 1.0), Vector3(0, 1.5, 0))
				var trunk := _box(Vector3(0.5, 4.5, 0.5), Color(0.38, 0.28, 0.2), Vector3(0, 2.25, 0), tree)
				trunk.rotation.z = _rng.randf_range(-0.3, 0.3)
				_sphere(1.6, Color(0.3, 0.42, 0.26), Vector3(0, 4.6, 0), tree)
			features.append({"centre": spot, "radius": 2.5, "height": 6.0, "type": type})
		"arch":
			var spot: Variant = _free_spot(4.5)
			if spot == null:
				return
			var holder := Node3D.new()
			holder.position = spot
			holder.basis = Basis(Vector3.UP, _rng.randf() * TAU)
			add_child(holder)
			_box(Vector3(1.6, 6.0, 1.8), ROCK, Vector3(-3.0, 3.0, 0), holder, true)
			_box(Vector3(1.6, 6.0, 1.8), ROCK, Vector3(3.0, 3.0, 0), holder, true)
			_box(Vector3(8.0, 1.4, 2.0), ROCK.lightened(0.05), Vector3(0, 6.6, 0), holder, true)
			features.append({"centre": spot, "radius": 4.2, "height": 7.3, "type": type})


func _nearest_edge(spot: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for i in 24:
		var a := TAU * i / 24.0
		for lobe in lobes:
			var p: Vector3 = lobe.centre + Vector3(cos(a), 0, sin(a)) * lobe.radius
			var inside := false
			for other in lobes:
				if other != lobe and Vector2(p.x - other.centre.x, p.z - other.centre.z).length() < other.radius - 0.3:
					inside = true
			if not inside and p.distance_to(spot) < best_d:
				best_d = p.distance_to(spot)
				best = {"point": p, "angle": a}
	return best


# --- Handmade kinds ----------------------------------------------------------------

func _add_note(text: String, at: Vector3) -> StoryItem:
	var note := StoryItem.new()
	note.label = "note"
	note.text = text
	note.hit_size = Vector3(0.6, 0.4, 0.6)
	note.hit_offset = Vector3(0, 0.2, 0)
	note.position = at
	add_child(note)
	_box(Vector3(0.3, 0.02, 0.4), Color(0.9, 0.86, 0.75), Vector3(0, 0.02, 0), note)
	return note


func _airship_wreck(scale_: float, at: Vector3) -> void:
	# The rock spire the airship snagged on, its broken deck, and torn red cloth.
	_box(Vector3(2.0, 14.0, 2.0) * Vector3(1, scale_, 1), ROCK, at + Vector3(3.5, 7.0 * scale_, -3.0), self, true)
	features.append({"centre": at + Vector3(3.5, 0, -3.0), "radius": 1.5, "height": 14.0 * scale_, "type": "spire"})
	features.append({"centre": at, "radius": 5.5 * scale_, "height": 1.0, "type": "deck"})
	_box(Vector3(7.0, 0.3, 3.5) * Vector3(scale_, 1, scale_), WOOD, at + Vector3(-0.5, 0.6, 1.0), self, true, Basis(Vector3.FORWARD, 0.08))
	_box(Vector3(0.3, 4.0, 0.3), WOOD, at + Vector3(-3.0, 2.6, 1.0), self, true)
	_box(Vector3(0.05, 1.0, 1.4), Color(0.75, 0.12, 0.1), at + Vector3(-3.0, 4.0, 1.75), self, false, Basis(Vector3.RIGHT, 0.2))
	var planks := _resource({"wood": 3}, 3, "loose planks", at + Vector3(-2.5, 0, -2.5), Vector3(1.6, 0.8, 1.2))
	_box(Vector3(1.5, 0.3, 1.0), WOOD, Vector3(0, 0.15, 0), planks)
	var cloth := _resource({"cloth": 2}, 2, "sailcloth", at + Vector3(1.0, 0, 3.8), Vector3(1.4, 0.8, 1.0))
	_box(Vector3(1.2, 0.2, 0.8), Color(0.8, 0.75, 0.65), Vector3(0, 0.1, 0), cloth)
	var rope := _resource({"rope": 2}, 1, "rope coil", at + Vector3(2.5, 0.75, 1.5), Vector3(0.8, 0.6, 0.8))
	_cylinder(0.35, 0.35, 0.25, Color(0.7, 0.6, 0.42), Vector3(0, 0.12, 0), rope)


func _build_small_wreck() -> void:
	_add_lobe(Vector3.ZERO, _rng.randf_range(8.0, 10.0), ROCK)
	_airship_wreck(0.7, Vector3.ZERO)
	var notes := [
		"\"Day 31. Cut the stern loose to stay up. Lost the stove with it. Worth it.\"",
		"\"Whoever reads this: the pods sag before they fail. Watch the sag.\"",
		"\"The rain ate through the canvas in an hour. Build a roof before you need one.\"",
	]
	_add_note(notes[_rng.randi_range(0, notes.size() - 1)], Vector3(0.5, 0.75, -0.5))
	_add_hangroot(_edge_point(), 8.0)


func _build_rare_shell() -> void:
	_add_lobe(Vector3.ZERO, 11.0, ROCK)
	# A vast pale shell, shed by something enormous, lodged on the rock.
	var shell := SphereMesh.new()
	shell.radius = 8.0
	shell.height = 8.0
	shell.is_hemisphere = true
	var instance := _mesh(shell, Color(0.88, 0.84, 0.78), Vector3(0, -0.5, 0))
	instance.rotation = Vector3(0.5, 0.3, 0.2)
	var scale_node := _resource({"cloth": 3, "fiber": 3, "rope": 2}, 2, "shell lining", Vector3(-2.0, 0, 3.0), Vector3(1.4, 1.0, 1.4), Vector3(0, 0.5, 0))
	_box(Vector3(1.2, 0.3, 1.0), Color(0.9, 0.85, 0.8), Vector3(0, 0.15, 0), scale_node)
	_add_note("Scratched into the shell, in a careful hand: \"It grew this in a single season.\"", Vector3(2.5, 0, 2.0))
	_add_hangroot(_edge_point(), 12.0)


func _build_rare_lantern() -> void:
	_add_lobe(Vector3.ZERO, 6.0, ROCK)
	# One huge tree whose canopy glows like a lantern, heavy with pods.
	_box(Vector3(1.0, 9.0, 1.0), Color(0.35, 0.26, 0.2), Vector3(0, 4.5, 0), self, true)
	_sphere(4.5, Color(0.95, 0.7, 0.3), Vector3(0, 10.0, 0), self, 1.5)
	features.append({"centre": Vector3.ZERO, "radius": 4.5, "height": 14.0, "type": "lantern"})
	var pods := _resource({"pod": 1}, 4, "lantern pods", Vector3(1.5, 0, 0), Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0))
	_sphere(0.5, Color(0.95, 0.6, 0.2), Vector3(0, 0.5, 0), pods, 1.2)
	_add_hangroot(_edge_point(), 10.0)


func _build_story_wreck() -> void:
	_add_lobe(Vector3.ZERO, 32.0, GRASS)
	for i in 2:
		var a := PI * i + 0.7
		_add_lobe(Vector3(cos(a), 0, sin(a)) * 26.0, 18.0, GRASS)
	_airship_wreck(1.6, Vector3.ZERO)
	var toolbox := _resource({"sky_paddle": 1}, 1, "tool chest", Vector3(-6.0, 0.0, -2.0), Vector3(1.0, 0.8, 0.8))
	_box(Vector3(0.9, 0.5, 0.6), Color(0.35, 0.25, 0.18), Vector3(0, 0.25, 0), toolbox)
	_add_note("\"The winds turned again last night. Three of us left now, and the pods are failing.\nIf anyone finds this: don't follow the shadows. Follow the needle.\"", Vector3(0.5, 0.75, -0.5))
	var compass := StoryItem.new()
	compass.label = "brass compass"
	compass.ends_slice = true
	compass.text = "The compass needle swings, then settles. It points one way only, out into the haze, and it doesn't move when you turn.\n\nEnd of the vertical slice. Thanks for playing."
	compass.hit_size = Vector3(0.6, 0.5, 0.6)
	compass.hit_offset = Vector3(0, 0.25, 0)
	compass.position = Vector3(-1.5, 0.78, 1.5)
	add_child(compass)
	_cylinder(0.18, 0.18, 0.08, Color(0.8, 0.62, 0.28), Vector3(0, 0.04, 0), compass, 0.4)
	for k in ["hill", "spring", "cave", "grove"]:
		_add_landform(k)
	for i in 4:
		_add_hangroot(_edge_point(), 18.0)
	_scatter(8)
