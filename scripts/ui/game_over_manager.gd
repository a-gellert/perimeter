class_name GameOverManager
extends CanvasLayer
## Manages game over state when player health drops to zero.
## Displays death screen, pauses the game, and handles restart.

@export var restart_button: Button
@export var quit_button: Button

var is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Resolve button references if not bound via inspector
	if not restart_button:
		restart_button = find_child("RestartButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
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
	
	if GameEvents:
		GameEvents.player_died.emit()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	if GameEvents:
		GameEvents.game_restarted.emit()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
