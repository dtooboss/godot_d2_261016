extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	# 模拟 LPC 下发雷尼摩饰带数据帧
	var mock_items = [
		{
			"name": "\u001b[f#908858m雷尼摩\u001b[0m",
			"icon": "items/armor/belt/sash.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/lenymo#1",
			"item_info": {
				"name": "雷尼摩",
				"desc": "<center>\u001b[f#908858m雷尼摩\u001b[0m\n\u001b[37m饰带\u001b[0m\n防御: \u001b[f#4850b8m2\u001b[0m\n耐久度: 100 / 100\n需要等级: 7\n\n\u001b[f#4850b8m+5% 所有抗性\n+1 照亮范围\n+15 法力值\n+30 法力恢复速度\u001b[0m</center>"
			}
		},
		{
			"name": "\u001b[f#908858m艾利屈之眼\u001b[0m",
			"icon": "items/misc/amulet/amulet1.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/eye_of_etlich#2",
			"item_info": {
				"name": "艾利屈之眼",
				"desc": "<center>\u001b[f#908858m艾利屈之眼\u001b[0m\n\u001b[37m项链\u001b[0m\n需要等级: 15\n\n\u001b[f#4850b8m+1 所有技能\n+3-7 冰冷伤害 (持续2-10秒)\n7% 击中偷取生命\n+40 对远距离攻击防御\n+5 照亮范围\u001b[0m</center>"
			}
		}
	]
	
	hud.inventory_panel.render_lpc_items(mock_items)
	
	# 模拟鼠标悬浮在第一个格子上
	var first_slot_btn = hud.inventory_panel.slots[0]
	hud.item_tooltip.show_item(hud.inventory_panel.items_map[0], first_slot_btn.global_position)
	await get_tree().create_timer(0.4).timeout
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/tooltip_compact_preview.png"
	img.save_png(shot)
	print("SAVED_COMPACT_SHOT: " + shot)
	get_tree().quit(0)
