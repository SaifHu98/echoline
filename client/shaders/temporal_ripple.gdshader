shader_type canvas_item;

// Post-Processing Spatial Temporal Shockwave & Chromatic Aberration

uniform vec2 center = vec2(0.5, 0.5);
uniform float force : hint_range(0.0, 0.2) = 0.05;
uniform float size : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.0, 0.2) = 0.05;
uniform vec4 timeline_tint : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 diff = uv - center;
	float dist = length(diff);
	
	// Create expanding spherical wave mask
	float mask = (1.0 - smoothstep(size - thickness, size, dist)) * 
	             smoothstep(size - thickness - 0.02, size - thickness, dist);
	
	vec2 disp = normalize(diff) * mask * force;
	
	// Chromatic aberration separation
	float r = texture(SCREEN_TEXTURE, uv - disp * 1.15).r;
	float g = texture(SCREEN_TEXTURE, uv - disp).g;
	float b = texture(SCREEN_TEXTURE, uv - disp * 0.85).b;
	
	vec3 scene_col = vec3(r, g, b);
	vec3 final_col = mix(scene_col, scene_col * timeline_tint.rgb, mask * 0.4);
	
	COLOR = vec4(final_col, 1.0);
}
