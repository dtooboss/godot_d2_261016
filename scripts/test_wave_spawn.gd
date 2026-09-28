extends Control

func _ready() -> void:
	print("==================================================")
	print("   START WAVE SPAWN & ANTI-OVERLAP UNIT TEST      ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)

	await get_tree().process_frame

	# Test 1: 验证 10 席独立槽位池
	assert(hud.SLOT_POSITIONS.size() == 10, "SLOT_POSITIONS 必须扩充至 10 个独立席位！")
	print("✔ Test 1: 10 independent slot positions verified!")

	# Test 2: 模拟地狱难度单波 7 只怪同屏注入
	var mock_monsters_7: Array = []
	for i in range(7):
		mock_monsters_7.append({
			"id": "hell_mon_%d" % i,
			"name": "地狱恶魔_%d" % i,
			"rank": "normal",
			"hp": 500,
			"max_hp": 500,
			"level": 85,
			"mon_key": "fallen"
		})

	var mock_data_wave1 = {
		"monsters": mock_monsters_7,
		"stage": {
			"stage_name": "地狱·鲜血荒地",
			"kill_step": 10,
			"threshold": 100,
			"boss_active": 0
		}
	}

	hud._handle_gstatus_data(mock_data_wave1)
	await get_tree().process_frame

	# 验证 7 只怪各占 1 个独立槽位，零重叠
	var allocated_slots: Array = []
	for mid in hud._monster_instances.keys():
		var node = hud._monster_instances[mid]
		assert(node != null, "怪物节点必须实例化成功！")
		assert(node.slot_index >= 0 and node.slot_index < 10, "槽位必须位于 [0, 9] 之间！")
		assert(not (node.slot_index in allocated_slots), "槽位索引 %d 发生冲突重叠！" % node.slot_index)
		allocated_slots.append(node.slot_index)

	assert(allocated_slots.size() == 7, "7 只怪物必须占用 7 个不同槽位！")
	assert(hud._occupied_slots.size() == 7, "occupied_slots 字典必须精确记录 7 个占用！")
	print("✔ Test 2: 7 monsters in Hell difficulty allocated 7 unique slots with 0 overlap!")

	# Test 3: 景深 Z-Index 验证
	for mid in hud._monster_instances.keys():
		var node = hud._monster_instances[mid]
		var expected_z = int(hud.SLOT_POSITIONS[node.slot_index].y * 100.0)
		assert(node.z_index == expected_z, "怪物 z_index 必须严格对齐景深数值！")
	print("✔ Test 3: Dynamic Z-Index depth sorting verified for all 7 monsters!")

	# Test 4: 死亡生命周期防叠与槽位延迟归还
	var victim_id = "hell_mon_0"
	var victim_node = hud._monster_instances[victim_id]
	var victim_slot = victim_node.slot_index

	# 模拟收到致命伤害帧
	var mock_death_data = {
		"attacker": "player_hero",
		"victim": victim_id,
		"victim_name": "地狱恶魔_0",
		"you_hp": 0,
		"you_max_hp": 500,
		"elem": "物理",
		"damage": 500
	}
	hud._handle_combat_data(mock_death_data)

	# 验证：正在播放死亡渐隐动效期间，槽位依然受锁定保护
	assert(hud._occupied_slots.has(victim_slot), "死亡渐隐动效期间，槽位必须保持锁定，防新怪抢座！")

	# 等待弹道飞抵 (约 0.12s) 与死亡动画（0.25s）播放完毕
	await get_tree().create_timer(0.55).timeout

	# 动效播放完毕后，槽位被安全释放归还
	assert(not hud._occupied_slots.has(victim_slot), "死亡动效播放完毕后，槽位必须被安全释放归还槽位池！")
	print("✔ Test 4: True death slot release lifecycle verified!")

	# Test 5: Boss 独占与中轴避让验证
	var boss_slot = hud._allocate_slot_for_monster("boss")
	assert(boss_slot == -99, "Boss 必须独占 -99 居中王座！")
	hud._occupied_slots[-99] = "boss_mon_1"

	# 当 Boss 在场时，连续分配小怪槽位，验证小怪自动避让正前中锋 Slot 2
	for k in range(5):
		var test_s = hud._allocate_slot_for_monster("normal")
		assert(test_s != 2 and test_s != -99, "Boss 在场时小怪必须避让中轴点位！")
	print("✔ Test 5: Boss exclusive throne and central corridor avoidance verified!")

	print("==================================================")
	print("    ALL WAVE SPAWN & ANTI-OVERLAP TESTS PASSED!   ")
	print("==================================================")
	get_tree().quit(0)
