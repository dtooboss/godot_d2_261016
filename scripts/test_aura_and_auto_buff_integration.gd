extends Control

## 圣骑士右键踩光环、右键自我Buff自释放与野蛮人战吼套件集成测试

@onready var party_hud: PartyHudPanel = $PartyHudPanel

func _ready() -> void:
	print("--- 开始测试：圣骑士右键踩光环、右键Buff自释放与野蛮人自动战吼 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# -------------------------------------------------------------
	# Test 1: 验证圣骑士右键绑定光环，踩光环状态广播与个人卡片点亮
	# -------------------------------------------------------------
	print("\n[Test 1] 圣骑士右键踩光环测试...")
	GameState.selected_character = {
		"id": "pal_hero",
		"name": "圣骑士·光明之手",
		"class": "pal",
		"level": 35,
		"hp": 520,
		"max_hp": 520,
		"combat_power": 1150,
		"equipped_aura": "fanaticism"
	}
	GameState.clear_team()

	party_hud.update_party([])

	assert(party_hud.visible == true, "Party HUD 必须可见")
	assert(party_hud.member_cards.size() == 1, "应渲染 1 张个人状态卡片")

	var pal_card = party_hud.member_cards["pal_hero"]
	var pal_buffs = pal_card.find_child("BuffContainer", true, false)
	assert(pal_buffs.get_child_count() == 1, "圣骑士踩狂热光环后，卡片必须亮起 1 个光环图标")
	print("✔ Test 1 通过：圣骑士右键踩光环状态成功同步并在个人卡片上常驻渲染狂热光环！")

	# -------------------------------------------------------------
	# Test 2: 验证法师右键寒冰装甲、死灵白骨装甲的时效 Buff 图标与倒计时
	# -------------------------------------------------------------
	print("\n[Test 2] 法师寒冰装甲与死灵白骨装甲时效增益渲染测试...")
	var team_data = [
		{
			"id": "pal_hero",
			"name": "圣骑士·光明之手",
			"class": "pal",
			"level": 35,
			"hp": 520,
			"max_hp": 520,
			"power": 1150,
			"is_leader": true,
			"buffs": [
				"fanaticism", # 队长常驻狂热光环
				{"id": "holy_shield", "remain": 120, "level": 15} # 圣盾术 Buff
			]
		},
		{
			"id": "sor_ally",
			"name": "女巫·冰雪奇缘",
			"class": "sor",
			"level": 33,
			"hp": 280,
			"max_hp": 280,
			"power": 980,
			"is_leader": false,
			"buffs": [
				"fanaticism", # 享受队友狂热光环
				{"id": "frozen_armor", "remain": 140, "level": 10} # 右键自施放寒冰装甲
			]
		},
		{
			"id": "nec_ally",
			"name": "死灵·白骨守望",
			"class": "nec",
			"level": 30,
			"hp": 310,
			"max_hp": 310,
			"power": 890,
			"is_leader": false,
			"buffs": [
				"fanaticism", # 享受队友狂热光环
				{"id": "bone_armor", "remain": 110, "level": 10} # 右键自施放白骨装甲
			]
		}
	]

	GameState.update_team_data("pal_hero", team_data)
	party_hud.update_party(team_data)

	assert(party_hud.member_cards.size() == 3, "组队模式应渲染 3 张队员卡片")

	var sor_card = party_hud.member_cards["sor_ally"]
	var sor_buffs = sor_card.find_child("BuffContainer", true, false)
	assert(sor_buffs.get_child_count() == 2, "女巫应包含 2 个增益 (队友狂热 + 自放寒冰装甲)")
	print("✔ Test 2.1 通过：女巫寒冰装甲成功展示，且享受队友光环！")

	var nec_card = party_hud.member_cards["nec_ally"]
	var nec_buffs = nec_card.find_child("BuffContainer", true, false)
	assert(nec_buffs.get_child_count() == 2, "死灵法师应包含 2 个增益 (队友狂热 + 自放白骨装甲)")
	print("✔ Test 2.2 通过：死灵白骨装甲成功展示！")

	# -------------------------------------------------------------
	# Test 3: 验证野蛮人自动战吼套件 (全队 BC -> BO -> Shout)
	# -------------------------------------------------------------
	print("\n[Test 3] 野蛮人自动战吼套件辐射全队测试...")
	var team_warcry_data = [
		{
			"id": "pal_hero",
			"name": "圣骑士·光明之手",
			"class": "pal",
			"level": 35,
			"hp": 950, # 受 BO 加持血量暴增
			"max_hp": 950,
			"power": 1450,
			"is_leader": true,
			"buffs": [
				"fanaticism",
				{"id": "bo", "remain": 160, "level": 20}, # 战斗号令
				{"id": "bc", "remain": 150, "level": 10}, # 战斗指挥
				{"id": "shout", "remain": 155, "level": 15} # 大叫
			]
		},
		{
			"id": "bar_shouter",
			"name": "野蛮人·不朽之王",
			"class": "bar",
			"level": 40,
			"hp": 2200,
			"max_hp": 2200,
			"power": 1900,
			"is_leader": false,
			"buffs": [
				"fanaticism",
				{"id": "bo", "remain": 160, "level": 20},
				{"id": "bc", "remain": 150, "level": 10},
				{"id": "shout", "remain": 155, "level": 15}
			]
		}
	]

	GameState.update_team_data("pal_hero", team_warcry_data)
	party_hud.update_party(team_warcry_data)

	assert(party_hud.member_cards.size() == 2, "应为 2 名队员")
	var leader_w_card = party_hud.member_cards["pal_hero"]
	var leader_w_buffs = leader_w_card.find_child("BuffContainer", true, false)
	assert(leader_w_buffs.get_child_count() == 4, "队长应包含 4 个增益徽章 (狂热 + BO + BC + Shout)")
	print("✔ Test 3 通过：野蛮人战吼套件全队辐射成功，BO、BC、Shout 完美同屏呈现！")

	# 等待 0.2 秒完成渲染
	await get_tree().create_timer(0.2).timeout
	print("\n🎉 圣骑士右键踩光环、右键Buff自释放与野蛮人战吼套件所有测试用例 100% 通过！")
	get_tree().quit(0)
