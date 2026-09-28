extends SceneTree

func _init():
	var packed = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = packed.instantiate()
	root.add_child(hud)
	
	await process_frame
	await process_frame
	await process_frame
	
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("res://test_hud_sidebar_fixed.png")
	print("SUCCESS: Saved test_hud_sidebar_fixed.png")
	quit()
