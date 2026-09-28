extends Node2D

## 投射物 2.0 实机战场画质渲染验证器

func _ready() -> void:
	print("=== 开始渲染投射物 2.0 真实战场视效 ===")
	
	# 设置窗口背景与渲染视口尺寸 (AFK 战斗视口 640x540)
	var vp_size = Vector2(800, 600)
	
	# 1. 真实鲜血荒地地图背景
	var bg_tex = load("res://mods/vanilla/assets/worlds/1/1.png")
	if bg_tex:
		var bg_sp = Sprite2D.new()
		bg_sp.texture = bg_tex
		bg_sp.position = vp_size * 0.5
		# 适当缩放平铺
		var s = max(vp_size.x / bg_tex.get_width(), vp_size.y / bg_tex.get_height())
		bg_sp.scale = Vector2(s, s)
		add_child(bg_sp)
	else:
		var dark_rect = ColorRect.new()
		dark_rect.size = vp_size
		dark_rect.color = Color(0.08, 0.09, 0.12)
		add_child(dark_rect)

	# 2. 模拟怪物目标位置 (放置两只怪物作为靶子)
	var mon_tex = load("res://assets/monsters/blood_zombie.png")
	if not mon_tex:
		mon_tex = load("res://assets/images/attack_effect.png")
		
	var target_1 = Vector2(250, 180)
	var target_2 = Vector2(550, 180)
	
	var m1 = Sprite2D.new()
	m1.texture = mon_tex
	m1.position = target_1
	m1.scale = Vector2(0.55, 0.55)
	add_child(m1)
	
	var m2 = Sprite2D.new()
	m2.texture = mon_tex
	m2.position = target_2
	m2.scale = Vector2(0.55, 0.55)
	add_child(m2)

	# 3. 挂载 CombatFXManager
	var fx_mgr_script = load("res://scenes/afk/components/combat_fx_manager.gd")
	var fx_mgr: AFK_CombatFXManager = fx_mgr_script.new()
	add_child(fx_mgr)

	# 4. 同时触发多轨经典暗黑技能投射物：
	var player_base_1 = Vector2(200, 520)
	var player_base_2 = Vector2(350, 520)
	var player_base_3 = Vector2(500, 520)
	var player_base_4 = Vector2(650, 520)
	
	# A. 圣骑士【祝福之锤】：高速自转金锤 + 圣金流光拖尾
	fx_mgr.play_combat_fx(player_base_1, target_1 + Vector2(-60, 0), "blessed_hammer", "魔法", func(): pass, false, true, 1, "hammer")
	
	# B. 法师【火球术】：炽白高热核 + 烈焰彗尾
	fx_mgr.play_combat_fx(player_base_2, target_1 + Vector2(60, 0), "fire_ball", "火", func(): pass, false, true, 1, "orb")
	
	# C. 亚马逊【多重箭】：5 发扇形齐射箭雨
	fx_mgr.play_combat_fx(player_base_3, target_2 + Vector2(-40, 0), "multiple_shot", "物理", func(): pass, false, true, 5, "arrow")
	
	# D. 纯正【银白高能电弧】：双层高压银白闪电
	fx_mgr.play_combat_fx(player_base_4, target_2 + Vector2(60, 0), "chain_lightning", "电", func(): pass, false, true, 1, "lightning")

	# 等待 0.08 秒，弹道正处于飞行最壮丽的高速中段时刻
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	await get_tree().process_frame

	# 截屏并保存
	var img = get_viewport().get_texture().get_image()
	var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/bbaff563-2193-4314-95e3-adb9825440f1/test_fx_real_battle_render.png"
	var err = img.save_png(save_path)
	if err == OK:
		print("SUCCESS: 真实战场实机视效已保存至 " + save_path)
	else:
		print("ERROR: 保存截屏失败: %d" % err)
		
	get_tree().quit(0)
