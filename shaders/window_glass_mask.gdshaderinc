// Glass openings traced against apartment_night.png (1672 x 941).
// Both rain passes share this exact mask. Coordinates deliberately sit inside
// the weathered frame, sloping crossbars, lower rails and curtain boundary.
uniform bool window_mask_enabled = false;

float glass_edge(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	return (edge.x * (p.y - a.y) - edge.y * (p.x - a.x)) / length(edge);
}

float glass_quad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	float inset = min(min(glass_edge(p, a, b), glass_edge(p, b, c)),
		min(glass_edge(p, c, d), glass_edge(p, d, a)));
	return smoothstep(0.0, 1.5, inset);
}

float window_glass_mask(vec2 screen_uv) {
	if (!window_mask_enabled) { return 1.0; }
	vec2 p = screen_uv * vec2(1672.0, 941.0);
	float top_left = glass_quad(p, vec2(1016.0,-8.0), vec2(1218.0,-8.0), vec2(1218.0,66.0), vec2(1012.0,96.0));
	float lower_left = glass_quad(p, vec2(1000.0,142.0), vec2(1218.0,112.0), vec2(1218.0,621.0), vec2(992.0,584.0));
	float top_right = glass_quad(p, vec2(1294.0,-8.0), vec2(1479.0,-8.0), vec2(1481.0,30.0), vec2(1294.0,58.0));
	float lower_right = glass_quad(p, vec2(1296.0,108.0), vec2(1488.0,78.0), vec2(1530.0,667.0), vec2(1303.0,638.0));
	return max(max(top_left, lower_left), max(top_right, lower_right));
}
