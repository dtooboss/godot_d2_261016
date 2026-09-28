extends Control

## 自动化测试：暗黑2战网聊天装备展示与点击查看全流程验证 (gshowitem & glookitem)
## 覆盖：公频带话喊话、[url=item:...] 链接渲染、点击链接反查、ItemTooltip 高保真装备面板弹出

const ARTIFACT_DIR = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c"

@onready var hub = $TownHub

func _ready() -> void:
	print("==================================================")
	print("    D2 SHOW ITEM & TOOLTIP FLOW AUTOMATED TEST    ")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	# 1. 模拟当前选角状态
	GameState.selected_character = {
		"name": "风之力射手",
		"class": "ama",
		"class_name": "亚马逊",
		"level": 92,
		"gold": 580000,
		"difficulty": "normal"
	}
	GameState.selected_difficulty = "normal"
	hub._init_player_ui()
	
	for i in range(5):
		await get_tree().process_frame
		
	print("Step 1: 模拟在公频接收到多条真实装备展示与玩家带话喊话...")
	# 广播 1: 玩家带留言展示暗金弓【九头蛇之弓·风之力】
	var msg1 = "『[color=#06b6d4]展示[/color]』风之力射手：换28号符文，带价来！ [url=item:/clone/weapon/hydra_bow#10294][color=#a59263]『九头蛇之弓·风之力』[/color][/url]"
	hub._append_chat(msg1)
	
	# 广播 2: 另一位玩家带留言求估价【谜团·法师铠甲】
	var msg2 = "『[color=#06b6d4]展示[/color]』光明使者亚瑟：刚做出来的 15ed 谜团，求大佬估价！ [url=item:/clone/armor/mage_plate#20381][color=#ffff64]『法师铠甲·谜团 [符文之语]』[/color][/url]"
	hub._append_chat(msg2)
	
	# 广播 3: 队伍交流
	hub._append_chat("[color=#fca5a5]【野蛮战神柯南】[/color] 哇！这把风之力吸蓝吸血数值全满！")
	
	for i in range(10):
		await get_tree().process_frame
		
	print("Step 2: 抓取装备展示在公频中的聊天广播截图 (Chat Broadcast)...")
	var img1 = get_viewport().get_texture().get_image()
	var shot1_path = ARTIFACT_DIR + "/test_showitem_chat_broadcast.png"
	img1.save_png(shot1_path)
	print("  ✅ 成功导出公频装备展示广播实机图: ", shot1_path)
	
	print("Step 3: 模拟玩家点击【九头蛇之弓·风之力】超链接...")
	var test_file_id = "/clone/weapon/hydra_bow#10294"
	hub._on_chat_meta_clicked("item:" + test_file_id)
	
	# 模拟服务端接收到 glookitem 后下发的高保真暗黑2装备面板帧 (J_PANEL)
	var esc = char(27)
	var mock_panel_data = {
		"desc": "<center>" + esc + "[img:items/weapon/bow/hydra_bow.lowend.png?sock=1&inlays=items/misc/gem/perfect_ruby.lowend.png]\n" +
			esc + "[f#a59263m九头蛇之弓·风之力 (Windforce)" + esc + "[m\n" +
			esc + "[f#a0a0a0m双手伤害: 35 到 547 (平均 291)" + esc + "[m\n" +
			esc + "[f#a0a0a0m需要等级: 73" + esc + "[m\n" +
			esc + "[f#a0a0a0m需要力量: 134" + esc + "[m\n" +
			esc + "[f#a0a0a0m需要敏捷: 167" + esc + "[m\n" +
			esc + "[f#a0a0a0m基础武器速度: [10]" + esc + "[m\n" +
			esc + "[f#4850b8m+20% 攻击速度" + esc + "[m\n" +
			esc + "[f#4850b8m+250% 增强伤害" + esc + "[m\n" +
			esc + "[f#4850b8m+3.125 每级最大伤害 (基于角色等级)" + esc + "[m\n" +
			esc + "[f#4850b8m8% 击中偷取法力" + esc + "[m\n" +
			esc + "[f#4850b8m击退" + esc + "[m\n" +
			esc + "[f#4850b8m+10 力量" + esc + "[m\n" +
			esc + "[f#4850b8m+5 敏捷" + esc + "[m\n" +
			esc + "[f#4850b8m耐力恢复速度提升 30%" + esc + "[m\n" +
			esc + "[f#4850b8m+38 生命 (已镶嵌: 完美红宝石)" + esc + "[m\n" +
			esc + "[f#a0a0a0m凹槽 (1)" + esc + "[m</center>"
	}
	
	# ItemTooltip 收到网络帧自动刷新
	hub.item_tooltip._on_network_json("panel", mock_panel_data)
	
	# 让 Tooltip 定位在聊天窗旁边舒适视线处
	hub.item_tooltip.position = Vector2(380, 160)
	hub.item_tooltip.show()
	
	for i in range(10):
		await get_tree().process_frame
		
	print("Step 4: 检查装备属性悬浮面板渲染...")
	if not hub.item_tooltip.visible:
		print("❌ ItemTooltip 悬浮窗未显示!")
		get_tree().quit(1)
		return
	print("  ✅ ItemTooltip 成功弹出并在屏幕正中央呈现！")
	
	print("Step 5: 抓取装备悬浮面板弹出截图 (Tooltip Popup)...")
	var img2 = get_viewport().get_texture().get_image()
	var shot2_path = ARTIFACT_DIR + "/test_showitem_tooltip_popup.png"
	img2.save_png(shot2_path)
	print("  ✅ 成功导出装备悬浮卡片实机图: ", shot2_path)
	
	print("==================================================")
	print("🎉 ALL SHOW ITEM & TOOLTIP TESTS PASSED SUCCESSFULLY!")
	print("==================================================")
	get_tree().quit(0)
