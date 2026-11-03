class_name SporeWolf
extends MutantBase
## "Споровый волк" (Spore Wolf) — Fast pack hunter with leap pounce and spore bursts.

@export var leap_distance: float = 7.5
@export var leap_damage: float = 24.0
@export var leap_cooldown_time: float = 3.8

var _leap_cooldown: float = 0.0
var _is_leaping: bool = false
@onready var animator: MutantAnimator = get_node_or_null("MutantAnimator")

func _ready() -> void:
	max_health = 52.0
	patrol_speed = 3.6
	chase_speed = 8.5 # Very agile predator
	attack_damage = 18.0
	attack_cooldown_time = 0.8
	hearing_sensitivity = 1.6
	super._ready()

func _physics_process(dt: float) -> void:
	_leap_cooldown = maxf(0.0, _leap_cooldown - dt)

	if _is_leaping:
		move_and_slide()
		if is_on_floor():
			_is_leaping = false
		return

	# Pounce leap check in combat
	if current_state == State.COMBAT and current_target and _leap_cooldown <= 0.0:
		var dist := global_position.distance_to(current_target.global_position)
		if dist >= 3.2 and dist <= leap_distance and is_on_floor():
			_perform_leap()
			return

	super._physics_process(dt)

func _perform_leap() -> void:
	if not current_target:
		return
	_is_leaping = true
	_leap_cooldown = leap_cooldown_time

	if animator:
		animator.play_attack_animation(0.7)

	var dir: Vector3 = (current_target.global_position - global_position).normalized()
	velocity.x = dir.x * 13.0
	velocity.z = dir.z * 13.0
	velocity.y = 5.2

	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 16.0)

	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(current_target) and global_position.distance_to(current_target.global_position) < 2.2:
			if current_target.has_method("take_damage"):
				current_target.take_damage(leap_damage)
	)

func _attack_target() -> void:
	if animator:
		animator.play_attack_animation(attack_cooldown_time * 0.8)
	super._attack_target()

func take_damage(amount: float) -> void:
	if animator:
		animator.play_hit_reaction()
	super.take_damage(amount)

func _die_from_light() -> void:
	if animator:
		animator.play_death_animation()
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		queue_free()
	)
