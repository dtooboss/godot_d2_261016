extends Control

func _ready() -> void:
	print("==================================================")
	print("   START REGISTER & CREATE & DELETE CHAR TEST     ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Test 1: 验证 NetworkClient 统一错误分发
	# ----------------------------------------------------
	print("\n[Test 1] 验证 NetworkClient 统一错误分发...")
	var failed_msgs: Array = []
	var json_errors: Array = []
	var on_failed = func(msg: String): failed_msgs.append(msg)
	var on_json_err = func(t: String, d: Variant):
		if t == "error": json_errors.append(d)
	NetworkClient.login_failed.connect(on_failed)
	NetworkClient.json_frame_received.connect(on_json_err)

	# 模拟服务端下发的注册账号已存在错误帧
	var mock_error_frame = "J_{\"type\":\"error\",\"msg\":\"该通行证账号已被注册，请直接登录或更换账号名称！\"}\n"
	NetworkClient._handle_incoming_line(mock_error_frame.strip_edges())

	assert(failed_msgs.size() == 1, "必须触发一次 login_failed 信号")
	assert(failed_msgs[0] == "该通行证账号已被注册，请直接登录或更换账号名称！", "login_failed 文案必须匹配")
	assert(json_errors.size() == 1, "必须触发一次 json_frame_received(error)")
	print("✔ Test 1 通过: 注册与通用 error 协议帧派发与错误提示完美捕获！")

	NetworkClient.login_failed.disconnect(on_failed)
	NetworkClient.json_frame_received.disconnect(on_json_err)

	# ----------------------------------------------------
	# Test 2: 验证角色大厅与创建新英雄弹窗组件
	# ----------------------------------------------------
	print("\n[Test 2] 验证 CharacterSelectController 创建角色弹窗与逻辑...")
	var lobby_scene = load("res://scenes/lobby/character_select_screen.tscn")
	var lobby = lobby_scene.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var title_lbl = lobby.get_node("TopBar/Title")
	print("  大厅标题文字: ", title_lbl.text)
	assert(not ("战网" in title_lbl.text), "大厅标题严禁包含战网侵权字样")
	assert(not ("庇护之地" in title_lbl.text), "大厅标题严禁包含庇护之地字样")
	if DisplayServer.get_name() != "headless":
		var vp = get_viewport()
		if vp and vp.get_texture():
			var img = vp.get_texture().get_image()
			if img: img.save_png("user://character_select_screen.png")

	assert(lobby.btn_create_char != null, "+ 创建新英雄 按钮必须存在")
	assert(lobby.create_char_modal != null, "创建角色模态弹窗必须存在")
	assert(lobby.create_char_modal.visible == false, "模态弹窗默认必须隐藏")

	# 2.1 打开弹窗
	lobby.btn_create_char.emit_signal("pressed")
	assert(lobby.create_char_modal.visible == true, "点击创建按钮后模态弹窗必须显示")
	assert(lobby.class_buttons_map.size() == 7, "必须动态生成 7 大暗黑职业卡片")

	# 2.2 职业与默认性别联动
	lobby._select_create_class("bar")
	assert(lobby.selected_create_class == "bar", "当前选中职业必须为野蛮人")
	assert(lobby.selected_create_gender == "男性", "野蛮人默认性别必须为男性")
	assert(lobby.gender_male.button_pressed == true, "男性单选框必须选中")

	lobby._select_create_class("ama")
	assert(lobby.selected_create_class == "ama", "当前选中职业必须为亚马逊")
	assert(lobby.selected_create_gender == "女性", "亚马逊默认性别必须为女性")
	assert(lobby.gender_female.button_pressed == true, "女性单选框必须选中")

	# 2.3 姓名输入校验：空名
	lobby.char_name_input.text = ""
	lobby.btn_confirm_create.emit_signal("pressed")
	assert("请输入角色姓名" in lobby.modal_error_label.text, "空姓名必须被拦截")

	# 2.4 姓名输入校验：非汉字
	lobby.char_name_input.text = "abc"
	lobby.btn_confirm_create.emit_signal("pressed")
	assert("中文汉字" in lobby.modal_error_label.text, "英文字符必须被拦截")

	# 2.5 姓名输入校验：过长
	lobby.char_name_input.text = "欧阳天霜剑客"
	lobby.btn_confirm_create.emit_signal("pressed")
	assert("2 到 4 个汉字" in lobby.modal_error_label.text, "超过4个汉字必须被拦截")

	# 2.6 合法姓名输入与指令生成
	NetworkClient.set_process(false)
	NetworkClient.is_connected = true
	var sent_cmds: Array = []
	var on_sent = func(cmd: String): sent_cmds.append(cmd)
	NetworkClient.raw_sent.connect(on_sent)

	lobby._select_create_class("sor")
	lobby.char_name_input.text = "紫烟仙子"
	lobby.btn_confirm_create.emit_signal("pressed")

	assert(sent_cmds.size() == 1, "必须发送一条指令")
	assert(sent_cmds[0] == "create_char sor║女性║紫烟仙子", "指令格式必须完全对齐 LPC 协议")
	print("✔ Test 2.6 通过: 合法创建指令精准生成: ", sent_cmds[0])

	# 2.7 模拟收到服务端下发的新角色列表（通过 character_list 帧）
	var mock_new_chars = [
		{
			"char_id": "test_sor",
			"name": "紫烟仙子",
			"class": "sor",
			"class_name": "法师",
			"level": 1,
			"difficulty": "normal"
		}
	]
	lobby._on_json_frame_received("character_list", { "characters": mock_new_chars })
	assert(lobby.create_char_modal.visible == false, "创建成功后模态弹窗必须自动关闭")
	assert(GameState.character_list.size() == 1, "全局角色列表必须同步更新")
	assert(lobby.current_selected_char["name"] == "紫烟仙子", "新建角色必须自动高亮选中")
	print("✔ Test 2.7 通过: 角色列表大厅创建成功闭环联动！")

	# ----------------------------------------------------
	# Test 3: 验证删除注销英雄交互与指令发送
	# ----------------------------------------------------
	print("\n[Test 3] 验证注销英雄确认弹窗与 delete_char 指令...")
	assert(lobby.btn_delete_char != null, "注销英雄按钮必须存在")
	assert(lobby.delete_char_modal != null, "注销确认模态弹窗必须存在")
	assert(lobby.delete_char_modal.visible == false, "注销弹窗默认必须隐藏")

	# 3.1 打开注销弹窗
	lobby.btn_delete_char.emit_signal("pressed")
	assert(lobby.delete_char_modal.visible == true, "点击注销按钮后确认弹窗必须弹出")
	assert("紫烟仙子" in lobby.delete_msg_label.text, "确认弹窗文案必须包含待注销英雄名称")

	# 3.2 确认注销
	sent_cmds.clear()
	lobby.btn_confirm_delete.emit_signal("pressed")
	assert(sent_cmds.size() == 1, "必须发送一条删除指令")
	assert(sent_cmds[0] == "delete_char test_sor", "删除指令格式必须为 delete_char <char_id>")
	print("✔ Test 3.2 通过: 删除指令精准生成: ", sent_cmds[0])

	# 3.3 模拟服务端删除完成下发空角色列表
	lobby._on_json_frame_received("character_list", { "characters": [] })
	assert(lobby.delete_char_modal.visible == false, "删除成功后注销弹窗必须自动关闭")
	assert(GameState.character_list.is_empty(), "角色列表已清空")
	assert(lobby.btn_enter_game.disabled == true, "角色清空后进入游戏按钮必须禁用")
	assert(lobby.btn_delete_char.disabled == true, "角色清空后注销按钮必须禁用")
	print("✔ Test 3.3 通过: 角色注销全流程闭环联动成功！")

	NetworkClient.raw_sent.disconnect(on_sent)
	NetworkClient.is_connected = false
	lobby.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 4: 验证登录界面绿色版本号 V0.1 动态渲染
	# ----------------------------------------------------
	print("\n[Test 4] 验证 LoginScreen 版本号与绿色富文本...")
	var login_scene = load("res://scenes/login/login_screen.tscn")
	var login_instance = login_scene.instantiate()
	add_child(login_instance)
	await get_tree().process_frame

	var footer = login_instance.get_node_or_null("FooterInfo")
	assert(footer != null, "FooterInfo 节点必须存在")
	assert(footer is RichTextLabel, "FooterInfo 必须是 RichTextLabel")
	print("  FooterInfo 文本内容: ", footer.text)
	assert("V0.1" in footer.text, "版本号必须显示 V0.1")
	assert("[color=#44ff44]V0.1[/color]" in footer.text, "版本号 V0.1 必须使用绿色 #44ff44 高亮渲染")
	print("✔ Test 4 通过: 登录界面版本号 V0.1 绿色高亮渲染验证无误！")

	# ----------------------------------------------------
	# Test 5: 验证同名注册报错防重连死循环与文案防覆盖保护
	# ----------------------------------------------------
	print("\n[Test 5] 验证同名通行证注册报错与断连防冲刷保护...")
	# 模拟发起注册请求
	NetworkClient.is_reconnecting = false
	NetworkClient.manual_disconnect = false
	login_instance._last_error_time = 0.0

	# 模拟收到同名注册失败的错误协议帧
	var mock_reg_conflict = "J_{\"type\":\"error\",\"msg\":\"该通行证账号已被注册，请直接登录或更换账号名称！\"}\n"
	NetworkClient._handle_incoming_line(mock_reg_conflict.strip_edges())

	# 断言 1: NetworkClient 收到 error 帧后必须设置 manual_disconnect = true，阻断自动重连
	assert(NetworkClient.manual_disconnect == true, "业务错误必须触发 manual_disconnect = true 阻断自动重连死循环")
	assert(NetworkClient.is_reconnecting == false, "不能处于正在重连状态")

	# 断言 2: LoginController 状态栏必须显示具体的错误提示
	var status_lbl = login_instance.get_node_or_null("Panel/VBox/StatusLabel")
	assert(status_lbl != null, "StatusLabel 必须存在")
	assert("该通行证账号已被注册" in status_lbl.text, "状态栏必须显示通行证已被注册提示，实际为: " + status_lbl.text)

	# 断言 3: 模拟紧随其后的断开连接信号 _on_disconnected()，验证文案不被冲刷
	login_instance._on_disconnected()
	assert("该通行证账号已被注册" in status_lbl.text, "断开连接事件不得覆盖具体业务报错提示，实际为: " + status_lbl.text)
	print("✔ Test 5 通过: 同名注册错误提示常驻且彻底阻断死循环自动重连！")

	login_instance.queue_free()
	await get_tree().process_frame

	print("\n==================================================")
	print("  CONGRATULATIONS: ALL REG, CREATE, DELETE OK!    ")
	print("==================================================")
	get_tree().quit(0)
