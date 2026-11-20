class_name StoryItem
extends Interactable
## A note or a found object. E shows its text on screen. The compass also ends the slice.

signal used(item: StoryItem)

@export var label := "note"
@export_multiline var text := ""
## True for the item that ends the vertical slice.
@export var ends_slice := false

var read := false


func get_prompt(_player: Player) -> String:
	return "[E] %s %s" % ["Pick up" if ends_slice else "Read", label]


func interact(_player: Player) -> void:
	read = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(text, 14.0 if ends_slice else 9.0)
	used.emit(self)
