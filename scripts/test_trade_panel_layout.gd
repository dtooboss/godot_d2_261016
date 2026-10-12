extends Node2D

func _ready() -> void:
	print("=== 开始 TradePanel 布局、拖放与图标渲染测试 ===")
	var trade_panel_script = preload("res://scripts/ui/trade_panel.gd")
	var panel = trade_panel_script.new()
	add_child(panel)
	
	panel.open_trade("test_partner", "凯恩")
	
	# 1. 验证布局方向：左侧为对方交付区，右侧为我方交付区 (靠近背包)
	assert(panel.lbl_partner_name != null, "对方名字标签应存在")
	assert(panel.lbl_my_name != null, "我方名字标签应存在")
	assert(panel.lbl_partner_name.get_parent().get_child(0) == panel.lbl_partner_name, "左侧第一列应为对方交付区标签")
	assert(panel.lbl_partner_name.get_parent().get_child(2) == panel.lbl_my_name, "右侧第三列应为我方交付区标签")
	
	assert(panel.partner_slots_grid.get_parent().get_parent().get_child(0).get_node("%partner_slots_grid" if false else "PanelContainer").get_child(0) == panel.partner_slots_grid, "左侧应为对方网格")
	print(">>> [验证 1 通过] 交易面板左右布局调换成功：左侧对方交付区，右侧我方交付区！")
	
	# 2. 验证拖拽支持 (Drag & Drop)
	var drag_item = {
		"file_id": "/clone/d2/equipment#999",
		"name": "手斧",
		"icon": "items/weapon/axe/hand_axe.lowend.png",
		"quality": "unique"
	}
	var drag_payload = {
		"source": "main_bag",
		"slot_idx": 0,
		"item_data": drag_item
	}
	
	assert(panel._can_drop_data(Vector2.ZERO, drag_payload) == true, "TradePanel 必须允许接收背包拖拽放入！")
	var my_slot0 = panel.my_slot_buttons[0]
	assert(my_slot0._can_drop_data(Vector2.ZERO, drag_payload) == true, "我方交易槽位必须允许接收背包拖拽放入！")
	print(">>> [验证 2 通过] TradePanel 与 TradeSlotButton 原生拖放接收接口验证通过！")
	
	# 3. 验证图标加载与渲染 (AnsiHelper.load_item_texture)
	var sync_data = {
		"partner_id": "test_partner",
		"partner_name": "凯恩",
		"my_items": [
			{
				"file_id": "/clone/d2/equipment#999",
				"name": "手斧",
				"icon": "items/weapon/axe/hand_axe.lowend.png",
				"quality": "unique"
			},
			{
				"file_id": "/clone/d2/equipment#888",
				"name": "拿各的戒指",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique"
			}
		],
		"partner_items": [
			{
				"file_id": "/clone/d2/equipment#777",
				"name": "蛇皮甲",
				"icon": "items/armor/armor/leather_armor.lowend.png",
				"quality": "rare"
			}
		],
		"my_confirmed": false,
		"partner_confirmed": true
	}
	panel.update_trade_sync(sync_data)
	
	# 检查我方槽位 0 的图标
	var icon0 = my_slot0.get_node_or_null("ItemIcon") as TextureRect
	assert(icon0 != null, "ItemIcon 节点必须存在")
	assert(icon0.texture != null, "ItemIcon.texture 不能为空，物品图标必须正确加载！")
	assert(icon0.visible == true, "ItemIcon 必须可见！")
	print(">>> [验证 3 通过] 物品图标成功加载并渲染至槽位！纹理对象: %s" % str(icon0.texture))
	
	# 检查对方槽位 0 的图标
	var partner_slot0 = panel.partner_slot_buttons[0]
	var p_icon0 = partner_slot0.get_node_or_null("ItemIcon") as TextureRect
	assert(p_icon0 != null and p_icon0.texture != null, "对方槽位 0 图标必须正确加载！")
	print(">>> [验证 4 通过] 对方物品图标同样正常加载！")
	
	# 等待两帧渲染并截屏
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	var screenshot_path = "C:/Users/Administrator/.gemini/antigravity/brain/b5309461-d440-459a-8a46-12eef9df4706/test_trade_panel_barter_layout.png"
	img.save_png(screenshot_path)
	print(">>> [验证 5 通过] 渲染截图已保存至: %s" % screenshot_path)
	
	print("\n===========================================")
	print("🎉 ALL CHECKS PASSED! 交易面板布局与图标修复 100% 成功！")
	print("===========================================")
	get_tree().quit()
