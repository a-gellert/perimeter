class_name PlayerCarrier
extends Node
## Manages physical carried objects (logs on shoulder) as described in the GDD.

@export var max_logs: int = 2
@export var log_visuals: Array[Node3D] = []

var carried_logs: int = 0

func _ready() -> void:
	_update_visuals()
	_notify_carried_changed()

func add_log() -> bool:
	if carried_logs < max_logs:
		carried_logs += 1
		_update_visuals()
		_notify_carried_changed()
		return true
	return false

func remove_log() -> bool:
	if carried_logs > 0:
		carried_logs -= 1
		_update_visuals()
		_notify_carried_changed()
		return true
	return false

func _notify_carried_changed() -> void:
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("logs_carried_changed"):
		bus.logs_carried_changed.emit(carried_logs, max_logs)

func has_logs() -> bool:
	return carried_logs > 0

func _update_visuals() -> void:
	for i in range(log_visuals.size()):
		if log_visuals[i] != null:
			log_visuals[i].visible = (i < carried_logs)
