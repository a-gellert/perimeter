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
			generate_all()

func _ready() -> void:
	if not has_node("ValleyTerrainBody"):
		generate_all()

# --- ВЫСОТНАЯ МАТЕМАТИЧЕСКАЯ МОДЕЛЬ ДОЛИНЫ ---
func get_height_at(x: float, z: float) -> float:
	# 1. Центр: Кордон Лесника (100х100м) - плоская площадка для базы и стройки
	var dist_from_center: float = maxf(absf(x), absf(z))
	var outpost_weight: float = clampf((dist_from_center - 45.0) / 25.0, 0.0, 1.0)
	var base_h: float = 0.0

	# 2. Север: Скальный хребет (Z < -150)
	var north_h: float = 0.0
	if z < -130.0:
		var n_factor: float = clampf((-z - 130.0) / 320.0, 0.0, 1.0)
		# Базовый подъем скал до +26м
		var ridge_base: float = n_factor * 26.0
		# Скальные пики и гребни до +38м
		var crags: float = sin(x * 0.024) * cos(z * 0.02) * 7.0 + sin(x * 0.06 + z * 0.04) * 3.5
		# Серпантинный пологий проход по центру к штольням
		var pass_dist: float = absf(x + 20.0)
		var pass_factor: float = clampf(pass_dist / 60.0, 0.0, 1.0)
		north_h = (ridge_base + crags * pass_factor) * n_factor

	# 3. Юг: Пойма и русло горной реки (Z > 140)
	var south_h: float = 0.0
	if z > 130.0:
		var s_factor: float = clampf((z - 130.0) / 250.0, 0.0, 1.0)
		# Плавный спуск поймы до -5.0м
		var floodplain: float = -s_factor * 5.5
		# Извилистое русло реки
		var river_x: float = get_river_center_x(z)
		var dist_river: float = absf(x - river_x)
		var river_depth: float = 0.0
		if dist_river < 38.0:
			var d_norm: float = dist_river / 38.0
			# Параболический профиль глубины до -11..-13м
			river_depth = -6.5 * (1.0 - d_norm * d_norm)
		south_h = (floodplain + river_depth) * s_factor

	# 4. Восток: Вековая тайга (X > 100)
	var east_h: float = 0.0
	if x > 80.0:
		var e_factor: float = clampf((x - 80.0) / 200.0, 0.0, 1.0)
		east_h = (sin(x * 0.022) * cos(z * 0.02) * 3.2 + 1.8) * e_factor

	# 5. Запад: Заброшенный поселок (X < -100)
	var west_h: float = 0.0
	if x < -80.0:
		var w_factor: float = clampf((-x - 80.0) / 200.0, 0.0, 1.0)
		west_h = (cos(x * 0.015) * 1.5 + 0.8) * w_factor

	# 6. Микрорельеф тайги (неровности)
	var micro_noise: float = sin(x * 0.09 + z * 0.07) * 0.35 + cos(x * 0.05 - z * 0.08) * 0.25

	var total_h: float = base_h + north_h + south_h + east_h + west_h + (micro_noise * outpost_weight)
	# Кордон егеря выравниваем строго в плоскость Y = 0.0
	return lerpf(0.0, total_h, outpost_weight)

# Координата X центра изгиба реки на заданной глубине Z
func get_river_center_x(z: float) -> float:
	return 65.0 * sin(z * 0.012) - 45.0 * cos(z * 0.008)

# --- ГЕНЕРАЦИЯ ВСЕГО КОМПЛЕКСА ЛАНДШАФТА ---
func generate_all() -> void:
	# Очистка предыдущих сгенерированных узлов
	for child in get_children():
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

			# Triangle 1 (v0, v1, v2)
			var n1: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
			st.set_normal(n1)
			st.set_uv(Vector2((v0.x + half) / map_size, (v0.z + half) / map_size))
			st.add_vertex(v0)
			st.set_normal(n1)
			st.set_uv(Vector2((v1.x + half) / map_size, (v1.z + half) / map_size))
			st.add_vertex(v1)
			st.set_normal(n1)
			st.set_uv(Vector2((v2.x + half) / map_size, (v2.z + half) / map_size))
			st.add_vertex(v2)

			# Triangle 2 (v0, v2, v3)
			var n2: Vector3 = (v2 - v0).cross(v3 - v0).normalized()
			st.set_normal(n2)
			st.set_uv(Vector2((v0.x + half) / map_size, (v0.z + half) / map_size))
			st.add_vertex(v0)
			st.set_normal(n2)
			st.set_uv(Vector2((v2.x + half) / map_size, (v2.z + half) / map_size))
			st.add_vertex(v2)
			st.set_normal(n2)
			st.set_uv(Vector2((v3.x + half) / map_size, (v3.z + half) / map_size))
			st.add_vertex(v3)

	st.generate_normals()
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
	if Engine.is_editor_hint():
		terrain_body.owner = self
		mesh_inst.owner = self
		col_shape.owner = self

func _build_river_water() -> void:
	# Водная гладь по изгибу поймы
	var water_root := Node3D.new()
	water_root.name = "RiverWaterSystem"

	# Добавляем GlacialRiver для авто-регистрации с ValleyEcology
	var glacial_river := GlacialRiver.new()
	glacial_river.name = "GlacialRiverEmitter"
	var pts: Array[Vector3] = []
	for z_step in range(160, 500, 20):
		var r_x: float = get_river_center_x(float(z_step))
		pts.append(Vector3(r_x, -6.5, float(z_step)))
	glacial_river.river_path = pts
	water_root.add_child(glacial_river)

	# Построение меша водной ленты шириной 50м
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_width: float = 52.0

	for i in range(pts.size() - 1):
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]

		var fwd: Vector3 = (p2 - p1).normalized()
		var side: Vector3 = Vector3(-fwd.z, 0, fwd.x).normalized() * (water_width * 0.5)

		var v0: Vector3 = p1 - side
		var v1: Vector3 = p1 + side
		var v2: Vector3 = p2 + side
		var v3: Vector3 = p2 - side

		st.set_normal(Vector3.UP)
		st.add_vertex(v0)
		st.set_normal(Vector3.UP)
		st.add_vertex(v1)
		st.set_normal(Vector3.UP)
		st.add_vertex(v2)

		st.set_normal(Vector3.UP)
		st.add_vertex(v0)
		st.set_normal(Vector3.UP)
		st.add_vertex(v2)
		st.set_normal(Vector3.UP)
		st.add_vertex(v3)

	var water_mesh: ArrayMesh = st.commit()
	var w_mat := ShaderMaterial.new()
	w_mat.shader = water_shader
	water_mesh.surface_set_material(0, w_mat)

	var water_inst := MeshInstance3D.new()
	water_inst.name = "RiverWaterMesh"
	water_inst.mesh = water_mesh
	water_root.add_child(water_inst)

	add_child(water_root)
	if Engine.is_editor_hint():
		water_root.owner = self
		glacial_river.owner = self
		water_inst.owner = self

func _build_cave_and_poi_structures() -> void:
	var pois_node := Node3D.new()
	pois_node.name = "ValleyPOIStructures"

	# 1. Пещерный грот: Провал Шнека №3 (-120, 18.5, -440)
	var cave_scene: PackedScene = load("res://scenes/environment/CaveGrotto.tscn")
	if cave_scene:
		var cave: Node3D = cave_scene.instantiate()
		cave.name = "CaveGrottoEntrance"
		cave.position = Vector3(-120.0, 18.5, -440.0)
		pois_node.add_child(cave)
		if Engine.is_editor_hint():
			cave.owner = self

	# 2. Серные штольни (40, 24.0, -380)
	var sulfur_scene: PackedScene = load("res://scenes/environment/SulfurMine.tscn")
	if sulfur_scene:
		var mine: Node3D = sulfur_scene.instantiate()
		mine.name = "SulfurMineQuarry"
		mine.position = Vector3(40.0, 24.0, -380.0)
		pois_node.add_child(mine)
		if Engine.is_editor_hint():
			mine.owner = self

	# 3. Рыбацкие мостки (15, -8.0, 310)
	var pier_scene: PackedScene = load("res://scenes/environment/FishingPier.tscn")
	if pier_scene:
		var pier: Node3D = pier_scene.instantiate()
		pier.name = "FishingPierStructure"
		pier.position = Vector3(15.0, -6.5, 310.0)
		pois_node.add_child(pier)
		if Engine.is_editor_hint():
			pier.owner = self

	# 4. Каменистый брод (-180, -9.5, 260)
	var crossing_scene: PackedScene = load("res://scenes/environment/RiverCrossing.tscn")
	if crossing_scene:
		var crossing: Node3D = crossing_scene.instantiate()
		crossing.name = "RiverCrossingBoulders"
		crossing.position = Vector3(-180.0, -6.8, 260.0)
		pois_node.add_child(crossing)
		if Engine.is_editor_hint():
			crossing.owner = self

	add_child(pois_node)
	if Engine.is_editor_hint():
		pois_node.owner = self

func _build_choppable_forest() -> void:
	var forest_node := Node3D.new()
	forest_node.name = "ChoppableForest"

	var preset_pine: PackedScene = load("res://scenes/environment/trees/Tree_Pine_Tall.tscn")
	var preset_cedar: PackedScene = load("res://scenes/environment/trees/Tree_Cedar_Giant.tscn")
	var preset_birch: PackedScene = load("res://scenes/environment/trees/Tree_Birch.tscn")
	var preset_deadwood: PackedScene = load("res://scenes/environment/trees/Tree_Deadwood.tscn")
	var preset_larch: PackedScene = load("res://scenes/environment/trees/Tree_Larch.tscn")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var target_tree_count: int = 180
	var spawned: int = 0
	var attempts: int = 0

	while spawned < target_tree_count and attempts < 1600:
		attempts += 1
		var tx: float = rng.randf_range(-460.0, 460.0)
		var tz: float = rng.randf_range(-460.0, 460.0)

		# Не спавним внутри кордона егеря (100х100м)
		if absf(tx) < 52.0 and absf(tz) < 52.0:
			continue

		# Не спавним в воде реки
		if tz > 130.0:
			var r_x: float = get_river_center_x(tz)
			if absf(tx - r_x) < 28.0:
				continue

		var ty: float = get_height_at(tx, tz)
		if ty > 32.0 or ty < -5.5:
			continue

		# Выбор пресета в зависимости от биома
		var selected_scene: PackedScene = preset_pine

		if tz < -140.0:
			# Северные скалы: горная лиственница и сухостой
			selected_scene = preset_larch if rng.randf() > 0.35 else preset_deadwood
		elif tz > 140.0:
			# Пойма реки: березы и лиственницы
			selected_scene = preset_birch if rng.randf() > 0.45 else preset_larch
		elif tx > 80.0:
			# Восточная тайга: могучие кедры и высокие сосны
			var roll: float = rng.randf()
			if roll < 0.45:
				selected_scene = preset_cedar
			elif roll < 0.8:
				selected_scene = preset_pine
			else:
				selected_scene = preset_birch
		elif tx < -80.0:
			# Западный поселок: сухостой и редкие березы
			selected_scene = preset_deadwood if rng.randf() > 0.4 else preset_birch
		else:
			# Буфер вокруг базы (периметр): сосны, березы, кедры
			var roll: float = rng.randf()
			if roll < 0.4: selected_scene = preset_pine
			elif roll < 0.7: selected_scene = preset_birch
			else: selected_scene = preset_cedar

		if selected_scene:
			var tree_inst := selected_scene.instantiate() as Node3D
			tree_inst.name = "Tree_%d" % spawned
			var scale_rnd: float = rng.randf_range(0.85, 1.25)
			tree_inst.scale = Vector3(scale_rnd, scale_rnd, scale_rnd)
			tree_inst.rotation.y = rng.randf_range(0.0, TAU)
			tree_inst.position = Vector3(tx, ty, tz)

			forest_node.add_child(tree_inst)
			if Engine.is_editor_hint():
				tree_inst.owner = self
			spawned += 1

	add_child(forest_node)
	if Engine.is_editor_hint():
		forest_node.owner = self
