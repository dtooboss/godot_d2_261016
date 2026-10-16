extends Node2D

func _ready() -> void:
	print("=== 开始交易接收点数 (TRP) 与未鉴定 UI 闭环端到端自动化测试 ===")

	# -------------------------------------------------------------
	# 1. 验证 InvSlotButton 未鉴定角标
	# -------------------------------------------------------------
	var slot_btn = InvSlotButton.new()
	add_child(slot_btn)
	slot_btn.set_slot_unidentified(true)
	assert(slot_btn.unid_badge != null, "InvSlotButton 必须具备 unid_badge 节点")
	assert(slot_btn.unid_badge.visible == true, "未鉴定装备的红问号角标必须可见")
	assert(slot_btn.unid_badge.text == "?", "未鉴定装备角标必须是问号 '?'")
	print(">>> [验证 1 通过] InvSlotButton 未鉴定问号角标创建与显隐正常！")

	slot_btn.set_slot_unidentified(false)
	assert(slot_btn.unid_badge.visible == false, "辨识后未鉴定角标必须自动隐藏")
	print(">>> [验证 2 通过] InvSlotButton 辨识后角标隐藏正常！")

	# -------------------------------------------------------------
	# 2. 验证 TradePanel 交易面板、红问号角标与交易点数核算栏
	# -------------------------------------------------------------
	var trade_panel_script = preload("res://scripts/ui/trade_panel.gd")
	var panel = trade_panel_script.new()
	panel.position = Vector2(80, 50)
	add_child(panel)

	panel.open_trade("test_trader", "刺客·夏娜")

	# Case A: 跨通行证混合交易 (1件未鉴定暗金 + 1件已鉴定亮金 + 1个符文)
	var sync_cross_ok = {
		"partner_id": "test_trader",
		"partner_name": "刺客·夏娜",
		"my_items": [
			{
				"file_id": "/clone/d2/equipment#101",
				"name": "乔丹之石",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique",
				"unidentified": false
			}
		],
		"partner_items": [
			{
				"file_id": "/clone/d2/equipment#201",
				"name": "未辨识的法师铠甲",
				"icon": "items/armor/armor/mage_plate.lowend.png",
				"quality": "unique",
				"unidentified": true
			},
			{
				"file_id": "/clone/d2/equipment#202",
				"name": "幽灵之扣 腰带",
				"icon": "items/armor/belt/sash_l.lowend.png",
				"quality": "rare",
				"unidentified": false
			},
			{
				"file_id": "/clone/d2/rune#203",
				"name": "30号 贝",
				"icon": "items/misc/rune/ber_rune.lowend.png",
				"quality": "normal",
				"unidentified": false
			}
		],
		"my_confirmed": false,
		"partner_confirmed": false,
		"is_cross_passport": true,
		"my_trade_points": 50,
		"partner_trade_points": 100,
		"inbound_summary": {
			"unid_count": 1,
			"id_count": 1,
			"free_count": 1,
			"total_cost": 11,
			"can_afford": true
		},
		"outbound_summary": {
			"unid_count": 0,
			"id_count": 1,
			"free_count": 0,
			"total_cost": 10,
			"partner_can_afford": true
		}
	}
	panel.update_trade_sync(sync_cross_ok)

	# 验证对方第 0 格 (未辨识暗金) 是否有红问号
	var partner_slot0 = panel.partner_slot_buttons[0]
	var unid_lbl0 = partner_slot0.get_node_or_null("UnidLabel") as Label
	assert(unid_lbl0 != null and unid_lbl0.visible == true, "对方未辨识物品槽位右上角必须显示红问号角标！")
	
	# 验证对方第 1 格 (已辨识亮金) 没有红问号
	var partner_slot1 = panel.partner_slot_buttons[1]
	var unid_lbl1 = partner_slot1.get_node_or_null("UnidLabel") as Label
	assert(unid_lbl1 != null and unid_lbl1.visible == false, "已辨识物品槽位右上角不可显示红问号！")

	# 验证账单展示
	assert(panel.lbl_cost_info != null, "lbl_cost_info 账单核算条必须存在")
	print(">>> 账单展示文案:\n", panel.lbl_cost_info.text)
	assert("11 点" in panel.lbl_cost_info.text, "账单必须显示接收消耗 11 点！")
	assert("39 点" in panel.lbl_cost_info.text, "账单必须显示扣减后剩余可用 39 点！")
	assert(panel.btn_confirm.disabled == false, "点数充足时确认按钮不可禁用！")
	print(">>> [验证 3 通过] 跨通行证混合交易点数核算条与红问号标识完美验证！")

	# Case B: 点数不足情况 (现有 5 点，需 11 点)
	var sync_cant_afford = sync_cross_ok.duplicate(true)
	sync_cant_afford["my_trade_points"] = 5
	sync_cant_afford["inbound_summary"]["can_afford"] = false
	panel.update_trade_sync(sync_cant_afford)

	print(">>> 点数不足文案:\n", panel.lbl_cost_info.text)
	assert("点数不足" in panel.lbl_cost_info.text, "账单必须弹出点数不足红字警告！")
	assert(panel.btn_confirm.disabled == true, "点数不足时确认按钮必须被禁用置灰！")
	assert("点数不足" in panel.btn_confirm.text, "确认按钮必须更新为点数不足文案！")
	print(">>> [验证 4 通过] 点数不足防御拦截与确认按钮锁死验证通过！")

	# Case C: 同通行证免点数转移
	var sync_same_passport = sync_cross_ok.duplicate(true)
	sync_same_passport["is_cross_passport"] = false
	panel.update_trade_sync(sync_same_passport)

	print(">>> 同通行证文案:\n", panel.lbl_cost_info.text)
	assert("同通行证安全转移" in panel.lbl_cost_info.text, "同通行证必须展示免费转移！")
	assert(panel.btn_confirm.disabled == false, "同通行证确认按钮恢复可用！")
	print(">>> [验证 5 通过] 同通行证 0 点消耗免扣通道验证通过！")

	# 恢复回充足状态并截图
	panel.update_trade_sync(sync_cross_ok)

	# 等待 2 帧完成渲染刷新并截图存证
	await get_tree().process_frame
	await get_tree().process_frame

	var vp_tex = get_viewport().get_texture()
	if vp_tex:
		var img = vp_tex.get_image()
		if img:
			var screenshot_path = "C:/Users/Administrator/.gemini/antigravity/brain/ec019a2c-0e22-4c1e-a5f7-c8b6eefd70db/trade_points_and_unid_ui_test.png"
			img.save_png(screenshot_path)
			print(">>> [验证 6 通过] 高清 UI 呈现截图已保存至: %s" % screenshot_path)

	print("\n===========================================")
	print("🎉 ALL CHECKS PASSED! 交易接收点数与未辨识 UI 闭环验收 100% 通过！")
	print("===========================================")
	get_tree().quit(0)
