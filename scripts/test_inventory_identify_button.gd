extends Node2D

func _ready() -> void:
	print("=== 开始背包【一键鉴定】按钮与未鉴定物品实机展示验证 ===")

	var inv_scene = preload("res://scenes/afk/components/player_inventory_panel.tscn")
	var inv_panel = inv_scene.instantiate()
	inv_panel.position = Vector2(80, 40)
	add_child(inv_panel)

	# 1. 验证【一键鉴定】按钮是否存在
	var btn_id = inv_panel.btn_identify_all
	assert(btn_id != null, "【一键鉴定】按钮必须存在于背包面板中！")
	print(">>> [验证 1 通过] 背包面板成功装载【一键鉴定】(BtnIdentifyAll) 实体按钮！")

	# 2. 模拟背包数据：传入未辨识暗金装备与未辨识稀有护身符
	var test_items = [
		{
			"file_id": "/clone/d2/equipment#901",
			"name": "未辨识的 地狱熔炉铁鎚",
			"icon": "items/weapon/mace/war_hammer.lowend.png",
			"quality": "unique",
			"unidentified": 1,
			"item_info": {
				"name": "未辨识的 地狱熔炉铁鎚",
				"desc": "【未辨识的物品】\n品阶：unique\n底材：铁鎚\n（未辨识前无法装备，右键或使用辨识卷轴进行辨识）"
			}
		},
		{
			"file_id": "/clone/d2/equipment#902",
			"name": "未辨识的 小型护身符",
			"icon": "items/misc/charm/charm_small.lowend.png",
			"quality": "rare",
			"unidentified": 1,
			"item_info": {
				"name": "未辨识的 小型护身符",
				"desc": "【未辨识的物品】\n品阶：rare\n底材：小型护身符"
			}
		},
		{
			"file_id": "/clone/d2/rune#903",
			"name": "30号 贝",
			"icon": "items/misc/rune/ber_rune.lowend.png",
			"quality": "normal",
			"unidentified": 0
		}
	]

	inv_panel.render_lpc_items(test_items, 0, 40, 1, 1, { "gold": 58888 })

	# 3. 验证未鉴定装备红问号角标
	var slot0 = inv_panel.slots[0]
	assert(slot0.unid_badge != null and slot0.unid_badge.visible == true, "第 0 格未辨识暗金装备必须带有红色问号角标！")
	
	var slot1 = inv_panel.slots[1]
	assert(slot1.unid_badge != null and slot1.unid_badge.visible == true, "第 1 格未辨识稀有护身符必须带有红色问号角标！")

	var slot2 = inv_panel.slots[2]
	assert(slot2.unid_badge != null and slot2.unid_badge.visible == false, "第 2 格普通物品不可有问号角标！")
	print(">>> [验证 2 通过] 格子未辨识红色问号角标显隐完全正确！")

	# 4. 验证一键鉴定按钮动态高亮
	assert(btn_id.text == "一键鉴定!", "有未辨识物品时按钮文案必须为 '一键鉴定!'")
	print(">>> [验证 3 通过] 一键鉴定按钮文案与高亮状态联动成功！当前按钮文案: %s" % btn_id.text)

	# 5. 验证点击事件发送指令
	var captured = [""]
	inv_panel.command_sent.connect(func(cmd: String):
		captured[0] = cmd
	)
	btn_id.pressed.emit()
	assert(captured[0] == "gidentify all", "点击一键鉴定按钮必须发送 'gidentify all' 指令！实际: %s" % captured[0])
	print(">>> [验证 4 通过] 点击一键鉴定按钮成功发送 'gidentify all'！")

	# 等待 2 帧完成渲染并截图存证
	await get_tree().process_frame
	await get_tree().process_frame

	var vp_tex = get_viewport().get_texture()
	if vp_tex:
		var img = vp_tex.get_image()
		if img:
			var screenshot_path = "C:/Users/Administrator/.gemini/antigravity/brain/ec019a2c-0e22-4c1e-a5f7-c8b6eefd70db/inventory_identify_button_test.png"
			img.save_png(screenshot_path)
			print(">>> [验证 5 通过] 高清实机渲染截图已保存至: %s" % screenshot_path)

	print("\n===========================================")
	print("🎉 ALL CHECKS PASSED! 背包一键鉴定按钮与红问号角标 100% 验收通过！")
	print("===========================================")
	get_tree().quit(0)
