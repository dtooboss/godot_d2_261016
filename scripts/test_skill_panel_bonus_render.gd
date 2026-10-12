extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- 开始测试技能面板装备加成显示与交互 ---")
	var scn = load("res://scenes/afk/components/skill_panel.tscn")
	if not scn:
		print("❌ 无法加载 skill_panel.tscn")
		quit(1)
		return

	var panel = scn.instantiate()
	root.add_child(panel)

	# 模拟带有装备加成的数据（仿法师冰系技能）
	var mock_data = {
		"class": "sor",
		"free_pts": 5,
		"tabs": [
			{"page": 1, "name": "火焰技能"},
			{"page": 2, "name": "闪电技能"},
			{"page": 3, "name": "冰冷技能"}
		],
		"skills": {
			"ice_bolt": {
				"name": "冰弹",
				"code": "ice_bolt",
				"page": 3,
				"row": 1,
				"col": 1,
				"cur_lvl": 1,
				"eff_lvl": 3, # 原生1级 + 装备+2 (all_skills 1 + skill_ice_bolt 1)
				"req_level": 1,
				"is_learned": true,
				"is_max": false,
				"can_learn": true,
				"prereq_satisfied": true,
				"is_main": true,
				"is_sub": false,
				"cur_desc": "造成 25-30 冰冷伤害",
				"next_desc": "造成 35-42 冰冷伤害"
			},
			"frozen_armor": {
				"name": "冰封装甲",
				"code": "frozen_armor",
				"page": 3,
				"row": 1,
				"col": 2,
				"cur_lvl": 0,
				"eff_lvl": 2, # 原生未投点(0级) + 装备赋予2级
				"req_level": 1,
				"is_learned": false,
				"is_max": false,
				"can_learn": true,
				"prereq_satisfied": true,
				"is_main": false,
				"is_sub": true,
				"cur_desc": "防御强化 +35%",
				"next_desc": "防御强化 +40%"
			},
			"frost_nova": {
				"name": "霜之新星",
				"code": "frost_nova",
				"page": 3,
				"row": 2,
				"col": 2,
				"cur_lvl": 2,
				"eff_lvl": 2, # 无装备加成，原生2级
				"req_level": 6,
				"is_learned": true,
				"is_max": false,
				"can_learn": true,
				"prereq_satisfied": true,
				"is_main": false,
				"is_sub": false,
				"cur_desc": "冰霜环绕减速",
				"next_desc": "范围更大"
			}
		}
	}

	# 1. 打开面板并加载数据
	panel.open()
	panel.render_gskills_data(mock_data)

	# 切换到第3页 (冰系)
	panel._current_page = 3
	panel._render_current_page_nodes()

	# 2. 检查冰弹 (有装备加成) 的角标
	var ice_bolt_node = panel._node_widgets.get("ice_bolt")
	assert(ice_bolt_node != null, "冰弹节点应存在")
	var ice_bolt_lbl: Label = null
	for child in ice_bolt_node.get_children():
		if child is Label and child.text == "3":
			ice_bolt_lbl = child
			break
	assert(ice_bolt_lbl != null, "冰弹角标应显示有效等级 3")
	var font_color = ice_bolt_lbl.get_theme_color("font_color")
	print("✔ 冰弹角标文本: ", ice_bolt_lbl.text, ", 颜色: ", font_color)
	assert(font_color.b > 0.7 and font_color.r < 0.5, "装备加成等级文本应为天蓝色")

	# 3. 检查冰封装甲 (原生0级，装备赋予2级) 的角标与状态
	var fa_node = panel._node_widgets.get("frozen_armor")
	assert(fa_node != null, "冰封装甲节点应存在")
	var fa_lbl: Label = null
	for child in fa_node.get_children():
		if child is Label and child.text == "2":
			fa_lbl = child
			break
	assert(fa_lbl != null, "冰封装甲角标应显示装备赋予等级 2")
	var fa_color = fa_lbl.get_theme_color("font_color")
	print("✔ 冰封装甲角标文本: ", fa_lbl.text, ", 颜色: ", fa_color)
	assert(fa_color.b > 0.7, "装备赋予技能角标应为天蓝色")

	# 4. 检查详情卡片
	panel._render_skill_details("ice_bolt")
	var cur_lvl_text = panel.detail_cur_lvl.text
	print("✔ 冰弹详情卡等级文案: ", cur_lvl_text)
	assert("当前等级: 1/20 (+2 装备)" in cur_lvl_text, "冰弹详情卡应显示 (+2 装备)")

	panel._render_skill_details("frozen_armor")
	var fa_lvl_text = panel.detail_cur_lvl.text
	print("✔ 冰封装甲详情卡等级文案: ", fa_lvl_text)
	assert("当前等级: 0/20 (+2 装备赋予)" in fa_lvl_text, "冰封装甲详情卡应显示 (+2 装备赋予)")

	# 5. 检查普通投点霜之新星
	panel._render_skill_details("frost_nova")
	var nova_lvl_text = panel.detail_cur_lvl.text
	print("✔ 霜之新星详情卡等级文案: ", nova_lvl_text)
	assert("当前等级: 2/20" in nova_lvl_text, "无加成技能应显示 2/20")

	# 6. 测试多维复合特性标签渲染 (以充能一击与雷霆之怒为例)
	var mock_ama_data = {
		"class": "ama",
		"free_pts": 10,
		"skills": {
			"charged_strike": {
				"name": "充能一击",
				"code": "charged_strike",
				"target_type": "combo",
				"damage_type": "light",
				"cast_driver": "ias",
				"hits": 6,
				"cur_lvl": 1,
				"eff_lvl": 1,
				"is_learned": true,
				"is_spell": false
			},
			"lightning_fury": {
				"name": "雷霆之怒",
				"code": "lightning_fury",
				"target_type": "aoe",
				"damage_type": "light",
				"cast_driver": "ias",
				"targets": 6,
				"cur_lvl": 1,
				"eff_lvl": 1,
				"is_learned": true,
				"is_spell": false
			}
		}
	}
	panel.render_gskills_data(mock_ama_data)
	panel._render_skill_details("charged_strike")
	var charged_tag = panel.detail_type_tag.text
	print("✔ 充能一击复合标签: ", charged_tag)
	assert("单体 6 连击" in charged_tag, "充能一击应明确标注单体 6 连击！实际: " + charged_tag)
	assert("闪电" in charged_tag, "充能一击应明确标注闪电伤害！实际: " + charged_tag)
	assert("受攻速(IAS)加速" in charged_tag, "充能一击应明确标注受攻速加速！实际: " + charged_tag)

	panel._render_skill_details("lightning_fury")
	var fury_tag = panel.detail_type_tag.text
	print("✔ 雷霆之怒复合标签: ", fury_tag)
	assert("群伤 AoE (6目标)" in fury_tag, "雷霆之怒应明确标注群伤 AoE (6目标)！实际: " + fury_tag)
	assert("闪电" in fury_tag, "雷霆之怒应明确标注闪电伤害！实际: " + fury_tag)

	print("--- 技能面板多维复合特性标签与装备加成所有测试 100% 通过！ ---")
	panel.queue_free()
	quit(0)
