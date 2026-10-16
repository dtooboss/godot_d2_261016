extends Control
class_name AFK_PlayerInventoryPanel

signal item_hovered(item_data, pos)
signal item_unhovered()
signal pocket_action_requested(action, file_id)
signal command_sent(cmd: String)

@onready var grid_container: GridContainer = %GridContainer
@onready var page_scroll_container: ScrollContainer = %PageScrollContainer
@onready var inv_button_container: VBoxContainer = %InvButtonContainer
@onready var gold_label: Label = %GoldLabel
@onready var btn_sort: Button = %BtnSort
@onready var btn_identify_all: Button = %BtnIdentifyAll
@onready var btn_help: Button = %BtnHelp
@onready var btn_pocket: Button = %BtnPocket
@onready var btn_multi_select: Button = %BtnMultiSelect
@onready var btn_workbench: Button = %BtnWorkbench
@onready var socketing_workbench_panel: AFK_SocketingWorkbenchPanel = %SocketingWorkbenchPanel

var is_multiselect_mode: bool = false
var selected_slots: Array[int] = []
@onready var little_pocket_panel: PanelContainer = %LittlePocketPanel
@onready var add_inv_panel: Control = %AddInventoryConfirmPanel

const COLS: int = 7
const ROWS: int = 12
const TOTAL_SLOTS: int = COLS * ROWS # 84格

var slots: Array[Button] = []
var items_map: Dictionary = {}
var raw_all_items: Array = []

var inventory_page_count: int = 1
var current_page: int = 1
var current_player_gold: int = 100000

var unlocked_pages: int = 1
var max_bag_pages: int = 4
var extend_cost: int = 50000
var _pending_new_item_pickup_fx: bool = false
var new_item_ids: Dictionary = {}
var current_hovered_slot: int = -1

func _ready() -> void:
	if little_pocket_panel:
		little_pocket_panel.z_index = 150
		little_pocket_panel.z_as_relative = false
	if socketing_workbench_panel:
		socketing_workbench_panel.z_index = 150
		socketing_workbench_panel.z_as_relative = false
	if add_inv_panel:
		add_inv_panel.z_index = 160
		add_inv_panel.z_as_relative = false

	if page_scroll_container:
		var v_bar = page_scroll_container.get_v_scroll_bar()
		if v_bar:
			v_bar.custom_minimum_size = Vector2(3, 0)
	_init_grid()
	_update_page_buttons()
	
	if btn_sort:
		btn_sort.pressed.connect(func():
			_send_lpc_cmd("gbag %d sort" % current_page)
		)
	if btn_identify_all:
		btn_identify_all.pressed.connect(func():
			_send_lpc_cmd("gidentify all")
		)
	if btn_multi_select:
		btn_multi_select.pressed.connect(_on_multi_select_pressed)
	
	if btn_pocket and little_pocket_panel:
		btn_pocket.pressed.connect(func():
			if not little_pocket_panel.visible:
				# 打开小口袋时，自动互斥关闭工坊
				if socketing_workbench_panel and socketing_workbench_panel.visible:
					socketing_workbench_panel.close()
			little_pocket_panel.toggle()
		)
		little_pocket_panel.item_hovered.connect(func(data, pos):
			item_hovered.emit(data, pos)
		)
		little_pocket_panel.item_unhovered.connect(func():
			item_unhovered.emit()
		)
		little_pocket_panel.pocket_action_requested.connect(_on_pocket_action)

	if btn_workbench and socketing_workbench_panel:
		btn_workbench.pressed.connect(func():
			var will_open = not socketing_workbench_panel.visible
			if will_open:
				# 打开工坊时，自动互斥关闭小口袋
				if little_pocket_panel and little_pocket_panel.visible:
					little_pocket_panel.close()
				# 单窗口互斥: 关魔盒 (兼顾安全区与挂机区)
				var hud_w = get_parent()
				while hud_w:
					if "cube_panel" in hud_w and hud_w.cube_panel:
						hud_w.cube_panel.visible = false
						break
					hud_w = hud_w.get_parent()
				socketing_workbench_panel.set_current_page(current_page)
				socketing_workbench_panel.open()
			else:
				socketing_workbench_panel.close()
		)
		socketing_workbench_panel.item_hovered.connect(func(data, pos):
			item_hovered.emit(data, pos)
		)
		socketing_workbench_panel.item_unhovered.connect(func():
			item_unhovered.emit()
		)
		socketing_workbench_panel.action_requested.connect(func(cmd_str: String):
			_send_lpc_cmd(cmd_str)
		)

func _update_page_buttons() -> void:
	if not inv_button_container:
		return
		
	var expected_children = inventory_page_count + 1
	var children = inv_button_container.get_children()
	
	# 如果子按钮数量与当前总页数匹配，只进行轻量样式增量刷新，绝不销毁重建！
	if children.size() == expected_children:
		for p in range(1, inventory_page_count + 1):
			var btn = children[p - 1] as Button
			if not btn: continue
			_apply_page_btn_style(btn, p == current_page)
		call_deferred("_scroll_to_page", current_page)
		return

	# 总页数发生变动时才进行全量构建
	for c in children:
		c.queue_free()
		
	# 1. 渲染数字页码按钮 (1, 2, 3...)
	for p in range(1, inventory_page_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(22, 22)
		btn.text = str(p)
		btn.add_theme_font_size_override("font_size", 12)
		btn.focus_mode = Control.FOCUS_NONE # 彻底禁用焦点抢占，杜绝自动滚屏
		_apply_page_btn_style(btn, p == current_page)
		btn.pressed.connect(_on_page_button_pressed.bind(p))
		inv_button_container.add_child(btn)
		
	# 2. 渲染 '+' 扩容按钮
	var btn_add = Button.new()
	btn_add.custom_minimum_size = Vector2(22, 22)
	btn_add.text = "+"
	btn_add.add_theme_font_size_override("font_size", 12)
	btn_add.focus_mode = Control.FOCUS_NONE # 彻底禁用焦点抢占
	
	var add_style = StyleBoxFlat.new()
	add_style.bg_color = Color(0.18, 0.16, 0.22, 0.95)
	add_style.border_width_left = 1
	add_style.border_width_top = 1
	add_style.border_width_right = 1
	add_style.border_width_bottom = 1
	add_style.border_color = Color(0.35, 0.3, 0.42, 0.8)
	add_style.corner_radius_top_left = 2
	add_style.corner_radius_top_right = 2
	add_style.corner_radius_bottom_right = 2
	add_style.corner_radius_bottom_left = 2
	btn_add.add_theme_stylebox_override("normal", add_style)
	btn_add.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
	
	btn_add.pressed.connect(_on_add_page_pressed)
	inv_button_container.add_child(btn_add)
	
	call_deferred("_scroll_to_page", current_page)

func _apply_page_btn_style(btn: Button, is_active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	
	if is_active:
		style.bg_color = Color(0.1, 0.55, 0.15, 1.0)
		style.border_color = Color(0.2, 0.85, 0.25, 1.0)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
		style.border_color = Color(0.25, 0.25, 0.28, 0.8)
		btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))
		
	btn.add_theme_stylebox_override("normal", style)

func _scroll_to_page(page_num: int) -> void:
	if not page_scroll_container:
		return
	# 每个页码按钮高 22px，间隔 3px，单项高度步长为 25px
	# 精准将目标页码滚动对齐在视口最顶部第一个位置！
	var target_v = max(0, (page_num - 1) * 25)
	page_scroll_container.scroll_vertical = target_v

func _on_page_button_pressed(page_num: int) -> void:
	if current_page == page_num:
		return
	current_page = page_num
	if socketing_workbench_panel:
		socketing_workbench_panel.set_current_page(page_num)
	_update_page_buttons()
	_scroll_to_page(page_num)
	_send_lpc_cmd("gbag %d" % current_page)

func _on_add_page_pressed() -> void:
	if add_inv_panel:
		add_inv_panel.show_panel(inventory_page_count, current_player_gold, extend_cost, max_bag_pages, _on_confirm_extend)

func _on_confirm_extend(_unused_cost: int = 0, _unused_next_cnt: int = 0) -> void:
	# 前端纯哑渲染驱动，杜绝本地扣款与虚假加页！
	# 统一向服务端下发 gbag extend，由服务端校验、扣金币、持久化并返回最新权威状态
	_send_lpc_cmd("gbag extend")

func _on_inventory_extended(_new_page_cnt: int) -> void:
	pass

func _init_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	slots.clear()
	items_map.clear()
	
	for i in range(TOTAL_SLOTS):
		var btn = InvSlotButton.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.flat = false
		btn.panel_owner = self
		btn.slot_type = "main_bag"
		btn.slot_index = i
		
		# 样式：黑底细金边框
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.08, 0.95)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.22, 0.22, 0.22, 0.8)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 2
		btn.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.9, 0.8, 0.3, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		
		btn.mouse_entered.connect(_on_slot_hovered.bind(i, btn))
		btn.mouse_exited.connect(_on_slot_unhovered.bind(i))
		btn.gui_input.connect(_on_slot_gui_input.bind(i, btn))
		
		grid_container.add_child(btn)
		slots.append(btn)

func update_gold(gold_val: int) -> void:
	current_player_gold = gold_val
	if gold_label:
		gold_label.text = "%sG" % _format_number(current_player_gold)

func render_lpc_items(items_list: Array, charm_used: int = -1, charm_max: int = 40, total_pages: int = 1, cur_page: int = -1, extra_info: Dictionary = {}) -> void:
	if not extra_info.is_empty():
		if extra_info.has("unlocked_pages"):
			unlocked_pages = AnsiHelper.to_safe_int(extra_info.get("unlocked_pages"), 1)
		if extra_info.has("max_pages"):
			max_bag_pages = AnsiHelper.to_safe_int(extra_info.get("max_pages"), 4)
		if extra_info.has("extend_cost"):
			extend_cost = AnsiHelper.to_safe_int(extra_info.get("extend_cost"), 0)
		if extra_info.has("gold"):
			update_gold(AnsiHelper.to_safe_int(extra_info.get("gold"), 0))
			
	var target_pages = max(total_pages, unlocked_pages)
	var need_refresh_btns = false
	if target_pages > 0 and target_pages != inventory_page_count:
		inventory_page_count = target_pages
		need_refresh_btns = true
	if cur_page > 0 and cur_page != current_page:
		current_page = cur_page
		need_refresh_btns = true
	if need_refresh_btns:
		_update_page_buttons()
	raw_all_items = items_list
	items_map.clear()
	for btn in slots:
		btn.icon = null
		if btn.has_method("set_slot_amount"):
			btn.set_slot_amount(0)
		if btn.has_method("set_slot_quality"):
			btn.set_slot_quality("")
		if btn.has_method("set_slot_sockets"):
			btn.set_slot_sockets(0, [])
		if btn.has_method("set_slot_new"):
			btn.set_slot_new(false)
		if btn.has_method("set_slot_unidentified"):
			btn.set_slot_unidentified(false)
		if btn.has_method("set_slot_unmet"):
			btn.set_slot_unmet(false)
		
	var main_bag_items: Array = []
	var pocket_items: Array = []
	var calc_charm_used: int = 0
	
	for it in items_list:
		if not it is Dictionary:
			continue
		var item_data = _parse_single_lpc_item(it)
		if item_data.get("in_charm_bag", false):
			pocket_items.append(item_data)
			calc_charm_used += item_data.get("charm_size", 1)
		else:
			main_bag_items.append(item_data)
			
	# 1. 渲染主背包格子 (排除已放入小口袋的物品)
	for i in range(main_bag_items.size()):
		if i >= slots.size():
			break
		set_lpc_item(i, main_bag_items[i])
		
	# 2. 渲染小口袋格子
	if little_pocket_panel and little_pocket_panel.has_method("render_pocket_items"):
		var final_used = charm_used if charm_used >= 0 else calc_charm_used
		little_pocket_panel.render_pocket_items(pocket_items, final_used, charm_max)
		
	# 3. 尾页新掉落高光动效回放
	if _pending_new_item_pickup_fx:
		_pending_new_item_pickup_fx = false
		if main_bag_items.size() > 0:
			var last_slot = min(main_bag_items.size() - 1, slots.size() - 1)
			_play_slot_pickup_fx(last_slot)

	# 4. 一键鉴定按钮动态状态 (若有未辨识物品则高亮提醒)
	if btn_identify_all:
		var has_unid = false
		for m_it in main_bag_items:
			if bool(m_it.get("unidentified", false)):
				has_unid = true
				break
		if has_unid:
			btn_identify_all.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
			btn_identify_all.text = "一键鉴定!"
		else:
			btn_identify_all.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
			btn_identify_all.text = "一键鉴定"

func _parse_single_lpc_item(it: Dictionary) -> Dictionary:
	var raw_name = str(it.get("name", "未命名物品"))
	var icon_path = str(it.get("icon", ""))
	var quality = str(it.get("quality", "normal")).to_lower()
	var amount = AnsiHelper.to_safe_int(it.get("amount"), 1)
	var cmd_str = str(it.get("cmd", ""))
	var info_dict = it.get("item_info", {})
	var in_pocket = AnsiHelper.to_safe_int(it.get("in_charm_bag"), 0) == 1
	var is_charm = AnsiHelper.to_safe_int(it.get("is_charm"), 0) == 1
	var c_size = AnsiHelper.to_safe_int(it.get("charm_size"), 1)
	var file_id = str(it.get("file_id", ""))
	var is_unid = AnsiHelper.to_safe_int(it.get("unidentified"), 0) == 1 or bool(it.get("unidentified", false))
	
	if file_id.is_empty() and cmd_str.begins_with("look "):
		file_id = cmd_str.substr(5).strip_edges()
		
	var col_hex = "#a59263"
	match quality:
		"unique": col_hex = "#a59263"
		"set": col_hex = "#00aa00"
		"rare": col_hex = "#ffff64"
		"magic": col_hex = "#4850b8"
		"crafted": col_hex = "#ff8000"
		_: col_hex = "#ffffff"
		
	var desc_text = ""
	if info_dict is Dictionary and info_dict.has("desc"):
		desc_text = str(info_dict.get("desc", ""))
	elif it.has("desc"):
		desc_text = str(it.get("desc", ""))
	else:
		desc_text = raw_name
		
	var clean_name = AnsiHelper.to_plain_text(raw_name)
	var sock_count = AnsiHelper.to_safe_int(it.get("sockets"), 0)
	var inlays = it.get("inlays", [])
	if not (inlays is Array):
		inlays = []
	if sock_count <= 0 and "?" in icon_path:
		var img_info = AnsiHelper.extract_img_info("[img:" + icon_path + "]")
		sock_count = AnsiHelper.to_safe_int(img_info.get("sock"), 0)
		var in_arr = img_info.get("inlays", [])
		if in_arr is Array or in_arr is PackedStringArray:
			inlays = Array(in_arr)
		
	var item_data = {
		"name": clean_name,
		"raw_name": raw_name,
		"type": quality.capitalize(),
		"quality": quality,
		"color": col_hex,
		"desc": desc_text,
		"cmd": cmd_str,
		"file_id": file_id,
		"amount": amount,
		"icon": icon_path,
		"sockets": sock_count,
		"inlays": inlays,
		"in_charm_bag": in_pocket,
		"is_charm": is_charm,
		"charm_size": c_size,
		"d2_type": str(it.get("d2_type", "")),
		"slot": str(it.get("slot", "")),
		"is_consumable": AnsiHelper.to_safe_int(it.get("is_consumable"), 0),
		"is_stackable": AnsiHelper.to_safe_int(it.get("is_stackable"), 0),
		"is_rune": AnsiHelper.to_safe_int(it.get("is_rune"), 0),
		"is_gem": AnsiHelper.to_safe_int(it.get("is_gem"), 0),
		"unidentified": is_unid,
		"unmet": AnsiHelper.to_safe_int(it.get("unmet", 0), 0),
	}
	
	var tex = _resolve_smart_icon(clean_name, icon_path)
	if tex:
		item_data["icon_texture"] = tex
		
	return item_data

func _resolve_smart_icon(item_name: String, icon_path: String) -> Texture2D:
	var tex: Texture2D = null
	if not icon_path.is_empty():
		tex = AnsiHelper.load_item_texture(icon_path)
	if tex:
		return tex
		
	var n = item_name.to_lower()
	if "护身符" in n or "charm" in n or "火炬" in n or "毁灭" in n or "吉黑得" in n:
		if "超大" in n or "grand" in n:
			return load("res://assets/items/misc/charm/charm_large.lowend.png")
		elif "大型" in n or "large" in n or "火炬" in n:
			return load("res://assets/items/misc/charm/charm_medium.lowend.png")
		return load("res://assets/items/misc/charm/charm_small.lowend.png")
	elif "带" in n or "腰" in n or "sash" in n or "belt" in n:
		return load("res://assets/items/armor/belt/sash_l.lowend.png")
	elif "手套" in n or "钳" in n or "glove" in n:
		return load("res://assets/items/armor/glove/gloves_l.lowend.png")
	elif "项链" in n or "眼" in n or "amulet" in n:
		return load("res://assets/items/misc/amulet/amulet1.lowend.png")
	elif "戒" in n or "ring" in n:
		return load("res://assets/items/misc/ring/ring1.lowend.png")
	elif "剑" in n or "刃" in n or "刀" in n or "sword" in n:
		return load("res://assets/items/weapon/sword/short_sword.lowend.png")
	elif "甲" in n or "铠" in n or "armor" in n:
		return load("res://assets/items/armor/armor/ancient_armor.lowend.png")
	elif "盔" in n or "冠" in n or "帽" in n or "helm" in n:
		return load("res://assets/items/armor/helmet/helm.lowend.png")
	elif "靴" in n or "鞋" in n or "boot" in n:
		return load("res://assets/items/armor/boot/leather_boots.lowend.png")
	elif "盾" in n or "shield" in n:
		return load("res://assets/items/armor/shield/large_shield.lowend.png")
	elif "符文" in n or "rune" in n:
		return load("res://assets/items/misc/rune/el_rune.lowend.png")
		
	return load("res://assets/items/misc/herb/herb.lowend.png")

func _get_item_unique_id(item_data: Dictionary) -> String:
	var fid = str(item_data.get("file_id", "")).strip_edges()
	if not fid.is_empty():
		return fid
	var cmd_str = str(item_data.get("cmd", "")).strip_edges()
	if cmd_str.begins_with("look "):
		return cmd_str.substr(5).strip_edges()
	var iname = str(item_data.get("name", ""))
	var iqual = str(item_data.get("quality", ""))
	var ilvl = str(item_data.get("level", ""))
	return "%s_%s_%s" % [iname, iqual, ilvl]

func _clear_item_new_state(item_data: Dictionary, btn: Button = null) -> void:
	var fid = _get_item_unique_id(item_data)
	if not fid.is_empty() and new_item_ids.has(fid):
		new_item_ids.erase(fid)
		if btn and btn.has_method("set_slot_new"):
			btn.set_slot_new(false)

func set_lpc_item(slot_idx: int, item_data: Dictionary) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	items_map[slot_idx] = item_data
	var btn = slots[slot_idx]
	if item_data.has("icon_texture"):
		btn.icon = item_data["icon_texture"]
	if btn.has_method("set_slot_amount"):
		btn.set_slot_amount(AnsiHelper.to_safe_int(item_data.get("amount"), 1))
	if btn.has_method("set_slot_quality"):
		var q = str(item_data.get("quality", "normal"))
		btn.set_slot_quality(q)
	if btn.has_method("set_slot_sockets"):
		var s_cnt = AnsiHelper.to_safe_int(item_data.get("sockets"), 0)
		var in_list = item_data.get("inlays", [])
		btn.set_slot_sockets(s_cnt, in_list if in_list is Array else [])
	if btn.has_method("set_slot_new"):
		var fid = _get_item_unique_id(item_data)
		btn.set_slot_new(not fid.is_empty() and new_item_ids.has(fid))
	if btn.has_method("set_slot_unidentified"):
		btn.set_slot_unidentified(bool(item_data.get("unidentified", false)))
	if btn.has_method("set_slot_unmet"):
		btn.set_slot_unmet(bool(item_data.get("unmet", false)))

## 增量添加掉落战利品 (0 延迟即时落入背包，无重绘无闪烁)
func add_incremental_reward(reward_item: Dictionary, gold_val: int = 0) -> bool:
	if gold_val > 0:
		update_gold(current_player_gold + gold_val)
		
	if reward_item.is_empty():
		return true
		
	var item_data = _parse_single_lpc_item(reward_item)
	var fid = _get_item_unique_id(item_data)
	if not fid.is_empty():
		new_item_ids[fid] = true
		
	var is_pocket = item_data.get("in_charm_bag", false)
	
	# 若属于小口袋护身符
	if is_pocket and little_pocket_panel and little_pocket_panel.has_method("render_pocket_items"):
		return true
		
	# 1. 堆叠判定：若属于可堆叠道具/材料 (符文、宝石、药水、卷轴等)，寻找背包现有同名格子就地更新
	if _is_item_stackable(item_data):
		var target_clean_name = AnsiHelper.to_plain_text(str(item_data.get("name", "")))
		var target_id = str(item_data.get("id", ""))
		var target_slot = -1
		
		for s_idx in items_map.keys():
			var existing = items_map[s_idx]
			var ex_clean_name = AnsiHelper.to_plain_text(str(existing.get("name", "")))
			if ex_clean_name == target_clean_name or (not target_id.is_empty() and str(existing.get("id", "")) == target_id) or (not item_data.get("file_id", "").is_empty() and existing.get("file_id") == item_data.get("file_id")):
				target_slot = s_idx
				break
				
		if target_slot != -1:
			var existing = items_map[target_slot]
			var server_amt = AnsiHelper.to_safe_int(item_data.get("amount"), 0)
			var cur_amt = AnsiHelper.to_safe_int(existing.get("amount"), 1)
			
			# 服务端 COMBINED_ITEM 原地合并下发权威总数 (如 7); 若一致说明已被 gbag_item_update 同步
			if server_amt > cur_amt:
				existing["amount"] = server_amt
			elif server_amt == cur_amt:
				pass
			else:
				existing["amount"] = cur_amt + max(1, server_amt)
				
			if item_data.has("file_id"): existing["file_id"] = item_data["file_id"]
			if item_data.has("cmd"): existing["cmd"] = item_data["cmd"]
			
			var btn = slots[target_slot]
			if btn and btn.has_method("set_slot_amount"):
				btn.set_slot_amount(existing["amount"])
			_play_slot_pickup_fx(target_slot)
			
			# 同步更新 raw_all_items 中的条目，绝不追加新条目（杜绝产生虚影）
			for raw in raw_all_items:
				var r_name = AnsiHelper.to_plain_text(str(raw.get("name", "")))
				if r_name == target_clean_name or (not target_id.is_empty() and str(raw.get("id", "")) == target_id):
					raw["amount"] = existing["amount"]
					if item_data.has("file_id"): raw["file_id"] = item_data["file_id"]
					break
			return true
			
		# 若当前可见页无此格子，检查 raw_all_items (其他页) 中是否已存在同名物品
		for raw in raw_all_items:
			var r_name = AnsiHelper.to_plain_text(str(raw.get("name", "")))
			if r_name == target_clean_name or (not target_id.is_empty() and str(raw.get("id", "")) == target_id):
				var server_amt = AnsiHelper.to_safe_int(item_data.get("amount"), 0)
				var r_amt = AnsiHelper.to_safe_int(raw.get("amount"), 1)
				if server_amt > r_amt:
					raw["amount"] = server_amt
				elif server_amt == r_amt:
					pass
				else:
					raw["amount"] = r_amt + max(1, server_amt)
				if item_data.has("file_id"): raw["file_id"] = item_data["file_id"]
				return true

	# 2. (2026-10-04 虚影根治) 不再本地伪造格子:
	#    堆的权威位置/数量由服务端 gbag_patch 帧下发; 当前页与缓存都未命中时
	#    静默等待 patch (战利品横幅照常弹出, 玩家感知不缺失; 翻页时 gbag 全量帧呈现真相)
	return true

func _is_item_stackable(item_data: Dictionary) -> bool:
	# 1. 优先以后端权威元数据标记驱动
	if item_data.has("is_stackable"):
		return AnsiHelper.to_safe_int(item_data.get("is_stackable"), 0) == 1
	if bool(item_data.get("is_combined", false)):
		return true
	if AnsiHelper.to_safe_int(item_data.get("is_rune"), 0) == 1 or AnsiHelper.to_safe_int(item_data.get("is_gem"), 0) == 1:
		return true
	if AnsiHelper.to_safe_int(item_data.get("amount"), 1) > 1:
		return true
	if _is_item_consumable(item_data):
		return true
		
	# 2. 字段类型判定 (消除符文中文名称特判与硬编码 ID)
	var it_type = str(item_data.get("d2_type", item_data.get("type", ""))).to_lower()
	if it_type in ["符文", "宝石", "药水", "卷轴", "材料", "rune", "gem", "potion", "scroll", "material"]:
		return true
		
	return false

## 获取宿主控制器 (自动适配 AFK_MainHUD 战斗挂机房 或 TownHubController 主城大本营)
func _get_host_controller() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var cur = tree.current_scene
	if cur and ("char_info_panel" in cur or "cube_panel" in cur):
		return cur
	var p = get_parent()
	while p:
		if "char_info_panel" in p or "cube_panel" in p:
			return p
		p = p.get_parent()
	return null

func _notify_inventory_full() -> void:
	print("[PlayerInventoryPanel] 背包已满！请及时整理背包或花费金币解锁新页码。")
	var host = _get_host_controller()
	if host and host.has_method("show_toast"):
		host.show_toast("背包已满！请及时整理背包或点击 [+] 扩充新页。")

## 战利品入包高光微动效 (强化爆装正反馈)
func _play_slot_pickup_fx(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	var btn = slots[slot_idx]
	btn.pivot_offset = btn.size * 0.5
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## 增量更新指定物品数量 (Delta Update, 零重绘、零闪烁、微秒级响应)
## 服务端权威账本补丁 (2026-10-04 虚影根治): 掉落入包后最终堆的页/槽/完整条目
## v2: 条目过 _parse_single_lpc_item 生成 icon_texture (修无图标); 名字匹配优先=合并必原地涨数;
##     x/y 仅落空闲格 (序列错位时绝不覆盖他人物品); 空格兜底
func apply_gbag_patch(data: Dictionary) -> void:
	var page = AnsiHelper.to_safe_int(data.get("page"), -1)
	var raw_it = data.get("item")
	if page < 1 or not (raw_it is Dictionary) or raw_it.is_empty():
		return
	# 非当前页: 不做本地渲染 (翻页时 gbag 全量帧天然呈现真相), 坚决不伪造
	if page != current_page:
		return
	var it = _parse_single_lpc_item(raw_it)
	var clean_name = AnsiHelper.to_plain_text(str(raw_it.get("name", "")))
	var is_stack = _is_item_stackable(it)
	var target_slot = -1
	# 1) 同堆名字匹配优先: 仅可堆叠物品生效！合并=原地覆盖涨数, 永不另起格子
	if is_stack:
		for s_idx in items_map.keys():
			var ex = items_map[s_idx]
			if AnsiHelper.to_plain_text(str(ex.get("name", ""))) == clean_name:
				target_slot = s_idx
				break
	# 2) x/y 落位: 仅当目标格空闲 (服务端/客户端序列短暂错位时绝不覆盖他人物品)
	if target_slot == -1:
		var gx = AnsiHelper.to_safe_int(raw_it.get("x"), -1)
		var gy = AnsiHelper.to_safe_int(raw_it.get("y"), -1)
		if gx >= 0 and gy >= 0:
			var calc_slot = gy * COLS + gx
			if calc_slot >= 0 and calc_slot < min(TOTAL_SLOTS, slots.size()) and not items_map.has(calc_slot):
				target_slot = calc_slot
	# 3) 第一个空格兜底
	if target_slot == -1:
		for i in range(min(TOTAL_SLOTS, slots.size())):
			if not items_map.has(i):
				target_slot = i
				break
	if target_slot == -1:
		return
	set_lpc_item(target_slot, it)
	_play_slot_pickup_fx(target_slot)

func update_item_amount(file_id: String, new_amount: int) -> bool:
	if file_id.is_empty():
		return false
		
	# 1. 在当前页已渲染格子中定位该物品 (优先比对 file_id，次选比对 cmd / id)
	var target_slot = -1
	for slot_idx in items_map.keys():
		var it = items_map[slot_idx]
		if it is Dictionary:
			var fid = str(it.get("file_id", ""))
			if fid == file_id:
				target_slot = slot_idx
				break
			var cmd_str = str(it.get("cmd", ""))
			if not cmd_str.is_empty() and (cmd_str == "look " + file_id or cmd_str.ends_with(file_id)):
				target_slot = slot_idx
				break
				
	# 2. 如果当前页找到了该格子
	if target_slot != -1:
		var btn = slots[target_slot]
		if new_amount > 0:
			# 数量 > 0：仅更新角标数字与本地数据，绝不重构图标与边框
			items_map[target_slot]["amount"] = new_amount
			if btn and btn.has_method("set_slot_amount"):
				btn.set_slot_amount(new_amount)
			_play_slot_pickup_fx(target_slot)
		else:
			# 数量 <= 0：用尽清空格子，彻底消除残影
			items_map.erase(target_slot)
			if btn:
				btn.icon = null
				if btn.has_method("set_slot_amount"):
					btn.set_slot_amount(0)
				if btn.has_method("set_slot_quality"):
					btn.set_slot_quality("")
				if btn.has_method("set_slot_sockets"):
					btn.set_slot_sockets(0, [])
				if btn.has_method("set_slot_new"):
					btn.set_slot_new(false)
				if btn.has_method("set_slot_unidentified"):
					btn.set_slot_unidentified(false)
				if btn.has_method("set_slot_unmet"):
					btn.set_slot_unmet(false)
					
	# 3. 同步更新 raw_all_items 中的对应数据（保证换页或重新排序时数据权威性）
	var raw_found = false
	for i in range(raw_all_items.size() - 1, -1, -1):
		var raw = raw_all_items[i]
		if raw is Dictionary:
			var r_fid = str(raw.get("file_id", ""))
			var r_cmd = str(raw.get("cmd", ""))
			if r_fid == file_id or (not r_cmd.is_empty() and (r_cmd == "look " + file_id or r_cmd.ends_with(file_id))):
				raw_found = true
				if new_amount > 0:
					raw["amount"] = new_amount
				else:
					raw_all_items.remove_at(i)
				break
				
	return (target_slot != -1 or raw_found)

func _is_item_consumable(item_data: Dictionary) -> bool:
	# 1. 优先以后端权威元数据标记驱动
	if item_data.has("is_consumable"):
		return AnsiHelper.to_safe_int(item_data.get("is_consumable"), 0) == 1
	if bool(item_data.get("is_potion", false)):
		return true

	# 2. 字段类型判定 (消除中文名称猜解和硬编码 ID 白名单)
	var d2_type = str(item_data.get("d2_type", item_data.get("type", ""))).to_lower()
	if d2_type in ["药水", "potion", "scroll", "卷轴", "消耗品", "consumable", "food", "pill", "book", "书"]:
		return true

	# 3. 任务与功能消耗道具兜底
	var iname = str(item_data.get("name", ""))
	if "技能之书" in iname or "生命药剂" in iname or "抵抗卷轴" in iname or "赦免徽章" in iname or "蓝·森之书" in iname or "蓝森之书" in iname:
		return true

	return false

func _on_slot_hovered(slot_idx: int, btn: Button) -> void:
	current_hovered_slot = slot_idx
	if items_map.has(slot_idx):
		var it = items_map[slot_idx]
		_clear_item_new_state(it, btn)
		item_hovered.emit(it, btn.global_position)

func _on_slot_unhovered(slot_idx: int = -1) -> void:
	if slot_idx == -1 or current_hovered_slot == slot_idx:
		current_hovered_slot = -1
		item_unhovered.emit()

func _on_slot_gui_input(event: InputEvent, slot_idx: int, _btn: Button = null) -> void:
	if event is InputEventMouseButton and event.pressed:
		if items_map.has(slot_idx):
			var cur_btn = _btn if _btn else (slots[slot_idx] if slot_idx < slots.size() else null)
			_clear_item_new_state(items_map[slot_idx], cur_btn)
			
	if event is InputEventMouseButton:
		if is_multiselect_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_toggle_slot_selection(slot_idx)
			return
			
		# Shift + 左键点击装备：优先插入聊天输入框 (图文一体自由留言)，无输入框时直接展示
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.shift_pressed:
			if items_map.has(slot_idx):
				var it = items_map[slot_idx]
				var fid = str(it.get("file_id", ""))
				if not fid.is_empty():
					var cur_scene = get_tree().current_scene
					if cur_scene and cur_scene.has_method("_insert_item_to_chat"):
						cur_scene._insert_item_to_chat(it)
						return
					_send_lpc_cmd("gshowitem %s" % fid)
					return

		# 鼠标右键：必须先判断当前哪个窗口打开，才对应执行哪个窗口操作！
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if items_map.has(slot_idx):
				var it = items_map[slot_idx]
				var fid = it.get("file_id", "")
				if fid.is_empty():
					return
					
				# 0.4 如果双向交易面板处于开启状态 -> 调用 trade_panel.offer_item (叠加物品智能弹窗选数量，单件装备直接放入)
				var cur_scene = get_tree().current_scene
				if cur_scene and "trade_panel" in cur_scene and cur_scene.trade_panel and cur_scene.trade_panel.visible:
					cur_scene.trade_panel.offer_item(it)
					return

				# 0.5 如果物品是未辨识装备/护身符 -> 绝对优先执行右键辨识 (优先消耗辨识卷轴，缺卷轴自动扣 2,000 金币)
				var is_unid = bool(it.get("unidentified", false)) or AnsiHelper.to_safe_int(it.get("unidentified"), 0) == 1
				if is_unid:
					_send_lpc_cmd("gidentify %s" % fid)
					return

				# 0.6 如果储物箱面板正打开 -> 直接存入储物箱当前仓位！
				var host = _get_host_controller()
				if host and "stash_panel" in host and host.stash_panel and host.stash_panel.is_visible_in_tree():
					var s_tab = host.stash_panel.current_tab
					_send_lpc_cmd("stash store %s %d" % [fid, s_tab])
					return

				# 1. 如果工坊面板正打开 -> 优先处理工坊操作 (直接由 LPC 指令全权判断处理，前端只负责发指令与纯渲染)
				if socketing_workbench_panel and socketing_workbench_panel.is_visible_in_tree():
					_send_lpc_cmd("gsocket put %s %d" % [fid, current_page])
					return

				# 2. 魔盒面板正打开 -> 放入赫拉迪克方块
				var host_c = _get_host_controller()
				if host_c and host_c.cube_panel and host_c.cube_panel.is_visible_in_tree():
					_send_lpc_cmd("gcube put %s" % fid)
					return

				# 3. 如果小口袋面板正打开 -> 护身符存入小口袋
				var is_charm = bool(it.get("is_charm", false)) or AnsiHelper.to_safe_int(it.get("is_charm"), 0) == 1
				if is_charm:
					if little_pocket_panel and little_pocket_panel.is_visible_in_tree():
						_on_pocket_action("in", fid)
					return

				# 4. 如果是药水或消耗品 -> 直接使用 (guse)，由服务端下发增量更新，0 重绘
				if _is_item_consumable(it):
					_send_lpc_cmd("guse %s" % fid)
					return

				# 5. 只有当角色纸娃娃窗口明确打开时 -> 右键装备才快速穿戴换装！
				var char_panel_open = false
				if host and host.char_info_panel and host.char_info_panel.is_visible_in_tree():
					char_panel_open = true
					
				if char_panel_open:
					_send_lpc_cmd("gwear %s %d" % [fid, current_page])
				else:
					# 纸娃娃窗口未打开时，右键装备不盲目换装
					pass

# ========== 拖拽接口 (Drag & Drop) ==========
func get_slot_drag_data(_slot_type: String, slot_idx: int) -> Variant:
	if not items_map.has(slot_idx):
		return null
	var it = items_map[slot_idx]
	var preview = TextureRect.new()
	if it.has("icon_texture"):
		preview.texture = it["icon_texture"]
	preview.custom_minimum_size = Vector2(36, 36)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return {
		"source": "main_bag",
		"slot_idx": slot_idx,
		"item_data": it
	}

func can_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> bool:
	if data is Dictionary and (data.get("source") == "pocket" or data.get("source") == "paperdoll" or data.get("source") == "cube" or data.get("source") == "stash"):
		return true
	return false

func on_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> void:
	if data is Dictionary:
		var it = data.get("item_data", {})
		var fid = it.get("file_id", "")
		if fid.is_empty():
			return
		if data.get("source") == "pocket":
			_on_pocket_action("out", fid)
		elif data.get("source") == "paperdoll":
			# 从纸娃娃槽位拖出到背包格子：执行卸装 (gremove 带刷新)
			_send_lpc_cmd("gremove %s %d" % [fid, current_page])
		elif data.get("source") == "cube":
			_send_lpc_cmd("gcube take %s" % fid)
		elif data.get("source") == "stash":
			var s_tab = data.get("tab", 1)
			var uuid = str(it.get("uuid", fid))
			_send_lpc_cmd("stash take %d %s" % [s_tab, uuid])

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and (data.get("source") == "pocket" or data.get("source") == "paperdoll" or data.get("source") == "cube" or data.get("source") == "stash"):
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		var it = data.get("item_data", {})
		var fid = it.get("file_id", "")
		if fid.is_empty():
			return
		if data.get("source") == "pocket":
			_on_pocket_action("out", fid)
		elif data.get("source") == "paperdoll":
			# 从纸娃娃槽位拖出到背包区域空白处：执行卸装 (gremove 带刷新)
			_send_lpc_cmd("gremove %s %d" % [fid, current_page])
		elif data.get("source") == "cube":
			_send_lpc_cmd("gcube take %s" % fid)
		elif data.get("source") == "stash":
			var s_tab = data.get("tab", 1)
			var uuid = str(it.get("uuid", fid))
			_send_lpc_cmd("stash take %d %s" % [s_tab, uuid])

func _on_pocket_action(action: String, file_id: String) -> void:
	# 向服务端发送 charm_bag in <file_id> 或 charm_bag out <file_id>
	_send_lpc_cmd("charm_bag %s %s" % [action, file_id])
	# 延时 0.2 秒主动刷新背包和人物属性帧
	await get_tree().create_timer(0.2).timeout
	_send_lpc_cmd("gbag %d" % current_page)
	_send_lpc_cmd("gscore")

func _send_lpc_cmd(cmd: String) -> void:
	print("[PlayerInventoryPanel] _send_lpc_cmd: ", cmd)
	command_sent.emit(cmd)
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw(cmd)

func _format_number(n: int) -> String:
	var s = str(n)
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

# ========== 多选分解 (Multi-select Salvage) ==========
func _on_multi_select_pressed() -> void:
	if not is_multiselect_mode:
		# 进入多选模式
		is_multiselect_mode = true
		selected_slots.clear()
		_update_multi_select_ui()
	else:
		# 处于多选模式
		if selected_slots.size() > 0:
			# 执行分解
			_execute_batch_salvage()
		else:
			# 退出多选模式
			_exit_multi_select_mode()

func _toggle_slot_selection(slot_idx: int) -> void:
	if not items_map.has(slot_idx):
		return
		
	var it = items_map[slot_idx]
	var in_pocket = bool(it.get("in_charm_bag", false))
	if in_pocket:
		print("[PlayerInventoryPanel] 小口袋中的护身符受系统保护，不可分解！")
		return
		
	if slot_idx in selected_slots:
		selected_slots.erase(slot_idx)
		if slot_idx < slots.size() and slots[slot_idx].has_method("set_selected"):
			slots[slot_idx].set_selected(false)
	else:
		selected_slots.append(slot_idx)
		if slot_idx < slots.size() and slots[slot_idx].has_method("set_selected"):
			slots[slot_idx].set_selected(true)
			
	_update_multi_select_ui()

func _update_multi_select_ui() -> void:
	if not btn_multi_select:
		return
	if is_multiselect_mode:
		var active_style = StyleBoxFlat.new()
		active_style.bg_color = Color(0.1, 0.55, 0.15, 1.0)
		active_style.border_width_left = 1
		active_style.border_width_top = 1
		active_style.border_width_right = 1
		active_style.border_width_bottom = 1
		active_style.border_color = Color(0.2, 0.85, 0.25, 1.0)
		active_style.corner_radius_top_left = 2
		active_style.corner_radius_top_right = 2
		active_style.corner_radius_bottom_right = 2
		active_style.corner_radius_bottom_left = 2
		btn_multi_select.add_theme_stylebox_override("normal", active_style)
		btn_multi_select.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		
		if selected_slots.size() > 0:
			btn_multi_select.text = "分解(%d)" % selected_slots.size()
		else:
			btn_multi_select.text = "取消"
	else:
		btn_multi_select.remove_theme_stylebox_override("normal")
		btn_multi_select.remove_theme_color_override("font_color")
		btn_multi_select.text = "多选"

func _exit_multi_select_mode() -> void:
	is_multiselect_mode = false
	for idx in selected_slots:
		if idx < slots.size() and slots[idx].has_method("set_selected"):
			slots[idx].set_selected(false)
	selected_slots.clear()
	_update_multi_select_ui()

func _execute_batch_salvage() -> void:
	if selected_slots.is_empty():
		_exit_multi_select_mode()
		return
		
	var fids: Array[String] = []
	var has_unique: bool = false
	var unique_item_data: Dictionary = {}
	
	for idx in selected_slots:
		if items_map.has(idx):
			var it = items_map[idx]
			var fid = str(it.get("file_id", ""))
			if not fid.is_empty():
				fids.append(fid)
				if str(it.get("quality", "")).to_lower() == "unique":
					has_unique = true
					unique_item_data = it
					
	if fids.is_empty():
		_exit_multi_select_mode()
		return
		
	# 尾参页码: 服务端分解后精准回推当前浏览页 (gxxxx 保页约定)
	var cmd = "gfenjie %s %d" % [";".join(fids), current_page]
	
	# 如果勾选了暗金且开启了二次确认，联动宿主控制器弹窗
	var host = _get_host_controller()
	var confirm_unique_enabled = true
	if host and host.has_node("%PickupSettingPanel"):
		var p_panel = host.get_node("%PickupSettingPanel")
		if p_panel.current_config:
			confirm_unique_enabled = bool(p_panel.current_config.get("confirm_unique", true))
			
	if has_unique and confirm_unique_enabled and host and host.has_node("%SalvageUniqueConfirmDialog"):
		var dlg = host.get_node("%SalvageUniqueConfirmDialog")
		dlg.prompt_confirm(unique_item_data, func(_unused):
			_send_lpc_cmd(cmd)
			_exit_multi_select_mode()
		)
	else:
		_send_lpc_cmd(cmd)
		_exit_multi_select_mode()
