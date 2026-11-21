extends Node
## Milestone 3 test: building.
## Run headless from the groundless/ folder:
##   godot --headless --fixed-fps 60 res://tests/build_test.tscn
## Checks grid placement rules, costs, weight and resting height, walking onto new planks,
## fixtures, roofs, cutting loose (including unconnected planks), crafting, patching,
## the sky-paddle and catching material flotsam. Exit code 0 = pass.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var raft: Raft
var lift: RaftLift
var build: RaftBuilder
var player: Player
var spawner: FlotsamSpawner
var failures: Array[String] = []


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	raft = main.get_node("Raft")
	lift = raft.get_node("Lift")
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


func _run() -> void:
	await _ticks(0.5)
	# Freeze leaks so height changes come only from building.
	Tuning.leak_healthy_per_min = 0.0
	Tuning.leak_damaged_per_min = 0.0
	player.items = {"wood": 30, "rope": 10, "cloth": 10, "fiber": 10, "pod": 2, "patch": 0, "sky_paddle": 0}

	print("Plank placement rules")
	_check(build.placement_problem("plank", Vector2i(0, 0), player) != "", "can't place a plank on the slab")
	_check(build.placement_problem("plank", Vector2i(3, 0), player) != "", "can't place a plank that doesn't touch the raft")
	_check(build.placement_problem("plank", Vector2i(2, 0), player) == "", "can place a plank next to the slab")
	var weight := lift.get_weight()
	var resting := lift.get_resting_height()
	var wood: int = player.items.wood
	_check(build.place("plank", Vector2i(2, 0), player), "place a plank at (2, 0)")
	_check(is_equal_approx(lift.get_weight() - weight, Tuning.plank_weight), "plank adds 15 kg")
	_check(absf(resting - lift.get_resting_height() - Tuning.plank_weight * Tuning.metres_per_kg) < 0.1, "plank lowers resting height by plank_weight x metres_per_kg")
	_check(player.items.wood == wood - 2 and player.items.rope == 9, "plank costs 2 wood and 1 rope")
	_check(build.placement_problem("plank", Vector2i(3, 0), player) == "", "can extend from a plank")
	build.place("plank", Vector2i(3, 0), player)
	build.place("plank", Vector2i(4, 0), player)

	print("Not enough materials")
	var saved: Dictionary = player.items.duplicate()
	player.items.rope = 0
	_check(build.placement_problem("plank", Vector2i(0, 2), player) == "Not enough materials", "no rope, no plank")
	_check(not build.place("plank", Vector2i(0, 2), player), "place refuses without materials")
	player.items = saved

	print("Walking onto new planks")
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _ticks(0.5)
	# Face +X in raft space, then walk.
	var target := raft.global_transform * Vector3(6.0, 0, 0)
	player.look_at(Vector3(target.x, player.global_position.y, target.z))
	player.input_override = Vector2(0, -1)
	await _ticks(1.2)
	player.input_override = Vector2.ZERO
	await _ticks(0.5)
	var local := raft.global_transform.affine_inverse() * player.global_position
	_check(local.x > 3.0 and absf(local.y) < 0.2, "player walked out onto the planks (local x %.2f, y %.2f)" % [local.x, local.y])
	_check(player.is_on_floor() and player.ride_body == raft, "player stands on and rides the new floor")

	print("Fixtures and roof")
	weight = lift.get_weight()
	_check(build.place("anchor", Vector2i(3, 0), player), "place a pod anchor on a plank")
	_check(build.placement_problem("rain_catcher", Vector2i(3, 0), player) == "Tile is taken", "one fixture per tile")
	var anchor: AnchorPoint = build.tiles[Vector2i(3, 0)].fixture
	anchor.interact(player)
	_check(anchor.pod != null, "tether a drift-pod to the new anchor")
	_check(build.place("roof", Vector2i(3, 0), player), "roof over the same tile")
	_check(build.place("rain_catcher", Vector2i(2, 0), player), "rain catcher on a plank")
	_check(build.place("ballast_sack", Vector2i(4, 0), player), "ballast sack on a plank")
	var expected := Tuning.tether_weight + Tuning.roof_weight + Tuning.rain_catcher_weight + Tuning.sandbag_weight
	_check(is_equal_approx(lift.get_weight() - weight, expected), "fixtures and roof add their weight (%.1f kg)" % (lift.get_weight() - weight))
	_check(build.placement_problem("anchor", Vector2i(0, 0), player) == "", "free slab tiles take fixtures")
	_check(build.placement_problem("anchor", Vector2i(1, 1), player) == "Tile is taken", "slab tiles with pre-built pieces are taken")

	print("Cutting loose")
	player.global_position = raft.global_transform * Vector3(0, 0.1, 0)
	await _ticks(0.3)
	var lift_before := lift.get_lift()
	weight = lift.get_weight()
	_check(build.cut(Vector2i(3, 0)), "cut the anchor at (3, 0)")
	_check(lift.get_lift() < lift_before - 30.0, "its pod goes with it")
	_check(absf(weight - lift.get_weight() - Tuning.tether_weight) < 0.01, "and its weight")
	_check(build.describe_cut(Vector2i(3, 0)) == "roof", "next cut there is the roof")
	weight = lift.get_weight()
	build.cut(Vector2i(2, 0))  # rain catcher
	build.cut(Vector2i(2, 0))  # plank: (3,0) and (4,0) are now unconnected and fall too
	var dropped := Tuning.rain_catcher_weight + 3.0 * Tuning.plank_weight + Tuning.roof_weight + Tuning.sandbag_weight
	_check(absf(weight - lift.get_weight() - dropped) < 0.01, "cutting the first plank drops the planks beyond it, with their roof and sack (%.1f kg)" % (weight - lift.get_weight()))
	_check(not build.has_floor(Vector2i(3, 0)) and not build.has_floor(Vector2i(4, 0)), "unconnected planks are gone")
	_check(not build.cut(Vector2i(0, 0)), "the slab can't be cut")
	_check(not build.cut(Vector2i(1, 1)), "pre-built slab pieces can't be cut")
	var base_weight := 200.0 + 2.0 + 10.0 + 3.0
	_check(is_equal_approx(lift.get_weight(), base_weight), "weight is back to the starting 215 kg")

	print("Removing mistakes")
	build.place("plank", Vector2i(0, 2), player)
	build.place("plank", Vector2i(0, 3), player)
	build.place("anchor", Vector2i(0, 2), player)
	player.held_pods = 1
	build.tiles[Vector2i(0, 2)].fixture.interact(player)
	var before_items: Dictionary = player.items.duplicate()
	_check(build.describe_remove(Vector2i(0, 2)).what == "fixture", "remove takes the anchor first")
	_check(build.remove(Vector2i(0, 2), player), "remove the anchor")
	_check(player.items.wood == before_items.wood + 1 and player.items.rope == before_items.rope + 1, "anchor cost refunded in full")
	_check(player.held_pods == 1, "its pod comes back as a drift-pod")
	_check(build.describe_remove(Vector2i(0, 2)).problem != "", "a plank with planks beyond it can't be removed")
	_check(not build.remove(Vector2i(0, 2), player), "remove refuses it")
	_check(build.remove(Vector2i(0, 3), player) and build.remove(Vector2i(0, 2), player), "remove the outer plank, then the inner one")
	_check(player.items.wood == before_items.wood + 1 + 4 and player.items.rope == before_items.rope + 1 + 2, "plank costs refunded in full")
	_check(is_equal_approx(lift.get_weight(), base_weight), "weight is back to 215 kg")
	_check(not build.remove(Vector2i(1, 1), player), "pre-built slab pieces can't be removed")
	player.held_pods = 1

	print("Crafting and patching")
	_check(player.craft("patch"), "craft a patch (2 fiber, 1 drift-pod)")
	_check(player.items.patch == 1 and player.items.pod == 0, "patch used the drift-pod")
	var wilting: AnchorPoint = raft.get_node("AnchorFrontLeft")
	_check(wilting.pod.damaged, "front-left pod starts wilting")
	wilting.interact(player)
	_check(not wilting.pod.damaged and player.items.patch == 0, "patching stops the fast leak")
	_check(not player.craft("plank"), "planks aren't crafted into the inventory")
	_check(not player.slot_available(Player.Slot.PADDLE), "no paddle slot before crafting one")
	_check(player.craft("sky_paddle"), "craft a sky-paddle")
	player.select_slot(Player.Slot.PADDLE)
	_check(player.selected_slot == Player.Slot.PADDLE, "paddle slot now selectable")

	print("Sky-paddle")
	await _ticks(1.0)
	var push := -player.camera.global_basis.z
	push.y = 0.0
	push = push.normalized()
	player.paddle_override = true
	await _ticks(4.0)
	var paddle_velocity := raft.get_horizontal_velocity() - Vector3(raft.velocity.x, 0, raft.velocity.z)
	_check(absf(paddle_velocity.length() - Tuning.paddle_speed) < 0.05, "paddling pushes the raft at 0.8 m/s (%.2f m/s)" % paddle_velocity.length())
	_check(paddle_velocity.normalized().dot(push) > 0.95, "the way the player faces")
	await _ticks(4.5)
	_check(player.is_resting() and not player.paddling, "after 8 s the player is too tired to paddle")
	player.paddle_override = false
	await _ticks(4.0)
	_check(not player.is_resting() and player.stamina > 7.9, "after resting 4 s stamina is back")

	print("Catching materials")
	player.select_slot(Player.Slot.HOOK)
	player.head.rotation.x = 0.0
	var rope_before: int = player.items.rope
	var item := spawner.spawn("rope")
	item.global_position = player.camera.global_position - player.camera.global_basis.z * 7.0
	await get_tree().physics_frame
	var aim := (item.global_position - player.camera.global_position).normalized()
	player.hook.throw(aim + Vector3.UP * 0.02, player._ride_velocity)
	await _ticks(4.0)
	_check(player.items.rope == rope_before + 1, "hooking a rope bundle adds 1 rope")
	var kinds := {}
	for i in 200:
		kinds[spawner._pick_material()] = true
	_check(kinds.size() == Tuning.flotsam_kind_weights.size(), "every material kind drifts in (%s)" % ", ".join(kinds.keys()))

	_report()


func _report() -> void:
	if failures.is_empty():
		print("BUILD TEST PASSED")
		get_tree().quit(0)
	else:
		print("BUILD TEST FAILED (%d)" % failures.size())
		get_tree().quit(1)
