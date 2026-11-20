extends Node
## Milestone 2 test: hook, pods and lift.
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/lift_test.tscn
## Checks the opening sinks, each control moves the resting height the right way by the
## right amount, the raft settles at its resting height, the murk slows and drains, and the
## hook catches a drift-pod. Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var lift: RaftLift
var player: Player
var spawner: FlotsamSpawner
var failures: Array[String] = []


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	lift = raft.get_node("Lift")
	player = main.get_node("Player")
	spawner = main.get_node("Flotsam")
	spawner.set_physics_process(false)  # Spawn only when the test asks.
	_run()


func _ticks(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures.append(message)


func _run() -> void:
	await _ticks(0.5)

	print("Opening")
	var weight := lift.get_weight()
	var lift_kg := lift.get_lift()
	print("  weight %.1f kg, lift %.1f kg, resting %.1f m, raft %.1f m" % [weight, lift_kg, lift.get_resting_height(), raft.get_base_height()])
	_check(is_equal_approx(weight, 200.0 + 2.0 + 10.0 + 3.0), "weight is slab + vent cord + sandbag + 3 tethers (215 kg)")
	_check(lift_kg > weight, "starts with spare lift")
	_check(absf(lift.get_resting_height() - raft.get_base_height()) < 3.0, "raft starts near its resting height")
	var r0 := lift.get_resting_height()
	await _ticks(20.0)
	_check(lift.get_resting_height() < r0 - 3.0, "wilting pod lowers the resting height over 20 s (%.1f -> %.1f m)" % [r0, lift.get_resting_height()])
	_check(raft.get_base_height() < 37.0, "raft is sinking (%.1f m)" % raft.get_base_height())

	print("Vent cord")
	var before := lift.get_resting_height()
	var vent: VentCord = raft.get_node("VentCord")
	vent.interact(player)
	var drop := before - lift.get_resting_height()
	_check(absf(drop - Tuning.vent_pull_kg * Tuning.metres_per_kg) < 0.5, "one pull lowers resting height by about 6 m (%.2f m)" % drop)

	print("Sandbag")
	before = lift.get_resting_height()
	var bag: Sandbag = raft.get_node("Sandbag")
	_check(bag.get_prompt(player) != "", "sandbag offers a prompt")
	bag.interact(player)
	var gain := lift.get_resting_height() - before
	_check(absf(gain - Tuning.sandbag_weight * Tuning.metres_per_kg) < 0.5, "dropping it raises resting height by about 15 m (%.2f m)" % gain)
	_check(bag.get_prompt(player) == "", "a dropped sandbag can't be used again")

	print("Tether and refill")
	var empty: AnchorPoint = raft.get_node("AnchorFrontRight")
	var wilting: AnchorPoint = raft.get_node("AnchorFrontLeft")
	before = lift.get_resting_height()
	empty.interact(player)
	_check(empty.pod == null, "can't tether without a drift-pod")
	player.held_pods = 2
	empty.interact(player)
	gain = lift.get_resting_height() - before
	var expected := (Tuning.pod_capacity_small - Tuning.tether_weight) * Tuning.metres_per_kg
	_check(empty.pod != null and player.held_pods == 1, "tethering uses a drift-pod")
	_check(absf(gain - expected) < 0.5, "a new small pod raises resting height by about %.0f m (%.2f m)" % [expected, gain])
	var gas := wilting.pod.gas
	wilting.interact(player)
	_check(player.held_pods == 0 and absf(wilting.pod.gas - minf(gas + Tuning.refill_gas, 1.0)) < 0.01, "refill adds 35%% gas (%.2f -> %.2f)" % [gas, wilting.pod.gas])

	print("Settling")
	for pod in lift.pods():
		pod.damaged = false
	var saved_leak := Tuning.leak_healthy_per_min
	Tuning.leak_healthy_per_min = 0.0
	await _ticks(60.0)
	var off := raft.get_base_height() - lift.get_resting_height()
	_check(absf(off) < 1.0, "raft settles at its resting height (%.2f m off)" % off)
	Tuning.leak_healthy_per_min = saved_leak

	print("Murk")
	for pod in lift.pods():
		pod.gas = 0.3
	await _ticks(60.0)
	_check(lift.is_in_murk(), "with little gas the raft sinks into the murk (%.1f m)" % raft.get_base_height())
	var drift := Vector2(raft.velocity.x, raft.velocity.z).length()
	_check(drift < Tuning.murk_drift_speed * 1.5, "drift slows in the murk (%.2f m/s)" % drift)
	_check(raft.get_base_height() >= Tuning.murk_floor - 0.5, "never sinks below the murk floor")
	var gas_before := lift.pods()[0].gas
	await _ticks(10.0)
	var lost_per_min := (gas_before - lift.pods()[0].gas) * 6.0
	var expected_loss := Tuning.leak_healthy_per_min + Tuning.leak_murk_extra_per_min
	_check(absf(lost_per_min - expected_loss) < 0.005, "murk adds extra leak (%.3f/min, expected %.3f)" % [lost_per_min, expected_loss])

	print("Hook")
	for pod in lift.pods():
		pod.gas = 1.0
	await _ticks(1.0)
	player.head.rotation.x = 0.0
	var aim := -player.camera.global_basis.z
	var pod := Flotsam.new()
	spawner.add_child(pod)
	pod.global_position = player.camera.global_position + aim * 8.0
	await get_tree().physics_frame
	aim = (pod.global_position - player.camera.global_position).normalized()
	player.hook.throw(aim + Vector3.UP * 0.02, player._ride_velocity)
	var caught := false
	for i in 300:
		await get_tree().physics_frame
		if player.held_pods == 1:
			caught = true
			break
	_check(caught, "hook catches a drift-pod 8 m away and reels it in")
	_check(player.hook.state == Hook.State.IDLE, "hook is back in hand")
	player.hook.throw(Vector3(0, 1, 0))
	await _ticks(3.0)
	_check(player.hook.state == Hook.State.IDLE and player.held_pods == 1, "a miss reels back empty")

	print("Drift-pod spawning")
	var spawned := spawner.spawn()
	var start_distance := spawned.global_position.distance_to(raft.global_position)
	var closest := start_distance
	for i in roundi(Tuning.drift_pod_arrival_time * 1.5 * 60.0):
		await get_tree().physics_frame
		if is_instance_valid(spawned):
			closest = minf(closest, spawned.global_position.distance_to(raft.global_position))
	print("  spawned %.1f m away, closest pass %.1f m" % [start_distance, closest])
	_check(closest < Tuning.hook_range, "a spawned drift-pod passes within hook range")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("LIFT TEST PASSED")
		get_tree().quit(0)
	else:
		print("LIFT TEST FAILED (%d)" % failures.size())
		get_tree().quit(1)
