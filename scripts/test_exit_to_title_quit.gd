extends Control

## 退出到标题与安全登出自动化测试
var _sent_commands: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print("   START EXIT TO TITLE QUIT COMMAND TEST          ")
	print("==================================================")
	NetworkClient.raw_sent.connect(func(cmd: String):
		_sent_commands.append(cmd)
	)
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Test 1: 验证 NetworkClient.safe_quit_and_disconnect 机制
	# ----------------------------------------------------
	print("\n[Test 1] 验证 NetworkClient.safe_quit_and_disconnect 原子登出...")
	_sent_commands.clear()
	NetworkClient.is_connected = true
	NetworkClient.manual_disconnect = false
	NetworkClient.is_reconnecting = false
	GameState.selected_character = {"char_id": "char_test", "name": "测试角色", "level": 50}
	GameState.player_max_stage = 25
	GameState.is_in_team = true
	GameState.chat_history.append("测试传音消息")

	# 执行原子安全退出
	await NetworkClient.safe_quit_and_disconnect()

	# 1.1 必须发送 quit 指令
	assert(_sent_commands.has("quit"), "安全登出必须向服务端发送 quit 指令！当前已发: %s" % str(_sent_commands))
	print("✔ 1.1 quit 指令发送验证通过: ", _sent_commands)

	# 1.2 必须立即标记 manual_disconnect = true 且终止重连
	assert(NetworkClient.manual_disconnect == true, "退出后 manual_disconnect 必须为 true")
	assert(NetworkClient.is_reconnecting == false, "退出后严禁处于重连状态")
	assert(NetworkClient.is_connected == false, "退出后 TCP 连接必须已切断")
	print("✔ 1.2 退出状态机防重连锁定通过！")

	# 1.3 模拟底层后续触发 STATUS_NONE 断开信号，验证绝不误报重连
	NetworkClient._process(0.016)
	assert(NetworkClient.is_reconnecting == false, "收到底层断开绝不得触发自动重连！")
	print("✔ 1.3 底层断开误报重连完全拦截！")

	# 1.4 验证 GameState 角色与主城数据已全部清空复位
	assert(GameState.selected_character.is_empty(), "GameState.selected_character 必须已被清空！")
	assert(GameState.player_max_stage == 0, "GameState.player_max_stage 必须已复位为 0！")
	assert(GameState.is_in_team == false, "GameState.is_in_team 必须已复位为 false！")
	assert(GameState.chat_history.is_empty(), "GameState.chat_history 必须已被清空！")
	print("✔ 1.4 全局游戏状态复位验证通过！")

	# ----------------------------------------------------
	# Test 2: 验证 ControlMatrixPanel 退出按钮信号绑定
	# ----------------------------------------------------
	print("\n[Test 2] 验证 ControlMatrixPanel 退出到标题按钮与信号...")
	var matrix_scene = load("res://scenes/afk/components/control_matrix_panel.tscn")
	var matrix = matrix_scene.instantiate()
	add_child(matrix)
	await get_tree().process_frame

	var btn_exit = matrix.get_node_or_null("%BtnExit")
	assert(btn_exit != null, "退出按钮 %BtnExit 必须存在")
	assert(btn_exit.text == "退出到标题", "按钮文本必须为【退出到标题】")

	print("  matrix.btn_exit is: ", matrix.btn_exit)
	print("  btn_exit connections: ", btn_exit.pressed.get_connections())
	var test_state = { "clicked": false }
	matrix.btn_exit_clicked.connect(func():
		print("  matrix btn_exit_clicked received in test!")
		test_state["clicked"] = true
	)
	btn_exit.pressed.emit()
	print("  after emit, test_state.clicked is: ", test_state["clicked"])
	assert(test_state["clicked"] == true, "点击退出按钮必须触发 btn_exit_clicked 信号")
	print("✔ Test 2 通过: ControlMatrixPanel 退出到标题按钮绑定与信号完全正常！")

	matrix.queue_free()
	await get_tree().process_frame

	print("\n==================================================")
	print("  CONGRATULATIONS: EXIT QUIT TEST PASSED!         ")
	print("==================================================")
	Engine.get_main_loop().quit(0)
