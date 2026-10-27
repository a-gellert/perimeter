class_name ZoneAudioAmbience
extends AudioStreamPlayer
## Audio controller for biome background ambience with smooth Tween transitions.

@export var outpost_ambience: AudioStream    # Потрескивание бревен, шелест листвы
@export var north_wind_ambience: AudioStream # Свист горного ветра, гул штолен
@export var river_ambience: AudioStream      # Шум горного потока, плеск
@export var town_ambience: AudioStream       # Скрип ржавого металла, глухие удары
@export var taiga_ambience: AudioStream      # Скрип вековых сосен, карканье ворон

var _current_tween: Tween = null

func _ready() -> void:
	if Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography"):
		WorldTopography.zone_entered.connect(_on_zone_entered)
		# Запуск фонового звука для начальной зоны
		_on_zone_entered(WorldTopography.current_zone, WorldTopography.get_zone_display_name(WorldTopography.current_zone))

func _on_zone_entered(zone: WorldZoneManager.ZoneType, _name: String) -> void:
	var target_stream: AudioStream = null
	match zone:
		WorldZoneManager.ZoneType.OUTPOST_CENTER: target_stream = outpost_ambience
		WorldZoneManager.ZoneType.NORTH_RIDGE: target_stream = north_wind_ambience
		WorldZoneManager.ZoneType.SOUTH_RIVER: target_stream = river_ambience
		WorldZoneManager.ZoneType.WEST_TOWN: target_stream = town_ambience
		WorldZoneManager.ZoneType.EAST_TAIGA: target_stream = taiga_ambience
	
	if target_stream and stream != target_stream:
		if _current_tween and _current_tween.is_valid():
			_current_tween.kill()
		
		# Плавный переход через Tween
		_current_tween = create_tween()
		_current_tween.tween_property(self, "volume_db", -40.0, 0.8)
		_current_tween.tween_callback(func():
			stream = target_stream
			play()
		)
		_current_tween.tween_property(self, "volume_db", 0.0, 1.2)
	elif not target_stream and stream:
		# Плавное затухание при выходе в зону без звука
		if _current_tween and _current_tween.is_valid():
			_current_tween.kill()
		_current_tween = create_tween()
		_current_tween.tween_property(self, "volume_db", -40.0, 0.8)
		_current_tween.tween_callback(func():
			stop()
			stream = null
		)
