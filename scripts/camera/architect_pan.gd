class_name ArchitectPan
extends Node
## Handles panning and zooming when in Top-Down Architect Mode.

@export var pan_speed: float = 24.0
@export var min_height: float = 18.0
@export var max_height: float = 40.0
@export var zoom_step: float = 3.0

var is_active: bool = false
var height: float = 28.0

func update_pan(pivot: Node3D, delta: float) -> void:
	if not is_active or not pivot:
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_vec := Vector3(input.x, 0, input_dir_y_to_z(input.y)) * (pan_speed * delta)
	pivot.global_position += move_vec
	pivot.global_position.y = height

func input_dir_y_to_z(y: float) -> float:
	return y

func handle_zoom(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			height = maxf(min_height, height - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			height = minf(max_height, height + zoom_step)
