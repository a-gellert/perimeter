class_name PlayerRifle
extends Node3D
## Warden's Hunting Rifle (ТОЗ-16).
## High-damage precision firearm for long-range defense against mutants.
## Consumes rifle ammo, alerts nearby sleepers with loud gunfire (45m radius),
## and features ADS (Aim Down Sights) zoom.

signal ammo_updated(current: int, reserve: int)
signal fired

@export var attack_ray: RayCast3D
@export var rifle_mesh: Node3D
@export var muzzle_flash: OmniLight3D
@export var damage: float = 85.0
@export var max_range: float = 50.0
@export var fire_rate: float = 0.8
@export var clip_capacity: int = 5

var current_ammo: int = 5
var can_fire: bool = true
var is_aiming: bool = false
var is_active: bool = false

var _orig_rifle_pos: Vector3 = Vector3.ZERO
var _orig_camera_fov: float = 75.0

func _ready() -> void:
	if rifle_mesh:
		_orig_rifle_pos = rifle_mesh.position
	if muzzle_flash:
		muzzle_flash.visible = false
	_emit_ammo_info()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and (inv.is_inventory_open or inv.is_crafting_open):
		return

	if event.is_action_pressed("primary_action") and can_fire:
		shoot()
	
	if event.is_action_pressed("secondary_action"):
		set_aiming(true)
	elif event.is_action_released("secondary_action"):
		set_aiming(false)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reload()

func shoot() -> void:
	if current_ammo <= 0:
		print("[Rifle] Click! Empty chamber. Press R to reload.")
		return

	can_fire = false
	current_ammo -= 1
	_emit_ammo_info()
	fired.emit()

	# 1. Звуковое оповещение экосистемы (громкий выстрел будит спящих в 45м)
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 45.0)
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx_3d"):
		audio.play_sfx_3d("gunshot", global_position)

	# 2. Вспышка выстрела
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.06).timeout.connect(func() -> void:
			if muzzle_flash:
				muzzle_flash.visible = false
		)

	# 3. Отдача
	if rifle_mesh:
		var tween := create_tween()
		var kick_pos := _orig_rifle_pos + Vector3(0, 0.04, 0.08)
		tween.tween_property(rifle_mesh, "position", kick_pos, 0.05)
		tween.tween_property(rifle_mesh, "position", _orig_rifle_pos, 0.22)

	# 4. Проверка попадания луча
	_raycast_damage()

	# 5. Кулдаун между выстрелами
	get_tree().create_timer(fire_rate).timeout.connect(func() -> void:
		can_fire = true
	)

func _raycast_damage() -> void:
	if not attack_ray:
		return

	# Увеличиваем дальность луча при стрельбе из ружья
	var orig_target := attack_ray.target_position
	attack_ray.target_position = Vector3(0, 0, -max_range)
	attack_ray.force_raycast_update()

	if attack_ray.is_colliding():
		var collider := attack_ray.get_collider()
		if collider:
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
				print("[Rifle] Hit enemy for ", damage, " damage!")
			elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
				collider.get_parent().take_damage(damage)
				print("[Rifle] Hit enemy parent for ", damage, " damage!")

	attack_ray.target_position = orig_target

func set_aiming(aim: bool) -> void:
	is_aiming = aim
	var camera := get_viewport().get_camera_3d()
	if camera:
		var target_fov := 48.0 if is_aiming else 75.0
		var tween := create_tween()
		tween.tween_property(camera, "fov", target_fov, 0.15)

func reload() -> void:
	var eco := get_node_or_null("/root/EconomyManager")
	var needed := clip_capacity - current_ammo
	if needed <= 0:
		return

	var available: int = 0
	if eco and eco.base_storage.has("ammo_rifle"):
		available = eco.base_storage["ammo_rifle"]

	if available <= 0:
		print("[Rifle] No rifle ammo in base warehouse!")
		return

	var to_load := mini(needed, available)
	current_ammo += to_load
	if eco:
		eco.base_storage["ammo_rifle"] -= to_load
		eco.resources_updated.emit()

	print("[Rifle] Loaded %d rounds. Magazine: %d/%d" % [to_load, current_ammo, clip_capacity])
	_emit_ammo_info()

func _emit_ammo_info() -> void:
	var eco := get_node_or_null("/root/EconomyManager")
	var reserve: int = 0
	if eco and eco.base_storage.has("ammo_rifle"):
		reserve = eco.base_storage["ammo_rifle"]
	ammo_updated.emit(current_ammo, reserve)
