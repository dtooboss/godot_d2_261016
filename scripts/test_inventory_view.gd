extends Node2D

@onready var inv_panel = $InventoryPanel

func _ready() -> void:
	inv_panel.open_window()
	
	# 构造带有 LPC 真实 icon 路径的 paperdoll 与 charms 数据
	var test_arm = {
		"paperdoll": {
			"weapon": { "name": "风之力", "icon": "items/weapon/bow/short_bow.lowend.png" },
			"cloth": { "name": "谜团", "icon": "items/armor/armor/ancient_armor.lowend.png" },
			"head": { "name": "军帽", "icon": "items/armor/helmet/helm.lowend.png" },
			"neck": { "name": "马拉的万花筒", "icon": "items/misc/amulet/amulet1.lowend.png" },
			"belt": { "name": "雷神之力", "icon": "items/armor/belt/belt_m.lowend.png" },
			"boots": { "name": "战争旅者", "icon": "items/armor/boot/leather_boots.lowend.png" },
			"gloves": { "name": "法师之拳", "icon": "items/armor/glove/gloves_l.lowend.png" },
			"ring1": { "name": "乔丹之石", "icon": "items/misc/ring/ring1.lowend.png" },
			"ring2": { "name": "乌鸦之霜", "icon": "items/misc/ring/ring2.lowend.png" },
			"shield": { "name": "暴风之盾", "icon": "items/armor/shield/large_shield.lowend.png" }
		},
		"charms": [
			{ "name": "\u001b[33m毁灭小护身符\u001b[0m", "size": 1, "icon": "items/misc/charm/charm_small.lowend.png", "quality": "unique", "desc": "+1 所有技能\n+20 所有属性\n+20 所有抗性" },
			{ "name": "\u001b[32m艾席拉的护身符\u001b[0m", "size": 2, "icon": "items/misc/charm/charm_small.lowend.png", "quality": "set", "desc": "+100 防御\n+15 冰冷抗性" },
			{ "name": "\u001b[34m炽热之超大护身符\u001b[0m", "size": 3, "icon": "items/misc/charm/charm_small.lowend.png", "quality": "magic", "desc": "+1 冰霜系技能\n+35 生命" },
			{ "name": "\u001b[36m乔丹之石符文\u001b[0m", "size": 1, "icon": "items/misc/rune/el_rune.lowend.png", "quality": "rare", "desc": "符文 #31" }
		],
		"used_slots": 7,
		"max_slots": 40
	}
	
	inv_panel._render_arm_data(test_arm)
	
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	
	var img1 = get_viewport().get_texture().get_image()
	var shot1 = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/inventory_charm_bag_with_icons.png"
	img1.save_png(shot1)
	print("SAVED_SHOT1: " + shot1)
	
	# 切换到战利品仓 (DropStashView)
	inv_panel._switch_tab(1)
	
	var test_filters = [
		{ "label": "全部", "cmd": "inventory" },
		{ "label": "\u001b[33m装备\u001b[0m", "cmd": "inventory equip" },
		{ "label": "\u001b[32m套装\u001b[0m", "cmd": "inventory set" },
		{ "label": "\u001b[36m符文\u001b[0m", "cmd": "inventory rune" },
		{ "label": "\u001b[35m宝石\u001b[0m", "cmd": "inventory gem" }
	]
	inv_panel._render_stash_filters(test_filters)
	
	# 测试带有 LPC 原生 \x1b[i:...] 协议的战利品物品条目！
	var test_items = [
		{ "label": "\u001b[i:items/weapon/bow/short_bow.lowend.png]\u001b[f#908858m[暗金] 风之力 九头蛇弓\u001b[0m", "cmd": "look /d/d2/obj/wf#1" },
		{ "label": "\u001b[i:items/armor/armor/ancient_armor.lowend.png]\u001b[f#00FF00m[套装] 塔拉夏的守护 漆甲\u001b[0m", "cmd": "look /d/d2/obj/tal_armor#2" },
		{ "label": "\u001b[i:items/weapon/sword/short_sword.lowend.png]\u001b[f#FFFF64m[稀有] 幽灵之锋 巨剑 (+2野蛮人技能)\u001b[0m", "cmd": "look /d/d2/obj/rare_sword#3" },
		{ "label": "\u001b[i:items/armor/belt/belt_m.lowend.png]\u001b[f#4850B8m[魔法] 珠宝之快速巨鲸腰带\u001b[0m", "cmd": "look /d/d2/obj/belt#4" },
		{ "label": "\u001b[i:items/misc/rune/el_rune.lowend.png]\u001b[37m[符文] 31# 乔 (Jah)\u001b[0m", "cmd": "look /d/d2/obj/rune_jah#5" },
		{ "label": "\u001b[33m1/3页\u001b[0m", "cmd": "inventory 1" },
		{ "label": "下一页", "cmd": "inventory 2" }
	]
	inv_panel._render_stash_items_and_pages(test_items)
	
	# 触发一条物品的 look 面板 (模拟服务端 J_PANEL 带有 \x1b[img:...] 大图)
	var mock_panel_desc = "\u001b[img:items/armor/armor/ancient_armor.lowend.png?sock=4]\n<center>\u001b[f#00FF00m塔拉夏的守护 漆甲\u001b[0m\n\u001b[37m防御: \u001b[f#4850B8m941\u001b[0m\n需要等级: 71\n需要力量: 84\n\u001b[f#4850B8m+400 防御\n冰冷抗性 +40%\n闪电抗性 +40%\n火焰抗性 +40%\n魔法装备掉落率提升 88%\u001b[0m</center>"
	inv_panel._render_panel_card(mock_panel_desc)
	
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	
	var img2 = get_viewport().get_texture().get_image()
	var shot2 = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/inventory_stash_with_icons.png"
	img2.save_png(shot2)
	print("SAVED_SHOT2: " + shot2)
	
	get_tree().quit()
