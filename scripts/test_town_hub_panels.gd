extends Control

@onready var hub = $TownHub

func _ready() -> void:
	print("==================================================")
	print("   START TOWN HUB ALL PANELS & SPOT DISPATCH TEST ")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	# 1. 模拟选角
	GameState.selected_character = {
		"name": "测试亚马逊",
		"class": "ama",
		"class_name": "亚马逊",
		"level": 99,
		"gold": 126777214,
		"difficulty": "normal"
	}
	GameState.selected_difficulty = "normal"
	hub._init_player_ui()

	var sent_cmds: Array[String] = []
	if NetworkClient.has_signal("raw_sent"):
		NetworkClient.raw_sent.connect(func(cmd):
			sent_cmds.append(cmd.strip_edges())
		)

	# 等待一帧
	await get_tree().process_frame

	# Test 1: 验证所有面板已成功挂载
	assert(hub.world_map != null, "WorldMap 必须存在于 town_hub 中！")
	assert(hub.char_info_panel != null, "CharacterInfoPanel 必须存在于 town_hub 中！")
	assert(hub.skill_panel != null, "SkillPanel 必须存在于 town_hub 中！")
	assert(hub.pickup_setting_panel != null, "PickupSettingPanel 必须存在于 town_hub 中！")
	assert(hub.cube_panel != null, "CubePanel 必须在 _ready 中成功动态创建！")
	print("✔ Test 1: All town_hub UI panels mounted and initialized!")

	# Test 2: 验证各个面板 Toggle 与互斥关闭逻辑
	assert(!hub.world_map.visible, "WorldMap 初始应隐藏")
	assert(!hub.char_info_panel.visible, "CharacterInfoPanel 初始应隐藏")
	assert(!hub.skill_panel.visible, "SkillPanel 初始应隐藏")
	assert(!hub.pickup_setting_panel.visible, "PickupSettingPanel 初始应隐藏")
	assert(!hub.cube_panel.visible, "CubePanel 初始应隐藏")

	# (1) 打开大地图
	hub._toggle_world_map()
	assert(hub.world_map.visible, "打开大地图后 world_map 必须可见")
	
	# (2) 互斥：打开角色面板，大地图应自动关闭
	hub._toggle_character_info()
	assert(!hub.world_map.visible, "打开角色面板后大地图必须互斥关闭")
	assert(hub.char_info_panel.visible, "角色面板必须可见")

	# (3) 打开技能面板，角色面板必须互斥关闭
	hub._toggle_skill_panel()
	assert(!hub.char_info_panel.visible, "打开技能面板后角色面板必须互斥关闭")
	assert(hub.skill_panel.visible, "技能面板必须可见")

	# (4) 打开方块面板，技能面板互斥关闭
	hub._toggle_cube_panel()
	assert(!hub.skill_panel.visible, "打开方块面板后技能面板必须互斥关闭")
	assert(hub.cube_panel.visible, "方块面板必须可见")

	# (5) 打开拾取设置面板，方块面板互斥关闭
	hub._toggle_pickup_setting()
	assert(!hub.cube_panel.visible, "打开拾取设置后方块面板必须互斥关闭")
	assert(hub.pickup_setting_panel.visible, "拾取设置面板必须可见")

	# (6) ESC 键全部关闭
	hub._close_all_popups_except(null)
	assert(!hub.pickup_setting_panel.visible, "ESC后拾取设置应关闭")
	print("✔ Test 2: Panel toggling and mutual exclusivity verified!")

	# Test 3: 验证大地图选点出征信号传递 (包含字典信号触发与双参方法兼容)
	hub.world_map.show()
	hub.world_map.enter_spot.emit({"stage_id": 2, "name": "冰冷之原"})
	assert(!hub.world_map.visible, "通过 enter_spot 信号选点出征后大地图必须自动隐藏！")
	hub.world_map.show()
	hub._on_map_spot_selected(1, "鲜血荒地")
	assert(!hub.world_map.visible, "选点出征后大地图必须自动隐藏！")
	print("✔ Test 3: Map spot selection & dispatch logic (signal + method) verified!")

	# Test 4: 验证数据包分发至面板 (gscore, gskills, gcube, gfenjie)
	var mock_score = {
		"name": "测试亚马逊",
		"level": 99,
		"hp": 478,
		"max_hp": 478,
		"str": 35,
		"dex": 80,
		"vit": 30,
		"ene": 30
	}
	hub._on_json_frame_received("gscore", mock_score)
	print("✔ Test 4.1: gscore frame parsed successfully!")

	var mock_fenjie = {
		"action": "config",
		"config": {
			"white_weapon": 1,
			"white_armor": 1,
			"material": 1,
			"min_sockets": {"normal": 2}
		}
	}
	hub._on_json_frame_received("gfenjie", mock_fenjie)
	assert(hub.pickup_setting_panel.current_config.get("white_weapon") == 1, "拾取设置面板配置应用失败！")
	print("✔ Test 4.2: gfenjie config frame verified!")

	# Test 5: 验证安全区中打开小背包与工坊的同级互斥及与魔盒的互斥
	var inv = hub.inventory_panel
	var pocket = inv.little_pocket_panel
	var wb = inv.socketing_workbench_panel

	# (1) 打开小背包
	inv.btn_pocket.emit_signal("pressed")
	assert(pocket.visible, "点击小背包按钮后小口袋必须打开")
	assert(!wb.visible, "打开小背包后工坊必须保持关闭")

	# (2) 在小背包打开时点击工坊
	inv.btn_workbench.emit_signal("pressed")
	assert(!pocket.visible, "打开工坊后小口袋必须互斥自动关闭")
	assert(wb.visible, "工坊必须已打开")

	# (3) 在工坊打开时点击小背包
	inv.btn_pocket.emit_signal("pressed")
	assert(!wb.visible, "打开小口袋后工坊必须互斥自动关闭")
	assert(pocket.visible, "小口袋必须已重新打开")

	# (4) 在小口袋打开时打开魔盒
	hub._toggle_cube_panel()
	assert(hub.cube_panel.visible, "魔盒必须已打开")
	assert(!pocket.visible, "打开魔盒后小口袋必须互斥自动关闭")
	assert(!wb.visible, "打开魔盒后工坊必须保持关闭")

	# (5) 在魔盒打开时打开工坊
	inv.btn_workbench.emit_signal("pressed")
	assert(wb.visible, "工坊必须已打开")
	assert(!hub.cube_panel.visible, "打开工坊后魔盒必须互斥自动关闭")
	assert(!pocket.visible, "工坊打开时小口袋必须保持关闭")

	# (6) 打开纸娃娃，工坊必须自动互斥关闭
	hub._toggle_character_info()
	assert(hub.char_info_panel.visible, "角色面板必须打开")
	assert(!wb.visible, "打开纸娃娃后工坊必须互斥自动关闭")

	hub._close_all_popups_except(null)
	print("✔ Test 5: Safe zone pocket & workbench mutual exclusivity verified 100%!")

	# Test 6: 验证安全区接收 gsocket 数据帧后，工坊面板能成功渲染出装备与孔位！
	wb.visible = true
	var mock_gsocket = {
		"equipment": {
			"file_id": "/clone/armor/plate_mail_01",
			"name": "巨型鳞甲 (Sacred Armor)",
			"color": "#1eff00",
			"icon": "res://assets/images/gemsocket.lowend.png",
			"sockets": 4,
			"max_sockets": 4,
			"inlay_count": 1,
			"inlays": [
				"res://assets/images/gemsocket.lowend.png",
				"",
				"",
				""
			],
			"quality": "normal"
		},
		"tool": {},
		"can_punch": false,
		"can_uninlay": true,
		"punch_hint": "已达最大孔数(4孔)，无法再打",
		"page": 1
	}
	hub._on_json_frame_received("gsocket", mock_gsocket)
	assert(wb.equip_name_label.text.contains("巨型鳞甲"), "安全区接收 gsocket 帧后工坊必须显示装备名称！")
	assert(wb.sockets_grid.get_child_count() == 4, "工坊凹槽网格必须精确渲染 4 个孔位！")
	assert(wb.btn_uninlay.disabled == false, "工坊洗孔按钮必须根据 can_uninlay 激活！")
	print("✔ Test 6: Safe zone gsocket frame routing & workbench rendering verified 100%!")

	# Test 7: 验证安全区整装（纸娃娃换装）右键联动
	print("\n--- Test 7: 验证安全区纸娃娃右键穿戴换装联动 ---")
	wb.visible = false
	inv = hub.inventory_panel
	inv.command_sent.connect(func(cmd):
		sent_cmds.append(cmd.strip_edges())
	)
	var dummy_gear = {
		"file_id": "/clone/d2/armor_test#101",
		"name": "符文之语【谜团】",
		"quality": "unique",
		"type": "甲",
		"amount": 1
	}
	inv.items_map[0] = dummy_gear
	inv.current_page = 1
	
	# (1) 纸娃娃关闭状态 -> 右键背包不盲目换装
	hub.char_info_panel.hide()
	sent_cmds.clear()
	var fake_rclick = InputEventMouseButton.new()
	fake_rclick.button_index = MOUSE_BUTTON_RIGHT
	fake_rclick.pressed = true
	inv._on_slot_gui_input(fake_rclick, 0)
	assert(sent_cmds.is_empty(), "安全区纸娃娃关闭时，右键背包装备必须防误触，不得发送 gwear！")
	print("✔ Test 7.1: 安全区纸娃娃关闭状态右键防误触生效！")

	# (2) 打开纸娃娃窗口 -> 右键背包装备立即发送 gwear 快速穿戴
	hub._toggle_character_info()
	assert(hub.char_info_panel.is_visible_in_tree(), "纸娃娃面板必须可见！")
	sent_cmds.clear()
	inv._on_slot_gui_input(fake_rclick, 0)
	assert(sent_cmds.has("gwear /clone/d2/armor_test#101 1"), "安全区纸娃娃打开时，右键背包必须精准下发 gwear 指令！实际发送: %s" % str(sent_cmds))
	print("✔ Test 7.2: 安全区纸娃娃打开时，右键装备成功触发快速穿戴 (gwear)！")

	# Test 8: 验证安全区合成（赫拉迪克方块）右键联动
	print("\n--- Test 8: 验证安全区赫拉迪克方块右键放入材料联动 ---")
	var dummy_cube_mat = {
		"file_id": "/clone/d2/rune_ber#30",
		"name": "贝(Ber) 30# 符文",
		"quality": "magic",
		"type": "符文",
		"amount": 1
	}
	inv.items_map[1] = dummy_cube_mat
	
	# 打开魔盒 (这会自动互斥关闭纸娃娃)
	hub._toggle_cube_panel()
	assert(hub.cube_panel != null and hub.cube_panel.is_visible_in_tree(), "安全区魔盒必须处于打开状态！")
	assert(!hub.char_info_panel.is_visible_in_tree(), "打开魔盒后纸娃娃必须互斥关闭！")
	
	sent_cmds.clear()
	inv._on_slot_gui_input(fake_rclick, 1)
	assert(sent_cmds.has("gcube put /clone/d2/rune_ber#30"), "安全区魔盒打开时，右键背包材料必须精准下发 gcube put 指令！实际发送: %s" % str(sent_cmds))
	print("✔ Test 8: 安全区魔盒打开时，右键材料成功触发放入魔盒 (gcube put)！")

	print("==================================================")
	print("    ALL TOWN HUB TESTS PASSED SUCCESSFULLY!       ")
	print("==================================================")
	get_tree().quit(0)
