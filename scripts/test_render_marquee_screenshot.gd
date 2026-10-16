extends Control

const NoticeMarqueeScene = preload("res://scenes/common/notice_marquee.tscn")

func _ready() -> void:
	# 模拟暗黑背景
	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.08, 0.06, 0.04, 1.0)
	add_child(bg)

	var marquee = NoticeMarqueeScene.instantiate()
	add_child(marquee)

	# 模拟用户截图中的公告：【赵狂敕令】+ 文本
	marquee.show_marquee({
		"text": "欢迎大家来到暗黑破坏神II重制版！",
		"duration": 10.0,
		"color": "#ffd700",
		"sender": "赵狂"
	})

	# 等待动画滑入展开稳定
	await get_tree().create_timer(0.6).timeout

	# 截屏保存
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_marquee_centered.png")
	print("✔ 截图已成功保存至 res://test_marquee_centered.png")
	get_tree().quit(0)
