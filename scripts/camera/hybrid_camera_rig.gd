class_name HybridCameraRig
extends Node3D
## Coordinates camera states and seamless 0.6s FPV <-> Top-Down transitions.

@export var camera: Camera3D
@export var transition: CameraTransition
@export var architect_pan: ArchitectPan

@export var fpv_mount: Node3D
@export var top_down_pivot: Node3D

var current_mode: int = GameEnums.CameraMode.FPV
var is_transitioning: bool = false

func _ready() -> void:
	GameEvents.request_mode_switch.connect(switch_mode)
	if camera and fpv_mount:
		camera.global_transform = fpv_mount.global_transform

func _process(delta: float) -> void:
	if is_transitioning:
		return

	if current_mode == GameEnums.CameraMode.FPV and fpv_mount and camera:
		camera.global_transform = fpv_mount.global_transform
	elif current_mode == GameEnums.CameraMode.ARCHITECT and top_down_pivot and camera:
		architect_pan.update_pan(top_down_pivot, delta)
		camera.global_transform = top_down_pivot.global_transform

func _unhandled_input(event: InputEvent) -> void:
	if current_mode == GameEnums.CameraMode.ARCHITECT and architect_pan:
		architect_pan.handle_zoom(event)

func switch_mode(target_mode: int) -> void:
	if target_mode == current_mode or is_transitioning:
		return

	is_transitioning = true
	var target_transform: Transform3D

	if target_mode == GameEnums.CameraMode.ARCHITECT:
		# Position architect view above current player location
		if fpv_mount and top_down_pivot:
			top_down_pivot.global_position = Vector3(
				fpv_mount.global_position.x,
				architect_pan.height,
				fpv_mount.global_position.z + 12.0
			)
			top_down_pivot.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
			target_transform = top_down_pivot.global_transform
	else:
		if fpv_mount:
			target_transform = fpv_mount.global_transform

	architect_pan.is_active = false

	transition.interpolate_transform(camera, target_transform, func() -> void:
		current_mode = target_mode
		is_transitioning = false
		architect_pan.is_active = (current_mode == GameEnums.CameraMode.ARCHITECT)
		GameEvents.camera_mode_changed.emit(current_mode)
	)
