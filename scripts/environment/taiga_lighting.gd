class_name TaigaLighting
extends Node
## Dynamically modifies sunlight, shadows, and spore fog based on day/night phase.

@export var sun_light: DirectionalLight3D
@export var world_env: WorldEnvironment

@export var day_sun_color: Color = Color(1.0, 0.90, 0.75)
@export var night_sun_color: Color = Color(0.25, 0.32, 0.60)
@export var sunset_sun_color: Color = Color(1.0, 0.68, 0.38)

@export var day_fog_color: Color = Color(0.70, 0.60, 0.52)
@export var night_fog_color: Color = Color(0.14, 0.12, 0.28) # Spore purple-blue tone

var _using_continuous: bool = false

func _ready() -> void:
	if GameEvents.has_signal("time_continuous_updated") and not GameEvents.time_continuous_updated.is_connected(_on_time_continuous_updated):
		GameEvents.time_continuous_updated.connect(_on_time_continuous_updated)
	if not GameEvents.time_updated.is_connected(_on_time_updated):
		GameEvents.time_updated.connect(_on_time_updated)
	_setup_shadow_parameters()

func _setup_shadow_parameters() -> void:
	if not sun_light:
		return
	sun_light.shadow_enabled = true
	# Enable cascade split blending to prevent shadow popping across cascades
	sun_light.directional_shadow_blend_splits = true
	# Soft blur filter for shadows
	sun_light.shadow_blur = 1.5
	# Normal bias prevents shadow acne on uneven taiga terrain
	sun_light.shadow_normal_bias = 2.0
	sun_light.shadow_bias = 0.05
	# Focus shadow map resolution on the playable zone (prevents pixel crawling)
	if sun_light.directional_shadow_max_distance < 1.0 or sun_light.directional_shadow_max_distance > 300.0:
		sun_light.directional_shadow_max_distance = 200.0

func _on_time_continuous_updated(exact_hour: float) -> void:
	_using_continuous = true
	_update_lighting(exact_hour)

func _on_time_updated(hours: int, minutes: int, _phase: int) -> void:
	if not _using_continuous:
		var total_hour := float(hours) + float(minutes) / 60.0
		_update_lighting(total_hour)

func _update_lighting(total_hour: float) -> void:
	# Continuous sun pitch (rotates smoothly every frame)
	var sun_pitch := (total_hour / 24.0) * 360.0 - 90.0

	if sun_light:
		sun_light.rotation_degrees.x = -sun_pitch
		
		# Smooth continuous day/night weight curve using smoothstep
		var day_weight: float = 0.0
		if total_hour >= 7.0 and total_hour <= 17.5:
			day_weight = 1.0
		elif total_hour > 5.0 and total_hour < 7.0:
			day_weight = smoothstep(5.0, 7.0, total_hour)
		elif total_hour > 17.5 and total_hour < 19.5:
			day_weight = 1.0 - smoothstep(17.5, 19.5, total_hour)
		else:
			day_weight = 0.0
		
		# Continuous energy curve: from night (0.15) to peak daylight (1.8)
		var target_energy := lerpf(0.15, 1.8, day_weight)
		
		# Golden hour / sunset color tinting at dawn and dusk
		var sunset_weight := 4.0 * day_weight * (1.0 - day_weight) # 0 at night/noon, 1.0 at dawn/dusk
		var base_color := night_sun_color.lerp(day_sun_color, day_weight)
		var final_sun_color := base_color.lerp(sunset_sun_color, sunset_weight * 0.45)
		
		sun_light.light_energy = target_energy
		sun_light.light_color = final_sun_color
		
		# Ensure shadows don't project upwards through the ground when the sun is below horizon
		var sun_above_horizon := sun_pitch >= -5.0 and sun_pitch <= 185.0
		sun_light.shadow_enabled = sun_above_horizon

	if world_env and world_env.environment:
		var env := world_env.environment
		var fog_weight := 0.0
		if total_hour >= 6.5 and total_hour <= 18.0:
			fog_weight = 1.0
		elif total_hour > 5.0 and total_hour < 6.5:
			fog_weight = smoothstep(5.0, 6.5, total_hour)
		elif total_hour > 18.0 and total_hour < 19.5:
			fog_weight = 1.0 - smoothstep(18.0, 19.5, total_hour)
		env.fog_light_color = night_fog_color.lerp(day_fog_color, fog_weight)
