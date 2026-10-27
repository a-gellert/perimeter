class_name NPCInteraction
extends Interactable
## Allows the Warden to manage settler shifts and check their status.

@export var npc: SurvivorNPC

func get_prompt_text(_actor: Node) -> String:
	if not npc:
		return "Поговорить"
	var shift_text := "Дневная смена" if npc.shift == GameEnums.Shift.DAY_SHIFT else "Ночной дозор"
	return "Сменить смену [%s] (Бодрость: %d%%)" % [shift_text, int(npc.energy)]

func interact(_actor: Node) -> void:
	if npc:
		npc.toggle_shift()
