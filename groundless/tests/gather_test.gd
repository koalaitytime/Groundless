extends Node
## Gathering test: charged hook, early reel, clumps, grabbing by hand, wind nets, streams.
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/gather_test.tscn
## Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var build: RaftBuilder
var player: Player
var spawner: FlotsamSpawner
var failures: Array[String] = []


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	build = raft.get_node("Build")
	player = main.get_node("Player")
	spawner = main.get_node("Flotsam")
	spawner.set_physics_process(false)
	_run()


func _ticks(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures.append(message)


func _clear_flotsam() -> void:
	for child in spawner.get_children():
		child.free()


## Furthest the hook gets from the hand for a throw at `power`, aimed 25 degrees up.
func _throw_distance(power: float) -> float:
	player.head.rotation.x = deg_to_rad(25.0)
	await get_tree().physics_frame
	player.throw_hook(power)
	var furthest := 0.0
	while player.hook.state != Hook.State.IDLE:
		furthest = maxf(furthest, player.hook.global_position.distance_to(player.hook.hand_position()))
		await get_tree().physics_frame
	return furthest


func _run() -> void:
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0
	await _ticks(0.5)
	_clear_flotsam()
	player.items = {"wood": 30, "rope": 10, "cloth": 10, "fiber": 10, "pod": 0, "patch": 0, "sky_paddle": 0}

	print("Charged throw")
	player.select_slot(Player.Slot.HOOK)
	player.use_primary()
	await _ticks(0.4)
	var charge := player.hook_charge
	_check(charge > 0.4 and charge < 0.6, "holding for 0.4 s charges about half (%.2f)" % charge)
	await _ticks(1.0)
	_check(is_equal_approx(player.hook_charge, 1.0), "charge caps at full")
	player.hook_charge = -1.0
	var weak := await _throw_distance(0.1)
	var strong := await _throw_distance(1.0)
	print("  weak throw %.1f m, full throw %.1f m" % [weak, strong])
	_check(strong > weak * 1.8, "a full charge throws much farther")
	_check(strong <= Tuning.hook_range + 1.0, "the rope stops the hook at %.0f m" % Tuning.hook_range)
	player.head.rotation.x = 0.0

	print("Reel in early")
	player.throw_hook(1.0)
	await _ticks(0.15)
	player.use_primary()
	_check(player.hook.state == Hook.State.REELING, "clicking while the hook flies reels it in")
	await _ticks(3.0)
	_check(player.hook.state == Hook.State.IDLE, "hook back in hand")

	print("Clumps")
	var clump := spawner.spawn(["wood", "rope", "cloth"])
	clump.global_position = player.camera.global_position - player.camera.global_basis.z * 7.0
	await get_tree().physics_frame
	var before: Dictionary = player.items.duplicate()
	player.hook.throw((clump.global_position - player.camera.global_position).normalized() + Vector3.UP * 0.02, player._ride_velocity, 1.0)
	await _ticks(4.0)
	_check(player.items.wood == before.wood + 1 and player.items.rope == before.rope + 1 and player.items.cloth == before.cloth + 1, "one hooked clump gives all three items")
	var saw_clump := false
	for i in 300:
		if spawner.random_material_contents().size() > 1:
			saw_clump = true
			break
	_check(saw_clump, "random material flotsam is sometimes a clump")
	var saved_chance := Tuning.clump_chance
	Tuning.clump_chance = 0.0
	var any_clump := false
	for i in 200:
		any_clump = any_clump or spawner.random_material_contents().size() > 1
	_check(not any_clump, "clump_chance 0 turns clumps off")
	Tuning.clump_chance = saved_chance

	print("Grab by hand")
	var near := spawner.spawn("fiber")
	near.global_position = player.camera.global_position - player.camera.global_basis.z * 1.6
	await _ticks(0.05)
	near.global_position = player.camera.global_position - player.camera.global_basis.z * 1.6
	await get_tree().physics_frame
	_check(player.focused_flotsam == near, "looking at nearby flotsam focuses it")
	var fiber: int = player.items.fiber
	player.grab_flotsam()
	_check(player.items.fiber == fiber + 1, "E grabs it")
	var far := spawner.spawn("fiber")
	far.global_position = player.camera.global_position - player.camera.global_basis.z * 6.0
	await _ticks(0.05)
	far.global_position = player.camera.global_position - player.camera.global_basis.z * 6.0
	await get_tree().physics_frame
	_check(player.focused_flotsam == null, "flotsam out of reach can't be grabbed")
	_clear_flotsam()

	print("Wind net")
	var weight := (raft.get_node("Lift") as RaftLift).get_weight()
	_check(build.place("plank", Vector2i(2, 0), player), "plank for the net")
	_check(build.place("wind_net", Vector2i(2, 0), player), "place a wind net")
	var net: WindNet = build.tiles[Vector2i(2, 0)].fixture
	_check(is_equal_approx((raft.get_node("Lift") as RaftLift).get_weight() - weight, Tuning.plank_weight + Tuning.wind_net_weight), "net adds its weight")
	for i in 3:
		var piece := spawner.spawn(["wood", "fiber"] if i == 0 else "rope")
		piece.global_position = net.global_position + Vector3(0, 1.0, 0)
	await _ticks(0.3)
	_check(net.caught.size() == 4, "net catches flotsam drifting through it (%d items)" % net.caught.size())
	_check(net.get_prompt(player).contains("4/"), "prompt shows what's in the net")
	var rope: int = player.items.rope
	net.interact(player)
	_check(player.items.rope == rope + 2 and net.caught.is_empty(), "E empties the net into the inventory")
	for i in Tuning.wind_net_capacity + 3:
		var piece := spawner.spawn("wood")
		piece.global_position = net.global_position + Vector3(0, 1.0, 0)
	await _ticks(0.3)
	_check(net.caught.size() == Tuning.wind_net_capacity and net.is_full(), "net stops at capacity")
	_check(build.remove(Vector2i(2, 0), player), "net can be removed for a refund")
	_clear_flotsam()

	print("Flotsam streams")
	var stream_height := raft.get_base_height() + 12.0
	spawner.start_stream(stream_height)
	spawner.set_physics_process(true)
	Tuning.drift_pod_first_delay = 1000.0
	await _ticks(15.0)
	var in_band := 0
	var total := 0
	for child in spawner.get_children():
		if child is Flotsam:
			total += 1
			if absf(child.global_position.y - stream_height) <= Tuning.stream_half_thickness + 0.5:
				in_band += 1
	print("  %d of %d flotsam pieces are in the stream band" % [in_band, total])
	_check(in_band >= 7, "a stream keeps flowing at its height")
	var dial: AltitudeDial = raft.get_node("AltitudeDial")
	_check(dial._stream_marks[0].visible, "the altitude dial marks the stream's height")
	# The stream passes over the raft: the pieces' horizontal paths come close.
	var closest := 1e9
	for i in roundi(Tuning.drift_pod_arrival_time * 60.0):
		await get_tree().physics_frame
		for child in spawner.get_children():
			if child is Flotsam and absf(child.global_position.y - stream_height) < 3.0:
				var d: Vector3 = child.global_position - raft.global_position
				closest = minf(closest, Vector2(d.x, d.z).length())
	_check(closest < Tuning.stream_half_width + 1.0, "stream pieces pass over the raft (closest %.1f m sideways)" % closest)

	_report()


func _report() -> void:
	if failures.is_empty():
		print("GATHER TEST PASSED")
		get_tree().quit(0)
	else:
		print("GATHER TEST FAILED (%d)" % failures.size())
		get_tree().quit(1)
