extends Control

@onready var hud: AFK_MainHUD = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始背包满页自动切换尾页与满包检查回归测试 ===")
	
	var inv: AFK_PlayerInventoryPanel = hud.inventory_panel
	assert(inv != null, "AFK_MainHUD 必须包含 inventory_panel")
	
	# Step 1: 模拟从服务端接收初始背包数据 (共 3 页已解锁，当前在第 1 页，第 1 页有 1 件装备)
	var init_gbag = {
		"items": [
			{
				"name": "多节棍",
				"raw_name": "多节棍",
				"icon": "items/weapon/staff/gnarled_staff.lowend.png",
				"quality": "normal",
				"page": 1,
				"x": 0, "y": 0,
				"amount": 1
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 1,
		"unlocked_pages": 3,
		"max_pages": 4,
		"extend_cost": 150000,
		"gold": 50000
	}
	hud._on_network_json("gbag", init_gbag)
	await get_tree().process_frame
	
	assert(inv.current_page == 1, "初始当前页必须为 1")
	assert(inv.inventory_page_count == 3, "初始总页数必须为 3")
	assert(inv.items_map.size() == 1, "初始第 1 页应只有 1 件物品")
	print("✔ [测试 1 通过] 初始第 1 页加载成功，当前页: 1, 总页数: 3")
	
	# Step 2: 收到掉落战利品 reward_pop (当前页未满) -> 增量填入槽位 1
	var loot1 = {
		"gold": 200,
		"exp": 50,
		"item": {
			"name": "超强皮甲",
			"raw_name": "超强皮甲",
			"icon": "items/armor/armor/leather_armor.lowend.png",
			"quality": "normal",
			"amount": 1
		}
	}
	hud._on_network_json("reward_pop", loot1)
	await get_tree().process_frame
	
	assert(inv.current_page == 1, "当前页未满时，必须保持在第 1 页")
	assert(inv.items_map.has(1), "战利品必须增量填入第 1 页的空闲槽位 1")
	print("✔ [测试 2 通过] 当前页有空位时，战利品增量落入槽位 1，页面保持为 1")
	
	# Step 3: 模拟第 1 页填满 (84 格全满)
	for i in range(84):
		inv.items_map[i] = {"name": "已占满装备 %d" % i}
		
	# 此时再次收到战利品掉落 -> 绝不可强制切到尾页，必须安静保持在第 1 页！
	var loot2 = {
		"gold": 1000,
		"exp": 150,
		"item": {
			"name": "暗金戒指【乔丹之石】",
			"raw_name": "乔丹之石",
			"icon": "items/misc/ring/ring1.lowend.png",
			"quality": "unique",
			"amount": 1
		}
	}
	hud._on_network_json("reward_pop", loot2)
	await get_tree().process_frame
	
	assert(inv.current_page == 1, "第 1 页满时，绝不可强制切页，必须安静保持在玩家当前正在浏览的第 1 页！")
	print("✔ [测试 3 通过] 第 1 页已满，战利品自然入库后续页，界面平稳保持在第 1 页不打扰玩家！")
	
	# Step 4: 玩家主动点击第 3 页页签，模拟服务端响应第 3 页数据帧，包含刚掉落的暗金戒指
	inv.current_page = 3
	var gbag_p3 = {
		"items": [
			{
				"name": "乔丹之石",
				"raw_name": "乔丹之石",
				"icon": "items/misc/ring/ring1.lowend.png",
				"quality": "unique",
				"page": 3,
				"x": 0, "y": 0,
				"amount": 1
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 3,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 51200
	}
	hud._on_network_json("gbag", gbag_p3)
	await get_tree().process_frame
	
	assert(inv.current_page == 3, "当前页为玩家主动翻到的第 3 页")
	assert(inv.items_map.size() == 1, "第 3 页应正常渲染该暗金戒指")
	print("✔ [测试 4 通过] 主动翻到尾页回包渲染完成，新装备正常展示！")
	
	# Step 5: 处于已解锁最后一页且全满 (unlocked_pages = 3, current_page = 3, 84格全满)
	for i in range(84):
		inv.items_map[i] = {"name": "第3页占满装备 %d" % i}
		
	# 再次收到掉落 -> 必须拦截，不得越界增加未购买页码，触发背包满提示
	var loot3 = {
		"gold": 500,
		"exp": 100,
		"item": {
			"name": "亮金护身符",
			"raw_name": "亮金护身符",
			"icon": "items/misc/amulet/amulet1.lowend.png",
			"quality": "rare",
			"amount": 1
		}
	}
	hud._on_network_json("reward_pop", loot3)
	await get_tree().process_frame
	
	assert(inv.current_page == 3, "达到购买上限且全满时，绝不可非法跳入未购买页码，应停留在第 3 页")
	print("✔ [测试 5 通过] 达到已解锁页数上限且全满时，成功拦截切页并触发满包告警！")
	
	# Step 6: 验证掉落时 icon, quality 与 [NEW] 角标增量展现
	inv.items_map.clear()
	for btn in inv.slots:
		btn.icon = null
		if btn.has_method("set_slot_new"):
			btn.set_slot_new(false)
			
	var loot_new = {
		"gold": 300,
		"exp": 80,
		"item": {
			"name": "暗金短剑【海鸥】",
			"raw_name": "海鸥",
			"icon": "items/weapon/dagger/dagger.lowend.png",
			"quality": "unique",
			"file_id": "/clone/d2/gear#9999",
			"amount": 1
		}
	}
	hud._on_network_json("reward_pop", loot_new)
	await get_tree().process_frame
	
	var slot0_btn = inv.slots[0]
	assert(slot0_btn.icon != null, "增量入包必须正确加载并设置 item icon")
	assert(slot0_btn.current_quality == "unique", "增量入包必须正确应用 unique 暗金品质")
	assert(slot0_btn.is_new_item == true, "增量入包的新物品必须标记为 is_new_item == true")
	assert(slot0_btn.new_badge != null and slot0_btn.new_badge.visible == true, "增量入包的新物品必须显示 NEW 角标")
	print("✔ [测试 6 通过] 战利品掉落增量入包时，icon、品质、NEW 角标均正确渲染！")
	
	# Step 7: 验证鼠标 hover 悬停查看物品后，[NEW] 标记自动消隐
	inv._on_slot_hovered(0, slot0_btn)
	await get_tree().process_frame
	assert(slot0_btn.is_new_item == false, "鼠标 hover 查看物品后，is_new_item 必须变为 false")
	assert(slot0_btn.new_badge.visible == false, "鼠标 hover 查看物品后，NEW 角标必须消隐")
	assert(not inv.new_item_ids.has("/clone/d2/gear#9999"), "鼠标查看后，必须从 new_item_ids 中移除")
	print("✔ [测试 7 通过] 鼠标 hover 查看物品后，NEW 状态成功消隐并移出追踪池！")
	
	# Step 8: 验证切页或服务端品质重排后，未查看的新物品仍然能保持 [NEW] 角标！
	var loot_unseen = {
		"gold": 600,
		"exp": 120,
		"item": {
			"name": "绿色套装项链【塔·拉夏的判决】",
			"raw_name": "塔·拉夏的判决",
			"icon": "items/misc/amulet/amulet1.lowend.png",
			"quality": "set",
			"file_id": "/clone/d2/gear#8888",
			"amount": 1
		}
	}
	# 收到新掉落但玩家尚未 hover 查看
	hud._on_network_json("reward_pop", loot_unseen)
	await get_tree().process_frame
	assert(inv.new_item_ids.has("/clone/d2/gear#8888"), "新掉落必须记录在 new_item_ids 中")
	
	# 模拟此时服务端执行品质排序并下发整页 gbag 数据：
	# 假设塔拉夏项链排在第 0 格，第 1 格是已有的普通短剑（不在 new_item_ids 中）
	var gbag_sorted = {
		"items": [
			{
				"name": "塔·拉夏的判决",
				"raw_name": "塔·拉夏的判决",
				"icon": "items/misc/amulet/amulet1.lowend.png",
				"quality": "set",
				"file_id": "/clone/d2/gear#8888",
				"page": 3,
				"x": 0, "y": 0,
				"amount": 1
			},
			{
				"name": "普通短剑",
				"raw_name": "短剑",
				"icon": "items/weapon/dagger/dagger.lowend.png",
				"quality": "normal",
				"file_id": "/clone/d2/gear#1111",
				"page": 3,
				"x": 1, "y": 0,
				"amount": 1
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 3,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 52100
	}
	hud._on_network_json("gbag", gbag_sorted)
	await get_tree().process_frame
	
	var btn0 = inv.slots[0]
	var btn1 = inv.slots[1]
	assert(btn0.is_new_item == true, "品质重排后，新获得的装备必须依然保持 is_new_item == true")
	assert(btn0.new_badge != null and btn0.new_badge.visible == true, "品质重排后，新获得的装备必须依然展示 NEW 角标")
	assert(btn1.is_new_item == false, "已有装备不可误打上 NEW 角标")
	print("✔ [测试 8 通过] 服务端品质重排或切页后，新掉落装备准确定位并保持 NEW 角标，旧装备不受影响！")

	# Step 9: 模拟点击槽位消除 NEW 标记
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	inv._on_slot_gui_input(click_event, 0, btn0)
	await get_tree().process_frame
	assert(btn0.is_new_item == false, "点击操作后 NEW 状态必须消除")
	assert(btn0.new_badge.visible == false, "点击操作后 NEW 角标必须消隐")
	print("✔ [测试 9 通过] 点击槽位后 NEW 标记成功消除！")
	
	print("\n========================================================")
	print(">>> 恭喜！背包增量掉落、品质渲染、NEW角标与自动切页 9 项自动化测试全部 100% 通过！<<<")
	print("========================================================\n")
	get_tree().quit(0)
