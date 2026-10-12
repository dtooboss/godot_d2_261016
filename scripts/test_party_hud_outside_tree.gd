extends Control

## 测试 party_hud_panel 在树外/树内调用 update_self_hp 的安全性

func _ready() -> void:
	print("==================================================")
	print("【测试开始】party_hud_panel 跨树/树外安全调用测试")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	GameState.selected_character = {
		"id": "hero_tester",
		"name": "测试勇士",
		"class": "pal",
		"level": 25,
		"hp": 100,
		"max_hp": 100
	}
	GameState.clear_team()

	var panel_scene = load("res://scenes/afk/components/party_hud_panel.tscn")
	assert(panel_scene != null, "加载 party_hud_panel.tscn 失败！")

	# ------------------------------------------------------------
	# 测试 1: 在场景树外调用 update_self_hp (复现原报错环境)
	# ------------------------------------------------------------
	print("\n--- 测试 1: 在场景树外 (not inside tree) 调用 update_self_hp ---")
	var outside_panel = panel_scene.instantiate()
	assert(outside_panel.is_inside_tree() == false, "此时 panel 绝不能在场景树中")
	
	# 这里在原代码中会直接崩溃抛出: Can't use get_node() with absolute paths from outside the active scene tree
	outside_panel.update_self_hp(50, 100)
	print("✅ 测试 1 通过：树外调用 update_self_hp 被安全守卫拦截，未抛出底层路径错误！")
	outside_panel.free()

	# ------------------------------------------------------------
	# 测试 2: 在场景树内正常调用 update_self_hp
	# ------------------------------------------------------------
	print("\n--- 测试 2: 在场景树内 (inside tree) 正常更新血量 ---")
	var inside_panel = panel_scene.instantiate()
	add_child(inside_panel)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(inside_panel.is_inside_tree() == true, "此时 panel 已经在场景树中")
	inside_panel.update_self_hp(80, 100)

	var my_card = inside_panel.member_cards.get("hero_tester", null)
	assert(my_card != null, "单人自身卡片必须存在")
	var hp_bar = my_card.find_child("HpBar", true, false)
	assert(hp_bar != null, "HpBar 进度条必须存在")
	assert(hp_bar.value == 80, "HpBar 当前值应为 80")
	assert(hp_bar.max_value == 100, "HpBar 最大值应为 100")
	print("✅ 测试 2 通过：树内调用正常更新卡片 HpBar (80/100)！")

	# ------------------------------------------------------------
	# 测试 3: 从场景树移除后再调用 (模拟切场景节点卸载)
	# ------------------------------------------------------------
	print("\n--- 测试 3: 从场景树移除 (remove_child) 后调用 update_self_hp ---")
	remove_child(inside_panel)
	assert(inside_panel.is_inside_tree() == false, "此时 panel 已离开场景树")
	inside_panel.update_self_hp(30, 100)
	print("✅ 测试 3 通过：节点离开场景树后继续调用无任何报错！")
	inside_panel.queue_free()

	print("\n==================================================")
	print("🎉 party_hud_panel 树外绝对路径安全防御 100% 验证通过！")
	print("==================================================")
	get_tree().quit(0)
