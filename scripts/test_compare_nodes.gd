extends Node2D

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var preset_node = hud.monster_display
	var dyn_node = hud.MonsterDisplayScene.instantiate()
	var vp = hud.get_node("MainHBox/LeftViewport")
	vp.add_child(dyn_node)
	
	hud._apply_monster_slot_position(preset_node, -99)
	hud._apply_monster_slot_position(dyn_node, -99)
	
	preset_node.bind_monster_data({
		"mon_key": "andariel",
		"rank": "boss",
		"hp": 8000,
		"max_hp": 8000
	})
	dyn_node.bind_monster_data({
		"mon_key": "andariel",
		"rank": "boss",
		"hp": 8000,
		"max_hp": 8000
	})
	
	await get_tree().process_frame
	
	print("\n=== PRESET NODE (预置节点) ===")
	print("layout_mode: ", preset_node.layout_mode)
	print("position: ", preset_node.position, " global_pos: ", preset_node.global_position)
	print("anchors: left=", preset_node.anchor_left, " top=", preset_node.anchor_top)
	print("offsets: left=", preset_node.offset_left, " top=", preset_node.offset_top, " right=", preset_node.offset_right, " bottom=", preset_node.offset_bottom)
	var p_sprite = preset_node.get_node("MonsterSprite")
	var p_panel = preset_node.get_node("NamePanel")
	print("sprite global_pos: ", p_sprite.global_position, " size: ", p_sprite.size)
	print("panel global_pos: ", p_panel.global_position, " size: ", p_panel.size)
	
	print("\n=== DYNAMIC NODE (动态实例化节点) ===")
	print("layout_mode: ", dyn_node.layout_mode)
	print("position: ", dyn_node.position, " global_pos: ", dyn_node.global_position)
	print("anchors: left=", dyn_node.anchor_left, " top=", dyn_node.anchor_top)
	print("offsets: left=", dyn_node.offset_left, " top=", dyn_node.offset_top, " right=", dyn_node.offset_right, " bottom=", dyn_node.offset_bottom)
	var d_sprite = dyn_node.get_node("MonsterSprite")
	var d_panel = dyn_node.get_node("NamePanel")
	print("sprite global_pos: ", d_sprite.global_position, " size: ", d_sprite.size)
	print("panel global_pos: ", d_panel.global_position, " size: ", d_panel.size)
	
	get_tree().quit(0)
