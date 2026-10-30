class_name ChoppableTree
extends Interactable
## Taiga tree that can be chopped down with axe or action button into physical logs.

@export var tree_name: String = "Таёжная Сосна"
@export var max_hits: int = 3
@export var logs_to_spawn: int = 2
@export var log_scene: PackedScene
@export var stump_scene: PackedScene
@export var leave_stump: bool = true

var current_hits: int = 0
var is_falling: bool = false

func _ready() -> void:
	if not log_scene:
		log_scene = load("res://scenes/items/LogItem.tscn")
	if not stump_scene:
		stump_scene = load("res://scenes/environment/TreeStump.tscn")
	prompt_message = "Рубить %s" % tree_name

func get_prompt_text(_actor: Node) -> String:
	return "Рубить %s (%d/%d)" % [tree_name, current_hits, max_hits]

func get_interaction_info(_player: PlayerController) -> Dictionary:
	if is_falling or current_hits >= max_hits:
		return { "prompt": "", "type": "" }
	return {
		"prompt": "Рубить %s (%d/%d)" % [tree_name, current_hits, max_hits],
		"type": "CHOP"
	}

# Поддержка ударов топором (ЛКМ / PlayerAxe)
func take_damage(_amount: float) -> void:
	interact(null)

# Вызывается при нажатии [E] или ударе топором
func interact(actor: Node) -> void:
	if is_falling or current_hits >= max_hits:
		return

	current_hits += 1

	var tree_root := _get_tree_root()
	var fallback_pos: Vector3 = (get_parent() as Node3D).global_position if get_parent() is Node3D else Vector3.ZERO
	var pos: Vector3 = tree_root.global_position if tree_root else fallback_pos

	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(pos, 22.0)

	# Визуальная отдача (встряска кроны при ударе)
	if tree_root:
		var tween := tree_root.create_tween()
		tween.tween_property(tree_root, "scale", Vector3(0.93, 1.07, 0.93), 0.05)
		tween.tween_property(tree_root, "scale", Vector3(1.04, 0.96, 1.04), 0.06)
		tween.tween_property(tree_root, "scale", Vector3.ONE, 0.08)

	if current_hits >= max_hits:
		_fell_tree(tree_root, actor)

func _fell_tree(tree_root: Node3D, actor: Node) -> void:
	if not tree_root or is_falling:
		return
	is_falling = true
	is_enabled = false

	# Отключаем коллизию интеракции
	var parent_area := get_parent() as Area3D
	if parent_area:
		parent_area.monitoring = false
		parent_area.monitorable = false

	# Направление падения: от игрока или случайно
	var fall_dir := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	if actor and actor is Node3D:
		var away: Vector3 = (tree_root.global_position - (actor as Node3D).global_position)
		away.y = 0.0
		if away.length_squared() > 0.01:
			fall_dir = away.normalized()

	var fall_axis := Vector3(-fall_dir.z, 0, fall_dir.x).normalized()
	var spawn_pos := tree_root.global_position
	var world := tree_root.get_parent()

	# Анимация падения ствола на землю
	var fall_tween := tree_root.create_tween()
	fall_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_method(func(angle: float):
		if is_instance_valid(tree_root):
			tree_root.basis = Basis(fall_axis, angle)
	, 0.0, deg_to_rad(85.0), 0.85)

	fall_tween.tween_callback(func():
		_on_tree_crashed(world, spawn_pos, fall_dir, tree_root)
	)

func _on_tree_crashed(world: Node, spawn_pos: Vector3, fall_dir: Vector3, tree_root: Node3D) -> void:
	# Громкий треск и грохот падения
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(spawn_pos, 35.0)

	# Спавн пня на месте сруба
	if leave_stump and stump_scene and world:
		var stump := stump_scene.instantiate() as Node3D
		world.add_child(stump)
		stump.global_position = spawn_pos

	# Спавн физических бревен
	if log_scene and world:
		for i in range(logs_to_spawn):
			var log_inst := log_scene.instantiate() as Node3D
			world.add_child(log_inst)
			# Бревна выпадают вдоль упавшего ствола
			var dist: float = 2.0 + float(i) * 1.8
			var jitter := Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
			log_inst.global_position = spawn_pos + (fall_dir * dist) + jitter
			log_inst.rotation.y = randf_range(0, TAU)

	# Удаляем упавшую крону
	if is_instance_valid(tree_root):
		tree_root.queue_free()

func _get_tree_root() -> Node3D:
	var cur: Node = self
	while cur.get_parent():
		var p: Node = cur.get_parent()
		if p is StaticBody3D:
			return p as Node3D
		cur = p
	return get_parent() as Node3D
