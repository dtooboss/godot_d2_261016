extends SceneTree

## 战利品横幅由服务端权威裁决 (show_banner) 自动化测试
## 验证药水等普通物品 (show_banner == 0) 不弹出横幅 Tooltip，暗金等神装 (show_banner == 1) 弹出

func _init() -> void:
	print("==================================================")
	print("【自动化测试开始】掉落 Tooltip 横幅按服务端权限裁决验证")
	print("==================================================")
	_run_tests()

func _run_tests() -> void:
	await process_frame

	var root_control = Control.new()
	root_control.custom_minimum_size = Vector2(1280, 720)
	root_control.size = Vector2(1280, 720)
	root.add_child(root_control)

	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	root_control.add_child(hud)

	await process_frame
	await process_frame

	# 测试点 1: 模拟掉落药水 (show_banner == 0)
	print("\n--- 测试点 1: 掉落药水 (show_banner == 0) ---")
	var potion_drop = {
		"monster_name": "沉沦魔",
		"monster_id": "fallen_1",
		"gold": 10,
		"exp": 5,
		"item": {
			"name": "超级治疗药水",
			"raw_name": "超级治疗药水",
			"quality": "normal",
			"show_banner": 0,
			"icon": "items/misc/potion/full_healing_potion.lowend.png"
		}
	}
	hud._handle_reward_pop(potion_drop)
	await process_frame
	await process_frame

	var banner = hud._loot_banner
	var is_banner_visible = (banner != null and banner.visible)
	assert(is_banner_visible == false, "药水掉落时，战利品横幅 Tooltip 绝不可弹出显示！")
	print("✔ 药水掉落测试通过：战利品横幅未弹出 (visible = false)")

	# 测试点 2: 模拟掉落普通/魔法装备 (show_banner == 0)
	print("\n--- 测试点 2: 掉落普通装备 (show_banner == 0) ---")
	var magic_drop = {
		"monster_name": "硬皮僵尸",
		"monster_id": "zombie_1",
		"gold": 25,
		"exp": 12,
		"item": {
			"name": "残酷之阔剑",
			"raw_name": "残酷之阔剑",
			"quality": "magic",
			"show_banner": 0,
			"icon": "items/weapons/sword/broad_sword.lowend.png"
		}
	}
	hud._handle_reward_pop(magic_drop)
	await process_frame
	await process_frame

	banner = hud._loot_banner
	is_banner_visible = (banner != null and banner.visible)
	assert(is_banner_visible == false, "普通/魔法装备掉落时，战利品横幅 Tooltip 不得弹出！")
	print("✔ 魔法装备掉落测试通过：战利品横幅未弹出 (visible = false)")

	# 测试点 3: 模拟掉落暗金神装 (show_banner == 1)
	print("\n--- 测试点 3: 掉落暗金神装 (show_banner == 1) ---")
	var unique_drop = {
		"monster_name": "尸体发火",
		"monster_id": "corpsefire_boss",
		"gold": 500,
		"exp": 200,
		"item": {
			"name": "乔丹之石",
			"raw_name": "乔丹之石",
			"quality": "unique",
			"show_banner": 1,
			"icon": "items/jewelry/ring/ring_unique.lowend.png"
		}
	}
	hud._handle_reward_pop(unique_drop)
	await process_frame
	await process_frame

	banner = hud._loot_banner
	is_banner_visible = (banner != null and banner.visible)
	assert(is_banner_visible == true, "暗金神装掉落时，战利品横幅应高光弹出展示！")
	print("✔ 暗金神装掉落测试通过：战利品横幅成功弹出 (visible = true)")

	print("\n==================================================")
	print("🎉 【自动化测试全部通过】Tooltip 掉落门禁验证 100% 成功！")
	print("==================================================")
	quit(0)
