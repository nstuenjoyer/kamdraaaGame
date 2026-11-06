shader_type canvas_item;
render_mode unshaded;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.18;
uniform float color_levels = 48.0;
uniform bool crt_enabled = false;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	ivec2 p = ivec2(floor(UV * vec2(640.0, 360.0))) % 4;
	float b[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float noise = (b[p.y * 4 + p.x] / 16.0 - 0.5) * dither_strength;
	c = floor(c * color_levels + 0.5 + noise) / color_levels;
	vec2 v = UV * 2.0 - 1.0;
	c *= 1.0 - 0.12 * dot(v, v);
	if (crt_enabled) { c *= 0.96 + 0.04 * cos(UV.y * 360.0 * 3.14159265); }
	COLOR = vec4(c, 1.0);
}
