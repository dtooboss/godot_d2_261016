extends Button
class_name PaperdollSlotButton

signal slot_dropped(data)

var slot_key: String = ""
var current_item_data: Dictionary = {}
var default_icon: Texture2D = null
var current_quality: String = ""
var sockets_overlay: SocketsOverlay = null

# 静态品质风格缓存，零冗余开销
static var _quality_styles: Dictionary = {}
static var _quality_hover_styles: Dictionary = {}

func _ready() -> void:
	_ensure_sockets_overlay()
	if default_icon == null and icon != null:
		default_icon = icon
	apply_quality_style("")

func _ensure_sockets_overlay() -> void:
	if sockets_overlay == null:
		sockets_overlay = SocketsOverlay.new()
		add_child(sockets_overlay)

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
			# 暗金：耀金色精致细边框 + 沉金暗夜微光底色
			style.border_color = Color(0.88, 0.74, 0.38, 1.0)
			style.bg_color = Color(0.14, 0.11, 0.06, 0.95)
		"set":
			# 套装：翡翠翠绿边框 + 墨绿暗夜底色
			style.border_color = Color(0.18, 0.82, 0.25, 1.0)
			style.bg_color = Color(0.06, 0.13, 0.07, 0.95)
		"rare":
			# 亮金：明黄色边框 + 深金褐微光底色
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
			# 白色普通/超强：黑铁灰精致边框
			style.border_color = Color(0.38, 0.38, 0.42, 0.85)
			style.bg_color = Color(0.08, 0.08, 0.09, 0.95)
		_:
			# 未穿戴/空格子：内敛玄铁凹槽边框与深黑底色
			style.border_color = Color(0.3, 0.26, 0.2, 0.6)
			style.bg_color = Color(0.06, 0.06, 0.07, 0.95)

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
		"normal", "superior":  hover.border_color = Color(0.6, 0.6, 0.65, 1.0)
		_:        hover.border_color = Color(0.5, 0.45, 0.35, 0.9)

	_quality_hover_styles[q] = hover
	return hover

func apply_quality_style(quality: String) -> void:
	current_quality = quality.to_lower().strip_edges()
	var normal_style = _get_quality_style(current_quality)
	var hover_style = _get_quality_hover_style(current_quality)
	
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", hover_style)
	
	var empty_focus = StyleBoxEmpty.new()
	add_theme_stylebox_override("focus", empty_focus)

func set_slot_data(key: String, item_data: Variant) -> void:
	slot_key = key
	if default_icon == null and icon != null:
		default_icon = icon

	if item_data is Dictionary and not item_data.is_empty():
		current_item_data = item_data
		var q = str(item_data.get("quality", "normal"))
		apply_quality_style(q)
		
		var icon_path = str(item_data.get("icon", ""))
		var tex = AnsiHelper.load_item_texture(icon_path)
		if tex:
			icon = tex
		modulate = Color(1, 1, 1, 1)

		var sock_count = AnsiHelper.to_safe_int(item_data.get("sockets"), 0)
		var inlays = item_data.get("inlays", [])
		if not (inlays is Array):
			inlays = []
		if sock_count <= 0 and "?" in icon_path:
			var img_info = AnsiHelper.extract_img_info("[img:" + icon_path + "]")
			sock_count = AnsiHelper.to_safe_int(img_info.get("sock"), 0)
			var in_arr = img_info.get("inlays", [])
			if in_arr is Array or in_arr is PackedStringArray:
				inlays = Array(in_arr)
		_ensure_sockets_overlay()
		sockets_overlay.set_sockets(sock_count, inlays)
	else:
		current_item_data = {}
		apply_quality_style("")
		icon = default_icon
		modulate = Color(0.65, 0.65, 0.65, 0.75) # 未穿戴时暗色呈现槽位部位底图
		_ensure_sockets_overlay()
		sockets_overlay.set_sockets(0, [])

func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item_data.is_empty():
		return null
	var preview = TextureRect.new()
	if icon:
		preview.texture = icon
	preview.custom_minimum_size = Vector2(36, 36)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate = Color(1, 1, 1, 0.8)
	if get_viewport() and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	return {
		"source": "paperdoll",
		"slot_key": slot_key,
		"item_data": current_item_data
	}

func is_item_compatible(item_data: Dictionary) -> bool:
	if item_data.is_empty() or slot_key.is_empty():
		return false
	var iname = str(item_data.get("name", "")).to_lower()
	var d2_type = str(item_data.get("d2_type", ""))
	var icon_p = str(item_data.get("icon", "")).to_lower()
	
	# 护符/药水/宝石/符文/卷轴不可穿戴到装备槽位
	if bool(item_data.get("is_charm", false)) or AnsiHelper.to_safe_int(item_data.get("is_charm"), 0) == 1:
		return false
	if AnsiHelper.to_safe_int(item_data.get("is_rune"), 0) == 1 or AnsiHelper.to_safe_int(item_data.get("is_gem"), 0) == 1:
		return false
	if "卷轴" in iname or "药水" in iname or "药剂" in iname or "精粹" in iname:
		return false

	match slot_key:
		"helmet":
			return ("盔" in iname or "冠" in iname or "帽" in iname or "面具" in iname or "面甲" in iname
				or "helm" in icon_p or "cap" in icon_p or "mask" in icon_p or "crown" in icon_p)
		"armor":
			# 严格互斥：绝不能是手套、靴子、腰带、头盔
			if "手套" in iname or "护手" in iname or "铁手" in iname or "glove" in icon_p:
				return false
			if "靴" in iname or "鞋" in iname or "boot" in icon_p:
				return false
			if "带" in iname or "腰" in iname or "belt" in icon_p or "sash" in icon_p:
				return false
			if "盔" in iname or "冠" in iname or "帽" in iname or "helm" in icon_p:
				return false
			return ("甲" in iname or "铠" in iname or "袍" in iname or "衣" in iname or "服" in iname
				or "armor" in icon_p or "cloth" in icon_p or "robe" in icon_p)
		"pants": # 腰带
			return ("带" in iname or "腰" in iname or "belt" in icon_p or "sash" in icon_p or "cord" in icon_p)
		"gloves":
			return ("手套" in iname or "护手" in iname or "铁手" in iname or "glove" in icon_p or "hand" in icon_p)
		"boots":
			return ("靴" in iname or "鞋" in iname or "boot" in icon_p or "greave" in icon_p)
		"necklace":
			return ("项链" in iname or "amulet" in icon_p or "amulet" in iname or "护符" in iname)
		"ring1", "ring2":
			return ("戒指" in iname or "指环" in iname or "戒" in iname or "ring" in icon_p)
		"main_hand":
			return (d2_type == "武器" or "剑" in iname or "刀" in iname or "斧" in iname or "杖" in iname or "弓" in iname
				or "弩" in iname or "枪" in iname or "矛" in iname or "爪" in iname or "球" in iname or "匕" in iname or "棍" in iname
				or "weapon" in icon_p or "sword" in icon_p or "axe" in icon_p or "bow" in icon_p or "wand" in icon_p or "staff" in icon_p)
		"off_hand":
			return ("盾" in iname or "shield" in icon_p or "箭筒" in iname or "弩弹" in iname or "quiver" in icon_p
				or d2_type == "武器" or "weapon" in icon_p or "sword" in icon_p or "claw" in icon_p)
		"wings":
			return ("翼" in iname or "翅" in iname or "wing" in iname or "wing" in icon_p)
		"pet":
			return ("宠" in iname or "兽" in iname or "pet" in iname)
	return true

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_visible_in_tree():
		return false
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		return is_item_compatible(it)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	slot_dropped.emit(data)
