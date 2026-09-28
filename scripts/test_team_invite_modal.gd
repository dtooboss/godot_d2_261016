extends Node

## 组队邀请确认/拒绝弹窗自动化测试脚本

const TeamInviteDialogScript = preload("res://scripts/ui/team_invite_dialog.gd")
@onready var dialog: Control = $TeamInviteDialog
var test_received_cmd: String = ""
var test_rejected: bool = false

func _ready() -> void:
	print("--- 开始运行组队邀请弹窗自动化测试 ---")
	
	# 模拟 LPC 下发的真实组队 NDJSON 帧
	var mock_desc = "\u001b[1;33m野蛮人·旋风狂人\u001b[0m邀请你加入组队。\n"
	var accept_cmd = "team with barb_test"
	var reject_cmd = "look"
	
	dialog.show_invite(mock_desc, accept_cmd, reject_cmd, 15.0)
	
	# 1. 验证弹窗状态
	assert(dialog.visible == true, "弹窗应处于可见状态")
	assert(dialog.is_active == true, "弹窗状态机应为激活状态")
	print("✔ 弹窗显示与状态机激活正常")
	
	# 2. 验证富文本去色清洗与渲染
	var desc_text = dialog.desc_label.text
	assert("野蛮人·旋风狂人" in desc_text, "描述中应包含邀请者姓名")
	assert(not "\u001b" in desc_text, "描述中不应有裸露的 ANSI 控制字符")
	print("✔ ANSI 序列清洗与富文本转换正常: ", desc_text)
	
	# 3. 验证按钮与倒计时
	var btn_reject_text = dialog.btn_reject.text
	var timer_text = dialog.timer_label.text
	assert("15" in btn_reject_text or "15" in timer_text, "倒计时数字应正确渲染")
	print("✔ 倒计时文本渲染正常: ", timer_text)
	
	# 等待 0.2 秒以完成 UI 布局与光栅化渲染并截图
	await get_tree().create_timer(0.2).timeout
	
	_take_screenshot("test_team_invite_modal_popup.png")
	
	# 4. 测试点击接受事件
	dialog.invite_accepted.connect(func(cmd):
		test_received_cmd = cmd
	)
	
	dialog._on_accept_pressed()
	
	assert(test_received_cmd == "team with barb_test", "接受信号派发的指令应为 team with barb_test")
	assert(dialog.visible == false, "点击接受后弹窗应自动关闭")
	print("✔ 接受按钮点击事件与网络指令分派正常: ", test_received_cmd)
	
	# 5. 测试拒绝并关闭
	dialog.show_invite(mock_desc, accept_cmd, reject_cmd, 10.0)
	dialog.invite_rejected.connect(func():
		test_rejected = true
	)
	dialog._on_reject_pressed()
	assert(test_rejected == true, "拒绝信号应正常发射")
	assert(dialog.visible == false, "点击拒绝后弹窗应自动关闭")
	print("✔ 拒绝按钮点击事件与弹窗关闭正常")

	
	print("🎉 组队邀请确认/拒绝弹窗所有自动化测试用例均通过！")
	get_tree().quit(0)

func _take_screenshot(filename: String) -> void:
	var viewport = get_viewport()
	if not viewport: return
	var tex = viewport.get_texture()
	if not tex: return
	var img = tex.get_image()
	if not img:
		print("当前处于 headless 模式，跳过截图采集")
		return
	var save_path = "C:/Users/Administrator/.gemini/antigravity/brain/b2f1f44a-f5cb-43fb-a6c5-206e6e3aba7c/" + filename
	img.save_png(save_path)
	print("已保存实机渲染截图至: ", save_path)
