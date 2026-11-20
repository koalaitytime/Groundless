class_name ResourceNode
extends Interactable
## Something on an island the player can gather from with E a few times:
## a pod vine, a bindwood tree, a hangroot clump, wreck salvage.

## What one use gives, e.g. {"wood": 2}.
@export var gives := {}
@export var uses := 3
## Shown in the prompt, e.g. "bindwood".
@export var label := "resource"


func get_prompt(_player: Player) -> String:
	if uses <= 0:
		return "%s (picked clean)" % label.capitalize()
	var parts: Array[String] = []
	for k in gives:
		parts.append("%d %s" % [gives[k], "drift-pod" if k == "pod" else k.replace("_", "-")])
	return "[E] Gather %s: %s  (%d left)" % [label, ", ".join(parts), uses]


func interact(player: Player) -> void:
	if uses <= 0:
		return
	uses -= 1
	for k in gives:
		player.add_item(k, gives[k])
	if uses <= 0:
		# Show it's spent: shrink whatever visuals belong to this node.
		for child in get_children():
			if child is MeshInstance3D:
				child.scale *= 0.6
