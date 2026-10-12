extends PanelContainer
class_name TradePanel

## 暗黑破坏神2 原版双向以物换物交易面板 (TradePanel)
## 支持双栏物品放置镜像、悬浮查看装备属性卡片、防欺诈双重锁定确认

signal item_hovered(item_data: Dictionary, pos: Vector2)
signal item_unhovered()
signal trade_cancelled()

var lbl_title: Label
var lbl_my_name: Label
var lbl_partner_name: Label
var my_slots_grid: GridContainer
var partner_slots_grid: GridContainer
var my_slot_buttons: Array[Button] = []
var partner_slot_buttons: Array[Button] = []
var lbl_my_status: RichTextLabel
var lbl_partner_status: RichTextLabel
var btn_confirm: Button
var btn_cancel: Button
var btn_close: Button

var current_partner_id: String = ""
var current_partner_name: String = ""
var my_trade_items: Array = []
var partner_trade_items: Array = []
var is_my_confirmed: bool = false
var is_partner_confirmed: bool = false

# 数量选择弹窗组件 (用于符文、药水等叠加物品拆分)
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
var _pending_offer_item: Dictionary = {}
var _current_offer_amount: int = 1
var _max_offer_amount: int = 1

const SLOT_SIZE = Vector2(44, 44)
const QUALITY_COLORS = {
	"unique": Color(0.78, 0.65, 0.4),      # 暗金
	"set": Color(0.2, 0.85, 0.2),         # 绿色套装
	"rare": Color(1.0, 0.9, 0.2),         # 亮金
	"crafted": Color(1.0, 0.5, 0.0),      # 橙色手工
	"magic": Color(0.3, 0.5, 1.0),        # 蓝色魔法
	"normal": Color(0.85, 0.85, 0.85)     # 白色普通
}

func _ready() -> void:
	custom_minimum_size = Vector2(560, 430)
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 窗口古典黑金暗黑风格背景
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	sb.border_color = Color(0.85, 0.68, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", sb)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# 1. 顶部标题栏与关闭按钮
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	lbl_title = Label.new()
	lbl_title.text = "❖ 双向以物换物交易 ❖"
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_hbox.add_child(lbl_title)

	btn_close = Button.new()
	btn_close.text = " ✕ "
	btn_close.custom_minimum_size = Vector2(28, 26)
	btn_close.pressed.connect(_on_cancel_pressed)
	header_hbox.add_child(btn_close)

	# 2. 交易双方玩家名展示 (左侧对方，右侧我方紧靠背包)
	var names_hbox = HBoxContainer.new()
	names_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(names_hbox)

	lbl_partner_name = Label.new()
	lbl_partner_name.text = "对方交付区"
	lbl_partner_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_partner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_partner_name.add_theme_font_size_override("font_size", 13)
	lbl_partner_name.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	names_hbox.add_child(lbl_partner_name)

	var vs_lbl = Label.new()
	vs_lbl.text = " ⇄ "
	vs_lbl.add_theme_font_size_override("font_size", 14)
	vs_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	names_hbox.add_child(vs_lbl)

	lbl_my_name = Label.new()
	lbl_my_name.text = "我方交付区"
	lbl_my_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_my_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_my_name.add_theme_font_size_override("font_size", 13)
	lbl_my_name.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	names_hbox.add_child(lbl_my_name)

	# 3. 中间双栏交易网格区
	var panels_hbox = HBoxContainer.new()
	panels_hbox.add_theme_constant_override("separation", 16)
	panels_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(panels_hbox)

	# 左栏：对方物品槽 (4x4 = 16格)
	var left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels_hbox.add_child(left_box)

	var left_hint = Label.new()
	left_hint.text = "对方提供的装备 (悬停查看属性)"
	left_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_hint.add_theme_font_size_override("font_size", 11)
	left_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	left_box.add_child(left_hint)

	var left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", _make_grid_bg())
	left_box.add_child(left_panel)

	partner_slots_grid = GridContainer.new()
	partner_slots_grid.columns = 4
	partner_slots_grid.add_theme_constant_override("h_separation", 4)
	partner_slots_grid.add_theme_constant_override("v_separation", 4)
	left_panel.add_child(partner_slots_grid)
	for i in range(16):
		var btn = _create_slot_btn(false, i)
		partner_slots_grid.add_child(btn)
		partner_slot_buttons.append(btn)

	# 右栏：我方物品槽 (4x4 = 16格，紧贴右侧背包侧)
	var right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels_hbox.add_child(right_box)

	var right_hint = Label.new()
	right_hint.text = "点击背包放入或拖入 / 点击槽中拿回"
	right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_hint.add_theme_font_size_override("font_size", 11)
	right_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	right_box.add_child(right_hint)

	var right_panel = PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", _make_grid_bg())
	right_box.add_child(right_panel)

	my_slots_grid = GridContainer.new()
	my_slots_grid.columns = 4
	my_slots_grid.add_theme_constant_override("h_separation", 4)
	my_slots_grid.add_theme_constant_override("v_separation", 4)
	right_panel.add_child(my_slots_grid)
	for i in range(16):
		var btn = _create_slot_btn(true, i)
		my_slots_grid.add_child(btn)
		my_slot_buttons.append(btn)

	# 4. 底部锁定状态与控制按钮排
	var bottom_vbox = VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(bottom_vbox)

	var status_hbox = HBoxContainer.new()
	bottom_vbox.add_child(status_hbox)

	lbl_partner_status = RichTextLabel.new()
	lbl_partner_status.bbcode_enabled = true
	lbl_partner_status.text = "[color=#aaaaaa]对方：未锁定[/color]"
	lbl_partner_status.fit_content = true
	lbl_partner_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(lbl_partner_status)

	lbl_my_status = RichTextLabel.new()
	lbl_my_status.bbcode_enabled = true
	lbl_my_status.text = "[color=#aaaaaa]我方：未锁定[/color]"
	lbl_my_status.fit_content = true
	lbl_my_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_my_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_hbox.add_child(lbl_my_status)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	bottom_vbox.add_child(btn_hbox)

	btn_confirm = Button.new()
	btn_confirm.text = "锁定并确认交易"
	btn_confirm.custom_minimum_size = Vector2(140, 32)
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_hbox.add_child(btn_confirm)

	btn_cancel = Button.new()
	btn_cancel.text = "取消交易"
	btn_cancel.custom_minimum_size = Vector2(100, 32)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_hbox.add_child(btn_cancel)

	# 5. 构建数量选择浮层微调窗口 (默认隐藏)
	_build_qty_modal()

func _make_grid_bg() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.9)
	sb.border_color = Color(0.3, 0.25, 0.15, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

## 构建暗黑2风格数量选择微调弹窗
func _build_qty_modal() -> void:
	_qty_modal = PanelContainer.new()
	_qty_modal.custom_minimum_size = Vector2(280, 200)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.border_color = Color(0.9, 0.78, 0.28, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	_qty_modal.add_theme_stylebox_override("panel", sb)
	
	_qty_modal.set_anchors_preset(Control.PRESET_CENTER)
	_qty_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_qty_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_qty_modal.visible = false
	add_child(_qty_modal)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_qty_modal.add_child(vbox)
	
	var title = Label.new()
	title.text = "❖ 放置交易数量 ❖"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	var item_row = HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 10)
	vbox.add_child(item_row)
	
	_qty_item_icon = TextureRect.new()
	_qty_item_icon.custom_minimum_size = Vector2(36, 36)
	_qty_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qty_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(_qty_item_icon)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(info_vbox)
	
	_qty_item_name = Label.new()
	_qty_item_name.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_qty_item_name)
	
	_qty_stock_label = Label.new()
	_qty_stock_label.add_theme_font_size_override("font_size", 11)
	_qty_stock_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(_qty_stock_label)
	
	var quick_row = HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 8)
	vbox.add_child(quick_row)
	
	_btn_qty_1 = Button.new()
	_btn_qty_1.text = " 1 "
	_btn_qty_1.custom_minimum_size = Vector2(50, 24)
	_btn_qty_1.pressed.connect(func(): _set_modal_qty(1))
	quick_row.add_child(_btn_qty_1)
	
	_btn_qty_half = Button.new()
	_btn_qty_half.text = " 一半 "
	_btn_qty_half.custom_minimum_size = Vector2(60, 24)
	_btn_qty_half.pressed.connect(func(): _set_modal_qty(max(1, _max_offer_amount / 2)))
	quick_row.add_child(_btn_qty_half)
	
	_btn_qty_all = Button.new()
	_btn_qty_all.text = " 全部 "
	_btn_qty_all.custom_minimum_size = Vector2(60, 24)
	_btn_qty_all.pressed.connect(func(): _set_modal_qty(_max_offer_amount))
	quick_row.add_child(_btn_qty_all)
	
	var adjust_row = HBoxContainer.new()
	adjust_row.alignment = BoxContainer.ALIGNMENT_CENTER
	adjust_row.add_theme_constant_override("separation", 6)
	vbox.add_child(adjust_row)
	
	var btn_minus = Button.new()
	btn_minus.text = " - "
	btn_minus.custom_minimum_size = Vector2(26, 24)
	btn_minus.pressed.connect(func(): _set_modal_qty(_current_offer_amount - 1))
	adjust_row.add_child(btn_minus)
	
	_qty_slider = HSlider.new()
	_qty_slider.min_value = 1
	_qty_slider.max_value = 100
	_qty_slider.step = 1
	_qty_slider.custom_minimum_size = Vector2(90, 20)
	_qty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_slider.value_changed.connect(func(v): _set_modal_qty(int(v)))
	adjust_row.add_child(_qty_slider)
	
	var btn_plus = Button.new()
	btn_plus.text = " + "
	btn_plus.custom_minimum_size = Vector2(26, 24)
	btn_plus.pressed.connect(func(): _set_modal_qty(_current_offer_amount + 1))
	adjust_row.add_child(btn_plus)
	
	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1
	_qty_spin.max_value = 100
	_qty_spin.step = 1
	_qty_spin.custom_minimum_size = Vector2(70, 24)
	_qty_spin.value_changed.connect(func(v): _set_modal_qty(int(v)))
	adjust_row.add_child(_qty_spin)
	
	var act_row = HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 16)
	vbox.add_child(act_row)
	
	_btn_qty_confirm = Button.new()
	_btn_qty_confirm.text = " 确定放入 "
	_btn_qty_confirm.custom_minimum_size = Vector2(90, 28)
	_btn_qty_confirm.pressed.connect(_on_qty_confirm_pressed)
	act_row.add_child(_btn_qty_confirm)
	
	_btn_qty_cancel = Button.new()
	_btn_qty_cancel.text = " 取消 "
	_btn_qty_cancel.custom_minimum_size = Vector2(70, 28)
	_btn_qty_cancel.pressed.connect(func(): _qty_modal.visible = false)
	act_row.add_child(_btn_qty_cancel)

func _set_modal_qty(val: int) -> void:
	_current_offer_amount = clamp(val, 1, _max_offer_amount)
	if _qty_slider and int(_qty_slider.value) != _current_offer_amount:
		_qty_slider.value = _current_offer_amount
	if _qty_spin and int(_qty_spin.value) != _current_offer_amount:
		_qty_spin.value = _current_offer_amount

func _show_amount_modal(item_data: Dictionary, total_amt: int) -> void:
	_pending_offer_item = item_data
	_max_offer_amount = max(1, total_amt)
	_current_offer_amount = _max_offer_amount
	
	var q = str(item_data.get("quality", "normal")).to_lower()
	var col = QUALITY_COLORS.get(q, Color(0.85, 0.85, 0.85))
	_qty_item_name.text = AnsiHelper.to_plain_text(str(item_data.get("name", "物品")))
	_qty_item_name.add_theme_color_override("font_color", col)
	
	var icon_path = str(item_data.get("icon", ""))
	if not icon_path.is_empty():
		_qty_item_icon.texture = AnsiHelper.load_item_texture(icon_path)
	else:
		_qty_item_icon.texture = null
		
	_qty_stock_label.text = "拥有总量: %d" % _max_offer_amount
	if _qty_slider:
		_qty_slider.max_value = _max_offer_amount
	if _qty_spin:
		_qty_spin.max_value = _max_offer_amount
		
	_set_modal_qty(_max_offer_amount)
	_qty_modal.visible = true

func _on_qty_confirm_pressed() -> void:
	if _pending_offer_item.is_empty():
		_qty_modal.visible = false
		return
	var fid = str(_pending_offer_item.get("file_id", _pending_offer_item.get("id", "")))
	if not fid.is_empty():
		NetworkClient.send_raw("gtrade add %s %d" % [fid, _current_offer_amount])
	_qty_modal.visible = false

## 打开交易会话
func open_trade(partner_id: String, partner_name: String) -> void:
	if _qty_modal:
		_qty_modal.visible = false
	current_partner_id = partner_id
	current_partner_name = partner_name
	
	var my_name = "我方"
	if GameState.selected_character and not GameState.selected_character.is_empty():
		my_name = str(GameState.selected_character.get("name", "我方"))
		
	lbl_partner_name.text = partner_name + " (对方交付区)"
	lbl_my_name.text = my_name + " (我方交付区)"
	
	my_trade_items.clear()
	partner_trade_items.clear()
	is_my_confirmed = false
	is_partner_confirmed = false
	
	_refresh_display()
	visible = true

## 同步交易数据帧 (trade_sync)
func update_trade_sync(data: Dictionary) -> void:
	current_partner_id = str(data.get("partner_id", current_partner_id))
	current_partner_name = str(data.get("partner_name", current_partner_name))
	
	my_trade_items = data.get("my_items", [])
	partner_trade_items = data.get("partner_items", [])
	is_my_confirmed = bool(data.get("my_confirmed", false))
	is_partner_confirmed = bool(data.get("partner_confirmed", false))
	
	_refresh_display()

## 专属交易槽位按钮（支持原生拖放接收）
class TradeSlotButton extends Button:
	var trade_panel_ref: TradePanel = null
	var is_mine_slot: bool = false
	
	func _can_drop_data(at_pos: Vector2, data: Variant) -> bool:
		if is_mine_slot and trade_panel_ref:
			return trade_panel_ref._can_drop_data(at_pos, data)
		return false
		
	func _drop_data(at_pos: Vector2, data: Variant) -> void:
		if is_mine_slot and trade_panel_ref:
			trade_panel_ref._drop_data(at_pos, data)

func _create_slot_btn(is_mine: bool, slot_index: int) -> Button:
	var slot_btn = TradeSlotButton.new()
	slot_btn.trade_panel_ref = self
	slot_btn.is_mine_slot = is_mine
	slot_btn.custom_minimum_size = SLOT_SIZE
	slot_btn.focus_mode = Control.FOCUS_NONE
	slot_btn.set_meta("is_mine", is_mine)
	slot_btn.set_meta("slot_index", slot_index)
	
	var slot_sb = StyleBoxFlat.new()
	slot_sb.bg_color = Color(0.08, 0.08, 0.1, 0.7)
	slot_sb.border_color = Color(0.2, 0.2, 0.25, 0.6)
	slot_sb.set_border_width_all(1)
	slot_btn.add_theme_stylebox_override("normal", slot_sb)
	
	var icon_rect = TextureRect.new()
	icon_rect.name = "ItemIcon"
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	slot_btn.add_child(icon_rect)
	
	# 右下角叠加数量显示徽章 (类似背包 InvSlotButton)
	var amt_lbl = Label.new()
	amt_lbl.name = "AmountLabel"
	amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	amt_lbl.offset_left = -34.0
	amt_lbl.offset_top = -14.0
	amt_lbl.offset_right = -2.0
	amt_lbl.offset_bottom = -1.0
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amt_lbl.add_theme_font_size_override("font_size", 10)
	amt_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	amt_lbl.add_theme_constant_override("outline_size", 2)
	amt_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	amt_lbl.visible = false
	slot_btn.add_child(amt_lbl)
	
	# 信号在初始化时固定连接一次，纯数据驱动，无需反复断连
	slot_btn.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_btn))
	slot_btn.mouse_exited.connect(_on_slot_mouse_exited)
	if is_mine:
		slot_btn.pressed.connect(_on_slot_pressed.bind(slot_btn))
	
	return slot_btn

func _on_slot_mouse_entered(btn: Button) -> void:
	var is_mine = bool(btn.get_meta("is_mine", false))
	var idx = int(btn.get_meta("slot_index", 0))
	var items = my_trade_items if is_mine else partner_trade_items
	if idx < items.size() and items[idx] is Dictionary:
		var item_data = items[idx]
		var m_pos = btn.get_global_position() + Vector2(SLOT_SIZE.x + 8, 0)
		item_hovered.emit(item_data, m_pos)

func _on_slot_mouse_exited() -> void:
	item_unhovered.emit()

func _on_slot_pressed(btn: Button) -> void:
	var is_mine = bool(btn.get_meta("is_mine", false))
	if not is_mine: return
	var idx = int(btn.get_meta("slot_index", 0))
	if idx < my_trade_items.size() and my_trade_items[idx] is Dictionary:
		var item_data = my_trade_items[idx]
		item_unhovered.emit()
		var fid = str(item_data.get("file_id", item_data.get("id", "")))
		if not fid.is_empty():
			NetworkClient.send_raw("gtrade remove " + fid)

## 刷新整盘显示
func _refresh_display() -> void:
	_populate_grid(partner_slot_buttons, partner_trade_items)
	_populate_grid(my_slot_buttons, my_trade_items)
	
	# 状态文字与按钮更新
	if is_partner_confirmed:
		lbl_partner_status.text = "[color=#44ff66]✔ 对方：已锁定确认[/color]"
	else:
		lbl_partner_status.text = "[color=#cccccc]对方：未锁定[/color]"
		
	if is_my_confirmed:
		lbl_my_status.text = "[color=#44ff66]✔ 我方：已锁定确认[/color]"
		btn_confirm.text = "已锁定 (等待对方)"
		btn_confirm.disabled = true
	else:
		lbl_my_status.text = "[color=#cccccc]我方：未锁定[/color]"
		btn_confirm.text = "锁定并确认交易"
		btn_confirm.disabled = false

## 填充 16 格物品网格 (增量复用 Button，更新图标、边框品质与叠加数量)
func _populate_grid(buttons: Array[Button], items: Array) -> void:
	for i in range(16):
		if i >= buttons.size():
			break
		var slot_btn = buttons[i]
		var icon_rect = slot_btn.get_node_or_null("ItemIcon") as TextureRect
		var amt_lbl = slot_btn.get_node_or_null("AmountLabel") as Label
		
		var slot_sb = StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		slot_sb.border_color = Color(0.2, 0.2, 0.25, 0.6)
		slot_sb.set_border_width_all(1)
		
		if i < items.size() and items[i] is Dictionary:
			var item_data = items[i]
			var quality = str(item_data.get("quality", "normal")).to_lower()
			var border_col = QUALITY_COLORS.get(quality, Color(0.85, 0.85, 0.85))
			slot_sb.border_color = border_col
			slot_sb.set_border_width_all(2)
			
			var icon_path = str(item_data.get("icon", ""))
			var tex: Texture2D = null
			if not icon_path.is_empty():
				tex = AnsiHelper.load_item_texture(icon_path)
				
			if icon_rect:
				icon_rect.texture = tex
				icon_rect.visible = (tex != null)
				
			var amt = AnsiHelper.to_safe_int(item_data.get("amount", 1), 1)
			if amt_lbl:
				if amt > 1:
					amt_lbl.text = "x%d" % amt
					amt_lbl.visible = true
				else:
					amt_lbl.visible = false
					
			slot_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
			if amt_lbl:
				amt_lbl.visible = false
			slot_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			
		slot_btn.add_theme_stylebox_override("normal", slot_sb)

## 放入物品 (供背包点击或拖拽调用，叠加物品自动弹窗选择数量)
func offer_item(item_data: Dictionary) -> void:
	if not visible: return
	if is_my_confirmed:
		return
	var fid = str(item_data.get("file_id", item_data.get("id", "")))
	if fid.is_empty():
		return
	var amt = AnsiHelper.to_safe_int(item_data.get("amount", 1), 1)
	if amt > 1:
		_show_amount_modal(item_data, amt)
	else:
		NetworkClient.send_raw("gtrade add " + fid)

## ========== 拖放数据接口 (Drag & Drop) ==========
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not visible or is_my_confirmed:
		return false
	if data is Dictionary and data.has("item_data"):
		var it = data.get("item_data", {})
		if it is Dictionary and not str(it.get("file_id", it.get("id", ""))).is_empty():
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not visible or is_my_confirmed:
		return
	if data is Dictionary and data.has("item_data"):
		var it = data.get("item_data", {})
		if it is Dictionary:
			offer_item(it)

func _on_confirm_pressed() -> void:
	NetworkClient.send_raw("gtrade confirm")

func _on_cancel_pressed() -> void:
	if _qty_modal:
		_qty_modal.visible = false
	item_unhovered.emit()
	visible = false
	NetworkClient.send_raw("gtrade cancel")
	trade_cancelled.emit()
