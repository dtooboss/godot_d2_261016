extends Control

## 暗黑破坏神2 登录界面控制器 (LoginController)
## 支持远程分区动态拉取 (PHP/JSON)、物理地址绝对隐藏、多大区与天梯赛季切换

@onready var id_input: LineEdit = $Panel/VBox/InputContainer/IdInput
@onready var pass_input: LineEdit = $Panel/VBox/InputContainer/PassInput
@onready var remember_check: CheckBox = $Panel/VBox/RememberContainer/RememberCheck
@onready var system_font_check: CheckBox = $Panel/VBox/RememberContainer/SystemFontCheck

# 大区选择条
@onready var server_info_label: Label = $Panel/VBox/ServerContainer/ServerInfoLabel
@onready var btn_change_server: Button = $Panel/VBox/ServerContainer/BtnChangeServer

# 状态提示与按钮
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var btn_login: Button = $Panel/VBox/ButtonContainer/BtnLogin
@onready var btn_register: Button = $Panel/VBox/ButtonContainer/HBoxSub/BtnRegister
@onready var btn_exit: Button = $Panel/VBox/ButtonContainer/HBoxSub/BtnExit

# 大区选择弹窗节点
@onready var realm_modal: Control = $RealmModal
@onready var realm_list_vbox: VBoxContainer = $RealmModal/CenterContainer/Panel/VBox/Scroll/RealmListVBox
@onready var btn_close_modal: Button = $RealmModal/CenterContainer/Panel/VBox/BtnCloseModal
@onready var footer_info: RichTextLabel = get_node_or_null("FooterInfo")

const CACHE_REALMS_PATH: String = "user://cached_realms.json"
const DEFAULT_REALMS_PATH: String = "res://data/default_realms.json"
const SAVE_PATH: String = "user://login_settings.json"

var remote_realms_url: String = "http://o.rainplay.cn:53000/"
var external_realms_loaded: bool = false
var cmdline_override_realm: bool = false

var realms: Array = []
var current_realm: Dictionary = {}
var selected_realm_id: String = ""
var _last_error_time: float = 0.0

var _http_request: HTTPRequest = null

func _ready() -> void:
	# 0. 刷新客户端版本号显示 (绿色 V0.1)
	if footer_info:
		var ver_str = GameState.CLIENT_VERSION if (GameState and "CLIENT_VERSION" in GameState) else "0.1"
		footer_info.text = "[right]《劳模必须死》CLIENT [color=#44ff44]V%s[/color] · 第一幕 游侠营地[/right]" % ver_str

	# 1. 优先载入外部配置与解析启动命令行参数 (解耦写死IP与通信密钥)
	_load_external_configs()
	_apply_cmdline_args()

	# 2. 载入本地/缓存大区与账号配置，确保界面毫秒级秒开
	_load_local_realms()
	_load_saved_settings()
	if cmdline_override_realm:
		_apply_cmdline_args() # 命令行指定服务器拥有最高优先级
	_update_server_display()
	
	# 3. 连接 NetworkClient 信号
	NetworkClient.connected_to_server.connect(_on_connected)
	NetworkClient.connection_failed.connect(_on_connection_failed)
	NetworkClient.disconnected_from_server.connect(_on_disconnected)
	NetworkClient.login_success.connect(_on_login_success)
	NetworkClient.login_failed.connect(_on_login_failed)
	
	# 4. 按钮点击绑定
	btn_login.pressed.connect(_on_login_pressed)
	btn_register.pressed.connect(_on_register_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_change_server.pressed.connect(_open_realm_modal)
	btn_close_modal.pressed.connect(_close_realm_modal)
	if system_font_check:
		system_font_check.button_pressed = GameState.use_system_font
		system_font_check.toggled.connect(_on_system_font_toggled)
	
	# 5. 回车直接触发登录
	id_input.text_submitted.connect(func(_text): pass_input.grab_focus())
	pass_input.text_submitted.connect(func(_text): _on_login_pressed())
	id_input.grab_focus()
	
	# 6. 后台异步静默从远程拉取最新大区列表 (若未显式被命令行锁定)
	if not cmdline_override_realm:
		_fetch_remote_realms()

## 载入外部配置文件 (支持可执行文件同级 server_config.json 或 realms.json)
func _load_external_configs() -> void:
	var base_dir = OS.get_executable_path().get_base_dir()
	var search_paths = [
		base_dir + "/server_config.json",
		base_dir + "/realms.json",
		"res://server_config.json",
		"user://server_config.json"
	]
	
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--config="):
			search_paths.insert(0, arg.substr(9).strip_edges())
			
	for cfg_path in search_paths:
		if FileAccess.file_exists(cfg_path):
			var file = FileAccess.open(cfg_path, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK:
					if json.data is Dictionary:
						var dict: Dictionary = json.data
						if dict.has("server_key"):
							NetworkClient.set_server_key(str(dict["server_key"]))
						if dict.has("realms_url"):
							remote_realms_url = str(dict["realms_url"])
						if dict.has("realms") and dict["realms"] is Array and dict["realms"].size() > 0:
							realms = dict["realms"]
							external_realms_loaded = true
							print("[Login] 成功从外部配置文件载入大区配置: ", cfg_path)
							break
					elif json.data is Array and json.data.size() > 0:
						realms = json.data
						external_realms_loaded = true
						print("[Login] 成功从外部 JSON 载入大区列表: ", cfg_path)
						break

## 应用启动命令行参数 (支持 --server=IP:PORT, --server-key=KEY, --realms-url=URL)
func _apply_cmdline_args() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--server-key="):
			var key = arg.substr(13).strip_edges()
			NetworkClient.set_server_key(key)
		elif arg.begins_with("--realms-url="):
			remote_realms_url = arg.substr(13).strip_edges()
		elif arg.begins_with("--server="):
			var s_val = arg.substr(9).strip_edges()
			var host = s_val
			var port = 7878
			if ":" in s_val:
				var parts = s_val.split(":")
				host = parts[0]
				port = int(parts[1]) if parts[1].is_valid_int() else 7878
			
			current_realm = {
				"id": "cmdline_custom",
				"name": "自定义服务器 (%s:%d)" % [host, port],
				"tag": "命令行",
				"status": "smooth",
				"host": host,
				"port": port
			}
			selected_realm_id = "cmdline_custom"
			cmdline_override_realm = true
			print("[Login] 命令行指定服务器参数: %s:%d" % [host, port])

## 从本地载入大区数据 (优先外部/缓存，其次默认内置)
func _load_local_realms() -> void:
	if external_realms_loaded:
		_sync_selected_realm()
		return

	var loaded = false
	if FileAccess.file_exists(CACHE_REALMS_PATH):
		var file = FileAccess.open(CACHE_REALMS_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array and json.data.size() > 0:
				realms = json.data
				loaded = true
				
	if not loaded and FileAccess.file_exists(DEFAULT_REALMS_PATH):
		var file = FileAccess.open(DEFAULT_REALMS_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				realms = json.data
				loaded = true
				
	_sync_selected_realm()

## 异步向远程 Linux API 拉取大区列表
func _fetch_remote_realms() -> void:
	if not is_inside_tree():
		return
	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.timeout = 4.0
		add_child(_http_request)
		_http_request.request_completed.connect(_on_remote_realms_received)
		
	var err = _http_request.request(remote_realms_url)
	if err != OK:
		print("[Login] 远程大区拉取请求失败，保持本地离线配置: ", err)

## 远程大区响应回调
func _on_remote_realms_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var text = body.get_string_from_utf8()
		if json.parse(text) == OK and json.data is Array and json.data.size() > 0:
			realms = json.data
			print("[Login] 成功从远程 Linux 获取最新大区列表，共 %d 个分区" % realms.size())
			
			# 写入本地缓存
			var cache_file = FileAccess.open(CACHE_REALMS_PATH, FileAccess.WRITE)
			if cache_file:
				cache_file.store_string(text)
				
			_sync_selected_realm()
			_update_server_display()
			if realm_modal.visible:
				_render_realm_cards()
	else:
		print("[Login] 远程大区接口未响应或返回错误码: %d，平滑降级使用本地配置" % response_code)

## 同步当前选中的大区对象
func _sync_selected_realm() -> void:
	if cmdline_override_realm:
		return

	if realms.is_empty():
		current_realm = {
			"id": "default",
			"name": "本地避难所",
			"tag": "单机",
			"status": "smooth",
			"host": "127.0.0.1",
			"port": 7878
		}
		return
		
	for r in realms:
		if r is Dictionary and str(r.get("id", "")) == selected_realm_id:
			current_realm = r
			return
			
	# 若无匹配或首次进入，默认选中第一个大区
	current_realm = realms[0]
	selected_realm_id = str(current_realm.get("id", ""))

## 更新登录面板上的大区展示 (绝对隐藏真实 IP 和端口)
func _update_server_display() -> void:
	var r_name = current_realm.get("name", "未知大区")
	var r_tag = current_realm.get("tag", "标准区")
	var r_status = current_realm.get("status", "smooth")
	
	var status_text = "流畅"
	var status_color = Color(0.4, 0.9, 0.4) # 绿
	
	if r_status == "hot":
		status_text = "火爆"
		status_color = Color(1.0, 0.7, 0.2) # 橙
	elif r_status == "busy":
		status_text = "拥挤"
		status_color = Color(1.0, 0.4, 0.2) # 红
	elif r_status == "maintenance":
		status_text = "维护中"
		status_color = Color(0.6, 0.6, 0.6) # 灰
		
	server_info_label.text = "[%s] %s  (%s)" % [r_tag, r_name, status_text]
	server_info_label.modulate = status_color

## 打开大区选择弹窗
func _open_realm_modal() -> void:
	_render_realm_cards()
	realm_modal.visible = true

## 关闭大区选择弹窗
func _close_realm_modal() -> void:
	realm_modal.visible = false

## 动态渲染大区卡片列表
func _render_realm_cards() -> void:
	for child in realm_list_vbox.get_children():
		child.queue_free()
		
	for r in realms:
		if not (r is Dictionary):
			continue
			
		var r_id = str(r.get("id", ""))
		var r_name = str(r.get("name", "未命名大区"))
		var r_tag = str(r.get("tag", "标准区"))
		var r_desc = str(r.get("desc", ""))
		var r_status = str(r.get("status", "smooth"))
		var is_season = bool(r.get("is_season", false))
		var is_selected = (r_id == selected_realm_id)
		
		# 卡片按钮容器
		var card = Button.new()
		card.custom_minimum_size = Vector2(0, 56)
		card.flat = false
		
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 12
		hbox.offset_right = -12
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hbox)
		
		# 左侧：名称与简介
		var vbox_info = VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(vbox_info)
		
		var title_label = Label.new()
		title_label.text = r_name + ("  [当前选择]" if is_selected else "")
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55) if is_selected else Color(0.9, 0.9, 0.9))
		vbox_info.add_child(title_label)
		
		if not r_desc.is_empty():
			var desc_label = Label.new()
			desc_label.text = r_desc
			desc_label.add_theme_font_size_override("font_size", 11)
			desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			vbox_info.add_child(desc_label)
			
		# 右侧：赛季标签与状态微光
		var tag_label = Label.new()
		tag_label.text = "【%s】" % r_tag
		tag_label.add_theme_font_size_override("font_size", 12)
		tag_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if is_season else Color(0.7, 0.7, 0.8))
		hbox.add_child(tag_label)
		
		var status_label_card = Label.new()
		var status_text = "● 流畅"
		var sc = Color(0.4, 0.9, 0.4)
		if r_status == "hot":
			status_text = "● 火爆"
			sc = Color(1.0, 0.7, 0.2)
		elif r_status == "busy":
			status_text = "● 拥挤"
			sc = Color(1.0, 0.4, 0.2)
		elif r_status == "maintenance":
			status_text = "● 维护中"
			sc = Color(0.6, 0.6, 0.6)
			card.disabled = true
			
		status_label_card.text = status_text
		status_label_card.add_theme_font_size_override("font_size", 12)
		status_label_card.add_theme_color_override("font_color", sc)
		hbox.add_child(status_label_card)
		
		# 绑定选择点击
		card.pressed.connect(func():
			_select_realm(r)
			_close_realm_modal()
		)
		realm_list_vbox.add_child(card)

## 切换选定的大区
func _select_realm(r: Dictionary) -> void:
	current_realm = r
	selected_realm_id = str(r.get("id", ""))
	_update_server_display()
	_save_settings()

func _on_login_pressed() -> void:
	_execute_auth("login")

func _on_register_pressed() -> void:
	_execute_auth("register")

func _execute_auth(action: String) -> void:
	var user = id_input.text.strip_edges()
	var pass_str = pass_input.text.strip_edges()
	
	if user.is_empty():
		_set_status("请输入通行证账号", Color(1.0, 0.4, 0.4))
		id_input.grab_focus()
		return
		
	if pass_str.is_empty():
		_set_status("请输入通行证密码", Color(1.0, 0.4, 0.4))
		pass_input.grab_focus()
		return
		
	# 检查大区维护状态
	var r_status = str(current_realm.get("status", "smooth"))
	var r_name = str(current_realm.get("name", "当前大区"))
	if r_status == "maintenance":
		_set_status("【%s】正在例行维护中，请选择其他大区或稍后登录" % r_name, Color(1.0, 0.5, 0.2))
		return
		
	_set_loading(true)
	if action == "register":
		_set_status("正在向【%s】注册新通行证..." % r_name, Color(0.8, 0.8, 0.9))
	else:
		_set_status("正在连接【%s】要塞..." % r_name, Color(0.8, 0.8, 0.9))
		
	_save_settings()
	_last_error_time = 0.0
	
	# 私有内部读取 host 与 port，UI 绝对不显示
	var host = str(current_realm.get("host", "127.0.0.1"))
	var port = int(current_realm.get("port", 7878))
	NetworkClient.connect_and_login(host, port, user, pass_str, action)

func _on_connected() -> void:
	_set_status("已连通大区，正在协商版本与验证身份...", Color(0.9, 0.85, 0.6))

func _on_connection_failed() -> void:
	_set_loading(false)
	var r_name = str(current_realm.get("name", "所选"))
	_set_status("无法连接到【%s】服务器，请检查网络或稍后重试" % r_name, Color(1.0, 0.3, 0.3))

func _on_disconnected() -> void:
	_set_loading(false)
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_error_time < 5.0:
		# 刚刚发生过登录/注册业务错误，保留具体的错误提示文案
		return
	_set_status("与服务器的连接已中断", Color(1.0, 0.4, 0.4))

func _on_login_success(characters: Array) -> void:
	_set_status("认证成功！正在载入英雄圣殿...", Color(0.4, 1.0, 0.5))
	print("[Login] 成功获取角色列表: ", characters)
	GameState.character_list = characters
	GameState.current_account = id_input.text.strip_edges().to_lower()
	
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file("res://scenes/lobby/character_select_screen.tscn")

func _on_login_failed(err_msg: String) -> void:
	_last_error_time = Time.get_ticks_msec() / 1000.0
	_set_loading(false)
	var display_msg = err_msg
	if not ("失败" in display_msg or "错误" in display_msg or "已被" in display_msg or "不存在" in display_msg):
		display_msg = "操作失败: " + display_msg
	_set_status(display_msg, Color(1.0, 0.3, 0.3))

func _set_loading(loading: bool) -> void:
	btn_login.disabled = loading
	btn_register.disabled = loading
	btn_change_server.disabled = loading
	id_input.editable = not loading
	pass_input.editable = not loading

func _set_status(msg: String, color: Color) -> void:
	status_label.text = msg
	status_label.modulate = color

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_system_font_toggled(button_pressed: bool) -> void:
	GameState.apply_font_preference(button_pressed)
	_save_settings()

func _load_saved_settings() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			var json = JSON.new()
			if json.parse(json_str) == OK and json.data is Dictionary:
				var data = json.data
				id_input.text = str(data.get("user", ""))
				if data.get("remember", false):
					remember_check.button_pressed = true
					pass_input.text = str(data.get("pass", ""))
				if data.has("use_system_font") and system_font_check:
					var use_sys = bool(data.get("use_system_font", false))
					system_font_check.button_pressed = use_sys
					GameState.apply_font_preference(use_sys)
				if not cmdline_override_realm:
					selected_realm_id = str(data.get("selected_realm_id", ""))
					_sync_selected_realm()

func _save_settings() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"user": id_input.text.strip_edges(),
			"remember": remember_check.button_pressed,
			"pass": pass_input.text if remember_check.button_pressed else "",
			"selected_realm_id": selected_realm_id,
			"use_system_font": system_font_check.button_pressed if system_font_check else false
		}
		file.store_string(JSON.stringify(data))
