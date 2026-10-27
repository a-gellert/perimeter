class_name SporeCanningStation
extends StaticBody3D
## Верстак препаратора / Засолочная станция в кордоне егеря.
## Используется для консервации скоропортящихся сырых споровых желез в товарные банки.

func get_interaction_info(_player: PlayerController) -> Dictionary:
	var eco := _get_economy()
	if not eco:
		return { "prompt": "Склад недоступен", "type": "BLOCKED" }

	if eco.can_can_spores():
		return {
			"prompt": "Законсервировать споровую железу (Банка + Соль)",
			"type": "CRAFT_CAN"
		}
	elif eco.base_storage.get("raw_spores", 0) <= 0:
		return { "prompt": "Нет сырых желез для консервации", "type": "BLOCKED" }
	else:
		return { "prompt": "Нужны пустая банка и соль!", "type": "NEED_ITEMS" }

func interact(_player: PlayerController) -> void:
	var eco := _get_economy()
	if not eco:
		return

	if eco.process_spore_canning():
		# Успешная консервация: звук металлической закаточной машинки и бульканье
		_play_canning_feedback()

func _play_canning_feedback() -> void:
	var sound: AudioStreamPlayer3D = get_node_or_null("CanningAudio")
	if sound:
		sound.play()

func _get_economy() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root and tree.root.has_node("EconomyManager"):
		return tree.root.get_node("EconomyManager")
	return null
