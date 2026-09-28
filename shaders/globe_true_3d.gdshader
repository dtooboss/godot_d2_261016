shader_type canvas_item;

// 真正 3D 球面凸透镜法线 + 精密数学切面棱镜折射 + 厚重水晶玻璃球壳着色器
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.65;
uniform vec4 primary_color : source_color = vec4(0.88, 0.06, 0.06, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.55, 0.55, 1.0);
uniform vec4 dark_color : source_color = vec4(0.12, 0.01, 0.02, 1.0);

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
	vec2 p = (uv - center) * 2.0; // [-1.0, 1.0]
	float r2 = dot(p, p);
	
	if (r2 > 1.0) {
		float shadow_dist = sqrt(r2);
		float shadow = (1.0 - smoothstep(1.0, 1.06, shadow_dist)) * 0.45;
		if (shadow <= 0.001) {
			discard;
		}
		COLOR = vec4(0.0, 0.0, 0.0, shadow);
	} else {
		// 极细暗金镶嵌外刃 (半径 0.94 ~ 0.985)
		if (r2 > 0.90) {
			float ring_norm = (sqrt(r2) - 0.948) / 0.038;
			float bevel = sin(clamp(ring_norm, 0.0, 1.0) * 3.14159);
			vec3 g_base = vec3(0.52, 0.42, 0.20);
			vec3 g_hi = vec3(0.95, 0.82, 0.45);
			vec3 g_sh = vec3(0.15, 0.10, 0.05);
			vec3 col = mix(g_sh, g_base, bevel);
			if (p.y < 0.0) {
				col += (-p.y) * 0.35 * g_hi;
			}
			COLOR = vec4(col, 1.0);
		} else {
			// 真正 3D 半球面法线 (Z 轴计算)
			float z = sqrt(max(0.0, 1.0 - r2));
			vec3 N = normalize(vec3(p.x, p.y, z));
			
			// 凸透镜折射 UV 映射 (越到边缘越收缩，产生极强透镜凸起感)
			vec2 refr_uv = p * (0.60 + 0.30 * (1.0 - z));
			
			// 3D 空间曲面波浪
			float sphere_curve = (1.0 - z) * 0.15;
			float wave = sin(p.x * 7.0 + TIME * 2.8) * 0.035 + cos(p.x * 4.5 - TIME * 2.0) * 0.020;
			float water_h = (1.0 - fill_ratio * 2.0) + wave - sphere_curve;
			
			vec3 final_color = vec3(0.0);
			
			// 精密八角切面宝石几何骨架
			vec2 ap = abs(refr_uv);
			float facet_diag = abs(ap.x + ap.y - 0.62);
			float facet_cross = min(abs(ap.x - 0.32), abs(ap.y - 0.32));
			float facet_edge = min(facet_diag, facet_cross);
			
			float facet_id = floor(atan(refr_uv.y, refr_uv.x) * 4.0 / 3.14159 + 4.0);
			float facet_shade = mod(facet_id, 2.0) == 0.0 ? 1.18 : 0.78;
			
			vec2 flow_p = refr_uv * 2.5 + vec2(TIME * 0.15, -TIME * 0.1);
			float flow_n = fbm(flow_p);
			
			if (p.y < water_h) {
				// 水面以上：深邃通透的黑曜石厚玻璃暗腔
				vec3 glass_dark = vec3(0.03, 0.025, 0.03);
				float internal_glow = (1.0 - smoothstep(water_h, water_h + 0.6, p.y)) * 0.25;
				glass_dark += primary_color.rgb * internal_glow;
				final_color = glass_dark;
			} else if (p.y < water_h + 0.045) {
				// 水面微浪高光折射晶莹光带
				float foam_mix = (p.y - water_h) / 0.045;
				final_color = mix(accent_color.rgb * 1.45, primary_color.rgb * 1.2, foam_mix);
			} else {
				// 水面以下：坚挺 3D 精密宝石切面 + 流体生命能量
				vec3 gem_core = mix(dark_color.rgb, primary_color.rgb, facet_shade);
				gem_core = mix(gem_core, accent_color.rgb * 0.85, flow_n * 0.32);
				float shine = (1.0 - smoothstep(0.0, 0.038, facet_edge)) * 0.58;
				gem_core += accent_color.rgb * shine;
				
				float core_focus = smoothstep(0.8, 0.0, length(refr_uv)) * 0.35;
				gem_core += primary_color.rgb * core_focus;
				final_color = gem_core;
			}
			
			// 3D 球面光学叠加
			vec3 light_dir = normalize(vec3(-0.45, -0.55, 0.70));
			float diffuse = max(0.0, dot(N, light_dir));
			
			vec3 view_dir = vec3(0.0, 0.0, 1.0);
			vec3 half_v = normalize(light_dir + view_dir);
			float spec = pow(max(0.0, dot(N, half_v)), 28.0); // 玻璃球顶强高光
			float spec_soft = pow(max(0.0, dot(N, half_v)), 7.0) * 0.25;
			
			// 边缘菲涅尔强暗角 (产生向后凹缩的强烈体积感)
			float fresnel = 1.0 - max(0.0, dot(N, view_dir));
			float rim_shade = pow(fresnel, 2.2) * 0.60;
			
			vec3 bounce_dir = normalize(vec3(0.2, 0.8, 0.3));
			float bounce = max(0.0, dot(N, bounce_dir)) * 0.15;
			
			final_color = final_color * (0.68 + 0.32 * diffuse) * (1.0 - rim_shade);
			final_color += vec3(0.95, 0.90, 0.82) * spec * 0.90;
			final_color += accent_color.rgb * spec_soft;
			final_color += primary_color.rgb * bounce;
			
			if (fill_ratio < 0.25) {
				float pulse = (sin(TIME * 6.5) + 1.0) * 0.5;
				float alert = smoothstep(0.4, 0.95, fresnel);
				final_color += vec3(0.9, 0.08, 0.08) * (alert * pulse * 0.75);
			}
			
			COLOR = vec4(final_color, 1.0);
		}
	}
}
