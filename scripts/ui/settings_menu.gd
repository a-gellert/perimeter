class_name SettingsMenu
extends CanvasLayer
## UI Controller for the Settings Menu.
## Manages Audio volume sliders, Graphic toggles, and Mouse sensitivity.

signal back_pressed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ambience_slider: HSlider = %AmbienceSlider

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var ui_mode_option: OptionButton = %UIModeOption
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var back_button: Button = %BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_sync_ui_with_settings()

func open() -> void:
	_sync_ui_with_settings()
	visible = true

func close() -> void:
	visible = false

func _sync_ui_with_settings() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if not sm:
		return

	if master_slider:
		master_slider.value = sm.master_volume
		if not master_slider.value_changed.is_connected(_on_master_changed):
			master_slider.value_changed.connect(_on_master_changed)

	if music_slider:
		music_slider.value = sm.music_volume
		if not music_slider.value_changed.is_connected(_on_music_changed):
			music_slider.value_changed.connect(_on_music_changed)

	if sfx_slider:
		sfx_slider.value = sm.sfx_volume
		if not sfx_slider.value_changed.is_connected(_on_sfx_changed):
			sfx_slider.value_changed.connect(_on_sfx_changed)

	if ambience_slider:
		ambience_slider.value = sm.ambience_volume
		if not ambience_slider.value_changed.is_connected(_on_ambience_changed):
			ambience_slider.value_changed.connect(_on_ambience_changed)

	if fullscreen_check:
		fullscreen_check.button_pressed = sm.fullscreen
		if not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
			fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	if vsync_check:
		vsync_check.button_pressed = sm.vsync
		if not vsync_check.toggled.is_connected(_on_vsync_toggled):
			vsync_check.toggled.connect(_on_vsync_toggled)

	if ui_mode_option:
		ui_mode_option.selected = sm.ui_mode
		if not ui_mode_option.item_selected.is_connected(_on_ui_mode_selected):
			ui_mode_option.item_selected.connect(_on_ui_mode_selected)

	if sensitivity_slider:
		sensitivity_slider.value = sm.mouse_sensitivity * 1000.0
		if not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
			sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _on_ui_mode_selected(index: int) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.set_ui_mode(index)

func _on_master_changed(val: float) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.master_volume = val
		sm.apply_settings()

func _on_music_changed(val: float) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.music_volume = val
		sm.apply_settings()

func _on_sfx_changed(val: float) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.sfx_volume = val
		sm.apply_settings()

func _on_ambience_changed(val: float) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.ambience_volume = val
		sm.apply_settings()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.fullscreen = toggled_on
		sm.apply_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.vsync = toggled_on
		sm.apply_settings()

func _on_sensitivity_changed(val: float) -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.mouse_sensitivity = val / 1000.0
		sm.apply_settings()

func _on_back_pressed() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		sm.save_settings()
	close()
	back_pressed.emit()
