extends Control

const CharacterSelectScene = preload("res://scenes/lobby/character_select_screen.tscn")

func _ready() -> void:
	print("==================================================================")
	print("【自动化回归测试】客户端版本检查与强制更新门禁测试")
	print("==================================================================")

	NetworkClient.set_process(false)
	NetworkClient.is_connected = true

	await _test_scene_nodes_and_defaults()
	await _test_forced_update_flow()
	await _test_optional_update_flow()
	await _test_up_to_date_flow()

	print("\n🎉 全部客户端版本检查与门禁测试 100% 通过！")
	get_tree().quit(0)

## Test 1: 验证角色大厅场景与版本更新节点结构
func _test_scene_nodes_and_defaults() -> void:
	print("\n[Test 1] 验证角色大厅 UpdateModal 节点结构及初始状态...")
	var screen = CharacterSelectScene.instantiate()
	add_child(screen)

	assert(screen.has_node("%UpdateModal"), "必须包含 UpdateModal 节点")
	assert(screen.has_node("%UpdateVersionLabel"), "必须包含 UpdateVersionLabel 节点")
	assert(screen.has_node("%UpdateNoticeText"), "必须包含 UpdateNoticeText 节点")
	assert(screen.has_node("%UpdateStatusLabel"), "必须包含 UpdateStatusLabel 节点")
	assert(screen.has_node("%BtnDownloadUpdate"), "必须包含 BtnDownloadUpdate 节点")
	assert(screen.has_node("%BtnCopyUrl"), "必须包含 BtnCopyUrl 节点")
	assert(screen.has_node("%BtnCloseUpdate"), "必须包含 BtnCloseUpdate 节点")

	var modal = screen.get_node("%UpdateModal")
	assert(modal.visible == false, "UpdateModal 默认应为隐藏状态")

	print("  ✔ UpdateModal 节点树解析与默认隐藏状态校验通过！")
	screen.queue_free()
	await get_tree().process_frame

## Test 2: 验证强制更新流程（旧版本被锁死门禁，无法进入游戏，无法关闭弹窗）
func _test_forced_update_flow() -> void:
	print("\n[Test 2] 验证强制更新流程 (is_forced=1, need_update=1)...")
	var screen = CharacterSelectScene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	# 模拟拥有 1 个角色
	var mock_chars = [{
		"char_id": "test_hero",
		"name": "测试勇士",
		"class": "ama",
		"class_name": "亚马逊",
		"level": 10,
		"unlocked_diff": 1
	}]

	# 模拟收到带有强制更新的 character_list 数据包
	var mock_forced_data = {
		"type": "character_list",
		"characters": mock_chars,
		"version_check": {
			"need_update": 1,
			"is_forced": 1,
			"client_version": "0.0",
			"latest_version": "0.1",
			"min_version": "0.1",
			"download_url": "https://d2.mud.ren/client_0.1.zip",
			"notice": "【紧急维护】0.1 版本已发布，包含跨幕安全区传送与性能优化！"
		}
	}

	screen._on_json_frame_received("character_list", mock_forced_data)
	await get_tree().process_frame

	var modal = screen.get_node("%UpdateModal")
	var ver_lbl = screen.get_node("%UpdateVersionLabel")
	var notice_lbl = screen.get_node("%UpdateNoticeText")
	var btn_close = screen.get_node("%BtnCloseUpdate")
	var btn_enter = screen.get_node("BottomBar/HBox/BtnEnterGame")

	assert(modal.visible == true, "强制更新时 UpdateModal 必须弹出显示")
	assert("0.0" in ver_lbl.text and "0.1" in ver_lbl.text, "版本信息应展示当前 0.0 与最新 0.1")
	assert("紧急维护" in notice_lbl.text, "更新公告富文本应显示服务端下发公告")
	assert(btn_close.visible == false, "强制更新时'稍后更新'按钮必须隐藏不可见")
	assert(btn_enter.disabled == true, "强制更新时'进入游戏'按钮必须被彻底禁用 (disabled = true)")

	# 模拟玩家强行触发进入游戏
	screen._on_enter_game_pressed()
	assert(screen.has_entered_world == false, "处于强制更新状态时，严禁进入世界！")

	# 模拟玩家尝试关闭弹窗
	screen._on_close_update_pressed()
	assert(modal.visible == true, "强制更新状态下点击关闭不能隐藏弹窗！")

	# 测试复制链接能力
	screen._on_copy_url_pressed()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		var clipboard_text = DisplayServer.clipboard_get()
		assert(clipboard_text == "https://d2.mud.ren/client_0.1.zip", "剪贴板内容必须与 download_url 一致")
	else:
		print("  (无头测试模式下剪贴板特性未激活，跳过物理剪贴板内容提取)")

	print("  ✔ 强制更新弹窗展示、按钮禁用、进入世界硬拦截、剪贴板复制全部验证通过！")
	screen.queue_free()
	await get_tree().process_frame

## Test 3: 验证可选更新流程 (is_forced=0, need_update=1)
func _test_optional_update_flow() -> void:
	print("\n[Test 3] 验证非强制更新流程 (is_forced=0, need_update=1)...")
	var screen = CharacterSelectScene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	var mock_chars = [{
		"char_id": "test_hero",
		"name": "测试勇士",
		"class": "sor",
		"class_name": "法师",
		"level": 15,
		"unlocked_diff": 1
	}]

	var mock_optional_data = {
		"type": "character_list",
		"characters": mock_chars,
		"version_check": {
			"need_update": 1,
			"is_forced": 0,
			"client_version": "0.1",
			"latest_version": "0.2",
			"min_version": "0.1",
			"download_url": "https://d2.mud.ren/client_0.2.zip",
			"notice": "【更新提示】0.2 新增更多炫酷光效与装备预览！"
		}
	}

	screen._on_json_frame_received("character_list", mock_optional_data)
	await get_tree().process_frame

	var modal = screen.get_node("%UpdateModal")
	var btn_close = screen.get_node("%BtnCloseUpdate")
	var btn_enter = screen.get_node("BottomBar/HBox/BtnEnterGame")

	assert(modal.visible == true, "可选更新时 UpdateModal 依然提示弹出")
	assert(btn_close.visible == true, "可选更新时'稍后更新'按钮必须可见")

	# 玩家点击'稍后更新'关闭弹窗
	screen._on_close_update_pressed()
	assert(modal.visible == false, "可选更新时玩家可关闭弹窗")
	assert(btn_enter.disabled == false, "可选更新关闭后，玩家可以正常点击进入游戏！")

	print("  ✔ 可选更新展示、关闭窗口、正常进入游戏验证通过！")
	screen.queue_free()
	await get_tree().process_frame

## Test 4: 验证已是最新版本无需更新流程 (is_forced=0, need_update=0)
func _test_up_to_date_flow() -> void:
	print("\n[Test 4] 验证版本最新流程 (is_forced=0, need_update=0)...")
	var screen = CharacterSelectScene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	var mock_chars = [{
		"char_id": "test_hero",
		"name": "测试勇士",
		"class": "bar",
		"class_name": "野蛮人",
		"level": 20,
		"unlocked_diff": 1
	}]

	var mock_latest_data = {
		"type": "character_list",
		"characters": mock_chars,
		"version_check": {
			"need_update": 0,
			"is_forced": 0,
			"client_version": "0.1",
			"latest_version": "0.1",
			"min_version": "0.1",
			"download_url": "https://d2.mud.ren/client_0.1.zip",
			"notice": "已是最新版本。"
		}
	}

	screen._on_json_frame_received("character_list", mock_latest_data)
	await get_tree().process_frame

	var modal = screen.get_node("%UpdateModal")
	var btn_enter = screen.get_node("BottomBar/HBox/BtnEnterGame")

	assert(modal.visible == false, "最新版本时不应弹出 UpdateModal")
	assert(btn_enter.disabled == false, "最新版本时'进入游戏'按钮正常启用")

	print("  ✔ 最新版本状态直通无阻断验证通过！")
	screen.queue_free()
	await get_tree().process_frame
