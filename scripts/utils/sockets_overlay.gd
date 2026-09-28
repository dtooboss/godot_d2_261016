extends Control
class_name SocketsOverlay

## 暗黑破坏神2正统凹槽(1~6孔)与镶嵌物(符文/宝石)视觉图层组件
## 算法与视觉参数完全对齐暗黑2正版矩阵与 Flutter 客户端

const SOCKET_TEX_PATH = "res://assets/images/gemsocket.lowend.png"
static var _socket_tex: Texture2D = null

var current_sock_count: int = 0
var current_inlays: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _socket_tex == null and ResourceLoader.exists(SOCKET_TEX_PATH):
		_socket_tex = load(SOCKET_TEX_PATH)

## 设置并渲染孔位与镶嵌物
func set_sockets(sock_count: int, inlays: Array = []) -> void:
	current_sock_count = sock_count
	current_inlays = inlays
	
	for child in get_children():
		child.queue_free()
		
	if sock_count <= 0:
		visible = false
		return
		
	visible = true
	_render_sockets()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if current_sock_count > 0:
			_render_sockets()

func _render_sockets() -> void:
	if _socket_tex == null and ResourceLoader.exists(SOCKET_TEX_PATH):
		_socket_tex = load(SOCKET_TEX_PATH)
		
	var p = get_parent() as Control
	var pw: float = 36.0
	var ph: float = 36.0
	if p:
		if p.size.x > 0 and p.size.y > 0:
			pw = p.size.x
			ph = p.size.y
		elif p.custom_minimum_size.x > 0 and p.custom_minimum_size.y > 0:
			pw = p.custom_minimum_size.x
			ph = p.custom_minimum_size.y
	elif size.x > 0 and size.y > 0:
		pw = size.x
		ph = size.y
		
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	custom_minimum_size = Vector2(pw, ph)
	
	var w = min(pw, ph)
	var socket_size: float = 8.5
	var gap: float = 1.0
	
	if w <= 40.0:
		if current_sock_count == 1:
			socket_size = 14.0
			gap = 2.0
		elif current_sock_count <= 3:
			socket_size = 10.5
			gap = 1.0
		else:
			socket_size = 8.5
			gap = 1.0
	elif w <= 52.0:
		if current_sock_count == 1:
			socket_size = 16.0
			gap = 2.0
		elif current_sock_count <= 3:
			socket_size = 12.0
			gap = 1.5
		else:
			socket_size = 10.0
			gap = 1.5
	else:
		if current_sock_count == 1:
			socket_size = 20.0
			gap = 3.0
		elif current_sock_count <= 3:
			socket_size = 15.0
			gap = 2.0
		else:
			socket_size = 12.5
			gap = 2.0

	var layout_w: float = socket_size
	var layout_h: float = socket_size
	match current_sock_count:
		1:
			layout_w = socket_size
			layout_h = socket_size
		2:
			layout_w = socket_size
			layout_h = socket_size * 2.0 + gap
		3:
			layout_w = socket_size
			layout_h = socket_size * 3.0 + gap * 2.0
		4:
			layout_w = socket_size * 2.0 + gap
			layout_h = socket_size * 2.0 + gap
		5, 6:
			layout_w = socket_size * 2.0 + gap
			layout_h = socket_size * 3.0 + gap * 2.0

	var layout = _build_sockets_layout(current_sock_count, current_inlays, socket_size, gap)
	if layout:
		layout.custom_minimum_size = Vector2(layout_w, layout_h)
		layout.size = Vector2(layout_w, layout_h)
		# 绝对数学像素居中计算，100% 居中无任何漂移
		var pos_x = round((pw - layout_w) * 0.5)
		var pos_y = round((ph - layout_h) * 0.5)
		layout.position = Vector2(pos_x, pos_y)
		add_child(layout)

func _get_inlay_path(index: int, inlays: Array) -> String:
	if index >= 0 and index < inlays.size():
		return str(inlays[index]).strip_edges()
	return ""

func _build_single_socket(inlay_path: String, s_size: float) -> Control:
	var box = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(s_size, s_size)
	
	var has_inlay = not inlay_path.is_empty()
	
	# 1. 凹槽底图 (gemsocket.lowend.png)
	if _socket_tex:
		var sock_rect = TextureRect.new()
		sock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sock_rect.texture = _socket_tex
		sock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sock_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		# 空孔 0.45 深度半透明透出装备细节，已镶嵌孔 0.75 衬托
		sock_rect.modulate = Color(1, 1, 1, 0.75 if has_inlay else 0.45)
		box.add_child(sock_rect)
		
	# 2. 镶嵌物图标 (符文 / 宝石 / 珠宝)
	if has_inlay:
		var in_tex = AnsiHelper.load_item_texture(inlay_path)
		if in_tex:
			var in_rect = TextureRect.new()
			in_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			in_rect.texture = in_tex
			in_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			in_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var in_size = s_size * 0.85
			in_rect.custom_minimum_size = Vector2(in_size, in_size)
			in_rect.size = Vector2(in_size, in_size)
			in_rect.position = Vector2((s_size - in_size) * 0.5, (s_size - in_size) * 0.5 - 0.5)
			box.add_child(in_rect)
			
	return box

func _build_sockets_layout(count: int, inlays: Array, s_size: float, gap: float) -> Control:
	match count:
		1:
			return _build_single_socket(_get_inlay_path(0, inlays), s_size)
		2:
			var vbox = VBoxContainer.new()
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_theme_constant_override("separation", int(gap))
			vbox.add_child(_build_single_socket(_get_inlay_path(0, inlays), s_size))
			vbox.add_child(_build_single_socket(_get_inlay_path(1, inlays), s_size))
			return vbox
		3:
			var vbox = VBoxContainer.new()
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_theme_constant_override("separation", int(gap))
			vbox.add_child(_build_single_socket(_get_inlay_path(0, inlays), s_size))
			vbox.add_child(_build_single_socket(_get_inlay_path(1, inlays), s_size))
			vbox.add_child(_build_single_socket(_get_inlay_path(2, inlays), s_size))
			return vbox
		4:
			var grid = GridContainer.new()
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", int(gap))
			grid.add_theme_constant_override("v_separation", int(gap))
			for i in range(4):
				grid.add_child(_build_single_socket(_get_inlay_path(i, inlays), s_size))
			return grid
		5:
			# 经典暗黑2梅花孔位排布 (上2 中1 下2)
			var vbox = VBoxContainer.new()
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_theme_constant_override("separation", int(gap))
			
			var top_row = HBoxContainer.new()
			top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_row.add_theme_constant_override("separation", int(gap))
			top_row.add_child(_build_single_socket(_get_inlay_path(0, inlays), s_size))
			top_row.add_child(_build_single_socket(_get_inlay_path(1, inlays), s_size))
			vbox.add_child(top_row)
			
			var mid_center = CenterContainer.new()
			mid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mid_center.add_child(_build_single_socket(_get_inlay_path(2, inlays), s_size))
			vbox.add_child(mid_center)
			
			var bot_row = HBoxContainer.new()
			bot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bot_row.add_theme_constant_override("separation", int(gap))
			bot_row.add_child(_build_single_socket(_get_inlay_path(3, inlays), s_size))
			bot_row.add_child(_build_single_socket(_get_inlay_path(4, inlays), s_size))
			vbox.add_child(bot_row)
			return vbox
		6:
			# 2x3 网格
			var grid = GridContainer.new()
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", int(gap))
			grid.add_theme_constant_override("v_separation", int(gap))
			for i in range(6):
				grid.add_child(_build_single_socket(_get_inlay_path(i, inlays), s_size))
			return grid
		_:
			return null
