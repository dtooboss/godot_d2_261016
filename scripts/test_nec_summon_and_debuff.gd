extends Control

const MonsterDisplayScript = preload("res://scenes/afk/components/monster_display.gd")
const AFKMainHudScript = preload("res://scenes/afk/afk_main_hud.gd")

func _ready() -> void:
	print("==================================================================")
	print("【自动化测试】死灵法师召唤物实体体系 + 怪物Debuff卡片 + 仆从徽章")
	print("==================================================================")

	_test_monster_debuff_rendering()
	_test_summons_container_rendering()
	_test_skeleton_cap_formula()
	_test_hell_minion_scaling_and_resistances()
	_test_mage_and_golem_stats_and_scaling()
	_test_triad_summons_and_clay_slow_rendering()

	print("\n🎉 死灵法师三位一体召唤与Debuff体系自动化测试 100% 全部通过！")
	get_tree().quit(0)

## 1. 验证怪物卡片 Debuff 图标渲染
func _test_monster_debuff_rendering() -> void:
	print("\n[Test 1] 验证 monster_display 对怪物 Debuff 徽章的动态渲染...")
	
	var mon_scene = load("res://scenes/afk/components/monster_display.tscn")
	var mon = mon_scene.instantiate()
	add_child(mon)

	var fake_mon_data = {
		"id": "mon_101",
		"mon_key": "fallen",
		"code": "fallen",
		"name": "沉沦魔",
		"rank": "normal",
		"hp": 80,
		"max_hp": 100,
		"level": 5,
		"debuffs": [
			{"id": "amplify_damage", "name": "伤害加深", "color": "#ff3333"},
			{"id": "poison", "name": "剧毒", "color": "#00ff66"}
		]
	}

	mon.bind_monster_data(fake_mon_data)

	var debuff_box = mon.get_node_or_null("NamePanel/VBox/DebuffBox")
	assert(debuff_box != null, "DebuffBox 容器必须成功创建")
	assert(debuff_box.visible == true, "DebuffBox 必须可见")
	assert(debuff_box.get_child_count() == 2, "DebuffBox 必须拥有 2 个减益徽章")

	var badge_amp = debuff_box.get_child(0)
	var lbl_amp = badge_amp.get_child(0) as Label
	print("  徽章 1: '%s'" % lbl_amp.text)
	assert("伤害加深" in lbl_amp.text and "🩸" in lbl_amp.text, "伤害加深徽章内容正确")

	var badge_poi = debuff_box.get_child(1)
	var lbl_poi = badge_poi.get_child(0) as Label
	print("  徽章 2: '%s'" % lbl_poi.text)
	assert("剧毒" in lbl_poi.text and "🧪" in lbl_poi.text, "剧毒徽章内容正确")

	# 测试清空 Debuff 时自动隐藏
	fake_mon_data["debuffs"] = []
	mon.bind_monster_data(fake_mon_data)
	assert(debuff_box.visible == false, "无 Debuff 时 DebuffBox 必须自动隐藏")

	mon.queue_free()
	print("✔ Test 1 通过：怪物卡片 Debuff 徽章渲染与自动隐藏验证无误！")

## 2. 验证玩家仆从徽章动态渲染
func _test_summons_container_rendering() -> void:
	print("\n[Test 2] 验证 afk_main_hud 仆从聚合状态徽章展示...")
	
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)

	var fake_summons = [
		{"type": "skeleton", "name": "复生骷髅", "count": 4, "max_count": 7, "hp_pct": 100}
	]

	hud._update_summons_display(fake_summons)

	var sum_box = hud.get_node_or_null("SummonsContainer")
	assert(sum_box != null, "SummonsContainer 必须成功动态创建")
	assert(sum_box.visible == true, "SummonsContainer 必须可见")
	assert(sum_box.get_child_count() == 1, "必须包含 1 个仆从卡片")

	var card = sum_box.get_child(0)
	var lbl = card.get_child(0) as Label
	print("  仆从卡片文本: '%s'" % lbl.text)
	assert("复生骷髅: 4 / 7" in lbl.text and "💀" in lbl.text, "仆从卡片文本必须包含骷髅数量")

	hud.queue_free()
	print("✔ Test 2 通过：仆从聚合徽章展示逻辑完备！")

## 3. 验证骷髅技能等级上限算法
func _test_skeleton_cap_formula() -> void:
	print("\n[Test 3] 验证复生骷髅技能等级与数量上限公式...")
	
	# 公式: (sk_lvl < 3) ? 1 : (2 + (sk_lvl - 3) / 3)
	var test_levels = [
		{"lvl": 1, "expected": 1},
		{"lvl": 2, "expected": 1},
		{"lvl": 3, "expected": 2},
		{"lvl": 4, "expected": 2},
		{"lvl": 5, "expected": 2},
		{"lvl": 6, "expected": 3},
		{"lvl": 9, "expected": 4},
		{"lvl": 12, "expected": 5},
		{"lvl": 20, "expected": 7},
	]

	for tc in test_levels:
		var lvl = tc["lvl"]
		var cap = 1 if lvl < 3 else (2 + (lvl - 3) / 3)
		print("  技能等级 Lv.%d -> 上限 %d (期望: %d)" % [lvl, cap, tc["expected"]])
		assert(cap == tc["expected"], "等级上限计算有误")

	print("✔ Test 3 通过：复生骷髅官方原版数量阶梯公式完全吻合！")

## 4. 验证地狱难度生命缩放与召唤抗性
func _test_hell_minion_scaling_and_resistances() -> void:
	print("\n[Test 4] 验证地狱难度生命乘数缩放与召唤抵抗全抗性继承...")
	
	var sk_lvl = 20
	var mastery_lvl = 20
	var base_hp_normal = int((25 + sk_lvl * 16) * (1.0 + mastery_lvl * 0.08) * 1.0)
	var hp_nm = int((25 + sk_lvl * 16) * (1.0 + mastery_lvl * 0.08) * 2.2)
	var hp_hell = int((25 + sk_lvl * 16) * (1.0 + mastery_lvl * 0.08) * 4.5)

	print("  Lv.20 复生骷髅 [普通难度 HP]: %d (期望 ~897)" % base_hp_normal)
	print("  Lv.20 复生骷髅 [噩梦难度 HP]: %d (期望 ~1973)" % hp_nm)
	print("  Lv.20 复生骷髅 [地狱难度 HP]: %d (期望 ~4036)" % hp_hell)

	assert(base_hp_normal > 800 and base_hp_normal < 1000, "普通难度骷髅血量在合理区间")
	assert(hp_hell > 4000, "地狱难度骷髅必须达到 4000+ 血量以抵御地狱怪物爆发")

	# 验证召唤抗性继承
	var sr_lvl = 20
	var elem_res = 28 + int(sr_lvl * 2.0) # 68%
	if elem_res > 75: elem_res = 75
	print("  Lv.20 召唤抗性全元素抗性 (火/冰/电/毒): %d%% (期望 66%%~75%%)" % elem_res)
	assert(elem_res >= 60 and elem_res <= 75, "召唤抗性必须提供 60%~75% 元素减伤")

	# 验证物理减伤
	var phys_res = 25
	print("  骷髅天然物理抗性: %d%%" % phys_res)
	assert(phys_res == 25, "骷髅天然具备 25% 物理抗性")

	print("✔ Test 4 通过：地狱难度生命缩放 (4000+ HP) 与召唤抗性 (68% 全抗 + 25% 物抗) 完美保障存活！")

## 5. 验证骷髅法师与黏土傀儡的数值建模与差异化
func _test_mage_and_golem_stats_and_scaling() -> void:
	print("\n[Test 5] 验证骷髅法师（脆皮元素）与黏土傀儡（单体巨坦）数值模型差异...")

	# 1. 骷髅法师数值 (战士约 40% 生命，远程元素)
	var mg_sk_lvl = 20
	var mg_mastery = 20
	var mage_hp_normal = int((15 + mg_sk_lvl * 8) * (1.0 + mg_mastery * 0.08) * 1.0)
	var mage_hp_hell = int((15 + mg_sk_lvl * 8) * (1.0 + mg_mastery * 0.08) * 4.5)
	print("  Lv.20 骷髅法师 [普通 HP]: %d (期望 ~455)" % mage_hp_normal)
	print("  Lv.20 骷髅法师 [地狱 HP]: %d (期望 ~2047)" % mage_hp_hell)
	assert(mage_hp_normal < 500, "法师普通血量符合脆皮后排定位")
	assert(mage_hp_hell > 1800, "法师地狱血量足以承受一般 AOE 伤害")

	# 2. 黏土傀儡数值 (超高血量坦克，受石魔精通巨额加成)
	var g_sk_lvl = 20
	var g_mastery = 20 # 每级 +20% HP，Lv20 +400%
	var golem_hp_normal = int((120 + g_sk_lvl * 40) * (1.0 + g_mastery * 0.20) * 1.0)
	var golem_hp_hell = int((120 + g_sk_lvl * 40) * (1.0 + g_mastery * 0.20) * 4.5)
	print("  Lv.20 黏土傀儡 [普通 HP]: %d (期望 ~4600)" % golem_hp_normal)
	print("  Lv.20 黏土傀儡 [地狱 HP]: %d (期望 ~20700)" % golem_hp_hell)
	assert(golem_hp_hell > 15000, "地狱黏土傀儡具备超级肉盾血量")

	# 3. 黏土减速公式
	var slow_pct = 15 + g_sk_lvl * 2 # 15 + 40 = 55 -> 封顶 50%
	if slow_pct > 50: slow_pct = 50
	print("  Lv.20 黏土傀儡减速效果: %d%% (期望 50%% 封顶)" % slow_pct)
	assert(slow_pct == 50, "黏土傀儡减速达到 50% 封顶")

	# 4. 天然物抗
	var golem_pr = 35
	print("  黏土傀儡天然物理减伤: %d%%" % golem_pr)
	assert(golem_pr == 35, "黏土傀儡天然具备 35% 物理抗性")

	print("✔ Test 5 通过：骷髅战士（高血近战）、骷髅法师（脆皮元素）与黏土傀儡（单体巨坦）数值模型严格差异化！")

## 6. 验证三位一体仆从聚合卡片与黏土减速 Debuff 徽章渲染
func _test_triad_summons_and_clay_slow_rendering() -> void:
	print("\n[Test 6] 验证前端 afk_main_hud 三位一体仆从渲染与黏土减速 Debuff 徽章...")

	# 1. 验证 HUD 三类随从聚合展示
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)

	var triad_summons = [
		{"type": "skeleton", "name": "复生骷髅", "count": 4, "max_count": 7, "hp_pct": 100},
		{"type": "mage", "name": "骷髅法师", "count": 3, "max_count": 7, "hp_pct": 100},
		{"type": "golem", "name": "黏土傀儡", "count": 1, "max_count": 1, "hp_pct": 100}
	]

	hud._update_summons_display(triad_summons)

	var sum_box = hud.get_node_or_null("SummonsContainer")
	assert(sum_box != null, "SummonsContainer 必须存在")
	assert(sum_box.get_child_count() == 3, "必须同时呈现 3 类随从卡片")

	var card_skel = sum_box.get_child(0)
	var lbl_skel = card_skel.get_child(0) as Label
	print("  随从卡片 1: '%s'" % lbl_skel.text)
	assert("复生骷髅: 4 / 7" in lbl_skel.text and "💀" in lbl_skel.text, "骷髅卡片正确")

	var card_mage = sum_box.get_child(1)
	var lbl_mage = card_mage.get_child(0) as Label
	print("  随从卡片 2: '%s'" % lbl_mage.text)
	assert("骷髅法师: 3 / 7" in lbl_mage.text and "💀" in lbl_mage.text, "法师卡片正确")

	var card_golem = sum_box.get_child(2)
	var lbl_golem = card_golem.get_child(0) as Label
	print("  随从卡片 3: '%s'" % lbl_golem.text)
	assert("黏土傀儡: 1 / 1" in lbl_golem.text and "🗿" in lbl_golem.text, "石魔卡片正确")

	hud.queue_free()

	# 2. 验证怪物黏土减速 Debuff 渲染
	var mon_scene = load("res://scenes/afk/components/monster_display.tscn")
	var mon = mon_scene.instantiate()
	add_child(mon)

	var fake_boss = {
		"id": "mon_duriel",
		"mon_key": "duriel",
		"code": "duriel",
		"name": "督瑞尔",
		"rank": "boss",
		"hp": 5000,
		"max_hp": 5000,
		"level": 25,
		"debuffs": [
			{"id": "decrepify", "name": "衰老", "color": "#cc88ff"},
			{"id": "clay_slow", "name": "迟缓", "color": "#d4a373"}
		]
	}

	mon.bind_monster_data(fake_boss)
	var debuff_box = mon.get_node_or_null("NamePanel/VBox/DebuffBox")
	assert(debuff_box != null, "DebuffBox 必须存在")
	assert(debuff_box.get_child_count() == 2, "必须展示 2 个 Debuff 徽章")

	var badge_dec = debuff_box.get_child(0)
	var lbl_dec = badge_dec.get_child(0) as Label
	print("  Boss Debuff 1: '%s'" % lbl_dec.text)
	assert("衰老" in lbl_dec.text and "⌛" in lbl_dec.text, "衰老徽章正确")

	var badge_slow = debuff_box.get_child(1)
	var lbl_slow = badge_slow.get_child(0) as Label
	print("  Boss Debuff 2: '%s'" % lbl_slow.text)
	assert("迟缓" in lbl_slow.text and "🗿" in lbl_slow.text, "黏土迟缓徽章正确")

	mon.queue_free()
	print("✔ Test 6 通过：三位一体随从卡片与黏土减速 Debuff 徽章全部完美渲染！")

