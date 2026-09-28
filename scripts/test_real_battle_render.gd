extends Node

## 真实战斗系统、0 延迟刷怪/切怪与背包增量刷新自动化全链路验证

@onready var hud: AFK_MainHUD = $AFK_MainHUD

func _ready() -> void:
	print("=== 开始运行真实战斗、0延迟切怪与掉落增量刷新自动化验证 ===")
	await get_tree().process_frame
	
	# 阶段一: 鲜血荒地真实双怪 (沉沦魔 + 勇士饥饿僵尸)
	print("[STEP 1] 注入服务端真实 gstatus 帧: 鲜血荒地 (沉沦魔 + 勇士饥饿僵尸)...")
	var gstatus_bloody_foothills = {
		"stage": {
			"stage_name": "鲜血荒地",
			"kill_step": 128,
			"threshold": 1000,
			"boss_active": 0
		},
		"monsters": [
			{
				"id": "/d/act1/npc/act1_monster#20",
				"name": "💢饥饿僵尸",
				"mon_key": "blood_zombie",
				"rank": "champion",
				"hp": 27,
				"max_hp": 36,
				"level": 3
			},
			{
				"id": "/d/act1/npc/act1_monster#21",
				"name": "沉沦魔",
				"mon_key": "fallen",
				"rank": "normal",
				"hp": 2,
				"max_hp": 2,
				"level": 1
			}
		]
	}
	
	hud._handle_gstatus_data(gstatus_bloody_foothills)
	
	var mon_disp = hud.monster_display
	assert(mon_disp != null, "AFK_MonsterDisplay 必须存在")
	print("  当前聚焦集火目标 key: " + mon_disp.cur_mon_key)
	assert(mon_disp.cur_mon_key == "blood_zombie", "集火优先算法应自动锁定勇士怪饥饿僵尸")
	assert(mon_disp.sprite != null and mon_disp.sprite.texture != null, "怪物必须成功加载高清贴图")
	print("  加载贴图路径: " + mon_disp.sprite.texture.resource_path)
	assert(not ("goblin" in mon_disp.sprite.texture.resource_path.to_lower()), "严禁出现哥布林！")
	
	# 阶段二: 实时战斗打击与飘字
	print("[STEP 2] 触发实时战斗打击流 (combat 帧) 与受击硬直/6系飘字...")
	hud._handle_combat_data({
		"attacker": "autohero99_bar",
		"victim": "/d/act1/npc/act1_monster#20",
		"skill": "重击",
		"dmg": 88,
		"elem": "物理",
		"crit": 1,
		"result": "hit",
		"you_hp": 18,
		"you_max_hp": 36
	})
	
	mon_disp.spawn_damage(42, "火", false, true)
	mon_disp.spawn_damage(26, "冰", false, true)
	mon_disp.set_dot_state(false, true)
	
	await get_tree().create_timer(0.3).timeout
	
	var viewport = get_viewport()
	if viewport:
		var img = viewport.get_texture().get_image()
		if img:
			var shot1 = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_real_monsters_combat.png"
			img.save_png(shot1)
			print("✔ 已成功生成第一张高光战斗截图: " + shot1)
			
	# 阶段二点五: 目标阵亡 -> 0 延迟即刻无缝切怪 + 掉落战利品增量入包！
	print("[STEP 2.5] 怪物倒地身亡 -> 验证 0 延迟无缝切怪与背包增量落格...")
	# 1. 致命斩杀
	hud._handle_combat_data({
		"attacker": "autohero99_bar",
		"victim": "/d/act1/npc/act1_monster#20",
		"skill": "狂乱",
		"dmg": 99,
		"elem": "物理",
		"crit": 1,
		"result": "hit",
		"you_hp": 0,
		"you_max_hp": 36
	})
	# 验证无缝切向沉沦魔
	assert(hud.monster_display.cur_mon_key == "fallen", "怪物阵亡后必须 0 延迟即刻切向同屏下一只存活怪沉沦魔！")
	print("✔ 成功验证 0 延迟切怪: 当前目标已平滑锁定为沉沦魔 (fallen)！")
	
	# 2. 战利品即刻增量入包
	var bag = hud.inventory_panel
	assert(bag != null, "背包面板必须存在")
	var initial_gold = bag.current_player_gold
	
	# 注入掉落包：金币 +6888，暗金项链【艾利屈之眼】
	hud._handle_reward_pop({
		"gold": 6888,
		"exp": 120,
		"item": {
			"id": "amulet_eye",
			"name": "\u001b[f#908858m艾利屈之眼\u001b[0m",
			"raw_name": "艾利屈之眼",
			"icon": "items/misc/amulet/amulet1.lowend.png",
			"quality": "unique",
			"type": "饰品",
			"level": 15,
			"desc": "需求等级: 15\n+1 所有技能\n+3-7 冰冷伤害\n7% 击中偷取生命"
		}
	})
	
	# 验证增量金币与物品
	assert(bag.current_player_gold == initial_gold + 6888, "金币必须即刻增量增加 6888！")
	assert(bag.items_map.has(0), "当前页槽位 0 必须增量落入新装备！")
	var slot0_item = bag.items_map[0]
	assert("艾利屈之眼" in slot0_item.name, "槽位 0 必须为艾利屈之眼！")
	print("✔ 成功验证装备增量入包: 槽位 0 成功获得 " + slot0_item.name + "，金币: " + str(bag.current_player_gold))
	
	# 再次注入可堆叠药水
	hud._handle_reward_pop({
		"gold": 50,
		"exp": 10,
		"item": {
			"id": "hp1",
			"name": "轻微治疗药水",
			"raw_name": "轻微治疗药水",
			"icon": "items/misc/potion/lesser_healing_potion.lowend.png",
			"quality": "normal",
			"amount": 1,
			"type": "药水"
		}
	})
	assert(bag.items_map.has(1), "槽位 1 必须增量填入药水！")
	
	# 再次掉落相同药水 -> 触发自动堆叠
	hud._handle_reward_pop({
		"gold": 20,
		"exp": 5,
		"item": {
			"id": "hp1",
			"name": "轻微治疗药水",
			"raw_name": "轻微治疗药水",
			"icon": "items/misc/potion/lesser_healing_potion.lowend.png",
			"quality": "normal",
			"amount": 1,
			"type": "药水"
		}
	})
	assert(bag.items_map[1].amount == 2, "相同药水必须成功增量堆叠为 2！")
	print("✔ 成功验证药水增量堆叠: 槽位 1 药水数量成功累加为 2！")
	
	await get_tree().create_timer(0.3).timeout
	if viewport:
		var img_drop = viewport.get_texture().get_image()
		if img_drop:
			var shot_drop = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_real_drop_incremental.png"
			img_drop.save_png(shot_drop)
			print("✔ 已成功生成掉落增量刷新实机截图: " + shot_drop)
			
	# 阶段三: 关卡 Boss 战
	print("[STEP 3] 模拟千斩达成，关卡 Boss 安达莉尔降临测试...")
	var gstatus_andariel = {
		"stage": {
			"stage_name": "地下墓穴第四层",
			"kill_step": 1000,
			"threshold": 1000,
			"boss_active": 1
		},
		"monsters": [
			{
				"id": "/d/act1/npc/andariel#1",
				"name": "安达莉尔",
				"mon_key": "andariel",
				"rank": "boss",
				"hp": 9600,
				"max_hp": 12000,
				"level": 12
			}
		]
	}
	
	hud._handle_gstatus_data(gstatus_andariel)
	assert(hud.monster_display.cur_mon_key == "andariel", "必须切换到关卡 Boss 安达莉尔")
	print("  Boss 贴图路径: " + hud.monster_display.sprite.texture.resource_path)
	assert("andariel" in hud.monster_display.sprite.texture.resource_path.to_lower(), "必须加载安达莉尔专属贴图")
	
	hud._handle_combat_data({
		"attacker": "autohero99_bar",
		"victim": "/d/act1/npc/andariel#1",
		"skill": "狂乱",
		"dmg": 520,
		"elem": "毒",
		"crit": 1,
		"result": "hit",
		"you_hp": 9080,
		"you_max_hp": 12000
	})
	hud.monster_display.spawn_damage(180, "毒", false, false)
	hud.monster_display.set_dot_state(true, false)
	
	await get_tree().create_timer(0.3).timeout
	
	if viewport:
		var img2 = viewport.get_texture().get_image()
		if img2:
			var shot2 = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_real_boss_andariel.png"
			img2.save_png(shot2)
			print("✔ 已成功生成第二张 Boss 实战截图: " + shot2)
			
	print("=== 所有自动化实机验证 100% 成功通过！ ===")
	get_tree().quit(0)
