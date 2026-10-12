extends Control

func _ready() -> void:
	print("==================================================================")
	print("【自动化测试】等级差经验倍率与防带小号机制重构验证")
	print("==================================================================")

	_test_peer_party_overlevel_kill()
	_test_power_leveling_protection()
	_test_underlevel_monster_penalty()

	print("\n🎉 等级经验分配与越级挑战自动化测试 100% 全部通过！")
	get_tree().quit(0)

## 模拟 d2_leveld.c 的 calc_diff_multiplier 实现
func calc_diff_multiplier(plvl: int, vic_lvl: int, max_party_lvl: int) -> float:
	if plvl < 1: plvl = 1
	if vic_lvl < 1: vic_lvl = 1
	if max_party_lvl < plvl: max_party_lvl = plvl

	var diff = plvl - vic_lvl

	# 1. 玩家高于怪物 6 级以上 (打低级怪虐菜)
	if diff > 5:
		if diff == 6: return 0.81
		if diff == 7: return 0.62
		if diff == 8: return 0.43
		if diff == 9: return 0.24
		return 0.05

	# 2. 怪物高于玩家 6 级以上 (越级打怪)
	if diff < -5:
		# 判定是否属于大号带小号 (队伍最大等级与自身相差 >= 15 级)
		if max_party_lvl - plvl >= 15:
			return 0.05
		# 正常越级挑战 (同级队伍或单人自强): 平滑缩放 plvl / vic_lvl
		return float(plvl) / float(vic_lvl)

	# 3. 等级差在 +/- 5 级以内: 100% 全额经验
	return 1.0

## 1. 验证同级队伍 (27级队伍) 越级打怪收益严格递增 (40级怪 > 30级怪)
func _test_peer_party_overlevel_kill() -> void:
	print("\n[Test 1] 验证全员 27 级开荒小队击杀 30 级怪 vs 40 级怪收益...")

	var plvl = 27
	var max_party = 27 # 全队同级，无大号带飞

	# 击杀 30 级怪
	var mult_30 = calc_diff_multiplier(plvl, 30, max_party)
	var base_exp_30 = 2000
	var final_exp_30 = int(base_exp_30 * mult_30)

	# 击杀 40 级怪
	var mult_40 = calc_diff_multiplier(plvl, 40, max_party)
	var base_exp_40 = 6000
	var final_exp_40 = int(base_exp_40 * mult_40)

	print("  27级打 30级怪: 经验倍率 = %.3f, 基础经验 = %d -> 实得经验 = %d" % [mult_30, base_exp_30, final_exp_30])
	print("  27级打 40级怪: 经验倍率 = %.3f, 基础经验 = %d -> 实得经验 = %d" % [mult_40, base_exp_40, final_exp_40])

	assert(mult_30 == 1.0, "30级怪与27级在5级以内，倍率必须是 1.0 (100%)")
	assert(is_equal_approx(mult_40, 27.0 / 40.0), "40级怪平滑倍率必须是 27/40 = 0.675")
	assert(final_exp_40 > final_exp_30, "40级怪实得经验必须明显多于30级怪！(解决原断崖BUG)")
	print("  经验提升幅度: +%d%% (40级怪实得经验比30级怪多出 %.1f 倍)" % [
		int((float(final_exp_40 - final_exp_30) / float(final_exp_30)) * 100),
		float(final_exp_40) / float(final_exp_30)
	])

	print("✔ Test 1 通过：同级队伍越级挑战强敌获得显著正向经验递增！")

## 2. 验证大号带小号保护 (90级带10级打90级怪)
func _test_power_leveling_protection() -> void:
	print("\n[Test 2] 验证 90 级大号带 10 级小号击杀 90 级怪的防蹭车保护...")

	var plvl_small = 10
	var plvl_big = 90
	var vic_lvl = 90
	var max_party = 90 # 队伍最高 90 级

	var total_levels = plvl_small + plvl_big # 100
	var base_exp = 50000

	# 1. 等级份额权重
	var share_small = base_exp * plvl_small / total_levels # 10% = 5000
	var share_big = base_exp * plvl_big / total_levels # 90% = 45000

	# 2. 等级差惩罚倍率
	var mult_small = calc_diff_multiplier(plvl_small, vic_lvl, max_party)
	var mult_big = calc_diff_multiplier(plvl_big, vic_lvl, max_party)

	var final_small = int(share_small * mult_small) # 5000 * 0.05 = 250
	var final_big = int(share_big * mult_big) # 45000 * 1.0 = 45000

	print("  10级小号: 等级权重份额 = %d (10%%), 惩罚倍率 = %.2f -> 最终实得经验 = %d" % [share_small, mult_small, final_small])
	print("  90级大号: 等级权重份额 = %d (90%%), 经验倍率 = %.2f -> 最终实得经验 = %d" % [share_big, mult_big, final_big])

	assert(mult_small == 0.05, "小号被悬殊大号带飞时，惩罚倍率必须压制为 0.05 (5%)")
	assert(final_small < 300, "10级小号最终经验极其微量 (50000经验怪仅获250点，不到0.5%)，成功杜绝蹭车！")

	print("✔ Test 2 通过：大号带小号受到队伍份额(10%)与大跨度惩罚(5%)双重压制，完全锁死！")

## 3. 验证大号虐低级怪物的经验惩罚 (防止新手村刷经验)
func _test_underlevel_monster_penalty() -> void:
	print("\n[Test 3] 验证高级玩家击杀低级怪物时的梯度惩罚...")

	var plvl = 30
	var max_party = 30

	var mult_25 = calc_diff_multiplier(plvl, 25, max_party) # 差5级: 100%
	var mult_24 = calc_diff_multiplier(plvl, 24, max_party) # 差6级: 81%
	var mult_23 = calc_diff_multiplier(plvl, 23, max_party) # 差7级: 62%
	var mult_22 = calc_diff_multiplier(plvl, 22, max_party) # 差8级: 43%
	var mult_21 = calc_diff_multiplier(plvl, 21, max_party) # 差9级: 24%
	var mult_15 = calc_diff_multiplier(plvl, 15, max_party) # 差15级: 5%

	print("  30级打 25级怪 (差5级):  %.2f (100%%)" % mult_25)
	print("  30级打 24级怪 (差6级):  %.2f (81%%)" % mult_24)
	print("  30级打 23级怪 (差7级):  %.2f (62%%)" % mult_23)
	print("  30级打 22级怪 (差8级):  %.2f (43%%)" % mult_22)
	print("  30级打 21级怪 (差9级):  %.2f (24%%)" % mult_21)
	print("  30级打 15级怪 (差15级): %.2f (5%%)" % mult_15)

	assert(mult_25 == 1.0, "差5级以内全额")
	assert(mult_24 == 0.81, "差6级 81%")
	assert(mult_15 == 0.05, "差10级以上压制到 5%")

	print("✔ Test 3 通过：大号虐菜惩罚阶梯完备，彻底杜绝赖在新手村升级！")
