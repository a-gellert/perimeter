class_name LogItem
extends StaticBody3D

func get_interaction_info(player: PlayerController) -> Dictionary:
	if player.can_pickup_log():
		return { "prompt": "Взять бревно на плечо", "type": "PICKUP" }
	return { "prompt": "Плечо занято (макс. 3)", "type": "BLOCKED" }

func interact(player: PlayerController) -> void:
	if player.add_log():
		queue_free() # Бревно перекочевало на плечо персонажа
