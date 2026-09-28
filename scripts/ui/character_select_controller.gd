extends Control

## 角色选择大厅控制器 (CharacterSelectController)
## 管理英雄列表切换、详细四维与属性展示、难度选择及进入游戏指令发送

const CARD_SCENE = preload("res://scenes/lobby/character_card.tscn")

@onready var card_container: VBoxContainer = $MainLayout/RightPanel/Scroll/CardList
@onready var detail_avatar: TextureRect = $MainLayout/LeftPanel/DetailBox/VBox/HeaderBox/BigAvatar
@onready var detail_name: Label = $MainLayout/LeftPanel/DetailBox/VBox/HeaderBox/VBox/DetailName
@onready var detail_class_level: Label = $MainLayout/LeftPanel/DetailBox/VBox/HeaderBox/VBox/DetailClassLevel

# 四维属性与状态
@onready var stat_life: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValLife
@onready var stat_mana: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValMana
@onready var stat_str: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValStr
@onready var stat_dex: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValDex
@onready var stat_vit: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValVit
@onready var stat_int: Label = $MainLayout/LeftPanel/DetailBox/VBox/StatsGrid/ValInt

# 难度单选按钮
@onready var diff_normal: CheckBox = $MainLayout/LeftPanel/DiffContainer/HBox/DiffNormal
@onready var diff_nm: CheckBox = $MainLayout/LeftPanel/DiffContainer/HBox/DiffNightmare
@onready var diff_hell: CheckBox = $MainLayout/LeftPanel/DiffContainer/HBox/DiffHell

# 按钮控制
@onready var btn_enter_game: Button = $BottomBar/HBox/BtnEnterGame
@onready var btn_back: Button = $BottomBar/HBox/BtnBack
@onready var status_label: Label = $BottomBar/StatusLabel

var current_selected_char: Dictionary = {}
var card_instances: Array = []

func _ready() -> void:
	# 难度按钮互斥绑定
	diff_normal.pressed.connect(func(): _set_difficulty("normal"))
	diff_nm.pressed.connect(func(): _set_difficulty("nightmare"))
	diff_hell.pressed.connect(func(): _set_difficulty("hell"))
	
	btn_enter_game.pressed.connect(_on_enter_game_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# 监听服务器断开与消息
	NetworkClient.disconnected_from_server.connect(_on_disconnected)
	NetworkClient.text_received.connect(_on_text_received)
	NetworkClient.json_frame_received.connect(_on_json_frame_received)
	
	_populate_character_list()

func _populate_character_list() -> void:
	# 清空旧卡片
	for child in card_container.get_children():
		child.queue_free()
	card_instances.clear()
	
	var chars = GameState.character_list
	if chars.is_empty():
		status_label.text = "暂无角色，请点击创建新英雄"
		return
		
	for i in range(chars.size()):
		var cdata = chars[i]
		var card = CARD_SCENE.instantiate()
		card_container.add_child(card)
		card_instances.append(card)
		
		var is_first = (i == 0)
		card.setup(cdata, is_first)
		card.card_selected.connect(_on_card_selected)
		
	# 默认选中第一个
	_select_character(chars[0])

func _on_card_selected(cdata: Dictionary) -> void:
	_select_character(cdata)

func _select_character(cdata: Dictionary) -> void:
	if not cdata.has("id") and cdata.has("char_id"):
		cdata["id"] = cdata["char_id"]
	current_selected_char = cdata
	GameState.selected_character = cdata
	
	# 更新列表卡片高亮
	var target_id = str(cdata.get("char_id", ""))
	for card in card_instances:
		var is_target = (str(card.character_data.get("char_id", "")) == target_id)
		card.set_selected(is_target)
		
	# 刷新左侧面板详细信息
	var char_name = str(cdata.get("name", "未命名"))
	var cls = str(cdata.get("class", "sor"))
	var cls_display = str(cdata.get("class_name", GameState.get_class_display_name(cls)))
	var level = int(cdata.get("level", 1))
	
	detail_name.text = char_name
	detail_class_level.text = "Lv.%d %s" % [level, cls_display]
	detail_avatar.texture = GameState.get_class_icon(cls)
	
	stat_life.text = str(int(cdata.get("life", 50)))
	stat_mana.text = str(int(cdata.get("mana", 20)))
	stat_str.text = str(int(cdata.get("str", 10)))
	stat_dex.text = str(int(cdata.get("dex", 10)))
	stat_vit.text = str(int(cdata.get("vit", 10)))
	stat_int.text = str(int(cdata.get("int", 10)))
	
	# 难度解锁判定 (unlocked_diff: 1=普通, 2=噩梦, 3=地狱)
	var unlocked = int(cdata.get("unlocked_diff", 1))
	diff_normal.disabled = false
	diff_nm.disabled = (unlocked < 2)
	diff_hell.disabled = (unlocked < 3)
	
	# 默认选普通
	_set_difficulty("normal")
	status_label.text = "已选定英雄: %s (%s)" % [char_name, cls_display]

func _set_difficulty(diff: String) -> void:
	GameState.selected_difficulty = diff
	diff_normal.button_pressed = (diff == "normal")
	diff_nm.button_pressed = (diff == "nightmare" or diff == "nm")
	diff_hell.button_pressed = (diff == "hell")

func _on_enter_game_pressed() -> void:
	if current_selected_char.is_empty():
		status_label.text = "请先选择一个角色！"
		return
		
	var char_id = str(current_selected_char.get("char_id", ""))
	var diff = GameState.selected_difficulty
	
	status_label.text = "正在进入庇护之地主城大本营..."
	btn_enter_game.disabled = true
	
	# 发送暗黑2标准选角进入指令: select_char <char_id> <diff>
	var cmd = "select_char %s %s" % [char_id, diff]
	print("[CharacterSelect] 发送进入游戏指令: ", cmd)
	NetworkClient.send_raw(cmd)

var has_entered_world: bool = false

func _on_json_frame_received(type: String, data: Variant) -> void:
	print("[CharacterSelect] 收到服务端世界数据包: type=", type)
	# 收到进入世界的数据帧 (login_ok / status / title / objects) 立即切入主城安全区
	if not has_entered_world:
		if type == "login_ok" or type == "status" or type == "title" or type == "objects" or type == "room":
			_enter_town_hub()

func _on_text_received(text: String) -> void:
	if not has_entered_world and ("加载世界" in text or "营地" in text or "荒地" in text or "鲁高因" in text or "海港" in text or "堡垒" in text or "哈洛加斯" in text):
		_enter_town_hub()

func _enter_town_hub() -> void:
	has_entered_world = true
	status_label.text = "成功进入世界！正在载入主城安全大本营..."
	print("[CharacterSelect] 正在切换至主城安全大本营: res://scenes/town/town_hub.tscn")
	get_tree().change_scene_to_file("res://scenes/town/town_hub.tscn")

func _on_disconnected() -> void:
	status_label.text = "与服务器的连接断开，正在返回登录界面..."
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/login/login_screen.tscn")

func _on_back_pressed() -> void:
	NetworkClient.disconnect_server()
	get_tree().change_scene_to_file("res://scenes/login/login_screen.tscn")
