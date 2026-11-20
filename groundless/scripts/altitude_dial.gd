class_name AltitudeDial
extends Node3D
## Brass altitude dial on a post. The bright needle is the raft's height; the thin dark
## needle is the resting height it is heading for. A red mark shows the murk's top.
## The dial face points along the node's +Z.

const MIN_HEIGHT := -60.0
const MAX_HEIGHT := 300.0
const SWEEP_DEGREES := 270.0
const FACE_HEIGHT := 1.35

var _lift: RaftLift
var _needle: Node3D
var _target_needle: Node3D


func _ready() -> void:
	_lift = RaftLift.find(self)
	add_child(Interactable.make_box(Vector3(0.1, FACE_HEIGHT, 0.1), Color(0.4, 0.32, 0.24), Vector3(0, FACE_HEIGHT * 0.5, -0.08)))

	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.26
	disc.bottom_radius = 0.26
	disc.height = 0.04
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.56, 0.26)
	brass.metallic = 0.6
	brass.roughness = 0.4
	disc.material = brass
	face.mesh = disc
	face.rotation_degrees = Vector3(90, 0, 0)
	face.position = Vector3(0, FACE_HEIGHT, 0)
	add_child(face)

	# Tick marks every 60 m, red at the murk's top.
	var h := MIN_HEIGHT
	while h <= MAX_HEIGHT + 0.1:
		var is_murk := is_equal_approx(h, Tuning.murk_top)
		_add_tick(h, Color(0.75, 0.15, 0.1) if is_murk else Color(0.2, 0.15, 0.1), 0.07 if is_murk else 0.04)
		h += 60.0

	_target_needle = _make_needle(0.17, 0.012, Color(0.15, 0.12, 0.1), 0.035)
	_needle = _make_needle(0.21, 0.02, Color(0.95, 0.92, 0.85), 0.045)


func _add_tick(height: float, colour: Color, length: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, FACE_HEIGHT, 0.025)
	pivot.rotation.z = _angle_for(height)
	add_child(pivot)
	pivot.add_child(Interactable.make_box(Vector3(0.012, length, 0.01), colour, Vector3(0, 0.24 - length * 0.5, 0)))


func _make_needle(length: float, width: float, colour: Color, depth: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, FACE_HEIGHT, depth)
	add_child(pivot)
	pivot.add_child(Interactable.make_box(Vector3(width, length, 0.008), colour, Vector3(0, length * 0.5 - 0.03, 0)))
	return pivot


func _angle_for(height: float) -> float:
	var t := clampf(inverse_lerp(MIN_HEIGHT, MAX_HEIGHT, height), 0.0, 1.0)
	# Low heights on the left, high on the right, sweeping clockwise.
	return deg_to_rad(SWEEP_DEGREES * 0.5 - t * SWEEP_DEGREES)


func _process(delta: float) -> void:
	if _lift == null:
		return
	var height := _lift.raft.get_base_height()
	var target := _lift.get_resting_height()
	_needle.rotation.z = lerp_angle(_needle.rotation.z, _angle_for(height), 1.0 - exp(-8.0 * delta))
	_target_needle.rotation.z = lerp_angle(_target_needle.rotation.z, _angle_for(target), 1.0 - exp(-3.0 * delta))
