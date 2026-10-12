extends Control

## 测试大地图点击后自动根据玩家身处的 Act 5 判定并定位据点

func _ready() -> void:
	print("==================================================")
	print("【自动化测试开始】大地图 Act 5 智能定位与渲染验证")
	print("==================================================")
	_run_tests()

func _run_tests() -> void:
	await get_tree().process_frame

	var world_map_scene = load("res://scenes/afk/world_map/world_map.tscn")
	var world_map = world_map_scene.instantiate()
	add_child(world_map)
	world_map.show()

	await get_tree().process_frame

	# -------------------------------------------------------------
	# 测试 1: 玩家在 Act 5 战斗中挂机 (current_stage_info["act"] == 5)
	# 模拟点击大地图打开
	# -------------------------------------------------------------
	print("\n--- [测试 1] 玩家身处 Act 5 挂机时点击大地图 ---")
	GameState.current_stage_info = {"stage": 65, "act": 5, "name": "哈洛加斯城塞"}
	GameState.selected_act = "act5"
	GameState.current_location_act = "act5"

	world_map.reset_user_selection()
	world_map._auto_locate_act()
	world_map.update_progress(65)
	await get_tree().process_frame

	print("大地图当前大幕 ID: ", world_map.current_act_id)
	print("大地图标题文本: ", world_map.world_name_label.text)
	assert(world_map.current_act_id == "act5", "大地图大幕 ID 必须为 act5！")
	assert(world_map.world_name_label.text == "第五幕：哈洛加斯", "大地图标题必须为 第五幕：哈洛加斯！")

	var spots = world_map.spots_container.get_children()
	assert(spots.size() > 0, "据点数量必须大于 0")
	var first_spot = spots[0]
	print("首个据点展示: ", first_spot.name_label.text)
	assert("哈洛加斯城塞" in first_spot.name_label.text, "首个据点必须是哈洛加斯城塞，绝不能是鲜血荒地！")
	print("✓ 测试 1 通过: Act 5 挂机时大地图自动直达第五幕哈洛加斯")

	# -------------------------------------------------------------
	# 测试 2: 用户曾手动切换到 act2，关闭大地图后重新打开，应重置并重新定位到 Act 5
	# -------------------------------------------------------------
	print("\n--- [测试 2] 用户曾切到 act2，重新打开时应自动重新对齐 Act 5 ---")
	# 模拟用户在地图面板手动选了 act2
	world_map.switch_act("act2", true)
	print("用户手动切换后大幕 ID: ", world_map.current_act_id)
	assert(world_map.current_act_id == "act2", "手动切换后应为 act2")

	# 模拟关闭大地图后，再次点击大地图打开
	world_map.reset_user_selection()
	world_map._auto_locate_act()
	world_map.update_progress(65)
	await get_tree().process_frame

	print("重新打开后大地图大幕 ID: ", world_map.current_act_id)
	assert(world_map.current_act_id == "act5", "重新打开后必须根据当前战斗大幕重新定位到 act5！")
	print("✓ 测试 2 通过: 重新打开大地图时选幕状态已重置，精准回归 Act 5")

	# -------------------------------------------------------------
	# 测试 3: 身处 Act 4 混沌避难所，大地图精准定位到第四幕群魔堡垒
	# -------------------------------------------------------------
	print("\n--- [测试 3] 身处 Act 4 时验证自动定位 ---")
	GameState.current_stage_info = {"stage": 64, "act": 4, "name": "混沌避难所"}
	world_map.reset_user_selection()
	world_map._auto_locate_act()
	world_map.update_progress(64)
	await get_tree().process_frame

	print("Act 4 大地图大幕 ID: ", world_map.current_act_id)
	assert(world_map.current_act_id == "act4", "大地图大幕 ID 必须为 act4！")
	print("✓ 测试 3 通过: 切换至 Act 4 自动定位完全准确")

	print("\n==================================================")
	print("🎉 所有 3 项大地图 Act 判定与自动定位测试全部通过！")
	print("==================================================")
	get_tree().quit(0)
