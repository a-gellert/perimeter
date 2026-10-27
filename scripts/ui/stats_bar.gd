class_name StatsBar
extends ProgressBar
## Smooth progress bar for player vitals.

@export var lerp_speed: float = 8.0
var target_val: float = 100.0

func _process(delta: float) -> void:
	value = lerpf(value, target_val, lerp_speed * delta)

func update_value(new_val: float, new_max: float = 100.0) -> void:
	max_value = new_max
	target_val = new_val
