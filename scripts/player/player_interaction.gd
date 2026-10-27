class_name PlayerInteraction
extends Node
## Detects interactable objects via RayCast3D and triggers context actions.

@export var interaction_ray: RayCast3D
@export var actor: CharacterBody3D

var current_target: Interactable = null
var is_active: bool = true

func _ready() -> void:
	if not actor:
		actor = _resolve_actor()

func _process(_delta: float) -> void:
	if not is_active or not interaction_ray:
		_clear_target()
		return

	var actor_node := _resolve_actor()

	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		var interactable := _find_interactable(collider)
		
		if interactable and interactable.can_interact(actor_node):
			_set_target(interactable, actor_node)
		else:
			_clear_target()
	else:
		_clear_target()

	if Input.is_action_just_pressed("interact") and current_target:
		current_target.interact(actor_node)
		# Re-evaluate after interaction (e.g. if item was consumed)
		_clear_target()

func _resolve_actor() -> CharacterBody3D:
	if actor:
		return actor
	var cur: Node = get_parent()
	while cur:
		if cur is CharacterBody3D:
			return cur as CharacterBody3D
		cur = cur.get_parent()
	return owner as CharacterBody3D

func _find_interactable(node: Node) -> Interactable:
	if not node:
		return null
	if node is Interactable:
		return node
	# Look in immediate children
	for child in node.get_children():
		if child is Interactable:
			return child
	# Look in parent or siblings if ray hit a child mesh/collider
	var parent_node := node.get_parent()
	if parent_node:
		if parent_node is Interactable:
			return parent_node
		for sibling in parent_node.get_children():
			if sibling is Interactable:
				return sibling
	return null

func _set_target(target: Interactable, actor_node: Node) -> void:
	if current_target != target:
		current_target = target
		GameEvents.context_action_updated.emit(target.get_prompt_text(actor_node), target)

func _clear_target() -> void:
	if current_target != null:
		current_target = null
		GameEvents.context_action_updated.emit("", null)
