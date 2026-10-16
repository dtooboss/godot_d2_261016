shader_type canvas_item;

// 中毒剧毒着色器 (Poison)
// 参考 GODOT-VFX-LIBRARY/shaders/poison.gdshader
uniform float poison_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 poison_color : source_color = vec4(0.25, 0.95, 0.28, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.01) {
        discard;
    }
    
    // 脉冲式毒素浸润
    float pulse = sin(TIME * pulse_speed) * 0.4 + 0.6;
    float intensity = poison_amount * pulse * 0.75;
    vec3 poisoned_rgb = mix(tex_color.rgb, poison_color.rgb, intensity);
    
    COLOR = vec4(poisoned_rgb, tex_color.a);
}
