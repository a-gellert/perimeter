shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.12, 0.42, 0.48, 0.78);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 0.98, 0.9);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.6;
uniform float wave_scale : hint_range(0.01, 2.0) = 0.35;
uniform float wave_height : hint_range(0.0, 1.0) = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave1 = sin(world_pos.x * wave_scale + TIME * wave_speed) * cos(world_pos.z * wave_scale * 0.8 + TIME * wave_speed * 0.7);
	float wave2 = cos(world_pos.x * wave_scale * 1.4 - TIME * wave_speed * 1.2) * sin(world_pos.z * wave_scale * 1.2 + TIME * wave_speed * 0.9);
	VERTEX.y += (wave1 + wave2) * wave_height;
}

void fragment() {
	float wave_norm = sin(world_pos.x * 0.6 + TIME * wave_speed * 1.5) * cos(world_pos.z * 0.6 + TIME * wave_speed);
	
	vec3 n = normalize(vec3(wave_norm * 0.15, 1.0, -wave_norm * 0.15));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = 0.06;
	METALLIC = 0.15;
	SPECULAR = 0.8;
}
