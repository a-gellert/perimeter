class_name HotbarUI
extends Control
## 5-Slot quick access bottom panel.
## Directly controlled via number keys 1-5 or mouse clicks.

@export var slot_buttons: Array[Button] = []
var _is_architect_mode: bool = false
var _is_mobile: bool = false

func _ready() -> void:
	add_to_group("hotbar_ui")
	_find_buttons()
	_connect_manager()
	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.ui_mode_changed.connect(_on_ui_mode_changed)

	var sm = get_node_or_null("/root/SettingsManager")
	var initial_mobile: bool = sm.is_mobile_ui() if sm and sm.has_method("is_mobile_ui") else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_on_ui_mode_changed(initial_mobile)
	refresh_hotbar()

func _on_ui_mode_changed(is_mobile: bool) -> void:
	_is_mobile = is_mobile
	for btn in slot_buttons:
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(84, 70) if _is_mobile else Vector2(74, 64)
	refresh_hotbar()

func _on_camera_mode_changed(mode: int) -> void:
	_is_architect_mode = (mode == GameEnums.CameraMode.ARCHITECT)
	visible = not _is_architect_mode

func _find_buttons() -> void:
	if slot_buttons.is_empty():
		for i in range(1, 6):
			var btn = find_child("Slot%d" % i, true, false) as Button
			if btn:
				slot_buttons.append(btn)

	for i in range(slot_buttons.size()):
		var idx := i
		if not slot_buttons[i].pressed.is_connected(_on_slot_pressed.bind(idx)):
			slot_buttons[i].pressed.connect(_on_slot_pressed.bind(idx))

func _connect_manager() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.hotbar_updated.connect(refresh_hotbar)
		inv.active_hotbar_changed.connect(_on_active_slot_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _is_architect_mode or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _trigger_slot(0)
			KEY_2: _trigger_slot(1)
			KEY_3: _trigger_slot(2)
			KEY_4: _trigger_slot(3)
			KEY_5: _trigger_slot(4)

func _trigger_slot(idx: int) -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.select_hotbar_slot(idx)

func _on_slot_pressed(idx: int) -> void:
	_trigger_slot(idx)

func _on_active_slot_changed(active_idx: int) -> void:
	for i in range(slot_buttons.size()):
		if i == active_idx:
			slot_buttons[i].modulate = Color(1.2, 1.2, 0.4, 1.0) # Golden highlight
		else:
			slot_buttons[i].modulate = Color(1.0, 1.0, 1.0, 1.0)

func refresh_hotbar() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if not inv:
		return

	for i in range(mini(slot_buttons.size(), inv.HOTBAR_SIZE)):
		var btn = slot_buttons[i]
		var data = inv.hotbar_slots[i]

		if data != null:
			var item_id: String = data.get("item_id", "")
			var item = ItemDatabase.get_item(item_id)
			var title: String = item.display_name if item else item_id
			
			var count_badge := ""
			if data.has("backpack_idx"):
				var b_idx: int = data["backpack_idx"]
				if b_idx < inv.backpack_slots.size() and inv.backpack_slots[b_idx] != null:
					count_badge = " x%d" % int(inv.backpack_slots[b_idx]["count"])
				else:
					# Попробуем найти в рюкзаке
					var total: int = inv.get_item_count(item_id)
					if total > 0: count_badge = " x%d" % total

			if _is_mobile:
				btn.text = "%s%s" % [title.left(8), count_badge]
				btn.tooltip_text = ""
			else:
				btn.text = "[%d]\n%s%s" % [i + 1, title.left(8), count_badge]
				btn.tooltip_text = "[%d] %s" % [i + 1, title]
		else:
			if _is_mobile:
				btn.text = "—"
				btn.tooltip_text = ""
			else:
				btn.text = "[%d]\n—" % (i + 1)
				btn.tooltip_text = "[%d] Пустой слот" % (i + 1)

	_on_active_slot_changed(inv.active_hotbar_index)
