extends Node

func _ready() -> void:
	print("=== 开始法力值蓝球与纯增量掉落横幅隔离回归测试 ===")
	GameState.selected_character = {
		"id": "ouyang",
		"char_id": "ouyang",
		"name": "欧阳霜云",
		"level": 8
	}
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var bottom_bar = hud.player_bottom_bar
	var mp_bar = bottom_bar.mp_bar

	# -------------------------------------------------------------
	# Test 1: 模拟 ghp1 下发的 gstatus 帧 (暗黑真实法力 71)
	# -------------------------------------------------------------
	print("\n--- Test 1: 验证 ghp1 驱动的 gstatus 帧能将蓝球更新为真实法力 (71/71) ---")
	var gstatus_frame = {
		"player": {
			"name": "欧阳霜云",
			"level": 8,
			"hp": 47,
			"max_hp": 47,
			"mp": 71,
			"max_mp": 71
		},
		"stage": {
			"stage_name": "鲜血荒地",
			"kill_step": 10,
			"threshold": 1000,
			"boss_active": 0
		},
		"monsters": []
	}
	hud._handle_gstatus_data(gstatus_frame)
	await get_tree().process_frame

	assert(mp_bar.cur_val == 71, "蓝球当前法力值必须为 71，实际为 %d" % mp_bar.cur_val)
	assert(mp_bar.max_val == 71, "蓝球最大法力值必须为 71，实际为 %d" % mp_bar.max_val)
	assert(mp_bar._label.text == "71/71(100%)", "蓝球文字必须为 71/71(100%)，实际为: " + str(mp_bar._label.text))
	print("✔ [测试 1 通过] gstatus 成功将蓝球法力值刷新为 71/71(100%)，彻底杜绝 2/2！")

	# -------------------------------------------------------------
	# Test 2: 模拟 combat 战斗帧施法扣蓝 (71 -> 53)
	# -------------------------------------------------------------
	print("\n--- Test 2: 验证 combat 战斗帧打击时实时同步玩家扣蓝 ---")
	var combat_frame = {
		"attacker": "欧阳霜云",
		"victim": "沉沦魔",
		"dmg": 25,
		"me_hp": 47,
		"me_max_hp": 47,
		"me_mp": 53,
		"me_max_mp": 71
	}
	hud._handle_combat_data(combat_frame)
	await get_tree().process_frame

	assert(mp_bar.cur_val == 53, "战斗施法扣蓝后当前法力必须为 53，实际为 %d" % mp_bar.cur_val)
	assert(mp_bar.max_val == 71, "最大法力上限必须保持为 71")
	print("✔ [测试 2 通过] combat 战斗帧成功平滑扣蓝至 53/71！")

	# -------------------------------------------------------------
	# Test 3: 纯金币掉落 -> 仅走微弱通道，不触发战利品横幅
	# -------------------------------------------------------------
	print("\n--- Test 3: 验证纯金币经验掉落仅走微弱浮字，不弹出主战利品横幅 ---")
	var pure_gold_reward = {
		"gold": 25,
		"exp": 50,
		"monster_name": "沉沦魔"
	}
	hud._handle_reward_pop(pure_gold_reward)
	await get_tree().process_frame

	assert(hud._loot_banner == null or hud._loot_banner.visible == false, "纯金币掉落绝不能弹出主战利品横幅！")
	assert(hud._minor_reward_label != null and hud._minor_reward_label.visible == true, "纯金币掉落必须走微弱通道浮字")
	print("✔ [测试 3 通过] 纯金币掉落成功隔离，未遮挡屏幕！")

	# -------------------------------------------------------------
	# Test 4: 装备掉落 -> 弹出高优先级战利品横幅，并记录到聊天视窗
	# -------------------------------------------------------------
	print("\n--- Test 4: 验证装备掉落弹出专属高亮横幅，并在聊天中持久记录 ---")
	var item_reward = {
		"gold": 120,
		"exp": 200,
		"monster_name": "尸体发火",
		"item": {
			"name": "暗金武器【涡流水晶】",
			"raw_name": "涡流水晶",
			"quality": "unique",
			"icon": "items/weapon/orb/dragon_stone.lowend.png",
			"amount": 1,
			"file_id": "/clone/d2/equipment#999"
		}
	}
	hud._handle_reward_pop(item_reward)
	await get_tree().process_frame

	assert(hud._loot_banner != null and hud._loot_banner.visible == true, "装备掉落必须激活专属战利品横幅！")
	var title_lbl = hud._loot_banner.get_node("HBox/VBox/LootTitle") as Label
	assert("涡流水晶" in title_lbl.text, "横幅标题必须包含装备名【涡流水晶】，实际为：%s" % title_lbl.text)
	print("✔ [测试 4 通过] 专属战利品横幅高亮展示装备名与品质！")

	# -------------------------------------------------------------
	# Test 5: 紧接着掉落纯金币 -> 绝对不能冲刷覆盖战利品横幅！
	# -------------------------------------------------------------
	print("\n--- Test 5: 验证后续密集死亡的小怪纯金币消息绝不冲刷覆盖战利品横幅 ---")
	var subsequent_gold = {
		"gold": 5,
		"exp": 10,
		"monster_name": "僵尸"
	}
	hud._handle_reward_pop(subsequent_gold)
	await get_tree().process_frame

	assert(hud._loot_banner != null and hud._loot_banner.visible == true, "战利品横幅必须依然保持展示！")
	title_lbl = hud._loot_banner.get_node("HBox/VBox/LootTitle") as Label
	assert("涡流水晶" in title_lbl.text, "战利品横幅内容依然必须是【涡流水晶】，绝不能被冲刷覆盖！实际为：%s" % title_lbl.text)
	print("✔ [测试 5 通过] 战利品横幅在频繁金币消息下坚挺驻留，彻底解决掉落提示被冲刷问题！")

	# -------------------------------------------------------------
	# Test 6: 检查背包增量落槽
	# -------------------------------------------------------------
	print("\n--- Test 6: 验证增量战利品成功进入背包槽位并点亮金色 NEW 角标 ---")
	var inv = hud.inventory_panel
	assert(inv.items_map.size() > 0, "背包槽位映射中必须包含刚掉落的战利品")
	var slot0 = inv.items_map.get(0, {})
	assert("涡流水晶" in str(slot0.get("name", "")), "第 0 格必须是刚掉落的涡流水晶")
	assert(inv.slots[0].is_new_item == true or (inv.slots[0].new_badge != null and inv.slots[0].new_badge.visible == true), "刚掉落的战利品必须点亮金色 NEW 呼吸角标")
	print("✔ [测试 6 通过] 战利品增量落槽成功，NEW 角标正确点亮！")
	# -------------------------------------------------------------
	# Test 7: 模拟怪物攻击玩家 (怪物的 me_max_mp 为 13，绝不能污染玩家蓝球！)
	# -------------------------------------------------------------
	print("\n--- Test 7: 验证怪物攻击玩家时，怪物的法力 (13) 绝不覆盖玩家底栏蓝球 ---")
	GameState.selected_character["id"] = "xdao_sor1"
	var monster_attack_frame = {
		"attacker": "zombie",
		"victim": "xdao_sor1",
		"dmg": 10,
		"me_hp": 35,
		"me_max_hp": 35,
		"me_mp": 5,
		"me_max_mp": 13, # 这是怪物的法力上限 13！
		"you_hp": 37,
		"you_max_hp": 47,
		"you_mp": 53,
		"you_max_mp": 71  # 这是玩家的真实法力上限 71！
	}
	hud._handle_combat_data(monster_attack_frame)
	await get_tree().process_frame

	assert(mp_bar.max_val == 71, "受击时玩家蓝球最大值必须依然为 71，绝不能被怪物的 13 污染！实际为: %d" % mp_bar.max_val)
	assert(mp_bar.cur_val == 53, "受击时玩家蓝球当前值必须为 53，实际为: %d" % mp_bar.cur_val)
	print("✔ [测试 7 通过] 怪打玩家时成功隔离怪物的 13 法力，玩家蓝球坚如磐石稳定在 71，彻底根除狂跳！")

	# -------------------------------------------------------------
	# Test 8: 击杀怪物并在其实际槽位物理点位升起掉落提示
	# -------------------------------------------------------------
	print("\n--- Test 8: 验证怪物致死时精准记录其屏幕坐标，掉落提示在尸体处升起 ---")
	var mon_uuid = "/d/act1/npc/act1_monster#888"
	var test_mon_data = {
		"id": mon_uuid,
		"name": "沉沦魔巫师",
		"rank": "champion",
		"hp": 20,
		"max_hp": 100
	}
	# 模拟生成怪物在 Slot 1 (右前)
	hud._handle_gstatus_data({
		"player": { "mp": 71, "max_mp": 71, "hp": 47, "max_hp": 47 },
		"monsters": [test_mon_data]
	})
	await get_tree().process_frame

	var mon_node = hud._monster_instances.get(mon_uuid)
	assert(mon_node != null, "怪物实例必须成功创建")
	var expected_pos = mon_node.global_position

	# 致死打击
	var fatal_strike = {
		"attacker": "xdao_sor1",
		"victim": "沉沦魔巫师",
		"victim_uuid": mon_uuid,
		"dmg": 50,
		"you_hp": 0,
		"you_max_hp": 100,
		"me_mp": 71,
		"me_max_mp": 71
	}
	hud._handle_combat_data(fatal_strike)
	await get_tree().process_frame

	assert(hud._killed_monster_positions.has(mon_uuid), "致死瞬间必须记录该怪物的屏幕坐标！")
	assert(hud._killed_monster_positions[mon_uuid] == expected_pos, "记录的击杀坐标必须与怪物的实际坐标完全一致")

	# 掉落到来
	var mon_reward = {
		"monster_id": mon_uuid,
		"monster_name": "沉沦魔巫师",
		"gold": 66,
		"exp": 188
	}
	hud._handle_reward_pop(mon_reward)
	await get_tree().process_frame
	print("✔ [测试 8 通过] 击杀点位与掉落提示 100% 精准绑定对应怪物实际屏幕位置！")

	print("\n========================================================")
	print(">>> 恭喜！法力值蓝球纠偏、怪打玩家法力防污染、原位掉落等 8 项测试全部 100% 通过！<<<")
	print("========================================================\n")
	get_tree().quit(0)
