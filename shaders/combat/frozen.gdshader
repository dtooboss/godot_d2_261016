shader_type canvas_item;

// 冰冻结霜着色器 (Frozen)
// 参考 GODOT-VFX-LIBRARY/shaders/frozen.gdshader
uniform float freeze_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ice_color : source_color = vec4(0.35, 0.78, 1.0, 1.0);
uniform float crystal_intensity : hint_range(0.0, 1.0) = 0.4;

float pseudo_noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.01) {
        discard;
    }
    
    // 程序化冰晶微粒噪波
    float n = pseudo_noise(floor(UV * 40.0) + vec2(TIME * 0.1, 0.0));
    vec3 frozen_rgb = mix(tex_color.rgb, ice_color.rgb, freeze_amount * 0.65);
    frozen_rgb += ice_color.rgb * n * crystal_intensity * freeze_amount;
    
    COLOR = vec4(frozen_rgb, tex_color.a);
}
