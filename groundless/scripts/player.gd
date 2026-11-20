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

@export var walk_speed := 4.0
@export var ground_acceleration := 30.0
@export var air_acceleration := 6.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
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

## The body the player is riding, or null.
var ride_body: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _ride_previous := Transform3D.IDENTITY
var _ride_velocity := Vector3.ZERO

@onready var head: Node3D = $Head


func _ready() -> void:
	platform_floor_layers = 0
	add_to_group("recentre")
	WorldOrigin.recentred.connect(_on_recentred)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_carry_with_ride(delta)

	var input_dir: Vector2
	if input_override != null:
		input_dir = input_override
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	wish = wish.normalized() * walk_speed * minf(input_dir.length(), 1.0)

	var wants_jump := jump_override or Input.is_action_just_pressed("jump")
	jump_override = false
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif wants_jump:
		velocity.y = jump_velocity

	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_update_ride()
	_check_fall()


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


func _check_fall() -> void:
	if home == null or ride_body != null:
		return
	if global_position.y < home.global_position.y - fall_reset_depth:
		respawn()


func respawn() -> void:
	global_position = home.global_transform * home_spawn_offset
	velocity = Vector3.ZERO
	ride_body = null


func _on_recentred(shift: Vector3) -> void:
	_ride_previous.origin -= shift
