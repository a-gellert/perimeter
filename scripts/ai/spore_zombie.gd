class_name SporeZombie
extends MutantBase
## "Споровый щелкун" (Spore Clicker) — Humanoid infected overwhelmed by Cordyceps.
## Blind, erratic stalker with high hearing sensitivity and devastating frenzy slashes.
## Emits echolocating clicks and an alert screech that summons nearby mutants.

@export var screech_cooldown_time: float = 8.0
var _screech_timer: float = 0.0
@onready var animator: MutantAnimator = get_node_or_null("MutantAnimator")

func _ready() -> void:
	max_health = 65.0
	patrol_speed = 2.4
	chase_speed = 6.8
	attack_damage = 22.0
	attack_cooldown_time = 0.85
	hearing_sensitivity = 2.2 # Extreme hearing (blind clicker)
	super._ready()

func _physics_process(dt: float) -> void:
	_screech_timer = maxf(0.0, _screech_timer - dt)
	super._physics_process(dt)

func _process_combat(dt: float) -> void:
	# Clicker Screech when first engaging target
	if _screech_timer <= 0.0 and current_target:
		_perform_clicker_screech()

	super._process_combat(dt)

func _perform_clicker_screech() -> void:
	_screech_timer = screech_cooldown_time
	# Emit high radius acoustic sound across the valley to alert other mutants
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 35.0)

	# Audio feedback
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx_3d"):
		audio.play_sfx_3d("screech", global_position, 2.0)

	if animator:
		animator.play_attack_animation(0.4)

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
	_spawn_death_spores()
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		queue_free()
	)

func _spawn_death_spores() -> void:
	var spore_vfx := load("res://scenes/vfx/SporeFogVFX.tscn")
	if spore_vfx:
		var vfx: Node3D = spore_vfx.instantiate() as Node3D
		if vfx:
			get_parent().add_child(vfx)
			vfx.global_position = global_position + Vector3(0, 0.5, 0)
