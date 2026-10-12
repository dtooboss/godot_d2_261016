extends Control

## 测试大厅英雄卡片点击交易按钮发起 gtrade 指令与提示

func _ready() -> void:
	print("==================================================")
	print("【测试开始】大厅交易按钮 gtrade 协议与提示验证测试")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var hub_scene = load("res://scenes/town/town_hub.tscn")
	assert(hub_scene != null, "加载 town_hub.tscn 失败！")

	var hub = hub_scene.instantiate()
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	hub.lbl_char_name.text = "测试自身"
	hub.current_player_diff = "normal"
	GameState.selected_character = {
		"id": "my_self_id",
		"name": "测试自身",
		"level": 30
	}
	GameState.clear_team()

	var test_heroes = [
		{
			"type": "hero",
			"id": "partner_bob",
			"name": "交易伙伴鲍勃",
			"class": "bar",
			"level": 30,
			"diff": "normal",
			"rating": "3.5k",
			"has_team": 0,
			"is_self": false
		}
	]

	hub.room_players = test_heroes
	hub._render_player_cards()

	var captured_sent_cmds = []
	var on_raw_sent = func(cmd: String):
		captured_sent_cmds.append(cmd)
	NetworkClient.raw_sent.connect(on_raw_sent)

	# 查找【交易伙伴鲍勃】卡片上的交易按钮
	var btn_trade: Button = null
	for card in hub.player_list_vbox.get_children():
		for btn in card.find_children("*", "Button", true, false):
			if btn is Button and btn.text == "交易":
				btn_trade = btn
				break

	assert(btn_trade != null, "交易按钮必须存在于目标玩家卡片中！")
	print("找到交易按钮: text='%s', disabled=%s" % [btn_trade.text, btn_trade.disabled])
	assert(btn_trade.disabled == false, "交易按钮应处于可用状态")

	# 模拟点击交易按钮
	btn_trade.emit_signal("pressed")

	# 验证发送的命令是否为 gtrade partner_bob
	print("捕获发出的指令队列: ", captured_sent_cmds)
	assert(captured_sent_cmds.has("gtrade partner_bob"), "必须发送 'gtrade partner_bob' 指令，而非旧版 trade！")
	print("✅ 验证 1 通过：点击交易按钮成功发送标准战网指令 'gtrade partner_bob'！")

	# 验证 toast 提示不包含羁绊点或战斗时间限制
	var toast_text = hub.toast_label.text
	print("Toast 提示内容: ", toast_text)
	assert(not ("羁绊" in toast_text), "Toast 提示中绝不可出现 '羁绊' 限制字样！")
	assert(not ("并肩作战" in toast_text), "Toast 提示中绝不可出现 '并肩作战' 限制字样！")
	assert("发起交易请求" in toast_text, "Toast 提示应为积极的发起交易请求！")
	print("✅ 验证 2 通过：Toast 提示已彻底取消羁绊点门槛与时间限制！")

	NetworkClient.raw_sent.disconnect(on_raw_sent)

	print("\n==================================================")
	print("🎉 大厅 gtrade 交易指令与免羁绊点测试 100% 验证通过！")
	print("==================================================")
	get_tree().quit(0)
