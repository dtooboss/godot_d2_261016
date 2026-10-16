extends Control
## 自动化测试：验证怪物攻击条四系属性渲染（火焰攻击/冰冻攻击/闪电攻击/剧毒攻击/普通攻击）

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("--- 开始测试：怪物攻击条四系元素动态渲染与文字对齐 ---")
	var mon_scene = load("res://scenes/afk/components/monster_display.tscn")
	assert(mon_scene != null, "必须成功加载 monster_display 场景")
	
	var mon_disp = mon_scene.instantiate()
	add_child(mon_disp)
	
	# 测试 1: 火焰攻击渲染
	mon_disp.trigger_attack(1.2, "火焰攻击", "火")
	assert(mon_disp.skill_label.text == "火焰攻击", "技能文字必须为火焰攻击")
	var col_fire = mon_disp._attack_fill_style.bg_color
	assert(col_fire.r > 0.8 and col_fire.b < 0.2, "火焰攻击条必须为炽烈橙红色")
	print("  ✔ 测试 1 通过：火焰攻击文字正确，进度条颜色成功渲染为炽焰橙红: ", col_fire)

	# 测试 2: 冰冻攻击渲染
	mon_disp.trigger_attack(1.5, "冰冻攻击", "冰")
	assert(mon_disp.skill_label.text == "冰冻攻击", "技能文字必须为冰冻攻击")
	var col_cold = mon_disp._attack_fill_style.bg_color
	assert(col_cold.b > 0.8 and col_cold.r < 0.4, "冰冻攻击条必须为冰蓝色")
	print("  ✔ 测试 2 通过：冰冻攻击文字正确，进度条颜色成功渲染为霜雪天蓝: ", col_cold)

	# 测试 3: 闪电攻击渲染
	mon_disp.trigger_attack(1.0, "闪电攻击", "电")
	assert(mon_disp.skill_label.text == "闪电攻击", "技能文字必须为闪电攻击")
	var col_light = mon_disp._attack_fill_style.bg_color
	assert(col_light.r > 0.9 and col_light.g > 0.8 and col_light.b < 0.3, "闪电攻击条必须为金黄色")
	print("  ✔ 测试 3 通过：闪电攻击文字正确，进度条颜色成功渲染为耀眼金黄: ", col_light)

	# 测试 4: 剧毒攻击渲染
	mon_disp.trigger_attack(2.0, "剧毒攻击", "毒")
	assert(mon_disp.skill_label.text == "剧毒攻击", "技能文字必须为剧毒攻击")
	var col_pois = mon_disp._attack_fill_style.bg_color
	assert(col_pois.g > 0.8 and col_pois.r < 0.3, "剧毒攻击条必须为翠绿色")
	print("  ✔ 测试 4 通过：剧毒攻击文字正确，进度条颜色成功渲染为剧毒翠绿: ", col_pois)

	# 测试 5: 普通物理攻击渲染
	mon_disp.trigger_attack(1.5, "普通攻击", "物理")
	assert(mon_disp.skill_label.text == "普通攻击", "技能文字必须为普通攻击")
	var col_phys = mon_disp._attack_fill_style.bg_color
	assert(col_phys.r == 1.0 and col_phys.g == 1.0 and col_phys.b == 0.0, "普通攻击条必须恢复为经典明黄色")
	print("  ✔ 测试 5 通过：普通攻击文字正确，进度条颜色成功恢复为经典明黄: ", col_phys)

	# 测试 6: 智能推导 (若外部未传 elem，仅传 skill_name)
	mon_disp.trigger_attack(1.2, "月亮氏族的火焰喷吐", "")
	assert(mon_disp._attack_fill_style.bg_color == col_fire, "无显式 elem 时应智能从技能名推断出火系主题色")
	print("  ✔ 测试 6 通过：无显式 elem 时智能推导机制工作正常！")

	print("\n🎉 怪物攻击条四系属性渲染 6 项测试全部通过！")
	get_tree().quit(0)
