class_name PlayerLook
extends Node
## Handles mouse look and orientation for First Person View.

@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = 85.0

var is_active: bool = true
var _pitch: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var parent_body := get_parent() as CharacterBody3D
		if parent_body:
			parent_body.rotate_y(-event.relative.x * mouse_sensitivity)
			
		_pitch = clampf(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)

func apply_pitch_to(node: Node3D) -> void:
	if is_active and node:
		node.rotation.x = _pitch

func set_active(active: bool) -> void:
	is_active = active
	if is_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
