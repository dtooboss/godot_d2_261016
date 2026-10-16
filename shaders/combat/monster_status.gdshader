shader_type canvas_item;

// 怪物多重综合状态着色器 2.0 (暗黑2高保真冷暖色相映射引擎)
// 坚决杜绝低频量化方块与马赛克！完好保留怪物高清原画的骨骼、毛发、肌肉全部细节

// 1. 受击闪白参数
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 2. 冰冻霜蓝调色板映射 (Dark Gothic Cold Tint: 琉璃冰晶通透感)
uniform float freeze_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cold_deep : source_color = vec3(0.05, 0.18, 0.45);
uniform vec3 cold_mid : source_color = vec3(0.28, 0.68, 0.98);
uniform vec3 cold_bright : source_color = vec3(0.85, 0.95, 1.15);

// 3. 剧毒 DoT 参数 (Dark Gothic Poison Tint: 幽毒墨绿脉冲)
uniform float poison_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 poison_deep : source_color = vec3(0.04, 0.20, 0.06);
uniform vec3 poison_bright : source_color = vec3(0.35, 1.0, 0.38);
uniform float poison_pulse_speed : hint_range(0.0, 10.0) = 3.5;

// 4. 死亡消融参数 (平滑垂直灰烬燃烧)
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.38, 0.08, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.01) {
        discard;
    }
    
    vec3 result_rgb = tex_color.rgb;
    float result_alpha = tex_color.a;
    
    // 计算原始画面感知亮度 (Rec.709 真实心理学人眼感知亮度)
    float luma = dot(result_rgb, vec3(0.2126, 0.7152, 0.0722));

    // A. 暗黑2原生冰冻调色板映射 (保留全部原画高光与暗影细节，零马赛克)
    if (freeze_amount > 0.001) {
        // 双阶高通透冰蓝色阶
        vec3 cold_ramp = luma < 0.45 
            ? mix(cold_deep, cold_mid, luma / 0.45) 
            : mix(cold_mid, cold_bright, (luma - 0.45) / 0.55);
            
        // 将原画明暗细节与冰霜色阶柔和融合，展现冰晶雕塑质感
        vec3 frosted = mix(result_rgb * cold_ramp * 1.35, cold_ramp, 0.42);
        result_rgb = mix(result_rgb, frosted, freeze_amount * 0.85);
    }
    
    // B. 暗黑2原生剧毒色阶映射
    if (poison_amount > 0.001) {
        float pulse = sin(TIME * poison_pulse_speed) * 0.25 + 0.75;
        vec3 p_ramp = mix(poison_deep, poison_bright, luma);
        vec3 poisoned = mix(result_rgb * p_ramp * 1.4, p_ramp, 0.38);
        result_rgb = mix(result_rgb, poisoned, poison_amount * pulse * 0.80);
    }
    
    // C. 受击纯白闪光覆盖 (置于所有状态之上，瞬间白炽高能)
    if (flash_amount > 0.001) {
        result_rgb = mix(result_rgb, flash_color.rgb, flash_amount);
    }
    
    // D. 死亡消融：平滑高频向上燃烧侵蚀 (彻底杜绝粗糙低频大方块)
    if (dissolve_amount > 0.001) {
        float burn_factor = UV.y * 0.65 + sin(UV.x * 24.0 + UV.y * 30.0) * 0.07 + sin(UV.x * 48.0 - UV.y * 18.0) * 0.035;
        float progress = dissolve_amount * 1.35;
        float edge_w = 0.09;
        
        float alpha_mask = smoothstep(progress - edge_w, progress, burn_factor);
        float edge = smoothstep(progress - edge_w, progress, burn_factor) * (1.0 - smoothstep(progress, progress + edge_w * 0.45, burn_factor));
        
        result_rgb = mix(result_rgb, dissolve_edge_color.rgb * 1.8, edge * 2.2);
        result_alpha *= (1.0 - alpha_mask);
    }

    COLOR = vec4(result_rgb, result_alpha);
}
