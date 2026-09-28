extends Control

@onready var hud = $AFK_MainHUD
var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("==================================================================")
	print("=== 开始验证：护身符、珠宝及各类背包物品的单选/多选分解全链路 ===")
	print("==================================================================")

	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
		net.raw_sent.connect(func(cmd):
			sent_commands.append(cmd)
			print("[Test] 客户端向服务端发送指令: ", cmd)
		)

	var inv_panel = hud.inventory_panel
	inv_panel.show()
	await get_tree().process_frame

	inv_panel.inventory_page_count = 5
	inv_panel.current_page = 1
	inv_panel._update_page_buttons()
	await get_tree().process_frame

	# -------------------------------------------------------------
	# 准备测试物品：
	# 槽位 0: 稀有珠宝 (Jewel)
	# 槽位 1: 魔法超大护身符 (Grand Charm)
	# 槽位 2: 次级治疗药水 (Potion)
	# 槽位 3: 黄金战剑 (Rare Sword)
	# 槽位 4: 小口袋中的地狱火炬 (Protected Pocket Charm)
	# -------------------------------------------------------------
	var jewel_item = {
		"name": "赤红之真理珠宝",
		"quality": "rare",
		"file_id": "/clone/d2/equipment#jewel101",
		"icon": "items/misc/gem/perfect_diamond2.lowend.png",
		"type": "珠宝",
		"d2_type": "珠宝",
		"in_charm_bag": 0
	}
	var charm_item = {
		"name": "闪电之超大护身符",
		"quality": "magic",
		"file_id": "/clone/d2/equipment#charm102",
		"icon": "items/misc/charm/charm_large.lowend.png",
		"is_charm": 1,
		"type": "护符",
		"d2_type": "护符",
		"in_charm_bag": 0
	}
	var potion_item = {
		"name": "次级治疗药水",
		"quality": "normal",
		"file_id": "/clone/d2/potion/hp2#pot103",
		"icon": "items/potion/hp2.lowend.png",
		"type": "药水",
		"amount": 20,
		"in_charm_bag": 0
	}
	var sword_item = {
		"name": "残酷之水晶剑",
		"quality": "rare",
		"file_id": "/clone/d2/equipment#sword104",
		"icon": "items/weapon/sword/crystal_sword.lowend.png",
		"in_charm_bag": 0
	}
	var pocket_torch = {
		"name": "地狱火炬",
		"quality": "unique",
		"file_id": "/clone/d2/charm_torch#torch999",
		"icon": "items/misc/charm/charm_large.lowend.png",
		"is_charm": 1,
		"in_charm_bag": 1
	}

	inv_panel.items_map[0] = jewel_item
	inv_panel.items_map[1] = charm_item
	inv_panel.items_map[2] = potion_item
	inv_panel.items_map[3] = sword_item
	inv_panel.items_map[4] = pocket_torch

	# -------------------------------------------------------------
	# 测试用例 1: 单选 1 件珠宝分解 (验证无分号指令生成)
	# -------------------------------------------------------------
	print("\n>>> [测试 1] 单选 1 件珠宝分解...")
	inv_panel._on_multi_select_pressed()
	assert(inv_panel.is_multiselect_mode == true, "应进入多选模式")

	inv_panel._toggle_slot_selection(0)
	assert(inv_panel.selected_slots.size() == 1, "应选中 1 个槽位")

	sent_commands.clear()
	inv_panel._execute_batch_salvage()
	assert(sent_commands.size() == 1, "应发送 1 条指令")
	var expected_single_jewel = "gfenjie /clone/d2/equipment#jewel101 1"
	assert(sent_commands[0] == expected_single_jewel, "单选分解指令应匹配无分号格式！实发: " + sent_commands[0])
	print("✔ 测试 1.1: 客户端单选珠宝成功生成无分号指令: ", sent_commands[0])

	# 模拟服务端下发单件珠宝分解回执
	hud._on_network_json("gfenjie", {
		"action": "salvage_result",
		"count": 1,
		"item_name": "赤红之真理珠宝",
		"quality": "rare",
		"rewards": { "gold": 4500, "dust": 2, "essence": 0, "shard": 0, "jinsha": 0 }
	})
	assert(hud._toast_label != null and hud._toast_label.text.contains("赤红之真理珠宝"), "HUD Toast 必须提示珠宝分解成功！当前: " + str(hud._toast_label.text if hud._toast_label else "null"))
	assert(hud._toast_label.text.contains("4500"), "HUD Toast 必须包含金币提示！当前: " + hud._toast_label.text)
	print("✔ 测试 1.2: HUD 接收单件珠宝分解结果并正确弹出 Toast 提示: ", hud._toast_label.text)

	# -------------------------------------------------------------
	# 测试用例 2: 单选 1 件超大护身符分解
	# -------------------------------------------------------------
	print("\n>>> [测试 2] 单选 1 件超大护身符分解...")
	inv_panel._on_multi_select_pressed()
	inv_panel._toggle_slot_selection(1)
	assert(inv_panel.selected_slots.size() == 1, "应选中护身符槽位")

	sent_commands.clear()
	inv_panel._execute_batch_salvage()
	var expected_single_charm = "gfenjie /clone/d2/equipment#charm102 1"
	assert(sent_commands[0] == expected_single_charm, "单选护身符分解指令应匹配无分号格式！实发: " + sent_commands[0])
	print("✔ 测试 2.1: 客户端单选护身符成功生成无分号指令: ", sent_commands[0])

	hud._on_network_json("gfenjie", {
		"action": "salvage_result",
		"count": 1,
		"item_name": "闪电之超大护身符",
		"quality": "magic",
		"rewards": { "gold": 1800, "dust": 1, "essence": 0, "shard": 0, "jinsha": 0 }
	})
	assert(hud._toast_label.text.contains("闪电之超大护身符"), "HUD Toast 必须提示护身符分解成功！")
	print("✔ 测试 2.2: HUD 成功提示护身符分解结果: ", hud._toast_label.text)

	# -------------------------------------------------------------
	# 测试用例 3: 单选 1 组药水/杂物分解 (处理身上多余杂物)
	# -------------------------------------------------------------
	print("\n>>> [测试 3] 单选 1 组药水分解...")
	inv_panel._on_multi_select_pressed()
	inv_panel._toggle_slot_selection(2)

	sent_commands.clear()
	inv_panel._execute_batch_salvage()
	var expected_potion_cmd = "gfenjie /clone/d2/potion/hp2#pot103 1"
	assert(sent_commands[0] == expected_potion_cmd, "单选药水分解指令匹配无分号格式！")
	print("✔ 测试 3.1: 客户端单选药水成功生成指令: ", sent_commands[0])

	hud._on_network_json("gfenjie", {
		"action": "salvage_result",
		"count": 1,
		"item_name": "次级治疗药水",
		"quality": "normal",
		"rewards": { "gold": 500, "dust": 0, "essence": 0, "shard": 0, "jinsha": 0 }
	})
	assert(hud._toast_label.text.contains("次级治疗药水"), "HUD Toast 必须提示药水分解成功！")
	print("✔ 测试 3.2: HUD 成功提示消耗品/药水分解结果: ", hud._toast_label.text)

	# -------------------------------------------------------------
	# 测试用例 4: 多选混合分解 (珠宝 + 护身符 + 武器)
	# -------------------------------------------------------------
	print("\n>>> [测试 4] 多选混合分解 (珠宝 + 护身符 + 武器)...")
	inv_panel._on_multi_select_pressed()
	inv_panel._toggle_slot_selection(0) # 珠宝
	inv_panel._toggle_slot_selection(1) # 护身符
	inv_panel._toggle_slot_selection(3) # 水晶剑
	assert(inv_panel.selected_slots.size() == 3, "应选中 3 个槽位")

	sent_commands.clear()
	inv_panel._execute_batch_salvage()
	var expected_batch = "gfenjie /clone/d2/equipment#jewel101;/clone/d2/equipment#charm102;/clone/d2/equipment#sword104 1"
	assert(sent_commands[0] == expected_batch, "批量分解命令格式正确！实发: " + sent_commands[0])
	print("✔ 测试 4.1: 客户端成功发出分号连接的混合批量分解指令: ", sent_commands[0])

	hud._on_network_json("gfenjie", {
		"action": "salvage_result",
		"count": 3,
		"rewards": { "gold": 12000, "dust": 5, "essence": 0, "shard": 0, "jinsha": 0 }
	})
	assert(hud._toast_label.text.contains("成功分解 3 件物品"), "HUD Toast 必须提示 3 件物品分解成功！当前: " + hud._toast_label.text)
	print("✔ 测试 4.2: HUD 成功提示批量分解结果: ", hud._toast_label.text)

	# -------------------------------------------------------------
	# 测试用例 5: 小口袋中的护身符保护验证
	# -------------------------------------------------------------
	print("\n>>> [测试 5] 小口袋生效护身符保护测试...")
	inv_panel._on_multi_select_pressed()
	inv_panel._toggle_slot_selection(4) # 小口袋中的地狱火炬
	assert(not (4 in inv_panel.selected_slots), "小口袋护身符严禁被勾选！")
	print("✔ 测试 5: 生效小口袋中的护身符受到绝对保护，无法被误选分解！")

	print("\n==================================================================")
	print("=== 所有 5 项测试全部通过！护身符、珠宝及背包杂物分解通道完全打通！===")
	print("==================================================================")
	get_tree().quit(0)
