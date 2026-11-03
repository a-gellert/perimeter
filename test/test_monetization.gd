extends Node

func _ready() -> void:
	print("=== RUNNING MONETIZATION, IAP & UNITY ADS TESTS ===")

	# 1. Autoload verification
	var monetization := get_node_or_null("/root/MonetizationManager")
	assert(monetization != null, "MonetizationManager Autoload singleton must exist!")
	assert(monetization.is_billing_ready == true, "Billing system should be ready")
	assert(monetization.is_ads_ready == true, "Unity Ads system should be initialized")
	print("[PASS] MonetizationManager singleton initialized successfully.")

	# 2. Test In-App Purchases: Starter Pack grants resources to EconomyManager
	var init_scrap: int = EconomyManager.base_storage["scrap"] if EconomyManager else 0
	var init_fuel: int = EconomyManager.base_storage["fuel"] if EconomyManager else 0
	var init_amber: int = EconomyManager.base_storage["amber"] if EconomyManager else 0

	var purchase_received := [false]
	var received_product_id := [""]
	var conn = monetization.purchase_successful.connect(func(id: String):
		purchase_received[0] = true
		received_product_id[0] = id
	)

	monetization.purchase_product(monetization.PRODUCT_STARTER_PACK)
	assert(purchase_received[0] == true, "purchase_successful signal must be emitted")
	assert(received_product_id[0] == monetization.PRODUCT_STARTER_PACK, "Product ID must match starter pack")
	assert(EconomyManager.base_storage["scrap"] == init_scrap + 50, "Starter pack must grant 50 scrap")
	assert(EconomyManager.base_storage["fuel"] == init_fuel + 2, "Starter pack must grant 2 fuel")
	assert(EconomyManager.base_storage["amber"] == init_amber + 10, "Starter pack must grant 10 amber")
	print("[PASS] In-App Purchase: Starter Pack reward delivery verified.")

	# 3. Test In-App Purchases: No-Ads status
	assert(monetization.is_no_ads_active == false, "No-ads should be false initially")
	monetization.purchase_product(monetization.PRODUCT_NO_ADS)
	assert(monetization.is_no_ads_active == true, "No-ads must become active after purchase")
	assert(monetization.is_owned(monetization.PRODUCT_NO_ADS) == true, "is_owned should return true")
	print("[PASS] In-App Purchase: No-Ads purchase verified.")

	# 4. Test Unity Ads: Rewarded Ad with callback
	var reward_callback_called := [false]
	var rewarded_ad_signal_received := [false]
	var conn_ad = monetization.rewarded_ad_completed.connect(func(_p: String):
		rewarded_ad_signal_received[0] = true
	)

	monetization.show_rewarded_ad(func():
		reward_callback_called[0] = true
	)
	assert(reward_callback_called[0] == true, "Rewarded Ad reward callback must be executed")
	assert(rewarded_ad_signal_received[0] == true, "rewarded_ad_completed signal must be emitted")
	print("[PASS] Unity Ads: Rewarded Ad and callback execution verified.")

	# 5. Test Unity Ads: Interstitial Ad
	var interstitial_signal_received := [false]
	var conn_inter = monetization.interstitial_ad_completed.connect(func(_p: String):
		interstitial_signal_received[0] = true
	)
	monetization.show_interstitial_ad()
	# Because no-ads is active, interstitial should be skipped
	assert(interstitial_signal_received[0] == false, "Interstitial should be skipped when No-Ads is active")

	monetization.is_no_ads_active = false
	monetization.show_interstitial_ad()
	assert(interstitial_signal_received[0] == true, "Interstitial should trigger when No-Ads is inactive")
	print("[PASS] Unity Ads: Interstitial Ad and No-Ads filter verified.")

	# 6. Verify Android Manifest & Export Presets configuration on disk
	var manifest_file := FileAccess.open("res://android/build/src/main/AndroidManifest.xml", FileAccess.READ)
	assert(manifest_file != null, "AndroidManifest.xml must exist")
	var manifest_content := manifest_file.get_as_text()
	manifest_file.close()

	assert(manifest_content.contains("com.android.vending.BILLING"), "Manifest must declare com.android.vending.BILLING")
	assert(manifest_content.contains("android.permission.INTERNET"), "Manifest must declare INTERNET")
	assert(manifest_content.contains("android.permission.ACCESS_NETWORK_STATE"), "Manifest must declare ACCESS_NETWORK_STATE")
	assert(manifest_content.contains("com.google.android.gms.permission.AD_ID"), "Manifest must declare AD_ID for Unity Ads")
	print("[PASS] AndroidManifest.xml permissions & queries verified.")

	var gradle_file := FileAccess.open("res://android/build/build.gradle", FileAccess.READ)
	assert(gradle_file != null, "build.gradle must exist")
	var gradle_content := gradle_file.get_as_text()
	gradle_file.close()

	assert(gradle_content.contains("com.android.billingclient:billing:8.0.0"), "build.gradle must contain billingclient version 8.0.0+")
	assert(gradle_content.contains("com.unity3d.ads:unity-ads"), "build.gradle must contain unity-ads dependency")
	print("[PASS] build.gradle dependencies verified with Billing 8.0.0.")

	print("=== ALL MONETIZATION TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
