class_name TetheredPod
extends Node3D
## A gas pod tied to an anchor point. Lift = capacity x gas.
## Grey-box look: a glowing amber sphere on a rope. It sags lower, shrinks and dims as it
## loses gas, so the player reads lift from the pods overhead (no HUD bars).

## Most lift this pod can give, in kg.
@export var capacity := 80.0
## How full the pod is, 0 to 1.
@export_range(0.0, 1.0) var gas := 1.0
## Damaged pods (wilting, storm, leech hole) leak fast. Patching comes with building.
@export var damaged := false

## Rope length at full gas, in metres.
const ROPE_FULL := 3.2
const ROPE_EMPTY := 0.9

var _time := 0.0
var _phase := randf() * TAU
var _ball: MeshInstance3D
var _rope: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	var radius := 0.35 * pow(capacity / 80.0, 1.0 / 3.0) + 0.15
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.3
	sphere.material = _material
	_ball = MeshInstance3D.new()
	_ball.mesh = sphere
	add_child(_ball)

	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.015
	rope_mesh.bottom_radius = 0.015
	rope_mesh.height = 1.0
	var rope_material := StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.55, 0.47, 0.36)
	rope_mesh.material = rope_material
	_rope = MeshInstance3D.new()
	_rope.mesh = rope_mesh
	add_child(_rope)
	_update_visual()


## Where the pod itself hangs, in world space.
func ball_position() -> Vector3:
	return _ball.global_position if _ball else global_position


func get_lift() -> float:
	return capacity * gas


## Lose gas. `force_healthy` uses the healthy rate even for a damaged pod (anchored).
func leak(delta: float, extra_per_min: float, force_healthy := false) -> void:
	var rate := Tuning.leak_damaged_per_min if damaged and not force_healthy else Tuning.leak_healthy_per_min
	gas = maxf(gas - (rate + extra_per_min) / 60.0 * delta, 0.0)


func refill(amount: float) -> void:
	gas = minf(gas + amount, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_update_visual()


func _update_visual() -> void:
	var length := lerpf(ROPE_EMPTY, ROPE_FULL, gas)
	var sway := Vector3(sin(_time * 0.7 + _phase), 0.0, cos(_time * 0.53 + _phase)) * 0.12 * gas
	var top := Vector3.UP * length + sway
	_ball.position = top
	_ball.scale = Vector3.ONE * lerpf(0.6, 1.0, gas)

	# Rope from the anchor (origin) to the pod.
	_rope.position = top * 0.5
	var up := top.normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	_rope.basis = Basis(side, up * top.length(), side.cross(up))

	var healthy := Color(0.95, 0.5, 0.12)
	var wilting := Color(0.62, 0.42, 0.22)
	var colour := wilting.lerp(healthy, gas) if not damaged else wilting.lerp(healthy, gas * 0.6)
	_material.albedo_color = colour.darkened(0.3)
	_material.emission = colour
	_material.emission_energy_multiplier = lerpf(0.05, 0.45, gas)
