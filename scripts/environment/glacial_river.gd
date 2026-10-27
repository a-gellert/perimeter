class_name GlacialRiver
extends Node3D
## Represents a flowing glacial mountain river with fresh flowing water.
## Automatically registers its path coordinates with ValleyEcology to create a spore-free microclimate.

@export var river_path: Array[Vector3] = [
	Vector3(24.0, 0.0, -40.0),
	Vector3(21.0, 0.0, -20.0),
	Vector3(20.0, 0.0, 0.0),
	Vector3(22.0, 0.0, 20.0),
	Vector3(25.0, 0.0, 40.0)
]

func _ready() -> void:
	if has_node("/root/ValleyEcology"):
		for pt in river_path:
			ValleyEcology.register_river_point(to_global(pt))
