extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始验证纸娃娃系统视觉品质染色与未穿戴底图还原 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
	
	var char_panel = hud.char_info_panel
	char_panel.open()
	await get_tree().process_frame
	
	var esc = char(27)
	var test_gscore = {
		"level": 85,
		"hp": 1850,
		"max_hp": 1850,
		"mp": 650,
		"max_mp": 650,
		"stat_points": 15,
		"equips": {
			"main_hand": {
				"name": "风之力",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/weapon/bow/composite_bow.lowend.png",
				"desc": esc + "[img:items/weapon/bow/composite_bow.lowend.png]\n风之力\n九头蛇弓\n双手伤害: 35 - 547\n需要力量: 134\n需要敏捷: 167\n+20% 攻击速度\n击退\n每级增加最大伤害",
				"file_id": "/d/d2/obj/bow#windforce"
			},
			"off_hand": {
				"name": "撒卡兰姆使者",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/armor/shield/gothic_shield.lowend.png",
				"desc": esc + "[img:items/armor/shield/gothic_shield.lowend.png]\n饰金盾牌\n防御: 507\n需要力量: 89\n所有抗性 +50%\n+2 圣骑士技能",
				"file_id": "/d/d2/obj/shield#herald"
			},
			"armor": {
				"name": "塔·拉夏的守护",
				"quality": "set",
				"color": "#00ff00",
				"icon": "items/armor/armor/plate_mail.lowend.png",
				"desc": esc + "[img:items/armor/armor/plate_mail.lowend.png]\n塔·拉夏的守护\n漆甲\n防御: 941\n需要力量: 84\n88% 获得魔法装备机率\n全抗 +40%",
				"file_id": "/d/d2/obj/armor#tal_armor"
			},
			"helmet": {
				"name": "塔·拉夏的赫拉迪克纹章",
				"quality": "set",
				"color": "#00ff00",
				"icon": "items/armor/helm/cap.lowend.png",
				"desc": esc + "[img:items/armor/helm/cap.lowend.png]\n塔·拉夏的面具\n死亡面具\n防御: 131\n10% 击中偷取生命\n10% 击中偷取法力\n全抗 +15%",
				"file_id": "/d/d2/obj/helm#tal_mask"
			},
			"necklace": {
				"name": "塔·拉夏的判决",
				"quality": "set",
				"color": "#00ff00",
				"icon": "items/misc/jewelry/amulet.lowend.png",
				"desc": esc + "[img:items/misc/jewelry/amulet.lowend.png]\n塔·拉夏的判决\n项链\n+2 巫师技能\n抗闪电 +33%\n受到闪电伤害: 1-42",
				"file_id": "/d/d2/obj/amulet#tal_neck"
			},
			"gloves": {
				"name": "残虐之重手套",
				"quality": "rare",
				"color": "#ffff00",
				"icon": "items/armor/gloves/leather_gloves.lowend.png",
				"desc": esc + "[img:items/armor/gloves/leather_gloves.lowend.png]\n残虐之重手套\n防御: 35\n+20% 攻击速度\n+15 敏捷\n+30% 抗火\n+28% 抗冰",
				"file_id": "/d/d2/obj/gloves#rare"
			},
			"boots": {
				"name": "灵巧之重靴",
				"quality": "rare",
				"color": "#ffff00",
				"icon": "items/armor/boots/boots.lowend.png",
				"desc": esc + "[img:items/armor/boots/boots.lowend.png]\n灵巧之重靴\n防御: 42\n+30% 高速跑步/行走\n+10 敏捷\n+40% 抗电",
				"file_id": "/d/d2/obj/boots#rare"
			},
			"ring1": {
				"name": "巴哈姆特之巨龙戒指",
				"quality": "magic",
				"color": "#4169e1",
				"icon": "items/misc/jewelry/ring.lowend.png",
				"desc": esc + "[img:items/misc/jewelry/ring.lowend.png]\n巴哈姆特之巨龙戒指\n+120 法力\n+40 生命",
				"file_id": "/d/d2/obj/ring#magic"
			},
			"ring2": {
				"name": "血灵之乌鸦印戒",
				"quality": "crafted",
				"color": "#ff8c00",
				"icon": "items/misc/jewelry/ring.lowend.png",
				"desc": esc + "[img:items/misc/jewelry/ring.lowend.png]\n血灵之乌鸦印戒\n+6% 击中偷取生命\n+25 力量\n+60 生命\n无法冰冻",
				"file_id": "/d/d2/obj/ring#crafted"
			}
			# pants, wings, pet 刻意留空，验证未穿戴时的原始暗沉底图保留
		}
	}
	
	char_panel.render_gscore_data(test_gscore)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	
	# 检查各个槽位的品质边框样式
	var slot_weapon = char_panel.slot_main_hand
	var slot_armor = char_panel.slot_armor
	var slot_gloves = char_panel.slot_gloves
	var slot_ring1 = char_panel.slot_ring1
	var slot_ring2 = char_panel.slot_ring2
	var slot_pants = char_panel.slot_pants
	
	assert(slot_weapon.current_quality == "unique", "武器应为 unique 暗金")
	assert(slot_armor.current_quality == "set", "铠甲应为 set 套装")
	assert(slot_gloves.current_quality == "rare", "手套应为 rare 亮金")
	assert(slot_ring1.current_quality == "magic", "戒指1应为 magic 魔法")
	assert(slot_ring2.current_quality == "crafted", "戒指2应为 crafted 橙色")
	assert(slot_pants.current_quality == "", "腰带未穿戴应为空")
	assert(slot_pants.icon != null, "未穿戴槽位必须保留部位轮廓底图")
	
	print(">>> 所有品质边框与底图断言全部通过！准备截屏...")
	
	# 截屏保存
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_paperdoll_quality_borders.png")
	print(">>> 截图成功保存至 res://test_paperdoll_quality_borders.png")
	get_tree().quit(0)
