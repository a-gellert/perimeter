class_name PlayerCarrier
extends Node
## Manages physical carried objects (logs on shoulder) as described in the GDD.

@export var max_logs: int = 2
@export var log_visuals: Array[Node3D] = []

var carried_logs: int = 0

func _ready() -> void:
	_update_visuals()
	GameEvents.logs_carried_changed.emit(carried_logs, max_logs)

func add_log() -> bool:
	if carried_logs < max_logs:
		carried_logs += 1
		_update_visuals()
		GameEvents.logs_carried_changed.emit(carried_logs, max_logs)
		return true
	return false

func remove_log() -> bool:
	if carried_logs > 0:
		carried_logs -= 1
		_update_visuals()
		GameEvents.logs_carried_changed.emit(carried_logs, max_logs)
		return true
	return false

func has_logs() -> bool:
	return carried_logs > 0

func _update_visuals() -> void:
	for i in range(log_visuals.size()):
		if log_visuals[i] != null:
			log_visuals[i].visible = (i < carried_logs)
