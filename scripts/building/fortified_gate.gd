class_name FortifiedGate
extends StaticBody3D
## Fortified Wooden Gate with Barred Latch.
## Constructed via logs and metal scrap. Once built, can be toggled open/closed from 1st-person FPV.
## Blocks nocturnal mutants when closed; permits friendly passage when opened.

signal gate_toggled(is_open: bool)

@export var required_logs: int = 6
@export var required_scrap: int = 4
@export var max_health: float = 300.0

@export var ghost_mesh: Node3D
@export var completed_mesh: Node3D
@export var door_leaf: Node3D
@export var solid_collision: CollisionShape3D
@export var interaction_area: Area3D

var current_logs: int = 0
var current_scrap: int = 0
var current_health: float = 300.0
var is_built: bool = false
var is_open: bool = false

func _ready() -> void:
	current_health = max_health
	_update_visuals()

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			return { "prompt": "Встроить бревно в ворота (%d/%d)" % [current_logs, required_logs], "type": "BUILD" }
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			return { "prompt": "Укрепить петли металлом (%d/%d)" % [current_scrap, required_scrap], "type": "BUILD" }
		else:
			return { "prompt": "Нужны бревна (%d/%d) и металл (%d/%d)" % [current_logs, required_logs, current_scrap, required_scrap], "type": "NEED_RESOURCES" }
	else:
		return {
			"prompt": "Закрыть ворота на засов" if is_open else "Открыть ворота",
			"type": "DOOR"
		}

func interact(player: PlayerController) -> void:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		# 1. Сначала укладываем брёвна
		if player.carried_logs > 0 and current_logs < required_logs:
			if player.remove_log():
				current_logs += 1
		# 2. Затем укрепляем петли металлоломом
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			if eco.use_scrap(1):
				current_scrap += 1

		_check_completion()
		_update_visuals()
	else:
		toggle_gate()

func toggle_gate() -> void:
	is_open = not is_open
	if solid_collision:
		solid_collision.disabled = is_open

	if door_leaf:
		var tween := create_tween()
		var target_rot_y := deg_to_rad(95.0) if is_open else 0.0
		tween.tween_property(door_leaf, "rotation:y", target_rot_y, 0.45).set_trans(Tween.TRANS_QUAD)

	gate_toggled.emit(is_open)

func take_damage(amount: float) -> void:
	if not is_built:
		return
	current_health = maxf(0.0, current_health - amount)
	if current_health <= 0.0:
		_breach_gate()

func _breach_gate() -> void:
	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("breach_alarm_triggered"):
		bus.breach_alarm_triggered.emit(global_position)
	# Распахиваем ворота при пробитии
	is_open = true
	if solid_collision:
		solid_collision.disabled = true
	if door_leaf:
		door_leaf.rotation.y = deg_to_rad(115.0)

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
		solid_collision.disabled = (not is_built) or is_open
