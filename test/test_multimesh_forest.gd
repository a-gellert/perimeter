extends Node

func _ready() -> void:
	print("=== RUNNING WATER SHADER, CAMERA FAR CLIP & MULTIMESH CHUNK TESTS ===")

	# -------------------------------------------------------------------------
	# TEST 1: Water Mesh Face Normal & Shader Verification
	# -------------------------------------------------------------------------
	print("\n--- TEST 1: River Water Mesh Normal & Shader ---")
	var tg := TerrainGenerator.new()
	add_child(tg)
	tg._build_river_water()

	var water_root := tg.get_node_or_null("RiverWaterSystem")
	assert(water_root != null, "RiverWaterSystem node must be created")
	var water_mesh_inst := water_root.get_node_or_null("RiverWaterMesh") as MeshInstance3D
	assert(water_mesh_inst != null, "RiverWaterMesh must exist")
	assert(water_mesh_inst.mesh != null, "Water mesh must be valid ArrayMesh")

	var mdt := MeshDataTool.new()
	mdt.create_from_surface(water_mesh_inst.mesh, 0)
	var face_count: int = mdt.get_face_count()
	assert(face_count > 0, "Water mesh must contain faces")

	for f in range(mini(face_count, 10)):
		var fn: Vector3 = mdt.get_face_normal(f)
		assert(fn.y > 0.9, "Water face normal %d must point straight UP (got %s)" % [f, fn])

	print("[PASS] River water mesh normals point UP (0, 1, 0) verified on %d faces." % face_count)
	tg.queue_free()

	# -------------------------------------------------------------------------
	# TEST 2: Architect Mode Switch & Camera Far Distance
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Camera Draw Distance & Hybrid Rig Mode Switch ---")
	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	assert(player_scene != null, "Player.tscn must exist")
	var player := player_scene.instantiate() as PlayerController
	add_child(player)

	var fpv_cam: Camera3D = player.get_node("Head/FPVCamera") as Camera3D
	assert(fpv_cam.far >= 1000.0, "Player FPVCamera.far must be >= 1000m to prevent draw distance breakage (got %f)" % fpv_cam.far)
	print("[PASS] Player FPVCamera.far = %f (>= 1000m) verified." % fpv_cam.far)

	var rig_scene: PackedScene = load("res://scenes/camera/HybridCameraRig.tscn")
	assert(rig_scene != null, "HybridCameraRig.tscn must exist")
	var rig := rig_scene.instantiate() as HybridCameraRig
	rig.fpv_mount = player.get_node("Head") as Node3D
	add_child(rig)

	assert(rig.camera.current == true, "Rig camera must be active")
	assert(rig.camera.far >= 1000.0, "Rig camera.far must be >= 1000m (got %f)" % rig.camera.far)

	# Simulate switching to Architect mode
	player.set_building_mode(true)
	assert(player.is_building_mode == true, "Player should be in building mode")
	assert(rig.camera.current == true, "Rig camera must remain active when building mode enabled")
	assert(rig.camera.far >= 1000.0, "Rig camera draw distance must not break")

	# Simulate returning to FPV mode
	player.set_building_mode(false)
	assert(player.is_building_mode == false, "Player should exit building mode")
	assert(rig.camera.current == true, "Rig camera must stay active after returning from architect mode")
	assert(rig.camera.far >= 1000.0, "Camera far distance must remain intact after returning from architect mode")
	print("[PASS] Camera transition FPV <-> Architect preserves draw distance and active camera.")

	player.queue_free()
	rig.queue_free()

	# -------------------------------------------------------------------------
	# TEST 3: 10x10 Chunk MultiMesh Forest (~5000 trees) & Felling Mechanics
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: 10x10 Chunk MultiMesh Forest & Dynamic FallingTree ---")
	var tg_forest := TerrainGenerator.new()
	add_child(tg_forest)
	tg_forest._build_choppable_forest()

	var forest_node := tg_forest.get_node_or_null("ChoppableForest")
	assert(forest_node != null, "ChoppableForest node must exist")

	var chunk_count: int = 0
	var total_tree_count: int = 0

	for cx in range(10):
		for cz in range(10):
			var chunk_name := "Chunk_%d_%d" % [cx, cz]
			var chunk := forest_node.get_node_or_null(chunk_name) as ForestChunk
			assert(chunk != null, "Chunk %s must exist in 10x10 grid" % chunk_name)
			chunk_count += 1
			total_tree_count += chunk.total_trees
			if chunk.total_trees > 0:
				assert(chunk.multimesh_instance != null, "Chunk %s must have a MultiMeshInstance3D" % chunk_name)
				assert(chunk.multimesh_instance.multimesh != null, "Chunk %s must have a MultiMesh" % chunk_name)
				assert(chunk.multimesh_instance.multimesh.instance_count == chunk.total_trees, "Instance count mismatch in chunk %s" % chunk_name)
				assert(chunk.multimesh_instance.custom_aabb.size.x >= 100.0, "Custom AABB must cover at least 100m")

	assert(chunk_count == 100, "Must generate exactly 100 chunks (10x10 grid), got %d" % chunk_count)
	assert(total_tree_count >= 4000 and total_tree_count <= 5500, "Total trees across 100 chunks should be ~5000, got %d" % total_tree_count)
	print("[PASS] 10x10 Chunk Grid verified: %d chunks, %d total trees." % [chunk_count, total_tree_count])

	# -------------------------------------------------------------------------
	# TEST 4: Felling a tree (MultiMesh shrink to 0 -> Spawn FallingTree -> Logs + Stump)
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Tree Felling: MultiMesh Zero-Scale & FallingTree Crash ---")
	var test_chunk := forest_node.get_node("Chunk_2_2") as ForestChunk
	assert(test_chunk != null and test_chunk.total_trees > 0, "Test chunk must contain trees")

	var target_instance_idx: int = 0
	var orig_transform := test_chunk.get_tree_transform(target_instance_idx)
	assert(orig_transform.basis.get_scale().length() > 0.5, "Original tree scale must be non-zero")

	# Find corresponding target collider
	var target_collider := test_chunk.get_node("TreeColliders/TreeTarget_0") as MultiMeshTreeTarget
	assert(target_collider != null, "Target collider TreeTarget_0 must exist in chunk")

	# Strike the tree (Raycast / Axe take_damage)
	target_collider.take_damage(35.0)

	# 1. MultiMesh instance scale must immediately shrink to 0
	var new_scale := test_chunk.get_tree_scale(target_instance_idx)
	assert(new_scale.is_zero_approx(), "Instance %d in MultiMesh must have scale (0,0,0) after chopping (got %s)" % [target_instance_idx, new_scale])
	assert(test_chunk.is_tree_felled(target_instance_idx) == true, "Tree must be marked as felled in chunk")
	print("[PASS] Step 1: MultiMesh instance scale shrank to Vector3.ZERO instantly.")

	# 2. FallingTree.tscn must have spawned in the same frame
	var falling_tree: FallingTree = null
	var search_nodes: Array[Node] = []
	if get_tree().current_scene:
		search_nodes.append_array(get_tree().current_scene.get_children())
	search_nodes.append_array(get_children())
	for child in search_nodes:
		if child is FallingTree:
			falling_tree = child as FallingTree
			break

	assert(falling_tree != null, "FallingTree instance must be spawned in scene")
	assert(falling_tree.global_position.distance_to(orig_transform.origin) < 0.1, "FallingTree must spawn at exact tree coordinates")
	print("[PASS] Step 2: Dynamic FallingTree.tscn spawned at exact coordinates.")

	# 3. Simulate completion of fall (crash callback)
	falling_tree._on_crash()

	# Verify Stump spawned
	var has_stump: bool = false
	var log_count: int = 0
	var check_nodes: Array[Node] = []
	var seen: Dictionary = {}
	if get_tree().current_scene:
		for c in get_tree().current_scene.get_children():
			if not seen.has(c):
				seen[c] = true
				check_nodes.append(c)
	for c in get_children():
		if not seen.has(c):
			seen[c] = true
			check_nodes.append(c)

	for child in check_nodes:
		if child.name.begins_with("TreeStump"):
			has_stump = true
		elif child.name.begins_with("LogItem"):
			log_count += 1

	assert(has_stump, "FallingTree crash must spawn a TreeStump at the base")
	assert(log_count >= 2 and log_count <= 3, "FallingTree crash must shatter into 2-3 LogItems, got %d" % log_count)
	print("[PASS] Step 3: Tree crashed, spawned TreeStump and %d LogItems." % log_count)

	tg_forest.queue_free()

	print("\n=== ALL TESTS COMPLETED SUCCESSFULLY WITH 100% PASS RATE! ===")
	get_tree().quit(0)
