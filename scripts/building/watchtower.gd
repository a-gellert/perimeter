class_name Watchtower
extends StaticBody3D
## Timber Watchtower for perimeter guard posts.
## Provides an elevated firing platform (+4.5m) for survivor sentries with bows/rifles.
## Grants sentries increased detection range and immunity to ground melee swipes.

signal sentry_stationed(npc_node: Node)
signal sentry_unstationed(npc_node: Node)

@export var required_logs: int = 8
@export var required_scrap: int = 2
@export var max_health: float = 450.0

@export var ghost_mesh: Node3D
@export var completed_mesh: Node3D
@export var solid_collision: CollisionShape3D
@export var sentry_post_marker: Marker3D

var current_logs: int = 0
var current_scrap: int = 0
var current_health: float = 450.0
var is_built: bool = false
var stationed_sentry: Node = null

func _ready() -> void:
	current_health = max_health
	_update_visuals()

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			return { "prompt": "Встроить опорное бревно вышки (%d/%d)" % [current_logs, required_logs], "type": "BUILD" }
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			return { "prompt": "Скрепить настил скобами (%d/%d)" % [current_scrap, required_scrap], "type": "BUILD" }
		else:
			return { "prompt": "Вышка: нужно %d брёвен и %d металла" % [required_logs, required_scrap], "type": "NEED_RESOURCES" }
	else:
		if stationed_sentry == null:
			return { "prompt": "Назначить часового на вышку", "type": "STATION_SENTRY" }
		else:
			return { "prompt": "Освободить пост вышки (%s)" % stationed_sentry.name, "type": "DISMISS_SENTRY" }

func interact(player: PlayerController) -> void:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			if player.remove_log():
				current_logs += 1
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			if eco.use_scrap(1):
				current_scrap += 1

		_check_completion()
		_update_visuals()
	else:
		if stationed_sentry == null:
			_auto_station_nearest_sentry()
		else:
			dismiss_sentry()

func _auto_station_nearest_sentry() -> void:
	var settlers := get_tree().get_nodes_in_group("settlers")
	var nearest_npc: Node3D = null
	var min_dist: float = 40.0

	for s in settlers:
		if s is Node3D and is_instance_valid(s):
			var dist := global_position.distance_to(s.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_npc = s

	if not nearest_npc:
		var single := get_tree().current_scene.get_node_or_null("SurvivorNPC") as Node3D
		if single and is_instance_valid(single):
			nearest_npc = single

	if nearest_npc:
		station_sentry(nearest_npc)

func station_sentry(npc: Node3D) -> void:
	stationed_sentry = npc
	if "is_stationed" in npc:
		npc.is_stationed = true
	if sentry_post_marker:
		npc.global_position = sentry_post_marker.global_position
	sentry_stationed.emit(npc)

func dismiss_sentry() -> void:
	if stationed_sentry:
		var dismissed := stationed_sentry
		stationed_sentry = null
		if dismissed is Node3D:
			dismissed.global_position = global_position + Vector3(2.0, 0.0, 2.0)
		if "is_stationed" in dismissed:
			dismissed.is_stationed = false
		sentry_unstationed.emit(dismissed)

func _check_completion() -> void:
	if current_logs >= required_logs and current_scrap >= required_scrap:
		is_built = true
		var bus := get_node_or_null("/root/GameEvents")
		if bus and bus.has_signal("structure_completed"):
			bus.structure_completed.emit(self)

func _update_visuals() -> void:
	if ghost_mesh:
		ghost_mesh.visible = not is_built
	if completed_mesh:
		completed_mesh.visible = is_built
	if solid_collision:
		solid_collision.disabled = not is_built
