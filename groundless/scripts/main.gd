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


func _ready() -> void:
	build_menu.player = player


func _process(_delta: float) -> void:
	# The murk is a big plane that follows the raft on X/Z.
	murk.global_position.x = raft.global_position.x
	murk.global_position.z = raft.global_position.z

	# Fog thickens as the camera sinks toward and into the murk.
	var depth := clampf((Tuning.murk_top + 15.0 - player.camera.global_position.y) / 30.0, 0.0, 1.0)
	environment.fog_density = lerpf(FOG_CLEAR, FOG_MURK, depth * depth)
	environment.fog_light_color = FOG_COLOUR_CLEAR.lerp(FOG_COLOUR_MURK, depth)

	prompt_label.text = _prompt_text()
	carried_label.text = _inventory_text()
	hotbar_label.text = _hotbar_text()

	if debug_label.visible:
		var wind: Vector3 = Wind.velocity_at(raft.global_position.y)
		var absolute: Vector3 = WorldOrigin.to_absolute(raft.global_position)
		var pod_lines := ""
		for pod in lift.pods():
			pod_lines += "  pod %d kg  gas %d%%%s\n" % [pod.capacity, roundi(pod.gas * 100.0), "  wilting" if pod.damaged else ""]
		debug_label.text = "FPS %d\nHeight %.1f m  resting %.1f m  vy %.2f m/s%s\nLift %.1f kg  weight %.1f kg  surplus %.1f kg\n%sWind %.2f m/s heading %d°  drift %.2f m/s\nRaft absolute X %.0f Z %.0f\nRiding %s  On floor %s" % [
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
		]


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
			text += "\n[Click] Place   [X] Cut loose   [Tab] Build menu"
		return text
	if player.selected_slot == Player.Slot.PADDLE:
		if player.is_resting():
			return "Too tired to paddle..."
		return "Hold [Click] to paddle the way you face  (%d%%)" % roundi(100.0 * player.stamina / Tuning.paddle_stamina)
	return player.focused.get_prompt(player) if player.focused else ""


func _inventory_text() -> String:
	var parts: Array[String] = []
	for k in ["wood", "rope", "cloth", "fiber", "pod", "patch"]:
		var n: int = player.items.get(k, 0)
		if n > 0:
			parts.append("%s %d" % ["drift-pod" if k == "pod" else k, n])
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
