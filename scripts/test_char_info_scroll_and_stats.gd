extends Control

func _ready() -> void:
	await get_tree().process_frame
	
	print("==================================================")
	print("--- 测试 1: 实例化 character_info_panel 并注入 LPC 真实全量 gscore ---")
	print("==================================================")
	
	var panel_scene = load("res://scenes/afk/components/character_info_panel.tscn")
	var panel = panel_scene.instantiate()
	add_child(panel)
	panel.show()
	panel.position = Vector2(100, 100)
	
	await get_tree().process_frame
	
	# 从本地 MUD 真实下发的全量 gscore 数据帧
	var real_mud_gscore = {
		"name": "赵狂狂",
		"level": 90,
		"class": "sor",
		"str": 11,
		"base_str": 10,
		"bonus_str": 1,
		"dex": 31,
		"base_dex": 25,
		"bonus_dex": 6,
		"vit": 10,
		"base_vit": 10,
		"bonus_vit": 0,
		"int": 35,
		"base_int": 35,
		"bonus_int": 0,
		"hp": 162,
		"max_hp": 162,
		"mp": 247,
		"max_mp": 34,
		"exp": 10359,
		"next_exp": 1296000,
		"stat_points": 0,
		"zone": "普通百姓营地",
		"combat": {
			"phy_dmg_min": 30,
			"phy_dmg_max": 40,
			"mag_dmg_min": 7845,
			"mag_dmg_max": 9268,
			"mag_dps": 2852.17,
			"main_skill_name": "火球术",
			"main_skill_code": "fire_ball",
			"dmg_enhance": 0,
			"ar": 228,
			"hit_rate": 83,
			"defense": 285,
			"block_rate": 4,
			"attack_speed": 0,
			"attack_rate": 0.88,
			"res_fire": 11,
			"max_res_fire": 75,
			"res_cold": 18,
			"max_res_cold": 75,
			"res_lightning": 11,
			"max_res_lightning": 75,
			"res_poison": 61,
			"max_res_poison": 75,
			"all_res": 11,
			"dr": 0,
			"dr_pct": 0,
			"mdr": 3,
			"plr": 0,
			"fcr": 0,
			"fhr": 0,
			"fbr": 0,
			"frw": 3,
			"crushing_blow": 0,
			"deadly_strike": 0,
			"open_wounds": 0,
			"crit_rate": 0,
			"crit_dmg": 200,
			"life_steal": 0,
			"mana_steal": 0,
			"life_after_kill": 0,
			"mana_after_kill": 0,
			"ignore_def": 0,
			"all_skills": 0,
			"magic_find": 23,
			"gold_find": 0,
			"light_radius": 1,
			"cannot_be_frozen": 0
		},
		"equips": {
			"necklace": {
				"name": "\u001b[f#00FF00m西刚的项圈\u001b[0m",
				"clean_name": "西刚的项圈",
				"icon": "items/misc/amulet/amulet2.lowend.png",
				"quality": "set",
				"type": "set",
				"file_id": "/clone/d2/equipment#20141",
				"sockets": 0,
				"inlays": []
			},
			"gloves": {
				"name": "\u001b[f#00FF00m西刚之铁手\u001b[0m",
				"clean_name": "西刚之铁手",
				"icon": "items/armor/glove/gloves_l.lowend.png",
				"quality": "set",
				"type": "set",
				"file_id": "/clone/d2/equipment#20140",
				"sockets": 0,
				"inlays": []
			},
			"ring1": {
				"name": "\u001b[f#908858m拿各的戒指\u001b[0m",
				"clean_name": "拿各的戒指",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique",
				"type": "unique",
				"file_id": "/clone/d2/equipment#20144",
				"sockets": 0,
				"inlays": []
			},
			"helmet": {
				"name": "\u001b[f#4850B8m权冠之环\u001b[0m",
				"clean_name": "权冠之环",
				"icon": "items/armor/circlet/diadem.lowend.png",
				"quality": "magic",
				"type": "magic",
				"file_id": "/clone/d2/equipment#20135",
				"sockets": 0,
				"inlays": []
			},
			"pants": {
				"name": "\u001b[f#908858m雷神之力\u001b[0m",
				"clean_name": "雷神之力",
				"icon": "items/armor/belt/sash_l.lowend.png",
				"quality": "unique",
				"type": "unique",
				"file_id": "/clone/d2/equipment#20142",
				"sockets": 0,
				"inlays": []
			},
			"main_hand": {
				"name": "\u001b[f#808080m法师宝珠\u001b[0m",
				"clean_name": "法师宝珠",
				"icon": "items/weapon/orb/smoked_sphere.lowend.png?sock=1&inlays=",
				"quality": "normal",
				"type": "normal",
				"file_id": "/clone/d2/equipment#20132",
				"sockets": 1,
				"inlays": [""]
			}
		}
	}
	
	panel.render_gscore_data(real_mud_gscore)
	await get_tree().process_frame
	
	print("--- 验证各项数值是否精准消费 LPC 数据 ---")
	print("等级:", panel.lbl_level.text)
	assert(panel.lbl_level.text == "90", "等级应为 90")
	
	print("生命:", panel.lbl_hp.text)
	assert(panel.lbl_hp.text == "162 / 162", "生命应为 162 / 162")
	
	print("物理伤害:", panel.lbl_phy_dmg.text)
	assert(panel.lbl_phy_dmg.text == "30 ~ 40", "物理伤害应为武器真实区间 30 ~ 40")
	
	print("魔法伤害:", panel.lbl_mag_dmg.text)
	assert(panel.lbl_mag_dmg.text == "7845 ~ 9268", "魔法伤害应为主攻火球术真实区间 7845 ~ 9268")
	var title_mag = panel.find_child("H_Mag", true, false).get_node("T") as Label
	print("魔法攻击标题:", title_mag.text)
	assert(title_mag.text == "魔法攻击 (火球术)", "魔法攻击标题应动态包含主攻技能名")
	
	print("防御力:", panel.lbl_defense.text)
	assert(panel.lbl_defense.text == "285", "防御力应为 285")
	
	print("准确率:", panel.lbl_ar.text)
	assert(panel.lbl_ar.text == "228", "准确率应为 228")
	
	print("火焰抗性:", panel.lbl_res_fire.text)
	assert(panel.lbl_res_fire.text == "11% / 75%", "火抗应为 11% / 75%")
	
	print("冰冷抗性:", panel.lbl_res_cold.text)
	assert(panel.lbl_res_cold.text == "18% / 75%", "冰抗应为 18% / 75%")
	
	print("闪电抗性:", panel.lbl_res_light.text)
	assert(panel.lbl_res_light.text == "11% / 75%", "电抗应为 11% / 75%")
	
	print("毒素抗性:", panel.lbl_res_poison.text)
	assert(panel.lbl_res_poison.text == "61% / 75%", "毒抗应为 61% / 75%")
	
	print("寻宝 (MF):", panel.lbl_mf.text)
	assert(panel.lbl_mf.text == "23%", "MF 应为 23%")
	
	print("高跑 (FRW):", panel.lbl_frw.text)
	assert(panel.lbl_frw.text == "3%", "FRW 应为 3%")
	
	print("魔法减伤 (MDR):", panel.lbl_mdr.text)
	assert(panel.lbl_mdr.text == "3", "MDR 应为 3")
	
	print("四维展示:")
	print("  力量:", panel.val_str.text)
	print("  敏捷:", panel.val_dex.text)
	assert(panel.val_str.text == "11 (+1)", "力量展示应含加成 11 (+1)")
	assert(panel.val_dex.text == "31 (+6)", "敏捷展示应含加成 31 (+6)")
	
	print("纸娃娃槽位:")
	assert(panel.slot_main_hand.current_item_data.get("clean_name") == "法师宝珠", "主手应装配法师宝珠")
	assert(panel.slot_helmet.current_item_data.get("clean_name") == "权冠之环", "头部应装配权冠之环")
	assert(panel.slot_necklace.current_item_data.get("clean_name") == "西刚的项圈", "项链应装配西刚的项圈")
	assert(panel.slot_gloves.current_item_data.get("clean_name") == "西刚之铁手", "手套应装配西刚之铁手")
	assert(panel.slot_pants.current_item_data.get("clean_name") == "雷神之力", "腰带应装配雷神之力")
	assert(panel.slot_ring1.current_item_data.get("clean_name") == "拿各的戒指", "戒指1应装配拿各的戒指")
	
	print(">>> 全部断言通过！纯渲染消费 LPC 数据闭环验证成功！")
	
	# 测试滚动条并截图
	var artifact_dir = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c"
	var scroll = panel.find_child("Scroll", true, false) as ScrollContainer
	assert(scroll != null, "必须包含 ScrollContainer 节点")
	
	await get_tree().create_timer(0.3).timeout
	var img1 = get_viewport().get_texture().get_image()
	img1.save_png(artifact_dir + "/test_char_panel_top.png")
	print("截图已保存: test_char_panel_top.png (滚动条在顶部)")
	
	# 向下滑动到中间
	scroll.scroll_vertical = 120
	await get_tree().create_timer(0.3).timeout
	var img2 = get_viewport().get_texture().get_image()
	img2.save_png(artifact_dir + "/test_char_panel_middle.png")
	print("截图已保存: test_char_panel_middle.png (滚动条向下滑动到中段)")
	
	# 向下滑动到更下方
	scroll.scroll_vertical = 260
	await get_tree().create_timer(0.3).timeout
	var img3 = get_viewport().get_texture().get_image()
	img3.save_png(artifact_dir + "/test_char_panel_bottom.png")
	print("截图已保存: test_char_panel_bottom.png (滚动条向下滑动到特技段)")
	
	# 向下滑动到最底部（技能与寻宝探索）
	scroll.scroll_vertical = 600
	await get_tree().create_timer(0.3).timeout
	var img4 = get_viewport().get_texture().get_image()
	img4.save_png(artifact_dir + "/test_char_panel_end.png")
	print("截图已保存: test_char_panel_end.png (滚动条完全触底)")
	
	print("--- 自动化全流程验证完成！准备退出 ---")
	get_tree().quit(0)
