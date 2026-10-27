class_name CampHeatEmitter
extends Node3D
## Periodically emits heat and smoke / food scent stimuli to attract mutants at night.
## Attach to cabin chimney, stove, or campfire.

@export var stimulus_type: String = "HEAT" # "HEAT" or "FOOD"
@export var emit_interval: float = 3.0
@export var is_burning: bool = true

var _timer: float = 0.0

func _ready() -> void:
	_timer = randf_range(0.5, emit_interval)

func _physics_process(delta: float) -> void:
	if not is_burning:
		return
	
	_timer -= delta
	if _timer <= 0.0:
		_timer = emit_interval
		if has_node("/root/ValleyEcology") and ValleyEcology.is_night:
			ValleyEcology.emit_camp_stimulus(global_position, stimulus_type)
