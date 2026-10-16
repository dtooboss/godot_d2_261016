extends Control

@onready var hud = $AFK_MainHUD

var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证背包悬浮防误关、无 look 缓存与 300ms 延时 look 机制 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
		net.raw_sent.connect(func(cmd):
			if cmd.begins_with("look"):
				sent_commands.append(cmd)
				print("[Test] 捕获客户端装备查询发包: ", cmd)
		)
		
	var inv_panel = hud.inventory_panel
	var tooltip = hud.item_tooltip
	assert(inv_panel != null, "inv_panel 必须存在")
	assert(tooltip != null, "tooltip 必须存在")
	
	# 清空命令队列
	AFK_ItemTooltip.clear_cache()
	sent_commands.clear()
	
	# 构造测试物品数据注入背包
	var test_items = [
		{
			"name": "格利风之眼",
			"quality": "unique",
			"file_id": "/d/d2/obj/diadem#1001",
			"cmd": "look /d/d2/obj/diadem#1001",
			"icon": "items/armor/helmet/diadem.lowend.png",
			"desc": "权冠\n防御: 260\n+1 级所有技能"
		},
		{
			"name": "谜团",
			"quality": "runeword",
			"file_id": "/d/d2/obj/armor#1002",
			"cmd": "look /d/d2/obj/armor#1002",
			"icon": "items/armor/armor/mage_plate.lowend.png",
			"desc": "法师铠甲\n+1 传送\n+775 防御"
		}
	]
	inv_panel.render_lpc_items(test_items)
	await get_tree().process_frame
	
	var slot0_btn = inv_panel.slots[0]
	var slot1_btn = inv_panel.slots[1]
	
	# =========================================================================
	# 测试 1: 验证相邻格子滑动时的反向退出竞态保护 (消除卡死显示不出的根因)
	# =========================================================================
	print("\n--- [测试 1] 验证相邻格子滑动时退出事件不会误关 Tooltip ---")
	# 1. 鼠标进入 Slot 0
	inv_panel._on_slot_hovered(0, slot0_btn)
	await get_tree().process_frame
	assert(tooltip.visible == true, "Slot 0 移入后 Tooltip 应立即可见")
	assert(tooltip._current_displayed_key == "/d/d2/obj/diadem#1001", "当前展示的应为格利风之眼")
	
	# 2. 模拟 Godot 引擎高频滑动竞态: Slot 1 先触发 entered，Slot 0 随后触发 exited
	inv_panel._on_slot_hovered(1, slot1_btn)
	assert(tooltip._current_displayed_key == "/d/d2/obj/armor#1002", "应无缝切换为谜团")
	
	# 此时 Slot 0 的离开事件延迟到达
	inv_panel._on_slot_unhovered(0)
	await get_tree().process_frame
	
	# 关键断言: Tooltip 绝不可被 Slot 0 的过期离开事件关闭！
	assert(tooltip.visible == true, "Tooltip 必须保持可见，绝不可被前一个格子的退出事件误关！")
	assert(tooltip._current_displayed_key == "/d/d2/obj/armor#1002", "Tooltip 应稳定保持显示 Slot 1 的谜团")
	print("✓ 测试 1 通过: 相邻槽位滑动竞态保护有效，Tooltip 稳定保持可见！")
	
	# 正常离开 Slot 1
	inv_panel._on_slot_unhovered(1)
	await get_tree().process_frame
	assert(tooltip.visible == false, "真正离开当前槽位后 Tooltip 正常隐藏")
	
	# =========================================================================
	# 测试 2: 验证 300ms 黄金悬停防抖机制 (快速划过路过格子 0 发包)
	# =========================================================================
	print("\n--- [测试 2] 验证 300ms 悬停防抖机制 ---")
	sent_commands.clear()
	
	# 快速划过 Slot 0 (停留 150ms 立即移走，低于 300ms 阈值)
	inv_panel._on_slot_hovered(0, slot0_btn)
	await get_tree().create_timer(0.15).timeout
	inv_panel._on_slot_unhovered(0)
	await get_tree().create_timer(0.20).timeout # 总等待 350ms
	
	assert(sent_commands.is_empty(), "停留时间未达到 300ms，严禁发送任何 look 网络包！实际发包: %s" % str(sent_commands))
	print("✓ 快速扫过格子 (150ms < 300ms) 成功被防抖拦截，完全零发包")
	
	# 稳定悬停在 Slot 0 (停留超过 300ms，如 350ms)
	inv_panel._on_slot_hovered(0, slot0_btn)
	await get_tree().create_timer(0.35).timeout # 等待 350ms
	
	assert(sent_commands.size() == 1, "停留超过 300ms 后应正式发包 1 次")
	assert(sent_commands[0] == "look /d/d2/obj/diadem#1001", "发出的命令必须为目标装备的 look 指令")
	print("✓ 停留达到 300ms 后成功发出 look 指令: %s" % sent_commands[0])
	
	# =========================================================================
	# 测试 3: 验证无缓存实时机制 (重访每次均发送 look，确保属性点变动实时计算红白)
	# =========================================================================
	print("\n--- [测试 3] 验证无 look 缓存实时发包机制 ---")
	sent_commands.clear()
	
	# 模拟服务端下发权威词缀 panel 帧
	var esc = char(27)
	var server_panel = {
		"desc": "<center>" + esc + "[img:items/armor/helmet/diadem.lowend.png]\n格利风之眼\n权冠\n防御: 260\n+1 级所有技能\n-20% 敌人闪电抗性\n+15% 闪电技能伤害\n+25 敏捷</center>"
	}
	net.json_frame_received.emit("panel", server_panel)
	await get_tree().process_frame
	
	# 验证内容被权威词缀更新
	assert(tooltip.content_label.text.contains("-20% 敌人闪电抗性"), "Tooltip 应成功更新服务端权威词缀")
	
	# 移开鼠标隐藏 Tooltip
	inv_panel._on_slot_unhovered(0)
	await get_tree().process_frame
	assert(tooltip.visible == false, "Tooltip 隐藏")
	
	# 再次移入 Slot 0 (停顿超过 300ms)
	inv_panel._on_slot_hovered(0, slot0_btn)
	await get_tree().create_timer(0.35).timeout
	
	# 关键断言: 无本地缓存，重访依然触发 300ms 延时实时 look 请求，确保属性变更不卡红
	assert(tooltip.visible == true, "Tooltip 应展示骨架")
	assert(sent_commands.size() == 1, "取消本地缓存后，重访停顿必须重新发包向服务端请求最新状态！实际发包: %s" % str(sent_commands))
	assert(sent_commands[0] == "look /d/d2/obj/diadem#1001", "重访发出的必须是 look 指令")
	print("✓ 测试 3 通过: 无本地缓存干扰，重访装备停顿 300ms 实时发包请求服务端最新数据！")
	
	inv_panel._on_slot_unhovered(0)
	await get_tree().process_frame
	
	# =========================================================================
	# 测试 4: 验证迟到在途回包守护机制 (光标已移走，迟到包不闪烁错误UI)
	# =========================================================================
	print("\n--- [测试 4] 验证迟到在途回包守护 ---")
	sent_commands.clear()
	
	# 鼠标悬停 Slot 1 (谜团) 超过 300ms 发出网络请求
	inv_panel._on_slot_hovered(1, slot1_btn)
	await get_tree().create_timer(0.35).timeout
	assert(sent_commands.size() == 1, "Slot 1 触发网络请求")
	assert(sent_commands[0] == "look /d/d2/obj/armor#1002", "发出谜团 look 请求")
	
	# 在回包到达前，用户移开鼠标
	inv_panel._on_slot_unhovered(1)
	await get_tree().process_frame
	assert(tooltip.visible == false, "Tooltip 应及时隐藏")
	
	# 此时服务端的迟到回包到达
	var enigma_panel = {
		"desc": "<center>" + esc + "[img:items/armor/armor/mage_plate.lowend.png]\n谜团\n法师铠甲\n+2 所有技能\n+45% 奔跑/移动速度\n+1 传送\n+775 防御</center>"
	}
	net.json_frame_received.emit("panel", enigma_panel)
	await get_tree().process_frame
	
	# 断言: Tooltip 绝不会因为迟到回包而错误弹出或闪烁
	assert(tooltip.visible == false, "迟到回包绝不能导致隐藏的 Tooltip 错误弹出！")
	print("✓ 测试 4 通过: 在途回包守护有效，移出后迟到包不误显！")
	
	print("\n=======================================================")
	print("🎉 恭喜！背包防误关、无 look 缓存与 300ms 防抖测试全部通过！")
	print("=======================================================")
	get_tree().quit(0)
