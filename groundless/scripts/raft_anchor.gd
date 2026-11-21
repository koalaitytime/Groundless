class_name RaftAnchor
extends Node
## Anchoring to an island (GDD "Anchoring"). Throw the hook into an island and its rope moors
## the raft there: the raft is reeled in until its nearest edge is Tuning.anchor_gap from the
## island's lip and hauled level with the lip (see RaftLift), then held still, so the player
## can walk straight across. A cleat appears on the raft's edge: E casts off, and the raft
## goes back to the resting height its lift gives.
## Child of the Raft, named "Anchor".

signal anchored(island: Island)
signal cast_off_done

var island: Island
## Anchor point in the island's local space (islands move only by recentring).
var local_point := Vector3.ZERO
var cleat: AnchorCleat

var _rope: MeshInstance3D
var _rope_mesh := ImmediateMesh.new()
var _rope_material := StandardMaterial3D.new()

@onready var raft: Raft = get_parent()


func _ready() -> void:
	# Decide the raft's anchored velocity before it moves this tick.
	process_physics_priority = -15
	_rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope_material.albedo_color = Color(0.75, 0.66, 0.5)
	_rope = MeshInstance3D.new()
	_rope.mesh = _rope_mesh
	_rope.top_level = true
	add_child(_rope)


func is_anchored() -> bool:
	return island != null and is_instance_valid(island)


func anchor_position() -> Vector3:
	return island.global_transform * local_point


func anchor_to(target: Island, world_point: Vector3) -> void:
	if is_anchored():
		return
	island = target
	local_point = island.global_transform.affine_inverse() * world_point
	cleat = AnchorCleat.new()
	cleat.anchor = self
	raft.add_child(cleat)
	_place_cleat()
	anchored.emit(island)


func cast_off() -> void:
	island = null
	raft.anchor_velocity = null
	if cleat:
		cleat.queue_free()
		cleat = null
	_rope_mesh.clear_surfaces()
	cast_off_done.emit()


## Where the raft's centre should sit: its nearest edge anchor_gap from the island's lip.
func target_position() -> Vector3:
	var centre := island.global_position
	var away := Vector3(raft.global_position.x - centre.x, 0.0, raft.global_position.z - centre.z)
	var direction := away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var build := raft.get_node("Build") as RaftBuilder
	var local_dir := raft.global_basis.inverse() * -direction
	var reach := build.extent_along(local_dir)
	var target := centre + direction * (island.radius + Tuning.anchor_gap + reach)
	target.y = raft.global_position.y
	return target


## Gap between the raft's nearest floor edge and the island's lip, in metres.
func edge_gap() -> float:
	var to_raft := Vector3(raft.global_position.x - island.global_position.x, 0.0, raft.global_position.z - island.global_position.z)
	var build := raft.get_node("Build") as RaftBuilder
	var reach := build.extent_along(raft.global_basis.inverse() * -to_raft.normalized())
	return to_raft.length() - island.radius - reach


func _physics_process(_delta: float) -> void:
	if island != null and not is_instance_valid(island):
		cast_off()
	if not is_anchored():
		return
	var to_target := target_position() - raft.global_position
	to_target.y = 0.0
	var speed := minf(Tuning.anchor_reel_speed, to_target.length() * 0.8)
	raft.anchor_velocity = to_target.normalized() * speed if to_target.length() > 0.02 else Vector3.ZERO
	_place_cleat()
	_draw_rope()


## Keep the cleat on the raft's edge facing the island.
func _place_cleat() -> void:
	if cleat == null:
		return
	var build := raft.get_node("Build") as RaftBuilder
	var toward := raft.global_basis.inverse() * (island.global_position - raft.global_position)
	toward.y = 0.0
	toward = toward.normalized()
	cleat.position = toward * (build.extent_along(toward) - 0.25)


func _draw_rope() -> void:
	var start := cleat.global_position + Vector3.UP * 0.3
	var end := anchor_position()
	var length := start.distance_to(end)
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _rope_material)
	for i in 13:
		var t := i / 12.0
		_rope_mesh.surface_add_vertex(start.lerp(end, t) + Vector3.DOWN * length * 0.08 * 4.0 * t * (1.0 - t))
	_rope_mesh.surface_end()
