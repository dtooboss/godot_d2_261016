extends Button
class_name InvSlotButton

var panel_owner = null
var slot_type: String = "main_bag"
var slot_index: int = 0

var amount_label: Label = null
var check_badge: Label = null
var new_badge: Label = null
var unid_badge: Label = null
var unmet_badge: Label = null
var sockets_overlay: SocketsOverlay = null
var is_selected: bool = false
var is_new_item: bool = false
var is_unidentified: bool = false
var is_unmet: bool = false
var current_quality: String = ""

# 静态缓存各品质专属风格，零冗余开销
static var _quality_styles: Dictionary = {}
static var _quality_hover_styles: Dictionary = {}

func _ready() -> void:
	_ensure_sockets_overlay()
	_ensure_amount_label()
	_ensure_check_badge()
	_ensure_new_badge()
	_ensure_unid_badge()
	_ensure_unmet_badge()
	_apply_style()

func _ensure_sockets_overlay() -> void:
	if sockets_overlay == null:
		sockets_overlay = SocketsOverlay.new()
		add_child(sockets_overlay)

func set_slot_sockets(sock_count: int, inlays: Array = []) -> void:
	_ensure_sockets_overlay()
	sockets_overlay.set_sockets(sock_count, inlays)

func _ensure_amount_label() -> void:
	if amount_label == null:
		amount_label = Label.new()
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		amount_label.offset_left = -34.0
		amount_label.offset_top = -14.0
		amount_label.offset_right = -2.0
		amount_label.offset_bottom = -1.0
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		
		amount_label.add_theme_font_size_override("font_size", 9)
		amount_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		amount_label.add_theme_constant_override("outline_size", 2)
		amount_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		amount_label.visible = false
		add_child(amount_label)

func _ensure_check_badge() -> void:
	if check_badge == null:
		check_badge = Label.new()
		check_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check_badge.offset_left = -16.0
		check_badge.offset_top = 0.0
		check_badge.offset_right = -1.0
		check_badge.offset_bottom = 14.0
		check_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		check_badge.text = "✔"
		check_badge.add_theme_font_size_override("font_size", 10)
		# 采用高对比度冰蓝宝石色，彻底与绿色套装分离！
		check_badge.add_theme_color_override("font_color", Color(0.15, 0.92, 1.0, 1.0))
		check_badge.add_theme_constant_override("outline_size", 2)
		check_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		check_badge.visible = false
		add_child(check_badge)

func _ensure_new_badge() -> void:
	if new_badge == null:
		new_badge = Label.new()
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		new_badge.offset_left = 2.0
		new_badge.offset_top = 0.0
		new_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		new_badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		new_badge.text = "NEW"
		new_badge.add_theme_font_size_override("font_size", 9)
		new_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
		new_badge.add_theme_constant_override("outline_size", 2)
		new_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		
		# 彻底去除底色和边框，纯净文本呈现，不遮挡装备图标
		var empty_style = StyleBoxEmpty.new()
		new_badge.add_theme_stylebox_override("normal", empty_style)
		
		new_badge.visible = false
		add_child(new_badge)

func set_slot_new(val: bool) -> void:
	is_new_item = val
	_ensure_new_badge()
	new_badge.visible = is_new_item
	if is_new_item:
		new_badge.pivot_offset = Vector2(8, 4)
		new_badge.scale = Vector2(0.6, 0.6)
		var tween = create_tween()
		if tween:
			tween.tween_property(new_badge, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ensure_unid_badge() -> void:
	if unid_badge == null:
		unid_badge = Label.new()
		unid_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unid_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		unid_badge.offset_left = -16.0
		unid_badge.offset_top = 0.0
		unid_badge.offset_right = -2.0
		unid_badge.offset_bottom = 15.0
		unid_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		unid_badge.text = "?"
		unid_badge.add_theme_font_size_override("font_size", 12)
		unid_badge.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
		unid_badge.add_theme_constant_override("outline_size", 2)
		unid_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		unid_badge.visible = false
		add_child(unid_badge)

func set_slot_unidentified(val: bool) -> void:
	is_unidentified = val
	_ensure_unid_badge()
	unid_badge.visible = is_unidentified and (not is_selected)

func _ensure_unmet_badge() -> void:
	if unmet_badge == null:
		unmet_badge = Label.new()
		unmet_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unmet_badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		unmet_badge.offset_left = 3.0
		unmet_badge.offset_top = -16.0
		unmet_badge.offset_right = 16.0
		unmet_badge.offset_bottom = -1.0
		unmet_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		unmet_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		unmet_badge.text = "!"
		unmet_badge.add_theme_font_size_override("font_size", 12)
		unmet_badge.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28, 1.0))
		unmet_badge.add_theme_constant_override("outline_size", 2)
		unmet_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		
		var empty_style = StyleBoxEmpty.new()
		unmet_badge.add_theme_stylebox_override("normal", empty_style)
		
		unmet_badge.visible = false
		add_child(unmet_badge)

func set_slot_unmet(val: bool) -> void:
	is_unmet = val
	_ensure_unmet_badge()
	unmet_badge.visible = is_unmet

static func _get_quality_style(quality: String) -> StyleBoxFlat:
	var q = quality.to_lower().strip_edges()
	if _quality_styles.has(q):
		return _quality_styles[q]

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	match q:
		"unique":
			# 暗金：耀金色边框 + 深金暗夜底色
			style.border_color = Color(0.88, 0.74, 0.38, 1.0)
			style.bg_color = Color(0.14, 0.11, 0.06, 0.95)
		"set":
			# 套装：翡翠翠绿边框 + 深墨绿暗夜底色
			style.border_color = Color(0.18, 0.82, 0.25, 1.0)
			style.bg_color = Color(0.06, 0.13, 0.07, 0.95)
		"rare":
			# 亮金：明黄色边框 + 深金褐底色
			style.border_color = Color(0.95, 0.88, 0.22, 1.0)
			style.bg_color = Color(0.13, 0.12, 0.05, 0.95)
		"magic":
			# 魔法：深海蓝边框 + 深幽蓝底色
			style.border_color = Color(0.32, 0.48, 0.95, 1.0)
			style.bg_color = Color(0.06, 0.08, 0.16, 0.95)
		"crafted", "runeword":
			# 手工/符文之语：活力橙
			style.border_color = Color(1.0, 0.58, 0.12, 1.0)
			style.bg_color = Color(0.15, 0.09, 0.05, 0.95)
		"normal", "superior":
			# 白色普通/超强：低调黑铁灰边框
			style.border_color = Color(0.32, 0.32, 0.35, 0.8)
			style.bg_color = Color(0.07, 0.07, 0.08, 0.95)
		_:
			# 默认空格子：玄铁极简微弱边框
			style.border_color = Color(0.18, 0.18, 0.20, 0.6)
			style.bg_color = Color(0.06, 0.06, 0.07, 0.92)

	_quality_styles[q] = style
	return style

static func _get_quality_hover_style(quality: String) -> StyleBoxFlat:
	var q = quality.to_lower().strip_edges()
	if _quality_hover_styles.has(q):
		return _quality_hover_styles[q]

	var normal = _get_quality_style(q)
	var hover = normal.duplicate()
	match q:
		"unique": hover.border_color = Color(1.0, 0.92, 0.55, 1.0)
		"set":    hover.border_color = Color(0.4, 1.0, 0.45, 1.0)
		"rare":   hover.border_color = Color(1.0, 1.0, 0.4, 1.0)
		"magic":  hover.border_color = Color(0.55, 0.75, 1.0, 1.0)
		"crafted", "runeword": hover.border_color = Color(1.0, 0.8, 0.4, 1.0)
		"normal", "superior":  hover.border_color = Color(0.8, 0.8, 0.85, 0.9)
		_:        hover.border_color = Color(0.85, 0.75, 0.3, 0.9)

	_quality_hover_styles[q] = hover
	return hover

func set_slot_quality(quality: String) -> void:
	current_quality = quality.to_lower().strip_edges()
	_apply_style()

func _apply_style() -> void:
	if is_selected:
		# 多选选中状态：明亮冰蓝宝石色边框与半透明光晕
		var sel_style = StyleBoxFlat.new()
		sel_style.bg_color = Color(0.06, 0.18, 0.28, 0.92)
		sel_style.border_width_left = 2
		sel_style.border_width_top = 2
		sel_style.border_width_right = 2
		sel_style.border_width_bottom = 2
		sel_style.border_color = Color(0.15, 0.85, 1.0, 1.0) # 2px 亮冰蓝选框
		sel_style.corner_radius_top_left = 2
		sel_style.corner_radius_top_right = 2
		sel_style.corner_radius_bottom_right = 2
		sel_style.corner_radius_bottom_left = 2
		add_theme_stylebox_override("normal", sel_style)

		var sel_hover = sel_style.duplicate()
		sel_hover.border_color = Color(0.5, 0.95, 1.0, 1.0)
		add_theme_stylebox_override("hover", sel_hover)
	else:
		var norm_style = _get_quality_style(current_quality)
		var hov_style = _get_quality_hover_style(current_quality)
		add_theme_stylebox_override("normal", norm_style)
		add_theme_stylebox_override("hover", hov_style)

func set_selected(val: bool) -> void:
	is_selected = val
	_ensure_check_badge()
	check_badge.visible = is_selected
	if unid_badge:
		unid_badge.visible = is_unidentified and (not is_selected)
	_apply_style()

func set_slot_amount(amt: int) -> void:
	_ensure_amount_label()
	var txt = format_stack_amount(amt)
	if txt.is_empty():
		amount_label.text = ""
		amount_label.visible = false
	else:
		amount_label.text = txt
		amount_label.visible = true

static func format_stack_amount(amt: int) -> String:
	if amt <= 1:
		return ""
	elif amt < 1000:
		return str(amt)
	elif amt < 10000:
		var k_val = float(amt) / 1000.0
		if amt % 1000 == 0:
			return "%dk" % int(k_val)
		else:
			return "%.1fk" % k_val
	elif amt < 1000000:
		return "%dk" % int(float(amt) / 1000.0)
	else:
		return "%dM" % int(float(amt) / 1000000.0)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if panel_owner and panel_owner.has_method("get_slot_drag_data"):
		return panel_owner.get_slot_drag_data(slot_type, slot_index)
	return null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if panel_owner and panel_owner.has_method("can_slot_drop_data"):
		return panel_owner.can_slot_drop_data(slot_type, slot_index, data)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if panel_owner and panel_owner.has_method("on_slot_drop_data"):
		panel_owner.on_slot_drop_data(slot_type, slot_index, data)
