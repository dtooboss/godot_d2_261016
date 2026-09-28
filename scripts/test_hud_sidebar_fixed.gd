extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始验证背包侧边栏对齐与经典风格还原 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
	
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	
	var right_sidebar = hud.find_child("RightSidebar", true, false)
	var inv = hud.find_child("PlayerInventoryPanel", true, false)
	var matrix = hud.find_child("ControlMatrixPanel", true, false)
	var title_bar = inv.find_child("TitleBar", true, false)
	var grid_margin = inv.find_child("GridMargin", true, false)
	var footer_bar = inv.find_child("FooterBar", true, false)
	var btn_help = inv.find_child("BtnHelp", true, false)
	var btn_pocket = inv.find_child("BtnPocket", true, false)
	var btn_sort = inv.find_child("BtnSort", true, false)
	
	print("RightSidebar pos.x=", right_sidebar.global_position.x, " width=", right_sidebar.size.x)
	print("PlayerInventoryPanel pos.x=", inv.global_position.x, " width=", inv.size.x)
	print("TitleBar pos.x=", title_bar.global_position.x, " width=", title_bar.size.x)
	print("GridMargin pos.x=", grid_margin.global_position.x, " width=", grid_margin.size.x)
	print("FooterBar pos.x=", footer_bar.global_position.x, " width=", footer_bar.size.x)
	print("ControlMatrix pos.x=", matrix.global_position.x, " width=", matrix.size.x)
	
	# 严格断言：所有组件左边缘 X 坐标完全平齐！
	assert(right_sidebar.global_position.x == inv.global_position.x, "面板与侧边栏对齐")
	assert(inv.global_position.x == title_bar.global_position.x, "TitleBar与面板对齐")
	assert(title_bar.global_position.x == grid_margin.global_position.x, "GridMargin与TitleBar对齐")
	assert(grid_margin.global_position.x == footer_bar.global_position.x, "FooterBar与GridMargin对齐")
	assert(footer_bar.global_position.x == matrix.global_position.x, "底部操作栏与下方面板对齐")
	
	print(">>> 所有组件左边缘 X 坐标 100% 垂直平齐断言通过！")
	
	# 截取全屏与侧边栏
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_hud_sidebar_fixed.png")
	print(">>> 截图成功保存至 res://test_hud_sidebar_fixed.png")
	get_tree().quit(0)
