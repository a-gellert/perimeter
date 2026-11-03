class_name PlayerWeaponManager
extends Node3D
## Manages active equipped weapon (Axe vs Hunting Rifle) in the player's hands.
## Handles slot switching (keys 1 and 2, or scroll wheel) and weapon visibility.

signal weapon_switched(weapon_name: String, slot_idx: int)

@export var axe_node: PlayerAxe
@export var rifle_node: PlayerRifle

var current_slot: int = 1 # 1: Axe, 2: Rifle

func _ready() -> void:
	if not axe_node:
		axe_node = get_node_or_null("PlayerAxe") as PlayerAxe
	if not rifle_node:
		rifle_node = get_node_or_null("PlayerRifle") as PlayerRifle

	equip_slot(1)

func _unhandled_input(event: InputEvent) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and (inv.is_inventory_open or inv.is_crafting_open):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			equip_slot(1)
		elif event.keycode == KEY_2:
			equip_slot(2)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			equip_slot(1 if current_slot == 2 else 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			equip_slot(2 if current_slot == 1 else 1)

func equip_slot(slot: int) -> void:
	current_slot = slot

	if axe_node:
		var axe_active := (slot == 1)
		axe_node.visible = axe_active
		axe_node.is_active = axe_active

	if rifle_node:
		var rifle_active := (slot == 2)
		rifle_node.visible = rifle_active
		rifle_node.is_active = rifle_active

	var weapon_name := "Топор Егеря" if slot == 1 else "Охотничий Карабин ТОЗ-16"
	weapon_switched.emit(weapon_name, slot)
	print("[WeaponManager] Equipped: ", weapon_name)
