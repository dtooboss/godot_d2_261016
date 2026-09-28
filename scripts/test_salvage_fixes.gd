extends Control

@onready var hud = $AFK_MainHUD
var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始验证：1. 多选分解保持当前页(如第6页) 2. 主背包护身符可多选分解 3. 小口袋护符受保护 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
		net.raw_sent.connect(func(cmd):
			sent_commands.append(cmd)
			print("[Test] 捕获客户端发送命令: ", cmd)
		)
	
	var inv_panel = hud.inventory_panel
	inv_panel.show()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 1. 模拟设置在第 6 页
	# -------------------------------------------------------------
	inv_panel.inventory_page_count = 10
	inv_panel.current_page = 6
	inv_panel._update_page_buttons()
	await get_tree().process_frame
	assert(inv_panel.current_page == 6, "初始当前页必须在第 6 页！")
	
	# -------------------------------------------------------------
	# 2. 模拟配置物品槽位：
	#    - 槽位 0: 主背包护身符 (is_charm=1, in_charm_bag=0)
	#    - 槽位 1: 小口袋护身符 (is_charm=1, in_charm_bag=1)
	#    - 槽位 2: 普通亮金装备 (is_charm=0, in_charm_bag=0)
	# -------------------------------------------------------------
	var charm_item = {
		"name": "巨龙之大型护身符",
		"quality": "magic",
		"file_id": "/d/d2/obj/charm#gc101",
		"icon": "items/misc/charm/charm_large.lowend.png",
		"is_charm": 1,
		"in_charm_bag": 0
	}
	var pocket_charm_item = {
		"name": "地狱火炬",
		"quality": "unique",
		"file_id": "/d/d2/obj/charm#torch999",
		"icon": "items/misc/charm/charm_large.lowend.png",
		"is_charm": 1,
		"in_charm_bag": 1
	}
	var regular_item = {
		"name": "阴影之重靴",
		"quality": "rare",
		"file_id": "/d/d2/obj/boots#rare202",
		"icon": "items/armor/boots/boots.lowend.png",
		"is_charm": 0,
		"in_charm_bag": 0
	}
	
	inv_panel.items_map[0] = charm_item
	inv_panel.items_map[1] = pocket_charm_item
	inv_panel.items_map[2] = regular_item
	
	inv_panel.slots[0].set_slot_quality("magic")
	inv_panel.slots[1].set_slot_quality("unique")
	inv_panel.slots[2].set_slot_quality("rare")
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 3. 开启多选模式并测试勾选
	# -------------------------------------------------------------
	inv_panel._on_multi_select_pressed()
	assert(inv_panel.is_multiselect_mode == true, "必须进入多选模式")
	
	# 勾选槽位 0 (主背包护身符) -> 期望：成功选中！
	inv_panel._toggle_slot_selection(0)
	assert(0 in inv_panel.selected_slots, "主背包护身符必须能够被成功选入多选列表！")
	assert(inv_panel.selected_slots.size() == 1, "选中计数应为 1")
	print(">>> [测试通过] 主背包护身符成功勾选！")
	
	# 勾选槽位 1 (小口袋护身符) -> 期望：受保护，无法选中！
	inv_panel._toggle_slot_selection(1)
	assert(not (1 in inv_panel.selected_slots), "小口袋护身符受系统保护，严禁被选入多选！")
	assert(inv_panel.selected_slots.size() == 1, "选中计数仍应为 1")
	print(">>> [测试通过] 小口袋护身符成功受到安全保护，禁止勾选！")
	
	# 勾选槽位 2 (普通装备) -> 期望：成功选中！
	inv_panel._toggle_slot_selection(2)
	assert(2 in inv_panel.selected_slots, "普通装备必须能够被成功选入多选列表！")
	assert(inv_panel.selected_slots.size() == 2, "选中计数应为 2")
	print(">>> [测试通过] 普通装备成功勾选！")
	
	# -------------------------------------------------------------
	# 4. 执行多选分解发送命令
	# -------------------------------------------------------------
	sent_commands.clear()
	inv_panel._execute_batch_salvage()
	assert(sent_commands.size() == 1, "应发送 1 条批量分解命令")
	var expected_cmd = "gfenjie /d/d2/obj/charm#gc101;/d/d2/obj/boots#rare202 6"
	assert(sent_commands[0] == expected_cmd, "分解命令中必须包含护身符与装备的 file_id 及页码！实发: " + sent_commands[0])
	print(">>> [测试通过] 发送的批量分解命令正确包含护符与当前页码: ", sent_commands[0])
	
	# -------------------------------------------------------------
	# 5. 模拟服务端分解完毕后下发当前页背包帧 (page=6, pages=10)
	# -------------------------------------------------------------
	inv_panel.render_lpc_items([], -1, 40, 10, 6)
	await get_tree().process_frame
	
	assert(inv_panel.current_page == 6, "分解后背包必须保持在当前第 6 页！当前实际为: " + str(inv_panel.current_page))
	print(">>> [测试通过] 刷新后当前页成功保持在第 6 页！")
	
	get_tree().quit(0)
