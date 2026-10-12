extends PanelContainer
class_name AFK_GShopPanel

## 暗黑2风格 4x7 随身补给商店面板 (GShopPanel)
## 4 列 x 7 行共 28 格，出售随难度进阶的红蓝药水与箭矢
## 交互：左键打开数量微调弹窗，右键 50 一堆极速购买

signal buy_requested(code: String, amount: int)
signal item_hovered(item_data: Dictionary, global_pos: Vector2)
signal item_unhovered()
signal closed()

const COLS: int = 4
const ROWS: int = 10
const TOTAL_SLOTS: int = COLS * ROWS # 40 格

# 内部节点
var _title_label: Label
var _diff_label: Label
var _gold_label: Label
var _grid: GridContainer
var _hint_label: Label

# 数量调节对话框节点
var _qty_modal: PanelContainer
var _qty_item_name: Label
var _qty_item_icon: TextureRect
var _qty_unit_price: Label
var _qty_input: LineEdit
var _qty_total_price: Label
var _btn_confirm_buy: Button
var _current_modal_item: Dictionary = {}
var _qty_preset_btns: Dictionary = {} # 档位 -> Button (弹窗按商品类型切换 2/50 档可见性)
var _current_modal_qty: int = 1

# 数据状态
var current_gold: int = 0
var current_diff: String = "normal"
var shop_items: Array = []
var slots: Array[Button] = []
var slot_item_map: Dictionary = {} # slot_idx -> item_data

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# 1. 外部暗金风格面板边框
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.08, 0.065, 0.045, 0.98)
	frame.border_width_left = 2
	frame.border_width_top = 2
	frame.border_width_right = 2
	frame.border_width_bottom = 2
	frame.border_color = Color(0.55, 0.42, 0.20, 1.0) # 暗金色浮雕边框
	frame.set_corner_radius_all(6)
	frame.set_content_margin_all(10.0)
	frame.shadow_color = Color(0, 0, 0, 0.85)
	frame.shadow_size = 10
	add_theme_stylebox_override("panel", frame)

	custom_minimum_size = Vector2(230, 480)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# 2. 顶部标题栏 (标题 + 关闭按钮)
	var title_box := HBoxContainer.new()
	main_vbox.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "◆ 随身补给商店 ◆"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	title_box.add_child(_title_label)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(22, 22)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	btn_close.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.5))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0, 0, 0, 0)
	btn_close.add_theme_stylebox_override("normal", close_style)
	btn_close.add_theme_stylebox_override("hover", close_style)
	btn_close.add_theme_stylebox_override("pressed", close_style)
	btn_close.pressed.connect(close)
	title_box.add_child(btn_close)

	# 3. 难度与金币信息栏
	var info_box := HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	main_vbox.add_child(info_box)

	_diff_label = Label.new()
	_diff_label.text = "[普通难度]"
	_diff_label.add_theme_font_size_override("font_size", 11)
	_diff_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	info_box.add_child(_diff_label)

	_gold_label = Label.new()
	_gold_label.text = "金币: 0 G"
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_size_override("font_size", 11)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	info_box.add_child(_gold_label)

	# 4. 4x7 物品网格区
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(_grid)

	for i in range(TOTAL_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(46, 46)
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = true

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.06, 0.05, 0.04, 0.95)
		slot_style.set_border_width_all(1)
		slot_style.border_color = Color(0.35, 0.28, 0.16, 0.8)
		slot_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", slot_style)

		var hover_style := slot_style.duplicate()
		hover_style.border_color = Color(0.95, 0.82, 0.35, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)

		# 单价角标 (右下角金色小字)
		var price_badge := Label.new()
		price_badge.name = "PriceBadge"
		price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		price_badge.offset_left = -44.0
		price_badge.offset_top = -14.0
		price_badge.offset_right = -2.0
		price_badge.offset_bottom = -1.0
		price_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		price_badge.add_theme_font_size_override("font_size", 9)
		price_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		price_badge.add_theme_constant_override("outline_size", 2)
		price_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		price_badge.visible = false
		btn.add_child(price_badge)

		btn.mouse_entered.connect(_on_slot_hovered.bind(i, btn))
		btn.mouse_exited.connect(_on_slot_unhovered)
		btn.gui_input.connect(_on_slot_gui_input.bind(i))

		_grid.add_child(btn)
		slots.append(btn)

	# 5. 底部操作说明行
	_hint_label = Label.new()
	_hint_label.text = "左键: 自选数量 | 右键: 50个一堆秒买"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	main_vbox.add_child(_hint_label)

	# 6. 自选数量购买弹窗 (初始隐藏，左键点击商品时弹出)
	_build_qty_modal()

func _build_qty_modal() -> void:
	_qty_modal = PanelContainer.new()
	_qty_modal.visible = false
	_qty_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var m_style := StyleBoxFlat.new()
	m_style.bg_color = Color(0.05, 0.04, 0.03, 0.98)
	m_style.set_border_width_all(2)
	m_style.border_color = Color(0.85, 0.70, 0.30, 1.0)
	m_style.set_corner_radius_all(6)
	m_style.set_content_margin_all(10.0)
	m_style.shadow_color = Color(0, 0, 0, 0.9)
	m_style.shadow_size = 12
	_qty_modal.add_theme_stylebox_override("panel", m_style)

	_qty_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_qty_modal)

	var mvbox := VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 8)
	_qty_modal.add_child(mvbox)

	# 弹窗标题
	var mtitle := Label.new()
	mtitle.text = "◆ 选购补给数量 ◆"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 13)
	mtitle.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	mvbox.add_child(mtitle)

	# 商品信息横条 (图标 + 名字 + 单价)
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 8)
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvbox.add_child(item_row)

	_qty_item_icon = TextureRect.new()
	_qty_item_icon.custom_minimum_size = Vector2(32, 32)
	_qty_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qty_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(_qty_item_icon)

	var name_vbox := VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 2)
	item_row.add_child(name_vbox)

	_qty_item_name = Label.new()
	_qty_item_name.text = "次级治疗药水"
	_qty_item_name.add_theme_font_size_override("font_size", 12)
	_qty_item_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_vbox.add_child(_qty_item_name)

	_qty_unit_price = Label.new()
	_qty_unit_price.text = "单价: 25 G"
	_qty_unit_price.add_theme_font_size_override("font_size", 10)
	_qty_unit_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_vbox.add_child(_qty_unit_price)

	# 数量步进控制 [-] [数量] [+]
	var step_row := HBoxContainer.new()
	step_row.alignment = BoxContainer.ALIGNMENT_CENTER
	step_row.add_theme_constant_override("separation", 6)
	mvbox.add_child(step_row)

	var btn_sub := Button.new()
	btn_sub.text = "-"
	btn_sub.custom_minimum_size = Vector2(28, 26)
	btn_sub.focus_mode = Control.FOCUS_NONE
	btn_sub.pressed.connect(func(): _adjust_modal_qty(-1))
	_style_dialog_button(btn_sub)
	step_row.add_child(btn_sub)

	_qty_input = LineEdit.new()
	_qty_input.text = "1"
	_qty_input.custom_minimum_size = Vector2(60, 26)
	_qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_input.text_changed.connect(_on_qty_text_changed)
	step_row.add_child(_qty_input)

	var btn_add := Button.new()
	btn_add.text = "+"
	btn_add.custom_minimum_size = Vector2(28, 26)
	btn_add.focus_mode = Control.FOCUS_NONE
	btn_add.pressed.connect(func(): _adjust_modal_qty(1))
	_style_dialog_button(btn_add)
	step_row.add_child(btn_add)

	# 快捷预设按钮排 [1] [10] [50] [最大]
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 4)
	mvbox.add_child(quick_row)

	for q in [1, 2, 10, 50]:
		var q_btn := Button.new()
		q_btn.text = str(q)
		q_btn.custom_minimum_size = Vector2(36, 22)
		q_btn.focus_mode = Control.FOCUS_NONE
		q_btn.add_theme_font_size_override("font_size", 10)
		q_btn.pressed.connect(func(): _set_modal_qty(q))
		_style_dialog_button(q_btn)
		quick_row.add_child(q_btn)
		if q == 2 or q == 50:
			_qty_preset_btns[q] = q_btn

	var btn_max := Button.new()
	btn_max.text = "最大"
	btn_max.custom_minimum_size = Vector2(40, 22)
	btn_max.focus_mode = Control.FOCUS_NONE
	btn_max.add_theme_font_size_override("font_size", 10)
	btn_max.pressed.connect(_on_quick_max_pressed)
	_style_dialog_button(btn_max)
	quick_row.add_child(btn_max)

	# 总价与金币核算显示
	_qty_total_price = Label.new()
	_qty_total_price.text = "总计: 25 G"
	_qty_total_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_total_price.add_theme_font_size_override("font_size", 12)
	_qty_total_price.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	mvbox.add_child(_qty_total_price)

	# 底部按钮: [确认购买] [取消]
	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 10)
	mvbox.add_child(act_row)

	_btn_confirm_buy = Button.new()
	_btn_confirm_buy.text = "确认购买"
	_btn_confirm_buy.custom_minimum_size = Vector2(80, 28)
	_btn_confirm_buy.focus_mode = Control.FOCUS_NONE
	_style_accent_button(_btn_confirm_buy)
	_btn_confirm_buy.pressed.connect(_on_confirm_buy_pressed)
	act_row.add_child(_btn_confirm_buy)

	var btn_cancel := Button.new()
	btn_cancel.text = "取消"
	btn_cancel.custom_minimum_size = Vector2(60, 28)
	btn_cancel.focus_mode = Control.FOCUS_NONE
	_style_dialog_button(btn_cancel)
	btn_cancel.pressed.connect(func(): _qty_modal.visible = false)
	act_row.add_child(btn_cancel)

# ========== 业务更新接口 ==========

func update_shop_data(data: Dictionary) -> void:
	current_diff = str(data.get("difficulty", "normal")).to_lower()
	current_gold = _safe_int(data.get("gold"), 0)
	shop_items = data.get("items", [])

	_update_header()
	_render_grid()

	# 若数量弹窗开着，同步金币核算
	if _qty_modal.visible:
		_refresh_modal_price_display()

func update_gold(gold_val: int) -> void:
	current_gold = gold_val
	_gold_label.text = "金币: %s G" % _format_number(current_gold)
	if _qty_modal.visible:
		_refresh_modal_price_display()

func _update_header() -> void:
	var diff_name = "普通难度"
	var diff_col = Color(0.3, 0.85, 0.4)
	if current_diff in ["nightmare", "nm"]:
		diff_name = "噩梦难度"
		diff_col = Color(0.95, 0.75, 0.2)
	elif current_diff == "hell":
		diff_name = "地狱难度"
		diff_col = Color(1.0, 0.3, 0.3)

	_diff_label.text = "[%s]" % diff_name
	_diff_label.add_theme_color_override("font_color", diff_col)
	_gold_label.text = "金币: %s G" % _format_number(current_gold)

func _render_grid() -> void:
	slot_item_map.clear()

	for i in range(TOTAL_SLOTS):
		var btn = slots[i]
		var price_badge: Label = btn.get_node_or_null("PriceBadge")

		if i < shop_items.size():
			var item_data: Dictionary = shop_items[i]
			slot_item_map[i] = item_data

			# 图标
			var icon_path: String = str(item_data.get("icon", ""))
			var tex = AnsiHelper.load_item_texture(icon_path)
			btn.icon = tex

			# 单价角标
			var p = int(item_data.get("price", 0))
			if price_badge:
				price_badge.text = "%dG" % p
				price_badge.visible = true
		else:
			# 空格
			btn.icon = null
			if price_badge:
				price_badge.visible = false

# ========== 交互与事件 ==========

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if not slot_item_map.has(slot_idx):
		return

	var item_data: Dictionary = slot_item_map[slot_idx]
	var code = str(item_data.get("code", ""))
	var item_type = str(item_data.get("type", "hp"))

	if event.button_index == MOUSE_BUTTON_LEFT:
		# 左键：弹出数量选择微调框
		_open_qty_modal(item_data)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# 右键：50 一堆极速购买（药水为 50，箭矢为 1）
		var buy_amt = 50 if item_type in ["hp", "mp"] else 1
		_do_buy(code, buy_amt)

func _on_slot_hovered(slot_idx: int, btn: Button) -> void:
	if not slot_item_map.has(slot_idx):
		return

	var item_data: Dictionary = slot_item_map[slot_idx]
	# 构建 tooltip 所需数据格式
	var tip_data: Dictionary = {
		"name": item_data.get("name", "补给品"),
		"icon": item_data.get("icon", ""),
		"color": "#e0b040" if item_data.get("type") == "ammo" else ("#ff6666" if item_data.get("type") == "hp" else "#6699ff"),
		"desc": "单价: %d 金币 / %s\n%s" % [
			int(item_data.get("price", 0)),
			str(item_data.get("unit", "件")),
			str(item_data.get("desc", ""))
		]
	}
	item_hovered.emit(tip_data, btn.global_position)

func _on_slot_unhovered() -> void:
	item_unhovered.emit()

func _open_qty_modal(item_data: Dictionary) -> void:
	_current_modal_item = item_data
	var code = str(item_data.get("code", ""))
	var item_type = str(item_data.get("type", "hp"))
	# 符文/弹药类贵重品隐藏 50 档预设, 显示 2 档; 药水反之
	var is_bulk_type = item_type in ["hp", "mp"]
	if _qty_preset_btns.has(50):
		_qty_preset_btns[50].visible = is_bulk_type
	if _qty_preset_btns.has(2):
		_qty_preset_btns[2].visible = not is_bulk_type

	# 默认数量：药水默认 50，弹药默认 1
	_current_modal_qty = 50 if item_type in ["hp", "mp"] else 1

	_qty_item_name.text = str(item_data.get("name", "商品"))
	var p = int(item_data.get("price", 0))
	var unit = str(item_data.get("unit", "个"))
	_qty_unit_price.text = "单价: %d G / %s" % [p, unit]

	var tex = AnsiHelper.load_item_texture(str(item_data.get("icon", "")))
	_qty_item_icon.texture = tex

	_qty_input.text = str(_current_modal_qty)
	_refresh_modal_price_display()
	_qty_modal.visible = true

func _adjust_modal_qty(delta: int) -> void:
	_set_modal_qty(_current_modal_qty + delta)

func _set_modal_qty(val: int) -> void:
	_current_modal_qty = clamp(val, 1, 500)
	_qty_input.text = str(_current_modal_qty)
	_refresh_modal_price_display()

func _on_qty_text_changed(new_text: String) -> void:
	var val = new_text.to_int()
	if val <= 0: val = 1
	if val > 500: val = 500
	_current_modal_qty = val
	_refresh_modal_price_display()

func _on_quick_max_pressed() -> void:
	var unit_p = int(_current_modal_item.get("price", 1))
	if unit_p <= 0: unit_p = 1
	var max_afford = current_gold / unit_p
	if max_afford <= 0: max_afford = 1
	_set_modal_qty(max_afford)

func _refresh_modal_price_display() -> void:
	if _current_modal_item.is_empty():
		return

	var unit_p = int(_current_modal_item.get("price", 0))
	var total = unit_p * _current_modal_qty

	var can_afford = (current_gold >= total)
	if can_afford:
		_qty_total_price.text = "总计: %s G (拥有: %s G)" % [
			_format_number(total),
			_format_number(current_gold)
		]
		_qty_total_price.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		_btn_confirm_buy.disabled = false
	else:
		_qty_total_price.text = "总计: %s G [金币不足! 仅有 %s G]" % [
			_format_number(total),
			_format_number(current_gold)
		]
		_qty_total_price.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_btn_confirm_buy.disabled = true

func _on_confirm_buy_pressed() -> void:
	if _current_modal_item.is_empty():
		return
	var code = str(_current_modal_item.get("code", ""))
	_do_buy(code, _current_modal_qty)
	_qty_modal.visible = false

func _do_buy(code: String, amount: int) -> void:
	if code.is_empty() or amount <= 0:
		return
	buy_requested.emit(code, amount)
	if is_inside_tree() and (Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient")):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw("gshop buy %s %d" % [code, amount])

func open() -> void:
	visible = true
	if _qty_modal:
		_qty_modal.visible = false
	if is_inside_tree() and (Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient")):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw("gshop")

func close() -> void:
	visible = false
	if _qty_modal:
		_qty_modal.visible = false
	item_unhovered.emit()
	closed.emit()

# ========== 样式与辅助工具 ==========

func _style_dialog_button(btn: Button) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.12, 0.09, 0.95)
	st.set_border_width_all(1)
	st.border_color = Color(0.45, 0.38, 0.22, 1.0)
	st.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", st)

	var hov := st.duplicate()
	hov.border_color = Color(0.95, 0.82, 0.35, 1.0)
	hov.bg_color = Color(0.20, 0.17, 0.12, 0.98)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))

func _style_accent_button(btn: Button) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.35, 0.22, 0.08, 0.98)
	st.set_border_width_all(1)
	st.border_color = Color(0.95, 0.82, 0.35, 1.0)
	st.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", st)

	var hov := st.duplicate()
	hov.bg_color = Color(0.50, 0.32, 0.10, 1.0)
	hov.border_color = Color(1.0, 0.92, 0.55, 1.0)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))

static func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return res

static func _safe_int(val, default_val: int = 0) -> int:
	if val == null:
		return default_val
	if val is int:
		return val
	if val is float:
		return int(val)
	if val is String:
		return int(val) if val.is_valid_int() else default_val
	if val is bool:
		return 1 if val else 0
	return default_val

