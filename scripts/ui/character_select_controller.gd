extends Control

## 角色选择大厅控制器 (CharacterSelectController)
## 管理英雄列表切换、详细四维与属性展示、难度选择、创建新英雄、注销英雄及进入游戏指令发送

const CARD_SCENE = preload("res://scenes/lobby/character_card.tscn")

@onready var card_container: VBoxContainer = $MainLayout/RightPanel/RightVBox/Scroll/CardList
@onready var btn_create_char: Button = %BtnCreateChar

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

# 底部按钮控制
@onready var btn_enter_game: Button = $BottomBar/HBox/BtnEnterGame
@onready var btn_delete_char: Button = %BtnDeleteChar
@onready var btn_back: Button = $BottomBar/HBox/BtnBack
@onready var status_label: Label = $BottomBar/StatusLabel

# 创建英雄模态弹窗相关节点
@onready var create_char_modal: Control = %CreateCharacterModal
@onready var class_grid: HBoxContainer = %ClassGrid
@onready var gender_male: CheckBox = %GenderMale
@onready var gender_female: CheckBox = %GenderFemale
@onready var char_name_input: LineEdit = %CharNameInput
@onready var modal_error_label: Label = %ModalErrorLabel
@onready var btn_confirm_create: Button = %BtnConfirmCreate
@onready var btn_cancel_create: Button = %BtnCancelCreate

# 删除角色确认模态弹窗相关节点
@onready var delete_char_modal: Control = %DeleteCharModal
@onready var delete_msg_label: Label = %DeleteMsgLabel
@onready var btn_confirm_delete: Button = %BtnConfirmDelete
@onready var btn_cancel_delete: Button = %BtnCancelDelete

const HERO_CLASSES = ["ama", "asn", "nec", "bar", "pal", "sor", "dru"]
const FEMALE_CLASSES = ["ama", "asn", "sor"]

var current_selected_char: Dictionary = {}
var card_instances: Array = []
var selected_create_class: String = "sor"
var selected_create_gender: String = "女性"
var class_buttons_map: Dictionary = {}

func _ready() -> void:
	# 难度按钮互斥绑定
	diff_normal.pressed.connect(func(): _set_difficulty("normal"))
	diff_nm.pressed.connect(func(): _set_difficulty("nm"))
	diff_hell.pressed.connect(func(): _set_difficulty("hell"))
	
	btn_enter_game.pressed.connect(_on_enter_game_pressed)
	btn_delete_char.pressed.connect(_open_delete_modal)
	btn_back.pressed.connect(_on_back_pressed)
	btn_create_char.pressed.connect(_open_create_modal)

	# 创建与删除弹窗初始化
	_init_create_character_modal()
	_init_delete_character_modal()
	
	# 双向监听服务器角色大厅广播与消息
	NetworkClient.disconnected_from_server.connect(_on_disconnected)
	NetworkClient.text_received.connect(_on_text_received)
	NetworkClient.json_frame_received.connect(_on_json_frame_received)
	NetworkClient.login_success.connect(_on_character_list_updated)
	
	_populate_character_list()

func _populate_character_list() -> void:
	# 清空旧卡片
	for child in card_container.get_children():
		child.queue_free()
	card_instances.clear()
	
	var chars = GameState.character_list
	if chars.is_empty():
		status_label.text = "暂无角色，请点击上方【+ 创建新英雄】开启庇护之地征途"
		btn_enter_game.disabled = true
		btn_delete_char.disabled = true
		detail_name.text = "暂无英雄"
		detail_class_level.text = "请先创建英雄"
		stat_life.text = "0"
		stat_mana.text = "0"
		stat_str.text = "0"
		stat_dex.text = "0"
		stat_vit.text = "0"
		stat_int.text = "0"
		return
		
	btn_enter_game.disabled = false
	btn_delete_char.disabled = false
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
	var level = AnsiHelper.to_safe_int(cdata.get("level"), 1)
	
	detail_name.text = char_name
	detail_class_level.text = "Lv.%d %s" % [level, cls_display]
	detail_avatar.texture = GameState.get_class_icon(cls)
	
	stat_life.text = str(AnsiHelper.to_safe_int(cdata.get("life"), 50))
	stat_mana.text = str(AnsiHelper.to_safe_int(cdata.get("mana"), 20))
	stat_str.text = str(AnsiHelper.to_safe_int(cdata.get("str"), 10))
	stat_dex.text = str(AnsiHelper.to_safe_int(cdata.get("dex"), 10))
	stat_vit.text = str(AnsiHelper.to_safe_int(cdata.get("vit"), 10))
	stat_int.text = str(AnsiHelper.to_safe_int(cdata.get("int"), 10))
	
	# 难度解锁判定 (unlocked_diff: 1=普通, 2=噩梦, 3=地狱)
	var unlocked = AnsiHelper.to_safe_int(cdata.get("unlocked_diff"), 1)
	diff_normal.disabled = false
	diff_nm.disabled = (unlocked < 2)
	diff_hell.disabled = (unlocked < 3)
	
	# 智能选择难度：若角色历史是噩梦/地狱且已解锁，则优先选中，否则选普通
	var default_diff = str(cdata.get("difficulty", "normal")).to_lower()
	if (default_diff == "nm" or default_diff == "nightmare" or default_diff == "噩梦") and unlocked >= 2:
		_set_difficulty("nm")
	elif (default_diff == "hell" or default_diff == "地狱") and unlocked >= 3:
		_set_difficulty("hell")
	else:
		_set_difficulty("normal")
	status_label.text = "已选定英雄: %s (%s)" % [char_name, cls_display]

func _set_difficulty(diff: String) -> void:
	if diff == "nightmare": diff = "nm"
	GameState.selected_difficulty = diff
	diff_normal.button_pressed = (diff == "normal")
	diff_nm.button_pressed = (diff == "nm")
	diff_hell.button_pressed = (diff == "hell")

func _on_enter_game_pressed() -> void:
	if current_selected_char.is_empty():
		status_label.text = "请先选择一个角色！"
		return
		
	var char_id = str(current_selected_char.get("char_id", ""))
	var diff = GameState.selected_difficulty
	if diff.is_empty(): diff = "normal"
	current_selected_char["difficulty"] = diff
	if GameState.selected_character is Dictionary:
		GameState.selected_character["difficulty"] = diff
	
	status_label.text = "正在进入庇护之地主城大本营..."
	btn_enter_game.disabled = true
	
	# 发送暗黑2标准选角进入指令: select_char <char_id> <diff>
	var cmd = "select_char %s %s" % [char_id, diff]
	print("[CharacterSelect] 发送进入游戏指令: ", cmd)
	NetworkClient.send_raw(cmd)

# ----------------------------------------------------
# 角色列表同步与全局刷新
# ----------------------------------------------------
func _on_character_list_updated(chars: Array) -> void:
	GameState.character_list = chars
	_close_create_modal()
	_close_delete_modal()
	_populate_character_list()
	if not chars.is_empty():
		_select_character(chars[chars.size() - 1])
	status_label.text = "英雄大厅已更新！请选择英雄出征！"

# ----------------------------------------------------
# 创建新英雄交互系统
# ----------------------------------------------------
func _init_create_character_modal() -> void:
	btn_cancel_create.pressed.connect(_close_create_modal)
	btn_confirm_create.pressed.connect(_on_confirm_create_pressed)
	char_name_input.text_submitted.connect(func(_text): _on_confirm_create_pressed())
	
	gender_male.pressed.connect(func():
		selected_create_gender = "男性"
		gender_male.button_pressed = true
		gender_female.button_pressed = false
	)
	gender_female.pressed.connect(func():
		selected_create_gender = "女性"
		gender_male.button_pressed = false
		gender_female.button_pressed = true
	)
	
	# 动态构建 7 大职业按钮
	for child in class_grid.get_children():
		child.queue_free()
	class_buttons_map.clear()
	
	for cls in HERO_CLASSES:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(74, 90)
		btn.toggle_mode = true
		
		var vbox = VBoxContainer.new()
		vbox.anchors_preset = Control.PRESET_FULL_RECT
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(46, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = GameState.get_class_icon(cls)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)
		
		var lbl = Label.new()
		lbl.text = GameState.get_class_display_name(cls)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)
		
		btn.add_child(vbox)
		btn.pressed.connect(func(): _select_create_class(cls))
		class_grid.add_child(btn)
		class_buttons_map[cls] = btn
		
	_select_create_class("sor")

func _select_create_class(cls: String) -> void:
	selected_create_class = cls
	for c_key in class_buttons_map:
		var b: Button = class_buttons_map[c_key]
		b.button_pressed = (c_key == cls)
		if c_key == cls:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			b.remove_theme_color_override("font_color")
			
	# 根据职业设置默认性别
	if cls in FEMALE_CLASSES:
		selected_create_gender = "女性"
		gender_male.button_pressed = false
		gender_female.button_pressed = true
	else:
		selected_create_gender = "男性"
		gender_male.button_pressed = true
		gender_female.button_pressed = false

func _open_create_modal() -> void:
	modal_error_label.text = ""
	char_name_input.text = ""
	btn_confirm_create.disabled = false
	create_char_modal.visible = true
	char_name_input.grab_focus()

func _close_create_modal() -> void:
	create_char_modal.visible = false

func _on_confirm_create_pressed() -> void:
	modal_error_label.text = ""
	var c_name = char_name_input.text.strip_edges()
	if c_name.is_empty():
		modal_error_label.text = "请输入角色姓名"
		char_name_input.grab_focus()
		return
		
	if c_name.length() < 2 or c_name.length() > 4:
		modal_error_label.text = "角色名长度需在 2 到 4 个汉字之间"
		char_name_input.grab_focus()
		return
		
	# 校验是否全为合法中文字符
	var regex = RegEx.new()
	regex.compile("^[\\x{4e00}-\\x{9fa5}]+$")
	if not regex.search(c_name):
		modal_error_label.text = "角色名字只能包含中文汉字"
		char_name_input.grab_focus()
		return

	btn_confirm_create.disabled = true
	modal_error_label.text = "正在为英雄赐名并构建命运..."

	var cmd = "create_char %s║%s║%s" % [selected_create_class, selected_create_gender, c_name]
	print("[CharacterSelect] 发送创建角色指令: ", cmd)
	NetworkClient.send_raw(cmd)

	# 超时兜底保护
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(self) and create_char_modal.visible and btn_confirm_create.disabled:
			btn_confirm_create.disabled = false
			modal_error_label.text = "响应超时，请重试或更换名称"
	)

# ----------------------------------------------------
# 注销删除英雄交互系统
# ----------------------------------------------------
func _init_delete_character_modal() -> void:
	btn_cancel_delete.pressed.connect(_close_delete_modal)
	btn_confirm_delete.pressed.connect(_on_confirm_delete_pressed)

func _open_delete_modal() -> void:
	if current_selected_char.is_empty():
		status_label.text = "请先选择要注销的英雄"
		return
		
	var c_name = str(current_selected_char.get("name", "该角色"))
	var c_cls = str(current_selected_char.get("class_name", "英雄"))
	var c_lvl = AnsiHelper.to_safe_int(current_selected_char.get("level"), 1)
	
	delete_msg_label.text = "确定要永久注销英雄【%s (Lv.%d %s)】吗？\n此操作将彻底删除角色及其随身物品，无法撤销！" % [c_name, c_lvl, c_cls]
	btn_confirm_delete.disabled = false
	delete_char_modal.visible = true

func _close_delete_modal() -> void:
	delete_char_modal.visible = false

func _on_confirm_delete_pressed() -> void:
	if current_selected_char.is_empty():
		_close_delete_modal()
		return
		
	var char_id = str(current_selected_char.get("char_id", ""))
	if char_id.is_empty():
		_close_delete_modal()
		return
		
	btn_confirm_delete.disabled = true
	status_label.text = "正在注销英雄并清理存档..."
	
	var cmd = "delete_char %s" % char_id
	print("[CharacterSelect] 发送删除角色指令: ", cmd)
	NetworkClient.send_raw(cmd)
	
	# 超时兜底保护
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(self) and delete_char_modal.visible and btn_confirm_delete.disabled:
			btn_confirm_delete.disabled = false
			status_label.text = "删除请求超时，请检查网络"
	)

# ----------------------------------------------------
# 协议帧监听
# ----------------------------------------------------
var has_entered_world: bool = false

func _on_json_frame_received(type: String, data: Variant) -> void:
	print("[CharacterSelect] 收到服务端数据包: type=", type)
	# 1. 收到角色列表刷新（登录成功、创建新角色成功或删除成功）
	if (type == "character_list" or type == "characters") and data is Dictionary:
		var chars = data.get("characters", data.get("character_list", []))
		if chars is Array:
			_on_character_list_updated(chars)
			return

	# 2. 收到创建或选角错误反馈
	if type == "error" and data is Dictionary:
		var err_msg = str(data.get("msg", "操作失败"))
		if create_char_modal and create_char_modal.visible:
			modal_error_label.text = err_msg
			btn_confirm_create.disabled = false
		elif delete_char_modal and delete_char_modal.visible:
			delete_msg_label.text = "注销失败: " + err_msg
			btn_confirm_delete.disabled = false
		else:
			status_label.text = "错误: " + err_msg
			btn_enter_game.disabled = false
		return

	# 3. 收到选角成功进入世界
	if type == "login_ok" and data is Dictionary:
		if data.has("difficulty"):
			var serv_diff = str(data["difficulty"]).to_lower()
			if serv_diff == "nightmare": serv_diff = "nm"
			GameState.selected_difficulty = serv_diff
			if GameState.selected_character is Dictionary:
				GameState.selected_character["difficulty"] = serv_diff
				
	# 收到进入世界的数据帧 (login_ok / status / title / objects / room) 立即切入主城安全区
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
	if NetworkClient.is_reconnecting:
		status_label.text = "网络连接中断，正在尝试重新连接..."
	else:
		status_label.text = "与服务器的连接断开，正在返回登录界面..."
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/login/login_screen.tscn")

func _on_back_pressed() -> void:
	NetworkClient.disconnect_server(true)
	get_tree().change_scene_to_file("res://scenes/login/login_screen.tscn")
