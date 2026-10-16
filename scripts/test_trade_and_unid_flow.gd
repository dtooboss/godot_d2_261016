extends Control

## 交易与未鉴定系统端到端真实网络测试
var received_lines: Array[String] = []
var test_finished: bool = false
var test_success: bool = false

func _ready() -> void:
	print("==================================================")
	print("   START REAL E2E TRADE & UNIDENTIFIED TEST       ")
	print("==================================================")
	
	NetworkClient.text_received.connect(_on_raw_received)
	NetworkClient.json_frame_received.connect(_on_json_received)
	NetworkClient.login_success.connect(_on_login_success)
	NetworkClient.login_failed.connect(_on_login_failed)
	
	call_deferred("_start_login_flow")

func _start_login_flow() -> void:
	print("[E2E] 连接 127.0.0.1:7878 并以账号 xdao2 登录...")
	var err = NetworkClient.connect_and_login("127.0.0.1", 7878, "xdao2", "xdao1234", "login")
	if err != OK:
		printerr("[E2E] 连接失败: ", err)
		get_tree().quit(1)

func _on_login_failed(msg: String) -> void:
	printerr("[E2E] 登录失败: ", msg)
	get_tree().quit(1)

func _on_login_success(characters: Array) -> void:
	print("[E2E] 通行证登录成功，收到角色列表: ", characters.size(), " 个角色")
	GameState.selected_character = {
		"char_id": "xdao2_sor",
		"name": "法法",
		"level": 1,
		"difficulty": "normal"
	}
	# 发送角色进入游戏协议
	print("[E2E] 发送选角进入游戏指令: select_char xdao2_sor normal")
	NetworkClient.send_raw("select_char xdao2_sor normal")
	
	# 等待 1.5 秒进入主城后，发送测试套件指令
	await get_tree().create_timer(1.5).timeout
	print("[E2E] 发送全链路测试指令: test_d2_trade_and_unid")
	NetworkClient.send_raw("test_d2_trade_and_unid")
	
	# 等待测试执行完成 (至多 8 秒)
	var wait_time = 0.0
	while wait_time < 8.0 and not test_finished:
		await get_tree().create_timer(0.2).timeout
		wait_time += 0.2
	
	if test_success:
		print("\n>>> ★★★ GODOT E2E TEST PASSED COMPLETELY! ★★★ <<<\n")
		# 截图存证
		var vp_tex = get_viewport().get_texture()
		if vp_tex:
			var img = vp_tex.get_image()
			if img:
				img.save_png("C:/Users/Administrator/.gemini/antigravity/brain/ec019a2c-0e22-4c1e-a5f7-c8b6eefd70db/trade_and_unid_test_success.png")
				print("截图已保存至: trade_and_unid_test_success.png")
		get_tree().quit(0)
	else:
		printerr("\n>>> ⚠ TEST TIMEOUT OR FAILED! <<<\n")
		get_tree().quit(1)

func _on_raw_received(line: String) -> void:
	received_lines.append(line)
	print("[Server Line] ", line.strip_edges())
	if "[PASS]" in line:
		print("  ", line.strip_edges())
	if "全部 8 项核心测试用例 100% 验证通过" in line:
		print("\n  ✔ 收到服务端确认: 全部 8 项核心测试用例 100% 验证通过！")
		test_finished = true
		test_success = true
func _on_json_received(type: String, data: Variant) -> void:
	var text_content = str(data)
	if "[PASS]" in text_content:
		print("  ", text_content.strip_edges())
	if "全部 8 项核心测试用例 100% 验证通过" in text_content:
		print("\n  ✔ 收到服务端确认: 全部 8 项核心测试用例 100% 验证通过！")
		test_finished = true
		test_success = true
	elif "FAIL" in text_content:
		printerr("  ✘ 收到服务端失败战报: ", text_content)
		test_finished = true
		test_success = false

