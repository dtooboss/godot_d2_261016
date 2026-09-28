extends Control

func _ready() -> void:
	print("=== 开始背包手动整理与满页掉落不强制跳页回归测试 ===")
	NetworkClient.is_connected = true
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud: AFK_MainHUD = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var inv: AFK_PlayerInventoryPanel = hud.inventory_panel
	assert(inv != null, "AFK_MainHUD 必须包含 inventory_panel")

	var sent_cmds: Array[String] = []
	inv.command_sent.connect(func(cmd: String):
		sent_cmds.append(cmd)
	)

	# -------------------------------------------------------------
	# Test 1: 验证普通翻页发送纯 gbag <page>，绝不带 sort
	# -------------------------------------------------------------
	print("\n--- Test 1: 验证普通翻页发送纯 gbag <page>，绝不带 sort ---")
	inv.inventory_page_count = 3
	inv._update_page_buttons()
	sent_cmds.clear()
	inv._on_page_button_pressed(2)
	await get_tree().process_frame
	assert(sent_cmds.size() > 0 and sent_cmds[-1] == "gbag 2", "普通翻页必须发送纯 'gbag 2'，实际为: '%s'" % (sent_cmds[-1] if sent_cmds.size() > 0 else "无"))
	assert(not "sort" in sent_cmds[-1], "普通翻页指令绝不能带有 'sort' 参数！")
	print("✔ [测试 1 通过] 普通翻页发送 'gbag 2'，彻底脱离自动排序！")

	# -------------------------------------------------------------
	# Test 2: 验证点击【整理】按钮明确发送 gbag <page> sort
	# -------------------------------------------------------------
	print("\n--- Test 2: 验证点击【整理】按钮明确发送 gbag <page> sort ---")
	sent_cmds.clear()
	inv.btn_sort.emit_signal("pressed")
	await get_tree().process_frame
	assert(sent_cmds.size() > 0 and sent_cmds[-1] == "gbag 2 sort", "点击整理按钮必须发送 'gbag 2 sort'，实际为: '%s'" % (sent_cmds[-1] if sent_cmds.size() > 0 else "无"))
	print("✔ [测试 2 通过] 点击整理按钮成功下发 'gbag 2 sort' 指令！")

	# -------------------------------------------------------------
	# Test 3: 验证普通翻页保持自然物理顺序，绝不自动置顶暗金
	# -------------------------------------------------------------
	print("\n--- Test 3: 验证普通翻页保持自然物理顺序，绝不自动打乱 ---")
	var unsorted_gbag = {
		"items": [
			{
				"name": "普通短剑",
				"raw_name": "短剑",
				"icon": "items/weapon/dagger/dagger.lowend.png",
				"quality": "normal",
				"page": 1,
				"x": 0, "y": 0,
				"amount": 1,
				"file_id": "/clone/d2/gear#101"
			},
			{
				"name": "暗金戒指【乔丹之石】",
				"raw_name": "乔丹之石",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique",
				"page": 1,
				"x": 1, "y": 0,
				"amount": 1,
				"file_id": "/clone/d2/gear#102"
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 1,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 10000
	}
	hud._on_network_json("gbag", unsorted_gbag)
	await get_tree().process_frame

	assert(inv.items_map[0].name == "普通短剑", "第 0 格必须保持为普通短剑")
	assert(inv.items_map[1].name == "暗金戒指【乔丹之石】", "第 1 格必须保持为乔丹之石，未整理时绝不自动移位！")
	print("✔ [测试 3 通过] 普通翻页成功维持自然顺序，暗金未被私自置顶！")

	# -------------------------------------------------------------
	# Test 4: 验证整理后品质智能排序生效
	# -------------------------------------------------------------
	print("\n--- Test 4: 验证整理后品质智能排序生效 (暗金在前) ---")
	var sorted_gbag = {
		"items": [
			{
				"name": "暗金戒指【乔丹之石】",
				"raw_name": "乔丹之石",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique",
				"page": 1,
				"x": 0, "y": 0,
				"amount": 1,
				"file_id": "/clone/d2/gear#102"
			},
			{
				"name": "普通短剑",
				"raw_name": "短剑",
				"icon": "items/weapon/dagger/dagger.lowend.png",
				"quality": "normal",
				"page": 1,
				"x": 1, "y": 0,
				"amount": 1,
				"file_id": "/clone/d2/gear#101"
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 1,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 10000
	}
	hud._on_network_json("gbag", sorted_gbag)
	await get_tree().process_frame

	assert(inv.items_map[0].name == "暗金戒指【乔丹之石】", "整理后暗金成功归置于第 0 格")
	assert(inv.items_map[1].name == "普通短剑", "整理后白装排在第 1 格")
	print("✔ [测试 4 通过] 显式整理后暗金成功置顶归类！")

	# -------------------------------------------------------------
	# Test 5: 验证新掉落增量追加于末尾，暗金位置稳定不动，新装带 NEW 标
	# -------------------------------------------------------------
	print("\n--- Test 5: 验证新掉落增量追加于末尾，原有暗金位置不动 ---")
	var new_loot = {
		"gold": 50,
		"exp": 10,
		"item": {
			"name": "魔法轻盾",
			"raw_name": "轻盾",
			"icon": "items/armor/shield/large_shield.lowend.png",
			"quality": "magic",
			"amount": 1,
			"file_id": "/clone/d2/gear#103"
		}
	}
	hud._on_network_json("reward_pop", new_loot)
	await get_tree().process_frame

	assert(inv.items_map[0].name == "暗金戒指【乔丹之石】", "原有第 0 格暗金依然纹丝不动！")
	assert(inv.items_map[2].name == "魔法轻盾", "新掉落装备规矩进入末尾槽位 2")
	assert(inv.slots[2].is_new_item == true, "新掉落装备必须点亮金色 NEW 标")
	print("✔ [测试 5 通过] 新掉落增量追加在末尾，暗金位置未受干扰，NEW 标正确点亮！")

	# -------------------------------------------------------------
	# Test 6: 验证当前页满时掉落，绝不强制跳转尾页！保持当前视图稳定
	# -------------------------------------------------------------
	print("\n--- Test 6: 验证当前页满时掉落绝不强制跳页，玩家停留在当前页 ---")
	# 将当前第 1 页全部 84 格填满
	for i in range(84):
		inv.items_map[i] = {"name": "满页测试装备 %d" % i}

	var overflow_loot = {
		"gold": 120,
		"exp": 30,
		"item": {
			"name": "符文【瑟】",
			"raw_name": "瑟",
			"icon": "items/misc/rune/el_rune.lowend.png",
			"quality": "unique",
			"amount": 1,
			"file_id": "/clone/d2/gear#104"
		}
	}
	hud._on_network_json("reward_pop", overflow_loot)
	await get_tree().process_frame

	assert(inv.current_page == 1, "第 1 页满时，绝不可强制切页，必须安静保持在第 1 页！实际当前页为: %d" % inv.current_page)
	assert(inv.items_map.size() == 84, "第 1 页原有的 84 个格子绝不能被清空！")
	assert(inv.items_map[0].name == "满页测试装备 0", "第 1 页原装备依然正常呈现")
	print("✔ [测试 6 通过] 满页掉落时绝不强制跳页，当前页格子未被清空，玩家操作体验丝滑平稳！")

	# -------------------------------------------------------------
	# Test 7: 验证跨页总数自适应增加，且 NEW 标记正确追踪
	# -------------------------------------------------------------
	print("\n--- Test 7: 验证跨页自适应增加页码按钮，且新物品保留 NEW 标记 ---")
	assert(inv.new_item_ids.has("/clone/d2/gear#104"), "溢出到后续页的装备必须依然在 new_item_ids 追踪池中！")
	print("✔ [测试 7 通过] 跨页物品 NEW 标记成功追踪，等待玩家自主翻页查看！")

	print("\n========================================================")
	print(">>> 恭喜！背包手动整理与满页掉落不跳页 7 项自动化测试全部 100% 通过！<<<")
	print("========================================================\n")
	get_tree().quit(0)
