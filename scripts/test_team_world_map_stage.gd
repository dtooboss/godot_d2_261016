extends Control

## 大地图队伍进度自适应与短板对齐测试脚本
## 验证单人模式、组队短板受限模式与解散恢复模式

func _ready() -> void:
	print("==================================================")
	print("【自动化测试开始】大地图队伍进度自适应与短板对齐验证")
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
	# 测试场景 1: 单人模式 (个人进度 Stage 5)
	# -------------------------------------------------------------
	print("\n--- [测试 1] 验证单人模式大地图据点状态 ---")
	GameState.is_in_team = false
	GameState.team_bottleneck_name = ""
	GameState.player_max_stage = 5
	world_map.switch_act("act1", false)
	world_map.update_progress(5)
	await get_tree().process_frame

	assert(world_map.world_name_label.text == "第一幕：罗格营地", "单人模式下大地图标题不应包含受限提示！")
	assert(world_map.current_spots.size() == 14, "Act 1 应有 14 个据点")

	# 验证据点解锁状态：Stage 1~6 解锁，Stage 7~14 锁定
	for s in world_map.current_spots:
		var sid = s["stage_id"]
		if sid <= 6:
			assert(s["unlocked"] == true, "Stage %d 应当解锁！" % sid)
		else:
			assert(s["unlocked"] == false, "Stage %d 应当锁定！" % sid)
	print("✔ 测试 1 通过: 单人模式下最高可挑战至个人最大进度 + 1 (Stage 6)，标题无受限提示！")

	# -------------------------------------------------------------
	# 测试场景 2: 组队模式 (队伍存在短板队员 "法法"，最低进度 Stage 2)
	# -------------------------------------------------------------
	print("\n--- [测试 2] 验证组队短板受限模式 ---")
	GameState.is_in_team = true
	GameState.team_bottleneck_name = "法法"
	GameState.player_max_stage = 2
	world_map.update_progress(2)
	await get_tree().process_frame

	assert("⚠️ 队伍受限: 法法" in world_map.world_name_label.text, "组队受限时大地图标题必须包含队员受限提示！")
	print("大地图受限标题当前显示为: %s" % world_map.world_name_label.text)

	# 验证据点解锁状态：最高可挑战点收缩至 Stage 3 (2 + 1)，Stage 4 及以后全部锁定置灰
	for s in world_map.current_spots:
		var sid = s["stage_id"]
		if sid <= 3:
			assert(s["unlocked"] == true, "受限模式下 Stage %d 应当解锁！" % sid)
		else:
			assert(s["unlocked"] == false, "受限模式下 Stage %d 必须锁定！" % sid)
	print("✔ 测试 2 通过: 队伍短板模式下，大地图标题自动标黄提示【⚠️ 队伍受限: 法法】，可点击据点精确截断在 Stage 3！")

	# -------------------------------------------------------------
	# 测试场景 3: 解散队伍后恢复单人模式 (个人进度 Stage 10)
	# -------------------------------------------------------------
	print("\n--- [测试 3] 验证解散队伍后大地图恢复个人进度 ---")
	GameState.clear_team()
	GameState.player_max_stage = 10
	world_map.update_progress(10)
	await get_tree().process_frame

	assert(world_map.world_name_label.text == "第一幕：罗格营地", "解散后受限提示必须清除！")
	for s in world_map.current_spots:
		var sid = s["stage_id"]
		if sid <= 11:
			assert(s["unlocked"] == true, "解散后 Stage %d 应当恢复解锁！" % sid)
		else:
			assert(s["unlocked"] == false, "Stage %d 应当锁定！" % sid)
	print("✔ 测试 3 通过: 解散队伍后，大地图无缝恢复个人最高通关进度 (最高可挑战 Stage 11)！")

	# 保存场景测试截图供确认
	await get_tree().process_frame
	var img = get_viewport().get_texture().get_image()
	var artifact_path = "C:/Users/Administrator/.gemini/antigravity/brain/b5309461-d440-459a-8a46-12eef9df4706/test_team_world_map_stage.png"
	img.save_png(artifact_path)
	print("✔ 截图已保存至: %s" % artifact_path)

	print("\n==================================================")
	print("🎉 ALL GODOT CLIENT TESTS PASSED! 客户端大地图逻辑 100% 通过！")
	print("==================================================")
	get_tree().quit(0)
