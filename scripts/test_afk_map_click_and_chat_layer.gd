extends Node

## 自动化测试：大地图点击防穿透与聊天窗口层级遮挡验证

func _ready() -> void:
	print("==================================================")
	print("【自动化测试开始】大地图防穿透与聊天视窗图层测试")
	print("==================================================")
	_run_tests()

func _run_tests() -> void:
	await get_tree().process_frame
	
	# 1. 实例化挂机主界面
	var packed_hud = load("res://scenes/afk/afk_main_hud.tscn")
	var hud: AFK_MainHUD = packed_hud.instantiate()
	add_child(hud)
	await get_tree().process_frame

	# 测试点 1: 验证聊天窗口层级 z_index = 80, z_as_relative = false
	print("\n--- 测试点 1: 聊天窗口图层 z_index 验证 ---")
	var chat_panel = hud.collapsible_chat
	assert(chat_panel != null, "聊天面板应存在")
	assert(chat_panel.z_index == 80, "聊天面板 z_index 应为 80, 实际为: %d" % chat_panel.z_index)
	assert(chat_panel.z_as_relative == false, "聊天面板 z_as_relative 应为 false")
	print("✔ 聊天窗口绝对图层高度校验通过: z_index = %d, z_as_relative = %s" % [chat_panel.z_index, str(chat_panel.z_as_relative)])

	# 模拟动态生成 5 只怪物
	var monster_scene = load("res://scenes/afk/components/monster_display.tscn")
	var left_vp = hud.left_viewport
	for i in range(5):
		var m_inst = monster_scene.instantiate()
		left_vp.add_child(m_inst)
		assert(m_inst.z_index < chat_panel.z_index, "怪物 z_index (%d) 必须低于聊天面板 (%d)" % [m_inst.z_index, chat_panel.z_index])
	print("✔ 动态刷出 5 只怪物，全部处于 z_index = 0 战场底层，绝对无法遮挡聊天窗口！")

	# 测试点 2: 组队状态与解散队伍按钮定位
	print("\n--- 测试点 2: 模拟组队状态与解散队伍按钮 ---")
	var party_panel = hud.party_hud_panel
	assert(party_panel != null, "组队面板应存在")
	# 模拟组队数据
	GameState.is_in_team = true
	GameState.current_team_members = [
		{"id": "leader_me", "name": "狂战士", "class": "barb", "level": 30, "cur_hp": 800, "max_hp": 800, "is_leader": true},
		{"id": "teammate_1", "name": "法师·艾莉丝", "class": "sor", "level": 28, "cur_hp": 450, "max_hp": 450, "is_leader": false}
	]
	party_panel.update_party(GameState.current_team_members)
	await get_tree().process_frame

	var btn_dismiss = party_panel.btn_team_action
	assert(btn_dismiss != null, "解散队伍按钮应存在")
	assert(btn_dismiss.visible == true, "解散队伍按钮应可见")
	var dismiss_clicked = false
	party_panel.team_dismiss_requested.connect(func():
		dismiss_clicked = true
	)
	var dismiss_global_pos = btn_dismiss.global_position + btn_dismiss.size * 0.5
	print("✔ 解散队伍按钮已就绪，屏幕绝对坐标: %s" % str(dismiss_global_pos))

	# 测试点 3: 打开大地图，验证层级置顶与 mouse_filter = STOP
	print("\n--- 测试点 3: 打开大地图并验证顶置与防穿透 ---")
	var world_map = hud.world_map
	assert(world_map != null, "大地图组件应存在")
	hud._on_return_map_pressed()
	await get_tree().process_frame

	assert(world_map.visible == true, "大地图应处于开启状态")
	assert(world_map.mouse_filter == Control.MOUSE_FILTER_STOP, "大地图根节点 mouse_filter 应为 STOP")
	assert(world_map.map_background.mouse_filter == Control.MOUSE_FILTER_STOP, "大地图背景底图 mouse_filter 应为 STOP")
	assert(world_map.get_index() > party_panel.get_index(), "大地图节点索引 (%d) 必须在组队面板 (%d) 之后" % [world_map.get_index(), party_panel.get_index()])
	print("✔ 大地图成功开启并顶置: 节点索引 = %d (高于组队面板 %d)" % [world_map.get_index(), party_panel.get_index()])

	# 测试点 4: 模拟向解散队伍按钮坐标发送点击事件
	print("\n--- 测试点 4: 模拟点击解散队伍区域，验证防穿透拦截 ---")
	# 构造一个鼠标按下与释放事件，坐标恰好在背后的解散队伍按钮上
	var click_press = InputEventMouseButton.new()
	click_press.position = dismiss_global_pos
	click_press.global_position = dismiss_global_pos
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.pressed = true
	
	# 通过 Viewport 统一派发 GUI 输入事件
	get_viewport().push_input(click_press)
	await get_tree().process_frame

	var click_release = InputEventMouseButton.new()
	click_release.position = dismiss_global_pos
	click_release.global_position = dismiss_global_pos
	click_release.button_index = MOUSE_BUTTON_LEFT
	click_release.pressed = false
	get_viewport().push_input(click_release)
	await get_tree().process_frame

	assert(dismiss_clicked == false, "致命错误：点击事件穿透到了背后的解散队伍按钮！")
	print("✔ 绝杀验证通过：点击事件已被大地图顶层完整拦截吸收，解散队伍未被误触！")

	# 保存实机渲染截图
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport = get_viewport()
	if viewport:
		var tex = viewport.get_texture()
		if tex and tex.get_width() > 0 and tex.get_height() > 0:
			var img = tex.get_image()
			if img:
				img.save_png("res://test_afk_map_no_passthrough.png")
				print("✔ 界面截图已保存至: res://test_afk_map_no_passthrough.png")

	print("\n==================================================")
	print("【自动化测试全部通过】大地图防穿透与聊天图层验证 100% 成功！")
	print("==================================================")
	get_tree().quit()
