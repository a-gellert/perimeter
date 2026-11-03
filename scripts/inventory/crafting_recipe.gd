class_name CraftingRecipe
extends Resource
## Defines a recipe for creating items at the workbench.
## Supports portable items (added to backpack) and heavy objects (spawned next to the workbench).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "Оружие" # "Оружие", "Боеприпасы", "Инструменты", "Снаряжение", "Мебель и Оборона"
@export var output_item_id: String = ""
@export var output_count: int = 1

## Словарь требуемых ресурсов: { "item_id": count, ... }
@export var ingredients: Dictionary = {}

## Переносимое ли созданное изделие.
## Если false (турели, мебель): объект появляется рядом с верстаком в физическом мире!
@export var is_portable: bool = true

## Путь к 3D сцене для спавна непереносимого объекта (или спавна при установке)
@export var world_scene_path: String = ""

func can_craft(inventory_counts: Dictionary) -> bool:
	for mat_id in ingredients:
		var req_count: int = int(ingredients[mat_id])
		var current_count: int = int(inventory_counts.get(mat_id, 0))
		if current_count < req_count:
			return false
	return true
