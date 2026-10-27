class_name TimeManager
extends Node
## Simulates the 24-hour taiga day/night cycle.
## Real-time ratio: 6 min day / 3 min night (~22.5s per in-game hour).

@export var start_hour: float = 7.0
@export var day_length_real_sec: float = 540.0 # 9 minutes total cycle

var current_hour: float = 7.0
var current_phase: int = GameEnums.DayPhase.DAY

func _ready() -> void:
	current_hour = start_hour
	_evaluate_phase(true)

func _process(delta: float) -> void:
	var hours_per_sec := 24.0 / day_length_real_sec
	current_hour = fmod(current_hour + hours_per_sec * delta, 24.0)
	_evaluate_phase()
	
	var h := int(current_hour)
	var m := int((current_hour - h) * 60.0)
	GameEvents.time_updated.emit(h, m, current_phase)

func skip_hours(hours: int) -> void:
	current_hour = fmod(current_hour + float(hours), 24.0)
	_evaluate_phase(true)

func _evaluate_phase(force_emit: bool = false) -> void:
	var new_phase: int
	if current_hour >= 5.0 and current_hour < 7.0:
		new_phase = GameEnums.DayPhase.DAWN
	elif current_hour >= 7.0 and current_hour < 18.0:
		new_phase = GameEnums.DayPhase.DAY
	elif current_hour >= 18.0 and current_hour < 21.0:
		new_phase = GameEnums.DayPhase.DUSK
	else:
		new_phase = GameEnums.DayPhase.NIGHT

	if new_phase != current_phase or force_emit:
		current_phase = new_phase
		GameEvents.day_phase_changed.emit(current_phase)
