extends Node

func _ready() -> void:
	print("=== VERIFYING MAIN SCENE FOREST GENERATION AND FOG REMOVAL ===")
	var scene: Node = get_tree().current_scene
	assert(scene != null, "Main scene must be active")

	# 1. Environment and Fog verification
	var world_env := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert(world_env != null and world_env.environment != null, "WorldEnvironment must exist")
	assert(world_env.environment.fog_enabled == false, "Environment fog must be DISABLED")
	print("[PASS] WorldEnvironment fog_enabled is FALSE.")

	var spore_fog := scene.get_node_or_null("Environment/SporeFogRavine")
	assert(spore_fog == null, "SporeFogRavine must be removed from scene")
	print("[PASS] SporeFogRavine removed from Environment.")

	# 2. Terrain and ChoppableForest verification
	var terrain := scene.get_node_or_null("TerrainValley") as TerrainGenerator
	assert(terrain != null, "TerrainValley must exist")

	var forest := terrain.get_node_or_null("ChoppableForest")
	assert(forest != null, "ChoppableForest must exist under TerrainValley")
	assert(forest.get_child_count() == 100, "ChoppableForest must contain exactly 100 chunks, got %d" % forest.get_child_count())

	var total_trees: int = 0
	for cx in range(10):
		for cz in range(10):
			var chunk_name := "Chunk_%d_%d" % [cx, cz]
			var chunk := forest.get_node_or_null(chunk_name) as ForestChunk
			assert(chunk != null, "Chunk %s must exist" % chunk_name)
			assert(chunk.multimesh_instance != null, "Chunk %s must have MultiMeshInstance3D" % chunk_name)
			assert(chunk.multimesh_instance.multimesh != null, "Chunk %s must have MultiMesh" % chunk_name)
			assert(chunk.multimesh_instance.visibility_range_end > 0.0 and chunk.multimesh_instance.visibility_range_end <= 250.0, "Visibility range end must be configured for distance culling (150-250m)")
			total_trees += chunk.total_trees

	assert(total_trees >= 4000 and total_trees <= 5500, "Total trees must be ~5000 across map, got %d" % total_trees)
	print("[PASS] 100 Chunks with %d trees successfully generated and active in Main scene!" % total_trees)

	print("=== MAIN SCENE VERIFICATION COMPLETE: ALL PASS ===")
	get_tree().quit(0)
