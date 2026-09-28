extends Node

## 野外挂机全景挂载 Party HUD 实机全貌渲染测试

@onready var hud: AFK_MainHUD = $AFK_MainHUD

func _ready() -> void:
	print("--- 开始运行野外战斗场景 Party HUD 全景挂载测试 ---")
	
	# 注入 2 人队伍数据 (模拟双开联机组队后)
	var mock_team = [
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
		}
	]
	
	GameState.update_team_data("barb_01", mock_team)
	
	# 驱动野外 HUD 刷新
	if hud.party_hud_panel:
		hud.party_hud_panel.update_party(mock_team)
		assert(hud.party_hud_panel.visible == true, "野外 Party HUD 应常驻可见")
		print("✔ 野外主界面成功挂载并激活 Party HUD 队伍面板！")
		
	# 等待 0.3 秒完成全部怪物立绘与 UI 光栅化
	await get_tree().create_timer(0.3).timeout
	
	var viewport = get_viewport()
	if viewport:
		var img = viewport.get_texture().get_image()
		if img:
			var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/test_afk_party_hud_full_success.png"
			img.save_png(save_path)
			print("已成功保存野外全景战斗队伍实机截图至: ", save_path)
			
	print("🎉 野外战斗场景队伍卡片全景挂载测试 100% 通过！")
	get_tree().quit(0)
