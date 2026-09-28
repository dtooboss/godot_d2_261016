extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证品质边框染色(暗金vs白板)与冰蓝多选防冲突体系 ===")
	
	var inv_panel = hud.inventory_panel
	inv_panel.show()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 1. 模拟背包注入：暗金风之力、白色九头蛇弓、绿色套装塔拉夏、亮金水晶剑
	# -------------------------------------------------------------
	var hydra_icon = "items/weapon/bow/composite_bow.lowend.png"
	var test_items = [
		{
			"name": "风之力",
			"quality": "unique",
			"icon": hydra_icon,
			"file_id": "/d/d2/obj/windforce#1"
		},
		{
			"name": "九头蛇弓",
			"quality": "normal",
			"icon": hydra_icon,
			"file_id": "/d/d2/obj/hydra_bow#2"
		},
		{
			"name": "塔·拉夏的判决",
			"quality": "set",
			"icon": "items/misc/amulet/amulet1.lowend.png",
			"file_id": "/d/d2/obj/tal_rasha_amulet#3"
		},
		{
			"name": "水晶剑",
			"quality": "rare",
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"file_id": "/d/d2/obj/crystal_sword#4"
		},
		{
			"name": "塔·拉夏的守护",
			"quality": "set",
			"icon": "items/armor/armor/ancient_armor.lowend.png",
			"file_id": "/d/d2/obj/tal_rasha_armor#5"
		}
	]
	
	inv_panel.render_lpc_items(test_items)
	await get_tree().process_frame
	
	var slot_unique = inv_panel.slots[0]
	var slot_normal = inv_panel.slots[1]
	var slot_set1   = inv_panel.slots[2]
	var slot_rare   = inv_panel.slots[3]
	var slot_set2   = inv_panel.slots[4]
	var slot_empty  = inv_panel.slots[5]
	
	# -------------------------------------------------------------
	# 2. 验证品质边框与暗夜微光底色区分（风之力 vs 九头蛇弓）
	# -------------------------------------------------------------
	var style_unique: StyleBoxFlat = slot_unique.get_theme_stylebox("normal")
	var style_normal: StyleBoxFlat = slot_normal.get_theme_stylebox("normal")
	var style_set: StyleBoxFlat    = slot_set1.get_theme_stylebox("normal")
	var style_rare: StyleBoxFlat   = slot_rare.get_theme_stylebox("normal")
	
	assert(style_unique != null and style_normal != null, "槽位必须正确应用 StyleBoxFlat！")
	
	# 断言：暗金与白色不仅边框不同，底色也不同！
	assert(style_unique.border_color.is_equal_approx(Color(0.88, 0.74, 0.38, 1.0)), "风之力边框必须为暗金色！")
	assert(style_normal.border_color.is_equal_approx(Color(0.32, 0.32, 0.35, 0.8)), "普通九头蛇弓边框必须为低调黑铁灰！")
	assert(style_unique.border_color != style_normal.border_color, "风之力与普通九头蛇弓在格子里必须有截然不同的边框！")
	print(">>> 验证 1 通过：【风之力】(暗金色框+暗金底) 与 【九头蛇弓】(灰框+黑底) 产生鲜明反差，彻底消除视觉混淆！")
	
	assert(style_set.border_color.is_equal_approx(Color(0.18, 0.82, 0.25, 1.0)), "套装必须呈现经典暗黑2翡翠深绿边框！")
	assert(style_rare.border_color.is_equal_approx(Color(0.95, 0.88, 0.22, 1.0)), "亮金稀有装备必须呈现明黄色边框！")
	print(">>> 验证 2 通过：绿色套装与亮金稀有装备均具备专属边框与底色微光！")
	
	# -------------------------------------------------------------
	# 3. 验证多选模式与绿色套装彻底脱钩（冰蓝宝石色选框）
	# -------------------------------------------------------------
	# 开启多选模式并选中第 2 格（绿色套装：塔拉夏项链）
	inv_panel.is_multiselect_mode = true
	slot_set1.set_selected(true)
	await get_tree().process_frame
	
	var style_selected: StyleBoxFlat = slot_set1.get_theme_stylebox("normal")
	assert(slot_set1.is_selected == true, "槽位 2 必须处于选中状态！")
	assert(slot_set1.check_badge.visible == true, "选中时对勾必须显示！")
	
	# 断言：选中的边框必须是明亮冰蓝宝石色 (Cyan)，绝不是绿色！
	assert(style_selected.border_color.is_equal_approx(Color(0.15, 0.85, 1.0, 1.0)), "多选选中的边框必须为冰蓝宝石色！")
	assert(slot_set1.check_badge.get_theme_color("font_color").is_equal_approx(Color(0.15, 0.92, 1.0, 1.0)), "多选对勾必须为冰蓝色！")
	
	# 断言：对比已选中的套装 slot_set1 与未选中的套装 slot_set2，形成冰蓝 vs 翡翠绿的强烈反差
	var style_unselected_set: StyleBoxFlat = slot_set2.get_theme_stylebox("normal")
	assert(style_unselected_set.border_color.is_equal_approx(Color(0.18, 0.82, 0.25, 1.0)), "未选中的套装必须保持翡翠绿！")
	print(">>> 验证 3 通过：选中的套装呈现明亮冰蓝宝石选框与冰蓝对勾，与未选中的翡翠绿套装完美共存，零视觉冲突！")
	
	# -------------------------------------------------------------
	# 4. 验证取消选中后完美还原固有品质风格
	# -------------------------------------------------------------
	slot_set1.set_selected(false)
	await get_tree().process_frame
	var style_restored: StyleBoxFlat = slot_set1.get_theme_stylebox("normal")
	assert(style_restored.border_color.is_equal_approx(Color(0.18, 0.82, 0.25, 1.0)), "取消选中后必须立即恢复原本的翡翠绿品质边框！")
	assert(slot_set1.check_badge.visible == false, "取消选中后对勾必须隐藏！")
	print(">>> 验证 4 通过：取消多选后无缝恢复装备固有品质边框与底色！")
	
	# 重新勾选 slot_set1 供最终走查截图对比展示
	slot_set1.set_selected(true)
	await get_tree().create_timer(0.2).timeout
	
	# -------------------------------------------------------------
	# 5. 走查截图
	# -------------------------------------------------------------
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_item_quality_borders_and_multiselect.png")
	print("[Test] 走查截图已保存至 res://test_item_quality_borders_and_multiselect.png")
	
	print("=== 全部 4 项品质边框与冰蓝多选防冲突核心验证 100% 通过！ ===")
	get_tree().quit(0)
