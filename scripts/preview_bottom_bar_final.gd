extends Node2D

func _ready() -> void:
	print("[BottomBarFinal] 正在渲染游戏真实底栏完整实机画面...")
	
	var bg = ColorRect.new()
	bg.size = Vector2(960, 540)
	bg.color = Color(0.06, 0.05, 0.05, 1.0)
	add_child(bg)
	
	# 模拟游戏背景氛围
	var hint = Label.new()
	hint.text = "【游戏实机底栏装配效果】生命球与法力球正式落地"
	hint.position = Vector2(40, 40)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	add_child(hint)
	
	var desc = Label.new()
	desc.text = "包含：全新深邃哥特切面红宝石 + 方案二黑铁暗金雕边底座 + 水平镜像法力蓝宝石 + 同步暗金数值胶囊"
	desc.position = Vector2(40, 75)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	add_child(desc)
	
	# 实例化真实底栏
	var bar_scene = load("res://scenes/afk/components/player_bottom_bar.tscn")
	var bar_inst = bar_scene.instantiate()
	# 居中放置在底部
	bar_inst.position = Vector2(480, 500)
	add_child(bar_inst)
	
	for i in range(20):
		await get_tree().process_frame

	await get_tree().create_timer(0.4).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://bottom_bar_final_real_render.png")
	print("[BottomBarFinal] 成功导出实机底栏预览图: bottom_bar_final_real_render.png")
	get_tree().quit(0)
