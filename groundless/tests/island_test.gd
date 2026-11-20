extends Node
## Milestone 4 test: islands and anchoring.
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/island_test.tscn
## Checks spawning (order, reachability, missed islands), reveal, the raft not passing
## through islands, hooking an island to anchor, reeling in, the rope's height limit,
## leaking while anchored, mantling, climbing hangroot, walking back aboard, casting off,
## recentring and the wreck's ending. Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var lift: RaftLift
var anchor: RaftAnchor
var player: Player
var islands: IslandSpawner
var failures: Array[String] = []


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	lift = raft.get_node("Lift")
	anchor = raft.get_node("Anchor")
	player = main.get_node("Player")
	islands = main.get_node("Islands")
	main.get_node("Flotsam").set_physics_process(false)
	_run()


func _ticks(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures.append(message)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Hold the raft at a height: lift off, target fixed.
func _hold_raft_at(height: float) -> void:
	lift.process_mode = Node.PROCESS_MODE_DISABLED
	raft.target_height = height
	raft._base_position.y = height
	raft.velocity.y = 0.0


## Put an island at a horizontal offset from the raft with its lip `lip_offset` above the deck.
func _place_island(island: Island, offset: Vector3, lip_offset: float) -> void:
	island.global_position = Vector3(raft.global_position.x + offset.x, raft.get_base_height() + lip_offset, raft.global_position.z + offset.z)


func _face(point: Vector3) -> void:
	player.look_at(Vector3(point.x, player.global_position.y, point.z))
	player.head.rotation.x = 0.0


func _run() -> void:
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0
	await _ticks(0.5)

	print("Spawning the first island")
	var drift := raft.get_horizontal_velocity().normalized()
	var spawned: Array = []
	islands.island_spawned.connect(func(i): spawned.append(i))
	await _ticks(4.0)
	_check(spawned.size() == 1, "an island appears after a few seconds")
	var first: Island = spawned[0]
	_check(first.kind == "pod_grove", "the first island is the pod grove")
	var to := first.global_position - raft.global_position
	var along := _flat(to).dot(drift)
	var sideways := _flat(to - drift * along).length()
	var max_side := islands.max_side_offset(Tuning.island_first_spawn_distance / raft.get_horizontal_velocity().length())
	print("  %.0f m ahead, %.1f m sideways (max %.1f), lip %+.1f m" % [along, sideways, max_side, to.y])
	_check(along > Tuning.island_first_spawn_distance * 0.9, "it's ahead, downwind")
	_check(sideways <= max_side + 1.5, "sideways offset is within reach without a paddle")
	_check(absf(to.y) <= Tuning.island_first_vertical_offset + 0.5, "its lip is near the raft's height")
	_check(first.reveal < 0.5, "far away it's mostly silhouette (reveal %.2f)" % first.reveal)
	player.items["sky_paddle"] = 1
	_check(islands.max_side_offset(160.0) > max_side * 5.0, "with a paddle, islands may appear further off the path")
	player.items["sky_paddle"] = 0

	print("Raft can't pass through an island")
	_hold_raft_at(raft.get_base_height())
	_place_island(first, drift * 25.0, 0.5)
	var overlap := false
	var closest := 1e9
	for i in 25 * 60:
		await get_tree().physics_frame
		var d := _flat(raft.global_position - first.global_position)
		var reach := (raft.get_node("Build") as RaftBuilder).extent_along(raft.global_basis.inverse() * -d.normalized())
		closest = minf(closest, d.length() - first.radius - reach)
		if d.length() < first.radius + reach - 0.3:
			overlap = true
	_check(not overlap, "the raft slides around the island (closest edge gap %.2f m)" % closest)
	_check(first.reveal > 0.95, "up close the island is in full colour (reveal %.2f)" % first.reveal)

	print("Hook into the island to anchor")
	_place_island(first, drift * 17.0, 1.0)
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	var aim_at := first.global_position - drift * (first.radius - 1.0) + Vector3.UP * 0.2
	_face(aim_at)
	player.head.look_at(aim_at)
	player.head.rotation.y = 0.0
	player.head.rotation.z = 0.0
	player.throw_hook(1.0)
	await _ticks(2.5)
	_check(anchor.is_anchored() and anchor.island == first, "the hook catches the island and the raft is anchored")
	_check(anchor.cleat != null, "a cleat appears on the raft")

	print("Reel in and hold")
	lift.process_mode = Node.PROCESS_MODE_INHERIT
	await _ticks(25.0)
	var gap := anchor.edge_gap()
	_check(absf(gap - Tuning.anchor_gap) < 0.35, "the raft is reeled in until its edge is about 1 m from the lip (%.2f m)" % gap)
	_check(_flat(raft.get_horizontal_velocity()).length() < 0.2, "and held there (%.2f m/s)" % _flat(raft.get_horizontal_velocity()).length())

	print("Anchor rope limits height")
	for pod in lift.pods():
		pod.gas = 0.0
	await _ticks(25.0)
	var below := anchor.anchor_position().y - raft.get_base_height()
	_check(below <= Tuning.anchor_rope_length + 0.5, "with no lift the rope holds the raft %.1f m below the anchor (max %.0f)" % [below, Tuning.anchor_rope_length])
	for pod in lift.pods():
		pod.gas = 1.0

	print("Leaking while anchored")
	Tuning.leak_healthy_per_min = 0.02
	Tuning.leak_damaged_per_min = 0.15
	var wilting: AnchorPoint = raft.get_node("AnchorFrontLeft")
	var gas := wilting.pod.gas
	await _ticks(6.0)
	var per_min := (gas - wilting.pod.gas) * 10.0
	_check(absf(per_min - 0.02) < 0.003, "a wilting pod leaks only at the healthy rate while anchored (%.3f/min)" % per_min)
	Tuning.leak_while_anchored = false
	gas = wilting.pod.gas
	await _ticks(3.0)
	_check(is_equal_approx(gas, wilting.pod.gas), "leak_while_anchored = false stops leaking")
	Tuning.leak_while_anchored = true
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0

	print("Mantle onto the island")
	_hold_raft_at(anchor.anchor_position().y - 1.2)
	await _ticks(3.0)
	var toward := _flat(first.global_position - raft.global_position).normalized()
	var reach_edge := (raft.get_node("Build") as RaftBuilder).extent_along(raft.global_basis.inverse() * toward)
	player.global_position = raft.global_position + toward * (reach_edge - 0.4) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _ticks(0.5)
	_face(first.global_position)
	player.jump_override = true
	await _ticks(1.0)
	await _ticks(0.5)
	var on_island := player.is_on_floor() and absf(player.global_position.y - first.global_position.y) < 0.3
	_check(on_island, "jumping at a 1.2 m ledge mantles onto the island (feet %+.2f m from lip)" % (player.global_position.y - first.global_position.y))
	_check(first.visited and islands.sequence_index == 1, "standing on it counts as visiting the pod grove")

	print("Gather on the island")
	var pod_node: ResourceNode = null
	for child in first.get_children():
		if child is ResourceNode and child.gives.has("pod"):
			pod_node = child
			break
	var pods: int = player.held_pods
	pod_node.interact(player)
	_check(player.held_pods == pods + 1 and pod_node.uses == 0, "a pod vine gives a drift-pod")

	print("Back aboard")
	player.global_position = first.global_position + toward * -(first.radius - 1.0) + Vector3.UP * 0.1
	await _ticks(0.3)
	_face(raft.global_position)
	player.input_override = Vector2(0, -1)
	await _ticks(1.5)
	player.input_override = Vector2.ZERO
	await _ticks(1.0)
	_check(player.ride_body == raft and player.is_on_floor(), "walking off the lip drops the player back onto the raft")

	print("Climb hangroot")
	_hold_raft_at(anchor.anchor_position().y - 7.0)
	await _ticks(3.0)
	var ladder: Ladder = null
	var best := 1e9
	for node in get_tree().get_nodes_in_group("ladder"):
		if first.is_ancestor_of(node):
			var dist := _flat(node.global_position - raft.global_position).length()
			if dist < best:
				best = dist
				ladder = node
	player.global_position = ladder.global_position + Vector3.UP * (raft.get_base_height() + 0.2 - ladder.global_position.y)
	player.velocity = Vector3.ZERO
	_face(first.global_position)
	player.input_override = Vector2(0, -1)
	var climbed := false
	for i in 8 * 60:
		await get_tree().physics_frame
		if player.climbing:
			climbed = true
		if not player.mantling and player.is_on_floor() and player.global_position.y > first.global_position.y - 0.3:
			break
	player.input_override = Vector2.ZERO
	await _ticks(0.5)
	_check(climbed, "pushing forward on hangroot climbs")
	_check(absf(player.global_position.y - first.global_position.y) < 0.4 and player.is_on_floor(), "and climbing to the top mantles onto the island (feet %+.2f m)" % (player.global_position.y - first.global_position.y))

	print("Cast off")
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	lift.process_mode = Node.PROCESS_MODE_INHERIT
	anchor.cleat.interact(player)
	_check(not anchor.is_anchored() and raft.anchor_velocity == null, "E on the cleat casts off")
	# Height-matched, the wind first slides the raft round the island's edge, then on.
	await _ticks(30.0)
	_check(_flat(raft.get_horizontal_velocity()).length() > 1.0, "the raft drifts on")

	print("Next island, and missing it")
	islands.current = null
	islands._timer = 0.0
	await _ticks(0.2)
	var second: Island = islands.current
	_check(second != null and second.kind == "weeping_rock", "after the pod grove comes the weeping rock")
	# Put it behind the raft: passed without visiting.
	var back := -raft.get_horizontal_velocity().normalized()
	_place_island(second, back * 120.0, 0.0)
	await _ticks(0.2)
	_check(islands.current == null, "an island left behind unvisited is let go")
	await _ticks(Tuning.island_missed_delay + 0.5)
	_check(islands.current != null and islands.current.kind == "weeping_rock", "a missed island comes back")

	print("Recentring keeps islands in place")
	var island_now: Island = islands.current
	var rel := island_now.global_position - raft.global_position
	WorldOrigin.recentre(Vector3(300, 0, -200))
	await get_tree().physics_frame
	var rel_after := island_now.global_position - raft.global_position
	_check(rel.distance_to(rel_after) < 3.0, "island stays put relative to the raft through a recentre")

	print("The wreck ends the slice")
	islands.sequence_index = 2
	islands.current = null
	islands._timer = 0.0
	await _ticks(0.2)
	var wreck: Island = islands.current
	_check(wreck.kind == "wreck", "the third island is the wreck")
	var compass: StoryItem = null
	var note: StoryItem = null
	for child in wreck.get_children():
		if child is StoryItem:
			if child.ends_slice:
				compass = child
			else:
				note = child
	note.interact(player)
	var message: Label = main.get_node("Hud/Message")
	_check(message.text.contains("needle"), "the note can be read")
	compass.interact(player)
	_check(message.text.contains("End of the vertical slice"), "picking up the compass ends the slice")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("ISLAND TEST PASSED")
		get_tree().quit(0)
	else:
		print("ISLAND TEST FAILED (%d)" % failures.size())
		get_tree().quit(1)
