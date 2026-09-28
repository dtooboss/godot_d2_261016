extends Node2D

## 自动化全链路验证：多点位怪群同屏、异位随机刷新、致死精准消散与战利品同源

@onready var hud: AFK_MainHUD = $AFK_MainHUD

func _ready() -> void:
	print("=== 开始运行多点位随机刷怪、击杀消散与战利品同源全链路验证 ===")
	await get_tree().process_frame
	
	var bag = hud.inventory_panel
	assert(bag != null, "背包面板必须存在")
	var initial_gold = bag.current_player_gold
	
	# -------------------------------------------------------------
	# 阶段一: 鲜血荒地同时刷出 2 只怪 (勇士饥饿僵尸 + 普通沉沦魔)
	# -------------------------------------------------------------
	print("\n[STEP 1] 注入鲜血荒地多怪快照: 勇士僵尸 (champion) + 沉沦魔 (normal)...")
	var gstatus_2_monsters = {
		"stage": {
			"stage_name": "鲜血荒地",
			"kill_step": 5,
			"threshold": 20,
			"boss_active": 0
		},
		"monsters": [
			{
				"id": "/d/act1/npc/act1_monster#101",
				"name": "💢饥饿僵尸",
				"mon_key": "blood_zombie",
				"rank": "champion",
				"hp": 36,
				"max_hp": 36,
				"level": 3
			},
			{
				"id": "/d/act1/npc/act1_monster#102",
				"name": "沉沦魔",
				"mon_key": "fallen",
				"rank": "normal",
				"hp": 2,
				"max_hp": 2,
				"level": 1
			}
		]
	}
	hud._handle_gstatus_data(gstatus_2_monsters)
	
	# 验证怪群多实例
	assert(hud._monster_instances.size() == 2, "场上必须同时存在 2 只怪物实例！")
	var zombie_node: AFK_MonsterDisplay = hud._monster_instances["/d/act1/npc/act1_monster#101"]
	var fallen_node: AFK_MonsterDisplay = hud._monster_instances["/d/act1/npc/act1_monster#102"]
	assert(zombie_node != null and fallen_node != null, "两只怪物节点均必须有效")
	
	# 验证点位不同 (不能都在正中或重叠)
	assert(zombie_node.slot_index != fallen_node.slot_index, "两只怪物必须分别占据不同的战术槽位！")
	print("✔ 成功分配多点位: 僵尸 Slot=%d (anchor_x=%.2f), 沉沦魔 Slot=%d (anchor_x=%.2f)" % [
		zombie_node.slot_index, zombie_node.anchor_left,
		fallen_node.slot_index, fallen_node.anchor_left
	])
	
	# 验证集火自动锁定勇士怪
	assert(hud._current_target_id == "/d/act1/npc/act1_monster#101", "主集火目标必须锁定勇士僵尸")
	assert(zombie_node.is_focused == true, "主怪必须开启金色目标锁定角标")
	assert(fallen_node.is_focused == false, "副怪不应显示主集火锁定角标")
	print("✔ 成功验证集火角标: 勇士僵尸处于高亮聚焦锁定状态")
	
	await get_tree().create_timer(0.25).timeout
	_take_screenshot("C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_multi_monsters_onscreen.png")
	
	# -------------------------------------------------------------
	# 阶段二: 击杀副怪沉沦魔 -> 验证沉沦魔就地消散，主怪血量不动！
	# -------------------------------------------------------------
	print("\n[STEP 2] 击杀副怪沉沦魔 (伤害 10，致死血量 you_hp = -1 -> 规范为 0)...")
	var killed_slot = fallen_node.slot_index
	hud._handle_combat_data({
		"attacker": "autohero99",
		"victim": "fallen",
		"victim_uuid": "/d/act1/npc/act1_monster#102",
		"skill": "旋风斩",
		"dmg": 10,
		"elem": "物理",
		"crit": 1,
		"result": "hit",
		"you_hp": -1, # 验证即使传负数，也能正确触发死亡
		"you_max_hp": 2
	})
	
	# 验证沉沦魔进入死亡状态，主怪僵尸依然健在
	assert(fallen_node.is_dying == true, "沉沦魔必须正确触发死亡动效！")
	assert(zombie_node.cur_hp == 36, "主怪饥饿僵尸血量必须保持 36 满血，不可受副怪死亡影响！")
	print("✔ 成功验证副怪独立致死消散: 沉沦魔阵亡消散中，主怪僵尸血量 36/36 保持不变")
	
	# -------------------------------------------------------------
	# 阶段三: 战利品明确来源并增量入包
	# -------------------------------------------------------------
	print("\n[STEP 3] 注入战利品帧 (带 monster_name: 沉沦魔)...")
	hud._handle_reward_pop({
		"gold": 666,
		"exp": 50,
		"monster_name": "沉沦魔",
		"monster_id": "/d/act1/npc/act1_monster#102",
		"item": {
			"id": "short_sword",
			"name": "\u001b[34m坚固的短剑\u001b[0m",
			"raw_name": "短剑",
			"icon": "items/weapons/sword/short_sword.lowend.png",
			"quality": "magic",
			"type": "单手剑"
		}
	})
	
	# 验证增量金币与装备入包
	assert(bag.current_player_gold == initial_gold + 666, "金币必须增量增加 666！")
	assert(bag.items_map.has(0), "背包槽位 0 必须增量落入短剑！")
	print("✔ 成功验证带归属战利品: 明确击杀沉沦魔掉落，金币与装备增量入包")
	
	# -------------------------------------------------------------
	# 阶段四: 服务端随死即补 -> 验证新怪避开刚死亡的槽位，随机从另一空闲点位刷出！
	# -------------------------------------------------------------
	print("\n[STEP 4] 补怪: 刷出新怪【硬毛老鼠】-> 验证随机异位刷新...")
	await get_tree().create_timer(0.3).timeout # 等待消散动画完成
	
	var gstatus_respawn = {
		"stage": {
			"stage_name": "鲜血荒地",
			"kill_step": 6,
			"threshold": 20,
			"boss_active": 0
		},
		"monsters": [
			{
				"id": "/d/act1/npc/act1_monster#101",
				"name": "💢饥饿僵尸",
				"mon_key": "blood_zombie",
				"rank": "champion",
				"hp": 36,
				"max_hp": 36,
				"level": 3
			},
			{
				"id": "/d/act1/npc/act1_monster#103",
				"name": "硬毛老鼠",
				"mon_key": "quill_rat",
				"rank": "normal",
				"hp": 4,
				"max_hp": 4,
				"level": 1
			}
		]
	}
	hud._handle_gstatus_data(gstatus_respawn)
	
	var new_rat_node: AFK_MonsterDisplay = hud._monster_instances.get("/d/act1/npc/act1_monster#103", null)
	assert(new_rat_node != null, "新怪硬毛老鼠必须成功生成！")
	print("  新怪硬毛老鼠分配到的 Slot: %d (刚死沉沦魔 Slot: %d)" % [new_rat_node.slot_index, killed_slot])
	assert(new_rat_node.slot_index != killed_slot, "新怪必须避开刚死怪物的槽位，随机在其他位置冒出！")
	print("✔ 成功验证随机异位刷新: 中间的沉沦魔阵亡后，新怪硬毛老鼠在不同战术点位涌出！")
	
	_take_screenshot("C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_drop_and_respawn_other_slot.png")
	
	# -------------------------------------------------------------
	# 阶段五: Boss 召唤降临 -> 独占中军居中王座 (BOSS_SLOT) 与霸气大体型
	# -------------------------------------------------------------
	print("\n[STEP 5] 进度达成，关卡魔王【安达利尔】降临 -> 验证居中特写...")
	var gstatus_boss = {
		"stage": {
			"stage_name": "折磨女王内殿",
			"kill_step": 20,
			"threshold": 20,
			"boss_active": 1
		},
		"monsters": [
			{
				"id": "/d/act1/npc/andariel#999",
				"name": "折磨女王·安达利尔",
				"mon_key": "andariel",
				"rank": "boss",
				"hp": 5000,
				"max_hp": 5000,
				"level": 12
			}
		]
	}
	hud._handle_gstatus_data(gstatus_boss)
	
	var boss_node: AFK_MonsterDisplay = hud._monster_instances.get("/d/act1/npc/andariel#999", null)
	assert(boss_node != null, "关卡魔王安达利尔必须成功生成！")
	assert(boss_node.slot_index == -99, "Boss 必须独占 -99 专属居中王座！")
	assert(boss_node.anchor_left == hud.BOSS_SLOT.x and boss_node.anchor_top == hud.BOSS_SLOT.y, "Boss 必须严格居中对齐！")
	assert(boss_node.base_scale >= 1.3, "Boss 必须具备 >=1.3x 领主体型缩放！")
	print("✔ 成功验证 Boss 居中王座: 安达利尔完美居中于 (%.2f, %.2f)，体型缩放: %.2fx" % [
		boss_node.anchor_left, boss_node.anchor_top, boss_node.base_scale
	])
	
	await get_tree().create_timer(0.25).timeout
	_take_screenshot("C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_boss_center_throne.png")
	
	print("\n=======================================================")
	print(">>> 恭喜！多点位随机刷怪、异位补怪、致死消散与战利品同源全部验证通过！<<<")
	print("=======================================================")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _take_screenshot(path: String) -> void:
	var vp = get_viewport()
	if vp:
		var img = vp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("📸 已保存实机高光截图: " + path)
