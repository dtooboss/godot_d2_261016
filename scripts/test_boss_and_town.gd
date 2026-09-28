extends Control

func _ready() -> void:
	print("==================================================")
	print("   START BOSS PROGRESS & TOWN REVIVAL UNIT TEST   ")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)

	await get_tree().process_frame

	# Test 1: 正常挂机野外阶段进度解析 (15 斩标准)
	var wild_stage_data = {
		"stage": {
			"stage_id": 1,
			"stage_name": "鲜血荒地",
			"difficulty": "normal",
			"alvl": 2,
			"kill_step": 3,
			"threshold": 15,
			"boss_active": 0,
			"is_town": 0
		},
		"monsters": []
	}
	hud._handle_gstatus_data(wild_stage_data)
	await get_tree().process_frame

	assert(hud.current_boss_kills == 3, "当前击杀步进应为 3！")
	assert(hud.max_boss_kills == 15, "Boss 门槛上限应为 15！")
	assert(hud.boss_progress_label.text == "BOSS进度: (3/15) 20%", "Boss 进度文本应精准呈现为 (3/15) 20%！当前为: " + hud.boss_progress_label.text)
	assert(int(hud.boss_progress_bar.value) == 20, "Boss 进度条值应为 20！")
	print("✔ Test 1: Wild stage boss progress (3/15, 20%) verified successfully!")

	# Test 2: 城镇安全区防御——绝不能出现 (0/1)
	var town_data = {
		"stage": {
			"stage_id": 0,
			"stage_name": "城镇安全区",
			"difficulty": "normal",
			"alvl": 1,
			"kill_step": 0,
			"threshold": 0,
			"boss_active": 0,
			"is_town": 1
		},
		"monsters": []
	}
	hud._handle_gstatus_data(town_data)
	await get_tree().process_frame

	assert(not ("(0/1)" in hud.boss_progress_label.text), "在城镇安全区严禁出现 (0/1) 荒谬显示！当前为: %s" % hud.boss_progress_label.text)
	assert("安全营地" in hud.boss_progress_label.text or "休整" in hud.boss_progress_label.text, "安全区应显示营地休整提示！当前为: %s" % hud.boss_progress_label.text)
	assert(hud.boss_progress_bar.value == 0, "安全区进度条应归零！")
	assert(hud._is_returning_to_town == true, "安全区必须标记 _is_returning_to_town 状态！")
	print("✔ Test 2: Town safe zone verified - (0/1) eliminated, camp status active!")

	# Test 3: 角色阵亡救助帧 (player_death_revive)
	var revive_packet = {
		"type": "player_death_revive",
		"data": {
			"town": "/d/act1/rogue_camp",
			"msg": "你在战斗中力竭倒地，已被修女与卫队救回营地大本营！"
		}
	}
	hud._on_network_json("player_death_revive", revive_packet["data"])
	await get_tree().process_frame

	assert(hud._monster_instances.is_empty(), "阵亡救回时战场实体必须完全清空！")
	assert(hud._occupied_slots.is_empty(), "阵亡救回时槽位必须完全释放！")
	print("✔ Test 3: Player death revival event & clean battlefield verified!")

	print("==================================================")
	print("     ALL BOSS & TOWN TESTS PASSED SUCCESSFULLY!   ")
	print("==================================================")
	get_tree().quit(0)
