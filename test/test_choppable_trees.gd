extends Node

func _ready() -> void:
	print("=== RUNNING CHOPPABLE TREES PRESET & FELLING TESTS ===")

	var presets: Dictionary = {
		"Pine": { "path": "res://scenes/environment/trees/Tree_Pine_Tall.tscn", "name": "Таёжная Сосна", "max_hits": 3, "logs": 3 },
		"Cedar": { "path": "res://scenes/environment/trees/Tree_Cedar_Giant.tscn", "name": "Сибирский Кедр", "max_hits": 5, "logs": 4 },
		"Birch": { "path": "res://scenes/environment/trees/Tree_Birch.tscn", "name": "Северная Берёза", "max_hits": 2, "logs": 2 },
		"Deadwood": { "path": "res://scenes/environment/trees/Tree_Deadwood.tscn", "name": "Сухостой", "max_hits": 2, "logs": 2 },
		"Larch": { "path": "res://scenes/environment/trees/Tree_Larch.tscn", "name": "Горная Лиственница", "max_hits": 4, "logs": 3 }
	}

	# Test 1: Load and verify all 5 tree presets
	for key in presets.keys():
		var p_info: Dictionary = presets[key]
		var scene: PackedScene = load(p_info["path"])
		assert(scene != null, "Tree preset %s must exist at %s" % [key, p_info["path"]])

		var tree_node: Node3D = scene.instantiate() as Node3D
		add_child(tree_node)

		var choppable: ChoppableTree = null
		for child in tree_node.find_children("*", "ChoppableTree", true, false):
			choppable = child as ChoppableTree
			break

		assert(choppable != null, "Tree %s must contain a ChoppableTree component" % key)
		assert(choppable.tree_name == p_info["name"], "Tree %s name mismatch: expected %s, got %s" % [key, p_info["name"], choppable.tree_name])
		assert(choppable.max_hits == p_info["max_hits"], "Tree %s max_hits mismatch: expected %d, got %d" % [key, p_info["max_hits"], choppable.max_hits])
		assert(choppable.logs_to_spawn == p_info["logs"], "Tree %s logs_to_spawn mismatch: expected %d, got %d" % [key, p_info["logs"], choppable.logs_to_spawn])

		# Test interaction info
		var info: Dictionary = choppable.get_interaction_info(null)
		assert(info["type"] == "CHOP", "Interaction info type must be CHOP")
		assert(info["prompt"].contains(p_info["name"]), "Prompt must contain tree name")
		assert(info["prompt"].contains("0/%d" % p_info["max_hits"]), "Prompt must show initial progress 0/%d" % p_info["max_hits"])

		tree_node.queue_free()
		print("[PASS] Tree preset %s (%s) verified successfully." % [key, p_info["name"]])

	# Test 2: Tree felling mechanics (hitting, prompt update, axe take_damage, log spawning)
	var birch_scene: PackedScene = load("res://scenes/environment/trees/Tree_Birch.tscn")
	var test_world := Node3D.new()
	add_child(test_world)

	var birch: Node3D = birch_scene.instantiate() as Node3D
	test_world.add_child(birch)

	var birch_chop: ChoppableTree = birch.find_children("*", "ChoppableTree", true, false)[0] as ChoppableTree

	# First hit via interact()
	birch_chop.interact(null)
	assert(birch_chop.current_hits == 1, "current_hits should be 1 after first chop")
	var prompt_after_hit: Dictionary = birch_chop.get_interaction_info(null)
	assert(prompt_after_hit["prompt"].contains("1/2"), "Prompt should reflect 1/2 progress")
	print("[PASS] Tree partial chop and progress tracking verified.")

	# Second hit via axe take_damage()
	birch_chop.take_damage(35.0)
	assert(birch_chop.current_hits == 2, "current_hits should be 2 after axe hit")
	assert(birch_chop.is_falling == true, "Tree must enter is_falling state when max hits reached")

	# Trigger crash directly to verify log spawning and stump placement
	birch_chop._on_tree_crashed(test_world, birch.global_position, Vector3.FORWARD, birch)

	var spawned_logs: Array[Node] = test_world.find_children("*", "StaticBody3D", false, false)
	# Should have spawned logs + stump
	var has_stump: bool = false
	var log_count: int = 0
	for node in test_world.get_children():
		if node.name.begins_with("TreeStump"):
			has_stump = true
		elif node.name.begins_with("LogItem"):
			log_count += 1

	assert(has_stump, "Felled tree must spawn a TreeStump on the ground")
	assert(log_count == 2, "Birch must spawn exactly 2 LogItems on felling, got %d" % log_count)
	print("[PASS] Tree felling: stump placement and 2 LogItems successfully spawned.")

	test_world.queue_free()

	print("=== ALL CHOPPABLE TREE TESTS PASSED! ===")
	get_tree().quit(0)
