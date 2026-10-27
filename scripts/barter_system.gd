class_name BarterSystem
extends Node

signal trader_arrived(trader_type: String)
signal trader_departed
signal trade_completed(item_received: String)

enum TraderType { BLACK_MARKET_COURIER, BIO_RESEARCH_AGENT, MERCENARY_SCOUT }

var days_since_last_visit: int = 0
var current_trader_active: bool = false
var current_trader_type: TraderType = TraderType.BLACK_MARKET_COURIER

# Каталог предложений: [Цена в банках со спорами -> Награда]
var courier_trades: Array[Dictionary] = [
	{ "id": "ammo_crate", "cost_glands": 1, "reward_item": "ammo_rifle", "amount": 10, "label": "Ящик патронов 7.62 (10 шт.)" },
	{ "id": "med_kit", "cost_glands": 1, "reward_item": "first_aid", "amount": 2, "label": "Армейские аптечки (2 шт.)" },
	{ "id": "tactical_scope", "cost_glands": 3, "reward_item": "optics", "amount": 1, "label": "Охотничья оптика x4" },
	{ "id": "mil_respirator", "cost_glands": 5, "reward_item": "filter_mask", "amount": 1, "label": "Военный респиратор с фильтрами" },
	{ "id": "auto_turret_blueprint", "cost_glands": 10, "reward_item": "blueprint_turret", "amount": 1, "label": "Схема автономной турели" }
]

var _last_tracked_hour: int = -1

func _ready() -> void:
	add_to_group("barter_system")
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("time_updated"):
		bus.time_updated.connect(_on_time_updated)

func _on_time_updated(hours: int, _minutes: int, _phase: int) -> void:
	# Рассвет в 06:00: проверка прихода торговца
	if hours == 6 and _last_tracked_hour != 6:
		process_new_day()
	_last_tracked_hour = hours

# Вызывается циклом времени суток каждое утро в 06:00
func process_new_day() -> void:
	if current_trader_active:
		_dismiss_trader()

	days_since_last_visit += 1
	# Торговец приходит с шансом 80% на 3-й день или гарантированно на 4-й
	if days_since_last_visit >= 4 or (days_since_last_visit >= 3 and randf() < 0.8):
		_spawn_morning_trader()

func _spawn_morning_trader() -> void:
	days_since_last_visit = 0
	current_trader_active = true
	current_trader_type = TraderType.BLACK_MARKET_COURIER
	emit_signal("trader_arrived", "Курьер Черного Рынка")

func _dismiss_trader() -> void:
	current_trader_active = false
	emit_signal("trader_departed")

# Совершение сделки
func execute_trade(trade_index: int) -> bool:
	if not current_trader_active or trade_index < 0 or trade_index >= courier_trades.size():
		return false

	var deal: Dictionary = courier_trades[trade_index]
	var cost: int = deal["cost_glands"]

	var eco := _get_economy()
	if not eco:
		return false

	if eco.base_storage.get("canned_spores", 0) >= cost:
		eco.base_storage["canned_spores"] -= cost
		_grant_reward(deal["reward_item"], deal["amount"])
		eco.emit_signal("resources_updated")
		emit_signal("trade_completed", deal["label"])
		return true

	return false

func _grant_reward(item_key: String, amount: int) -> void:
	var eco := _get_economy()
	if not eco:
		return
	if eco.base_storage.has(item_key):
		eco.base_storage[item_key] += amount
	else:
		eco.base_storage[item_key] = amount

# --- ПРАВИЛО: ТЕКТОНИЧЕСКИЙ ЯНТАРЬ ЗАПРЕЩЕН К ПРОДАЖЕ ТОРГОВЦАМ ---
func can_trade_resource(resource_key: String) -> bool:
	if resource_key == "amber":
		return false
	return resource_key == "canned_spores"

func attempt_trade_amber() -> Dictionary:
	return {
		"success": false,
		"reason": "Тектонический янтарь запрещено продавать торговцам! Он расходуется базой на УФ-прожекторы."
	}

func _get_economy() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root and tree.root.has_node("EconomyManager"):
		return tree.root.get_node("EconomyManager")
	return null
