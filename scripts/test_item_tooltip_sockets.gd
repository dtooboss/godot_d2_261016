extends SceneTree

func _init() -> void:
	print("[TEST] 开始测试 ItemTooltip 凹槽图形化与镶嵌物显示...")
	
	var tooltip = AFK_ItemTooltip.new()
	root.add_child(tooltip)
	
	# 测试数据：6 孔大战戟，前 3 孔镶嵌 (Jah, Ber, Cham)，后 3 孔为空孔
	var test_data = {
		"name": "大战戟",
		"quality": "normal",
		"color": "#ffffff",
		"icon": "items/weapon/polearm/war_pike.lowend.png",
		"sockets": 6,
		"inlays": [
			"items/misc/rune/jah_rune.lowend.png",
			"items/misc/rune/ber_rune.lowend.png",
			"items/misc/rune/cham_rune.lowend.png",
			"", "", ""
		],
		"desc": "大战戟\n单手伤害: 15\n耐久度: 100 / 100\n凹槽 (6)",
		"file_id": "/clone/d2/equipment#test_pike"
	}
	
	# 1. 模拟初次显示
	tooltip.show_item(test_data, Vector2(400, 300))
	
	assert(tooltip.visible, "Tooltip 应该可见")
	assert(tooltip.sockets_bar != null, "sockets_bar 应该已初始化")
	assert(tooltip.sockets_bar.visible, "sockets_bar 应该可见")
	assert(tooltip.sockets_bar.get_child_count() == 6, "sockets_bar 应该有 6 个孔位")
	
	print("[TEST] sockets_bar 孔数验证通过: %d 个孔位" % tooltip.sockets_bar.get_child_count())
	
	# 验证前 3 个孔有镶嵌物贴图，后 3 个孔为纯空孔
	for i in range(6):
		var slot = tooltip.sockets_bar.get_child(i) as Control
		assert(slot != null, "槽位节点应存在")
		var textures = []
		for child in slot.get_children():
			if child is TextureRect and child.texture != null:
				textures.append(child)
		if i < 3:
			assert(textures.size() >= 2, "已镶嵌孔应同时有凹槽底图与镶嵌物图标 (孔 %d)" % (i + 1))
			print("[TEST] 第 %d 孔已正确渲染凹槽与镶嵌物图标" % (i + 1))
		else:
			assert(textures.size() == 1, "未镶嵌孔应仅有凹槽底图 (孔 %d)" % (i + 1))
			print("[TEST] 第 %d 孔已正确渲染空凹槽底图" % (i + 1))
			
	# 2. 模拟收到服务端的 panel 帧（测试服务端数据下发后的原地刷新）
	var panel_desc = "<center>" + char(27) + "[img:items/weapon/polearm/war_pike.lowend.png?sock=6&inlays=items/misc/rune/jah_rune.lowend.png,items/misc/rune/ber_rune.lowend.png,items/misc/rune/cham_rune.lowend.png,,,]\n大战戟\n单手伤害: 15\n凹槽 (6)</center>"
	tooltip._on_network_json("panel", { "desc": panel_desc })
	
	assert(not tooltip.content_label.text.contains("【 镶嵌物品"), "卡片文字绝不应再出现旧版纯文本 【 镶嵌物品 】")
	assert(not tooltip.content_label.text.contains("☆☆☆☆"), "卡片文字绝不应再出现旧版纯文本星号字符画")
	assert(tooltip.sockets_bar.get_child_count() == 6, "网络刷新后 sockets_bar 依然为 6 个孔位")
	
	print("[TEST] 网络刷新后文本验证通过：已彻底消除旧版字符画！")
	print("[TEST SUCCESS] 所有测试通过！")
	
	quit(0)
