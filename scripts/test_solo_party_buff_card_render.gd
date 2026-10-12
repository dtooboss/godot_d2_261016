extends Control

## 测试单人常驻个人卡片、队伍状态、顶置血条与战吼倒计时渲染验证

@onready var party_hud: PartyHudPanel = $PartyHudPanel

func _ready() -> void:
	print("--- 开始测试单人卡片与时效战吼倒计时渲染 ---")
	
	# 1. 模拟单人状态与专注光环
	GameState.selected_character = {
		"id": "yy_001",
		"name": "YY",
		"class": "ama",
		"level": 27,
		"hp": 368,
		"max_hp": 378,
		"combat_power": 769,
		"equipped_aura": "concentration"
	}
	GameState.clear_team()
	
	party_hud.update_party([])
	
	assert(party_hud.visible == true, "单人状态下 Party HUD 个人卡片应常驻可见")
	assert(party_hud.member_cards.size() == 1, "应渲染 1 张个人状态卡片")
	
	var solo_card = party_hud.member_cards["yy_001"]
	var name_lbl = solo_card.find_child("NameLabel", true, false)
	assert("YY" in name_lbl.text, "角色名应为 YY")
	
	var lvl_lbl = solo_card.find_child("LevelLabel", true, false)
	assert("LV.27" in lvl_lbl.text, "等级应为 LV.27")
	
	var pwr_lbl = solo_card.find_child("PowerLabel", true, false)
	assert(pwr_lbl.text == "769", "战力应为 769")
	
	var buff_box = solo_card.find_child("BuffContainer", true, false)
	assert(buff_box.get_child_count() == 1, "应显示 1 个装备赋予的专注光环图标")
	print("✔ 单人模式常驻卡片验证通过: 姓名=YY, 等级=LV.27, 战力=769, 光环=专注")
	
	# 2. 模拟组队并带有战吼倒计时
	var team_data = [
		{
			"id": "yy_001",
			"name": "YY",
			"class": "ama",
			"level": 27,
			"hp": 368,
			"max_hp": 378,
			"power": 769,
			"is_leader": true,
			"buffs": [
				"concentration", # 永久光环
				{"id": "bo", "remain": 45, "level": 15} # 战吼：战斗体质，剩余 45 秒
			]
		},
		{
			"id": "barb_02",
			"name": "野蛮人·狂徒",
			"class": "bar",
			"level": 85,
			"hp": 2750,
			"max_hp": 3000,
			"power": 2450,
			"is_leader": false,
			"buffs": [
				{"id": "bo", "remain": 45, "level": 15},
				{"id": "bc", "remain": 115, "level": 1} # 战吼：战斗指挥，剩余 115 秒 (显示 2m)
			]
		}
	]
	
	GameState.update_team_data("yy_001", team_data)
	party_hud.update_party(team_data)
	
	assert(party_hud.member_cards.size() == 2, "组队模式应渲染 2 张卡片")
	
	var leader_card = party_hud.member_cards["yy_001"]
	var leader_buffs = leader_card.find_child("BuffContainer", true, false)
	assert(leader_buffs.get_child_count() == 2, "队长应包含 2 个增益徽章 (专注 + BO战吼)")
	
	var bo_badge = leader_buffs.get_child(1)
	assert(bo_badge.lbl_timer.text == "45", "BO 战吼角标应显示 45 秒倒计时")
	print("✔ 组队时效战吼验证通过: BO战吼角标倒计时呈现 = ", bo_badge.lbl_timer.text)

	var barb_card = party_hud.member_cards["barb_02"]
	var barb_pwr = barb_card.find_child("PowerLabel", true, false)
	assert(barb_pwr.text == "2.5k", "2450 战力应格式化为 2.5k")
	print("✔ 组队队员战力格式化验证通过: barb_02 战力 = ", barb_pwr.text)

	# 验证战力在第一行且第二行空给 Buff
	var solo_pwr_lbl = solo_card.find_child("PowerLabel", true, false)
	var solo_name_lbl = solo_card.find_child("NameLabel", true, false)
	assert(solo_pwr_lbl.get_parent().get_parent() == solo_name_lbl.get_parent(), "战力标签应与名字等级同在第一行")
	print("✔ 卡片两行布局验证通过: 战力升至第一行，第二行独立容纳 Buff 容器")
	
	# 等待 0.3 秒完成窗口绘制并截图
	await get_tree().create_timer(0.3).timeout
	_take_screenshot("test_compact_card_and_countdown_buff.png")
	
	print("🎉 单人常驻卡片与战吼倒计时所有测试用例 100% 通过！")
	get_tree().quit(0)

func _take_screenshot(filename: String) -> void:
	var viewport = get_viewport()
	if not viewport: return
	var tex = viewport.get_texture()
	if not tex: return
	var img = tex.get_image()
	if not img: return
	var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/b5309461-d440-459a-8a46-12eef9df4706/" + filename
	img.save_png(save_path)
	print("📸 实机渲染截图已保存至: ", save_path)
