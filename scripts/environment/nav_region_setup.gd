class_name NavRegionSetup
extends NavigationRegion3D
## Programmatically sets up NavigationMesh covering the 1000x1000m taiga valley
## with agent dimensions matching sleeper mutants (radius 0.45, height 1.7).

@export var map_size: float = 1000.0
@export var agent_radius: float = 0.45
@export var agent_height: float = 1.7
@export var agent_max_climb: float = 0.5
@export var agent_max_slope: float = 45.0

func _ready() -> void:
	_setup_navigation_mesh()
	call_deferred(&"bake_navigation_mesh")

func _setup_navigation_mesh() -> void:
	if navigation_mesh == null:
		navigation_mesh = NavigationMesh.new()

	var half_size: float = map_size * 0.5
	# Cover the 1000x1000m area across expected valley elevations (-50m to +150m)
	navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-half_size, -50.0, -half_size),
		Vector3(map_size, 200.0, map_size)
	)
	navigation_mesh.agent_radius = agent_radius
	navigation_mesh.agent_height = agent_height
	navigation_mesh.agent_max_climb = agent_max_climb
	navigation_mesh.agent_max_slope = agent_max_slope
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
