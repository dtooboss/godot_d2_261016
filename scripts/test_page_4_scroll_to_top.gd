extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证 27 页点击第 4 页精准对齐视口顶部第 1 个位置 ===")
	
	var inv_panel = hud.inventory_panel
	inv_panel.show()
	await get_tree().process_frame
	
	# 模拟 27 页背包
	inv_panel.inventory_page_count = 27
	inv_panel.current_page = 1
	inv_panel._update_page_buttons()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	assert(inv_panel.page_scroll_container.scroll_vertical == 0, "初始第 1 页滚动条必须为 0！")
	print(">>> 初始状态：第 1 页在顶部第一个位置，scroll_vertical = 0")
	
	# 模拟点击第 4 页
	inv_panel._on_page_button_pressed(4)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	var scroll_v = inv_panel.page_scroll_container.scroll_vertical
	print("[Test] 点击第 4 页后，视口滚动位置: scroll_vertical = %d" % scroll_v)
	
	# 断言：第 4 页对应 (4 - 1) * 25 = 75px
	assert(scroll_v == 75, "点击第 4 页后，滚动条必须精准滚动到 75px，让第 4 页对齐在视口最顶部第一个位置！")
	
	# 断言：绝不是滚到最下方的 '+' 按钮（27页时 '+' 按钮位置在 27 * 25 = 675px）
	assert(scroll_v < 200, "绝对不能滚到底部的 '+' 按钮！")
	print(">>> 核心断言通过：第 4 页精准对齐在视口顶部第 1 个位置，彻底解决跳到底部 '+' 的 Bug！")
	
	# 验证子控件数量未发生重复重建
	var btn_count = inv_panel.inv_button_container.get_child_count()
	assert(btn_count == 28, "按钮总数应保持 27 个页码 + 1 个 '+'，未发生多余重建！")
	
	# 截图走查
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_page_4_scroll_to_top.png")
	print("[Test] 走查截图已保存至 res://test_page_4_scroll_to_top.png")
	
	print("=== 全部验证 100% 通过！ ===")
	get_tree().quit(0)
