extends Node

func _ready() -> void:
	print("=== RUNNING PERIMETER ECONOMY, RESOURCES & BARTER TESTS ===")

	# --------------------------------------------------------------------------
	# Test 1: Autoload EconomyManager verification
	# --------------------------------------------------------------------------
	var eco = get_node_or_null("/root/EconomyManager")
	assert(eco != null, "EconomyManager Autoload must exist in root!")
	print("[PASS] EconomyManager singleton loaded successfully.")

	# Verify baseline limits and storage
	assert(eco.max_shoulder_logs == 3, "Max shoulder logs must be 3")
	assert(eco.max_fuel_canisters == 2, "Max fuel canisters must be 2")
	assert(eco.max_pocket_scrap == 50, "Max pocket scrap must be 50")
	assert(eco.base_storage["logs"] == 12, "Initial logs must be 12")
	assert(eco.base_storage["scrap"] == 25, "Initial scrap must be 25")
	assert(eco.base_storage["fuel"] == 1, "Initial fuel must be 1")
	assert(eco.base_storage["rations"] == 10, "Initial rations must be 10")
	assert(eco.base_storage["amber"] == 0, "Initial amber must be 0")
	assert(eco.base_storage["canned_spores"] == 0, "Initial canned spores must be 0")
	assert(eco.base_storage["raw_spores"] == 0, "Initial raw spores must be 0")
	assert(eco.base_storage["salt"] == 4, "Initial salt must be 4")
	assert(eco.base_storage["empty_jars"] == 3, "Initial empty jars must be 3")
	print("[PASS] Initial storage values and carry limits verified.")

	# --------------------------------------------------------------------------
	# Test 2: Log Operations (Strict shoulder limit = 3 logs)
	# --------------------------------------------------------------------------
	eco.player_logs = 0
	assert(eco.can_pickup_log() == true, "Must be able to pick up log when player_logs == 0")
	assert(eco.pickup_log() == true, "1st log pickup should succeed")
	assert(eco.pickup_log() == true, "2nd log pickup should succeed")
	assert(eco.pickup_log() == true, "3rd log pickup should succeed")
	assert(eco.player_logs == 3, "Player should have exactly 3 logs")
	assert(eco.can_pickup_log() == false, "Must NOT be able to pick up 4th log")
	assert(eco.pickup_log() == false, "4th log pickup must return false")
	assert(eco.player_logs == 3, "Player logs must remain 3")

	var initial_base_logs: int = eco.base_storage["logs"]
	var deposited: int = eco.deposit_logs_to_base()
	assert(deposited == 3, "Must deposit 3 logs")
	assert(eco.player_logs == 0, "Player logs must be 0 after depositing")
	assert(eco.base_storage["logs"] == initial_base_logs + 3, "Base logs must increase by 3")

	var take_success: bool = eco.take_logs_from_base(2)
	assert(take_success == true, "Should withdraw 2 logs from base")
	assert(eco.player_logs == 2, "Player should carry 2 logs")
	eco.deposit_logs_to_base()
	print("[PASS] Strict shoulder log limit (max 3) and base deposit/take verified.")

	# --------------------------------------------------------------------------
	# Test 3: Scrap & Fuel Canisters
	# --------------------------------------------------------------------------
	eco.player_fuel = 0
	assert(eco.add_fuel_canister() == true, "1st fuel canister should succeed")
	assert(eco.add_fuel_canister() == true, "2nd fuel canister should succeed")
	assert(eco.can_pickup_fuel() == false, "Should not exceed max 2 canisters")
	assert(eco.add_fuel_canister() == false, "3rd canister must be blocked")

	var initial_base_fuel: int = eco.base_storage["fuel"]
	eco.deposit_fuel_to_base()
	assert(eco.player_fuel == 0, "Player fuel should be reset")
	assert(eco.base_storage["fuel"] == initial_base_fuel + 2, "Base fuel should increase by 2")

	var initial_scrap: int = eco.base_storage["scrap"]
	eco.add_scrap(15)
	assert(eco.base_storage["scrap"] == initial_scrap + 15, "Base scrap should increase by 15")
	print("[PASS] Scrap stacking and fuel canister limits verified.")

	# --------------------------------------------------------------------------
	# Test 4: Tectonic Amber (Internal defense only, cannot be traded)
	# --------------------------------------------------------------------------
	eco.base_storage["amber"] = 0
	eco.add_amber(5)
	assert(eco.base_storage["amber"] == 5, "Base amber should be 5")
	assert(eco.consume_amber_for_uv(2) == true, "Should consume 2 amber for UV lamps")
	assert(eco.base_storage["amber"] == 3, "Remaining amber should be 3")
	assert(eco.consume_amber_for_uv(10) == false, "Cannot consume more amber than stored")
	assert(eco.base_storage["amber"] == 3, "Amber should remain 3")

	# Check BarterSystem rejection of amber
	var barter = BarterSystem.new()
	add_child(barter)
	assert(barter.can_trade_resource("amber") == false, "Tectonic amber CANNOT be traded!")
	var amber_trade_result: Dictionary = barter.attempt_trade_amber()
	assert(amber_trade_result["success"] == false, "Trading amber must be rejected")
	print("[PASS] Tectonic amber internal use (consume_amber_for_uv) and barter ban verified.")

	# --------------------------------------------------------------------------
	# Test 5: Two-stage Spore System (Raw decay vs Canning workbench)
	# --------------------------------------------------------------------------
	eco.base_storage["raw_spores"] = 0
	eco.harvest_raw_gland(3)
	assert(eco.base_storage["raw_spores"] == 3, "Raw spores should be 3")

	# Spoilage of raw glands
	var spoiled: int = eco.rot_raw_glands(1)
	assert(spoiled == 1, "1 raw gland should spoil")
	assert(eco.base_storage["raw_spores"] == 2, "Raw spores should now be 2")

	# Canning preparation: 1 raw spore + 1 jar + 1 salt -> 1 canned spore
	eco.base_storage["empty_jars"] = 1
	eco.base_storage["salt"] = 1
	eco.base_storage["canned_spores"] = 0
	assert(eco.can_can_spores() == true, "Should be able to can spores")

	var canning_success: bool = eco.process_spore_canning()
	assert(canning_success == true, "Canning should succeed")
	assert(eco.base_storage["canned_spores"] == 1, "Canned spores should be 1")
	assert(eco.base_storage["raw_spores"] == 1, "Raw spores should decrease to 1")
	assert(eco.base_storage["empty_jars"] == 0, "Empty jars should be 0")
	assert(eco.base_storage["salt"] == 0, "Salt should be 0")

	# Second attempt fails due to missing jar and salt
	assert(eco.can_can_spores() == false, "Cannot can spores without jars/salt")
	assert(eco.process_spore_canning() == false, "Canning must fail when ingredients missing")
	print("[PASS] Spore harvest, decay (rot_raw_glands) and canning verified.")

	# --------------------------------------------------------------------------
	# Test 6: Spore Canning Station (Interactive Workbench)
	# --------------------------------------------------------------------------
	var station_scene: PackedScene = load("res://scenes/spore_canning_station.tscn")
	assert(station_scene != null, "scenes/spore_canning_station.tscn must load")
	var station = station_scene.instantiate()
	assert(station != null, "SporeCanningStation must instantiate correctly")
	add_child(station)

	# With missing ingredients (salt=0, jars=0, raw_spores=1)
	var info_missing: Dictionary = station.get_interaction_info(null)
	assert(info_missing["type"] == "NEED_ITEMS", "Should prompt NEED_ITEMS")

	# Add ingredients
	eco.base_storage["empty_jars"] = 2
	eco.base_storage["salt"] = 2
	var info_ready: Dictionary = station.get_interaction_info(null)
	assert(info_ready["type"] == "CRAFT_CAN", "Should prompt CRAFT_CAN")

	station.interact(null)
	assert(eco.base_storage["canned_spores"] == 2, "Canned spores should now be 2")
	station.queue_free()
	print("[PASS] SporeCanningStation workbench interaction verified.")

	# --------------------------------------------------------------------------
	# Test 7: Black Market Courier & Barter System (barter_system.gd)
	# --------------------------------------------------------------------------
	barter.current_trader_active = false
	barter.days_since_last_visit = 0

	# Process 3 days: trader arrives with high chance, guaranteed at day 4
	barter.process_new_day() # day 1
	assert(barter.days_since_last_visit == 1)
	barter.process_new_day() # day 2
	assert(barter.days_since_last_visit == 2)
	barter.process_new_day() # day 3
	# Force day 4 if not spawned yet
	if not barter.current_trader_active:
		barter.process_new_day()
	assert(barter.current_trader_active == true, "Courier should arrive by day 4 guaranteed")
	print("[PASS] Black Market Courier visit timing verified.")

	# Trade test: Catalog index 0: Ammo crate (cost 1 canned spore -> 10 rifle ammo)
	eco.base_storage["canned_spores"] = 1
	var initial_rifle_ammo: int = eco.base_storage.get("ammo_rifle", 0)

	var signal_trade_item := [""]
	var callable := func(item_received: String) -> void:
		signal_trade_item[0] = item_received
	barter.trade_completed.connect(callable)

	var trade_done: bool = barter.execute_trade(0)
	assert(trade_done == true, "Trade should succeed")
	assert(eco.base_storage["canned_spores"] == 0, "1 canned spore consumed")
	assert(eco.base_storage["ammo_rifle"] == initial_rifle_ammo + 10, "10 rifle ammo received")
	assert(signal_trade_item[0].contains("7.62"), "Signal should carry deal label")
	barter.trade_completed.disconnect(callable)

	# Try trading without funds
	var trade_failed: bool = barter.execute_trade(0)
	assert(trade_failed == false, "Trade must fail when spores are insufficient")
	print("[PASS] Barter trade execution (canned spores -> goods) verified.")

	# --------------------------------------------------------------------------
	# Test 8: Colony Daily Rations & Mercenary Weekly Cost
	# --------------------------------------------------------------------------
	eco.base_storage["rations"] = 6
	var feed_ok: bool = eco.daily_colony_feed(4)
	assert(feed_ok == true, "Feeding 4 colonists with 6 rations succeeds")
	assert(eco.base_storage["rations"] == 2, "2 rations remaining")

	var feed_deficit: bool = eco.daily_colony_feed(4)
	assert(feed_deficit == false, "Feeding 4 colonists with 2 rations fails with deficit")
	assert(eco.base_storage["rations"] == 0, "Rations emptied to 0 on deficit")

	# Mercenary payment (2 canned spores)
	eco.base_storage["canned_spores"] = 1
	assert(eco.pay_weekly_mercenary() == false, "Cannot pay mercenary with only 1 canned spore")
	eco.base_storage["canned_spores"] = 3
	assert(eco.pay_weekly_mercenary() == true, "Mercenary payment succeeds with >= 2 spores")
	assert(eco.base_storage["canned_spores"] == 1, "Remaining spores should be 1")
	print("[PASS] Colony daily rations and mercenary weekly pay verified.")

	# --------------------------------------------------------------------------
	# Test 9: Mercenary Sentry NPC & Post Abandonment
	# --------------------------------------------------------------------------
	var sentry_scene: PackedScene = load("res://scenes/mercenary_sentry.tscn")
	assert(sentry_scene != null, "scenes/mercenary_sentry.tscn must exist")
	var sentry = sentry_scene.instantiate()
	assert(sentry != null, "MercenarySentry must instantiate")
	add_child(sentry)

	# Initially not hired
	assert(sentry.is_hired == false)
	eco.base_storage["canned_spores"] = 0
	assert(sentry.hire() == false, "Cannot hire without 2 canned spores")

	eco.base_storage["canned_spores"] = 2
	assert(sentry.hire() == true, "Hire succeeds with 2 canned spores")
	assert(sentry.is_hired == true, "Mercenary is now hired")
	assert(sentry.days_contract_left == 7, "Contract starts at 7 days")

	# Simulate 6 midnight passes
	for day in range(6):
		sentry.process_midnight_check()
	assert(sentry.days_contract_left == 1, "Should have 1 day left after 6 days")

	# 7th midnight pass: contract renewal test
	eco.base_storage["canned_spores"] = 2
	sentry.process_midnight_check() # hits 0, auto-renews
	assert(sentry.days_contract_left == 7, "Contract should renew for 7 days when paid")
	assert(sentry.is_hired == true, "Still hired")

	# Now deplete spores and let contract run out
	eco.base_storage["canned_spores"] = 0
	for day in range(6):
		sentry.process_midnight_check()
	assert(sentry.days_contract_left == 1)

	# Final midnight with 0 spores -> abandon post
	sentry.process_midnight_check()
	assert(sentry.is_hired == false, "Mercenary must abandon post when unpaid")
	sentry.queue_free()
	print("[PASS] MercenarySentry contract countdown, auto-renewal, and abandonment verified.")

	# --------------------------------------------------------------------------
	# Test 10: TraderNPC Scene
	# --------------------------------------------------------------------------
	var trader_scene: PackedScene = load("res://scenes/trader_npc.tscn")
	assert(trader_scene != null, "scenes/trader_npc.tscn must exist")
	var trader = trader_scene.instantiate()
	assert(trader != null, "TraderNPC must instantiate")
	add_child(trader)

	barter._spawn_morning_trader()
	trader._on_trader_arrived("Курьер Черного Рынка")
	assert(trader.visible == true, "Trader should be visible on arrival")
	var trader_info: Dictionary = trader.get_interaction_info(null)
	assert(trader_info["type"].begins_with("TRADE"), "Trader interaction should be TRADE")

	barter._dismiss_trader()
	trader._on_trader_departed()
	assert(trader.visible == false, "Trader should be hidden after departure")
	trader.queue_free()
	barter.queue_free()
	print("[PASS] TraderNPC arrival, interaction prompt, and departure verified.")

	# --------------------------------------------------------------------------
	# Test 11: ResourcePickup Scene
	# --------------------------------------------------------------------------
	var pickup_scene: PackedScene = load("res://scenes/resource_pickup.tscn")
	assert(pickup_scene != null, "scenes/resource_pickup.tscn must exist")
	var pickup = pickup_scene.instantiate()
	pickup.resource_type = "scrap"
	pickup.amount = 12
	add_child(pickup)
	var scrap_before: int = eco.base_storage["scrap"]
	pickup.interact(null)
	assert(eco.base_storage["scrap"] == scrap_before + 12, "Scrap pickup must add to base storage")
	pickup.queue_free()
	print("[PASS] ResourcePickup scene interaction verified.")

	print("=== ALL ECONOMY, RESOURCES & BARTER TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
