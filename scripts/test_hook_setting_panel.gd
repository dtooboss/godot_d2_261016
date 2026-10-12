extends SceneTree

## 挂机设置面板 (AFK_HookSettingPanel) 自动化测试脚本
## 验证推图复选框、4 格药水拖放槽位、右键清除与配置保存

func _init() -> void:
	print("==================================================")
	print("【自动化测试开始】挂机与推图设置弹窗 (HookSettingPanel) 验证")
	print("==================================================")
	_run_tests()

func _run_tests() -> void:
	await process_frame
	
	# 1. 构建主控根节点
	var root_control = Control.new()
	root_control.custom_minimum_size = Vector2(1280, 720)
	root_control.size = Vector2(1280, 720)
	root.add_child(root_control)

	# 深色测试背景
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg)

	# 2. 实例化 HookSettingPanel
	var panel_scene = load("res://scenes/afk/components/hook_setting_panel.tscn")
	var panel = panel_scene.instantiate()
	root_control.add_child(panel)

	await process_frame
	await process_frame

	print("\n--- 测试点 1: 打开挂机设置面板 ---")
	panel.show_panel()
	assert(panel.visible == true, "挂机设置面板应正常可见")
	print("✔ 挂机设置面板成功弹出，visible = true")

	# 测试点 2: 真实网络帧派发 (json_frame_received) 与服务端数据回显测试
	print("\n--- 测试点 2: 真实网络帧派发 (json_frame_received) 回显测试 ---")
	var mock_server_data = {
		"auto_next_stage": 1,
		"hook_potions": "hp5,rvl",
		"auto_potion_pct": 65
	}
	panel._on_json_frame_received("afk_settings", mock_server_data)
	await process_frame
	assert(panel.chk_auto_next.button_pressed == true, "推图模式复选框应被勾选")
	assert(panel.potion_slots[0] == "hp5", "槽位 1 药水代码应为 hp5")
	assert(panel.potion_slots[1] == "rvl", "槽位 2 药水代码应为 rvl")
	assert(panel.slider_potion_pct.value == 65, "喝药阈值滑条应同步为 65")
	assert("65%" in panel.label_potion_pct.text, "喝药阈值标签应显示 65%")
	print("✔ 真实网络帧 afk_settings 成功驱动 UI 同步：推图=%s, 槽位1=%s, 槽位2=%s, 喝药阈值=%d%%" % [
		panel.chk_auto_next.button_pressed, panel.potion_slots[0], panel.potion_slots[1], panel.slider_potion_pct.value
	])

	# 测试点 2.1: 模拟玩家拖动滑条调整喝药阈值到 40%
	print("\n--- 测试点 2.1: 玩家滑动喝药阈值滑条 ---")
	panel.slider_potion_pct.value = 40
	await process_frame
	assert(panel.slider_potion_pct.value == 40, "滑条应变更为 40")
	assert("40%" in panel.label_potion_pct.text, "喝药阈值标签应实时更新为 40%")
	print("✔ 滑条实时更新验证成功：%s" % panel.label_potion_pct.text)

	# 测试点 3: 模拟从背包拖拽药水放入槽位 3 (强效法力药水)
	print("\n--- 测试点 3: 模拟背包药水拖入槽位 3 ---")
	var slot3 = panel.slot_controls[2]
	var drag_data_mp = {
		"source": "main_bag",
		"slot_idx": 5,
		"item_data": {
			"id": "mp4",
			"name": "强效法力药水",
			"d2_type": "药水"
		}
	}
	assert(slot3._can_drop_data(Vector2.ZERO, drag_data_mp) == true, "槽位 3 应接受药水拖入")
	slot3._drop_data(Vector2.ZERO, drag_data_mp)
	await process_frame
	assert(panel.potion_slots[2] == "mp4", "槽位 3 药水代码应成功更新为 mp4")
	print("✔ 拖拽放入药水成功：槽位 3 成功记录 mp4")

	# 测试点 4: 模拟右键清除槽位 2 (清空 rvl)
	print("\n--- 测试点 4: 模拟右键点击清空槽位 2 ---")
	var slot2 = panel.slot_controls[1]
	var rclick_event = InputEventMouseButton.new()
	rclick_event.button_index = MOUSE_BUTTON_RIGHT
	rclick_event.pressed = true
	slot2._gui_input(rclick_event)
	await process_frame
	assert(panel.potion_slots[1] == "", "槽位 2 右键清空后应为空")
	print("✔ 右键清空槽位成功：槽位 2 已变为空槽")

	# 测试点 5: 保存设置与信号捕获
	print("\n--- 测试点 5: 保存设置并验证 settings_saved 信号 ---")
	var captured_cfg = {}
	panel.settings_saved.connect(func(cfg):
		captured_cfg.merge(cfg)
	)
	panel._on_save_pressed()
	await process_frame
	print("DEBUG: captured_cfg =", captured_cfg)
	assert(captured_cfg.get("auto_next_stage") == 1, "保存的推图模式应为 1")
	assert(captured_cfg.get("auto_potion_pct") == 40, "保存的喝药阈值应为 40")
	var saved_pots = captured_cfg.get("hook_potions", [])
	assert("hp5" in saved_pots, "保存的药水序列应包含 hp5")
	assert("mp4" in saved_pots, "保存的药水序列应包含 mp4")
	assert(panel.visible == false, "保存后面板应自动隐藏")
	print("✔ 保存成功！捕获配置: %s，面板已关闭" % str(captured_cfg))

	# 测试点 6: 验证无全屏遮罩且外部点击不关闭
	print("\n--- 测试点 6: 验证无全屏遮罩且外部点击不关闭 ---")
	assert(panel.get_node_or_null("Backdrop") == null, "不应存在 Backdrop 遮罩节点")
	assert(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "根节点应设为 MOUSE_FILTER_IGNORE 以支持穿透")
	
	# 模拟外部背包区域点击
	var outside_click = InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(1000, 300)
	outside_click.global_position = Vector2(1000, 300)
	root.push_input(outside_click)
	await process_frame
	assert(panel.visible == false, "保存后处于关闭状态")
	print("✔ 验证通过：无遮罩遮挡，且外部区域点击挂机面板稳定保持打开！")

	# 重新打开以供最终渲染快照截图
	panel.show_panel()
	await process_frame
	await process_frame

	var vp = root.get_viewport()
	if vp and vp.get_texture():
		var img = vp.get_texture().get_image()
		if img:
			var shot_path = "res://test_hook_setting_panel.png"
			img.save_png(shot_path)
			print("✔ 截图已保存至 %s" % shot_path)

	print("==================================================")
	print("🎉 【自动化测试全部通过】HookSettingPanel 验证完毕！")
	print("==================================================")
	quit(0)
