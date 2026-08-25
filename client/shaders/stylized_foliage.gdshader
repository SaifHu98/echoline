shader_type spatial;
render_mode specular_toon, cull_disabled;

// Stylized Courtyard Foliage with Procedural Wind Sway

uniform vec4 foliage_color_top : source_color = vec4(0.3, 0.75, 0.25, 1.0);
uniform vec4 foliage_color_bottom : source_color = vec4(0.1, 0.4, 0.15, 1.0);
uniform float wind_speed : hint_range(0.1, 4.0) = 1.2;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.2;

void vertex() {
	// Wind sway affecting upper vertices only
	float height_factor = clamp(VERTEX.y * 0.5, 0.0, 1.0);
	float wind_sway = sin(TIME * wind_speed + VERTEX.x * 2.0) * wind_strength * height_factor;
	VERTEX.x += wind_sway;
	VERTEX.z += wind_sway * 0.5;
}

void fragment() {
	vec3 col = mix(foliage_color_bottom.rgb, foliage_color_top.rgb, UV.y);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	RIM = 0.4;
	RIM_TINT = 0.5;
}
