class_name PauseMenu
extends CanvasLayer
## Manages game pause menu triggered by ui_cancel (Esc).
## Toggles pause state, manages mouse capture, and provides resume/save/load/settings/quit controls.

@export var resume_button: Button
@export var save_button: Button
@export var load_button: Button
@export var settings_button: Button
@export var main_menu_button: Button
@export var quit_button: Button
@export var status_label: Label
@export var settings_menu: SettingsMenu

var is_paused: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if not resume_button:
		resume_button = find_child("ResumeButton", true, false) as Button
	if not save_button:
		save_button = find_child("SaveButton", true, false) as Button
	if not load_button:
		load_button = find_child("LoadButton", true, false) as Button
	if not settings_button:
		settings_button = find_child("SettingsButton", true, false) as Button
	if not main_menu_button:
		main_menu_button = find_child("MainMenuButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button
	if not status_label:
		status_label = find_child("StatusLabel", true, false) as Label
	if not settings_menu:
		settings_menu = find_child("SettingsMenu", true, false) as SettingsMenu

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if settings_menu:
		settings_menu.back_pressed.connect(_on_settings_closed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_game_over_active():
			return
		if settings_menu and settings_menu.visible:
			settings_menu.close()
			return
		toggle_pause()
		if get_viewport():
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	set_paused(not is_paused)

func set_paused(pause: bool) -> void:
	is_paused = pause
	get_tree().paused = is_paused
	visible = is_paused

	if is_paused:
		_saved_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_button_states()
		if status_label:
			status_label.text = ""
	else:
		if settings_menu:
			settings_menu.close()
		Input.mouse_mode = _saved_mouse_mode

func _update_button_states() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if load_button and sm:
		load_button.disabled = not (sm.has_save(1) or sm.has_save(0))

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_save_pressed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var ok: bool = sm.save_game(1, "Быстрое сохранение")
		if status_label:
			if ok:
				status_label.text = "Игра успешно сохранена!"
				status_label.modulate = Color(0.3, 0.9, 0.4)
			else:
				status_label.text = "Ошибка сохранения."
				status_label.modulate = Color(0.9, 0.3, 0.3)
		_update_button_states()

func _on_load_pressed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var slot_to_load := 1
		if not sm.has_save(1) and sm.has_save(0):
			slot_to_load = 0
		if sm.has_save(slot_to_load):
			set_paused(false)
			sm.load_game(slot_to_load)

func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.open()

func _on_settings_closed() -> void:
	pass

func _on_main_menu_pressed() -> void:
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _is_game_over_active() -> bool:
	if get_tree() and get_tree().current_scene:
		var go := get_tree().current_scene.find_child("GameOver*", true, false)
		if go and go is CanvasLayer and go.visible:
			return true
	return false
