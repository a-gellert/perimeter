@tool
class_name MultiMeshTreeTarget
extends StaticBody3D
## Lightweight interaction & physics target for an individual tree inside a MultiMesh chunk.

var chunk: ForestChunk
var instance_idx: int = -1
var tree_transform: Transform3D
var tree_name: String = "Таёжная Сосна"

func get_interaction_info(_actor: PlayerController) -> Dictionary:
	return {
		"prompt": "Рубить %s" % tree_name,
		"type": "CHOP"
	}

func take_damage(_amount: float) -> void:
	chop(null)

func interact(actor: Node) -> void:
	chop(actor)

func chop(actor: Node) -> void:
	# Отключаем коллизию, чтобы исключить повторные срабатывания в том же кадре
	collision_layer = 0
	collision_mask = 0

	var player_pos: Vector3 = tree_transform.origin - Vector3(0, 0, 1)
	if actor and actor is Node3D:
		player_pos = (actor as Node3D).global_position
	elif is_inside_tree():
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			player_pos = player.global_position

	if chunk and is_instance_valid(chunk):
		chunk.chop_tree(instance_idx, tree_transform, player_pos)

	queue_free()
