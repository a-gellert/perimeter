class_name PauseMenu
extends CanvasLayer
## Manages game pause menu triggered by ui_cancel (Esc).
## Toggles pause state, manages mouse capture, and provides resume/quit controls.

@export var resume_button: Button
@export var quit_button: Button

var is_paused: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if not resume_button:
		resume_button = find_child("ResumeButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_game_over_active():
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
	else:
		Input.mouse_mode = _saved_mouse_mode

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _is_game_over_active() -> bool:
	if get_tree() and get_tree().current_scene:
		var go := get_tree().current_scene.find_child("GameOver*", true, false)
		if go and go is CanvasLayer and go.visible:
			return true
	return false
