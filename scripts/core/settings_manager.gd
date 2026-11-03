class_name GameSettingsManager
extends Node
## Global Settings Manager for Perimeter.
## Persists player preferences to 'user://settings.cfg' and applies them to:
## - Audio buses (Master, Music, SFX, Ambience)
## - Display and Graphics (Window mode, VSync, Shadows, Fog)
## - Controls (Mouse sensitivity, Invert Y)

signal settings_changed

const CONFIG_FILE: String = "user://settings.cfg"

# Audio Settings
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambience_volume: float = 0.9

# Graphics Settings
var fullscreen: bool = false
var vsync: bool = true
var shadow_quality: int = 1 # 0: Low, 1: Medium, 2: High
var fog_enabled: bool = true

# Gameplay / Input Settings
enum UIMode {
	AUTO = 0,    # Авто-определение (ПК на компьютерах, Мобильный на смартфонах/планшетах)
	PC = 1,      # Принудительно ПК (Мышь + Клавиатура, подсказки горячих клавиш)
	MOBILE = 2   # Принудительно Мобильный (Экранный джойстик, сенсорные кнопки, крупный тач-интерфейс)
}

var ui_mode: int = UIMode.AUTO
var mouse_sensitivity: float = 0.0025
var invert_y: bool = false
var language: String = "ru"
var touch_controls_enabled: bool = false

func is_mobile_ui() -> bool:
	match ui_mode:
		UIMode.PC:
			return false
		UIMode.MOBILE:
			return true
		UIMode.AUTO, _:
			return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available() or touch_controls_enabled

func set_ui_mode(mode: int) -> void:
	ui_mode = clampi(mode, 0, 2)
	touch_controls_enabled = is_mobile_ui()
	apply_settings()
	save_settings()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_FILE)
	if err != OK:
		# Файл еще не создан — используем настройки по умолчанию
		return

	# Audio
	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	ambience_volume = config.get_value("audio", "ambience_volume", ambience_volume)

	# Graphics
	fullscreen = config.get_value("graphics", "fullscreen", fullscreen)
	vsync = config.get_value("graphics", "vsync", vsync)
	shadow_quality = config.get_value("graphics", "shadow_quality", shadow_quality)
	fog_enabled = config.get_value("graphics", "fog_enabled", fog_enabled)

	# Gameplay
	mouse_sensitivity = config.get_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	invert_y = config.get_value("gameplay", "invert_y", invert_y)
	language = config.get_value("gameplay", "language", language)
	touch_controls_enabled = config.get_value("gameplay", "touch_controls_enabled", touch_controls_enabled)
	ui_mode = config.get_value("gameplay", "ui_mode", ui_mode)

func save_settings() -> void:
	var config := ConfigFile.new()

	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambience_volume", ambience_volume)

	# Graphics
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "fog_enabled", fog_enabled)

	# Gameplay
	config.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("gameplay", "invert_y", invert_y)
	config.set_value("gameplay", "language", language)
	config.set_value("gameplay", "touch_controls_enabled", touch_controls_enabled)
	config.set_value("gameplay", "ui_mode", ui_mode)

	config.save(CONFIG_FILE)
	apply_settings()
	settings_changed.emit()

func apply_settings() -> void:
	# 1. Применение графики
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	# Shadow Quality, Atlas Size, and Shadow Distance
	match shadow_quality:
		0:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.directional_shadow_atlas_set_size(4096, true)

	var sun: DirectionalLight3D = null
	if get_tree() and get_tree().current_scene:
		sun = get_tree().current_scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		match shadow_quality:
			0: sun.directional_shadow_max_distance = 50.0
			1: sun.directional_shadow_max_distance = 85.0
			2: sun.directional_shadow_max_distance = 140.0

	# 2. Применение звука
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Ambience", ambience_volume)

	# 3. Передача чувствительности игроку, если он на сцене
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player and is_instance_valid(player):
		player.mouse_sensitivity = mouse_sensitivity

	# 4. Обновление экранных сенсорных контролов и режима UI
	var is_mob := is_mobile_ui()
	var tc := get_tree().get_first_node_in_group("touch_controls") as TouchControls
	if tc and is_instance_valid(tc):
		tc.set_touch_enabled(is_mob)

	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("ui_mode_changed"):
		bus.ui_mode_changed.emit(is_mob)

func _set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db := linear_to_db(clampf(volume_linear, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, volume_linear <= 0.001)
