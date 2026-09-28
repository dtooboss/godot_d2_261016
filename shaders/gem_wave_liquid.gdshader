shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float ghost_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.007;
uniform float wave_frequency : hint_range(1.0, 30.0) = 14.0;
uniform float wave_speed : hint_range(0.5, 15.0) = 4.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.45, 0.25, 0.85);
uniform sampler2D tex_under : filter_linear;

void fragment() {
	vec4 fill_col = texture(TEXTURE, UV);
	vec4 under_col = texture(tex_under, UV);
	
	if (fill_col.a < 0.05 && under_col.a < 0.05) {
		COLOR = vec4(0.0);
	} else {
		// 双频正弦波浪叠加
		float wave = sin(UV.x * wave_frequency + TIME * wave_speed) * wave_amplitude +
		             cos(UV.x * wave_frequency * 1.5 - TIME * wave_speed * 1.3) * (wave_amplitude * 0.35);
		
		float water_line = (1.0 - fill_ratio) + wave;
		float ghost_line = (1.0 - ghost_ratio) + wave * 0.5;
		
		vec4 final_col = under_col;
		
		// 1. D2R 受击滞后残影层 (受创时半透明受创血晕)
		if (ghost_ratio > fill_ratio + 0.005 && UV.y >= ghost_line && UV.y < water_line) {
			vec4 ghost_tint = vec4(fill_col.rgb * 0.5 + vec3(0.35, 0.1, 0.1), fill_col.a * 0.85);
			final_col = mix(under_col, ghost_tint, 0.7);
		}
		
		// 2. 真实宝石液体主体
		if (UV.y >= water_line) {
			final_col = fill_col;
		}
		
		// 3. 方案 B 核心: 极细水润微光 (仅约 1~2px 宽)
		float dist = abs(UV.y - water_line);
		if (dist < 0.0045 && fill_ratio > 0.015 && fill_ratio < 0.985) {
			float rim_factor = 1.0 - (dist / 0.0045);
			final_col.rgb = mix(final_col.rgb, final_col.rgb * 1.3 + rim_color.rgb * 0.6, rim_factor * rim_color.a);
		}
		
		final_col.a = max(fill_col.a, under_col.a);
		COLOR = final_col;
	}
}
