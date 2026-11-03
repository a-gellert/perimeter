class_name AmberSpotlight
extends StaticBody3D
## Tectonic Amber Ultraviolet Spotlight.
## Emits a powerful UV beam that burns and repels nocturnal spore mutants.
## Requires 2 Amber crystals, 4 Scrap, and 2 Logs to construct.

@export var required_logs: int = 2
@export var required_scrap: int = 4
@export var required_amber: int = 2

@export var uv_damage_per_sec: float = 35.0
@export var beam_range: float = 24.0
@export var beam_angle_deg: float = 45.0

@export var spot_light: SpotLight3D
@export var beam_mesh: MeshInstance3D
@export var uv_detection_area: Area3D
@export var ghost_mesh: Node3D
@export var completed_mesh: Node3D

var current_logs: int = 0
var current_scrap: int = 0
var current_amber: int = 0
var is_built: bool = false
var is_active: bool = false

var _mutants_in_beam: Array[CharacterBody3D] = []

func _ready() -> void:
	_update_visuals()
	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("day_phase_changed"):
		bus.day_phase_changed.connect(_on_phase_changed)

	if uv_detection_area:
		uv_detection_area.body_entered.connect(_on_body_entered_beam)
		uv_detection_area.body_exited.connect(_on_body_exited_beam)

func _physics_process(delta: float) -> void:
	if not is_built or not is_active:
		return

	# Нанесение термического УФ-урона всем мутантам в световом конусе
	for mutant in _mutants_in_beam:
		if is_instance_valid(mutant) and mutant is CharacterBody3D:
			if mutant.has_method("take_damage"):
				mutant.take_damage(uv_damage_per_sec * delta)
			elif mutant.get("stats") and mutant.stats.has_method("take_damage"):
				mutant.stats.take_damage(uv_damage_per_sec * delta)
			
			# Периодические искры ожога
			if randf() < 0.15:
				var vfx_scene := load("res://scenes/vfx/UVScorchVFX.tscn") as PackedScene
				if vfx_scene and get_tree() and get_tree().current_scene:
					var scorch := vfx_scene.instantiate() as CPUParticles3D
					get_tree().current_scene.add_child(scorch)
					scorch.global_position = mutant.global_position + Vector3(0, 1.0, 0)
					scorch.emitting = true
					get_tree().create_timer(0.6).timeout.connect(scorch.queue_free)

func _on_phase_changed(phase: int) -> void:
	if not is_built:
		return
	# Автоматически активируется в сумерках и ночью
	var should_shine := (phase == GameEnums.DayPhase.NIGHT or phase == GameEnums.DayPhase.DUSK)
	set_active(should_shine)

func set_active(active: bool) -> void:
	is_active = active
	if spot_light:
		spot_light.visible = is_active
	if beam_mesh:
		beam_mesh.visible = is_active

func get_interaction_info(player: PlayerController) -> Dictionary:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			return { "prompt": "Установить мачту прожектора (%d/%d)" % [current_logs, required_logs], "type": "BUILD" }
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			return { "prompt": "Смонтировать рефлектор из металла (%d/%d)" % [current_scrap, required_scrap], "type": "BUILD" }
		elif eco and eco.base_storage.get("amber", 0) > 0 and current_amber < required_amber:
			return { "prompt": "Вставить ядро тектонического янтаря (%d/%d)" % [current_amber, required_amber], "type": "BUILD" }
		else:
			return { "prompt": "УФ-прожектор: нужно %d бр., %d мет., %d янт." % [required_logs, required_scrap, required_amber], "type": "NEED_RESOURCES" }
	else:
		return { "prompt": "Выключить УФ-прожектор" if is_active else "Включить УФ-прожектор", "type": "TOGGLE_POWER" }

func interact(player: PlayerController) -> void:
	if not is_built:
		var eco := get_node_or_null("/root/EconomyManager")
		if player.carried_logs > 0 and current_logs < required_logs:
			if player.remove_log():
				current_logs += 1
		elif eco and eco.player_scrap > 0 and current_scrap < required_scrap:
			if eco.use_scrap(1):
				current_scrap += 1
		elif eco and eco.base_storage.get("amber", 0) > 0 and current_amber < required_amber:
			eco.base_storage["amber"] -= 1
			eco.resources_updated.emit()
			current_amber += 1

		_check_completion()
		_update_visuals()
	else:
		set_active(not is_active)

func _check_completion() -> void:
	if current_logs >= required_logs and current_scrap >= required_scrap and current_amber >= required_amber:
		is_built = true
		set_active(true)
		var bus := get_node_or_null("/root/GameEvents")
		if bus and bus.has_signal("structure_completed"):
			bus.structure_completed.emit(self)

func _update_visuals() -> void:
	if ghost_mesh:
		ghost_mesh.visible = not is_built
	if completed_mesh:
		completed_mesh.visible = is_built
	set_active(is_built and is_active)

func _on_body_entered_beam(body: Node) -> void:
	if body is CharacterBody3D and (body.is_in_group("enemies") or body is MutantBase):
		if not _mutants_in_beam.has(body):
			_mutants_in_beam.append(body)

func _on_body_exited_beam(body: Node) -> void:
	if body is CharacterBody3D and _mutants_in_beam.has(body):
		_mutants_in_beam.erase(body)
