extends Control

@onready var hud = $AFK_MainHUD

var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证纸娃娃脱装与背包扩展翻页完整链路 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true # 模拟已连接状态
		net.raw_sent.connect(func(cmd):
			sent_commands.append(cmd)
			print("[Test] 捕获发送命令: ", cmd)
		)
	
	var char_panel = hud.char_info_panel
	var inv_panel = hud.inventory_panel
	
	# 打开角色面板与背包面板
	char_panel.open()
	inv_panel.show()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 测试 1: 纸娃娃穿戴数据注入与拖拽数据生成 (Paperdoll Drag Data)
	# -------------------------------------------------------------
	var test_gscore = {
		"level": 30,
		"hp": 500,
		"max_hp": 500,
		"equips": {
			"armor": {
				"name": "督瑞尔的壳",
				"quality": "unique",
				"file_id": "/d/d2/obj/armor#8888",
				"icon": "items/armor/armor/ancient_armor.lowend.png"
			},
			"main_hand": {
				"name": "水晶剑",
				"quality": "rare",
				"file_id": "/d/d2/obj/sword#9999",
				"icon": "items/weapon/sword/short_sword.lowend.png"
			}
		}
	}
	char_panel.render_gscore_data(test_gscore)
	await get_tree().process_frame
	
	var slot_armor = char_panel.slot_armor
	assert(slot_armor != null, "衣服槽位必须存在")
	assert(slot_armor.current_item_data.get("file_id") == "/d/d2/obj/armor#8888", "衣服槽位数据绑定必须正确")
	
	var drag_data = slot_armor._get_drag_data(Vector2.ZERO)
	assert(drag_data != null, "衣服槽位拖拽数据不能为 null")
	assert(drag_data.get("source") == "paperdoll", "拖拽来源必须为 paperdoll")
	assert(drag_data.get("slot_key") == "armor", "槽位 key 必须为 armor")
	assert(drag_data.get("item_data", {}).get("file_id") == "/d/d2/obj/armor#8888", "item_data 中的 file_id 必须匹配")
	print(">>> 验证 1 通过：纸娃娃槽位成功生成 drag_data (source: paperdoll)")
	
	# -------------------------------------------------------------
	# 测试 2: 背包面板接受纸娃娃拖拽卸装 (Drop on Bag to Unequip)
	# -------------------------------------------------------------
	sent_commands.clear()
	var can_drop_slot = inv_panel.can_slot_drop_data("main_bag", 0, drag_data)
	assert(can_drop_slot == true, "背包格子必须允许接收来自 paperdoll 的拖拽数据！")
	
	var can_drop_panel = inv_panel._can_drop_data(Vector2.ZERO, drag_data)
	assert(can_drop_panel == true, "背包面板空白区必须允许接收来自 paperdoll 的拖拽数据！")
	
	# 模拟在背包第 0 格松手
	inv_panel.on_slot_drop_data("main_bag", 0, drag_data)
	assert(sent_commands.has("remove /d/d2/obj/armor#8888"), "在背包松手后必须向服务端发送 remove /d/d2/obj/armor#8888")
	print(">>> 验证 2 通过：拖拽到背包成功触发 remove <file_id> 卸装！")
	
	# -------------------------------------------------------------
	# 测试 3: 纸娃娃右键直接脱装 (Right Click Slot to Unequip)
	# -------------------------------------------------------------
	sent_commands.clear()
	var right_click = InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	slot_armor.gui_input.emit(right_click)
	assert(sent_commands.has("remove /d/d2/obj/armor#8888"), "右键衣服槽位必须发送 remove /d/d2/obj/armor#8888")
	print(">>> 验证 3 通过：右键纸娃娃槽位成功触发 remove <file_id> 卸装！")
	
	# -------------------------------------------------------------
	# 测试 4: 购买扩充背包第二页 (Buy / Extend Bag Page)
	# -------------------------------------------------------------
	sent_commands.clear()
	inv_panel._on_confirm_extend(50000, 2)
	assert(sent_commands.has("gbag extend"), "确认扩充背包必须发送 gbag extend 指令")
	print(">>> 验证 4 通过：扩充背包确认已发送 gbag extend！")
	
	# -------------------------------------------------------------
	# 测试 5: 服务端响应空第二页 (LPC gbag Frame with Empty Page 2)
	# -------------------------------------------------------------
	# 模拟服务端下发扩充成功后的第 2 页空背包数据
	var gbag_p2 = {
		"page": 2,
		"pages": 2,
		"current_page": 2,
		"items": []
	}
	hud._on_network_json("gbag", gbag_p2)
	await get_tree().process_frame
	
	assert(inv_panel.inventory_page_count == 2, "背包总页数必须更新为 2")
	assert(inv_panel.current_page == 2, "背包当前选中页必须切换为 2")
	
	# 检查页码按钮容器中的子节点（按钮 1, 按钮 2, '+' 按钮）
	var page_btns = inv_panel.inv_button_container.get_children()
	assert(page_btns.size() == 3, "应当有按钮 1、按钮 2 与 '+' 按钮")
	assert(page_btns[0].text == "1", "第一个按钮文字为 1")
	assert(page_btns[1].text == "2", "第二个按钮文字为 2")
	assert(page_btns[2].text == "+", "第三个按钮文字为 +")
	print(">>> 验证 5 通过：空第 2 页成功展示，页码 2 正常高亮可用！")
	
	# -------------------------------------------------------------
	# 测试 6: 点击页码 1 翻回第 1 页
	# -------------------------------------------------------------
	sent_commands.clear()
	inv_panel._on_page_button_pressed(1)
	assert(sent_commands.has("gbag 1"), "点击页码 1 必须发送 gbag 1")
	
	# 模拟服务端返回第 1 页的物品（包含脱下的衣服）
	var gbag_p1 = {
		"page": 1,
		"pages": 2,
		"current_page": 1,
		"items": [
			{
				"name": "督瑞尔的壳",
				"quality": "unique",
				"file_id": "/d/d2/obj/armor#8888",
				"icon": "items/armor/armor/ancient_armor.lowend.png",
				"amount": 1,
				"is_charm": 0,
				"in_charm_bag": 0
			}
		]
	}
	hud._on_network_json("gbag", gbag_p1)
	await get_tree().process_frame
	assert(inv_panel.current_page == 1, "当前页必须更新为 1")
	assert(inv_panel.slots[0].icon != null, "第 1 页第 0 格必须显示物品图标")
	print(">>> 验证 6 通过：翻页切回第 1 页成功渲染！")
	
	# 截图保存走查结果
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_paperdoll_unequip_and_bag_extend.png")
	print("[Test] 走查截图已保存至 res://test_paperdoll_unequip_and_bag_extend.png")
	
	print("=== 全部 6 项核心验证 100% 通过！ ===")
	get_tree().quit(0)
