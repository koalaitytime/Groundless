class_name AnchorCleat
extends Interactable
## The post the anchor rope is tied to while the raft is anchored. E casts off.

var anchor: RaftAnchor


func _ready() -> void:
	hit_size = Vector3(0.5, 0.7, 0.5)
	hit_offset = Vector3(0, 0.35, 0)
	super()
	add_child(make_box(Vector3(0.18, 0.5, 0.18), Color(0.35, 0.27, 0.2), Vector3(0, 0.25, 0)))
	add_child(make_box(Vector3(0.45, 0.08, 0.1), Color(0.35, 0.27, 0.2), Vector3(0, 0.45, 0)))


func get_prompt(_player: Player) -> String:
	return "Anchored\n[E] Cast off (let the raft drift on)"


func interact(_player: Player) -> void:
	if anchor:
		anchor.cast_off()
