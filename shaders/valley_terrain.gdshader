shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Biome palette matching user's map sketch
uniform vec4 color_rock : source_color = vec4(0.52, 0.44, 0.38, 1.0);
uniform vec4 color_grass : source_color = vec4(0.38, 0.54, 0.22, 1.0); // Lime green for West & Outpost
uniform vec4 color_taiga : source_color = vec4(0.18, 0.32, 0.16, 1.0); // Deep forest green for East Taiga
uniform vec4 color_riverbed : source_color = vec4(0.28, 0.25, 0.22, 1.0);
uniform vec4 color_sand : source_color = vec4(0.62, 0.50, 0.36, 1.0); // Warm sandy shores
uniform vec4 color_high_peak : source_color = vec4(0.85, 0.86, 0.90, 1.0); // White snowy alpine peaks

varying vec3 world_pos;
varying vec3 raw_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	raw_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Crisp low-poly faceted flat shading computed directly from screen derivatives
	vec3 flat_norm = normalize(cross(dFdy(world_pos), dFdx(world_pos)));
	if (dot(flat_norm, raw_normal) < 0.0) {
		flat_norm = -flat_norm;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(flat_norm, 0.0)).xyz);

	float slope = clamp(flat_norm.y, 0.0, 1.0);
	vec3 col;
	float r = 0.88;

	// Height-based biome coloring matching the reference taiga valley
	if (world_pos.y < -5.5) {
		// Deep riverbed & pebbles
		col = mix(color_riverbed.rgb, color_sand.rgb, 0.35);
		r = 0.55; // wet gravel
	} else if (world_pos.y < -1.0) {
		// Floodplain banks & sandy shores
		float t = clamp((world_pos.y - (-5.5)) / 4.5, 0.0, 1.0);
		col = mix(color_sand.rgb, color_grass.rgb, t);
	} else if (world_pos.y > 36.0) {
		// High rocky cliffs & white alpine peaks
		float t = clamp((world_pos.y - 36.0) / 34.0, 0.0, 1.0);
		col = mix(color_rock.rgb, color_high_peak.rgb, t);
	} else {
		// Middle valley basin: Outpost, Town, Taiga
		// Organic boundary between West (meadow/town) and East (deep pine taiga)
		float boundary_x = 10.0 + sin(world_pos.z * 0.018) * 35.0 + cos(world_pos.z * 0.04) * 15.0;
		if (world_pos.x > boundary_x) {
			col = color_taiga.rgb;
		} else {
			col = color_grass.rgb;
		}
	}

	// Steep cliff rock blend (rocky facets on slopes)
	if (slope < 0.72) {
		float rock_blend = 1.0 - smoothstep(0.38, 0.72, slope);
		col = mix(col, color_rock.rgb, rock_blend);
		r = mix(r, 0.95, rock_blend);
	}

	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = 0.02;
}
