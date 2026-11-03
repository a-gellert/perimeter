class_name InventoryUI
extends Control
## Mount & Blade: Warband style inventory and equipment interface.
## Toggled by 'Q' key or UI button.
## Left: Backpack items with stack limit of 5 and upgradable capacity.
## Right: 4 Weapon slots, Helmet/Gasmask, Body outfit, Boots, and Character Stats.

@export var backpack_grid: GridContainer
@export var backpack_title_label: Label
@export var detail_title: Label
@export var detail_desc: Label
@export var detail_stats: Label
@export var equip_btn: Button
@export var drop_btn: Button
@export var hotbar_assign_btn: Button

# Экипировочные слоты (Warband)
@export var slot_head: Button
@export var slot_body: Button
@export var slot_feet: Button
@export var slot_weapon_1: Button
@export var slot_weapon_2: Button
@export var slot_weapon_3: Button
@export var slot_weapon_4: Button

# Статы персонажа
@export var stats_summary_label: Label

var selected_backpack_idx: int = -1
var selected_equip_slot: String = ""
var _current_camera_mode: int = 0 # GameEnums.CameraMode.FPV
var _is_mobile: bool = false
var close_btn: Button

func _ready() -> void:
	visible = false
	add_to_group("inventory_ui")

	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.ui_mode_changed.connect(_on_ui_mode_changed)

	if not backpack_grid:
		backpack_grid = find_child("BackpackGrid", true, false) as GridContainer
	if not backpack_title_label:
		backpack_title_label = find_child("BackpackTitleLabel", true, false) as Label
	if not detail_title:
		detail_title = find_child("DetailTitle", true, false) as Label
	if not detail_desc:
		detail_desc = find_child("DetailDesc", true, false) as Label
	if not detail_stats:
		detail_stats = find_child("DetailStats", true, false) as Label
	if not equip_btn:
		equip_btn = find_child("EquipButton", true, false) as Button
	if not drop_btn:
		drop_btn = find_child("DropButton", true, false) as Button
	if not hotbar_assign_btn:
		hotbar_assign_btn = find_child("HotbarAssignButton", true, false) as Button

	if not slot_head: slot_head = find_child("SlotHead", true, false) as Button
	if not slot_body: slot_body = find_child("SlotBody", true, false) as Button
	if not slot_feet: slot_feet = find_child("SlotFeet", true, false) as Button
	if not slot_weapon_1: slot_weapon_1 = find_child("SlotWeapon1", true, false) as Button
	if not slot_weapon_2: slot_weapon_2 = find_child("SlotWeapon2", true, false) as Button
	if not slot_weapon_3: slot_weapon_3 = find_child("SlotWeapon3", true, false) as Button
	if not slot_weapon_4: slot_weapon_4 = find_child("SlotWeapon4", true, false) as Button
	if not stats_summary_label: stats_summary_label = find_child("StatsSummaryLabel", true, false) as Label

	_setup_buttons()
	_connect_manager()

	var sm = get_node_or_null("/root/SettingsManager")
	var initial_mobile: bool = sm.is_mobile_ui() if sm and sm.has_method("is_mobile_ui") else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_on_ui_mode_changed(initial_mobile)

func _on_ui_mode_changed(is_mobile: bool) -> void:
	_is_mobile = is_mobile
	if close_btn:
		close_btn.text = "✕ ЗАКРЫТЬ" if _is_mobile else "✕ Закрыть инвентарь [ Q / Esc ]"
		close_btn.custom_minimum_size = Vector2(0, 50) if _is_mobile else Vector2(0, 44)
	if equip_btn:
		equip_btn.custom_minimum_size = Vector2(0, 48) if _is_mobile else Vector2(0, 36)
	if drop_btn:
		drop_btn.custom_minimum_size = Vector2(0, 48) if _is_mobile else Vector2(0, 36)
	if hotbar_assign_btn:
		hotbar_assign_btn.custom_minimum_size = Vector2(0, 48) if _is_mobile else Vector2(0, 36)
	var equip_slots: Array[Button] = [slot_head, slot_body, slot_feet, slot_weapon_1, slot_weapon_2, slot_weapon_3, slot_weapon_4]
	for es in equip_slots:
		if is_instance_valid(es):
			es.custom_minimum_size = Vector2(0, 48) if _is_mobile else Vector2(0, 40)
	if visible:
		refresh_ui()

func _setup_buttons() -> void:
	if equip_btn: equip_btn.pressed.connect(_on_equip_pressed)
	if drop_btn: drop_btn.pressed.connect(_on_drop_pressed)
	if hotbar_assign_btn: hotbar_assign_btn.pressed.connect(_on_hotbar_assign_pressed)

	close_btn = find_child("CloseButton", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(close_inventory)

	# Кнопки слотов экипировки (клик снимает предмет обратно в рюкзак)
	if slot_head: slot_head.pressed.connect(func(): _on_equip_slot_clicked("head"))
	if slot_body: slot_body.pressed.connect(func(): _on_equip_slot_clicked("body"))
	if slot_feet: slot_feet.pressed.connect(func(): _on_equip_slot_clicked("feet"))
	if slot_weapon_1: slot_weapon_1.pressed.connect(func(): _on_equip_slot_clicked("weapon_1"))
	if slot_weapon_2: slot_weapon_2.pressed.connect(func(): _on_equip_slot_clicked("weapon_2"))
	if slot_weapon_3: slot_weapon_3.pressed.connect(func(): _on_equip_slot_clicked("weapon_3"))
	if slot_weapon_4: slot_weapon_4.pressed.connect(func(): _on_equip_slot_clicked("weapon_4"))

func _connect_manager() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.inventory_updated.connect(refresh_ui)
		inv.equipment_updated.connect(refresh_ui)

func _on_camera_mode_changed(mode: int) -> void:
	_current_camera_mode = mode
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		close_inventory()

func _unhandled_input(event: InputEvent) -> void:
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		return
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		return
	if visible:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		return
	visible = true
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.is_inventory_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_ui()

func close_inventory() -> void:
	visible = false
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.is_inventory_open = false
	if _current_camera_mode == GameEnums.CameraMode.ARCHITECT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not (inv and inv.is_crafting_open):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_ui() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if not inv:
		return

	# 1. Заголовок рюкзака
	var used_slots := 0
	for s in inv.backpack_slots:
		if s != null:
			used_slots += 1
	if backpack_title_label:
		backpack_title_label.text = "%s (%d / %d ячеек)" % [
			inv.backpack_name,
			used_slots,
			inv.backpack_capacity
		]

	# 2. Сетка предметов рюкзака
	_rebuild_backpack_grid(inv)

	# 3. Слоты экипировки (Warband)
	_update_equip_slot_button(slot_head, "head", inv.equipment.get("head"))
	_update_equip_slot_button(slot_body, "body", inv.equipment.get("body"))
	_update_equip_slot_button(slot_feet, "feet", inv.equipment.get("feet"))
	_update_equip_slot_button(slot_weapon_1, "weapon_1", inv.equipment.get("weapon_1"))
	_update_equip_slot_button(slot_weapon_2, "weapon_2", inv.equipment.get("weapon_2"))
	_update_equip_slot_button(slot_weapon_3, "weapon_3", inv.equipment.get("weapon_3"))
	_update_equip_slot_button(slot_weapon_4, "weapon_4", inv.equipment.get("weapon_4"))

	# 4. Сводка характеристик персонажа
	_update_stats_summary(inv)

	# 5. Панель деталей
	_update_detail_view(inv)

func _rebuild_backpack_grid(inv: Node) -> void:
	if not backpack_grid:
		return

	for c in backpack_grid.get_children():
		c.queue_free()

	for i in range(inv.backpack_slots.size()):
		var slot_data = inv.backpack_slots[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(74, 74) if _is_mobile else Vector2(64, 64)
		btn.focus_mode = Control.FOCUS_NONE

		if slot_data != null:
			var item = ItemDatabase.get_item(slot_data["item_id"])
			var count: int = int(slot_data["count"])
			var title: String = item.display_name if item else slot_data["item_id"]
			
			btn.text = "%s\n[x%d]" % [title.left(10), count]
			if _is_mobile:
				btn.tooltip_text = ""
			else:
				btn.tooltip_text = "%s (x%d / %d)\n%s" % [
					title,
					count,
					item.max_stack if item else 5,
					item.description if item else ""
				]
			if item:
				btn.modulate = item.icon_color.lerp(Color.WHITE, 0.4)
		else:
			btn.text = "—"
			btn.tooltip_text = ""
			btn.modulate = Color(0.4, 0.4, 0.4, 0.7)

		var slot_index := i
		btn.pressed.connect(func(): _on_backpack_slot_clicked(slot_index))
		backpack_grid.add_child(btn)

func _update_equip_slot_button(btn: Button, slot_type: String, slot_data) -> void:
	if not btn:
		return
	if slot_data != null:
		var item = ItemDatabase.get_item(slot_data["item_id"])
		var item_name: String = item.display_name if item else slot_data["item_id"]
		var count_str := ""
		if int(slot_data.get("count", 1)) > 1:
			count_str = " (x%d)" % int(slot_data["count"])
		btn.text = "%s%s" % [item_name, count_str]
		btn.modulate = item.icon_color.lerp(Color.WHITE, 0.5) if item else Color.WHITE
		if _is_mobile:
			btn.tooltip_text = ""
		else:
			btn.tooltip_text = "%s\nНажмите, чтобы снять обратно в рюкзак." % item_name
	else:
		if _is_mobile:
			match slot_type:
				"head": btn.text = "[ Шлем / Защита ]"
				"body": btn.text = "[ Одежда ]"
				"feet": btn.text = "[ Обувь ]"
				"weapon_1": btn.text = "[ Оружие 1 ]"
				"weapon_2": btn.text = "[ Оружие 2 ]"
				"weapon_3": btn.text = "[ Слот 3 / Стрелы ]"
				"weapon_4": btn.text = "[ Слот 4 / Болты ]"
			btn.tooltip_text = ""
		else:
			match slot_type:
				"head": btn.text = "[ Пусто: Шлем/Противогаз ]"
				"body": btn.text = "[ Пусто: Комплект одежды ]"
				"feet": btn.text = "[ Пусто: Обувь ]"
				"weapon_1": btn.text = "[ Слот 1: Основное оружие ]"
				"weapon_2": btn.text = "[ Слот 2: Второе оружие / Лук ]"
				"weapon_3": btn.text = "[ Слот 3: Оружие / Стрелы ]"
				"weapon_4": btn.text = "[ Слот 4: Оружие / Болты ]"
			btn.tooltip_text = "Слот экипировки пуст."
		btn.modulate = Color(0.5, 0.5, 0.5, 0.6)

func _update_stats_summary(inv: Node) -> void:
	if not stats_summary_label:
		return

	var total_armor := 0
	var spore_res := 0
	var speed_bonus := 0.0

	var head = inv.equipment.get("head")
	if head:
		var it = ItemDatabase.get_item(head["item_id"])
		if it:
			total_armor += int(it.stats.get("head_armor", 0))
			spore_res += int(it.stats.get("spore_resistance", 0))

	var body = inv.equipment.get("body")
	if body:
		var it = ItemDatabase.get_item(body["item_id"])
		if it:
			total_armor += int(it.stats.get("body_armor", 0))

	var feet = inv.equipment.get("feet")
	if feet:
		var it = ItemDatabase.get_item(feet["item_id"])
		if it:
			total_armor += int(it.stats.get("feet_armor", 0))
			speed_bonus += float(it.stats.get("speed_bonus", 0.0))

	stats_summary_label.text = "Броня: +%d | Сопротивление спорам: %d%% | Бонус скорости: +%d%%" % [
		total_armor,
		spore_res,
		int(speed_bonus * 100.0)
	]

func _on_backpack_slot_clicked(idx: int) -> void:
	selected_backpack_idx = idx
	selected_equip_slot = ""
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		_update_detail_view(inv)

func _on_equip_slot_clicked(equip_key: String) -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if not inv:
		return

	selected_equip_slot = equip_key
	selected_backpack_idx = -1

	# Если в слоте что-то есть — снимаем в рюкзак
	if inv.equipment.get(equip_key) != null:
		inv.unequip_item(equip_key)
	else:
		inv.notify("Слот пуст. Выберите подходящий предмет в рюкзаке слева.", false)

func _update_detail_view(inv: Node) -> void:
	if selected_backpack_idx >= 0 and selected_backpack_idx < inv.backpack_slots.size():
		var slot_data = inv.backpack_slots[selected_backpack_idx]
		if slot_data != null:
			var item = ItemDatabase.get_item(slot_data["item_id"])
			if item:
				if detail_title: detail_title.text = item.display_name
				if detail_desc: detail_desc.text = item.description
				if detail_stats:
					var st := "Стек: %d / %d единиц\n" % [int(slot_data["count"]), item.max_stack]
					for k in item.stats:
						st += "%s: %s\n" % [k, str(item.stats[k])]
					detail_stats.text = st

				if equip_btn:
					equip_btn.visible = true
					match item.category:
						ItemData.ItemCategory.WEAPON, ItemData.ItemCategory.AMMO:
							equip_btn.text = "В ОРУЖЕЙНЫЙ СЛОТ" if _is_mobile else "Экипировать в оружейный слот"
						ItemData.ItemCategory.ARMOR_HEAD, ItemData.ItemCategory.ARMOR_BODY, ItemData.ItemCategory.ARMOR_FEET:
							equip_btn.text = "НАДЕТЬ" if _is_mobile else "Надеть снаряжение"
						ItemData.ItemCategory.CONSUMABLE:
							equip_btn.text = "ИСПОЛЬЗОВАТЬ" if _is_mobile else "Съесть / Использовать"
						ItemData.ItemCategory.BACKPACK:
							equip_btn.text = "УЛУЧШИТЬ РЮКЗАК" if _is_mobile else "Улучшить рюкзак"
						_:
							equip_btn.visible = false

				if drop_btn:
					drop_btn.visible = true
					drop_btn.text = "ВЫБРОСИТЬ (1)" if _is_mobile else "Выбросить (1 шт)"
				if hotbar_assign_btn:
					hotbar_assign_btn.visible = true
					hotbar_assign_btn.text = "В БЫСТРЫЙ ДОСТУП" if _is_mobile else "На панель [1-5]"
				return

	# Пустой или не выбранный
	if detail_title: detail_title.text = "Выберите предмет"
	if detail_desc: detail_desc.text = "Нажмите на ячейку в рюкзаке или экипировке."
	if detail_stats: detail_stats.text = ""
	if equip_btn: equip_btn.visible = false
	if drop_btn: drop_btn.visible = false
	if hotbar_assign_btn: hotbar_assign_btn.visible = false

func _on_equip_pressed() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv and selected_backpack_idx >= 0:
		inv.equip_item_from_backpack(selected_backpack_idx)

func _on_drop_pressed() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv and selected_backpack_idx >= 0:
		inv.drop_item(selected_backpack_idx, 1)

func _on_hotbar_assign_pressed() -> void:
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if not inv or selected_backpack_idx < 0:
		return
	var slot_data = inv.backpack_slots[selected_backpack_idx]
	if slot_data == null:
		return

	# Находим свободный слот хотбара или привязываем к первому свободному
	for i in range(inv.HOTBAR_SIZE):
		if inv.hotbar_slots[i] == null:
			inv.assign_hotbar_slot(i, { "item_id": slot_data["item_id"], "backpack_idx": selected_backpack_idx })
			inv.notify("Предмет добавлен на панель быстрого доступа [%d]." % (i + 1), false)
			return

	# Иначе заменяем активный
	var cur_idx: int = inv.active_hotbar_index
	inv.assign_hotbar_slot(cur_idx, { "item_id": slot_data["item_id"], "backpack_idx": selected_backpack_idx })
	inv.notify("Предмет помещен в слот [%d] быстрого доступа." % (cur_idx + 1), false)
