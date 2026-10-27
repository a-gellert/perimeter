class_name PlayerTopographyHook
extends Node
## Hook component connecting player character to WorldTopography zoning, slope stamina penalties, and POI discovery.

@export var player: CharacterBody3D
@export var update_interval: float = 0.5

var _timer: float = 0.0

func _ready() -> void:
	if not player and get_parent() is CharacterBody3D:
		player = get_parent() as CharacterBody3D

func _physics_process(dt: float) -> void:
	if not player:
		return

	# 1. Проверка зоны и штраф за уклон
	if player.is_on_floor() and (Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography")):
		var current_floor_normal: Vector3 = player.get_floor_normal()
		var slope_severity: float = WorldTopography.evaluate_slope(current_floor_normal)

		# Подъем по крутому серпантину к скалам расходует больше сил
		if slope_severity > 0.25 and player.velocity.length() > 0.5:
			if "stamina" in player:
				player.stamina = max(0.0, player.stamina - (15.0 * slope_severity) * dt)

	# 2. Обновление зоны и открытие точек интереса каждые 0.5 секунды
	_timer += dt
	if _timer >= update_interval:
		_timer = 0.0
		_update_topography()

func _update_topography() -> void:
	if not player or not (Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography")):
		return

	var new_zone: WorldZoneManager.ZoneType = WorldTopography.get_zone_at_position(player.global_position)
	if new_zone != WorldTopography.current_zone:
		WorldTopography.current_zone = new_zone
		WorldTopography.emit_signal("zone_entered", new_zone, WorldTopography.get_zone_display_name(new_zone))

	WorldTopography.check_poi_proximity(player.global_position)
