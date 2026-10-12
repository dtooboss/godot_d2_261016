extends Node

## Diablo II LPC 网络客户端核心单例 (NetworkClient)
## 负责与 LPC 服务端 (7878/7879) 维持原生 TCP Socket 握手通信、NDJSON 协议分帧与自动断线重连

signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()
signal reconnecting(attempt: int, max_attempts: int)
signal reconnected_to_server()
signal reconnect_failed()
signal login_success(characters: Array)
signal login_failed(error_msg: String)
signal json_frame_received(type: String, data: Variant)
signal text_received(raw_text: String)
signal raw_sent(text: String)

var tcp_client: StreamPeerTCP = StreamPeerTCP.new()
var is_connected: bool = false
var receive_buffer: PackedByteArray = PackedByteArray()

# 登录握手上下文
var current_host: String = ""
var current_port: int = 7878
var auth_user: String = ""
var auth_pass: String = ""
var auth_action: String = "login"
var server_key: String = "AP4s3dF5"

# 自动重连控制
var auto_reconnect: bool = true
var reconnect_attempts: int = 0
const MAX_RECONNECT_ATTEMPTS: int = 10
const RECONNECT_INTERVAL: float = 3.0
var reconnect_timer: float = 0.0
var is_reconnecting: bool = false
var manual_disconnect: bool = false

# 全局重连浮层引用
var overlay: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup_overlay")

func _setup_overlay() -> void:
	if overlay == null:
		var overlay_script = load("res://scripts/ui/reconnect_overlay.gd")
		if overlay_script:
			overlay = overlay_script.new()
			add_child(overlay)

func _process(delta: float) -> void:
	tcp_client.poll()
	var status = tcp_client.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not is_connected:
			is_connected = true
			emit_signal("connected_to_server")
			print("[NetworkClient] 已成功建立与 LPC 战网服务器的 TCP 连接")
		
		# 读取所有可用数据
		var available = tcp_client.get_available_bytes()
		if available > 0:
			var chunk = tcp_client.get_data(available)
			if chunk[0] == OK:
				receive_buffer.append_array(chunk[1])
				_process_buffer()
				
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		if is_connected:
			is_connected = false
			emit_signal("disconnected_from_server")
			print("[NetworkClient] 与 LPC 服务器的连接已断开")
			if auto_reconnect and not manual_disconnect:
				_start_reconnect_cycle()
				
	# 驱动自动重连周期调度
	if is_reconnecting and not is_connected:
		reconnect_timer -= delta
		if reconnect_timer <= 0.0:
			_attempt_reconnect()

## 发起连接并准备认证
func connect_and_login(host: String, port: int, user: String, password: String, action: String = "login") -> Error:
	current_host = host
	current_port = port
	auth_user = user.strip_edges().to_lower()
	auth_pass = password
	auth_action = action
	manual_disconnect = false
	is_reconnecting = false
	reconnect_attempts = 0
	
	if is_connected:
		tcp_client.disconnect_from_host()
		is_connected = false
		
	receive_buffer.clear()
	var err = tcp_client.connect_to_host(host, port)
	if err != OK:
		print("[NetworkClient] 无法建立 TCP 连接: ", err)
		emit_signal("connection_failed")
	return err

## 发送原始字符串 (自动追加换行符)
func send_raw(text: String) -> void:
	emit_signal("raw_sent", text.strip_edges())
	if is_connected:
		if not text.ends_with("\n"):
			text += "\n"
		tcp_client.put_data(text.to_utf8_buffer())

## 启动重连调度
func _start_reconnect_cycle() -> void:
	if is_reconnecting: return
	if current_host.is_empty() or current_port <= 0: return
	if manual_disconnect: return
	
	is_reconnecting = true
	reconnect_attempts = 0
	reconnect_timer = 0.5 # 初次掉线后 0.5s 极速初试
	print("[NetworkClient] 触发自动重连机制，准备发起重连...")

## 发起单次重连尝试
func _attempt_reconnect() -> void:
	if manual_disconnect or not auto_reconnect:
		_stop_reconnect()
		return
		
	reconnect_attempts += 1
	if reconnect_attempts > MAX_RECONNECT_ATTEMPTS:
		print("[NetworkClient] 已达到最大重连次数 (%d)，停止自动重连" % MAX_RECONNECT_ATTEMPTS)
		_stop_reconnect()
		emit_signal("reconnect_failed")
		return
		
	print("[NetworkClient] 正在发起第 %d/%d 次重连 (%s:%d)..." % [reconnect_attempts, MAX_RECONNECT_ATTEMPTS, current_host, current_port])
	emit_signal("reconnecting", reconnect_attempts, MAX_RECONNECT_ATTEMPTS)
	reconnect_timer = RECONNECT_INTERVAL
	
	receive_buffer.clear()
	tcp_client.disconnect_from_host()
	var err = tcp_client.connect_to_host(current_host, current_port)
	if err != OK:
		print("[NetworkClient] 重连 TCP 连接发起失败: ", err)

## 手动重试重连
func retry_reconnect() -> void:
	reconnect_attempts = 0
	is_reconnecting = true
	manual_disconnect = false
	_attempt_reconnect()

## 停止重连
func _stop_reconnect() -> void:
	is_reconnecting = false
	reconnect_attempts = 0
	reconnect_timer = 0.0

## 处理接收缓冲区中的每一行 (以 \n 拆帧)
func _process_buffer() -> void:
	var newline_pos = receive_buffer.find(10) # ASCII 10 = '\n'
	while newline_pos != -1:
		var line_bytes = receive_buffer.slice(0, newline_pos)
		receive_buffer = receive_buffer.slice(newline_pos + 1)
		
		var line_str = line_bytes.get_string_from_utf8().strip_edges()
		if line_str.length() > 0:
			_handle_incoming_line(line_str)
			
		newline_pos = receive_buffer.find(10)

## 协议分发与登录握手状态机
func _handle_incoming_line(line: String) -> void:
	# 1. 第一步：收到版本协商指令 (ver1.0,crypt)
	if line.begins_with("ver"):
		print("[NetworkClient] 收到服务端版本握手: ", line)
		send_raw("版本验证成功")
		return
		
	# 2. 第二步：收到版本验证通过确认
	if "版本验证成功" in line:
		print("[NetworkClient] 版本协商通过，正在发送认证包...")
		# 智能判断直连角色恢复还是进入角色选择大厅
		var gs = get_node_or_null("/root/GameState")
		var cur_char_id = ""
		var cur_diff = "normal"
		if gs and "selected_character" in gs and gs.selected_character is Dictionary and not gs.selected_character.is_empty():
			cur_char_id = str(gs.selected_character.get("char_id", gs.selected_character.get("id", "")))
			cur_diff = str(gs.selected_character.get("difficulty", "normal"))
		
		var auth_packet = ""
		if not cur_char_id.is_empty():
			# 角色直连恢复协议：user║pass║serverKey║json║char_id║diff
			print("[NetworkClient] 检测到正在游戏中，发送角色直连恢复协议: ", cur_char_id, " [", cur_diff, "]")
			auth_packet = "%s║%s║%s║json║%s║%s" % [auth_user, auth_pass, server_key, cur_char_id, cur_diff]
		else:
			# 常规选角大厅协议: user║pass║serverKey║json║action
			auth_packet = "%s║%s║%s║json║%s" % [auth_user, auth_pass, server_key, auth_action]
		send_raw(auth_packet)
		return
		
	# 3. 第三步：处理 JSON 协议帧 (J_{...} 或纯 NDJSON {...})
	var json_str = ""
	if line.begins_with("J_{"):
		json_str = line.substr(2)
	elif line.begins_with("{"):
		json_str = line
		
	if json_str.length() > 0:
		var json = JSON.new()
		var parse_err = json.parse(json_str)
		if parse_err == OK and json.data is Dictionary:
			var dict: Dictionary = json.data
			var type = str(dict.get("type", ""))
			
			# 检查登录/操作错误 (兼容 error 字段与 type == "error" 格式)
			if (dict.has("error") and dict.get("error", 0) != 0) or type == "error":
				var msg = str(dict.get("msg", "操作失败"))
				print("[NetworkClient] 收到错误响应: ", msg)
				emit_signal("login_failed", msg)
				emit_signal("json_frame_received", "error", dict)
				return
				
			# 检查战网角色大厅列表
			if dict.has("characters") or dict.has("character_list") or type == "character_list":
				var char_list = dict.get("characters", dict.get("character_list", []))
				print("[NetworkClient] 收到角色大厅数据: ", char_list.size(), " 个角色")
				if is_reconnecting:
					_stop_reconnect()
					emit_signal("reconnected_to_server")
				emit_signal("login_success", char_list)
				emit_signal("json_frame_received", "character_list", dict)
				return

			# 检查登录成功 / 重连成功
			if type == "login_ok" or (type == "status" and is_reconnecting):
				if is_reconnecting:
					print("[NetworkClient] ★★★ 断线重连认证成功！已恢复角色连接 ★★★")
					_stop_reconnect()
					emit_signal("reconnected_to_server")
				
			# 通用协议派发 (type & data)
			var data = dict.get("data", null)
			emit_signal("json_frame_received", type, data)
			return

	# 检查文本帧重连标记 (0007 / 重新连接成功)
	if "0007" in line or "重新连接成功" in line:
		if is_reconnecting:
			print("[NetworkClient] ★★★ 断线重连成功！已恢复角色连接 ★★★")
			_stop_reconnect()
			emit_signal("reconnected_to_server")

	# 普通文本行输出
	emit_signal("text_received", line)

## 断开连接
## [is_manual] 是否为用户主动退出，主动退出时不触发自动重连
func disconnect_server(is_manual: bool = true) -> void:
	if is_manual:
		manual_disconnect = true
		_stop_reconnect()
	if is_connected:
		tcp_client.disconnect_from_host()
		is_connected = false
