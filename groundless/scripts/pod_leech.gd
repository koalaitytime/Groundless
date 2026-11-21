class_name PodLeech
extends Area3D
## The pod-leech (GDD "Creatures and combat"): a pale jellyfish-like drifter that swims to the
## raft, latches onto a tethered pod and drains its gas. Hit it with the hook or tear it off
## by hand (E): the first hit knocks it off and it backs away before trying again; enough
## hits pop it. No skeleton: it pulses and trails tendrils in code.
## Sits on physics layer 2 with flotsam, so the hook's ray and the grab ray find it.

enum State { APPROACH, LATCHED, KNOCKED, DEAD }

var state := State.APPROACH
var target_pod: TetheredPod
var hits_left := 3
var raft: Raft

var _time := randf() * 10.0
var _knock_timer := 0.0
var _knock_dir := Vector3.ZERO
var _bell: MeshInstance3D
var _tendrils: Array[MeshInstance3D] = []
var _material := StandardMaterial3D.new()


func _ready() -> void:
	collision_layer = Flotsam.LAYER
	collision_mask = 0
	monitoring = false
	hits_left = Tuning.leech_hits
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)
	_material.albedo_color = Color(0.9, 0.88, 0.95, 0.7)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission = Color(0.7, 0.75, 1.0)
	_material.emission_energy_multiplier = 0.3
	var bell := SphereMesh.new()
	bell.radius = 0.55
	bell.height = 0.7
	bell.is_hemisphere = true
	bell.material = _material
	_bell = MeshInstance3D.new()
	_bell.mesh = bell
	add_child(_bell)
	for i in 5:
		var a := TAU * i / 5.0
		var tendril := Interactable.make_box(Vector3(0.04, 1.0, 0.04), Color(0.85, 0.82, 0.92), Vector3(cos(a) * 0.3, -0.5, sin(a) * 0.3))
		add_child(tendril)
		_tendrils.append(tendril)


## Hit by the hook or a hand. Returns true if it died.
func hit() -> bool:
	if state == State.DEAD:
		return true
	hits_left -= 1
	if hits_left <= 0:
		_die()
		return true
	# Knocked off: back away, then come back.
	state = State.KNOCKED
	_knock_timer = 5.0
	_knock_dir = (global_position - raft.global_position).normalized() if raft else Vector3.UP
	_knock_dir.y = absf(_knock_dir.y) + 0.3
	_knock_dir = _knock_dir.normalized()
	target_pod = null
	return false


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.15)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(queue_free)


func _pick_pod() -> TetheredPod:
	if raft == null:
		return null
	var best: TetheredPod = null
	var best_d := INF
	for pod in raft.find_children("*", "TetheredPod", true, false):
		if pod.gas <= 0.01:
			continue
		var d: float = pod.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = pod
	return best


func _physics_process(delta: float) -> void:
	_time += delta
	_animate()
	if raft == null or state == State.DEAD:
		return
	var carry: Vector3 = raft.get_horizontal_velocity() + Vector3(0, raft.velocity.y, 0)
	match state:
		State.APPROACH:
			if target_pod == null or not is_instance_valid(target_pod):
				target_pod = _pick_pod()
				if target_pod == null:
					return
			var goal := target_pod.ball_position()
			var to := goal - global_position
			if to.length() < 0.5:
				state = State.LATCHED
				return
			global_position += (carry + to.normalized() * minf(Tuning.leech_speed, to.length() * 2.0)) * delta
		State.LATCHED:
			if target_pod == null or not is_instance_valid(target_pod) or not target_pod.is_inside_tree():
				state = State.APPROACH
				target_pod = null
				return
			global_position = target_pod.ball_position() + Vector3.UP * 0.35
			target_pod.gas = maxf(target_pod.gas - Tuning.leech_drain_per_min / 60.0 * delta, 0.0)
			if target_pod.gas <= 0.0:
				state = State.APPROACH
				target_pod = null
		State.KNOCKED:
			_knock_timer -= delta
			global_position += (carry + _knock_dir * 2.5 * (_knock_timer / 5.0)) * delta
			if _knock_timer <= 0.0:
				state = State.APPROACH


## A slow pulse of the bell, faster while feeding; tendrils trail and sway.
func _animate() -> void:
	var rate := 6.0 if state == State.LATCHED else 2.5
	var pulse := 1.0 + 0.15 * sin(_time * rate)
	_bell.scale = Vector3(pulse, 1.0 / pulse, pulse)
	_material.emission_energy_multiplier = 0.9 if state == State.LATCHED else 0.3
	for i in _tendrils.size():
		_tendrils[i].rotation = Vector3(sin(_time * 2.0 + i) * 0.35, 0, cos(_time * 1.7 + i) * 0.35)
