extends Node
## Verification test script for Loot, Inventory (Warband style), and Workbench Crafting modules.

func _ready() -> void:
	print("==================================================")
	print("🧪 STARTING PERIMETER INVENTORY & CRAFTING TEST SUITE")
	print("==================================================")

	var all_passed := true

	# --- TEST 1: ItemDatabase ---
	print("\n--- TEST 1: ItemDatabase Initialization ---")
	var items = ItemDatabase.get_all_items()
	print("Registered items count: ", items.size())
	if items.size() < 15:
		printerr("FAIL: Expected at least 15 items in ItemDatabase, found: ", items.size())
		all_passed = false
	else:
		print("PASS: ItemDatabase contains %d items." % items.size())

	# Check essential items
	for check_id in ["berries", "branches", "rags", "scrap", "circuit", "log", "axe", "knife", "bow", "crossbow", "rifle", "pistol", "arrow", "bolt", "ammo_rifle", "ammo_9mm", "gasmask", "jacket", "boots", "backpack_tier2", "turret", "furniture_chair", "lantern"]:
		if not ItemDatabase.has_item(check_id):
			printerr("FAIL: Missing essential item: ", check_id)
			all_passed = false
		else:
			var it = ItemDatabase.get_item(check_id)
			print("  ✓ %s ('%s'): portable=%s, is_log=%s, max_stack=%d" % [check_id, it.display_name, str(it.is_portable), str(it.is_log), it.max_stack])

	# --- TEST 2: Log Rejection & Stack Size 5 ---
	print("\n--- TEST 2: Log Exclusions & Stacking (Max 5) ---")
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		var inv_script = load("res://scripts/inventory/inventory_manager.gd")
		inv = inv_script.new()
		inv.name = "InventoryManager"
		get_tree().root.add_child(inv)

	# Test log rejection
	var log_can_add = inv.can_add_item("log", 1)
	if log_can_add:
		printerr("FAIL: Logs must NOT be allowed in the backpack!")
		all_passed = false
	else:
		print("PASS: Successfully rejected log from inventory (can_add_item('log') == false).")

	# Test heavy object rejection from backpack
	var turret_can_add = inv.can_add_item("turret", 1)
	if turret_can_add:
		printerr("FAIL: Heavy non-portable objects must NOT be allowed in backpack!")
		all_passed = false
	else:
		print("PASS: Successfully rejected non-portable turret from backpack.")

	# Test stacking limit of 5
	var branches_item = ItemDatabase.get_item("branches")
	if branches_item.max_stack != 5:
		printerr("FAIL: Expected branches max_stack to be 5, got: ", branches_item.max_stack)
		all_passed = false
	else:
		print("PASS: Branches max_stack is 5 as requested.")

	# --- TEST 3: Warband Style Equipment Slots ---
	print("\n--- TEST 3: Mount & Blade: Warband Style Equipment Slots ---")
	print("Equipment slots: ", inv.equipment.keys())
	for slot_key in ["weapon_1", "weapon_2", "weapon_3", "weapon_4", "head", "body", "feet"]:
		if not inv.equipment.has(slot_key):
			printerr("FAIL: Missing equipment slot: ", slot_key)
			all_passed = false
		else:
			var current_item = inv.equipment[slot_key]
			var name_str = current_item["item_id"] if current_item else "Empty"
			print("  ✓ Slot '%s': %s" % [slot_key, name_str])

	# Test equipping into weapon_3 and weapon_4
	inv.add_item("knife", 1)
	inv.add_item("arrow", 5)
	var knife_idx = inv._find_item_slot_idx("knife")
	var arrow_idx = inv._find_item_slot_idx("arrow")
	if knife_idx != -1:
		inv.equip_item_from_backpack(knife_idx, "weapon_3")
		print("PASS: Equipped knife into weapon_3 slot: ", inv.equipment["weapon_3"])
	if arrow_idx != -1:
		inv.equip_item_from_backpack(arrow_idx, "weapon_4")
		print("PASS: Equipped arrows into weapon_4 slot: ", inv.equipment["weapon_4"])

	# --- TEST 4: Backpack Upgrade Progression ---
	print("\n--- TEST 4: Backpack Upgrades ---")
	var initial_cap: int = inv.backpack_capacity
	print("Initial backpack capacity: ", initial_cap)
	inv.upgrade_backpack(25, "Охотничий рюкзак (T2)")
	if inv.backpack_capacity != 25 or inv.backpack_slots.size() != 25:
		printerr("FAIL: Backpack capacity failed to upgrade to 25!")
		all_passed = false
	else:
		print("PASS: Successfully upgraded backpack to 25 slots.")

	# --- TEST 5: Hotbar 5 Slots ---
	print("\n--- TEST 5: 5-Slot Bottom Hotbar ---")
	if inv.HOTBAR_SIZE != 5 or inv.hotbar_slots.size() != 5:
		printerr("FAIL: Expected 5 hotbar slots, found: ", inv.hotbar_slots.size())
		all_passed = false
	else:
		print("PASS: 5-slot hotbar confirmed.")

	# --- TEST 6: Workbench Crafting & Portability Flag ---
	print("\n--- TEST 6: Workbench Crafting (Portable vs Heavy) ---")
	var recipes = CraftingDatabase.get_all_recipes()
	print("Available recipes count: ", recipes.size())
	if recipes.size() < 10:
		printerr("FAIL: Expected at least 10 recipes, found: ", recipes.size())
		all_passed = false

	# Test portable crafting (e.g. arrows)
	var arrow_recipe = CraftingDatabase.get_recipe_by_id("craft_arrow")
	if not arrow_recipe:
		printerr("FAIL: craft_arrow recipe not found!")
		all_passed = false
	else:
		print("PASS: Found craft_arrow recipe (is_portable = %s, output = %s x%d)" % [
			str(arrow_recipe.is_portable), arrow_recipe.output_item_id, arrow_recipe.output_count
		])

	# Test non-portable / heavy crafting (e.g. turret, chair, table)
	for heavy_id in ["craft_turret", "craft_chair", "craft_table"]:
		var heavy_recipe = CraftingDatabase.get_recipe_by_id(heavy_id)
		if not heavy_recipe:
			printerr("FAIL: Recipe not found: ", heavy_id)
			all_passed = false
		elif heavy_recipe.is_portable:
			printerr("FAIL: Expected %s to be non-portable (is_portable == false)!" % heavy_id)
			all_passed = false
		else:
			print("PASS: Confirmed %s is non-portable (spawns beside workbench)." % heavy_id)

	# Test crafting execution
	inv.add_item("branches", 5)
	inv.add_item("scrap", 5)
	var axe_recipe = CraftingDatabase.get_recipe_by_id("craft_axe")
	var axe_crafted = inv.craft_recipe(axe_recipe)
	if not axe_crafted:
		printerr("FAIL: Could not craft axe with available materials!")
		all_passed = false
	else:
		print("PASS: Successfully crafted portable axe into backpack.")

	# Test heavy craft execution (turret)
	inv.add_item("scrap", 5)
	inv.add_item("circuit", 3)
	inv.add_item("branches", 3)
	var turret_recipe = CraftingDatabase.get_recipe_by_id("craft_turret")
	var turret_crafted = inv.craft_recipe(turret_recipe, Vector3(2, 0, 8))
	if not turret_crafted:
		printerr("FAIL: Could not craft turret!")
		all_passed = false
	else:
		print("PASS: Successfully crafted heavy turret (spawned next to workbench).")

	# --- TEST 5: Architect Mode UI Transition & Mobile Building Buttons ---
	print("\n--- TEST 5: Architect Mode UI Isolation & Mobile Construction Cards ---")
	var inv_ui_scene = load("res://scenes/inventory/InventoryUI.tscn")
	var hotbar_ui_scene = load("res://scenes/inventory/HotbarUI.tscn")
	var arch_ui_scene = load("res://scenes/ui/ArchitectUI.tscn")

	var inv_ui = inv_ui_scene.instantiate() as InventoryUI
	var hotbar_ui = hotbar_ui_scene.instantiate() as HotbarUI
	var arch_ui = arch_ui_scene.instantiate() as ArchitectUI

	add_child(inv_ui)
	add_child(hotbar_ui)
	add_child(arch_ui)

	# 1. Open inventory in FPV mode
	inv_ui.open_inventory()
	if not inv_ui.visible or not inv.is_inventory_open:
		printerr("FAIL: Expected inventory to open in FPV mode!")
		all_passed = false
	else:
		print("PASS: Inventory successfully opened in FPV mode.")

	# 2. Switch to Architect Mode
	print("  Switching to CameraMode.ARCHITECT...")
	GameEvents.camera_mode_changed.emit(GameEnums.CameraMode.ARCHITECT)

	if inv_ui.visible:
		printerr("FAIL: InventoryUI MUST be hidden/closed when entering Architect mode!")
		all_passed = false
	else:
		print("PASS: InventoryUI automatically closed upon entering Architect mode.")

	if inv.is_inventory_open:
		printerr("FAIL: InventoryManager.is_inventory_open must be false in Architect mode!")
		all_passed = false
	else:
		print("PASS: InventoryManager.is_inventory_open is false.")

	# 3. Test inventory opening suppression while in Architect mode
	inv_ui.open_inventory()
	if inv_ui.visible:
		printerr("FAIL: Opening inventory must be blocked in Architect mode!")
		all_passed = false
	else:
		print("PASS: Opening inventory is blocked while in Architect mode.")

	# 4. Verify Hotbar is hidden
	if hotbar_ui.visible:
		printerr("FAIL: HotbarUI MUST be hidden in Architect mode!")
		all_passed = false
	else:
		print("PASS: HotbarUI is hidden in Architect mode.")

	# 5. Verify ArchitectUI is visible with building cards
	if not arch_ui.visible:
		printerr("FAIL: ArchitectUI MUST be visible in Architect mode!")
		all_passed = false
	else:
		print("PASS: ArchitectUI is visible in Architect mode.")

	var dock = arch_ui.find_child("DockContainer", true, false)
	if not dock or dock.get_child_count() != 5:
		printerr("FAIL: Expected 5 mobile building cards in ArchitectUI dock, found: ", dock.get_child_count() if dock else 0)
		all_passed = false
	else:
		print("PASS: ArchitectUI contains %d mobile construction cards." % dock.get_child_count())
		for c in dock.get_children():
			var btn = c as Button
			print("   Card: ", btn.text.replace("\n", " | "))

	# 6. Switch back to FPV Mode
	print("  Switching back to CameraMode.FPV...")
	GameEvents.camera_mode_changed.emit(GameEnums.CameraMode.FPV)

	if not hotbar_ui.visible:
		printerr("FAIL: HotbarUI MUST become visible again in FPV mode!")
		all_passed = false
	else:
		print("PASS: HotbarUI restored in FPV mode.")

	if arch_ui.visible:
		printerr("FAIL: ArchitectUI must be hidden in FPV mode!")
		all_passed = false
	else:
		print("PASS: ArchitectUI hidden in FPV mode.")

	# 7. Clean up test nodes
	inv_ui.queue_free()
	hotbar_ui.queue_free()
	arch_ui.queue_free()

	# --- TEST 6: Dual Control Systems (PC Keyboard/Mouse + Mobile Touchscreen) ---
	print("\n--- TEST 6: Dual Controls Verification (PC & Mobile Touch) ---")
	var touch_controls_scene = load("res://scenes/ui/TouchControls.tscn")
	var touch_controls = touch_controls_scene.instantiate() as TouchControls
	add_child(touch_controls)

	# 1. Enable touch controls explicitly
	touch_controls.set_touch_enabled(true)
	if not touch_controls.visible:
		printerr("FAIL: TouchControls must be visible when enabled!")
		all_passed = false
	else:
		print("PASS: TouchControls successfully enabled and visible.")

	# 2. Test Virtual Joystick input injection
	var joystick = touch_controls.find_child("VirtualJoystick", true, false) as TouchJoystick
	if not joystick:
		printerr("FAIL: VirtualJoystick not found in TouchControls!")
		all_passed = false
	else:
		# Emulate dragging joystick forward
		joystick._update_knob(Vector2(joystick.size.x * 0.5, joystick.size.y * 0.5 - joystick.radius))
		var forward_strength = Input.get_action_strength("move_forward")
		if forward_strength < 0.9:
			printerr("FAIL: Expected move_forward action strength >= 0.9, got: ", forward_strength)
			all_passed = false
		else:
			print("PASS: VirtualJoystick drives 'move_forward' strength: ", forward_strength)

		# Emulate releasing joystick
		joystick._reset()
		var reset_strength = Input.get_action_strength("move_forward")
		if reset_strength != 0.0:
			printerr("FAIL: Expected move_forward to reset to 0.0, got: ", reset_strength)
			all_passed = false
		else:
			print("PASS: VirtualJoystick resets action strength to 0.0 on release.")

	# 3. Test Player look rotation (works for both mouse drag & touch swipe)
	var player_scene = load("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate() as PlayerController
	add_child(player)

	var initial_rot_y = player.rotation.y
	player.apply_look_rotation(Vector2(100.0, 50.0))
	if player.rotation.y == initial_rot_y:
		printerr("FAIL: apply_look_rotation did not rotate player!")
		all_passed = false
	else:
		print("PASS: apply_look_rotation correctly updated player yaw & pitch for PC/touch.")

	# 4. Test Player Jump & Sprint toggle
	player.set_sprint(true)
	if not player.wants_sprint_toggle:
		printerr("FAIL: Player sprint toggle failed!")
		all_passed = false
	else:
		print("PASS: Player sprint toggle verified.")

	# 5. Verify TouchControls hide when entering Architect Mode
	GameEvents.camera_mode_changed.emit(GameEnums.CameraMode.ARCHITECT)
	if touch_controls.visible:
		printerr("FAIL: TouchControls must hide in Architect mode!")
		all_passed = false
	else:
		print("PASS: TouchControls automatically hid in Architect mode.")

	# 6. Switch back to FPV and clean up
	GameEvents.camera_mode_changed.emit(GameEnums.CameraMode.FPV)
	if not touch_controls.visible:
		printerr("FAIL: TouchControls must restore in FPV mode when enabled!")
		all_passed = false
	else:
		print("PASS: TouchControls restored in FPV mode.")

	touch_controls.queue_free()
	player.queue_free()

	# --- TEST 7: Platform UI Mode Adaptation (PC vs Mobile) ---
	print("\n--- TEST 7: Platform UI Mode Adaptation (PC vs Mobile) ---")
	var sm = get_node_or_null("/root/SettingsManager")
	if not sm:
		printerr("FAIL: SettingsManager autoload not found!")
		all_passed = false
	else:
		# 1. Instantiate UI elements
		var test_hud_scene = load("res://scenes/ui/HUD.tscn")
		var test_hotbar_scene = load("res://scenes/inventory/HotbarUI.tscn")
		var test_inv_scene = load("res://scenes/inventory/InventoryUI.tscn")
		var test_arch_scene = load("res://scenes/ui/ArchitectUI.tscn")

		var test_hud = test_hud_scene.instantiate()
		var hud_ctrl = test_hud.find_child("HUDController", true, false) as HUDController
		var test_hotbar = test_hotbar_scene.instantiate() as HotbarUI
		var test_inv_ui = test_inv_scene.instantiate() as InventoryUI
		var test_arch_ui = test_arch_scene.instantiate() as ArchitectUI

		add_child(test_hud)
		add_child(test_hotbar)
		add_child(test_inv_ui)
		add_child(test_arch_ui)

		# 2. Switch to PC UI Mode
		print("  Setting UI Mode: PC...")
		sm.set_ui_mode(SettingsManager.UIMode.PC)
		if sm.is_mobile_ui():
			printerr("FAIL: Expected sm.is_mobile_ui() to be false in PC mode!")
			all_passed = false
		else:
			print("PASS: SettingsManager confirmed PC mode (is_mobile_ui == false).")

		# Check PC HUD tablet button
		if hud_ctrl:
			var tablet_btn := hud_ctrl.find_child("TabletButton", true, false) as Button
			if tablet_btn and not tablet_btn.text.contains("[Tab]"):
				printerr("FAIL: PC HUD tablet button should contain '[Tab]', got: ", tablet_btn.text)
				all_passed = false
			else:
				print("PASS: PC HUD tablet button contains '[Tab]' hotkey hint.")

		# Check PC Hotbar button formatting
		var first_hotbar_btn = test_hotbar.slot_buttons[0]
		if not first_hotbar_btn.text.begins_with("[1]"):
			printerr("FAIL: PC Hotbar slot 1 should begin with '[1]', got: ", first_hotbar_btn.text)
			all_passed = false
		else:
			print("PASS: PC Hotbar slot has '[1]' prefix.")

		# Check PC Architect card formatting
		var first_arch_card = test_arch_ui._building_cards[0]
		if not first_arch_card.text.begins_with("[ 1 ]"):
			printerr("FAIL: PC Architect card 1 should begin with '[ 1 ]', got: ", first_arch_card.text)
			all_passed = false
		else:
			print("PASS: PC Architect card has '[ 1 ]' hotkey index.")

		# Check PC Architect action button
		if not test_arch_ui.rotate_btn.text.contains("[R]"):
			printerr("FAIL: PC Architect rotate button should contain '[R]', got: ", test_arch_ui.rotate_btn.text)
			all_passed = false
		else:
			print("PASS: PC Architect rotate button contains '[R]'.")

		# 3. Switch to Mobile UI Mode
		print("  Setting UI Mode: MOBILE...")
		sm.set_ui_mode(SettingsManager.UIMode.MOBILE)
		if not sm.is_mobile_ui():
			printerr("FAIL: Expected sm.is_mobile_ui() to be true in MOBILE mode!")
			all_passed = false
		else:
			print("PASS: SettingsManager confirmed Mobile mode (is_mobile_ui == true).")

		# Check Mobile HUD tablet button
		if hud_ctrl:
			var tablet_btn := hud_ctrl.find_child("TabletButton", true, false) as Button
			if tablet_btn and tablet_btn.text.contains("[Tab]"):
				printerr("FAIL: Mobile HUD tablet button should NOT contain '[Tab]', got: ", tablet_btn.text)
				all_passed = false
			else:
				print("PASS: Mobile HUD tablet button has clean touch label: '%s'" % (tablet_btn.text if tablet_btn else ""))

		# Check Mobile Hotbar button formatting (no [1] prefix, larger size)
		if first_hotbar_btn.text.begins_with("[1]"):
			printerr("FAIL: Mobile Hotbar slot should NOT have '[1]' prefix, got: ", first_hotbar_btn.text)
			all_passed = false
		else:
			print("PASS: Mobile Hotbar button clean text without '[1]': '%s'" % first_hotbar_btn.text.replace("\n", " "))

		if first_hotbar_btn.custom_minimum_size != Vector2(84, 70):
			printerr("FAIL: Mobile Hotbar button size should be (84, 70), got: ", first_hotbar_btn.custom_minimum_size)
			all_passed = false
		else:
			print("PASS: Mobile Hotbar button enlarged to touch-friendly (84, 70).")

		# Check Mobile Architect card formatting
		first_arch_card = test_arch_ui._building_cards[0]
		if first_arch_card.text.begins_with("[ 1 ]"):
			printerr("FAIL: Mobile Architect card should NOT have '[ 1 ]' prefix, got: ", first_arch_card.text)
			all_passed = false
		else:
			print("PASS: Mobile Architect card clean touch format without keyboard keys.")

		# Check Mobile Architect action buttons
		if test_arch_ui.rotate_btn.text.contains("[R]"):
			printerr("FAIL: Mobile Architect rotate button should NOT have '[R]', got: ", test_arch_ui.rotate_btn.text)
			all_passed = false
		else:
			print("PASS: Mobile Architect rotate button clean touch text: '%s'" % test_arch_ui.rotate_btn.text)

		# Check Mobile Inventory UI close button
		if test_inv_ui.close_btn.text.contains("[ Q"):
			printerr("FAIL: Mobile Inventory close button should NOT contain '[ Q', got: ", test_inv_ui.close_btn.text)
			all_passed = false
		else:
			print("PASS: Mobile Inventory close button clean touch text: '%s'" % test_inv_ui.close_btn.text)

		# Reset back to Auto
		sm.set_ui_mode(SettingsManager.UIMode.AUTO)

		if is_instance_valid(test_hud): test_hud.queue_free()
		if is_instance_valid(test_hotbar): test_hotbar.queue_free()
		if is_instance_valid(test_inv_ui): test_inv_ui.queue_free()
		if is_instance_valid(test_arch_ui): test_arch_ui.queue_free()

	print("\n==================================================")
	if all_passed:
		print("🎉 ALL TESTS PASSED SUCCESSFULLY! 100% VERIFIED!")
	else:
		printerr("❌ SOME TESTS FAILED!")
	print("==================================================")

	get_tree().quit(0 if all_passed else 1)
