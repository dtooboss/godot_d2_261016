extends PanelContainer

## 赫拉迪姆大储物箱面板 (D2R 风格: 账号共享仓 1~3 + 个人专属仓) — 纯后端数据驱动
## 紧凑不越界排版、智能图标解析、完整暗黑2词缀 Tooltip、右键直接存取与拖拽

signal action_requested(cmd_str: String)
signal item_hovered(item_data: Dictionary, global_pos: Vector2)
signal item_unhovered()
signal closed()

const COLS: int = 10
const ROWS: int = 10
const TOTAL_SLOTS: int = COLS * ROWS # 100 格

var slots: Array[InvSlotButton] = []
var items_map: Dictionary = {} # slot_idx -> item_data

var current_tab: int = 1
var account_id: String = ""
var stash_gold: int = 0
var max_stash_gold: int = 2500000
var player_gold: int = 0

# UI 节点引用
var _title_label: Label
var _tabs_container: HBoxContainer
var _tab_buttons: Array[Button] = []
var _gold_label: Label
var _player_gold_label: Label
var _grid: GridContainer
var _hint_label: Label

# 数量选择弹窗组件 (用于药水、符文等叠加物品取出数量选择)
var _qty_modal: PanelContainer = null
var _qty_item_name: Label = null
var _qty_item_icon: TextureRect = null
var _qty_stock_label: Label = null
var _qty_slider: HSlider = null
var _qty_spin: SpinBox = null
var _btn_qty_1: Button = null
var _btn_qty_half: Button = null
var _btn_qty_all: Button = null
var _btn_qty_confirm: Button = null
var _btn_qty_cancel: Button = null
var _pending_withdraw_item: Dictionary = {}
var _current_withdraw_amount: int = 1
var _max_withdraw_amount: int = 1

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _title_label:
		_build_ui()

func _build_ui() -> void:
	# 暗金微雕外框风格 (紧凑外边距，防止垂直越界)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.08, 0.065, 0.045, 0.98)
	frame.border_width_left = 2
	frame.border_width_top = 2
	frame.border_width_right = 2
	frame.border_width_bottom = 2
	frame.border_color = Color(0.65, 0.48, 0.22, 1.0)
	frame.set_corner_radius_all(6)
	frame.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	# 1. 顶部标题栏 (标题 + 关闭 ✕)
	var title_box := HBoxContainer.new()
	vbox.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "◆ 赫拉迪姆大储物箱 ◆"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
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
	btn_close.pressed.connect(_close)
	title_box.add_child(btn_close)

	# 2. 标签页切换栏 (共享仓1, 共享仓2, 共享仓3, 个人专属 - 纯文字去Emoji)
	_tabs_container = HBoxContainer.new()
	_tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_tabs_container)

	var tab_configs = [
		{ "id": 1, "name": "共享仓 1" },
		{ "id": 2, "name": "共享仓 2" },
		{ "id": 3, "name": "共享仓 3" },
		{ "id": 0, "name": "个人专属" },
	]

	for cfg in tab_configs:
		var btn_tab := Button.new()
		btn_tab.text = cfg["name"]
		btn_tab.custom_minimum_size = Vector2(88, 24)
		btn_tab.add_theme_font_size_override("font_size", 11)
		btn_tab.focus_mode = Control.FOCUS_NONE
		_style_tab_button(btn_tab, false)
		var t_id = cfg["id"]
		btn_tab.pressed.connect(func():
			if _qty_modal: _qty_modal.visible = false
			action_requested.emit("stash tab %d" % t_id)
		)
		_tabs_container.add_child(btn_tab)
		_tab_buttons.append(btn_tab)

	# 3. 紧凑型金币操作栏 (高度压缩，消除Emoji，防止截断)
	var gold_panel := PanelContainer.new()
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	g_style.border_color = Color(0.35, 0.28, 0.15, 0.7)
	g_style.set_border_width_all(1)
	g_style.set_corner_radius_all(3)
	g_style.set_content_margin_all(3.0)
	gold_panel.add_theme_stylebox_override("panel", g_style)
	vbox.add_child(gold_panel)

	var gold_vbox := VBoxContainer.new()
	gold_vbox.add_theme_constant_override("separation", 2)
	gold_panel.add_child(gold_vbox)

	var gold_info_hbox := HBoxContainer.new()
	gold_info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_info_hbox.add_theme_constant_override("separation", 8)
	gold_vbox.add_child(gold_info_hbox)

	_gold_label = Label.new()
	_gold_label.text = "仓内金币: 0 / 2,500,000"
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.add_theme_font_size_override("font_size", 11)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	gold_info_hbox.add_child(_gold_label)

	_player_gold_label = Label.new()
	_player_gold_label.text = "随身: 0"
	_player_gold_label.add_theme_font_size_override("font_size", 11)
	_player_gold_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	gold_info_hbox.add_child(_player_gold_label)

	# 快捷存取金币按钮排
	var gold_btn_hbox := HBoxContainer.new()
	gold_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_btn_hbox.add_theme_constant_override("separation", 4)
	gold_vbox.add_child(gold_btn_hbox)

	_add_gold_btn(gold_btn_hbox, "+1W", true, 10000)
	_add_gold_btn(gold_btn_hbox, "+5W", true, 50000)
	_add_gold_btn(gold_btn_hbox, "+全部", true, -1)
	_add_gold_btn(gold_btn_hbox, "-1W", false, 10000)
	_add_gold_btn(gold_btn_hbox, "-5W", false, 50000)
	_add_gold_btn(gold_btn_hbox, "-全部", false, -1)

	# 4. 10x10 格子矩阵区 (单格 32x32 紧凑排列，外包滚动保护，限高 256px，绝不下端越界)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 256)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(_grid)

	for i in range(TOTAL_SLOTS):
		var btn := InvSlotButton.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.flat = false
		btn.panel_owner = self
		btn.slot_type = "stash"
		btn.slot_index = i
		btn.focus_mode = Control.FOCUS_NONE

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.05, 0.038, 0.95)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.24, 0.14, 0.8)
		style.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.border_color = Color(0.9, 0.78, 0.4, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = true

		btn.mouse_entered.connect(_on_slot_hovered.bind(i, btn))
		btn.mouse_exited.connect(_on_slot_unhovered)
		btn.gui_input.connect(_on_slot_gui_input.bind(i))
		_grid.add_child(btn)
		slots.append(btn)

	# 5. 底部操作说明提示行 (纯文字，消除Emoji)
	_hint_label = Label.new()
	_hint_label.text = "提示：右键/点击储物箱物品取出；右键随身背包物品存入当前仓；支持拖拽"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	vbox.add_child(_hint_label)

	# 6. 数量选择模态弹窗 (用于叠加物品取出，默认隐藏)
	_build_qty_modal()

## 构建暗黑2风格数量选择弹窗 (用于叠加物品取出，严格防护边界)
func _build_qty_modal() -> void:
	_qty_modal = PanelContainer.new()
	_qty_modal.custom_minimum_size = Vector2(290, 175)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.98)
	sb.border_color = Color(0.9, 0.78, 0.28, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_qty_modal.add_theme_stylebox_override("panel", sb)
	
	_qty_modal.set_anchors_preset(Control.PRESET_CENTER)
	_qty_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_qty_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_qty_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_qty_modal.visible = false
	add_child(_qty_modal)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_qty_modal.add_child(vbox)
	
	var title := Label.new()
	title.text = "❖ 取出数量 ❖"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 10)
	vbox.add_child(item_row)
	
	_qty_item_icon = TextureRect.new()
	_qty_item_icon.custom_minimum_size = Vector2(36, 36)
	_qty_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qty_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(_qty_item_icon)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(info_vbox)
	
	_qty_item_name = Label.new()
	_qty_item_name.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_qty_item_name)
	
	_qty_stock_label = Label.new()
	_qty_stock_label.add_theme_font_size_override("font_size", 11)
	_qty_stock_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(_qty_stock_label)
	
	# 快捷按钮行 (1, 一半, 全部)
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 8)
	vbox.add_child(quick_row)
	
	_btn_qty_1 = Button.new()
	_btn_qty_1.text = " 1 "
	_btn_qty_1.custom_minimum_size = Vector2(50, 24)
	_btn_qty_1.focus_mode = Control.FOCUS_NONE
	_btn_qty_1.pressed.connect(func(): _set_modal_qty(1))
	quick_row.add_child(_btn_qty_1)
	
	_btn_qty_half = Button.new()
	_btn_qty_half.text = " 一半 "
	_btn_qty_half.custom_minimum_size = Vector2(60, 24)
	_btn_qty_half.focus_mode = Control.FOCUS_NONE
	_btn_qty_half.pressed.connect(func(): _set_modal_qty(max(1, _max_withdraw_amount / 2)))
	quick_row.add_child(_btn_qty_half)
	
	_btn_qty_all = Button.new()
	_btn_qty_all.text = " 全部 "
	_btn_qty_all.custom_minimum_size = Vector2(60, 24)
	_btn_qty_all.focus_mode = Control.FOCUS_NONE
	_btn_qty_all.pressed.connect(func(): _set_modal_qty(_max_withdraw_amount))
	quick_row.add_child(_btn_qty_all)
	
	# 数量调节行 (- Slider + SpinBox)
	var adjust_row := HBoxContainer.new()
	adjust_row.alignment = BoxContainer.ALIGNMENT_CENTER
	adjust_row.add_theme_constant_override("separation", 6)
	vbox.add_child(adjust_row)
	
	var btn_minus := Button.new()
	btn_minus.text = " - "
	btn_minus.custom_minimum_size = Vector2(26, 24)
	btn_minus.focus_mode = Control.FOCUS_NONE
	btn_minus.pressed.connect(func(): _set_modal_qty(_current_withdraw_amount - 1))
	adjust_row.add_child(btn_minus)
	
	_qty_slider = HSlider.new()
	_qty_slider.min_value = 1
	_qty_slider.max_value = 100
	_qty_slider.step = 1
	_qty_slider.custom_minimum_size = Vector2(80, 20)
	_qty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_slider.value_changed.connect(func(v): _set_modal_qty(int(v)))
	adjust_row.add_child(_qty_slider)
	
	var btn_plus := Button.new()
	btn_plus.text = " + "
	btn_plus.custom_minimum_size = Vector2(26, 24)
	btn_plus.focus_mode = Control.FOCUS_NONE
	btn_plus.pressed.connect(func(): _set_modal_qty(_current_withdraw_amount + 1))
	adjust_row.add_child(btn_plus)
	
	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1
	_qty_spin.max_value = 100
	_qty_spin.step = 1
	_qty_spin.custom_minimum_size = Vector2(70, 24)
	_qty_spin.value_changed.connect(func(v): _set_modal_qty(int(v)))
	adjust_row.add_child(_qty_spin)
	
	# 操作按钮行 (确认取出 / 取消)
	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 16)
	vbox.add_child(act_row)
	
	_btn_qty_confirm = Button.new()
	_btn_qty_confirm.text = " 确认取出 "
	_btn_qty_confirm.custom_minimum_size = Vector2(90, 28)
	_btn_qty_confirm.focus_mode = Control.FOCUS_NONE
	_btn_qty_confirm.pressed.connect(_on_qty_confirm_pressed)
	act_row.add_child(_btn_qty_confirm)
	
	_btn_qty_cancel = Button.new()
	_btn_qty_cancel.text = " 取消 "
	_btn_qty_cancel.custom_minimum_size = Vector2(70, 28)
	_btn_qty_cancel.focus_mode = Control.FOCUS_NONE
	_btn_qty_cancel.pressed.connect(func(): _qty_modal.visible = false)
	act_row.add_child(_btn_qty_cancel)

func _set_modal_qty(val: int) -> void:
	_current_withdraw_amount = clamp(val, 1, _max_withdraw_amount)
	if _qty_slider and int(_qty_slider.value) != _current_withdraw_amount:
		_qty_slider.value = _current_withdraw_amount
	if _qty_spin and int(_qty_spin.value) != _current_withdraw_amount:
		_qty_spin.value = _current_withdraw_amount

func _show_amount_modal(item_data: Dictionary, total_amt: int) -> void:
	_pending_withdraw_item = item_data
	_max_withdraw_amount = max(1, total_amt)
	_current_withdraw_amount = _max_withdraw_amount
	
	var q = str(item_data.get("quality", "normal")).to_lower()
	var col_hex = _get_quality_color_hex(q)
	var col = Color.from_string(col_hex, Color(0.85, 0.85, 0.85))
	_qty_item_name.text = AnsiHelper.to_plain_text(str(item_data.get("name", "物品")))
	_qty_item_name.add_theme_color_override("font_color", col)
	
	var tex = item_data.get("icon_texture")
	if tex is Texture2D:
		_qty_item_icon.texture = tex
	else:
		var icon_path = str(item_data.get("icon", ""))
		_qty_item_icon.texture = _resolve_item_icon(_qty_item_name.text, icon_path)
		
	_qty_stock_label.text = "仓内存量: %d" % _max_withdraw_amount
	if _qty_slider:
		_qty_slider.min_value = 1
		_qty_slider.max_value = _max_withdraw_amount
	if _qty_spin:
		_qty_spin.min_value = 1
		_qty_spin.max_value = _max_withdraw_amount
		
	_set_modal_qty(_max_withdraw_amount)
	_qty_modal.visible = true

func _on_qty_confirm_pressed() -> void:
	if _pending_withdraw_item.is_empty():
		_qty_modal.visible = false
		return
	var uuid = str(_pending_withdraw_item.get("uuid", ""))
	if uuid.is_empty():
		uuid = str(_pending_withdraw_item.get("slot", ""))
	if not uuid.is_empty():
		var amt = clamp(_current_withdraw_amount, 1, _max_withdraw_amount)
		action_requested.emit("stash take %d %s %d" % [current_tab, uuid, amt])
	_qty_modal.visible = false

func _add_gold_btn(parent: Control, label_text: String, is_deposit: bool, amount: int) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(52, 20)
	btn.add_theme_font_size_override("font_size", 10)
	btn.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(2)
	style.set_border_width_all(1)
	if is_deposit:
		style.bg_color = Color(0.12, 0.2, 0.12, 0.9)
		style.border_color = Color(0.3, 0.6, 0.3, 0.8)
		btn.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
	else:
		style.bg_color = Color(0.2, 0.14, 0.1, 0.9)
		style.border_color = Color(0.6, 0.4, 0.2, 0.8)
		btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.border_color = Color(1.0, 0.9, 0.5, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	btn.pressed.connect(func():
		var final_amt = amount
		if is_deposit:
			if amount == -1: final_amt = player_gold
			if final_amt <= 0: return
			action_requested.emit("stash gold put %d %d" % [final_amt, current_tab])
		else:
			if amount == -1: final_amt = stash_gold
			if final_amt <= 0: return
			action_requested.emit("stash gold get %d %d" % [final_amt, current_tab])
	)
	parent.add_child(btn)

func _style_tab_button(btn: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	if is_active:
		style.bg_color = Color(0.32, 0.18, 0.06, 0.98)
		style.border_color = Color(0.95, 0.8, 0.35, 1.0)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	else:
		style.bg_color = Color(0.1, 0.08, 0.06, 0.92)
		style.border_color = Color(0.38, 0.3, 0.18, 0.8)
		btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.border_color = Color(0.9, 0.75, 0.4, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

# ========== 服务端 gstash 状态帧渲染 (纯后端权威驱动) ==========
func render_gstash_data(data: Dictionary) -> void:
	if not _title_label:
		_build_ui()
	if _qty_modal and _qty_modal.visible:
		_qty_modal.visible = false
	var raw_tab = data.get("cur_tab")
	if raw_tab == null and data.has("cur_tab_id"):
		raw_tab = data["cur_tab_id"]
	current_tab = AnsiHelper.to_safe_int(raw_tab, 1)
	account_id = str(data.get("account", ""))
	stash_gold = AnsiHelper.to_safe_int(data.get("gold"), 0)
	max_stash_gold = AnsiHelper.to_safe_int(data.get("max_gold"), 2500000)
	player_gold = AnsiHelper.to_safe_int(data.get("player_gold"), 0)

	if not account_id.is_empty():
		_title_label.text = "◆ 赫拉迪姆大储物箱 (通行证: %s) ◆" % account_id

	# 更新金币
	_gold_label.text = "仓内金币: %s / %s" % [_format_number(stash_gold), _format_number(max_stash_gold)]
	_player_gold_label.text = "随身: %s" % _format_number(player_gold)

	# 更新标签页按钮外观与容量角标
	var tabs_info = data.get("tabs", [])
	var tab_counts = {}
	if tabs_info is Array:
		for t_data in tabs_info:
			if t_data is Dictionary:
				tab_counts[AnsiHelper.to_safe_int(t_data.get("id"), 0)] = {
					"used": AnsiHelper.to_safe_int(t_data.get("used"), 0),
					"max": AnsiHelper.to_safe_int(t_data.get("max"), 100),
				}

	var tab_configs = [
		{ "id": 1, "name": "共享仓 1" },
		{ "id": 2, "name": "共享仓 2" },
		{ "id": 3, "name": "共享仓 3" },
		{ "id": 0, "name": "个人专属" },
	]

	for idx in range(min(_tab_buttons.size(), tab_configs.size())):
		var btn = _tab_buttons[idx]
		var cfg = tab_configs[idx]
		var t_id = cfg["id"]
		var count_str = ""
		if tab_counts.has(t_id):
			count_str = " (%d/%d)" % [tab_counts[t_id]["used"], tab_counts[t_id]["max"]]
		btn.text = cfg["name"] + count_str
		_style_tab_button(btn, t_id == current_tab)

	# 清空格子
	items_map.clear()
	for btn in slots:
		btn.icon = null
		if btn.has_method("set_slot_amount"): btn.set_slot_amount(0)
		if btn.has_method("set_slot_quality"): btn.set_slot_quality("")
		if btn.has_method("set_slot_sockets"): btn.set_slot_sockets(0, [])
		if btn.has_method("set_slot_unmet"): btn.set_slot_unmet(false)

	# 填充物品
	var items = data.get("items", [])
	if items is Array:
		for it in items:
			if not (it is Dictionary): continue
			var slot_idx = AnsiHelper.to_safe_int(it.get("slot"), -1)
			if slot_idx < 0 or slot_idx >= slots.size(): continue

			var item_dict = it.get("item_data", it)
			var raw_cname = str(it.get("colored_name", it.get("name", "")))
			var clean_name = AnsiHelper.to_plain_text(str(it.get("name", "")))
			var quality_s = str(it.get("quality", "normal")).to_lower()
			var icon_p = str(it.get("icon", ""))
			var desc_p = str(it.get("desc", ""))
			if desc_p.is_empty() and item_dict is Dictionary:
				desc_p = str(item_dict.get("desc", ""))

			var item_data := {
				"name": clean_name,
				"raw_name": raw_cname,
				"quality": quality_s,
				"type": quality_s.capitalize(),
				"color": _get_quality_color_hex(quality_s),
				"desc": desc_p,
				"cmd": "stash look %d %d" % [current_tab, slot_idx],
				"file_id": str(it.get("uuid", it.get("file_id", ""))),
				"uuid": str(it.get("uuid", "")),
				"amount": AnsiHelper.to_safe_int(it.get("amount"), 1),
				"sockets": AnsiHelper.to_safe_int(it.get("sockets"), 0),
				"inlays": item_dict.get("inlay", []) if item_dict is Dictionary and item_dict.get("inlay") is Array else [],
				"slot": str(it.get("slot", item_dict.get("slot", ""))),
				"d2_type": str(it.get("d2_type", item_dict.get("d2_type", ""))),
				"is_consumable": AnsiHelper.to_safe_int(it.get("is_consumable", item_dict.get("is_consumable", 0)), 0),
				"unmet": AnsiHelper.to_safe_int(it.get("unmet", 0), 0),
				"item_data": item_dict
			}

			# 智能图标加载：优先 load_item_texture，兜底智能名称解析
			var tex := _resolve_item_icon(clean_name, icon_p)
			if tex:
				item_data["icon_texture"] = tex
				slots[slot_idx].icon = tex

			if slots[slot_idx].has_method("set_slot_amount"):
				slots[slot_idx].set_slot_amount(item_data["amount"])
			if slots[slot_idx].has_method("set_slot_quality"):
				slots[slot_idx].set_slot_quality(item_data["quality"])
			if slots[slot_idx].has_method("set_slot_sockets"):
				slots[slot_idx].set_slot_sockets(item_data["sockets"], item_data["inlays"])
			if slots[slot_idx].has_method("set_slot_unmet"):
				slots[slot_idx].set_slot_unmet(bool(item_data["unmet"]))

			items_map[slot_idx] = item_data

## 智能图标解析器 (双轨容错，保证 100% 呈现有效暗黑2图标)
func _resolve_item_icon(item_name: String, icon_path: String) -> Texture2D:
	var tex: Texture2D = null
	if not icon_path.is_empty() and icon_path != "items/misc/bag.png":
		tex = AnsiHelper.load_item_texture(icon_path)
	if tex:
		return tex

	var n = item_name.to_lower()
	if "护身符" in n or "charm" in n or "火炬" in n or "毁灭" in n:
		if "超大" in n or "grand" in n:
			return load("res://assets/items/misc/charm/charm_large.lowend.png")
		elif "大型" in n or "large" in n:
			return load("res://assets/items/misc/charm/charm_medium.lowend.png")
		return load("res://assets/items/misc/charm/charm_small.lowend.png")
	elif "带" in n or "腰" in n or "belt" in n or "sash" in n:
		return load("res://assets/items/armor/belt/belt_m.lowend.png")
	elif "手套" in n or "钳" in n or "glove" in n:
		return load("res://assets/items/armor/glove/gloves_l.lowend.png")
	elif "项链" in n or "眼" in n or "amulet" in n:
		return load("res://assets/items/misc/amulet/amulet1.lowend.png")
	elif "戒" in n or "ring" in n:
		return load("res://assets/items/misc/ring/ring1.lowend.png")
	elif "剑" in n or "刃" in n or "刀" in n or "sword" in n or "镰刀" in n:
		return load("res://assets/items/weapon/sword/short_sword.lowend.png")
	elif "甲" in n or "铠" in n or "armor" in n or "鹰甲" in n:
		return load("res://assets/items/armor/armor/leather_armor.lowend.png")
	elif "盔" in n or "冠" in n or "帽" in n or "helm" in n:
		return load("res://assets/items/armor/helmet/helm.lowend.png")
	elif "靴" in n or "鞋" in n or "boot" in n:
		return load("res://assets/items/armor/boot/leather_boots.lowend.png")
	elif "盾" in n or "shield" in n:
		return load("res://assets/items/armor/shield/large_shield.lowend.png")
	elif "符文" in n or "rune" in n:
		return load("res://assets/items/misc/rune/el_rune.lowend.png")
	elif "弓" in n or "bow" in n:
		return load("res://assets/items/weapon/bow/short_bow.lowend.png")
	elif "杖" in n or "staff" in n or "wand" in n:
		return load("res://assets/items/weapon/staff/short_staff.lowend.png")
	elif "斧" in n or "axe" in n:
		return load("res://assets/items/weapon/axe/hand_axe.lowend.png")

	return load("res://assets/items/misc/herb/herb.lowend.png")

func _get_quality_color_hex(q: String) -> String:
	match q:
		"unique": return "#a59263"
		"set": return "#00aa00"
		"rare": return "#ffff64"
		"magic": return "#4850b8"
		"crafted", "runeword": return "#ff8000"
		_: return "#ffffff"

func _format_number(n: int) -> String:
	var s = str(n)
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

# ========== 悬浮 Tooltip (联动 HUD 通用 item_tooltip) ==========
func _on_slot_hovered(slot_idx: int, btn: Button) -> void:
	if items_map.has(slot_idx):
		item_hovered.emit(items_map[slot_idx], btn.global_position)

func _on_slot_unhovered() -> void:
	item_unhovered.emit()

# ========== 格子右键 / 左键取出 ==========
func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT) and items_map.has(slot_idx):
			var it: Dictionary = items_map[slot_idx]
			var total_amt: int = AnsiHelper.to_safe_int(it.get("amount", 1), 1)
			var uuid: String = str(it.get("uuid", ""))
			if uuid.is_empty(): uuid = str(slot_idx)

			# 叠加物品数量 > 1 时，弹出暗黑2风格数量选择弹窗 (Shift 点击保留直接取出)
			if total_amt > 1 and not event.shift_pressed:
				_show_amount_modal(it, total_amt)
				return

			# 单件物品或按住 Shift 直接全额取出
			action_requested.emit("stash take %d %s" % [current_tab, uuid])

# ========== 拖拽接口: 接收随身背包拖入物品 (source = "main_bag") ==========
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("source") == "main_bag":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		var fid = str(it.get("file_id", ""))
		if not fid.is_empty():
			action_requested.emit("stash store %s %d" % [fid, current_tab])

# ========== InvSlotButton panel_owner 转发接口 ==========
func get_slot_drag_data(_slot_type: String, slot_idx: int) -> Variant:
	if not items_map.has(slot_idx):
		return null
	var it: Dictionary = items_map[slot_idx]
	var preview := TextureRect.new()
	if it.has("icon_texture"):
		preview.texture = it["icon_texture"]
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate = Color(1, 1, 1, 0.8)
	if get_viewport() and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	return {
		"source": "stash",
		"slot_idx": slot_idx,
		"tab": current_tab,
		"item_data": it,
	}

func can_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> bool:
	if data is Dictionary and data.get("source") == "main_bag":
		return true
	return false

func on_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		var fid = str(it.get("file_id", ""))
		if not fid.is_empty():
			action_requested.emit("stash store %s %d" % [fid, current_tab])

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _qty_modal and _qty_modal.visible:
			_qty_modal.visible = false
			return
		_close()

func _close() -> void:
	if _qty_modal:
		_qty_modal.visible = false
	visible = false
	item_unhovered.emit()
	closed.emit()
