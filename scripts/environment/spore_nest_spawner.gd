class_name SporeNestSpawner
extends StaticBody3D
## "Гнездо кордицепса" (Spore Nest Spawner) — Infested biomass hive.
## Spawns Spore Zombies, Spore Wolves, and Spore Boars when disturbed or under the cover of night.
## Destructible biological objective yielding rare valley resources upon purification.

@export var max_health: float = 120.0
@export var trigger_radius: float = 28.0
@export var spawn_radius: float = 7.0
@export var spawn_interval: float = 12.0
@export var night_spawn_interval: float = 7.0
@export var max_active_monsters: int = 4
@export var monster_scenes: Array[PackedScene] = []

var health: float = 120.0
var _spawn_timer: float = 0.0
var _active_spawned: Array[Node3D] = []
var _target_player: CharacterBody3D
var _nest_mesh: Node3D

func _ready() -> void:
	health = max_health
	add_to_group("spore_nests")
	add_to_group("interactable")
	_nest_mesh = get_node_or_null("MoundMesh")

	if monster_scenes.is_empty():
		monster_scenes.append(load("res://scenes/enemies/SporeZombie.tscn"))
		monster_scenes.append(load("res://scenes/enemies/SporeWolf.tscn"))
		monster_scenes.append(load("res://scenes/enemies/SporeBoar.tscn"))

	_spawn_timer = randf_range(2.0, 5.0)

func _process(delta: float) -> void:
	_cleanup_dead_monsters()

	if not _target_player:
		_find_player()

	var is_night: bool = false
	if has_node("/root/ValleyEcology"):
		is_night = ValleyEcology.is_night

	var player_near: bool = false
	if _target_player and is_instance_valid(_target_player):
		var dist := global_position.distance_to(_target_player.global_position)
		if dist <= trigger_radius:
			player_near = true

	# Spawner acts if player is close or if it's nighttime
	if player_near or is_night:
		var current_interval := night_spawn_interval if is_night else spawn_interval
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = current_interval
			if _active_spawned.size() < max_active_monsters:
				_spawn_spore_monster()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_target_player = players[0] as CharacterBody3D
	elif get_tree().current_scene:
		_target_player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D

func _cleanup_dead_monsters() -> void:
	var alive: Array[Node3D] = []
	for m in _active_spawned:
		if is_instance_valid(m):
			alive.append(m)
	_active_spawned = alive

func _spawn_spore_monster() -> void:
	if monster_scenes.is_empty():
		return

	# Weighted selection: Zombie (45%), Wolf (35%), Boar (20%)
	var r := randf()
	var selected_scene: PackedScene
	if r < 0.45:
		selected_scene = monster_scenes[0] # Zombie
	elif r < 0.80 and monster_scenes.size() > 1:
		selected_scene = monster_scenes[1] # Wolf
	elif monster_scenes.size() > 2:
		selected_scene = monster_scenes[2] # Boar
	else:
		selected_scene = monster_scenes[0]

	if not selected_scene:
		return

	var angle := randf_range(0.0, TAU)
	var dist := randf_range(2.5, spawn_radius)
	var spawn_pos := global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	# Adjust Y to terrain if manager exists
	var world_topo := get_node_or_null("/root/WorldTopography")
	if world_topo and world_topo.has_method("get_elevation_at"):
		spawn_pos.y = world_topo.get_elevation_at(spawn_pos.x, spawn_pos.z)
	else:
		spawn_pos.y = global_position.y

	var monster := selected_scene.instantiate() as CharacterBody3D
	if not monster:
		return

	var enemies_container: Node = get_tree().current_scene.get_node_or_null("Enemies")
	if not enemies_container:
		enemies_container = get_parent()

	enemies_container.add_child(monster)
	monster.global_position = spawn_pos
	_active_spawned.append(monster)

	# Direct monster towards disturbance
	if monster is MutantBase:
		monster.target_stimulus_pos = global_position
		monster.current_state = MutantBase.State.ALERTED
		if monster.has_method("_wake_up_to_hunt"):
			monster._wake_up_to_hunt()

	# Visual pulse on spawn
	if _nest_mesh:
		var tw := create_tween()
		tw.tween_property(_nest_mesh, "scale", Vector3(1.15, 1.25, 1.15), 0.15)
		tw.tween_property(_nest_mesh, "scale", Vector3.ONE, 0.25)

	# Sound warning
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 22.0)

func take_damage(amount: float) -> void:
	health -= amount

	# Shake reaction
	if _nest_mesh:
		var tw := create_tween()
		tw.tween_property(_nest_mesh, "scale", Vector3(0.9, 0.85, 0.9), 0.08)
		tw.tween_property(_nest_mesh, "scale", Vector3.ONE, 0.15)

	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 25.0)

	if health <= 0.0:
		_destroy_nest()

func _destroy_nest() -> void:
	# Spawn destruction spore cloud
	var spore_vfx := load("res://scenes/vfx/SporeFogVFX.tscn")
	if spore_vfx:
		var vfx: Node3D = spore_vfx.instantiate() as Node3D
		if vfx:
			get_parent().add_child(vfx)
			vfx.global_position = global_position + Vector3(0, 1.0, 0)

	# Drop rewards
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	var pickup_scene := load("res://scenes/resource_pickup.tscn")
	if not pickup_scene:
		return

	# Drop 2x Amber (rare spore core) and 1x Scrap
	for loot_info in [{"type": "amber", "amt": 2}, {"type": "scrap", "amt": 15}]:
		var pickup := pickup_scene.instantiate() as Node3D
		if pickup:
			get_parent().add_child(pickup)
			pickup.global_position = global_position + Vector3(randf_range(-1.2, 1.2), 0.5, randf_range(-1.2, 1.2))
			if "resource_type" in pickup:
				pickup.resource_type = loot_info["type"]
			if "amount" in pickup:
				pickup.amount = loot_info["amt"]
