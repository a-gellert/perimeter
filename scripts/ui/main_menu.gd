class_name MainMenu
extends Control
## Main Menu controller for Perimeter.
## Manages game startup, save slot continuation, settings dialog, and quitting.

@export var continue_button: Button
@export var new_game_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var save_info_label: Label
@export var settings_menu: SettingsMenu

func _ready() -> void:
	# Ensure mouse is visible in menus
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not continue_button:
		continue_button = find_child("ContinueButton", true, false) as Button
	if not new_game_button:
		new_game_button = find_child("NewGameButton", true, false) as Button
	if not settings_button:
		settings_button = find_child("SettingsButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button
	if not save_info_label:
		save_info_label = find_child("SaveInfoLabel", true, false) as Label
	if not settings_menu:
		settings_menu = find_child("SettingsMenu", true, false) as SettingsMenu

	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	_check_save_state()

func _check_save_state() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var has_any_save: bool = false
	var save_title: String = ""

	if sm:
		if sm.has_save(1):
			has_any_save = true
			var meta: Dictionary = sm.get_save_meta(1)
			save_title = meta.get("title", "Слот 1")
		elif sm.has_save(0):
			has_any_save = true
			var meta: Dictionary = sm.get_save_meta(0)
			save_title = meta.get("title", "Автосохранение")

	if continue_button:
		continue_button.disabled = not has_any_save

	if save_info_label:
		if has_any_save:
			save_info_label.text = "Последнее сохранение: %s" % save_title
			save_info_label.modulate = Color(0.7, 0.85, 0.75, 0.9)
		else:
			save_info_label.text = "Нет сохранённых данных"
			save_info_label.modulate = Color(0.6, 0.65, 0.7, 0.6)

func _on_continue_pressed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var slot_to_load := 1
		if not sm.has_save(1) and sm.has_save(0):
			slot_to_load = 0
		sm.load_game(slot_to_load)

func _on_new_game_pressed() -> void:
	# Начинаем чистую сессию игры
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.open()

func _on_quit_pressed() -> void:
	get_tree().quit()
