extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	
	# 等待一帧让布局生效
	await process_frame
	await process_frame
	
	print("[DEBUG] LeftViewport size: ", hud.get_node("MainHBox/LeftViewport").size)
	print("[DEBUG] LeftViewport global_position: ", hud.get_node("MainHBox/LeftViewport").global_position)
	print("[DEBUG] parent_viewport: ", hud.monster_display.get_parent().get_path())
	
	hud._handle_gstatus_data({
		"stage": { "stage_id": 1, "stage_name": "鲜血荒地" },
		"monsters": [
			{
				"id": "/d/act1/npc/act1_monster#1",
				"mon_key": "fallen",
				"name": "沉沦魔",
				"rank": "normal",
				"hp": 15,
				"max_hp": 15
			},
			{
				"id": "/d/act1/npc/act1_monster#2",
				"mon_key": "blood_zombie",
				"name": "饥饿僵尸",
				"rank": "normal",
				"hp": 20,
				"max_hp": 20
			}
		]
	})
	
	await process_frame
	
	for mid in hud._monster_instances.keys():
		var node = hud._monster_instances[mid]
		print("[MONSTER] mid: ", mid)
		print("  visible: ", node.visible)
		print("  parent: ", node.get_parent().get_path())
		print("  slot_index: ", node.slot_index)
		print("  anchors: ", node.anchor_left, ", ", node.anchor_top)
		print("  position: ", node.position)
		print("  global_position: ", node.global_position)
		print("  size: ", node.size)
		if node.sprite:
			print("  sprite texture: ", node.sprite.texture)
			print("  sprite position: ", node.sprite.position)
			print("  sprite global_position: ", node.sprite.global_position)
			print("  sprite scale: ", node.sprite.scale)
	
	quit(0)
