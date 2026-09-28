extends Node

## 队伍解散、脱离与卡片上下文交互自动化测试

@onready var party_hud: Control = $PartyHudPanel

var test_dismiss_called: bool = false
var test_tell_target: String = ""

func _ready() -> void:
	print("--- 开始运行队伍解散、脱离与上下文交互自动化测试 ---")
	
	# 模拟当前玩家为野蛮人队长
	GameState.selected_character = { "id": "barb_01", "name": "野蛮人·强哥", "class": "bar" }
	
	var mock_team = [
		{
			"id": "barb_01",
			"name": "野蛮人·强哥",
			"class": "bar",
			"level": 85,
			"hp": 2800,
			"max_hp": 3000,
			"is_leader": true,
			"buffs": ["fanaticism"]
		},
		{
			"id": "sorc_02",
			"name": "法师·冰雪",
			"class": "sor",
			"level": 82,
			"hp": 950,
			"max_hp": 1100,
			"is_leader": false,
			"buffs": ["fanaticism"]
		}
	]
	
	GameState.update_team_data("barb_01", mock_team)
	party_hud.update_party(mock_team)
	
	# 1. 验证队长身份下的操作栏按钮显示
	assert(party_hud.btn_team_action.text == "解散队伍", "队长视角顶部按钮应为【解散队伍】")
	print("✔ 队长视角顶部操作栏按钮渲染正常: ", party_hud.btn_team_action.text)
	
	# 2. 验证点击解散队伍弹出确认框
	party_hud._on_team_action_pressed()
	assert(party_hud.confirm_dialog.visible == true, "点击解散后确认框应弹出显示")
	assert("解散" in party_hud.confirm_msg.text, "确认文本应包含解散提示")
	print("✔ 解散防误触二次确认弹窗弹出正常: ", party_hud.confirm_msg.text)
	
	# 3. 验证确认解散事件
	party_hud.team_dismiss_requested.connect(func():
		test_dismiss_called = true
	)
	party_hud._on_confirm_ok_pressed()
	assert(test_dismiss_called == true, "确认解散信号应正常发射")
	assert(party_hud.confirm_dialog.visible == false, "确认后弹窗应自动关闭")
	print("✔ 队伍解散流程与信号派发正常")
	
	# 4. 验证点击队员卡片弹出上下文菜单
	party_hud._show_context_menu("sorc_02", "法师·冰雪", Vector2(100, 100))
	assert(party_hud.context_menu.visible == true, "点击队员应唤起上下文浮层菜单")
	assert(party_hud.btn_menu_transfer.visible == true, "队长视角应可见【移交队长】")
	assert(party_hud.btn_menu_kick.visible == true, "队长视角应可见【踢出队伍】")
	print("✔ 队长管理上下文菜单（私聊/移交/踢出）展示正常")
	
	# 等待 0.2 秒完成光栅化渲染并截取包含上下文菜单的实景
	await get_tree().create_timer(0.2).timeout
	_take_screenshot("test_party_hud_menu_dismiss_success.png")
	
	# 5. 验证私聊事件派发
	party_hud.tell_requested.connect(func(tid):
		test_tell_target = tid
	)
	party_hud._on_menu_tell_pressed()
	assert(test_tell_target == "sorc_02", "点击私聊应派发目标队员 ID sorc_02")
	assert(party_hud.context_menu.visible == false, "点击操作项后菜单应自动收起")
	print("✔ 队员快捷私聊派发正常: 目标=", test_tell_target)
	
	# 6. 验证队员视角下的按钮显示与权限收缩
	GameState.selected_character = { "id": "sorc_02", "name": "法师·冰雪", "class": "sor" }
	party_hud.update_party(mock_team)
	assert(party_hud.btn_team_action.text == "离开队伍", "队员视角顶部按钮应为【离开队伍】")
	party_hud._show_context_menu("barb_01", "野蛮人·强哥", Vector2(100, 100))
	assert(party_hud.btn_menu_transfer.visible == false, "普通队员不可见【移交队长】")
	assert(party_hud.btn_menu_kick.visible == false, "普通队员不可见【踢出队伍】")
	print("✔ 队员视角【离开队伍】与管理权限收缩隔离正常")
	
	print("🎉 队伍解散、脱离与上下文交互所有自动化测试用例均 100% 通过！")
	get_tree().quit(0)

func _take_screenshot(filename: String) -> void:
	var viewport = get_viewport()
	if not viewport: return
	var tex = viewport.get_texture()
	if not tex: return
	var img = tex.get_image()
	if not img:
		print("当前处于 headless 模式，跳过截图采集")
		return
	var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/" + filename
	img.save_png(save_path)
	print("已保存实机渲染截图至: ", save_path)
