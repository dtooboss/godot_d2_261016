extends SceneTree

func _init() -> void:
	print(">>> 启动战场全流程深度诊断 <<<")
	
	# 1. 实例化主 HUD 场景
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	
	# 模拟窗口尺寸 1280x720
	root.size = Vector2i(1280, 720)
	hud.size = Vector2(1280, 720)
	
	# 等待两帧让 UI Container 完成布局计算
	await process_frame
	await process_frame
	
	var left_vp = hud.get_node("MainHBox/LeftViewport")
	print("\n[DIAGNOSE 1] UI 容器初始化:")
	print("  hud.size: ", hud.size)
	print("  left_vp.size: ", left_vp.size)
	print("  left_vp.global_position: ", left_vp.global_position)
	print("  monster_display: ", hud.monster_display, " (visible: ", hud.monster_display.visible, ")")

	# 2. 模拟第一波怪生成 (单只普通怪)
	print("\n[DIAGNOSE 2] 模拟第一波刷怪 (单只小怪)...")
	var mob1_id = "/d/act1/npc/act1_monster#101"
	hud._handle_gstatus_data({
		"stage": { "stage_id": 1, "stage_name": "鲜血荒地", "boss_active": 0, "threshold": 50, "kill_step": 0 },
		"monsters": [
			{ "id": mob1_id, "mon_key": "fallen", "code": "fallen", "name": "沉沦魔", "rank": "normal", "hp": 30, "max_hp": 30, "level": 1 }
		]
	})
	
	await process_frame
	await process_frame
	
	var node1 = hud._monster_instances.get(mob1_id, null)
	print("  node1 created: ", node1 != null)
	if node1:
		print("  node1.parent: ", node1.get_parent().name)
		print("  node1.position: ", node1.position, " global_pos: ", node1.global_position)
		print("  node1.size: ", node1.size)
		print("  node1.anchors: left=", node1.anchor_left, " top=", node1.anchor_top)
		print("  node1.modulate.a: ", node1.modulate.a)
		if node1.sprite:
			print("  sprite.global_pos: ", node1.sprite.global_position, " scale: ", node1.sprite.scale, " size: ", node1.sprite.size)
		var np1 = node1.get_node_or_null("NamePanel")
		if np1:
			print("  NamePanel.global_pos: ", np1.global_position, " size: ", np1.size)

	# 3. 模拟小怪被击杀死亡释放
	print("\n[DIAGNOSE 3] 模拟小怪被击杀死亡...")
	hud._handle_combat_data({
		"attacker": "hero", "attacker_uuid": "hero#1",
		"victim": "fallen", "victim_uuid": mob1_id,
		"dmg": 30, "elem": "物理", "crit": 0, "you_hp": 0, "you_max_hp": 30
	})
	
	# 快进等待死亡动效完成
	await create_timer(0.35).timeout
	await process_frame
	
	print("  node1 valid after death: ", is_instance_valid(node1))
	print("  hud.monster_display valid: ", is_instance_valid(hud.monster_display))
	print("  _monster_instances size: ", hud._monster_instances.size())

	# 4. 模拟第二波刷怪 (Boss + 3只小怪)
	print("\n[DIAGNOSE 4] 模拟第二波刷怪 (Boss + 3只小怪)...")
	var boss_id = "/d/act1/npc/act1_monster#888"
	var mob2_id = "/d/act1/npc/act1_monster#201"
	var mob3_id = "/d/act1/npc/act1_monster#202"
	var mob4_id = "/d/act1/npc/act1_monster#203"
	
	hud._handle_gstatus_data({
		"stage": { "stage_id": 14, "stage_name": "地下墓穴第四层", "boss_active": 1, "threshold": 100, "kill_step": 100 },
		"monsters": [
			{ "id": boss_id, "mon_key": "andariel", "code": "andariel", "name": "👑 安达莉尔", "rank": "boss", "hp": 8000, "max_hp": 8000, "level": 12 },
			{ "id": mob2_id, "mon_key": "dark_brute", "code": "brute", "name": "黑暗小怪A", "rank": "normal", "hp": 50, "max_hp": 50, "level": 10 },
			{ "id": mob3_id, "mon_key": "dark_brute", "code": "brute", "name": "黑暗小怪B", "rank": "normal", "hp": 50, "max_hp": 50, "level": 10 },
			{ "id": mob4_id, "mon_key": "dark_brute", "code": "brute", "name": "黑暗小怪C", "rank": "normal", "hp": 50, "max_hp": 50, "level": 10 }
		]
	})
	
	await process_frame
	await process_frame
	
	for mid in [boss_id, mob2_id, mob3_id, mob4_id]:
		var mnode = hud._monster_instances.get(mid, null)
		if mnode and is_instance_valid(mnode):
			var np = mnode.get_node_or_null("NamePanel")
			print("  Monster [%s] slot=%d pos=%s global_pos=%s vis=%s parent=%s" % [
				mid.substr(mid.length()-3), mnode.slot_index, str(mnode.position), str(mnode.global_position), str(mnode.visible),
				mnode.get_parent().name if mnode.get_parent() else "NULL"
			])
			if mnode.sprite:
				print("    -> sprite global_pos=%s vis=%s size=%s scale=%s" % [
					str(mnode.sprite.global_position), str(mnode.sprite.visible), str(mnode.sprite.size), str(mnode.sprite.scale)
				])
			if np:
				print("    -> NamePanel global_pos=%s vis=%s size=%s" % [
					str(np.global_position), str(np.visible), str(np.size)
				])
		else:
			print("  Monster [%s] FAILED TO SPAWN! (is_null: %s)" % [mid, str(mnode == null)])

	print("\n>>> 诊断测试执行完毕 <<<")
	quit()
