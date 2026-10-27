class_name LogPickup
extends Interactable
## Ground log that the Warden can pick up on his shoulder.

@export var item_root: Node

func _init() -> void:
	prompt_message = "Взять бревно на плечо"

func can_interact(actor: Node) -> bool:
	if not is_enabled:
		return false
	if actor is PlayerController:
		return (actor as PlayerController).can_pickup_log()
	var carrier := _get_carrier(actor)
	return carrier != null and carrier.carried_logs < carrier.max_logs

func get_interaction_info(player: PlayerController) -> Dictionary:
	if player.can_pickup_log():
		return { "prompt": "Взять бревно на плечо", "type": "PICKUP" }
	return { "prompt": "Плечо занято (макс. 3)", "type": "BLOCKED" }

func interact(actor: Node) -> void:
	if actor is PlayerController:
		if (actor as PlayerController).add_log():
			_destroy_log()
			return
	var carrier := _get_carrier(actor)
	if carrier and carrier.add_log():
		_destroy_log()

func _destroy_log() -> void:
	if item_root and is_instance_valid(item_root):
		item_root.queue_free()
		return
	
	# Fallback: climb up until top-level StaticBody3D or RigidBody3D
	var cur: Node = self
	while cur.get_parent() and not (cur is StaticBody3D or cur is RigidBody3D):
		cur = cur.get_parent()
	if cur:
		cur.queue_free()

func _get_carrier(actor: Node) -> Object:
	if not actor:
		return null
	if actor is PlayerController:
		return (actor as PlayerController).carrier
	for child in actor.get_children():
		if child is PlayerCarrier:
			return child
	return null
