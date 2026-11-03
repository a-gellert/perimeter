class_name PlacedObject
extends StaticBody3D
## Represents a large/heavy non-portable crafted object placed in the world next to the workbench.
## Examples: Defense Turret, Furniture Chair, Table, Makeshift Bed.

@export var object_id: String = "turret"
@export var display_name: String = "Объект"

var _current_target: Node = null

func _ready() -> void:
	add_to_group("placed_objects")
	add_to_group("interactable")
	collision_layer = 5 # Layer 1 (Environment) + Layer 3 (Interactable: 0b101 = 5)
	collision_mask = 3
	setup_object(object_id)

func setup_object(id: String) -> void:
	object_id = id
	var item = ItemDatabase.get_item(id)
	if item:
		display_name = item.display_name

	# Удаляем временную геометрию
	for c in get_children():
		if c.name.begins_with("GeneratedVisual"):
			c.queue_free()

	var visual_root := Node3D.new()
	visual_root.name = "GeneratedVisual"
	add_child(visual_root)

	match id:
		"turret":
			_build_turret_visual(visual_root)
		"furniture_chair":
			_build_chair_visual(visual_root)
		"furniture_table":
			_build_table_visual(visual_root)
		"furniture_bed":
			_build_bed_visual(visual_root)
		_:
			_build_generic_box_visual(visual_root)

func _build_turret_visual(root: Node3D) -> void:
	# Штатив
	var tripod := CSGCylinder3D.new()
	tripod.radius = 0.35
	tripod.height = 0.6
	tripod.position = Vector3(0, 0.3, 0)
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color(0.2, 0.22, 0.25)
	mat_base.metallic = 0.8
	tripod.material = mat_base
	root.add_child(tripod)

	# Корпус турели
	var body := CSGBox3D.new()
	body.size = Vector3(0.4, 0.3, 0.6)
	body.position = Vector3(0, 0.75, 0)
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.35, 0.4, 0.35)
	mat_body.metallic = 0.7
	body.material = mat_body
	root.add_child(body)

	# Сдвоенный ствол
	var barrel1 := CSGCylinder3D.new()
	barrel1.radius = 0.04
	barrel1.height = 0.7
	barrel1.rotation_degrees = Vector3(90, 0, 0)
	barrel1.position = Vector3(-0.1, 0.75, -0.45)
	var mat_gun := StandardMaterial3D.new()
	mat_gun.albedo_color = Color(0.1, 0.1, 0.1)
	barrel1.material = mat_gun
	root.add_child(barrel1)

	var barrel2 := CSGCylinder3D.new()
	barrel2.radius = 0.04
	barrel2.height = 0.7
	barrel2.rotation_degrees = Vector3(90, 0, 0)
	barrel2.position = Vector3(0.1, 0.75, -0.45)
	barrel2.material = mat_gun
	root.add_child(barrel2)

	# Сенсор / лазерный прицел
	var sensor := OmniLight3D.new()
	sensor.position = Vector3(0, 0.85, -0.3)
	sensor.light_color = Color(1.0, 0.1, 0.1)
	sensor.light_energy = 1.5
	sensor.omni_range = 4.0
	root.add_child(sensor)

func _build_chair_visual(root: Node3D) -> void:
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.55, 0.38, 0.22)
	mat_wood.roughness = 0.85

	# Сиденье
	var seat := CSGBox3D.new()
	seat.size = Vector3(0.5, 0.08, 0.5)
	seat.position = Vector3(0, 0.45, 0)
	seat.material = mat_wood
	root.add_child(seat)

	# Спинка
	var back := CSGBox3D.new()
	back.size = Vector3(0.5, 0.5, 0.06)
	back.position = Vector3(0, 0.75, 0.22)
	back.material = mat_wood
	root.add_child(back)

	# 4 ножки
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			var leg := CSGCylinder3D.new()
			leg.radius = 0.03
			leg.height = 0.45
			leg.position = Vector3(x, 0.225, z)
			leg.material = mat_wood
			root.add_child(leg)

func _build_table_visual(root: Node3D) -> void:
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.48, 0.32, 0.18)
	mat_wood.roughness = 0.9

	# Столешница
	var top := CSGBox3D.new()
	top.size = Vector3(1.4, 0.1, 0.8)
	top.position = Vector3(0, 0.8, 0)
	top.material = mat_wood
	root.add_child(top)

	# 4 ножки
	for x in [-0.6, 0.6]:
		for z in [-0.3, 0.3]:
			var leg := CSGCylinder3D.new()
			leg.radius = 0.05
			leg.height = 0.8
			leg.position = Vector3(x, 0.4, z)
			leg.material = mat_wood
			root.add_child(leg)

func _build_bed_visual(root: Node3D) -> void:
	var bed_fbx := "res://assets/just_survive/FBX/MakeshiftBed.fbx"
	if ResourceLoader.exists(bed_fbx):
		var scn = load(bed_fbx)
		if scn:
			var inst = scn.instantiate()
			inst.scale = Vector3(1.2, 1.2, 1.2)
			root.add_child(inst)
			return
	_build_generic_box_visual(root)

func _build_generic_box_visual(root: Node3D) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	box.position = Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.4, 0.3)
	box.material = mat
	root.add_child(box)

func can_interact(_actor: Node) -> bool:
	return true

func get_prompt_text(_actor: Node) -> String:
	return "Осмотреть %s" % display_name

func get_interaction_info(player: Node) -> Dictionary:
	return { "prompt": get_prompt_text(player), "type": "INSPECT" }

func interact(_actor: Node) -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.notify("%s установлен на кордоне." % display_name, false)
