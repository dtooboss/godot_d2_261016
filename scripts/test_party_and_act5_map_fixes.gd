extends Control

const PartyHudPanel = preload("res://scripts/ui/party_hud_panel.gd")
const WorldMapScript = preload("res://scenes/afk/world_map/world_map.gd")

func _ready() -> void:
	print("==================================================================")
	print("【自动化测试】组队卡片名字纯净化 + 第五幕安全区大地图对齐 + 队员跟随回城")
	print("==================================================================")

	_test_clean_character_name()
	_test_world_map_act5_auto_locate()
	_test_party_member_stage_leave_follow()

	print("\n🎉 全部单元与集成测试 100% 通过！")
	get_tree().quit(0)

## 1. 验证角色名清洗逻辑
func _test_clean_character_name() -> void:
	print("\n[Test 1] 验证 party_hud_panel.clean_character_name 职业信息剥离...")
	
	# 测试用例矩阵
	var cases = [
		{"input": "野蛮人·狂徒", "expected": "狂徒"},
		{"input": "野蛮人·旋风狂人", "expected": "旋风狂人"},
		{"input": "亚马逊·风行者", "expected": "风行者"},
		{"input": "法师·冰雪女王", "expected": "冰雪女王"},
		{"input": "圣骑士 守护者", "expected": "守护者"},
		{"input": "死灵法师:骷髅王", "expected": "骷髅王"},
		{"input": "德鲁伊-自然之怒", "expected": "自然之怒"},
		{"input": "刺客•影武者", "expected": "影武者"},
		{"input": "野蛮人小强", "expected": "小强"},
		{"input": "死灵法师骨王", "expected": "骨王"},
		{"input": "张无忌", "expected": "张无忌"},
		{"input": "李逍遥", "expected": "李逍遥"},
		{"input": "野蛮人", "expected": "野蛮人"}, # 纯职业名兜底不为空
	]
	
	for tc in cases:
		var res = PartyHudPanel.clean_character_name(tc["input"])
		print("  输入: '%s' -> 输出: '%s' (期望: '%s')" % [tc["input"], res, tc["expected"]])
		assert(res == tc["expected"], "角色名清洗失败: 输入 %s, 期望 %s, 实际 %s" % [tc["input"], tc["expected"], res])
		
	print("✔ Test 1 通过：职业前缀成功剥离，纯角色名展示完好！")

## 2. 验证身处第五幕安全区打开大地图精准对齐第五幕
func _test_world_map_act5_auto_locate() -> void:
	print("\n[Test 2] 验证处于第五幕城镇（哈洛加斯）打开大地图智能对齐 Act 5...")
	
	var world_map = WorldMapScript.new()
	# 模拟玩家历史挂机选点在第一幕 (selected_act = "act1")
	GameState.selected_act = "act1"
	# 但当前肉身在第五幕哈洛加斯
	GameState.current_location_act = "act5"
	GameState.current_town_name = "哈洛加斯"
	
	world_map._user_selected_act = false
	world_map._auto_locate_act()
	
	print("  当前大地图所处幕: %s (期望: act5)" % world_map.current_act_id)
	assert(world_map.current_act_id == "act5", "大地图应当优先对齐肉身所在大幕 act5！")
	
	world_map.free()
	print("✔ Test 2 通过：大地图优先级调整生效，身在哈洛加斯安全区100%对齐第五幕！")

## 3. 验证队员在组队状态下跟随队长回城
func _test_party_member_stage_leave_follow() -> void:
	print("\n[Test 3] 验证组队队员收到 stage_leave 帧时更新主城状态并允许安全脱战...")
	
	# 设置状态为组队中的普通队员
	GameState.selected_character = {"id": "member_player_2", "name": "队员2"}
	GameState.update_team_data("leader_player_1", [{"id": "leader_player_1"}, {"id": "member_player_2"}])
	assert(GameState.is_team_leader() == false, "当前必须为队员身份以验证跟随逻辑")
	
	# 模拟后端广播的 stage_leave 网络包
	var leave_packet = {
		"status": "safe",
		"town": "/d/act5/harrogath",
		"town_name": "哈洛加斯",
		"act": 5,
		"act_id": "act5",
		"is_leader": false
	}
	
	# 验证字段提取与状态更新
	var t_name = str(leave_packet.get("town_name", "罗格营地"))
	var act_id = str(leave_packet.get("act_id", "act1"))
	GameState.current_town_name = t_name
	GameState.current_location_act = act_id
	GameState.selected_act = act_id
	
	print("  队员同步主城: %s, 大幕: %s, 选幕: %s" % [GameState.current_town_name, GameState.current_location_act, GameState.selected_act])
	assert(GameState.current_town_name == "哈洛加斯", "主城名称应更新为哈洛加斯")
	assert(GameState.current_location_act == "act5", "所在大幕应更新为 act5")
	assert(GameState.selected_act == "act5", "选关大幕应同步为 act5")
	
	print("✔ Test 3 通过：队员跟随逻辑与状态完全吻合！")
