shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Biome palette
uniform vec4 color_rock : source_color = vec4(0.32, 0.30, 0.28, 1.0);
uniform vec4 color_grass : source_color = vec4(0.24, 0.38, 0.20, 1.0);
uniform vec4 color_taiga : source_color = vec4(0.16, 0.26, 0.16, 1.0);
uniform vec4 color_riverbed : source_color = vec4(0.28, 0.24, 0.20, 1.0);
uniform vec4 color_sand : source_color = vec4(0.42, 0.37, 0.28, 1.0);
uniform vec4 color_high_peak : source_color = vec4(0.50, 0.48, 0.46, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float slope = clamp(world_normal.y, 0.0, 1.0);
	vec3 col;
	float r = 0.88;

	// Height-based biome coloring
	if (world_pos.y < -5.5) {
		// Deep riverbed & pebbles
		col = mix(color_riverbed.rgb, color_sand.rgb, 0.4);
		r = 0.6; // wet gravel
	} else if (world_pos.y < -2.0) {
		// Floodplain banks
		float t = clamp((world_pos.y - (-5.5)) / 3.5, 0.0, 1.0);
		col = mix(color_sand.rgb, color_grass.rgb, t);
	} else if (world_pos.y > 18.0) {
		// High rocky cliffs & peaks
		float t = clamp((world_pos.y - 18.0) / 16.0, 0.0, 1.0);
		col = mix(color_rock.rgb, color_high_peak.rgb, t);
	} else {
		// Middle plateau: Outpost, Town, Taiga
		if (world_pos.x > 80.0) {
			// East Taiga: dark mossy forest floor
			col = color_taiga.rgb;
		} else if (world_pos.x < -80.0) {
			// West Town: dry sparse grass & dirt
			col = mix(color_grass.rgb, color_sand.rgb, 0.3);
		} else {
			// Outpost Center: ranger meadow
			col = color_grass.rgb;
		}
	}

	// Steep cliff rock blend
	if (slope < 0.72) {
		float rock_blend = 1.0 - smoothstep(0.42, 0.72, slope);
		col = mix(col, color_rock.rgb, rock_blend);
		r = mix(r, 0.95, rock_blend);
	}

	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = 0.02;
}
