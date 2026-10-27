class_name TopographyData
extends RefCounted
## Data structures and constants for 1000x1000m world topography and zoning.

# --- КАРТОГРАФИЧЕСКИЕ КОНСТАНТЫ (1000x1000 м) ---
const MAP_SIZE: float = 1000.0
const HALF_MAP_SIZE: float = 500.0
const OUTPOST_RADIUS: float = 50.0 # Кордон 100х100м, радиус от центра = 50м

# --- ДИАПАЗОНЫ ВЫСОТ (Ось Y) ---
# Y in [-15, -4]: Низина и русло реки (Юг)
const ELEVATION_SOUTH_RIVER_MIN: float = -15.0
const ELEVATION_SOUTH_RIVER_MAX: float = -4.0

# Y in [0, 4]: Среднее плато (Кордон егеря, Вековая тайга, Поселок)
const ELEVATION_PLATEAU_MIN: float = 0.0
const ELEVATION_PLATEAU_MAX: float = 4.0

# Y in [10, 38]: Горные уступы и Скальный хребет (Север)
const ELEVATION_NORTH_RIDGE_MIN: float = 10.0
const ELEVATION_NORTH_RIDGE_MAX: float = 38.0

# --- СТРУКТУРЫ ДАННЫХ ---

class POIInfo:
	var id: String
	var name: String
	var pos: Vector3
	var zone: int
	var visited: bool = false
	var description: String = ""
	var discovery_radius: float = 25.0

	func _init(p_id: String, p_name: String, p_pos: Vector3, p_zone: int, p_visited: bool = false, p_desc: String = "", p_radius: float = 25.0) -> void:
		id = p_id
		name = p_name
		pos = p_pos
		zone = p_zone
		visited = p_visited
		description = p_desc
		discovery_radius = p_radius

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"pos": pos,
			"zone": zone,
			"visited": visited,
			"description": description,
			"discovery_radius": discovery_radius
		}

	static func from_dict(dict: Dictionary) -> POIInfo:
		return POIInfo.new(
			dict.get("id", ""),
			dict.get("name", ""),
			dict.get("pos", Vector3.ZERO),
			dict.get("zone", 0),
			dict.get("visited", false),
			dict.get("description", ""),
			dict.get("discovery_radius", 25.0)
		)

class BiomeInfo:
	var zone_type: int
	var display_name: String
	var description: String
	var elevation_range: Vector2
	var bounds_description: String
	var can_build: bool = false

	func _init(p_type: int, p_name: String, p_desc: String, p_elev: Vector2, p_bounds: String, p_can_build: bool = false) -> void:
		zone_type = p_type
		display_name = p_name
		description = p_desc
		elevation_range = p_elev
		bounds_description = p_bounds
		can_build = p_can_build

# --- МЕТАДАННЫЕ БИОМОВ ---
static func get_biome_definitions() -> Dictionary:
	return {
		WorldZoneManager.ZoneType.OUTPOST_CENTER: BiomeInfo.new(
			WorldZoneManager.ZoneType.OUTPOST_CENTER,
			"Кордон Лесника",
			"База, сруб, печь, колодец, стройплощадка частокола",
			Vector2(ELEVATION_PLATEAU_MIN, ELEVATION_PLATEAU_MAX),
			"Центр 100x100м: X [-50, 50], Z [-50, 50]",
			true
		),
		WorldZoneManager.ZoneType.NORTH_RIDGE: BiomeInfo.new(
			WorldZoneManager.ZoneType.NORTH_RIDGE,
			"Скальный Хребет",
			"Пещеры, руда, тектонический янтарь, серные штольни. Крутой подъем по серпантину",
			Vector2(ELEVATION_NORTH_RIDGE_MIN, ELEVATION_NORTH_RIDGE_MAX),
			"Север: Z < -150",
			false
		),
		WorldZoneManager.ZoneType.SOUTH_RIVER: BiomeInfo.new(
			WorldZoneManager.ZoneType.SOUTH_RIVER,
			"Пойма Горной Реки",
			"Мостки, ловля хариуса, брод, камыши, чистая вода. Спуск к пойме",
			Vector2(ELEVATION_SOUTH_RIVER_MIN, ELEVATION_SOUTH_RIVER_MAX),
			"Юг: Z > 150",
			false
		),
		WorldZoneManager.ZoneType.WEST_TOWN: BiomeInfo.new(
			WorldZoneManager.ZoneType.WEST_TOWN,
			"Заброшенный Поселок",
			"АЗС, склад, аптека, гаражи, спящие в тени зомби/лут",
			Vector2(ELEVATION_PLATEAU_MIN, ELEVATION_PLATEAU_MAX),
			"Запад: X < -100",
			false
		),
		WorldZoneManager.ZoneType.EAST_TAIGA: BiomeInfo.new(
			WorldZoneManager.ZoneType.EAST_TAIGA,
			"Вековая Тайга",
			"Плотные сосны, бурелом, коконы спящих зверей",
			Vector2(ELEVATION_PLATEAU_MIN, ELEVATION_PLATEAU_MAX),
			"Восток: X > 100",
			false
		),
		WorldZoneManager.ZoneType.DEAD_BORDER: BiomeInfo.new(
			WorldZoneManager.ZoneType.DEAD_BORDER,
			"Смертельный Периметр",
			"Смертельный споровый туман за пределами долины 1000х1000м",
			Vector2(-50.0, 100.0),
			"За границей |X| > 500 или |Z| > 500",
			false
		)
	}

# --- НАЧАЛЬНЫЙ НАБОР POI ---
static func get_default_pois() -> Dictionary:
	return {
		"outpost_cabin": {
			"name": "Дом Егеря",
			"pos": Vector3(0, 1.6, 0),
			"zone": WorldZoneManager.ZoneType.OUTPOST_CENTER,
			"visited": true,
			"description": "Центральная база выживания и убежище с печью."
		},
		"gas_station": {
			"name": "АЗС «Северная»",
			"pos": Vector3(-320, 1.2, -40),
			"zone": WorldZoneManager.ZoneType.WEST_TOWN,
			"visited": false,
			"description": "Заброшенная заправка на въезде в поселок. Топливо и запчасти."
		},
		"town_pharmacy": {
			"name": "Поселковая Аптека",
			"pos": Vector3(-410, 2.0, -90),
			"zone": WorldZoneManager.ZoneType.WEST_TOWN,
			"visited": false,
			"description": "Разграбленная аптека. Шанс найти антибиотики и бинты."
		},
		"amber_quarry": {
			"name": "Серные Штольни",
			"pos": Vector3(40, 24.0, -380),
			"zone": WorldZoneManager.ZoneType.NORTH_RIDGE,
			"visited": false,
			"description": "Высокогорные выработки серы и месторождения тектонического янтаря."
		},
		"cave_entrance": {
			"name": "Провал Шнека №3",
			"pos": Vector3(-120, 18.5, -440),
			"zone": WorldZoneManager.ZoneType.NORTH_RIDGE,
			"visited": false,
			"description": "Глубокая пещерная расселина в скальной гряде."
		},
		"fishing_pier": {
			"name": "Рыбацкие Мостки",
			"pos": Vector3(15, -8.0, 310),
			"zone": WorldZoneManager.ZoneType.SOUTH_RIVER,
			"visited": false,
			"description": "Старые деревянные помосты для ловли хариуса в быстрой воде."
		},
		"river_crossing": { "name": "Каменистый Брод",
			"pos": Vector3(-180, -9.5, 260),
			"zone": WorldZoneManager.ZoneType.SOUTH_RIVER,
			"visited": false,
			"description": "Безопасный мелкий переход через пороги горной реки."
		},
		"ancient_grove": {
			"name": "Медвежий Бурелом",
			"pos": Vector3(340, 3.0, 80),
			"zone": WorldZoneManager.ZoneType.EAST_TAIGA,
			"visited": false,
			"description": "Непролазная чаща с гигантскими поваленными соснами и логовом зверя."
		}
	}
