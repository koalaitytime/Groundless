class_name Storm
extends Node3D
## The caustic rain storm (GDD "The slice storm"). Clear skies, then a warning (the air turns
## sour and the sky darkens) long enough to finish a first roof, then the rain:
##  - the wind strengthens and swings, shoving the raft off course
##  - it burns the player anywhere without cover overhead
##  - it eats at pods whose anchor tile has no roof (gas loss, sometimes a hole to patch)
##  - it fills rain catchers fast
##  - it eats wood: unroofed planks wear fast, roofs slower (see RaftBuilder.weather)
## A blackout (passing out) ends the storm early, so it can't burn you twice.
## Node in the main scene, in the "storm" group.

signal warning_started
signal rain_started
signal cleared

enum Phase { CLEAR, WARNING, RAIN }

@export var raft: Raft
@export var player: Player

var phase := Phase.CLEAR
var timer := 0.0
## 0..1: how strongly the storm is affecting wind, sky and fog right now.
var strength := 0.0

var _rain: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("storm")
	_rng.randomize()
	timer = Tuning.storm_first_delay
	_build_rain()
	if player:
		player.survival.passed_out.connect(func(_r): if phase == Phase.RAIN: end_storm())


func is_raining() -> bool:
	return phase == Phase.RAIN


func is_warning() -> bool:
	return phase == Phase.WARNING


## Seconds until the rain starts (only meaningful while warning).
func time_to_rain() -> float:
	return timer if phase == Phase.WARNING else 0.0


func start_warning() -> void:
	phase = Phase.WARNING
	timer = Tuning.storm_warning
	warning_started.emit()


func start_rain() -> void:
	phase = Phase.RAIN
	timer = Tuning.storm_duration
	rain_started.emit()


func end_storm() -> void:
	phase = Phase.CLEAR
	timer = _rng.randf_range(Tuning.storm_interval_min, Tuning.storm_interval_max)
	cleared.emit()


func _physics_process(delta: float) -> void:
	timer -= delta
	match phase:
		Phase.CLEAR:
			if timer <= 0.0:
				start_warning()
		Phase.WARNING:
			if timer <= 0.0:
				start_rain()
		Phase.RAIN:
			if timer <= 0.0:
				end_storm()
			else:
				_rain_effects(delta)
	var target := 1.0 if phase == Phase.RAIN else (0.4 if phase == Phase.WARNING else 0.0)
	strength = move_toward(strength, target, delta / 8.0)
	Wind.storm_strength = strength
	if _rain and player:
		_rain.emitting = phase == Phase.RAIN
		_rain.global_position = player.camera.global_position + Vector3.UP * 8.0


func _rain_effects(delta: float) -> void:
	if player and not player.survival.out_cold and not is_sheltered(player.camera.global_position):
		player.survival.hurt(Tuning.rain_burn * delta, "rain")
	if raft == null:
		return
	var build := raft.get_node_or_null("Build") as RaftBuilder
	var lift := raft.get_node_or_null("Lift") as RaftLift
	if build == null or lift == null:
		return
	build.weather(delta)
	for anchor in raft.find_children("*", "AnchorPoint", true, false):
		var pod: TetheredPod = anchor.pod
		if pod == null:
			continue
		var tile := build.tile_of(anchor.position)
		if build.tiles.has(tile) and build.tiles[tile].roof != null:
			continue  # Roofed: the pod is shielded.
		pod.gas = maxf(pod.gas - Tuning.rain_pod_gas_per_min / 60.0 * delta, 0.0)
		if not pod.damaged and _rng.randf() < Tuning.rain_pod_damage_chance * delta:
			pod.damaged = true


## Is there something solid overhead (a roof, a cave, an arch) within 30 m?
func is_sheltered(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * 30.0, 1)
	if player:
		query.exclude = [player.get_rid()]
	return not space.intersect_ray(query).is_empty()


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 1500
	_rain.lifetime = 1.4
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-15, -20, -15), Vector3(30, 30, 30))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(14, 1, 14)
	process.direction = Vector3(0.15, -1, 0)
	process.spread = 4.0
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.45, 0.015)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.9, 0.55, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = material
	_rain.draw_pass_1 = drop
	_rain.top_level = true
	add_child(_rain)
