class_name Survival
extends Node
## Thirst, hunger and health (GDD "Survival"). Child of the Player, named "Survival".
## Thirst and hunger run down over time; at zero they hurt. Health also comes back slowly
## while you're fed and watered. Falling off the raft or running out of health makes you
## black out and wake on the raft, having lost some of what you carried.

signal passed_out(reason: String)
signal woke_up(reason: String)

var thirst := 100.0
var hunger := 100.0
var health := 100.0
## True during the blackout fade.
var out_cold := false
## Seconds since the last damage: health only comes back after a few quiet seconds.
var _since_hurt := 99.0

@onready var player: Player = get_parent()


func _physics_process(delta: float) -> void:
	if out_cold:
		return
	thirst = maxf(thirst - 100.0 / (Tuning.thirst_minutes * 60.0) * delta, 0.0)
	hunger = maxf(hunger - 100.0 / (Tuning.hunger_minutes * 60.0) * delta, 0.0)
	_since_hurt += delta
	if thirst <= 0.0 or hunger <= 0.0:
		hurt(Tuning.starving_damage * delta, "starving")
	elif _since_hurt > 3.0 and thirst > Tuning.health_regen_above and hunger > Tuning.health_regen_above:
		health = minf(health + Tuning.health_regen * delta, 100.0)


func drink(amount: float) -> void:
	thirst = minf(thirst + amount, 100.0)


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, 100.0)


## Eat one shelf fungus from the inventory, if there is one. Returns true if eaten.
func eat_fungus() -> bool:
	if player.items.get("fungus", 0) <= 0 or hunger >= 99.0:
		return false
	player.items.fungus -= 1
	eat(Tuning.fungus_food)
	return true


func hurt(amount: float, reason: String) -> void:
	if out_cold:
		return
	health = maxf(health - amount, 0.0)
	_since_hurt = 0.0
	if health <= 0.0:
		black_out(reason)


## Fade out, lose some carried materials, wake on the raft. Used for falling off and for
## running out of health.
func black_out(reason: String) -> void:
	if out_cold:
		return
	out_cold = true
	passed_out.emit(reason)
	for k in ["wood", "rope", "cloth", "fiber", "pod", "fungus"]:
		var n: int = player.items.get(k, 0)
		player.items[k] = n - int(floor(n * Tuning.wake_item_loss))
	var timer := get_tree().create_timer(1.6, true, true)
	timer.timeout.connect(_wake.bind(reason))


func _wake(reason: String) -> void:
	player.respawn()
	if reason != "fell":
		health = maxf(health, Tuning.wake_stats)
		thirst = maxf(thirst, Tuning.wake_stats)
		hunger = maxf(hunger, Tuning.wake_stats)
	out_cold = false
	woke_up.emit(reason)
