class_name SpringWater
extends Interactable
## A spring's pond on an island. Fresh water, as much as you like: E drinks.


func get_prompt(player: Player) -> String:
	if player.survival.thirst >= 99.0:
		return "Fresh spring water"
	return "Fresh spring water\n[E] Drink"


func interact(player: Player) -> void:
	player.survival.drink(Tuning.spring_drink_amount)
