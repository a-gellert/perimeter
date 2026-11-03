extends Node
## Global Manager for In-App Purchases (Google Play Billing) and Unity Ads.
## Registered as Autoload: MonetizationManager.

# --- IAP SIGNALS ---
signal billing_connected
signal billing_disconnected
signal purchase_successful(product_id: String)
signal purchase_failed(product_id: String, error_message: String)
signal purchases_restored

# --- UNITY ADS SIGNALS ---
signal ads_initialized
signal rewarded_ad_loaded(placement_id: String)
signal rewarded_ad_failed_to_load(placement_id: String, error: String)
signal rewarded_ad_completed(placement_id: String)
signal interstitial_ad_completed(placement_id: String)
signal banner_ad_loaded
signal banner_ad_failed(error: String)

# --- IAP PRODUCT CATALOG ---
const PRODUCT_NO_ADS := "perimeter_no_ads"
const PRODUCT_STARTER_PACK := "perimeter_starter_pack"
const PRODUCT_AMBER_CACHE := "perimeter_amber_cache"
const PRODUCT_FUEL_CRATE := "perimeter_fuel_crate"

# --- UNITY ADS CONFIGURATION ---
@export var unity_game_id: String = "5700000" # Замените на реальный Game ID из Unity Dashboard
@export var test_mode: bool = true
@export var rewarded_placement: String = "Rewarded_Android"
@export var interstitial_placement: String = "Interstitial_Android"
@export var banner_placement: String = "Banner_Android"

# State
var is_billing_ready: bool = false
var is_ads_ready: bool = false
var owned_purchases: Dictionary = {} # product_id: bool
var is_no_ads_active: bool = false

# Underlying platform singletons (if exported to Android with plugin)
var _billing_singleton: Object = null
var _unity_ads_singleton: Object = null

# Callback storage for rewarded ads
var _pending_reward_callback: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_billing()
	_init_unity_ads()

# ==============================================================================
# IN-APP PURCHASES (GOOGLE PLAY BILLING)
# ==============================================================================

func _init_billing() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing_singleton = Engine.get_singleton("GodotGooglePlayBilling")
		_connect_billing_signals()
		_billing_singleton.startConnection()
		print("[MonetizationManager] Connecting to GodotGooglePlayBilling...")
	else:
		# На ПК / в редакторе эмулируем готовность биллинга
		is_billing_ready = true
		print("[MonetizationManager] Desktop/Editor mode: Google Play Billing mocked.")

func _connect_billing_signals() -> void:
	if not _billing_singleton:
		return
	
	if _billing_singleton.has_signal("connected"):
		_billing_singleton.connected.connect(_on_billing_connected)
	if _billing_singleton.has_signal("disconnected"):
		_billing_singleton.disconnected.connect(_on_billing_disconnected)
	if _billing_singleton.has_signal("purchases_updated"):
		_billing_singleton.purchases_updated.connect(_on_purchases_updated)
	if _billing_singleton.has_signal("purchase_error"):
		_billing_singleton.purchase_error.connect(_on_purchase_error)

func _on_billing_connected() -> void:
	is_billing_ready = true
	billing_connected.emit()
	print("[MonetizationManager] Google Play Billing connected successfully.")
	_query_purchases()

func _on_billing_disconnected() -> void:
	is_billing_ready = false
	billing_disconnected.emit()
	print("[MonetizationManager] Google Play Billing disconnected.")

func _query_purchases() -> void:
	if _billing_singleton:
		_billing_singleton.queryPurchases("inapp")

func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		var product_id: String = purchase.get("sku", "")
		if product_id.is_empty() and purchase.has("products"):
			var prods = purchase.get("products")
			if prods is Array and prods.size() > 0:
				product_id = prods[0]
		
		var purchase_state: int = purchase.get("purchase_state", 1) # 1 = PURCHASED
		if purchase_state == 1:
			_process_successful_purchase(product_id, purchase.get("purchase_token", ""))

func _on_purchase_error(code: int, message: String) -> void:
	print("[MonetizationManager] Purchase failed: code %d, message: %s" % [code, message])
	purchase_failed.emit("", message)

## Запуск покупки товара по ID
func purchase_product(product_id: String) -> void:
	if not is_billing_ready:
		purchase_failed.emit(product_id, "Billing system not ready.")
		return

	if _billing_singleton:
		var response = _billing_singleton.purchase(product_id)
		if response != null and response.has("status") and response.status != 0:
			purchase_failed.emit(product_id, "Purchase launch error: %s" % str(response))
	else:
		# Режим симуляции для ПК/редактора
		print("[MonetizationManager] Simulating purchase for: %s" % product_id)
		_process_successful_purchase(product_id, "mock_token_%d" % Time.get_unix_time_from_system())

func _process_successful_purchase(product_id: String, token: String) -> void:
	owned_purchases[product_id] = true
	
	match product_id:
		PRODUCT_NO_ADS:
			is_no_ads_active = true
			hide_banner_ad()
			print("[MonetizationManager] Ad-free status unlocked!")
		PRODUCT_STARTER_PACK:
			if EconomyManager:
				EconomyManager.add_scrap(50)
				EconomyManager.base_storage["fuel"] += 2
				EconomyManager.add_amber(10)
				EconomyManager.emit_signal("resources_updated")
		PRODUCT_AMBER_CACHE:
			if EconomyManager:
				EconomyManager.add_amber(25)
		PRODUCT_FUEL_CRATE:
			if EconomyManager:
				EconomyManager.base_storage["fuel"] += 5
				EconomyManager.emit_signal("resources_updated")

	# Потребление расходуемых товаров (consumables)
	if product_id != PRODUCT_NO_ADS and _billing_singleton:
		_billing_singleton.consumePurchase(token)

	purchase_successful.emit(product_id)

func restore_purchases() -> void:
	if _billing_singleton:
		_query_purchases()
	purchases_restored.emit()

func is_owned(product_id: String) -> bool:
	return owned_purchases.get(product_id, false)

# ==============================================================================
# UNITY ADS
# ==============================================================================

func _init_unity_ads() -> void:
	if Engine.has_singleton("GodotUnityAds"):
		_unity_ads_singleton = Engine.get_singleton("GodotUnityAds")
		_connect_unity_ads_signals()
		_unity_ads_singleton.init(unity_game_id, test_mode)
		print("[MonetizationManager] Initializing Unity Ads with Game ID: %s (Test: %s)" % [unity_game_id, test_mode])
	else:
		is_ads_ready = true
		ads_initialized.emit()
		print("[MonetizationManager] Desktop/Editor mode: Unity Ads mocked.")

func _connect_unity_ads_signals() -> void:
	if not _unity_ads_singleton:
		return
	
	if _unity_ads_singleton.has_signal("on_init_complete"):
		_unity_ads_singleton.on_init_complete.connect(_on_ads_init_complete)
	if _unity_ads_singleton.has_signal("on_ad_show_complete"):
		_unity_ads_singleton.on_ad_show_complete.connect(_on_ad_show_complete)

func _on_ads_init_complete() -> void:
	is_ads_ready = true
	ads_initialized.emit()
	print("[MonetizationManager] Unity Ads initialized successfully.")

func _on_ad_show_complete(placement_id: String, state: String) -> void:
	# state: "COMPLETED", "SKIPPED", "ERROR"
	if state == "COMPLETED":
		if placement_id == rewarded_placement:
			if _pending_reward_callback.is_valid():
				_pending_reward_callback.call()
				_pending_reward_callback = Callable()
			rewarded_ad_completed.emit(placement_id)
		elif placement_id == interstitial_placement:
			interstitial_ad_completed.emit(placement_id)
	else:
		print("[MonetizationManager] Ad show ended with state: %s" % state)

## Показ рекламы с вознаграждением (Rewarded Ad)
func show_rewarded_ad(on_reward: Callable = Callable()) -> void:
	_pending_reward_callback = on_reward
	
	if _unity_ads_singleton:
		_unity_ads_singleton.showRewarded(rewarded_placement)
	else:
		# Эмуляция в редакторе / на ПК
		print("[MonetizationManager] Mock Rewarded Ad completed!")
		if _pending_reward_callback.is_valid():
			_pending_reward_callback.call()
			_pending_reward_callback = Callable()
		rewarded_ad_completed.emit(rewarded_placement)

## Показ полноэкранной межстраничной рекламы (Interstitial Ad)
func show_interstitial_ad() -> void:
	if is_no_ads_active:
		print("[MonetizationManager] Interstitial skipped (No-Ads active).")
		return
		
	if _unity_ads_singleton:
		_unity_ads_singleton.showInterstitial(interstitial_placement)
	else:
		print("[MonetizationManager] Mock Interstitial Ad shown.")
		interstitial_ad_completed.emit(interstitial_placement)

## Баннерная реклама (Banner Ad)
func show_banner_ad() -> void:
	if is_no_ads_active:
		return
	if _unity_ads_singleton:
		_unity_ads_singleton.showBanner(banner_placement)

func hide_banner_ad() -> void:
	if _unity_ads_singleton:
		_unity_ads_singleton.hideBanner()
