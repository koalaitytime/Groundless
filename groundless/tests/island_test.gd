extends Node
## Islands and anchoring test (milestone 4, with the island kit).
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/island_test.tscn
## Checks spawning (teaching order, reachability, type chances, missed islands, the story
## island), island size and landforms, reveal, the raft not passing through islands, hooking
## an island to anchor, mooring level with the lip, leaking while anchored, walking across,
## mantling, climbing hangroot, walking back aboard, casting off, recentring and the ending.
## Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var lift: RaftLift
var anchor: RaftAnchor
var build: RaftBuilder
var player: Player
var islands: IslandSpawner
var failures: Array[String] = []


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	lift = raft.get_node("Lift")
	anchor = raft.get_node("Anchor")
	build = raft.get_node("Build")
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


func _hold_raft_at(height: float) -> void:
	lift.process_mode = Node.PROCESS_MODE_DISABLED
	raft.target_height = height
	raft._base_position.y = height
	raft.velocity.y = 0.0


## The point on the island's outline closest to `from`, with the outward direction there.
func _nearest_edge(island: Island, from: Vector3) -> Dictionary:
	var lobes := island.world_lobes()
	var best := {}
	var best_d := INF
	for lobe in lobes:
		var dir := _flat(from - lobe.centre).normalized()
		var p: Vector3 = lobe.centre + dir * lobe.radius
		var inside := false
		for other in lobes:
			if other != lobe and _flat(p - other.centre).length() < other.radius - 0.2:
				inside = true
		if not inside and _flat(p - from).length() < best_d:
			best_d = _flat(p - from).length()
			best = {"point": Vector3(p.x, island.global_position.y, p.z), "out": dir, "distance": best_d}
	return best


## Move an island so its nearest edge is `gap` metres from the raft's edge (along
## `direction`), with its lip `lip_offset` above the deck.
func _place_island(island: Island, direction: Vector3, gap: float, lip_offset: float) -> void:
	island.global_position = raft.global_position + direction * (island.radius + gap + 5.0)
	for i in 6:
		var edge := _nearest_edge(island, raft.global_position)
		var reach := build.extent_along(raft.global_basis.inverse() * -edge.out)
		island.global_position -= direction * (edge.distance - reach - gap)
	island.global_position.y = raft.get_base_height() + lip_offset


func _face(point: Vector3) -> void:
	player.look_at(Vector3(point.x, player.global_position.y, point.z))
	player.head.rotation = Vector3.ZERO


func _overlaps(island: Island) -> bool:
	for circle in island.solid_circles_at(raft.get_base_height() + 0.2):
		var d := _flat(raft.global_position - circle.centre)
		var reach := build.extent_along(raft.global_basis.inverse() * -d.normalized())
		if d.length() < circle.radius + reach - 0.3:
			return true
	return false


func _run() -> void:
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0
	await _ticks(0.5)

	print("Island types")
	var counts := {}
	for i in 5000:
		var spec := islands.random_spec()
		var bucket: String = "rare" if spec.kind.begins_with("rare") else spec.kind
		counts[bucket] = counts.get(bucket, 0) + 1
	var rare_pct: float = 100.0 * counts.get("rare", 0) / 5000.0
	var wreck_pct: float = 100.0 * counts.get("wreck", 0) / 5000.0
	print("  standard %d, wreck %.1f%%, rare %.1f%%" % [counts.get("standard", 0), wreck_pct, rare_pct])
	_check(rare_pct > 3.0 and rare_pct < 5.0, "rare encounters are 3 to 5% of random islands")
	_check(wreck_pct > 14.0 and wreck_pct < 20.0, "wrecks are about 1 in 6")
	var sizes: Array[float] = []
	var landform_counts: Array[int] = []
	for i in 12:
		var test_island := Island.new()
		test_island.island_seed = 1000 + i
		add_child(test_island)
		test_island.global_position = Vector3(5000 + i * 200, 500, 5000)
		sizes.append(test_island.radius * 2.0)
		landform_counts.append(test_island.landforms.size())
		test_island.queue_free()
	print("  standard island widths %s m, landforms %s" % [str(sizes.map(func(x): return roundi(x))), str(landform_counts)])
	_check(sizes.min() >= 38.0 and sizes.max() <= 95.0, "standard islands are roughly 40 to 80 m across")
	_check(landform_counts.min() >= 2 and landform_counts.max() <= 5, "standard islands get several landforms from the kit")
	var seeded_a := Island.new()
	seeded_a.island_seed = 77
	var seeded_b := Island.new()
	seeded_b.island_seed = 77
	add_child(seeded_a)
	add_child(seeded_b)
	_check(seeded_a.landforms == seeded_b.landforms and is_equal_approx(seeded_a.radius, seeded_b.radius), "the same seed builds the same island")
	seeded_a.queue_free()
	seeded_b.queue_free()

	print("Spawning the first island")
	var drift := raft.get_horizontal_velocity().normalized()
	var spawned: Array = []
	islands.island_spawned.connect(func(i): spawned.append(i))
	await _ticks(4.0)
	_check(spawned.size() == 1, "an island appears after a few seconds")
	var first: Island = spawned[0]
	_check(first.kind == "standard" and first.theme == "grove" and first.landforms.has("grove"), "the first island is a standard island with a pod grove")
	var to := first.global_position - raft.global_position
	var along := _flat(to).dot(drift)
	var sideways := _flat(to - drift * along).length()
	var max_side := islands.max_side_offset(Tuning.island_first_spawn_distance / raft.get_horizontal_velocity().length())
	print("  %.0f m ahead, %.1f m sideways (max %.1f), lip %+.1f m, %.0f m across" % [along, sideways, max_side, to.y, first.radius * 2.0])
	_check(along > Tuning.island_first_spawn_distance * 0.9, "it's ahead, downwind")
	_check(sideways <= max_side + 1.5, "sideways offset is within reach without a paddle")
	_check(absf(to.y) <= Tuning.island_first_vertical_offset + 0.5, "its lip is near the raft's height")
	_check(first.reveal < 0.7, "far away it's mostly silhouette (reveal %.2f)" % first.reveal)

	print("Raft can't pass through an island")
	_hold_raft_at(raft.get_base_height())
	_place_island(first, drift, 12.0, 0.5)
	var overlap := false
	for i in 30 * 60:
		await get_tree().physics_frame
		if _overlaps(first):
			overlap = true
	_check(not overlap, "the raft slides around the island's lobes and landforms")
	_check(first.reveal > 0.95, "up close the island is in full colour (reveal %.2f)" % first.reveal)

	print("Hook into the island to anchor")
	var towards := _flat(first.global_position - raft.global_position).normalized()
	_place_island(first, towards, 9.0, 1.0)
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	var edge := _nearest_edge(first, raft.global_position)
	var aim_at: Vector3 = edge.point - edge.out * 2.0 + Vector3.UP * 0.1
	_face(aim_at)
	player.head.look_at(aim_at)
	player.head.rotation.y = 0.0
	player.head.rotation.z = 0.0
	player.throw_hook(1.0)
	await _ticks(2.5)
	_check(anchor.is_anchored() and anchor.island == first, "the hook catches the island and the raft is anchored")

	print("Moored level with the lip")
	lift.process_mode = Node.PROCESS_MODE_INHERIT
	for pod in lift.pods():
		pod.gas = 0.0
	await _ticks(25.0)
	var gap := anchor.edge_gap()
	_check(absf(gap - Tuning.anchor_gap) < 0.35, "reeled in until its edge is anchor_gap from the island (%.2f m)" % gap)
	_check(_flat(raft.get_horizontal_velocity()).length() < 0.2, "and held there")
	var level := raft.global_position.y - first.global_position.y
	_check(absf(level) < 0.1, "with no lift at all, the deck is held level with the lip (%+.2f m)" % level)
	_check(rad_to_deg(raft.global_basis.y.angle_to(Vector3.UP)) < 0.2, "a moored raft stops bobbing and swaying")
	_check(not _overlaps(first), "the moored raft doesn't overlap the island")
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

	print("Walk straight across")
	edge = _nearest_edge(first, raft.global_position)
	var reach_edge := build.extent_along(raft.global_basis.inverse() * -edge.out)
	player.global_position = raft.global_position - edge.out * (reach_edge - 0.8) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _ticks(0.3)
	_face(edge.point - edge.out * 5.0)
	player.input_override = Vector2(0, -1)
	await _ticks(1.0)
	player.input_override = Vector2.ZERO
	await _ticks(0.5)
	var feet := player.global_position.y - first.global_position.y
	_check(player.is_on_floor() and player.ride_body == null and first.covers(player.global_position) and absf(feet) < 0.1, "the player walks from the deck onto the island (feet %+.2f m)" % feet)
	_check(first.visited and islands.teaching_index == 1, "that counts as visiting the first teaching island")

	print("Gather on the island")
	var pod_node: ResourceNode = null
	for child in first.get_children():
		if child is ResourceNode and child.gives.has("pod"):
			pod_node = child
			break
	var pods: int = player.held_pods
	pod_node.interact(player)
	_check(player.held_pods == pods + 1, "a pod vine in the grove gives a drift-pod")

	print("Mantle onto the island")
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	_hold_raft_at(first.global_position.y - 1.2)
	await _ticks(2.0)
	edge = _nearest_edge(first, raft.global_position)
	reach_edge = build.extent_along(raft.global_basis.inverse() * -edge.out)
	player.global_position = raft.global_position - edge.out * (reach_edge - 0.4) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _ticks(0.5)
	_face(edge.point - edge.out * 5.0)
	player.jump_override = true
	await _ticks(1.5)
	feet = player.global_position.y - first.global_position.y
	_check(player.is_on_floor() and absf(feet) < 0.3, "jumping at a 1.2 m lip mantles onto the island (feet %+.2f m)" % feet)

	print("Back aboard")
	edge = _nearest_edge(first, raft.global_position)
	player.global_position = edge.point - edge.out * 1.2 + Vector3.UP * 0.1
	await _ticks(0.3)
	_face(raft.global_position)
	player.input_override = Vector2(0, -1)
	await _ticks(1.5)
	player.input_override = Vector2.ZERO
	await _ticks(1.0)
	_check(player.ride_body == raft and player.is_on_floor(), "walking off the lip drops the player back onto the raft")

	print("Climb hangroot")
	var ladder: Ladder = null
	for node in get_tree().get_nodes_in_group("ladder"):
		if first.is_ancestor_of(node):
			ladder = node
			break
	player.global_position = ladder.global_position + Vector3.UP * (ladder.top_y() - ladder.global_position.y - 6.0)
	player.velocity = Vector3.ZERO
	var lobe_centre := first.global_position
	var best := INF
	for lobe in first.world_lobes():
		var d: float = _flat(lobe.centre - ladder.global_position).length() - lobe.radius
		if d < best:
			best = d
			lobe_centre = lobe.centre
	_face(lobe_centre)
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
	feet = player.global_position.y - first.global_position.y
	_check(player.is_on_floor() and absf(feet) < 0.4, "and climbing to the top mantles onto the island (feet %+.2f m)" % feet)

	print("Cast off")
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	lift.process_mode = Node.PROCESS_MODE_INHERIT
	anchor.cleat.interact(player)
	_check(not anchor.is_anchored() and raft.anchor_velocity == null, "E on the cleat casts off")
	await _ticks(40.0)
	_check(_flat(raft.get_horizontal_velocity()).length() > 1.0, "the raft drifts on")

	print("Next island, and missing it")
	islands.current = null
	islands._timer = 0.0
	await _ticks(0.2)
	var second: Island = islands.current
	_check(second != null and second.kind == "standard" and second.theme == "hangroot", "the second island is the hangroot teaching island")
	var hangroot_ladders := 0
	for node in get_tree().get_nodes_in_group("ladder"):
		if second.is_ancestor_of(node):
			hangroot_ladders += 1
	_check(hangroot_ladders >= 4, "it has long root curtains (%d)" % hangroot_ladders)
	second.global_position = raft.global_position - raft.get_horizontal_velocity().normalized() * (second.radius + 120.0)
	await _ticks(0.2)
	_check(islands.current == null, "an island left behind unvisited is let go")
	await _ticks(Tuning.island_missed_delay + 0.5)
	_check(islands.current != null and islands.current.theme == "hangroot", "a missed teaching island comes back")

	print("Recentring keeps islands in place")
	var island_now: Island = islands.current
	var rel := island_now.global_position - raft.global_position
	WorldOrigin.recentre(Vector3(300, 0, -200))
	await get_tree().physics_frame
	_check(rel.distance_to(island_now.global_position - raft.global_position) < 3.0, "island stays put relative to the raft through a recentre")

	print("Random islands, then the story island")
	islands.teaching_index = 2
	islands.visited_count = 2
	islands._owed = null
	_check(islands.next_spec().kind != "story_wreck", "no story island before enough visits")
	islands.visited_count = 3
	islands.current = null
	islands._timer = 0.0
	await _ticks(0.2)
	var story: Island = islands.current
	_check(story.kind == "story_wreck", "after three visits the story island (the wreck) appears")
	_check(story.radius * 2.0 > 80.0, "the story island is large (%.0f m across)" % (story.radius * 2.0))
	var compass: StoryItem = null
	var note: StoryItem = null
	for child in story.get_children():
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
