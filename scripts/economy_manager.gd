# Autoload singleton: EconomyManager (registered in Project Settings -> Globals -> Autoload)
extends Node

# Сигналы обновления запасов
signal resources_updated
signal ration_consumed(success: bool, deficit: int)
signal mercenary_paid(success: bool)

# --- ИНВЕНТАРЬ ЕГЕРЯ (ПЕРЕНОСИМЫЙ) ---
@export_group("Player Carry Limits")
@export var max_shoulder_logs: int = 3
@export var max_fuel_canisters: int = 2
@export var max_pocket_scrap: int = 50

var player_logs: int = 0
var player_fuel: int = 0
var player_scrap: int = 0
var player_rations: int = 2

# --- СКЛАД КОРДОНА (ХРАНИЛИЩЕ БАЗЫ) ---
# Ресурсы, доступные строителям, часовым и печи
var base_storage: Dictionary = {
	"logs": 12,              # Дерево для частокола, бараков и топки
	"scrap": 25,             # Металлолом для капканов и арбалетов
	"fuel": 1,               # Канистры бензина для генератора/пилы
	"rations": 10,           # Суточный сухпаек колонии
	"amber": 0,              # Тектонический янтарь (только для наших нужд)
	"canned_spores": 0,      # Герметичные банки со споровыми железами (валюта)
	"raw_spores": 0,         # Сырые железы (риск порчи без консервации)
	"salt": 4,               # Каменная соль для раствора консервации
	"empty_jars": 3,         # Пустые банки из поселка
	"ammo_rifle": 8,         # Патроны для ружья егеря
	"ammo_arrow": 20         # Болты/стрелы для часовых
}

# --- ПОТРЕБЛЕНИЕ КОЛОНИИ ---
@export var food_per_colonist_day: int = 1
@export var merc_weekly_cost_glands: int = 2

# Автоматическая порча сырых желез со временем (если не законсервированы)
@export var auto_spoil_enabled: bool = true
@export var spoil_timer_interval: float = 60.0 # Секунд между порчей единицы сырых спор
var _spoil_timer: float = 0.0

func _ready() -> void:
	add_to_group("economy_system")

func _process(delta: float) -> void:
	if auto_spoil_enabled and base_storage.get("raw_spores", 0) > 0:
		_spoil_timer += delta
		if _spoil_timer >= spoil_timer_interval:
			_spoil_timer = 0.0
			rot_raw_glands(1)

# ==============================================================================
# 1. ОПЕРАЦИИ С БРЕВНАМИ (ФИЗИЧЕСКИЙ ПЕРЕНОС НА ПЛЕЧЕ)
# ==============================================================================
func can_pickup_log() -> bool:
	return player_logs < max_shoulder_logs

func pickup_log() -> bool:
	if can_pickup_log():
		player_logs += 1
		emit_signal("resources_updated")
		return true
	return false

func deposit_logs_to_base() -> int:
	var deposited: int = player_logs
	base_storage["logs"] += deposited
	player_logs = 0
	emit_signal("resources_updated")
	return deposited

func take_logs_from_base(amount: int = 1) -> bool:
	if base_storage["logs"] >= amount and (player_logs + amount) <= max_shoulder_logs:
		base_storage["logs"] -= amount
		player_logs += amount
		emit_signal("resources_updated")
		return true
	return false

# ==============================================================================
# 2. МЕТАЛЛОЛОМ И ТОПЛИВО
# ==============================================================================
func add_scrap(amount: int) -> void:
	base_storage["scrap"] += amount
	emit_signal("resources_updated")

func can_pickup_scrap(amount: int = 1) -> bool:
	return (player_scrap + amount) <= max_pocket_scrap

func pickup_scrap(amount: int = 1) -> bool:
	if can_pickup_scrap(amount):
		player_scrap += amount
		emit_signal("resources_updated")
		return true
	return false

func deposit_scrap_to_base() -> int:
	var deposited: int = player_scrap
	base_storage["scrap"] += deposited
	player_scrap = 0
	emit_signal("resources_updated")
	return deposited

func take_scrap_from_base(amount: int = 1) -> bool:
	if base_storage["scrap"] >= amount and (player_scrap + amount) <= max_pocket_scrap:
		base_storage["scrap"] -= amount
		player_scrap += amount
		emit_signal("resources_updated")
		return true
	return false

func can_pickup_fuel() -> bool:
	return player_fuel < max_fuel_canisters

func add_fuel_canister() -> bool:
	if player_fuel < max_fuel_canisters:
		player_fuel += 1
		emit_signal("resources_updated")
		return true
	return false

func deposit_fuel_to_base() -> void:
	base_storage["fuel"] += player_fuel
	player_fuel = 0
	emit_signal("resources_updated")

func take_fuel_from_base(amount: int = 1) -> bool:
	if base_storage["fuel"] >= amount and (player_fuel + amount) <= max_fuel_canisters:
		base_storage["fuel"] -= amount
		player_fuel += amount
		emit_signal("resources_updated")
		return true
	return false

# ==============================================================================
# 3. ТЕКТОНИЧЕСКИЙ ЯНТАРЬ (ВНУТРЕННИЕ ТЕХНОЛОГИИ)
# ==============================================================================
func add_amber(amount: int) -> void:
	base_storage["amber"] += amount
	emit_signal("resources_updated")

func consume_amber_for_uv(amount: int = 1) -> bool:
	if base_storage["amber"] >= amount:
		base_storage["amber"] -= amount
		emit_signal("resources_updated")
		return true
	return false

# ==============================================================================
# 4. СПОРОВЫЕ ЖЕЛЕЗЫ: СЫРЫЕ VS КОНСЕРВИРОВАННЫЕ В БАНКАХ
# ==============================================================================
func harvest_raw_gland(amount: int = 1) -> void:
	base_storage["raw_spores"] += amount
	emit_signal("resources_updated")

# Консервация: 1 сырая железа + 1 банка + 1 порция соли = 1 товарная банка
func can_can_spores() -> bool:
	return base_storage["raw_spores"] >= 1 and base_storage["empty_jars"] >= 1 and base_storage["salt"] >= 1

func process_spore_canning() -> bool:
	if can_can_spores():
		base_storage["raw_spores"] -= 1
		base_storage["empty_jars"] -= 1
		base_storage["salt"] -= 1
		base_storage["canned_spores"] += 1
		emit_signal("resources_updated")
		return true
	return false

# Порча сырых желез при длительном хранении на открытом воздухе
func rot_raw_glands(spoil_count: int = 1) -> int:
	var actual_spoil: int = mini(base_storage["raw_spores"], spoil_count)
	base_storage["raw_spores"] -= actual_spoil
	if actual_spoil > 0:
		emit_signal("resources_updated")
	return actual_spoil

# ==============================================================================
# 5. СУТОЧНЫЙ ПАЕК КОЛОНИИ И ОПЛАТА НАЕМНИКОВ
# ==============================================================================
func daily_colony_feed(colonists_count: int) -> bool:
	var required_food: int = colonists_count * food_per_colonist_day
	if base_storage["rations"] >= required_food:
		base_storage["rations"] -= required_food
		emit_signal("ration_consumed", true, 0)
		emit_signal("resources_updated")
		return true
	else:
		var deficit: int = required_food - base_storage["rations"]
		base_storage["rations"] = 0
		emit_signal("ration_consumed", false, deficit)
		emit_signal("resources_updated")
		return false

func pay_weekly_mercenary() -> bool:
	if base_storage["canned_spores"] >= merc_weekly_cost_glands:
		base_storage["canned_spores"] -= merc_weekly_cost_glands
		emit_signal("mercenary_paid", true)
		emit_signal("resources_updated")
		return true
	else:
		emit_signal("mercenary_paid", false)
		return false
