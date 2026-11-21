class_name Player
extends CharacterBody3D
## First-person player.
##
## Riding: the engine's own moving-platform handling is off (platform_floor_layers = 0).
## Instead, every tick the player applies the exact transform change of the body it rides
## (position and yaw) before its own movement. This stays exact while the raft bobs, sways and
## turns, keeps working mid-jump, and survives world recentring.
## A body is rideable if it is in the "rideable" group and moves before the player each tick
## (lower process_physics_priority).

@export var ground_acceleration := 30.0
@export var air_acceleration := 6.0
@export var mouse_sensitivity := 0.0025
## How far the player can reach to use things, in metres.
@export var reach := 2.6
## Keep riding while airborne if a rideable body is within this distance below.
@export var air_ride_distance := 30.0
## Placeholder for the falling-off rule: respawn when this far below the raft.
@export var fall_reset_depth := 40.0
## Where to respawn. Usually the raft.
@export var home: Node3D
@export var home_spawn_offset := Vector3(0.0, 0.5, 0.0)

## Tests set these to drive the player without real input.
var input_override: Variant = null
var jump_override := false

enum Slot { HOOK = 1, HAMMER = 2, PADDLE = 3 }
const SLOT_NAMES := {1: "Hook", 2: "Hammer", 3: "Sky-paddle"}

## Inventory: materials ("wood", "rope", "cloth", "fiber"), drift-pods ("pod") and crafted
## items ("patch", "sky_paddle"). Carried things weigh nothing (GDD).
var items := {}
## Drift-pods caught and not yet used.
var held_pods: int:
	get:
		return items.get("pod", 0)
	set(value):
		items["pod"] = value
var selected_slot := Slot.HOOK
## The piece the hammer places.
var build_choice := "plank"
## Why the current hammer placement isn't possible ("" if it is).
var build_problem := ""
var build_tile: Variant = null
var stamina := 0.0
var paddling := false
## Tests set this to paddle without the mouse.
var paddle_override := false
var builder: RaftBuilder
## Thirst, hunger and health.
var survival: Survival
## A pod-leech within reach that the player is looking at, or null.
var focused_leech: PodLeech
## Climbing a ladder (hangroot) right now.
var climbing := false
## Mantling up onto a ledge right now (code-driven, no animation).
var mantling := false
var _resting := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
## The interactable the player is looking at, or null.
var focused: Interactable
## Flotsam within grabbing reach that the player is looking at, or null.
var focused_flotsam: Flotsam
## Hook throw charge 0..1 while the button is held, or -1 when not charging.
var hook_charge := -1.0
var hook: Hook

## The body the player is riding, or null.
var ride_body: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _ride_previous := Transform3D.IDENTITY
var _ride_velocity := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	platform_floor_layers = 0
	add_to_group("recentre")
	WorldOrigin.recentred.connect(_on_recentred)
	hook = Hook.new()
	add_child(hook)
	survival = Survival.new()
	survival.name = "Survival"
	add_child(survival)
	items = Tuning.starting_items.duplicate()
	for k in ["pod", "patch", "sky_paddle"]:
		items[k] = 0
	stamina = Tuning.paddle_stamina
	if home:
		builder = home.get_node_or_null("Build")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_primary"):
		use_primary()
	elif event.is_action_released("use_primary"):
		release_primary()
	elif event.is_action_pressed("interact") and focused_leech:
		focused_leech.hit()
	elif event.is_action_pressed("interact") and focused_flotsam:
		grab_flotsam()
	elif event.is_action_pressed("interact_alt") and focused:
		focused.alt_interact(self)
	elif event.is_action_pressed("eat"):
		survival.eat_fungus()
	elif event.is_action_pressed("interact") and focused:
		focused.interact(self)
	elif event.is_action_pressed("cut_loose"):
		cut_loose()
	elif event.is_action_pressed("remove_piece"):
		remove_piece()
	elif event.is_action_pressed("hotbar_next"):
		cycle_slot(1)
	elif event.is_action_pressed("hotbar_prev"):
		cycle_slot(-1)
	else:
		for n in [1, 2, 3]:
			if event.is_action_pressed("hotbar_%d" % n):
				select_slot(n)


func _physics_process(delta: float) -> void:
	_carry_with_ride(delta)
	if mantling:
		_update_mantle(delta)
		_update_focus()
		return

	var input_dir: Vector2
	if input_override != null:
		input_dir = input_override
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	var speed := Tuning.sprint_speed if Input.is_action_pressed("sprint") else Tuning.walk_speed
	wish = wish.normalized() * speed * minf(input_dir.length(), 1.0)

	var wants_jump := jump_override or Input.is_action_just_pressed("jump")
	jump_override = false
	# Jump next to a ledge up to mantle_max_height above your feet: climb onto it instead.
	if wants_jump and (is_on_floor() or climbing) and try_mantle():
		return
	var ladder := _current_ladder()
	var holding_climb := input_dir.y < -0.3 or Input.is_action_pressed("jump")
	climbing = ladder != null and (holding_climb or climbing) and not (is_on_floor() and input_dir.y > 0.3)
	if climbing:
		# On hangroot: forward/jump climbs up, back climbs down, no gravity.
		var vertical := 0.0
		if holding_climb:
			vertical = Tuning.climb_speed
		elif input_dir.y > 0.3:
			vertical = -Tuning.climb_speed
		velocity = global_basis * Vector3(input_dir.x, 0.0, 0.0) * Tuning.climb_speed * 0.5
		velocity.y = vertical
		move_and_slide()
		if vertical > 0.0 and global_position.y + Tuning.mantle_max_height >= ladder.top_y() - 0.4:
			try_mantle()
		_update_ride()
		_update_focus()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif wants_jump:
		velocity.y = sqrt(2.0 * gravity * Tuning.jump_height)

	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_update_ride()
	_check_fall()
	_update_focus()
	_update_paddle(delta)
	_update_build_preview()
	if hook_charge >= 0.0:
		if selected_slot != Slot.HOOK:
			hook_charge = -1.0
		else:
			hook_charge = minf(hook_charge + delta / Tuning.hook_charge_time, 1.0)


# --- Inventory -----------------------------------------------------------------------

func add_item(kind: String, count := 1) -> void:
	items[kind] = items.get(kind, 0) + count


func has_items(cost: Dictionary) -> bool:
	for k in cost:
		if items.get(k, 0) < cost[k]:
			return false
	return true


func spend_items(cost: Dictionary) -> void:
	for k in cost:
		items[k] = items.get(k, 0) - cost[k]


## Craft an item recipe (sky-paddle, patch) into the inventory.
func craft(id: String) -> bool:
	var recipe: Dictionary = Tuning.recipes[id]
	if recipe.kind != "item" or not has_items(recipe.cost):
		return false
	spend_items(recipe.cost)
	add_item(id)
	return true


# --- Hotbar ------------------------------------------------------------------------

func slot_available(slot: int) -> bool:
	return slot != Slot.PADDLE or items.get("sky_paddle", 0) > 0


func select_slot(slot: int) -> void:
	if slot_available(slot):
		selected_slot = slot


func cycle_slot(step: int) -> void:
	var slot := selected_slot
	for i in 3:
		slot = wrapi(slot + step, 1, 4)
		if slot_available(slot):
			selected_slot = slot
			return


func use_primary() -> void:
	match selected_slot:
		Slot.HOOK:
			if hook.state == Hook.State.FLYING:
				hook.reel_in()
			elif hook.can_throw():
				hook_charge = 0.0
		Slot.HAMMER:
			if builder and build_tile != null:
				builder.place(build_choice, build_tile, self)


func release_primary() -> void:
	if hook_charge >= 0.0:
		throw_hook(hook_charge)
		hook_charge = -1.0


func grab_flotsam() -> void:
	if focused_flotsam and is_instance_valid(focused_flotsam) and not focused_flotsam.hooked:
		focused_flotsam.give_to(self)
		focused_flotsam.queue_free()
		focused_flotsam = null


func cut_loose() -> void:
	if selected_slot == Slot.HAMMER and builder:
		var tile: Variant = builder.aim_tile(camera)
		if tile != null:
			builder.cut(tile)


## Hammer + right-click: take back the aimed piece with a full refund.
func remove_piece() -> void:
	if selected_slot == Slot.HAMMER and builder:
		var tile: Variant = builder.aim_tile(camera)
		if tile != null:
			builder.remove(tile, self)


func _update_build_preview() -> void:
	if builder == null:
		return
	if selected_slot == Slot.HAMMER:
		build_tile = builder.aim_tile(camera)
		build_problem = builder.show_ghost(build_choice, build_tile, self)
	else:
		build_tile = null
		builder.hide_ghost()


## Sky-paddle: hold the use button to push the raft the way you face. Stamina limited.
func _update_paddle(delta: float) -> void:
	var wants := paddle_override or (selected_slot == Slot.PADDLE and Input.is_action_pressed("use_primary") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	paddling = false
	if wants and _resting <= 0.0 and stamina > 0.0 and ride_body is Raft:
		paddling = true
		ride_body.paddle(-camera.global_basis.z)
		stamina -= delta
		if stamina <= 0.0:
			stamina = 0.0
			_resting = Tuning.paddle_rest
	elif _resting > 0.0:
		_resting -= delta
		if _resting <= 0.0:
			stamina = Tuning.paddle_stamina
	elif not wants:
		stamina = minf(Tuning.paddle_stamina, stamina + delta * Tuning.paddle_stamina / Tuning.paddle_rest)


func is_resting() -> bool:
	return _resting > 0.0


func throw_hook(power := 1.0) -> void:
	hook.throw(-camera.global_basis.z, _ride_velocity if ride_body else Vector3.ZERO, power)


## Find what the player is looking at within reach.
func _update_focus() -> void:
	var from := camera.global_position
	var distance := maxf(reach, Tuning.grab_reach)
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * distance, 1 | Interactable.LAYER | Flotsam.LAYER, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	focused = null
	focused_flotsam = null
	focused_leech = null
	if hit.is_empty():
		return
	var near := from.distance_to(hit.position)
	if hit.collider is PodLeech and near <= Tuning.grab_reach:
		focused_leech = hit.collider
	elif hit.collider is Flotsam and not hit.collider.hooked and near <= Tuning.grab_reach:
		focused_flotsam = hit.collider
	elif hit.collider is Interactable and near <= reach:
		focused = hit.collider


## Apply the ridden body's motion since last tick to the player.
func _carry_with_ride(delta: float) -> void:
	if ride_body == null:
		return
	if not is_instance_valid(ride_body):
		ride_body = null
		return
	var now := ride_body.global_transform
	var change := now * _ride_previous.affine_inverse()
	_ride_previous = now

	var before := global_position
	global_position = change * before
	_ride_velocity = (global_position - before) / delta

	# Turn with the raft but stay upright: take only the yaw part of its rotation.
	var forward := change.basis * Vector3.FORWARD
	rotate_y(atan2(-forward.x, -forward.z))


## Decide which body to ride after moving.
func _update_ride() -> void:
	var new_ride := ride_body
	var hit := _ray_down(0.6 if is_on_floor() else air_ride_distance)
	if is_on_floor():
		# Standing on something: ride it if rideable. If the short ray misses (standing on an
		# edge), keep the current ride rather than letting the raft slide out from under us.
		if hit:
			new_ride = hit if hit.is_in_group("rideable") else null
			if hit is Island:
				hit.mark_boarded()
	else:
		new_ride = hit if hit and hit.is_in_group("rideable") else null

	if new_ride == ride_body:
		return
	if ride_body != null and new_ride == null:
		# Leaving the raft: keep its momentum so it doesn't look like it was yanked away.
		velocity += _ride_velocity
	ride_body = new_ride
	_ride_velocity = Vector3.ZERO
	if ride_body != null:
		_ride_previous = ride_body.global_transform


func _ray_down(distance: float) -> Node3D:
	var from := global_position + up_direction * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from - up_direction * (0.3 + distance))
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.collider as Node3D


# --- Boarding: mantle and climb ----------------------------------------------------

func _current_ladder() -> Ladder:
	for node in get_tree().get_nodes_in_group("ladder"):
		if node.contains(global_position + Vector3.UP * 0.9):
			return node
	return null


## Look for a ledge just ahead whose top is up to mantle_max_height above the feet.
## Returns the standing point on it, or null.
func find_ledge() -> Variant:
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state
	# Look a little way ahead, far enough to reach across the anchored raft's gap.
	for reach_ahead: float in [0.6, 1.0, 1.4, 1.8]:
		var top: Vector3 = global_position + forward * reach_ahead + Vector3.UP * (Tuning.mantle_max_height + 0.4)
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (Tuning.mantle_max_height + 0.4), 1, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var rise: float = hit.position.y - global_position.y
		# Low ledges are just jumped; mantling starts where a jump stops being enough.
		if rise < 0.6 or rise > Tuning.mantle_max_height:
			continue
		# Room to stand: nothing in the way at head height above the ledge.
		var head := PhysicsRayQueryParameters3D.create(hit.position + Vector3.UP * 0.1, hit.position + Vector3.UP * 1.7, 1, [get_rid()])
		if not space.intersect_ray(head).is_empty():
			continue
		return hit.position + forward * 0.25 + Vector3.UP * 0.02
	return null


## Start a mantle if there's a ledge ahead. Returns true if mantling.
func try_mantle() -> bool:
	var ledge: Variant = find_ledge()
	if ledge == null:
		return false
	mantling = true
	climbing = false
	_mantle_from = global_position
	_mantle_to = ledge
	_mantle_t = 0.0
	velocity = Vector3.ZERO
	if ride_body != null:
		ride_body = null
	return true


## Up first, then forward over the lip.
func _update_mantle(delta: float) -> void:
	_mantle_t = minf(_mantle_t + delta / Tuning.mantle_time, 1.0)
	var up_part := clampf(_mantle_t / 0.6, 0.0, 1.0)
	var over_part := clampf((_mantle_t - 0.5) / 0.5, 0.0, 1.0)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, smoothstep(0.0, 1.0, up_part))
	p.x = lerpf(_mantle_from.x, _mantle_to.x, smoothstep(0.0, 1.0, over_part))
	p.z = lerpf(_mantle_from.z, _mantle_to.z, smoothstep(0.0, 1.0, over_part))
	global_position = p
	if _mantle_t >= 1.0:
		mantling = false
		velocity = Vector3.ZERO
		apply_floor_snap()
		_update_ride()


func _check_fall() -> void:
	if home == null or ride_body != null or survival.out_cold:
		return
	if global_position.y < home.global_position.y - fall_reset_depth:
		# Falling off: black out and wake on the raft (GDD "Falling off").
		survival.black_out("fell")


func respawn() -> void:
	global_position = home.global_transform * home_spawn_offset
	velocity = Vector3.ZERO
	ride_body = null


func _on_recentred(shift: Vector3) -> void:
	_ride_previous.origin -= shift
	_mantle_from -= shift
	_mantle_to -= shift
