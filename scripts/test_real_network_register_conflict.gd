extends Control

## 真实网络端到端测试：验证同名账号注册冲突、无死循环重连、合规标题与绿色版本号
func _ready() -> void:
	print("==================================================")
	print("   START REAL TCP NETWORK REGISTER CONFLICT TEST  ")
	print("==================================================")
	call_deferred("_run_real_test")

func _run_real_test() -> void:
	# 1. 载入并实例化登录场景
	var login_scene = load("res://scenes/login/login_screen.tscn")
	var login_screen = login_scene.instantiate()
	add_child(login_screen)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	# 2. 验证合规化标题 (无战网、无侵权)
	var header = login_screen.get_node("Panel/VBox/PanelHeader")
	print("  当前面板标题: ", header.text)
	assert(not ("战网" in header.text), "面板标题绝不能包含暴雪商标【战网】")
	assert("冒险者通行证" in header.text, "面板标题应为合规的冒险者通行证认证")

	# 3. 验证绿色版本号 V0.1
	var footer = login_screen.get_node("FooterInfo")
	print("  当前版本信息: ", footer.text)
	assert("[color=#44ff44]V0.1[/color]" in footer.text, "版本号必须以绿色 #44ff44 高亮显示 V0.1")

	# 4. 模拟在真实 UI 中输入已存在的账号 testall
	var id_in = login_screen.get_node("Panel/VBox/InputContainer/IdInput")
	var pass_in = login_screen.get_node("Panel/VBox/InputContainer/PassInput")
	var btn_reg = login_screen.get_node("Panel/VBox/ButtonContainer/HBoxSub/BtnRegister")
	var status_lbl = login_screen.get_node("Panel/VBox/StatusLabel")

	id_in.text = "testall"
	pass_in.text = "123456"

	print("\n[Real E2E] 点击【注册账号】按钮，向 127.0.0.1:7878 发送真实注册请求...")
	btn_reg.emit_signal("pressed")

	# 5. 等待真实服务端返回 (轮询等待至多 3 秒)
	var wait_time = 0.0
	var got_expected_error = false
	while wait_time < 3.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
		if "已被注册" in status_lbl.text:
			got_expected_error = true
			break

	print("  服务端真实响应后的状态栏提示: ", status_lbl.text)
	assert(got_expected_error, "必须在 3 秒内收到服务端下发的【该通行证账号已被注册...】提示")
	assert("该通行证账号已被注册" in status_lbl.text, "提示文案必须准确指出已被注册")

	# 6. 等待 1 秒，观察是否发生自动重连死循环
	await get_tree().create_timer(1.0).timeout
	print("  当前重连状态: is_reconnecting=", NetworkClient.is_reconnecting, " manual_disconnect=", NetworkClient.manual_disconnect)
	assert(NetworkClient.is_reconnecting == false, "严禁发生死循环自动重连！")
	assert("该通行证账号已被注册" in status_lbl.text, "断开事件绝不得覆盖具体的业务错误提示！")

	# 7. 截图保存验证
	if DisplayServer.get_name() != "headless":
		var vp = get_viewport()
		if vp and vp.get_texture():
			var img = vp.get_texture().get_image()
			if img:
				var shot_path = "user://real_test_register_conflict.png"
				img.save_png(shot_path)
				print("✔ 真实端到端测试截图已保存至: ", OS.get_user_data_dir() + "/real_test_register_conflict.png")

	print("\n==================================================")
	print("  REAL TCP E2E TEST PASSED 100% SUCCESFULLY!      ")
	print("==================================================")
	get_tree().quit(0)
