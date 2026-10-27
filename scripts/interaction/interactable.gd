class_name Interactable
extends Node
## Base component or node for any object the player can interact with.

@export var prompt_message: String = "Взаимодействовать"
@export var is_enabled: bool = true

func can_interact(actor: Node) -> bool:
	return is_enabled

func interact(actor: Node) -> void:
	# Virtual method to be overridden by specific interactable scripts
	pass

func get_prompt_text(actor: Node) -> String:
	return prompt_message

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not can_interact(player):
		return { "prompt": "", "type": "BLOCKED" }
	return { "prompt": get_prompt_text(player), "type": "INTERACT" }
