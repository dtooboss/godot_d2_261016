extends SceneTree

func _init():
	print("========================================")
	print("   开始 Tooltip 避让与防闪烁全功能测试   ")
	print("========================================")
	
	var packed = load("res://scenes/afk/components/item_tooltip.tscn")
	var tooltip = packed.instantiate()
	root.add_child(tooltip)
	
	# 等待两帧以确保 _ready() 完成且视口与主题就绪
	await process_frame
	await process_frame
	
	# 测试 1: 鼠标穿透递归检测
	print("\n[测试 1] 鼠标穿透 (mouse_filter == MOUSE_FILTER_IGNORE) 验证...")
	var all_nodes = []
	_collect_controls(tooltip, all_nodes)
	var any_blocking = false
	for c in all_nodes:
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("  ❌ 节点拦截鼠标: ", c.name, " filter=", c.mouse_filter)
			any_blocking = true
	if not any_blocking:
		print("  ✅ 成功: Tooltip 全树所有节点 (共 %d 个) 均已穿透 (MOUSE_FILTER_IGNORE)" % all_nodes.size())
	assert(not any_blocking, "存在阻挡鼠标事件的节点！")
	
	# 测试用例定义
	var narrow_item = {
		"name": "超强红茶",
		"type": "消耗品",
		"desc": "[color=#ffffff]恢复生命值 150 点[/color]",
		"amount": 20
	}
	
	var wide_item = {
		"name": "风之力 (Windforce) 九头蛇弓",
		"type": "弓",
		"desc": "[center][color=#908858][b]风之力[/b][/color]\n[color=#ffffff]九头蛇弓[/color]\n双手伤害: 35 到 241\n需要等级: 73\n需要力量: 134\n需要敏捷: 167\n弓等级 - 基础攻击速度: [10]\n[color=#4850b8]+250% 增强伤害\n+ (每级 3.125) 3-309 最大伤害 (依角色等级决定)\n20% 提升攻击速度\n8% 击中偷取法力\n击退\n+10 力量\n+5 敏捷\n体力恢复速度提升 30%[/color][/center]",
		"sockets": 1
	}
	
	# 模拟背包 7 列格子 (X 从 1000 到 1228)
	var slot_cols = [1000.0, 1038.0, 1076.0, 1114.0, 1152.0, 1190.0, 1228.0]
	var slot_w = 38.0
	var slot_y = 250.0
	
	print("\n[测试 2] 背包右侧 7 列格子 (窄卡片与宽卡片) 零重叠避让测试...")
	for col_idx in range(slot_cols.size()):
		var slot_x = slot_cols[col_idx]
		var slot_pos = Vector2(slot_x, slot_y)
		
		# 测试 2.1: 窄物品
		tooltip.show_item(narrow_item, slot_pos)
		await process_frame
		var n_pos = tooltip.global_position
		var n_size = tooltip.size
		var n_right = n_pos.x + n_size.x
		assert(n_right <= slot_x, "窄卡片侵入了格子！")
		
		# 测试 2.2: 宽物品
		tooltip.show_item(wide_item, slot_pos)
		await process_frame
		
		var real_pos = tooltip.global_position
		var real_size = tooltip.size
		var right_edge = real_pos.x + real_size.x
		var left_edge = real_pos.x
		
		# 检查是否与格子区间 [slot_x, slot_x + slot_w] 重叠
		var overlaps = (right_edge > slot_x and left_edge < slot_x + slot_w)
		print("  列 %d (slot_x=%.1f): 窄卡片宽=%.1f 右缘=%.1f | 宽卡片宽=%.1f 右缘=%.1f | 宽卡片间隙=%.1f" % [
			col_idx, slot_x, n_size.x, n_right, real_size.x, right_edge, slot_x - right_edge
		])
		if overlaps:
			printerr("  ❌ 重叠错误！卡片侵入了格子区间！")
		assert(not overlaps, "卡片重叠了格子！")
		assert(right_edge <= slot_x, "卡片右边缘侵入了格子左边缘！")
	print("  ✅ 成功: 背包全部 7 列格子均保持严格零重叠与安全间隙！")
	
	# 测试 3: 屏幕左侧格子自动反转避让测试 (如随身商店/纸娃娃/小口袋)
	print("\n[测试 3] 屏幕左侧格子 (空间不足时) 自动反转至右侧避让测试...")
	var left_slots = [50.0, 100.0, 150.0]
	for sx in left_slots:
		var slot_pos = Vector2(sx, 200.0)
		tooltip.show_item(wide_item, slot_pos)
		await process_frame
		
		var real_pos = tooltip.global_position
		var real_size = tooltip.size
		var right_edge = real_pos.x + real_size.x
		var left_edge = real_pos.x
		
		# 应当翻转到格子右侧: left_edge >= sx + slot_w
		var flipped_right = left_edge >= sx + slot_w
		var overlaps = (right_edge > sx and left_edge < sx + slot_w)
		print("  左侧格子 (slot_x=%.1f): 卡片反转至右侧 pos_x=%.1f, 右缘=%.1f | 与格子右缘间隙=%.1f" % [
			sx, left_edge, right_edge, left_edge - (sx + slot_w)
		])
		assert(flipped_right, "左侧格子空间不足时未翻转到右侧！")
		assert(not overlaps, "反转后发生重叠！")
	print("  ✅ 成功: 左侧狭窄区域已自动无缝翻转至右侧，100% 杜绝遮挡！")
	
	print("\n========================================")
	print("   🎉 恭喜！Tooltip 防闪烁避让测试全部通过！ ")
	print("========================================")
	quit()

func _collect_controls(node: Node, arr: Array) -> void:
	if node is Control:
		arr.append(node)
	for child in node.get_children():
		_collect_controls(child, arr)
