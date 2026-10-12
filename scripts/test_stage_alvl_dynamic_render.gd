extends Control

## 测试服务端权威 alvl 驱动大地图据点等级动态渲染
## 验证场景：
## 1. 无服务端 alvl 下发时，据点保持默认回退等级
## 2. 模拟噩梦难度下发 stage_alvls: Stage 1 为 36 级，Stage 2 为 37 级
## 3. 模拟地狱难度下发 stage_alvls: Stage 1 为 66 级
## 4. 模拟切换大幕 Act 2: Stage 15 动态显示对应 alvl

func _ready() -> void:
	print("==================================================")
	print("【自动化测试开始】大地图据点权威 alvl 动态渲染验证")
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
	# 测试 1: 默认无服务端 stage_alvls 时，回退展示默认等级 (Lv.1)
	# -------------------------------------------------------------
	print("\n--- [测试 1] 默认无 stage_alvls 时的回退等级展示 ---")
	GameState.stage_alvls.clear()
	world_map.switch_act("act1", false)
	world_map.update_progress(0)
	await get_tree().process_frame

	var spot_nodes = world_map.spots_container.get_children()
	assert(spot_nodes.size() == 14, "Act 1 据点数量必须为 14")
	var first_spot = spot_nodes[0]
	print("默认展示文本: ", first_spot.name_label.text)
	assert(first_spot.name_label.text == "Lv.1 鲜血荒地", "默认应展示 Lv.1 鲜血荒地")
	print("✓ 测试 1 通过: 默认回退等级正确")

	# -------------------------------------------------------------
	# 测试 2: 模拟噩梦难度下发 stage_alvls (鲜血荒地 36, 冰冷之原 37)
	# -------------------------------------------------------------
	print("\n--- [测试 2] 模拟噩梦难度 stage_alvls 动态渲染 ---")
	GameState.stage_alvls = {
		"1": 36,
		"2": 37,
		"3": 38,
		"4": 39,
		"14": 49
	}
	world_map.update_progress(0)
	await get_tree().process_frame

	spot_nodes = world_map.spots_container.get_children()
	var spot1 = spot_nodes[0]
	var spot2 = spot_nodes[1]
	var spot14 = spot_nodes[13]
	print("噩梦 Stage 1 展示: ", spot1.name_label.text)
	print("噩梦 Stage 2 展示: ", spot2.name_label.text)
	print("噩梦 Stage 14 展示: ", spot14.name_label.text)
	assert(spot1.name_label.text == "Lv.36 鲜血荒地", "噩梦 Stage 1 必须动态渲染为 Lv.36 鲜血荒地！")
	assert(spot2.name_label.text == "Lv.37 冰冷之原", "噩梦 Stage 2 必须动态渲染为 Lv.37 冰冷之原！")
	assert(spot14.name_label.text == "Lv.49 地下墓穴第四层", "噩梦 Stage 14 必须动态渲染为 Lv.49 地下墓穴第四层！")
	print("✓ 测试 2 通过: 噩梦难度权威 alvl 动态渲染完美对齐")

	# -------------------------------------------------------------
	# 测试 3: 模拟地狱难度下发 stage_alvls (鲜血荒地 66)
	# -------------------------------------------------------------
	print("\n--- [测试 3] 模拟地狱难度 stage_alvls 动态渲染 ---")
	GameState.stage_alvls = {
		"1": 66,
		"2": 67,
		"14": 79
	}
	world_map.update_progress(0)
	await get_tree().process_frame

	spot_nodes = world_map.spots_container.get_children()
	spot1 = spot_nodes[0]
	print("地狱 Stage 1 展示: ", spot1.name_label.text)
	assert(spot1.name_label.text == "Lv.66 鲜血荒地", "地狱 Stage 1 必须动态渲染为 Lv.66 鲜血荒地！")
	print("✓ 测试 3 通过: 地狱难度权威 alvl 动态渲染完美对齐")

	# -------------------------------------------------------------
	# 测试 4: 切换到 Act 2 鲁高因大幕，验证动态 alvl 依然生效
	# -------------------------------------------------------------
	print("\n--- [测试 4] 切换大幕到 Act 2 动态渲染 ---")
	GameState.stage_alvls["15"] = 48 # 噩梦 Act 2 第 1 关
	world_map.switch_act("act2", false)
	await get_tree().process_frame

	spot_nodes = world_map.spots_container.get_children()
	var spot15 = spot_nodes[0]
	print("Act 2 第 1 关展示: ", spot15.name_label.text)
	assert(spot15.name_label.text == "Lv.48 鲁高因码头卫所", "Act 2 第 1 关必须动态渲染为 Lv.48！")
	print("✓ 测试 4 通过: 跨大幕动态 alvl 渲染完全正确")

	print("\n==================================================")
	print("🎉 所有 4 项大地图权威 alvl 动态渲染测试全部通过！")
	print("==================================================")
	get_tree().quit(0)
