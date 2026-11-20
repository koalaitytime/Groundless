class_name Raft
extends AnimatableBody3D
## The raft. Moved by script: it eases toward the wind velocity at its height,
## holds a target height (lift comes in milestone 2), and bobs, sways and slowly turns.
## Things standing on it ride along through the "rideable" group (see player.gd).

## Height the raft eases toward, in metres. Milestone 2 replaces this with lift minus weight.
@export var target_height := 100.0
## How quickly the raft eases toward its target height (per second).
@export var height_response := 0.5
## How quickly the raft's drift matches the wind (per second). Lower feels heavier.
@export var drift_response := 0.3
## Vertical bob, in metres and seconds.
@export var bob_height := 0.12
@export var bob_period := 6.0
## Pitch and roll sway, in degrees.
@export var sway_degrees := 1.5
## Slow wandering turn, in degrees per second at its peak.
@export var turn_degrees_per_second := 2.0

## Current drift velocity in m/s (bob not included).
var velocity := Vector3.ZERO

var _time := 0.0
var _base_position := Vector3.ZERO
var _yaw := 0.0


func _ready() -> void:
	sync_to_physics = false
	# Move before anything riding on us reads our transform this tick.
	process_physics_priority = -10
	add_to_group("rideable")
	add_to_group("recentre")
	_base_position = global_position
	_yaw = global_rotation.y
	WorldOrigin.focus = self
	WorldOrigin.recentred.connect(_on_recentred)


func _physics_process(delta: float) -> void:
	_time += delta

	var wind: Vector3 = Wind.velocity_at(_base_position.y)
	velocity = velocity.lerp(wind, 1.0 - exp(-drift_response * delta))
	_base_position.x += velocity.x * delta
	_base_position.z += velocity.z * delta
	_base_position.y = lerpf(_base_position.y, target_height, 1.0 - exp(-height_response * delta))

	_yaw += deg_to_rad(turn_degrees_per_second) * sin(_time * 0.05) * delta

	var bob := sin(_time * TAU / bob_period) * bob_height
	var sway := deg_to_rad(sway_degrees)
	var pitch := sway * sin(_time * TAU / 7.3)
	var roll := sway * sin(_time * TAU / 9.1 + 0.7)
	global_transform = Transform3D(
		Basis.from_euler(Vector3(pitch, _yaw, roll)),
		_base_position + Vector3.UP * bob
	)


func _on_recentred(shift: Vector3) -> void:
	_base_position -= shift
