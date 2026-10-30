class_name NightRaidManager
extends Node
## Manages nocturnal mutant incursions and siege waves against the ranger outpost.
## Scales raid intensity across day cycles, triggers mid-night reinforcement waves,
## and purges distant mutants when dawn breaks.

@export var current_day: int = 1
@export var min_spawn_distance: float = 80.0
@export var max_spawn_distance: float = 120.0
@export var cleanup_distance: float = 60.0
@export var mutant_scene: PackedScene

var current_phase: int = GameEnums.DayPhase.DAY
var is_raid_active: bool = false
var _mid_night_reinforcement_done: bool = false
var _spawned_mutants: Array[Node3D] = []

func _ready() -> void:
	if not mutant_scene:
		mutant_scene = load("res://scenes/mutant_sleeper.tscn")
	
	if GameEvents:
		if GameEvents.has_signal("day_phase_changed"):
			GameEvents.day_phase_changed.connect(_on_day_phase_changed)
		if GameEvents.has_signal("time_updated"):
			GameEvents.time_updated.connect(_on_time_updated)

func _on_day_phase_changed(phase: int) -> void:
	current_phase = phase
	match phase:
		GameEnums.DayPhase.DAWN:
			current_day += 1
			_mid_night_reinforcement_done = false
		GameEnums.DayPhase.NIGHT:
			_start_night_raid()
		GameEnums.DayPhase.DAY:
			_end_night_raid()

func _on_time_updated(hours: int, _minutes: int, phase: int) -> void:
	if phase != GameEnums.DayPhase.NIGHT and current_phase != GameEnums.DayPhase.NIGHT:
		return
	
	# Mid-night reinforcement wave around 01:00 AM
	if hours == 1 and not _mid_night_reinforcement_done:
		_mid_night_reinforcement_done = true
		_spawn_mid_night_reinforcements()

func _start_night_raid() -> void:
	is_raid_active = true
	var intensity := get_raid_intensity()
	var spawn_count: int = intensity["count"]
	var is_boss_night: bool = intensity["has_boss"]

	if spawn_count > 0:
		for i in range(spawn_count):
			var is_boss := is_boss_night and (i == 0 or (spawn_count >= 12 and i == 1))
			_spawn_mutant(is_boss)
	
	GameEvents.night_raid_started.emit(spawn_count)

func _spawn_mid_night_reinforcements() -> void:
	if not is_raid_active:
		return
	
	var cycle_day: int = ((current_day - 1) % 6) + 1
	var extra_count: int = 0
	var has_boss: bool = false

	match cycle_day:
		3, 4:
			extra_count = randi_range(2, 3)
		5:
			# Blood Eclipse mid-night surge
			extra_count = randi_range(4, 6)
			has_boss = true
		_:
			extra_count = 0

	for i in range(extra_count):
		var is_boss := has_boss and (i == 0)
		_spawn_mutant(is_boss)

func _end_night_raid() -> void:
	is_raid_active = false
	_cleanup_far_mutants()
	GameEvents.night_raid_ended.emit()

func get_raid_intensity() -> Dictionary:
	# 6-day cycle:
	# Days 1-2: 2-4 mutants
	# Days 3-4: 5-8 mutants
	# Day 5: 12+ mutants with boss rush (Blood Eclipse)
	# Day 6: guaranteed quiet night (0 mutants)
	var cycle_day: int = ((current_day - 1) % 6) + 1
	match cycle_day:
		1, 2:
			return { "count": randi_range(2, 4), "has_boss": false, "name": "Разведка" }
		3, 4:
			return { "count": randi_range(5, 8), "has_boss": false, "name": "Стая" }
		5:
			return { "count": randi_range(12, 15), "has_boss": true, "name": "Кровавое Затмение" }
		6:
			return { "count": 0, "has_boss": false, "name": "Затишье" }
		_:
			return { "count": 2, "has_boss": false, "name": "Набег" }

func _spawn_mutant(is_boss: bool = false) -> Node3D:
	if not mutant_scene:
		return null

	var base_pos := get_base_position()
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(min_spawn_distance, max_spawn_distance)
	var spawn_pos := base_pos + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	spawn_pos.y = _get_elevation_at(spawn_pos.x, spawn_pos.z)

	var inst := mutant_scene.instantiate() as CharacterBody3D
	if not inst:
		return null

	# Add to scene tree
	var enemies_container: Node = null
	if get_tree() and get_tree().current_scene:
		enemies_container = get_tree().current_scene.get_node_or_null("Enemies")
		if not enemies_container:
			enemies_container = get_tree().current_scene
	else:
		enemies_container = self

	enemies_container.add_child(inst)
	inst.global_position = spawn_pos
	_spawned_mutants.append(inst)

	if inst is MutantBase:
		inst.target_stimulus_pos = base_pos
		inst.current_state = MutantBase.State.ALERTED
		if inst.has_method("_wake_up_to_hunt"):
			inst._wake_up_to_hunt()
		if is_boss:
			inst.max_health *= 2.5
			inst.health = inst.max_health
			inst.attack_damage *= 1.8
			inst.scale = Vector3(1.35, 1.35, 1.35)
			inst.add_to_group("boss_mutants")

	return inst

func _cleanup_far_mutants() -> void:
	var base_pos := get_base_position()
	var active_survivors: Array[Node3D] = []

	for mutant in _spawned_mutants:
		if is_instance_valid(mutant) and mutant is Node3D:
			var dist: float = mutant.global_position.distance_to(base_pos)
			if dist >= cleanup_distance:
				mutant.queue_free()
			else:
				active_survivors.append(mutant)

	_spawned_mutants = active_survivors

func get_base_position() -> Vector3:
	if get_tree():
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			return player.global_position
		var cabin := get_tree().get_first_node_in_group("warden_cabin") as Node3D
		if cabin and is_instance_valid(cabin):
			return cabin.global_position
		if get_tree().current_scene:
			var cabin_node := get_tree().current_scene.get_node_or_null("WardenCabin") as Node3D
			if cabin_node:
				return cabin_node.global_position
	return Vector3(0.0, 0.0, 10.0)

func _get_elevation_at(x: float, z: float) -> float:
	if is_inside_tree() and get_viewport() and get_viewport().world_3d:
		var space_state := get_viewport().world_3d.direct_space_state
		if space_state:
			var ray_query := PhysicsRayQueryParameters3D.create(
				Vector3(x, 100.0, z),
				Vector3(x, -50.0, z),
				1 # Environment collision layer
			)
			var hit := space_state.intersect_ray(ray_query)
			if not hit.is_empty():
				return hit.position.y
	if get_tree() and get_tree().current_scene:
		var terrain := get_tree().current_scene.get_node_or_null("TerrainValley")
		if terrain and terrain.has_method("get_height_at"):
			return terrain.get_height_at(x, z)
	return 0.0
