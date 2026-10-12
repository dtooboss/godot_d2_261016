extends Node

## 测试自己伤害飘字 vs 他人伤害飘字字号与透明度分流

const MonsterDisplayScene = preload("res://scenes/afk/components/monster_display.tscn")

func _ready() -> void:
	print("--- 开始测试伤害飘字大小与透明度区分 ---")
	
	var mon = MonsterDisplayScene.instantiate()
	add_child(mon)
	
	var dmg_box = mon.find_child("DamageContainer", true, false)
	assert(dmg_box != null, "怪物应包含 DamageContainer 节点")
	
	# 1. 自身普通伤害测试 (is_attacker_me = true)
	mon.spawn_damage(520, "物理", false, false, true)
	var lbl_self = dmg_box.get_child(dmg_box.get_child_count() - 1) as Label
	assert(lbl_self != null, "应生成伤害 Label")
	var sz_self = lbl_self.get_theme_font_size("font_size")
	assert(sz_self == 20, "自己打的普通伤害字号应为 20px (当前: %d)" % sz_self)
	var col_self = lbl_self.get_theme_color("font_color")
	assert(is_equal_approx(col_self.a, 1.0), "自己打的伤害应为 100% 不透明")
	print("✔ 自身普通伤害验证通过: 字号=%d, 透明度=%.2f" % [sz_self, col_self.a])
	
	# 2. 队友普通伤害测试 (is_attacker_me = false)
	mon.spawn_damage(380, "物理", false, false, false)
	var lbl_team = dmg_box.get_child(dmg_box.get_child_count() - 1) as Label
	var sz_team = lbl_team.get_theme_font_size("font_size")
	assert(sz_team == 13, "队友打的普通伤害字号应为 13px (当前: %d)" % sz_team)
	var col_team = lbl_team.get_theme_color("font_color")
	assert(col_team.a < 0.7, "队友打的伤害应淡化半透明 (当前: %.2f)" % col_team.a)
	print("✔ 队友普通伤害验证通过: 字号=%d, 透明度=%.2f" % [sz_team, col_team.a])
	
	# 3. 自身暴击伤害测试 (is_attacker_me = true, is_crit = true)
	mon.spawn_damage(1680, "火", true, false, true)
	var lbl_self_crit = dmg_box.get_child(dmg_box.get_child_count() - 1) as Label
	var sz_self_crit = lbl_self_crit.get_theme_font_size("font_size")
	assert(sz_self_crit == 28, "自己打的暴击字号应为 28px (当前: %d)" % sz_self_crit)
	print("✔ 自身暴击伤害验证通过: 字号=%d" % sz_self_crit)
	
	# 4. 队友暴击伤害测试 (is_attacker_me = false, is_crit = true)
	mon.spawn_damage(1200, "电", true, false, false)
	var lbl_team_crit = dmg_box.get_child(dmg_box.get_child_count() - 1) as Label
	var sz_team_crit = lbl_team_crit.get_theme_font_size("font_size")
	assert(sz_team_crit == 17, "队友打的暴击字号应为 17px (当前: %d)" % sz_team_crit)
	print("✔ 队友暴击伤害验证通过: 字号=%d" % sz_team_crit)
	
	print("🎉 伤害飘字主次分流所有断言 100% 通过！")
	get_tree().quit(0)
