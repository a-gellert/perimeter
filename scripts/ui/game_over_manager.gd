class_name GameOverManager
extends CanvasLayer
## Manages game over state when player health drops to zero.
## Displays death screen, pauses the game, and handles load save / restart / main menu.

@export var load_save_button: Button
@export var restart_button: Button
@export var main_menu_button: Button
@export var quit_button: Button

var is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if not load_save_button:
		load_save_button = find_child("LoadSaveButton", true, false) as Button
	if not restart_button:
		restart_button = find_child("RestartButton", true, false) as Button
	if not main_menu_button:
		main_menu_button = find_child("MainMenuButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button

	if load_save_button:
		load_save_button.pressed.connect(_on_load_save_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if GameEvents:
		GameEvents.stats_updated.connect(_on_stats_updated)

func _on_stats_updated(hp: float, _stamina: float, _max_stamina: float, _hunger: float) -> void:
	if hp <= 0.0 and not is_game_over:
		trigger_game_over()

func trigger_game_over() -> void:
	is_game_over = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Проверяем наличие сохранений
	var sm := get_node_or_null("/root/SaveManager")
	if load_save_button and sm:
		load_save_button.disabled = not (sm.has_save(1) or sm.has_save(0))

	if GameEvents:
		GameEvents.player_died.emit()

func _on_load_save_pressed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var slot := 1 if sm.has_save(1) else 0
		if sm.has_save(slot):
			get_tree().paused = false
			is_game_over = false
			visible = false
			sm.load_game(slot)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_game_over = false
	if GameEvents:
		GameEvents.game_restarted.emit()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	is_game_over = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
