extends Node3D
## Grey-box floating rocks scattered around the raft so drift is visible.
## Rocks that fall too far behind are moved to the far side of the area ahead.
## The node sits in the "recentre" group, so its children move with every recentre.

@export var follow: Node3D
@export var count := 140
@export var radius := 260.0
@export var height_spread := 70.0
@export var min_size := 1.0
@export var max_size := 9.0

var _rocks: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("recentre")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1729
	var centre := follow.global_position if follow else Vector3.ZERO
	for i in count:
		var rock := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			rng.randf_range(min_size, max_size),
			rng.randf_range(min_size, max_size) * 0.6,
			rng.randf_range(min_size, max_size)
		)
		var material := StandardMaterial3D.new()
		var shade := rng.randf_range(0.35, 0.6)
		material.albedo_color = Color(shade, shade * 0.95, shade * 1.08)
		mesh.material = material
		rock.mesh = mesh
		add_child(rock)
		var offset := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * radius
		offset.y = rng.randf_range(-height_spread, height_spread)
		# Keep a clear bubble around the raft.
		if Vector2(offset.x, offset.z).length() < 25.0:
			offset.x += 40.0
		rock.global_position = centre + offset
		rock.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		_rocks.append(rock)


func _process(_delta: float) -> void:
	if follow == null:
		return
	var centre := follow.global_position
	for rock in _rocks:
		var d := rock.global_position - centre
		var flat := Vector2(d.x, d.z)
		if flat.length() > radius * 1.1:
			# Wrap to the opposite side.
			var wrapped := -flat.normalized() * radius * 0.95
			rock.global_position = Vector3(centre.x + wrapped.x, rock.global_position.y, centre.z + wrapped.y)
