extends Node

func _ready() -> void:
	print("=== RUNNING SMOOTH SHADOWS & TAIGA LIGHTING TESTS ===")

	# 1. Test TimeManager continuous time emissions
	var time_mgr := TimeManager.new()
	add_child(time_mgr)
	time_mgr.day_length_real_sec = 540.0
	time_mgr.start_hour = 10.0
	time_mgr._ready()

	var continuous_updates: Array[float] = []
	var discrete_updates: Array[Array] = []

	var conn1 = GameEvents.time_continuous_updated.connect(func(h: float):
		continuous_updates.append(h)
	)
	var conn2 = GameEvents.time_updated.connect(func(h: int, m: int, p: int):
		discrete_updates.append([h, m, p])
	)

	# Simulate 10 frames of 16ms delta
	for i in range(10):
		time_mgr._process(0.016)

	assert(continuous_updates.size() == 10, "Continuous time must emit every frame")
	# Check that continuous time changes monotonically each frame
	for i in range(1, continuous_updates.size()):
		assert(continuous_updates[i] > continuous_updates[i - 1], "Time must increase continuously each frame")
		var step: float = continuous_updates[i] - continuous_updates[i - 1]
		assert(step < 0.005, "Step per frame must be infinitesimal (< 0.005 hours), got %f" % step)

	print("[PASS] TimeManager continuous per-frame time progression verified.")

	# 2. Test TaigaLighting reaction to continuous time
	var lighting := TaigaLighting.new()
	var sun := DirectionalLight3D.new()
	add_child(sun)
	lighting.sun_light = sun
	add_child(lighting)

	assert(sun.directional_shadow_blend_splits == true, "Cascade blend splits must be enabled for smooth shadows")
	assert(sun.shadow_blur >= 1.5, "Shadow blur must be at least 1.5")
	assert(sun.shadow_normal_bias >= 2.0, "Shadow normal bias must be >= 2.0")

	# Check rotation degrees changes smoothly
	var pitch_angles: Array[float] = []
	for hr in [8.0, 8.01, 8.02, 8.03, 8.04]:
		GameEvents.time_continuous_updated.emit(hr)
		pitch_angles.append(sun.rotation_degrees.x)

	for i in range(1, pitch_angles.size()):
		assert(pitch_angles[i] != pitch_angles[i - 1], "Sun pitch must change smoothly with continuous time")
		var diff = absf(pitch_angles[i] - pitch_angles[i - 1])
		assert(diff < 0.5, "Sun angle change between micro-steps must be small (< 0.5 deg), got %f" % diff)

	print("[PASS] TaigaLighting continuous sun rotation and shadow blending verified.")

	# 3. Test day/night smooth curve and below-horizon shadow cut-off
	# Noon (12:00): Full energy, shadows enabled
	GameEvents.time_continuous_updated.emit(12.0)
	assert(is_equal_approx(sun.light_energy, 1.8), "Noon light energy should be 1.8")
	assert(sun.shadow_enabled == true, "Noon shadows must be enabled")

	# Sunset (18.5): Smoothly reduced energy
	GameEvents.time_continuous_updated.emit(18.5)
	assert(sun.light_energy < 1.8 and sun.light_energy > 0.15, "Sunset light energy must be smoothly intermediate")

	# Deep Night (2.0): Low ambient-level energy, sun below horizon so sun shadows disabled
	GameEvents.time_continuous_updated.emit(2.0)
	assert(is_equal_approx(sun.light_energy, 0.15), "Night light energy should be 0.15")
	assert(sun.shadow_enabled == false, "Sun shadows must be disabled when sun is below horizon at night")
	print("[PASS] Day/Night smooth energy curve and below-horizon shadow safety verified.")

	# Cleanup
	sun.free()
	lighting.free()
	time_mgr.free()

	print("=== ALL SMOOTH SHADOW TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
