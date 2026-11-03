class_name ItemDatabase
extends RefCounted
## Centralized registry for all items in the game.
## To add a new item, simply add an entry to the `_catalog` dictionary!

static var _items: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_all()

static func get_item(id: String) -> ItemData:
	_ensure_initialized()
	if _items.has(id):
		return _items[id]
	push_warning("[ItemDatabase] Item not found: '%s'" % id)
	return null

static func has_item(id: String) -> bool:
	_ensure_initialized()
	return _items.has(id)

static func get_all_items() -> Array:
	_ensure_initialized()
	return _items.values()

static func register_item(item: ItemData) -> void:
	_items[item.id] = item

static func _create_item(
	id: String,
	name: String,
	desc: String,
	cat: ItemData.ItemCategory,
	equip_slot: ItemData.EquipSlotType = ItemData.EquipSlotType.NONE,
	max_stack: int = 5,
	is_portable: bool = true,
	is_log: bool = false,
	model_path: String = "",
	color: Color = Color.WHITE,
	stats: Dictionary = {}
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = name
	item.description = desc
	item.category = cat
	item.equip_slot_type = equip_slot
	item.max_stack = max_stack
	item.is_portable = is_portable
	item.is_log = is_log
	item.model_path = model_path
	item.icon_color = color
	item.stats = stats
	return item

static func _register_all() -> void:
	# =========================================================================
	# 1. СБОР ЛУТА И РЕСУРСЫ (Loot & Resources)
	# =========================================================================
	register_item(_create_item(
		"berries", "Лесные ягоды",
		"Спелые таежные ягоды. Восстанавливают сытость (+15) и немного сил (+10).",
		ItemData.ItemCategory.CONSUMABLE,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/BlueberryBush.fbx",
		Color(0.2, 0.5, 0.95),
		{"hunger": 15.0, "stamina": 10.0}
	))

	register_item(_create_item(
		"branches", "Сухие ветки",
		"Прочные сосновые ветви. Базовый материал для стрел, луков, факелов и верстака.",
		ItemData.ItemCategory.RESOURCE,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Branch001.fbx",
		Color(0.65, 0.45, 0.25)
	))

	register_item(_create_item(
		"rags", "Тряпки (из города)",
		"Обрывки прочной ткани, найденные в заброшенных строениях. Идут на перевязку и одежду.",
		ItemData.ItemCategory.RESOURCE,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Bandage.fbx",
		Color(0.85, 0.85, 0.8)
	))

	register_item(_create_item(
		"scrap", "Металлолом",
		"Ржавые куски стали, скобы и прутья. Необходимы для создания наконечников, ножей и механизмов.",
		ItemData.ItemCategory.RESOURCE,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Hammer.fbx",
		Color(0.5, 0.55, 0.6)
	))

	register_item(_create_item(
		"circuit", "Электронная плата",
		"Уцелевшая микросхема из промышленной аппаратуры. Ценнейший компонент для турелей и фонарей.",
		ItemData.ItemCategory.RESOURCE,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Radio.fbx",
		Color(0.2, 0.8, 0.4)
	))

	# Особый ресурс: бревна (The Forest механика). В инвентарь НЕ кладутся!
	register_item(_create_item(
		"log", "Сосновое бревно",
		"Тяжелое бревно для частокола и бараков. Слишком крупное для рюкзака — переносится на плече!",
		ItemData.ItemCategory.HEAVY_OBJECT,
		ItemData.EquipSlotType.NONE,
		1, false, true, # is_portable = false, is_log = true!
		"res://assets/just_survive/FBX/ChopedWood.fbx",
		Color(0.6, 0.4, 0.2)
	))

	# =========================================================================
	# 2. ОРУЖИЕ (Weapons - Warband-стиль: подходят в любой из 4 слотов)
	# =========================================================================
	register_item(_create_item(
		"knife", "Охотничий нож",
		"Острый нож из закаленной стали. Быстрые взмахи и снятие шкур.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/Knife.fbx",
		Color(0.8, 0.8, 0.85),
		{"damage": 20.0, "speed": 1.4}
	))

	register_item(_create_item(
		"axe", "Топор лесоруба",
		"Тяжелый топор. Эффективно валит деревья и крушит мутантов в ближнем бою.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/FireAxe.fbx",
		Color(0.9, 0.3, 0.2),
		{"damage": 35.0, "chop_power": 1.0}
	))

	register_item(_create_item(
		"bow", "Самодельный лук",
		"Гибкий лук из таежного ясеня. Бесшумное оружие охоты на дальних дистанциях.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/RecurveBow.fbx",
		Color(0.7, 0.5, 0.3),
		{"damage": 45.0, "range": 35.0, "ammo_type": "arrow"}
	))

	register_item(_create_item(
		"crossbow", "Тяжелый арбалет",
		"Стальной арбалет со спусковым механизмом. Огромная пробивная сила и точность.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/RecurveBow.fbx",
		Color(0.6, 0.6, 0.7),
		{"damage": 75.0, "range": 50.0, "ammo_type": "bolt"}
	))

	register_item(_create_item(
		"rifle", "Карабин ТОЗ-16",
		"Охотничий нарезной карабин калибра .308. Смертоносен для самых опасных тварей.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/HuntingRifle.fbx",
		Color(0.4, 0.35, 0.3),
		{"damage": 120.0, "range": 80.0, "ammo_type": "ammo_rifle"}
	))

	register_item(_create_item(
		"pistol", "Пистолет 9мм",
		"Надежный полуавтоматический пистолет. Удобное запасное оружие.",
		ItemData.ItemCategory.WEAPON,
		ItemData.EquipSlotType.WEAPON,
		1, true, false,
		"res://assets/just_survive/FBX/Clock9mm.fbx",
		Color(0.25, 0.25, 0.28),
		{"damage": 38.0, "range": 25.0, "ammo_type": "ammo_9mm"}
	))

	# =========================================================================
	# 3. БОЕПРИПАСЫ (Ammo - можно снаряжать в оружейные слоты как колчаны в Warband)
	# =========================================================================
	register_item(_create_item(
		"arrow", "Стрелы",
		"Оперенные стрелы с каменным или металлическим наконечником. Стек по 5 шт.",
		ItemData.ItemCategory.AMMO,
		ItemData.EquipSlotType.WEAPON, # В Warband стрелы/болты ставятся в слот оружия
		5, true, false,
		"res://assets/just_survive/FBX/Arrow.fbx",
		Color(0.6, 0.5, 0.35)
	))

	register_item(_create_item(
		"bolt", "Арбалетные болты",
		"Короткие стальные болты для арбалета. Высокая пробиваемость. Стек по 5 шт.",
		ItemData.ItemCategory.AMMO,
		ItemData.EquipSlotType.WEAPON,
		5, true, false,
		"res://assets/just_survive/FBX/Arrow.fbx",
		Color(0.7, 0.7, 0.75)
	))

	register_item(_create_item(
		"ammo_rifle", "Патроны .308 Win",
		"Мощные винтовочные патроны. Стек по 5 шт.",
		ItemData.ItemCategory.AMMO,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Ammo.308.fbx",
		Color(0.9, 0.75, 0.2)
	))

	register_item(_create_item(
		"ammo_9mm", "Патроны 9x19mm",
		"Пистолетные патроны стандартного калибра. Стек по 5 шт.",
		ItemData.ItemCategory.AMMO,
		ItemData.EquipSlotType.NONE,
		5, true, false,
		"res://assets/just_survive/FBX/Ammo9mm.fbx",
		Color(0.85, 0.7, 0.25)
	))

	# =========================================================================
	# 4. БРОНЯ И ЭКИПИРОВКА (Armor: Шлем, Одежда, Обувь)
	# =========================================================================
	register_item(_create_item(
		"gasmask", "Противогаз ГП-7",
		"Надежный гражданский противогаз с фильтрующей коробкой. Защищает легкие от спор периметра.",
		ItemData.ItemCategory.ARMOR_HEAD,
		ItemData.EquipSlotType.HEAD,
		1, true, false,
		"",
		Color(0.3, 0.35, 0.3),
		{"head_armor": 15, "spore_resistance": 50}
	))

	register_item(_create_item(
		"helmet_tactical", "Тактический шлем",
		"Кевларовый шлем с защитным забралом. Снижает урон от прямых атак мутантов.",
		ItemData.ItemCategory.ARMOR_HEAD,
		ItemData.EquipSlotType.HEAD,
		1, true, false,
		"",
		Color(0.35, 0.4, 0.35),
		{"head_armor": 30, "spore_resistance": 10}
	))

	register_item(_create_item(
		"jacket", "Штормовой комплект егеря",
		"Полный комплект плотной одежды: водонепроницаемая куртка и усиленные штаны.",
		ItemData.ItemCategory.ARMOR_BODY,
		ItemData.EquipSlotType.BODY,
		1, true, false,
		"",
		Color(0.3, 0.4, 0.25),
		{"body_armor": 35, "cold_resistance": 40}
	))

	register_item(_create_item(
		"boots", "Армейские берцы",
		"Прочные кожаные ботинки с высоким берцем. Увеличивают скорость бега и защищают ноги.",
		ItemData.ItemCategory.ARMOR_FEET,
		ItemData.EquipSlotType.FEET,
		1, true, false,
		"res://assets/just_survive/FBX/Boots.fbx",
		Color(0.2, 0.2, 0.2),
		{"feet_armor": 20, "speed_bonus": 0.15}
	))

	# =========================================================================
	# 5. УЛУЧШЕНИЯ РЮКЗАКА (Backpack upgrades)
	# =========================================================================
	register_item(_create_item(
		"backpack_tier1", "Базовый вещмешок",
		"Стандартный компактный вещмешок егеря на 15 слотов.",
		ItemData.ItemCategory.BACKPACK,
		ItemData.EquipSlotType.NONE,
		1, true, false,
		"res://assets/just_survive/FBX/Backpack.fbx",
		Color(0.5, 0.45, 0.35),
		{"capacity": 15}
	))

	register_item(_create_item(
		"backpack_tier2", "Охотничий рюкзак (T2)",
		"Вместительный охотничий рюкзак с боковыми карманами на 25 слотов.",
		ItemData.ItemCategory.BACKPACK,
		ItemData.EquipSlotType.NONE,
		1, true, false,
		"res://assets/just_survive/FBX/Backpack.fbx",
		Color(0.35, 0.5, 0.3),
		{"capacity": 25}
	))

	register_item(_create_item(
		"backpack_tier3", "Тактический рейдовый рюкзак (T3)",
		"Огромный военный рюкзак с молле-стропами на 35 слотов.",
		ItemData.ItemCategory.BACKPACK,
		ItemData.EquipSlotType.NONE,
		1, true, false,
		"res://assets/just_survive/FBX/Backpack2.fbx",
		Color(0.2, 0.25, 0.2),
		{"capacity": 35}
	))

	# =========================================================================
	# 6. ПЕРЕНОСИМЫЕ ПРИБОРЫ И НЕПЕРЕНОСИМЫЕ ОБЪЕКТЫ (Craftable Heavy & Lights)
	# =========================================================================
	register_item(_create_item(
		"lantern", "Кемпинговый фонарь",
		"Яркий переносной фонарь. Освещает территорию и отпугивает тварей.",
		ItemData.ItemCategory.CONSUMABLE,
		ItemData.EquipSlotType.NONE,
		1, true, false,
		"res://assets/just_survive/FBX/Torch.fbx",
		Color(1.0, 0.85, 0.3),
		{"light_range": 12.0}
	))

	# НЕПЕРЕНОСИМЫЕ (тяжелые) объекты — спавнятся рядом с верстаком:
	register_item(_create_item(
		"turret", "Автономная турель",
		"Стационарная автоматическая турель для защиты периметра базы. Тяжелая — создается рядом с верстаком!",
		ItemData.ItemCategory.HEAVY_OBJECT,
		ItemData.EquipSlotType.NONE,
		1, false, false, # is_portable = false!
		"",
		Color(0.9, 0.2, 0.2),
		{"health": 200, "damage": 25, "range": 20}
	))

	register_item(_create_item(
		"furniture_chair", "Стул егеря",
		"Простой деревянный табурет для отдыха у печи. Мебель создается рядом с верстаком.",
		ItemData.ItemCategory.HEAVY_OBJECT,
		ItemData.EquipSlotType.NONE,
		1, false, false,
		"",
		Color(0.55, 0.38, 0.22)
	))

	register_item(_create_item(
		"furniture_table", "Стол из бревен",
		"Прочный рабочий стол для дома кордона. Мебель создается рядом с верстаком.",
		ItemData.ItemCategory.HEAVY_OBJECT,
		ItemData.EquipSlotType.NONE,
		1, false, false,
		"",
		Color(0.5, 0.35, 0.2)
	))

	register_item(_create_item(
		"furniture_bed", "Походная койка",
		"Деревянная кровать с соломенным тюфяком для отдыха колонистов.",
		ItemData.ItemCategory.HEAVY_OBJECT,
		ItemData.EquipSlotType.NONE,
		1, false, false,
		"res://assets/just_survive/FBX/MakeshiftBed.fbx",
		Color(0.45, 0.35, 0.25)
	))
