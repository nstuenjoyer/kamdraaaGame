shader_type canvas_item;
render_mode unshaded;

uniform vec4 city_glow_cyan : source_color = vec4(0.08, 0.55, 0.85, 0.45);
uniform vec4 city_glow_magenta : source_color = vec4(0.85, 0.15, 0.55, 0.4);
uniform vec4 city_glow_amber : source_color = vec4(0.95, 0.5, 0.12, 0.3);
uniform float rain_speed : hint_range(0.2, 3.0) = 0.85;
uniform float rain_intensity : hint_range(0.1, 2.5) = 0.8;
uniform float neon_flicker : hint_range(0.0, 2.0) = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 sample_city_backdrop(vec2 uv, float t, float flicker) {
	// Небо ночного города: глубокий нуарный градиент с атмосферной дымкой
	vec3 col = vec3(0.026, 0.030, 0.050);
	col += vec3(0.016, 0.030, 0.055) * (1.0 - uv.y);
	col += vec3(0.055, 0.025, 0.040) * uv.y * 0.75;
	
	// Мягкий силуэт далекого городского горизонта
	float horizon = 0.58 + 0.03 * sin(uv.x * 6.28) + 0.015 * sin(uv.x * 18.84);
	float skyline = smoothstep(horizon - 0.06, horizon + 0.06, uv.y);
	col = mix(col, col * 0.78, skyline * 0.30);

	// Неоновая вывеска отеля "KAMDRAAA" (сочный маджента-неон слева)
	vec2 sign_pos = vec2(0.24, 0.32);
	float sign_dist = length(uv - sign_pos);
	float sign_glow = smoothstep(0.52, 0.01, sign_dist) * flicker;
	float sign_core = smoothstep(0.12, 0.005, sign_dist) * flicker * 1.8;
	col += city_glow_magenta.rgb * (sign_glow * 0.85 + sign_core * 1.4);
	
	// Кинематографичное боке ночных огней высоток и витрин
	vec2 b1_pos = vec2(0.78 + sin(t * 0.4) * 0.02, 0.42);
	float b1 = smoothstep(0.38, 0.01, length(uv - b1_pos));
	col += city_glow_cyan.rgb * b1 * (0.85 + 0.25 * sin(t * 1.4));
	
	vec2 b2_pos = vec2(0.55, 0.68 + cos(t * 0.5) * 0.02);
	float b2 = smoothstep(0.42, 0.01, length(uv - b2_pos));
	col += city_glow_amber.rgb * b2 * (0.80 + 0.25 * cos(t * 1.1));
	
	vec2 b3_pos = vec2(0.88, 0.72);
	float b3 = smoothstep(0.32, 0.01, length(uv - b3_pos));
	col += city_glow_cyan.rgb * b3 * 0.65;
	
	vec2 b4_pos = vec2(0.12, 0.78);
	float b4 = smoothstep(0.35, 0.01, length(uv - b4_pos));
	col += city_glow_amber.rgb * b4 * 0.75;
	
	vec2 b5_pos = vec2(0.68, 0.85);
	float b5 = smoothstep(0.30, 0.01, length(uv - b5_pos));
	col += vec3(0.95, 0.65, 0.25) * b5 * 0.55;

	// Дополнительный мягкий циановый источник в центре вверху
	vec2 b6_pos = vec2(0.45, 0.25);
	float b6 = smoothstep(0.28, 0.01, length(uv - b6_pos));
	col += city_glow_cyan.rgb * b6 * 0.35;

	// Далекий проблесковый маячок на антенне высотки (красный микро-блик)
	vec2 beacon_pos = vec2(0.62, 0.22);
	float beacon_blink = step(0.65, fract(t * 1.2));
	float beacon_dist = length(uv - beacon_pos);
	col += vec3(1.0, 0.15, 0.15) * smoothstep(0.035, 0.001, beacon_dist) * beacon_blink * 0.85;

	return col;
}

// Далекие струи дождя в воздухе на улице
float background_rain_streaks(vec2 uv, float t) {
	vec2 st = uv * vec2(60.0, 14.0);
	st.y -= t * rain_speed * 20.0;
	st.x += (uv.y) * 7.5;
	
	vec2 id = floor(st);
	vec2 f = fract(st);
	float h = hash12(id);
	if (h < 0.75) {
		return 0.0;
	}
	float streak = smoothstep(0.0, 0.08, f.x) * smoothstep(0.22, 0.08, f.x);
	streak *= smoothstep(0.0, 0.75, f.y) * smoothstep(1.0, 0.25, f.y);
	return streak * (h - 0.75) * 3.4;
}

void fragment() {
    vec2 uv = UV;
    float flicker = clamp(neon_flicker, 0.7, 1.15);
    vec3 city = sample_city_backdrop(uv, TIME * 0.25, flicker);
    // Defocused street lights provide detail for the foreground water lens.
    vec2 lights = uv * vec2(12.0, 7.0);
    vec2 cell = floor(lights);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = cell + vec2(float(x), float(y));
            float seed = hash12(id + 19.0);
            vec2 center = id + 0.2 + hash22(id + 3.0) * 0.6;
            vec2 offset = (lights - center) * vec2(1.0, 0.85);
            float radius = mix(0.06, 0.26, hash12(id + 7.0));
            float bokeh = exp(-dot(offset, offset) / (radius * radius));
            vec3 tint = mix(vec3(0.08, 0.48, 0.65), vec3(0.85, 0.43, 0.14), seed);
            city += tint * bokeh * step(0.55, seed) * smoothstep(0.15, 0.65, uv.y) * 0.65;
        }
    }
    float distant_rain = background_rain_streaks(uv, TIME * 0.3);
    city += vec3(0.10, 0.14, 0.18) * distant_rain * 0.06;
    float vignette = 1.0 - smoothstep(0.30, 0.85, length(uv - 0.5)) * 0.45;
    COLOR = vec4(city * vignette * 0.65, 1.0);
}
