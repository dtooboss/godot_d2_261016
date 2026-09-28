# test_battle_statistics.gd
extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("==================================================================")
	print("=== 开始验证：战斗统计算力、Tooltip 顶层层级与房间名净化全链路 ===")
	print("==================================================================")
	
	# ----------------------------------------------------------------
	# 1. 验证 Tooltip 的 Z-Index 绝对层级 (必须为 500，远超纸娃娃 150)
	# ----------------------------------------------------------------
	print("\n>>> [测试 1] 验证 ItemTooltip 绝对层级优先级...")
	var tooltip = hud.item_tooltip
	assert(tooltip != null, "HUD 中必须存在 item_tooltip！")
	assert(tooltip.z_index >= 500, "Tooltip z_index 必须 >= 500！当前: %d" % tooltip.z_index)
	assert(tooltip.z_as_relative == false, "Tooltip z_as_relative 必须为 false 确保绝对最高层级！")
	
	var char_panel = hud.char_info_panel
	assert(char_panel != null, "HUD 中必须存在 char_info_panel！")
	assert(tooltip.z_index > char_panel.z_index, "Tooltip z_index (%d) 必须大于纸娃娃面板 (%d)！" % [tooltip.z_index, char_panel.z_index])
	print("✔ 测试 1 通过: ItemTooltip z_index = 500，已拥有绝对最高渲染优先级，彻底杜绝被纸娃娃遮盖！")
	
	# ----------------------------------------------------------------
	# 2. 验证关卡与房间名净化函数 (彻底消除【普通】与(挂机副本)缀词)
	# ----------------------------------------------------------------
	print("\n>>> [测试 2] 验证房间名净化函数...")
	var raw1 = "【普通】下水道一层 (挂机副本)"
	var clean1 = hud._clean_stage_name(raw1)
	assert(clean1 == "下水道一层", "【普通】下水道一层 (挂机副本) 净化后应为 '下水道一层'！实际: " + clean1)
	
	var raw2 = "【地狱】遗忘之塔 (挂机点)"
	var clean2 = hud._clean_stage_name(raw2)
	assert(clean2 == "遗忘之塔", "【地狱】遗忘之塔 (挂机点) 净化后应为 '遗忘之塔'！实际: " + clean2)
	
	var raw3 = "鲜血荒地"
	var clean3 = hud._clean_stage_name(raw3)
	assert(clean3 == "鲜血荒地", "原本纯净的名应保持不变！实际: " + clean3)
	print("✔ 测试 2 通过: 房间名净化函数 100% 滤除难度前缀与挂机后缀，名称清爽美观！")
	
	# ----------------------------------------------------------------
	# 3. 独立 BattleStatistics 组件单元测试
	# ----------------------------------------------------------------
	print("\n>>> [测试 3] 验证 BattleStatistics 初始状态零假数据...")
	var stats_scene = load("res://scenes/afk/components/battle_statistics.tscn")
	assert(stats_scene != null, "battle_statistics.tscn 加载失败！")
	var stats_node = stats_scene.instantiate()
	add_child(stats_node)
	await get_tree().process_frame
	
	assert(stats_node.death_count == 0, "初始死亡次数应为 0")
	assert(stats_node.total_damage_dealt == 0, "初始输出伤害应为 0")
	assert(stats_node.total_damage_taken == 0, "初始承受伤害应为 0")
	assert(stats_node.total_heal == 0, "初始治疗量应为 0")
	assert(stats_node.total_kills == 0, "初始击杀数应为 0")
	assert(stats_node.total_exp == 0, "初始经验应为 0")
	assert(stats_node.val_dps.text == "0.0", "初始每秒伤害显示应为 0.0！当前: " + stats_node.val_dps.text)
	assert(stats_node.val_take_dmg.text == "0.0", "初始每秒承伤显示应为 0.0！当前: " + stats_node.val_take_dmg.text)
	assert(stats_node.val_time.text == "00:00:00", "初始挂机时间应为 00:00:00！当前: " + stats_node.val_time.text)
	print("✔ 测试 3 通过: 初始状态无任何 Mock 假数据，全部清零初始化！")
	
	# 模拟事件与 10 秒时间推进
	print("\n>>> [测试 4] 模拟 10 秒战斗事件推进与平滑算力验证...")
	stats_node.reset_stats()
	stats_node.record_damage_dealt(1200) # 总输出 1200
	stats_node.record_damage_taken(300)  # 总承伤 300
	stats_node.record_heal(150)          # 总治疗 150
	stats_node.record_kill(5)            # 总击杀 5
	stats_node.record_exp(6000)          # 总经验 6000
	stats_node.record_death()            # 死亡 1 次
	
	stats_node.elapsed_seconds = 10.0
	stats_node.update_display()
	
	assert(stats_node.val_time.text == "00:00:10", "10秒后挂机时间应为 00:00:10！当前: " + stats_node.val_time.text)
	assert(stats_node.val_death.text == "1", "死亡次数应显示为 1！当前: " + stats_node.val_death.text)
	assert(stats_node.val_dps.text == "120", "DPS 应为 1200/10=120！当前: " + stats_node.val_dps.text)
	assert(stats_node.val_take_dmg.text == "30", "承伤/秒应为 300/10=30！当前: " + stats_node.val_take_dmg.text)
	assert(stats_node.val_heal.text == "15", "治疗/秒应为 150/10=15！当前: " + stats_node.val_heal.text)
	assert(stats_node.val_kill_rate.text == "30.00", "每分击杀应为 (5/10)*60 = 30.00！当前: " + stats_node.val_kill_rate.text)
	assert(stats_node.val_exp_rate.text == "36.0K", "每分经验应为 (6000/10)*60 = 36.0K！当前: " + stats_node.val_exp_rate.text)
	print("✔ 测试 4 通过: DPS(120)、承伤(30)、治疗(15)、每分击杀(30.00)、每分经验(36.0K) 计算 100% 精准！")
	
	# 验证【重置】
	print("\n>>> [测试 5] 验证点击【重置】按钮一键归零...")
	stats_node.reset_stats()
	assert(stats_node.val_time.text == "00:00:00", "重置后时间应归零 00:00:00")
	assert(stats_node.val_death.text == "0", "重置后死亡应归零")
	assert(stats_node.val_dps.text == "0.0", "重置后 DPS 应归零")
	assert(stats_node.val_take_dmg.text == "0.0", "重置后承伤应归零")
	assert(stats_node.val_kill_rate.text == "0.00", "重置后击杀率应归零")
	assert(stats_node.val_exp_rate.text == "0", "重置后经验率应归零")
	print("✔ 测试 5 通过: 重置按钮完全生效，所有指标秒级归零！")
	
	# ----------------------------------------------------------------
	# 4. 验证 HUD 战斗网络帧驱动下的自动化闭环
	# ----------------------------------------------------------------
	print("\n>>> [测试 6] 验证 AFK_MainHUD 真实 combat 与 reward_pop 帧驱动接入...")
	var hud_stats = hud.battle_statistics
	assert(hud_stats != null, "HUD 中必须正确挂载 battle_statistics 节点！")
	
	hud._my_player_name = "测试英雄"
	var net_client = get_node_or_null("/root/NetworkClient")
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.player_id = "hero101"
	
	var combat_atk = {
		"attacker": "hero101",
		"victim": "zombie_1",
		"dmg": 500,
		"elem": "物理"
	}
	hud._handle_combat_data(combat_atk)
	assert(hud_stats.total_damage_dealt == 500, "combat 攻击帧应累加 500 输出伤害！实际: %d" % hud_stats.total_damage_dealt)
	
	var combat_def = {
		"attacker": "zombie_1",
		"victim": "hero101",
		"dmg": 88,
		"elem": "毒"
	}
	hud._handle_combat_data(combat_def)
	assert(hud_stats.total_damage_taken == 88, "combat 受击帧应累加 88 承受伤害！实际: %d" % hud_stats.total_damage_taken)
	
	var pop_frame = {
		"monster_id": "zombie_1",
		"gold": 200,
		"exp": 1500
	}
	hud._handle_reward_pop(pop_frame)
	assert(hud_stats.total_exp == 1500, "reward_pop 帧应累加 1500 经验！实际: %d" % hud_stats.total_exp)
	print("✔ 测试 6 通过: HUD 实时战斗事件流成功全权消费，统计面板无缝联动！")
	
	print("\n==================================================================")
	print("=== 全部 6 项核心验证 100% 成功通过！Tooltip/房间名/统计面板完美闭环！===")
	print("==================================================================")
	get_tree().quit(0)
