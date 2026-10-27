class_name HUDController
extends Control
## Central HUD coordinator listening to decoupled GameEvents.

@export var hp_bar: StatsBar
@export var stamina_bar: StatsBar
@export var logs_label: Label
@export var time_label: Label
@export var context_prompt_label: Label
@export var mode_label: Label
@export var zone_label: Label

func _ready() -> void:
	GameEvents.stats_updated.connect(_on_stats_updated)
	GameEvents.logs_carried_changed.connect(_on_logs_changed)
	GameEvents.context_action_updated.connect(_on_context_updated)
	GameEvents.time_updated.connect(_on_time_updated)
	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)

	if Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography"):
		WorldTopography.zone_entered.connect(_on_zone_entered)
		WorldTopography.poi_discovered.connect(_on_poi_discovered)
		if zone_label:
			zone_label.text = "[ %s ]" % WorldTopography.get_current_zone_name()

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
	if context_prompt_label:
		if action_title.is_empty():
			context_prompt_label.visible = false
		else:
			context_prompt_label.visible = true
			context_prompt_label.text = "[E] " + action_title

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
	if mode_label:
		if mode == GameEnums.CameraMode.ARCHITECT:
			mode_label.text = "[ПЛАНШЕТ ЕГЕРЯ: РЕЖИМ АРХИТЕКТОРА] (Tab - выход)"
		else:
			mode_label.text = "Вид от первого лица (Tab - Планшет)"
