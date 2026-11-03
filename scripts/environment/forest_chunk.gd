@tool
class_name ForestChunk
extends Node3D
## Represents a 100x100m chunk of taiga forest with its own MultiMeshInstance3D.
## Provides automated Frustum Culling: chunks outside the camera
## frustum are culled by Godot in one piece with zero draw calls.

@export var chunk_coord: Vector2i = Vector2i.ZERO
@export var falling_tree_scene: PackedScene
@export var visibility_distance: float = 200.0
@export var visibility_fade_margin: float = 25.0

var multimesh_instance: MultiMeshInstance3D
var colliders_root: Node3D
var colliders_active: bool = true
var chunk_center: Vector3 = Vector3.ZERO
var _update_timer: float = 0.0

var total_trees: int = 0
var tree_transforms: Array[Transform3D] = []
var felled_indices: Dictionary = {}

func initialize(coord: Vector2i, transforms: Array[Transform3D], tree_mesh: Mesh, ft_scene: PackedScene) -> void:
	chunk_coord = coord
	falling_tree_scene = ft_scene
	total_trees = transforms.size()
	tree_transforms = transforms.duplicate()
	chunk_center = Vector3(-450.0 + float(chunk_coord.x) * 100.0, 0.0, -450.0 + float(chunk_coord.y) * 100.0)
	_update_timer = float((chunk_coord.x * 7 + chunk_coord.y * 13) % 10) * 0.05

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree_mesh
	mm.instance_count = total_trees

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "ChunkMultiMesh"
	multimesh_instance.multimesh = mm

	# Настройка AABB для автоматического Frustum Culling движком Godot
	var x_min: float = -500.0 + float(chunk_coord.x) * 100.0
	var z_min: float = -500.0 + float(chunk_coord.y) * 100.0
	multimesh_instance.custom_aabb = AABB(
		Vector3(x_min, -15.0, z_min),
		Vector3(100.0, 55.0, 100.0)
	)

	# Distance Culling (отсечение дальней дистанции):
	# Деревья за пределами visibility_distance плавно затухают (fade) и не нагружают GPU/шейдеры.
	multimesh_instance.visibility_range_end = visibility_distance
	multimesh_instance.visibility_range_end_margin = visibility_fade_margin
	multimesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	add_child(multimesh_instance)

	if total_trees == 0:
		return

	colliders_root = Node3D.new()
	colliders_root.name = "TreeColliders"
	add_child(colliders_root)

	var shape := CylinderShape3D.new()
	shape.height = 10.0
	shape.radius = 0.5

	for i in range(total_trees):
		var t: Transform3D = transforms[i]
		mm.set_instance_transform(i, t)

		# Индивидуальная точка коллизии и интеракции для каждого дерева в чанке
		var target := MultiMeshTreeTarget.new()
		target.name = "TreeTarget_%d" % i
		target.chunk = self
		target.instance_idx = i
		target.tree_transform = t
		target.collision_layer = 1 | 4 # Layer 1 (Environment) + Layer 3 (Interactable)
		target.collision_mask = 0

		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		col_shape.position = Vector3(0, 5.0, 0)
		target.add_child(col_shape)

		colliders_root.add_child(target)
		target.position = t.origin

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_timer += delta
	if _update_timer < 0.5:
		return
	_update_timer = 0.0

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var dist_sq: float = player.global_position.distance_squared_to(chunk_center)
	# Оптимизация физики: коллайдеры активны только в радиусе 130м вокруг игрока
	var should_be_active := dist_sq < (130.0 * 130.0)
	if should_be_active != colliders_active:
		colliders_active = should_be_active
		_set_colliders_enabled(should_be_active)

func _set_colliders_enabled(enabled: bool) -> void:
	if not colliders_root:
		return
	var layer: int = (1 | 4) if enabled else 0
	for child in colliders_root.get_children():
		var target := child as CollisionObject3D
		if target:
			target.collision_layer = layer

func chop_tree(instance_idx: int, tree_global_transform: Transform3D, player_pos: Vector3) -> void:
	if not multimesh_instance or not multimesh_instance.multimesh:
		return
	if felled_indices.has(instance_idx):
		return
	felled_indices[instance_idx] = true

	var effective_transform := tree_global_transform
	if instance_idx >= 0 and instance_idx < tree_transforms.size():
		effective_transform = tree_transforms[instance_idx]

	# 1. Масштаб этого инстанса в MultiMesh сжимается в 0 (дерево мгновенно исчезает из пачки)
	var zero_t := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), effective_transform.origin)
	multimesh_instance.multimesh.set_instance_transform(instance_idx, zero_t)
	if instance_idx >= 0 and instance_idx < tree_transforms.size():
		tree_transforms[instance_idx] = zero_t

	# 2. В тот же кадр на тех же координатах: спавнится динамическая сцена FallingTree.tscn
	if not falling_tree_scene:
		falling_tree_scene = load("res://scenes/environment/FallingTree.tscn")

	if falling_tree_scene:
		var ft := falling_tree_scene.instantiate() as FallingTree
		var world: Node = null
		if get_tree() and get_tree().current_scene:
			world = get_tree().current_scene
		elif get_parent():
			world = get_parent()
		else:
			world = self

		world.add_child(ft)
		ft.setup(effective_transform, player_pos)

func get_tree_scale(instance_idx: int) -> Vector3:
	if instance_idx >= 0 and instance_idx < tree_transforms.size():
		return tree_transforms[instance_idx].basis.get_scale()
	return Vector3.ONE

func get_tree_transform(instance_idx: int) -> Transform3D:
	if instance_idx >= 0 and instance_idx < tree_transforms.size():
		return tree_transforms[instance_idx]
	return Transform3D.IDENTITY

func is_tree_felled(instance_idx: int) -> bool:
	return felled_indices.has(instance_idx)
