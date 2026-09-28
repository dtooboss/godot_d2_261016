extends PanelContainer
class_name AFK_SocketingWorkbenchPanel

signal action_requested(cmd_str: String)
signal item_hovered(item_data: Dictionary, global_pos: Vector2)
signal item_unhovered()
signal panel_closed()

@onready var btn_close: Button = %BtnClose
@onready var equip_slot_btn: Button = %EquipSlotBtn
@onready var equip_name_label: RichTextLabel = %EquipNameLabel
@onready var equip_sockets_label: Label = %EquipSocketsLabel
@onready var equip_hint_label: Label = %EquipHintLabel

@onready var tool_slot_btn: Button = %ToolSlotBtn
@onready var btn_punch: Button = %BtnPunch
@onready var punch_hint_label: Label = %PunchHintLabel

@onready var sockets_grid: HBoxContainer = %SocketsGrid
@onready var inlay_hint_label: Label = %InlayHintLabel

@onready var btn_uninlay: Button = %BtnUninlay
@onready var btn_take_out: Button = %BtnTakeOut

var current_equipment: Dictionary = {}
var current_tool: Dictionary = {}
var current_page: int = 1
var _last_workbench_data: Dictionary = {}

var equip_sockets_overlay: SocketsOverlay = null

var _confirm_dialog: ConfirmationDialog = null

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(close)
	if btn_take_out:
		btn_take_out.pressed.connect(_on_take_out_pressed)
	if btn_punch:
		btn_punch.pressed.connect(_on_punch_pressed)
	if btn_uninlay:
		btn_uninlay.pressed.connect(_on_uninlay_pressed)
		
	if equip_slot_btn:
		equip_slot_btn.mouse_entered.connect(_on_equip_slot_hovered)
		equip_slot_btn.mouse_exited.connect(_on_slot_unhovered)
	if tool_slot_btn:
		tool_slot_btn.mouse_entered.connect(_on_tool_slot_hovered)
		tool_slot_btn.mouse_exited.connect(_on_slot_unhovered)
		
	# 启用 Control 拖拽事件转发，整窗与所有子槽均畅通接收拖入
	var forward_can_drop = func(_at_pos, data): return _can_drop_data(_at_pos, data)
	var forward_drop = func(_at_pos, data): _drop_data(_at_pos, data)
	
	if equip_slot_btn:
		equip_slot_btn.set_drag_forwarding(Callable(), forward_can_drop, forward_drop)
	if tool_slot_btn:
		tool_slot_btn.set_drag_forwarding(Callable(), forward_can_drop, forward_drop)
	if sockets_grid:
		sockets_grid.set_drag_forwarding(Callable(), forward_can_drop, forward_drop)
		
	_init_confirm_dialog()
	_render_empty_state()

func _init_confirm_dialog() -> void:
	if _confirm_dialog == null:
		_confirm_dialog = ConfirmationDialog.new()
		_confirm_dialog.title = "工坊确认"
		_confirm_dialog.ok_button_text = "确认"
		_confirm_dialog.cancel_button_text = "取消"
		add_child(_confirm_dialog)

# 装备框图标上的孔位/镶嵌物覆盖层 (与背包格、纸娃娃槽同款 SocketsOverlay)
func _ensure_equip_sockets_overlay() -> void:
	if equip_sockets_overlay == null and equip_slot_btn:
		equip_sockets_overlay = SocketsOverlay.new()
		equip_slot_btn.add_child(equip_sockets_overlay)

func open() -> void:
	visible = true
	# 打开时拉取服务端实时状态
	action_requested.emit("gsocket query %d" % current_page)

func close() -> void:
	visible = false
	panel_closed.emit()

func set_current_page(page_num: int) -> void:
	if page_num > 0:
		current_page = page_num

# ========== 纯数据驱动渲染逻辑 (LPC 驱动 Thin Client) ==========
func render_workbench_data(data: Dictionary) -> void:
	_last_workbench_data = data
	var p = AnsiHelper.to_safe_int(data.get("page"), current_page)
	if p > 0:
		current_page = p
		
	current_equipment = data.get("equipment", {})
	current_tool = data.get("tool", {})
	
	if current_equipment.is_empty():
		_render_empty_state()
		return
		
	_render_equipment_state(data)

func _render_empty_state() -> void:
	equip_slot_btn.icon = null
	_ensure_equip_sockets_overlay()
	if equip_sockets_overlay:
		equip_sockets_overlay.set_sockets(0, [])
	equip_name_label.text = "[color=#888888]请放入待操作的装备[/color]"
	equip_sockets_label.text = "凹槽状态: 未放置"
	equip_hint_label.text = "从背包拖拽装备至此处，或右键点击装备"
	
	tool_slot_btn.icon = null
	btn_punch.disabled = true
	punch_hint_label.text = "请先放入装备"
	
	_clear_sockets_grid()
	inlay_hint_label.text = "请先放入带孔装备以进行镶嵌"
	
	btn_uninlay.disabled = true
	btn_uninlay.text = "🔴 挖除所有镶嵌物 (未镶嵌)"
	btn_take_out.disabled = true

func _render_equipment_state(data: Dictionary) -> void:
	btn_take_out.disabled = false
	
	# 1. 渲染装备基本信息 (完美解析并呈现 MUD ANSI 色彩码)
	var raw_eq_name = str(current_equipment.get("name", "未知装备"))
	var eq_bbcode = AnsiHelper.to_bbcode(raw_eq_name)
	if not ("[color=" in eq_bbcode):
		var q_col = current_equipment.get("color", "#ffffff")
		equip_name_label.text = "[color=%s][b]%s[/b][/color]" % [q_col, eq_bbcode]
	else:
		equip_name_label.text = "[b]%s[/b]" % eq_bbcode
	
	var icon_p = str(current_equipment.get("icon", ""))
	if not icon_p.is_empty():
		var t = AnsiHelper.load_item_texture(icon_p)
		if t: equip_slot_btn.icon = t
	else:
		equip_slot_btn.icon = null
		
	var sockets = AnsiHelper.to_safe_int(current_equipment.get("sockets"), 0)
	var max_sockets = AnsiHelper.to_safe_int(current_equipment.get("max_sockets"), sockets)
	var inlays_arr = current_equipment.get("inlays", [])
	var inlay_cnt = AnsiHelper.to_safe_int(current_equipment.get("inlay_count"), 0)
	
	_ensure_equip_sockets_overlay()
	if equip_sockets_overlay:
		equip_sockets_overlay.set_sockets(sockets, inlays_arr if inlays_arr is Array else [])
	
	equip_sockets_label.text = "凹槽状态: %d 孔 (上限 %d 孔) | 已镶嵌 %d 孔" % [sockets, max_sockets, inlay_cnt]
	equip_hint_label.text = "已就绪"
	
	# 2. 渲染打孔专区 (完全依从服务端 can_punch 与 punch_hint)
	btn_punch.disabled = not bool(data.get("can_punch", false))
	punch_hint_label.text = str(data.get("punch_hint", ""))
	
	if not current_tool.is_empty():
		var tool_icon_p = str(current_tool.get("icon", ""))
		if not tool_icon_p.is_empty():
			var tt = AnsiHelper.load_item_texture(tool_icon_p)
			if tt: tool_slot_btn.icon = tt
		else:
			tool_slot_btn.icon = null
	else:
		tool_slot_btn.icon = null
		
	# 3. 渲染动态凹槽列表 (依从服务端 inlays)
	_render_sockets_grid(sockets, inlays_arr)
	
	# 4. 洗孔按钮状态 (完全依从服务端 can_uninlay)
	var can_uninlay = bool(data.get("can_uninlay", false))
	btn_uninlay.disabled = not can_uninlay
	if can_uninlay and inlay_cnt > 0:
		btn_uninlay.text = "🔴 挖除所有镶嵌物 (共%d颗/洗孔)" % inlay_cnt
	else:
		btn_uninlay.text = "🔴 挖除所有镶嵌物 (未镶嵌)"

func _clear_sockets_grid() -> void:
	for c in sockets_grid.get_children():
		c.queue_free()

func _render_sockets_grid(sock_count: int, inlays: Array) -> void:
	_clear_sockets_grid()
	if sock_count <= 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "当前装备暂无凹槽 (可先使用上方打孔)"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		sockets_grid.add_child(empty_lbl)
		inlay_hint_label.text = ""
		return
		
	inlay_hint_label.text = "💡 可在背包直接右键或拖入符文/宝石填孔"
	
	var first_empty_found = false
	for i in range(sock_count):
		var inlay_raw = ""
		if i < inlays.size():
			inlay_raw = str(inlays[i]).strip_edges()
			
		var is_inlaid = not inlay_raw.is_empty()
		var is_next = false
		if not is_inlaid and not first_empty_found:
			is_next = true
			first_empty_found = true
			
		var slot_p = PanelContainer.new()
		slot_p.custom_minimum_size = Vector2(40, 52)
		
		var slot_style = StyleBoxFlat.new()
		slot_style.set_corner_radius_all(4)
		slot_style.set_border_width_all(1)
		
		if is_inlaid:
			slot_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
			slot_style.border_color = Color(0.7, 0.6, 0.2, 0.8)
		elif is_next:
			slot_style.bg_color = Color(0.06, 0.12, 0.08, 0.95)
			slot_style.border_color = Color(0.3, 0.9, 0.4, 1.0)
		else:
			slot_style.bg_color = Color(0.04, 0.04, 0.05, 0.95)
			slot_style.border_color = Color(0.25, 0.25, 0.25, 0.6)
			
		slot_p.add_theme_stylebox_override("panel", slot_style)
		
		var v_box = VBoxContainer.new()
		v_box.alignment = BoxContainer.ALIGNMENT_CENTER
		v_box.add_theme_constant_override("separation", 1)
		
		var num_lbl = Label.new()
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		num_lbl.text = "%d孔" % (i + 1)
		v_box.add_child(num_lbl)
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if is_inlaid:
			var in_tex = AnsiHelper.load_item_texture(inlay_raw)
			if in_tex:
				icon_rect.texture = in_tex
		else:
			var socket_empty_p = "res://assets/images/gemsocket.lowend.png"
			if ResourceLoader.exists(socket_empty_p):
				icon_rect.texture = load(socket_empty_p)
				icon_rect.modulate = Color(1, 1, 1, 0.45)
				
		v_box.add_child(icon_rect)
		slot_p.add_child(v_box)
		sockets_grid.add_child(slot_p)

# ========== 拖拽接收逻辑 (KISS 原则：不猜类型，全部交由 LPC 处理) ==========
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var it = data.get("item_data", {})
	if it.is_empty():
		return false
	return not str(it.get("file_id", "")).is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var it = data.get("item_data", {})
	var fid = str(it.get("file_id", ""))
	if fid.is_empty():
		return
		
	# 直接派发给 LPC 专属工坊指令判定放置或镶嵌
	action_requested.emit("gsocket put %s %d" % [fid, current_page])

# ========== 按钮交互事件 ==========
func _on_take_out_pressed() -> void:
	action_requested.emit("gsocket clear %d" % current_page)

func _on_punch_pressed() -> void:
	if current_equipment.is_empty():
		return
	var eq_name = current_equipment.get("name", "装备")
	var sockets = AnsiHelper.to_safe_int(current_equipment.get("sockets"), 0)
	var prompt = "确定消耗 1 个【打孔器】为【%s】打孔吗？
(当前孔数: %d孔 -> %d孔)" % [eq_name, sockets, sockets + 1]
	
	_show_confirm("确认打孔", prompt, func():
		action_requested.emit("gsocket punch %d" % current_page)
	)

func _on_uninlay_pressed() -> void:
	if current_equipment.is_empty():
		return
	var eq_name = current_equipment.get("name", "装备")
	var in_cnt = AnsiHelper.to_safe_int(current_equipment.get("inlay_count"), 0)
	var prompt = "⚠️ 高危操作：洗孔操作不可逆！\n确定要挖除【%s】上的所有镶嵌物 (共%d颗) 吗？\n\n【注意】：槽内所有宝石/符文将全部碎裂化为齑粉，底材装备完好如新。" % [eq_name, in_cnt]
	
	_show_confirm("警告：确认洗孔", prompt, func():
		action_requested.emit("gsocket unsocket %d" % current_page)
	)

func _show_confirm(title_str: String, msg: String, on_ok: Callable) -> void:
	_init_confirm_dialog()
	_confirm_dialog.title = title_str
	_confirm_dialog.dialog_text = msg
	
	for conn in _confirm_dialog.confirmed.get_connections():
		_confirm_dialog.confirmed.disconnect(conn["callable"])
		
	_confirm_dialog.confirmed.connect(on_ok)
	_confirm_dialog.popup_centered()

func _on_equip_slot_hovered() -> void:
	if not current_equipment.is_empty():
		item_hovered.emit(current_equipment, equip_slot_btn.global_position)

func _on_tool_slot_hovered() -> void:
	if not current_tool.is_empty():
		item_hovered.emit(current_tool, tool_slot_btn.global_position)

func _on_slot_unhovered() -> void:
	item_unhovered.emit()
