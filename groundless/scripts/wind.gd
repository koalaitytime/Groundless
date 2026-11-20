extends Node
## Autoload "Wind". Wind velocity as a function of height (Y).
## The direction turns as height changes, so changing height is how you steer.

## Average horizontal wind speed in m/s.
@export var base_speed := 2.5
## How much the speed varies with height, in m/s.
@export var speed_variation := 1.0
## How far the wind direction turns per metre of height, in degrees.
@export var turn_degrees_per_metre := 1.5
## Slow gusting, as a fraction of the speed.
@export var gust_strength := 0.2

var _time := 0.0


func _physics_process(delta: float) -> void:
	_time += delta


## Horizontal wind velocity (m/s) at a given height. Y of the result is always 0.
func velocity_at(height: float) -> Vector3:
	var angle := deg_to_rad(height * turn_degrees_per_metre)
	var speed := base_speed + speed_variation * sin(height * 0.013)
	var gust := 1.0 + gust_strength * sin(_time * 0.37) * sin(_time * 0.11 + 1.3)
	return Vector3(cos(angle), 0.0, sin(angle)) * speed * gust
