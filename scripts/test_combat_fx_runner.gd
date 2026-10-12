extends Node

func _ready():
	print("=== START COMBAT FX & ATTACK SPEED UNIT TEST ===")
	
	# 1. 测试 PlayerBottomBar
	var bar_scene = preload("res://scenes/afk/components/player_bottom_bar.tscn")
	var bar = bar_scene.instantiate()
	add_child(bar)
	
	assert(bar.attack_duration == 1.5, "Default attack_duration should be 1.5")
	bar.trigger_attack(0.6)
	assert(abs(bar.attack_duration - 0.6) < 0.001, "trigger_attack(0.6) should update duration to 0.6")
	assert(bar.attack_timer == 0.0, "attack_timer should reset to 0.0")
	bar.set_main_skill("暴风雪", "blizzard")
	assert(bar.skill_name_label.text == "【主攻】暴风雪", "Skill label should update")
	bar.set_main_skill("[F#FF3300m火焰弹[2;37;0m", "fire_bolt")
	assert(bar.skill_name_label.text == "【主攻】火焰弹", "ANSI codes should be completely stripped")
	print("PASS: PlayerBottomBar logic & ANSI stripping verified successfully!")
	
	# 2. 测试 CombatFXManager
	var fx_mgr_script = preload("res://scenes/afk/components/combat_fx_manager.gd")
	var fx_mgr = fx_mgr_script.new()
	add_child(fx_mgr)
	
	var hit_box = [0]
	var on_hit = func():
		hit_box[0] += 1
		
	# 测试近战斩光 (瞬间触发)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(200, 200), "attack", "物理", on_hit, false)
	assert(hit_box[0] == 1, "Melee slash should trigger on_hit immediately")
	print("PASS: Melee slash FX verified!")
	
	# 测试银白双层电弧 (瞬间触发)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(300, 300), "chain_lightning", "电", on_hit, false)
	assert(hit_box[0] == 2, "Lightning FX should trigger on_hit immediately")
	print("PASS: Silver Lightning FX verified!")
	
	# 测试火球术法球 (异步 Tween + 流光拖尾)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(150, 150), "fire_ball", "火", on_hit, true)
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 3, "Projectile FX should trigger on_hit on arrival")
	print("PASS: Fireball Orb FX verified!")

	# 测试圣骑士祝福之锤 (战锤形态 + 高速自转)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(180, 180), "blessed_hammer", "魔法", on_hit, false, true, 1, "hammer")
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 4, "Blessed Hammer FX should trigger on_hit on arrival")
	print("PASS: Blessed Hammer FX verified!")

	# 测试亚马逊多重箭 (5 发扇形齐射)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(220, 220), "multiple_shot", "物理", on_hit, false, true, 5, "arrow")
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 5, "Multiple Shot 5-arrow fan spread should trigger on_hit on arrival")
	print("PASS: Multiple Shot 5-arrow Fan Spread FX verified!")

	# 测试死灵法师骨矛 (尖刺形态)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(250, 250), "bone_spear", "魔法", on_hit, false, true, 1, "spike")
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 6, "Bone Spear Spike FX should trigger on_hit on arrival")
	print("PASS: Bone Spear Spike FX verified!")

	# 测试亚马逊充能一击 (Charged Strike: 近身戳刺 + 6道电荷弹炸裂)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(200, 200), "charged_strike", "电", on_hit, false)
	assert(hit_box[0] == 7, "Charged Strike should trigger on_hit immediately")
	print("PASS: Amazon Charged Strike FX verified!")

	# 测试亚马逊雷霆之怒 (Lightning Fury: 投掷神矛 + 环形万雷齐发)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(280, 280), "lightning_fury", "电", on_hit, true)
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 8, "Lightning Fury should trigger on_hit on impact")
	print("PASS: Amazon Lightning Fury Radial Burst FX verified!")

	# 测试亚马逊闪电攻击 (Lightning Strike: 刺击 + 连锁弹射)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(210, 210), "lightning_strike", "电", on_hit, false)
	assert(hit_box[0] == 9, "Lightning Strike should trigger on_hit immediately")
	print("PASS: Amazon Lightning Strike Chain FX verified!")

	# 测试亚马逊闪电标枪 (Lightning Bolt: 实体电矛贯穿飞行)
	fx_mgr.play_combat_fx(Vector2(100, 100), Vector2(260, 260), "lightning_bolt", "电", on_hit, false)
	await get_tree().create_timer(0.25).timeout
	assert(hit_box[0] == 10, "Lightning Bolt Javelin should trigger on_hit on arrival")
	print("PASS: Amazon Lightning Javelin FX verified!")
	
	print("=== ALL COMBAT FX & TIMING TESTS PASSED! ===")
	get_tree().quit(0)
