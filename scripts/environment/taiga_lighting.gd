class_name TaigaLighting
extends Node
## Dynamically modifies sunlight, shadows, and spore fog based on day/night phase.

@export var sun_light: DirectionalLight3D
@export var world_env: WorldEnvironment

@export var day_sun_color: Color = Color(1.0, 0.92, 0.78)
@export var night_sun_color: Color = Color(0.25, 0.35, 0.65)

@export var day_fog_color: Color = Color(0.48, 0.58, 0.62)
@export var night_fog_color: Color = Color(0.14, 0.12, 0.28) # Spore purple-blue tone

func _ready() -> void:
	GameEvents.time_updated.connect(_on_time_updated)

func _on_time_updated(hours: int, minutes: int, _phase: int) -> void:
	var total_hour := float(hours) + float(minutes) / 60.0
	var sun_pitch := (total_hour / 24.0) * 360.0 - 90.0

	if sun_light:
		sun_light.rotation_degrees.x = -sun_pitch
		
		# Daytime sun curve
		var is_daytime := total_hour >= 6.0 and total_hour <= 19.0
		var target_energy := 1.8 if is_daytime else 0.15
		var target_color := day_sun_color if is_daytime else night_sun_color
		
		sun_light.light_energy = lerpf(sun_light.light_energy, target_energy, 0.05)
		sun_light.light_color = sun_light.light_color.lerp(target_color, 0.05)

	if world_env and world_env.environment:
		var env := world_env.environment
		var is_daytime := total_hour >= 6.0 and total_hour <= 19.0
		var target_fog_color := day_fog_color if is_daytime else night_fog_color
		env.fog_light_color = env.fog_light_color.lerp(target_fog_color, 0.05)
