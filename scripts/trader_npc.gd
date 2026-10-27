class_name TraderNPC
extends CharacterBody3D
## Приходящий торговец у ворот кордона (Курьер Черного Рынка).
## Появляется каждые 3-4 дня на рассвете и предлагает редкое снаряжение за банки со споровыми железами.

@export var arrival_gate_position: Vector3 = Vector3(4.0, 0.0, -16.0)
@export var departure_hidden_position: Vector3 = Vector3(4.0, -100.0, -16.0)
@export var lantern_light: OmniLight3D

var current_deal_index: int = 0

func _ready() -> void:
	add_to_group("traders")
	add_to_group("npcs")
	_connect_barter_system()
	_update_presence(false)

func _connect_barter_system() -> void:
	var barter := _get_barter_system()
	if barter:
		if not barter.is_connected("trader_arrived", _on_trader_arrived):
			barter.trader_arrived.connect(_on_trader_arrived)
		if not barter.is_connected("trader_departed", _on_trader_departed):
			barter.trader_departed.connect(_on_trader_departed)
		_update_presence(barter.current_trader_active)

func _on_trader_arrived(_trader_type: String) -> void:
	_update_presence(true)

func _on_trader_departed() -> void:
	_update_presence(false)

func _update_presence(active: bool) -> void:
	visible = active
	if lantern_light:
		lantern_light.visible = active
	# Перемещаем либо к воротам, либо скрываем
	if active:
		global_position = arrival_gate_position
		collision_layer = 4 | 32 # Interactable + NPC
	else:
		global_position = departure_hidden_position
		collision_layer = 0

func get_interaction_info(_player: PlayerController) -> Dictionary:
	var barter := _get_barter_system()
	if not barter or not barter.current_trader_active:
		return {
			"prompt": "Курьер ушел в пустошь (приходит на рассвете раз в 3-4 дня)",
			"type": "BLOCKED"
		}

	var deals: Array[Dictionary] = barter.courier_trades
	if deals.is_empty():
		return { "prompt": "У курьера нет предложений", "type": "BLOCKED" }

	var deal: Dictionary = deals[current_deal_index % deals.size()]
	var eco := _get_economy()
	var canned: int = eco.base_storage.get("canned_spores", 0) if eco else 0
	var cost: int = deal["cost_glands"]

	var prompt_str: String = "Купить: %s (Цена: %d банок со спорами)" % [deal["label"], cost]
	if canned < cost:
		prompt_str += " [Не хватает банок! Есть: %d]" % canned
		return { "prompt": prompt_str, "type": "TRADE_NEED_SPORES" }
	else:
		return { "prompt": prompt_str, "type": "TRADE" }

func interact(_player: PlayerController) -> void:
	var barter := _get_barter_system()
	if not barter or not barter.current_trader_active:
		return

	var deals: Array[Dictionary] = barter.courier_trades
	if deals.is_empty():
		return

	var target_index: int = current_deal_index % deals.size()
	var success: bool = barter.execute_trade(target_index)
	if success:
		# Переключаем на следующее предложение в каталоге
		current_deal_index = (current_deal_index + 1) % deals.size()
	else:
		# Если не хватило на текущее, переключаем на следующее при повторном клике
		current_deal_index = (current_deal_index + 1) % deals.size()

func trade(index: int) -> bool:
	var barter := _get_barter_system()
	if barter:
		return barter.execute_trade(index)
	return false

func _get_barter_system() -> BarterSystem:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree:
		if tree.root and tree.root.has_node("BarterSystem"):
			return tree.root.get_node("BarterSystem") as BarterSystem
		var group_nodes: Array = tree.get_nodes_in_group("barter_system")
		if not group_nodes.is_empty():
			return group_nodes[0] as BarterSystem
	return null

func _get_economy() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root and tree.root.has_node("EconomyManager"):
		return tree.root.get_node("EconomyManager")
	return null
