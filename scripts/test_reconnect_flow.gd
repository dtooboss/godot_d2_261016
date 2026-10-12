extends Control

## 断线自动重连全链路核心逻辑自动化测试

func _ready() -> void:
	print("==================================================")
	print("【测试开始】断线自动重连全链路逻辑测试")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 确保测试环境干净
	NetworkClient.disconnect_server(true)
	GameState.clear_team()
	GameState.selected_character = {}

	# ------------------------------------------------------------
	# 测试 1: 验证初始网络状态与凭证记录
	# ------------------------------------------------------------
	print("\n--- 测试 1: 初始参数与凭证记录 ---")
	NetworkClient.current_host = "127.0.0.1"
	NetworkClient.current_port = 29999
	NetworkClient.auth_user = "test_user"
	NetworkClient.auth_pass = "test_pass"
	NetworkClient.server_key = "AP4s3dF5"
	NetworkClient.auto_reconnect = true
	NetworkClient.manual_disconnect = false
	NetworkClient.is_reconnecting = false
	NetworkClient.reconnect_attempts = 0

	assert(NetworkClient.auto_reconnect == true, "必须默认启用自动重连")
	assert(NetworkClient.MAX_RECONNECT_ATTEMPTS == 10, "最大重连尝试次数必须为 10 次")
	print("✅ 测试 1 通过：基础参数与重连配置初始化正确！")

	# ------------------------------------------------------------
	# 测试 2: 验证直连角色握手包生成 (游戏中掉线)
	# ------------------------------------------------------------
	print("\n--- 测试 2: 验证在游戏中掉线时的直连角色握手包 ---")
	GameState.selected_character = {
		"id": "my_paladin_99",
		"name": "圣骑士无敌",
		"difficulty": "hell"
	}
	
	var captured = { "pkt": "" }
	var on_sent = func(pkt: String):
		if "║json║" in pkt:
			captured["pkt"] = pkt
	NetworkClient.raw_sent.connect(on_sent)

	# 模拟收到服务端的版本协商指令
	NetworkClient._handle_incoming_line("ver1.0,crypt")
	# 模拟收到版本协商通过
	NetworkClient._handle_incoming_line("版本验证成功")

	print("抓取到的认证包: ", captured["pkt"])
	var expected_direct_pkt = "test_user║test_pass║AP4s3dF5║json║my_paladin_99║hell"
	assert(captured["pkt"] == expected_direct_pkt, "断线重连直连认证包必须精准匹配角色与难度！实际: " + captured["pkt"])
	print("✅ 测试 2 通过：游戏中掉线能够生成直连角色的重连包！")

	# ------------------------------------------------------------
	# 测试 3: 验证在大厅未进游戏时的普通握手包
	# ------------------------------------------------------------
	print("\n--- 测试 3: 验证在大厅未进游戏时的普通登录握手包 ---")
	GameState.selected_character = {}
	captured["pkt"] = ""
	NetworkClient._handle_incoming_line("版本验证成功")
	print("抓取到的大厅认证包: ", captured["pkt"])
	var expected_lobby_pkt = "test_user║test_pass║AP4s3dF5║json║login"
	assert(captured["pkt"] == expected_lobby_pkt, "大厅掉线认证包必须为普通 login 格式！实际: " + captured["pkt"])
	print("✅ 测试 3 通过：大厅掉线正确回退到常规登录！")

	NetworkClient.raw_sent.disconnect(on_sent)

	# ------------------------------------------------------------
	# 测试 4: 模拟重连周期调度与 reconnecting 信号
	# ------------------------------------------------------------
	print("\n--- 测试 4: 模拟掉线触发重连状态机 ---")
	var rec_state = { "received": false, "attempt": 0 }
	var on_reconnecting = func(attempt: int, _max_attempts: int):
		rec_state["received"] = true
		rec_state["attempt"] = attempt
	NetworkClient.reconnecting.connect(on_reconnecting)

	# 模拟启动重连
	NetworkClient.manual_disconnect = false
	NetworkClient._start_reconnect_cycle()
	assert(NetworkClient.is_reconnecting == true, "掉线后必须处于重连中状态")
	
	# 模拟时间流逝触发初次重连尝试
	NetworkClient._attempt_reconnect()
	assert(rec_state["received"] == true, "必须发出 reconnecting 信号")
	assert(rec_state["attempt"] == 1, "初次尝试次数应为 1")
	print("✅ 测试 4 通过：断线成功触发重连状态机与通知信号！")

	NetworkClient.reconnecting.disconnect(on_reconnecting)

	# ------------------------------------------------------------
	# 测试 5: 模拟收到服务端恢复响应 (login_ok / 0007)
	# ------------------------------------------------------------
	print("\n--- 测试 5: 模拟服务端返回登录成功并触发 reconnected_to_server 信号 ---")
	var ok_state = { "received": false }
	var on_reconnected = func():
		ok_state["received"] = true
	NetworkClient.reconnected_to_server.connect(on_reconnected)

	# 模拟服务端下发 login_ok 帧
	NetworkClient._handle_incoming_line("J_{\"type\":\"login_ok\",\"msg\":\"登录成功\",\"difficulty\":\"hell\"}")
	assert(ok_state["received"] == true, "收到 login_ok 必须发出 reconnected_to_server 信号")
	assert(NetworkClient.is_reconnecting == false, "重连成功后 is_reconnecting 必须复位为 false")
	assert(NetworkClient.reconnect_attempts == 0, "重连成功后重试计数器必须清零")
	print("✅ 测试 5 通过：服务端恢复响应成功触发全局恢复事件！")

	NetworkClient.reconnected_to_server.disconnect(on_reconnected)

	# ------------------------------------------------------------
	# 测试 6: 验证达到最大重试上限时的保护与失败通知
	# ------------------------------------------------------------
	print("\n--- 测试 6: 验证达到最大重试上限时的保护与失败通知 ---")
	var fail_state = { "received": false }
	var on_failed = func():
		fail_state["received"] = true
	NetworkClient.reconnect_failed.connect(on_failed)

	NetworkClient.is_reconnecting = true
	NetworkClient.reconnect_attempts = NetworkClient.MAX_RECONNECT_ATTEMPTS # 达到 10 次
	NetworkClient._attempt_reconnect()

	assert(fail_state["received"] == true, "超过最大重连尝试次数必须发出 reconnect_failed 信号")
	assert(NetworkClient.is_reconnecting == false, "失败后应停止重连")
	print("✅ 测试 6 通过：最大重连限制与失败信号正确拦截！")

	NetworkClient.reconnect_failed.disconnect(on_failed)

	# ------------------------------------------------------------
	# 测试 7: 验证用户主动登出时不触发自动重连
	# ------------------------------------------------------------
	print("\n--- 测试 7: 验证用户主动登出时不触发自动重连 ---")
	NetworkClient.disconnect_server(true)
	assert(NetworkClient.manual_disconnect == true, "手动断开时 manual_disconnect 必须为 true")
	assert(NetworkClient.is_reconnecting == false, "手动断开时不应处于重连状态")
	NetworkClient._start_reconnect_cycle()
	assert(NetworkClient.is_reconnecting == false, "手动断开状态下拒绝启动重连")
	print("✅ 测试 7 通过：用户主动退出不误触发重连！")

	print("\n==================================================")
	print("🎉 断线自动重连全链路所有 7 项核心用例 100% 验证通过！")
	print("==================================================")
	get_tree().quit(0)
