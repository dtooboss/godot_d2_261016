extends PanelContainer
class_name AFK_ItemTooltip

@onready var icon_frame: PanelContainer = %IconFrame
@onready var item_icon: TextureRect = %ItemIcon
@onready var content_label: RichTextLabel = %ContentLabel
@onready var btn_close: Button = %BtnClose

var current_item_cmd: String = ""
var current_slot_pos: Vector2 = Vector2.ZERO
var tooltip_sockets: SocketsOverlay = null
var sockets_bar: HBoxContainer = null

const CACHE_TTL_MS: int = 60000 # 60秒轻量客户端短时缓存 (1分钟内反复查看 0 发包秒显)
const DEBOUNCE_TIME_SEC: float = 0.25 # 250ms 黄金悬浮防抖阈值 (滑过零网络发包，停顿即平滑补充详细属性)

# 静态短时缓存：cache_key -> { "desc": String, "sock": int, "inlays": Array, "timestamp": int, "large_icon": String }
static var _tooltip_cache: Dictionary = {}

var _debounce_timer: SceneTreeTimer = null
var _pending_req_cmd: String = ""
var _pending_cache_key: String = ""
var _in_flight_cache_key: String = ""
var _current_displayed_key: String = ""

static func clear_cache() -> void:
	_tooltip_cache.clear()

static func _get_cache_key(data: Dictionary) -> String:
	var fid = str(data.get("file_id", "")).strip_edges()
	if not fid.is_empty():
		return fid
	var cmd = str(data.get("cmd", "")).strip_edges()
	if not cmd.is_empty():
		return cmd
	var name_s = str(data.get("name", ""))
	var q_s = str(data.get("quality", ""))
	return "%s_%s" % [name_s, q_s]

func _cancel_debounce() -> void:
	_debounce_timer = null
	_pending_req_cmd = ""
	_pending_cache_key = ""

func _start_debounce_request(cmd_to_send: String, key_to_cache: String) -> void:
	var tree = get_tree()
	if not tree:
		return
	var timer = tree.create_timer(DEBOUNCE_TIME_SEC)
	_debounce_timer = timer
	timer.timeout.connect(func():
		if _debounce_timer == timer and _pending_cache_key == key_to_cache and visible:
			_debounce_timer = null
			_in_flight_cache_key = key_to_cache
			_send_net_request(cmd_to_send)
	)

func _send_net_request(cmd_to_send: String) -> void:
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw(cmd_to_send)

func _render_from_cache(cache_entry: Dictionary, data: Dictionary) -> void:
	var large_icon = str(cache_entry.get("large_icon", ""))
	var icon_tex: Texture2D = null
	if not large_icon.is_empty():
		icon_tex = AnsiHelper.load_item_texture(large_icon)
	if not icon_tex:
		icon_tex = data.get("icon_texture", null)
	if not icon_tex and data.has("icon"):
		icon_tex = AnsiHelper.load_item_texture(str(data.get("icon", "")))
		
	if icon_tex:
		item_icon.texture = icon_tex
		icon_frame.show()
	else:
		icon_frame.hide()
		
	var sock_count = int(cache_entry.get("sock", 0))
	var inlays = cache_entry.get("inlays", [])
	if not (inlays is Array):
		inlays = []
	_ensure_tooltip_sockets()
	if tooltip_sockets:
		tooltip_sockets.set_sockets(sock_count, inlays)
	_update_sockets_bar(sock_count, inlays)
	
	var desc = str(cache_entry.get("desc", ""))
	_apply_dynamic_size(AnsiHelper.to_bbcode(desc), sock_count)

func _ready() -> void:
	hide()
	z_as_relative = false
	z_index = 500
	_set_ignore_mouse_filter_recursive(self)
	if btn_close:
		btn_close.pressed.connect(hide_tooltip)
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net:
			net.json_frame_received.connect(_on_network_json)

## 递归设置自身及所有子节点 mouse_filter = MOUSE_FILTER_IGNORE，防止悬停卡片截获鼠标引发闪烁
static func _set_ignore_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_mouse_filter_recursive(child)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	# 按 ESC 快捷关闭装备弹窗
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_tooltip()
		get_viewport().set_input_as_handled()

static var _bbcode_regex: RegEx = null

static func _strip_bbcode_tags(text: String) -> String:
	if _bbcode_regex == null:
		_bbcode_regex = RegEx.new()
		_bbcode_regex.compile("\\[\\/?(?:b|i|u|s|color|center|right|fill|url|img|font|font_size)(?:=[^\\]]+)?\\]")
	return _bbcode_regex.sub(text, "", true)

## 智能将过长的一行属性在变量区间 [、说明括号 ( 或词间断点处拆成两行
static func _format_and_split_long_lines(text_body: String, max_w: float, font: Font, font_size: int) -> String:
	var lines = text_body.split("\n")
	var new_lines: Array = []
	for raw_line in lines:
		var clean = _strip_bbcode_tags(raw_line).strip_edges()
		if clean.is_empty():
			new_lines.append(raw_line)
			continue
			
		var w = font.get_string_size(clean, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w <= max_w:
			new_lines.append(raw_line)
		else:
			# 过长，智能拆为两行居中排版
			var split_pos = -1
			var bracket_idx = raw_line.rfind(" [")
			if bracket_idx == -1:
				bracket_idx = raw_line.rfind("[")
			var paren_idx = raw_line.rfind(" (")
			if paren_idx == -1:
				paren_idx = raw_line.rfind("(")
				
			if bracket_idx > 0 and bracket_idx > raw_line.length() * 0.35:
				split_pos = bracket_idx
			elif paren_idx > 0 and paren_idx > raw_line.length() * 0.35:
				split_pos = paren_idx
			else:
				var space_idx = raw_line.find(" ", int(raw_line.length() * 0.4))
				if space_idx > 0 and space_idx < int(raw_line.length() * 0.75):
					split_pos = space_idx
					
			if split_pos > 0:
				var part1 = raw_line.substr(0, split_pos).strip_edges()
				var part2 = raw_line.substr(split_pos).strip_edges()
				new_lines.append(part1)
				new_lines.append(part2)
			else:
				new_lines.append(raw_line)
				
	return "\n".join(PackedStringArray(new_lines))

func _apply_dynamic_size(text_body: String, sock_count: int) -> void:
	if not content_label:
		return
		
	var font = content_label.get_theme_font("normal_font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = content_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 12
		
	# 设定单行属性的最佳舒适视觉宽度上限 (约 180px)
	var max_single_line_w = 180.0
	
	# 1. 过长的单行属性自动智能拆成两行
	var formatted_text = _format_and_split_long_lines(text_body, max_single_line_w, font, font_size)
		
	# 2. 剥离 BBCode 样式标签并逐行度量拆行后纯文本的最大像素宽度
	var cleaned = _strip_bbcode_tags(formatted_text)
	var max_line_w: float = 0.0
	for line in cleaned.split("\n"):
		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue
		var w = font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > max_line_w:
			max_line_w = w
			
	# 3. 计算底部凹槽横排所需宽度 (每个孔 19px, separation 3px，6 孔约 129px)
	var sock_w: float = 0.0
	if sock_count > 0:
		sock_w = sock_count * 19.0 + (sock_count - 1) * 3.0
		
	# 4. 动态计算适度内容宽度与面板宽度 (内容宽 140px ~ 195px，卡片总宽约 156px ~ 211px)
	var fit_content_w = clamp(max(max_line_w + 8.0, sock_w), 140.0, 195.0)
	var final_panel_w = fit_content_w + 16.0 # MarginContainer 左右边距各 8px
	
	content_label.text = formatted_text
	content_label.custom_minimum_size = Vector2(fit_content_w, 0)
	custom_minimum_size = Vector2(final_panel_w, 0)
	size = Vector2(final_panel_w, 0)
	reset_size()
	
	# 5. 取卡片真实合并物理尺寸
	var real_w = max(size.x, get_combined_minimum_size().x)
	var real_h = max(size.y, get_combined_minimum_size().y)
	
	# 6. 零重叠双向避让 (Zero-Overlap Smart Flipping)
	if current_slot_pos != Vector2.ZERO:
		_reposition_tooltip(real_w, real_h)

## 智能零重叠避让定位 (Zero-Overlap Smart Flipping)
func _reposition_tooltip(panel_w: float, panel_h: float) -> void:
	var vp_size = get_viewport_rect().size
	var slot_size = Vector2(38.0, 38.0) # 格子尺寸预估
	var gap_x = 12.0 # 距离格子的水平安全间距
	
	var target_x: float = 0.0
	# 优先放置在格子左侧
	var left_x = current_slot_pos.x - panel_w - gap_x
	if left_x >= 10.0:
		# 左侧空间充足
		target_x = left_x
	else:
		# 左侧空间不足（格子靠左），智能反转放置在格子右侧，绝不盖住格子！
		var right_x = current_slot_pos.x + slot_size.x + gap_x
		if right_x + panel_w <= vp_size.x - 10.0:
			target_x = right_x
		else:
			# 若右侧也贴近屏幕边缘，贴紧右边缘但绝对不侵入格子右边界
			target_x = max(current_slot_pos.x + slot_size.x + 2.0, vp_size.x - panel_w - 10.0)
			
	# Y 轴：尽量平视居中，做屏幕边界保护
	var target_y = current_slot_pos.y + (slot_size.y - panel_h) * 0.5
	var max_y = max(10.0, vp_size.y - panel_h - 10.0)
	target_y = clamp(target_y, 10.0, max_y)
	
	global_position = Vector2(target_x, target_y)

func _ensure_tooltip_sockets() -> void:
	if tooltip_sockets == null and item_icon:
		tooltip_sockets = SocketsOverlay.new()
		item_icon.add_child(tooltip_sockets)

func _ensure_sockets_bar() -> void:
	if sockets_bar == null:
		var vbox = get_node_or_null("Margin/VBox")
		if vbox:
			sockets_bar = HBoxContainer.new()
			sockets_bar.alignment = BoxContainer.ALIGNMENT_CENTER
			sockets_bar.add_theme_constant_override("separation", 3)
			sockets_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sockets_bar)

func _update_sockets_bar(sock_count: int, inlays: Array) -> void:
	_ensure_sockets_bar()
	if not sockets_bar:
		return
		
	for child in sockets_bar.get_children():
		child.queue_free()
		
	if sock_count <= 0:
		sockets_bar.hide()
		return
		
	sockets_bar.show()
	var socket_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/images/gemsocket.lowend.png"):
		socket_tex = load("res://assets/images/gemsocket.lowend.png")
		
	for i in range(sock_count):
		var slot_box = Control.new()
		slot_box.custom_minimum_size = Vector2(19, 19)
		slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var inlay_path = ""
		if i < inlays.size():
			inlay_path = str(inlays[i]).strip_edges()
		var has_inlay = not inlay_path.is_empty()
		
		# 1. 凹槽底图
		if socket_tex:
			var sock_rect = TextureRect.new()
			sock_rect.texture = socket_tex
			sock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sock_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			sock_rect.modulate = Color(1, 1, 1, 0.85 if has_inlay else 0.4)
			sock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_box.add_child(sock_rect)
			
		# 2. 镶嵌物贴图 (宝石 / 符文)
		if has_inlay:
			var in_tex = AnsiHelper.load_item_texture(inlay_path)
			if in_tex:
				var in_rect = TextureRect.new()
				in_rect.texture = in_tex
				in_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				in_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				var in_size = 16.0
				in_rect.custom_minimum_size = Vector2(in_size, in_size)
				in_rect.size = Vector2(in_size, in_size)
				in_rect.position = Vector2((20.0 - in_size) * 0.5, (20.0 - in_size) * 0.5)
				in_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_box.add_child(in_rect)
				
		sockets_bar.add_child(slot_box)
	_set_ignore_mouse_filter_recursive(sockets_bar)

func show_item(data: Dictionary, global_slot_pos: Vector2) -> void:
	if not content_label:
		return
	
	_cancel_debounce()
	
	# 确保 Tooltip 永远处于同级节点的最顶层
	z_as_relative = false
	z_index = 500
	move_to_front()
	current_slot_pos = global_slot_pos
		
	current_item_cmd = str(data.get("cmd", ""))
	var file_id = str(data.get("file_id", ""))
	if current_item_cmd.is_empty() and not file_id.is_empty():
		current_item_cmd = "look " + file_id
		
	var cache_key = _get_cache_key(data)
	_current_displayed_key = cache_key
	
	# 1. 优先检查本地短时缓存 (5秒有效，命中则 0 网络包秒开)
	var now = Time.get_ticks_msec()
	if _tooltip_cache.has(cache_key):
		var cache_entry = _tooltip_cache[cache_key]
		if (now - int(cache_entry.get("timestamp", 0))) < CACHE_TTL_MS:
			_render_from_cache(cache_entry, data)
			show()
			return
	
	# 2. 缓存未命中：先以本地已有属性秒显骨架 (手感丝滑零白屏)
	var icon_tex: Texture2D = data.get("icon_texture", null)
	var icon_path: String = str(data.get("icon", ""))
	if not icon_tex and not icon_path.is_empty():
		icon_tex = AnsiHelper.load_item_texture(icon_path)
		
	if icon_tex:
		item_icon.texture = icon_tex
		icon_frame.show()
	else:
		icon_frame.hide()
		
	var raw_name = data.get("name", "未命名装备")
	var desc = str(data.get("desc", ""))
	if desc.is_empty() and data.has("item_info") and data["item_info"] is Dictionary:
		desc = str(data["item_info"].get("desc", ""))
	var color_hex = data.get("color", "#a59263")
	
	# 如果 desc 中带有内嵌大图标签，尝试提取
	var img_info = AnsiHelper.extract_img_info(desc)
	if not img_info.path.is_empty():
		var large_tex = AnsiHelper.load_item_texture(img_info.path)
		if large_tex:
			item_icon.texture = large_tex
			icon_frame.show()
			
	# 解析装备凹槽与镶嵌物 (支持原生字典字段与 ?sock= URL 双轨解析)
	var sock_count = AnsiHelper.to_safe_int(data.get("sockets"), 0)
	var inlays = data.get("inlays", [])
	if not (inlays is Array):
		inlays = []
	if sock_count <= 0 and "?" in icon_path:
		var img_info_icon = AnsiHelper.extract_img_info("[img:" + icon_path + "]")
		sock_count = AnsiHelper.to_safe_int(img_info_icon.get("sock"), 0)
		var in_arr = img_info_icon.get("inlays", [])
		if in_arr is Array or in_arr is PackedStringArray:
			inlays = Array(in_arr)
	if sock_count <= 0 and "?" in desc:
		var img_info_desc = AnsiHelper.extract_img_info(desc)
		sock_count = AnsiHelper.to_safe_int(img_info_desc.get("sock"), 0)
		var in_arr_desc = img_info_desc.get("inlays", [])
		if in_arr_desc is Array or in_arr_desc is PackedStringArray:
			inlays = Array(in_arr_desc)
			
	_ensure_tooltip_sockets()
	if tooltip_sockets:
		tooltip_sockets.set_sockets(sock_count, inlays)
	_update_sockets_bar(sock_count, inlays)
	
	var text_body = ""
	if desc.begins_with("<center>") or desc.begins_with("[center]"):
		text_body = AnsiHelper.to_bbcode(desc)
	else:
		var clean_name = AnsiHelper.to_plain_text(raw_name)
		var clean_desc = AnsiHelper.to_bbcode(desc)
		var item_type = data.get("type", "")
		var amount = AnsiHelper.to_safe_int(data.get("amount"), 1)
		
		text_body = "[center]"
		if not clean_desc.contains(clean_name):
			text_body += "[color=%s][b]%s[/b][/color]\n" % [color_hex, clean_name]
			if not item_type.is_empty():
				text_body += "[color=#ffffff]%s[/color]\n" % item_type
			if amount > 1:
				text_body += "[color=#ffdd66]数量: %s[/color]\n" % _format_number(amount)
			if not clean_desc.is_empty():
				text_body += "\n" + clean_desc
		else:
			text_body += clean_desc
		text_body += "[/center]"
		
	if sock_count > 0 and not text_body.contains("凹槽"):
		if text_body.ends_with("[/center]"):
			text_body = text_body.substr(0, text_body.length() - 9) + "\n[color=#808080]凹槽 (%d)[/color][/center]" % sock_count
		else:
			text_body += "\n[color=#808080]凹槽 (%d)[/color]" % sock_count
		
	_apply_dynamic_size(text_body, sock_count)
	show()
	
	# 3. 启动 80ms 防抖计时器向服务端请求更详尽的卡片 (快速扫过路过格子不发包)
	if not current_item_cmd.is_empty():
		_pending_req_cmd = current_item_cmd
		_pending_cache_key = cache_key
		_start_debounce_request(current_item_cmd, cache_key)

func _on_network_json(type: String, data: Variant) -> void:
	# 收到 look 返回的 panel 卡片数据，原地刷新更详尽的暗黑2词缀并存入短时缓存
	if (type == "panel" or type == "actions") and data is Dictionary:
		var desc = str(data.get("desc", ""))
		if desc.is_empty():
			return
			
		var img_info = AnsiHelper.extract_img_info(desc)
		var net_sock = AnsiHelper.to_safe_int(img_info.get("sock"), 0)
		var net_inlays = img_info.get("inlays", [])
		var in_arr = Array(net_inlays if (net_inlays is Array or net_inlays is PackedStringArray) else [])
		var large_icon = str(img_info.path)
		
		# 存入短时缓存 (优先使用当前展示的 key；若鼠标已移开，则使用在途发包 key)
		var target_key = _current_displayed_key if not _current_displayed_key.is_empty() else _in_flight_cache_key
		if target_key.is_empty() and not _pending_cache_key.is_empty():
			target_key = _pending_cache_key
			
		if not target_key.is_empty():
			_tooltip_cache[target_key] = {
				"desc": desc,
				"sock": net_sock,
				"inlays": in_arr,
				"large_icon": large_icon,
				"timestamp": Time.get_ticks_msec()
			}
			if target_key == _in_flight_cache_key:
				_in_flight_cache_key = ""
			
		# 仅当 Tooltip 仍然可见、且当前展示的物品与回包 key 匹配时才原地刷新
		if visible and not _current_displayed_key.is_empty() and (_current_displayed_key == target_key or target_key.is_empty()):
			if not large_icon.is_empty():
				var large_tex = AnsiHelper.load_item_texture(large_icon)
				if large_tex:
					item_icon.texture = large_tex
					icon_frame.show()
					
			if net_sock > 0:
				_ensure_tooltip_sockets()
				if tooltip_sockets:
					tooltip_sockets.set_sockets(net_sock, in_arr)
			_update_sockets_bar(net_sock, in_arr)
					
			_apply_dynamic_size(AnsiHelper.to_bbcode(desc), net_sock)

func hide_tooltip() -> void:
	_cancel_debounce()
	hide()
	current_item_cmd = ""
	_current_displayed_key = ""
	# 注意：保留 _in_flight_cache_key，网络在途迟到回包到达时仍能准确写入 60s 缓存
	current_slot_pos = Vector2.ZERO
	if tooltip_sockets:
		tooltip_sockets.set_sockets(0, [])
	if sockets_bar:
		sockets_bar.hide()

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
