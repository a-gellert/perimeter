class_name ArchitectBuilder
extends Node3D
## Handles grid snapping and ghost blueprint placement in Top-Down Architect Mode.

@export var camera: Camera3D
@export var ghost_wall_scene: PackedScene
@export var preview_mesh: MeshInstance3D
@export var grid_size: float = 2.5

var is_active: bool = false
var _snapped_pos: Vector3

func _ready() -> void:
	GameEvents.camera_mode_changed.connect(_on_mode_changed)
	if preview_mesh:
		preview_mesh.visible = false

func _process(_delta: float) -> void:
	if not is_active or not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	
	# Raycast onto y = 0 plane
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("primary_action") and ghost_wall_scene:
		_place_blueprint()

func _place_blueprint() -> void:
	# Строить частокол и бараки разрешено строго в пределах кордона 100х100 м
	if Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography"):
		if not WorldTopography.is_inside_buildable_zone(_snapped_pos):
			return

	var world := get_tree().current_scene
	if not world:
		return
	
	var wall := ghost_wall_scene.instantiate() as Node3D
	world.add_child(wall)
	wall.global_position = _snapped_pos
	GameEvents.blueprint_placed.emit(wall)

func _on_mode_changed(mode: int) -> void:
	is_active = (mode == GameEnums.CameraMode.ARCHITECT)
	if preview_mesh:
		preview_mesh.visible = is_active
