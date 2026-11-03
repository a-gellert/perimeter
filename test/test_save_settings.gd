extends Node

func _ready() -> void:
	print("=== RUNNING SAVE & SETTINGS MANAGER TESTS ===")

	# --------------------------------------------------------------------------
	# Test 1: Autoload verification
	# --------------------------------------------------------------------------
	var sm = get_node_or_null("/root/SaveManager")
	assert(sm != null, "SaveManager Autoload must exist in root!")
	print("[PASS] SaveManager loaded.")

	var settings = get_node_or_null("/root/SettingsManager")
	assert(settings != null, "SettingsManager Autoload must exist in root!")
	print("[PASS] SettingsManager loaded.")

	# --------------------------------------------------------------------------
	# Test 2: SettingsManager persistence and modification
	# --------------------------------------------------------------------------
	var original_sens: float = settings.mouse_sensitivity
	settings.mouse_sensitivity = 0.0055
	settings.master_volume = 0.65
	settings.save_settings()

	# Create a temporary new instance to test loading from file
	var test_settings := GameSettingsManager.new()
	test_settings.load_settings()
	assert(is_equal_approx(test_settings.mouse_sensitivity, 0.0055), "Mouse sensitivity should be persisted!")
	assert(is_equal_approx(test_settings.master_volume, 0.65), "Master volume should be persisted!")
	test_settings.free()

	# Restore original
	settings.mouse_sensitivity = original_sens
	settings.master_volume = 1.0
	settings.save_settings()
	print("[PASS] SettingsManager save/load to config file verified.")

	# --------------------------------------------------------------------------
	# Test 3: SaveManager saving and metadata
	# --------------------------------------------------------------------------
	var test_slot := 99 # Dedicated test slot
	if sm.has_save(test_slot):
		sm.delete_save(test_slot)
	assert(sm.has_save(test_slot) == false, "Test slot should not exist initially.")

	var save_ok: bool = sm.save_game(test_slot, "Тестовое Сохранение")
	assert(save_ok == true, "Save game should return true on success.")
	assert(sm.has_save(test_slot) == true, "SaveManager must recognize created save.")

	var meta: Dictionary = sm.get_save_meta(test_slot)
	assert(meta.get("slot") == test_slot, "Meta slot must match.")
	assert(meta.get("title") == "Тестовое Сохранение", "Meta title must match.")
	print("[PASS] SaveManager slot creation and metadata verified.")

	# --------------------------------------------------------------------------
	# Test 4: SaveManager slot deletion
	# --------------------------------------------------------------------------
	var del_ok: bool = sm.delete_save(test_slot)
	assert(del_ok == true, "SaveManager delete_save should return true.")
	assert(sm.has_save(test_slot) == false, "Test slot must be deleted.")
	print("[PASS] SaveManager deletion verified.")

	print("=== ALL SAVE & SETTINGS TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
