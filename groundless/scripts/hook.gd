class_name Hook
extends Node3D
## The hook. Thrown from the player's hand along the view, it flies on an arc up to
## Tuning.hook_range, then reels back. Flotsam it touches (drift-pods, materials) comes back
## with it and goes into the player's inventory. It hits the raft and other solid things too, and
## then just reels back. Works in world space, so it shifts itself on recentre.

enum State { IDLE, FLYING, REELING }

const HIT_MASK := 1 | Flotsam.LAYER

var state := State.IDLE
var hooked_item: Flotsam

var _player: Player
var _velocity := Vector3.ZERO
var _head: MeshInstance3D
var _rope: MeshInstance3D
var _rope_mesh := ImmediateMesh.new()
var _rope_material := StandardMaterial3D.new()


func _ready() -> void:
	_player = get_parent() as Player
	top_level = true
	process_physics_priority = 10  # After the player has moved.
	_head = Interactable.make_box(Vector3(0.12, 0.2, 0.06), Color(0.3, 0.3, 0.32))
	add_child(_head)
	_rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope_material.albedo_color = Color(0.75, 0.66, 0.5)
	_rope = MeshInstance3D.new()
	_rope.mesh = _rope_mesh
	_rope.top_level = true
	add_child(_rope)
	WorldOrigin.recentred.connect(_on_recentred)
	_set_visible(false)


func hand_position() -> Vector3:
	var camera := _player.get_node("Head/Camera3D") as Node3D
	return camera.global_transform * Vector3(0.25, -0.2, -0.4)


func can_throw() -> bool:
	return state == State.IDLE


## Throw along `direction`. `carry_velocity` is added (the raft's motion under the player).
func throw(direction: Vector3, carry_velocity := Vector3.ZERO) -> void:
	if not can_throw():
		return
	state = State.FLYING
	global_position = hand_position()
	_velocity = direction.normalized() * Tuning.hook_throw_speed + carry_velocity
	_set_visible(true)


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_fly(delta)
		State.REELING:
			_reel(delta)
	if state != State.IDLE:
		_draw_rope()


func _fly(delta: float) -> void:
	_velocity.y -= 9.8 * delta
	var next := global_position + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, HIT_MASK, [_player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var item := hit.collider as Flotsam
		if item and not item.hooked:
			hooked_item = item
			item.hooked = true
		state = State.REELING
		return
	global_position = next
	if global_position.distance_to(hand_position()) >= Tuning.hook_range:
		state = State.REELING


func _reel(delta: float) -> void:
	var target := hand_position()
	var speed := Tuning.hook_reel_speed_loaded if hooked_item else Tuning.hook_reel_speed
	global_position = global_position.move_toward(target, speed * delta)
	if hooked_item and is_instance_valid(hooked_item):
		hooked_item.global_position = global_position
	if global_position.distance_to(target) < 0.6:
		if hooked_item and is_instance_valid(hooked_item):
			_player.add_item(hooked_item.kind)
			hooked_item.queue_free()
		hooked_item = null
		state = State.IDLE
		_set_visible(false)


func _draw_rope() -> void:
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _rope_material)
	_rope_mesh.surface_add_vertex(hand_position())
	_rope_mesh.surface_add_vertex(global_position)
	_rope_mesh.surface_end()


func _set_visible(on: bool) -> void:
	_head.visible = on
	_rope.visible = on
	if not on:
		_rope_mesh.clear_surfaces()


func _on_recentred(shift: Vector3) -> void:
	global_position -= shift
