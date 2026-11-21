extends Node
## Milestone 5 test: survival, the caustic rain storm and the pod-leech.
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/survival_test.tscn
## Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var lift: RaftLift
var build: RaftBuilder
var player: Player
var storm: Storm
var leeches: LeechSpawner
var failures: Array[String] = []


func _ready() -> void:
	# Nothing happens on its own: the test starts storms and leeches itself.
	Tuning.storm_first_delay = 99999.0
	Tuning.leech_first_delay = 99999.0
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	lift = raft.get_node("Lift")
	build = raft.get_node("Build")
	player = main.get_node("Player")
	storm = main.get_node("Storm")
	leeches = main.get_node("Leeches")
	main.get_node("Flotsam").set_physics_process(false)
	main.get_node("Islands").process_mode = Node.PROCESS_MODE_DISABLED
	_run()


func _ticks(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures.append(message)


func _run() -> void:
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0
	await _ticks(0.5)
	var s := player.survival
	player.items = {"wood": 30, "rope": 10, "cloth": 10, "fiber": 10, "pod": 0, "patch": 0, "sky_paddle": 0, "fungus": 0}

	print("Thirst and hunger")
	await _ticks(60.0)
	var thirst_per_min := 100.0 - s.thirst
	var hunger_per_min := 100.0 - s.hunger
	_check(absf(thirst_per_min - 100.0 / Tuning.thirst_minutes) < 0.3, "thirst runs out in %.0f min (%.1f per min)" % [Tuning.thirst_minutes, thirst_per_min])
	_check(absf(hunger_per_min - 100.0 / Tuning.hunger_minutes) < 0.3, "hunger runs out in %.0f min (%.1f per min)" % [Tuning.hunger_minutes, hunger_per_min])
	s.thirst = 0.0
	var health := s.health
	await _ticks(4.0)
	_check(s.health < health - 1.5, "empty thirst hurts (%.1f -> %.1f)" % [health, s.health])
	s.thirst = 80.0
	health = s.health
	await _ticks(4.0)
	_check(s.health > health, "fed and watered, health comes back")

	print("Drinking and eating")
	_check(build.place("rain_catcher", Vector2i(0, 0), player), "build a rain catcher")
	var catcher: RainCatcher = build.tiles[Vector2i(0, 0)].fixture
	catcher.set_water(3.0)
	var weight := lift.get_weight()
	s.thirst = 20.0
	catcher.interact(player)
	_check(is_equal_approx(s.thirst, 20.0 + Tuning.drink_amount), "E on the catcher drinks (thirst +%d)" % Tuning.drink_amount)
	_check(absf(catcher.water - 2.0) < 0.05 and absf(weight - lift.get_weight() - 1.0) < 0.05, "drinking takes a litre and a kilo off the raft")
	catcher.alt_interact(player)
	_check(catcher.water == 0.0, "Q dumps the water")
	await _ticks(30.0)
	_check(catcher.water > 0.1 and catcher.water < 0.3, "passing mist slowly fills it (%.2f L in 30 s)" % catcher.water)
	var spring := SpringWater.new()
	add_child(spring)
	s.thirst = 10.0
	spring.interact(player)
	_check(is_equal_approx(s.thirst, 10.0 + Tuning.spring_drink_amount), "a spring gives a long drink")
	spring.queue_free()
	var found_spring := false
	for seed in range(1, 60):
		var island := Island.new()
		island.island_seed = seed
		add_child(island)
		island.global_position = Vector3(9000, 600, 9000)
		var has := island.landforms.has("spring")
		var has_fungus := false
		for child in island.get_children():
			if child is ResourceNode and child.gives.has("fungus"):
				has_fungus = true
		var has_water := false
		for child in island.get_children():
			if child is SpringWater:
				has_water = true
		island.free()
		if has:
			found_spring = has_water and has_fungus
			break
	_check(found_spring, "islands with a spring have drinkable water, and shelf fungus under their roots")
	s.hunger = 30.0
	_check(not s.eat_fungus(), "can't eat without fungus")
	player.items.fungus = 2
	_check(s.eat_fungus() and is_equal_approx(s.hunger, 30.0 + Tuning.fungus_food) and player.items.fungus == 1, "F eats a shelf fungus")

	print("Falling off")
	player.items = {"wood": 10, "rope": 4, "cloth": 3, "fiber": 1, "pod": 2, "patch": 0, "sky_paddle": 0, "fungus": 1}
	player.global_position = raft.global_position + Vector3(12, 0, 0)
	player.velocity = Vector3.ZERO
	var blacked_out := [false]
	s.passed_out.connect(func(_r): blacked_out[0] = true, CONNECT_ONE_SHOT)
	await _ticks(6.0)
	_check(blacked_out[0], "falling far below the raft blacks you out")
	_check(player.ride_body == raft and not s.out_cold, "and you wake on the raft")
	_check(player.items.wood == 5 and player.items.rope == 2 and player.items.pod == 1, "losing half of what you carried (wood %d, rope %d)" % [player.items.wood, player.items.rope])

	print("Storm warning")
	var warned := [false]
	storm.warning_started.connect(func(): warned[0] = true, CONNECT_ONE_SHOT)
	storm.start_warning()
	_check(warned[0] and storm.is_warning() and not storm.is_raining(), "a warning comes first")
	_check(is_equal_approx(storm.time_to_rain(), Tuning.storm_warning), "with %d s to get under a roof" % Tuning.storm_warning)
	var message: Label = main.get_node("Hud/Message")
	await get_tree().process_frame
	_check(message.text.contains("Caustic rain"), "the player is told")

	print("Rain")
	player.items = {"wood": 30, "rope": 10, "cloth": 10, "fiber": 10, "pod": 0, "patch": 0, "sky_paddle": 0, "fungus": 0}
	player.global_position = raft.global_transform * Vector3(-0.3, 0.1, 0.3)
	s.health = 100.0
	s.thirst = 100.0
	s.hunger = 100.0
	var open_anchor: AnchorPoint = raft.get_node("AnchorBackLeft")
	var roofed_anchor: AnchorPoint = raft.get_node("AnchorBackRight")
	build.place("roof", build.tile_of(roofed_anchor.position), player)
	var drift_before := Vector2(raft.get_horizontal_velocity().x, raft.get_horizontal_velocity().z).length()
	storm.start_rain()
	_check(storm.is_raining(), "then the rain")
	var open_gas := open_anchor.pod.gas
	var roofed_gas := roofed_anchor.pod.gas
	await _ticks(20.0)
	_check(s.health < 100.0 - Tuning.rain_burn * 15.0, "standing in the open, it burns (health %.0f)" % s.health)
	_check(open_anchor.pod.gas < open_gas - 0.01, "unroofed pods lose gas (%.3f)" % (open_gas - open_anchor.pod.gas))
	_check(is_equal_approx(roofed_anchor.pod.gas, roofed_gas), "a pod whose anchor has a roof is shielded")
	_check(catcher.water > 2.0, "rain fills the catcher fast (%.1f L)" % catcher.water)
	var drift_now := Vector2(raft.get_horizontal_velocity().x, raft.get_horizontal_velocity().z).length()
	_check(drift_now > drift_before * 1.3, "the storm wind shoves the raft harder (%.1f -> %.1f m/s)" % [drift_before, drift_now])

	print("Shelter")
	var tile := build.tile_of(raft.global_transform.affine_inverse() * player.global_position)
	_check(build.place("roof", tile, player), "build a roof over where the player stands")
	await _ticks(0.5)
	health = s.health
	await _ticks(10.0)
	_check(s.health >= health - 0.01, "under the roof, the rain can't reach you (%.1f -> %.1f)" % [health, s.health])

	print("Passing out ends the storm")
	player.global_position = raft.global_transform * Vector3(1.5, 0.1, 1.5)
	await _ticks(0.2)
	s.health = 3.0
	await _ticks(4.0)
	_check(not storm.is_raining(), "blacking out in the rain ends the storm")
	_check(s.health >= Tuning.wake_stats - 0.5 and player.ride_body == raft, "you wake on the raft with some health back")
	await _ticks(10.0)
	_check(Wind.storm_strength < 0.1, "the wind settles again")

	print("Pod-leech")
	# Take the roofs down so the hook has a clear throw.
	build.cut(build.tile_of(roofed_anchor.position))
	build.cut(tile)
	for anchor in [open_anchor, roofed_anchor]:
		anchor.pod.gas = 1.0
	var leech := leeches.spawn()
	var latched := false
	for i in 40 * 60:
		await get_tree().physics_frame
		if leech.state == PodLeech.State.LATCHED:
			latched = true
			break
	_check(latched, "a leech swims in and latches onto a pod")
	var pod := leech.target_pod
	var gas := pod.gas
	await _ticks(12.0)
	var drained := (gas - pod.gas) * 5.0
	_check(absf(drained - Tuning.leech_drain_per_min) < 0.02, "it drains about 25%% of a pod per minute (%.3f)" % drained)
	_check(leeches.active() == leech, "only one leech at a time")
	# Knock it off with the hook.
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	player.select_slot(Player.Slot.HOOK)
	player.head.look_at(leech.global_position)
	player.head.rotation.y = 0.0
	player.look_at(Vector3(leech.global_position.x, player.global_position.y, leech.global_position.z))
	player.head.look_at(leech.global_position)
	player.hook.throw((leech.global_position - player.hook.hand_position()).normalized(), player._ride_velocity, 1.0)
	await _ticks(1.0)
	_check(leech.state == PodLeech.State.KNOCKED, "the hook knocks it off the pod")
	await _ticks(2.0)
	_check(leech.global_position.distance_to(pod.ball_position()) > 2.0, "and it backs away")
	# It comes back; tear it off by hand.
	var back := false
	for i in 30 * 60:
		await get_tree().physics_frame
		if leech.state == PodLeech.State.LATCHED:
			back = true
			break
	_check(back, "after a while it comes back for more")
	player.focused_leech = leech
	leech.hit()
	await _ticks(1.0)
	_check(not is_instance_valid(leech) or leech.state == PodLeech.State.DEAD, "a second hit pops it")
	_check(leeches.active() == null, "and it's gone")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("SURVIVAL TEST PASSED")
		get_tree().quit(0)
	else:
		print("SURVIVAL TEST FAILED (%d)" % failures.size())
		get_tree().quit(1)
