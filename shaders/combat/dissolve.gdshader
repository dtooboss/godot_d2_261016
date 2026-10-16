shader_type canvas_item;

// 恶魔消融消散着色器 (Dissolve)
// 参考 GODOT-VFX-LIBRARY/shaders/dissolve.gdshader
// 特性：内置程序化伪噪波，零外部贴图依赖，边缘火烬高亮
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float edge_width : hint_range(0.0, 0.25) = 0.06;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float procedural_noise(vec2 uv) {
    vec2 p = uv * 18.0;
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.01) {
        discard;
    }
    
    float noise = procedural_noise(UV);
    float dissolve_edge = dissolve_amount + edge_width;
    float alpha = smoothstep(dissolve_amount, dissolve_edge, noise);
    
    // 灼烧亮边
    float edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise);
    edge = edge * (1.0 - smoothstep(dissolve_amount + edge_width * 0.5, dissolve_edge, noise));
    
    vec4 final_color = mix(tex_color, edge_color * 1.5, edge);
    COLOR = final_color;
    COLOR.a = tex_color.a * alpha;
}
