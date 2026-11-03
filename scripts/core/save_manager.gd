class_name SaveSystem
extends Node
## Global Save and Load Manager for Perimeter (Perimeter: Warden).
## Handles serialization and deserialization of the game state:
## - Time, Day and Weather
## - Player position, orientation, vitals (HP, stamina, fatigue, hunger)
## - Economy and inventory (carried items and outpost warehouse)
## - Built and blueprint structures (GhostWall, palisades)
## - Colony survivors (health, energy, assigned shifts)
## - Night raid progression (current cycle day)

signal save_started(slot: int)
signal save_completed(slot: int)
signal load_started(slot: int)
signal load_completed(slot: int)
signal save_error(message: String)

const SAVE_DIR: String = "user://saves/"
const META_FILE: String = "user://saves/metadata.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_SLOT: int = 0

var current_slot: int = 1
var is_loading: bool = false
var pending_load_data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_directory()
	_connect_autosave()

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			printerr("[SaveManager] Failed to create save directory: ", err)

func _connect_autosave() -> void:
	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("day_phase_changed"):
		bus.day_phase_changed.connect(_on_day_phase_changed)

func _on_day_phase_changed(phase: int) -> void:
	# Автосохранение на рассвете (DAWN) - безопасная зона начала дня
	if phase == GameEnums.DayPhase.DAWN:
		print("[SaveManager] Dawn reached. Performing autosave...")
		save_game(AUTOSAVE_SLOT, "Автосохранение (Рассвет)")

# ==============================================================================
# ПУБЛИЧНЫЕ МЕТОДЫ СОХРАНЕНИЯ И ЗАГРУЗКИ
# ==============================================================================

func save_game(slot: int = 1, custom_title: String = "") -> bool:
	save_started.emit(slot)
	_ensure_save_directory()

	var save_data := _gather_game_state()
	if save_data.is_empty():
		var err_msg := "Failed to gather game state for save."
		save_error.emit(err_msg)
		return false

	var current_day: int = save_data.get("time", {}).get("day", 1)
	var title := custom_title
	if title.is_empty():
		title = "День %d — %02d:00" % [
			current_day,
			int(save_data.get("time", {}).get("hour", 7.0))
		]

	var meta := {
		"slot": slot,
		"version": SAVE_VERSION,
		"title": title,
		"timestamp": Time.get_datetime_string_from_system(),
		"day": current_day,
		"hour": save_data.get("time", {}).get("hour", 7.0)
	}

	save_data["meta"] = meta

	var file_path := _get_slot_path(slot)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		var err_code := FileAccess.get_open_error()
		var msg := "Cannot open file %s for write: %d" % [file_path, err_code]
		printerr("[SaveManager] ", msg)
		save_error.emit(msg)
		return false

	var json_str := JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.close()

	_update_slot_meta(slot, meta)
	print("[SaveManager] Saved successfully to slot %d (%s)" % [slot, file_path])
	save_completed.emit(slot)
	return true

func load_game(slot: int = 1) -> bool:
	var file_path := _get_slot_path(slot)
	if not FileAccess.file_exists(file_path):
		printerr("[SaveManager] Save file does not exist: ", file_path)
		return false

	load_started.emit(slot)
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[SaveManager] Cannot open file %s for read." % file_path)
		return false

	var json_text := file.get_as_text()
	file.close()

	var test_json_conv := JSON.new()
	var parse_err := test_json_conv.parse(json_text)
	if parse_err != OK:
		printerr("[SaveManager] JSON parse error in save file: ", test_json_conv.get_error_message())
		return false

	var save_data: Dictionary = test_json_conv.data
	pending_load_data = save_data
	current_slot = slot

	# Если сцена Main уже загружена, восстанавливаем состояние
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.name == "Main":
		_apply_game_state(save_data)
		load_completed.emit(slot)
	else:
		# Переходим на сцену игры и после загрузки накатываем данные
		is_loading = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		# Ждем кадра готовности новой сцены
		_wait_and_apply_state(slot)

	return true

func _wait_and_apply_state(slot: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not pending_load_data.is_empty():
		_apply_game_state(pending_load_data)
		pending_load_data.clear()
	is_loading = false
	load_completed.emit(slot)

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))

func delete_save(slot: int = 1) -> bool:
	var path := _get_slot_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			_remove_slot_meta(slot)
			return true
	return false

func get_all_saves_meta() -> Dictionary:
	if not FileAccess.file_exists(META_FILE):
		return {}
	var file := FileAccess.open(META_FILE, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data
	return {}

func get_save_meta(slot: int) -> Dictionary:
	var all_meta := get_all_saves_meta()
	var slot_key := str(slot)
	if all_meta.has(slot_key):
		return all_meta[slot_key]
	return {}

# ==============================================================================
# СБОР СОСТОЯНИЯ ИГРЫ (SERIALIZATION)
# ==============================================================================

func _gather_game_state() -> Dictionary:
	var state: Dictionary = {}
	var world := get_tree().current_scene
	if not world:
		return {}

	# 1. Время и День
	var tm := world.get_node_or_null("TimeManager") as TimeManager
	var raid_mgr := world.get_node_or_null("NightRaidManager") as NightRaidManager
	var current_day := 1
	if raid_mgr:
		current_day = raid_mgr.current_day

	state["time"] = {
		"hour": tm.current_hour if tm else 7.0,
		"phase": tm.current_phase if tm else GameEnums.DayPhase.DAY,
		"day": current_day
	}

	# 2. Игрок (PlayerController)
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player and is_instance_valid(player):
		state["player"] = {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
			"hp": player.hp,
			"stamina": player.stamina,
			"fatigue": player.fatigue,
			"hunger": player.hunger,
			"carried_logs": player.carried_logs
		}

	# 3. Экономика и Склад базы
	var eco := get_node_or_null("/root/EconomyManager")
	if eco:
		state["economy"] = {
			"player_logs": eco.player_logs,
			"player_fuel": eco.player_fuel,
			"player_scrap": eco.player_scrap,
			"player_rations": eco.player_rations,
			"base_storage": eco.base_storage.duplicate(true)
		}

	# 4. Постройки и Чертежи стен
	var buildings_data: Array = []
	var blueprints_node := world.get_node_or_null("PerimeterBlueprints")
	if blueprints_node:
		for child in blueprints_node.get_children():
			var wall_data := _serialize_wall_node(child)
			if not wall_data.is_empty():
				buildings_data.append(wall_data)
	state["buildings"] = buildings_data

	# 5. Выжившие (NPC)
	var npcs_data: Array = []
	for npc in get_tree().get_nodes_in_group("settlers"):
		if npc is SurvivorNPC and is_instance_valid(npc):
			npcs_data.append({
				"name": npc.npc_name,
				"position": [npc.global_position.x, npc.global_position.y, npc.global_position.z],
				"energy": npc.energy,
				"shift": npc.shift
			})
	# Если группа не была добавлена, ищем по ноде SurvivorNPC
	if npcs_data.is_empty():
		var single_npc := world.get_node_or_null("SurvivorNPC") as SurvivorNPC
		if single_npc and is_instance_valid(single_npc):
			npcs_data.append({
				"name": single_npc.npc_name,
				"position": [single_npc.global_position.x, single_npc.global_position.y, single_npc.global_position.z],
				"energy": single_npc.energy,
				"shift": single_npc.shift
			})
	state["npcs"] = npcs_data

	# 6. Срубленные деревья
	var chopped_trees: Array = []
	var env_node := world.get_node_or_null("Environment")
	if env_node:
		for tree_node in env_node.get_children():
			var choppable := tree_node.get_node_or_null("ChoppableTree") as ChoppableTree
			if choppable and choppable.current_hits > 0:
				chopped_trees.append({
					"node_name": tree_node.name,
					"hits": choppable.current_hits,
					"is_felled": (choppable.current_hits >= choppable.max_hits)
				})
	state["trees"] = chopped_trees

	return state

func _serialize_wall_node(node: Node) -> Dictionary:
	var ghost_area := node.get_node_or_null("GhostWall") as GhostWall
	if not ghost_area and node is GhostWall:
		ghost_area = node

	if ghost_area:
		var parent_3d := node as Node3D
		return {
			"node_name": node.name,
			"position": [parent_3d.global_position.x, parent_3d.global_position.y, parent_3d.global_position.z],
			"rotation_y": parent_3d.rotation.y,
			"current_logs": ghost_area.current_logs,
			"required_logs": ghost_area.required_logs,
			"is_completed": (ghost_area.current_logs >= ghost_area.required_logs)
		}
	return {}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ ИГРЫ (DESERIALIZATION)
# ==============================================================================

func _apply_game_state(state: Dictionary) -> void:
	var world := get_tree().current_scene
	if not world:
		return

	# 1. Время и Рейды
	if state.has("time"):
		var t_data: Dictionary = state["time"]
		var tm := world.get_node_or_null("TimeManager") as TimeManager
		if tm:
			tm.current_hour = t_data.get("hour", 7.0)
			tm.current_phase = t_data.get("phase", GameEnums.DayPhase.DAY)
			tm._evaluate_phase(true)

		var raid_mgr := world.get_node_or_null("NightRaidManager") as NightRaidManager
		if raid_mgr:
			raid_mgr.current_day = t_data.get("day", 1)
			raid_mgr.current_phase = t_data.get("phase", GameEnums.DayPhase.DAY)

	# 2. Игрок
	if state.has("player"):
		var p_data: Dictionary = state["player"]
		var player := get_tree().get_first_node_in_group("player") as PlayerController
		if player and is_instance_valid(player):
			var pos_arr: Array = p_data.get("position", [0, 0, 0])
			if pos_arr.size() == 3:
				player.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
			player.rotation.y = p_data.get("rotation_y", 0.0)
			player.hp = p_data.get("hp", player.max_hp)
			player.stamina = p_data.get("stamina", player.max_stamina)
			player.fatigue = p_data.get("fatigue", 0.0)
			player.hunger = p_data.get("hunger", 100.0)
			player.carried_logs = p_data.get("carried_logs", 0)
			player._update_log_visuals()
			player.emit_signal("stats_changed", player.hp, player.stamina, player.fatigue, player.hunger)
			player.emit_signal("carried_logs_changed", player.carried_logs, player.max_carried_logs)

	# 3. Экономика
	if state.has("economy"):
		var e_data: Dictionary = state["economy"]
		var eco := get_node_or_null("/root/EconomyManager")
		if eco:
			eco.player_logs = e_data.get("player_logs", 0)
			eco.player_fuel = e_data.get("player_fuel", 0)
			eco.player_scrap = e_data.get("player_scrap", 0)
			eco.player_rations = e_data.get("player_rations", 2)
			if e_data.has("base_storage") and e_data["base_storage"] is Dictionary:
				eco.base_storage = e_data["base_storage"].duplicate(true)
			eco.resources_updated.emit()

	# 4. Постройки и Стены
	if state.has("buildings"):
		var blueprints_node := world.get_node_or_null("PerimeterBlueprints")
		if blueprints_node:
			var b_list: Array = state["buildings"]
			for b_info in b_list:
				var wall_node := blueprints_node.get_node_or_null(b_info.get("node_name", ""))
				if wall_node:
					var ghost := wall_node.get_node_or_null("GhostWall") as GhostWall
					if ghost:
						ghost.current_logs = b_info.get("current_logs", 0)
						for i in range(1, ghost.current_logs + 1):
							ghost._snap_log_visual(i)
						if b_info.get("is_completed", false):
							ghost._complete_construction()

	# 5. Выжившие
	if state.has("npcs"):
		var npc_list: Array = state["npcs"]
		for npc_data in npc_list:
			var single_npc := world.get_node_or_null("SurvivorNPC") as SurvivorNPC
			if single_npc and is_instance_valid(single_npc):
				single_npc.energy = npc_data.get("energy", 100.0)
				single_npc.shift = npc_data.get("shift", GameEnums.Shift.DAY_SHIFT)
				var pos_a: Array = npc_data.get("position", [])
				if pos_a.size() == 3:
					single_npc.global_position = Vector3(pos_a[0], pos_a[1], pos_a[2])

	# 6. Деревья
	if state.has("trees"):
		var env_node := world.get_node_or_null("Environment")
		if env_node:
			for t_info in state["trees"]:
				var tree_node := env_node.get_node_or_null(t_info.get("node_name", ""))
				if tree_node:
					var choppable := tree_node.get_node_or_null("ChoppableTree") as ChoppableTree
					if choppable:
						choppable.current_hits = t_info.get("hits", 0)
						if t_info.get("is_felled", false):
							tree_node.visible = false
							tree_node.process_mode = Node.PROCESS_MODE_DISABLED

	print("[SaveManager] Game state applied successfully.")

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ РАБОТЫ С МЕТАДАННЫМИ
# ==============================================================================

func _get_slot_path(slot: int) -> String:
	return "%ssave_slot_%d.json" % [SAVE_DIR, slot]

func _update_slot_meta(slot: int, meta: Dictionary) -> void:
	var all_meta := get_all_saves_meta()
	all_meta[str(slot)] = meta
	var file := FileAccess.open(META_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all_meta, "\t"))
		file.close()

func _remove_slot_meta(slot: int) -> void:
	var all_meta := get_all_saves_meta()
	var slot_key := str(slot)
	if all_meta.has(slot_key):
		all_meta.erase(slot_key)
		var file := FileAccess.open(META_FILE, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(all_meta, "\t"))
			file.close()
