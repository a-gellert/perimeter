class_name LootPickup
extends StaticBody3D
## Interactive loot pickup in the 3D world (berries, branches, rags, scrap, circuits, weapons, ammo, etc.).
## Integrates with PlayerInteraction raycast and InventoryManager.

@export var item_id: String = "branches"
@export var count: int = 1
@export var respawn_time: float = 0.0 # 0: one-time pickup, >0: respawns after X seconds (e.g. berry bushes)
@export var auto_rotate: bool = true

var _initial_pos: Vector3
var _is_collected: bool = false
var _mesh_node: Node = null

func _ready() -> void:
	add_to_group("loot_pickups")
	add_to_group("interactable")
	collision_layer = 4 # Layer 3: Interactable (0b100)
	collision_mask = 1
	_initial_pos = global_position
	_setup_visuals()

func _process(delta: float) -> void:
	if auto_rotate and visible and _mesh_node:
		_mesh_node.rotate_y(0.8 * delta)

func _setup_visuals() -> void:
	var item = ItemDatabase.get_item(item_id)
	if not item:
		return

	# Удаляем старую модель если была
	var old_model = get_node_or_null("VisualModel")
	if old_model:
		old_model.queue_free()

	# 1. Попытка загрузить готовую 3D FBX модель
	if not item.model_path.is_empty() and ResourceLoader.exists(item.model_path):
		var scn = load(item.model_path)
		if scn:
			var inst = scn.instantiate()
			inst.name = "VisualModel"
			_adjust_model_scale_and_pos(inst, item_id)
			add_child(inst)
			_mesh_node = inst
			var fallback_mesh = get_node_or_null("MeshInstance3D")
			if fallback_mesh:
				fallback_mesh.visible = false
			return

	# 2. Если FBX нет, настраиваем встроенный процедурный MeshInstance3D
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "MeshInstance3D"
		add_child(mesh_inst)

	_mesh_node = mesh_inst
	mesh_inst.visible = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.icon_color
	mat.roughness = 0.4
	mat.metallic = 0.3

	match item_id:
		"circuit":
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.8, 0.3)
			mat.emission_energy_multiplier = 1.2
			var box := BoxMesh.new()
			box.size = Vector3(0.35, 0.05, 0.35)
			mesh_inst.mesh = box
		"rags":
			mat.roughness = 0.9
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.15
			cylinder.bottom_radius = 0.15
			cylinder.height = 0.3
			mesh_inst.mesh = cylinder
		"berries":
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.4, 0.9)
			mat.emission_energy_multiplier = 0.5
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.4
			mesh_inst.mesh = sphere
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.3, 0.3)
			mesh_inst.mesh = box

	mesh_inst.material_override = mat

func _adjust_model_scale_and_pos(model: Node, id: String) -> void:
	match id:
		"berries":
			model.scale = Vector3(0.6, 0.6, 0.6)
		"branches":
			model.scale = Vector3(0.8, 0.8, 0.8)
		"rags":
			model.scale = Vector3(1.2, 1.2, 1.2)
		"scrap":
			model.scale = Vector3(0.9, 0.9, 0.9)
		"circuit":
			model.scale = Vector3(0.5, 0.5, 0.5)
		"knife":
			model.scale = Vector3(1.2, 1.2, 1.2)
		"axe":
			model.scale = Vector3(0.8, 0.8, 0.8)
		"bow", "crossbow":
			model.scale = Vector3(0.7, 0.7, 0.7)
		"rifle":
			model.scale = Vector3(0.8, 0.8, 0.8)
		"pistol":
			model.scale = Vector3(1.0, 1.0, 1.0)
		"arrow", "bolt":
			model.scale = Vector3(1.0, 1.0, 1.0)
		"ammo_rifle", "ammo_9mm":
			model.scale = Vector3(1.5, 1.5, 1.5)
		"boots":
			model.scale = Vector3(0.8, 0.8, 0.8)
		"backpack_tier2", "backpack_tier3":
			model.scale = Vector3(0.9, 0.9, 0.9)
		_:
			model.scale = Vector3.ONE

func can_interact(_actor: Node) -> bool:
	return not _is_collected and visible

func get_prompt_text(_actor: Node) -> String:
	var item = ItemDatabase.get_item(item_id)
	var name_str: String = item.display_name if item else item_id
	if count > 1:
		return "Подобрать %s (x%d)" % [name_str, count]
	return "Подобрать %s" % name_str

func get_interaction_info(player: Node) -> Dictionary:
	if not can_interact(player):
		return { "prompt": "", "type": "BLOCKED" }
	return { "prompt": get_prompt_text(player), "type": "PICKUP" }

func interact(_actor: Node) -> void:
	if _is_collected:
		return

	var inv = _get_inventory()
	if not inv:
		return

	if not inv.can_add_item(item_id, count):
		inv.notify("Рюкзак полон! Освободите место.", true)
		return

	var rem: int = inv.add_item(item_id, count)
	if rem == 0:
		_on_fully_collected()
	else:
		count = rem
		var item = ItemDatabase.get_item(item_id)
		inv.notify("Взято частично. Осталось: %d шт." % count, false)

func _on_fully_collected() -> void:
	_is_collected = true
	var item = ItemDatabase.get_item(item_id)
	var name_str: String = item.display_name if item else item_id
	var inv = _get_inventory()
	if inv:
		inv.notify("Подобрано: %s (+%d)" % [name_str, count], false)

	if respawn_time > 0.0:
		visible = false
		collision_layer = 0
		var timer := get_tree().create_timer(respawn_time)
		timer.timeout.connect(func():
			_is_collected = false
			visible = true
			collision_layer = 4
		)
	else:
		queue_free()

func _get_inventory() -> Node:
	if is_inside_tree() and get_tree().root.has_node("InventoryManager"):
		return get_tree().root.get_node("InventoryManager")
	return null
