class_name POIMarker
extends Node3D
## Marker for Points of Interest (POI) used by compass, map navigation, and discovery system.

signal discovered()

@export var poi_id: String = ""
@export var poi_name: String = ""
@export var zone_type: WorldZoneManager.ZoneType = WorldZoneManager.ZoneType.OUTPOST_CENTER
@export var discovery_radius: float = 25.0
@export var show_label_when_discovered: bool = true

var is_discovered: bool = false

@onready var label: Label3D = get_node_or_null("Label3D")
@onready var beacon: MeshInstance3D = get_node_or_null("BeaconMesh")

func _ready() -> void:
	# Регистрация в глобальном менеджере зон, если еще не зарегистрирован
	if Engine.has_singleton("WorldTopography") or get_node_or_null("/root/WorldTopography"):
		if not poi_id.is_empty():
			if not WorldTopography.pois.has(poi_id):
				WorldTopography.register_poi(poi_id, poi_name, global_position, zone_type, false, discovery_radius)
			else:
				var data: Dictionary = WorldTopography.pois[poi_id]
				is_discovered = data.get("visited", false)
				if poi_name.is_empty():
					poi_name = data.get("name", poi_id)

		WorldTopography.poi_discovered.connect(_on_global_poi_discovered)
	
	_update_visuals()

func _on_global_poi_discovered(p_id: String, _p_name: String) -> void:
	if p_id == poi_id:
		is_discovered = true
		_update_visuals()
		emit_signal("discovered")

func _update_visuals() -> void:
	if label:
		label.text = poi_name if not poi_name.is_empty() else poi_id
		label.visible = is_discovered and show_label_when_discovered
	if beacon:
		beacon.visible = is_discovered
