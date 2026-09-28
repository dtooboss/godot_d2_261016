extends Node

## Diablo II LPC 网络客户端核心单例 (NetworkClient)
## 负责与 LPC 服务端 (7878/7879) 维持原生 TCP Socket 握手通信与 NDJSON 协议分帧

signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()
signal login_success(characters: Array)
signal login_failed(error_msg: String)
signal json_frame_received(type: String, data: Variant)
signal text_received(raw_text: String)
signal raw_sent(text: String)

var tcp_client: StreamPeerTCP = StreamPeerTCP.new()
var is_connected: bool = false
var receive_buffer: PackedByteArray = PackedByteArray()

# 登录握手上下文
var auth_user: String = ""
var auth_pass: String = ""
var auth_action: String = "login"
var server_key: String = "AP4s3dF5"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	tcp_client.poll()
	var status = tcp_client.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not is_connected:
			is_connected = true
			emit_signal("connected_to_server")
			print("[NetworkClient] 已成功连接至 LPC 战网服务器")
		
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

## 发起连接并准备认证
func connect_and_login(host: String, port: int, user: String, password: String, action: String = "login") -> Error:
	auth_user = user.strip_edges().to_lower()
	auth_pass = password
	auth_action = action
	
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
		print("[NetworkClient] 版本协商通过，正在发送通行证认证包...")
		# 构造暗黑2 LPC 专属认证协议格式: user║pass║serverKey║json║action
		var auth_packet = "%s║%s║%s║json║%s" % [auth_user, auth_pass, server_key, auth_action]
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
			
			# 检查登录错误
			if dict.has("error") and dict.get("error", 0) != 0:
				var msg = str(dict.get("msg", "登录认证失败"))
				print("[NetworkClient] 登录认证失败: ", msg)
				emit_signal("login_failed", msg)
				return
				
			# 检查战网角色大厅列表
			if dict.has("characters") or dict.has("character_list"):
				var char_list = dict.get("characters", dict.get("character_list", []))
				print("[NetworkClient] 登录认证成功！收到角色大厅数据: ", char_list.size(), " 个角色")
				emit_signal("login_success", char_list)
				return
				
			# 通用协议派发 (type & data)
			var type = str(dict.get("type", ""))
			var data = dict.get("data", null)
			emit_signal("json_frame_received", type, data)
			return

	# 普通文本行输出
	emit_signal("text_received", line)

## 断开连接
func disconnect_server() -> void:
	if is_connected:
		tcp_client.disconnect_from_host()
		is_connected = false
