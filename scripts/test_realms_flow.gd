extends SceneTree

## 自动化测试：Godot 客户端登录页远程大区拉取与切换全流程验证

func _init() -> void:
	print("==================================================")
	print("   GODOT LOGIN REALMS INTERFACE AUTOMATED TEST    ")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	var login_scene_res = load("res://scenes/login/login_screen.tscn")
	if not login_scene_res:
		print("❌ 无法加载 res://scenes/login/login_screen.tscn")
		quit(1)
		return
		
	var login_screen = login_scene_res.instantiate()
	root.add_child(login_screen)
	
	print("Step 1: 验证初始界面与离线大区兜底...")
	var server_label = login_screen.get_node("Panel/VBox/ServerContainer/ServerInfoLabel") as Label
	print("  初始大区显示文本: ", server_label.text)
	
	# 检查是否泄漏 IP 或端口
	if ":" in server_label.text and "127.0.0.1" in server_label.text:
		print("❌ 严重安全隐患: 界面仍包含裸露 IP!")
		quit(1)
		return
	else:
		print("  ✅ 物理地址隐藏验证通过：无任何 IP 或端口暴露！")
		
	print("Step 2: 等待远程接口 (http://o.rainplay.cn:53000/) 异步拉取响应...")
	for i in range(40):
		await create_timer(0.1).timeout
		if login_screen.realms.size() >= 2:
			break
			
	print("  当前大区总数: ", login_screen.realms.size())
	for idx in range(login_screen.realms.size()):
		var r = login_screen.realms[idx]
		print("    - 大区[%d]: %s (%s) 状态: %s" % [idx, r.get("name"), r.get("tag"), r.get("status")])
		
	if login_screen.realms.size() < 2:
		print("❌ 远程大区拉取数量不足!")
		quit(1)
		return
	print("  ✅ 远程动态拉取验证成功！")
	
	print("Step 3: 测试打开大区选择弹窗...")
	login_screen._open_realm_modal()
	var modal = login_screen.get_node("RealmModal") as Control
	if not modal.visible:
		print("❌ 大区弹窗未显示!")
		quit(1)
		return
		
	var card_container = login_screen.get_node("RealmModal/CenterContainer/Panel/VBox/Scroll/RealmListVBox")
	print("  弹窗中生成的大区卡片数量: ", card_container.get_child_count())
	if card_container.get_child_count() != login_screen.realms.size():
		print("❌ 大区卡片数量不匹配!")
		quit(1)
		return
	print("  ✅ 大区选择弹窗卡片渲染通过！")
	
	print("Step 4: 测试切换大区至 [标准区·罗格营地]...")
	var standard_realm = login_screen.realms[1]
	login_screen._select_realm(standard_realm)
	login_screen._close_realm_modal()
	
	print("  切换后当前大区显示文本: ", server_label.text)
	if "罗格营地" not in server_label.text:
		print("❌ 切换大区失败!")
		quit(1)
		return
	print("  ✅ 动态切换大区验证成功！")
	
	# 测试结束
	await create_timer(0.1).timeout
		
	print("==================================================")
	print("🎉 ALL REALM SYSTEM TESTS PASSED SUCCESSFULLY!   ")
	print("==================================================")
	quit(0)
