extends SceneTree

func _init() -> void:
	print("========== 开始测试：全新 LPC 业务驱动 + 前端纯渲染工坊 ==========")
	var scene = load("res://scenes/afk/afk_main_hud.tscn")
	if not scene:
		print("❌ 无法加载 afk_main_hud.tscn")
		quit(1)
		return
		
	var hud = scene.instantiate()
	root.add_child(hud)
	
	var inv = hud.get_node("%PlayerInventoryPanel")
	var wb = hud.get_node("%SocketingWorkbenchPanel")
	
	assert(inv != null, "背包面板必须存在")
	assert(wb != null, "凹槽工坊面板必须存在")
	
	var captured_cmds: Array = []
	inv.action_requested.connect(func(c): captured_cmds.append(c))
	wb.action_requested.connect(func(c): captured_cmds.append(c))
	
	# 测试 1: 模拟打开工坊面板，触发 gsocket query
	print("\n[测试 1] 模拟打开工坊面板...")
	wb.set_current_page(3)
	wb.open()
	assert(captured_cmds.has("gsocket query 3"), "打开工坊必须向 LPC 发送 gsocket query 3")
	print("✅ 测试 1 通过：打开工坊成功发送 gsocket query 3")
	captured_cmds.clear()
	
	# 测试 2: 模拟 LPC 下发包含 4 孔装备 (已镶嵌 2 颗符文) 的工坊状态帧
	print("\n[测试 2] 模拟 LPC 下发 gsocket 数据帧...")
	var gsocket_data = {
		"equipment": {
			"file_id": "/clone/armor/plate_mail_01",
			"name": "巨型鳞甲",
			"color": "#1eff00",
			"icon": "res://assets/images/gemsocket.lowend.png",
			"sockets": 4,
			"max_sockets": 6,
			"inlay_count": 2,
			"inlays": [
				"res://assets/images/gemsocket.lowend.png",
				"res://assets/images/gemsocket.lowend.png",
				"",
				""
			],
			"quality": "normal"
		},
		"tool": {
			"file_id": "/clone/d2/tool/dakong_01",
			"name": "普通打孔器",
			"icon": "res://assets/images/gemsocket.lowend.png"
		},
		"can_punch": true,
		"can_uninlay": true,
		"punch_hint": "当前 4/6 孔，可打孔 (+1)",
		"page": 3
	}
	hud._on_network_json("gsocket", gsocket_data)
	
	# 检查 UI 是否纯数据驱动渲染成功
	assert(wb.equip_name_label.text.contains("巨型鳞甲"), "装备名称必须显示巨型鳞甲")
	assert(wb.btn_punch.disabled == false, "打孔按钮必须可用")
	assert(wb.btn_uninlay.disabled == false, "洗孔按钮必须可用")
	assert(wb.btn_uninlay.text.contains("共2颗"), "洗孔按钮文本必须包含共2颗")
	assert(wb.sockets_grid.get_child_count() == 4, "凹槽网格必须精确显示 4 个孔位")
	print("✅ 测试 2 通过：纯数据驱动渲染成功 (装备/打孔器/4个孔位/洗孔高亮)")
	
	# 测试 3: 模拟右键或拖入任意物品 (装备、符文或打孔器)
	print("\n[测试 3] 模拟右键物品放入工坊...")
	wb.visible = true
	# 模拟背包中的右键点击 (背包模拟一件符文)
	inv.items_map[0] = {
		"file_id": "/clone/d2/rune/r30_01",
		"name": "30# 贝 符文"
	}
	# 触发右键
	var slot0 = inv.grid_container.get_child(0)
	var ev_rclick = InputEventMouseButton.new()
	ev_rclick.button_index = MOUSE_BUTTON_RIGHT
	ev_rclick.pressed = true
	slot0.gui_input.emit(ev_rclick)
	
	assert(captured_cmds.has("gsocket put /clone/d2/rune/r30_01 3"), "工坊打开时右键物品必须直接向 LPC 发送 gsocket put 指令")
	print("✅ 测试 3 通过：右键物品直接交由 LPC 处理，已捕获: gsocket put /clone/d2/rune/r30_01 3")
	captured_cmds.clear()
	
	# 测试 4: 模拟点击洗孔
	print("\n[测试 4] 模拟点击洗孔确认...")
	wb._on_uninlay_pressed()
	# 触发确认框确定
	wb._confirm_dialog.confirmed.emit()
	assert(captured_cmds.has("gsocket unsocket 3"), "确认洗孔必须向 LPC 发送 gsocket unsocket 3")
	print("✅ 测试 4 通过：点击洗孔成功触发 gsocket unsocket 3")
	captured_cmds.clear()
	
	# 测试 5: 模拟取出装备
	print("\n[测试 5] 模拟点击取出装备...")
	wb._on_take_out_pressed()
	assert(captured_cmds.has("gsocket clear 3"), "点击取出必须向 LPC 发送 gsocket clear 3")
	print("✅ 测试 5 通过：点击取出成功触发 gsocket clear 3")
	
	print("\n🎉 恭喜！全新 LPC 专属工坊驱动 + 前端纯渲染全部 5 项测试 100% 通过！")
	hud.queue_free()
	quit(0)
