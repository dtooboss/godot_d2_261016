extends Control

## 大厅英雄列表组队按钮已有队伍置灰及各边界状态测试脚本

func _ready() -> void:
	print("==================================================")
	print("【测试开始】大厅英雄列表组队按钮状态全矩阵自动化测试")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var hub_scene = load("res://scenes/town/town_hub.tscn")
	assert(hub_scene != null, "加载 town_hub.tscn 失败！")

	var hub = hub_scene.instantiate()
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	hub.lbl_char_name.text = "自身英雄"
	hub.current_player_diff = "normal"
	GameState.selected_character = {
		"id": "my_self_id",
		"name": "自身英雄",
		"level": 30
	}
	GameState.clear_team()

	# 构造 5 名测试英雄覆盖全部场景
	var mock_heroes_data = [
		# 1. 自身英雄
		{
			"type": "hero",
			"id": "my_self_id",
			"name": "自身英雄",
			"class": "pal",
			"level": 30,
			"diff": "normal",
			"rating": "3.5k",
			"has_team": 0,
			"is_self": true
		},
		# 2. 自由可组队英雄 (双方空闲同难度)
		{
			"type": "hero",
			"id": "free_hero_id",
			"name": "流浪剑客",
			"class": "bar",
			"level": 28,
			"diff": "normal",
			"rating": "2.8k",
			"has_team": 0,
			"is_self": false
		},
		# 3. 已经在其他队伍中的英雄
		{
			"type": "hero",
			"id": "busy_hero_id",
			"name": "名花有主",
			"class": "sor",
			"level": 32,
			"diff": "normal",
			"rating": "3.2k",
			"has_team": 1,
			"is_self": false
		},
		# 4. 不同难度的英雄
		{
			"type": "hero",
			"id": "diff_hero_id",
			"name": "地狱强者",
			"class": "nec",
			"level": 70,
			"diff": "hell",
			"rating": "8.5k",
			"has_team": 0,
			"is_self": false
		},
		# 5. 我队伍中的队友
		{
			"type": "hero",
			"id": "teammate_id",
			"name": "我的跟班",
			"class": "dru",
			"level": 25,
			"diff": "normal",
			"rating": "2.1k",
			"has_team": 1,
			"is_self": false
		}
	]

	# ------------------------------------------------------------
	# 阶段 1：未组队状态下的列表测试
	# ------------------------------------------------------------
	print("\n--- 阶段 1: 自身未组队状态下的按钮表现 ---")
	hub.room_players = mock_heroes_data.duplicate(true)
	hub._render_player_cards()

	# 1.1 测试【名花有主】(已有其他队伍)
	var btn_busy = _find_hero_button(hub, "名花有主")
	assert(btn_busy != null, "已有队伍英雄组队按钮必须存在")
	print("已有队伍英雄按钮: text='%s', disabled=%s, tooltip='%s'" % [btn_busy.text, btn_busy.disabled, btn_busy.tooltip_text])
	assert(btn_busy.text == "已有队伍", "按钮文本应为 '已有队伍'")
	assert(btn_busy.disabled == true, "已有队伍英雄按钮必须被禁用置灰！")
	assert("其他队伍" in btn_busy.tooltip_text, "tooltip 应提示已在其他队伍中")
	print("✅ 测试 1.1 通过：目标已有队伍时，大厅组队按钮成功置灰不可用！")

	# 1.2 测试【流浪剑客】(自由英雄)
	var btn_free = _find_hero_button(hub, "流浪剑客")
	assert(btn_free != null, "自由英雄组队按钮必须存在")
	print("自由英雄按钮: text='%s', disabled=%s" % [btn_free.text, btn_free.disabled])
	assert(btn_free.text == "组队", "自由英雄按钮文本应为 '组队'")
	assert(btn_free.disabled == false, "自由英雄按钮应为可用状态")
	print("✅ 测试 1.2 通过：双方均自由时，组队按钮正常可用！")

	# 1.3 测试【地狱强者】(跨难度)
	var btn_diff = _find_hero_button(hub, "地狱强者")
	assert(btn_diff != null, "跨难度英雄组队按钮必须存在")
	print("跨难度英雄按钮: text='%s', disabled=%s" % [btn_diff.text, btn_diff.disabled])
	assert(btn_diff.disabled == true, "跨难度英雄组队按钮应禁用")
	print("✅ 测试 1.3 通过：跨难度英雄正确拦截！")

	# ------------------------------------------------------------
	# 阶段 2：自身已入队但为队员 (非队长)
	# ------------------------------------------------------------
	print("\n--- 阶段 2: 自身已入队且为普通队员 ---")
	var team_data_member = [
		{"id": "boss_leader", "name": "大队长", "is_leader": true},
		{"id": "my_self_id", "name": "自身英雄", "is_leader": false},
		{"id": "teammate_id", "name": "我的跟班", "is_leader": false}
	]
	GameState.update_team_data("boss_leader", team_data_member)
	hub._render_player_cards()

	var btn_free_as_member = _find_hero_button(hub, "流浪剑客")
	print("自身为队员时看自由英雄: text='%s', disabled=%s, tooltip='%s'" % [btn_free_as_member.text, btn_free_as_member.disabled, btn_free_as_member.tooltip_text])
	assert(btn_free_as_member.disabled == true, "队员不可邀请新队员，必须置灰禁用！")
	assert("只有队伍领袖" in btn_free_as_member.tooltip_text, "应提示只有领袖可邀请")
	print("✅ 测试 2 通过：队员无权限邀请他人，按钮正确置灰！")

	# ------------------------------------------------------------
	# 阶段 3：自身已入队且为队长，队伍已满员 (5人)
	# ------------------------------------------------------------
	print("\n--- 阶段 3: 自身为队长且队伍满员 5 人 ---")
	var team_data_full = [
		{"id": "my_self_id", "name": "自身英雄", "is_leader": true},
		{"id": "m1", "name": "队员1"},
		{"id": "m2", "name": "队员2"},
		{"id": "m3", "name": "队员3"},
		{"id": "m4", "name": "队员4"}
	]
	GameState.update_team_data("my_self_id", team_data_full)
	hub._render_player_cards()

	var btn_free_as_full = _find_hero_button(hub, "流浪剑客")
	print("满员队长看自由英雄: text='%s', disabled=%s" % [btn_free_as_full.text, btn_free_as_full.disabled])
	assert(btn_free_as_full.text == "队满", "满员应显示 '队满'")
	assert(btn_free_as_full.disabled == true, "满员队长不可再邀请他人")
	print("✅ 测试 3 通过：队伍满员时按钮正确显示 '队满' 并禁用！")

	# ------------------------------------------------------------
	# 阶段 4：队长看自己的队友 (应显示踢出)
	# ------------------------------------------------------------
	print("\n--- 阶段 4: 队长看己方队员 ---")
	var team_data_leader = [
		{"id": "my_self_id", "name": "自身英雄", "is_leader": true},
		{"id": "teammate_id", "name": "我的跟班", "is_leader": false}
	]
	GameState.update_team_data("my_self_id", team_data_leader)
	hub._render_player_cards()

	var btn_teammate = _find_hero_button(hub, "我的跟班")
	assert(btn_teammate != null, "队友按钮必须存在")
	print("队长看队员按钮: text='%s', disabled=%s" % [btn_teammate.text, btn_teammate.disabled])
	assert(btn_teammate.text == "踢出", "队长看队友应显示 '踢出'")
	assert(btn_teammate.disabled == false, "队长踢出按钮应可用")
	print("✅ 测试 4 通过：队长看队员显示 '踢出' 且可点击！")

	print("\n==================================================")
	print("🎉 大厅英雄列表组队按钮所有测试场景 100% 通过！")
	print("==================================================")
	get_tree().quit(0)

func _find_hero_button(hub: Control, hero_name: String) -> Button:
	if hub == null or hub.player_list_vbox == null: return null
	for card in hub.player_list_vbox.get_children():
		var name_lbl = _find_label_with_text(card, hero_name)
		if name_lbl != null:
			for child in card.find_children("*", "Button", true, false):
				if child is Button and child.text in ["组队", "已有队伍", "已入队", "踢出", "队满"]:
					return child
	return null

func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and text in node.text:
		return node
	for child in node.get_children():
		var res = _find_label_with_text(child, text)
		if res != null: return res
	return null
