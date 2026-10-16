extends Control
## 验证 Buff 勋章图标真实贴图加载与自适应兜底

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("--- 开始测试：BuffBadgeNode 真实图片资源加载与自适应兜底 ---")
	var party_hud_scene = load("res://scenes/afk/components/party_hud_panel.tscn")
	assert(party_hud_scene != null, "必须成功加载 party_hud_panel 场景")
	
	var party_hud = party_hud_scene.instantiate()
	add_child(party_hud)
	
	var test_buffs_sor = [
		{"id": "frozen_armor", "remain": 120, "level": 2},
		{"id": "shiver_armor", "remain": 110, "level": 3},
		{"id": "chilling_armor", "remain": 100, "level": 1},
		{"id": "energy_shield", "remain": 90, "level": 4},
		{"id": "thunder_storm", "remain": 89, "level": 10},
		{"id": "enchant", "remain": 180, "level": 20}
	]
	
	var test_buffs_bar = [
		{"id": "shout", "remain": 150, "level": 5},
		{"id": "battle_orders", "remain": 140, "level": 10},
		{"id": "battle_command", "remain": 130, "level": 1},
		{"id": "holy_shield", "remain": 120, "level": 8},
		{"id": "bone_armor", "remain": 300, "level": 5},
		{"id": "cyclone_armor", "remain": 120, "level": 10},
		{"id": "quickness", "remain": 120, "level": 15},
		{"id": "fade", "remain": 120, "level": 12},
		{"id": "venom", "remain": 120, "level": 20},
		{"id": "fanaticism", "level": 20},
		{"id": "concentration", "level": 15}
	]
	
	var team_data = [
		{
			"id": "hero_sor",
			"name": "冰雷大法师",
			"class": "sor",
			"level": 30,
			"hp": 600,
			"max_hp": 600,
			"power": 1200,
			"is_leader": true,
			"buffs": test_buffs_sor
		},
		{
			"id": "hero_bar",
			"name": "旋风野蛮人",
			"class": "bar",
			"level": 30,
			"hp": 1200,
			"max_hp": 1200,
			"power": 1500,
			"is_leader": false,
			"buffs": test_buffs_bar
		}
	]
	
	party_hud.update_party(team_data)
	assert(party_hud.member_cards.has("hero_sor"), "必须存在 hero_sor 卡片")
	assert(party_hud.member_cards.has("hero_bar"), "必须存在 hero_bar 卡片")
	
	for mid in ["hero_sor", "hero_bar"]:
		var card = party_hud.member_cards[mid]
		var buff_box = card.find_child("BuffContainer", true, false)
		assert(buff_box != null, "卡片必须包含 BuffContainer")
		
		# 关键核心断言：每一个 Buff 勋章的 icon_rect.texture 绝不能为 null！
		for child in buff_box.get_children():
			var badge = child
			var b_id = badge.buff_id
			assert(badge.icon_rect != null, "勋章必须包含 icon_rect")
			assert(badge.icon_rect.texture != null, "Buff [%s] 必须成功加载到真实 Texture 贴图，绝不能为 null！" % b_id)
			print("✔ 角色 [%s] 的 Buff [%s] 贴图校验通过: %s" % [mid, b_id, badge.icon_rect.texture.resource_path])
			if b_id == "thunder_storm":
				assert("雷暴术" in badge.tooltip_text, "雷暴术 tooltip 必须包含中文名称【雷暴术】")
				print("✔ 雷暴术 tooltip 校验通过: %s" % badge.tooltip_text.split("\n")[0])
		
	print("\n🎉🎉🎉 客户端所有时效 Buff 与光环贴图全部 100% 成功加载渲染！🎉🎉🎉")
	get_tree().quit(0)
