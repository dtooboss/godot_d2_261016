shader_type canvas_item;

// 暗黑破坏神 2 正统 3D 球面凸透镜厚玻璃血球/法力球着色器
// (高精真实流体贴图驱动 + 动态呼吸对流 + 半透明通透厚玻璃空腔 + 晶莹高光)
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float ghost_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.007;
uniform float wave_frequency : hint_range(1.0, 30.0) = 14.0;
uniform float wave_speed : hint_range(0.5, 15.0) = 4.5;

// 高精流体贴图 (血浆 / 奥术法力)
uniform sampler2D fluid_texture : filter_linear, repeat_disable;

uniform vec4 primary_color : source_color = vec4(0.85, 0.06, 0.08, 1.0); // 调色/流体边缘色
uniform vec4 accent_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);  // 浪花高亮色
uniform vec4 dark_color : source_color = vec4(0.18, 0.015, 0.025, 1.0);  // 深渊暗部色

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	vec2 p = (uv - center) * 2.0; // 归一化到 [-1.0, 1.0]
	float r2 = dot(p, p);
	
	// 圆形边缘超细抗锯齿 (极其干净锐利的厚玻璃球轮廓，绝不发虚羽化)
	float radius = 0.985;
	float edge_aa = 0.006;
	float mask = 1.0 - smoothstep(radius - edge_aa, radius, sqrt(r2));
	if (mask <= 0.001) {
		discard;
	}
	
	// 1. 真正 3D 半球面法线 (Z 轴半球曲率)
	float z = sqrt(max(0.0, 1.0 - min(r2, 0.999)));
	vec3 N = normalize(vec3(p.x, p.y, z));
	
	// 2. 凸透镜折射坐标：越往边缘微幅压缩，呈现厚重透镜感
	vec2 refr_p = p * (0.80 + 0.20 * (1.0 - z));
	
	// 3. 3D 曲面液面与微浪模拟 (液面随球面曲率自然下弯)
	float sphere_curvature = (1.0 - z) * 0.16;
	float wave = sin(refr_p.x * (wave_frequency * 0.6) + TIME * wave_speed) * (wave_amplitude * 2.2) +
	             cos(refr_p.x * (wave_frequency * 0.9) - TIME * (wave_speed * 1.2)) * (wave_amplitude * 1.1);
	
	// 将 fill_ratio 映射到 [-1.0, 1.0]
	float water_line = (1.0 - fill_ratio * 2.0) + wave - sphere_curvature;
	float ghost_line = (1.0 - ghost_ratio * 2.0) + wave * 0.5 - sphere_curvature;
	
	// 4. 动态流体对流与呼吸扰动 UV
	vec2 flow_dir1 = vec2(
		sin(p.y * 3.2 + TIME * 0.85) * 0.012 + cos(p.x * 2.8 - TIME * 0.6) * 0.006,
		cos(p.x * 3.5 - TIME * 0.75) * 0.012 + sin(p.y * 2.5 + TIME * 0.5) * 0.006
	);
	vec2 fluid_sample_uv = clamp(uv + flow_dir1, vec2(0.005), vec2(0.995));
	vec4 fluid_tex = texture(fluid_texture, fluid_sample_uv);
	
	// 安全 fallback：若未分配贴图则使用经典颜色
	if (fluid_tex.a < 0.05) {
		fluid_tex = vec4(mix(dark_color.rgb, primary_color.rgb, 0.65), 1.0);
	}
	
	// 5. 3D 光学与精准对齐的晶莹椭圆厚玻璃高光
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	
	// 菲涅尔边缘反光 (轻柔收敛，避免边缘泛光羽化)
	float fresnel = 1.0 - max(0.0, dot(N, view_dir));
	float rim_glow = pow(fresnel, 3.8) * 0.18; // 大幅轻柔化
	float rim_shade = pow(fresnel, 2.2) * 0.35;
	
	// 精准对齐贴图玻璃主高光 (中心坐标 -0.572, -0.429，倾斜椭圆)
	vec2 d_spec = p - vec2(-0.572, -0.429);
	vec2 rot_spec = vec2(d_spec.x * 0.88 + d_spec.y * 0.47, -d_spec.x * 0.47 + d_spec.y * 0.88);
	float spec_dist = length(rot_spec / vec2(0.14, 0.09));
	float spec = smoothstep(1.0, 0.0, spec_dist);
	float spec_soft = smoothstep(1.8, 0.0, spec_dist) * 0.18;
	
	vec3 col = vec3(0.0);
	float out_alpha = mask;
	
	if (p.y < water_line) {
		// == 水面以上：纯净通透半透明厚玻璃空腔 (清澈透出后方托座与暗黑地牢) ==
		vec3 glass_tint = vec3(0.06, 0.07, 0.08); // 纯净冷灰玻璃基底
		
		// 紧贴液面的极微弱水面漫射微光 (仅在水线上方 0.02 极窄边缘)
		float internal_radiance = (1.0 - smoothstep(water_line, water_line + 0.02, p.y)) * 0.08;
		glass_tint += primary_color.rgb * internal_radiance;
		
		// 受创滞后残影 (仅在受到伤害且 ghost_ratio > fill_ratio 时呈现淡血雾)
		float ghost_alpha_boost = 0.0;
		if (ghost_ratio > fill_ratio + 0.01 && p.y >= ghost_line) {
			float ghost_factor = smoothstep(ghost_line, water_line, p.y);
			vec3 ghost_wash = mix(primary_color.rgb * 0.5 + vec3(0.2, 0.15, 0.15), accent_color.rgb, 0.25);
			glass_tint = mix(glass_tint, ghost_wash, 0.50 * ghost_factor);
			ghost_alpha_boost = 0.35 * ghost_factor;
		}
		
		// 玻璃透明度：中心高度通透 (alpha 仅 0.06~0.10)，仅在玻璃高光与极窄边缘处有轻微玻璃厚度感
		float glass_alpha = clamp(0.06 + fresnel * 0.35 + spec * 0.90 + ghost_alpha_boost, 0.0, 1.0);
		out_alpha = mask * glass_alpha;
		
		// 玻璃表面晶莹椭圆主高光与轻微冷色菲涅尔反光
		glass_tint += vec3(1.0, 0.98, 0.95) * (spec * 1.20);
		glass_tint += vec3(0.60, 0.70, 0.85) * (rim_glow * 0.8);
		col = glass_tint;
	} else if (p.y < water_line + 0.035) {
		// == 水面交界：凸透镜弯液面晶莹光带 ==
		float meniscus = (p.y - water_line) / 0.035;
		col = mix(accent_color.rgb * 1.2, fluid_tex.rgb * 1.05, meniscus);
		col += vec3(1.0, 0.98, 0.95) * (spec * 0.4);
		out_alpha = mask * 0.98;
	} else {
		// == 水面以下：浓稠深邃流体主体 (高精真实流体贴图驱动) ==
		vec3 blood = fluid_tex.rgb;
		
		// 保持原生深邃暗红与对流涡流，边缘自然暗沉，绝不泛白光
		blood = blood * (1.0 - rim_shade * 0.25);
		
		// 贴图本身已带有完美椭圆主高光，此处仅叠加极微弱锐利高光
		blood += vec3(1.0, 0.98, 0.95) * (spec * 0.25);
		blood += accent_color.rgb * spec_soft;
		
		// 6. 残血/低法力急促心跳律动 (仅在残存流体内部深处呼吸，绝不污染外层空玻璃)
		if (fill_ratio < 0.22) {
			float pulse = (sin(TIME * 7.5) + 1.0) * 0.5;
			blood += primary_color.rgb * (pulse * 0.35);
		}
		
		col = blood;
		out_alpha = mask * 0.99;
	}
	
	COLOR = vec4(col, out_alpha);
}
