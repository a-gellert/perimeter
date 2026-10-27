class_name GhostWallBlueprint
extends Interactable
## Holographic blueprint of a wooden palisade wall section.
## Accepts logs one by one from the player's shoulder until completed.

@export var required_logs: int = 4
@export var ghost_mesh: Node3D
@export var completed_mesh: Node3D
@export var solid_collision: CollisionShape3D
@export var interaction_area: Area3D

var deposited_logs: int = 0

func _ready() -> void:
	_update_state()

func get_prompt_text(_actor: Node) -> String:
	return "Вставить бревно в каркас (%d/%d)" % [deposited_logs, required_logs]

func can_interact(actor: Node) -> bool:
	if deposited_logs >= required_logs:
		return false
	if actor is PlayerController:
		return (actor as PlayerController).carried_logs > 0
	var carrier := _get_carrier(actor)
	return carrier != null and carrier.has_logs()

func get_interaction_info(player: PlayerController) -> Dictionary:
	if deposited_logs >= required_logs:
		return { "prompt": "", "type": "" }
	if player.carried_logs > 0:
		return { "prompt": "Встроить бревно (%d/%d)" % [deposited_logs, required_logs], "type": "BUILD" }
	return { "prompt": "Нужны бревна (%d/%d)" % [deposited_logs, required_logs], "type": "NEED_LOGS" }

func interact(actor: Node) -> void:
	if actor is PlayerController:
		var pc := actor as PlayerController
		if pc.carried_logs > 0 and deposited_logs < required_logs:
			if pc.remove_log():
				deposited_logs += 1
				_update_state()
				if deposited_logs >= required_logs:
					_complete_building()
		return
	var carrier := _get_carrier(actor)
	if carrier and carrier.remove_log():
		deposited_logs += 1
		_update_state()
		if deposited_logs >= required_logs:
			_complete_building()

func _complete_building() -> void:
	is_enabled = false
	prompt_message = "Частокол готов"
	if interaction_area:
		interaction_area.monitoring = false
	GameEvents.structure_completed.emit(get_parent())

func _update_state() -> void:
	var is_done := (deposited_logs >= required_logs)
	if ghost_mesh:
		ghost_mesh.visible = not is_done
	if completed_mesh:
		completed_mesh.visible = is_done
	if solid_collision:
		solid_collision.disabled = not is_done

func _get_carrier(actor: Node) -> Object:
	if not actor:
		return null
	if actor is PlayerController:
		return (actor as PlayerController).carrier
	for child in actor.get_children():
		if child is PlayerCarrier:
			return child
	return null
