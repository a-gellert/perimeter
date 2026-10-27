class_name WildAnimal
extends CharacterBody3D
## AI for peaceful valley fauna (deer, hares, etc.).
## Driven by height instinct: avoids heavy spore fog basins and grazes on wind-swept ridges
## or along clean glacial rivers.

@export var safe_altitude: float = 8.0 # Минимальная высота обитания
@export var run_speed: float = 7.5
@export var graze_speed: float = 1.8
@export var max_health: float = 40.0

var health: float = 40.0
var fear_vector: Vector3 = Vector3.ZERO
var _graze_timer: float = 0.0
var _graze_dir: Vector3 = Vector3.ZERO
var _flee_rethink_timer: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	health = max_health
	add_to_group("wild_animals")

func _physics_process(dt: float) -> void:
	# Животное ежесекундно оценивает зараженность точки через экологический менеджер
	var current_toxicity: float = 0.0
	if has_node("/root/ValleyEcology"):
		current_toxicity = ValleyEcology.get_spore_concentration(global_position)
	elif global_position.y < safe_altitude:
		current_toxicity = 0.5 # Запасной расчет при отсутствии синглтона

	# Если попало в овраг с туманом (> 0.25) — инстинктивно бежит вверх по склону на продуваемый хребет!
	if current_toxicity > 0.25:
		_flee_to_high_ground(dt)
	else:
		_graze(dt)

func _flee_to_high_ground(dt: float) -> void:
	_flee_rethink_timer -= dt
	if _flee_rethink_timer <= 0.0 or fear_vector == Vector3.ZERO:
		_flee_rethink_timer = randf_range(0.5, 1.0)
		fear_vector = _calculate_best_escape_direction()

	velocity.x = fear_vector.x * run_speed
	velocity.z = fear_vector.z * run_speed
	
	if not is_on_floor():
		velocity.y -= 18.0 * dt

	_face_direction(fear_vector)
	move_and_slide()

func _calculate_best_escape_direction() -> Vector3:
	# 1. Поиск направления с минимальной концентрацией спор (подъем в гору или к реке)
	if has_node("/root/ValleyEcology"):
		var best_dir: Vector3 = Vector3.ZERO
		var min_tox: float = ValleyEcology.get_spore_concentration(global_position)
		var test_dist: float = 6.0
		
		# Проверяем 8 радиальных направлений
		for i in range(8):
			var angle: float = i * (TAU / 8.0)
			var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * test_dist
			var sample_pos: Vector3 = global_position + offset
			var tox: float = ValleyEcology.get_spore_concentration(sample_pos)
			if tox < min_tox:
				min_tox = tox
				best_dir = offset.normalized()

		if best_dir != Vector3.ZERO:
			return best_dir

		# 2. Если все точки на одном уровне, проверяем ближайшую реку
		if ValleyEcology.river_points.size() > 0:
			var nearest_pt: Vector3 = ValleyEcology.river_points[0]
			var min_dist: float = global_position.distance_to(nearest_pt)
			for pt in ValleyEcology.river_points:
				var d: float = global_position.distance_to(pt)
				if d < min_dist:
					min_dist = d
					nearest_pt = pt
			var dir_to_river: Vector3 = (nearest_pt - global_position)
			dir_to_river.y = 0.0
			if dir_to_river.length() > 0.5:
				return dir_to_river.normalized()

	# 3. Базовый инстинкт подъема высоты Y
	var random_high: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.8, randf_range(-1.0, 1.0)).normalized()
	return Vector3(random_high.x, 0.0, random_high.z).normalized()

func _graze(dt: float) -> void:
	# Спокойно пасется у реки или на хребте
	_graze_timer -= dt
	if _graze_timer <= 0.0:
		_graze_timer = randf_range(3.0, 6.0)
		if randf() < 0.35:
			# Небольшое плавное перемещение
			var angle := randf() * TAU
			_graze_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		else:
			# Стоит на месте и щиплет траву
			_graze_dir = Vector3.ZERO

	if _graze_dir != Vector3.ZERO:
		velocity.x = _graze_dir.x * graze_speed
		velocity.z = _graze_dir.z * graze_speed
		_face_direction(_graze_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)

	if not is_on_floor():
		velocity.y -= 18.0 * dt

	move_and_slide()

func _face_direction(dir: Vector3) -> void:
	var horiz := Vector3(dir.x, 0.0, dir.z)
	if horiz.length_squared() > 0.01:
		look_at(global_position + horiz, Vector3.UP)

func take_damage(amount: float) -> void:
	health -= amount
	# Внезапная паника при атаке
	fear_vector = -transform.basis.z + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)).normalized()
	_flee_rethink_timer = 2.5
	if health <= 0.0:
		queue_free()
