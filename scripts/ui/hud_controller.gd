class_name HUDController
extends Control
## Central HUD coordinator listening to decoupled GameEvents.
## Displays HP, Stamina, Carried Logs, Time/Day, Active Weapon, Zone, and Raid Alerts.

@export var hp_bar: StatsBar
@export var stamina_bar: StatsBar
@export var logs_label: Label
@export var time_label: Label
@export var fps_label: Label
@export var context_prompt_label: Label
@export var mode_label: Label
@export var zone_label: Label
@export var weapon_label: Label
@export var raid_banner: Label
@export var quest_label: Label

var _fps_update_timer: float = 0.0
var _is_mobile: bool = false
var _current_camera_mode: int = 0
var _cached_action_title: String = ""
var _cached_weapon_name: String = "Топор Егеря"
var _cached_weapon_slot: int = 1

func _process(delta: float) -> void:
	if fps_label:
		_fps_update_timer += delta
		if _fps_update_timer >= 0.2:
			_fps_update_timer = 0.0
			var fps := Engine.get_frames_per_second()
			fps_label.text = "FPS: %d" % fps

func _ready() -> void:
	GameEvents.stats_updated.connect(_on_stats_updated)
	GameEvents.logs_carried_changed.connect(_on_logs_changed)
	GameEvents.context_action_updated.connect(_on_context_updated)
	GameEvents.time_updated.connect(_on_time_updated)
	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.day_phase_changed.connect(_on_phase_changed)
	GameEvents.ui_mode_changed.connect(_on_ui_mode_changed)

	var sm = get_node_or_null("/root/SettingsManager")
	var initial_mobile: bool = sm.is_mobile_ui() if sm and sm.has_method("is_mobile_ui") else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_on_ui_mode_changed(initial_mobile)

	_update_quest_display()

	if GameEvents.has_signal("night_raid_started"):
		GameEvents.night_raid_started.connect(_on_night_raid_started)
	if GameEvents.has_signal("breach_alarm_triggered"):
		GameEvents.breach_alarm_triggered.connect(_on_breach_alarm)

	var topo := get_node_or_null("/root/WorldTopography")
	if topo:
		topo.zone_entered.connect(_on_zone_entered)
		topo.poi_discovered.connect(_on_poi_discovered)
		if zone_label:
			zone_label.text = "[ %s ]" % topo.get_current_zone_name()

	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		inv.notification_message.connect(_on_inventory_notification)

	if raid_banner:
		raid_banner.visible = false

	var touch_toggle_btn := find_child("TouchToggleButton", true, false) as Button
	if touch_toggle_btn:
		touch_toggle_btn.pressed.connect(func():
			var tc := get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc and tc.has_method("toggle_touch_controls"):
				tc.toggle_touch_controls()
				var active_text := "🎮 Сенсор: ВКЛ" if tc.visible else "🎮 Сенсор: ВЫКЛ"
				touch_toggle_btn.text = active_text
		)

	# Подключение к WeaponManager на игроке
	_connect_weapon_manager()

func _connect_weapon_manager() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var wm := player.find_child("HandSlot", true, false) as PlayerWeaponManager
		if wm:
			wm.weapon_switched.connect(_on_weapon_switched)
			_on_weapon_switched("Топор Егеря", 1)

func _on_ui_mode_changed(is_mobile: bool) -> void:
	_is_mobile = is_mobile

	# 1. Кнопка ручного переключения сенсора (нужна только на ПК для тестирования)
	var touch_toggle_btn := find_child("TouchToggleButton", true, false) as Button
	if touch_toggle_btn:
		touch_toggle_btn.visible = not _is_mobile
		if not _is_mobile:
			var sm = get_node_or_null("/root/SettingsManager")
			var is_touch_active: bool = sm.touch_controls_enabled if sm else false
			touch_toggle_btn.text = "🎮 Сенсор: ВКЛ" if is_touch_active else "🎮 Сенсор: ВЫКЛ"

	# 2. Кнопка планшета
	var tablet_btn := find_child("TabletButton", true, false) as Button
	if tablet_btn:
		if _is_mobile:
			tablet_btn.text = "📱 Планшет"
		else:
			tablet_btn.text = "Планшет [Tab]"

	# 3. Прицел (на ПК четкий для мыши, на мобилках полупрозрачный/минималистичный)
	var crosshair = find_child("Crosshair", true, false)
	if crosshair:
		crosshair.modulate.a = 0.35 if _is_mobile else 0.85

	# 4. Обновляем надписи
	_render_weapon_label()
	_render_context_prompt()
	_render_mode_label()

func _render_weapon_label() -> void:
	if weapon_label:
		if _is_mobile:
			weapon_label.text = _cached_weapon_name
		else:
			weapon_label.text = "[%d] %s" % [_cached_weapon_slot, _cached_weapon_name]

func _render_context_prompt() -> void:
	if context_prompt_label:
		if _cached_action_title.is_empty():
			context_prompt_label.visible = false
		else:
			context_prompt_label.visible = true
			if _is_mobile:
				context_prompt_label.text = _cached_action_title
			else:
				context_prompt_label.text = "[E] " + _cached_action_title

func _render_mode_label() -> void:
	if not mode_label:
		return
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		if _is_mobile:
			mode_label.text = "Режим строительства (Планшет)"
		else:
			mode_label.text = "Режим архитектора (1..5 - Чертежи | R - Поворот | ЛКМ - Поставить | Tab - Выход)"
	else:
		if _is_mobile:
			mode_label.text = "Вид от 1-го лица"
		else:
			mode_label.text = "Вид от 1-го лица (Q - Инвентарь, Tab - Планшет, 1..5 - Хотбар, Shift - Бег)"

func _on_weapon_switched(weapon_name: String, slot_idx: int) -> void:
	_cached_weapon_name = weapon_name
	_cached_weapon_slot = slot_idx
	_render_weapon_label()

func _on_zone_entered(_zone: int, zone_name: String) -> void:
	if zone_label:
		zone_label.text = "[ %s ]" % zone_name

func _on_poi_discovered(_poi_id: String, poi_name: String) -> void:
	if context_prompt_label:
		context_prompt_label.visible = true
		context_prompt_label.text = "★ Найдено: " + poi_name
		var timer := get_tree().create_timer(3.5)
		timer.timeout.connect(func():
			if is_instance_valid(context_prompt_label) and context_prompt_label.text.begins_with("★"):
				context_prompt_label.visible = false
		)

func _on_stats_updated(hp: float, stamina: float, max_stamina: float, _hunger: float) -> void:
	if hp_bar:
		hp_bar.update_value(hp, 100.0)
	if stamina_bar:
		stamina_bar.update_value(stamina, max_stamina)

func _on_logs_changed(current: int, max_cap: int) -> void:
	if logs_label:
		logs_label.text = "Бревна на плече: %d / %d" % [current, max_cap]

func _on_context_updated(action_title: String, _target: Node) -> void:
	_cached_action_title = action_title
	_render_context_prompt()

func _on_time_updated(hours: int, minutes: int, phase: int) -> void:
	if time_label:
		var phase_name := "День"
		match phase:
			GameEnums.DayPhase.DAWN: phase_name = "Рассвет"
			GameEnums.DayPhase.DAY: phase_name = "День"
			GameEnums.DayPhase.DUSK: phase_name = "Сумерки"
			GameEnums.DayPhase.NIGHT: phase_name = "Ночь"
		time_label.text = "%02d:%02d | %s" % [hours, minutes, phase_name]

func _on_camera_mode_changed(mode: int) -> void:
	_current_camera_mode = mode
	var is_fpv := (mode == GameEnums.CameraMode.FPV)
	var crosshair = find_child("Crosshair", true, false)
	if crosshair:
		crosshair.visible = is_fpv
		crosshair.modulate.a = 0.35 if _is_mobile else 0.85
	var bottom_left = find_child("BottomLeft", true, false)
	if bottom_left:
		bottom_left.visible = is_fpv
	if not is_fpv and context_prompt_label:
		context_prompt_label.visible = false

	_render_mode_label()

func _on_inventory_notification(msg: String, is_warning: bool) -> void:
	if not context_prompt_label:
		return
	context_prompt_label.visible = true
	context_prompt_label.text = msg
	context_prompt_label.modulate = Color(1.0, 0.35, 0.35) if is_warning else Color(0.4, 0.9, 0.5)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(context_prompt_label) and context_prompt_label.text == msg:
			context_prompt_label.visible = false
			context_prompt_label.modulate = Color.WHITE
	)

func _on_phase_changed(_phase: int) -> void:
	_update_quest_display()

func _update_quest_display() -> void:
	if not quest_label:
		return
	var current_day := 1
	var world := get_tree().current_scene
	if world:
		var tm := world.get_node_or_null("TimeManager") as TimeManager
		if tm:
			current_day = tm.current_day
	var key := "quest_day%d" % clampi(current_day, 1, 5)
	quest_label.text = LocalizationData.get_text(key)

func _on_night_raid_started(wave_count: int) -> void:
	if raid_banner:
		raid_banner.visible = true
		raid_banner.text = "⚠ ТРЕВОГА: НОЧНОЙ ШТУРМ! ВОЛНА (%d ТВАРЕЙ) ⚠" % wave_count
		raid_banner.modulate = Color(1.0, 0.25, 0.25)
		var tween := create_tween().set_loops(4)
		tween.tween_property(raid_banner, "modulate:a", 0.3, 0.4)
		tween.tween_property(raid_banner, "modulate:a", 1.0, 0.4)
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(raid_banner):
				raid_banner.visible = false
		)

func _on_breach_alarm(_loc: Vector3) -> void:
	if raid_banner:
		raid_banner.visible = true
		raid_banner.text = "🚨 ВНИМАНИЕ: ЗАБОР ПРОЛОМЛЕН! ОНИ ВО ДВОРЕ! 🚨"
		raid_banner.modulate = Color(1.0, 0.1, 0.1)
		var tween := create_tween().set_loops(5)
		tween.tween_property(raid_banner, "modulate:a", 0.2, 0.3)
		tween.tween_property(raid_banner, "modulate:a", 1.0, 0.3)
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(raid_banner):
				raid_banner.visible = false
		)
