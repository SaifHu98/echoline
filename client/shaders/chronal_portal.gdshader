shader_type spatial;
render_mode unshaded, cull_disabled;

// Subterranean Chronal Gate Portal Swirl Shader

uniform vec4 portal_core_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 portal_rim_color : source_color = vec4(0.56, 0.07, 0.99, 1.0);
uniform float vortex_speed : hint_range(0.1, 5.0) = 1.5;
uniform float distortion_intensity : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);
	
	// Spiral vortex rotation
	float spiral = angle + dist * 4.0 - TIME * vortex_speed;
	float ring = sin(dist * 12.0 - TIME * 3.0 + spiral);
	
	// Color transition from core to rim
	vec3 col = mix(portal_core_color.rgb, portal_rim_color.rgb, clamp(dist, 0.0, 1.0));
	col += vec3(ring * 0.3);
	
	float alpha = smoothstep(1.0, 0.1, dist);
	
	ALBEDO = col * 1.5;
	ALPHA = alpha;
}
