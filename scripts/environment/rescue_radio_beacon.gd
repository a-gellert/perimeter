class_name RescueRadioBeacon
extends StaticBody3D
## Emergency Radio Relay on the Northern Ridge.
## Serves as the endgame objective:
## 1. Repair generator: 2 Fuel canisters, 10 Scrap, 2 Tectonic Amber.
## 2. Broadcast SOS signal: triggers a defensive siege until dawn.
## 3. Evacuation arrival at Dawn triggers the Victory screen!

signal signal_broadcast_started
signal evacuation_completed

@export var required_fuel: int = 2
@export var required_scrap: int = 10
@export var required_amber: int = 2

@export var radio_mast_light: OmniLight3D
@export var antenna_particles: CPUParticles3D

var current_fuel: int = 0
var current_scrap: int = 0
var current_amber: int = 0

var is_repaired: bool = false
var is_broadcasting: bool = false

func _ready() -> void:
	if radio_mast_light:
		radio_mast_light.visible = false
	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("day_phase_changed"):
		bus.day_phase_changed.connect(_on_day_phase_changed)

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not is_repaired:
		var eco := get_node_or_null("/root/EconomyManager")
		if eco:
			if eco.player_fuel > 0 and current_fuel < required_fuel:
				return { "prompt": "Залить топливо в радиомаяк (%d/%d)" % [current_fuel, required_fuel], "type": "REPAIR" }
			elif eco.player_scrap > 0 and current_scrap < required_scrap:
				return { "prompt": "Починить проводку металлом (%d/%d)" % [current_scrap, required_scrap], "type": "REPAIR" }
			elif eco.base_storage.get("amber", 0) > 0 and current_amber < required_amber:
				return { "prompt": "Вставить кристалл янтаря в передатчик (%d/%d)" % [current_amber, required_amber], "type": "REPAIR" }
		return {
			"prompt": "Аварийный маяк: нужно %d топл., %d мет., %d янт." % [required_fuel, required_scrap, required_amber],
			"type": "NEED_RESOURCES"
		}
	else:
		if not is_broadcasting:
			return { "prompt": "Подать сигнал эвакуации SOS (Штурм до рассвета!)", "type": "SOS" }
		else:
			return { "prompt": "Сигнал в эфире. Обороняйте кордон до рассвета!", "type": "BROADCASTING" }

func interact(player: PlayerController) -> void:
	var eco := get_node_or_null("/root/EconomyManager")
	if not is_repaired:
		if not eco:
			return
		if eco.player_fuel > 0 and current_fuel < required_fuel:
			eco.player_fuel -= 1
			current_fuel += 1
			eco.resources_updated.emit()
		elif eco.player_scrap > 0 and current_scrap < required_scrap:
			if eco.use_scrap(1):
				current_scrap += 1
		elif eco.base_storage.get("amber", 0) > 0 and current_amber < required_amber:
			eco.base_storage["amber"] -= 1
			current_amber += 1
			eco.resources_updated.emit()

		if current_fuel >= required_fuel and current_scrap >= required_scrap and current_amber >= required_amber:
			is_repaired = true
			if radio_mast_light:
				radio_mast_light.visible = true
			print("[RescueBeacon] Radio beacon fully repaired! Ready to broadcast SOS.")
	else:
		if not is_broadcasting:
			start_broadcast()

func start_broadcast() -> void:
	is_broadcasting = true
	if radio_mast_light:
		radio_mast_light.light_color = Color(1.0, 0.2, 0.2)
		radio_mast_light.light_energy = 6.0

	# Громкий сигнал тревоги
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 80.0)

	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("breach_alarm_triggered"):
		bus.breach_alarm_triggered.emit(global_position)

	signal_broadcast_started.emit()
	print("[RescueBeacon] SOS Broadcast transmitted! Hold out until dawn!")

func _on_day_phase_changed(phase: int) -> void:
	# Если сигнал был передан и наступает рассвет — ПОБЕДА!
	if is_broadcasting and phase == GameEnums.DayPhase.DAWN:
		_trigger_evacuation_victory()

func _trigger_evacuation_victory() -> void:
	evacuation_completed.emit()
	print("[RescueBeacon] Dawn reached! Evacuation helicopter arrived. VICTORY!")
	
	# Показываем экран победы
	var victory_overlay := CanvasLayer.new()
	victory_overlay.layer = 100
	var label := Label.new()
	label.text = "ЭВАКУАЦИЯ УСПЕШНА!\nВЫ СПАСЛИ КОРДОН И ВЫЖИВШИХ!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	victory_overlay.add_child(label)
	get_tree().root.add_child(victory_overlay)
