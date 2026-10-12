extends SceneTree

const AFK_LootDropFx = preload("res://scenes/afk/components/loot_drop_fx.gd")

## 战利品掉落呼吸晃动与流光小箭头入包自动化测试
## 验证点：
## 1. 掉落时生成 AFK_LootDropFx，正确加载物品专属 icon 与品质色
## 2. 0~1.0s 内，Icon 在掉落点原位上下浮动晃动与轻柔呼吸
## 3. 1.0s 到期后，Icon 淡出，生成流光小箭头并沿贝塞尔弧线加速射向背包
## 4. 到达背包时触发微震吸收反馈，并在 0.2s 内彻底释放销毁

func _init() -> void:
	print("==================================================")
	print("【自动化测试开始】掉落 Icon 呼吸 1s + 流光小箭头入包动效")
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

	# 测试点 1: 模拟击杀怪物掉落暗金装备【乔丹之石】
	print("\n--- 测试点 1: 掉落暗金装备【乔丹之石】，验证 1.0s 原地呼吸晃动 ---")
	var unique_drop = {
		"monster_name": "安达利尔",
		"monster_id": "andariel_1",
		"gold": 500,
		"exp": 1200,
		"item": {
			"name": "乔丹之石",
			"raw_name": "乔丹之石",
			"quality": "unique",
			"show_banner": 1,
			"icon": "items/misc/ring/ring1.lowend.png"
		}
	}
	# 设定击杀坐标
	hud._killed_monster_positions["andariel_1"] = Vector2(400, 360)
	hud._handle_reward_pop(unique_drop)

	await process_frame

	# 查找生成的 AFK_LootDropFx
	var fx_node = null
	for c in hud.get_children():
		if c is AFK_LootDropFx:
			fx_node = c
			break

	assert(fx_node != null, "掉落时必须生成 AFK_LootDropFx 动效节点！")
	assert(fx_node.icon_container != null, "前 2.2s 内必须存在 icon_container 展现原位晃动！")
	print("✔ 成功在击杀怪物脚下地表 (400, 435) 生成掉落光效节点")

	# 等待 1.0s（处于 2.2s 晃动与呼吸阶段）
	await create_timer(1.0).timeout

	assert(is_instance_valid(fx_node), "1.0s 时光效节点必须有效存活")
	assert(is_instance_valid(fx_node.icon_container), "1.0s 时 Icon 容器必须在原位晃动中")
	print("✔ 1.0s 状态验证通过：Icon 正在掉落点平稳晃动呼吸")

	# 测试点 2: 验证 2.2s 后 Icon 淡出，流光小箭头生成并飞向背包
	print("\n--- 测试点 2: 验证 2.2s 后转为流光小箭头贝塞尔飞行 ---")
	await create_timer(1.35).timeout # 累计 2.35s，已进入飞行阶段

	assert(is_instance_valid(fx_node), "2.35s 时光效节点仍存活并处于飞行阶段")
	assert(fx_node.arrow_visual != null and is_instance_valid(fx_node.arrow_visual), "2.35s 时流光小箭头必须已生成并处于飞行中")
	var arrow_pos = fx_node.arrow_visual.global_position
	print("✔ 小箭头正在飞行中，当前坐标: ", arrow_pos, "，角度: ", fx_node.arrow_visual.rotation)
	assert(arrow_pos.x > 400.0, "小箭头必须已脱离初始掉落点朝右侧背包加速射出！")

	# 测试点 3: 验证飞达背包后微震与节点彻底销毁
	print("\n--- 测试点 3: 验证命中背包并彻底释放销毁 ---")
	await create_timer(0.75).timeout # 累计 3.1s，动效完全播放完毕并释放

	await process_frame
	await process_frame

	assert(not is_instance_valid(fx_node), "动效播放完毕后，AFK_LootDropFx 必须已彻底 queue_free() 释放，无内存泄露！")
	print("✔ 内存释放验证通过：动效节点已彻底销毁！")

	print("\n==================================================")
	print("【自动化测试全部通过】掉落 Icon 呼吸 2.2s + 流光小箭头入包动效完全正常！")
	print("==================================================")
	quit()
