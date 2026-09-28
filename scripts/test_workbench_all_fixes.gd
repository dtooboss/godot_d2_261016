extends Node

func _ready() -> void:
	print("=== 开始工坊与背包全方位修复测试 ===")
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		
	var workbench_scene = load("res://scenes/afk/components/socketing_workbench_panel.tscn")
	var panel = workbench_scene.instantiate()
	add_child(panel)
	panel.position = Vector2(40, 30)
	panel.visible = true
	
	# 测试 1: 放入 3 孔完全干净的空装备 (服务端返回 inlays = ["", "", ""])
	var clean_armor = {
		"name": "法师铠甲 (Mage Plate)",
		"raw_name": "$HIW$法师铠甲$NOR$",
		"color": "#ffffff",
		"quality": "normal",
		"sockets": 3,
		"d2_max_sockets": 4,
		"inlays": ["", "", ""], # 真实空孔
		"file_id": "/clone/d2/armor/mage_plate#456",
		"icon": "res://assets/items/armor/armor/plate_mail.lowend.png"
	}
	
	panel.put_equipment(clean_armor)
	
	var valid_inlays = panel.get_valid_inlays(panel.current_equipment.get("inlays", []))
	print(">>> 真实有效镶嵌物数量:", valid_inlays.size())
	assert(valid_inlays.size() == 0, "空孔装备的有效镶嵌物必须为 0！")
	assert(panel.btn_uninlay.disabled == true, "空孔装备的洗孔按钮必须置灰禁用！")
	print(">>> 验证 1 通过：空孔装备洗孔按钮成功置灰！")
	
	# 测试 2: 验证镶嵌物判定与拖拽放行
	var rune_jah = {
		"name": "31# 乔 (Jah)",
		"raw_name": "$HIW$31# 乔$NOR$",
		"file_id": "/clone/d2/rune/r31#777",
		"d2_type": "符文",
		"is_rune": 1,
		"icon": "items/misc/rune/jah_rune.lowend.png"
	}
	var drag_rune_data = {
		"source": "main_bag",
		"slot_idx": 0,
		"item_data": rune_jah
	}
	
	var can_inlay = panel._can_drop_data(Vector2.ZERO, drag_rune_data)
	print(">>> 拖拽符文检测放行状态 (应为 true):", can_inlay)
	assert(can_inlay == true, "有空孔时必须允许拖入符文！")
	print(">>> 验证 2 通过：符文拖拽判定放行成功！")
	
	# 测试 3: 模拟镶入 1 颗符文后状态
	clean_armor["inlays"] = ["clone/d2/rune/r31", "", ""]
	panel.put_equipment(clean_armor)
	valid_inlays = panel.get_valid_inlays(panel.current_equipment.get("inlays", []))
	print(">>> 镶入1颗后有效镶嵌物数量:", valid_inlays.size())
	assert(valid_inlays.size() == 1, "镶嵌1颗后有效镶嵌物必须为 1！")
	assert(panel.btn_uninlay.disabled == false, "已镶嵌装备的洗孔按钮必须激活！")
	print(">>> 验证 3 通过：已镶嵌装备的洗孔按钮成功激活亮起！")
	
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_socketing_workbench_fixed.png")
	print(">>> 走查截图已保存至 res://test_socketing_workbench_fixed.png")
	get_tree().quit(0)
