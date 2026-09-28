extends Control

func _ready() -> void:
	print("[TestRender] 正在使用 Godot 引擎离屏渲染全新 3D 血球与底座...")
	
	size = Vector2(960, 540)
	
	# 1. 真实 ACT 1 战斗地表背景
	var bg = TextureRect.new()
	bg.texture = load("res://mods/vanilla/assets/worlds/1/1.png")
	bg.size = Vector2(960, 540)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	# 2. 标题提示
	var lbl = Label.new()
	lbl.text = "【方案 1 实机渲染】原创黑铁魔爪托座 + 3D 凸透镜厚玻璃血球 (100% 满血 / 50% 受创 / 20% 濒血)"
	lbl.position = Vector2(40, 30)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	add_child(lbl)
	
	# 创建 3 个不同状态的血球对比
	var shader = load("res://shaders/globe_3d_sphere.gdshader")
	var tex_frame = load("res://assets/images/cradle/hp_cradle_frame.png")
	var tex_shadow = load("res://assets/images/cradle/globe_shadow.png")
	var tex_glow = load("res://assets/images/cradle/globe_glow_red.png")
	
	var fills = [1.0, 0.50, 0.20]
	var ghosts = [1.0, 0.65, 0.20]
	var positions_x = [70, 370, 670]
	
	for i in range(3):
		var fill = fills[i]
		var ghost = ghosts[i]
		var base_x = positions_x[i]
		var base_y = 140
		
		# 组装容器
		var assembly = Control.new()
		assembly.position = Vector2(base_x, base_y)
		assembly.scale = Vector2(0.24, 0.24) # 1024 * 0.24 = 245px
		add_child(assembly)
		
		# Layer 1: 接触投影
		var shadow_rect = TextureRect.new()
		shadow_rect.texture = tex_shadow
		shadow_rect.size = Vector2(1024, 1024)
		assembly.add_child(shadow_rect)
		
		# Layer 2: 环境微光漫射
		var glow_rect = TextureRect.new()
		glow_rect.texture = tex_glow
		glow_rect.size = Vector2(1024, 1024)
		glow_rect.modulate = Color(1, 1, 1, 0.40 + fill * 0.60)
		assembly.add_child(glow_rect)
		
		# Layer 3: 核心 3D 凸透镜厚玻璃球体
		var globe_rect = ColorRect.new()
		globe_rect.position = Vector2(229, 164)
		globe_rect.size = Vector2(552, 552)
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("fill_ratio", fill)
		mat.set_shader_parameter("ghost_ratio", ghost)
		mat.set_shader_parameter("wave_amplitude", 0.014 if fill < 0.9 else 0.007)
		globe_rect.material = mat
		assembly.add_child(globe_rect)
		
		# Layer 4: 黑铁魔爪托架与前后包裹
		var frame_rect = TextureRect.new()
		frame_rect.texture = tex_frame
		frame_rect.size = Vector2(1024, 1024)
		assembly.add_child(frame_rect)
		
		# Layer 5: 数值胶囊
		var badge = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.045, 0.04, 0.88)
		style.border_color = Color(0.65, 0.52, 0.25, 0.85)
		style.border_width_bottom = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		badge.add_theme_stylebox_override("panel", style)
		
		var b_lbl = Label.new()
		var cur_hp = int(round(162 * fill))
		b_lbl.text = " %d/162(%d%%) " % [cur_hp, int(fill * 100)]
		b_lbl.add_theme_font_size_override("font_size", 12)
		b_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.85))
		b_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		badge.add_child(b_lbl)
		
		# 胶囊放置在爪托下方正中
		badge.position = Vector2(base_x + 68, base_y + 208)
		add_child(badge)

	for f in range(25):
		await get_tree().process_frame

	await get_tree().create_timer(0.3).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/godot_real_render_opt1.png")
	print("[TestRender] 成功导出 Godot 真机渲染图: godot_real_render_opt1.png")
	get_tree().quit(0)
