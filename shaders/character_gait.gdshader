shader_type canvas_item;
uniform float phase = 0.0;
uniform float motion = 0.0;
uniform float gait = 1.0;
void fragment() {
    vec2 uv = UV;
    float side = uv.x < 0.50 ? 1.0 : -1.0;
    float legs = smoothstep(0.72, 0.80, uv.y);
    float stride = sin(phase) * side * motion;
    uv.y += stride * legs * mix(0.012, 0.042, gait / 2.0);
    uv.x += stride * legs * 0.018;
    float arm = smoothstep(0.12, 0.21, abs(uv.x - 0.5)) * smoothstep(0.34, 0.44, uv.y) * (1.0-smoothstep(0.68, 0.78, uv.y));
    uv.y -= stride * arm * 0.016 * gait;
    COLOR = texture(TEXTURE, uv);
}
