class_name RaftBuilder
extends Node
## Building on the raft's grid (GDD "Building and structures").
##
## The raft is a grid of Tuning.tile_size tiles in raft-local X/Z. The rock slab covers
## tiles -1..1 on both axes. Each tile holds a floor (slab or plank), at most one fixture
## (anchor, rain catcher, ballast sack, or a pre-built slab fixture) and at most one roof.
## Planks must touch existing floor. Plank and roof collision shapes go straight onto the
## raft body, so riding and walking on new floor just work.
## Child of the Raft, named "Build".

const SLAB_RADIUS := 1  # Slab covers tiles -1..1.

## Vector2i -> {"floor": "slab" or a plank Node3D, "shape": CollisionShape3D or null,
##              "fixture": Node3D or null, "roof": Node3D or null, "roof_shape": ...}
var tiles := {}

var _ghost: MeshInstance3D
var _ghost_material := StandardMaterial3D.new()
var _ghost_meshes := {}

@onready var raft: Raft = get_parent()
@onready var lift: RaftLift = raft.get_node("Lift")


func _ready() -> void:
	for x in range(-SLAB_RADIUS, SLAB_RADIUS + 1):
		for z in range(-SLAB_RADIUS, SLAB_RADIUS + 1):
			tiles[Vector2i(x, z)] = _empty_tile("slab")
	# Pre-built slab fixtures (anchors, vent cord, dial, sandbag) take up their tiles.
	for child in raft.get_children():
		if child is Interactable or child is AltitudeDial:
			var tile := tile_of(child.position)
			if tiles.has(tile) and tiles[tile].fixture == null:
				tiles[tile].fixture = child

	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.no_depth_test = false
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _ghost_material
	_ghost.visible = false
	raft.add_child.call_deferred(_ghost)


func _empty_tile(floor_value) -> Dictionary:
	return {"floor": floor_value, "shape": null, "fixture": null, "roof": null, "roof_shape": null}


# --- Grid helpers -------------------------------------------------------------------

func tile_of(local: Vector3) -> Vector2i:
	return Vector2i(roundi(local.x / Tuning.tile_size), roundi(local.z / Tuning.tile_size))


func tile_centre(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * Tuning.tile_size, 0.0, tile.y * Tuning.tile_size)


func has_floor(tile: Vector2i) -> bool:
	return tiles.has(tile)


func _touches_floor(tile: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tiles.has(tile + d):
			return true
	return false


## The tile the camera is aiming at on the deck plane, or null if out of reach.
func aim_tile(camera: Camera3D) -> Variant:
	var to_local := raft.global_transform.affine_inverse()
	var origin := to_local * camera.global_position
	var direction := (to_local.basis * -camera.global_basis.z).normalized()
	if direction.y > -0.05:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0 or distance > Tuning.build_reach:
		return null
	return tile_of(origin + direction * distance)


# --- Placing ------------------------------------------------------------------------

## Weight a piece adds, in kg.
func weight_of(id: String) -> float:
	match id:
		"plank":
			return Tuning.plank_weight
		"roof":
			return Tuning.roof_weight
		"rain_catcher":
			return Tuning.rain_catcher_weight
		"ballast_sack":
			return Tuning.sandbag_weight
		"wind_net":
			return Tuning.wind_net_weight
	return 0.0


## Why a piece can't go on a tile, or "" if it can.
func placement_problem(id: String, tile: Vector2i, player: Player) -> String:
	var recipe: Dictionary = Tuning.recipes[id]
	match recipe.kind:
		"floor":
			if tiles.has(tile):
				return "Already floor here"
			if not _touches_floor(tile):
				return "Must touch the raft"
		"fixture":
			if not tiles.has(tile):
				return "Needs floor"
			if tiles[tile].fixture != null:
				return "Tile is taken"
		"roof":
			if not tiles.has(tile):
				return "Needs floor"
			if tiles[tile].roof != null:
				return "Already roofed"
	if not player.has_items(recipe.cost):
		return "Not enough materials"
	return ""


func place(id: String, tile: Vector2i, player: Player) -> bool:
	if placement_problem(id, tile, player) != "":
		return false
	player.spend_items(Tuning.recipes[id].cost)
	var centre := tile_centre(tile)
	match id:
		"plank":
			_add_plank(tile)
		"roof":
			_add_roof(tile)
		"anchor":
			_add_fixture(tile, AnchorPoint.new(), centre, id)
		"rain_catcher":
			_add_fixture(tile, RainCatcher.new(), centre, id)
		"ballast_sack":
			_add_fixture(tile, Sandbag.new(), centre, id)
		"wind_net":
			var net := WindNet.new()
			net.rotation.y = facing_yaw(player)
			_add_fixture(tile, net, centre, id)
	return true


func _add_plank(tile: Vector2i) -> void:
	var size := Vector3(Tuning.tile_size - 0.03, 0.15, Tuning.tile_size - 0.03)
	var centre := tile_centre(tile) + Vector3(0, -0.075, 0)
	var mesh := Interactable.make_box(size, Color(0.5, 0.38, 0.25), centre)
	mesh.set_meta("built", true)
	mesh.set_meta("recipe", "plank")
	raft.add_child(mesh)
	var shape := _add_shape(size, centre)
	tiles[tile] = _empty_tile(mesh)
	tiles[tile].shape = shape
	lift.add_weight(Tuning.plank_weight)


func _add_roof(tile: Vector2i) -> void:
	var roof := Node3D.new()
	roof.position = tile_centre(tile)
	roof.set_meta("built", true)
	roof.set_meta("recipe", "roof")
	var wood := Color(0.42, 0.33, 0.24)
	var inset := Tuning.tile_size * 0.5 - 0.1
	for corner in [Vector3(-inset, 0, -inset), Vector3(inset, 0, -inset), Vector3(-inset, 0, inset), Vector3(inset, 0, inset)]:
		roof.add_child(Interactable.make_box(Vector3(0.08, 2.3, 0.08), wood, corner + Vector3(0, 1.15, 0)))
	var top_size := Vector3(Tuning.tile_size, 0.08, Tuning.tile_size)
	roof.add_child(Interactable.make_box(top_size, Color(0.55, 0.5, 0.36), Vector3(0, 2.34, 0)))
	raft.add_child(roof)
	tiles[tile].roof = roof
	tiles[tile].roof_shape = _add_shape(top_size, tile_centre(tile) + Vector3(0, 2.34, 0))
	lift.add_weight(Tuning.roof_weight)


func _add_fixture(tile: Vector2i, node: Node3D, centre: Vector3, id: String) -> void:
	node.position = centre
	node.set_meta("built", true)
	node.set_meta("recipe", id)
	raft.add_child(node)
	tiles[tile].fixture = node


func _add_shape(size: Vector3, centre: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = centre
	raft.add_child(shape)
	return shape


## The player's facing in raft space, snapped to 90 degrees (for nets).
func facing_yaw(player: Player) -> float:
	var forward := raft.global_basis.inverse() * -player.camera.global_basis.z
	var yaw := atan2(-forward.x, -forward.z)
	return snappedf(yaw, PI / 2.0)


# --- Cutting loose ------------------------------------------------------------------

## Cut loose the top-most built thing on a tile: fixture, then roof, then the plank itself.
## A plank takes everything on it, and any planks left unconnected to the slab fall too.
## Returns false if there is nothing built to cut.
func cut(tile: Vector2i) -> bool:
	if not tiles.has(tile):
		return false
	var t: Dictionary = tiles[tile]
	if t.fixture != null and t.fixture.has_meta("built"):
		_cut_fixture(t)
		return true
	if t.roof != null:
		_cut_roof(t)
		return true
	if t.floor is Node3D:
		_cut_plank(tile)
		_drop_unconnected()
		return true
	return false


func describe_cut(tile: Vector2i) -> String:
	if not tiles.has(tile):
		return ""
	var t: Dictionary = tiles[tile]
	if t.fixture != null and t.fixture.has_meta("built"):
		return "fixture"
	if t.roof != null:
		return "roof"
	if t.floor is Node3D:
		return "plank"
	return ""


func _cut_fixture(t: Dictionary) -> void:
	var node: Node3D = t.fixture
	if node.has_method("on_cut"):
		node.on_cut()
	t.fixture = null
	_drop(node)


func _cut_roof(t: Dictionary) -> void:
	lift.remove_weight(Tuning.roof_weight)
	t.roof_shape.queue_free()
	_drop(t.roof)
	t.roof = null
	t.roof_shape = null


func _cut_plank(tile: Vector2i) -> void:
	var t: Dictionary = tiles[tile]
	if t.fixture != null:
		_cut_fixture(t)
	if t.roof != null:
		_cut_roof(t)
	lift.remove_weight(Tuning.plank_weight)
	t.shape.queue_free()
	_drop(t.floor)
	tiles.erase(tile)


func _drop_unconnected() -> void:
	var reached := {}
	var queue: Array[Vector2i] = []
	for tile in tiles:
		if tiles[tile].floor is String:
			reached[tile] = true
			queue.append(tile)
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = tile + d
			if tiles.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	for tile in tiles.keys():
		if not reached.has(tile):
			_cut_plank(tile)


# --- Removing (fixing mistakes) ----------------------------------------------------

## What remove() would take off this tile ("" if nothing), and why it can't, if it can't.
func describe_remove(tile: Vector2i) -> Dictionary:
	var what := describe_cut(tile)
	if what == "":
		return {"what": "", "problem": ""}
	var t: Dictionary = tiles[tile]
	var node: Node3D = t.fixture if what == "fixture" else (t.roof if what == "roof" else t.floor)
	var id: String = node.get_meta("recipe", "")
	var problem := ""
	if what == "plank" and _would_disconnect(tile):
		problem = "Remove the planks beyond this one first"
	return {"what": what, "name": Tuning.recipes[id].name if id != "" else what, "problem": problem}


## Take the top-most built piece off a tile and give its full cost back. Nothing falls:
## a plank that other planks depend on can't be removed (cut it loose instead).
## A pod on a removed anchor comes back as a drift-pod. Returns true if something was removed.
func remove(tile: Vector2i, player: Player) -> bool:
	var info := describe_remove(tile)
	if info.what == "" or info.problem != "":
		return false
	var t: Dictionary = tiles[tile]
	var node: Node3D
	match info.what:
		"fixture":
			node = t.fixture
			if node is AnchorPoint and node.pod:
				player.held_pods += 1
			if node.has_method("on_cut"):
				node.on_cut()
			t.fixture = null
		"roof":
			node = t.roof
			lift.remove_weight(Tuning.roof_weight)
			t.roof_shape.queue_free()
			t.roof = null
			t.roof_shape = null
		"plank":
			node = t.floor
			lift.remove_weight(Tuning.plank_weight)
			t.shape.queue_free()
			tiles.erase(tile)
	var id: String = node.get_meta("recipe", "")
	if id != "":
		for k in Tuning.recipes[id].cost:
			player.add_item(k, Tuning.recipes[id].cost[k])
	node.queue_free()
	return true


func _would_disconnect(tile: Vector2i) -> bool:
	var saved: Dictionary = tiles[tile]
	tiles.erase(tile)
	var reached := {}
	var queue: Array[Vector2i] = []
	for t in tiles:
		if tiles[t].floor is String:
			reached[t] = true
			queue.append(t)
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + d
			if tiles.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	var disconnects := reached.size() < tiles.size()
	tiles[tile] = saved
	return disconnects


## Let a cut piece fall away into the sky.
func _drop(node: Node3D) -> void:
	var scene := raft.get_parent()
	node.reparent(scene, true)
	var tween := node.create_tween()
	tween.tween_property(node, "global_position", node.global_position + Vector3(0, -60, 0), 4.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation", node.rotation + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), 4.0)
	tween.tween_callback(node.queue_free)


# --- Preview ------------------------------------------------------------------------

func show_ghost(id: String, tile: Variant, player: Player) -> String:
	if tile == null or not Tuning.recipes.has(id) or Tuning.recipes[id].kind == "item":
		_ghost.visible = false
		return ""
	var problem := placement_problem(id, tile, player)
	_ghost.mesh = _ghost_mesh(id)
	_ghost.rotation = Vector3.ZERO
	var centre := tile_centre(tile)
	match id:
		"plank":
			_ghost.position = centre + Vector3(0, -0.075, 0)
		"roof":
			_ghost.position = centre + Vector3(0, 1.2, 0)
		"wind_net":
			_ghost.position = centre + Vector3(0, 1.1, 0)
			_ghost.rotation.y = facing_yaw(player)
		_:
			_ghost.position = centre + Vector3(0, 0.3, 0)
	_ghost_material.albedo_color = Color(0.4, 1.0, 0.5, 0.35) if problem == "" else Color(1.0, 0.35, 0.3, 0.35)
	_ghost.visible = true
	return problem


func hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false


func _ghost_mesh(id: String) -> Mesh:
	if not _ghost_meshes.has(id):
		var box := BoxMesh.new()
		match id:
			"plank":
				box.size = Vector3(Tuning.tile_size, 0.15, Tuning.tile_size)
			"roof":
				box.size = Vector3(Tuning.tile_size, 2.4, Tuning.tile_size)
			"wind_net":
				box.size = Vector3(1.44, 2.2, 0.1)
			_:
				box.size = Vector3(0.7, 0.6, 0.7)
		_ghost_meshes[id] = box
	return _ghost_meshes[id]
