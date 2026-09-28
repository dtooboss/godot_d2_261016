extends SceneTree

func _init():
	print("==================================================")
	print("【测试开始】装备详情弹窗 (ItemTooltip) 关闭交互验证")
	print("==================================================")
	
	var pass_count = 0
	var total_tests = 4
	
	# 加载 ItemTooltip 场景
	var tooltip_scene = load("res://scenes/afk/components/item_tooltip.tscn")
	assert(tooltip_scene != null, "加载 item_tooltip.tscn 失败！")
	
	var tooltip = tooltip_scene.instantiate()
	root.add_child(tooltip)
	
	# ----------------------------------------------------
	# 测试 1: 验证 BtnClose 节点存在且样式正确
	# ----------------------------------------------------
	print("\n--- 1. 验证 BtnClose 节点存在与层级 ---")
	var btn_close = tooltip.get_node_or_null("%BtnClose")
	assert(btn_close != null, "ItemTooltip 中缺少 BtnClose 节点！")
	assert(btn_close.text == "✕", "BtnClose 文本不为 ✕！")
	assert(btn_close.mouse_filter == Control.MOUSE_FILTER_STOP, "BtnClose mouse_filter 未设置为 STOP！")
	print("✅ 测试 1 通过：BtnClose 节点完整配置，字符为 '✕'，mouse_filter 为 STOP")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 2: 验证点击 BtnClose 能够正常关闭卡片
	# ----------------------------------------------------
	print("\n--- 2. 验证点击 BtnClose 隐藏卡片 ---")
	tooltip.show_item({
		"name": "天使的镰刀",
		"desc": "[center]军刀\n伤害: 51\n需要等级: 12[/center]",
		"color": "#a59263"
	}, Vector2(200, 200))
	
	await process_frame
	
	print("btn_close is_connected to hide_tooltip: ", btn_close.is_connected("pressed", tooltip.hide_tooltip))
	
	# 模拟点击 BtnClose
	btn_close.pressed.emit()
	assert(tooltip.visible == false, "点击 BtnClose 后卡片未隐藏！")
	print("✅ 测试 2 通过：点击 BtnClose 成功关闭装备卡片！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 3: 验证按 ESC 键能够正常关闭卡片
	# ----------------------------------------------------
	print("\n--- 3. 验证按 ESC 快捷键关闭卡片 ---")
	tooltip.show_item({
		"name": "天使的镰刀",
		"desc": "[center]军刀\n伤害: 51[/center]",
		"color": "#a59263"
	}, Vector2(200, 200))
	assert(tooltip.visible == true, "卡片未处于可见状态！")
	
	var esc_event = InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	tooltip._unhandled_input(esc_event)
	
	assert(tooltip.visible == false, "按 ESC 后卡片未隐藏！")
	print("✅ 测试 3 通过：按 ESC 成功关闭装备卡片！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 4: 验证点击卡片外部区域自动关闭
	# ----------------------------------------------------
	print("\n--- 4. 验证点击卡片外部区域自动关闭 ---")
	tooltip.show_item({
		"name": "天使的镰刀",
		"desc": "[center]军刀\n伤害: 51[/center]",
		"color": "#a59263"
	}, Vector2(200, 200))
	assert(tooltip.visible == true, "卡片未处于可见状态！")
	
	var click_outside = InputEventMouseButton.new()
	click_outside.pressed = true
	click_outside.button_index = MOUSE_BUTTON_LEFT
	click_outside.position = Vector2(-100, -100) # 明显位于卡片外部
	tooltip._unhandled_input(click_outside)
	
	assert(tooltip.visible == false, "外部点击后卡片未隐藏！")
	print("✅ 测试 4 通过：点击外部区域成功关闭装备卡片！")
	pass_count += 1
	
	print("\n==================================================")
	print("【测试结果】全部 %d/%d 项装备弹窗关闭测试 100%% 通过！" % [pass_count, total_tests])
	print("==================================================")
	
	tooltip.queue_free()
	quit()
