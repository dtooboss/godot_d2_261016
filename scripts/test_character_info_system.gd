extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	print("--- 测试 1: 模拟点击右下角【角色信息(C)】按钮 ---")
	assert(hud.char_info_panel.visible == false, "初始角色面板应该为隐藏状态")
	
	# 模拟点击控制矩阵里的角色信息按钮
	hud.control_matrix.btn_character.pressed.emit()
	await get_tree().process_frame
	assert(hud.char_info_panel.visible == true, "点击【角色信息(C)】按钮后角色面板应该打开！")
	print(">>> 点击按钮打开角色信息面板测试通过！")
	
	print("--- 测试 2: 极端 null 脏数据下的安全性 ---")
	var dirty_null_gscore = {
		"name": "测试空值角色",
		"level": null,
		"class": "bar",
		"str": null,
		"dex": null,
		"vit": null,
		"int": null,
		"hp": null,
		"max_hp": null,
		"mp": null,
		"max_mp": null,
		"exp": null,
		"next_exp": null,
		"stat_points": null,
		"combat": {
			"phy_dmg_min": null,
			"phy_dmg_max": null,
			"phy_dps": null,
			"mag_dmg_min": null,
			"mag_dmg_max": null,
			"mag_dps": null,
			"dmg_enhance": null,
			"attack_speed": null,
			"hit_rate": null,
			"crit_rate": null,
			"crit_dmg": null,
			"defense": null,
			"res_fire": null,
			"res_cold": null,
			"res_lightning": null,
			"res_poison": null
		},
		"equips": null
	}
	
	hud._on_network_json("gscore", dirty_null_gscore)
	assert(hud.char_info_panel.current_stat_points == 0, "current_stat_points 应该安全兜底为 0")
	print(">>> 极端 null 数据测试通过：无崩溃，成功安全回退到默认数值！")
	
	# 随后下发正常的真实模拟数据
	var mock_gscore = {
		"name": "野蛮人战神",
		"level": 35,
		"class": "bar",
		"str": 120,
		"dex": 80,
		"vit": 150,
		"int": 30,
		"hp": 650,
		"max_hp": 650,
		"mp": 120,
		"max_mp": 120,
		"exp": 124500,
		"next_exp": 196000,
		"stat_points": 5,
		"combat": {
			"phy_dmg_min": 120,
			"phy_dmg_max": 240,
			"phy_dps": 288.50,
			"mag_dmg_min": 10,
			"mag_dmg_max": 20,
			"mag_dps": 15.00,
			"dmg_enhance": 85,
			"attack_speed": 40,
			"hit_rate": 88,
			"crit_rate": 15,
			"crit_dmg": 260,
			"defense": 320,
			"res_fire": 45,
			"res_cold": 30,
			"res_lightning": 50,
			"res_poison": 20
		},
		"equips": {
			"helmet": {
				"name": "\u001b[f#908858m亚瑞特的面容\u001b[0m",
				"icon": "items/armor/helmet/helm.lowend.png",
				"quality": "unique",
				"file_id": "/d/d2/obj/arreat_face#1",
				"item_info": {
					"name": "亚瑞特的面容",
					"desc": "<center>\u001b[f#908858m亚瑞特的面容\u001b[0m\n杀手防护冠\n防御: 350\n+2 所有野蛮人技能\n+30% 快速打击恢复\n+20 力量\n+20 敏捷\n所有抗性 +30</center>"
				}
			},
			"main_hand": {
				"name": "\u001b[f#908858m祖父之剑\u001b[0m",
				"icon": "items/weapon/sword/short_sword.lowend.png",
				"quality": "unique",
				"file_id": "/d/d2/obj/grandfather#1",
				"item_info": {
					"name": "祖父之剑",
					"desc": "<center>\u001b[f#908858m祖父之剑\u001b[0m\n巨神之刃\n双手伤害: 180 - 450\n+200% 伤害\n+250 准确率\n+20 所有属性</center>"
				}
			}
		}
	}
	
	hud._on_network_json("gscore", mock_gscore)
	
	# 悬停在头盔槽位展示 Tooltip
	var helm_btn = hud.char_info_panel.slot_helmet
	hud.item_tooltip.show_item(hud.char_info_panel.equips_map["helmet"], helm_btn.global_position)
	
	await get_tree().create_timer(0.4).timeout
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/char_info_btn_clicked_verified.png"
	img.save_png(shot)
	print("SAVED_CHAR_PANEL_SHOT: " + shot)
	get_tree().quit(0)
