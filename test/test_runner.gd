extends Node

func _ready() -> void:
	print("=== RUNNING PERIMETER BIOLOGY & ECOLOGY TESTS ===")
	
	# Test 1: Autoload ValleyEcology verification
	var ecology = get_node_or_null("/root/ValleyEcology")
	assert(ecology != null, "ValleyEcology Autoload should exist in root!")
	print("[PASS] ValleyEcology singleton loaded successfully.")

	# Test 2: Spore concentration by altitude
	var high_ridge := Vector3(0, 14.0, 0)
	var deep_valley := Vector3(0, -12.0, 0)
	var mid_level := Vector3(0, 1.0, 0)
	var above_ridge := Vector3(0, 25.0, 0)
	var below_valley := Vector3(0, -20.0, 0)

	var conc_ridge = ValleyEcology.get_spore_concentration(high_ridge)
	var conc_valley = ValleyEcology.get_spore_concentration(deep_valley)
	var conc_mid = ValleyEcology.get_spore_concentration(mid_level)
	var conc_above = ValleyEcology.get_spore_concentration(above_ridge)
	var conc_below = ValleyEcology.get_spore_concentration(below_valley)

	assert(is_equal_approx(conc_ridge, 0.0), "Ridge Y=14 should have 0.0 concentration, got %f" % conc_ridge)
	assert(is_equal_approx(conc_valley, 1.0), "Valley Y=-12 should have 1.0 concentration, got %f" % conc_valley)
	assert(is_equal_approx(conc_mid, 0.5), "Mid Y=1 should have 0.5 concentration, got %f" % conc_mid)
	assert(is_equal_approx(conc_above, 0.0), "Above ridge Y=25 should have 0.0 concentration, got %f" % conc_above)
	assert(is_equal_approx(conc_below, 1.0), "Below valley Y=-20 should have 1.0 concentration, got %f" % conc_below)
	print("[PASS] Altitude spore gradient calculation verified.")

	# Test 3: Glacial River safe zone
	ValleyEcology.clear_river_points()
	var river_pt := Vector3(10.0, -12.0, 10.0) # In the deepest valley
	ValleyEcology.register_river_point(river_pt)

	var conc_at_river = ValleyEcology.get_spore_concentration(river_pt + Vector3(5.0, 0, 0)) # 5m from river (< 18m)
	var conc_far_from_river = ValleyEcology.get_spore_concentration(river_pt + Vector3(25.0, 0, 0)) # 25m from river (> 18m)

	assert(is_equal_approx(conc_at_river, 0.0), "Near river in valley must have 0.0 concentration, got %f" % conc_at_river)
	assert(is_equal_approx(conc_far_from_river, 1.0), "Far from river in valley must have 1.0 concentration, got %f" % conc_far_from_river)
	print("[PASS] River safe zone clears heavy spores verified.")

	# Test 4: Day/Night cycle and UV intensity
	var phase_signal_received := [false]
	ValleyEcology.day_phase_changed.connect(func(n: bool, _uv: float):
		phase_signal_received[0] = true
	)

	# Set night
	ValleyEcology.set_time_of_day(2.0)
	assert(ValleyEcology.is_night == true, "Hour 2.0 should be night")
	assert(is_equal_approx(ValleyEcology.sun_uv_intensity, 0.0), "Night UV should be 0.0")

	# Set noon (day)
	ValleyEcology.set_time_of_day(12.5)
	assert(ValleyEcology.is_night == false, "Hour 12.5 should be day")
	assert(ValleyEcology.sun_uv_intensity > 0.9, "Noon UV should be strong (> 0.9), got %f" % ValleyEcology.sun_uv_intensity)
	assert(phase_signal_received[0], "day_phase_changed signal must be emitted")
	print("[PASS] Day/Night phase transitions and UV curve verified.")

	# Test 5: Mutant sleeper scene and FSM states
	var mutant_scene = load("res://scenes/mutant_sleeper.tscn")
	assert(mutant_scene != null, "mutant_sleeper.tscn must exist!")
	var mutant = mutant_scene.instantiate()
	add_child(mutant)

	# At day, mutant should be in HIBERNATION
	ValleyEcology.set_time_of_day(10.0)
	mutant._on_day_phase_changed(false, 0.8)
	assert(mutant.current_state == MutantBase.State.HIBERNATION, "Mutant must hibernate during day")
	assert(is_equal_approx(mutant.body_mesh.scale.x, 0.9), "Mutant body mesh must compress during hibernation")
	print("[PASS] Daytime mutant hibernation cocoon verified.")

	# Daytime noise: weak noise far away does NOT wake it up
	mutant.hear_noise(mutant.global_position + Vector3(20, 0, 0), 10.0)
	assert(mutant.current_state == MutantBase.State.HIBERNATION, "Weak far noise must not wake hibernating mutant")

	# Daytime noise: loud chopping/shot in close range wakes it up
	mutant.hear_noise(mutant.global_position + Vector3(4, 0, 0), 22.0)
	assert(mutant.current_state == MutantBase.State.ALERTED, "Loud chopping in range must wake mutant to ALERTED")
	print("[PASS] Daytime noise thresholds verified.")

	# Camp heat during day does NOT attract sleeping mutant
	mutant._fall_into_hibernation()
	mutant.sense_camp_heat_or_food(mutant.global_position + Vector3(10, 0, 0), "HEAT")
	assert(mutant.current_state == MutantBase.State.HIBERNATION, "Daytime camp heat must not attract sleeping mutant")

	# At night, mutant wakes up to NIGHT_PROWLER
	ValleyEcology.set_time_of_day(22.0)
	mutant._on_day_phase_changed(true, 0.0)
	assert(mutant.current_state == MutantBase.State.NIGHT_PROWLER, "Mutant must awaken to NIGHT_PROWLER at night")
	assert(is_equal_approx(mutant.body_mesh.scale.x, 1.0), "Mutant body mesh scale must restore at night")

	# Night camp heat DOES attract mutant
	mutant.sense_camp_heat_or_food(mutant.global_position + Vector3(15, 0, 0), "HEAT")
	assert(mutant.current_state == MutantBase.State.ALERTED, "Night camp heat must alert mutant")
	assert(mutant.target_stimulus_pos.distance_to(mutant.global_position + Vector3(15, 0, 0)) < 0.1, "Target stimulus pos set to camp")
	print("[PASS] Night awakening and camp heat reaction verified.")

	# Test 6: UV Thermal Shock
	ValleyEcology.set_time_of_day(12.0)
	var initial_hp = mutant.health
	mutant._apply_uv_thermal_shock(1.0)
	assert(mutant.current_state == MutantBase.State.UV_STUNNED, "Direct sunlight must cause UV_STUNNED state")
	assert(mutant.health < initial_hp, "Direct sunlight must cause damage to mutant")
	print("[PASS] Photophobic UV thermal shock verified.")

	# Test 6b: is_in_direct_sunlight check
	var space_state = (mutant.get_world_3d() as World3D).direct_space_state
	# During day in open space
	ValleyEcology.set_time_of_day(12.0)
	var in_sun = ValleyEcology.is_in_direct_sunlight(Vector3(100, 50, 100), space_state)
	assert(in_sun == true, "Open point during day must be in direct sunlight")
	# At night
	ValleyEcology.set_time_of_day(1.0)
	var in_sun_night = ValleyEcology.is_in_direct_sunlight(Vector3(100, 50, 100), space_state)
	assert(in_sun_night == false, "At night, must NOT be in direct sunlight")
	ValleyEcology.set_time_of_day(12.0)
	print("[PASS] Direct sunlight detection physics raycast verified.")
	mutant.queue_free()

	# Test 7: Wild animal scene and elevation instinct
	var deer_scene = load("res://scenes/deer_prey.tscn")
	assert(deer_scene != null, "deer_prey.tscn must exist!")
	var deer = deer_scene.instantiate()
	add_child(deer)

	# Place deer in deep toxic ravine (Y = -10.0, no river)
	ValleyEcology.clear_river_points()
	deer.global_position = Vector3(0, -10.0, 0)
	var tox = ValleyEcology.get_spore_concentration(deer.global_position)
	assert(tox > 0.25, "Valley floor should have high spore toxicity")

	# Animal physics process evaluates toxicity and flees
	deer._physics_process(0.016)
	assert(deer.velocity.length() > 0.1, "Animal must flee when toxicity > 0.25")
	print("[PASS] Wild animal instinct: flees heavy spore fog basins verified.")

	# Place deer on safe high ridge (Y = 12.0)
	deer.global_position = Vector3(0, 12.0, 0)
	var safe_tox = ValleyEcology.get_spore_concentration(deer.global_position)
	assert(safe_tox <= 0.25, "Ridge should have low spore toxicity (< 0.25)")
	deer._graze(0.016)
	print("[PASS] Wild animal grazing on high ground verified.")
	deer.queue_free()

	print("=== ALL TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
