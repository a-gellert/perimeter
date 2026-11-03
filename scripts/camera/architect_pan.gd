class_name ArchitectPan
extends Node
## Handles panning and zooming when in Top-Down Architect Mode.

@export var pan_speed: float = 24.0
@export var min_height: float = 16.0
@export var max_height: float = 45.0
@export var zoom_step: float = 3.0
@export var boundary_limit: float = 80.0

var is_active: bool = false
var height: float = 28.0

var _touches: Dictionary = {}
var _last_pinch_dist: float = 0.0
var _pivot_ref: Node3D = null

func update_pan(pivot: Node3D, delta: float) -> void:
	if not is_active or not pivot:
		return

	_pivot_ref = pivot

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input.length_squared() > 0.001:
		var move_vec := Vector3(input.x, 0, input_dir_y_to_z(input.y)) * (pan_speed * delta)
		pivot.global_position += move_vec

	# Clamp to perimeter boundaries and set height
	pivot.global_position.x = clampf(pivot.global_position.x, -boundary_limit, boundary_limit)
	pivot.global_position.z = clampf(pivot.global_position.z, -boundary_limit, boundary_limit)
	pivot.global_position.y = height

func input_dir_y_to_z(y: float) -> float:
	return y

func handle_input(event: InputEvent, pivot: Node3D = null) -> void:
	if not is_active:
		return
	if pivot:
		_pivot_ref = pivot

	# 1. Mouse Wheel Zoom (PC)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			height = maxf(min_height, height - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			height = minf(max_height, height + zoom_step)

	# 2. Mouse Drag (Right or Middle Button for PC pan)
	elif event is InputEventMouseMotion:
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) and _pivot_ref:
			var move_factor: float = height * 0.0018
			_pivot_ref.global_position.x -= event.relative.x * move_factor
			_pivot_ref.global_position.z -= event.relative.y * move_factor

	# 3. Touch Input (Mobile 1-Finger Pan & 2-Finger Pinch Zoom)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_last_pinch_dist = 0.0

	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1 and _pivot_ref:
			# 1 finger drag: camera pan
			var move_factor: float = height * 0.002
			_pivot_ref.global_position.x -= event.relative.x * move_factor
			_pivot_ref.global_position.z -= event.relative.y * move_factor
		elif _touches.size() >= 2:
			# 2 fingers: pinch to zoom
			var keys := _touches.keys()
			var p1: Vector2 = _touches[keys[0]]
			var p2: Vector2 = _touches[keys[1]]
			var cur_dist := p1.distance_to(p2)
			if _last_pinch_dist > 0.0:
				var delta_dist := cur_dist - _last_pinch_dist
				height = clampf(height - (delta_dist * 0.06), min_height, max_height)
			_last_pinch_dist = cur_dist

func handle_zoom(event: InputEvent) -> void:
	handle_input(event, _pivot_ref)
