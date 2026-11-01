shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/window_glass_mask.gdshaderinc"
uniform sampler2D backdrop : hint_screen_texture, repeat_disable, filter_linear;
varying vec4 water;
void vertex() { water = INSTANCE_CUSTOM; }
void fragment() {
	float across = UV.x * 2.0 - 1.0;
	float mask = (1.0 - smoothstep(0.3, 1.0, abs(across))) * pow(water.r, 1.6);
	vec3 color = texture(backdrop, SCREEN_UV + vec2(across * SCREEN_PIXEL_SIZE.x * 1.2, 0.0)).rgb;
	color += vec3(0.018, 0.024, 0.03) * (1.0 - abs(across));
	COLOR = vec4(color, mask * 0.38 * window_glass_mask(SCREEN_UV));
}
