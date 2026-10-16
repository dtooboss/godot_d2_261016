extends Control

func _ready() -> void:
	print("[Godot Tester] 启动热更新与测试验证流程...")
	call_deferred("_run_flow")

func _run_flow() -> void:
	var test_user = "looktest_99"
	var test_pass = "123456"
	
	NetworkClient.login_failed.connect(func(msg):
		print("[Godot Tester] 登录提示: ", msg)
		if "不存在" in msg or "密码错误" in msg or "未注册" in msg:
			print("[Godot Tester] 尝试注册新测试账号: ", test_user)
			NetworkClient.connect_and_login("127.0.0.1", 7878, test_user, test_pass, "register")
	)

	NetworkClient.login_success.connect(func(char_list):
		print("[Godot Tester] 登录成功，角色列表数量: ", char_list.size())
		if char_list.is_empty():
			print("[Godot Tester] 新建角色并进入...")
			NetworkClient.send_raw("create_char test_sor sor 女")
			await get_tree().create_timer(1.0).timeout
			NetworkClient.send_raw("enter test_sor")
		else:
			var target_char = char_list[0].get("id", char_list[0].get("char_id", ""))
			print("[Godot Tester] 选择现有角色进入: ", target_char)
			NetworkClient.send_raw("enter " + target_char)

		await get_tree().create_timer(1.0).timeout
		print("[Godot Tester] 发送热更新指令: update /cmds/std/look...")
		NetworkClient.send_raw("update /cmds/std/look")
		await get_tree().create_timer(0.4).timeout
		print("[Godot Tester] 发送热更新指令: update /cmds/usr/gidentify...")
		NetworkClient.send_raw("update /cmds/usr/gidentify")
		await get_tree().create_timer(0.4).timeout
		print("[Godot Tester] 执行自动化测试: test_d2_look_unid...")
		NetworkClient.send_raw("test_d2_look_unid")

		await get_tree().create_timer(2.5).timeout
		print("[Godot Tester] ★★★ 测试已全部完成，正常退出 ★★★")
		get_tree().quit(0)
	)

	NetworkClient.text_received.connect(func(t):
		if "PASS" in t or "FAIL" in t or "100%" in t or "未辨识" in t or "短巨战弓" in t or "编译" in t or "成功" in t:
			print(" [MUD 返回] ", t)
	)

	# 先直接尝试登录
	print("[Godot Tester] 正在连接 MUD: ", test_user)
	NetworkClient.connect_and_login("127.0.0.1", 7878, test_user, test_pass, "login")
