extends Control

const TownHubScene = preload("res://scenes/town/town_hub.tscn")

func _ready() -> void:
	print("==================================================================")
	print("【自动化回归测试】安全区出征按钮与记忆关卡动态匹配测试")
	print("==================================================================")

	# 1. 设置用户真实的场景：玩家从冰冷之原 (Stage 2) 返回罗格营地
	GameState.current_stage_info = {"stage": 2, "name": "冰冷之原", "act": 1}
	GameState.selected_stage_id = 2
	GameState.current_town_name = "罗格营地"
	GameState.current_location_act = "act1"
	GameState.selected_act = "act1"

	var hub = TownHubScene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var btn = hub.btn_go_battle
	assert(btn != null, "出征按钮必须存在")
	print("  当前出征按钮文字: ", btn.text)
	assert("冰冷之原" in btn.text, "记忆关卡为冰冷之原时，按钮必须显示前往冰冷之原！实际显示: %s" % btn.text)
	print("  ✔ 测试 1 通过: 冰冷之原记忆关卡动态匹配成功！")

	# 2. 测试切到第二幕鲁高因 (无有效记忆时对齐首关 鲁高因码头卫所)
	hub._update_town_display("鲁高因")
	print("  切到鲁高因后按钮文字: ", btn.text)
	assert("鲁高因码头卫所" in btn.text, "切到鲁高因后必须对齐鲁高因首关！实际显示: %s" % btn.text)
	print("  ✔ 测试 2 通过: 跨大幕首关安全对齐校验通过！")

	# 3. 测试第二幕记忆关卡 (如 stage 18 下水道三层)
	GameState.current_stage_info = {"stage": 18, "name": "下水道三层", "act": 2}
	hub._update_go_battle_button()
	print("  鲁高因记忆下水道三层后按钮文字: ", btn.text)
	assert("下水道三层" in btn.text, "记忆下水道三层时必须正确显示！实际显示: %s" % btn.text)
	print("  ✔ 测试 3 通过: 第二幕记忆关卡匹配通过！")

	# 4. 测试收到服务端 stage_info (selected_stage = 5 石块旷野)
	hub.current_act_key = "act1"
	GameState.current_stage_info = {}
	hub._on_json_frame_received("stage_info", {
		"max_stage": 14,
		"selected_stage": 5,
		"selected_act": "act1"
	})
	print("  收到 stage_info (selected=5) 后按钮文字: ", btn.text)
	assert("石块旷野" in btn.text, "根据 stage_id=5 必须从大地图拓扑查出石块旷野！实际显示: %s" % btn.text)
	print("  ✔ 测试 4 通过: stage_info 大地图拓扑反查石块旷野成功！")

	print("\n🎉 全部出征关卡匹配与动态更新测试 100% 通过！")
	get_tree().quit(0)
