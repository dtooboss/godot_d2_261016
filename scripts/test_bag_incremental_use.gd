extends Node

func _ready() -> void:
	print("==================================================")
	print("  开始测试 背包药水/消耗品增量 -1 (Delta Update) 协议  ")
	print("==================================================")

	# ----------------------------------------------------
	# 测试 1: PlayerInventoryPanel 单元逻辑与增量更新
	# ----------------------------------------------------
	print("\n[测试 1] PlayerInventoryPanel 增量更新 (update_item_amount) 验证...")
	var inv_scene = load("res://scenes/afk/components/player_inventory_panel.tscn")
	var inv_panel = inv_scene.instantiate()
	add_child(inv_panel)
	await get_tree().process_frame
	await get_tree().process_frame

	var mock_items = [
		{
			"file_id": "/clone/d2/potion/hp1#1001",
			"name": "轻微治疗药水",
			"amount": 50,
			"quality": "normal",
			"type": "药水",
			"icon": "items/misc/potion/lesser_healing_potion.lowend.png",
			"is_potion": true
		},
		{
			"file_id": "/clone/d2/potion/mp1#1002",
			"name": "轻微法力药水",
			"amount": 20,
			"quality": "normal",
			"type": "药水",
			"icon": "items/misc/potion/lesser_mana_potion.lowend.png",
			"is_potion": true
		},
		{
			"file_id": "/clone/d2/weapon/sword#2001",
			"name": "短剑",
			"amount": 1,
			"quality": "magic",
			"type": "单手剑",
			"icon": "items/weapon/sword/short_sword.lowend.png"
		}
	]

	inv_panel.render_lpc_items(mock_items, 0, 40, 1, 1)
	assert(inv_panel.items_map.size() == 3, "初始应成功渲染 3 个格子")
	assert(inv_panel.items_map[0]["amount"] == 50, "格子 0 应为 50 瓶治疗药水")
	assert(inv_panel.items_map[1]["amount"] == 20, "格子 1 应为 20 瓶法力药水")
	assert(inv_panel.items_map[2]["amount"] == 1, "格子 2 应为 1 把短剑")
	print("  ✅ 1.1 初始背包渲染成功: 治疗药水 x50, 法力药水 x20, 短剑 x1")

	# 1.2 消耗品判定函数验证
	assert(inv_panel._is_item_consumable(mock_items[0]) == true, "治疗药水必须被判定为消耗品")
	assert(inv_panel._is_item_consumable(mock_items[1]) == true, "法力药水必须被判定为消耗品")
	assert(inv_panel._is_item_consumable(mock_items[2]) == false, "短剑不能被判定为消耗品")
	print("  ✅ 1.2 消耗品判定规则 (_is_item_consumable) 100% 正确")

	# 1.3 模拟增量 -1：喝下 1 瓶治疗药水 -> 50 变为 49
	var ret = inv_panel.update_item_amount("/clone/d2/potion/hp1#1001", 49)
	assert(ret == true, "增量更新应当成功匹配")
	assert(inv_panel.items_map.size() == 3, "增量更新格子总数不变（零重绘）")
	assert(inv_panel.items_map[0]["amount"] == 49, "格子 0 数量应增量降为 49")
	var btn0 = inv_panel.slots[0]
	assert(btn0.amount_label.text == "49", "格子按钮显示的角标数量应为 49")
	print("  ✅ 1.3 增量 -1: 治疗药水 50 -> 49, 按钮角标即时反映 49")

	# 1.4 再喝下 1 瓶 -> 49 变为 48
	inv_panel.update_item_amount("/clone/d2/potion/hp1#1001", 48)
	assert(inv_panel.items_map[0]["amount"] == 48, "格子 0 数量应降为 48")
	assert(btn0.amount_label.text == "48", "按钮角标应为 48")
	print("  ✅ 1.4 持续增量更新: 治疗药水 49 -> 48")

	# 1.5 最后一瓶喝光：amount 变为 0 -> 精准清空格子，杜绝残影
	inv_panel.update_item_amount("/clone/d2/potion/hp1#1001", 0)
	assert(not inv_panel.items_map.has(0), "数量为 0 时 items_map 必须精准清除该格子")
	assert(btn0.icon == null, "清空后按钮图标必须置为 null")
	assert(btn0.amount_label.visible == false, "清空后按钮角标必须隐藏")
	# 同时验证其他格子未受丝毫扰动
	assert(inv_panel.items_map.has(1) and inv_panel.items_map[1]["amount"] == 20, "法力药水未受影响")
	assert(inv_panel.items_map.has(2) and inv_panel.items_map[2]["name"] == "短剑", "短剑未受影响")
	print("  ✅ 1.5 物品耗尽归零 (amount=0): 目标格子精准清空，其余格子完好无损")

	inv_panel.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# 测试 2: AFK_MainHUD 挂接 gbag_item_update 增量网络帧
	# ----------------------------------------------------
	print("\n[测试 2] AFK_MainHUD 挂接 gbag_item_update 网络帧测试...")
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud_inv = hud.inventory_panel
	assert(hud_inv != null, "AFK_MainHUD 必须挂载 inventory_panel")

	# 填充初始测试数据
	hud_inv.render_lpc_items([
		{
			"file_id": "/clone/d2/potion/rvs#3001",
			"name": "全面恢复活力药剂",
			"amount": 10,
			"quality": "normal",
			"type": "药水",
			"icon": "items/misc/potion/full_rejuv_potion.lowend.png",
			"is_potion": true
		}
	], 0, 40, 1, 1)
	assert(hud_inv.items_map[0]["amount"] == 10, "初始活力药剂 x10")

	# 模拟从服务端收到 gbag_item_update (10 -> 9)
	hud._on_network_json("gbag_item_update", {
		"file_id": "/clone/d2/potion/rvs#3001",
		"amount": 9
	})
	assert(hud_inv.items_map[0]["amount"] == 9, "HUD 收到 gbag_item_update 后成功将活力药剂更新为 9")
	print("  ✅ 2.1 AFK_MainHUD 收到 gbag_item_update: 药剂 10 -> 9")

	# 模拟药水用光 (9 -> 0)
	hud._on_network_json("gbag_item_update", {
		"file_id": "/clone/d2/potion/rvs#3001",
		"amount": 0
	})
	assert(not hud_inv.items_map.has(0), "HUD 收到 amount=0 后成功清合格子")
	print("  ✅ 2.2 AFK_MainHUD 收到 amount=0: 格子清空成功")

	hud.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# 测试 3: TownHubController 挂接 gbag_item_update 网络帧
	# ----------------------------------------------------
	print("\n[测试 3] TownHubController 挂接 gbag_item_update 网络帧测试...")
	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var town_inv = town.inventory_panel
	assert(town_inv != null, "TownHubController 必须挂载 inventory_panel")

	town_inv.render_lpc_items([
		{
			"file_id": "/clone/d2/scroll/tsc#4001",
			"name": "城镇传送卷轴",
			"amount": 15,
			"quality": "normal",
			"type": "卷轴",
			"icon": "items/misc/herb/herb.lowend.png"
		}
	], 0, 40, 1, 1)
	assert(town_inv.items_map[0]["amount"] == 15, "初始回城卷轴 x15")

	# 模拟使用 1 张卷轴 (15 -> 14)
	town._on_json_frame_received("gbag_item_update", {
		"file_id": "/clone/d2/scroll/tsc#4001",
		"amount": 14
	})
	assert(town_inv.items_map[0]["amount"] == 14, "TownHub 收到增量帧后成功将卷轴更新为 14")
	print("  ✅ 3.1 TownHub 收到 gbag_item_update: 回城卷轴 15 -> 14")

	town.queue_free()
	await get_tree().process_frame

	print("\n==================================================")
	print("  🎉 增量 -1 (Delta Update) 协议全链路测试全部通过！ ")
	print("==================================================")
	get_tree().quit()
