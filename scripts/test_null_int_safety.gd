extends Control

func _ready() -> void:
	print("==================================================")
	print("   START NULL INT CONSTRUCTOR DEFENSE TEST        ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Test 1: 验证 PlayerInventoryPanel extra_info 包含 null 时的安全解析
	# ----------------------------------------------------
	print("\n[Test 1] 验证 PlayerInventoryPanel 抵御 null gold...")
	var inv_scene = load("res://scenes/afk/components/player_inventory_panel.tscn")
	var inv = inv_scene.instantiate()
	add_child(inv)
	await get_tree().process_frame

	var mock_extra_null = {
		"gold": null,
		"unlocked_pages": null,
		"max_pages": null,
		"extend_cost": null
	}
	# 调用 render_lpc_items，必须安全执行，绝不能抛出 Nonexistent 'int' constructor
	inv.render_lpc_items([], -1, 40, 1, 1, mock_extra_null)
	assert(inv.current_player_gold == 0, "null 金币必须安全转为 0")
	assert(inv.unlocked_pages == 1, "null 解锁页数必须安全转为默认值 1")
	assert(inv.max_bag_pages == 4, "null 最大页数必须安全转为默认值 4")
	assert(inv.extend_cost == 0, "null 扩充花费必须安全转为默认值 0")
	print("✔ Test 1 通过: 背包面板完美抵御 null gold 与扩展参数！")

	inv.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 2: 验证 GShopPanel 抵御 null gold
	# ----------------------------------------------------
	print("\n[Test 2] 验证 GShopPanel 抵御 null gold...")
	var shop = AFK_GShopPanel.new()
	add_child(shop)
	await get_tree().process_frame

	var mock_shop_null = {
		"gold": null,
		"difficulty": "normal",
		"items": []
	}
	shop.update_shop_data(mock_shop_null)
	assert(shop.current_gold == 0, "null 商店金币必须安全转为 0")
	print("✔ Test 2 通过: 商店面板完美抵御 null gold！")

	shop.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 3: 验证 TownHubController 抵御 stage_info null
	# ----------------------------------------------------
	print("\n[Test 3] 验证 TownHubController 抵御 stage_info 与初始 cdata 中的 null...")
	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	add_child(town)
	await get_tree().process_frame

	var mock_stage_null = {
		"max_stage": null,
		"selected_stage": null,
		"worlds": [1, 2],
		"selected_act": "act1"
	}
	# 调用 _on_json_frame_received("stage_info", ...)
	town._on_json_frame_received("stage_info", mock_stage_null)
	assert(GameState.player_max_stage == 0, "null max_stage 必须安全转为 0")
	assert(GameState.selected_stage_id == 1, "null selected_stage 必须安全转为默认 1")
	print("✔ Test 3 通过: 城镇大厅完美抵御 stage_info null 关卡！")

	town.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 4: 验证 CharacterCard 与 CharacterSelect 面板抵御 null cdata
	# ----------------------------------------------------
	print("\n[Test 4] 验证 CharacterCard 与 CharacterSelect 抵御 null 属性...")
	var card_scene = load("res://scenes/lobby/character_card.tscn")
	var card = card_scene.instantiate()
	add_child(card)
	await get_tree().process_frame

	var mock_null_char = {
		"char_id": "char_999",
		"name": "测试null",
		"class": "bar",
		"level": null,
		"life": null,
		"mana": null,
		"str": null,
		"dex": null,
		"vit": null,
		"int": null,
		"unlocked_diff": null
	}
	card.setup(mock_null_char, false)
	assert(card.class_level_label.text.begins_with("Lv.1"), "null level 必须安全转为 1")
	print("✔ Test 4.1 通过: CharacterCard 完美防御 null 角色属性！")
	card.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 5: 验证 SkillPanel 抵御 null 技能点与技能节点
	# ----------------------------------------------------
	print("\n[Test 5] 验证 AFK_SkillPanel 抵御 null skill_points 与技能节点...")
	var skill_panel_scene = load("res://scenes/afk/components/skill_panel.tscn")
	var skill_panel = skill_panel_scene.instantiate()
	add_child(skill_panel)
	await get_tree().process_frame

	var mock_null_skills = {
		"class": "sor",
		"class_name": "巫师",
		"skill_points": null,
		"tabs": [
			{"page": null, "name": "火焰", "points_spent": null}
		],
		"skills": {
			"fire_bolt": {
				"code": "fire_bolt",
				"name": "火焰弹",
				"page": null,
				"row": null,
				"col": null,
				"cur_lvl": null,
				"req_level": null,
				"eff_lvl": null
			}
		}
	}
	skill_panel.render_gskills_data(mock_null_skills)
	print("✔ Test 5 通过: AFK_SkillPanel 完美防御 null 技能树数据！")
	skill_panel.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# Test 6: 验证 WorldMap 抵御 null stage_info 与 spot_data
	# ----------------------------------------------------
	print("\n[Test 6] 验证 WorldMap 抵御 null stage_id 与 act...")
	var world_map_scene = load("res://scenes/afk/world_map/world_map.tscn")
	var world_map = world_map_scene.instantiate()
	add_child(world_map)
	await get_tree().process_frame

	GameState.current_stage_info = {"act": null, "stage": null}
	GameState.selected_character = {"unlocked_diff": null}
	world_map._auto_locate_act()
	world_map.update_progress(0)
	world_map._on_spot_clicked({"unlocked": true, "name": "鲜血荒地", "stage_id": null})
	print("✔ Test 6 通过: WorldMap 完美防御 null 关卡与难度！")
	world_map.queue_free()
	await get_tree().process_frame

	print("\n==================================================")
	print("  CONGRATULATIONS: ALL NULL SAFETY TESTS OK!      ")
	print("==================================================")
	get_tree().quit(0)
