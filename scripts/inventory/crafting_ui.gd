class_name CraftingUI
extends Control
## Crafting interface at the Workbench.
## Displays recipe categories, ingredients check, and handles portable vs heavy object delivery.

@export var recipe_list_container: VBoxContainer
@export var recipe_title_label: Label
@export var recipe_desc_label: Label
@export var delivery_mode_label: Label
@export var ingredients_container: VBoxContainer
@export var craft_button: Button
@export var category_tabs_container: HBoxContainer

var current_workbench: Node = null
var current_category: String = "Все"
var selected_recipe: CraftingRecipe = null
var _is_mobile: bool = false
var close_btn: Button

func _ready() -> void:
	visible = false
	add_to_group("crafting_ui")

	if not recipe_list_container:
		recipe_list_container = find_child("RecipeList", true, false) as VBoxContainer
	if not recipe_title_label:
		recipe_title_label = find_child("RecipeTitle", true, false) as Label
	if not recipe_desc_label:
		recipe_desc_label = find_child("RecipeDesc", true, false) as Label
	if not delivery_mode_label:
		delivery_mode_label = find_child("DeliveryModeLabel", true, false) as Label
	if not ingredients_container:
		ingredients_container = find_child("IngredientsList", true, false) as VBoxContainer
	if not craft_button:
		craft_button = find_child("CraftButton", true, false) as Button
	if not category_tabs_container:
		category_tabs_container = find_child("CategoryTabs", true, false) as HBoxContainer

	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)

	close_btn = find_child("CloseButton", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(close_workbench)

	GameEvents.camera_mode_changed.connect(_on_camera_mode_changed)
	GameEvents.ui_mode_changed.connect(_on_ui_mode_changed)

	_setup_category_tabs()

	var sm = get_node_or_null("/root/SettingsManager")
	var initial_mobile: bool = sm.is_mobile_ui() if sm and sm.has_method("is_mobile_ui") else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_on_ui_mode_changed(initial_mobile)

func _on_ui_mode_changed(is_mobile: bool) -> void:
	_is_mobile = is_mobile
	if close_btn:
		close_btn.text = "✕ ЗАКРЫТЬ" if _is_mobile else "✕ Закрыть [Esc / E]"
		close_btn.custom_minimum_size = Vector2(0, 50) if _is_mobile else Vector2(0, 40)
	if craft_button:
		craft_button.custom_minimum_size = Vector2(0, 52) if _is_mobile else Vector2(0, 42)
	if category_tabs_container:
		for c in category_tabs_container.get_children():
			if c is Button:
				c.custom_minimum_size = Vector2(0, 46) if _is_mobile else Vector2(0, 36)
	if visible:
		refresh_recipe_list()

func _on_camera_mode_changed(mode: int) -> void:
	if mode == GameEnums.CameraMode.ARCHITECT:
		close_workbench()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("toggle_inventory")):
		close_workbench()
		get_viewport().set_input_as_handled()

func open_workbench(wb: Node) -> void:
	current_workbench = wb
	visible = true
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.is_crafting_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_recipe_list()

func close_workbench() -> void:
	visible = false
	current_workbench = null
	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if inv:
		inv.is_crafting_open = false
		if not inv.is_inventory_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_category_tabs() -> void:
	if not category_tabs_container:
		return
	for c in category_tabs_container.get_children():
		if c is Button:
			var cat_name: String = c.text
			c.pressed.connect(func(): _select_category(cat_name))

func _select_category(cat: String) -> void:
	current_category = cat
	refresh_recipe_list()

func refresh_recipe_list() -> void:
	if not recipe_list_container:
		return

	for c in recipe_list_container.get_children():
		c.queue_free()

	var inv = get_tree().root.get_node_or_null("InventoryManager")
	var inv_counts: Dictionary = inv.get_all_inventory_counts() if inv else {}

	var recipes := CraftingDatabase.get_recipes_by_category(current_category)

	var first_recipe: CraftingRecipe = null

	for r in recipes:
		if first_recipe == null:
			first_recipe = r

		var can_make := r.can_craft(inv_counts)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52) if _is_mobile else Vector2(0, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var portable_tag := "🎒" if r.is_portable else "🏗 (Тяжелый)"
		var status_color := Color(0.3, 0.9, 0.4) if can_make else Color(0.8, 0.35, 0.35)

		btn.text = "  %s  %s  [%s]" % [portable_tag, r.display_name, r.category]
		btn.modulate = status_color

		var recipe_ref := r
		btn.pressed.connect(func(): _select_recipe(recipe_ref))
		recipe_list_container.add_child(btn)

	if selected_recipe and recipes.has(selected_recipe):
		_select_recipe(selected_recipe)
	elif first_recipe:
		_select_recipe(first_recipe)
	else:
		_clear_detail()

func _select_recipe(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	if not recipe:
		_clear_detail()
		return

	var inv = get_tree().root.get_node_or_null("InventoryManager")
	var inv_counts: Dictionary = inv.get_all_inventory_counts() if inv else {}

	if recipe_title_label:
		recipe_title_label.text = recipe.display_name
	if recipe_desc_label:
		recipe_desc_label.text = recipe.description

	if delivery_mode_label:
		if recipe.is_portable:
			delivery_mode_label.text = "🎒 ПЕРЕНОСИМЫЙ: Создается прямо в рюкзак (стеки по 5 шт.)"
			delivery_mode_label.modulate = Color(0.4, 0.85, 0.95)
		else:
			delivery_mode_label.text = "🏗 НЕПЕРЕНОСИМЫЙ: Тяжелый объект (турель/мебель). Устанавливается рядом с верстаком!"
			delivery_mode_label.modulate = Color(1.0, 0.7, 0.2)

	# Список ингредиентов
	if ingredients_container:
		for c in ingredients_container.get_children():
			c.queue_free()

		for mat_id in recipe.ingredients:
			var req_count: int = int(recipe.ingredients[mat_id])
			var cur_count: int = int(inv_counts.get(mat_id, 0))
			var item_data = ItemDatabase.get_item(mat_id)
			var item_name: String = item_data.display_name if item_data else mat_id

			var lbl := Label.new()
			var has_enough := cur_count >= req_count
			var mark := "[✓ В наличии]" if has_enough else "[✗ Не хватает]"
			lbl.text = "• %s: %d / %d %s" % [item_name, cur_count, req_count, mark]
			lbl.modulate = Color(0.3, 0.9, 0.4) if has_enough else Color(0.9, 0.3, 0.3)
			ingredients_container.add_child(lbl)

	var can_make := recipe.can_craft(inv_counts)
	if craft_button:
		craft_button.disabled = not can_make
		craft_button.text = "СОЗДАТЬ: %s" % recipe.display_name

func _clear_detail() -> void:
	if recipe_title_label: recipe_title_label.text = "Выберите рецепт"
	if recipe_desc_label: recipe_desc_label.text = "Выберите предмет слева для просмотра материалов."
	if delivery_mode_label: delivery_mode_label.text = ""
	if ingredients_container:
		for c in ingredients_container.get_children():
			c.queue_free()
	if craft_button:
		craft_button.disabled = true
		craft_button.text = "СОЗДАТЬ"

func _on_craft_pressed() -> void:
	if not selected_recipe:
		return

	var inv = get_tree().root.get_node_or_null("InventoryManager")
	if not inv:
		return

	var spawn_pos := Vector3.ZERO
	if current_workbench and current_workbench.has_method("get_heavy_spawn_position"):
		spawn_pos = current_workbench.get_heavy_spawn_position()
	elif is_inside_tree() and get_tree().get_first_node_in_group("player"):
		var p = get_tree().get_first_node_in_group("player")
		spawn_pos = p.global_position + (-p.global_transform.basis.z * 2.0)

	var success: bool = inv.craft_recipe(selected_recipe, spawn_pos)
	if success:
		refresh_recipe_list()
