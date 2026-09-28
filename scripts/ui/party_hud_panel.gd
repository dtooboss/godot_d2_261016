extends Control
class_name PartyHudPanel

## 暗黑2战网风格野外战斗队伍状态面板 (Party HUD)
## 包含队伍成员状态、右侧横向Buff栏、队长解散/队员离队及卡片上下文交互

signal tell_requested(target_id: String)
signal team_dismiss_requested()

@onready var lbl_team_title: Label = %LblTeamTitle
@onready var btn_team_action: Button = %BtnTeamAction
@onready var member_list_vbox: VBoxContainer = %MemberListVBox

# 上下文菜单与确认弹窗
@onready var context_menu: PanelContainer = %ContextMenu
@onready var btn_menu_tell: Button = %BtnMenuTell
@onready var btn_menu_transfer: Button = %BtnMenuTransfer
@onready var btn_menu_kick: Button = %BtnMenuKick

@onready var confirm_dialog: Control = %ConfirmDialog
@onready var confirm_msg: Label = %ConfirmMsg
@onready var btn_confirm_ok: Button = %BtnConfirmOk
@onready var btn_confirm_cancel: Button = %BtnConfirmCancel

# 缓存已渲染的卡片节点: member_id -> Node
var member_cards: Dictionary = {}
var selected_member_id: String = ""
var selected_member_name: String = ""
var pending_confirm_action: String = "" # "dismiss" | "kick"

const AnsiHelperScript = preload("res://scripts/utils/ansi_helper.gd")

func _ready() -> void:
	visible = false
	if member_list_vbox:
		for child in member_list_vbox.get_children():
			child.queue_free()
			
	if btn_team_action:
		btn_team_action.pressed.connect(_on_team_action_pressed)
		
	# 菜单按钮绑定
	if btn_menu_tell:
		btn_menu_tell.pressed.connect(_on_menu_tell_pressed)
	if btn_menu_transfer:
		btn_menu_transfer.pressed.connect(_on_menu_transfer_pressed)
	if btn_menu_kick:
		btn_menu_kick.pressed.connect(_on_menu_kick_pressed)
		
	# 确认框绑定
	if btn_confirm_ok:
		btn_confirm_ok.pressed.connect(_on_confirm_ok_pressed)
	if btn_confirm_cancel:
		btn_confirm_cancel.pressed.connect(func(): confirm_dialog.visible = false)
		
	# 监听全局队伍更新
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node_or_null("/root/GameState")
		if gs:
			gs.team_updated.connect(update_party)
			if gs.is_in_team:
				update_party(gs.current_team_members)

## 刷新整支队伍状态
func update_party(members: Array) -> void:
	if members.size() <= 1:
		visible = false
		_clear_all_cards()
		if context_menu: context_menu.visible = false
		if confirm_dialog: confirm_dialog.visible = false
		return
		
	visible = true
	var current_ids = []
	
	# 刷新顶部队伍标题与行动按钮
	var is_leader = false
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node_or_null("/root/GameState")
		if gs: is_leader = gs.is_team_leader()
		
	if lbl_team_title:
		lbl_team_title.text = "❖ 队伍 (%d/5) ❖" % members.size()
	if btn_team_action:
		btn_team_action.text = "解散队伍" if is_leader else "离开队伍"
	
	for m in members:
		if not m is Dictionary: continue
		var mid = str(m.get("id", ""))
		if mid.is_empty(): continue
		current_ids.append(mid)
		
		if member_cards.has(mid):
			_update_card_data(member_cards[mid], m)
		else:
			var card = _create_member_card(m)
			member_list_vbox.add_child(card)
			member_cards[mid] = card
			
	# 移除已离队成员卡片
	var to_remove = []
	for mid in member_cards.keys():
		if not mid in current_ids:
			to_remove.append(mid)
	for mid in to_remove:
		if is_instance_valid(member_cards[mid]):
			member_cards[mid].queue_free()
		member_cards.erase(mid)

func _clear_all_cards() -> void:
	for mid in member_cards.keys():
		if is_instance_valid(member_cards[mid]):
			member_cards[mid].queue_free()
	member_cards.clear()

## 动态创建单个队员卡片
func _create_member_card(data: Dictionary) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 44)
	
	# 1. 卡片主体 (固定宽度 190, 高度 42)
	var card_body = PanelContainer.new()
	card_body.custom_minimum_size = Vector2(190, 42)
	card_body.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.075, 0.065, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	
	var is_leader = bool(data.get("is_leader", false))
	sb.border_color = Color(0.85, 0.7, 0.25, 0.95) if is_leader else Color(0.5, 0.4, 0.25, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 6
	sb.content_margin_top = 4
	sb.content_margin_right = 6
	sb.content_margin_bottom = 4
	card_body.add_theme_stylebox_override("panel", sb)
	row.add_child(card_body)
	
	# 点击卡片弹出上下文菜单
	var mid = str(data.get("id", ""))
	var mname = str(data.get("name", "队员"))
	card_body.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_context_menu(mid, mname, card_body.get_global_mouse_position())
	)
	
	var inner_h = HBoxContainer.new()
	inner_h.add_theme_constant_override("separation", 6)
	inner_h.alignment = BoxContainer.ALIGNMENT_CENTER
	card_body.add_child(inner_h)
	
	# 职业头像
	var avatar = TextureRect.new()
	avatar.custom_minimum_size = Vector2(30, 30)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cls = str(data.get("class", "sor")).to_lower()
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node_or_null("/root/GameState")
		if gs:
			avatar.texture = gs.get_class_icon(cls)
	inner_h.add_child(avatar)
	
	# 信息垂直列 (上名字/等级，下血条)
	var vcol = VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.add_theme_constant_override("separation", 2)
	inner_h.add_child(vcol)
	
	# 名字行
	var name_row = HBoxContainer.new()
	vcol.add_child(name_row)
	
	var lbl_name = Label.new()
	lbl_name.name = "NameLabel"
	var raw_name = str(data.get("name", "队员"))
	var clean_name = AnsiHelperScript.to_plain_text(raw_name).strip_edges()
	lbl_name.text = ("👑 " if is_leader else "") + clean_name
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_leader else Color(0.9, 0.9, 0.9))
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(lbl_name)
	
	var lvl = int(data.get("level", 1))
	var lbl_lvl = Label.new()
	lbl_lvl.name = "LevelLabel"
	lbl_lvl.text = "Lv.%d" % lvl
	lbl_lvl.add_theme_font_size_override("font_size", 10)
	lbl_lvl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	name_row.add_child(lbl_lvl)
	
	# 实时血条 (带居中数值文字: cur_hp / max_hp)
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(0, 11)
	hp_bar.show_percentage = false
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.18, 0.04, 0.04, 0.9)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_right = 2
	bg_style.corner_radius_bottom_left = 2
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.15, 0.15, 0.95)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_right = 2
	fill_style.corner_radius_bottom_left = 2
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	var cur_hp = int(data.get("hp", 100))
	var max_hp = int(data.get("max_hp", 100))
	if max_hp <= 0: max_hp = 1
	hp_bar.max_value = max_hp
	hp_bar.value = cur_hp

	var lbl_hp = Label.new()
	lbl_hp.name = "HpTextLabel"
	lbl_hp.text = "%d / %d" % [cur_hp, max_hp]
	lbl_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_hp.add_theme_font_size_override("font_size", 9)
	lbl_hp.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	lbl_hp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl_hp.add_theme_constant_override("outline_size", 2)
	hp_bar.add_child(lbl_hp)

	vcol.add_child(hp_bar)
	
	# 2. 右侧横向 Buff 小图标容器 (紧贴卡片右边缘横向排布，不改变垂直高度)
	var buff_container = HBoxContainer.new()
	buff_container.name = "BuffContainer"
	buff_container.add_theme_constant_override("separation", 3)
	buff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buff_container)
	
	_render_buff_icons(buff_container, data.get("buffs", []))
	
	return row

## 更新单个卡片的数据
func _update_card_data(card_node: Control, data: Dictionary) -> void:
	if not is_instance_valid(card_node): return
	
	var hp_bar = card_node.find_child("HpBar", true, false)
	if hp_bar is ProgressBar:
		var cur_hp = int(data.get("hp", 100))
		var max_hp = int(data.get("max_hp", 100))
		if max_hp <= 0: max_hp = 1
		hp_bar.max_value = max_hp
		hp_bar.value = cur_hp
		var lbl_hp = hp_bar.find_child("HpTextLabel", true, false)
		if lbl_hp is Label:
			lbl_hp.text = "%d / %d" % [cur_hp, max_hp]
		
	var buff_container = card_node.find_child("BuffContainer", true, false)
	if buff_container is HBoxContainer:
		_render_buff_icons(buff_container, data.get("buffs", []))

## 渲染右侧横向 Buff 小图标
func _render_buff_icons(container: HBoxContainer, buffs: Array) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
		
	for b in buffs:
		var b_name = str(b)
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 默认光环/增益小徽章
		icon_rect.tooltip_text = "光环增益: " + b_name
		container.add_child(icon_rect)

## 弹出上下文菜单
func _show_context_menu(mid: String, mname: String, global_pos: Vector2) -> void:
	selected_member_id = mid
	selected_member_name = mname
	
	var my_id = ""
	var is_leader = false
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node_or_null("/root/GameState")
		if gs:
			if gs.has_method("get_my_character_id"):
				my_id = gs.get_my_character_id()
			else:
				my_id = str(gs.selected_character.get("id", gs.selected_character.get("char_id", "")))
			is_leader = gs.is_team_leader()
			
	var is_self = (mid == my_id)
	
	if is_self:
		# 点击自己卡片：触发离队/解散确认
		_on_team_action_pressed()
		return
		
	# 点击其他队员卡片
	if btn_menu_transfer:
		btn_menu_transfer.visible = is_leader
	if btn_menu_kick:
		btn_menu_kick.visible = is_leader
		
	if context_menu:
		var local_pos = get_global_transform().affine_inverse() * global_pos
		context_menu.position = local_pos + Vector2(10, 0)
		context_menu.visible = true

func _on_menu_tell_pressed() -> void:
	if context_menu: context_menu.visible = false
	if not selected_member_id.is_empty():
		tell_requested.emit(selected_member_id)

func _on_menu_transfer_pressed() -> void:
	if context_menu: context_menu.visible = false
	if not selected_member_id.is_empty():
		if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
			var net = get_node_or_null("/root/NetworkClient")
			if net and net.is_connected:
				net.send_raw("team cleader " + selected_member_id)

func _on_menu_kick_pressed() -> void:
	if context_menu: context_menu.visible = false
	if not selected_member_id.is_empty():
		pending_confirm_action = "kick"
		if confirm_msg:
			confirm_msg.text = "确定要将队员【%s】移出队伍吗？" % selected_member_name
		if confirm_dialog:
			confirm_dialog.visible = true

func _on_team_action_pressed() -> void:
	if context_menu: context_menu.visible = false
	var is_leader = false
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node_or_null("/root/GameState")
		if gs: is_leader = gs.is_team_leader()
		
	pending_confirm_action = "dismiss"
	if confirm_msg:
		confirm_msg.text = "确定要解散整支队伍吗？" if is_leader else "确定要脱离当前队伍吗？"
	if confirm_dialog:
		confirm_dialog.visible = true

func _on_confirm_ok_pressed() -> void:
	if confirm_dialog: confirm_dialog.visible = false
	
	if pending_confirm_action == "dismiss":
		team_dismiss_requested.emit()
		if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
			var net = get_node_or_null("/root/NetworkClient")
			if net and net.is_connected:
				net.send_raw("team dismiss")
	elif pending_confirm_action == "kick":
		if not selected_member_id.is_empty():
			if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
				var net = get_node_or_null("/root/NetworkClient")
				if net and net.is_connected:
					net.send_raw("team dismiss " + selected_member_id)
					
	pending_confirm_action = ""

func _unhandled_input(event: InputEvent) -> void:
	if context_menu and context_menu.visible and event is InputEventMouseButton and event.pressed:
		context_menu.visible = false
