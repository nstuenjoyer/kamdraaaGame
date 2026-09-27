shader_type canvas_item;

// =============================================================================
// Фотореалистичный шейдер дождя и капель воды на стекле для Kamdraaa
// Физически обоснованная оптика:
// - 3D-сферический сегмент капли с гравитационным провисанием (sessile drop)
// - Закон преломления Снеллиуса с хроматической дисперсией n(λ)
// - Тёмный ободок полного внутреннего отражения (мениск TIR)
// - Тройные зеркальные блики: верхний свет + маджента-неон + циановые огни
// - Внутренняя каустическая фокусировка света
// - Прерывистое скольжение (stick-slip) с отрывом бисерных капель
// =============================================================================

uniform vec4 city_glow_cyan : source_color = vec4(0.08, 0.55, 0.85, 0.45);
uniform vec4 city_glow_magenta : source_color = vec4(0.85, 0.15, 0.55, 0.4);
uniform vec4 city_glow_amber : source_color = vec4(0.95, 0.5, 0.12, 0.3);
uniform float rain_speed : hint_range(0.2, 3.0) = 0.85;
uniform float rain_intensity : hint_range(0.1, 2.5) = 0.8;
uniform float neon_flicker : hint_range(0.0, 2.0) = 1.0;

// Быстрые хэш-функции
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

// Плавный естественный дрейф капли под действием гравитации и микронеровностей стекла
float get_gentle_drift(float y, float seed) {
	return sin(y * 3.4 + seed * 6.28) * 0.005 + sin(y * 7.1 + seed * 14.2) * 0.002;
}

// Физическая модель прерывистого движения капли (stick-slip):
// капля копит массу, срывается с ускорением, тормозит на неровности стекла
float calculate_stick_slip(float cycle, out float velocity) {
	float pos = 0.0;
	velocity = 0.0;
	
	if (cycle < 0.18) {
		// Фаза накопления массы: микро-дрожание на месте
		pos = sin(cycle * 34.9) * 0.0006;
		velocity = 0.02;
	} else if (cycle < 0.32) {
		// Первый срыв (рывок вниз на ~26% пути)
		float f = (cycle - 0.18) / 0.14;
		float s = smoothstep(0.0, 1.0, f);
		pos = s * 0.26;
		velocity = sin(f * 3.14159) * 2.2;
	} else if (cycle < 0.46) {
		// Остановка и фиксация на микропоре стекла
		pos = 0.26;
		velocity = 0.0;
	} else if (cycle < 0.60) {
		// Второй срыв (рывок вниз на ~26% пути)
		float f = (cycle - 0.46) / 0.14;
		float s = smoothstep(0.0, 1.0, f);
		pos = 0.26 + s * 0.26;
		velocity = sin(f * 3.14159) * 2.2;
	} else if (cycle < 0.70) {
		// Краткая пауза
		pos = 0.52;
		velocity = 0.0;
	} else if (cycle < 0.94) {
		// Стремительный финальный сход вниз через всё стекло
		float f = (cycle - 0.70) / 0.24;
		float s = f * f * (3.0 - 2.0 * f);
		pos = 0.52 + s * 0.68;
		velocity = sin(f * 3.14159) * 2.8;
	} else {
		pos = 1.20 + (cycle - 0.94) * 0.6;
		velocity = 1.0;
	}
	
	return pos;
}

// Огни и архитектурный силуэт ночного мегаполиса за стеклом
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

// Оптическая 3D-линза капли воды (физика сферического сегмента, контактный угол, мениск, каустика)
void evaluate_droplet_3d(
	vec2 offset, float base_radius, float seed, float sag_amount,
	inout vec2 total_norm, inout float total_mask, inout float total_spec,
	inout float total_neon_spec, inout float total_cyan_spec, inout float total_fresnel,
	inout float total_meniscus, inout float total_caustic, inout float total_shadow
) {
	// 1. Естественное гравитационное провисание (капли на вертикальном стекле массивнее снизу)
	vec2 p_sag = offset;
	if (p_sag.y > 0.0) {
		p_sag.y *= 1.0 - sag_amount * 0.20;
	} else {
		p_sag.y *= 1.0 + sag_amount * 0.30;
	}

	float dist = length(p_sag);
	
	// 2. Органические микро-неровности контура (пиннинг контактной линии на стекле)
	float angle = atan(p_sag.y, p_sag.x);
	float wobble = 1.0 + 0.052 * sin(angle * 3.0 + seed * 6.28) + 0.028 * cos(angle * 5.0 + seed * 12.57);
	float r = base_radius * wobble;

	// 3. Контактная тень снаружи капли (ambient occlusion с нижней теневой стороны)
	if (dist >= r * 0.90 && dist < r * 1.38) {
		float shadow_d = dist / (r * 1.35);
		float sh_angle = max(0.0, p_sag.y * 0.75 + p_sag.x * 0.35) / max(dist, 0.001);
		float sh = smoothstep(1.35, 1.0, shadow_d) * smoothstep(0.90, 1.05, shadow_d) * sh_angle;
		total_shadow = max(total_shadow, sh * 0.35);
	}

	if (dist < r * 1.05) {
		float norm_d = clamp(dist / r, 0.0, 1.0);
		float alpha = smoothstep(1.05, 0.92, norm_d);
		
		// 4. Форма водного купола: плавная вершина, крутой перепад высоты у границы (мениск)
		float dome_shape = sqrt(max(0.0, 1.0 - norm_d * norm_d));
		float slope = pow(norm_d, 0.82) * (1.15 - dome_shape * 0.35);
		vec2 n_xy = (p_sag / max(dist, 0.0001)) * slope;
		float n_z = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy) * 0.85));
		vec3 N = normalize(vec3(n_xy, n_z));

		total_norm += n_xy * alpha;
		total_mask = max(total_mask, alpha);

		// 5. Отражение Френеля на крутой границе капли (Schlick's approximation)
		float fresnel = 0.03 + 0.97 * pow(1.0 - max(0.0, N.z), 4.5);
		total_fresnel = max(total_fresnel, fresnel * alpha);

		// 6. Тёмный ободок полного внутреннего отражения (TIR / Meniscus) у самого края
		float meniscus_rim = smoothstep(0.74, 0.94, norm_d) * smoothstep(1.04, 0.94, norm_d);
		total_meniscus = max(total_meniscus, meniscus_rim * alpha);

		// 7. Основной зеркальный блик от верхнего света (небо / интерьер)
		vec3 L_sky = normalize(vec3(-0.35, -0.80, 0.50));
		vec3 V = vec3(0.0, 0.0, 1.0);
		vec3 H_sky = normalize(L_sky + V);
		float NdotH_sky = max(0.0, dot(N, H_sky));
		float spec_sharp = pow(NdotH_sky, 72.0) * 4.5;
		float spec_soft = pow(NdotH_sky, 14.0) * 0.80;
		total_spec += (spec_sharp + spec_soft) * alpha;

		// 8. Неоновый зеркальный блик от вывески отеля слева
		vec3 L_neon = normalize(vec3(-0.65, 0.25, 0.70));
		vec3 H_neon = normalize(L_neon + V);
		float NdotH_neon = max(0.0, dot(N, H_neon));
		float neon_spec = pow(NdotH_neon, 36.0) * 2.4;
		total_neon_spec += neon_spec * alpha;

		// 9. Циановый зеркальный блик от огней мегаполиса справа
		vec3 L_cyan = normalize(vec3(0.65, -0.20, 0.65));
		vec3 H_cyan = normalize(L_cyan + V);
		float NdotH_cyan = max(0.0, dot(N, H_cyan));
		float cyan_spec = pow(NdotH_cyan, 36.0) * 1.8;
		total_cyan_spec += cyan_spec * alpha;

		// 10. Внутренний каустический световой фокус в нижней части капли
		float caustic_zone = pow(max(0.0, -n_xy.y * 0.85 + n_xy.x * 0.35), 2.5);
		float caustic = caustic_zone * smoothstep(0.35, 0.90, norm_d) * (1.0 - meniscus_rim * 0.75);
		total_caustic += caustic * 0.90 * alpha;
	}
}

// Проверка: находится ли точка внутри протёртой полосы любого из ручейков
float get_rivulet_clearing_at(vec2 pos, float t, float aspect_x) {
	float clearing = 0.0;
	for (int i = 0; i < 6; i++) {
		float u_col = (float(i) + 0.5) / 6.0;
		float h = hash11(float(i) * 19.31 + 4.19);
		float col_x = (u_col + (h - 0.5) * (0.72 / 6.0)) * aspect_x;
		
		float col_speed = (0.65 + 0.45 * hash11(float(i) * 31.7 + 1.2)) * rain_speed;
		float col_time = t * col_speed * 0.16 + h * 27.5;
		float cycle = fract(col_time);
		
		float dummy_vel;
		float slip = calculate_stick_slip(cycle, dummy_vel);
		float drop_y = -0.15 + slip * 1.35;
		
		float r_head = 0.018 * (0.85 + 0.3 * h);
		float r_wipe = r_head * 1.15;
		
		float dy = pos.y - drop_y;
		float trail_len = 0.85;
		
		if (dy <= 0.015 && dy > -trail_len) {
			float riv_x = col_x + get_gentle_drift(pos.y, h);
			float dx = abs(pos.x - riv_x);
			if (dx < r_wipe) {
				float c = smoothstep(r_wipe, r_wipe * 0.65, dx);
				clearing = max(clearing, c);
			}
		}
	}
	return clearing;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Изотропное пространство 16:9: p.x от 0.0 до 1.77778, p.y от 0.0 до 1.0
	vec2 aspect = vec2(1.77778, 1.0);
	vec2 p = uv * aspect;

	// Неоновое мерцание с микро-сбоями напряжения
	float pulse = 0.85 + 0.15 * sin(t * 1.8);
	float glitch = 1.0;
	float rnd_step = hash11(floor(t * 12.0));
	if (rnd_step > 0.88) {
		glitch = 0.45 + 0.55 * sin(t * 60.0);
	} else if (rnd_step > 0.82) {
		glitch = 0.75;
	}
	float total_flicker = neon_flicker * pulse * glitch;

	vec2 total_normal = vec2(0.0);
	float drop_mask = 0.0;
	float total_spec = 0.0;
	float total_neon_spec = 0.0;
	float total_cyan_spec = 0.0;
	float total_fresnel = 0.0;
	float meniscus = 0.0;
	float caustic = 0.0;
	float total_shadow = 0.0;
	float total_cleared = 0.0;
	float total_sheen = 0.0;

	// =========================================================================
	// 1. ВЕРТИКАЛЬНЫЕ СПОЛЗАЮЩИЕ РУЧЕЙКИ ПО ВСЕЙ ШИРИНЕ ЭКРАНА (6 ПОЛОС)
	// =========================================================================
	for (int i = 0; i < 6; i++) {
		float u_col = (float(i) + 0.5) / 6.0;
		float h = hash11(float(i) * 19.31 + 4.19);
		float col_x = (u_col + (h - 0.5) * (0.72 / 6.0)) * aspect.x;
		
		float col_speed = (0.65 + 0.45 * hash11(float(i) * 31.7 + 1.2)) * rain_speed;
		float col_time = t * col_speed * 0.16 + h * 27.5;
		float cycle = fract(col_time);
		
		float vel;
		float slip = calculate_stick_slip(cycle, vel);
		float drop_y = -0.15 + slip * 1.35;
		
		float r_head = 0.018 * (0.85 + 0.3 * h);
		float r_wipe = r_head * 1.15;
		
		// 1A. Каплевидная динамическая голова ручейка
		vec2 head_pos = vec2(col_x + get_gentle_drift(drop_y, h), drop_y);
		vec2 d_head = p - head_pos;
		
		// Динамическое вытягивание капли при ускорении (сохранение объема несжимаемой жидкости)
		float stretch_y = 1.0 + clamp(vel * 0.28, 0.0, 0.65);
		float squeeze_x = 1.0 / sqrt(stretch_y);
		vec2 d_tear = vec2(d_head.x * squeeze_x, d_head.y / stretch_y);
		
		if (length(d_tear) < r_head * 2.0) {
			if (d_tear.y < 0.0) {
				// Плавное сужение и капиллярное вытягивание хвоста капли сверху
				d_tear.x *= 1.0 + clamp(-d_tear.y / (r_head * 1.25), 0.0, 2.2);
			} else {
				// Сплюснутая округлая нижняя кромка
				d_tear.y *= 1.15;
			}
			evaluate_droplet_3d(
				d_tear, r_head, h * 17.3, 0.28,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
		}
		
		// 1B. Протёртая полоса в конденсате позади капли (чистый, кристальный мокрый след)
		float dy = p.y - drop_y;
		float trail_len = 0.85;
		
		if (dy < 0.0 && dy > -trail_len) {
			float path_x = col_x + get_gentle_drift(p.y, h);
			float dx = abs(p.x - path_x);
			float trail_fade = smoothstep(-trail_len, -trail_len * 0.75, dy) * smoothstep(0.01, -0.01, dy);
			
			if (dx < r_wipe * 1.25) {
				float inside_swath = smoothstep(r_wipe * 1.15, r_wipe * 0.80, dx);
				total_cleared = max(total_cleared, inside_swath * trail_fade);
				
				// Тонкие бортики поверхностного натяжения на границах дорожки
				float border = smoothstep(r_wipe * 0.75, r_wipe * 0.98, dx) * smoothstep(r_wipe * 1.20, r_wipe * 0.98, dx);
				total_normal.x += sign(p.x - path_x) * border * 0.16 * trail_fade;
				total_sheen += border * 0.14 * trail_fade;
				total_fresnel = max(total_fresnel, border * 0.25 * trail_fade);
			}
		}
		
		// 1C. Бисерные капли, отделившиеся и оставшиеся на стекле в точках остановки капли
		float y_pause1 = -0.15 + 0.26 * 1.35;
		if (drop_y > y_pause1 + 0.04 && y_pause1 > drop_y - trail_len) {
			vec2 pos_b1 = vec2(col_x + get_gentle_drift(y_pause1, h), y_pause1);
			evaluate_droplet_3d(
				p - pos_b1, r_head * 0.32, h * 31.1, 0.12,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
		}
		
		float y_pause2 = -0.15 + 0.52 * 1.35;
		if (drop_y > y_pause2 + 0.04 && y_pause2 > drop_y - trail_len) {
			vec2 pos_b2 = vec2(col_x + get_gentle_drift(y_pause2, h), y_pause2);
			evaluate_droplet_3d(
				p - pos_b2, r_head * 0.26, h * 53.7, 0.08,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
		}
		
		float y_pause3 = -0.15 + 0.78 * 1.35;
		if (drop_y > y_pause3 + 0.04 && y_pause3 > drop_y - trail_len) {
			vec2 pos_b3 = vec2(col_x + get_gentle_drift(y_pause3, h), y_pause3);
			evaluate_droplet_3d(
				p - pos_b3, r_head * 0.20, h * 79.3, 0.05,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
		}
	}

	// =========================================================================
	// 2. СТАТИЧНЫЕ КАПЛИ И КОНДЕНСАТ (РАВНОМЕРНО ПО ВСЕМУ ЭКРАНУ)
	// =========================================================================
	// 2A. Крупные и средние покоящиеся капли с гравитационным провисанием
	float cell_size_m = 0.060;
	vec2 cell_id_m = floor(p / cell_size_m);
	float h_m = hash12(cell_id_m + 3.7);
	
	if (h_m > 0.42) {
		vec2 center_d = (hash22(cell_id_m + 1.9) - 0.5) * 0.58;
		vec2 drop_center_abs = (cell_id_m + 0.5 + center_d) * cell_size_m;
		
		float is_cleared = get_rivulet_clearing_at(drop_center_abs, t, aspect.x);
		if (is_cleared < 0.35) {
			vec2 gv = fract(p / cell_size_m) - 0.5;
			vec2 d_iso = (gv - center_d) * cell_size_m;
			
			float r = 0.0092 * (0.55 + 0.55 * hash12(cell_id_m + 8.1)) * (1.0 - is_cleared);
			evaluate_droplet_3d(
				d_iso, r, h_m * 41.3, 0.22,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
			
			// Слившиеся капли-близнецы (двойные капли арахисовой формы)
			if (h_m > 0.78) {
				vec2 twin_offset = vec2(0.006 * sin(h_m * 12.0), 0.007 * cos(h_m * 12.0));
				evaluate_droplet_3d(
					d_iso - twin_offset, r * 0.68, h_m * 67.2, 0.15,
					total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
					total_fresnel, meniscus, caustic, total_shadow
				);
			}
		}
	}

	// 2B. Мелкие капли (размер ячейки 0.028x0.028)
	float cell_size_f = 0.028;
	vec2 cell_id_f = floor(p / cell_size_f);
	float h_f = hash12(cell_id_f + 7.3);
	
	if (h_f > 0.38) {
		vec2 center_d_f = (hash22(cell_id_f + 4.1) - 0.5) * 0.58;
		vec2 drop_center_f_abs = (cell_id_f + 0.5 + center_d_f) * cell_size_f;
		
		float is_cleared_f = get_rivulet_clearing_at(drop_center_f_abs, t, aspect.x);
		if (is_cleared_f < 0.35) {
			vec2 gv_f = fract(p / cell_size_f) - 0.5;
			vec2 d_iso_f = (gv_f - center_d_f) * cell_size_f;
			
			float r_f = 0.0042 * (0.60 + 0.40 * h_f) * (1.0 - is_cleared_f);
			evaluate_droplet_3d(
				d_iso_f, r_f, h_f * 91.5, 0.08,
				total_normal, drop_mask, total_spec, total_neon_spec, total_cyan_spec,
				total_fresnel, meniscus, caustic, total_shadow
			);
		}
	}

	// 2C. Микро-роса конденсата (бархатистая россыпь)
	float cell_size_dew = 0.014;
	vec2 cell_id_dew = floor(p / cell_size_dew);
	float h_dew = hash12(cell_id_dew + 15.2);
	if (h_dew > 0.65) {
		vec2 center_d_dew = (hash22(cell_id_dew + 9.8) - 0.5) * 0.55;
		vec2 gv_dew = fract(p / cell_size_dew) - 0.5;
		vec2 d_iso_dew = (gv_dew - center_d_dew) * cell_size_dew;
		float dist_dew = length(d_iso_dew);
		float r_dew = 0.0016 * (0.7 + 0.3 * h_dew) * (1.0 - total_cleared);
		if (dist_dew < r_dew) {
			float dew_alpha = smoothstep(r_dew, r_dew * 0.4, dist_dew) * (1.0 - total_cleared);
			vec2 n_dew = (d_iso_dew / max(dist_dew, 0.0001)) * dew_alpha;
			total_normal += n_dew * 0.25;
			total_spec += dew_alpha * 0.6;
			drop_mask = max(drop_mask, dew_alpha * 0.4);
		}
	}

	// =========================================================================
	// 3. ОПТИЧЕСКИЙ РЕНДЕРИНГ И КОМПОЗИЦИЯ
	// =========================================================================
	// Фоновый ночной город за окном
	vec3 city_bg = sample_city_backdrop(uv, t, total_flicker);
	
	// Ливень в воздухе на улице за стеклом
	float streaks = background_rain_streaks(uv, t) * rain_intensity;
	vec3 streak_color = mix(vec3(0.55, 0.70, 0.88), city_glow_cyan.rgb, 0.4);
	city_bg += streak_color * streaks * 0.35;

	// Физическое преломление света линзой капли воды с хроматической аберрацией (дисперсией):
	// n(красный) ~ 1.331, n(зеленый) ~ 1.333, n(синий) ~ 1.338
	vec2 refr_base = uv - total_normal * 0.065;
	vec2 refr_r = uv - total_normal * 0.060;
	vec2 refr_g = refr_base;
	vec2 refr_b = uv - total_normal * 0.071;

	vec3 drop_city = vec3(
		sample_city_backdrop(refr_r, t, total_flicker).r,
		sample_city_backdrop(refr_g, t, total_flicker).g,
		sample_city_backdrop(refr_b, t, total_flicker).b
	);
	drop_city += streak_color * background_rain_streaks(refr_g, t) * 0.4;

	// Контактная тень под каплей (ambient occlusion)
	drop_city *= (1.0 - total_shadow * 0.65);

	// Тёмный контур полного внутреннего отражения (TIR мениск)
	drop_city = mix(drop_city, drop_city * 0.12, meniscus * 0.90);
	
	// Внутренний каустический световой фокус
	drop_city += (city_glow_cyan.rgb * 0.80 + vec3(0.35, 0.32, 0.25)) * caustic;
	
	// Зеркальный блик верхнего света (холодный белый с легким циановым оттенком)
	vec3 spec_glow = mix(vec3(1.0), city_glow_cyan.rgb, 0.20) * total_spec;
	drop_city += spec_glow;

	// Вторичный неоновый блик от вывески отеля слева
	vec3 neon_spec_glow = city_glow_magenta.rgb * total_neon_spec * total_flicker;
	drop_city += neon_spec_glow;

	// Третичный циановый блик от огней города справа
	vec3 cyan_spec_glow = city_glow_cyan.rgb * total_cyan_spec;
	drop_city += cyan_spec_glow;

	// Стеклянный ободок Френеля на границе капли
	vec3 fresnel_glow = mix(vec3(0.9, 0.95, 1.0), city_glow_cyan.rgb, 0.35) * total_fresnel * 0.55;
	drop_city += fresnel_glow;

	// Смешивание капель с фоном стекла
	vec3 final_color = mix(city_bg, drop_city, drop_mask);

	// Тонкий отблеск на водных бортиках протёртой полосы
	final_color += (city_glow_cyan.rgb * 0.35 + vec3(0.18)) * total_sheen;
	
	// Легкое отражение неона на влажной поверхности стекла
	vec3 glass_reflection = mix(city_glow_cyan.rgb, city_glow_magenta.rgb, 0.5 + 0.5 * sin(t * 1.5)) * 0.040 * total_flicker;
	final_color += glass_reflection;

	// Нуарная виньетка
	float vignette = smoothstep(1.35, 0.35, length(uv - vec2(0.5, 0.5)));
	final_color *= vignette;

	// Финальная альфа для прозрачности слоя над подложкой
	float alpha = clamp(0.78 + drop_mask * 0.22 + streaks * 0.15, 0.0, 0.98);

	COLOR = vec4(final_color, alpha);
}



