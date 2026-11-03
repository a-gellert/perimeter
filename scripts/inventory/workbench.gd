class_name Workbench
extends StaticBody3D
## Interactive Workbench object in the player's cabin/base.
## Allows crafting weapons, ammo, gear, and heavy objects (turrets, furniture).

@export var prompt_message: String = "Верстак: Создание предметов"
@onready var spawn_point: Node3D = $HeavyObjectSpawnPoint

func _ready() -> void:
	add_to_group("workbenches")
	add_to_group("interactable")
	collision_layer = 5 # Environment + Interactable
	collision_mask = 1

	if not spawn_point:
		spawn_point = get_node_or_null("HeavyObjectSpawnPoint")
		if not spawn_point:
			spawn_point = Node3D.new()
			spawn_point.name = "HeavyObjectSpawnPoint"
			spawn_point.position = Vector3(1.6, 0.0, 0.0)
			add_child(spawn_point)

func can_interact(_actor: Node) -> bool:
	return true

func get_prompt_text(_actor: Node) -> String:
	return prompt_message

func get_interaction_info(player: Node) -> Dictionary:
	return { "prompt": get_prompt_text(player), "type": "WORKBENCH" }

func interact(_actor: Node) -> void:
	var crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
	if crafting_ui and crafting_ui.has_method("open_workbench"):
		crafting_ui.open_workbench(self)
	else:
		# Fallback: check if crafting_ui is in HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			var cui = hud.find_child("CraftingUI", true, false)
			if cui and cui.has_method("open_workbench"):
				cui.open_workbench(self)

func get_heavy_spawn_position() -> Vector3:
	if spawn_point:
		return spawn_point.global_position
	return global_position + Vector3(1.6, 0.0, 0.0)
