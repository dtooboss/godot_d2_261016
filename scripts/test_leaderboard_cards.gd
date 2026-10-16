extends Control

## 自动化测试：暗黑哥特石质卡片式天梯英雄榜渲染与交互验证
const ARTIFACT_DIR = "C:/Users/Administrator/.gemini/antigravity/brain/ec019a2c-0e22-4c1e-a5f7-c8b6eefd70db"

@onready var hub = $TownHub

func _ready() -> void:
	print("==================================================")
	print("    D2 CARD-STYLE LEADERBOARD AUTOMATED TEST      ")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	# 1. 模拟当前玩家
	GameState.selected_character = {
		"name": "死灵法师阿道",
		"class": "nec",
		"class_name": "死灵法师",
		"level": 85,
		"gold": 500000,
		"difficulty": "hell"
	}
	GameState.selected_difficulty = "hell"
	hub._init_player_ui()

	print("Step 1: 打开天梯排行榜弹窗...")
	hub._open_leaderboard()
	for i in range(5):
		await get_tree().process_frame

	if not hub.leaderboard_modal.visible:
		print("❌ 天梯排行榜弹窗未正常弹出!")
		get_tree().quit(1)
		return
	print("  ✅ 天梯排行榜弹窗弹出成功！")

	print("Step 2: 注入多维度加权天梯结构化协议数据 (涵盖地狱/噩梦/普通各难度与7大职业)...")
	var mock_ladder_data = {
		"my_rank": 0,
		"is_wiz": true,
		"list": [
			{
				"rank": 1, "char_id": "necro_shadow", "name": "死灵统领暗影",
				"class": "nec", "class_name": "死灵法师", "level": 85, "exp_pct": "74.5",
				"diff": "hell", "diff_name": "地狱", "stage_id": 81, "stage_name": "毁灭王座",
				"rating": 2850, "ladder_score": 3818574
			},
			{
				"rank": 2, "char_id": "lili_sor", "name": "冰雷法神莉莉丝",
				"class": "sor", "class_name": "魔法使", "level": 82, "exp_pct": "35.2",
				"diff": "hell", "diff_name": "地狱", "stage_id": 78, "stage_name": "混沌避难所",
				"rating": 2620, "ladder_score": 3788235
			},
			{
				"rank": 3, "char_id": "arthur_pal", "name": "圣堂圣骑亚瑟",
				"class": "pal", "class_name": "圣骑士", "level": 80, "exp_pct": "91.0",
				"diff": "hell", "diff_name": "地狱", "stage_id": 65, "stage_name": "哈洛加斯要塞",
				"rating": 2490, "ladder_score": 3658091
			},
			{
				"rank": 4, "char_id": "conan_bar", "name": "旋风狂战柯南",
				"class": "bar", "class_name": "野蛮人", "level": 75, "exp_pct": "58.4",
				"diff": "nm", "diff_name": "噩梦", "stage_id": 81, "stage_name": "毁灭王座",
				"rating": 2180, "ladder_score": 1817558
			},
			{
				"rank": 5, "char_id": "shadow_asn", "name": "影袭刺客夜刃",
				"class": "asn", "class_name": "刺客", "level": 71, "exp_pct": "12.8",
				"diff": "nm", "diff_name": "噩梦", "stage_id": 70, "stage_name": "水晶通道",
				"rating": 1950, "ladder_score": 1707112
			},
			{
				"rank": 6, "char_id": "malfurion_dru", "name": "野性德鲁伊玛法",
				"class": "dru", "class_name": "德鲁伊", "level": 55, "exp_pct": "84.0",
				"diff": "normal", "diff_name": "普通", "stage_id": 81, "stage_name": "毁灭王座",
				"rating": 1620, "ladder_score": 815584
			},
			{
				"rank": 7, "char_id": "wind_ama", "name": "风之弓手艾尔温",
				"class": "ama", "class_name": "亚马逊", "level": 48, "exp_pct": "46.2",
				"diff": "normal", "diff_name": "普通", "stage_id": 56, "stage_name": "神圣避难所",
				"rating": 1340, "ladder_score": 564846
			}
		]
	}

	hub._on_json_frame_received("leaderboard", mock_ladder_data)
	for i in range(10):
		await get_tree().process_frame

	print("Step 2.1: 验证 GM/巫师账号排位展示状态...")
	var rank_title = hub.leaderboard_modal.get_node("CenterContainer/Panel/VBox/RankTitle").text
	if not ("GM巫师" in rank_title or "不参与排名" in rank_title):
		print("❌ GM账号排位提示异常: %s" % rank_title)
		get_tree().quit(1)
		return
	print("  ✅ 成功验证 GM/巫师账号专属不参与排名提示: %s" % rank_title)

	var card_count = hub.rank_list_vbox.get_child_count()
	print("Step 3: 检查卡片生成数量: %d" % card_count)
	if card_count != 7:
		print("❌ 天梯卡片生成数量异常: 期望 7, 实际 %d" % card_count)
		get_tree().quit(1)
		return
	print("  ✅ 成功生成 7 张高质感天梯卡片！")

	print("Step 4: 测试卡片点击锁定与 Build 预留扩展逻辑...")
	var first_card = hub.rank_list_vbox.get_child(0)
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	first_card.gui_input.emit(click_event)
	
	for i in range(5):
		await get_tree().process_frame

	if hub.selected_ladder_hero.get("char_id", "") != "necro_shadow":
		print("❌ 点击卡片后角色选定状态异常!")
		get_tree().quit(1)
		return
	print("  ✅ 点击卡片成功锁定选定英雄: %s, 预留接口就绪！" % hub.selected_ladder_hero.get("name"))

	print("Step 5: 截取实机卡片式天梯渲染高清图像...")
	for i in range(10):
		await get_tree().process_frame
		
	var tex = get_viewport().get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			var shot_path = ARTIFACT_DIR + "/leaderboard_cards_full.png"
			var err = img.save_png(shot_path)
			if err == OK:
				print("  ✅ 成功输出实机截图: %s" % shot_path)
			else:
				print("  ⚠️ 截图保存失败，错误码: %d" % err)
		else:
			print("  ℹ️ Headless 模式下无视口图像缓冲，跳过保存截图")
	else:
		print("  ℹ️ Headless 模式下无纹理缓冲，跳过保存截图")

	print("==================================================")
	print("       ALL LEADERBOARD CARD TESTS PASSED!         ")
	print("==================================================")
	get_tree().quit(0)
