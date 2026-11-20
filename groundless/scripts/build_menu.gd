class_name BuildMenu
extends PanelContainer
## Build menu, opened with Tab. Lists every recipe with its cost and weight.
## Picking a piece selects it for the hammer; picking an item crafts it at once.

var player: Player

var _list: VBoxContainer
var _buttons := {}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(460, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Build  (Tab to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	for id in Tuning.recipes:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_pick.bind(id))
		_list.add_child(button)
		_buttons[id] = button


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	for id in _buttons:
		var recipe: Dictionary = Tuning.recipes[id]
		var parts: Array[String] = []
		for k in recipe.cost:
			parts.append("%d %s" % [recipe.cost[k], k])
		var weight_text := ""
		if recipe.kind == "item":
			weight_text = "craft"
		elif player.builder:
			var kg := player.builder.weight_of(id)
			weight_text = "%d kg, -%d m" % [kg, roundi(kg * Tuning.metres_per_kg)] if kg > 0.0 else "weightless"
		var marker := "> " if id == player.build_choice and recipe.kind != "item" else "   "
		var owned := ""
		if recipe.kind == "item":
			owned = "  (have %d)" % player.items.get(id, 0)
		_buttons[id].text = "%s%s:  %s   [%s]%s" % [marker, recipe.name, ", ".join(parts), weight_text, owned]
		_buttons[id].disabled = not player.has_items(recipe.cost)


func _on_pick(id: String) -> void:
	if Tuning.recipes[id].kind == "item":
		player.craft(id)
		if id == "sky_paddle":
			player.select_slot(Player.Slot.PADDLE)
		refresh()
		return
	player.build_choice = id
	player.select_slot(Player.Slot.HAMMER)
	toggle()
