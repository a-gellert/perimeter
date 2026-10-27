class_name MercenarySentry
extends CharacterBody3D

@export var is_hired: bool = false
var days_contract_left: int = 7

var _last_tracked_midnight_hour: int = -1

func _ready() -> void:
	add_to_group("mercenaries")
	add_to_group("allies")
	var bus: Node = get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("time_updated"):
		bus.time_updated.connect(_on_time_updated)

func _on_time_updated(hours: int, _minutes: int, _phase: int) -> void:
	if hours == 0 and _last_tracked_midnight_hour != 0:
		process_midnight_check()
	_last_tracked_midnight_hour = hours

func process_midnight_check() -> void:
	if not is_hired:
		return

	days_contract_left -= 1
	if days_contract_left <= 0:
		# Попытка продлить контракт за 2 банки споровых желез
		var eco := _get_economy()
		if eco and eco.pay_weekly_mercenary():
			days_contract_left = 7
		else:
			_abandon_post()

func hire() -> bool:
	if is_hired:
		return true

	var eco := _get_economy()
	if eco and eco.pay_weekly_mercenary():
		is_hired = true
		days_contract_left = 7
		return true
	return false

func _abandon_post() -> void:
	is_hired = false
	# Наемник складывает оружие, уходит за ворота кордона и покидает долину
	queue_free()

func get_interaction_info(_player: PlayerController) -> Dictionary:
	var eco := _get_economy()
	if not is_hired:
		var cost: int = eco.merc_weekly_cost_glands if eco else 2
		var available: int = eco.base_storage.get("canned_spores", 0) if eco else 0
		if available >= cost:
			return {
				"prompt": "Нанять часового-наемника (Плата: %d банки со спорами/нед.)" % cost,
				"type": "HIRE_MERC"
			}
		else:
			return {
				"prompt": "Нужно %d банки со спорами для найма наемника" % cost,
				"type": "BLOCKED"
			}
	else:
		return {
			"prompt": "Часовой-наемник на посту (Осталось: %d дн.)" % days_contract_left,
			"type": "MERC_STATUS"
		}

func interact(_player: PlayerController) -> void:
	if not is_hired:
		hire()

func _get_economy() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root and tree.root.has_node("EconomyManager"):
		return tree.root.get_node("EconomyManager")
	return null
