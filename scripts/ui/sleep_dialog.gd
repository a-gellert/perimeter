class_name SleepDialog
extends Control
## Handles the sleep dilemma UI, fading screen, and hourly simulation.

@export var panel: Control
@export var fade_overlay: ColorRect
@export var sleep_4h_btn: Button
@export var sleep_8h_btn: Button
@export var cancel_btn: Button

func _ready() -> void:
	visible = false
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 0)
	GameEvents.request_sleep_dialog.connect(_on_request_sleep)
	
	if sleep_4h_btn:
		sleep_4h_btn.pressed.connect(func() -> void: _perform_sleep(4))
	if sleep_8h_btn:
		sleep_8h_btn.pressed.connect(func() -> void: _perform_sleep(8))
	if cancel_btn:
		cancel_btn.pressed.connect(_close)

func _on_request_sleep(_bed: Node) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _perform_sleep(hours: int) -> void:
	panel.visible = false
	
	# Fade to black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		_simulate_rest(hours)
	)
	tween.tween_interval(0.5)
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.6)
	tween.tween_callback(_close)

func _simulate_rest(hours: int) -> void:
	var world := get_tree().current_scene
	var time_mgr := world.get_node_or_null("TimeManager") as TimeManager
	if time_mgr:
		time_mgr.skip_hours(hours)

	var player := world.get_node_or_null("Player") as PlayerController
	if player and player.stats:
		player.stats.restore_stamina(hours * 12.5)
		player.stats.heal(hours * 6.0)

func _close() -> void:
	visible = false
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
