class_name BedInteraction
extends Interactable
## Interactive bed inside the cabin triggering the sleep dilemma dialog.

func _init() -> void:
	prompt_message = "Лечь спать (Кровать егеря)"

func interact(actor: Node) -> void:
	GameEvents.request_sleep_dialog.emit(self)
