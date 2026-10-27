class_name ChoppableTree
extends Interactable
## Taiga pine tree that can be chopped into physical logs.

@export var max_hits: int = 3
@export var log_scene: PackedScene
@export var logs_to_spawn: int = 2

var current_hits: int = 0

func _init() -> void:
	prompt_message = "Рубить сосну"

func interact(actor: Node) -> void:
	current_hits += 1
	
	# Visual hit punch (scale shake)
	var parent_node := get_parent() as Node3D
	if parent_node:
		var tween := parent_node.create_tween()
		tween.tween_property(parent_node, "scale", Vector3(0.92, 1.08, 0.92), 0.08)
		tween.tween_property(parent_node, "scale", Vector3.ONE, 0.12)

	if current_hits >= max_hits:
		_fell_tree(parent_node)

func _fell_tree(tree_root: Node3D) -> void:
	if not tree_root:
		return
	var spawn_pos := tree_root.global_position
	var world := tree_root.get_parent()

	if log_scene and world:
		for i in range(logs_to_spawn):
			var log_inst := log_scene.instantiate() as Node3D
			world.add_child(log_inst)
			var offset := Vector3(randf_range(-1.2, 1.2), 0.5, randf_range(-1.2, 1.2))
			log_inst.global_position = spawn_pos + offset

	tree_root.queue_free()
