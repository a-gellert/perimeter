class_name BearTrap
extends Area3D
## Steel Wolf Trap crafted from metal scrap.
## Snaps onto trespassing mutants, dealing severe crush damage (65 HP)
## and rooting them in place for 3.5 seconds.

signal triggered(victim: Node3D)

@export var damage: float = 65.0
@export var root_duration: float = 3.5
@export var is_armed: bool = true

@export var open_jaws_mesh: Node3D
@export var closed_jaws_mesh: Node3D
@export var snap_collision: CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _on_body_entered(body: Node3D) -> void:
	if not is_armed:
		return

	if body is CharacterBody3D and (body.is_in_group("enemies") or body is MutantBase):
		snap_trap(body)

func snap_trap(victim: CharacterBody3D) -> void:
	is_armed = false
	_update_visuals()

	# Громкий лязг капкана
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 15.0)
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx_3d"):
		audio.play_sfx_3d("trap_snap", global_position)

	# Нанесение урона
	if victim.has_method("take_damage"):
		victim.take_damage(damage)
	elif victim.get("stats") and victim.stats.has_method("take_damage"):
		victim.stats.take_damage(damage)

	# Обездвиживание мутанта на root_duration
	if victim is MutantBase:
		victim.velocity = Vector3.ZERO
		var orig_speed: float = victim.speed
		victim.speed = 0.0
		get_tree().create_timer(root_duration).timeout.connect(func() -> void:
			if is_instance_valid(victim):
				victim.speed = orig_speed
		)

	triggered.emit(victim)
	print("[BearTrap] SNAP! Trapped %s for %.1fs, dealt %.0f damage." % [victim.name, root_duration, damage])

func rearm() -> void:
	is_armed = true
	_update_visuals()

func _update_visuals() -> void:
	if open_jaws_mesh:
		open_jaws_mesh.visible = is_armed
	if closed_jaws_mesh:
		closed_jaws_mesh.visible = not is_armed
