extends Control

## 罗格营地 (Rogue Encampment) 主城大厅总控制器
## 负责管理 Act 1 安全区公共大厅交互、NPC服务对话、组队系统以及出征战斗切换

# 顶部玩家信息
@onready var lbl_room_title: Label = $TopBar/HBox/RoomTitleLabel
@onready var lbl_char_name: Label = $TopBar/HBox/CharInfoBox/CharNameLabel
@onready var lbl_char_class: Label = $TopBar/HBox/CharInfoBox/CharClassLabel
@onready var lbl_hp: Label = $TopBar/HBox/ResourceBox/HpLabel
@onready var lbl_mp: Label = $TopBar/HBox/ResourceBox/MpLabel
@onready var lbl_gold: Label = $TopBar/HBox/ResourceBox/GoldLabel
@onready var avatar_icon: TextureRect = $TopBar/HBox/AvatarRect

# 营地 NPC 与设施按钮
@onready var btn_akara: Button = $CenterHub/NpcGrid/BtnAkara
@onready var btn_charsi: Button = $CenterHub/NpcGrid/BtnCharsi
@onready var btn_gheed: Button = $CenterHub/NpcGrid/BtnGheed
@onready var btn_kashya: Button = $CenterHub/NpcGrid/BtnKashya
@onready var btn_stash: Button = $CenterHub/NpcGrid/BtnStash
@onready var btn_waypoint: Button = $CenterHub/NpcGrid/BtnWaypoint

# 底部出征与系统操作
@onready var btn_go_blood_moor: Button = $BottomBar/HBox/BtnGoBloodMoor
@onready var btn_party: Button = $BottomBar/HBox/BtnParty
@onready var btn_bag: Button = $BottomBar/HBox/BtnBag

# 社交与组队弹窗/侧边栏
@onready var player_list_box: VBoxContainer = $RightSidebar/VBox/Scroll/PlayerList
@onready var chat_log: RichTextLabel = $ChatPanel/ChatLog
@onready var chat_input: LineEdit = $ChatPanel/HBox/ChatInput
@onready var toast_label: Label = $ToastLabel

var current_room_name: String = "罗格营地"
var current_hp: int = 100
var max_hp: int = 100
var current_mp: int = 50
var max_mp: int = 50
var gold_amount: int = 0

func _ready() -> void:
	_init_player_ui()
	_connect_signals()
	
	# 向服务端发送 look 刷新当前营地全貌与 NPC 列表
	NetworkClient.send_raw("look")
	_show_toast("已安全抵达【游侠营地】大本营！")

func _init_player_ui() -> void:
	var cdata = GameState.selected_character
	if not cdata.is_empty():
		var cname = str(cdata.get("name", "英雄"))
		var cls = str(cdata.get("class", "sor"))
		var cls_name = str(cdata.get("class_name", GameState.get_class_display_name(cls)))
		var level = int(cdata.get("level", 1))
		
		lbl_char_name.text = cname
		lbl_char_class.text = "Lv.%d %s" % [level, cls_name]
		avatar_icon.texture = GameState.get_class_icon(cls)
		
		max_hp = int(cdata.get("life", 100))
		current_hp = max_hp
		max_mp = int(cdata.get("mana", 50))
		current_mp = max_mp
		_update_vitals()

func _connect_signals() -> void:
	# NPC 与设施交互
	btn_akara.pressed.connect(func(): _interact_npc("akara", "阿卡拉修女"))
	btn_charsi.pressed.connect(func(): _interact_npc("charsi", "铁匠恰西"))
	btn_gheed.pressed.connect(func(): _interact_npc("gheed", "基德赌博摊"))
	btn_kashya.pressed.connect(func(): _interact_npc("kashya", "卡夏雇佣兵营"))
	btn_stash.pressed.connect(func(): _open_stash())
	btn_waypoint.pressed.connect(func(): _open_waypoint())
	
	# 出征鲜血荒地
	btn_go_blood_moor.pressed.connect(_on_leave_town_pressed)
	
	# 组队与背包
	btn_party.pressed.connect(_on_party_btn_pressed)
	btn_bag.pressed.connect(func(): NetworkClient.send_raw("inv"))
	
	# 聊天输入
	chat_input.text_submitted.connect(_on_chat_submitted)
	
	# 监听 LPC 协议下发
	NetworkClient.json_frame_received.connect(_on_json_frame_received)
	NetworkClient.text_received.connect(_on_text_received)

func _update_vitals() -> void:
	lbl_hp.text = "❤ 生命: %d / %d" % [current_hp, max_hp]
	lbl_mp.text = "✦ 法力: %d / %d" % [current_mp, max_mp]
	lbl_gold.text = "🪙 金币: %d" % gold_amount

## NPC 交互对话
func _interact_npc(npc_id: String, npc_name: String) -> void:
	_append_chat("[color=#f59e0b]【系统】[/color] 正在与 [color=#60a5fa]%s[/color] 交谈..." % npc_name)
	# 发送 look <npc_id> 触发 LPC 的 J_PANEL / J_ACTIONS 交互菜单
	NetworkClient.send_raw("look " + npc_id)

func _open_stash() -> void:
	_append_chat("[color=#f59e0b]【系统】[/color] 打开赫拉迪姆大储物箱...")
	NetworkClient.send_raw("open stash")

func _open_waypoint() -> void:
	_append_chat("[color=#f59e0b]【系统】[/color] 激活石制传送小站 (Waypoint)...")
	NetworkClient.send_raw("waypoint")

## 出城进入战斗
func _on_leave_town_pressed() -> void:
	_append_chat("[color=#ef4444]【出征】[/color] 穿过栅栏大门，向 [color=#fbbf24]鲜血荒地[/color] 进发！")
	NetworkClient.send_raw("north")

## 组队指令
func _on_party_btn_pressed() -> void:
	_append_chat("[color=#38bdf8]【组队】[/color] 正在查询当前队伍信息...")
	NetworkClient.send_raw("team")

## 聊天输入
func _on_chat_submitted(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	chat_input.clear()
	# 发送聊天指令
	NetworkClient.send_raw("chat " + text)

## 处理服务端 JSON 数据包
func _on_json_frame_received(type: String, data: Variant) -> void:
	# 1. 房间标题 (如切换地图)
	if type == "title":
		current_room_name = str(data)
		lbl_room_title.text = "【 %s 】" % current_room_name
		_append_chat("[color=#22c55e]【场景切换】[/color] 进入了 %s" % current_room_name)
		
	# 2. 房间对象/NPC/玩家列表
	elif type == "objects":
		if data is Array:
			_update_room_objects(data)
			
	# 3. 角色状态同步 (HP/MP)
	elif type == "status" or type == "charhp":
		if data is Dictionary:
			if data.has("qi"): current_hp = int(data["qi"])
			if data.has("max_qi"): max_hp = int(data["max_qi"])
			if data.has("jing"): current_mp = int(data["jing"])
			if data.has("max_jing"): max_mp = int(data["max_jing"])
			if data.has("gold"): gold_amount = int(data["gold"])
			_update_vitals()
			
	# 4. 交互面板 (J_PANEL / J_ACTIONS)
	elif type == "panel" or type == "actions":
		_handle_interactive_panel(data)

## 更新营地内的在线玩家与NPC列表
func _update_room_objects(objects_list: Array) -> void:
	for child in player_list_box.get_children():
		child.queue_free()
		
	for obj in objects_list:
		if not obj is Dictionary: continue
		var oname = str(obj.get("name", ""))
		var ocmd = str(obj.get("cmd", ""))
		var rank = str(obj.get("rank", "normal"))
		
		# 过滤出其他在线玩家并创建可交互条目
		var btn = Button.new()
		btn.text = oname.replace("\u001b", "") # 简易去色码
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(func(): NetworkClient.send_raw(ocmd))
		player_list_box.add_child(btn)

func _handle_interactive_panel(data: Variant) -> void:
	if data is Dictionary:
		var desc = str(data.get("desc", ""))
		if not desc.is_empty():
			_append_chat("[color=#e2e8f0]" + desc.replace("\n", " ") + "[/color]")

## 处理文本输出
func _on_text_received(text: String) -> void:
	_append_chat(text)

func _append_chat(msg: String) -> void:
	chat_log.append_text(msg.strip_edges(false, true) + "\n")

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	var tween = create_tween()
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.5)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): toast_label.visible = false)
