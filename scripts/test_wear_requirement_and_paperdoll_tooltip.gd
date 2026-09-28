extends Control

@onready var hud = $AFK_MainHUD

var sent_commands: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	
	print("=== 开始验证装备需求校验拦截提示与纸娃娃悬停 Tooltip 完整词缀展示 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
		net.raw_sent.connect(func(cmd):
			sent_commands.append(cmd)
			print("[Test] 捕获客户端发送命令: ", cmd)
		)
	
	var char_panel = hud.char_info_panel
	var tooltip = hud.item_tooltip
	
	# 打开角色信息面板
	char_panel.open()
	await get_tree().process_frame
	
	# -------------------------------------------------------------
	# 1. 验证 gscore 下发的全量词缀纸娃娃装备数据注入与渲染
	# -------------------------------------------------------------
	var esc = char(27)
	var test_gscore = {
		"level": 30,
		"hp": 500,
		"max_hp": 500,
		"stat_points": 5,
		"equips": {
			"armor": {
				"name": "督瑞尔的壳",
				"quality": "unique",
				"color": "#c7b377",
				"type": "Unique",
				"desc": esc + "[img:items/armor/armor/ancient_armor.lowend.png]\n督瑞尔的壳\n连衫铠\n防御: 580\n需要等级: 41\n需要力量: 65\n+160% 防御强化\n+1.25 生命/级\n无法冰冻\n抗冰 +50%",
				"file_id": "/d/d2/obj/armor#8888",
				"icon": "items/armor/armor/ancient_armor.lowend.png",
				"cmd": "look /d/d2/obj/armor#8888"
			},
			"main_hand": {
				"name": "水晶剑",
				"quality": "rare",
				"color": "#ffff00",
				"type": "Rare",
				"desc": esc + "[img:items/weapon/sword/short_sword.lowend.png]\n水晶剑\n单手伤害: 5 - 15\n需要力量: 43\n+30% 攻击速度\n+100% 伤害强化",
				"file_id": "/d/d2/obj/sword#9999",
				"icon": "items/weapon/sword/short_sword.lowend.png",
				"cmd": "look /d/d2/obj/sword#9999"
			}
		}
	}
	char_panel.render_gscore_data(test_gscore)
	await get_tree().process_frame
	
	var slot_armor = char_panel.slot_armor
	assert(slot_armor != null, "衣服槽位必须存在")
	assert(slot_armor.icon != null, "衣服槽位必须正常渲染装备图标")
	print(">>> 验证 1 通过：纸娃娃装备槽位成功加载服务端 gscore 装备数据与图标！")
	
	# -------------------------------------------------------------
	# 2. 验证纸娃娃槽位鼠标悬停，展示完整暗黑2属性 Tooltip 卡片
	# -------------------------------------------------------------
	# 模拟鼠标移动进入衣服槽位
	char_panel.item_hovered.emit(test_gscore["equips"]["armor"], slot_armor.global_position)
	await get_tree().process_frame
	
	assert(tooltip.visible == true, "鼠标悬停后 Tooltip 必须可见！")
	assert(tooltip.current_item_cmd == "look /d/d2/obj/armor#8888", "Tooltip 必须携带正确的 cmd 指令！")
	assert(sent_commands.has("look /d/d2/obj/armor#8888"), "Tooltip 弹出后应自动发送 look 指令向 LPC 请求更多详情！")
	
	var tip_text = tooltip.content_label.text
	print("[Test] 当前 Tooltip 富文本内容预览:\n", tip_text)
	
	# 断言：富文本中必须包含关键属性，不再只有名字！
	assert("防御: 580" in tip_text or "580" in tip_text, "Tooltip 必须包含防御数值！")
	assert("需要力量: 65" in tip_text or "65" in tip_text, "Tooltip 必须包含力量需求！")
	assert("无法冰冻" in tip_text, "Tooltip 必须包含暗黑2核心词缀【无法冰冻】！")
	assert(tooltip.item_icon.texture != null, "Tooltip 顶部装备大图必须成功解析并加载！")
	assert(tooltip.z_index >= 100, "Tooltip z_index 必须大于等于 100 以保证顶层渲染！")
	assert(tooltip.get_index() >= hud.get_child_count() - 1, "Tooltip 必须处于父容器的最顶层（最后一个兄弟节点）！")
	print(">>> 验证 2 通过：纸娃娃悬停 Tooltip 成功展示完整词缀、防御、需求与大图原画，且 z_index >= 100 置顶！")
	
	# -------------------------------------------------------------
	# 3. 验证 LPC 后端下发需求拦截信息时，前端 Toast 准确反馈
	# -------------------------------------------------------------
	var fail_str_text = "你的力量不足（需要力量 100 点，当前力量 25 点），拿不动重剑。\n"
	hud._on_network_text(fail_str_text)
	await get_tree().process_frame
	
	assert(hud._toast_label != null, "Toast Label 实例必须已创建！")
	assert(hud._toast_label.visible == true, "Toast 必须已激活显示！")
	assert("你的力量不足" in hud._toast_label.text, "Toast 文本必须呈现力量不足提示！")
	assert("拿不动重剑" in hud._toast_label.text, "Toast 文本必须呈现拿不动重剑提示！")
	print(">>> 验证 3 通过：服务端拦截力量不足提示通过 Toast 完美呈现！")
	
	# 模拟等级不足拦截
	var fail_lvl_text = "你的等级不足（需要等级 45 级，当前等级 30 级），无法装备圣堂法杖。\n"
	hud._on_network_text(fail_lvl_text)
	await get_tree().process_frame
	assert("你的等级不足" in hud._toast_label.text, "Toast 文本必须呈现等级不足提示！")
	print(">>> 验证 4 通过：服务端拦截等级不足提示通过 Toast 完美呈现！")
	
	# 模拟穿戴成功反馈
	var wear_ok_text = "你装备了督瑞尔的壳。\n"
	hud._on_network_text(wear_ok_text)
	await get_tree().process_frame
	assert("你装备了督瑞尔的壳" in hud._toast_label.text, "Toast 文本必须呈现装备成功提示！")
	print(">>> 验证 5 通过：服务端穿戴成功通知通过 Toast 完美呈现！")
	
	# -------------------------------------------------------------
	# 4. 截图并优雅退出
	# -------------------------------------------------------------
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_wear_req_and_paperdoll_tooltip.png")
	print("[Test] 走查截图已保存至 res://test_wear_req_and_paperdoll_tooltip.png")
	
	print("=== 全部 5 项穿戴需求校验与纸娃娃 Tooltip 核心验证 100% 通过！ ===")
	get_tree().quit(0)
