extends Node2D

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	print("=== 开始运行怪物血条隔离与 UUID 精准对齐自动化验证 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	
	# -------------------------------------------------------------------------
	# [CASE 1] 注入 Boss (8000 HP) 与旁边的小怪 (35 HP) 同屏数据
	# -------------------------------------------------------------------------
	print("\n[STEP 1] 注入 Boss (8000血) 与旁边的小怪 (35血) 同屏快照...")
	var boss_mid = "/d/act1/npc/act1_monster#888"
	var mob_mid = "/d/act1/npc/act1_monster#999"
	
	hud._handle_gstatus_data({
		"stage": { "stage_id": 14, "stage_name": "地下墓穴第四层", "boss_active": 1 },
		"monsters": [
			{
				"id": boss_mid,
				"mon_key": "andariel",
				"code": "andariel",
				"name": "👑 安达莉尔",
				"rank": "boss",
				"hp": 8000,
				"max_hp": 8000,
				"level": 12
			},
			{
				"id": mob_mid,
				"mon_key": "blood_zombie",
				"code": "zombie1",
				"name": "饥饿僵尸",
				"rank": "normal",
				"hp": 35,
				"max_hp": 35,
				"level": 3
			}
		]
	})
	
	var boss_node = hud._monster_instances.get(boss_mid, null)
	var mob_node = hud._monster_instances.get(mob_mid, null)
	assert(boss_node != null, "Boss 节点必须成功创建")
	assert(mob_node != null, "小怪节点必须成功创建")
	
	print("[POS_DEBUG] LeftViewport size: ", hud.get_node("MainHBox/LeftViewport").size)
	print("[POS_DEBUG] Boss slot: ", boss_node.slot_index, " pos: ", boss_node.position, " global_pos: ", boss_node.global_position, " visible: ", boss_node.visible, " size: ", boss_node.size)
	print("[POS_DEBUG] Mob slot: ", mob_node.slot_index, " pos: ", mob_node.position, " global_pos: ", mob_node.global_position, " visible: ", mob_node.visible, " size: ", mob_node.size)
	if boss_node.sprite:
		print("[POS_DEBUG] Boss sprite texture: ", boss_node.sprite.texture, " pos: ", boss_node.sprite.position, " scale: ", boss_node.sprite.scale)
	if mob_node.sprite:
		print("[POS_DEBUG] Mob sprite texture: ", mob_node.sprite.texture, " pos: ", mob_node.sprite.position, " scale: ", mob_node.sprite.scale)
	
	# -------------------------------------------------------------------------
	# [CASE 2] 故意将玩家目标选中小怪，服务端下发 Boss 的 charhp 实时血条帧
	# -------------------------------------------------------------------------
	print("\n[STEP 2] 验证 charhp 帧按 file_name 定向更新，绝不污染当前选中的小怪...")
	# 设玩家当前集火目标为小怪
	hud._current_target_id = mob_mid
	
	# 下发 Boss 的 charhp (附带 Boss 的 file_name)
	hud._on_network_json("charhp", {
		"name": "look " + boss_mid,
		"hp": "7600:8000"
	})
	
	# 验证：Boss 扣血至 7600/8000，小怪必须坚守 35/35！
	print("  -> charhp 触发后: Boss 当前血量=%d/%d, 小怪当前血量=%d/%d" % [
		boss_node.cur_hp, boss_node.max_hp, mob_node.cur_hp, mob_node.max_hp
	])
	assert(boss_node.cur_hp == 7600 and boss_node.max_hp == 8000, "Boss 节点血量必须成功更新为 7600/8000")
	assert(mob_node.cur_hp == 35 and mob_node.max_hp == 35, "❌ 严重Bug复发！小怪血条被 Boss 的 charhp 篡改了！")
	print("✔ 成功断言: 即使当前焦点在小怪，Boss 的 charhp 也绝不会污染小怪血条！")
	
	# -------------------------------------------------------------------------
	# [CASE 3] 下发 Boss combat 攻击打击帧 (附带 victim_uuid)
	# -------------------------------------------------------------------------
	print("\n[STEP 3] 验证 combat 打击帧按 UUID 精准扣血，小怪不受影响...")
	hud._handle_combat_data({
		"attacker": "xdao_sor",
		"attacker_uuid": "/clone/user/user#1",
		"victim": "andariel",
		"victim_uuid": boss_mid,
		"dmg": 500,
		"elem": "火焰",
		"crit": 0,
		"you_hp": 7100,
		"you_max_hp": 8000
	})
	
	print("  -> combat 触发后: Boss 当前血量=%d/%d, 小怪当前血量=%d/%d" % [
		boss_node.cur_hp, boss_node.max_hp, mob_node.cur_hp, mob_node.max_hp
	])
	assert(boss_node.cur_hp == 7100 and boss_node.max_hp == 8000, "Boss 血量应为 7100/8000")
	assert(mob_node.cur_hp == 35 and mob_node.max_hp == 35, "❌ 严重Bug复发！小怪血条被 Boss 的 combat 帧篡改了！")
	print("✔ 成功断言: combat 帧精准命中 Boss，小怪血量分毫未动！")
	
	# -------------------------------------------------------------------------
	# [CASE 4] 极端严苛测试：Boss 与小怪同名 (同底材 dark_brute)
	# -------------------------------------------------------------------------
	print("\n[STEP 4] 验证极端同名同键怪场景 (S7 地底通道 Boss 和小怪均叫巨身蛮兽)...")
	var same_boss_mid = "/d/act1/npc/act1_monster#111"
	var same_mob_mid = "/d/act1/npc/act1_monster#222"
	
	hud._handle_gstatus_data({
		"stage": { "stage_id": 7, "stage_name": "地底通道", "boss_active": 1 },
		"monsters": [
			{
				"id": same_boss_mid,
				"mon_key": "dark_brute",
				"code": "brute1",
				"name": "👑 巨身蛮兽",
				"rank": "boss",
				"hp": 475,
				"max_hp": 475,
				"level": 7
			},
			{
				"id": same_mob_mid,
				"mon_key": "dark_brute",
				"code": "brute1",
				"name": "巨身蛮兽",
				"rank": "normal",
				"hp": 95,
				"max_hp": 95,
				"level": 4
			}
		]
	})
	
	var s_boss = hud._monster_instances.get(same_boss_mid, null)
	var s_mob = hud._monster_instances.get(same_mob_mid, null)
	assert(s_boss != null and s_mob != null, "同名双怪均应存在")
	
	# 下发击中同名 Boss 的 combat 帧
	hud._handle_combat_data({
		"attacker": "xdao_sor",
		"attacker_uuid": "/clone/user/user#1",
		"victim": "dark_brute",
		"victim_uuid": same_boss_mid,
		"dmg": 75,
		"elem": "物理",
		"crit": 0,
		"you_hp": 400,
		"you_max_hp": 475
	})
	
	print("  -> 同名怪打击后: Boss 当前血量=%d/%d, 小怪当前血量=%d/%d" % [
		s_boss.cur_hp, s_boss.max_hp, s_mob.cur_hp, s_mob.max_hp
	])
	assert(s_boss.cur_hp == 400 and s_boss.max_hp == 475, "同名 Boss 成功更新为 400/475")
	assert(s_mob.cur_hp == 95 and s_mob.max_hp == 95, "❌ 严重Bug复发！同名小怪血条被同名 Boss 篡改了！")
	print("✔ 成功断言: 同名怪通过 UUID 精准隔离，绝不产生同名串写！")
	
	print("\n🎉 === 所有血条隔离与防篡改自动化测试 100% 成功通过！ ===")
	get_tree().quit(0)
