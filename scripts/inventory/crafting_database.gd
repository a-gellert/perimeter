class_name CraftingDatabase
extends RefCounted
## Registry of recipes available at the Workbench.
## Modular and extensible: to add a new recipe, simply add an entry to `_register_all()`!

static var _recipes: Array[CraftingRecipe] = []
static var _recipes_by_id: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_all()

static func get_all_recipes() -> Array[CraftingRecipe]:
	_ensure_initialized()
	return _recipes

static func get_recipe_by_id(recipe_id: String) -> CraftingRecipe:
	_ensure_initialized()
	return _recipes_by_id.get(recipe_id, null)

static func get_recipes_by_category(category: String) -> Array[CraftingRecipe]:
	_ensure_initialized()
	if category == "Все" or category.is_empty():
		return _recipes
	var result: Array[CraftingRecipe] = []
	for r in _recipes:
		if r.category == category:
			result.append(r)
	return result

static func register_recipe(recipe: CraftingRecipe) -> void:
	_recipes.append(recipe)
	_recipes_by_id[recipe.id] = recipe

static func _create_recipe(
	id: String,
	display_name: String,
	desc: String,
	category: String,
	output_item_id: String,
	output_count: int,
	ingredients: Dictionary,
	is_portable: bool = true,
	world_scene: String = ""
) -> CraftingRecipe:
	var r := CraftingRecipe.new()
	r.id = id
	r.display_name = display_name
	r.description = desc
	r.category = category
	r.output_item_id = output_item_id
	r.output_count = output_count
	r.ingredients = ingredients
	r.is_portable = is_portable
	r.world_scene_path = world_scene
	return r

static func _register_all() -> void:
	# 1. ОРУЖИЕ (Weapons)
	register_recipe(_create_recipe(
		"craft_knife", "Охотничий нож",
		"Компактный клинок для ближнего боя и разделки добычи.",
		"Оружие", "knife", 1,
		{"branches": 1, "scrap": 2},
		true
	))

	register_recipe(_create_recipe(
		"craft_axe", "Топор лесоруба",
		"Тяжелое лезвие на березовом топорище. Рубит лес и сокрушает мутантов.",
		"Оружие", "axe", 1,
		{"branches": 2, "scrap": 2},
		true
	))

	register_recipe(_create_recipe(
		"craft_bow", "Самодельный лук",
		"Таежный охотничий лук с тетивой из скрученной ткани.",
		"Оружие", "bow", 1,
		{"branches": 3, "rags": 2},
		true
	))

	register_recipe(_create_recipe(
		"craft_crossbow", "Тяжелый арбалет",
		"Мощный спусковой механизм на стальной дуге. Огромная убойная сила.",
		"Оружие", "crossbow", 1,
		{"branches": 4, "scrap": 3, "circuit": 1},
		true
	))

	# 2. БОЕПРИПАСЫ (Ammo)
	register_recipe(_create_recipe(
		"craft_arrow", "Стрелы (5 шт.)",
		"Комплект оперенных стрел для лука.",
		"Боеприпасы", "arrow", 5,
		{"branches": 2, "scrap": 1},
		true
	))

	register_recipe(_create_recipe(
		"craft_bolt", "Арбалетные болты (5 шт.)",
		"Комплект стальных болтов с тяжелыми бронебойными наконечниками.",
		"Боеприпасы", "bolt", 5,
		{"branches": 2, "scrap": 2},
		true
	))

	# 3. СНАРЯЖЕНИЕ И УЛУЧШЕНИЕ РЮКЗАКА (Gear & Backpacks)
	register_recipe(_create_recipe(
		"craft_lantern", "Кемпинговый фонарь",
		"Электрический фонарь на основе диодов и микросхемы. Освещает тьму.",
		"Снаряжение", "lantern", 1,
		{"circuit": 1, "scrap": 2, "rags": 1},
		true
	))

	register_recipe(_create_recipe(
		"craft_gasmask", "Противогаз ГП-7",
		"Защита органов дыхания от спор мутации. Надевается в слот шлема.",
		"Снаряжение", "gasmask", 1,
		{"rags": 3, "scrap": 2, "circuit": 1},
		true
	))

	register_recipe(_create_recipe(
		"craft_backpack_t2", "Охотничий рюкзак (25 слотов)",
		"Улучшение вместимости рюкзака: расширяет инвентарь до 25 ячеек.",
		"Снаряжение", "backpack_tier2", 1,
		{"rags": 4, "scrap": 2},
		true
	))

	register_recipe(_create_recipe(
		"craft_backpack_t3", "Тактический рюкзак (35 слотов)",
		"Предельное расширение инвентаря егеря до 35 ячеек.",
		"Снаряжение", "backpack_tier3", 1,
		{"rags": 8, "scrap": 4, "circuit": 2},
		true
	))

	# 4. МЕБЕЛЬ И ОБОРОНА (ТЯЖЕЛЫЕ ОБЪЕКТЫ - НЕ В ИНВЕНТАРЬ, СПАВНЯТСЯ У ВЕРСТАКА!)
	register_recipe(_create_recipe(
		"craft_turret", "Автономная турель",
		"Стационарный стрелковый модуль. Тяжелый объект — устанавливается рядом с верстаком!",
		"Мебель и Защита", "turret", 1,
		{"scrap": 5, "circuit": 3, "branches": 3},
		false # is_portable = false!
	))

	register_recipe(_create_recipe(
		"craft_chair", "Стул егеря",
		"Деревянный стул ручной работы. Мебель размещается рядом с верстаком.",
		"Мебель и Защита", "furniture_chair", 1,
		{"branches": 3},
		false # is_portable = false!
	))

	register_recipe(_create_recipe(
		"craft_table", "Стол из бревен",
		"Широкий деревянный стол для жилого дома. Размещается рядом с верстаком.",
		"Мебель и Защита", "furniture_table", 1,
		{"branches": 5, "scrap": 2},
		false # is_portable = false!
	))

	register_recipe(_create_recipe(
		"craft_bed", "Походная койка",
		"Койка для отдыха колонистов. Размещается рядом с верстаком.",
		"Мебель и Защита", "furniture_bed", 1,
		{"branches": 4, "rags": 3},
		false # is_portable = false!
	))
