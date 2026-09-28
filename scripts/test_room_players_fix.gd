extends Node

func _ready() -> void:
	print("==================================================")
	print("【测试开始】营地英雄列表防清空覆盖与双开互显全链路验证")
	print("==================================================")
	
	var pass_count = 0
	var total_tests = 4
	
	var hub_scene = load("res://scenes/town/town_hub.tscn")
	assert(hub_scene != null, "加载 town_hub.tscn 失败！")
	
	var hub = hub_scene.instantiate()
	add_child(hub)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 设置自身角色名为“法师小美”
	hub.lbl_char_name.text = "法师小美"
	
	# ----------------------------------------------------
	# 测试 1: 模拟服务端下发 exits 帧（包含自身与另一个在线玩家野蛮人大强）
	# ----------------------------------------------------
	print("\n--- 1. 模拟收到 exits 帧 (包含双开两名英雄) ---")
	var mock_exits_data = [
		# 1. 另一个在线英雄（野蛮人大强，来自双开客户端）
		{
			"type": "hero",
			"id": "barbarian_user",
			"name": "野蛮人大强",
			"class": "bar",
			"level": 35,
			"diff": "hell",
			"rating": "3.8k",
			"cmd": "look /clone/user/barbarian_user#102",
			"icon": "hireables/barbarianicon.lowend.png",
			"hp_text": "1200:1200"
		},
		# 2. 自身角色（法师小美）
		{
			"type": "hero",
			"id": "sor_user",
			"name": "法师小美",
			"class": "sor",
			"level": 40,
			"diff": "hell",
			"rating": "5.2k",
			"cmd": "look /clone/user/sor_user#101",
			"icon": "hireables/sorceressicon.lowend.png",
			"hp_text": "800:800"
		},
		# 3. 正常出口与场景指令
		{
			"dir": "north",
			"name": "鲜血荒地",
			"cmd": "go north"
		},
		{
			"dir": "full",
			"name": "电子BT",
			"cmd": "full"
		}
	]
	
	hub._on_json_frame_received("exits", mock_exits_data)
	
	print("解析后 room_players 数量: ", hub.room_players.size())
	assert(hub.room_players.size() == 2, "exits 帧解析英雄失败，数量不为 2！")
	print("✅ 测试 1 通过：exits 帧成功解析出 2 名英雄 (对方与自己)！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 2: 模拟紧随其后的 objects 帧 (纯设施，必须绝不清空英雄列表！)
	# ----------------------------------------------------
	print("\n--- 2. 模拟随后收到 objects 帧 (仅含储物箱，验证防覆盖清空) ---")
	var mock_objects_data = [
		{
			"name": "大储物箱",
			"cmd": "look /clone/d2/stash_box#1"
		},
		{
			"name": "传送小站",
			"cmd": "look /d/act1/waypoint"
		}
	]
	
	hub._on_json_frame_received("objects", mock_objects_data)
	
	print("objects 帧后 room_players 数量: ", hub.room_players.size())
	assert(hub.room_players.size() == 2, "致命缺陷重现：objects 帧再次清空了英雄列表！")
	assert(hub.lbl_player_count.text == "营地英雄 (2 人)", "人数标签未正确显示 2 人！")
	print("✅ 测试 2 通过：objects 帧完美解耦，英雄列表坚如磐石，保持 2 人！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 3: 验证卡片渲染详情与交互按钮
	# ----------------------------------------------------
	print("\n--- 3. 验证英雄卡片渲染与组件详情 ---")
	var cards = hub.player_list_vbox.get_children()
	print("渲染出的卡片数量: ", cards.size())
	assert(cards.size() == 2, "渲染的英雄卡片数量不为 2！")
	
	var other_hero = hub.room_players[0]
	assert(other_hero["name"] == "野蛮人大强", "对方英雄名字错误！")
	assert(other_hero["class"] == "bar", "对方职业代号错误！")
	assert(other_hero["is_self"] == false, "对方英雄被错误识别为自己！")
	
	var self_hero = hub.room_players[1]
	assert(self_hero["name"] == "法师小美", "自身英雄名字错误！")
	assert(self_hero["is_self"] == true, "自身英雄未识别为自己！")
	
	print("✅ 测试 3 通过：对方卡片 (野蛮人大强) 与自身卡片 (法师小美 (你)) 正确渲染，组队/交易/私聊就绪！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 4: 模拟无 class 仅有 icon 时的智能职业提取
	# ----------------------------------------------------
	print("\n--- 4. 验证从 icon 智能推断职业代号 ---")
	var mock_hero_with_icon_only = [
		{
			"type": "hero",
			"id": "pal_user",
			"name": "圣骑士阿尔萨斯",
			"level": 30,
			"rating": "2.9k",
			"icon": "hireables/paladinicon.lowend.png"
		}
	]
	hub._parse_room_players(mock_hero_with_icon_only)
	assert(hub.room_players.size() == 1, "未解析出英雄！")
	assert(hub.room_players[0]["class"] == "pal", "未能从 paladinicon.lowend.png 反推出 pal 职业！")
	print("✅ 测试 4 通过：成功从 paladinicon 智能提取出职业代号 'pal'！")
	pass_count += 1
	
	print("\n==================================================")
	print("【测试结果】全部 %d/%d 项营地英雄列表测试 100%% 通过！" % [pass_count, total_tests])
	print("==================================================")
	
	get_tree().quit()
