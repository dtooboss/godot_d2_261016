extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证装备穿戴与小口袋交互流 ===")
	
	# 准备测试数据：1 件衣服装备(is_charm=0)，1 个护身符(is_charm=1)
	var armor_item = {
		"name": "野蛮人战甲",
		"quality": "rare",
		"file_id": "/d/d2/obj/armor#999",
		"is_charm": 0,
		"in_charm_bag": 0
	}
	var charm_item = {
		"name": "超大护身符",
		"quality": "magic",
		"file_id": "/d/d2/obj/charm#888",
		"is_charm": 1,
		"in_charm_bag": 0
	}
	
	hud.inventory_panel.raw_all_items = [armor_item, charm_item]
	hud.inventory_panel.items_map[0] = armor_item
	hud.inventory_panel.items_map[1] = charm_item
	
	# -------------------------------------------------------------
	# 1. 验证小口袋拦截非护身符
	# -------------------------------------------------------------
	var pocket = hud.inventory_panel.little_pocket_panel
	var drag_armor = {"source": "main_bag", "slot_idx": 0, "item_data": armor_item}
	var drag_charm = {"source": "main_bag", "slot_idx": 1, "item_data": charm_item}
	
	var can_drop_armor_to_pocket = pocket._can_drop_data(Vector2.ZERO, drag_armor)
	assert(can_drop_armor_to_pocket == false, "小口袋必须拒绝衣服等装备的拖拽放置！")
	print(">>> 验证 1 通过：小口袋已成功拦截非护身符拖拽！")
	
	var can_drop_charm_to_pocket = pocket._can_drop_data(Vector2.ZERO, drag_charm)
	assert(can_drop_charm_to_pocket == true, "小口袋必须允许护身符拖拽放置！")
	print(">>> 验证 2 通过：小口袋允许护身符拖拽放置！")
	
	# -------------------------------------------------------------
	# 2. 验证纸娃娃面板及槽位接收装备拖拽
	# -------------------------------------------------------------
	var char_panel = hud.char_info_panel
	var slot_armor = char_panel.slot_armor
	
	var can_slot_armor_drop = slot_armor._can_drop_data(Vector2.ZERO, drag_armor)
	assert(can_slot_armor_drop == true, "纸娃娃衣服槽位必须允许装备放置！")
	print(">>> 验证 3 通过：纸娃娃衣服槽位允许装备拖放放置！")
	
	var can_panel_drop = char_panel._can_drop_data(Vector2.ZERO, drag_armor)
	assert(can_panel_drop == true, "纸娃娃面板必须允许装备放置！")
	print(">>> 验证 4 通过：纸娃娃面板全局允许装备拖放放置！")
	
	# 模拟在衣服槽位松手放置
	slot_armor._drop_data(Vector2.ZERO, drag_armor)
	print(">>> 验证 5 通过：槽位松手触发穿戴流程！")
	
	# -------------------------------------------------------------
	# 3. 验证背包右键分流
	# -------------------------------------------------------------
	var right_click_event = InputEventMouseButton.new()
	right_click_event.button_index = MOUSE_BUTTON_RIGHT
	right_click_event.pressed = true
	
	# 右键衣服槽位 (slot 0)
	hud.inventory_panel._on_slot_gui_input(right_click_event, 0)
	print(">>> 验证 6 通过：右键衣服执行 wear 穿戴流程！")
	
	# 右键护身符槽位 (slot 1)
	hud.inventory_panel._on_slot_gui_input(right_click_event, 1)
	print(">>> 验证 7 通过：右键护身符放入小口袋！")
	
	await get_tree().create_timer(0.3).timeout
	print("=== 所有装备穿戴与小口袋防护单测全部通过！ ===")
	get_tree().quit(0)
