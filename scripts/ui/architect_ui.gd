class_name ArchitectUI
extends Control
## Mobile-optimized UI for Architect (Top-Down Tablet) Mode.
## Automatically shows when entering Architect mode, hiding inventory and displaying
## large, touch-friendly construction buttons and actions.

@export var dock_container: HBoxContainer
@export var rotate_btn: Button
@export var place_btn: Button
@export var exit_btn: Button
@export var logs_label: Label
@export var scrap_label: Label
@export var amber_label: Label
@export var status_toast_label: Label

var _building_cards: Array[Button] = []
var _builder: ArchitectBuilder = null
var _is_mobile: bool = false

# Данные о доступных постройках для мобильного интерфейса
const BUILDINGS_INFO := [
	{
		"name": "Частокол",
		"cost": "4 бревна",
		"icon": "🪵",
		"desc": "Стена базы"
	},
	{
		"name": "Ворота",
		"cost": "6 бр, 4 мет",
		"icon": "🚪",
		"desc": "Укреплённый створ"
	},
	{
		"name": "Вышка",
		"cost": "8 бр, 2 мет",
		"icon": "🗼",
		"desc": "Смотровая позиция"
	},
	{
		"name": "Прожектор",
		"cost": "2 бр, 4 мет, 2 янт",
		"icon": "💡",
		"desc": "УФ-отпугиватель"
	},
	{
		"name": "Барак",
		"cost": "10 бр, 4 мет",
		"icon": "🏠",
		"desc": "Жилье колонистов"
	}
]

func _ready() -> void:
	visible = false
	add_to_group("architect_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_find_nodes()
	_setup_actions()

	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.ui_mode_changed.connect(_on_ui_mode_changed)

	var sm = get_node_or_null("/root/SettingsManager")
	var initial_mobile: bool = sm.is_mobile_ui() if sm and sm.has_method("is_mobile_ui") else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_on_ui_mode_changed(initial_mobile)

	var eco = get_node_or_null("/root/EconomyManager")
	if eco:
		eco.resources_updated.connect(_update_storage_display)
		_update_storage_display()

func _on_ui_mode_changed(is_mobile: bool) -> void:
	_is_mobile = is_mobile
	if exit_btn:
		exit_btn.text = "✕ Вид от 1-го лица" if _is_mobile else "✕ [Tab] Вид от 1-го лица"
		exit_btn.custom_minimum_size = Vector2(0, 52) if _is_mobile else Vector2(0, 44)
	if rotate_btn:
		rotate_btn.text = "⟳ Поворот 90°" if _is_mobile else "⟳ [R] Поворот 90°"
		rotate_btn.custom_minimum_size = Vector2(0, 52) if _is_mobile else Vector2(0, 44)
	if place_btn:
		place_btn.text = "✔ ПОСТАВИТЬ" if _is_mobile else "✔ [ЛКМ] Поставить"
		place_btn.custom_minimum_size = Vector2(0, 52) if _is_mobile else Vector2(0, 44)
	_create_building_cards()

func _find_nodes() -> void:
	if not dock_container:
		dock_container = find_child("DockContainer", true, false) as HBoxContainer
	if not rotate_btn:
		rotate_btn = find_child("RotateButton", true, false) as Button
	if not place_btn:
		place_btn = find_child("PlaceButton", true, false) as Button
	if not exit_btn:
		exit_btn = find_child("ExitButton", true, false) as Button
	if not logs_label:
		logs_label = find_child("LogsLabel", true, false) as Label
	if not scrap_label:
		scrap_label = find_child("ScrapLabel", true, false) as Label
	if not amber_label:
		amber_label = find_child("AmberLabel", true, false) as Label
	if not status_toast_label:
		status_toast_label = find_child("StatusToastLabel", true, false) as Label

func _setup_actions() -> void:
	if rotate_btn:
		rotate_btn.pressed.connect(_on_rotate_pressed)
	if place_btn:
		place_btn.pressed.connect(_on_place_pressed)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

func _get_builder() -> ArchitectBuilder:
	if _builder and is_instance_valid(_builder):
		return _builder
	_builder = get_tree().get_first_node_in_group("architect_builder") as ArchitectBuilder
	if not _builder:
		var world = get_tree().current_scene
		if world:
			_builder = world.find_child("ArchitectBuilder", true, false) as ArchitectBuilder
	if _builder and not _builder.blueprint_selected.is_connected(_on_builder_blueprint_selected):
		_builder.blueprint_selected.connect(_on_builder_blueprint_selected)
	return _builder

func _on_builder_blueprint_selected(idx: int) -> void:
	_highlight_selected_card(idx)

func _create_building_cards() -> void:
	if not dock_container:
		return

	for c in dock_container.get_children():
		c.queue_free()
	_building_cards.clear()

	for i in range(BUILDINGS_INFO.size()):
		var info: Dictionary = BUILDINGS_INFO[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(160, 84)
		card.focus_mode = Control.FOCUS_NONE

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.18, 0.92)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.35, 0.42, 0.52, 1.0)
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("normal", sb)

		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.18, 0.22, 0.28, 0.95)
		sb_hover.border_color = Color(0.55, 0.65, 0.8, 1.0)
		card.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed := sb.duplicate() as StyleBoxFlat
		sb_pressed.bg_color = Color(0.25, 0.3, 0.4, 0.95)
		card.add_theme_stylebox_override("pressed", sb_pressed)

		if _is_mobile:
			card.custom_minimum_size = Vector2(160, 84)
			card.text = "%s %s\n%s\n[%s]" % [
				info["icon"],
				info["name"],
				info["desc"],
				info["cost"]
			]
		else:
			card.custom_minimum_size = Vector2(170, 84)
			card.text = "[ %d ] %s %s\n%s\n[%s]" % [
				i + 1,
				info["icon"],
				info["name"],
				info["desc"],
				info["cost"]
			]

		var idx := i
		card.pressed.connect(func(): _on_building_card_pressed(idx))
		dock_container.add_child(card)
		_building_cards.append(card)

	_highlight_selected_card(0)

func _on_building_card_pressed(idx: int) -> void:
	var builder = _get_builder()
	if builder:
		builder.select_building(idx)
	_highlight_selected_card(idx)

func _highlight_selected_card(selected_idx: int) -> void:
	for i in range(_building_cards.size()):
		var card = _building_cards[i]
		if i == selected_idx:
			card.modulate = Color(1.3, 1.25, 0.45, 1.0) # Золотистая подсветка выбранного
		else:
			card.modulate = Color(0.9, 0.92, 0.95, 1.0)

func _on_rotate_pressed() -> void:
	var builder = _get_builder()
	if builder:
		builder.rotate_blueprint()
		show_toast("⟳ Поворот на 90°")

func _on_place_pressed() -> void:
	var builder = _get_builder()
	if builder:
		var ok: bool = builder.place_blueprint()
		if ok:
			var info: Dictionary = BUILDINGS_INFO[builder.selected_index]
			show_toast("✔ Каркас '%s' установлен! Доставьте ресурсы на кордон." % info["name"])
		else:
			show_toast("⚠ Нельзя строить здесь (только внутри кордона)!", true)

func _on_exit_pressed() -> void:
	GameEvents.request_mode_switch.emit(GameEnums.CameraMode.FPV)

func _on_camera_mode_changed(mode: int) -> void:
	var is_architect: bool = (mode == GameEnums.CameraMode.ARCHITECT)
	visible = is_architect

	if is_architect:
		_update_storage_display()
		var builder = _get_builder()
		if builder:
			_highlight_selected_card(builder.selected_index)
		if _is_mobile:
			show_toast("Режим архитектора. Выберите постройку и нажмите «ПОСТАВИТЬ».")
		else:
			show_toast("Режим архитектора. Выбор [1-5], поворот [R], установка [ЛКМ], выход [Tab].")

func _update_storage_display() -> void:
	var eco = get_node_or_null("/root/EconomyManager")
	if not eco:
		return

	var logs: int = eco.base_storage.get("logs", 0)
	var scrap: int = eco.base_storage.get("scrap", 0)
	var amber: int = eco.base_storage.get("amber", 0)

	if logs_label:
		logs_label.text = "🪵 Брёвна: %d" % logs
	if scrap_label:
		scrap_label.text = "⚙ Металл: %d" % scrap
	if amber_label:
		amber_label.text = "💎 Янтарь: %d" % amber

func show_toast(msg: String, is_warning: bool = false) -> void:
	if not status_toast_label:
		return
	status_toast_label.visible = true
	status_toast_label.text = msg
	status_toast_label.modulate = Color(1.0, 0.35, 0.35) if is_warning else Color(0.3, 0.95, 0.5)

	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(status_toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(status_toast_label) and status_toast_label.text == msg:
			status_toast_label.visible = false
			status_toast_label.modulate.a = 1.0
	)
