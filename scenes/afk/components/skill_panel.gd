extends Control
class_name AFK_SkillPanel

## Diablo II LPC Godot 专属现代技能面板 (AFK_SkillPanel)
## 架构：全数据后端驱动 (Thin Client Dumb Renderer)
## 视觉：纯程序化暗黑哥特石质面板 + 动态能量依赖连线 + 高清暗金立体图标
## 交互：左键单击选中高亮、左键双击设为主攻、右键单击设为副攻、加号升级、右侧全属性对比

signal skill_learn_requested(skill_code: String)
signal skill_reset_requested()
signal skill_buy_respec_requested()
signal skill_set_binding_requested(skill_code: String, slot_type: String)

static func _safe_int(val: Variant, default_val: int = 0) -> int:
	return AnsiHelper.to_safe_int(val, default_val)

@onready var title_label: Label = %TitleLabel
@onready var class_avatar: TextureRect = %ClassAvatar
@onready var points_label: Label = %PointsLabel
@onready var lbl_skill_respec_count: Label = %LblSkillRespecCount
@onready var btn_buy_skill_respec: Button = %BtnBuySkillRespec
@onready var btn_reset: Button = %BtnReset
@onready var btn_close: Button = %BtnClose
@onready var tab_bar: HBoxContainer = %TabBar
@onready var canvas_area: Control = %CanvasArea
@onready var line_drawer: Control = %LineDrawer
@onready var nodes_container: Control = %NodesContainer
@onready var level_guide: VBoxContainer = %LevelGuide

# 右侧详情卡控件
@onready var detail_panel: Control = %DetailPanel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_code: Label = %DetailCode
@onready var detail_type_tag: Label = %DetailTypeTag
@onready var detail_req_lvl: Label = %DetailReqLvl
@onready var detail_cur_lvl: Label = %DetailCurLvl
@onready var detail_mana_cost: Label = %DetailManaCost
@onready var detail_intro: Label = %DetailIntro
@onready var detail_cur_desc: Label = %DetailCurDesc
@onready var detail_next_desc: Label = %DetailNextDesc
@onready var detail_synergies: Label = %DetailSynergies
@onready var btn_set_main: Button = %BtnSetMain
@onready var btn_set_sub: Button = %BtnSetSub
@onready var passive_hint_label: Label = %PassiveHintLabel

# 数据缓存
var _current_data: Dictionary = {}
var _current_class: String = "sor"
var _current_page: int = 1
var _selected_skill_code: String = ""
var _node_widgets: Dictionary = {} # code -> Control
var _node_selection_boxes: Dictionary = {} # code -> Panel
var _skill_respecs: int = 0
var _respec_price: int = 0
var _player_level: int = 1
var _player_gold: int = 0

static func _calc_respec_gold_cost(lvl: int) -> int:
	if lvl < 1: lvl = 1
	return 10000 + (lvl * lvl * lvl * lvl) / 2

static func _format_gold(amount: int) -> String:
	var s = str(amount)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

# 网格坐标常数 (6 行 3 列)
const GRID_START_X = 65.0
const GRID_START_Y = 20.0
const GRID_STEP_X = 135.0
const GRID_STEP_Y = 68.0
const NODE_SIZE = 50.0

func _ready() -> void:
	hide()
	if btn_buy_skill_respec:
		btn_buy_skill_respec.visible = false
	if btn_close:
		btn_close.pressed.connect(close)
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
	if btn_buy_skill_respec:
		btn_buy_skill_respec.pressed.connect(_on_buy_respec_pressed)
	if btn_set_main:
		btn_set_main.pressed.connect(func():
			if not _selected_skill_code.is_empty():
				skill_set_binding_requested.emit(_selected_skill_code, "main")
		)
	if btn_set_sub:
		btn_set_sub.pressed.connect(func():
			if not _selected_skill_code.is_empty():
				skill_set_binding_requested.emit(_selected_skill_code, "sub")
		)
		
	if line_drawer:
		line_drawer.draw.connect(_on_draw_flow_lines)

func open() -> void:
	show()

func close() -> void:
	hide()

## -------------------------------------------------------------
## 核心渲染入口：由服务端权威 gskills 帧直接驱动
## -------------------------------------------------------------
func render_gskills_data(data: Dictionary) -> void:
	_current_data = data
	_current_class = str(data.get("class", "sor")).to_lower()
	var c_name = str(data.get("class_name", "英雄"))
	var pts = _safe_int(data.get("skill_points"), 0)

	# 1. 顶部标题与点数
	if title_label:
		title_label.text = "【%s】技能树" % c_name
	if points_label:
		points_label.text = "可用技能点: %d" % pts
		if pts > 0:
			points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			points_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	_player_level = _safe_int(data.get("level", 1), 1)
	_player_gold = _safe_int(data.get("gold", 0), 0)
	_skill_respecs = _safe_int(data.get("skill_respecs", data.get("free_respecs", 0)), 0)
	var dynamic_cost = _calc_respec_gold_cost(_player_level)
	_respec_price = _safe_int(data.get("respec_gold_cost", data.get("respec_price", dynamic_cost)), dynamic_cost)

	if lbl_skill_respec_count:
		if _skill_respecs > 0:
			lbl_skill_respec_count.text = "免费洗点: %d次" % _skill_respecs
			lbl_skill_respec_count.modulate = Color(0.4, 0.95, 0.4, 1.0)
		else:
			lbl_skill_respec_count.text = "洗点: %s金币" % _format_gold(_respec_price)
			lbl_skill_respec_count.modulate = Color(0.95, 0.8, 0.3, 1.0)
		lbl_skill_respec_count.tooltip_text = "剩余免费技能洗点 %d 次。免费次数用尽后，每次洗点消耗 10000+等级^4/2 金币。" % _skill_respecs

	if btn_buy_skill_respec:
		btn_buy_skill_respec.visible = false
			
	if class_avatar:
		class_avatar.texture = _get_class_icon(_current_class)

	# 2. 渲染 3 系 Tabs
	_render_tabs(data.get("tabs", []))

	# 3. 渲染当前系别的技能节点图
	_render_current_page_nodes()

	# 4. 刷新右侧详情展示 (若未选中，则默认选当前系已点或第一个技能)
	if _selected_skill_code.is_empty() or not _get_skill_info(_selected_skill_code):
		_select_default_skill()
	else:
		_select_and_highlight_skill(_selected_skill_code)

	show()

## -------------------------------------------------------------
## 渲染三系 Tab 按钮
## -------------------------------------------------------------
func _render_tabs(tabs: Array) -> void:
	if not tab_bar:
		return
	for child in tab_bar.get_children():
		child.queue_free()

	for i in range(tabs.size()):
		var t = tabs[i]
		if not (t is Dictionary):
			continue
		var page = _safe_int(t.get("page"), i + 1)
		var t_name = str(t.get("name", "系别 %d" % page))
		var pts_spent = _safe_int(t.get("points_spent"), 0)

		var btn = Button.new()
		btn.text = "%s (%d)" % [t_name, pts_spent]
		btn.custom_minimum_size = Vector2(130, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (page == _current_page)
		
		_style_tab_button(btn, page == _current_page)
		
		btn.pressed.connect(func():
			_current_page = page
			for b in tab_bar.get_children():
				if b is Button:
					b.button_pressed = (b == btn)
					_style_tab_button(b, b == btn)
			_render_current_page_nodes()
			_select_default_skill()
		)
		tab_bar.add_child(btn)

func _style_tab_button(btn: Button, is_active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.border_width_top = 2
	style.border_width_left = 1
	style.border_width_right = 1
	if is_active:
		style.bg_color = Color(0.18, 0.15, 0.12, 0.95)
		style.border_color = Color(0.9, 0.75, 0.3, 1.0)
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	else:
		style.bg_color = Color(0.1, 0.09, 0.08, 0.8)
		style.border_color = Color(0.35, 0.3, 0.25, 0.6)
		btn.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

## -------------------------------------------------------------
## 渲染当前系别的技能节点图
## -------------------------------------------------------------
func _render_current_page_nodes() -> void:
	if not nodes_container:
		return

	# 1. 绝对校准左侧等级标尺纵向中心对齐
	if level_guide:
		var labels = level_guide.get_children()
		for r in range(min(labels.size(), 6)):
			var lbl = labels[r]
			if lbl is Control:
				var target_y = GRID_START_Y + r * GRID_STEP_Y + (NODE_SIZE * 0.5) - 8.0
				lbl.position.y = target_y

	# 清理旧节点
	for child in nodes_container.get_children():
		child.queue_free()
	_node_widgets.clear()
	_node_selection_boxes.clear()

	var all_skills = _current_data.get("skills", {})
	if not (all_skills is Dictionary):
		return

	for sk_code in all_skills.keys():
		var sk = all_skills[sk_code]
		if not (sk is Dictionary):
			continue
		var page = _safe_int(sk.get("page"), 1)
		if page != _current_page:
			continue

		var row = clampi(_safe_int(sk.get("row"), 1) - 1, 0, 5)
		var col = clampi(_safe_int(sk.get("col"), 1) - 1, 0, 2)

		var pos_x = GRID_START_X + col * GRID_STEP_X
		var pos_y = GRID_START_Y + row * GRID_STEP_Y

		var widget = _create_skill_node_widget(sk)
		widget.position = Vector2(pos_x, pos_y)
		nodes_container.add_child(widget)
		_node_widgets[sk_code] = widget

	if line_drawer:
		line_drawer.queue_redraw()

## -------------------------------------------------------------
## 创建单个技能节点视图 (纯程序化，瘦客户端)
## -------------------------------------------------------------
func _create_skill_node_widget(sk: Dictionary) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	root.size = Vector2(NODE_SIZE, NODE_SIZE)

	var sk_code = str(sk.get("code", ""))
	var cur_lvl = _safe_int(sk.get("cur_lvl"), 0)
	var eff_lvl = _safe_int(sk.get("eff_lvl"), cur_lvl)
	var is_learned = bool(sk.get("is_learned", false))
	var is_usable = is_learned or eff_lvl > 0
	var can_learn = bool(sk.get("can_learn", false))
	var is_max = bool(sk.get("is_max", false))
	var is_main = bool(sk.get("is_main", false))
	var is_sub = bool(sk.get("is_sub", false))
	var prereq_ok = bool(sk.get("prereq_satisfied", false))
	var is_passive = bool(sk.get("is_passive", false))

	# 1. 图标底框与纹理
	var icon_rect = TextureRect.new()
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path = str(sk.get("icon_file", ""))
	if not icon_path.is_empty() and ResourceLoader.exists("res://assets/" + icon_path):
		icon_rect.texture = load("res://assets/" + icon_path)
	else:
		var fallback_path = "res://assets/skills/%s/%s.png" % [_current_class, sk_code]
		if ResourceLoader.exists(fallback_path):
			icon_rect.texture = load(fallback_path)

	# 状态色彩调制
	if is_usable:
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif can_learn:
		icon_rect.modulate = Color(0.9, 0.9, 0.9, 0.9)
	elif prereq_ok:
		icon_rect.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		icon_rect.modulate = Color(0.35, 0.35, 0.35, 0.65)

	root.add_child(icon_rect)

	# 2. 选中态高亮光圈/金框 (选中时显示)
	var select_border = Panel.new()
	select_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sel_sb = StyleBoxFlat.new()
	sel_sb.draw_center = false
	sel_sb.border_width_left = 2
	sel_sb.border_width_top = 2
	sel_sb.border_width_right = 2
	sel_sb.border_width_bottom = 2
	sel_sb.border_color = Color(1.0, 0.9, 0.25, 1.0) # 亮金选框
	sel_sb.corner_radius_top_left = 3
	sel_sb.corner_radius_top_right = 3
	sel_sb.corner_radius_bottom_right = 3
	sel_sb.corner_radius_bottom_left = 3
	select_border.add_theme_stylebox_override("panel", sel_sb)
	select_border.visible = (sk_code == _selected_skill_code)
	root.add_child(select_border)
	_node_selection_boxes[sk_code] = select_border

	# 3. 未解锁小锁标记
	if not is_usable and not prereq_ok:
		var lock_lbl = Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_lbl.add_theme_font_size_override("font_size", 14)
		lock_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lock_lbl)

	# 4. 主副攻角标提示 (左键 L / 右键 R)
	if is_main or is_sub:
		var bind_tag = Label.new()
		bind_tag.text = "L" if is_main else "R"
		bind_tag.position = Vector2(2, 2)
		bind_tag.add_theme_font_size_override("font_size", 9)
		bind_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2) if is_main else Color(0.4, 0.8, 1.0))
		var tag_sb = StyleBoxFlat.new()
		tag_sb.bg_color = Color(0.05, 0.05, 0.05, 0.9)
		tag_sb.border_width_left = 1
		tag_sb.border_width_top = 1
		tag_sb.border_width_right = 1
		tag_sb.border_width_bottom = 1
		tag_sb.border_color = Color(0.85, 0.7, 0.2, 0.9) if is_main else Color(0.3, 0.65, 0.9, 0.9)
		tag_sb.corner_radius_top_left = 2
		tag_sb.corner_radius_top_right = 2
		tag_sb.corner_radius_bottom_right = 2
		tag_sb.corner_radius_bottom_left = 2
		tag_sb.content_margin_left = 3
		tag_sb.content_margin_right = 3
		tag_sb.content_margin_top = 0
		tag_sb.content_margin_bottom = 1
		bind_tag.add_theme_stylebox_override("normal", tag_sb)
		bind_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bind_tag)

	# 5. 右下角等级角标 (严格自适应宽度，内嵌于右下角，绝不溢出)
	if is_usable:
		var lvl_lbl = Label.new()
		var display_lvl = eff_lvl if eff_lvl > 0 else cur_lvl
		var is_boosted = (eff_lvl > cur_lvl)
		var txt = "MAX" if (is_max and not is_boosted) else "%d" % display_lvl
		lvl_lbl.text = txt
		var f_size = 9 if (is_max and not is_boosted) else 10
		lvl_lbl.add_theme_font_size_override("font_size", f_size)
		if is_boosted:
			lvl_lbl.add_theme_color_override("font_color", Color(0.35, 0.78, 1.0)) # 暗黑2经典装备加成天蓝色
		elif is_max:
			lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # 投满金色
		else:
			lvl_lbl.add_theme_color_override("font_color", Color.WHITE)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# 测算文本实际宽度，精准靠右下对齐，留 2px 边距
		var font = ThemeDB.fallback_font
		var str_w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size).x if font else (22.0 if (is_max and not is_boosted) else 14.0)
		var badge_w = clampf(str_w + 6.0, 16.0, 36.0)
		var badge_h = 14.0
		lvl_lbl.size = Vector2(badge_w, badge_h)
		lvl_lbl.position = Vector2(NODE_SIZE - badge_w - 2.0, NODE_SIZE - badge_h - 2.0)

		var lvl_sb = StyleBoxFlat.new()
		lvl_sb.bg_color = Color(0.04, 0.04, 0.04, 0.92)
		lvl_sb.border_width_left = 1
		lvl_sb.border_width_top = 1
		lvl_sb.border_width_right = 1
		lvl_sb.border_width_bottom = 1
		if is_boosted:
			lvl_sb.border_color = Color(0.2, 0.55, 0.85, 0.95) # 装备加成亮蓝边框
		elif is_max:
			lvl_sb.border_color = Color(0.85, 0.72, 0.22, 0.9) # 金色边框
		else:
			lvl_sb.border_color = Color(0.5, 0.45, 0.35, 0.8) # 铜色边框
		lvl_sb.corner_radius_top_left = 2
		lvl_sb.corner_radius_top_right = 2
		lvl_sb.corner_radius_bottom_right = 2
		lvl_sb.corner_radius_bottom_left = 2
		lvl_sb.content_margin_left = 2
		lvl_sb.content_margin_right = 2
		lvl_sb.content_margin_top = 0
		lvl_sb.content_margin_bottom = 1
		lvl_lbl.add_theme_stylebox_override("normal", lvl_sb)
		lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lvl_lbl)

	# 6. 交互透明按钮覆盖 (支持单击切换、双击设为主攻、右键设为副攻)
	var click_btn = Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	var empty_sb = StyleBoxEmpty.new()
	click_btn.add_theme_stylebox_override("normal", empty_sb)
	click_btn.add_theme_stylebox_override("hover", empty_sb)
	click_btn.add_theme_stylebox_override("pressed", empty_sb)
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT

	click_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# 左键单击选中
				_select_and_highlight_skill(sk_code)
				if event.double_click and is_usable and not is_passive:
					# 左键双击设为主攻
					skill_set_binding_requested.emit(sk_code, "main")
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# 右键单击直接设为辅助技能
				_select_and_highlight_skill(sk_code)
				if is_usable and not is_passive:
					skill_set_binding_requested.emit(sk_code, "sub")
	)
	root.add_child(click_btn)

	# 7. 可加点 [+] 按钮 (放最上层)
	if can_learn:
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.position = Vector2(NODE_SIZE - 14, -5)
		plus_btn.size = Vector2(18, 18)
		plus_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		plus_btn.add_theme_font_size_override("font_size", 12)
		plus_btn.add_theme_color_override("font_color", Color.WHITE)
		var plus_sb = StyleBoxFlat.new()
		plus_sb.bg_color = Color(0.75, 0.15, 0.15, 0.95)
		plus_sb.border_width_left = 1
		plus_sb.border_width_top = 1
		plus_sb.border_width_right = 1
		plus_sb.border_width_bottom = 1
		plus_sb.border_color = Color(1.0, 0.85, 0.3, 1.0)
		plus_sb.corner_radius_top_left = 9
		plus_sb.corner_radius_top_right = 9
		plus_sb.corner_radius_bottom_left = 9
		plus_sb.corner_radius_bottom_right = 9
		plus_btn.add_theme_stylebox_override("normal", plus_sb)
		plus_btn.add_theme_stylebox_override("hover", plus_sb)
		plus_btn.pressed.connect(func():
			_select_and_highlight_skill(sk_code)
			skill_learn_requested.emit(sk_code)
		)
		root.add_child(plus_btn)

	return root

## -------------------------------------------------------------
## 选中技能并高亮其选框
## -------------------------------------------------------------
func _select_and_highlight_skill(sk_code: String) -> void:
	_selected_skill_code = sk_code

	# 切换选框可见性
	for code in _node_selection_boxes.keys():
		var box = _node_selection_boxes[code]
		if is_instance_valid(box):
			box.visible = (code == sk_code)

	_render_skill_details(sk_code)

## -------------------------------------------------------------
## 动态能量依赖连线绘制 (Flow Line Drawing)
## -------------------------------------------------------------
func _on_draw_flow_lines() -> void:
	if not line_drawer:
		return

	var all_skills = _current_data.get("skills", {})
	if not (all_skills is Dictionary):
		return

	var half_node = NODE_SIZE / 2.0

	for sk_code in all_skills.keys():
		var sk = all_skills[sk_code]
		if not (sk is Dictionary):
			continue
		if _safe_int(sk.get("page"), 1) != _current_page:
			continue

		var reqs = sk.get("req_skills", [])
		if not (reqs is Array) or reqs.is_empty():
			continue

		var to_row = clampi(_safe_int(sk.get("row"), 1) - 1, 0, 5)
		var to_col = clampi(_safe_int(sk.get("col"), 1) - 1, 0, 2)
		var to_pos = Vector2(GRID_START_X + to_col * GRID_STEP_X + half_node, GRID_START_Y + to_row * GRID_STEP_Y + half_node)

		for req_code in reqs:
			var req_sk = all_skills.get(req_code)
			if not (req_sk is Dictionary):
				continue
			if _safe_int(req_sk.get("page"), 1) != _current_page:
				continue

			var from_row = clampi(_safe_int(req_sk.get("row"), 1) - 1, 0, 5)
			var from_col = clampi(_safe_int(req_sk.get("col"), 1) - 1, 0, 2)
			var from_pos = Vector2(GRID_START_X + from_col * GRID_STEP_X + half_node, GRID_START_Y + from_row * GRID_STEP_Y + half_node)

			var is_req_learned = bool(req_sk.get("is_learned", false))

			if is_req_learned:
				var gold_col = Color(1.0, 0.82, 0.2, 0.85)
				_draw_arrow_line(line_drawer, from_pos, to_pos, gold_col, 2.5)
			else:
				var dim_col = Color(0.35, 0.3, 0.25, 0.5)
				_draw_arrow_line(line_drawer, from_pos, to_pos, dim_col, 1.5)

func _draw_arrow_line(canvas: Control, p1: Vector2, p2: Vector2, color: Color, width: float) -> void:
	var dir = (p2 - p1).normalized()
	var start = p1 + dir * (NODE_SIZE * 0.45)
	var end = p2 - dir * (NODE_SIZE * 0.48)

	if start.distance_to(end) > 8.0:
		canvas.draw_line(start, end, color, width)
		var arrow_len = 7.0
		var arrow_angle = PI / 6.0
		var left_wing = end - dir.rotated(arrow_angle) * arrow_len
		var right_wing = end - dir.rotated(-arrow_angle) * arrow_len
		canvas.draw_line(end, left_wing, color, width)
		canvas.draw_line(end, right_wing, color, width)

## -------------------------------------------------------------
## 技能详情卡渲染
## -------------------------------------------------------------
func _render_skill_details(sk_code: String) -> void:
	var sk = _get_skill_info(sk_code)
	if not sk:
		return

	_selected_skill_code = sk_code

	var sk_name = str(sk.get("name", "技能"))
	var is_passive = bool(sk.get("is_passive", false))
	var is_spell = bool(sk.get("is_spell", false))
	var req_lvl = _safe_int(sk.get("req_level"), 1)
	var cur_lvl = _safe_int(sk.get("cur_lvl"), 0)
	var eff_lvl = _safe_int(sk.get("eff_lvl"), cur_lvl)
	var mana_cost = float(sk.get("mana_cost", 0))
	var intro = str(sk.get("intro", ""))
	var cur_desc = str(sk.get("cur_desc", ""))
	var next_desc = str(sk.get("next_desc", ""))
	var is_learned = bool(sk.get("is_learned", false))
	var is_main = bool(sk.get("is_main", false))
	var is_sub = bool(sk.get("is_sub", false))
	var is_usable = is_learned or eff_lvl > 0

	if detail_name:
		detail_name.text = sk_name
	if detail_code:
		detail_code.text = "(%s)" % sk_code

	# 技能复合特性标签解析 (类型 / 范围 / 元素 / 驱动机制)
	if detail_type_tag:
		var target_type = str(sk.get("target_type", "")).to_lower()
		var damage_type = str(sk.get("damage_type", "")).to_lower()
		var cast_driver = str(sk.get("cast_driver", "")).to_lower()
		var hits = _safe_int(sk.get("hits"), 1)
		var targets = _safe_int(sk.get("targets"), 1)
		var chain_count = _safe_int(sk.get("chain_count"), 0)

		var tags: Array[String] = []

		# 1. 基础驱动门类 (严格按技能树页签 page 划分战吼/光环/战斗技能，杜绝跨分类乌龙)
		var sk_cls = str(sk.get("class", ""))
		var sk_page = _safe_int(sk.get("page"), 1)
		var s_code = sk_code.to_lower()

		if is_passive:
			tags.append("被动技能")
		elif target_type == "buff":
			if sk_cls == "pal" and sk_page in [2, 3]:
				tags.append("增益光环")
			elif sk_cls == "bar" and sk_page == 3:
				tags.append("增益战吼")
			else:
				tags.append("增益状态")
		elif target_type == "curse":
			if sk_cls == "bar" and sk_page == 3:
				tags.append("战吼削弱")
			else:
				tags.append("诅咒弱化")
		elif target_type == "summon":
			tags.append("召唤法术")
		elif is_spell:
			tags.append("法术技能")
		else:
			if s_code == "leap":
				tags.append("位移技能")
			else:
				tags.append("战斗技能")

		# 2. 作用范围与打击段数 (仅对主动输出与控制技能呈现)
		if not is_passive and target_type not in ["buff", "summon", "curse"]:
			if target_type == "combo" or hits > 1:
				tags.append("多段技能 (%d连击)" % hits if hits > 1 else "多段技能")
			elif target_type == "aoe" or targets > 1:
				tags.append("AOE技能 (%d目标)" % targets if targets > 1 else "AOE技能")
			elif target_type == "chain" or chain_count > 0:
				tags.append("连锁技能 (%d跳)" % (chain_count if chain_count > 0 else 5))
			else:
				tags.append("单体技能")

		# 3. 伤害属性
		if not is_passive and target_type not in ["buff", "summon", "curse"]:
			match damage_type:
				"phys": tags.append("物理")
				"light": tags.append("闪电")
				"fire": tags.append("火焰")
				"cold": tags.append("冰霜")
				"poison": tags.append("毒素")
				"magic": tags.append("纯魔法")
				"elemental": tags.append("全元素")
				"phys_fire": tags.append("物理/火焰")

		detail_type_tag.text = "【 %s 】" % " · ".join(tags)
		detail_type_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if is_passive:
			detail_type_tag.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		elif is_spell or target_type in ["curse", "summon"]:
			detail_type_tag.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
		elif target_type == "buff":
			detail_type_tag.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
		else:
			detail_type_tag.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

	if detail_icon:
		var icon_path = str(sk.get("icon_file", ""))
		if not icon_path.is_empty() and ResourceLoader.exists("res://assets/" + icon_path):
			detail_icon.texture = load("res://assets/" + icon_path)

	if detail_req_lvl:
		detail_req_lvl.text = "需求等级: Lv.%d" % req_lvl
	if detail_cur_lvl:
		if cur_lvl > 0:
			if eff_lvl > cur_lvl:
				detail_cur_lvl.text = "当前等级: %d/20 (+%d 装备)" % [cur_lvl, eff_lvl - cur_lvl]
				detail_cur_lvl.add_theme_color_override("font_color", Color(0.35, 0.78, 1.0))
			else:
				detail_cur_lvl.text = "当前等级: %d/20" % cur_lvl
				detail_cur_lvl.remove_theme_color_override("font_color")
		elif eff_lvl > 0:
			detail_cur_lvl.text = "当前等级: 0/20 (+%d 装备赋予)" % eff_lvl
			detail_cur_lvl.add_theme_color_override("font_color", Color(0.35, 0.78, 1.0))
		else:
			detail_cur_lvl.text = "当前等级: 未领悟"
			detail_cur_lvl.remove_theme_color_override("font_color")

	if detail_mana_cost:
		if mana_cost > 0:
			detail_mana_cost.text = "法力消耗: %.1f 点" % mana_cost
			detail_mana_cost.visible = true
		else:
			detail_mana_cost.visible = false

	if detail_intro:
		detail_intro.text = intro
		detail_intro.visible = not intro.is_empty()

	if detail_cur_desc:
		detail_cur_desc.text = cur_desc if is_usable else "尚未领悟此技能。"

	if detail_next_desc:
		if next_desc.is_empty() or cur_lvl >= 20:
			detail_next_desc.text = "已达原生投入上限 (20级)"
		else:
			detail_next_desc.text = next_desc

	# 协同技能加成渲染
	if detail_synergies:
		var syn = sk.get("synergies", {})
		if syn is Dictionary and not syn.is_empty():
			var syn_lines = ["【协同技能加成】"]
			for s_code in syn.keys():
				var s_name = _resolve_skill_display_name(s_code)
				syn_lines.append("• %s: +%s%% 效果" % [s_name, str(syn[s_code])])
			detail_synergies.text = "\n".join(syn_lines)
			detail_synergies.visible = true
		else:
			detail_synergies.visible = false

	# 底部操作按钮状态
	if is_passive:
		if btn_set_main: btn_set_main.visible = false
		if btn_set_sub: btn_set_sub.visible = false
		if passive_hint_label:
			passive_hint_label.text = "纯被动技能，自动常驻生效"
			passive_hint_label.visible = true
	else:
		if passive_hint_label: passive_hint_label.visible = false
		if btn_set_main:
			btn_set_main.visible = true
			btn_set_main.disabled = not is_usable
			btn_set_main.text = "已设为主攻 (左键)" if is_main else "设为主攻 (左键 / 双击)"
			if is_main:
				var m_style = StyleBoxFlat.new()
				m_style.bg_color = Color(0.18, 0.45, 0.2, 0.95)
				m_style.border_width_left = 1
				m_style.border_width_top = 1
				m_style.border_width_right = 1
				m_style.border_width_bottom = 1
				m_style.border_color = Color(0.3, 0.9, 0.4, 1.0)
				m_style.corner_radius_top_left = 3
				m_style.corner_radius_top_right = 3
				m_style.corner_radius_bottom_right = 3
				m_style.corner_radius_bottom_left = 3
				btn_set_main.add_theme_stylebox_override("normal", m_style)
			else:
				btn_set_main.remove_theme_stylebox_override("normal")

		if btn_set_sub:
			btn_set_sub.visible = true
			btn_set_sub.disabled = not is_usable
			btn_set_sub.text = "已设为辅助 (右键)" if is_sub else "设为辅助 (右键点击)"
			if is_sub:
				var s_style = StyleBoxFlat.new()
				s_style.bg_color = Color(0.15, 0.3, 0.5, 0.95)
				s_style.border_width_left = 1
				s_style.border_width_top = 1
				s_style.border_width_right = 1
				s_style.border_width_bottom = 1
				s_style.border_color = Color(0.3, 0.7, 1.0, 1.0)
				s_style.corner_radius_top_left = 3
				s_style.corner_radius_top_right = 3
				s_style.corner_radius_bottom_right = 3
				s_style.corner_radius_bottom_left = 3
				btn_set_sub.add_theme_stylebox_override("normal", s_style)
			else:
				btn_set_sub.remove_theme_stylebox_override("normal")

func _select_default_skill() -> void:
	var all_skills = _current_data.get("skills", {})
	if not (all_skills is Dictionary):
		return
	var first_code = ""
	for k in all_skills.keys():
		var sk = all_skills[k]
		if _safe_int(sk.get("page"), 1) == _current_page:
			if first_code.is_empty():
				first_code = k
			if _safe_int(sk.get("cur_lvl"), 0) > 0:
				_select_and_highlight_skill(k)
				return
	if not first_code.is_empty():
		_select_and_highlight_skill(first_code)

func _get_skill_info(sk_code: String) -> Dictionary:
	var all_skills = _current_data.get("skills", {})
	if all_skills is Dictionary and all_skills.has(sk_code):
		return all_skills[sk_code]
	return {}

func _resolve_skill_display_name(sk_code: String) -> String:
	var sk = _get_skill_info(sk_code)
	if not sk.is_empty():
		return str(sk.get("name", sk_code))
	return sk_code

func _on_buy_respec_pressed() -> void:
	pass

func _on_reset_pressed() -> void:
	var dlg = ConfirmationDialog.new()
	dlg.cancel_button_text = "取消"
	add_child(dlg)

	if _skill_respecs > 0:
		dlg.title = "重置技能点 (免费)"
		dlg.dialog_text = "确定要消耗 1 次【免费技能洗点机会】重置全部技能点吗？\n已分配的所有技能点将 100%% 全额返还为可用技能点。（当前剩余免费: %d 次）" % _skill_respecs
		dlg.ok_button_text = "确认重置"
		dlg.confirmed.connect(func():
			skill_reset_requested.emit()
			dlg.queue_free()
		)
	else:
		var cost = _respec_price if _respec_price > 0 else _calc_respec_gold_cost(_player_level)
		dlg.title = "重置技能点 (消耗金币)"
		if _player_gold < cost:
			dlg.dialog_text = "任务免费洗点次数已用尽！\n本次重置需要消耗金币：%s\n当前拥有金币：%s\n\n【金币不足，无法洗点】" % [
				_format_gold(cost), _format_gold(_player_gold)
			]
			dlg.ok_button_text = "我知道了"
			dlg.confirmed.connect(func(): dlg.queue_free())
		else:
			dlg.dialog_text = "任务免费洗点次数已用尽！\n本次重置技能点需要消耗金币：%s\n当前拥有金币：%s\n\n是否确认扣除金币并重置技能点？" % [
				_format_gold(cost), _format_gold(_player_gold)
			]
			dlg.ok_button_text = "确认扣费并重置"
			dlg.confirmed.connect(func():
				skill_reset_requested.emit()
				dlg.queue_free()
			)

	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()

func _get_class_icon(cls: String) -> Texture2D:
	const AVATARS = {
		"ama": "res://assets/avatars/amazon.png",
		"asn": "res://assets/avatars/assassin.png",
		"bar": "res://assets/avatars/barbarian.png",
		"dru": "res://assets/avatars/druid.png",
		"nec": "res://assets/avatars/necromancer.png",
		"pal": "res://assets/avatars/paladin.png",
		"sor": "res://assets/avatars/sorceress.png",
	}
	var p = AVATARS.get(cls.to_lower(), "res://assets/avatars/sorceress.png")
	if ResourceLoader.exists(p):
		return load(p)
	return null
