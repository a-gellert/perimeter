class_name SurvivorNPC
extends CharacterBody3D
## First settler ("Семеныч") with 2-shift schedule and energy tracking.

@export var npc_name: String = "Семеныч"
@export var shift: int = GameEnums.Shift.DAY_SHIFT
@export var torch_light: OmniLight3D
@export var torch_mesh: Node3D

var energy: float = 100.0
var patrol_point: Vector3

var is_stationed: bool = false
var shelter_target: Node3D = null

func _ready() -> void:
	add_to_group("settlers")
	patrol_point = global_position
	GameEvents.day_phase_changed.connect(_on_phase_changed)
	_update_shift_state(GameEnums.DayPhase.DAY)

func _process(delta: float) -> void:
	# Energy consumption during active duty
	if _is_on_duty():
		energy = maxf(0.0, energy - 1.2 * delta)
	else:
		var recovery_rate: float = 4.0
		var nearest_shelter := _find_nearest_shelter()
		if nearest_shelter and global_position.distance_to(nearest_shelter.global_position) < 6.0:
			recovery_rate = 8.0 # Двойной отдых в бараке
		energy = minf(100.0, energy + recovery_rate * delta)

func _physics_process(delta: float) -> void:
	if is_stationed:
		velocity = Vector3.ZERO
		return

	if not _is_on_duty():
		var shelter := _find_nearest_shelter()
		if shelter:
			var to_shelter := shelter.global_position - global_position
			to_shelter.y = 0.0
			if to_shelter.length() > 2.5:
				velocity = to_shelter.normalized() * 2.0
				move_and_slide()
				return

	# Idle or return to patrol point
	var to_patrol := patrol_point - global_position
	to_patrol.y = 0.0
	if to_patrol.length() > 1.5:
		velocity = to_patrol.normalized() * 1.5
		move_and_slide()
	else:
		velocity = Vector3.ZERO

func _find_nearest_shelter() -> Node3D:
	var shelters := get_tree().get_nodes_in_group("shelters")
	var nearest: Node3D = null
	var min_dist: float = 9999.0
	for s in shelters:
		if s is Node3D and is_instance_valid(s):
			var dist := global_position.distance_to(s.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = s
	return nearest

func toggle_shift() -> void:
	shift = GameEnums.Shift.NIGHT_SHIFT if shift == GameEnums.Shift.DAY_SHIFT else GameEnums.Shift.DAY_SHIFT
	var phase := _get_current_phase()
	_update_shift_state(phase)

func _is_on_duty() -> bool:
	var phase := _get_current_phase()
	if shift == GameEnums.Shift.DAY_SHIFT:
		return phase == GameEnums.DayPhase.DAY or phase == GameEnums.DayPhase.DAWN
	else:
		return phase == GameEnums.DayPhase.NIGHT or phase == GameEnums.DayPhase.DUSK

func _on_phase_changed(phase: int) -> void:
	_update_shift_state(phase)

func _update_shift_state(phase: int) -> void:
	var on_duty := _is_on_duty()
	var is_night := (phase == GameEnums.DayPhase.NIGHT or phase == GameEnums.DayPhase.DUSK)
	
	if torch_light:
		torch_light.visible = on_duty and is_night
	if torch_mesh:
		torch_mesh.visible = on_duty and is_night

func _get_current_phase() -> int:
	var world := get_tree().current_scene
	var tm := world.get_node_or_null("TimeManager") as TimeManager
	return tm.current_phase if tm else GameEnums.DayPhase.DAY
