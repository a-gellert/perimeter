class_name SleeperMutant
extends CharacterBody3D
## Photophobic mutant: dormant during daytime, aggressive hunter at night.

@export var max_health: float = 60.0
@export var speed: float = 3.8
@export var attack_damage: float = 16.0
@export var attack_range: float = 1.8
@export var eye_mesh: MeshInstance3D

var health: float = 60.0
var is_dormant: bool = true
var target_player: CharacterBody3D
var attack_cooldown: float = 0.0

func _ready() -> void:
	health = max_health
	GameEvents.day_phase_changed.connect(_on_phase_changed)
	_update_dormancy(GameEnums.DayPhase.DAY)
	_try_connect_player_noise()

func _try_connect_player_noise() -> void:
	if not target_player and get_tree().current_scene:
		target_player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if target_player and target_player.has_signal("noise_emitted"):
		if not target_player.noise_emitted.is_connected(_on_noise_emitted):
			target_player.noise_emitted.connect(_on_noise_emitted)

func _on_noise_emitted(world_pos: Vector3, radius: float) -> void:
	if not is_dormant:
		return
	if global_position.distance_to(world_pos) <= radius:
		is_dormant = false
		_set_eyes_glowing(true)

func _physics_process(delta: float) -> void:
	if not target_player:
		_try_connect_player_noise()
	if is_dormant:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	
	if not target_player:
		target_player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D

	if target_player:
		var diff := target_player.global_position - global_position
		var dist := diff.length()
		
		# Look at player
		if dist > 0.2:
			var look_target := Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z)
			look_at(look_target, Vector3.UP)

		if dist <= attack_range:
			velocity.x = 0.0
			velocity.z = 0.0
			if attack_cooldown <= 0.0:
				_attack()
		else:
			var dir := diff.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed

	move_and_slide()

func _attack() -> void:
	attack_cooldown = 1.5
	if target_player:
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
		elif target_player.get("stats") and target_player.stats.has_method("take_damage"):
			target_player.stats.take_damage(attack_damage)
	
	# Visual lunge punch
	var tween := create_tween()
	tween.tween_property(self, "position", position + -transform.basis.z * 0.4, 0.1)
	tween.tween_property(self, "position", position, 0.15)

func take_damage(amount: float) -> void:
	health -= amount
	# Flash red
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12)
	
	# Wake up if hit even during daytime
	if is_dormant:
		is_dormant = false
		_set_eyes_glowing(true)

	if health <= 0.0:
		_die()

func _die() -> void:
	queue_free()

func _on_phase_changed(phase: int) -> void:
	_update_dormancy(phase)

func _update_dormancy(phase: int) -> void:
	var was_dormant := is_dormant
	is_dormant = (phase == GameEnums.DayPhase.DAY or phase == GameEnums.DayPhase.DAWN)
	_set_eyes_glowing(not is_dormant)

func _set_eyes_glowing(active: bool) -> void:
	if eye_mesh and eye_mesh.material_override:
		var mat := eye_mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = active
