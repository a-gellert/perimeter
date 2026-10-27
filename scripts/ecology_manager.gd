class_name ValleyEcologyManager
extends Node
## Global Manager for Valley Ecology, Spore Fog, and Environmental Zones.
## Registered as Autoload: ValleyEcology.

# Сигналы смены фаз суток
signal day_phase_changed(is_night: bool, sun_intensity: float)

# Сигналы для сенсорных раздражителей
signal sound_broadcast(origin: Vector3, radius: float)
signal camp_stimulus_broadcast(camp_pos: Vector3, stimulus_type: String)

# --- ПАРАМЕТРЫ ЭКОЛОГИИ ДОЛИНЫ ---
@export_group("Spore Fog Thresholds")
@export var valley_floor_y: float = -12.0    # Глубокие овраги и шахты (100% концентрация)
@export var safe_ridge_y: float = 14.0       # Продуваемые хребты и кордон егеря (0% концентрация)
@export var river_safe_distance: float = 18.0# Радиус очистки воздуха вокруг ледниковой реки
@export var sun_collision_mask: int = 9      # Маска коллизии геометрии мира (1=Environment, 8=Buildings/Roofs)

# --- СУТОЧНЫЙ ЦИКЛ (СВЕТ И УЛЬТРАФИОЛЕТ) ---
var is_night: bool = false
var sun_uv_intensity: float = 1.0            # 1.0 (день, паралич) .. 0.0 (глубокая ночь)
var _first_time_set: bool = true

# Ссылка на координаты ледниковой горной реки (Path3D или массив точек)
var river_points: Array[Vector3] = []

func _ready() -> void:
	add_to_group("ecology_system")
	set_time_of_day(8.0) # По умолчанию утро/день
	
	# Подключение к шине событий существующего TimeManager
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("time_updated"):
		bus.time_updated.connect(_on_bus_time_updated)

func _on_bus_time_updated(hours: int, minutes: int, _phase: int) -> void:
	var float_hour: float = float(hours) + float(minutes) / 60.0
	set_time_of_day(float_hour)

# Расчет токсичности и плотности спор в любой точке карты
func get_spore_concentration(world_pos: Vector3) -> float:
	# 1. Фактор проточной ледниковой реки: вода смывает и осаждает споры
	for pt in river_points:
		if world_pos.distance_to(pt) < river_safe_distance:
			return 0.0 # Воздух над рекой чист

	# 2. Физика тяжелого газа (Закон высоты):
	# В низинах (Y <= valley_floor_y) концентрация 1.0. На сопках (Y >= safe_ridge_y) — 0.0.
	var height_factor: float = inverse_lerp(safe_ridge_y, valley_floor_y, world_pos.y)
	return clamp(height_factor, 0.0, 1.0)

# Проверка: находится ли точка под открытым смертельным для мутантов солнцем
func is_in_direct_sunlight(world_pos: Vector3, space_state: PhysicsDirectSpaceState3D) -> bool:
	if is_night or sun_uv_intensity < 0.15:
		return false # Ночью солнца нет

	# Бросаем луч вверх под углом падения солнечного света
	var sun_dir: Vector3 = Vector3(0.3, 0.8, 0.4).normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		world_pos + Vector3.UP * 0.5,
		world_pos + sun_dir * 40.0,
		sun_collision_mask
	)
	var result: Dictionary = space_state.intersect_ray(query)
	# Если луч ни во что не уперся — точка на открытом солнце
	return result.is_empty()

func set_time_of_day(hour: float) -> void:
	# День: с 06:00 до 19:00. Ночь: с 19:00 до 06:00
	var new_is_night: bool = (hour < 6.0 or hour >= 19.0)
	var phase_transition := (_first_time_set or new_is_night != is_night)
	_first_time_set = false
	is_night = new_is_night
	
	if is_night:
		sun_uv_intensity = 0.0
	else:
		# Плавный подъем и спад интенсивности УФ
		sun_uv_intensity = clamp(sin((hour - 6.0) / 13.0 * PI), 0.0, 1.0)
	
	if phase_transition:
		emit_signal("day_phase_changed", is_night, sun_uv_intensity)

# ==============================================================================
# ШИРОКОВЕЩАТЕЛЬНЫЕ СЕНСОРНЫЕ РАЗДРАЖИТЕЛИ (ЗВУК, ДЫМ, ТЕПЛО, ЗАПАХ ЕДЫ)
# ==============================================================================

# Оповещает всех мутантов в долине об источнике звука (выстрел, рубка, бег)
func emit_sound(origin: Vector3, radius: float) -> void:
	emit_signal("sound_broadcast", origin, radius)
	var mutants: Array[Node] = get_tree().get_nodes_in_group("mutants")
	for mutant in mutants:
		if mutant.has_method("hear_noise"):
			mutant.hear_noise(origin, radius)

# Оповещает мутантов о ночном дыме из трубы печи егеря, костре или готовке пищи
func emit_camp_stimulus(camp_pos: Vector3, stimulus_type: String = "HEAT") -> void:
	emit_signal("camp_stimulus_broadcast", camp_pos, stimulus_type)
	var mutants: Array[Node] = get_tree().get_nodes_in_group("mutants")
	for mutant in mutants:
		if mutant.has_method("sense_camp_heat_or_food"):
			mutant.sense_camp_heat_or_food(camp_pos, stimulus_type)

# Регистрация точек проточной реки
func register_river_point(pt: Vector3) -> void:
	if not river_points.has(pt):
		river_points.append(pt)

func register_river_path(points: Array[Vector3]) -> void:
	for pt in points:
		register_river_point(pt)

func clear_river_points() -> void:
	river_points.clear()
