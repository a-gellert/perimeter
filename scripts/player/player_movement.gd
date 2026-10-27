class_name PlayerMovement
extends Node
## Handles walking, running, jumping, and physical motion of CharacterBody3D.
## Decoupled from camera rotation and direct UI.

@export var walk_speed: float = 3.6
@export var sprint_speed: float = 6.4
@export var sprint_cost_per_sec: float = 14.0
@export var acceleration: float = 12.0
@export var jump_velocity: float = 4.2

var is_active: bool = true

func update_movement(
	body: CharacterBody3D,
	stats: PlayerStats,
	camera_basis: Basis,
	delta: float
) -> void:
	if not is_active:
		body.velocity.x = move_toward(body.velocity.x, 0.0, acceleration * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, acceleration * delta)
		body.move_and_slide()
		return

	# Apply gravity
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta

	# Read input direction relative to camera
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir := (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	move_dir.y = 0.0
	move_dir = move_dir.normalized()

	# Determine speed and sprint stamina cost
	var target_speed := walk_speed
	var wants_sprint := Input.is_action_pressed("sprint") and input_dir.length_squared() > 0.1
	
	if wants_sprint and stats and stats.consume_stamina(sprint_cost_per_sec * delta):
		target_speed = sprint_speed

	# Accelerate
	var target_vel := move_dir * target_speed
	body.velocity.x = move_toward(body.velocity.x, target_vel.x, acceleration * delta)
	body.velocity.z = move_toward(body.velocity.z, target_vel.z, acceleration * delta)

	# Jump
	if Input.is_action_just_pressed("jump") and body.is_on_floor():
		body.velocity.y = jump_velocity

	body.move_and_slide()
