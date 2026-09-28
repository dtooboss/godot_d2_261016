shader_type canvas_item;

// 3-A 现代暗黑流体水晶球专用着色器 (浓稠流体 + 极细发丝级暗金刃环)
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 primary_color : source_color = vec4(0.85, 0.08, 0.08, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.45, 0.45, 1.0);
uniform vec4 dark_color : source_color = vec4(0.18, 0.02, 0.04, 1.0);
uniform float ring_width : hint_range(0.005, 0.04) = 0.014;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	float dist = length(uv - center);
	
	// 圆形边缘抗锯齿遮罩
	float outer_r = 0.495;
	float alpha = 1.0 - smoothstep(outer_r - 0.005, outer_r, dist);
	if (alpha <= 0.001) {
		discard;
	}
	
	// 极细发丝级暗金刃边 (1~1.5px)
	float inner_r = outer_r - ring_width;
	
	if (dist > inner_r) {
		float ring_norm = (dist - inner_r) / ring_width;
		float bevel = sin(ring_norm * 3.14159);
		vec3 g_base = vec3(0.52, 0.42, 0.22);
		vec3 g_hi = vec3(0.88, 0.75, 0.40);
		vec3 g_sh = vec3(0.18, 0.12, 0.06);
		vec3 col = mix(g_sh, g_base, bevel);
		if (uv.y < 0.5) {
			col += (0.5 - uv.y) * 0.25 * g_hi;
		}
		COLOR = vec4(col, alpha);
	} else {
		vec2 p = (uv - center) / inner_r;
		float p_dist = length(p);
		
		// 鲜血与魔力微浪动态
		float wave = sin(uv.x * 14.0 + TIME * 2.8) * 0.018 + cos(uv.x * 9.0 - TIME * 2.2) * 0.010;
		float water_y = (1.0 - fill_ratio) + wave;
		
		vec3 inner_col = vec3(0.0);
		
		if (uv.y < water_y) {
			// 水面以上：深邃通透的黑曜石玻璃腔体
			vec3 glass_dark = vec3(0.035, 0.030, 0.035);
			float glass_spec = smoothstep(0.40, 0.0, length(uv - vec2(0.32, 0.28))) * 0.38;
			float fresnel = smoothstep(0.65, 1.0, p_dist) * 0.12;
			inner_col = glass_dark + vec3(glass_spec) + fresnel * primary_color.rgb * 0.25;
		} else if (uv.y < water_y + 0.018) {
			// 水面微浪晶莹浮沫光线
			inner_col = accent_color.rgb * 1.30;
		} else {
			// 水面以下：浓稠鲜血 / 奥术能量流
			vec2 flow_uv = p * 2.2 + vec2(TIME * 0.14, -TIME * 0.09);
			float n = fbm(flow_uv);
			float n2 = fbm(flow_uv * 1.8 + vec2(n));
			
			vec3 blood = mix(dark_color.rgb * 0.75, primary_color.rgb, n);
			blood = mix(blood, accent_color.rgb, n2 * 0.42);
			float vein = smoothstep(0.48, 0.52, abs(n2 - 0.5));
			blood += accent_color.rgb * vein * 0.38;
			
			blood *= (1.1 - p_dist * 0.5);
			inner_col = blood;
		}
		
		// 残血心跳呼吸脉冲
		if (fill_ratio < 0.25) {
			float pulse = (sin(TIME * 6.5) + 1.0) * 0.5;
			float edge_alert = smoothstep(0.6, 1.0, p_dist);
			inner_col += vec3(0.85, 0.1, 0.1) * (edge_alert * pulse * 0.65);
		}
		
		COLOR = vec4(inner_col, alpha);
	}
}
