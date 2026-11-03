class_name SkinnerMutant
extends MutantBase
## "Скорняк" (Skinner) — Mutated predatory taiga beast.
## Agile flanker with leap attack (pounce), high sprint speed (8.0 m/s),
## and opportunistic aggression towards unfortified gaps in perimeter walls.

@export var leap_distance: float = 7.0
@export var leap_damage: float = 28.0
@export var leap_cooldown_time: float = 3.5

var leap_cooldown: float = 0.0
var is_leaping: bool = false

func _ready() -> void:
	max_health = 55.0
	chase_speed = 7.8
	patrol_speed = 3.5
	attack_damage = 14.0
	attack_cooldown_time = 0.9
	hearing_sensitivity = 1.4
	super._ready()

func _physics_process(dt: float) -> void:
	leap_cooldown = maxf(0.0, leap_cooldown - dt)

	if is_leaping:
		move_and_slide()
		if is_on_floor():
			is_leaping = false
		return

	# Попытка прыжка с разбега на жертву
	if current_state == State.COMBAT and current_target and leap_cooldown <= 0.0:
		var dist := global_position.distance_to(current_target.global_position)
		if dist >= 3.5 and dist <= leap_distance and is_on_floor():
			_perform_leap()
			return

	super._physics_process(dt)

func _perform_leap() -> void:
	if not current_target:
		return
	is_leaping = true
	leap_cooldown = leap_cooldown_time

	var dir: Vector3 = (current_target.global_position - global_position).normalized()
	velocity.x = dir.x * 12.0
	velocity.z = dir.z * 12.0
	velocity.y = 5.5 # Высокая траектория прыжка

	# Звук рывка
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 18.0)

	# Таймер проверки урона в полете
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(current_target) and global_position.distance_to(current_target.global_position) < 2.5:
			if current_target.has_method("take_damage"):
				current_target.take_damage(leap_damage)
			elif current_target.get("stats") and current_target.stats.has_method("take_damage"):
				current_target.stats.take_damage(leap_damage)
			print("[Skinner] Pounced target for ", leap_damage, " damage!")
	)
