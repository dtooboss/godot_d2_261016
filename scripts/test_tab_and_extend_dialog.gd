extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	var mock_items = [
		{
			"name": "\u001b[f#908858m短剑\u001b[0m",
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"amount": 1,
			"quality": "unique",
			"cmd": "look /d/d2/obj/sword#1",
			"file_id": "/d/d2/obj/sword#1",
			"in_charm_bag": 0,
			"is_charm": 0,
			"charm_size": 1,
			"item_info": {
				"name": "短剑",
				"desc": "<center>\u001b[f#908858m短剑\u001b[0m\n攻击力: 3 - 7</center>"
			}
		}
	]
	
	hud.inventory_panel.render_lpc_items(mock_items, 0, 40)
	
	# 打开扩展背包弹窗进行截图
	hud.inventory_panel._on_add_page_pressed()
	
	await get_tree().create_timer(0.4).timeout
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/add_inventory_dialog_preview.png"
	img.save_png(shot)
	print("SAVED_ADD_INV_SHOT: " + shot)
	get_tree().quit(0)
