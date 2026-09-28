extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	
	# 模拟 LPC gfenjie 默认全捡取配置 (所有装备分解项为0，孔数>=0)
	var default_d2_cfg = {
		"confirm_unique": 1,
		"keep_sockets": 1,
		"white_weapon": 0,
		"white_armor": 0,
		"white_shield": 0,
		"white_head": 0,
		"superior_prop": 0,
		"ethereal_prop": 0,
		"sockets_prop": 0,
		"magic_weapon": 0,
		"magic_armor": 0,
		"magic_boots_gloves": 0,
		"magic_jewelry": 0,
		"rare_armor": 0,
		"rare_weapon": 0,
		"rare_boots_gloves": 0,
		"rare_jewelry": 0,
		"set_weapon": 0,
		"set_armor": 0,
		"unique_weapon": 0,
		"unique_armor": 0,
		"unique_jewelry": 0,
		"material": 1,
		"key": 1,
		"jewel": 1,
		"skill": 1,
		"min_sockets": {
			"normal": 0,
			"superior": 4, # 模拟设置底材保留4孔以上
			"magic": 0,
			"rare": 0,
			"set": 0,
			"unique": 0
		}
	}
	
	# 打开物品拾取设置面板
	hud.toggle_pickup_setting()
	hud._on_network_json("gfenjie", {"action": "config", "config": default_d2_cfg})
	
	await get_tree().create_timer(0.2).timeout
	var panel = hud.pickup_setting_panel
	# 展开第 2 行【超强 (无形/底材)】以展示其细分项
	if panel and panel.rows_container and panel.rows_container.get_child_count() > 1:
		var sup_row = panel.rows_container.get_child(1)
		if sup_row.get_child_count() > 1:
			var sub_panel = sup_row.get_child(1)
			sub_panel.visible = true
			var btn_toggle = sup_row.get_child(0).get_child(0)
			if btn_toggle is Button:
				btn_toggle.text = "▲"
				
	await get_tree().create_timer(0.3).timeout
	
	# 保存实机截图
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/d2_pickup_setting_panel_preview.png"
	img.save_png(shot)
	print("SAVED_D2_PICKUP_SHOT: " + shot)
	get_tree().quit(0)
