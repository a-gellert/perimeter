extends Node
## Ensures default input actions exist so the game works out-of-the-box.

func _ready() -> void:
	_register_key_action("move_forward", [KEY_W, KEY_UP])
	_register_key_action("move_backward", [KEY_S, KEY_DOWN])
	_register_key_action("move_left", [KEY_A, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("sprint", [KEY_SHIFT])
	_register_key_action("interact", [KEY_E])
	_register_key_action("toggle_tablet", [KEY_TAB])
	_register_key_action("jump", [KEY_SPACE])
	_register_mouse_action("primary_action", MOUSE_BUTTON_LEFT)
	_register_mouse_action("secondary_action", MOUSE_BUTTON_RIGHT)

func _register_key_action(action_name: StringName, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _register_mouse_action(action_name: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
