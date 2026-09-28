extends Node

func _ready() -> void:
	print("=== 开始全新 LPC 数据驱动工坊端到端测试 ===")
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		
	var workbench_scene = load("res://scenes/afk/components/socketing_workbench_panel.tscn")
	if not workbench_scene:
		print("ERROR: Failed to load socketing_workbench_panel.tscn")
		get_tree().quit(1)
		return
		
	var panel = workbench_scene.instantiate()
	add_child(panel)
	panel.position = Vector2(50, 40)
	panel.visible = true
	
	var captured_actions: Array = []
	panel.action_requested.connect(func(cmd):
		print(">>> 捕获到前端派发指令:", cmd)
		captured_actions.append(cmd)
	)
	
	# 1. 模拟 LPC 下发战斗剑（带ANSI色彩码与战斗剑图标）
	var mock_lpc_data = {
		"equipment": {
			"name": "[F#808080m战斗剑[2;37;0m",
			"color": "#808080",
			"sockets": 3,
			"max_sockets": 4,
			"inlay_count": 1,
			"inlays": [
				"res://assets/images/gemsocket.lowend.png",
				"",
				""
			],
			"file_id": "/clone/d2/weapon/battle_sword#123",
			"icon": "items/weapon/sword/battle_sword.lowend.png"
		},
		"tool": {
			"name": "普通打孔器",
			"icon": "res://assets/images/gemsocket.lowend.png",
			"file_id": "/clone/d2/tool/dakong#456"
		},
		"can_punch": true,
		"can_uninlay": true,
		"punch_hint": "当前 4/6 孔，可打孔 (+1)",
		"page": 2
	}
	
	print(">>> 正在调用 render_workbench_data(mock_lpc_data)...")
	panel.render_workbench_data(mock_lpc_data)
	
	# 验证
	assert(panel.current_equipment.get("sockets") == 3, "孔数必须为3")
	assert(panel.btn_punch.disabled == false, "打孔按钮必须可用")
	assert(panel.btn_uninlay.disabled == false, "洗孔按钮必须可用")
	assert(panel.sockets_grid.get_child_count() == 3, "凹槽网格必须显示3个孔")
	print(">>> 数据驱动渲染验证全部通过！")
	
	# 2. 模拟拖拽接收测试 (拖入任意物品，无本地类型猜测，直接派发 gsocket put)
	panel._drop_data(Vector2.ZERO, {
		"item_data": {
			"file_id": "/clone/d2/rune/r30_01",
			"name": "30# 贝 符文"
		}
	})
	assert(captured_actions.has("gsocket put /clone/d2/rune/r30_01 2"), "拖拽必须直接派发 gsocket put 指令")
	print(">>> 拖拽派发 gsocket put 验证通过！")
	
	# 3. 模拟点击洗孔
	panel._on_uninlay_pressed()
	panel._confirm_dialog.confirmed.emit()
	assert(captured_actions.has("gsocket unsocket 2"), "洗孔确认必须派发 gsocket unsocket 指令")
	print(">>> 洗孔派发 gsocket unsocket 验证通过！")
	
	# 4. 模拟点击取出
	panel._on_take_out_pressed()
	assert(captured_actions.has("gsocket clear 2"), "取出必须派发 gsocket clear 指令")
	print(">>> 取出派发 gsocket clear 验证通过！")
	
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_socketing_workbench_pure_render.png")
	print(">>> 截图已保存至 res://test_socketing_workbench_pure_render.png！")
	print("🎉 全流程测试圆满成功！")
	get_tree().quit(0)
