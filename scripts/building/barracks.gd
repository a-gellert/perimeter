class_name SettlerBarracks
extends StaticBody3D
## Settler Barracks (Барак выживших).
## Provides sheltered sleeping quarters for colony workers,
## accelerating energy restoration when off duty.

@export var required_logs: int = 10
@export var required_scrap: int = 4
@export var max_health: float = 600.0

@export var ghost_mesh: Node3D
@export var completed_mesh: Node3D
@export var solid_collision: CollisionShape3D

var current_logs: int = 0
var current_scrap: int = 0
var current_health: float = 600.0
var is_built: bool = false

var beds_count: int = 3
var current_occupants: Array[Node] = []

func _ready() -> void:
	current_health = max_health
	_update_visuals()

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			return { "prompt": "Встроить бревно в сруб барака (%d/%d)" % [current_logs, required_logs], "type": "BUILD" }
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			return { "prompt": "Обить крышу жестью (%d/%d)" % [current_scrap, required_scrap], "type": "BUILD" }
		else:
			return { "prompt": "Барак: нужно %d брёвен и %d металла" % [required_logs, required_scrap], "type": "NEED_RESOURCES" }
	else:
		return { "prompt": "Барак выживших (Коек свободно: %d/%d)" % [beds_count - current_occupants.size(), beds_count], "type": "INFO" }

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

func _check_completion() -> void:
	if current_logs >= required_logs and current_scrap >= required_scrap:
		is_built = true
		add_to_group("shelters")
		var bus := get_node_or_null("/root/GameEvents")
		if bus and bus.has_signal("structure_completed"):
			bus.structure_completed.emit(self)
		print("[Barracks] Constructed! Survivors can now rest safely.")

func _update_visuals() -> void:
	if ghost_mesh:
		ghost_mesh.visible = not is_built
	if completed_mesh:
		completed_mesh.visible = is_built
	if solid_collision:
		solid_collision.disabled = not is_built
