extends Node3D
## Grey-box game scene: the raft drifting on the wind with the player on it.
## F3 toggles the debug readout.

## Fog density above the murk and deep inside it.
const FOG_CLEAR := 0.004
const FOG_MURK := 0.06
const FOG_COLOUR_CLEAR := Color(0.58, 0.44, 0.56)
const FOG_COLOUR_MURK := Color(0.08, 0.1, 0.22)

@onready var raft: Raft = $Raft
@onready var lift: RaftLift = $Raft/Lift
@onready var player: Player = $Player
@onready var murk: Node3D = $Murk
@onready var environment: Environment = $WorldEnvironment.environment
@onready var debug_label: Label = $Debug/Label
@onready var prompt_label: Label = $Hud/Prompt
@onready var carried_label: Label = $Hud/Carried
@onready var hotbar_label: Label = $Hud/Hotbar
@onready var build_menu: BuildMenu = $Hud/BuildMenu


@onready var message_label: Label = $Hud/Message
@onready var stats_label: Label = $Hud/Stats
@onready var vignette: ColorRect = $Hud/Vignette
@onready var fade: ColorRect = $Hud/Fade
@onready var storm: Storm = $Storm
@onready var sun: DirectionalLight3D = $Sun

## Fog colour and light while a storm is on.
const FOG_COLOUR_STORM := Color(0.42, 0.46, 0.32)

var _message_time := 0.0
var _sun_energy := 1.0


func _ready() -> void:
	add_to_group("hud")
	build_menu.player = player
	_sun_energy = sun.light_energy
	storm.warning_started.connect(func(): show_message("The air turns sharp and sour, and the sky yellows.\nCaustic rain is coming. Get a roof over your head, and over your pods.", 10.0))
	storm.rain_started.connect(func(): show_message("The rain burns.", 4.0))
	storm.cleared.connect(func(): show_message("The storm passes.", 4.0))
	player.survival.passed_out.connect(_on_passed_out)
	player.survival.woke_up.connect(_on_woke_up)


func _on_passed_out(reason: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.2)


func _on_woke_up(reason: String) -> void:
	var text := "You come to on the raft, cold, your pack lighter." if reason == "fell" else "You wake on the raft, aching, your pack lighter."
	show_message(text, 5.0)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.5)


## Show a message (a note, the ending) in the middle of the screen for a while.
func show_message(text: String, seconds := 8.0) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_time = seconds


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)

	# The murk is a big plane that follows the raft on X/Z.
	murk.global_position.x = raft.global_position.x
	murk.global_position.z = raft.global_position.z

	# Fog thickens as the camera sinks toward and into the murk.
	var depth := clampf((Tuning.murk_top + 15.0 - player.camera.global_position.y) / 30.0, 0.0, 1.0)
	environment.fog_density = lerpf(FOG_CLEAR, FOG_MURK, depth * depth) + storm.strength * 0.006
	environment.fog_light_color = FOG_COLOUR_CLEAR.lerp(FOG_COLOUR_STORM, storm.strength * 0.7).lerp(FOG_COLOUR_MURK, depth)
	sun.light_energy = _sun_energy * (1.0 - storm.strength * 0.55)

	# Survival, shown minimally: thirst and hunger as short bars; health only as a red edge.
	var s := player.survival
	stats_label.text = "Thirst  %s\nHunger  %s" % [_bar(s.thirst), _bar(s.hunger)]
	stats_label.modulate = Color(1, 0.6, 0.5) if s.thirst < 20.0 or s.hunger < 20.0 else Color(1, 1, 1, 0.8)
	vignette.color.a = clampf((100.0 - s.health) / 100.0, 0.0, 1.0) * 0.45
	prompt_label.text = _prompt_text()
	carried_label.text = _inventory_text()
	hotbar_label.text = _hotbar_text()

	if debug_label.visible:
		var wind: Vector3 = Wind.velocity_at(raft.global_position.y)
		var absolute: Vector3 = WorldOrigin.to_absolute(raft.global_position)
		var pod_lines := ""
		for pod in lift.pods():
			pod_lines += "  pod %d kg  gas %d%%%s\n" % [pod.capacity, roundi(pod.gas * 100.0), "  wilting" if pod.damaged else ""]
		debug_label.text = "FPS %d\nHeight %.1f m  resting %.1f m  vy %.2f m/s%s\nLift %.1f kg  weight %.1f kg  surplus %.1f kg\n%sWind %.2f m/s heading %d°  drift %.2f m/s\nRaft absolute X %.0f Z %.0f\nRiding %s  On floor %s%s%s" % [
			Engine.get_frames_per_second(),
			raft.get_base_height(),
			lift.get_resting_height(),
			raft.velocity.y,
			"  IN MURK" if lift.is_in_murk() else "",
			lift.get_lift(),
			lift.get_weight(),
			lift.get_lift() - lift.get_weight(),
			pod_lines,
			wind.length(),
			int(fposmod(rad_to_deg(atan2(wind.x, -wind.z)), 360.0)),
			Vector2(raft.velocity.x, raft.velocity.z).length(),
			absolute.x,
			absolute.z,
			"yes" if player.ride_body != null else "no",
			"yes" if player.is_on_floor() else "no",
			"  ANCHORED" if raft.get_node("Anchor").is_anchored() else "",
			_island_debug(),
		]


func _bar(value: float) -> String:
	var filled := roundi(value / 10.0)
	return "|".repeat(filled) + ".".repeat(10 - filled)


func _island_debug() -> String:
	var islands: IslandSpawner = $Islands
	if islands.current == null:
		return "\nNext island soon (%s)%s" % [islands.next_kind(), _storm_debug()]
	var to := islands.current.global_position - raft.global_position
	return _storm_debug() + "\nIsland %s: %.0f m away, lip %+.1f m%s" % [islands.current.kind, Vector2(to.x, to.z).length(), to.y, "  visited" if islands.current.visited else ""]


func _storm_debug() -> String:
	var phase: String = ["clear", "WARNING", "RAIN"][storm.phase]
	return "\nStorm: %s, %.0f s   Health %.0f" % [phase, storm.timer, player.survival.health]


func _prompt_text() -> String:
	if player.selected_slot == Player.Slot.HAMMER:
		var recipe: Dictionary = Tuning.recipes[player.build_choice]
		var kg := player.builder.weight_of(player.build_choice)
		var cost: Array[String] = []
		for k in recipe.cost:
			cost.append("%d %s" % [recipe.cost[k], k])
		var text := "%s  (%s)" % [recipe.name, ", ".join(cost)]
		if kg > 0.0:
			text += "\n+%d kg: resting height -%d m" % [kg, roundi(kg * Tuning.metres_per_kg)]
		if player.build_tile == null:
			text += "\nAim at the deck or just past its edge"
		elif player.build_problem != "":
			text += "\n" + player.build_problem
		else:
			text += "\n[Click] Place"
		if player.build_tile != null:
			var info: Dictionary = player.builder.describe_remove(player.build_tile)
			if info.what != "":
				if info.problem != "":
					text += "\n%s here: %s" % [info.name, info.problem]
				else:
					text += "\n[Right-click] Remove %s (full refund)   [X] Cut loose" % info.name.to_lower()
		text += "\n[Tab] Build menu"
		return text
	if player.selected_slot == Player.Slot.PADDLE:
		if player.is_resting():
			return "Too tired to paddle..."
		return "Hold [Click] to paddle the way you face  (%d%%)" % roundi(100.0 * player.stamina / Tuning.paddle_stamina)
	if player.focused_leech:
		return "[E] Tear the pod-leech off"
	if player.focused_flotsam:
		return "[E] Grab " + player.focused_flotsam.describe()
	if player.selected_slot == Player.Slot.HOOK and player.hook_charge >= 0.0:
		var bars := roundi(player.hook_charge * 10.0)
		return "Throw  " + "|".repeat(bars) + ".".repeat(10 - bars)
	return player.focused.get_prompt(player) if player.focused else ""


func _inventory_text() -> String:
	var parts: Array[String] = []
	for k in ["wood", "rope", "cloth", "fiber", "pod", "patch", "fungus"]:
		var n: int = player.items.get(k, 0)
		if n > 0:
			parts.append("%s %d" % ["drift-pod" if k == "pod" else k, n])
	if player.items.get("fungus", 0) > 0:
		parts.append("[F] eat")
	return "   ".join(parts)


func _hotbar_text() -> String:
	var parts: Array[String] = []
	for slot in [1, 2, 3]:
		if not player.slot_available(slot):
			continue
		var name: String = Player.SLOT_NAMES[slot]
		if slot == Player.Slot.HAMMER:
			name += ": " + Tuning.recipes[player.build_choice].name
		parts.append(("[%d %s]" if slot == player.selected_slot else " %d %s ") % [slot, name])
	return "   ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_menu"):
		build_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug_label.visible = not debug_label.visible
