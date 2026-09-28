extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证背包页码标签栏上下滑动（ScrollContainer）支持 ===")
	
	var inv_panel = hud.inventory_panel
	inv_panel.show()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 1. 验证 PageScrollContainer 节点结构
	# -------------------------------------------------------------
	assert(inv_panel.page_scroll_container != null, "page_scroll_container 必须存在！")
	assert(inv_panel.inv_button_container.get_parent() == inv_panel.page_scroll_container, "inv_button_container 必须作为 page_scroll_container 的子节点！")
	print(">>> 验证 1 通过：背包页码栏已正确挂载在 PageScrollContainer 滚动视口内！")
	
	# -------------------------------------------------------------
	# 2. 模拟 1000+ 装备测试号产生 25 页数据
	# -------------------------------------------------------------
	inv_panel.inventory_page_count = 25
	inv_panel.current_page = 1
	inv_panel._update_page_buttons()
	await get_tree().process_frame
	
	var total_btns = inv_panel.inv_button_container.get_child_count()
	assert(total_btns == 26, "必须生成 25 个页码按钮 + 1 个 '+' 扩容按钮！")
	print(">>> 验证 2 通过：成功生成 25 页大量标签按钮！")
	
	# -------------------------------------------------------------
	# 3. 验证滚动视口高度限制（不越界、不挤压外部布局）
	# -------------------------------------------------------------
	await get_tree().process_frame
	var scroll_height = inv_panel.page_scroll_container.size.y
	var panel_height = inv_panel.size.y
	print("[Test] 当前背包高度: %d, 页码视口高度: %d" % [panel_height, scroll_height])
	assert(scroll_height < panel_height, "页码视口高度必须受限于背包内部，绝不能向下越界超出！")
	print(">>> 验证 3 通过：大量页码被严格限制在滚动视口内部，彻底解决下溢越界！")
	
	# -------------------------------------------------------------
	# 4. 验证切换到深层页码（如第 20 页）时视口自动滚动对齐
	# -------------------------------------------------------------
	inv_panel._on_page_button_pressed(20)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	
	assert(inv_panel.current_page == 20, "当前页码必须更新为 20！")
	var scroll_v = inv_panel.page_scroll_container.scroll_vertical
	print("[Test] 切换至第 20 页后，垂直滚动偏移量 scroll_vertical = %d" % scroll_v)
	assert(scroll_v > 0, "切换到深层页码时，视口必须自动向下滚动聚焦当前页！")
	print(">>> 验证 4 通过：切换深层页码自动向下平滑滚动，保持当前页码可见！")
	
	# -------------------------------------------------------------
	# 5. 截图保存并退出
	# -------------------------------------------------------------
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_bag_page_scroll_25pages.png")
	print("[Test] 走查截图已保存至 res://test_bag_page_scroll_25pages.png")
	
	print("=== 全部 4 项页码标签栏上下滚动核心验证 100% 通过！ ===")
	get_tree().quit(0)
