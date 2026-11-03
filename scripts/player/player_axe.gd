class_name PlayerAxe
extends Node3D
## Handles the Warden's taiga axe for woodchopping and mutant defense.

@export var attack_ray: RayCast3D
@export var axe_mesh: Node3D
@export var stamina_cost: float = 6.0
@export var damage: float = 35.0

var is_swinging: bool = false
var is_active: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_swinging:
		return
	
	if event.is_action_pressed("primary_action"):
		var inv = get_node_or_null("/root/InventoryManager")
		if inv and (inv.is_inventory_open or inv.is_crafting_open):
			return
		swing_axe()

func swing_axe() -> void:
	is_swinging = true
	var player := owner as PlayerController
	if not player and get_parent():
		var p: Node = self
		while p.get_parent():
			p = p.get_parent()
			if p is PlayerController:
				player = p as PlayerController
				break

	if player:
		if player.has_method("consume_stamina"):
			player.consume_stamina(stamina_cost)
		elif player.stats and player.stats.has_method("consume_stamina"):
			player.stats.consume_stamina(stamina_cost)

	# Procedural swing animation
	if axe_mesh:
		var tween := create_tween()
		var orig_rot := axe_mesh.rotation
		tween.tween_property(axe_mesh, "rotation:x", orig_rot.x - 0.7, 0.08)
		tween.tween_property(axe_mesh, "rotation:x", orig_rot.x + 0.35, 0.08)
		tween.tween_callback(_check_hit)
		tween.tween_property(axe_mesh, "rotation", orig_rot, 0.15)
		tween.tween_callback(func() -> void: is_swinging = false)
	else:
		_check_hit()
		is_swinging = false

func _check_hit() -> void:
	if not attack_ray or not attack_ray.is_colliding():
		return

	var collider := attack_ray.get_collider()
	if not collider:
		return

	# Damage mutant or strike tree
	if has_node("/root/ValleyEcology"):
		ValleyEcology.emit_sound(global_position, 22.0)

	if collider.has_method("take_damage"):
		collider.take_damage(damage)
	elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
		collider.get_parent().take_damage(damage)
	elif collider is ChoppableTree:
		collider.interact(owner)
	else:
		for child in collider.get_children():
			if child is ChoppableTree:
				child.interact(owner)
				break
