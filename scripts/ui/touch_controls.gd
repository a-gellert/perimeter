class_name TouchControls
extends Control
## Mobile on-screen HUD controls for First-Person View.
## Features:
## - 360-degree analog Virtual Joystick for smooth movement
## - Touch swipe look area for camera control (yaw and pitch)
## - Large thumb-friendly action buttons: Attack, Interact [E], Jump, Sprint toggle, Reload, Inventory [Q]
## - Context-aware interaction feedback
## - Automatically hides in Architect mode and respects platform settings.

@export var virtual_joystick: TouchJoystick
@export var touch_look_zone: Control

@export var attack_button: Button
@export var interact_button: Button
@export var jump_button: Button
@export var sprint_button: Button
@export var reload_button: Button
@export var inventory_button: Button

@export var look_sensitivity: float = 1.0

var _look_touch_id: int = -1
var _is_mouse_swiping: bool = false
var _is_touch_enabled: bool = false
var _player: PlayerController = null

func _ready() -> void:
	add_to_group("touch_controls")
	_find_nodes()
	_detect_platform_controls()
	_setup_button_signals()

	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.context_action_updated.connect(_on_context_action_updated)
	GameEvents.ui_mode_changed.connect(func(is_mob: bool):
		set_touch_enabled(is_mob)
	)

	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.inventory_updated.connect(_update_weapon_controls)

func _find_nodes() -> void:
	if not virtual_joystick:
		virtual_joystick = find_child("VirtualJoystick", true, false) as TouchJoystick
	if not touch_look_zone:
		touch_look_zone = find_child("TouchLookZone", true, false) as Control
	if not attack_button:
		attack_button = find_child("AttackButton", true, false) as Button
	if not interact_button:
		interact_button = find_child("InteractButton", true, false) as Button
	if not jump_button:
		jump_button = find_child("JumpButton", true, false) as Button
	if not sprint_button:
		sprint_button = find_child("SprintButton", true, false) as Button
	if not reload_button:
		reload_button = find_child("ReloadButton", true, false) as Button
	if not inventory_button:
		inventory_button = find_child("InventoryButton", true, false) as Button

	if touch_look_zone:
		touch_look_zone.gui_input.connect(_on_look_zone_gui_input)

func _setup_button_signals() -> void:
	if attack_button:
		attack_button.pressed.connect(_on_attack_pressed)
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
	if sprint_button:
		sprint_button.pressed.connect(_on_sprint_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_pressed)

	if virtual_joystick:
		virtual_joystick.moved.connect(_on_joystick_moved)

func _detect_platform_controls() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("is_mobile_ui"):
		set_touch_enabled(sm.is_mobile_ui())
	else:
		var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
		set_touch_enabled(is_mobile)

func set_touch_enabled(enabled: bool) -> void:
	_is_touch_enabled = enabled
	visible = _is_touch_enabled

func toggle_touch_controls() -> void:
	set_touch_enabled(not _is_touch_enabled)

func _get_player() -> PlayerController:
	if _player and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	return _player

func _on_look_zone_gui_input(event: InputEvent) -> void:
	var player = _get_player()
	if not player:
		return

	# Сенсорный свайп камеры
	if event is InputEventScreenTouch:
		if event.pressed and _look_touch_id == -1:
			_look_touch_id = event.index
			touch_look_zone.accept_event()
		elif not event.pressed and event.index == _look_touch_id:
			_look_touch_id = -1
			touch_look_zone.accept_event()

	elif event is InputEventScreenDrag:
		if event.index == _look_touch_id:
			player.apply_look_rotation(event.relative * look_sensitivity)
			touch_look_zone.accept_event()

	# Мышь для тестирования на ПК
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_swiping = true
			else:
				_is_mouse_swiping = false

	elif event is InputEventMouseMotion and _is_mouse_swiping:
		player.apply_look_rotation(event.relative * look_sensitivity)

func _on_joystick_moved(vector: Vector2) -> void:
	var player = _get_player()
	if not player:
		return

	# Если джойстик выжат на максимум вперед (>85%), автоматически подключаем бег
	if virtual_joystick and virtual_joystick.is_sprint_recommended():
		player.set_sprint(true)
		if sprint_button:
			sprint_button.modulate = Color(1.3, 1.2, 0.4, 1.0)
	elif not player.wants_sprint_toggle:
		player.set_sprint(false)
		if sprint_button:
			sprint_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_attack_pressed() -> void:
	var player = _get_player()
	if player:
		player.trigger_primary_action()

func _on_interact_pressed() -> void:
	var player = _get_player()
	if player:
		player.perform_context_action()

func _on_jump_pressed() -> void:
	var player = _get_player()
	if player:
		player.jump()

func _on_sprint_pressed() -> void:
	var player = _get_player()
	if player:
		player.toggle_sprint()
		if sprint_button:
			if player.wants_sprint_toggle:
				sprint_button.modulate = Color(1.3, 1.2, 0.4, 1.0) # Золотая подсветка активного спринта
			else:
				sprint_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_reload_pressed() -> void:
	var player = _get_player()
	if player:
		player.trigger_reload()

func _on_inventory_pressed() -> void:
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("toggle_inventory"):
		inv_ui.toggle_inventory()

func _on_context_action_updated(action_title: String, target: Node) -> void:
	if not interact_button:
		return

	if target != null and not action_title.is_empty():
		interact_button.text = "✋\n%s" % action_title.left(12)
		interact_button.modulate = Color(0.4, 1.1, 0.6, 1.0) # Зеленый призыв к действию
	else:
		interact_button.text = "✋\nДействие"
		interact_button.modulate = Color(0.85, 0.9, 0.95, 0.75)

func _update_weapon_controls() -> void:
	var player = _get_player()
	if not player:
		return
	var wm = player.find_child("HandSlot", true, false)
	if wm and reload_button:
		var has_gun: bool = (wm.rifle_node != null and wm.rifle_node.visible)
		reload_button.visible = has_gun

func _on_camera_mode_changed(mode: int) -> void:
	if mode == GameEnums.CameraMode.ARCHITECT:
		visible = false
	else:
		visible = _is_touch_enabled
