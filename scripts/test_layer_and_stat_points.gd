extends Control

func _ready() -> void:
	print("==================================================")
	print("   START LAYER Z-INDEX & STAT POINTS TEST         ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Test 1: 验证小背包与工坊的图层 Z-Index 高于战场怪物
	# ----------------------------------------------------
	print("\n[Test 1] 验证小背包与工坊的图层 Z-Index 与 z_as_relative...")
	var inv_scene = load("res://scenes/afk/components/player_inventory_panel.tscn")
	var inv = inv_scene.instantiate()
	add_child(inv)
	await get_tree().process_frame

	var pocket = inv.little_pocket_panel
	var wb = inv.socketing_workbench_panel
	var add_inv = inv.add_inv_panel

	assert(pocket != null, "小背包节点必须存在")
	assert(wb != null, "工坊节点必须存在")
	assert(pocket.z_index == 150, "小背包 z_index 必须为 150 (当前: %d)" % pocket.z_index)
	assert(!pocket.z_as_relative, "小背包 z_as_relative 必须为 false")
	assert(wb.z_index == 150, "工坊 z_index 必须为 150 (当前: %d)" % wb.z_index)
	assert(!wb.z_as_relative, "工坊 z_as_relative 必须为 false")
	assert(add_inv.z_index >= 150, "背包扩展弹窗 z_index 必须 >= 150")

	# 战场怪物的最大 z_index 仅为 20，断言小背包与工坊远高出战场怪物
	const MAX_MONSTER_Z_INDEX = 20
	assert(pocket.z_index > MAX_MONSTER_Z_INDEX, "小背包图层必须远高于怪物景深最高层")
	assert(wb.z_index > MAX_MONSTER_Z_INDEX, "工坊图层必须远高于怪物景深最高层")
	print("✔ Test 1 通过: 小背包与工坊图层 (z_index=150) 彻底解决怪物遮挡！")

	inv.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 2: 验证角色属性面板对属性点双键名解析与加点按钮激活
	# ----------------------------------------------------
	print("\n[Test 2] 验证 CharacterInfoPanel 属性点解析与加点按钮联动...")
	var char_scene = load("res://scenes/afk/components/character_info_panel.tscn")
	var char_panel = char_scene.instantiate()
	add_child(char_panel)
	await get_tree().process_frame

	# 2.1 模拟服务端下发带 stat_pts 键的 gscore
	var mock_gscore_stat_pts = {
		"level": 15,
		"stat_pts": 10,
		"str": 25,
		"dex": 20,
		"vit": 30,
		"int": 15,
		"hp": 100,
		"max_hp": 100,
		"mp": 50,
		"max_mp": 50,
		"combat": {}
	}
	char_panel.render_gscore_data(mock_gscore_stat_pts)
	assert(char_panel.current_stat_points == 10, "必须正确解析 stat_pts 为 10")
	assert(char_panel.points_label.text == "10", "剩余属性点标签必须显示为 10")
	assert(char_panel.btn_add_str.visible == true, "力量加点按钮必须显示")
	assert(char_panel.btn_add_dex.visible == true, "敏捷加点按钮必须显示")
	assert(char_panel.btn_add_vit.visible == true, "体力加点按钮必须显示")
	assert(char_panel.btn_add_int.visible == true, "智力加点按钮必须显示")
	print("  -> 2.1 stat_pts 兼容解析与加点按钮激活成功！")

	# 2.2 模拟服务端下发带 stat_points 键的 gscore
	var mock_gscore_stat_points = {
		"level": 16,
		"stat_points": 5,
		"str": 25,
		"dex": 20,
		"vit": 30,
		"int": 15,
		"hp": 100,
		"max_hp": 100,
		"mp": 50,
		"max_mp": 50,
		"combat": {}
	}
	char_panel.render_gscore_data(mock_gscore_stat_points)
	assert(char_panel.current_stat_points == 5, "必须正确解析 stat_points 为 5")
	assert(char_panel.points_label.text == "5", "剩余属性点标签必须显示为 5")
	assert(char_panel.btn_add_str.visible == true, "加点按钮必须激活")
	print("  -> 2.2 stat_points 兼容解析与加点按钮激活成功！")

	# 2.3 模拟属性点为 0 时加点按钮隐藏
	var mock_gscore_zero = {
		"level": 16,
		"stat_points": 0,
		"str": 30,
		"dex": 20,
		"vit": 30,
		"int": 15,
		"hp": 100,
		"max_hp": 100,
		"mp": 50,
		"max_mp": 50,
		"combat": {}
	}
	char_panel.render_gscore_data(mock_gscore_zero)
	assert(char_panel.current_stat_points == 0, "点数必须为 0")
	assert(char_panel.points_label.text == "0", "剩余属性点标签必须显示为 0")
	assert(char_panel.btn_add_str.visible == false, "点数为 0 时力量加点按钮必须隐藏")
	assert(char_panel.btn_add_dex.visible == false, "点数为 0 时敏捷加点按钮必须隐藏")
	assert(char_panel.btn_add_vit.visible == false, "点数为 0 时体力加点按钮必须隐藏")
	assert(char_panel.btn_add_int.visible == false, "点数为 0 时智力加点按钮必须隐藏")
	print("  -> 2.3 属性点为 0 时按钮安全隐藏验证成功！")

	char_panel.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 3: 验证挂机 HUD 收到 level_up 广播主动拉取 gscore
	# ----------------------------------------------------
	print("\n[Test 3] 验证 AFK_MainHUD 升级帧联动拉取 gscore...")
	NetworkClient.set_process(false)
	NetworkClient.is_connected = true
	var sent_cmds: Array = []
	var on_raw_sent = func(cmd: String):
		sent_cmds.append(cmd)
	NetworkClient.raw_sent.connect(on_raw_sent)

	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var mock_level_up = {
		"level": 18,
		"stat_pts": 5,
		"skill_pts": 1,
		"leveled": 1,
		"msg": "恭喜！你的等级提升到了 18 级！"
	}
	sent_cmds.clear()
	hud._on_network_json("level_up", mock_level_up)
	assert(sent_cmds.has("gscore"), "AFK_MainHUD 收到 level_up 后必须主动发送 gscore 指令同步属性点")
	print("✔ Test 3 通过: 挂机区升级即时触发 gscore 全景同步！")

	hud.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 4: 验证城镇安全区收到 level_up 广播主动拉取 gscore
	# ----------------------------------------------------
	print("\n[Test 4] 验证 TownHubController 升级帧联动拉取 gscore...")
	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	add_child(town)
	await get_tree().process_frame

	sent_cmds.clear()
	town._on_json_frame_received("level_up", mock_level_up)
	assert(sent_cmds.has("gscore"), "TownHubController 收到 level_up 后必须主动发送 gscore 指令同步属性点")
	print("✔ Test 4 通过: 安全区升级即时触发 gscore 全景同步！")

	NetworkClient.raw_sent.disconnect(on_raw_sent)
	NetworkClient.is_connected = false

	print("\n==================================================")
	print("  CONGRATULATIONS: ALL TESTS PASSED SUCCESSFULLY! ")
	print("==================================================")
	get_tree().quit(0)
