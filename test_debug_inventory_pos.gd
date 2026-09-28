extends SceneTree

func _init():
	var packed = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = packed.instantiate()
	root.add_child(hud)
	
	# Wait frames for layout
	await process_frame
	await process_frame
	
	var right_sidebar = hud.find_child("RightSidebar", true, false)
	var inv = hud.find_child("PlayerInventoryPanel", true, false)
	var matrix = hud.find_child("ControlMatrixPanel", true, false)
	var title_bar = inv.find_child("TitleBar", true, false)
	var grid_margin = inv.find_child("GridMargin", true, false)
	var footer_bar = inv.find_child("FooterBar", true, false)
	var panel = inv.find_child("Panel", true, false)
	var vbox = inv.find_child("VBox", true, false)
	
	print("RightSidebar: pos=", right_sidebar.global_position, " size=", right_sidebar.size)
	print("PlayerInventoryPanel: pos=", inv.global_position, " size=", inv.size)
	print("Panel: pos=", panel.global_position, " size=", panel.size)
	print("VBox: pos=", vbox.global_position, " size=", vbox.size)
	print("TitleBar: pos=", title_bar.global_position, " size=", title_bar.size)
	print("GridMargin: pos=", grid_margin.global_position, " size=", grid_margin.size)
	print("FooterBar: pos=", footer_bar.global_position, " size=", footer_bar.size)
	print("ControlMatrixPanel: pos=", matrix.global_position, " size=", matrix.size)
	
	quit()
