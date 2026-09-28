shader_type canvas_item;

// 屏幕纹理与黑白灰度、微暗调参数
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float gray_amount : hint_range(0.0, 1.0) = 1.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	// 经典人眼感知亮度灰度加权 (Rec. 601)
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(c.rgb, vec3(gray), gray_amount);
	// 混合暗化并保留原始 alpha
	COLOR = vec4(desaturated * (1.0 - darkness * gray_amount), c.a);
}
