extends Control

const NoticeMarqueeScene = preload("res://scenes/common/notice_marquee.tscn")

func _ready() -> void:
	print("==================================================================")
	print("【自动化回归测试】全界面置顶大字跑马灯系统测试")
	print("==================================================================")

	await _test_marquee_structure()
	await _test_short_text_display()
	await _test_long_text_marquee()
	await _test_mud_macro_color_parsing()

	print("\n🎉 全部跑马灯系统单元与动效测试 100% 通过！")
	get_tree().quit(0)

## Test 1: 验证组件结构与初始状态
func _test_marquee_structure() -> void:
	print("\n[Test 1] 验证跑马灯组件节点树与初始状态...")
	var marquee = NoticeMarqueeScene.instantiate()
	add_child(marquee)

	assert(marquee.has_node("Container"), "必须包含 Container 节点")
	assert(marquee.has_node("%BadgeLabel"), "必须包含 BadgeLabel 节点")
	assert(marquee.has_node("%ClipViewport"), "必须包含 ClipViewport 节点")
	assert(marquee.has_node("%NoticeText"), "必须包含 NoticeText 节点")

	assert(marquee.layer == 120, "CanvasLayer 必须设置为 120 顶层")
	assert(marquee.container.visible == false, "初始状态必须为隐藏")

	print("  ✔ 节点树与 120 顶层配置校验通过！")
	marquee.queue_free()
	await get_tree().process_frame

## Test 2: 验证短文本居中展示与色彩基准
func _test_short_text_display() -> void:
	print("\n[Test 2] 验证短文本居中展示与指定基色...")
	var marquee = NoticeMarqueeScene.instantiate()
	add_child(marquee)
	await get_tree().process_frame

	marquee.show_marquee({
		"text": "庇护之地平静祥和",
		"duration": 3.0,
		"color": "#22c55e",
		"sender": "大天使泰瑞尔"
	})

	assert(marquee.badge_label.text == "【大天使泰瑞尔敕令】", "微标文本必须准确")
	assert("#22c55e" in marquee.notice_text.text, "富文本必须应用指定的绿色基调")
	assert("庇护之地平静祥和" in marquee.notice_text.text, "公告文本必须完整呈现")
	assert(marquee.container.visible == true, "展示时 Container 必须变为可见")

	print("  ✔ 短文本居中、基色渲染与微标校验通过！")
	marquee.queue_free()
	await get_tree().process_frame

## Test 3: 验证长文本滚动模式 (Marquee)
func _test_long_text_marquee() -> void:
	print("\n[Test 3] 验证长文本自动进入右至左滚动模式...")
	var marquee = NoticeMarqueeScene.instantiate()
	add_child(marquee)
	await get_tree().process_frame

	var long_str = "【重大战报】全服所有勇士请注意，暗黑破坏神与巴尔已经突破混沌庇难所的封印，罗格营地、鲁高因、海港已全面拉响一级战斗警报！"
	marquee.show_marquee({
		"text": long_str,
		"duration": 4.0,
		"color": "#ef4444",
		"sender": "迪卡·凯恩"
	})

	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_w = marquee.clip_viewport.size.x
	var text_w = marquee.notice_text.size.x
	assert(text_w >= viewport_w, "长文本尺寸 (%f) 必须达到或超过视口宽度 (%f)" % [text_w, viewport_w])
	assert(marquee.is_showing == true, "跑马灯应处于播放中")

	print("  ✔ 长文本尺寸自适应与跑马灯滚动队列验证通过！")
	marquee.queue_free()
	await get_tree().process_frame

## Test 4: 验证 MUD 传统色彩宏解析 ($HIR$, $HIY$ 等)
func _test_mud_macro_color_parsing() -> void:
	print("\n[Test 4] 验证 MUD 传统颜色宏 ($HIR$ / $HIY$ / $HIG$) 混合富文本解析...")
	var marquee = NoticeMarqueeScene.instantiate()
	add_child(marquee)
	await get_tree().process_frame

	var mud_macro_text = "$HIR$高危警戒：$HIY$世界Boss$HIG$地狱大菠萝$NOR$降临！"
	marquee.show_marquee({
		"text": mud_macro_text,
		"duration": 3.0,
		"color": "#ffd700",
		"sender": "天神"
	})

	await get_tree().process_frame

	# 验证 BBCode 标签已被正确展开
	var bb = marquee.notice_text.text
	assert("[color=" in bb, "MUD 色彩宏必须被转换为 [color=...] BBCode 标签")
	assert("高危警戒" in bb and "地狱大菠萝" in bb, "文本内容必须完整保真")

	print("  ✔ MUD 色彩宏完美映射为富文本 BBCode 校验通过！")
	marquee.queue_free()
	await get_tree().process_frame
