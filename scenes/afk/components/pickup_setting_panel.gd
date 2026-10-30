extends Control
class_name AFK_PickupSettingPanel

signal settings_saved(config: Dictionary)

@onready var tab_container: TabContainer = %TabContainer
@onready var btn_close: Button = %BtnClose
@onready var btn_save: Button = %BtnSave

# 其他拾取 Tab 内的复选框
@onready var chk_material: CheckBox = %ChkMaterial
@onready var chk_key: CheckBox = %ChkKey
@onready var chk_jewel: CheckBox = %ChkJewel
@onready var chk_skill: CheckBox = %ChkSkill
@onready var chk_confirm_unique: CheckBox = %ChkConfirmUnique
@onready var chk_keep_sockets: CheckBox = %ChkKeepSockets

# 预设按钮
@onready var btn_preset_safe: Button = %BtnPresetSafe
@onready var btn_preset_farm: Button = %BtnPresetFarm
@onready var btn_preset_speed: Button = %BtnPresetSpeed

# 细则规则 (JSON) Tab 控件
@onready var chk_enable_custom_json: CheckBox = %ChkEnableCustomJson
@onready var chk_auto_salvage_loot: CheckBox = %ChkAutoSalvageLoot
@onready var btn_import_json_file: Button = %BtnImportJsonFile
@onready var btn_export_json_file: Button = %BtnExportJsonFile
@onready var btn_reset_default_json: Button = %BtnResetDefaultJson
@onready var btn_clean_bag_now: Button = %BtnCleanBagNow
@onready var btn_toggle_view: Button = %BtnToggleView
@onready var lbl_json_status: Label = %LblJsonStatus
@onready var scroll_visual_rules: ScrollContainer = %ScrollVisualRules
@onready var visual_rules_vbox: VBoxContainer = %VisualRulesVBox
@onready var txt_json_rules: TextEdit = %TxtJsonRules
@onready var file_dialog_import: FileDialog = %FileDialogImport
@onready var file_dialog_export: FileDialog = %FileDialogExport

var is_code_view: bool = false

# 装备拾取 Tab 内的折叠行容器
@onready var rows_container: VBoxContainer = %RowsContainer

var current_config: Dictionary = {}
var rarity_spinboxes: Dictionary = {}

func _ready() -> void:
	z_index = 150
	hide()
	if btn_close:
		btn_close.pressed.connect(hide_panel)
	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)
		
	if btn_preset_safe:
		btn_preset_safe.tooltip_text = "【开荒全留】：全部不勾选，所有掉落装备全部拾取入包"
		btn_preset_safe.pressed.connect(func(): _apply_preset("safe"))
	if btn_preset_farm:
		btn_preset_farm.tooltip_text = "【进阶挂机】：自动分解白蓝装与粗糙黄装，保留暗金、套装与极品底材"
		btn_preset_farm.pressed.connect(func(): _apply_preset("farm"))
	if btn_preset_speed:
		btn_preset_speed.tooltip_text = "【极速神装】：自动分解白蓝黄绿大件，仅保留暗金神装与底材"
		btn_preset_speed.pressed.connect(func(): _apply_preset("speed"))
		
	if tab_container:
		tab_container.set_tab_title(0, "装备自动分解")
		tab_container.set_tab_title(1, "杂项与保护")
		tab_container.set_tab_title(2, "细则规则 (JSON)")

	_init_json_tab_controls()
	_init_d2_equipment_rows()

func _init_d2_equipment_rows() -> void:
	# 暗黑2正统 6 大品质/分类定义（彻底消除拾取与分解歧义）
	var d2_rarities = [
		{
			"id": "normal",
			"name": "普通装备 (白色 · 勾选分解 / 不勾拾取)",
			"color": Color(0.85, 0.85, 0.85), # 纯白
			"sub_types": [
				{"name": "武器", "key": "white_weapon"},
				{"name": "衣服/防具", "key": "white_armor"},
				{"name": "盾牌", "key": "white_shield"},
				{"name": "头盔", "key": "white_head"}
			]
		},
		{
			"id": "superior",
			"name": "特殊属性 (超强/无形/带孔底材 · 勾选放行分解 / 不勾受保护)",
			"color": Color(0.6, 0.8, 1.0), # 淡蓝银灰
			"sub_types": [
				{"name": "超强属性 (+ED/耐久)", "key": "superior_prop"},
				{"name": "无形 (佣兵神器/高攻防)", "key": "ethereal_prop"},
				{"name": "天然带孔底材", "key": "sockets_prop"}
			]
		},
		{
			"id": "magic",
			"name": "魔法装备 (蓝色 · 勾选分解 / 不勾拾取)",
			"color": Color(0.35, 0.5, 1.0), # 暗黑蓝
			"sub_types": [
				{"name": "武器", "key": "magic_weapon"},
				{"name": "防具", "key": "magic_armor"},
				{"name": "手套/鞋子", "key": "magic_boots_gloves"},
				{"name": "项链/戒指", "key": "magic_jewelry"}
			]
		},
		{
			"id": "rare",
			"name": "稀有装备 (亮金 · 勾选分解 / 不勾拾取)",
			"color": Color(1.0, 1.0, 0.4), # 亮金
			"sub_types": [
				{"name": "武器", "key": "rare_weapon"},
				{"name": "大件防具", "key": "rare_armor"},
				{"name": "手套/鞋子", "key": "rare_boots_gloves"},
				{"name": "项链/头环", "key": "rare_jewelry"}
			]
		},
		{
			"id": "set",
			"name": "套装装备 (绿色 · 勾选分解 / 不勾拾取)",
			"color": Color(0.1, 0.9, 0.1), # 暗黑绿
			"sub_types": [
				{"name": "套装武器", "key": "set_weapon"},
				{"name": "套装防具", "key": "set_armor"}
			]
		},
		{
			"id": "unique",
			"name": "暗金装备 (金色 · 勾选分解 / 不勾拾取)",
			"color": Color(0.85, 0.72, 0.4), # 暗金色
			"sub_types": [
				{"name": "暗金武器", "key": "unique_weapon"},
				{"name": "暗金防具", "key": "unique_armor"},
				{"name": "暗金饰品 (戒指/项链)", "key": "unique_jewelry"}
			]
		}
	]
	
	for child in rows_container.get_children():
		child.queue_free()
	rarity_spinboxes.clear()
		
	for r in d2_rarities:
		var row = _create_d2_rarity_row(r)
		rows_container.add_child(row)

func _create_d2_rarity_row(info: Dictionary) -> Control:
	var row_vbox = VBoxContainer.new()
	row_vbox.set_meta("rarity_info", info)
	
	# 主栏：折叠手柄 + 名称 + 孔数>=微调输入
	var bar_hbox = HBoxContainer.new()
	bar_hbox.custom_minimum_size = Vector2(0, 30)
	
	var btn_toggle = Button.new()
	btn_toggle.text = "▼"
	btn_toggle.custom_minimum_size = Vector2(24, 24)
	btn_toggle.flat = true
	bar_hbox.add_child(btn_toggle)
	
	var lbl_name = Label.new()
	lbl_name.text = info["name"]
	lbl_name.add_theme_color_override("font_color", info["color"])
	lbl_name.add_theme_font_size_override("font_size", 13)
	bar_hbox.add_child(lbl_name)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_hbox.add_child(spacer)
	
	# 暗黑2地道门槛：孔数 >= [ 0 ~ 6 ]
	var lbl_sock = Label.new()
	lbl_sock.text = "孔数≥"
	lbl_sock.add_theme_font_size_override("font_size", 11)
	lbl_sock.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	bar_hbox.add_child(lbl_sock)
	
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = 6 # 暗黑2装备最高 6 孔
	spin.step = 1
	spin.value = 0
	spin.custom_minimum_size = Vector2(65, 24)
	bar_hbox.add_child(spin)
	rarity_spinboxes[info["id"]] = spin
	
	row_vbox.add_child(bar_hbox)
	
	# 展开子分类区域
	var sub_panel = PanelContainer.new()
	var sub_style = StyleBoxFlat.new()
	sub_style.bg_color = Color(0.06, 0.06, 0.07, 0.85)
	sub_style.border_width_left = 1
	sub_style.border_color = Color(0.25, 0.25, 0.28, 0.5)
	sub_panel.add_theme_stylebox_override("panel", sub_style)
	sub_panel.visible = false
	
	var sub_margin = MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 28)
	sub_margin.add_theme_constant_override("margin_top", 4)
	sub_margin.add_theme_constant_override("margin_bottom", 6)
	
	var sub_grid = HFlowContainer.new()
	sub_grid.add_theme_constant_override("h_separation", 16)
	sub_grid.add_theme_constant_override("v_separation", 4)
	
	for sub in info.get("sub_types", []):
		var chk = CheckBox.new()
		chk.text = sub["name"]
		chk.name = sub["key"]
		sub_grid.add_child(chk)
		
	sub_margin.add_child(sub_grid)
	sub_panel.add_child(sub_margin)
	row_vbox.add_child(sub_panel)
	
	# 绑定手柄折叠展开
	btn_toggle.pressed.connect(func():
		sub_panel.visible = !sub_panel.visible
		btn_toggle.text = "▲" if sub_panel.visible else "▼"
	)
	
	return row_vbox

func _init_json_tab_controls() -> void:
	if btn_import_json_file and file_dialog_import:
		btn_import_json_file.pressed.connect(func(): file_dialog_import.popup_centered())
	if btn_export_json_file and file_dialog_export:
		btn_export_json_file.pressed.connect(func(): file_dialog_export.popup_centered())
	if btn_reset_default_json:
		btn_reset_default_json.pressed.connect(_on_reset_default_json_pressed)
	if btn_clean_bag_now:
		btn_clean_bag_now.pressed.connect(_on_clean_bag_now_pressed)
	if btn_toggle_view:
		btn_toggle_view.pressed.connect(_on_toggle_view_pressed)
		
	if file_dialog_import:
		file_dialog_import.file_selected.connect(_on_import_file_selected)
	if file_dialog_export:
		file_dialog_export.file_selected.connect(_on_export_file_selected)

func _on_toggle_view_pressed() -> void:
	var mgr = _get_custom_salvage_manager()
	if not mgr:
		return
	if not is_code_view:
		# 切换为代码视图
		is_code_view = true
		if txt_json_rules:
			txt_json_rules.text = JSON.stringify(mgr.current_rules, "  ")
			txt_json_rules.visible = true
		if scroll_visual_rules: scroll_visual_rules.visible = false
		if btn_toggle_view: btn_toggle_view.text = "📋 列表视图"
	else:
		# 切换回可视化列表视图
		if txt_json_rules:
			var raw_txt = txt_json_rules.text.strip_edges()
			if not raw_txt.is_empty():
				var json = JSON.new()
				if json.parse(raw_txt) == OK and json.data is Dictionary:
					mgr.current_rules = json.data
					mgr.save_rules()
				else:
					if lbl_json_status: lbl_json_status.text = "⚠️ JSON 语法有误，无法切换回列表视图！请检查语法。"
					return
		is_code_view = false
		if txt_json_rules: txt_json_rules.visible = false
		if scroll_visual_rules: scroll_visual_rules.visible = true
		if btn_toggle_view: btn_toggle_view.text = "📝 代码视图"
		_refresh_json_tab()

func _refresh_json_tab() -> void:
	var mgr = _get_custom_salvage_manager()
	if not mgr:
		return
	var rules = mgr.current_rules
	if chk_enable_custom_json:
		chk_enable_custom_json.button_pressed = bool(rules.get("enabled", false))
	if chk_auto_salvage_loot:
		chk_auto_salvage_loot.button_pressed = bool(rules.get("auto_salvage_on_loot", false))
	if txt_json_rules:
		txt_json_rules.text = JSON.stringify(rules, "  ")
	
	var keep_rules = rules.get("keep_rules", [])
	var salvage_rules = rules.get("salvage_rules", [])
	var keep_cnt = keep_rules.size() if keep_rules is Array else 0
	var salv_cnt = salvage_rules.size() if salvage_rules is Array else 0
	if lbl_json_status:
		lbl_json_status.text = "白名单居上优先保留 (共 %d 条)；未命中由下半区黑名单目标执行分解 (共 %d 条)。" % [keep_cnt, salv_cnt]
	
	_render_two_blocks_visual_rules(rules)

## 核心渲染两大板块：白名单居上 (绝对优先)，黑名单居下 (兜底分解)
func _render_two_blocks_visual_rules(rules: Dictionary) -> void:
	if not visual_rules_vbox:
		return
	for c in visual_rules_vbox.get_children():
		c.queue_free()
		
	var keep_rules = rules.get("keep_rules", [])
	var salvage_rules = rules.get("salvage_rules", [])
	if not keep_rules is Array: keep_rules = []
	if not salvage_rules is Array: salvage_rules = []

	# =========================================================================
	# 【大块 1】：★ 白名单保留规则 (居上 · 绝对优先)
	# =========================================================================
	var keep_header = _create_section_header("★ 白名单保留规则 (居上绝对优先 · 命中受保护留在背包 · %d 条)" % keep_rules.size(), Color(0.15, 0.4, 0.22, 0.95), Color(0.4, 0.95, 0.6))
	visual_rules_vbox.add_child(keep_header)

	if keep_rules.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "  (暂无白名单保留规则，所有底材将进入下方黑名单判定)"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		visual_rules_vbox.add_child(empty_lbl)
	else:
		for i in range(keep_rules.size()):
			var r = keep_rules[i]
			if r is Dictionary:
				var card = _create_rule_card(r, "keep", i)
				visual_rules_vbox.add_child(card)

	# 间距与分割
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 10)
	visual_rules_vbox.add_child(sep)

	# =========================================================================
	# 【大块 2】：♻️ 黑名单分解目标 (居下 · 白名单未命中时兜底)
	# =========================================================================
	var salvage_header = _create_section_header("♻️ 黑名单分解目标 (白名单未命中时判定 · 命中则调用指令分解 · %d 条)" % salvage_rules.size(), Color(0.35, 0.16, 0.16, 0.95), Color(1.0, 0.5, 0.45))
	visual_rules_vbox.add_child(salvage_header)

	if salvage_rules.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "  (暂无黑名单分解目标，未命中白名单的装备默认保留)"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		visual_rules_vbox.add_child(empty_lbl)
	else:
		for i in range(salvage_rules.size()):
			var r = salvage_rules[i]
			if r is Dictionary:
				var card = _create_rule_card(r, "salvage", i)
				visual_rules_vbox.add_child(card)

## 创建大区块横幅标题
func _create_section_header(title: String, bg_col: Color, text_col: Color) -> Control:
	var p = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", text_col)
	p.add_child(lbl)
	return p

## 单条规则卡片 (带 ▼/▲ 展开箭头手柄与详细参数抽屉)
func _create_rule_card(rule: Dictionary, rule_type: String, idx: int) -> Control:
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 2)
	
	# 1. 顶部主栏：箭头手柄 + 徽标 + 规则名称 + 删除按钮
	var bar_panel = PanelContainer.new()
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar_style.border_width_left = 3
	bar_style.border_color = Color(0.3, 0.85, 0.5) if rule_type == "keep" else Color(0.9, 0.4, 0.35)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.content_margin_left = 4
	bar_style.content_margin_right = 6
	bar_style.content_margin_top = 2
	bar_style.content_margin_bottom = 2
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	
	var bar_hbox = HBoxContainer.new()
	bar_hbox.custom_minimum_size = Vector2(0, 26)
	
	var btn_toggle = Button.new()
	btn_toggle.text = "▼"
	btn_toggle.custom_minimum_size = Vector2(24, 24)
	btn_toggle.flat = true
	bar_hbox.add_child(btn_toggle)
	
	var badge = Label.new()
	badge.text = "[★保留]" if rule_type == "keep" else "[♻️分解]"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5) if rule_type == "keep" else Color(1.0, 0.45, 0.4))
	bar_hbox.add_child(badge)
	
	var lbl_name = Label.new()
	lbl_name.text = str(rule.get("name", "未命名规则"))
	lbl_name.add_theme_font_size_override("font_size", 12)
	lbl_name.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	bar_hbox.add_child(lbl_name)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_hbox.add_child(spacer)
	
	# 删除本条按钮
	var btn_del = Button.new()
	btn_del.text = "🗑️"
	btn_del.flat = true
	btn_del.custom_minimum_size = Vector2(24, 22)
	btn_del.tooltip_text = "从当前规则中删除此项"
	btn_del.pressed.connect(func(): _delete_single_rule(rule_type, idx))
	bar_hbox.add_child(btn_del)
	
	bar_panel.add_child(bar_hbox)
	card_vbox.add_child(bar_panel)
	
	# 2. 展开抽屉面板 (展示底材、孔数、品质、无形、ED 等结构化参数)
	var sub_panel = PanelContainer.new()
	var sub_style = StyleBoxFlat.new()
	sub_style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sub_style.border_width_left = 2
	sub_style.border_color = Color(0.25, 0.25, 0.3, 0.6)
	sub_style.content_margin_left = 28
	sub_style.content_margin_right = 10
	sub_style.content_margin_top = 6
	sub_style.content_margin_bottom = 6
	sub_panel.add_theme_stylebox_override("panel", sub_style)
	sub_panel.visible = false
	
	var sub_grid = HFlowContainer.new()
	sub_grid.add_theme_constant_override("h_separation", 16)
	sub_grid.add_theme_constant_override("v_separation", 4)
	
	# (1) 底材包含
	var b_names = rule.get("base_names", [])
	var b_text = "底材: [" + ", ".join(b_names) + "]" if (b_names is Array and not b_names.is_empty()) else "底材: [全部底材]"
	sub_grid.add_child(_create_param_label(b_text, Color(0.95, 0.85, 0.4)))
	
	# (2) 孔数
	var sock_val = rule.get("sockets")
	var s_text = ""
	if sock_val is Array and not sock_val.is_empty():
		var str_socks: Array[String] = []
		for s in sock_val: str_socks.append(str(s) + "孔")
		s_text = "孔数: [" + "/".join(str_socks) + "]"
	elif sock_val is int or sock_val is float:
		s_text = "孔数: [%d孔]" % int(sock_val)
	else:
		s_text = "孔数: [不限]"
	sub_grid.add_child(_create_param_label(s_text, Color(0.4, 0.85, 1.0)))
	
	# (3) 品质限定
	var q_list = rule.get("qualities", [])
	if q_list is Array and not q_list.is_empty():
		var q_cn: Array[String] = []
		for q in q_list:
			match str(q).to_lower():
				"normal": q_cn.append("普通白色")
				"superior": q_cn.append("超强")
				"magic": q_cn.append("蓝色")
				"rare": q_cn.append("亮金")
				_: q_cn.append(str(q))
		sub_grid.add_child(_create_param_label("品质: [" + "/".join(q_cn) + "]", Color(0.75, 0.75, 0.8)))
		
	# (4) 无形
	if rule.has("ethereal"):
		var eth_text = "无形: [必须无形]" if bool(rule["ethereal"]) else "无形: [必须有形]"
		sub_grid.add_child(_create_param_label(eth_text, Color(0.7, 0.8, 1.0)))
		
	# (5) 增强伤害/防御门槛 (min_ed)
	if rule.has("min_ed") and int(rule["min_ed"]) > 0:
		sub_grid.add_child(_create_param_label("ED增强: [≥ %d%%]" % int(rule["min_ed"]), Color(1.0, 0.65, 0.2)))
		
	sub_panel.add_child(sub_grid)
	card_vbox.add_child(sub_panel)
	
	# 绑定手柄折叠展开事件
	btn_toggle.pressed.connect(func():
		sub_panel.visible = !sub_panel.visible
		btn_toggle.text = "▲" if sub_panel.visible else "▼"
	)
	
	return card_vbox

func _create_param_label(text: String, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	return l

## 删除单条规则
func _delete_single_rule(rule_type: String, idx: int) -> void:
	var mgr = _get_custom_salvage_manager()
	if not mgr:
		return
	var key = "keep_rules" if rule_type == "keep" else "salvage_rules"
	var list = mgr.current_rules.get(key, [])
	if list is Array and idx >= 0 and idx < list.size():
		list.remove_at(idx)
		mgr.current_rules[key] = list
		mgr.save_rules()
		_refresh_json_tab()

func _get_custom_salvage_manager() -> Node:
	if Engine.has_singleton("CustomSalvageManager"):
		return Engine.get_singleton("CustomSalvageManager")
	var tree = get_tree()
	if tree and tree.root.has_node("CustomSalvageManager"):
		return tree.root.get_node("CustomSalvageManager")
	return null

func _on_reset_default_json_pressed() -> void:
	var mgr = _get_custom_salvage_manager()
	if mgr:
		mgr.current_rules = mgr.get_default_rules()
		mgr.save_rules()
		_refresh_json_tab()

func _on_clean_bag_now_pressed() -> void:
	var mgr = _get_custom_salvage_manager()
	if mgr:
		var cnt = mgr.scan_and_salvage_bag()
		if lbl_json_status:
			lbl_json_status.text = "已扫描执行细则清理：发现并请求分解 %d 件装备。" % cnt

func _on_import_file_selected(path: String) -> void:
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		if f:
			var content = f.get_as_text()
			f.close()
			var mgr = _get_custom_salvage_manager()
			if mgr:
				var res = mgr.import_rules_from_string(content)
				if res.get("success", false):
					_refresh_json_tab()
					if lbl_json_status: lbl_json_status.text = "成功从文件导入规则！"
				else:
					if lbl_json_status: lbl_json_status.text = "导入失败: " + str(res.get("msg", ""))

func _on_export_file_selected(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		var content = txt_json_rules.text if txt_json_rules else ""
		f.store_string(content)
		f.close()
		if lbl_json_status: lbl_json_status.text = "成功导出规则到: " + path

func open_with_config(cfg: Dictionary) -> void:
	current_config = cfg.duplicate()
	_apply_config_to_ui(current_config)
	_refresh_json_tab()
	show()

func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func show_panel() -> void:
	z_index = 150
	_send_lpc_cmd("gfenjie get")
	_refresh_json_tab()
	show()

func hide_panel() -> void:
	hide()

func _apply_config_to_ui(cfg: Dictionary) -> void:
	if chk_material: chk_material.button_pressed = bool(cfg.get("material", true))
	if chk_key: chk_key.button_pressed = bool(cfg.get("key", false))
	if chk_jewel: chk_jewel.button_pressed = bool(cfg.get("jewel", false))
	if chk_skill: chk_skill.button_pressed = bool(cfg.get("skill", false))
	if chk_confirm_unique: chk_confirm_unique.button_pressed = bool(cfg.get("confirm_unique", true))
	if chk_keep_sockets: chk_keep_sockets.button_pressed = bool(cfg.get("keep_sockets", true))
	
	# 恢复孔数设置
	var sock_dict = cfg.get("min_sockets", {})
	if sock_dict is Dictionary:
		for r_id in rarity_spinboxes:
			if sock_dict.has(r_id):
				rarity_spinboxes[r_id].value = int(sock_dict[r_id])
				
	# 遍历装备行复选框
	if not rows_container:
		rows_container = get_node_or_null("%RowsContainer")
	if rows_container:
		for row in rows_container.get_children():
			for chk in _find_all_checkboxes(row):
				if cfg.has(chk.name):
					chk.button_pressed = bool(cfg[chk.name])

func _find_all_checkboxes(node: Node) -> Array[CheckBox]:
	var res: Array[CheckBox] = []
	if node is CheckBox:
		res.append(node)
	for child in node.get_children():
		res.append_array(_find_all_checkboxes(child))
	return res

func _on_save_pressed() -> void:
	var new_cfg = current_config.duplicate()
	if chk_material: new_cfg["material"] = int(chk_material.button_pressed)
	if chk_key: new_cfg["key"] = int(chk_key.button_pressed)
	if chk_jewel: new_cfg["jewel"] = int(chk_jewel.button_pressed)
	if chk_skill: new_cfg["skill"] = int(chk_skill.button_pressed)
	if chk_confirm_unique: new_cfg["confirm_unique"] = int(chk_confirm_unique.button_pressed)
	if chk_keep_sockets: new_cfg["keep_sockets"] = int(chk_keep_sockets.button_pressed)
	
	# 保存孔数
	var sock_dict = {}
	for r_id in rarity_spinboxes:
		sock_dict[r_id] = int(rarity_spinboxes[r_id].value)
	new_cfg["min_sockets"] = sock_dict
	
	# 保存各细分选项
	for row in rows_container.get_children():
		for chk in _find_all_checkboxes(row):
			new_cfg[chk.name] = int(chk.button_pressed)
			
	# 同步保存细则 JSON 规则
	var mgr = _get_custom_salvage_manager()
	if mgr and txt_json_rules:
		var raw_txt = txt_json_rules.text.strip_edges()
		if not raw_txt.is_empty():
			var json = JSON.new()
			if json.parse(raw_txt) == OK and json.data is Dictionary:
				var rules: Dictionary = json.data
				if chk_enable_custom_json: rules["enabled"] = chk_enable_custom_json.button_pressed
				if chk_auto_salvage_loot: rules["auto_salvage_on_loot"] = chk_auto_salvage_loot.button_pressed
				mgr.current_rules = rules
				mgr.save_rules()
			else:
				if lbl_json_status:
					lbl_json_status.text = "⚠️ 细则规则 JSON 格式有误，无法保存！请检查语法或恢复默认。"
				return

	current_config = new_cfg
	var json_str = JSON.stringify(new_cfg)
	_send_lpc_cmd("gfenjie save %s" % json_str)
	settings_saved.emit(new_cfg)
	hide_panel()

func _apply_preset(p_name: String) -> void:
	_send_lpc_cmd("gfenjie preset %s" % p_name)

func _send_lpc_cmd(cmd: String) -> void:
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw(cmd)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()
