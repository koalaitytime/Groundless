class_name Raft
extends AnimatableBody3D
## The raft. Moved by script: it drifts with the wind at its height, eases toward its
## resting height (set by the Lift child from lift minus weight), and bobs, sways and slowly
## turns. Things standing on it ride along through the "rideable" group (see player.gd).

## Height the raft eases toward, in metres. The Lift child sets this every tick.
@export var target_height := 40.0
## Vertical bob, in metres and seconds.
@export var bob_height := 0.12
@export var bob_period := 6.0
## Pitch and roll sway, in degrees.
@export var sway_degrees := 1.5
## Slow wandering turn, in degrees per second at its peak.
@export var turn_degrees_per_second := 2.0
## How quickly the raft's drift matches the wind (per second). Lower feels heavier.
@export var drift_response := 0.3

## Current drift velocity in m/s (bob not included). Y is the vertical speed.
var velocity := Vector3.ZERO

var _time := 0.0
var _paddle_target := Vector3.ZERO
var _paddle_velocity := Vector3.ZERO
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

	# Horizontal: ease toward a fraction of the wind (the raft is heavy).
	var wind: Vector3 = Wind.velocity_at(_base_position.y) * Tuning.raft_wind_fraction
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(wind, 1.0 - exp(-drift_response * delta))

	# Vertical: vy target = clamp((target - y) / T, -max_sink, +max_rise), smoothed.
	var desired_vy := clampf(
		(target_height - _base_position.y) / Tuning.height_time_constant,
		-Tuning.max_sink_speed,
		Tuning.max_rise_speed
	)
	var vy := lerpf(velocity.y, desired_vy, 1.0 - exp(-Tuning.vertical_smoothing * delta))
	velocity = Vector3(horizontal.x, vy, horizontal.z)
	_paddle_velocity = _paddle_velocity.lerp(_paddle_target, 1.0 - exp(-2.0 * delta))
	_paddle_target = Vector3.ZERO
	_base_position += (velocity + _paddle_velocity) * delta

	_yaw += deg_to_rad(turn_degrees_per_second) * sin(_time * 0.05) * delta

	var bob := sin(_time * TAU / bob_period) * bob_height
	var sway := deg_to_rad(sway_degrees)
	var pitch := sway * sin(_time * TAU / 7.3)
	var roll := sway * sin(_time * TAU / 9.1 + 0.7)
	global_transform = Transform3D(
		Basis.from_euler(Vector3(pitch, _yaw, roll)),
		_base_position + Vector3.UP * bob
	)


## The sky-paddle pushes the raft this way (horizontal) for this tick.
func paddle(direction: Vector3) -> void:
	direction.y = 0.0
	_paddle_target = direction.normalized() * Tuning.paddle_speed


## Total horizontal velocity including paddling.
func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x + _paddle_velocity.x, 0.0, velocity.z + _paddle_velocity.z)


## Height without the bob.
func get_base_height() -> float:
	return _base_position.y


func _on_recentred(shift: Vector3) -> void:
	_base_position -= shift
