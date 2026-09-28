extends Control

func _ready() -> void:
	print("=== 开始 ACT1 大地图选点打通与全场景切关自动化回归测试 ===")
	NetworkClient.set_process(false)
	NetworkClient.is_connected = true

	# 1. 实例化主挂机 HUD
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud: AFK_MainHUD = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var world_map: AFK_WorldMap = hud.world_map
	assert(world_map != null, "AFK_MainHUD 必须挂载 world_map 节点！")

	# 记录发出的网络原始指令
	var sent_raw_cmds: Array[String] = []
	var on_data_sent = func(data: String):
		sent_raw_cmds.append(data.strip_edges())
	if not NetworkClient.raw_sent.is_connected(on_data_sent):
		NetworkClient.raw_sent.connect(on_data_sent)

	# -------------------------------------------------------------
	# Test 1: 验证大地图包含且仅包含 13 个 ACT1 正统据点，无假选点残留
	# -------------------------------------------------------------
	print("\n--- Test 1: 验证大地图 13 个正统据点完整性与纯净度 ---")
	assert(world_map.spots.size() == 13, "ACT1 大地图必须且只能有 13 个据点，当前数量: %d" % world_map.spots.size())
	
	var expected_act1_stages = [
		{"stage_id": 1, "name": "鲜血荒地", "boss": "尸火"},
		{"stage_id": 2, "name": "冰冷之原", "boss": "毕须博须"},
		{"stage_id": 3, "name": "邪恶洞窟", "boss": "尸火"},
		{"stage_id": 4, "name": "罗格埋骨之地", "boss": "血鸦"},
		{"stage_id": 5, "name": "石块旷野", "boss": "拉卡尼休"},
		{"stage_id": 6, "name": "地底通道", "boss": "巨身蛮兽"},
		{"stage_id": 7, "name": "黑暗森林", "boss": "树头木拳"},
		{"stage_id": 8, "name": "黑色荒地", "boss": "女伯爵"},
		{"stage_id": 9, "name": "遗忘之塔", "boss": "女伯爵"},
		{"stage_id": 10, "name": "修道院兵营", "boss": "铁匠"},
		{"stage_id": 11, "name": "修道院监牢", "boss": "恶臭污犬"},
		{"stage_id": 12, "name": "修道院大教堂", "boss": "骨灰"},
		{"stage_id": 13, "name": "地下墓穴第四层", "boss": "安达利尔"}
	]

	var forbidden_names = ["哀伤草原", "烈风平原", "毒蜂丘陵", "地精营地", "巨魔矿坑", "迷雾沼泽", "试炼之地"]

	for i in range(13):
		var actual = world_map.spots[i]
		var exp = expected_act1_stages[i]
		assert(actual.get("stage_id") == exp["stage_id"], "据点索引 %d 的 stage_id 必须为 %d" % [i, exp["stage_id"]])
		assert(actual.get("name") == exp["name"], "据点索引 %d 的名字必须为 '%s'，实际为 '%s'" % [i, exp["name"], actual.get("name")])
		assert(actual.get("boss") == exp["boss"], "据点索引 %d 的首领必须为 '%s'，实际为 '%s'" % [i, exp["boss"], actual.get("boss")])
		for f_name in forbidden_names:
			assert(not f_name in actual.get("name"), "据点绝对不能包含旧项目虚构地名 '%s'" % f_name)

	print("✔ [测试 1 通过] 13 个正统 ACT1 据点全部验证通过，无任何参考项目假地名残留！")

	# -------------------------------------------------------------
	# Test 2: 验证点击据点下发 stage 指令
	# -------------------------------------------------------------
	print("\n--- Test 2: 验证大地图选点点击触发与发送 stage 指令 ---")
	
	# 测试点击 Stage 1 (鲜血荒地)
	sent_raw_cmds.clear()
	world_map.enter_spot.emit(world_map.spots[0])
	await get_tree().process_frame
	assert(sent_raw_cmds.has("stage 1"), "点击鲜血荒地据点必须发送 'stage 1' 指令，实际记录: %s" % str(sent_raw_cmds))
	assert(hud.current_map_label.text == "鲜血荒地", "本地当前地图标签必须更新为 '鲜血荒地'")
	print("✔ 选点 Stage 1 (鲜血荒地) -> 发送 'stage 1' 成功！")

	# 测试点击 Stage 4 (罗格埋骨之地)
	sent_raw_cmds.clear()
	world_map.enter_spot.emit(world_map.spots[3])
	await get_tree().process_frame
	assert(sent_raw_cmds.has("stage 4"), "点击罗格埋骨之地据点必须发送 'stage 4' 指令，实际记录: %s" % str(sent_raw_cmds))
	assert(hud.current_map_label.text == "罗格埋骨之地", "本地当前地图标签必须更新为 '罗格埋骨之地'")
	print("✔ 选点 Stage 4 (罗格埋骨之地) -> 发送 'stage 4' 成功！")

	# 测试点击 Stage 13 (地下墓穴第四层 - 安达莉尔 Boss)
	sent_raw_cmds.clear()
	world_map.enter_spot.emit(world_map.spots[12])
	await get_tree().process_frame
	assert(sent_raw_cmds.has("stage 13"), "点击地下墓穴第四层据点必须发送 'stage 13' 指令，实际记录: %s" % str(sent_raw_cmds))
	assert(hud.current_map_label.text == "地下墓穴第四层", "本地当前地图标签必须更新为 '地下墓穴第四层'")
	print("✔ 选点 Stage 13 (地下墓穴第四层) -> 发送 'stage 13' 成功！")
	print("✔ [测试 2 通过] 任意据点选点切关指令与本地即时响应均准确无误！")

	# -------------------------------------------------------------
	# Test 3: 模拟服务端返回 stage_enter 帧，验证旧怪平滑清场与刷新
	# -------------------------------------------------------------
	print("\n--- Test 3: 模拟服务端 stage_enter 帧，验证旧怪平滑清场与刷新 ---")
	
	# 先模拟当前场景有一些残留怪
	var dummy_monster = Node2D.new()
	dummy_monster.name = "dummy_monster_old"
	hud.add_child(dummy_monster)
	hud._monster_instances["old_mob_1"] = dummy_monster
	hud._occupied_slots["slot_0"] = true
	hud._current_target_id = "old_mob_1"

	assert(hud._monster_instances.size() > 0, "前置检查：应当有旧场景怪物实例")

	# 接收服务端推送的 stage_enter 帧
	sent_raw_cmds.clear()
	var enter_frame = {
		"stage_id": 13,
		"name": "地下墓穴第四层",
		"alvl": 15,
		"boss": "安达利尔",
		"boss_kills": 0,
		"max_kills": 15
	}
	hud._on_network_json("stage_enter", enter_frame)
	await get_tree().process_frame

	# 验证旧怪被清空
	assert(hud._monster_instances.is_empty(), "收到 stage_enter 后必须彻底清空旧怪物节点映射！")
	assert(hud._occupied_slots.is_empty(), "收到 stage_enter 后必须重置怪物槽位！")
	assert(hud._current_target_id.is_empty(), "收到 stage_enter 后必须重置当前锁定目标！")
	assert(hud.current_map_label.text == "地下墓穴第四层", "场景标签必须确认为 '地下墓穴第四层'")
	assert(sent_raw_cmds.has("ghp1"), "进场后必须自动发送 'ghp1' 获取新场景怪群，实际发送: %s" % str(sent_raw_cmds))
	print("✔ [测试 3 通过] stage_enter 平滑清场、槽位释放并立即发送 ghp1 请求新怪群！")

	# -------------------------------------------------------------
	# Test 4: 模拟新场景 gstatus 快照，验证安达莉尔 Boss 与怪群刷出
	# -------------------------------------------------------------
	print("\n--- Test 4: 模拟接收新场景 gstatus 快照，验证 Boss 与怪群正常载入 ---")
	var gstatus_act1_boss = {
		"stage": {
			"stage_name": "地下墓穴第四层",
			"kill_step": 5,
			"threshold": 15,
			"boss_active": 0
		},
		"monsters": [
			{
				"id": "andariel_boss",
				"name": "安达利尔",
				"hp": 25000,
				"max_hp": 25000,
				"level": 15,
				"type": "boss"
			},
			{
				"id": "dark_one_1",
				"name": "黑暗恶魔",
				"hp": 300,
				"max_hp": 300,
				"level": 14,
				"type": "normal"
			}
		]
	}
	hud._on_network_json("gstatus", gstatus_act1_boss)
	await get_tree().process_frame

	# 验证 Boss 进度 UI (常规推进阶段)
	assert(hud.current_boss_kills == 5, "当前 Boss 进度击杀计数应为 5，实际为: %d" % hud.current_boss_kills)
	assert(hud.max_boss_kills == 15, "Boss 进度上限应为 15，实际为: %d" % hud.max_boss_kills)
	assert(hud.boss_progress_label.text.contains("5/15"), "Boss UI 进度文字必须包含 '5/15'，实际为: '%s'" % hud.boss_progress_label.text)

	# 验证安达莉尔 Boss 降临特写状态
	var gstatus_andariel_active = {
		"stage": {
			"stage_name": "地下墓穴第四层",
			"kill_step": 15,
			"threshold": 15,
			"boss_active": 1
		},
		"monsters": [
			{
				"id": "andariel_boss",
				"name": "安达利尔",
				"hp": 25000,
				"max_hp": 25000,
				"level": 15,
				"type": "boss"
			}
		]
	}
	hud._on_network_json("gstatus", gstatus_andariel_active)
	await get_tree().process_frame
	assert(hud.boss_progress_label.text.contains("领主降临"), "安达莉尔现身时 UI 必须切换为领主降临特写！实际为: '%s'" % hud.boss_progress_label.text)
	print("✔ [测试 4 通过] 地下墓穴第四层安达莉尔 Boss 战况与 UI 正确同步渲染！")

	print("\n=======================================================")
	print("✔✔✔ ACT1 大地图选点全流程 4 项测试全部 100% 通过！✔✔✔")
	print("=======================================================")
	get_tree().quit(0)
