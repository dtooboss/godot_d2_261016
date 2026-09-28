extends Node

## 野外挂机队伍卡片 (Party HUD) 与队长带队协同自动化测试

@onready var party_hud: Control = $PartyHudPanel
var test_team_received: Array = []

func _ready() -> void:
	print("--- 开始运行野外挂机队伍卡片与协同测试 ---")
	
	# 1. 模拟全队 3 名队员数据 (队长野蛮人、法师、圣骑士)
	var mock_members = [
		{
			"id": "barb_01",
			"name": "野蛮人·旋风狂人",
			"class": "bar",
			"level": 85,
			"hp": 2800,
			"max_hp": 3000,
			"is_leader": true,
			"buffs": ["fanaticism", "bo"]
		},
		{
			"id": "sorc_02",
			"name": "法师·冰雪之灵",
			"class": "sor",
			"level": 82,
			"hp": 950,
			"max_hp": 1100,
			"is_leader": false,
			"buffs": ["fanaticism"]
		},
		{
			"id": "pal_03",
			"name": "圣骑士·圣堂武士",
			"class": "pal",
			"level": 80,
			"hp": 1850,
			"max_hp": 2000,
			"is_leader": false,
			"buffs": ["fanaticism", "holy_shield"]
		}
	]
	
	# 2. 验证 GameState 队伍数据更新与信号
	GameState.team_updated.connect(func(members):
		test_team_received = members
	)
	GameState.update_team_data("barb_01", mock_members)
	
	assert(GameState.is_in_team == true, "GameState 应处于组队状态")
	assert(test_team_received.size() == 3, "GameState 接收到的全队成员应为 3 人")
	print("✔ GameState 全局队伍状态管理与信号广播正常")
	
	# 3. 驱动 PartyHudPanel 进行渲染
	party_hud.update_party(mock_members)
	assert(party_hud.visible == true, "处于队伍中时 Party HUD 应保持常驻可见")
	
	var cards = party_hud.member_list_vbox.get_children()
	assert(cards.size() == 3, "Party HUD 应渲染出 3 张队员卡片")
	print("✔ Party HUD 队员卡片列表构建正常: 渲染出 %d 张卡片" % cards.size())
	
	# 4. 验证队长皇冠勋章与名字渲染
	var first_card = cards[0]
	var name_lbl = first_card.find_child("NameLabel", true, false)
	assert(name_lbl != null, "卡片中应包含 NameLabel")
	assert("👑" in name_lbl.text, "队长卡片应标注 👑 金色皇冠勋章")
	assert("旋风狂人" in name_lbl.text, "队长卡片姓名应正确呈现")
	print("✔ 队长金色皇冠勋章与角色名渲染正常: ", name_lbl.text)
	
	# 5. 验证动态血条渲染
	var hp_bar = first_card.find_child("HpBar", true, false)
	assert(hp_bar != null, "卡片中应包含实时生命值血条 HpBar")
	assert(hp_bar.max_value == 3000, "血条最大值应为 3000")
	assert(hp_bar.value == 2800, "血条当前值应为 2800")
	print("✔ 动态实时生命值血条渲染正常: %d / %d" % [hp_bar.value, hp_bar.max_value])
	
	# 6. 验证右侧横向 Buff 小图标容器 (黄金规范：垂直高度严格固定)
	var buff_box = first_card.find_child("BuffContainer", true, false)
	assert(buff_box != null, "卡片右侧应紧邻横向 BuffContainer")
	assert(buff_box.get_child_count() == 2, "队长应横向展开 2 个 Buff 小图标 (狂热与战吼)")
	assert(first_card.custom_minimum_size.y == 44, "卡片垂直高度严格锁定为 44px，杜绝跳动")
	print("✔ 卡片右侧横向延伸 Buff 小图标容器验证正常: 图标数=%d, 卡片高=%.0fpx" % [buff_box.get_child_count(), first_card.custom_minimum_size.y])
	
	# 等待 0.2 秒以完成真实渲染并采集实机画面
	await get_tree().create_timer(0.2).timeout
	_take_screenshot("test_party_hud_battle_card_success.png")
	
	print("🎉 野外挂机队伍卡片与协同出征所有自动化测试用例均 100% 通过！")
	get_tree().quit(0)

func _take_screenshot(filename: String) -> void:
	var viewport = get_viewport()
	if not viewport: return
	var tex = viewport.get_texture()
	if not tex: return
	var img = tex.get_image()
	if not img:
		print("当前处于 headless 模式，跳过截图采集")
		return
	var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/" + filename
	img.save_png(save_path)
	print("已保存实机渲染截图至: ", save_path)
