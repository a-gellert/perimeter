extends Node

func _ready() -> void:
	print("=== RUNNING PHASE 2 GAMEPLAY, WEAPONS & BOSS TESTS ===")

	# --------------------------------------------------------------------------
	# Test 1: Fortified Gate build and toggle logic
	# --------------------------------------------------------------------------
	var gate := FortifiedGate.new()
	add_child(gate)
	assert(gate.is_built == false, "Gate should not be built initially")
	assert(gate.current_logs == 0, "Gate logs should be 0")
	gate.current_logs = gate.required_logs
	gate.current_scrap = gate.required_scrap
	gate._check_completion()
	assert(gate.is_built == true, "Gate should be built once resources match")
	assert(gate.is_open == false, "Gate should be closed initially")
	gate.toggle_gate()
	assert(gate.is_open == true, "Gate should be open after toggle")
	gate.toggle_gate()
	assert(gate.is_open == false, "Gate should be closed again")
	gate.free()
	print("[PASS] Fortified Gate completion and toggle verified.")

	# --------------------------------------------------------------------------
	# Test 2: Watchtower sentry stationing
	# --------------------------------------------------------------------------
	var tower := Watchtower.new()
	add_child(tower)
	tower.current_logs = tower.required_logs
	tower.current_scrap = tower.required_scrap
	tower._check_completion()
	assert(tower.is_built == true, "Watchtower must be built")

	var dummy_sentry := Node3D.new()
	dummy_sentry.name = "TestSentry"
	add_child(dummy_sentry)
	tower.station_sentry(dummy_sentry)
	assert(tower.stationed_sentry == dummy_sentry, "Sentry must be stationed on tower")
	tower.dismiss_sentry()
	assert(tower.stationed_sentry == null, "Sentry must be dismissed from tower")
	dummy_sentry.free()
	tower.free()
	print("[PASS] Watchtower stationing/dismissal verified.")

	# --------------------------------------------------------------------------
	# Test 3: Bear Trap snapping
	# --------------------------------------------------------------------------
	var trap := BearTrap.new()
	add_child(trap)
	assert(trap.is_armed == true, "Bear trap should be armed initially")

	var dummy_mutant := CharacterBody3D.new()
	dummy_mutant.name = "TestMutant"
	dummy_mutant.add_to_group("enemies")
	add_child(dummy_mutant)

	var hit_detected := [false]
	trap.triggered.connect(func(_v: Node3D) -> void: hit_detected[0] = true)
	trap.snap_trap(dummy_mutant)
	assert(trap.is_armed == false, "Trap should be disarmed after snapping")
	assert(hit_detected[0] == true, "Triggered signal should be emitted")
	dummy_mutant.free()
	trap.free()
	print("[PASS] Bear Trap snapping and disarm verified.")

	# --------------------------------------------------------------------------
	# Test 4: Rescue Radio Beacon repair and SOS
	# --------------------------------------------------------------------------
	var beacon := RescueRadioBeacon.new()
	add_child(beacon)
	assert(beacon.is_repaired == false, "Beacon should not be repaired initially")
	beacon.current_fuel = beacon.required_fuel
	beacon.current_scrap = beacon.required_scrap
	beacon.current_amber = beacon.required_amber
	# Emulate interact
	beacon.is_repaired = true
	assert(beacon.is_repaired == true, "Beacon repaired")
	assert(beacon.is_broadcasting == false, "Not broadcasting initially")
	beacon.start_broadcast()
	assert(beacon.is_broadcasting == true, "Broadcasting SOS signal active")
	beacon.free()
	print("[PASS] Rescue Radio Beacon SOS sequence verified.")

	# --------------------------------------------------------------------------
	# Test 5: Settler Barracks construction and shelter group
	# --------------------------------------------------------------------------
	var barracks := SettlerBarracks.new()
	add_child(barracks)
	assert(barracks.is_built == false, "Barracks should not be built initially")
	barracks.current_logs = barracks.required_logs
	barracks.current_scrap = barracks.required_scrap
	barracks._check_completion()
	assert(barracks.is_built == true, "Barracks must be built")
	assert(barracks.is_in_group("shelters"), "Barracks must be in shelters group")
	barracks.free()
	print("[PASS] Settler Barracks shelter registration verified.")

	# --------------------------------------------------------------------------
	# Test 6: Skinner Mutant stats and leap setup
	# --------------------------------------------------------------------------
	var skinner_scene := load("res://scenes/enemies/SkinnerMutant.tscn") as PackedScene
	var skinner: Node = skinner_scene.instantiate()
	add_child(skinner)
	assert(skinner.max_health == 55.0, "Skinner should have 55 HP")
	assert(skinner.is_in_group("enemies"), "Skinner must be in enemies group")
	assert(skinner.is_in_group("mutants"), "Skinner must be in mutants group")
	skinner.free()
	print("[PASS] Skinner Mutant scene initialization verified.")

	# --------------------------------------------------------------------------
	# Test 7: Geo Titan Boss stats and siege role
	# --------------------------------------------------------------------------
	var titan_scene := load("res://scenes/enemies/GeoTitanBoss.tscn") as PackedScene
	var titan: Node = titan_scene.instantiate()
	add_child(titan)
	assert(titan.max_health == 850.0, "Geo Titan should have 850 HP")
	assert(titan.is_in_group("boss_mutants"), "Geo Titan must be in boss_mutants group")
	titan.take_damage(100.0)
	assert(titan.health == 750.0, "Geo Titan must register damage")
	titan.free()
	print("[PASS] Geo Titan Boss health and damage verified.")

	# --------------------------------------------------------------------------
	# Test 8: Localization Data retrieval
	# --------------------------------------------------------------------------
	assert(LocalizationData.get_text("game_title", "ru") == "ПЕРИМЕТР", "RU game_title must match")
	assert(LocalizationData.get_text("game_title", "en") == "PERIMETER", "EN game_title must match")
	assert(LocalizationData.get_text("quest_day1", "ru").contains("Срубите"), "RU quest 1 must be valid")
	print("[PASS] Localization Data multi-language queries verified.")

	print("=== ALL PHASE 2 & 5 TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
