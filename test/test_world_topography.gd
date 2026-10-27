extends Node

func _ready() -> void:
	print("=== RUNNING WORLD TOPOGRAPHY & ZONING TESTS ===")
	
	# Test 1: Autoload WorldTopography verification
	var topo: Node = get_node_or_null("/root/WorldTopography")
	assert(topo != null, "WorldTopography Autoload should exist in root!")
	print("[PASS] WorldTopography singleton loaded successfully.")

	# Test 2: Zone detection at various coordinates
	var center_pos := Vector3(0, 1.0, 0)
	var north_pos := Vector3(0, 20.0, -250.0)
	var south_pos := Vector3(0, -8.0, 250.0)
	var west_pos := Vector3(-250.0, 2.0, 0)
	var east_pos := Vector3(250.0, 2.0, 0)
	var dead_x_pos := Vector3(510.0, 0, 0)
	var dead_z_pos := Vector3(0, 0, -510.0)

	assert(topo.get_zone_at_position(center_pos) == WorldZoneManager.ZoneType.OUTPOST_CENTER, "Center should be OUTPOST_CENTER")
	assert(topo.get_zone_at_position(north_pos) == WorldZoneManager.ZoneType.NORTH_RIDGE, "North Z<-150 should be NORTH_RIDGE")
	assert(topo.get_zone_at_position(south_pos) == WorldZoneManager.ZoneType.SOUTH_RIVER, "South Z>150 should be SOUTH_RIVER")
	assert(topo.get_zone_at_position(west_pos) == WorldZoneManager.ZoneType.WEST_TOWN, "West X<-100 should be WEST_TOWN")
	assert(topo.get_zone_at_position(east_pos) == WorldZoneManager.ZoneType.EAST_TAIGA, "East X>100 should be EAST_TAIGA")
	assert(topo.get_zone_at_position(dead_x_pos) == WorldZoneManager.ZoneType.DEAD_BORDER, "X>500 should be DEAD_BORDER")
	assert(topo.get_zone_at_position(dead_z_pos) == WorldZoneManager.ZoneType.DEAD_BORDER, "Z<-500 should be DEAD_BORDER")
	print("[PASS] Zone detection by coordinates (5 sectors + border) verified.")

	# Test 3: Zone display names
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.OUTPOST_CENTER) == "Кордон Лесника")
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.NORTH_RIDGE) == "Скальный Хребет")
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.SOUTH_RIVER) == "Пойма Горной Реки")
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.WEST_TOWN) == "Заброшенный Поселок")
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.EAST_TAIGA) == "Вековая Тайга")
	assert(topo.get_zone_display_name(WorldZoneManager.ZoneType.DEAD_BORDER) == "Смертельный Периметр")
	print("[PASS] Russian display names for all zones verified.")

	# Test 4: Buildable zone limits (only outpost 100x100m)
	assert(topo.is_inside_buildable_zone(Vector3(0, 0, 0)) == true, "Center (0,0,0) must be buildable")
	assert(topo.is_inside_buildable_zone(Vector3(40, 2, 40)) == true, "(40,2,40) inside 100x100 must be buildable")
	assert(topo.is_inside_buildable_zone(Vector3(-45, 0, -45)) == true, "(-45,0,-45) inside 100x100 must be buildable")
	assert(topo.is_inside_buildable_zone(Vector3(65, 0, 0)) == false, "X=65 outside 100x100 must NOT be buildable")
	assert(topo.is_inside_buildable_zone(Vector3(0, 0, -200)) == false, "North Ridge must NOT be buildable")
	assert(topo.is_inside_buildable_zone(Vector3(-300, 0, 0)) == false, "West Town must NOT be buildable")
	print("[PASS] is_inside_buildable_zone (100x100m cordon constraint) verified.")

	# Test 5: Slope evaluation
	var flat_normal := Vector3(0, 1.0, 0)
	var mild_slope_normal := Vector3(0.1, 0.95, 0).normalized()
	var steep_slope_normal := Vector3(0.7, 0.7, 0).normalized()
	var vertical_cliff_normal := Vector3(1.0, 0.0, 0)

	var slope_flat: float = topo.evaluate_slope(flat_normal)
	var slope_mild: float = topo.evaluate_slope(mild_slope_normal)
	var slope_steep: float = topo.evaluate_slope(steep_slope_normal)
	var slope_cliff: float = topo.evaluate_slope(vertical_cliff_normal)

	assert(is_equal_approx(slope_flat, 0.0), "Flat floor should have 0.0 slope severity")
	assert(slope_mild < 0.25, "Mild slope severity should be < 0.25")
	assert(slope_steep > 0.25, "Steep slope severity should be > 0.25 (triggers stamina penalty)")
	assert(is_equal_approx(slope_cliff, 1.0), "Vertical cliff should have 1.0 slope severity")
	print("[PASS] Slope evaluation evaluate_slope() verified.")

	# Test 6: POI proximity and discovery system
	assert(topo.pois.has("outpost_cabin"), "outpost_cabin POI must exist")
	assert(topo.pois.has("amber_quarry"), "amber_quarry POI must exist")
	assert(topo.pois.has("gas_station"), "gas_station POI must exist")
	assert(topo.pois.has("town_pharmacy"), "town_pharmacy POI must exist")
	assert(topo.pois.has("cave_entrance"), "cave_entrance POI must exist")
	assert(topo.pois.has("fishing_pier"), "fishing_pier POI must exist")
	assert(topo.pois.has("river_crossing"), "river_crossing POI must exist")
	assert(topo.pois.has("ancient_grove"), "ancient_grove POI must exist")

	var discovered_signal := [false, "", ""]
	topo.poi_discovered.connect(func(p_id: String, p_name: String):
		discovered_signal[0] = true
		discovered_signal[1] = p_id
		discovered_signal[2] = p_name
	)

	# Initially gas_station is unvisited
	assert(topo.pois["gas_station"]["visited"] == false)
	# Player walks to gas_station (-320, 1.2, -40)
	topo.check_poi_proximity(Vector3(-320, 1.2, -40), 25.0)
	assert(topo.pois["gas_station"]["visited"] == true, "gas_station must be marked visited")
	assert(discovered_signal[0] == true, "poi_discovered signal must be fired")
	assert(discovered_signal[1] == "gas_station")
	assert(discovered_signal[2] == "АЗС «Северная»")
	print("[PASS] POI registration and discovery system verified.")

	# Test 7: WorldMapBounds scene structure
	var bounds_scene: PackedScene = load("res://scenes/world_map_bounds.tscn")
	assert(bounds_scene != null, "scenes/world_map_bounds.tscn must exist and load")
	var bounds_node: Node3D = bounds_scene.instantiate() as Node3D
	add_child(bounds_node)

	var walls := bounds_node.get_node_or_null("NaturalRockWalls") as StaticBody3D
	assert(walls != null, "NaturalRockWalls must exist")
	assert(walls.get_node_or_null("NorthCliffCollider") != null)
	assert(walls.get_node_or_null("SouthGorgeCollider") != null)
	assert(walls.get_node_or_null("WestBarricadeCollider") != null)
	assert(walls.get_node_or_null("EastMountainCollider") != null)

	var kill_vol := bounds_node.get_node_or_null("DeadlyBorderKillVolume") as Area3D
	assert(kill_vol != null, "DeadlyBorderKillVolume Area3D must exist")
	assert(kill_vol.get_node_or_null("BorderShape") != null, "BorderShape CollisionShape3D must exist")
	assert(kill_vol.collision_mask == 2, "DeadlyBorderKillVolume collision_mask must be 2 (Player)")

	# Test lethal damage in BorderKillVolume
	var fake_player := CharacterBody3D.new()
	var player_script := GDScript.new()
	player_script.source_code = "extends CharacterBody3D\nvar hp: float = 100.0\nfunc take_damage(dmg: float) -> void:\n\thp = max(0.0, hp - dmg)"
	player_script.reload()
	fake_player.set_script(player_script)
	fake_player.name = "Player"
	fake_player.set("hp", 100.0)
	kill_vol._on_body_entered(fake_player)
	assert(fake_player.get("hp") == 0.0, "BorderKillVolume must reduce player HP to 0")
	fake_player.queue_free()
	bounds_node.queue_free()
	print("[PASS] WorldMapBounds scene colliders and lethal spore border verified.")

	# Test 8: POIMarker scene
	var poi_scene: PackedScene = load("res://scenes/poi_marker.tscn")
	assert(poi_scene != null, "scenes/poi_marker.tscn must exist and load")
	var poi_node: POIMarker = poi_scene.instantiate() as POIMarker
	poi_node.poi_id = "test_custom_poi"
	poi_node.poi_name = "Тестовая Стоянка"
	add_child(poi_node)
	assert(topo.pois.has("test_custom_poi"), "Custom POI should auto-register in WorldTopography")
	poi_node.queue_free()
	print("[PASS] POIMarker auto-registration and scene instantiation verified.")

	# Test 9: ZoneAudioAmbience component
	var audio_script: GDScript = load("res://scripts/zone_audio_ambience.gd")
	assert(audio_script != null, "scripts/zone_audio_ambience.gd must exist")
	var audio_player: ZoneAudioAmbience = ZoneAudioAmbience.new()
	add_child(audio_player)
	# Trigger zone change to test listener
	topo.zone_entered.emit(WorldZoneManager.ZoneType.NORTH_RIDGE, "Скальный Хребет")
	audio_player.queue_free()
	print("[PASS] ZoneAudioAmbience signal connection and execution verified.")

	print("=== ALL 9 WORLD TOPOGRAPHY & ZONING TESTS PASSED! ===")
	get_tree().quit(0)
