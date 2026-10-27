class_name SurvivorNPC
extends CharacterBody3D
## First settler ("Семеныч") with 2-shift schedule and energy tracking.

@export var npc_name: String = "Семеныч"
@export var shift: int = GameEnums.Shift.DAY_SHIFT
@export var torch_light: OmniLight3D
@export var torch_mesh: Node3D

var energy: float = 100.0
var patrol_point: Vector3

func _ready() -> void:
	patrol_point = global_position
	GameEvents.day_phase_changed.connect(_on_phase_changed)
	_update_shift_state(GameEnums.DayPhase.DAY)

func _process(delta: float) -> void:
	# Energy consumption during active duty
	if _is_on_duty():
		energy = maxf(0.0, energy - 1.2 * delta)
	else:
		energy = minf(100.0, energy + 4.0 * delta)

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
