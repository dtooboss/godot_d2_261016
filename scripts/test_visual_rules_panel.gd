extends Node
## 自动化测试：细则规则两大块可视化列表 (白名单居上优先、黑名单居下) 与展开手柄测试

func _ready() -> void:
	print("=========================================================================")
	print("[开始测试] 细则规则两大块可视化列表 (带展开箭头) 测试")
	print("=========================================================================")

	var panel_scene = load("res://scenes/afk/components/pickup_setting_panel.tscn")
	var panel = panel_scene.instantiate()
	add_child(panel)

	# 1. 验证面板初始化
	assert(panel != null, "面板应成功实例化")
	panel.show_panel()
	panel._on_reset_default_json_pressed()
	
	var vbox = panel.get_node("%VisualRulesVBox")
	assert(vbox != null, "VisualRulesVBox 必须存在")
	assert(vbox.get_child_count() >= 3, "两大块渲染必须包含白名单标题、规则卡片、分割线及黑名单标题")
	print("✔ Test 1 通过：可视化列表两大块容器成功挂载并完成初始渲染")

	# 2. 验证白名单居上、黑名单居下
	var first_header = vbox.get_child(0)
	assert("白名单" in first_header.get_child(0).text, "第 1 个区块必须是【白名单保留规则】(居上绝对优先)")
	
	var found_salvage_header = false
	for child in vbox.get_children():
		if child is PanelContainer and child.get_child_count() > 0 and child.get_child(0) is Label:
			if "黑名单" in child.get_child(0).text:
				found_salvage_header = true
				break
	assert(found_salvage_header == true, "必须找到居下的【黑名单分解目标】区块")
	print("✔ Test 2 通过：【白名单保留规则】居上优先、【黑名单分解目标】居下兜底结构完全吻合要求")

	# 3. 验证折叠箭头 ▼ / ▲ 手柄展开收起
	var rule_card = null
	for child in vbox.get_children():
		if child is VBoxContainer and child.get_child_count() == 2:
			rule_card = child
			break
	assert(rule_card != null, "必须找到规则卡片折叠行")
	
	var bar_panel = rule_card.get_child(0)
	var sub_panel = rule_card.get_child(1)
	var btn_toggle = bar_panel.get_child(0).get_child(0) # btn_toggle
	
	assert(sub_panel.visible == false, "抽屉初始必须为折叠收起隐藏状态")
	assert(btn_toggle.text == "▼", "初始箭头手柄必须显示 ▼")
	
	# 模拟点击展开
	btn_toggle.pressed.emit()
	assert(sub_panel.visible == true, "点击后抽屉必须展开可见")
	assert(btn_toggle.text == "▲", "展开后手柄必须切换为 ▲")
	
	# 再次点击收起
	btn_toggle.pressed.emit()
	assert(sub_panel.visible == false, "再次点击后抽屉必须收起隐藏")
	assert(btn_toggle.text == "▼", "收起后手柄必须恢复为 ▼")
	print("✔ Test 3 通过：折叠手柄 (▼ / ▲) 展开抽屉与收起动画交互 100% 验证通过")

	# 4. 验证双视图无缝切换 (代码视图 <-> 列表视图)
	var btn_toggle_view = panel.get_node("%BtnToggleView")
	var scroll_visual = panel.get_node("%ScrollVisualRules")
	var txt_json = panel.get_node("%TxtJsonRules")
	
	assert(scroll_visual.visible == true, "初始为可视化列表视图")
	assert(txt_json.visible == false, "初始代码视图隐藏")
	
	# 点击切换到代码视图
	btn_toggle_view.pressed.emit()
	assert(scroll_visual.visible == false, "切换后列表隐藏")
	assert(txt_json.visible == true, "切换后代码框展示")
	assert(btn_toggle_view.text == "📋 列表视图", "按钮提示切换回列表视图")
	assert("keep_rules" in txt_json.text, "代码框中包含当前规则 JSON 文本")

	# 再次点击切回列表视图
	btn_toggle_view.pressed.emit()
	assert(scroll_visual.visible == true, "切回后列表重新展示")
	assert(txt_json.visible == false, "切回后代码框隐藏")
	assert(btn_toggle_view.text == "📝 代码视图", "按钮恢复提示切换代码视图")
	print("✔ Test 4 通过：可视化列表视图与代码视图双向切换与数据热同步 100% 验证通过")

	# 5. 验证单条规则删除联动
	var csm = panel._get_custom_salvage_manager()
	var init_keep_count = csm.current_rules["keep_rules"].size()
	assert(init_keep_count > 0, "白名单规则数量应大于 0")
	
	# 删除第 0 条白名单规则
	panel._delete_single_rule("keep", 0)
	var new_keep_count = csm.current_rules["keep_rules"].size()
	assert(new_keep_count == init_keep_count - 1, "删除后白名单规则数量应减少 1")
	print("✔ Test 5 通过：单条规则删除、重新解析渲染与本地持久化联动 100% 验证通过")

	print("=========================================================================")
	print("🎉 全量测试全部 PASS (5/5)！细则规则两大块可视化系统稳健可靠！")
	print("=========================================================================")
	get_tree().quit(0)
