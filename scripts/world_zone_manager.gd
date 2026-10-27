class_name WorldZoneManager
extends Node

# Сигналы смены локации и пограничных зон
signal zone_entered(zone_type: ZoneType, zone_name: String)
signal steep_slope_entered(is_sliding: bool)
signal poi_discovered(poi_id: String, poi_name: String)

enum ZoneType {
	OUTPOST_CENTER,    # Дом егеря (безопасная зона стройки)
	NORTH_RIDGE,       # Скальный хребет и пещеры (янтарь, высота)
	SOUTH_RIVER,       # Река и пойма (чистая вода, рыбалка)
	WEST_TOWN,         # Заброшенный поселок и АЗС (лут, здания)
	EAST_TAIGA,        # Вековая тайга (лес, древесина, зверь)
	DEAD_BORDER        # Смертельная зона за границей 1000х1000м
}

# --- НАСТРОЙКИ ГРАНИЦ И МАСШТАБА ---
@export_group("Map Boundaries (1000x1000)")
@export var half_map_size: float = 500.0          # Лимит карты от -500 до +500
@export var deadly_spore_border_margin: float = 30.0 # Буфер гибели за пределами карты

@export_group("Building Zone (Outpost)")
@export var outpost_bounds: AABB = AABB(Vector3(-50, -5, -50), Vector3(100, 20, 100))

# Список зарегистрированных POI (Точки интереса)
var pois: Dictionary = {
	"outpost_cabin": { "name": "Дом Егеря", "pos": Vector3(0, 1.6, 0), "zone": ZoneType.OUTPOST_CENTER, "visited": true },
	"gas_station": { "name": "АЗС «Северная»", "pos": Vector3(-320, 1.2, -40), "zone": ZoneType.WEST_TOWN, "visited": false },
	"town_pharmacy": { "name": "Поселковая Аптека", "pos": Vector3(-410, 2.0, -90), "zone": ZoneType.WEST_TOWN, "visited": false },
	"amber_quarry": { "name": "Серные Штольни", "pos": Vector3(40, 24.0, -380), "zone": ZoneType.NORTH_RIDGE, "visited": false },
	"cave_entrance": { "name": "Провал Шнека №3", "pos": Vector3(-120, 18.5, -440), "zone": ZoneType.NORTH_RIDGE, "visited": false },
	"fishing_pier": { "name": "Рыбацкие Мостки", "pos": Vector3(15, -8.0, 310), "zone": ZoneType.SOUTH_RIVER, "visited": false },
	"river_crossing": { "name": "Каменистый Брод", "pos": Vector3(-180, -9.5, 260), "zone": ZoneType.SOUTH_RIVER, "visited": false },
	"ancient_grove": { "name": "Медвежий Бурелом", "pos": Vector3(340, 3.0, 80), "zone": ZoneType.EAST_TAIGA, "visited": false }
}

var current_zone: ZoneType = ZoneType.OUTPOST_CENTER

func _ready() -> void:
	add_to_group("topography_system")

# Определение биома по координатам X/Z игрока
func get_zone_at_position(pos: Vector3) -> ZoneType:
	# 1. Проверка смертельного края карты (за пределами 1000х1000м)
	if abs(pos.x) > half_map_size or abs(pos.z) > half_map_size:
		return ZoneType.DEAD_BORDER

	# 2. Проверка центрального кордона (100х100м)
	if outpost_bounds.has_point(pos):
		return ZoneType.OUTPOST_CENTER

	# 3. Кардинальное разделение по секторам карты
	# Север (Z < -150)
	if pos.z < -150.0:
		return ZoneType.NORTH_RIDGE
	# Юг (Z > 150)
	elif pos.z > 150.0:
		return ZoneType.SOUTH_RIVER
	# Запад (X < -100)
	elif pos.x < -100.0:
		return ZoneType.WEST_TOWN
	# Восток (X > 100)
	elif pos.x > 100.0:
		return ZoneType.EAST_TAIGA

	# Буферный переходный лес вокруг базы
	return ZoneType.OUTPOST_CENTER

# Проверка разрешения на постройку (только на кордоне 100х100м)
func is_inside_buildable_zone(world_pos: Vector3) -> bool:
	return outpost_bounds.has_point(world_pos)

# Оценка уклона рельефа (для штрафа выносливости егеря при подъеме на скалы)
func evaluate_slope(normal: Vector3) -> float:
	# normal.y == 1.0 (плоскость), normal.y < 0.7 (~45 градусов)
	return 1.0 - clamp(normal.y, 0.0, 1.0)

# Проверка приближения к POI и их открытие
func check_poi_proximity(player_pos: Vector3, discovery_radius: float = 25.0) -> void:
	for poi_id in pois.keys():
		var poi: Dictionary = pois[poi_id]
		if not poi.get("visited", false):
			var poi_pos: Vector3 = poi.get("pos", Vector3.ZERO)
			var rad: float = poi.get("discovery_radius", discovery_radius)
			if player_pos.distance_to(poi_pos) <= rad:
				poi["visited"] = true
				emit_signal("poi_discovered", poi_id, poi.get("name", poi_id))

# Регистрация новой POI (если создается динамически в мире)
func register_poi(poi_id: String, poi_name: String, pos: Vector3, zone: ZoneType, visited: bool = false, radius: float = 25.0) -> void:
	if not pois.has(poi_id):
		pois[poi_id] = {
			"name": poi_name,
			"pos": pos,
			"zone": zone,
			"visited": visited,
			"discovery_radius": radius
		}

# Возвращает читаемое имя зоны на русском
func get_zone_display_name(zone: ZoneType) -> String:
	match zone:
		ZoneType.OUTPOST_CENTER: return "Кордон Лесника"
		ZoneType.NORTH_RIDGE: return "Скальный Хребет"
		ZoneType.SOUTH_RIVER: return "Пойма Горной Реки"
		ZoneType.WEST_TOWN: return "Заброшенный Поселок"
		ZoneType.EAST_TAIGA: return "Вековая Тайга"
		ZoneType.DEAD_BORDER: return "Смертельный Периметр"
	return "Неизведанная глушь"

# Читаемое текущее имя зоны
func get_current_zone_name() -> String:
	return get_zone_display_name(current_zone)
