extends SceneTree

func _init():
	print("========================================")
	print("  开始 EXP 纯后端数据驱动与升级全链路测试  ")
	print("========================================")
	
	# ----------------------------------------------------
	# 测试 1: PlayerBottomBar 纯数据驱动与各种边界格式化
	# ----------------------------------------------------
	print("\n[测试 1] PlayerBottomBar 纯数据驱动与显示验证...")
	var bottom_bar_scene = load("res://scenes/afk/components/player_bottom_bar.tscn")
	var bar: AFK_PlayerBottomBar = bottom_bar_scene.instantiate()
	root.add_child(bar)
	await process_frame
	await process_frame
	
	# 1.1 初始阶段 (0%)
	bar.update_exp(0, 500, 0.0)
	assert(bar.exp_bar.value == 0.0, "初始经验进度条应为 0")
	assert(bar.exp_label.text == "0 / 500 (0.0%)", "经验文本格式错误: " + bar.exp_label.text)
	print("  ✅ 1.1 初始进度: ", bar.exp_label.text)
	
	# 1.2 战斗中杀怪推进 (例如 70%)
	bar.update_exp(350, 500, 70.0)
	assert(abs(bar.exp_bar.value - 70.0) < 0.01, "进度条应推进到 70%")
	assert(bar.exp_label.text == "350 / 500 (70.0%)", "经验文本格式错误: " + bar.exp_label.text)
	print("  ✅ 1.2 杀怪推进: ", bar.exp_label.text)
	
	# 1.3 高等级大数值千分位格式化
	bar.update_exp(1234567, 5000000, 24.69)
	assert(bar.exp_label.text == "1,234,567 / 5,000,000 (24.7%)", "大数值格式化错误: " + bar.exp_label.text)
	print("  ✅ 1.3 大数值千分位: ", bar.exp_label.text)
	
	# 1.4 满级 MAX
	bar.update_exp(99999999, 0, 100.0)
	assert(bar.exp_label.text == "MAX / MAX (100.0%)", "满级显示错误: " + bar.exp_label.text)
	print("  ✅ 1.4 满级状态: ", bar.exp_label.text)
	
	# 1.5 升级动效
	bar.play_level_up_fx()
	print("  ✅ 1.5 升级微动效 play_level_up_fx 调用正常")
	
	bar.queue_free()
	await process_frame
	
	# ----------------------------------------------------
	# 测试 2: AFK_MainHUD 挂接 gstatus (ghp1 驱动)
	# ----------------------------------------------------
	print("\n[测试 2] AFK_MainHUD 挂接 gstatus (由 ghp1 驱动)...")
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	
	var gstatus_mock = {
		"player": {
			"name": "暗黑游侠",
			"level": 12,
			"hp": 200,
			"max_hp": 200,
			"mp": 100,
			"max_mp": 100,
			"exp_cur": 4500,
			"exp_max": 18000,
			"exp_pct": 25.0,
			"exp": 76644,
			"next_exp": 90180
		},
		"stage": {
			"stage_name": "鲜血荒地",
			"kill_step": 3,
			"threshold": 15,
			"boss_active": 0,
			"is_town": 0
		},
		"monsters": []
	}
	
	hud._handle_gstatus_data(gstatus_mock)
	await process_frame
	
	assert(hud.player_bottom_bar != null, "player_bottom_bar 不可为空")
	assert(abs(hud.player_bottom_bar.exp_bar.value - 25.0) < 0.01, "gstatus 未正确驱动经验条到 25%")
	assert(hud.player_bottom_bar.exp_label.text == "4,500 / 18,000 (25.0%)", "gstatus 经验文本错误: " + hud.player_bottom_bar.exp_label.text)
	print("  ✅ gstatus (ghp1) 成功驱动经验条: ", hud.player_bottom_bar.exp_label.text)
	
	# ----------------------------------------------------
	# 测试 3: AFK_MainHUD 挂接 status (hp1 驱动)
	# ----------------------------------------------------
	print("\n[测试 3] AFK_MainHUD 挂接 status (由 hp1 驱动)...")
	var status_mock = {
		"lvl": 12,
		"exp_cur": 9000,
		"exp_max": 18000,
		"exp_pct": 50.0,
		"exp": 81144,
		"exp_next": 90180
	}
	hud._on_network_json("status", status_mock)
	await process_frame
	
	assert(abs(hud.player_bottom_bar.exp_bar.value - 50.0) < 0.01, "status 未正确驱动经验条到 50%")
	assert(hud.player_bottom_bar.exp_label.text == "9,000 / 18,000 (50.0%)", "status 经验文本错误: " + hud.player_bottom_bar.exp_label.text)
	print("  ✅ status (hp1) 成功驱动经验条: ", hud.player_bottom_bar.exp_label.text)
	
	# ----------------------------------------------------
	# 测试 4: AFK_MainHUD 接收纯 JSON level_up 升级事件
	# ----------------------------------------------------
	print("\n[测试 4] AFK_MainHUD 接收 level_up 升级事件广播...")
	var level_up_mock = {
		"level": 13,
		"stat_pts": 5,
		"skill_pts": 1,
		"leveled": 1,
		"msg": "恭喜！你的等级提升到了 13 级！获得 5 点自由属性点和 1 点技能点！"
	}
	hud._on_network_json("level_up", level_up_mock)
	await process_frame
	assert("Lv.13" in hud.player_bottom_bar.player_info_label.text, "升级后玩家底栏未更新为 Lv.13")
	print("  ✅ level_up 事件驱动成功: ", hud.player_bottom_bar.player_info_label.text)
	
	hud.queue_free()
	await process_frame
	
	# ----------------------------------------------------
	# 测试 5: TownHubController 接收 status 与 level_up
	# ----------------------------------------------------
	print("\n[测试 5] TownHubController (主城大本营) 等级与升级同步验证...")
	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	root.add_child(town)
	await process_frame
	await process_frame
	
	# 5.1 status 帧更新等级
	town._on_json_frame_received("status", { "lvl": 13, "gold": 8888 })
	await process_frame
	assert("Lv.13" in town.lbl_char_class.text, "主城顶栏未更新为 Lv.13")
	print("  ✅ 主城 status 成功同步等级: ", town.lbl_char_class.text)
	
	# 5.2 主城接收 level_up 升级广播
	town._on_json_frame_received("level_up", { "level": 14, "msg": "恭喜升级到 14 级！" })
	await process_frame
	assert("Lv.14" in town.lbl_char_class.text, "主城接收 level_up 未更新为 Lv.14")
	print("  ✅ 主城 level_up 广播成功驱动等级: ", town.lbl_char_class.text)
	
	town.queue_free()
	await process_frame
	
	print("\n========================================")
	print("   🎉 恭喜！EXP 纯后端数据驱动测试全部通过！ ")
	print("========================================")
	quit()
