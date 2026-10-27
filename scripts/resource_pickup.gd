class_name ResourcePickup
extends StaticBody3D
## Интерактивный подбираемый предмет в мире (металлолом, канистра топлива, банки, соль, янтарь, споры).

@export_enum("scrap", "fuel", "empty_jars", "salt", "raw_spores", "canned_spores", "amber") var resource_type: String = "scrap"
@export var amount: int = 1

@export var mesh_instance: MeshInstance3D

func _ready() -> void:
	add_to_group("resource_pickups")
	collision_layer = 4 # Layer 3: Interactable
	_setup_visuals()

func _setup_visuals() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return

	var mat := StandardMaterial3D.new()
	match resource_type:
		"scrap":
			mat.albedo_color = Color(0.42, 0.44, 0.46, 1.0)
			mat.metallic = 0.85
			mat.roughness = 0.4
		"fuel":
			mat.albedo_color = Color(0.85, 0.15, 0.12, 1.0)
			mat.metallic = 0.3
			mat.roughness = 0.5
		"empty_jars":
			mat.albedo_color = Color(0.85, 0.92, 0.95, 0.6)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.1
			mat.metallic = 0.1
		"salt":
			mat.albedo_color = Color(0.95, 0.95, 0.96, 1.0)
			mat.roughness = 0.85
		"raw_spores":
			mat.albedo_color = Color(0.68, 0.15, 0.55, 1.0)
			mat.roughness = 0.7
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.05, 0.35, 1.0)
		"canned_spores":
			mat.albedo_color = Color(0.3, 0.65, 0.45, 1.0)
			mat.metallic = 0.5
			mat.roughness = 0.3
		"amber":
			mat.albedo_color = Color(1.0, 0.65, 0.05, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.5, 0.05, 1.0)
			mat.emission_energy_multiplier = 1.8

	mesh_instance.material_override = mat

func get_interaction_info(_player: PlayerController) -> Dictionary:
	var eco := _get_economy()
	match resource_type:
		"scrap":
			return { "prompt": "Подобрать металлолом (+%d)" % amount, "type": "PICKUP" }
		"fuel":
			if eco and not eco.can_pickup_fuel():
				return { "prompt": "Инвентарь топлива полон (макс. %d)" % eco.max_fuel_canisters, "type": "BLOCKED" }
			return { "prompt": "Взять канистру топлива (в руки)", "type": "PICKUP" }
		"empty_jars":
			return { "prompt": "Подобрать пустую банку (+%d)" % amount, "type": "PICKUP" }
		"salt":
			return { "prompt": "Подобрать каменную соль (+%d)" % amount, "type": "PICKUP" }
		"raw_spores":
			return { "prompt": "Собрать сырую споровую железу (+%d)" % amount, "type": "PICKUP" }
		"canned_spores":
			return { "prompt": "Подобрать банку со спорами (валюта)", "type": "PICKUP" }
		"amber":
			return { "prompt": "Добыть тектонический янтарь (+%d) [Не для продажи!]" % amount, "type": "PICKUP" }
		_:
			return { "prompt": "Подобрать предмет", "type": "PICKUP" }

func interact(_player: PlayerController) -> void:
	var eco := _get_economy()
	if not eco:
		queue_free()
		return

	match resource_type:
		"scrap":
			eco.add_scrap(amount)
			eco.pickup_scrap(amount)
			queue_free()
		"fuel":
			if eco.add_fuel_canister():
				queue_free()
		"empty_jars":
			eco.base_storage["empty_jars"] = eco.base_storage.get("empty_jars", 0) + amount
			eco.emit_signal("resources_updated")
			queue_free()
		"salt":
			eco.base_storage["salt"] = eco.base_storage.get("salt", 0) + amount
			eco.emit_signal("resources_updated")
			queue_free()
		"raw_spores":
			eco.harvest_raw_gland(amount)
			queue_free()
		"canned_spores":
			eco.base_storage["canned_spores"] = eco.base_storage.get("canned_spores", 0) + amount
			eco.emit_signal("resources_updated")
			queue_free()
		"amber":
			eco.add_amber(amount)
			queue_free()

func _get_economy() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root and tree.root.has_node("EconomyManager"):
		return tree.root.get_node("EconomyManager")
	return null
