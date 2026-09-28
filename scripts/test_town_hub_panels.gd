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

	print("==================================================")
	print("    ALL TOWN HUB TESTS PASSED SUCCESSFULLY!       ")
	print("==================================================")
	get_tree().quit(0)
