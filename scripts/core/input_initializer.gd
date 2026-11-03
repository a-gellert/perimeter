extends Node
## Ensures default input actions exist for Keyboard, Mouse, and Gamepad controller.

func _ready() -> void:
	# 1. Клавиатура и Мышь
	_register_key_action("move_forward", [KEY_W, KEY_UP])
	_register_key_action("move_backward", [KEY_S, KEY_DOWN])
	_register_key_action("move_left", [KEY_A, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("sprint", [KEY_SHIFT])
	_register_key_action("interact", [KEY_E, KEY_F])
	_register_key_action("toggle_inventory", [KEY_Q])
	_register_key_action("toggle_tablet", [KEY_TAB])
	_register_key_action("jump", [KEY_SPACE])
	_register_key_action("reload", [KEY_R])
	_register_key_action("weapon_1", [KEY_1])
	_register_key_action("weapon_2", [KEY_2])
	_register_key_action("hotbar_1", [KEY_1])
	_register_key_action("hotbar_2", [KEY_2])
	_register_key_action("hotbar_3", [KEY_3])
	_register_key_action("hotbar_4", [KEY_4])
	_register_key_action("hotbar_5", [KEY_5])
	_register_key_action("ui_cancel", [KEY_ESCAPE])

	_register_mouse_action("primary_action", MOUSE_BUTTON_LEFT)
	_register_mouse_action("secondary_action", MOUSE_BUTTON_RIGHT)

	# 2. Геймпад (Xbox / DualSense / Steam Deck)
	_register_joy_button("interact", JOY_BUTTON_A)
	_register_joy_button("jump", JOY_BUTTON_B)
	_register_joy_button("reload", JOY_BUTTON_X)
	_register_joy_button("toggle_inventory", JOY_BUTTON_Y)
	_register_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_register_joy_button("toggle_tablet", JOY_BUTTON_BACK)
	_register_joy_button("ui_cancel", JOY_BUTTON_START)
	_register_joy_button("primary_action", JOY_BUTTON_RIGHT_SHOULDER)
	_register_joy_button("secondary_action", JOY_BUTTON_LEFT_SHOULDER)

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

func _register_joy_button(action_name: StringName, button_index: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
