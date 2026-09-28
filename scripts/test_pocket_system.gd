extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	# 模拟 LPC 下发包含普通装备与小口袋护身符的真实 gbag 数据帧
	var mock_items = [
		{
			"name": "\u001b[f#908858m雷尼摩\u001b[0m",
			"icon": "items/armor/belt/sash.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/lenymo#1",
			"file_id": "/d/d2/obj/lenymo#1",
			"in_charm_bag": 0,
			"is_charm": 0,
			"charm_size": 1,
			"item_info": {
				"name": "雷尼摩",
				"desc": "<center>\u001b[f#908858m雷尼摩\u001b[0m\n\u001b[37m饰带\u001b[0m\n防御: \u001b[f#4850b8m2\u001b[0m\n耐久度: 100 / 100\n需要等级: 7\n\n\u001b[f#4850b8m+5% 所有抗性\n+1 照亮范围\n+15 法力值\n+30 法力恢复速度\u001b[0m</center>"
			}
		},
		{
			"name": "\u001b[f#908858m毁灭\u001b[0m",
			"icon": "items/misc/charm/charm_small.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/annihilus#2",
			"file_id": "/d/d2/obj/annihilus#2",
			"in_charm_bag": 1,
			"is_charm": 1,
			"charm_size": 1,
			"item_info": {
				"name": "毁灭",
				"desc": "<center>\u001b[f#908858m毁灭\u001b[0m\n\u001b[37m小护身符\u001b[0m\n需要等级: 70\n\n\u001b[f#4850b8m+1 所有技能\n+20 所有属性\n+20% 所有抗性\n+10% 获得经验值\u001b[0m</center>"
			}
		},
		{
			"name": "\u001b[f#908858m地狱火炬\u001b[0m",
			"icon": "items/misc/charm/charm_medium.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/torch#3",
			"file_id": "/d/d2/obj/torch#3",
			"in_charm_bag": 1,
			"is_charm": 1,
			"charm_size": 2,
			"item_info": {
				"name": "地狱火炬",
				"desc": "<center>\u001b[f#908858m地狱火炬\u001b[0m\n\u001b[37m大型护身符\u001b[0m\n需要等级: 75\n\n\u001b[f#4850b8m+3 圣骑士技能\n+20 所有属性\n+20% 所有抗性\n攻击时 5% 概率施展等级 10 陨石\u001b[0m</center>"
			}
		}
	]
	
	hud.inventory_panel.render_lpc_items(mock_items, 3, 40)
	
	# 打开小口袋面板
	hud.inventory_panel.little_pocket_panel.open()
	
	# 悬停在小口袋的第一个护身符（毁灭）上，展示 Tooltip
	var pocket_btn = hud.inventory_panel.little_pocket_panel.slots[0]
	hud.item_tooltip.show_item(hud.inventory_panel.little_pocket_panel.items_map[0], pocket_btn.global_position)
	
	await get_tree().create_timer(0.4).timeout
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/pocket_and_tooltip_preview.png"
	img.save_png(shot)
	print("SAVED_POCKET_SHOT: " + shot)
	get_tree().quit(0)
