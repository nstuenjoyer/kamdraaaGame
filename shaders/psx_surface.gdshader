shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 texture_scale = vec2(1.0);
uniform float vertex_snap : hint_range(0.0, 1.0) = 0.0;
uniform float affine_strength : hint_range(0.0, 1.0) = 0.0;
uniform float face_protection : hint_range(0.0, 1.0) = 0.0;
varying vec2 affine_uv;
varying float affine_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float strength = vertex_snap * (1.0 - face_protection);
	vec2 grid = vec2(640.0, 360.0);
	vec2 snapped = floor(clip.xy / max(clip.w, 0.001) * grid + 0.5) / grid;
	clip.xy = mix(clip.xy, snapped * clip.w, strength);
	POSITION = clip;
	affine_uv = UV * clip.w;
	affine_w = clip.w;
}

void fragment() {
	vec2 uv = mix(UV, affine_uv / max(affine_w, 0.001), affine_strength * (1.0 - face_protection));
	ALBEDO = texture(albedo_texture, uv * texture_scale).rgb * tint.rgb;
	ROUGHNESS = 1.0;
}
