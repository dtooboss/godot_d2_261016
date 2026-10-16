extends CanvasLayer

## 全局断线重连浮层 (ReconnectOverlay)
## 无论在战斗、主城还是大厅，断线时均会自动显示并提示重连进度

var panel: PanelContainer
var lbl_status: Label
var btn_box: HBoxContainer
var btn_retry: Button
var btn_logout: Button
var fade_tween: Tween

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	visible = false

func _build_ui() -> void:
	# 居中顶部悬浮卡片
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 50)
	panel.anchors_preset = Control.PRESET_CENTER_TOP
	panel.offset_top = 24.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# 暗黑风格半透明黑底金边框
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.border_color = Color(0.85, 0.65, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	lbl_status = Label.new()
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_status.add_theme_font_size_override("font_size", 14)
	lbl_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl_status.text = "⚡ 网络连接已断开，正在尝试重新连接..."
	vbox.add_child(lbl_status)

	# 失败时的操作按钮排 (重试 / 登出)
	btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	btn_box.visible = false
	vbox.add_child(btn_box)

	btn_retry = Button.new()
	btn_retry.text = "立即重试"
	btn_retry.custom_minimum_size = Vector2(90, 28)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_box.add_child(btn_retry)

	btn_logout = Button.new()
	btn_logout.text = "返回登录"
	btn_logout.custom_minimum_size = Vector2(90, 28)
	btn_logout.pressed.connect(_on_logout_pressed)
	btn_box.add_child(btn_logout)

func _connect_signals() -> void:
	if NetworkClient.has_signal("reconnecting"):
		NetworkClient.reconnecting.connect(_on_reconnecting)
	if NetworkClient.has_signal("reconnected_to_server"):
		NetworkClient.reconnected_to_server.connect(_on_reconnected)
	if NetworkClient.has_signal("reconnect_failed"):
		NetworkClient.reconnect_failed.connect(_on_reconnect_failed)

func _on_reconnecting(attempt: int, max_attempts: int) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	panel.modulate.a = 1.0
	visible = true
	btn_box.visible = false
	lbl_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	lbl_status.text = "⚡ 网络连接中断，正在尝试第 %d/%d 次重连..." % [attempt, max_attempts]

func _on_reconnected() -> void:
	lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.45))
	lbl_status.text = "✔ 已成功恢复连接！正在同步战场状态..."
	btn_box.visible = false
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_interval(1.0)
	fade_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func(): visible = false)

func _on_reconnect_failed() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	panel.modulate.a = 1.0
	visible = true
	lbl_status.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
	lbl_status.text = "❌ 无法连通服务器，请检查网络后重试"
	btn_box.visible = true

func hide_overlay() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	visible = false
	if btn_box:
		btn_box.visible = false

func _on_retry_pressed() -> void:
	btn_box.visible = false
	NetworkClient.retry_reconnect()

func _on_logout_pressed() -> void:
	hide_overlay()
	await NetworkClient.safe_quit_and_disconnect()
	get_tree().change_scene_to_file("res://scenes/login/login_screen.tscn")
