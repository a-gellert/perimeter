class_name FallingTree
extends Node3D
## Dynamic falling tree spawned in the exact frame when a MultiMesh tree is chopped.
## Plays sway/creak animation, falls with physics away from player, and shatters into 2-3 logs + stump.

@export var sway_duration: float = 0.35
@export var fall_duration: float = 1.05
@export var log_scene: PackedScene
@export var stump_scene: PackedScene
@export var chips_scene: PackedScene
@export var logs_to_spawn: int = 3

var is_falling: bool = false
var fall_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	if not log_scene:
		log_scene = load("res://scenes/items/LogItem.tscn")
	if not stump_scene:
		stump_scene = load("res://scenes/environment/TreeStump.tscn")
	if not chips_scene:
		chips_scene = load("res://scenes/vfx/WoodChipsVFX.tscn")

func setup(initial_transform: Transform3D, player_pos: Vector3) -> void:
	global_transform = initial_transform

	# Направление падения: строго в сторону от игрока
	var away := global_position - player_pos
	away.y = 0.0
	if away.length_squared() > 0.01:
		fall_direction = away.normalized()
	else:
		var rnd_angle := randf_range(0.0, TAU)
		fall_direction = Vector3(cos(rnd_angle), 0, sin(rnd_angle))

	_start_sway_and_fall()

func _start_sway_and_fall() -> void:
	# 1. Звук удара и спавн древесных щепок в месте сруба
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx_3d"):
		audio.play_sfx_3d("chop", global_position + Vector3(0, 1.2, 0))

	var eco: Node = get_node_or_null("/root/ValleyEcology")
	if eco and eco.has_method("emit_sound"):
		eco.emit_sound(global_position, 22.0)

	if chips_scene:
		var chips := chips_scene.instantiate() as CPUParticles3D
		if chips:
			add_child(chips)
			chips.global_position = global_position + Vector3(0, 1.2, 0)
			chips.emitting = true

	# Ось вращения, перпендикулярная направлению падения
	var fall_axis := Vector3(-fall_direction.z, 0, fall_direction.x).normalized()

	# 2. Анимация покачивания (ствол вздрагивает при ударе, отклоняется назад, затем кренится вперед)
	var tween := create_tween()
	var base_basis := global_transform.basis

	# Отдача назад при ударе топором
	tween.tween_method(func(angle: float) -> void:
		global_transform.basis = base_basis * Basis(fall_axis, -angle)
	, 0.0, deg_to_rad(3.0), sway_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Качок вперед и хруст древесины
	tween.tween_method(func(angle: float) -> void:
		global_transform.basis = base_basis * Basis(fall_axis, angle)
	, -deg_to_rad(3.0), deg_to_rad(4.5), sway_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# 3. Физическое падение ствола на землю с ускорением свободного падения (QUAD_IN)
	tween.tween_method(func(angle: float) -> void:
		global_transform.basis = base_basis * Basis(fall_axis, angle)
	, deg_to_rad(4.5), deg_to_rad(86.0), fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_callback(_on_crash)

func _on_crash() -> void:
	if is_falling:
		return
	is_falling = true

	var world := get_parent()
	if not world:
		world = get_tree().current_scene

	# Глухой грохот удара дерева о землю, слышимый мутантам в округе
	var eco: Node = get_node_or_null("/root/ValleyEcology")
	if eco and eco.has_method("emit_sound"):
		eco.emit_sound(global_position, 35.0)

	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx_3d"):
		audio.play_sfx_3d("chop", global_position)

	# Спавн пня на месте сруба
	if stump_scene and world:
		var stump := stump_scene.instantiate() as Node3D
		world.add_child(stump)
		stump.global_position = global_position
		stump.rotation.y = rotation.y

	# Разлом ствола на 2–3 физических бревна вдоль вектора падения
	if log_scene and world:
		var count: int = clampi(logs_to_spawn, 2, 3)
		for i in range(count):
			var log_inst := log_scene.instantiate() as Node3D
			log_inst.name = "LogItem"
			world.add_child(log_inst, true)
			var dist: float = 2.2 + float(i) * 2.0
			var jitter := Vector3(randf_range(-0.4, 0.4), 0.25, randf_range(-0.4, 0.4))
			log_inst.global_position = global_position + (fall_direction * dist) + jitter
			log_inst.rotation.y = randf_range(0.0, TAU)

	queue_free()
