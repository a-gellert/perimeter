class_name GeoTitanBoss
extends MutantBase
## "Гео-Титан" (Geo-Titan) — Night 5 Blood Eclipse Siege Boss.
## Massive amalgamation of bio-mass and heavy tectonic mining machinery.
## Systematically rams perimeter palisades and fortified gates.
## Stuns itself upon impacting heavy walls, creating vulnerability windows.

signal boss_defeated

@export var ram_damage: float = 140.0
@export var ground_slam_damage: float = 45.0
@export var charge_cooldown_time: float = 6.0

var is_charging: bool = false
var is_stunned: bool = false
var charge_cooldown: float = 2.0
var _charge_dir: Vector3 = Vector3.ZERO
var _enraged: bool = false

func _ready() -> void:
	max_health = 850.0
	health = max_health
	patrol_speed = 1.8
	chase_speed = 3.2
	attack_damage = 38.0
	attack_cooldown_time = 1.8
	scale = Vector3(1.6, 1.6, 1.6)
	add_to_group("boss_mutants")
	super._ready()

func _physics_process(dt: float) -> void:
	if is_stunned:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	charge_cooldown = maxf(0.0, charge_cooldown - dt)

	# Фаза ярости при HP < 50%
	if health < max_health * 0.5 and not _enraged:
		_enraged = true
		chase_speed = 4.5
		charge_cooldown_time = 4.0
		print("[GeoTitan] ENRAGED! Speed and aggression increased!")

	# Таранная атака
	if is_charging:
		velocity.x = _charge_dir.x * 10.5
		velocity.z = _charge_dir.z * 10.5
		if not is_on_floor():
			velocity.y -= 18.0 * dt
		move_and_slide()

		# Проверка столкновения со стенами или воротами во время тарана
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider:
				_handle_ram_impact(collider)
				break
		return

	# Инициация тарана при наличии цели на прямой линии
	if current_state == State.COMBAT and charge_cooldown <= 0.0:
		var target := _find_priority_siege_target()
		if target:
			var dist := global_position.distance_to(target.global_position)
			if dist >= 6.0 and dist <= 28.0:
				_start_charge(target.global_position)
				return

	super._physics_process(dt)

func _find_priority_siege_target() -> Node3D:
	# Приоритет: сначала ворота, затем стены, затем игрок
	var gates := get_tree().get_nodes_in_group("gates")
	for g in gates:
		if g is Node3D and is_instance_valid(g) and global_position.distance_to(g.global_position) < 30.0:
			return g
	var blueprints := get_tree().current_scene.get_node_or_null("PerimeterBlueprints")
	if blueprints:
		for wall in blueprints.get_children():
			if wall is Node3D and is_instance_valid(wall) and global_position.distance_to(wall.global_position) < 25.0:
				return wall
	return current_target

func _start_charge(target_pos: Vector3) -> void:
	is_charging = true
	charge_cooldown = charge_cooldown_time
	_charge_dir = (target_pos - global_position).normalized()
	_charge_dir.y = 0.0

	# Грозный рев босса перед тараном
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 55.0)

	# Автоматическое завершение тарана через 2.5 сек, если никуда не врезался
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_charging:
			is_charging = false
	)

func _handle_ram_impact(collider: Object) -> void:
	is_charging = false
	print("[GeoTitan] RAMMED into ", collider)

	# Нанесение урона структуре
	if collider.has_method("take_damage"):
		collider.take_damage(ram_damage)
	elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
		collider.get_parent().take_damage(ram_damage)

	# Оглушение босса после удара о прочную преграду
	is_stunned = true
	if body_mesh:
		var tw := create_tween()
		tw.tween_property(body_mesh, "rotation:z", deg_to_rad(15.0), 0.1)
		tw.tween_property(body_mesh, "rotation:z", 0.0, 0.2)

	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		is_stunned = false
		print("[GeoTitan] Recovered from stun.")
	)

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if health <= 0.0:
		_on_boss_death()

func _on_boss_death() -> void:
	print("[GeoTitan] DEFEATED! Dropping rare spore glands and amber.")
	var eco := get_node_or_null("/root/EconomyManager")
	if eco:
		eco.base_storage["raw_spores"] = eco.base_storage.get("raw_spores", 0) + 4
		eco.base_storage["amber"] = eco.base_storage.get("amber", 0) + 2
		eco.resources_updated.emit()

	boss_defeated.emit()
	var bus := get_node_or_null("/root/GameEvents")
	if bus and bus.has_signal("structure_completed"):
		pass
