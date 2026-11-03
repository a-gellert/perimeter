@tool
class_name TerrainGenerator
extends Node3D
## Editor Tool & Runtime generator for the 1000x1000m Perimeter valley landscape.
## Generates procedural terrain mesh with trimesh collision, river water,
## cave grottos, sulfur mines, fishing piers, river crossings, and MultiMesh taiga forest.

@export_group("Map Generation")
@export var map_size: float = 1000.0
@export var grid_subdivisions: int = 100 # 100x100 quads
@export var terrain_shader: Shader = preload("res://shaders/valley_terrain.gdshader")
@export var water_shader: Shader = preload("res://shaders/river_water.gdshader")

@export_group("Actions")
@export var generate_now: bool = false:
	set(val):
		if val:
			generate_now = false
			generate_all()
			notify_property_list_changed()

func _ready() -> void:
	if not has_node("ValleyTerrainBody"):
		generate_all()
	else:
		_ensure_choppable_forest()

func _ensure_choppable_forest() -> void:
	var existing_forest := get_node_or_null("ChoppableForest")
	var is_valid := false
	if existing_forest:
		var c0 := existing_forest.get_node_or_null("Chunk_0_0") as ForestChunk
		if c0 != null and c0.multimesh_instance != null and c0.total_trees > 0:
			is_valid = true

	if not is_valid:
		if existing_forest:
			remove_child(existing_forest)
			existing_forest.queue_free()
		_build_choppable_forest()

# --- ВЫСОТНАЯ МАТЕМАТИЧЕСКАЯ МОДЕЛЬ ДОЛИНЫ ПО КАРТЕ-СХЕМЕ ---
func get_height_at(x: float, z: float) -> float:
	# 1. Кордон Лесника у восточных гор (320, 120) - плоская площадка базы Y = 0.0
	var dist_from_outpost: float = maxf(absf(x - 320.0), absf(z - 120.0))
	var outpost_weight: float = clampf((dist_from_outpost - 45.0) / 25.0, 0.0, 1.0)

	# 2. Северная горная гряда (Z < -70) с двумя долинами-языками к POI
	var north_h: float = 0.0
	if z < -70.0:
		var n_factor: float = clampf((-z - 70.0) / 380.0, 0.0, 1.0)
		var base_mountain: float = n_factor * 58.0

		# Ущелье 1: к Пещерному гроту (X ~ -120, Z ~ -440)
		var dist_cave_valley: float = absf(x - (-120.0))
		var cave_pass: float = clampf(dist_cave_valley / 65.0, 0.0, 1.0)

		# Ущелье 2: к Серным штольням (X ~ +40, Z ~ -380)
		var dist_sulfur_valley: float = absf(x - 40.0)
		var sulfur_pass: float = clampf(dist_sulfur_valley / 65.0, 0.0, 1.0)

		# Проходимость ущелий: по дну ущелья подъем более плавный
		var valley_pass_factor: float = minf(cave_pass, sulfur_pass)

		# Скалистые пики между ущельями и по бокам до +85..+95м
		var crags: float = sin(x * 0.02) * cos(z * 0.016) * 24.0 + sin(x * 0.045 + z * 0.03) * 12.0 + cos(x * 0.09) * 6.0
		north_h = (base_mountain + crags * (0.35 + 0.65 * valley_pass_factor)) * n_factor

	# 3. Западная горная стена (X < -260) с перевалом-кордоном (Z ~ -40..10)
	var west_h: float = 0.0
	if x < -260.0:
		var w_factor: float = clampf((-x - 260.0) / 200.0, 0.0, 1.0)
		var west_mountain: float = w_factor * 50.0 + sin(z * 0.022) * 12.0

		# Перевал "Кордон" (куда указывает красная стрелка: Z ~ -40..10)
		var dist_pass_z: float = absf(z - (-15.0))
		var pass_cut: float = clampf(dist_pass_z / 65.0, 0.0, 1.0)

		# В зоне заброшенного города на юго-западе (Z > 150) горы отступают на запад
		var town_cut: float = 1.0
		if z > 150.0 and z < 410.0:
			town_cut = clampf((-x - 420.0) / 60.0, 0.0, 1.0)

		west_h = west_mountain * w_factor * pass_cut * town_cut

	# 4. Юго-Западное плато: Заброшенный город (фиолетовый прямоугольник X in [-420, -180], Z in [170, 390])
	var town_h: float = 0.0
	if x < -170.0 and x > -430.0 and z > 160.0 and z < 400.0:
		var edge_x: float = minf(clampf((-170.0 - x) / 30.0, 0.0, 1.0), clampf((x - (-430.0)) / 30.0, 0.0, 1.0))
		var edge_z: float = minf(clampf((z - 160.0) / 30.0, 0.0, 1.0), clampf((400.0 - z) / 30.0, 0.0, 1.0))
		var town_mask: float = edge_x * edge_z
		town_h = 2.0 * town_mask

	# 5. Восточная Вековая тайга и восточный хребет (X > 90)
	var east_h: float = 0.0
	if x > 90.0:
		var taiga_rolling: float = sin(x * 0.025) * cos(z * 0.02) * 4.5 + 2.0
		var east_ridge: float = 0.0
		if x > 350.0:
			var e_factor: float = clampf((x - 350.0) / 140.0, 0.0, 1.0)
			east_ridge = (e_factor * 55.0 + sin(z * 0.018) * 12.0) * e_factor
		east_h = taiga_rolling + east_ridge

	# 6. Южная речная система (Водная артерия вдоль всего юга Z > 380 + залив по центру Z in [230, 410])
	var river_depth_total: float = 0.0

	# 6.1. Главная южная река (вдоль всего юга карты Z > 380)
	if z > 380.0:
		var s_factor: float = clampf((z - 380.0) / 100.0, 0.0, 1.0)
		river_depth_total = -10.5 * s_factor

	# 6.2. Центральный речной залив (идет на север до Z ~ 230 вдоль X ~ 15)
	if z > 230.0 and z <= 410.0:
		var inlet_dist_x: float = absf(x - 15.0)
		if inlet_dist_x < 36.0:
			var d_norm: float = inlet_dist_x / 36.0
			var inlet_z_factor: float = clampf((z - 230.0) / 70.0, 0.0, 1.0)
			var inlet_depth: float = -9.5 * (1.0 - d_norm * d_norm) * inlet_z_factor
			river_depth_total = minf(river_depth_total, inlet_depth)

	var mountain_h: float = maxf(north_h, maxf(west_h, east_h))
	var micro_noise: float = sin(x * 0.08 + z * 0.06) * 0.45 + cos(x * 0.05 - z * 0.07) * 0.35

	var total_h: float = mountain_h + town_h + river_depth_total + (micro_noise * outpost_weight)
	# Кордон егеря выравниваем строго в плоскость Y = 0.0
	return lerpf(0.0, total_h, outpost_weight)

# Координата X центра русла реки на заданной глубине Z
func get_river_center_x(z: float) -> float:
	if z < 410.0:
		return 15.0 # Центральный речной залив
	return 0.0 # Вдоль юга река широкая на всю карту

func _assign_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or node == null:
		return
	var scene_owner: Node = get_tree().edited_scene_root if get_tree() else null
	if not scene_owner:
		scene_owner = owner if owner else self
	if scene_owner and scene_owner.is_ancestor_of(node):
		node.owner = scene_owner

# --- ГЕНЕРАЦИЯ ВСЕГО КОМПЛЕКСА ЛАНДШАФТА ---
func generate_all() -> void:
	# Очистка предыдущих сгенерированных узлов
	for child in get_children():
		remove_child(child)
		child.queue_free()

	print("[TerrainGenerator] Generating 1000x1000m landscape...")
	_build_terrain_mesh()
	_build_river_water()
	_build_cave_and_poi_structures()
	_build_choppable_forest()
	print("[TerrainGenerator] Landscape generation complete!")

func _build_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half: float = map_size * 0.5
	var step: float = map_size / float(grid_subdivisions)
	var count: int = grid_subdivisions + 1

	# Сетка вершин
	var vertices: Array[Vector3] = []
	vertices.resize(count * count)

	for iz in range(count):
		var z: float = -half + float(iz) * step
		for ix in range(count):
			var x: float = -half + float(ix) * step
			var y: float = get_height_at(x, z)
			vertices[iz * count + ix] = Vector3(x, y, z)

	# Построение треугольников с расчетом нормалей и UV
	for iz in range(grid_subdivisions):
		for ix in range(grid_subdivisions):
			var i0: int = iz * count + ix
			var i1: int = iz * count + (ix + 1)
			var i2: int = (iz + 1) * count + (ix + 1)
			var i3: int = (iz + 1) * count + ix

			var v0: Vector3 = vertices[i0]
			var v1: Vector3 = vertices[i1]
			var v2: Vector3 = vertices[i2]
			var v3: Vector3 = vertices[i3]

			# Triangle 1 (v0, v1, v2) - CCW winding for upward normal
			var n1: Vector3 = (v2 - v0).cross(v1 - v0).normalized()
			st.set_normal(n1)
			st.set_uv(Vector2((v0.x + half) / map_size, (v0.z + half) / map_size))
			st.add_vertex(v0)
			st.set_normal(n1)
			st.set_uv(Vector2((v1.x + half) / map_size, (v1.z + half) / map_size))
			st.add_vertex(v1)
			st.set_normal(n1)
			st.set_uv(Vector2((v2.x + half) / map_size, (v2.z + half) / map_size))
			st.add_vertex(v2)

			# Triangle 2 (v0, v2, v3) - CCW winding for upward normal
			var n2: Vector3 = (v3 - v0).cross(v2 - v0).normalized()
			st.set_normal(n2)
			st.set_uv(Vector2((v0.x + half) / map_size, (v0.z + half) / map_size))
			st.add_vertex(v0)
			st.set_normal(n2)
			st.set_uv(Vector2((v2.x + half) / map_size, (v2.z + half) / map_size))
			st.add_vertex(v2)
			st.set_normal(n2)
			st.set_uv(Vector2((v3.x + half) / map_size, (v3.z + half) / map_size))
			st.add_vertex(v3)

	var arr_mesh: ArrayMesh = st.commit()

	# Материал ландшафта
	var mat := ShaderMaterial.new()
	mat.shader = terrain_shader
	arr_mesh.surface_set_material(0, mat)

	# StaticBody3D и коллизия
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "ValleyTerrainBody"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.mesh = arr_mesh
	terrain_body.add_child(mesh_inst)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "TerrainTrimeshCollision"
	col_shape.shape = arr_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)

	add_child(terrain_body)
	_assign_editor_owner(terrain_body)
	_assign_editor_owner(mesh_inst)
	_assign_editor_owner(col_shape)

func _build_river_water() -> void:
	var water_root := Node3D.new()
	water_root.name = "RiverWaterSystem"

	var glacial_river := GlacialRiver.new()
	glacial_river.name = "GlacialRiverEmitter"
	var pts: Array[Vector3] = []
	# Центральный речной залив (от Z=240 до 400 вдоль X=15)
	for z_step in range(240, 420, 20):
		pts.append(Vector3(15.0, -6.5, float(z_step)))
	# Главная южная река (вдоль Z=450 от X=-450 до +450)
	for x_step in range(-450, 480, 50):
		pts.append(Vector3(float(x_step), -6.5, 450.0))
	glacial_river.river_path = pts
	water_root.add_child(glacial_river)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Центральный речной залив (Z от 235 до 415, ширина 50м вдоль X=15)
	for z in range(235, 415, 20):
		var z0: float = float(z)
		var z1: float = float(z + 20)
		var x0: float = -10.0
		var x1: float = 40.0
		_add_water_quad(st, Vector3(x0, -6.5, z0), Vector3(x1, -6.5, z0), Vector3(x1, -6.5, z1), Vector3(x0, -6.5, z1))

	# 2. Главная южная река (вдоль всего юга карты X от -500 до +500, Z от 400 до 500)
	for x in range(-500, 500, 50):
		var x0: float = float(x)
		var x1: float = float(x + 50)
		var z0: float = 400.0
		var z1: float = 500.0
		_add_water_quad(st, Vector3(x0, -6.5, z0), Vector3(x1, -6.5, z0), Vector3(x1, -6.5, z1), Vector3(x0, -6.5, z1))

	st.generate_tangents()
	var water_mesh: ArrayMesh = st.commit()
	var w_mat := ShaderMaterial.new()
	w_mat.shader = water_shader
	water_mesh.surface_set_material(0, w_mat)

	var water_inst := MeshInstance3D.new()
	water_inst.name = "RiverWaterMesh"
	water_inst.mesh = water_mesh
	water_root.add_child(water_inst)

	add_child(water_root)
	_assign_editor_owner(water_root)
	_assign_editor_owner(glacial_river)
	_assign_editor_owner(water_inst)

func _add_water_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	# Tri 1: v0, v1, v2 (Normal points UP)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(v1)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)

	# Tri 2: v0, v2, v3 (Normal points UP)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(v3)

func _build_cave_and_poi_structures() -> void:
	var pois_node := Node3D.new()
	pois_node.name = "ValleyPOIStructures"

	# 1. Пещерный грот: Провал Шнека №3 (-120, 18.5, -440)
	var cave_scene: PackedScene = load("res://scenes/environment/CaveGrotto.tscn")
	if cave_scene:
		var cave: Node3D = cave_scene.instantiate()
		cave.name = "CaveGrottoEntrance"
		cave.position = Vector3(-120.0, get_height_at(-120.0, -440.0), -440.0)
		pois_node.add_child(cave)

	# 2. Серные штольни (40, 24.0, -380)
	var sulfur_scene: PackedScene = load("res://scenes/environment/SulfurMine.tscn")
	if sulfur_scene:
		var mine: Node3D = sulfur_scene.instantiate()
		mine.name = "SulfurMineQuarry"
		mine.position = Vector3(40.0, get_height_at(40.0, -380.0), -380.0)
		pois_node.add_child(mine)

	# 3. Рыбацкие мостки (15, -6.5, 310)
	var pier_scene: PackedScene = load("res://scenes/environment/FishingPier.tscn")
	if pier_scene:
		var pier: Node3D = pier_scene.instantiate()
		pier.name = "FishingPierStructure"
		pier.position = Vector3(15.0, -6.5, 310.0)
		pois_node.add_child(pier)

	# 4. Каменистый брод (-180, -6.4, 260)
	var crossing_scene: PackedScene = load("res://scenes/environment/RiverCrossing.tscn")
	if crossing_scene:
		var crossing: Node3D = crossing_scene.instantiate()
		crossing.name = "RiverCrossingBoulders"
		crossing.position = Vector3(-180.0, -6.4, 260.0)
		pois_node.add_child(crossing)

	add_child(pois_node)
	_assign_editor_owner(pois_node)
	for child in pois_node.get_children():
		_assign_editor_owner(child)

func _build_choppable_forest() -> void:
	var forest_node := Node3D.new()
	forest_node.name = "ChoppableForest"
	add_child(forest_node)

	var tree_mesh: Mesh = load("res://assets/pine_tree_multimesh.res")
	var ft_scene: PackedScene = load("res://scenes/environment/FallingTree.tscn")

	# Архитектура карты: разбивка на Чанки 100х100 м (сетка 10х10 = 100 чанков на 1000х1000м)
	# Каждый чанк имеет собственный MultiMeshInstance3D для автоматического Frustum Culling.
	for cx in range(10):
		for cz in range(10):
			var x_start: float = -500.0 + float(cx) * 100.0
			var x_end: float = x_start + 100.0
			var z_start: float = -500.0 + float(cz) * 100.0
			var z_end: float = z_start + 100.0

			var rng := RandomNumberGenerator.new()
			rng.seed = 42 + cx * 73 + cz * 179

			var transforms: Array[Transform3D] = []
			var attempts: int = 0
			var target_per_chunk: int = 50

			while transforms.size() < target_per_chunk and attempts < 150:
				attempts += 1
				var tx: float = rng.randf_range(x_start + 2.0, x_end - 2.0)
				var tz: float = rng.randf_range(z_start + 2.0, z_end - 2.0)

				# Не спавним внутри кордона егеря (площадка 100х100м у гор X=320, Z=120)
				if absf(tx - 320.0) < 52.0 and absf(tz - 120.0) < 52.0:
					continue

				# Не спавним в воде южной реки и центрального речного залива
				if tz > 395.0:
					continue
				if tz > 225.0 and absf(tx - 15.0) < 30.0:
					continue

				# Зона заброшенного города (Юго-Запад): открытая территория под застройку
				if tx < -170.0 and tx > -420.0 and tz > 170.0 and tz < 390.0:
					if rng.randf() > 0.12:
						continue

				var ty: float = get_height_at(tx, tz)
				if ty > 58.0 or ty < -5.5:
					continue

				var scale_rnd: float = rng.randf_range(0.85, 1.25)
				var rot_y: float = rng.randf_range(0.0, TAU)
				var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(scale_rnd, scale_rnd, scale_rnd))
				transforms.append(Transform3D(basis, Vector3(tx, ty, tz)))

			var chunk := ForestChunk.new()
			chunk.name = "Chunk_%d_%d" % [cx, cz]
			chunk.initialize(Vector2i(cx, cz), transforms, tree_mesh, ft_scene)
			forest_node.add_child(chunk)
