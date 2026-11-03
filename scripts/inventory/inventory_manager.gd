extends Node
## Central manager for player inventory, Warband-style equipment, and 5-slot quick access hotbar.
## Autoload: registered as 'InventoryManager' in Project Settings.

signal inventory_updated
signal equipment_updated
signal hotbar_updated
signal active_hotbar_changed(slot_idx: int)
signal notification_message(msg: String, is_warning: bool)
signal heavy_object_spawned(item_id: String, world_pos: Vector3)

# --- ВМЕСТИМОСТЬ И РЮКЗАК ---
@export var backpack_name: String = "Базовый вещмешок"
@export var backpack_capacity: int = 15 # Начальная вместимость (Tier 1)

# Массив слотов рюкзака: каждый элемент { "item_id": String, "count": int } или null
var backpack_slots: Array = []

# --- СЛОТЫ ЭКИПИРОВКИ (WARBAND STYLE) ---
# 4 слота под любое оружие/боеприпасы (лук, арбалет, винтовка, топор, нож, стрелы...)
# Шлем (противогаз), Одежда (полный комплект), Обувь (берцы)
var equipment: Dictionary = {
	"weapon_1": null,
	"weapon_2": null,
	"weapon_3": null,
	"weapon_4": null,
	"head": null,
	"body": null,
	"feet": null
}

# --- ПАНЕЛЬ БЫСТРОГО ДОСТУПА (ХОТБАР - 5 ПРЕДМЕТОВ) ---
const HOTBAR_SIZE: int = 5
# Хранит привязки: { "item_id": String, "slot_type": "backpack" | "weapon", "index": int } или null
var hotbar_slots: Array = []
var active_hotbar_index: int = 0

var is_inventory_open: bool = false
var is_crafting_open: bool = false

func _init() -> void:
	_init_slots()

func _ready() -> void:
	if backpack_slots.is_empty():
		_init_slots()
	_give_starter_gear()

func _init_slots() -> void:
	backpack_slots.clear()
	for i in range(backpack_capacity):
		backpack_slots.append(null)

	hotbar_slots.clear()
	for i in range(HOTBAR_SIZE):
		hotbar_slots.append(null)

func _give_starter_gear() -> void:
	# Стартовая экипировка в стиле Mount & Blade:
	# Оружие 1: Топор
	equipment["weapon_1"] = { "item_id": "axe", "count": 1 }
	# Оружие 2: Карабин
	equipment["weapon_2"] = { "item_id": "rifle", "count": 1 }
	# Обувь: Берцы
	equipment["feet"] = { "item_id": "boots", "count": 1 }
	# Одежда: Штормовой комплект
	equipment["body"] = { "item_id": "jacket", "count": 1 }

	# Стартовые ресурсы в рюкзаке для проверки:
	add_item("berries", 3)
	add_item("branches", 4)
	add_item("rags", 3)
	add_item("scrap", 3)
	add_item("circuit", 1)
	add_item("ammo_rifle", 5)

	# Привязка первых слотов хотбара:
	hotbar_slots[0] = { "item_id": "axe", "equip_slot": "weapon_1" }
	hotbar_slots[1] = { "item_id": "rifle", "equip_slot": "weapon_2" }
	hotbar_slots[2] = { "item_id": "berries", "backpack_idx": 0 }

	emit_signal("inventory_updated")
	emit_signal("equipment_updated")
	emit_signal("hotbar_updated")

# ==============================================================================
# 1. ДОБАВЛЕНИЕ И ПРОВЕРКА ПРЕДМЕТОВ (С ОГРАНИЧЕНИЯМИ ПО ТЗ)
# ==============================================================================

## Проверка: можно ли положить предмет в рюкзак.
## По ТЗ: "в инвентарь можно положить всё кроме бревен. разделить на стеки по 5 элементов одного типа."
func can_add_item(item_id: String, count: int = 1) -> bool:
	var item = ItemDatabase.get_item(item_id)
	if not item:
		return false

	# 1. Исключение бревен
	if item.is_log or item_id == "log":
		notify("Бревно нельзя положить в рюкзак! Переносите его на плече.", true)
		return false

	# 2. Непереносимые (тяжелые) объекты (турели, мебель)
	if not item.is_portable:
		notify("Объект '%s' слишком громоздкий для рюкзака!" % item.display_name, true)
		return false

	var remaining: int = count
	var max_stack: int = item.max_stack

	# Проверяем существующие неполные стеки
	for slot in backpack_slots:
		if slot != null and slot["item_id"] == item_id:
			var space: int = max_stack - int(slot["count"])
			remaining -= max(0, space)
			if remaining <= 0:
				return true

	# Проверяем пустые слоты
	var free_slots: int = 0
	for slot in backpack_slots:
		if slot == null:
			free_slots += 1

	return (free_slots * max_stack) >= remaining

## Добавляет предмет в рюкзак стеками по max_stack (по умолчанию 5).
## Возвращает остаток, который не влез (0 если всё успешно добавлено).
func add_item(item_id: String, count: int = 1) -> int:
	var item = ItemDatabase.get_item(item_id)
	if not item:
		return count

	# Ограничение по бревнам
	if item.is_log or item_id == "log":
		notify("Бревно нельзя положить в рюкзак! Несите на плече.", true)
		return count

	# Ограничение по тяжелым объектам
	if not item.is_portable:
		notify("Тяжелый объект '%s' не влезает в рюкзак!" % item.display_name, true)
		return count

	var remaining: int = count
	var max_stk: int = item.max_stack

	# 1. Заполняем существующие неполные стеки того же предмета
	for i in range(backpack_slots.size()):
		var slot = backpack_slots[i]
		if slot != null and slot["item_id"] == item_id:
			var cur_count: int = int(slot["count"])
			if cur_count < max_stk:
				var to_add: int = mini(remaining, max_stk - cur_count)
				slot["count"] = cur_count + to_add
				remaining -= to_add
				if remaining <= 0:
					break

	# 2. Оставшееся раскладываем в новые свободные ячейки стеками по max_stk
	if remaining > 0:
		for i in range(backpack_slots.size()):
			if backpack_slots[i] == null:
				var to_add: int = mini(remaining, max_stk)
				backpack_slots[i] = { "item_id": item_id, "count": to_add }
				remaining -= to_add
				if remaining <= 0:
					break

	if remaining < count:
		emit_signal("inventory_updated")
		_refresh_hotbar_sync()

	if remaining > 0:
		notify("Рюкзак полон! Часть предметов не поместилась (%d шт.)." % remaining, true)

	return remaining

## Удаляет указанное количество предмета из рюкзака (полезно для крафта)
func remove_item(item_id: String, count: int = 1) -> bool:
	if get_item_count(item_id) < count:
		return false

	var remaining: int = count
	for i in range(backpack_slots.size() - 1, -1, -1):
		var slot = backpack_slots[i]
		if slot != null and slot["item_id"] == item_id:
			var cur_cnt: int = int(slot["count"])
			if cur_cnt <= remaining:
				remaining -= cur_cnt
				backpack_slots[i] = null
			else:
				slot["count"] = cur_cnt - remaining
				remaining = 0
			if remaining <= 0:
				break

	emit_signal("inventory_updated")
	_refresh_hotbar_sync()
	return true

## Подсчет общего количества конкретного предмета в рюкзаке
func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in backpack_slots:
		if slot != null and slot["item_id"] == item_id:
			total += int(slot["count"])
	return total

## Возвращает словарь { item_id: total_count } всех предметов в рюкзаке
func get_all_inventory_counts() -> Dictionary:
	var dict: Dictionary = {}
	for slot in backpack_slots:
		if slot != null:
			var id: String = slot["item_id"]
			dict[id] = dict.get(id, 0) + int(slot["count"])
	return dict

# ==============================================================================
# 2. ЭКИПИРОВКА В СТИЛЕ MOUNT & BLADE: WARBAND
# ==============================================================================

## Экипирует предмет из слота рюкзака в слот экипировки
func equip_item_from_backpack(backpack_idx: int, target_slot: String = "") -> bool:
	if backpack_idx < 0 or backpack_idx >= backpack_slots.size():
		return false
	var slot_data = backpack_slots[backpack_idx]
	if slot_data == null:
		return false

	var item = ItemDatabase.get_item(slot_data["item_id"])
	if not item:
		return false

	# Определяем подходящий слот экипировки
	var equip_key: String = target_slot
	if equip_key.is_empty():
		match item.equip_slot_type:
			ItemData.EquipSlotType.WEAPON:
				# Ищем первый свободный оружейный слот из 4, либо заменяем weapon_1
				equip_key = "weapon_1"
				for w_key in ["weapon_1", "weapon_2", "weapon_3", "weapon_4"]:
					if equipment[w_key] == null:
						equip_key = w_key
						break
			ItemData.EquipSlotType.HEAD:
				equip_key = "head"
			ItemData.EquipSlotType.BODY:
				equip_key = "body"
			ItemData.EquipSlotType.FEET:
				equip_key = "feet"
			_:
				# Если это улучшение рюкзака - применяем
				if item.category == ItemData.ItemCategory.BACKPACK:
					return apply_backpack_upgrade(item, backpack_idx)
				# Если это расходуемый предмет (ягоды) - используем
				if item.category == ItemData.ItemCategory.CONSUMABLE:
					return use_consumable(backpack_idx)
				notify("Этот предмет нельзя экипировать!", true)
				return false

	# Проверяем допустимость типа слота
	if equip_key.begins_with("weapon_") and item.equip_slot_type != ItemData.EquipSlotType.WEAPON:
		notify("В этот слот можно поместить только оружие или боеприпасы!", true)
		return false
	if equip_key == "head" and item.equip_slot_type != ItemData.EquipSlotType.HEAD:
		notify("В этот слот можно надеть только шлем или защиту головы!", true)
		return false
	if equip_key == "body" and item.equip_slot_type != ItemData.EquipSlotType.BODY:
		notify("В этот слот можно надеть только комплект одежды!", true)
		return false
	if equip_key == "feet" and item.equip_slot_type != ItemData.EquipSlotType.FEET:
		notify("В этот слот можно надеть только обувь!", true)
		return false

	# Свап предмета из экипировки и рюкзака
	var prev_equipped = equipment[equip_key]
	equipment[equip_key] = slot_data
	backpack_slots[backpack_idx] = prev_equipped

	emit_signal("equipment_updated")
	emit_signal("inventory_updated")
	_apply_equipment_bonuses()
	_sync_player_active_weapon()
	notify("Экипировано: %s" % item.display_name, false)
	return true

## Снять экипированный предмет обратно в рюкзак
func unequip_item(equip_key: String) -> bool:
	if not equipment.has(equip_key) or equipment[equip_key] == null:
		return false

	var slot_data = equipment[equip_key]
	var item = ItemDatabase.get_item(slot_data["item_id"])

	# Проверяем, есть ли место в рюкзаке
	var empty_idx: int = _find_first_empty_slot()
	if empty_idx == -1:
		notify("В рюкзаке нет свободного места, чтобы снять предмет!", true)
		return false

	equipment[equip_key] = null
	backpack_slots[empty_idx] = slot_data

	emit_signal("equipment_updated")
	emit_signal("inventory_updated")
	_apply_equipment_bonuses()
	_sync_player_active_weapon()
	notify("Снято: %s" % (item.display_name if item else "предмет"), false)
	return true

func _find_first_empty_slot() -> int:
	for i in range(backpack_slots.size()):
		if backpack_slots[i] == null:
			return i
	return -1

# ==============================================================================
# 3. УЛУЧШЕНИЕ РЮКЗАКА ("можно улучшить свой рюкзак или найти побольше")
# ==============================================================================

func apply_backpack_upgrade(item: ItemData, from_slot_idx: int = -1) -> bool:
	var new_cap: int = int(item.stats.get("capacity", backpack_capacity + 10))
	if new_cap <= backpack_capacity:
		notify("Текущий рюкзак уже вместительнее или равен этому!", true)
		return false

	upgrade_backpack(new_cap, item.display_name)
	if from_slot_idx >= 0 and from_slot_idx < backpack_slots.size():
		backpack_slots[from_slot_idx] = null
	emit_signal("inventory_updated")
	return true

func upgrade_backpack(new_capacity: int, new_name: String) -> void:
	if new_capacity <= backpack_capacity:
		return
	var diff: int = new_capacity - backpack_capacity
	backpack_capacity = new_capacity
	backpack_name = new_name
	for _i in range(diff):
		backpack_slots.append(null)
	notify("★ Рюкзак улучшен: %s! Слотов: %d" % [backpack_name, backpack_capacity], false)
	emit_signal("inventory_updated")

# ==============================================================================
# 4. ИСПОЛЬЗОВАНИЕ ПРЕДМЕТОВ И ХОТБАР
# ==============================================================================

func use_consumable(backpack_idx: int) -> bool:
	if backpack_idx < 0 or backpack_idx >= backpack_slots.size():
		return false
	var slot_data = backpack_slots[backpack_idx]
	if slot_data == null:
		return false

	var item = ItemDatabase.get_item(slot_data["item_id"])
	if not item:
		return false

	var player = _get_player()
	if item.id == "berries":
		if player and player.has_method("restore_stamina"):
			player.restore_stamina(10.0)
			if "hunger" in player:
				player.hunger = minf(100.0, player.hunger + 15.0)
				player.emit_signal("stats_changed", player.hp, player.stamina, player.fatigue, player.hunger)
		notify("Съедены ягоды: +15 сытости, +10 сил.", false)
		slot_data["count"] = int(slot_data["count"]) - 1
		if int(slot_data["count"]) <= 0:
			backpack_slots[backpack_idx] = null
		emit_signal("inventory_updated")
		_refresh_hotbar_sync()
		return true

	elif item.id == "lantern":
		notify("Кемпинговый фонарь включен / переключен.", false)
		return true

	return false

## Выбор активного слота хотбара по клавишам 1..5 или клику
func select_hotbar_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= HOTBAR_SIZE:
		return
	active_hotbar_index = slot_idx
	emit_signal("active_hotbar_changed", active_hotbar_index)

	var slot = hotbar_slots[slot_idx]
	if slot == null:
		return

	# Если это оружейный слот
	if slot.has("equip_slot"):
		var eq_key: String = slot["equip_slot"]
		var eq_data = equipment.get(eq_key, null)
		if eq_data:
			_equip_weapon_in_hands(eq_data["item_id"])
	elif slot.has("backpack_idx"):
		var b_idx: int = slot["backpack_idx"]
		use_consumable(b_idx)
	elif slot.has("item_id"):
		# Ищем в рюкзаке и используем
		var b_idx: int = _find_item_slot_idx(slot["item_id"])
		if b_idx != -1:
			use_consumable(b_idx)

func _find_item_slot_idx(item_id: String) -> int:
	for i in range(backpack_slots.size()):
		if backpack_slots[i] != null and backpack_slots[i]["item_id"] == item_id:
			return i
	return -1

func assign_hotbar_slot(hotbar_idx: int, binding: Dictionary) -> void:
	if hotbar_idx >= 0 and hotbar_idx < HOTBAR_SIZE:
		hotbar_slots[hotbar_idx] = binding
		emit_signal("hotbar_updated")

func _refresh_hotbar_sync() -> void:
	# Проверяем актуальность предметов на хотбаре
	emit_signal("hotbar_updated")

# ==============================================================================
# 5. ВЫБРАСЫВАНИЕ ПРЕДМЕТА В МИР (СПАВН 3D ЛУТА)
# ==============================================================================

func drop_item(backpack_idx: int, count: int = -1) -> bool:
	if backpack_idx < 0 or backpack_idx >= backpack_slots.size():
		return false
	var slot_data = backpack_slots[backpack_idx]
	if slot_data == null:
		return false

	var drop_count: int = slot_data["count"] if count <= 0 else mini(count, int(slot_data["count"]))
	var item_id: String = slot_data["item_id"]

	slot_data["count"] = int(slot_data["count"]) - drop_count
	if int(slot_data["count"]) <= 0:
		backpack_slots[backpack_idx] = null

	var player = _get_player()
	var drop_pos: Vector3 = Vector3.ZERO
	if player:
		drop_pos = player.global_position + (-player.global_transform.basis.z * 1.5) + Vector3.UP * 0.3

	_spawn_world_loot(item_id, drop_count, drop_pos)
	emit_signal("inventory_updated")
	_refresh_hotbar_sync()
	notify("Выброшено: %s (%d шт.)" % [ItemDatabase.get_item(item_id).display_name, drop_count], false)
	return true

func _spawn_world_loot(item_id: String, count: int, pos: Vector3) -> void:
	var loot_scn = load("res://scenes/items/LootPickup.tscn")
	if loot_scn:
		var pickup = loot_scn.instantiate()
		pickup.item_id = item_id
		pickup.count = count
		pickup.position = pos
		var target_parent: Node = null
		if is_inside_tree() and get_tree():
			target_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
		if target_parent:
			target_parent.add_child(pickup)

# ==============================================================================
# 6. КРАФТ НА ВЕРСТАКЕ (ПЕРЕНОСИМЫЕ vs НЕПЕРЕНОСИМЫЕ)
# ==============================================================================

## Создание предмета по рецепту.
## Если is_portable == true: добавляется в рюкзак.
## Если is_portable == false: спавнится в 3D мире рядом с верстаком (спавн-точка).
func craft_recipe(recipe: CraftingRecipe, workbench_spawn_pos: Vector3 = Vector3.ZERO) -> bool:
	if not recipe:
		return false

	# Проверяем наличие всех ингредиентов
	var inv_counts: Dictionary = get_all_inventory_counts()
	if not recipe.can_craft(inv_counts):
		notify("Недостаточно материалов для создания!", true)
		return false

	# Если предмет переносимый — проверяем, есть ли место в инвентаре
	if recipe.is_portable:
		if not can_add_item(recipe.output_item_id, recipe.output_count):
			notify("В инвентаре недостаточно места для создаваемого предмета!", true)
			return false

	# Списываем ингредиенты
	for mat_id in recipe.ingredients:
		var req_cnt: int = int(recipe.ingredients[mat_id])
		remove_item(mat_id, req_cnt)

	# Выдаем результат
	if recipe.is_portable:
		add_item(recipe.output_item_id, recipe.output_count)
		var item = ItemDatabase.get_item(recipe.output_item_id)
		notify("★ Создано: %s (%d шт.)! Добавлено в рюкзак." % [
			item.display_name if item else recipe.display_name,
			recipe.output_count
		], false)
	else:
		# НЕПЕРЕНОСИМЫЙ объект (турель, стул, стол, мебель)
		# Спавним рядом с верстаком в физическом мире!
		_spawn_heavy_crafted_object(recipe, workbench_spawn_pos)

	emit_signal("inventory_updated")
	return true

func _spawn_heavy_crafted_object(recipe: CraftingRecipe, spawn_pos: Vector3) -> void:
	var item = ItemDatabase.get_item(recipe.output_item_id)
	var spawn_scene_path: String = recipe.world_scene_path
	if spawn_scene_path.is_empty():
		spawn_scene_path = "res://scenes/crafting/PlacedObject.tscn"

	var scn = load(spawn_scene_path)
	if scn:
		var inst = scn.instantiate()
		inst.position = spawn_pos
		if inst.has_method("setup_object"):
			inst.setup_object(recipe.output_item_id)
		var target_parent: Node = null
		if is_inside_tree() and get_tree():
			target_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
		if target_parent:
			target_parent.add_child(inst)

	emit_signal("heavy_object_spawned", recipe.output_item_id, spawn_pos)
	notify("★ Создан крупный объект: %s! Установлен рядом с верстаком." % recipe.display_name, false)

# ==============================================================================
# 7. ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ==============================================================================

func notify(msg: String, is_warning: bool = false) -> void:
	emit_signal("notification_message", msg, is_warning)
	print("[Inventory] ", msg)

func _apply_equipment_bonuses() -> void:
	# Пересчитываем защиту и бонусы обуви/одежды/шлема
	var player = _get_player()
	if not player:
		return
	var boots_data = equipment.get("feet", null)
	if boots_data != null and boots_data.get("item_id") == "boots":
		player.walk_speed = 4.6
		player.sprint_speed = 7.2
	else:
		player.walk_speed = 4.0
		player.sprint_speed = 6.5

func _sync_player_active_weapon() -> void:
	var w1 = equipment.get("weapon_1", null)
	if w1:
		_equip_weapon_in_hands(w1["item_id"])

func _equip_weapon_in_hands(weapon_id: String) -> void:
	var player = _get_player()
	if not player:
		return
	var wm = player.find_child("HandSlot", true, false)
	if wm and wm.has_method("equip_slot"):
		if weapon_id in ["axe", "knife"]:
			wm.equip_slot(1)
		elif weapon_id in ["rifle", "bow", "crossbow", "pistol"]:
			wm.equip_slot(2)

func _get_player() -> Node:
	if is_inside_tree() and get_tree():
		return get_tree().get_first_node_in_group("player")
	return null
