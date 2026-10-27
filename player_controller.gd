class_name PlayerController
extends CharacterBody3D

# --- СИГНАЛЫ ДЛЯ UI И МЕНЕДЖЕРОВ ---
signal stats_changed(hp: float, stamina: float, fatigue: float, hunger: float)
signal carried_logs_changed(count: int, max_count: int)
signal noise_emitted(world_pos: Vector3, radius: float)
signal interaction_target_changed(prompt_text: String, action_type: String)

# --- ПАРАМЕТРЫ ДВИЖЕНИЯ ---
@export_group("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
@export var acceleration: float = 12.0
@export var gravity: float = 18.0

# --- ПАРАМЕТРЫ ХАРАКТЕРИСТИК ---
@export_group("Stats & Limits")
@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
@export var max_carried_logs: int = 3

# --- ПАРАМЕТРЫ ШУМА ---
@export_group("Noise Radii (Meters)")
@export var noise_walk: float = 5.0
@export var noise_sprint: float = 12.0
@export var noise_chop: float = 22.0
@export var noise_shoot: float = 45.0

# --- УПРАВЛЕНИЕ КАМЕРОЙ / ОБЗОРОМ (ПК) ---
@export_group("Look")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = 85.0

# --- ТЕКУЩЕЕ СОСТОЯНИЕ ---
var hp: float = 100.0
var stamina: float = 100.0
var fatigue: float = 0.0     # 0 (бодр) .. 100 (валится с ног)
var hunger: float = 100.0    # 100 (сыт) .. 0 (голоден)
var carried_logs: int = 0

var is_sprinting: bool = false
var is_building_mode: bool = false
var current_interactable: Node = null
var _pitch: float = 0.0

# Свойства для обратной совместимости с существующими системами
var stats: PlayerController:
	get: return self
var carrier: PlayerController:
	get: return self

# --- ССЫЛКИ НА НОДЫ ---
@onready var head: Node3D = $Head
@onready var fpv_camera: Camera3D = $Head/FPVCamera
@onready var interaction_ray: RayCast3D = $Head/InteractionRay
@onready var log_meshes: Array[MeshInstance3D] = [
	$ShoulderLogSlot/LogMesh1,
	$ShoulderLogSlot/LogMesh2,
	$ShoulderLogSlot/LogMesh3
]

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	stamina = max_stamina
	var eco: Node = get_node_or_null("/root/EconomyManager")
	if eco:
		carried_logs = eco.player_logs
		max_carried_logs = eco.max_shoulder_logs
	_update_log_visuals()
	emit_signal("stats_changed", hp, stamina, fatigue, hunger)
	_setup_bus_connections()
	_setup_topography()

func _setup_topography() -> void:
	var topo_timer := Timer.new()
	topo_timer.name = "TopographyTimer"
	topo_timer.wait_time = 0.5
	topo_timer.autostart = true
	topo_timer.timeout.connect(_on_topography_timer_timeout)
	add_child(topo_timer)

func _setup_bus_connections() -> void:
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus:
		stats_changed.connect(func(h: float, s: float, _f: float, hung: float) -> void:
			if bus.has_signal("stats_updated"):
				bus.stats_updated.emit(h, s, max_stamina, hung)
		)
		carried_logs_changed.connect(func(cnt: int, max_cnt: int) -> void:
			if bus.has_signal("logs_carried_changed"):
				bus.logs_carried_changed.emit(cnt, max_cnt)
		)
		interaction_target_changed.connect(func(prompt: String, _type: String) -> void:
			if bus.has_signal("context_action_updated"):
				bus.context_action_updated.emit(prompt, current_interactable)
		)
		if bus.has_signal("camera_mode_changed"):
			bus.camera_mode_changed.connect(func(mode: int) -> void:
				set_building_mode(mode == GameEnums.CameraMode.ARCHITECT)
			)
		if bus.has_signal("stats_updated"):
			bus.stats_updated.emit(hp, stamina, max_stamina, hunger)
		if bus.has_signal("logs_carried_changed"):
			bus.logs_carried_changed.emit(carried_logs, max_carried_logs)

func _physics_process(dt: float) -> void:
	if is_building_mode:
		return # При виде сверху персонаж замирает, физику не крутим

	_apply_gravity(dt)
	_handle_movement(dt)

	# 1. Проверка зоны и штраф за уклон
	if is_on_floor() and (Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography")):
		var current_floor_normal: Vector3 = get_floor_normal()
		var slope_severity: float = WorldTopography.evaluate_slope(current_floor_normal)

		# Подъем по крутому серпантину к скалам расходует больше сил
		if slope_severity > 0.25 and velocity.length() > 0.5:
			stamina = max(0.0, stamina - (15.0 * slope_severity) * dt)

	_update_vitals(dt)
	_check_interaction()

# 2. Обновление зоны и открытие точек интереса каждые 0.5 секунды
func _on_topography_timer_timeout() -> void:
	if not Engine.has_singleton("WorldTopography") and not get_node_or_null("/root/WorldTopography"):
		return
	var new_zone: WorldZoneManager.ZoneType = WorldTopography.get_zone_at_position(global_position)
	if new_zone != WorldTopography.current_zone:
		WorldTopography.current_zone = new_zone
		WorldTopography.emit_signal("zone_entered", new_zone, WorldTopography.get_zone_display_name(new_zone))
	
	WorldTopography.check_poi_proximity(global_position)

func _unhandled_input(event: InputEvent) -> void:
	if is_building_mode:
		if event.is_action_pressed("toggle_tablet"):
			_toggle_tablet_mode()
		return

	if event.is_action_pressed("interact"):
		perform_context_action()

	if event.is_action_pressed("toggle_tablet"):
		_toggle_tablet_mode()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		if head:
			head.rotation.x = _pitch

func _toggle_tablet_mode() -> void:
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("request_mode_switch"):
		var new_mode: int = GameEnums.CameraMode.ARCHITECT if not is_building_mode else GameEnums.CameraMode.FPV
		bus.request_mode_switch.emit(new_mode)
	else:
		set_building_mode(not is_building_mode)

# ==============================================================================
# 1. ДВИЖЕНИЕ, СПРИНТ И УСТАЛОСТЬ
# ==============================================================================
func _handle_movement(dt: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Спринт блокируется при нулевой стамине или переноске бревен
	var can_sprint: bool = Input.is_action_pressed("sprint") and stamina > 5.0 and carried_logs == 0 and input_dir.y < 0
	is_sprinting = can_sprint

	# Скорость режется от усталости и веса бревен на плече
	var speed: float = sprint_speed if is_sprinting else walk_speed
	if carried_logs > 0:
		speed *= (1.0 - carried_logs * 0.15) # 3 бревна = -45% скорости
	if fatigue > 70.0:
		speed *= 0.7 # Истощение к ночи

	if move_direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, move_direction.x * speed, acceleration * dt)
		velocity.z = lerp(velocity.z, move_direction.z * speed, acceleration * dt)
		
		# Расход стамины и шум
		if is_sprinting:
			stamina = max(0.0, stamina - 18.0 * dt)
			_emit_noise(noise_sprint * dt)
		else:
			_emit_noise(noise_walk * dt)
	else:
		velocity.x = lerp(velocity.x, 0.0, acceleration * dt)
		velocity.z = lerp(velocity.z, 0.0, acceleration * dt)

	move_and_slide()

func _apply_gravity(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * dt
	else:
		velocity.y = 0.0

# ==============================================================================
# 2. ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ (VITALS)
# ==============================================================================
func _update_vitals(dt: float) -> void:
	# Восстановление стамины
	if not is_sprinting and stamina < max_stamina:
		var recovery_rate: float = 20.0
		if hunger < 20.0: recovery_rate *= 0.5 # При голоде стамина восстанавливается вдвое медленнее
		stamina = min(max_stamina, stamina + recovery_rate * dt)

	# Пассивный голод (100% за ~20 минут реального времени)
	hunger = max(0.0, hunger - 0.08 * dt)

	# Пассивная регенерация HP при хорошем питании
	if hunger > 60.0 and hp < max_hp:
		hp = min(max_hp, hp + 0.5 * dt)

	emit_signal("stats_changed", hp, stamina, fatigue, hunger)

func add_fatigue(amount: float) -> void:
	fatigue = clamp(fatigue + amount, 0.0, 100.0)
	emit_signal("stats_changed", hp, stamina, fatigue, hunger)

func sleep_and_restore(hours: int) -> void:
	# 8 часов сна полностью сбрасывают 100 усталости
	var fatigue_recovered: float = (float(hours) / 8.0) * 100.0
	fatigue = max(0.0, fatigue - fatigue_recovered)
	stamina = max_stamina
	# Сон расходует часть еды
	hunger = max(0.0, hunger - hours * 3.0)
	emit_signal("stats_changed", hp, stamina, fatigue, hunger)

func take_damage(amount: float) -> void:
	hp = max(0.0, hp - amount)
	emit_signal("stats_changed", hp, stamina, fatigue, hunger)

# ==============================================================================
# 3. ИНТЕРАКЦИЯ И КОНТЕКСТНАЯ КНОПКА (УМНЫЙ ТАЧ)
# ==============================================================================
func _check_interaction() -> void:
	if interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		var target: Object = null
		if collider:
			if collider.has_method("get_interaction_info"):
				target = collider
			else:
				for child in collider.get_children():
					if child.has_method("get_interaction_info"):
						target = child
						break
				if not target and collider.get_parent() and collider.get_parent().has_method("get_interaction_info"):
					target = collider.get_parent()

		if target:
			current_interactable = target
			var info: Dictionary = target.get_interaction_info(self)
			emit_signal("interaction_target_changed", info.get("prompt", ""), info.get("type", ""))
			return

	current_interactable = null
	emit_signal("interaction_target_changed", "", "")

# Вызывается UI-кнопкой действия справа на экране (или клавишей E на ПК)
func perform_context_action() -> void:
	if current_interactable and current_interactable.has_method("interact"):
		current_interactable.interact(self)

# ==============================================================================
# 4. ЛОГИКА ПЕРЕНОСКИ БРЕВЕН (THE FOREST MECHANIC - ПЕРЕНОС НА ПЛЕЧЕ)
# ==============================================================================
func can_pickup_log() -> bool:
	var eco: Node = get_node_or_null("/root/EconomyManager")
	if eco:
		return eco.can_pickup_log()
	return carried_logs < max_carried_logs

func has_logs() -> bool:
	return carried_logs > 0

func pickup_log() -> bool:
	var eco: Node = get_node_or_null("/root/EconomyManager")
	if eco:
		if eco.pickup_log():
			carried_logs = eco.player_logs
			_update_log_visuals()
			emit_signal("carried_logs_changed", carried_logs, max_carried_logs)
			return true
		return false
	if carried_logs < max_carried_logs:
		carried_logs += 1
		_update_log_visuals()
		emit_signal("carried_logs_changed", carried_logs, max_carried_logs)
		return true
	return false

func deposit_logs_to_base() -> int:
	var eco: Node = get_node_or_null("/root/EconomyManager")
	var deposited: int = 0
	if eco:
		deposited = eco.deposit_logs_to_base()
		carried_logs = eco.player_logs
	else:
		deposited = carried_logs
		carried_logs = 0
	_update_log_visuals()
	emit_signal("carried_logs_changed", carried_logs, max_carried_logs)
	return deposited

func add_log() -> bool:
	return pickup_log()

func remove_log() -> bool:
	var eco: Node = get_node_or_null("/root/EconomyManager")
	if eco:
		if eco.player_logs > 0:
			eco.player_logs -= 1
			carried_logs = eco.player_logs
			eco.emit_signal("resources_updated")
			_update_log_visuals()
			emit_signal("carried_logs_changed", carried_logs, max_carried_logs)
			return true
		return false
	if carried_logs > 0:
		carried_logs -= 1
		_update_log_visuals()
		emit_signal("carried_logs_changed", carried_logs, max_carried_logs)
		return true
	return false

func _update_log_visuals() -> void:
	if log_meshes.is_empty() or log_meshes[0] == null:
		var slot: Node = get_node_or_null("ShoulderLogSlot")
		if slot:
			log_meshes = [
				slot.get_node_or_null("LogMesh1") as MeshInstance3D,
				slot.get_node_or_null("LogMesh2") as MeshInstance3D,
				slot.get_node_or_null("LogMesh3") as MeshInstance3D
			]
	for i in range(log_meshes.size()):
		if log_meshes[i]:
			log_meshes[i].visible = (i < carried_logs)

# ==============================================================================
# 5. СИСТЕМА ШУМА ДЛЯ СПЯЩИХ МУТАНТОВ
# ==============================================================================
func _emit_noise(radius: float) -> void:
	var pos: Vector3 = global_position if is_inside_tree() else position
	emit_signal("noise_emitted", pos, radius)
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(pos, radius)

# ==============================================================================
# 6. ПЕРЕКЛЮЧЕНИЕ В «РЕЖИМ АРХИТЕКТОРА» (ВИД СВЕРХУ)
# ==============================================================================
func set_building_mode(enabled: bool) -> void:
	is_building_mode = enabled
	if fpv_camera:
		fpv_camera.current = !enabled
	# Визуальные бревна скрываем на время вида сверху, чтобы не мелькали
	var slot: Node3D = get_node_or_null("ShoulderLogSlot")
	if slot:
		slot.visible = !enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
