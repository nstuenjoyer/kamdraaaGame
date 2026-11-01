shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/window_glass_mask.gdshaderinc"
uniform sampler2D backdrop : hint_screen_texture, repeat_disable, filter_linear_mipmap;
varying vec4 droplet;
void vertex() { droplet = INSTANCE_CUSTOM; }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x *= mix(1.08, 0.94, smoothstep(-0.8, 0.8, p.y)) + droplet.g * max(0.0, -p.y) * 0.18;
	float r2 = dot(p, p);
	float edge = max(fwidth(r2) * 1.2, 0.025);
	float mask = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r2);
	float z = sqrt(max(0.01, 1.0 - min(r2, 0.99)));
	vec3 normal = normalize(vec3(p * 0.75, z));
	vec2 shift = normal.xy * SCREEN_PIXEL_SIZE * droplet.r * 2.6;
	vec3 lens = textureLod(backdrop, clamp(SCREEN_UV + shift, vec2(0.001), vec2(0.999)), 0.0).rgb;
	float rim = smoothstep(0.72, 1.0, r2);
	lens *= 1.0 - smoothstep(0.88, 1.0, r2) * 0.20;
	float highlight = pow(max(0.0, dot(normal, normalize(vec3(-0.45, -0.65, 0.9)))), 48.0);
	lens += vec3(0.72, 0.82, 0.92) * highlight * 0.85;
	lens += vec3(0.11, 0.15, 0.19) * pow(max(0.0, dot(normal, normalize(vec3(-0.45, -0.65, 0.9)))), 12.0);
	lens += vec3(0.10, 0.16, 0.20) * rim * 0.11;
	COLOR = vec4(lens, mask * 0.94 * window_glass_mask(SCREEN_UV));
}
