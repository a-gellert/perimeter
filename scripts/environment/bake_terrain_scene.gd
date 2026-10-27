@tool
extends SceneTree

func _init() -> void:
	print("=== BAKING 1000x1000m TERRAIN VALLEY SCENE ===")
	var root := Node3D.new()
	root.name = "TerrainValley"

	var gen: TerrainGenerator = TerrainGenerator.new()
	gen.name = "TerrainGenerator"
	root.add_child(gen)
	gen.generate_all()

	# Pack the scene
	var packed := PackedScene.new()
	_set_owner_recursive(root, root)
	var err := packed.pack(root)
	if err == OK:
		var save_err := ResourceSaver.save(packed, "res://scenes/environment/TerrainValley.tscn")
		if save_err == OK:
			print("[SUCCESS] Baked res://scenes/environment/TerrainValley.tscn successfully!")
		else:
			printerr("Failed to save scene: ", save_err)
	else:
		printerr("Failed to pack scene: ", err)

	quit(0)

func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)
