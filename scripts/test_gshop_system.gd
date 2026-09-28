extends SceneTree

const AFK_GShopPanel = preload("res://scenes/afk/components/gshop_panel.gd")

func _init() -> void:
	print("[TEST] ====== 开始随身商店 (GShopSystem) 自动化测试 ======")

	# 1. 实例化 AFK_GShopPanel
	var shop = AFK_GShopPanel.new()
	var root = Control.new()
	root.size = Vector2(1024, 768)
	root.add_child(shop)
	shop._ready()

	# 验证初始状态与格子数
	assert(shop.slots.size() == 28, "随身商店必须拥有 28 个格子 (4x7)！")
	assert(shop.visible == false, "随身商店初始应为隐藏！")
	print("[TEST] [PASS] 4x7 (共28格) 槽位初始化成功！")

	# 2. 模拟普通难度 gshop 数据下发
	var mock_normal_data = {
		"difficulty": "normal",
		"gold": 5000,
		"cols": 4,
		"rows": 7,
		"total_slots": 28,
		"items": [
			{
				"code": "hp2", "name": "次级治疗药水", "price": 25, "unit": "瓶", "type": "hp",
				"icon": "items/misc/potion/light_healing_potion.lowend.png", "desc": "恢复100生命", "stack": 1
			},
			{
				"code": "mp2", "name": "次级法力药水", "price": 25, "unit": "瓶", "type": "mp",
				"icon": "items/misc/potion/light_mana_potion.lowend.png", "desc": "恢复60法力", "stack": 1
			},
			{
				"code": "aqv", "name": "箭筒", "price": 10, "unit": "筒", "type": "ammo",
				"icon": "items/misc/quiver/arrows.lowend.png", "desc": "箭筒", "stack": 0
			},
			{
				"code": "cqv", "name": "十字弓弹", "price": 15, "unit": "袋", "type": "ammo",
				"icon": "items/misc/quiver/bolts.lowend.png", "desc": "十字弓弹", "stack": 0
			}
		]
	}
	shop.update_shop_data(mock_normal_data)
	assert(shop.current_diff == "normal", "难度应为 normal")
	assert(shop.current_gold == 5000, "金币应为 5000")
	assert(shop.slot_item_map.size() == 4, "应有 4 个商品放入槽位")
	assert(shop.slots[0].get_node("PriceBadge").text == "25G", "第 1 格价格角标应为 25G")
	assert(shop.slots[2].get_node("PriceBadge").text == "10G", "第 3 格价格角标应为 10G")
	assert(shop.slots[4].icon == null, "第 5 格应为空槽")
	print("[TEST] [PASS] 普通难度商品数据渲染与单价角标映射成功！")

	# 3. 悬停提示信号测试
	var hovered_item = {}
	shop.item_hovered.connect(func(data, _pos): hovered_item.merge(data))
	shop._on_slot_hovered(0, shop.slots[0])
	assert(hovered_item.get("name") == "次级治疗药水", "悬停提示商品名匹配")
	assert("25 金币" in hovered_item.get("desc", ""), "悬停提示描述应包含单价 25 金币")
	print("[TEST] [PASS] 商品鼠标悬停与 Tooltip 数据格式化成功！")

	# 4. 右键极速购买测试 (药水秒买 50 瓶，箭矢秒买 1 筒)
	var buy_log = []
	shop.buy_requested.connect(func(code, amt): buy_log.append({"code": code, "amount": amt}))

	# 触发右键药水 (slot 0: hp2)
	var r_click_event = InputEventMouseButton.new()
	r_click_event.button_index = MOUSE_BUTTON_RIGHT
	r_click_event.pressed = true
	shop._on_slot_gui_input(r_click_event, 0)
	assert(buy_log.size() == 1 and buy_log[0]["code"] == "hp2" and buy_log[0]["amount"] == 50, "右键药水应秒买 50 瓶！")

	# 触发右键箭矢 (slot 2: aqv)
	shop._on_slot_gui_input(r_click_event, 2)
	assert(buy_log.size() == 2 and buy_log[1]["code"] == "aqv" and buy_log[1]["amount"] == 1, "右键箭矢应秒买 1 筒！")
	print("[TEST] [PASS] 右键 50 一堆药水秒买与箭矢单筒秒买测试成功！")

	# 5. 左键自选数量弹窗测试
	var l_click_event = InputEventMouseButton.new()
	l_click_event.button_index = MOUSE_BUTTON_LEFT
	l_click_event.pressed = true
	shop._on_slot_gui_input(l_click_event, 1) # 点击 mp2
	assert(shop._qty_modal.visible == true, "左键点击应展开数量自选弹窗！")
	assert(shop._current_modal_qty == 50, "药水自选弹窗初始默认数量应为 50！")

	# 步进调节与快捷按钮
	shop._set_modal_qty(10)
	assert(shop._current_modal_qty == 10, "设置数量为 10 成功")
	assert("250 G" in shop._qty_total_price.text, "10 瓶次级法力药水总价应为 250 G")

	# 测试最大按钮 (5000 金币 / 25 金 = 200 瓶)
	shop._on_quick_max_pressed()
	assert(shop._current_modal_qty == 200, "根据 5000 金币计算最大应为 200 瓶！")

	# 确认购买
	shop._on_confirm_buy_pressed()
	assert(buy_log.size() == 3 and buy_log[2]["code"] == "mp2" and buy_log[2]["amount"] == 200, "确认购买应发送自选 200 瓶！")
	assert(shop._qty_modal.visible == false, "购买后弹窗自动关闭")
	print("[TEST] [PASS] 自选数量弹窗、步进调节、最大换算与确认购买测试成功！")

	# 6. 金币不足校验测试
	shop.update_gold(20) # 仅剩 20 金币
	shop._open_qty_modal(mock_normal_data["items"][0]) # 打开 25 金币的 hp2
	shop._set_modal_qty(1) # 买 1 瓶需 25，不足
	assert(shop._btn_confirm_buy.disabled == true, "金币不足时确认购买按钮应被禁用！")
	assert("金币不足" in shop._qty_total_price.text, "总价文本应显示金币不足提示！")
	print("[TEST] [PASS] 金币不足防护与按钮置灰测试成功！")

	# 7. 地狱难度动态进阶测试
	var mock_hell_data = {
		"difficulty": "hell",
		"gold": 999999,
		"items": [
			{ "code": "hp5", "name": "超级治疗药水", "price": 200, "unit": "瓶", "type": "hp", "icon": "items/misc/potion/full_healing_potion.lowend.png" },
			{ "code": "mp5", "name": "超级法力药水", "price": 200, "unit": "瓶", "type": "mp", "icon": "items/misc/potion/full_mana_potion.lowend.png" },
			{ "code": "aqv", "name": "箭筒", "price": 10, "unit": "筒", "type": "ammo", "icon": "items/misc/quiver/arrows.lowend.png" },
			{ "code": "cqv", "name": "十字弓弹", "price": 15, "unit": "袋", "type": "ammo", "icon": "items/misc/quiver/bolts.lowend.png" }
		]
	}
	shop.update_shop_data(mock_hell_data)
	assert(shop.current_diff == "hell", "当前难度应为 hell")
	assert(shop.slot_item_map[0]["code"] == "hp5", "地狱难度第 1 格应为超级治疗药水 hp5")
	assert(shop.slot_item_map[1]["code"] == "mp5", "地狱难度第 2 格应为超级法力药水 mp5")
	assert(shop.slots[0].get_node("PriceBadge").text == "200G", "超级药水角标应为 200G")
	print("[TEST] [PASS] 地狱难度超级药水进阶与金币显示测试成功！")

	print("[TEST] ====== 随身商店 (GShopSystem) 全部测试用例通过！======")
	quit(0)
