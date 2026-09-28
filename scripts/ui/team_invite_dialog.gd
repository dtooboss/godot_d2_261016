extends Control
class_name TeamInviteDialog

## 暗黑2古典风格组队邀请确认/拒绝弹窗
## 捕获服务端 LPC 下发的 J_PANEL 组队帧并提供接受、拒绝与倒计时关闭

signal invite_accepted(cmd: String)
signal invite_rejected()

@onready var title_label: Label = %TitleLabel
@onready var desc_label: RichTextLabel = %DescLabel
@onready var hint_label: Label = %HintLabel
@onready var timer_label: Label = %TimerLabel
@onready var btn_accept: Button = %BtnAccept
@onready var btn_reject: Button = %BtnReject
@onready var btn_close: Button = %BtnClose
@onready var backdrop: ColorRect = %Backdrop

var current_accept_cmd: String = ""
var current_reject_cmd: String = ""
var remaining_time: float = 15.0
var is_active: bool = false

const AnsiHelperScript = preload("res://scripts/utils/ansi_helper.gd")

func _ready() -> void:
	visible = false
	if btn_accept:
		btn_accept.pressed.connect(_on_accept_pressed)
	if btn_reject:
		btn_reject.pressed.connect(_on_reject_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_reject_pressed)
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

func _process(delta: float) -> void:
	if not is_active or not visible:
		return
		
	remaining_time -= delta
	if remaining_time <= 0.0:
		_on_timeout()
	else:
		_update_timer_display()

## 弹出组队邀请
func show_invite(raw_desc: String, accept_cmd: String, reject_cmd: String = "look", timeout_sec: float = 15.0) -> void:
	current_accept_cmd = accept_cmd.strip_edges()
	current_reject_cmd = reject_cmd.strip_edges()
	remaining_time = timeout_sec
	is_active = true
	
	# 文本富文本化与去除原生控制码
	var bbcode_desc = AnsiHelperScript.to_bbcode(raw_desc).strip_edges()
	if desc_label:
		desc_label.text = "[center]" + bbcode_desc + "[/center]"
		
	if hint_label:
		hint_label.text = "组队后同场景并肩作战将共享战斗经验与掉落加成。\n（不同难度英雄无法组队）"
		
	_update_timer_display()
	visible = true
	move_to_front()

## 更新倒计时显示
func _update_timer_display() -> void:
	var sec = int(ceil(remaining_time))
	if timer_label:
		timer_label.text = "（%d 秒后自动关闭）" % sec
	if btn_accept:
		btn_accept.text = "接受"
	if btn_reject:
		btn_reject.text = "拒绝 (%ds)" % sec

## 点击接受
func _on_accept_pressed() -> void:
	var cmd = current_accept_cmd
	hide_dialog()
	if not cmd.is_empty():
		if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
			var net = get_node_or_null("/root/NetworkClient")
			if net and net.is_connected:
				net.send_raw(cmd)
	invite_accepted.emit(cmd)

## 点击拒绝
func _on_reject_pressed() -> void:
	var cmd = current_reject_cmd
	hide_dialog()
	# 如果服务端拒绝指令是 look 且有连接，可执行或静默关闭
	if not cmd.is_empty() and cmd != "look":
		if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
			var net = get_node_or_null("/root/NetworkClient")
			if net and net.is_connected:
				net.send_raw(cmd)
	invite_rejected.emit()

## 超时自动关闭
func _on_timeout() -> void:
	hide_dialog()
	invite_rejected.emit()

## 关闭并重置弹窗
func hide_dialog() -> void:
	is_active = false
	visible = false
	current_accept_cmd = ""
	current_reject_cmd = ""

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击遮罩空白处不做盲关，防止误触关闭重要邀请；支持右上角和ESC
		pass

func _unhandled_input(event: InputEvent) -> void:
	if visible and is_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_reject_pressed()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_on_accept_pressed()
