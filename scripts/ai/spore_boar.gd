class_name SporeBoar
extends MutantBase
## "Споровый вепрь" (Spore Boar) — Heavy armored tank with fungal carapace and charge ram attack.

@export var charge_damage: float = 38.0
@export var charge_cooldown_time: float = 6.0
@export var charge_speed: float = 14.0

var _charge_cooldown: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_duration: float = 0.0
@onready var animator: MutantAnimator = get_node_or_null("MutantAnimator")

func _ready() -> void:
	max_health = 135.0 # Tanky
	patrol_speed = 2.0
	chase_speed = 5.2
	attack_damage = 30.0
	attack_cooldown_time = 1.5
	hearing_sensitivity = 0.9
	super._ready()

func _physics_process(dt: float) -> void:
	_charge_cooldown = maxf(0.0, _charge_cooldown - dt)

	if _is_charging:
		_process_charge(dt)
		return

	# Trigger charge if within range
	if current_state == State.COMBAT and current_target and _charge_cooldown <= 0.0:
		var dist := global_position.distance_to(current_target.global_position)
		if dist >= 4.0 and dist <= 16.0 and is_on_floor():
			_start_charge()
			return

	super._physics_process(dt)

func _start_charge() -> void:
	if not current_target:
		return
	_is_charging = true
	_charge_cooldown = charge_cooldown_time
	_charge_duration = 1.4

	_charge_dir = (current_target.global_position - global_position)
	_charge_dir.y = 0.0
	_charge_dir = _charge_dir.normalized()

	look_at(global_position + _charge_dir, Vector3.UP)

	if animator:
		animator.play_attack_animation(1.2)

	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 28.0)

func _process_charge(dt: float) -> void:
	_charge_duration -= dt
	velocity.x = _charge_dir.x * charge_speed
	velocity.z = _charge_dir.z * charge_speed
	if not is_on_floor():
		velocity.y -= 18.0 * dt

	move_and_slide()

	# Check collision with player or buildings
	if current_target and is_instance_valid(current_target):
		if global_position.distance_to(current_target.global_position) < 2.2:
			if current_target.has_method("take_damage"):
				current_target.take_damage(charge_damage)
			_is_charging = false
			return

	if _charge_duration <= 0.0 or is_on_wall():
		_is_charging = false

func _attack_target() -> void:
	if animator:
		animator.play_attack_animation(attack_cooldown_time * 0.8)
	super._attack_target()

func take_damage(amount: float) -> void:
	# Armored fungal carapace absorbs 25% damage
	var effective_damage := amount * 0.75
	if animator:
		animator.play_hit_reaction()
	super.take_damage(effective_damage)

func _die_from_light() -> void:
	if animator:
		animator.play_death_animation()
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		queue_free()
	)
