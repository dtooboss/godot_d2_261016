extends Control

@onready var hud = $AFK_MainHUD

var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证 G 端专属指令 gwear/gremove 与第 6 页穿戴页码保持机制 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
		net.raw_sent.connect(func(cmd):
			sent_commands.append(cmd)
			print("[Test] 捕获客户端发送命令: ", cmd)
		)
	
	var inv_panel = hud.inventory_panel
	var char_panel = hud.char_info_panel
	inv_panel.show()
	char_panel.open()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 1. 模拟切到第 6 页，并在第 6 页有一件【风之力】
	# -------------------------------------------------------------
	inv_panel.inventory_page_count = 10
	inv_panel.current_page = 6
	inv_panel._update_page_buttons()
	await get_tree().process_frame
	
	var test_windforce = {
		"name": "风之力",
		"quality": "unique",
		"file_id": "/d/d2/obj/windforce#999",
		"icon": "items/weapon/bow/composite_bow.lowend.png",
		"is_charm": 0,
		"in_charm_bag": 0
	}
	inv_panel.items_map[0] = test_windforce
	inv_panel.slots[0].icon = load("res://assets/items/weapon/bow/composite_bow.lowend.png")
	inv_panel.slots[0].set_slot_quality("unique")
	await get_tree().process_frame
	
	assert(inv_panel.current_page == 6, "初始当前页必须在第 6 页！")
	
	# -------------------------------------------------------------
	# 2. 模拟在第 6 页右键穿戴装备
	# -------------------------------------------------------------
	sent_commands.clear()
	var right_click = InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	inv_panel._on_slot_gui_input(right_click, 0, inv_panel.slots[0])
	
	# 断言：发出的必须是 G 端专属指令 gwear，且必须携带当前页码 6！绝不是通用的 wear
	assert(sent_commands.has("gwear /d/d2/obj/windforce#999 6"), "必须发送 G 端专属指令 gwear 并携带当前页码 6！")
	assert(!sent_commands.has("wear /d/d2/obj/windforce#999"), "绝不能发送会影响文字端的通用 wear 指令！")
	print(">>> 验证 1 通过：右键穿戴发送了专属指令 gwear 并精准绑定第 6 页！")
	
	# -------------------------------------------------------------
	# 3. 模拟服务端 gwear 结算后返回第 6 页的 gbag 协议包
	# -------------------------------------------------------------
	var gbag_resp_p6 = {
		"page": 6,
		"pages": 10,
		"items": [] # 穿戴后此格为空
	}
	hud._on_network_json("gbag", gbag_resp_p6)
	await get_tree().process_frame
	
	# 断言：背包必须保持在第 6 页，绝不能滚回第 1 页！
	assert(inv_panel.current_page == 6, "收到 gbag 响应后，背包必须依然保持在第 6 页，绝不回退至第 1 页！")
	print(">>> 验证 2 通过：穿戴后背包精准保留在第 6 页，彻底解决跳回第 1 页的严重问题！")
	
	# -------------------------------------------------------------
	# 4. 验证纸娃娃卸装发送专属 gremove
	# -------------------------------------------------------------
	sent_commands.clear()
	var slot_armor = char_panel.slot_armor
	slot_armor.current_item_data = {"file_id": "/d/d2/obj/armor#888"}
	char_panel.equips_map["armor"] = {"file_id": "/d/d2/obj/armor#888"}
	
	var right_click_unequip = InputEventMouseButton.new()
	right_click_unequip.button_index = MOUSE_BUTTON_RIGHT
	right_click_unequip.pressed = true
	slot_armor.gui_input.emit(right_click_unequip)
	
	assert(sent_commands.has("gremove /d/d2/obj/armor#888"), "纸娃娃右键卸装必须发送专属 gremove 指令！")
	assert(!sent_commands.has("remove /d/d2/obj/armor#888"), "绝不能发送通用文字端 remove 指令！")
	print(">>> 验证 3 通过：纸娃娃卸装发送专属指令 gremove，多端彻底隔离！")
	
	# -------------------------------------------------------------
	# 5. 走查截图并退出
	# -------------------------------------------------------------
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_gwear_keep_page_6.png")
	print("[Test] 走查截图已保存至 res://test_gwear_keep_page_6.png")
	
	print("=== 全部验证 100% 通过！ ===")
	get_tree().quit(0)
