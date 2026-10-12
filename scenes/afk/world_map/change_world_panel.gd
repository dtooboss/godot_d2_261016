extends Control
class_name AFK_ChangeWorldPanel

signal world_selected(world_id, world_name)
signal closed()

@onready var btn_close: Button = %BtnClose
@onready var cards_container: VBoxContainer = %CardsContainer

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(func(): 
			hide()
			closed.emit()
		)
	visibility_changed.connect(_on_visibility_changed)
	refresh_cards()

func _on_visibility_changed() -> void:
	if visible:
		if NetworkClient.is_connected:
			NetworkClient.send_raw("stage")
		refresh_cards()

## 根据后端权威下发的大幕解锁状态动态渲染大幕卡片 (纯渲染架构)
func refresh_cards() -> void:
	if not cards_container: return
	for child in cards_container.get_children():
		child.queue_free()
	
	var p_max_stage = GameState.player_max_stage if "player_max_stage" in GameState else 0
	
	var worlds_config = [
		{
			"id": "act1",
			"name": "第一幕：罗格营地",
			"req_lvl": 1,
			"req_stage": 0,
			"req_desc": "",
			"bg": "res://mods/vanilla/assets/worlds/1/map.png"
		},
		{
			"id": "act2",
			"name": "第二幕：鲁高因",
			"req_lvl": 14,
			"req_stage": 14,
			"req_desc": "通关地下墓穴第四层(安达莉尔)",
			"bg": "res://mods/vanilla/assets/worlds/2/map.png"
		},
		{
			"id": "act3",
			"name": "第三幕：库拉斯特海港",
			"req_lvl": 21,
			"req_stage": 34,
			"req_desc": "通关督瑞尔巢穴(都瑞尔)",
			"bg": "res://mods/vanilla/assets/worlds/3/map.png"
		},
		{
			"id": "act4",
			"name": "第四幕：群魔堡垒",
			"req_lvl": 26,
			"req_stage": 56,
			"req_desc": "通关憎恨王座(墨菲斯托)",
			"bg": "res://mods/vanilla/assets/worlds/4/map.png"
		},
		{
			"id": "act5",
			"name": "第五幕：哈洛加斯",
			"req_lvl": 30,
			"req_stage": 64,
			"req_desc": "通关混沌避难所(迪亚波罗)",
			"bg": "res://mods/vanilla/assets/worlds/5/map.png"
		}
	]
	
	# 后端已下发权威大幕状态映射
	var server_worlds_map = {}
	if GameState.unlocked_worlds is Array and not GameState.unlocked_worlds.is_empty():
		for sw in GameState.unlocked_worlds:
			if sw is Dictionary and sw.has("id"):
				server_worlds_map[str(sw["id"])] = sw

	for w in worlds_config:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 110)
		
		# 权威解锁判定：优先信任后端下发的 unlocked 标志；若无缓存则按通关关卡保底
		var is_unlocked = false
		var wid = str(w["id"])
		if server_worlds_map.has(wid):
			var s_data = server_worlds_map[wid]
			is_unlocked = bool(s_data.get("unlocked", 0))
		else:
			is_unlocked = (w["req_stage"] == 0) or (p_max_stage >= w["req_stage"])
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.12, 0.95) if is_unlocked else Color(0.08, 0.08, 0.08, 0.90)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.6, 0.5, 0.25, 0.8) if is_unlocked else Color(0.25, 0.25, 0.25, 0.6)
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		panel.add_child(hbox)
		
		# 左侧背景横幅
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(200, 95)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ResourceLoader.exists(w["bg"]):
			tex_rect.texture = load(w["bg"])
		if not is_unlocked:
			tex_rect.modulate = Color(0.4, 0.4, 0.4, 0.5) # 未解锁暗灰
		hbox.add_child(tex_rect)
		
		# 中间信息
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = w["name"]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0) if is_unlocked else Color(0.55, 0.55, 0.55, 1.0))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		info_vbox.add_child(name_lbl)
		
		var lvl_lbl = Label.new()
		lvl_lbl.text = "推荐等级: Lv.%d" % w["req_lvl"]
		lvl_lbl.add_theme_font_size_override("font_size", 12)
		lvl_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
		info_vbox.add_child(lvl_lbl)
		
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 11)
		if is_unlocked:
			status_lbl.text = "✨ 准入资格已达成"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1.0))
		else:
			status_lbl.text = "🔒 未解锁 (需%s)" % w["req_desc"]
			status_lbl.add_theme_color_override("font_color", Color(0.85, 0.4, 0.4, 1.0))
		info_vbox.add_child(status_lbl)
		
		# 右侧进入按钮
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 32)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if is_unlocked:
			btn.text = "进入"
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.18, 0.45, 0.8, 1.0)
			btn_style.corner_radius_top_left = 3
			btn_style.corner_radius_top_right = 3
			btn_style.corner_radius_bottom_left = 3
			btn_style.corner_radius_bottom_right = 3
			btn.add_theme_stylebox_override("normal", btn_style)
			var w_id_val = w["id"]
			var w_name_val = w["name"]
			btn.pressed.connect(func():
				world_selected.emit(w_id_val, w_name_val)
				hide()
			)
		else:
			btn.text = "未解锁"
			btn.disabled = true
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			btn_style.corner_radius_top_left = 3
			btn_style.corner_radius_top_right = 3
			btn_style.corner_radius_bottom_left = 3
			btn_style.corner_radius_bottom_right = 3
			btn.add_theme_stylebox_override("disabled", btn_style)
		hbox.add_child(btn)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		hbox.add_child(spacer)
		
		cards_container.add_child(panel)
