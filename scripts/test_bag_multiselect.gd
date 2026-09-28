extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	
	var inv_panel = hud.inventory_panel
	if not inv_panel:
		print("未找到 inventory_panel!")
		return
		
	# 模拟背包中多件物品
	var mock_items = [
		{
			"name": "海鸥 (Seagull)",
			"quality": "unique",
			"amount": 1,
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"file_id": "/clone/d2/unique_sword#1"
		},
		{
			"name": "塔·拉夏的赫拉迪姆冠顶",
			"quality": "set",
			"amount": 1,
			"icon": "items/armor/helmet/helm.lowend.png",
			"file_id": "/clone/d2/set_helm#2"
		},
		{
			"name": "残酷之刃 水晶剑",
			"quality": "rare",
			"amount": 1,
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"file_id": "/clone/d2/rare_sword#3"
		},
		{
			"name": "偏向之 统治者大盾",
			"quality": "magic",
			"amount": 1,
			"icon": "items/armor/shield/large_shield.lowend.png",
			"file_id": "/clone/d2/magic_shield#4"
		}
	]
	inv_panel.render_lpc_items(mock_items, 8, 40, 1)
	
	# 1. 模拟点击标题栏【多选】按钮进入多选模式
	await get_tree().create_timer(0.2).timeout
	inv_panel._on_multi_select_pressed()
	
	# 2. 模拟点击勾选第 0、1、2 个小方格子（多选上色 + 绿勾角标）
	await get_tree().create_timer(0.1).timeout
	inv_panel._toggle_slot_selection(0) # 选中海鸥
	inv_panel._toggle_slot_selection(1) # 选中塔拉夏
	inv_panel._toggle_slot_selection(2) # 选中水晶剑
	
	await get_tree().create_timer(0.3).timeout
	
	# 截图保存
	var img = get_viewport().get_texture().get_image()
	var shot = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/bag_multiselect_preview.png"
	img.save_png(shot)
	print("SAVED_MULTISELECT_SHOT: " + shot)
	get_tree().quit(0)
