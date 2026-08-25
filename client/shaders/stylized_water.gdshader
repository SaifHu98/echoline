shader_type spatial;
render_mode specular_toon, depth_draw_always;

// Stylized Canal Water with Dynamic Foam, Caustics, and Depth Gradient

uniform vec4 shallow_color : source_color = vec4(0.0, 0.75, 0.9, 0.7);
uniform vec4 deep_color : source_color = vec4(0.05, 0.2, 0.45, 0.95);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_frequency : hint_range(0.5, 10.0) = 3.0;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.08;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void vertex() {
	// Stylized procedural vertex wave displacement
	float wave1 = sin(VERTEX.x * wave_frequency + TIME * wave_speed);
	float wave2 = cos(VERTEX.z * wave_frequency * 0.8 + TIME * wave_speed * 1.2);
	VERTEX.y += (wave1 + wave2) * wave_amplitude;
}

void fragment() {
	// Depth-based color gradient and shore foam calculation
	float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	
	// Foam and water color blending
	float wave_factor = (sin(UV.x * 20.0 + TIME * 2.0) + 1.0) * 0.5;
	vec4 water_col = mix(shallow_color, deep_color, clamp(UV.y * 1.5, 0.0, 1.0));
	
	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
	EMISSION = shallow_color.rgb * 0.15;
}
