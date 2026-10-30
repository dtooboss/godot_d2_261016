extends Control

func _ready() -> void:
	print("==================================================")
	print("   START FULL MUTUAL EXCLUSION & WORKBENCH TEST   ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Part 1: 测试战斗挂机区 (AFK_MainHUD) 全浮窗排他性
	# ----------------------------------------------------
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var inv = hud.inventory_panel
	var pocket = inv.little_pocket_panel
	var wb = inv.socketing_workbench_panel

	# 1. 挂机战斗区：合成魔盒与镶嵌打孔按钮必须置灰禁用 (disabled = true)
	assert(hud.control_matrix.btn_workbench != null, "[HUD] 控制矩阵必须包含镶嵌打孔按钮")
	assert(hud.control_matrix.btn_workbench.disabled == true, "[HUD] 战斗挂机区镶嵌打孔按钮必须置灰禁用！")
	assert(hud.control_matrix.btn_craft != null, "[HUD] 控制矩阵必须包含合成魔盒按钮")
	assert(hud.control_matrix.btn_craft.disabled == true, "[HUD] 战斗挂机区合成魔盒按钮必须置灰禁用！")

	# 2. 挂机战斗区：尝试调用 toggle 方法必须被拦截，窗口保持不可见
	hud.toggle_workbench()
	assert(!wb.visible, "[HUD] 战斗挂机区工坊窗口绝对不可被打开！")
	hud.toggle_cube_panel()
	assert(!hud.cube_panel.visible, "[HUD] 战斗挂机区魔盒窗口绝对不可被打开！")

	# 3. 挂机战斗区：小口袋与纸娃娃互斥依然正常运作
	inv.btn_pocket.emit_signal("pressed")
	assert(pocket.visible, "[HUD] 点击小口袋按钮后小口袋必须打开")
	hud.toggle_character_info()
	assert(hud.char_info_panel.visible, "[HUD] 纸娃娃必须已打开")
	assert(!pocket.visible, "[HUD] 打开纸娃娃后小口袋必须保持关闭")

	print("✔ Part 1: Combat AFK HUD disabled state & mutual exclusion verified 100%!")
	hud.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Part 2: 测试安全区 (TownHub) 全浮窗排他性与工坊 gsocket 渲染
	# ----------------------------------------------------
	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	add_child(town)
	await get_tree().process_frame

	var t_inv = town.inventory_panel
	var t_pocket = t_inv.little_pocket_panel
	var t_wb = t_inv.socketing_workbench_panel

	# 1. 安全区打开小口袋
	t_inv.btn_pocket.emit_signal("pressed")
	assert(t_pocket.visible, "[Town] 点击小口袋按钮后小口袋必须打开")
	assert(!t_wb.visible, "[Town] 打开小口袋后工坊必须保持关闭")

	# 2. 安全区点击底部控制矩阵 '镶嵌打孔' -> 小口袋自动关闭
	assert(town.control_matrix.btn_workbench != null, "[Town] 控制矩阵必须包含镶嵌打孔按钮")
	assert(town.control_matrix.btn_workbench.text == "镶嵌打孔", "[Town] 镶嵌打孔按钮文字必须为 '镶嵌打孔'")
	town.control_matrix.btn_workbench.emit_signal("pressed")
	assert(!t_pocket.visible, "[Town] 打开工坊后小口袋必须互斥自动关闭")
	assert(t_wb.visible, "[Town] 工坊必须已打开")

	# 3. 安全区打开纸娃娃 -> 工坊自动互斥关闭
	town._toggle_character_info()
	assert(town.char_info_panel.visible, "[Town] 纸娃娃必须已打开")
	assert(!t_wb.visible, "[Town] 打开纸娃娃后工坊必须互斥自动关闭")

	# 4. 安全区收到 gsocket 数据帧 -> 工坊即时渲染出装备
	t_wb.visible = true
	var mock_gsocket = {
		"equipment": {
			"file_id": "/clone/armor/plate_mail_01",
			"name": "巨型鳞甲 (Sacred Armor)",
			"color": "#1eff00",
			"icon": "res://assets/images/gemsocket.lowend.png",
			"sockets": 4,
			"max_sockets": 4,
			"inlay_count": 2,
			"inlays": [
				"res://assets/images/gemsocket.lowend.png",
				"res://assets/images/gemsocket.lowend.png",
				"",
				""
			],
			"quality": "normal"
		},
		"tool": {},
		"can_punch": false,
		"can_uninlay": true,
		"punch_hint": "已达最大孔数(4孔)，无法再打",
		"page": 1
	}
	town._on_json_frame_received("gsocket", mock_gsocket)
	assert(t_wb.equip_name_label.text.contains("巨型鳞甲"), "[Town] 安全区接收 gsocket 帧后必须即时渲染装备名称！")
	assert(t_wb.sockets_grid.get_child_count() == 4, "[Town] 安全区凹槽网格必须精准呈现 4 个孔位！")
	assert(t_wb.btn_uninlay.disabled == false, "[Town] 洗孔按钮必须激活！")
	assert(t_wb.btn_uninlay.text.contains("共2颗"), "[Town] 洗孔按钮文案必须包含共2颗！")
	print("✔ Part 2: Town Hub full mutual exclusion & gsocket rendering verified 100%!")

	print("==================================================")
	print("  CONGRATULATIONS: ALL MUTUAL EXCLUSION TESTS OK! ")
	print("==================================================")
	get_tree().quit(0)
