extends Node2D

func _ready() -> void:
	print("[TestSocketingWorkbench] Starting test...")
	var panel = preload("res://scenes/afk/components/socketing_workbench_panel.tscn").instantiate()
	add_child(panel)
	panel.position = Vector2(40, 30)
	panel.visible = true
	
	# 模拟放入一件 3 孔执政官铠甲（当前已镶 1 孔：31# 贾）
	var mock_armor = {
		"name": "执政官铠甲 (Archon Plate)",
		"raw_name": "$HIW$执政官铠甲$NOR$",
		"color": "#ffffff",
		"quality": "normal",
		"sockets": 3,
		"d2_max_sockets": 4, # 上限 4 孔，当前 3 孔，因此还可以打 1 孔！
		"inlays": ["clone/d2/rune/r31"], # 已镶嵌 31# 贾
		"file_id": "/clone/d2/armor/archon_plate#123",
		"icon": "res://assets/items/armor/armor/archon_plate.lowend.png"
	}
	
	panel.current_equipment = mock_armor
	panel._refresh_ui()
	
	print("[TestSocketingWorkbench] Current sockets:", mock_armor["sockets"])
	print("[TestSocketingWorkbench] Inlays:", mock_armor["inlays"])
	print("[TestSocketingWorkbench] UI refreshed. Waiting 1.0s for rendering...")
	
	await get_tree().create_timer(1.0).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_socketing_workbench.png")
	print("[TestSocketingWorkbench] Saved test_socketing_workbench.png successfully!")
	get_tree().quit(0)
