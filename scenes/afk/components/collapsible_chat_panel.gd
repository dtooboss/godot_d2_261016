extends Control
class_name AFK_CollapsibleChatPanel

## 挂机战斗专属可折叠/回缩传音视窗
## 放置于战斗视口左下角(红球上方)，收起时为24px微型跑马灯条，展开时为140px完整聊天视窗

signal item_inspected(file_id: String)
signal focus_changed(is_focused: bool)

# 节点引用
@onready var collapsed_bar: PanelContainer = %CollapsedBar
@onready var lbl_snippet: Label = %LblSnippet
@onready var btn_expand: Button = %BtnExpand

@onready var expanded_panel: PanelContainer = %ExpandedPanel
@onready var btn_collapse: Button = %BtnCollapse
@onready var chat_log: RichTextLabel = %ChatLog
@onready var channel_select: OptionButton = %ChannelSelect
@onready var chat_input: LineEdit = %ChatInput
@onready var btn_send: Button = %BtnSend

# 状态与附带装备
var is_expanded: bool = false
var attached_item: Dictionary = {}

const CHANNEL_CMDS = {
	0: "chat", # 世界频道 (默认)
	1: "tt",   # 队伍频道
	2: "bill"  # 交易频道
}

func _ready() -> void:
	_init_channel_select()
	_connect_signals()
	_load_initial_history()
	set_expanded(false)

func _init_channel_select() -> void:
	if not channel_select: return
	channel_select.clear()
	channel_select.add_item("世界", 0)
	channel_select.add_item("队伍", 1)
	channel_select.add_item("交易", 2)
	channel_select.selected = 0

func _connect_signals() -> void:
	if btn_expand:
		btn_expand.pressed.connect(func(): set_expanded(true))
	if btn_collapse:
		btn_collapse.pressed.connect(func(): set_expanded(false))
		
	if btn_send:
		btn_send.pressed.connect(func(): _on_chat_submitted(chat_input.text))
	if chat_input:
		chat_input.text_submitted.connect(_on_chat_submitted)
		chat_input.focus_entered.connect(func(): focus_changed.emit(true))
		chat_input.focus_exited.connect(func(): focus_changed.emit(false))
		if chat_input.has_signal("item_dropped"):
			chat_input.item_dropped.connect(insert_item_to_chat)
			
	if chat_log:
		chat_log.meta_clicked.connect(_on_meta_clicked)
		
	# 监听全局消息流
	if GameState.has_signal("chat_message_added"):
		GameState.chat_message_added.connect(_on_global_chat_message_added)

## 载入已有全局历史消息 (从大本营或之前战斗累积)
func _load_initial_history() -> void:
	if chat_log:
		chat_log.clear()
		for msg in GameState.chat_history:
			chat_log.append_text(msg + "\n")
	if lbl_snippet:
		lbl_snippet.text = AnsiHelper.strip_bbcode(GameState.latest_chat_snippet)

## 全局消息更新事件响应
func _on_global_chat_message_added(bbcode: String, snippet: String) -> void:
	if chat_log:
		chat_log.append_text(bbcode + "\n")
	if lbl_snippet:
		lbl_snippet.text = AnsiHelper.strip_bbcode(snippet)

## 切换折叠 / 展开状态
func set_expanded(expanded: bool) -> void:
	is_expanded = expanded
	if collapsed_bar:
		collapsed_bar.visible = not is_expanded
	if expanded_panel:
		expanded_panel.visible = is_expanded
	
	if is_expanded:
		custom_minimum_size = Vector2(320, 140)
		offset_left = 12.0
		offset_top = -325.0
		offset_right = 12.0 + 320.0
		offset_bottom = -185.0
		if chat_input:
			# 展开后平滑聚焦到输入栏末尾
			chat_input.grab_focus()
	else:
		custom_minimum_size = Vector2(280, 24)
		offset_left = 12.0
		offset_top = -209.0
		offset_right = 12.0 + 280.0
		offset_bottom = -185.0
		if chat_input and chat_input.has_focus():
			chat_input.release_focus()

func toggle_expanded() -> void:
	set_expanded(not is_expanded)

## 将背包装备插入输入框 (支持拖入与 Shift+点击)
func insert_item_to_chat(item_data: Dictionary) -> void:
	if not is_expanded:
		set_expanded(true)
		
	var raw_name = str(item_data.get("name", "装备"))
	var clean_name = AnsiHelper.to_plain_text(raw_name).strip_edges()
	var fid = str(item_data.get("file_id", item_data.get("id", "")))
	if fid.is_empty(): return
	
	var tag = "【%s】" % clean_name
	attached_item = {
		"file_id": fid,
		"name": clean_name,
		"tag": tag
	}
	
	var col = chat_input.caret_column
	var cur_text = chat_input.text
	var before = cur_text.substr(0, col)
	var after = cur_text.substr(col)
	
	chat_input.text = before + tag + " " + after
	chat_input.grab_focus()
	chat_input.caret_column = (before + tag + " ").length()

## 提交发送聊天
func _on_chat_submitted(text: String) -> void:
	var msg = text.strip_edges()
	if msg.is_empty(): return
	
	# 附带装备则触发 gshowitem
	if not attached_item.is_empty() and attached_item.get("tag", "") in msg:
		var fid = attached_item.get("file_id", "")
		NetworkClient.send_raw("gshowitem %s %s" % [fid, msg])
		attached_item.clear()
	elif msg.begins_with("/tell ") or msg.begins_with("/t "):
		NetworkClient.send_raw(msg.replace("/", ""))
	elif msg.begins_with("/show ") or msg.begins_with("gshowitem ") or msg.begins_with("showitem "):
		NetworkClient.send_raw(msg.replace("/", ""))
	else:
		var ch_idx = channel_select.selected if channel_select else 0
		var cmd_prefix = CHANNEL_CMDS.get(ch_idx, "chat")
		NetworkClient.send_raw("%s %s" % [cmd_prefix, msg])
		
	chat_input.text = ""
	chat_input.release_focus()

## 点击富文本超链接
func _on_meta_clicked(meta: Variant) -> void:
	var meta_str = str(meta).strip_edges()
	if meta_str.begins_with("item:"):
		var file_id = meta_str.substr(5)
		item_inspected.emit(file_id)
	elif meta_str.begins_with("cmds:"):
		var cmd = meta_str.substr(5)
		if NetworkClient.is_connected:
			NetworkClient.send_raw(cmd)

## 快捷键阻断与处理
func _unhandled_input(event: InputEvent) -> void:
	if not is_expanded: return
	if chat_input and chat_input.has_focus():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
