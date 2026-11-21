extends Node
## Milestone 1 test: "walking on the moving raft never glitches".
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/ride_test.tscn
## Exaggerates drift, turn, sway, bob and recentring, then drives the player through
## standing, walking, jumping and walking off the edge. Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var player: Player
var phase := ""
var phase_time := 0.0
var failures: Array[String] = []
var recentres := 0

# Per-phase measurements.
var start_local := Vector3.ZERO
var max_horizontal_drift := 0.0
var max_vertical_drift := 0.0
var ticks := 0
var floor_ticks := 0
var riding_ticks := 0
var left_raft := false
var jump_count := 0
var jump_start_local := Vector3.ZERO
var max_jump_drift := 0.0
var was_airborne := false
var grounded_time := 0.0
var detached := false
var respawned := false

var phases := [
	["settle", 1.5],
	["stand", 8.0],
	["walk_circle", 10.0],
	["walk_square", 8.0],
	["jumps", 6.0],
	["walk_off_edge", 12.0],
]
var phase_index := -1


func _ready() -> void:
	process_physics_priority = 200
	Tuning.drift_speed = 8.0
	WorldOrigin.threshold = 15.0
	WorldOrigin.recentred.connect(func(_s): recentres += 1)
	main = MAIN.instantiate()
	raft = main.get_node("Raft")
	player = main.get_node("Player")
	raft.turn_degrees_per_second = 15.0
	raft.sway_degrees = 4.0
	raft.bob_height = 0.4
	raft.bob_period = 3.0
	# Hold height: this test is about riding, not lift.
	raft.get_node("Lift").process_mode = Node.PROCESS_MODE_DISABLED
	raft.target_height = 85.0
	add_child(main)
	# No islands: this test is about riding the raft in open sky.
	main.get_node("Islands").process_mode = Node.PROCESS_MODE_DISABLED
	_next_phase()


func _local() -> Vector3:
	return raft.global_transform.affine_inverse() * player.global_position


func _next_phase() -> void:
	if phase != "":
		_finish_phase()
	phase_index += 1
	if phase_index >= phases.size():
		_report()
		return
	phase = phases[phase_index][0]
	phase_time = 0.0
	start_local = _local()
	max_horizontal_drift = 0.0
	max_vertical_drift = 0.0
	ticks = 0
	floor_ticks = 0
	riding_ticks = 0
	left_raft = false
	player.input_override = Vector2.ZERO
	if phase in ["walk_circle", "walk_square", "jumps"]:
		_put_player_at(Vector3(-0.3, 0.05, 0.3))


func _put_player_at(local: Vector3) -> void:
	player.global_position = raft.global_transform * local
	player.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if phase_index >= phases.size():
		return
	phase_time += delta
	var local := _local()
	ticks += 1
	if player.is_on_floor():
		floor_ticks += 1
	if player.ride_body == raft:
		riding_ticks += 1
	if absf(local.x) > 2.25 or absf(local.z) > 2.25:
		left_raft = true

	match phase:
		"stand":
			var d := local - start_local
			max_horizontal_drift = maxf(max_horizontal_drift, Vector2(d.x, d.z).length())
			max_vertical_drift = maxf(max_vertical_drift, absf(d.y))
		"walk_circle":
			var t := phase_time * 4.5
			player.input_override = Vector2(cos(t), sin(t))
			max_vertical_drift = maxf(max_vertical_drift, absf(local.y))
		"walk_square":
			# Hold one direction for 1 s at a time: forward, right, back, left.
			var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
			player.input_override = dirs[int(phase_time) % 4] * 0.4
			max_vertical_drift = maxf(max_vertical_drift, absf(local.y))
		"jumps":
			player.input_override = Vector2.ZERO
			var airborne := not player.is_on_floor()
			grounded_time = 0.0 if airborne else grounded_time + delta
			if not airborne and not was_airborne and grounded_time > 0.3:
				grounded_time = -10.0
				player.jump_override = true
				jump_start_local = local
				jump_count += 1
			if was_airborne and not airborne:
				# Landed: compare where we came down with where we took off.
				var d := local - jump_start_local
				max_jump_drift = maxf(max_jump_drift, Vector2(d.x, d.z).length())
			was_airborne = airborne
		"walk_off_edge":
			if not detached:
				player.input_override = Vector2(0, -1)
				if player.ride_body == null:
					detached = true
					player.input_override = Vector2.ZERO
			elif not respawned and player.ride_body == raft and player.is_on_floor():
				respawned = true

	if phase_time >= phases[phase_index][1]:
		_next_phase()


func _finish_phase() -> void:
	var floor_pct := 100.0 * floor_ticks / maxi(ticks, 1)
	var ride_pct := 100.0 * riding_ticks / maxi(ticks, 1)
	match phase:
		"stand":
			print("stand: drift horizontal %.4f m, vertical %.4f m, on floor %.1f%%, riding %.1f%%" % [max_horizontal_drift, max_vertical_drift, floor_pct, ride_pct])
			_check(max_horizontal_drift < 0.02, "standing player slid %.3f m on the raft" % max_horizontal_drift)
			_check(max_vertical_drift < 0.05, "standing player bounced %.3f m" % max_vertical_drift)
			_check(floor_ticks == ticks, "standing player left the floor (%.1f%% on floor)" % floor_pct)
		"walk_circle", "walk_square":
			print("%s: max height off deck %.4f m, on floor %.1f%%, riding %.1f%%, left raft %s" % [phase, max_vertical_drift, floor_pct, ride_pct, left_raft])
			_check(floor_ticks == ticks, "%s: player left the floor (%.1f%% on floor)" % [phase, floor_pct])
			_check(riding_ticks == ticks, "%s: player stopped riding (%.1f%%)" % [phase, ride_pct])
			_check(max_vertical_drift < 0.4, "%s: player rose %.3f m off the deck" % [phase, max_vertical_drift])
			_check(not left_raft, "%s: player walked off the raft" % phase)
		"jumps":
			print("jumps: %d jumps, max landing offset from take-off spot %.4f m, riding %.1f%%" % [jump_count, max_jump_drift, ride_pct])
			_check(jump_count >= 4, "only %d jumps happened" % jump_count)
			# The raft sways 4 degrees here, so a 1.2 m jump lands a few cm off by geometry alone.
			_check(max_jump_drift < 0.08, "player landed %.3f m from where they jumped" % max_jump_drift)
			_check(riding_ticks == ticks, "player stopped riding during jumps")
		"walk_off_edge":
			print("walk off edge: detached %s, respawned on raft %s" % [detached, respawned])
			_check(detached, "walking off the edge never detached from the raft")
			_check(respawned, "player was not respawned onto the raft after falling")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _report() -> void:
	print("recentres during test: %d" % recentres)
	_check(recentres >= 10, "only %d recentres happened" % recentres)
	if failures.is_empty():
		print("RIDE TEST PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		print("RIDE TEST FAILED")
		get_tree().quit(1)
