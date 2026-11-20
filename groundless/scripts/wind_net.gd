class_name WindNet
extends Interactable
## A net stretched on a frame. Flotsam drifting through the tile it stands on gets caught and
## hangs in the mesh until the player empties it with E. Holds Tuning.wind_net_capacity items.

const CATCH_SIZE := Vector3(2.4, 4.0, 2.4)

var caught: Array[String] = []

var _lift: RaftLift
var _catch: Area3D
var _knots: Node3D


func _ready() -> void:
	hit_size = Vector3(1.4, 2.0, 0.4)
	hit_offset = Vector3(0, 1.0, 0)
	super()
	var wood := Color(0.42, 0.33, 0.24)
	add_child(make_box(Vector3(0.08, 2.2, 0.08), wood, Vector3(-0.68, 1.1, 0)))
	add_child(make_box(Vector3(0.08, 2.2, 0.08), wood, Vector3(0.68, 1.1, 0)))
	add_child(make_box(Vector3(1.44, 0.06, 0.06), wood, Vector3(0, 2.17, 0)))
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.7, 0.62, 0.45, 0.45)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var net_plane := QuadMesh.new()
	net_plane.size = Vector2(1.3, 1.7)
	net_plane.material = mesh_material
	var net := MeshInstance3D.new()
	net.mesh = net_plane
	net.position = Vector3(0, 1.25, 0)
	add_child(net)
	_knots = Node3D.new()
	add_child(_knots)

	# The catching volume covers the whole tile column and a little beyond.
	_catch = Area3D.new()
	_catch.collision_layer = 0
	_catch.collision_mask = Flotsam.LAYER
	_catch.monitorable = false
	var box := BoxShape3D.new()
	box.size = CATCH_SIZE
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0, 1.0, 0)
	_catch.add_child(shape)
	add_child(_catch)
	_catch.area_entered.connect(_on_area_entered)

	_lift = RaftLift.find(self)
	if _lift:
		_lift.add_weight(Tuning.wind_net_weight)


func is_full() -> bool:
	return caught.size() >= Tuning.wind_net_capacity


## Catch a piece of flotsam if there is room. Returns true if caught.
func catch_flotsam(item: Flotsam) -> bool:
	if item.hooked or is_full() or item.is_queued_for_deletion():
		return false
	for k in item.contents:
		caught.append(k)
	item.queue_free()
	_refresh_knots()
	return true


func _on_area_entered(area: Area3D) -> void:
	if area is Flotsam:
		catch_flotsam(area)


func _refresh_knots() -> void:
	for child in _knots.get_children():
		child.queue_free()
	for i in caught.size():
		var visual := Flotsam.make_visual(caught[i])
		visual.scale = Vector3.ONE * 0.5
		visual.position = Vector3(-0.45 + (i % 4) * 0.3, 0.7 + (i / 4) * 0.45, 0.05)
		_knots.add_child(visual)


func get_prompt(_player: Player) -> String:
	if caught.is_empty():
		return "Wind net (empty)"
	return "Wind net: %d/%d%s\n[E] Take everything" % [caught.size(), Tuning.wind_net_capacity, "  FULL" if is_full() else ""]


func interact(player: Player) -> void:
	for k in caught:
		player.add_item(k)
	caught.clear()
	_refresh_knots()


func on_cut() -> void:
	if _lift:
		_lift.remove_weight(Tuning.wind_net_weight)
	collision_layer = 0
	_catch.monitoring = false
