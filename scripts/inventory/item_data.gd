class_name ItemData
extends Resource
## Data structure representing an item in the game.
## Supports loot gathering, Mount & Blade style equipment slots, and crafting portability.

enum ItemCategory {
	RESOURCE,      # Ягоды, ветки, тряпки, платы, металлолом и т.д.
	WEAPON,        # Топоры, ножи, луки, арбалеты, винтовки, пистолеты
	AMMO,          # Стрелы, болты, патроны
	ARMOR_HEAD,    # Шлем, противогаз
	ARMOR_BODY,    # Полный комплект одежды, броня
	ARMOR_FEET,    # Обувь, берцы
	CONSUMABLE,    # Еда, аптечки
	BACKPACK,      # Улучшение рюкзака (большая вместимость)
	HEAVY_OBJECT   # Турели, мебель (не помещаются в инвентарь, ставятся в мире)
}

enum EquipSlotType {
	NONE,
	WEAPON,        # Подходит в любой из 4 слотов оружия (Warband-стиль)
	HEAD,          # Шлем / противогаз
	BODY,          # Одежда / бронекостюм
	FEET           # Обувь
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: ItemCategory = ItemCategory.RESOURCE
@export var equip_slot_type: EquipSlotType = EquipSlotType.NONE

## Максимальный размер стека в инвентаре (по ТЗ: по умолчанию 5 единиц одного типа)
@export var max_stack: int = 5

## Переносимое ли в инвентаре (если false: турели, мебель - ставятся рядом с верстаком)
@export var is_portable: bool = true

## Флаг бревна (по ТЗ: в инвентарь можно положить всё кроме бревен)
@export var is_log: bool = false

## Путь к 3D модели (FBX / GLB / tscn) для спавна в мире
@export var model_path: String = ""

## Цветовой оттенок иконки / отображения
@export var icon_color: Color = Color.WHITE

## Дополнительные характеристики (урон, защита, сытость, слоты и т.д.)
@export var stats: Dictionary = {}

func can_fit_in_inventory() -> bool:
	return is_portable and not is_log
