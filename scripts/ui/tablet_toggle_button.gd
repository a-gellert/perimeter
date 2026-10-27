class_name TabletToggleButton
extends Button
## Button for switching between FPV and Top-Down tablet view (touch/mobile friendly).

var _current_mode: int = GameEnums.CameraMode.FPV

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)

func _on_pressed() -> void:
	var next_mode := GameEnums.CameraMode.ARCHITECT if _current_mode == GameEnums.CameraMode.FPV else GameEnums.CameraMode.FPV
	GameEvents.request_mode_switch.emit(next_mode)

func _on_camera_mode_changed(mode: int) -> void:
	_current_mode = mode
	text = "Выйти из планшета" if mode == GameEnums.CameraMode.ARCHITECT else "Планшет егеря"
