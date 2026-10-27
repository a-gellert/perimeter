class_name CameraTransition
extends Node
## Manages smooth 0.6s interpolation between FPV and Architect viewpoints.

@export var duration: float = 0.6
var _tween: Tween

func interpolate_transform(camera: Camera3D, target_transform: Transform3D, on_complete: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	_tween.tween_property(camera, "global_position", target_transform.origin, duration)
	
	# Smooth quaternion rotation interpolation
	var start_rot := camera.global_transform.basis.get_rotation_quaternion()
	var target_rot := target_transform.basis.get_rotation_quaternion()
	
	_tween.tween_method(
		func(weight: float) -> void:
			camera.global_transform.basis = Basis(start_rot.slerp(target_rot, weight)),
		0.0,
		1.0,
		duration
	)
	
	_tween.chain().tween_callback(on_complete)
