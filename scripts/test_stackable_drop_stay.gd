extends Node

func _ready() -> void:
	print("==================================================")
	print("  开始验证 可叠加物品掉落原地 +1 回归测试  ")
	print("==================================================")

	# 1. 实例化 AFK_MainHUD
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud: AFK_MainHUD = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var inv = hud.inventory_panel
	assert(inv != null, "HUD 必须包含 inventory_panel")

	# ----------------------------------------------------
	# 测试 1: 初始背包设置 (共 3 页，当前在第 1 页，第 0 格有 1 个【碎裂的红宝石】)
	# ----------------------------------------------------
	print("\n[测试 1] 加载初始背包 (第 1 页第 0 格: 碎裂的红宝石 x1)...")
	var mock_gbag = {
		"items": [
			{
				"name": "碎裂的红宝石",
				"raw_name": "碎裂的红宝石",
				"amount": 1,
				"quality": "normal",
				"icon": "items/misc/gem/ruby_chipped.lowend.png",
				"file_id": "/clone/d2/misc/gem#101",
				"page": 1,
				"x": 0, "y": 0,
				"is_gem": 1
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
	hud._on_network_json("gbag", mock_gbag)
	await get_tree().process_frame

	assert(inv.current_page == 1, "当前必须在第 1 页")
	assert(inv.inventory_page_count == 3, "总页数必须为 3")
	assert(inv.items_map.size() == 1, "初始第 1 页只有 1 件物品")
	assert(inv.items_map.has(0), "第 0 格必须为碎裂的红宝石")
	assert(inv.items_map[0]["amount"] == 1, "第 0 格初始数量必须为 1")
	print("  ✅ 1.1 初始背包加载成功: 第 0 格 碎裂的红宝石 x1")

	# ----------------------------------------------------
	# 测试 2: 模拟击杀怪物掉落同名【碎裂的红宝石】
	# 正确协议流：
	# 1) gbag_item_update (file_id: /clone/d2/misc/gem#101, amount: 2) -> 原地涨数
	# 2) reward_pop (item: 碎裂的红宝石, amount: 2) -> 横幅弹窗并增量确认
	# 3) 绝不收到 gbag_item_update amount: 0 清格帧
	# 4) 绝不在最后一页推 gbag_patch
	# ----------------------------------------------------
	print("\n[测试 2] 模拟怪掉落同类物品，验证原地 +1 且不被清空...")
	hud._on_network_json("gbag_item_update", {
		"file_id": "/clone/d2/misc/gem#101",
		"amount": 2
	})
	await get_tree().process_frame

	assert(inv.items_map.has(0), "第 0 格绝不能被清空或删除！")
	assert(inv.items_map[0]["amount"] == 2, "第 0 格红宝石数量必须原地变为 2，实际为: %d" % inv.items_map[0]["amount"])
	print("  ✅ 2.1 收到 gbag_item_update: 第 0 格数量成功原地增加至 2")

	# 紧接着战利品弹窗帧到达
	hud._on_network_json("reward_pop", {
		"monster_name": "沉沦魔巫师",
		"gold": 50,
		"exp": 100,
		"item": {
			"name": "碎裂的红宝石",
			"raw_name": "碎裂的红宝石",
			"amount": 2,
			"quality": "normal",
			"icon": "items/misc/gem/ruby_chipped.lowend.png",
			"file_id": "/clone/d2/misc/gem#101",
			"is_gem": 1
		}
	})
	await get_tree().process_frame

	assert(inv.items_map.size() == 1, "第 1 页依然必须只有 1 个格子，绝不能在空位新生成多余格子！实际格子数: %d" % inv.items_map.size())
	assert(inv.items_map[0]["amount"] == 2, "第 0 格红宝石数量必须稳定保持为 2，防重复累加！实际为: %d" % inv.items_map[0]["amount"])
	assert(not inv.items_map.has(1), "第 1 格必须为空，绝不能在后面生成新物品！")
	print("  ✅ 2.2 收到 reward_pop: 幂等性保障通过，没有在后面新生成格子，数量稳健保持为 2")

	# ----------------------------------------------------
	# 测试 3: 翻到第 3 页 (最后一页)，验证最后一页绝无多余新格子
	# ----------------------------------------------------
	print("\n[测试 3] 验证第 3 页 (最后一页) 状态...")
	# 模拟翻到第 3 页
	hud._on_network_json("gbag", {
		"items": [],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 3,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 50050
	})
	await get_tree().process_frame

	assert(inv.current_page == 3, "当前页已切换至第 3 页")
	assert(inv.items_map.size() == 0, "第 3 页是空页，绝不能有错误残留或新增的宝石格子！实际大小: %d" % inv.items_map.size())
	print("  ✅ 3.1 翻到最后一页 (第 3 页) 检查通过: 最后一页干净无新增虚影！")

	# 翻回第 1 页
	hud._on_network_json("gbag", {
		"items": [
			{
				"name": "碎裂的红宝石",
				"raw_name": "碎裂的红宝石",
				"amount": 2,
				"quality": "normal",
				"icon": "items/misc/gem/ruby_chipped.lowend.png",
				"file_id": "/clone/d2/misc/gem#101",
				"page": 1,
				"x": 0, "y": 0,
				"is_gem": 1
			}
		],
		"charm_used_slots": 0,
		"charm_max_slots": 40,
		"pages": 3,
		"page": 1,
		"unlocked_pages": 3,
		"max_pages": 4,
		"gold": 50050
	})
	await get_tree().process_frame
	assert(inv.current_page == 1, "成功切回第 1 页")
	assert(inv.items_map[0]["amount"] == 2, "切回第 1 页后第 0 格红宝石依然稳健为 2")
	print("  ✅ 3.2 切回第 1 页检查通过: 第 0 格原位置稳健保存！")

	# ----------------------------------------------------
	# 测试 4: 掉落全新未拥有物品 (轻微法力药水) -> 正确在空闲槽位新生成
	# ----------------------------------------------------
	print("\n[测试 4] 掉落全新未拥有物品，验证正常落入空闲槽位...")
	hud._on_network_json("gbag_patch", {
		"page": 1,
		"item": {
			"name": "轻微法力药水",
			"raw_name": "轻微法力药水",
			"amount": 1,
			"quality": "normal",
			"icon": "items/misc/potion/lesser_mana_potion.lowend.png",
			"file_id": "/clone/d2/potion/mp1#202",
			"page": 1,
			"x": 1, "y": 0,
			"is_potion": 1
		}
	})
	await get_tree().process_frame

	assert(inv.items_map.size() == 2, "背包现在应有 2 个物品")
	assert(inv.items_map[0]["amount"] == 2, "第 0 格红宝石不受影响，仍为 2")
	assert(inv.items_map.has(1), "第 1 格成功生成了新掉落的轻微法力药水")
	assert(inv.items_map[1]["name"] == "轻微法力药水", "第 1 格名称为轻微法力药水")
	assert(inv.items_map[1]["amount"] == 1, "第 1 格药水数量为 1")
	print("  ✅ 4.1 全新未拥有物品成功通过 gbag_patch 落入空位 (槽位 1)，第 0 格原物品完好无损！")

	print("\n==================================================")
	print("  🎉 可叠加物品掉落原地 +1 全链路回归测试 100% 通过！  ")
	print("==================================================")
	get_tree().quit()
