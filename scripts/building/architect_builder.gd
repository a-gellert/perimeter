class_name ArchitectBuilder
extends Node3D
## Handles grid snapping, rotation, and modular blueprint placement in Architect Mode.
## Supports Palisade Walls, Fortified Gates, Watchtowers, and Amber Spotlights.

signal blueprint_selected(index: int)

@export var camera: Camera3D
@export var preview_mesh: MeshInstance3D
@export var grid_size: float = 2.5

@export var building_scenes: Array[PackedScene] = []
var selected_index: int = 0
var current_rotation_y: float = 0.0

var is_active: bool = false
var _snapped_pos: Vector3

const BUILDING_NAMES := [
	"Частокол (4 бревна)",
	"Укреплённые ворота (6 брёвен, 4 металла)",
	"Смотровая вышка (8 брёвен, 2 металла)",
	"УФ-прожектор (2 бревна, 4 металла, 2 янтаря)",
	"Барак выживших (10 брёвен, 4 металла)"
]

func _ready() -> void:
	add_to_group("architect_builder")
	GameEvents.camera_mode_changed.connect(_on_mode_changed)
	if building_scenes.is_empty():
		building_scenes.append(load("res://scenes/buildings/GhostWall.tscn"))
		building_scenes.append(load("res://scenes/buildings/FortifiedGate.tscn"))
		building_scenes.append(load("res://scenes/buildings/Watchtower.tscn"))
		building_scenes.append(load("res://scenes/buildings/AmberSpotlight.tscn"))
		building_scenes.append(load("res://scenes/buildings/Barracks.tscn"))

	if preview_mesh:
		preview_mesh.visible = false
	_update_preview_mesh_shape(selected_index)

func _process(_delta: float) -> void:
	if not is_active or not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)

	if absf(ray_normal.y) > 0.001:
		var distance := -ray_origin.y / ray_normal.y
		if distance > 0.0:
			var hit_pos := ray_origin + ray_normal * distance
			_snapped_pos = Vector3(
				snappedf(hit_pos.x, grid_size),
				0.0,
				snappedf(hit_pos.z, grid_size)
			)
			if preview_mesh:
				preview_mesh.visible = true
				preview_mesh.global_position = _snapped_pos
				preview_mesh.rotation.y = current_rotation_y

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("primary_action"):
		place_blueprint()

	# Вращение чертежа по клавише [R]
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			rotate_blueprint()
		# Переключение чертежей клавишами 1-5
		elif event.keycode == KEY_1:
			select_building(0)
		elif event.keycode == KEY_2:
			select_building(1)
		elif event.keycode == KEY_3:
			select_building(2)
		elif event.keycode == KEY_4:
			select_building(3)
		elif event.keycode == KEY_5:
			select_building(4)

func select_building(idx: int) -> void:
	if idx >= 0 and idx < building_scenes.size():
		selected_index = idx
		_update_preview_mesh_shape(idx)
		blueprint_selected.emit(idx)
		print("[Architect] Selected blueprint: ", BUILDING_NAMES[selected_index])

func _select_building(idx: int) -> void:
	select_building(idx)

func rotate_blueprint() -> void:
	current_rotation_y = fmod(current_rotation_y + PI * 0.5, TAU)
	if preview_mesh:
		preview_mesh.rotation.y = current_rotation_y

func place_blueprint() -> bool:
	if selected_index < 0 or selected_index >= building_scenes.size():
		return false
	var scene_to_place = building_scenes[selected_index]
	if not scene_to_place:
		return false

	# Проверка: строить разрешено строго в пределах кордона 100х100 м
	var topo := get_node_or_null("/root/WorldTopography")
	if topo and not topo.is_inside_buildable_zone(_snapped_pos):
		return false

	var world := get_tree().current_scene
	if not world:
		return false

	var blueprints_parent := world.get_node_or_null("PerimeterBlueprints")
	if not blueprints_parent:
		blueprints_parent = world

	var instance := scene_to_place.instantiate() as Node3D
	blueprints_parent.add_child(instance)
	instance.global_position = _snapped_pos
	instance.rotation.y = current_rotation_y
	GameEvents.blueprint_placed.emit(instance)
	print("[Architect] Placed: ", BUILDING_NAMES[selected_index], " at ", _snapped_pos)
	return true

func _place_blueprint() -> void:
	place_blueprint()

func _update_preview_mesh_shape(idx: int) -> void:
	if not preview_mesh:
		return
	var box := BoxMesh.new()
	var prev_mat: Material = null
	if preview_mesh.mesh and preview_mesh.mesh is BoxMesh:
		prev_mat = (preview_mesh.mesh as BoxMesh).material
	if prev_mat:
		box.material = prev_mat

	match idx:
		0: # Частокол
			box.size = Vector3(2.4, 2.5, 0.4)
			preview_mesh.position.y = 1.25
		1: # Ворота
			box.size = Vector3(4.0, 3.2, 0.6)
			preview_mesh.position.y = 1.6
		2: # Смотровая вышка
			box.size = Vector3(3.2, 6.0, 3.2)
			preview_mesh.position.y = 3.0
		3: # УФ-прожектор
			box.size = Vector3(1.2, 2.8, 1.2)
			preview_mesh.position.y = 1.4
		4: # Барак
			box.size = Vector3(6.0, 3.5, 5.0)
			preview_mesh.position.y = 1.75
		_:
			box.size = Vector3(2.5, 2.5, 2.5)
			preview_mesh.position.y = 1.25
	preview_mesh.mesh = box

func _on_mode_changed(mode: int) -> void:
	is_active = (mode == GameEnums.CameraMode.ARCHITECT)
	if preview_mesh:
		preview_mesh.visible = is_active
