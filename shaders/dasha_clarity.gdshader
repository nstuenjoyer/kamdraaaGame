shader_type canvas_item;

// The drawn movement poses are softer than the resting art. Increase local
// contrast without changing the geometry or filtering the pixel grid.
uniform float clarity_amount : hint_range(0.0, 1.5) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec2 dimensions = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * dimensions;
	vec2 cell_min = floor(p / vec2(160.0, 256.0)) * vec2(160.0, 256.0) + vec2(0.5);
	vec2 cell_max = cell_min + vec2(159.0, 255.0);
	vec4 center = texture(TEXTURE, UV);
	vec4 left = texture(TEXTURE, clamp(p + vec2(-1.0, 0.0), cell_min, cell_max) / dimensions);
	vec4 right = texture(TEXTURE, clamp(p + vec2(1.0, 0.0), cell_min, cell_max) / dimensions);
	vec4 top = texture(TEXTURE, clamp(p + vec2(0.0, -1.0), cell_min, cell_max) / dimensions);
	vec4 bottom = texture(TEXTURE, clamp(p + vec2(0.0, 1.0), cell_min, cell_max) / dimensions);
	vec3 neighbours = (mix(center.rgb, left.rgb, left.a) + mix(center.rgb, right.rgb, right.a)
		+ mix(center.rgb, top.rgb, top.a) + mix(center.rgb, bottom.rgb, bottom.a)) * 0.25;
	COLOR = vec4(clamp(center.rgb + (center.rgb - neighbours) * clarity_amount, vec3(0.0), vec3(1.0)), center.a) * sprite_tint;
}
