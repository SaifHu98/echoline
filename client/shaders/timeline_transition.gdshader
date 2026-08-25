shader_type canvas_item;

// Temporal Timeline Rift Wipe & Dissolve Transition

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float diamond_pixel_size = 40.0;
uniform vec4 rift_color : source_color = vec4(0.56, 0.07, 0.99, 1.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float x_fract = fract(FRAGCOORD.x / diamond_pixel_size);
	float y_fract = fract(FRAGCOORD.y / diamond_pixel_size);
	
	float x_dist = abs(x_fract - 0.5);
	float y_dist = abs(y_fract - 0.5);
	
	if (x_dist + y_dist + UV.x > progress * 2.0) {
		discard;
	}
	
	COLOR = rift_color;
}
