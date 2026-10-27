class_name GhostWall
extends Area3D

@export var required_logs: int = 4
var current_logs: int = 0

func get_interaction_info(player: PlayerController) -> Dictionary:
	if current_logs >= required_logs:
		return { "prompt": "", "type": "" }
	if player.carried_logs > 0:
		return { "prompt": "Встроить бревно (%d/%d)" % [current_logs, required_logs], "type": "BUILD" }
	return { "prompt": "Нужны бревна (%d/%d)" % [current_logs, required_logs], "type": "NEED_LOGS" }

func interact(player: PlayerController) -> void:
	if player.carried_logs > 0 and current_logs < required_logs:
		if player.remove_log():
			current_logs += 1
			_snap_log_visual(current_logs)
			if current_logs >= required_logs:
				_complete_construction()

func _snap_log_visual(count: int) -> void:
	var completed = get_parent().get_node_or_null("CompletedMesh")
	if completed:
		var log_node = completed.get_node_or_null("Log%d" % count)
		if log_node:
			log_node.visible = true

func _complete_construction() -> void:
	var parent_body = get_parent()
	if parent_body:
		var solid_col = parent_body.get_node_or_null("CollisionShape3D")
		if solid_col:
			solid_col.disabled = false
		var ghost_mesh = parent_body.get_node_or_null("GhostMesh")
		if ghost_mesh:
			ghost_mesh.visible = false
		var completed = parent_body.get_node_or_null("CompletedMesh")
		if completed:
			completed.visible = true
