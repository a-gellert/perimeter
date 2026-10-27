class_name BorderKillVolume
extends Area3D
## Lethal spore border volume outside the 1000x1000m valley bounds.

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# Если игрок перелезает барьеры — споровый туман за пределами долины мгновенно убивает
func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController or body.name == "Player":
		# Нанесение быстрого летального урона от сверхвысокой концентрации спор
		if body.has_method("take_damage"):
			body.take_damage(body.get("hp") if body.get("hp") != null and body.get("hp") > 0 else 9999.0)
		body.set("hp", 0.0)
