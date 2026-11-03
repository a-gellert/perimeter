class_name TouchJoystick
extends Control
## High-performance analog Virtual Joystick for mobile touch controls.
## Renders crisp antialiased vector elements and directly feeds Input action strengths.

signal moved(vector: Vector2)
signal released

@export var radius: float = 65.0
@export var deadzone: float = 0.12
@export var sprint_threshold: float = 0.85

@export var base_color: Color = Color(0.08, 0.1, 0.14, 0.6)
@export var border_color: Color = Color(0.4, 0.55, 0.75, 0.85)
@export var knob_color: Color = Color(0.88, 0.94, 1.0, 0.85)
@export var knob_active_color: Color = Color(1.25, 1.15, 0.4, 1.0)

var _touch_index: int = -1
var _knob_position: Vector2 = Vector2.ZERO
var _output_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.2, radius * 2.2)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var center := size * 0.5
	var is_active := (_touch_index != -1)

	# 1. Outer base ring
	draw_circle(center, radius, base_color)
	draw_arc(center, radius, 0.0, TAU, 36, border_color, 2.5, true)

	# 2. Deadzone indicator
	draw_arc(center, radius * deadzone, 0.0, TAU, 16, border_color * 0.4, 1.0, true)

	# 3. Outer sprint threshold guide
	draw_arc(center, radius * sprint_threshold, 0.0, TAU, 28, Color(0.5, 0.8, 1.0, 0.25), 1.0, true)

	# 4. Knob
	var cur_knob_color := knob_active_color if is_active else knob_color
	var knob_center := center + _knob_position
	var knob_r := radius * 0.36
	draw_circle(knob_center, knob_r, cur_knob_color)
	draw_arc(knob_center, knob_r, 0.0, TAU, 24, Color.WHITE, 2.0, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_reset()
			accept_event()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_knob(event.position)
			accept_event()

	# Support for desktop mouse testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _touch_index == -1:
				_touch_index = 999
				_update_knob(event.position)
				accept_event()
			elif not event.pressed and _touch_index == 999:
				_reset()
				accept_event()

	elif event is InputEventMouseMotion and _touch_index == 999:
		_update_knob(event.position)
		accept_event()

func _update_knob(touch_pos: Vector2) -> void:
	var center := size * 0.5
	var diff := touch_pos - center
	var dist := diff.length()

	if dist > 0.001:
		_knob_position = diff.normalized() * minf(dist, radius)
	else:
		_knob_position = Vector2.ZERO

	if dist > radius * deadzone:
		_output_vector = diff / radius
		if _output_vector.length() > 1.0:
			_output_vector = _output_vector.normalized()
	else:
		_output_vector = Vector2.ZERO

	_apply_input_actions(_output_vector)
	moved.emit(_output_vector)
	queue_redraw()

func _reset() -> void:
	_touch_index = -1
	_knob_position = Vector2.ZERO
	_output_vector = Vector2.ZERO
	_apply_input_actions(Vector2.ZERO)
	released.emit()
	queue_redraw()

func _apply_input_actions(vec: Vector2) -> void:
	if vec.x > 0.01:
		Input.action_press("move_right", vec.x)
		Input.action_release("move_left")
	elif vec.x < -0.01:
		Input.action_press("move_left", -vec.x)
		Input.action_release("move_right")
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")

	if vec.y > 0.01:
		Input.action_press("move_backward", vec.y)
		Input.action_release("move_forward")
	elif vec.y < -0.01:
		Input.action_press("move_forward", -vec.y)
		Input.action_release("move_backward")
	else:
		Input.action_release("move_backward")
		Input.action_release("move_forward")

func get_output() -> Vector2:
	return _output_vector

func is_sprint_recommended() -> bool:
	return _output_vector.length() >= sprint_threshold and _output_vector.y < -0.6
