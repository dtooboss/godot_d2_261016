extends Node2D

func _ready() -> void:
	print("[ClassicGemPreview] 正在渲染【原版经典底座架构 + 用户指定深红宝石 + 镜像深蓝宝石 + 方案二黑铁暗金底座】...")
	
	var bg = ColorRect.new()
	bg.size = Vector2(960, 540)
	bg.color = Color(0.04, 0.035, 0.035, 1.0)
	add_child(bg)
	
	var title = Label.new()
	title.text = "【暗黑 2 状态球终极装配】实机效果验证"
	title.position = Vector2(40, 20)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	add_child(title)
	
	var sub = Label.new()
	sub.text = "左侧生命球 (深红花窗切面 + 正向黑铁暗金底座) | 右侧法力球 (水平镜像切面 + 镜像黑铁暗金底座，严丝合缝无悬空)"
	sub.position = Vector2(40, 48)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	add_child(sub)
	
	# 创建三个状态列：满血 (100%)、战斗中 (55%)、残血 (25%)
	var cases = [
		{ "title": "满充盈态 (100%)", "hp_val": 350, "hp_max": 350, "mp_val": 180, "mp_max": 180, "x": 60 },
		{ "title": "战斗损耗 (55%)", "hp_val": 192, "hp_max": 350, "mp_val": 95, "mp_max": 180, "x": 370 },
		{ "title": "危险残血 (25%)", "hp_val": 88, "hp_max": 350, "mp_val": 36, "mp_max": 180, "x": 680 },
	]
	
	for c in cases:
		var cx = c["x"]
		var h = Label.new()
		h.text = c["title"]
		h.position = Vector2(cx + 20, 85)
		h.add_theme_font_size_override("font_size", 14)
		h.add_theme_color_override("font_color", Color(1.0, 0.90, 0.6))
		add_child(h)
		
		# 红球 (经典切面组件，使用 hp_bar_fill.png)
		var hp_bar = _build_classic_gem_bar("ruby", c["hp_val"], c["hp_max"], false)
		hp_bar.position = Vector2(cx + 10, 130)
		add_child(hp_bar)
		
		# 蓝球 (经典切面组件，使用 mp_bar_fill.png，底座水平翻转)
		var mp_bar = _build_classic_gem_bar("sapphire", c["mp_val"], c["mp_max"], true)
		mp_bar.position = Vector2(cx + 10, 320)
		add_child(mp_bar)

	for i in range(15):
		await get_tree().process_frame

	await get_tree().create_timer(0.3).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://classic_new_gem_preview.png")
	print("[ClassicGemPreview] 成功导出: classic_new_gem_preview.png")
	get_tree().quit(0)

func _build_classic_gem_bar(gem_type: String, cur: int, maximum: int, is_mirrored: bool) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(130, 130)
	root.size = Vector2(130, 130)
	
	var is_ruby = (gem_type == "ruby")
	var under_tex = load("res://assets/images/hp_bar_under.png" if is_ruby else "res://assets/images/mp_bar_under.png")
	var prog_tex = load("res://assets/images/hp_bar_fill.png" if is_ruby else "res://assets/images/mp_bar_fill.png")
	var base_tex = load("res://assets/images/bar_base.png")
	
	# 1. 经典 TextureProgressBar (从下往上充盈裁剪)
	var bar = TextureProgressBar.new()
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.texture_under = under_tex
	bar.texture_progress = prog_tex
	bar.scale = Vector2(0.25, 0.25)
	bar.max_value = float(maximum)
	bar.value = float(cur)
	bar.position = Vector2(1, 1)
	root.add_child(bar)
	
	# 2. 方案二 黑铁暗金雕边底座
	var base_rect = TextureRect.new()
	base_rect.texture = base_tex
	base_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_rect.size = Vector2(148, 50)
	if not is_mirrored:
		base_rect.position = Vector2(-8, 80)
	else:
		base_rect.scale = Vector2(-1, 1)
		base_rect.position = Vector2(138, 80)
	root.add_child(base_rect)
	
	# 3. 药水存量提示徽章 (仅红球)
	if is_ruby:
		var pot = Label.new()
		pot.text = "🧪3"
		pot.position = Vector2(4, 82)
		pot.add_theme_font_size_override("font_size", 10)
		pot.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		root.add_child(pot)
	
	# 4. 原版经典数值底框 (PanelContainer + Label)
	var num_panel = PanelContainer.new()
	num_panel.position = Vector2(30, 96)
	num_panel.custom_minimum_size = Vector2(70, 18)
	var num_sb = StyleBoxFlat.new()
	num_sb.bg_color = Color(0.04, 0.04, 0.04, 0.90)
	num_sb.border_width_left = 1; num_sb.border_width_top = 1; num_sb.border_width_right = 1; num_sb.border_width_bottom = 1
	num_sb.border_color = Color(0.48, 0.40, 0.22, 0.75)
	num_sb.corner_radius_top_left = 3; num_sb.corner_radius_top_right = 3; num_sb.corner_radius_bottom_right = 3; num_sb.corner_radius_bottom_left = 3
	num_panel.add_theme_stylebox_override("panel", num_sb)
	
	var lbl = Label.new()
	var pct = int(float(cur) / float(maximum) * 100.0)
	lbl.text = "%d/%d(%d%%)" % [cur, maximum, pct]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.85) if is_ruby else Color(0.85, 0.92, 1.0))
	num_panel.add_child(lbl)
	root.add_child(num_panel)
	
	return root
