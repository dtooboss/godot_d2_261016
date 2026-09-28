extends Node2D

func _ready() -> void:
	print("[3DCompare] 正在渲染【扁平平面感】与【真正 3D 凸透镜厚重立体感】横向对比...")
	
	var bg = ColorRect.new()
	bg.size = Vector2(980, 560)
	bg.color = Color(0.04, 0.035, 0.035, 1.0)
	add_child(bg)
	
	var title = Label.new()
	title.text = "立体感重塑深度剖析：【原版 2D 扁平贴图感】 VS 【真正 3D 球面透镜厚重感】"
	title.position = Vector2(40, 20)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	add_child(title)
	
	var sub = Label.new()
	sub.text = "对比左侧（二维平面纸片感）与右侧（具备 3D 半球面法线高光、厚玻璃凸透镜折射、切面坚挺骨架与边缘强纵深）："
	sub.position = Vector2(40, 48)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	add_child(sub)
	
	var flat_shader = load("res://shaders/globe_liquid.gdshader")
	var true3d_shader = load("res://shaders/globe_true_3d.gdshader")
	
	var columns = [
		{
			"shader": flat_shader,
			"title": "❌ 优化前：二维平面感 (缺乏立体感)",
			"desc": "波浪为平面直线剪切、无厚度高光、无透镜畸变，像贴在圆圈里的 2D 壁纸",
			"x": 100,
			"is_3d": false
		},
		{
			"shader": true3d_shader,
			"title": "✨ 升级后：真正 3D 凸透镜厚重水晶球",
			"desc": "真正 3D 球面法线高光、切面棱镜多面受光、凸透镜折射曲面波浪、边缘菲涅尔深邃纵深",
			"x": 540,
			"is_3d": true
		}
	]
	
	for col in columns:
		var cx = col["x"]
		var h = Label.new()
		h.text = col["title"]
		h.position = Vector2(cx, 85)
		h.add_theme_font_size_override("font_size", 15)
		h.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5) if not col["is_3d"] else Color(0.5, 0.95, 0.6))
		add_child(h)
		
		var d = Label.new()
		d.text = col["desc"]
		d.position = Vector2(cx, 110)
		d.size = Vector2(340, 36)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.60, 0.55, 0.50))
		add_child(d)
		
		# 红球 (HP 65%)
		var hp_g = _build_node(col["shader"], 0.65, Color(0.88, 0.06, 0.06), Color(1.0, 0.55, 0.55), Color(0.12, 0.01, 0.02), "227 / 350", col["is_3d"])
		hp_g.position = Vector2(cx + 80, 160)
		add_child(hp_g)
		
		# 蓝球 (MP 65%)
		var mp_g = _build_node(col["shader"], 0.65, Color(0.10, 0.45, 0.95), Color(0.65, 0.88, 1.0), Color(0.02, 0.06, 0.20), "117 / 180", col["is_3d"])
		mp_g.position = Vector2(cx + 80, 340)
		add_child(mp_g)

	for i in range(15):
		await get_tree().process_frame

	await get_tree().create_timer(0.5).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://depth_3d_comparison.png")
	print("[3DCompare] 成功导出立体感横向对比图: depth_3d_comparison.png")
	get_tree().quit(0)

func _build_node(shader: Shader, fill: float, pri: Color, acc: Color, dark: Color, num_str: String, is_3d: bool) -> Control:
	var root = Control.new()
	var sz = 140.0
	root.custom_minimum_size = Vector2(sz, sz)
	root.size = Vector2(sz, sz)
	
	var claw_c = ColorRect.new()
	claw_c.position = Vector2(sz * 0.5 - 10, sz - 4)
	claw_c.size = Vector2(20, 4)
	claw_c.color = Color(0.45, 0.35, 0.18, 0.85)
	root.add_child(claw_c)
	
	var g = ColorRect.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fill_ratio", fill)
	mat.set_shader_parameter("primary_color", pri)
	mat.set_shader_parameter("accent_color", acc)
	mat.set_shader_parameter("dark_color", dark)
	g.material = mat
	root.add_child(g)
	
	var panel = PanelContainer.new()
	panel.position = Vector2(sz * 0.5 - 40, sz * 0.68)
	panel.custom_minimum_size = Vector2(80, 18)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.70)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.40, 0.35, 0.22, 0.50)
	sb.corner_radius_top_left = 9; sb.corner_radius_top_right = 9; sb.corner_radius_bottom_left = 9; sb.corner_radius_bottom_right = 9
	panel.add_theme_stylebox_override("panel", sb)
	
	var lbl = Label.new()
	lbl.text = num_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.82) if pri.r > 0.5 else Color(0.85, 0.92, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(lbl)
	root.add_child(panel)
	
	return root
