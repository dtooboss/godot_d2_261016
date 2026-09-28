extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== START TEST_BAG_EXTENSION_SERVER_DRIVEN ===")
	
	var inv = hud.inventory_panel
	assert(inv != null, "InventoryPanel not found")
	
	# Step 1: 模拟从服务器接收到第一页的 gbag 数据帧
	var mock_gbag_p1 = {
		"items": [],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 1,
		"page": 1,
		"unlocked_pages": 1,
		"max_pages": 4,
		"extend_cost": 50000,
		"gold": 120000
	}
	hud._on_network_json("gbag", mock_gbag_p1)
	await get_tree().process_frame
	
	print("[Check 1] Page count: %d (expected: 1)" % inv.inventory_page_count)
	print("[Check 1] Current page: %d (expected: 1)" % inv.current_page)
	print("[Check 1] Player gold: %d (expected: 120000)" % inv.current_player_gold)
	print("[Check 1] Extend cost: %d (expected: 50000)" % inv.extend_cost)
	assert(inv.inventory_page_count == 1, "Page count should be 1")
	assert(inv.current_player_gold == 120000, "Gold should be 120000")
	assert(inv.extend_cost == 50000, "Cost should be 50000")
	
	# Step 2: 弹出扩充弹窗，检查定价与状态
	inv._on_add_page_pressed()
	await get_tree().process_frame
	var add_panel = inv.add_inv_panel
	assert(add_panel.visible, "Add panel should be visible")
	print("[Check 2] AddPanel need_gold: %d (expected: 50000)" % add_panel.need_gold)
	print("[Check 2] AddPanel confirm_button disabled: %s (expected: false)" % str(add_panel.confirm_button.disabled))
	assert(add_panel.need_gold == 50000, "Need gold should be 50000")
	assert(not add_panel.confirm_button.disabled, "Confirm button should be enabled")
	
	# 截图1: 第1页扩容弹窗（需5万金币）
	await get_tree().create_timer(0.25).timeout
	var tex1 = get_viewport().get_texture()
	if tex1:
		var img1 = tex1.get_image()
		if img1:
			var shot1 = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_bag_extend_p1_to_p2.png"
			img1.save_png(shot1)
			print("Saved shot 1 to " + shot1)
	
	# Step 3: 点击确认扩充，验证前端不扣本地金币、不提前加页，纯向后端发命令
	add_panel.confirm_button.emit_signal("pressed")
	await get_tree().process_frame
	print("[Check 3] AddPanel hidden: %s" % str(not add_panel.visible))
	print("[Check 3] Page count remains before server reply: %d (expected: 1)" % inv.inventory_page_count)
	print("[Check 3] Gold remains before server reply: %d (expected: 120000)" % inv.current_player_gold)
	assert(inv.inventory_page_count == 1, "Frontend must NOT increase pages before server confirmation")
	assert(inv.current_player_gold == 120000, "Frontend must NOT deduct gold locally")
	
	# Step 4: 服务端处理完毕，下发扩充到第2页的 gbag 数据帧
	var mock_gbag_p2 = {
		"items": [],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 2,
		"page": 2,
		"unlocked_pages": 2,
		"max_pages": 4,
		"extend_cost": 100000,
		"gold": 70000
	}
	hud._on_network_json("gbag", mock_gbag_p2)
	await get_tree().process_frame
	print("[Check 4] Page count after server reply: %d (expected: 2)" % inv.inventory_page_count)
	print("[Check 4] Current page: %d (expected: 2)" % inv.current_page)
	print("[Check 4] Player gold after server reply: %d (expected: 70000)" % inv.current_player_gold)
	print("[Check 4] Next extend cost: %d (expected: 100000)" % inv.extend_cost)
	assert(inv.inventory_page_count == 2, "Page count should be 2")
	assert(inv.current_page == 2, "Current page should be 2")
	assert(inv.current_player_gold == 70000, "Gold should be updated to 70000")
	assert(inv.extend_cost == 100000, "Next cost should be 100000")
	
	# Step 5: 再次打开扩容弹窗，此时玩家有 70000，但需要 100000，金币不足应禁用确认按钮
	inv._on_add_page_pressed()
	await get_tree().process_frame
	print("[Check 5] AddPanel need_gold for p3: %d (expected: 100000)" % add_panel.need_gold)
	print("[Check 5] AddPanel confirm_button disabled (gold lack): %s (expected: true)" % str(add_panel.confirm_button.disabled))
	assert(add_panel.need_gold == 100000, "Need gold should be 100000")
	assert(add_panel.confirm_button.disabled, "Confirm button should be disabled due to lack of gold")
	
	# 截图2: 第2页扩容弹窗（需10万金币，仅7万，按钮置灰且文字变红）
	await get_tree().create_timer(0.25).timeout
	var tex2 = get_viewport().get_texture()
	if tex2:
		var img2 = tex2.get_image()
		if img2:
			var shot2 = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_bag_extend_gold_lack.png"
			img2.save_png(shot2)
			print("Saved shot 2 to " + shot2)
	add_panel.hide_panel()
	await get_tree().process_frame
	
	# Step 6: 模拟满级 4 页已解锁
	var mock_gbag_p4 = {
		"items": [],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 4,
		"page": 4,
		"unlocked_pages": 4,
		"max_pages": 4,
		"extend_cost": 0,
		"gold": 500000
	}
	hud._on_network_json("gbag", mock_gbag_p4)
	await get_tree().process_frame
	inv._on_add_page_pressed()
	await get_tree().create_timer(0.25).timeout
	print("[Check 6] AddPanel for full pages (4): confirm_button disabled: %s (expected: true)" % str(add_panel.confirm_button.disabled))
	assert(add_panel.confirm_button.disabled, "Confirm button should be disabled when max pages reached")
	
	# 截图3: 满级 4 页提示
	var tex3 = get_viewport().get_texture()
	if tex3:
		var img3 = tex3.get_image()
		if img3:
			var shot3 = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_bag_extend_max_reached.png"
			img3.save_png(shot3)
			print("Saved shot 3 to " + shot3)
	
	print("=== ALL TESTS PASSED! ===")
	get_tree().quit(0)
