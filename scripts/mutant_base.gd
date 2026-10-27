class_name MutantBase
extends CharacterBody3D
## Base class for infected mutants in the valley.
## Implements FSM: Hibernation cocoon during daylight, Night prowler under the moon,
## and severe photophobic UV thermal shock in direct sunlight.

enum State { HIBERNATION, NIGHT_PROWLER, ALERTED, COMBAT, UV_STUNNED }

# --- ХАРАКТЕРИСТИКИ ---
@export_group("Stats")
@export var max_health: float = 80.0
@export var patrol_speed: float = 2.2
@export var chase_speed: float = 5.8
@export var uv_damage_per_sec: float = 35.0
@export var attack_damage: float = 18.0
@export var attack_cooldown_time: float = 1.2

# --- СЕНСОРЫ ВРАГА (ПРИЕМНИКИ РАЗДРАЖИТЕЛЕЙ) ---
@export_group("Senses")
@export var hearing_sensitivity: float = 1.0    # Множитель восприятия звука
@export var heat_detect_range: float = 25.0     # Дистанция реакции на топку печи/костер
@export var food_scent_range: float = 18.0      # Реакция на жарку рыбы/мяса

var current_state: State = State.HIBERNATION
var health: float = 80.0
var target_stimulus_pos: Vector3 = Vector3.ZERO
var current_target: Node3D = null
var attack_cooldown: float = 0.0
var _original_mesh_pos: Vector3 = Vector3.ZERO

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	health = max_health
	add_to_group("mutants")
	if body_mesh:
		_original_mesh_pos = body_mesh.position
	
	if has_node("/root/ValleyEcology"):
		ValleyEcology.day_phase_changed.connect(_on_day_phase_changed)
	_evaluate_initial_state()

func _physics_process(dt: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	# 1. ПРОВЕРКА УЛЬТРАФИОЛЕТОВОГО ТЕРМИЧЕСКОГО ШОКА
	if has_node("/root/ValleyEcology") and ValleyEcology.is_in_direct_sunlight(global_position, space_state):
		_apply_uv_thermal_shock(dt)
		return
	else:
		if current_state == State.UV_STUNNED:
			# Выход из прямого солнечного света (ушел в тень или наступила ночь)
			if body_mesh:
				body_mesh.position = _original_mesh_pos
			if has_node("/root/ValleyEcology") and ValleyEcology.is_night:
				_wake_up_to_hunt()
			else:
				_fall_into_hibernation()

	# 2. ВЫПОЛНЕНИЕ ТЕКУЩЕГО СОСТОЯНИЯ FSM
	match current_state:
		State.HIBERNATION:
			_process_hibernation()
		State.NIGHT_PROWLER:
			_process_night_hunt(dt)
		State.ALERTED:
			_move_to_point(target_stimulus_pos, patrol_speed, dt)
			if global_position.distance_to(target_stimulus_pos) < 2.0:
				if has_node("/root/ValleyEcology") and ValleyEcology.is_night:
					current_state = State.NIGHT_PROWLER
				else:
					_fall_into_hibernation()
		State.COMBAT:
			_process_combat(dt)
		State.UV_STUNNED:
			# Мутант корчится в параличе от света прожектора/солнца
			velocity = Vector3.ZERO
			if not is_on_floor():
				velocity.y -= 18.0 * dt
			move_and_slide()

# ==============================================================================
# БИОЛОГИЧЕСКИЕ РЕАКЦИИ: ДЕНЬ VS НОЧЬ
# ==============================================================================
func _evaluate_initial_state() -> void:
	if has_node("/root/ValleyEcology") and ValleyEcology.is_night:
		_wake_up_to_hunt()
	else:
		_fall_into_hibernation()

func _on_day_phase_changed(is_night_time: bool, _uv: float) -> void:
	if is_night_time:
		_wake_up_to_hunt()
	else:
		_fall_into_hibernation()

func _fall_into_hibernation() -> void:
	current_state = State.HIBERNATION
	velocity = Vector3.ZERO
	# Визуально каменеет под цвет сухой коры/кокона
	if body_mesh:
		body_mesh.scale = Vector3(0.9, 0.85, 0.9) # Сжатие туловища
		body_mesh.position = _original_mesh_pos

func _wake_up_to_hunt() -> void:
	if current_state == State.HIBERNATION or current_state == State.UV_STUNNED:
		current_state = State.NIGHT_PROWLER
		if body_mesh:
			body_mesh.scale = Vector3.ONE
			body_mesh.position = _original_mesh_pos

# Солнечный ожог и паралич нервной системы
func _apply_uv_thermal_shock(dt: float) -> void:
	current_state = State.UV_STUNNED
	health -= uv_damage_per_sec * dt
	velocity = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	move_and_slide()
	
	# Конвульсии и паралич от ультрафиолета
	if body_mesh:
		body_mesh.position = _original_mesh_pos + Vector3(
			randf_range(-0.04, 0.04),
			randf_range(-0.02, 0.02),
			randf_range(-0.04, 0.04)
		)
	
	if health <= 0.0:
		_die_from_light()

# ==============================================================================
# ВОСПРИЯТИЕ РАЗДРАЖИТЕЛЕЙ: ЗВУК, ТЕПЛО И ЕДА
# ==============================================================================

# Вызывается игроком (рубка, шаги, выстрелы)
func hear_noise(noise_origin: Vector3, noise_radius: float) -> void:
	var dist: float = global_position.distance_to(noise_origin)
	if dist <= (noise_radius * hearing_sensitivity):
		target_stimulus_pos = noise_origin
		if current_state == State.HIBERNATION:
			# Днем разбудить можно только сильным шумом в упор
			if dist < 6.0 or noise_radius >= 40.0:
				current_state = State.ALERTED
				if body_mesh:
					body_mesh.scale = Vector3.ONE
		else:
			current_state = State.ALERTED

# Вызывается лагерем егеря (дым из трубы печи ночью или готовка еды)
func sense_camp_heat_or_food(camp_pos: Vector3, stimulus_type: String) -> void:
	if has_node("/root/ValleyEcology") and not ValleyEcology.is_night:
		return # Днем в анабиозе тепло не привлекает

	var dist: float = global_position.distance_to(camp_pos)
	var max_range: float = heat_detect_range if stimulus_type == "HEAT" else food_scent_range

	if dist <= max_range:
		target_stimulus_pos = camp_pos
		current_state = State.ALERTED
		if body_mesh:
			body_mesh.scale = Vector3.ONE

# ==============================================================================
# НАВИГАЦИЯ И БОЙ
# ==============================================================================
func _process_hibernation() -> void:
	velocity = Vector3.ZERO
	move_and_slide()

func _process_night_hunt(dt: float) -> void:
	# Если целей нет — мутант медленно крадется по низинам к лагерю
	if current_target:
		current_state = State.COMBAT
		return
	
	# Поиск ближайшего игрока или шума
	_scan_for_targets()
	if current_target:
		current_state = State.COMBAT
	else:
		velocity.x = move_toward(velocity.x, 0.0, patrol_speed * dt)
		velocity.z = move_toward(velocity.z, 0.0, patrol_speed * dt)
		if not is_on_floor():
			velocity.y -= 18.0 * dt
		move_and_slide()

func _process_combat(dt: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - dt)
	if not is_instance_valid(current_target):
		current_target = null
		current_state = State.NIGHT_PROWLER
		return

	_move_to_point(current_target.global_position, chase_speed, dt)
	if global_position.distance_to(current_target.global_position) < 1.8:
		if attack_cooldown <= 0.0:
			_attack_target()
			attack_cooldown = attack_cooldown_time

func _move_to_point(target_pos: Vector3, speed: float, _dt: float) -> void:
	var move_dest: Vector3 = target_pos
	if nav_agent:
		nav_agent.target_position = target_pos
		if not nav_agent.is_navigation_finished():
			var next_pos: Vector3 = nav_agent.get_next_path_position()
			if next_pos != Vector3.ZERO:
				move_dest = next_pos

	var diff: Vector3 = move_dest - global_position
	diff.y = 0.0
	
	if diff.length() > 0.2:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var look_target := global_position + Vector3(dir.x, 0.0, dir.z)
		look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	if not is_on_floor():
		velocity.y -= 18.0 * _dt
	move_and_slide()

func _scan_for_targets() -> void:
	# Проверка дистанции до игрока в группе "player"
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: CharacterBody3D = players[0] as CharacterBody3D
		if p and global_position.distance_to(p.global_position) < 15.0:
			current_target = p
			return
	
	# Запасной поиск игрока в текущей сцене
	var current_scene := get_tree().current_scene
	if current_scene:
		var p := current_scene.get_node_or_null("Player") as CharacterBody3D
		if p and global_position.distance_to(p.global_position) < 15.0:
			current_target = p

func _attack_target() -> void:
	if not current_target:
		return
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
	elif current_target.get("stats") and current_target.stats.has_method("take_damage"):
		current_target.stats.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	health -= amount
	# При получении урона мутант просыпается и контратакует
	if current_state == State.HIBERNATION:
		current_state = State.ALERTED
		if body_mesh:
			body_mesh.scale = Vector3.ONE
	
	# Визуальная вспышка боли
	if body_mesh:
		var tw := create_tween()
		tw.tween_property(body_mesh, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
		tw.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)

	if health <= 0.0:
		queue_free()

func _die_from_light() -> void:
	# Падение замертво от света и оставление споровых желез
	queue_free()
