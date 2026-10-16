extends Control

const WorldMapScript = preload("res://scenes/afk/world_map/world_map.gd")
const BattleSpotScene = preload("res://scenes/afk/world_map/battle_spot.tscn")
const TownHubScene = preload("res://scenes/town/town_hub.tscn")
const MainHudScene = preload("res://scenes/afk/afk_main_hud.tscn")

func _ready() -> void:
	print("==================================================================")
	print("【自动化回归测试】ACT 1-5 安全区落地点 Room 小站与大地图点选进入")
	print("==================================================================")

	NetworkClient.set_process(false)
	NetworkClient.is_connected = true

	_test_acts_config_safe_zone_waypoints()
	_test_battle_spot_waypoint_rendering()
	await _test_afk_main_hud_waypoint_click()
	await _test_town_hub_waypoint_cross_act_teleport()

	print("\n🎉 全部安全区小站与大地图切入测试 100% 通过！")
	get_tree().quit(0)

## Test 1: 验证 ACT 1-5 大地图数据配置中各幕首位安全区小站
func _test_acts_config_safe_zone_waypoints() -> void:
	print("\n[Test 1] 验证 ACT 1-5 大地图配置及落地点 Room 小站完整性...")
	var expected_towns = {
		"act1": {"name": "罗格营地", "room_path": "/d/act1/rogue_camp", "stage_count": 15},
		"act2": {"name": "鲁高因", "room_path": "/d/act2/lut_gholein", "stage_count": 21},
		"act3": {"name": "库拉斯特海港", "room_path": "/d/act3/kurast_docks", "stage_count": 23},
		"act4": {"name": "群魔堡垒", "room_path": "/d/act4/pandemonium_fortress", "stage_count": 9},
		"act5": {"name": "哈洛加斯", "room_path": "/d/act5/harrogath", "stage_count": 18}
	}

	for act_id in expected_towns:
		var exp = expected_towns[act_id]
		assert(WorldMapScript.ACTS_CONFIG.has(act_id), "ACTS_CONFIG 必须包含 %s" % act_id)
		var act_cfg = WorldMapScript.ACTS_CONFIG[act_id]
		var spots = act_cfg["spots"]
		assert(spots.size() == exp["stage_count"], "%s 据点总数应为 %d，实际为 %d" % [act_id, exp["stage_count"], spots.size()])
		
		# 验证第 0 位小站数据
		var wp = spots[0]
		assert(wp.get("is_town", false) == true, "%s 首个据点必须标记 is_town == true" % act_id)
		assert(wp.get("stage_id", -1) == 0, "%s 小站 stage_id 必须为 0" % act_id)
		assert(wp.get("name") == exp["name"], "%s 小站名字必须为 %s，实际为 %s" % [act_id, exp["name"], wp.get("name")])
		assert(wp.get("room_path") == exp["room_path"], "%s 落地点 room 必须为 %s，实际为 %s" % [act_id, exp["room_path"], wp.get("room_path")])
		print("  ✔ %s: %s (落地点: %s, 共 %d 个据点) 校验通过！" % [act_id, wp["name"], wp["room_path"], spots.size()])

	print("✔ [Test 1 通过] ACT 1-5 全 5 幕安全区小站配置均准确无误！")

## Test 2: 验证据点组件 (battle_spot.gd) 的小站专属渲染
func _test_battle_spot_waypoint_rendering() -> void:
	print("\n[Test 2] 验证据点组件 (battle_spot.gd) 小站奥术幽蓝与神圣金边渲染...")
	var spot = BattleSpotScene.instantiate()
	add_child(spot)

	var wp_data = {
		"stage_id": 0,
		"name": "罗格营地",
		"lvl": 0,
		"boss": "传送小站",
		"pos": Vector2(530, 650),
		"is_town": true,
		"room_path": "/d/act1/rogue_camp",
		"unlocked": true,
		"cleared": true
	}
	spot.setup(wp_data)
	
	assert(spot.name_label.text == "🌟 罗格营地 (小站)", "小站标签文本必须为 '🌟 罗格营地 (小站)'，实际为: '%s'" % spot.name_label.text)
	assert(spot.icon_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "小站光标必须为可点击手型")
	
	spot.queue_free()
	print("✔ [Test 2 通过] 据点组件渲染小站文案与光标样式验证无误！")

## Test 3: 验证挂机 HUD 中点击大地图小站发送 stage town 指令
func _test_afk_main_hud_waypoint_click() -> void:
	print("\n[Test 3] 验证在野外战场 (afk_main_hud) 点击大地图小站触发脱战回城...")
	var hud: AFK_MainHUD = MainHudScene.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var sent_cmds: Array[String] = []
	var on_data_sent = func(cmd: String):
		sent_cmds.append(cmd.strip_edges())
	NetworkClient.raw_sent.connect(on_data_sent)

	# 模拟点击大地图上的第一幕小站 (罗格营地)
	sent_cmds.clear()
	var act1_wp = WorldMapScript.ACTS_CONFIG["act1"]["spots"][0].duplicate()
	act1_wp["act_id"] = "act1"
	hud._on_spot_selected(act1_wp)
	await get_tree().process_frame

	assert(sent_cmds.has("stage town act1"), "点击罗格营地小站必须发送 'stage town act1' 指令，实际记录: %s" % str(sent_cmds))
	print("  ✔ 点击罗格营地小站 -> 成功发送 'stage town act1'")

	# 模拟点击大地图上的第二幕小站 (鲁高因)
	sent_cmds.clear()
	var act2_wp = WorldMapScript.ACTS_CONFIG["act2"]["spots"][0].duplicate()
	act2_wp["act_id"] = "act2"
	hud._on_spot_selected(act2_wp)
	await get_tree().process_frame

	assert(sent_cmds.has("stage town act2"), "点击鲁高因小站必须发送 'stage town act2' 指令，实际记录: %s" % str(sent_cmds))
	print("  ✔ 点击鲁高因小站 -> 成功发送 'stage town act2'")

	NetworkClient.raw_sent.disconnect(on_data_sent)
	hud.queue_free()
	print("✔ [Test 3 通过] 战场脱战点选小站回城逻辑验证通过！")

## Test 4: 验证主城中大地图小站跨幕传送
func _test_town_hub_waypoint_cross_act_teleport() -> void:
	print("\n[Test 4] 验证在大本营主城 (town_hub) 点选小站跨幕传送...")
	var town_hub = TownHubScene.instantiate()
	add_child(town_hub)
	await get_tree().process_frame

	var sent_cmds: Array[String] = []
	var on_data_sent = func(cmd: String):
		sent_cmds.append(cmd.strip_edges())
	NetworkClient.raw_sent.connect(on_data_sent)

	town_hub.current_act_key = "act1"
	town_hub.current_room_name = "罗格营地"

	# 1. 点击同幕小站：不应发送网络请求
	sent_cmds.clear()
	var act1_wp = WorldMapScript.ACTS_CONFIG["act1"]["spots"][0].duplicate()
	act1_wp["act_id"] = "act1"
	town_hub._on_map_spot_selected(act1_wp)
	await get_tree().process_frame

	assert(sent_cmds.is_empty(), "点击身处同幕小站时不应重复发送传送指令，实际记录: %s" % str(sent_cmds))
	print("  ✔ 点击当前幕小站 -> 本地智能拦截并友好提示，无冗余网络包")

	# 2. 从罗格营地分别点击第二、三、四、五幕安全区小站，验证发送正确的跨幕指令
	var acts_to_test = [
		{"key": "act2", "name": "鲁高因", "expected": "stage town act2"},
		{"key": "act3", "name": "库拉斯特海港", "expected": "stage town act3"},
		{"key": "act4", "name": "群魔堡垒", "expected": "stage town act4"},
		{"key": "act5", "name": "哈洛加斯", "expected": "stage town act5"}
	]

	for item in acts_to_test:
		sent_cmds.clear()
		# 直接读取未做额外加工的原始据点字典
		var wp_data = WorldMapScript.ACTS_CONFIG[item["key"]]["spots"][0].duplicate(true)
		town_hub._on_map_spot_selected(wp_data)
		await get_tree().process_frame
		assert(sent_cmds.has(item["expected"]), "在罗格营地点击【%s】小站必须精准发送 '%s'，实际捕获: %s" % [item["name"], item["expected"], str(sent_cmds)])
		print("  ✔ 罗格营地点击【%s】安全区小站 -> 成功发出 '%s' 传送指令！" % [item["name"], item["expected"]])

	NetworkClient.raw_sent.disconnect(on_data_sent)
	town_hub.queue_free()
	print("✔ [Test 4 通过] 主城小站跨幕传送逻辑验证通过！")
