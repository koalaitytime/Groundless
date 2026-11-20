extends Node3D
## Milestone 1 scene: the raft drifting on the wind with the player on it.
## F3 toggles the debug readout.

@onready var raft: Raft = $Raft
@onready var player: Player = $Player
@onready var murk: Node3D = $Murk
@onready var debug_label: Label = $Debug/Label


func _process(_delta: float) -> void:
	# The murk layer is a big plane that just follows the raft on X/Z.
	murk.global_position.x = raft.global_position.x
	murk.global_position.z = raft.global_position.z

	if debug_label.visible:
		var wind: Vector3 = Wind.velocity_at(raft.global_position.y)
		var absolute: Vector3 = WorldOrigin.to_absolute(raft.global_position)
		debug_label.text = "FPS %d\nRaft height %.1f m\nWind %.2f m/s heading %d°\nDrift %.2f m/s\nRaft absolute X %.0f Z %.0f\nRiding %s  On floor %s" % [
			Engine.get_frames_per_second(),
			raft.global_position.y,
			wind.length(),
			int(fposmod(rad_to_deg(atan2(wind.x, -wind.z)), 360.0)),
			Vector2(raft.velocity.x, raft.velocity.z).length(),
			absolute.x,
			absolute.z,
			"yes" if player.ride_body != null else "no",
			"yes" if player.is_on_floor() else "no",
		]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug_label.visible = not debug_label.visible
