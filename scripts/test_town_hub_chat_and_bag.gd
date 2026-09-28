extends Node

func _ready() -> void:
	print("=== 开始自动化测试：大本营三频道聊天、热键焦点隔离与 gbag 背包体系 ===")
	
	# 1. 实例化大本营场景
	var scene = load("res://scenes/town/town_hub.tscn")
	assert(scene != null, "town_hub.tscn 必须能够成功加载")
	var hub = scene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 捕获 NetworkClient 发送的指令
	var sent_commands = []
	NetworkClient.raw_sent.connect(func(cmd: String):
		sent_commands.append(cmd)
	)
	
	# 2. 验证频道下拉框初始化
	assert(hub.channel_select != null, "必须存在 channel_select 下拉框")
	assert(hub.channel_select.item_count == 3, "必须包含 3 个频道")
	assert(hub.channel_select.get_item_text(0) == "世界", "选项 0 必须为世界")
	assert(hub.channel_select.get_item_text(1) == "队伍", "选项 1 必须为队伍")
	assert(hub.channel_select.get_item_text(2) == "交易", "选项 2 必须为交易")
	assert(hub.channel_select.selected == 0, "默认频道必须为世界")
	print(">>> [验证 1 通过] 频道下拉框（世界/队伍/交易）初始化正确！")
	
	# 3. 验证三频道发送指令映射
	# 测试 3.1: 默认世界频道发送
	sent_commands.clear()
	hub.chat_input.text = "勇士们集结营地！"
	hub._on_chat_submitted(hub.chat_input.text)
	assert(sent_commands.has("chat 勇士们集结营地！"), "世界频道必须发送 chat 指令")
	assert(hub.chat_input.text == "", "发送后输入框必须自动清空")
	
	# 测试 3.2: 队伍频道发送
	sent_commands.clear()
	hub.channel_select.selected = 1
	hub.chat_input.text = "进军鲜血荒野"
	hub._on_chat_submitted(hub.chat_input.text)
	assert(sent_commands.has("tt 进军鲜血荒野"), "队伍频道必须发送 tt 指令")
	
	# 测试 3.3: 交易频道发送
	sent_commands.clear()
	hub.channel_select.selected = 2
	hub.chat_input.text = "出售天界之球+3技能"
	hub._on_chat_submitted(hub.chat_input.text)
	assert(sent_commands.has("bill 出售天界之球+3技能"), "交易频道必须发送 bill 指令")
	print(">>> [验证 2 通过] 三频道指令分发（chat / tt / bill）映射 100% 准确！")
	
	# 4. 验证消息接收放行与视觉转义
	hub._on_text_received("『闲聊』 迪卡凯恩：你好，流浪者。")
	hub._on_text_received("『交易』 恰西：收购优质符文与底材。")
	hub._on_text_received("【队伍】卡夏：全体罗格已就位。")
	hub._on_text_received("你现在并没有和别人组成队伍。")
	
	await get_tree().process_frame
	var chat_text = hub.chat_log.get_parsed_text()
	if chat_text.is_empty():
		chat_text = hub.chat_log.text
	print("chat_log 当前渲染文本: [", chat_text, "]")
	assert("『世界』" in chat_text, "闲聊必须被转义放行展示为『世界』")
	assert("『交易』" in chat_text, "交易消息必须被放行展示")
	assert("【队伍】" in chat_text, "队伍消息必须被放行展示")
	assert("你现在并没有和别人组成队伍" in chat_text, "系统提示信息必须展示为弱提示")
	print(">>> [验证 3 通过] LPC channeld 文本消息分流与转义上屏正确！")
	
	# 5. 验证打字热键隔离（核心体验修复）
	# 聚焦输入框时，按 B 键绝不弹出背包
	assert(hub.inventory_panel.visible == false, "初始背包必须隐藏")
	hub.chat_input.grab_focus()
	await get_tree().process_frame
	
	var key_b_event = InputEventKey.new()
	key_b_event.pressed = true
	key_b_event.keycode = KEY_B
	hub._unhandled_input(key_b_event)
	await get_tree().process_frame
	assert(hub.inventory_panel.visible == false, "输入框聚焦打字时，按 B 键绝不能触发打开背包！")
	
	# 聚焦输入框时，按 ESC 释放焦点
	var key_esc_event = InputEventKey.new()
	key_esc_event.pressed = true
	key_esc_event.keycode = KEY_ESCAPE
	hub._unhandled_input(key_esc_event)
	await get_tree().process_frame
	assert(hub.get_viewport().gui_get_focus_owner() != hub.chat_input, "在输入框按 ESC 必须释放焦点！")
	
	# 失焦状态下，按 B 键正常呼出背包
	hub._unhandled_input(key_b_event)
	await get_tree().process_frame
	assert(hub.inventory_panel.visible == true, "非打字状态下，按 B 键正常开启背包！")
	print(">>> [验证 4 通过] 聊天打字热键彻底隔离，按 ESC 平滑失焦！")
	
	# 6. 验证 gbag 专属协议与 84 格多页渲染
	var mock_gbag = {
		"current_page": 1,
		"pages": 4,
		"charm_used_slots": 5,
		"charm_max_slots": 40,
		"items": [
			{
				"file_id": "sword_001",
				"name": "格利斯瓦尔德的刃之锋",
				"color": "unique",
				"icon": "res://assets/images/items/sword.png",
				"amount": 1
			},
			{
				"file_id": "armor_002",
				"name": "塔·拉夏的守护",
				"color": "set",
				"icon": "res://assets/images/items/armor.png",
				"amount": 1
			}
		]
	}
	hub._on_json_frame_received("gbag", mock_gbag)
	await get_tree().process_frame
	
	assert(hub.inventory_panel.items_map.size() == 2, "gbag 必须正确解析并渲染 2 件物品到背包格子")
	assert(hub.inventory_panel.inventory_page_count == 4, "gbag 必须正确同步总页数 4 页")
	print(">>> [验证 5 通过] LPC gbag 84 格多页专属背包数据流完美贯通！")
	
	# 7. 验证装备拖入聊天框 (Drag & Drop) 与图文一体留言发送
	var drag_armor = {
		"file_id": "/clone/armor/tal_armor#102",
		"name": "塔·拉夏的守护",
		"d2_quality": "set"
	}
	var drag_payload = {
		"source": "main_bag",
		"slot_idx": 1,
		"item_data": drag_armor
	}
	assert(hub.chat_input._can_drop_data(Vector2.ZERO, drag_payload) == true, "输入框必须允许接收装备拖入")
	hub.chat_input._drop_data(Vector2.ZERO, drag_payload)
	await get_tree().process_frame
	
	assert(hub.chat_input.text == "【塔·拉夏的守护】 ", "拖入装备后输入框必须自动插入带括号的装备名")
	assert(hub.attached_item.get("file_id") == "/clone/armor/tal_armor#102", "必须记录被拖入装备的 file_id")
	
	# 模拟玩家在装备名后打字留言并回车
	sent_commands.clear()
	hub.chat_input.text = "诚心出 【塔·拉夏的守护】 换军帽带价来"
	hub._on_chat_submitted(hub.chat_input.text)
	await get_tree().process_frame
	
	assert(sent_commands.has("gshowitem /clone/armor/tal_armor#102 诚心出 【塔·拉夏的守护】 换军帽带价来"), "附带装备发送时必须触发 gshowitem 携带完整留言")
	assert(hub.attached_item.is_empty(), "发送后 attached_item 必须清空")
	
	# 模拟服务端下发带 png 小图标的展示广播
	var mock_broadcast = "『世界』 亚瑟：诚心出 [url=item:/clone/armor/tal_armor#102][img=18]res://assets/images/coin.png[/img] [color=#00ff00]『塔·拉夏的守护』[/color][/url] 换军帽带价来"
	hub._on_text_received(mock_broadcast)
	await get_tree().process_frame
	
	var final_chat = hub.chat_log.get_parsed_text()
	assert("塔·拉夏的守护" in final_chat, "图文广播必须正确显示在公频")
	print(">>> [验证 6 通过] 装备拖拽入框、图文一体留言与带图标超链接广播完美闭环！")
	
	# 8. 截图保存实机效果
	await get_tree().create_timer(0.2).timeout
	var image = get_viewport().get_texture().get_image()
	var artifact_path = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_town_hub_chat_and_gbag_success.png"
	image.save_png(artifact_path)
	print(">>> 实机效果已保存至产物截图库: ", artifact_path)
	
	print("=== 所有 6 项验证全部通过，系统工作完美！ ===")
	get_tree().quit(0)
