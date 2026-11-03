shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Vibrant glacial cyan water matching the reference art
uniform vec4 water_color : source_color = vec4(0.18, 0.60, 0.78, 0.85);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 0.95);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.6;
uniform float wave_scale : hint_range(0.01, 2.0) = 0.35;
uniform float wave_height : hint_range(0.0, 1.0) = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float flow_time = TIME * wave_speed;
	// Waves flow downstream towards +Z
	float wave1 = sin(world_pos.x * wave_scale + flow_time * 0.7) * cos(world_pos.z * wave_scale * 0.8 - flow_time);
	float wave2 = cos(world_pos.x * wave_scale * 1.4 - flow_time * 0.5) * sin(world_pos.z * wave_scale * 1.2 - flow_time * 1.2);
	VERTEX.y += (wave1 + wave2) * wave_height;
}

void fragment() {
	float flow_time = TIME * wave_speed;
	float wave_norm_x = sin(world_pos.x * 0.6 + flow_time * 0.8) * cos(world_pos.z * 0.6 - flow_time);
	float wave_norm_z = cos(world_pos.x * 0.7 - flow_time * 0.5) * sin(world_pos.z * 0.7 - flow_time * 1.1);

	// Surface normal in world coordinates (Y points UP into the sky)
	vec3 world_n = normalize(vec3(wave_norm_x * 0.15, 1.0, wave_norm_z * 0.15));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);

	// Subtle Fresnel effect for water surface realism
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
	vec3 final_color = mix(water_color.rgb, foam_color.rgb, fresnel * 0.3);

	ALBEDO = final_color;
	ALPHA = water_color.a;
	ROUGHNESS = 0.04;
	METALLIC = 0.12;
	SPECULAR = 0.9;
}
