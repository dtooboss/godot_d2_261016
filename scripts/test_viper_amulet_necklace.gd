extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始验证蝮蛇护符(项链槽)与单复数鞋/手套穿戴集成测试 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
	
	var char_panel = hud.char_info_panel
	char_panel.open()
	await get_tree().process_frame
	
	var esc = char(27)
	# 模拟服务端经自愈与数据修正后下发的 gscore 装备映射
	var test_gscore = {
		"level": 30,
		"hp": 550,
		"max_hp": 550,
		"stat_points": 0,
		"equips": {
			"necklace": {
				"name": "蝮蛇护符",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/misc/amulet/amulet2.lowend.png",
				"desc": esc + "[img:items/misc/amulet/amulet2.lowend.png]\n蝮蛇护符 [已装备]\n赫拉迪克之杖顶端\n防御: 57\n耐久度: 100 / 100\n+10 生命值\n+10 法力值\n+25% 毒素抗性",
				"file_id": "/d/d2/obj/amulet#viper"
			},
			"armor": {
				"name": "抽动的挣扎",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/armor/armor/leather_armor.lowend.png",
				"desc": esc + "[img:items/armor/armor/leather_armor.lowend.png]\n抽动的挣扎\n镶嵌甲\n防御: 60",
				"file_id": "/d/d2/obj/armor#twitchthroe"
			},
			"boots": {
				"name": "水上飘",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/armor/boots/boots.lowend.png",
				"desc": esc + "[img:items/armor/boots/boots.lowend.png]\n水上飘\n鲨皮之靴",
				"file_id": "/d/d2/obj/boots#waterwalk"
			},
			"gloves": {
				"name": "法师之拳",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/armor/gloves/leather_gloves.lowend.png",
				"desc": esc + "[img:items/armor/gloves/leather_gloves.lowend.png]\n法师之拳\n轻型铁手套",
				"file_id": "/d/d2/obj/gloves#magefist"
			}
		}
	}
	
	char_panel.render_gscore_data(test_gscore)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	
	# 断言检查
	var slot_neck = char_panel.slot_necklace
	var slot_armor = char_panel.slot_armor
	var slot_boots = char_panel.slot_boots
	var slot_gloves = char_panel.slot_gloves
	
	assert(slot_neck.current_item_data.get("name") == "蝮蛇护符", "项链槽位必须装备蝮蛇护符！")
	assert(slot_neck.current_quality == "unique", "蝮蛇护符在项链槽位必须呈现暗金品质边框！")
	
	assert(slot_armor.current_item_data.get("name") == "抽动的挣扎", "胸甲槽位必须装备胸甲，绝不能再被护符霸占！")
	assert(slot_boots.current_item_data.get("name") == "水上飘", "鞋子槽位必须正常装备单数 slot 的靴子！")
	assert(slot_gloves.current_item_data.get("name") == "法师之拳", "手套槽位必须正常装备手套！")
	
	print(">>> 验证全部 100% 通过：蝮蛇护符完美就位于项链栏，胸甲/鞋子/手套各归其位！")
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_viper_amulet_necklace.png")
	print(">>> 截图成功保存至 res://test_viper_amulet_necklace.png")
	get_tree().quit(0)
