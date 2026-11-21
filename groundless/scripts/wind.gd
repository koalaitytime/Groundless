extends Node
## Autoload "Wind". Wind velocity as a function of height (Y).
## The direction turns as height changes, so changing height is how you steer.
## Speeds and turn rate come from Tuning.

## Speed variation with height, as a fraction of the speed.
@export var speed_variation := 0.15
## Slow gusting, as a fraction of the speed.
@export var gust_strength := 0.15

var _time := 0.0
## 0..1, set by the Storm: stronger, swung wind.
var storm_strength := 0.0


func _physics_process(delta: float) -> void:
	_time += delta


## Horizontal wind velocity (m/s) at a given height. Y of the result is always 0.
func velocity_at(height: float) -> Vector3:
	var angle := deg_to_rad(height * Tuning.wind_turn_degrees_per_metre)
	# Slow in the murk, blending over 10 m around its top.
	var murk_blend := clampf((Tuning.murk_top - height) / 10.0 + 0.5, 0.0, 1.0)
	var speed := lerpf(Tuning.drift_speed, Tuning.murk_drift_speed, murk_blend)
	speed *= 1.0 + speed_variation * sin(height * 0.013)
	var gust := 1.0 + gust_strength * sin(_time * 0.37) * sin(_time * 0.11 + 1.3)
	if storm_strength > 0.0:
		speed = lerpf(speed, Tuning.storm_drift_speed, storm_strength)
		angle += deg_to_rad(Tuning.storm_wind_turn_degrees) * storm_strength
		gust += storm_strength * 0.3 * sin(_time * 1.7)
	return Vector3(cos(angle), 0.0, sin(angle)) * speed * gust
