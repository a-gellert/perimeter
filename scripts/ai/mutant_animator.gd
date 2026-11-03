class_name MutantAnimator
extends Node
## Procedural & State-Driven Animation Controller for Polygon Spore Mutants.
## Handles dynamic walking bob/sway, idle breathing, attack lunges, flinching, and death.

@export var model_root: Node3D
@export var base_bob_height: float = 0.08
@export var stride_frequency: float = 8.5
@export var roll_sway_amount: float = 0.08

var _parent_mutant: CharacterBody3D
var _original_pos: Vector3 = Vector3.ZERO
var _original_rot: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _is_attacking: bool = false
var _is_dead: bool = false
var _time_alive: float = 0.0

# Limb references if found
var _head: Node3D
var _jaw: Node3D
var _tail: Node3D
var _arm_l: Node3D
var _arm_r: Node3D

func _ready() -> void:
	_parent_mutant = get_parent() as CharacterBody3D
	if not model_root and _parent_mutant:
		model_root = _parent_mutant.get_node_or_null("Model") as Node3D
		if not model_root:
			model_root = _parent_mutant.get_node_or_null("VisualModel") as Node3D

	if model_root:
		_original_pos = model_root.position
		_original_rot = model_root.rotation
		_cache_limb_nodes(model_root)

func _cache_limb_nodes(root: Node) -> void:
	for child in root.get_children():
		var cname := child.name.to_lower()
		if "head" in cname and not _head:
			_head = child as Node3D
		elif "jaw" in cname and not _jaw:
			_jaw = child as Node3D
		elif "tail" in cname and not _tail:
			_tail = child as Node3D
		elif ("arm_l" in cname or "upperarm_l" in cname) and not _arm_l:
			_arm_l = child as Node3D
		elif ("arm_r" in cname or "upperarm_r" in cname) and not _arm_r:
			_arm_r = child as Node3D
		_cache_limb_nodes(child)

func _process(delta: float) -> void:
	if not model_root or _is_dead:
		return

	_time_alive += delta

	if _is_attacking:
		return

	var horizontal_vel := Vector2.ZERO
	if _parent_mutant:
		horizontal_vel = Vector2(_parent_mutant.velocity.x, _parent_mutant.velocity.z)

	var speed := horizontal_vel.length()

	if speed > 0.2:
		_animate_walk(speed, delta)
	else:
		_animate_idle(delta)

func _animate_idle(delta: float) -> void:
	# Breathing cycle
	var breath := sin(_time_alive * 2.2)
	model_root.position.y = _original_pos.y + breath * 0.02
	model_root.rotation.x = _original_rot.x + breath * 0.015

	# Subtle spore quiver
	var quiver := sin(_time_alive * 12.0) * 0.005
	model_root.position.x = _original_pos.x + quiver

	# Jaw twitch
	if _jaw:
		_jaw.rotation.x = sin(_time_alive * 3.5) * 0.08
	# Tail slow sway
	if _tail:
		_tail.rotation.y = sin(_time_alive * 1.8) * 0.12

func _animate_walk(speed: float, delta: float) -> void:
	var freq := stride_frequency * (speed / 5.0)
	_walk_phase += freq * delta

	# Stride bobbing (bounce)
	var bounce := absf(sin(_walk_phase)) * base_bob_height
	model_root.position.y = _original_pos.y + bounce

	# Body roll and yaw sway
	var roll := sin(_walk_phase) * roll_sway_amount
	model_root.rotation.z = _original_rot.z + roll
	model_root.rotation.y = _original_rot.y + sin(_walk_phase * 0.5) * (roll_sway_amount * 0.5)

	# Limbs swing
	if _arm_l and _arm_r:
		_arm_l.rotation.x = sin(_walk_phase) * 0.45
		_arm_r.rotation.x = -sin(_walk_phase) * 0.45

	if _head:
		_head.rotation.x = -bounce * 0.8

	if _tail:
		_tail.rotation.y = sin(_walk_phase) * 0.25

func play_attack_animation(duration: float = 0.55) -> void:
	if not model_root or _is_dead:
		return
	_is_attacking = true

	var tw := create_tween()
	# 1. Windup (pull back & open jaw)
	tw.tween_property(model_root, "position:z", _original_pos.z + 0.25, duration * 0.3).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(model_root, "rotation:x", _original_rot.x - 0.25, duration * 0.3)
	if _jaw:
		tw.parallel().tween_property(_jaw, "rotation:x", 0.45, duration * 0.3)

	# 2. Strike (lunge forward & bite/slash)
	tw.tween_property(model_root, "position:z", _original_pos.z - 0.55, duration * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model_root, "rotation:x", _original_rot.x + 0.35, duration * 0.25)
	if _jaw:
		tw.parallel().tween_property(_jaw, "rotation:x", -0.15, duration * 0.25)

	# 3. Recovery
	tw.tween_property(model_root, "position", _original_pos, duration * 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(model_root, "rotation", _original_rot, duration * 0.45)
	if _jaw:
		tw.parallel().tween_property(_jaw, "rotation:x", 0.0, duration * 0.45)

	tw.finished.connect(func() -> void:
		_is_attacking = false
	)

func play_hit_reaction() -> void:
	if not model_root or _is_dead:
		return

	var tw := create_tween()
	tw.tween_property(model_root, "position:z", _original_pos.z + 0.18, 0.08)
	tw.parallel().tween_property(model_root, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	tw.tween_property(model_root, "position", _original_pos, 0.14)
	tw.parallel().tween_property(model_root, "scale", Vector3.ONE, 0.14)

func play_death_animation() -> void:
	if not model_root:
		return
	_is_dead = true

	var tw := create_tween()
	tw.tween_property(model_root, "rotation:x", math_deg_to_rad(-80.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model_root, "position:y", 0.15, 0.35)
	tw.parallel().tween_property(model_root, "rotation:z", math_deg_to_rad(randf_range(-25.0, 25.0)), 0.35)

func math_deg_to_rad(deg: float) -> float:
	return deg * (PI / 180.0)
