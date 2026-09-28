extends Control

## 暗黑破坏神2 装备与物品存储体系全能控制器 (InventoryController)
## 双轨融合架构 (方案 B)：
## 1. 随身装备纸娃娃与40格护身符激活包 (LPC: arm + charm_bag)
## 2. 掉落战利品暂存库与大容量管理仓 (LPC: inventory) - 吸收 AFKnew 战利品管理体验
## 3. 深度支持 LPC 图标协议：\x1b[i:<path>] 内嵌图标与 \x1b[img:<path>] 装备大图

signal closed

# 标签页控制
@onready var btn_tab_charm: Button = $PanelContainer/MarginContainer/VBox/TabHBox/BtnTabCharmBag
@onready var btn_tab_stash: Button = $PanelContainer/MarginContainer/VBox/TabHBox/BtnTabDropStash
@onready var charm_bag_view: Control = $PanelContainer/MarginContainer/VBox/ViewsStack/CharmBagView
@onready var drop_stash_view: Control = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView
@onready var btn_close: Button = $PanelContainer/MarginContainer/VBox/TopBar/BtnClose

# 随身背包视图组件 (charm_bag + paperdoll)
@onready var slots_container: Control = $PanelContainer/MarginContainer/VBox/ViewsStack/CharmBagView/PaperdollSlots
@onready var charms_grid: GridContainer = $PanelContainer/MarginContainer/VBox/ViewsStack/CharmBagView/CharmsGrid
@onready var charm_load_label: Label = $PanelContainer/MarginContainer/VBox/ViewsStack/CharmBagView/CharmLoadLabel

# 掉落战利品仓视图组件 (inventory)
@onready var stash_desc_label: RichTextLabel = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView/VBox/StashDescLabel
@onready var btn_sort_stash: Button = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView/VBox/FilterBar/BtnSortStash
@onready var filter_hbox: HBoxContainer = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView/VBox/FilterBar/FilterScroll/FilterHBox
@onready var items_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView/VBox/ItemsScroll/ItemsVBox
@onready var page_hbox: HBoxContainer = $PanelContainer/MarginContainer/VBox/ViewsStack/DropStashView/VBox/PageHBox

# 物品浮动详情与交互菜单
@onready var tooltip_box: PanelContainer = $TooltipBox
@onready var item_large_icon: TextureRect = $TooltipBox/Margin/VBox/IconCenter/ItemLargeIcon
@onready var icon_center: CenterContainer = $TooltipBox/Margin/VBox/IconCenter
@onready var lbl_tooltip_content: RichTextLabel = $TooltipBox/Margin/VBox/RichTextLabel
@onready var action_hbox: HBoxContainer = $TooltipBox/Margin/VBox/ActionHBox
@onready var btn_primary: Button = $TooltipBox/Margin/VBox/ActionHBox/BtnActionPrimary
@onready var btn_secondary: Button = $TooltipBox/Margin/VBox/ActionHBox/BtnActionSecondary

# 纸娃娃 10 大装备部位映射 (像素级吻合暗黑2官方 509x700 石雕底板)
const PAPERDOLL_CONFIG = {
	"head": { "pos": Vector2(206, 7), "size": Vector2(96, 96), "default": "res://assets/ui/inventory/inventory_paperdoll_headarmor.png", "title": "头部" },
	"neck": { "pos": Vector2(328, 96), "size": Vector2(48, 48), "default": "res://assets/ui/inventory/inventory_paperdoll_amulet.png", "title": "项链" },
	"cloth": { "pos": Vector2(206, 110), "size": Vector2(96, 145), "default": "res://assets/ui/inventory/inventory_paperdoll_chestarmor.png", "title": "胸甲" },
	"belt": { "pos": Vector2(206, 273), "size": Vector2(96, 48), "default": "res://assets/ui/inventory/inventory_paperdoll_belt.png", "title": "腰带" },
	"weapon": { "pos": Vector2(13, 70), "size": Vector2(96, 194), "default": "res://assets/ui/inventory/inventory_paperdoll_weapon.png", "title": "主手武器" },
	"shield": { "pos": Vector2(400, 70), "size": Vector2(96, 194), "default": "res://assets/ui/inventory/inventory_paperdoll_shield.png", "title": "副手盾牌" },
	"gloves": { "pos": Vector2(13, 273), "size": Vector2(96, 96), "default": "res://assets/ui/inventory/inventory_paperdoll_glove.png", "title": "手套" },
	"boots": { "pos": Vector2(400, 273), "size": Vector2(96, 96), "default": "res://assets/ui/inventory/inventory_paperdoll_boots.png", "title": "靴子" },
	"ring1": { "pos": Vector2(130, 273), "size": Vector2(48, 48), "default": "res://assets/ui/inventory/inventory_paperdoll_ring.png", "title": "左戒" },
	"ring2": { "pos": Vector2(330, 273), "size": Vector2(48, 48), "default": "res://assets/ui/inventory/inventory_paperdoll_ring.png", "title": "右戒" }
}

var paperdoll_slot_nodes = {}
var current_arm_data = {}
var active_tab_index = 0 # 0: charm_bag, 1: drop_stash
var current_stash_filter_cmd = "inventory" # 记住当前分类指令，用于一键整理

func _ready() -> void:
	visible = false
	tooltip_box.visible = false
	icon_center.visible = false
	btn_close.pressed.connect(close_window)
	
	btn_tab_charm.pressed.connect(func(): _switch_tab(0))
	btn_tab_stash.pressed.connect(func(): _switch_tab(1))
	btn_sort_stash.pressed.connect(_on_sort_stash_pressed)
	
	_init_paperdoll_slots()
	_init_charms_grid()
	
	NetworkClient.json_frame_received.connect(_on_json_frame_received)

func _switch_tab(tab_idx: int) -> void:
	active_tab_index = tab_idx
	tooltip_box.visible = false
	
	if active_tab_index == 0:
		btn_tab_charm.button_pressed = true
		btn_tab_stash.button_pressed = false
		charm_bag_view.visible = true
		drop_stash_view.visible = false
		NetworkClient.send_raw("arm")
	else:
		btn_tab_charm.button_pressed = false
		btn_tab_stash.button_pressed = true
		charm_bag_view.visible = false
		drop_stash_view.visible = true
		NetworkClient.send_raw(current_stash_filter_cmd)

func _on_sort_stash_pressed() -> void:
	NetworkClient.send_raw(current_stash_filter_cmd)

func open_window() -> void:
	visible = true
	_switch_tab(active_tab_index)

func close_window() -> void:
	visible = false
	tooltip_box.visible = false
	closed.emit()

func toggle_window() -> void:
	if visible:
		close_window()
	else:
		open_window()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_I:
			toggle_window()
		elif event.keycode == KEY_ESCAPE and visible:
			close_window()

func _init_paperdoll_slots() -> void:
	for slot_name in PAPERDOLL_CONFIG:
		var cfg = PAPERDOLL_CONFIG[slot_name]
		var slot_btn = TextureButton.new()
		slot_btn.name = slot_name
		slot_btn.position = cfg.pos
		slot_btn.custom_minimum_size = cfg.size
		slot_btn.size = cfg.size
		slot_btn.ignore_texture_size = true
		slot_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var def_tex = load(cfg.default)
		if def_tex:
			slot_btn.texture_normal = def_tex
			slot_btn.modulate = Color(1, 1, 1, 0.45)
			
		slot_btn.mouse_entered.connect(func(): _on_slot_hover(slot_name, true))
		slot_btn.pressed.connect(func(): _on_slot_click(slot_name))
		
		slots_container.add_child(slot_btn)
		paperdoll_slot_nodes[slot_name] = slot_btn

func _init_charms_grid() -> void:
	for c in charms_grid.get_children():
		c.queue_free()
	
	for i in range(40):
		var cell = PanelContainer.new()
		cell.custom_minimum_size = Vector2(46, 46)
		charms_grid.add_child(cell)

## 处理服务端下发数据帧
func _on_json_frame_received(type: String, data: Variant) -> void:
	# 1. 随身 40 格与纸娃娃 (arm)
	if type == "d2_arm" and data is Dictionary:
		current_arm_data = data
		_render_arm_data(data)
		
	# 2. 掉落暂存仓描述头 (inventory -> J_INTERACTION)
	elif type == "interaction" and data is Dictionary:
		var desc = str(data.get("desc", ""))
		if not desc.is_empty():
			stash_desc_label.text = AnsiHelper.to_bbcode(desc)
			
	# 3. 掉落暂存仓分类与物品 (inventory -> J_ACTIONS)
	elif type == "actions" and data is Dictionary:
		var idx = int(data.get("index", 1))
		var list = data.get("list", [])
		if idx == 1 and list is Array:
			_render_stash_filters(list)
		elif idx == 2 and list is Array:
			_render_stash_items_and_pages(list)
			
	# 4. 点击物品后服务端返回的装备面板/描述 (look <item> -> J_PANEL)
	elif type == "panel" and data is Dictionary:
		var desc = str(data.get("desc", ""))
		if not desc.is_empty() and visible:
			_render_panel_card(desc)

func _render_panel_card(desc: String) -> void:
	# 提取卡片大图与孔位 \x1b[img:<path>?sock=4&inlays=...]
	var img_info = AnsiHelper.extract_img_info(desc)
	if not img_info.path.is_empty():
		var large_tex = AnsiHelper.load_item_texture(img_info.path)
		if large_tex:
			item_large_icon.texture = large_tex
			icon_center.visible = true
		else:
			icon_center.visible = false
	else:
		icon_center.visible = false
		
	lbl_tooltip_content.text = AnsiHelper.to_bbcode(desc)
	tooltip_box.visible = true

## -------------------------------------------------------------
## 随身背包 (charm_bag) 与纸娃娃渲染逻辑
## -------------------------------------------------------------
func _render_arm_data(data: Dictionary) -> void:
	var paperdoll = data.get("paperdoll", {})
	if paperdoll is Dictionary:
		for slot_name in PAPERDOLL_CONFIG:
			var slot_node = paperdoll_slot_nodes.get(slot_name)
			if not slot_node: continue
			
			var equip_info = paperdoll.get(slot_name)
			if equip_info is Dictionary and not equip_info.is_empty():
				var raw_icon = str(equip_info.get("icon", ""))
				var icon_res = AnsiHelper.load_item_texture(raw_icon)
				if icon_res:
					slot_node.texture_normal = icon_res
					slot_node.modulate = Color(1, 1, 1, 1.0)
				else:
					var def_tex = load(PAPERDOLL_CONFIG[slot_name].default)
					if def_tex:
						slot_node.texture_normal = def_tex
						slot_node.modulate = Color(1, 1, 1, 0.7)
			else:
				var def_tex = load(PAPERDOLL_CONFIG[slot_name].default)
				if def_tex:
					slot_node.texture_normal = def_tex
					slot_node.modulate = Color(1, 1, 1, 0.35)
	
	var charms = data.get("charms", [])
	var used_slots = int(data.get("used_slots", 0))
	var max_slots = int(data.get("max_slots", 40))
	charm_load_label.text = "随身护符包负载 (charm_bag): %d / %d 格" % [used_slots, max_slots]
	
	for c in charms_grid.get_children():
		c.queue_free()
		
	var rendered_cells = 0
	if charms is Array:
		for item in charms:
			if not item is Dictionary: continue
			var sz = int(item.get("size", 1))
			var item_btn = TextureButton.new()
			item_btn.custom_minimum_size = Vector2(46, 46 * sz)
			item_btn.ignore_texture_size = true
			item_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			
			var raw_icon = str(item.get("icon", ""))
			var icon_res = AnsiHelper.load_item_texture(raw_icon)
			if icon_res:
				item_btn.texture_normal = icon_res
			else:
				# 护符回退图标
				var def_charm_icon = AnsiHelper.load_item_texture("items/misc/charm/charm_small.lowend.png")
				if def_charm_icon:
					item_btn.texture_normal = def_charm_icon
				
			var quality = str(item.get("quality", "normal"))
			item_btn.modulate = _get_quality_color(quality)
			
			item_btn.mouse_entered.connect(func(): _show_item_tooltip(item, "charm_bag"))
			item_btn.pressed.connect(func(): _show_item_tooltip(item, "charm_bag"))
			
			charms_grid.add_child(item_btn)
			rendered_cells += sz
			
	while rendered_cells < 40:
		var empty_cell = Panel.new()
		empty_cell.custom_minimum_size = Vector2(46, 46)
		empty_cell.modulate = Color(1, 1, 1, 0.08)
		charms_grid.add_child(empty_cell)
		rendered_cells += 1

## -------------------------------------------------------------
## 掉落战利品暂存仓 (inventory) 渲染逻辑 (方案 B - AFKnew 战利品卡片)
## -------------------------------------------------------------
func _render_stash_filters(filters_list: Array) -> void:
	for c in filter_hbox.get_children():
		c.queue_free()
		
	for f in filters_list:
		if not f is Dictionary: continue
		var label_str = str(f.get("label", ""))
		var cmd_str = str(f.get("cmd", ""))
		var btn = Button.new()
		btn.text = AnsiHelper.to_plain_text(label_str)
		btn.custom_minimum_size = Vector2(65, 30)
		btn.pressed.connect(func():
			current_stash_filter_cmd = cmd_str
			NetworkClient.send_raw(cmd_str)
		)
		filter_hbox.add_child(btn)

func _render_stash_items_and_pages(items_and_pages: Array) -> void:
	for c in items_vbox.get_children():
		c.queue_free()
	for c in page_hbox.get_children():
		c.queue_free()
		
	for item in items_and_pages:
		if not item is Dictionary: continue
		var label_str = str(item.get("label", ""))
		var cmd_str = str(item.get("cmd", ""))
		
		# 判断是翻页按钮还是物品条目
		if "页" in label_str or "上一页" in label_str or "下一页" in label_str:
			var p_btn = Button.new()
			p_btn.text = AnsiHelper.to_plain_text(label_str)
			p_btn.custom_minimum_size = Vector2(90, 32)
			p_btn.pressed.connect(func(): NetworkClient.send_raw(cmd_str))
			page_hbox.add_child(p_btn)
		else:
			# 掉落物品卡片条目 (支持原生解析 \x1b[i:...] 图标协议)
			var card = _create_stash_item_card(label_str, cmd_str)
			items_vbox.add_child(card)

func _create_stash_item_card(label_str: String, cmd_str: String) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 水平内部容器
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	
	# 左侧微边距
	var left_pad = Control.new()
	left_pad.custom_minimum_size = Vector2(4, 0)
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_pad)
	
	# 1. 优先提取 LPC 协议图标 \x1b[i:<icon_path>]
	var embedded_icon_path = AnsiHelper.extract_icon_path(label_str)
	var icon_tex: Texture2D = null
	if not embedded_icon_path.is_empty():
		icon_tex = AnsiHelper.load_item_texture(embedded_icon_path)
		
	# 2. 若无则进行关键词智能回退
	if not icon_tex:
		icon_tex = _detect_fallback_icon(label_str)
		
	if icon_tex:
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(34, 34)
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex_rect)
	else:
		var emoji_lbl = Label.new()
		emoji_lbl.text = "📦"
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(emoji_lbl)
		
	# 富文本名称 (剥除 \x1b[i:...] 之后，纯净展现 ANSI 彩色品质)
	var rich_lbl = RichTextLabel.new()
	rich_lbl.bbcode_enabled = true
	rich_lbl.text = AnsiHelper.to_bbcode(label_str)
	rich_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rich_lbl.fit_content = true
	rich_lbl.scroll_active = false
	rich_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rich_lbl)
	
	btn.add_child(hbox)
	
	# 点击卡片：呼出快捷菜单并向服务端发送 look
	btn.pressed.connect(func():
		_show_stash_item_menu(label_str, cmd_str, icon_tex)
		NetworkClient.send_raw(cmd_str)
	)
	
	return btn

func _detect_fallback_icon(label_str: String) -> Texture2D:
	var s = label_str.to_lower()
	if "弓" in s or "弩" in s:
		return AnsiHelper.load_item_texture("items/weapon/bow/short_bow.lowend.png")
	elif "剑" in s or "刀" in s:
		return AnsiHelper.load_item_texture("items/weapon/sword/short_sword.lowend.png")
	elif "斧" in s:
		return AnsiHelper.load_item_texture("items/weapon/axe/hand_axe.lowend.png")
	elif "杖" in s:
		return AnsiHelper.load_item_texture("items/weapon/staff/short_staff.lowend.png")
	elif "盾" in s:
		return AnsiHelper.load_item_texture("items/armor/shield/large_shield.lowend.png")
	elif "甲" in s or "袍" in s:
		return AnsiHelper.load_item_texture("items/armor/armor/leather_armor.lowend.png")
	elif "头" in s or "盔" in s or "冠" in s:
		return AnsiHelper.load_item_texture("items/armor/helmet/helm.lowend.png")
	elif "靴" in s or "鞋" in s:
		return AnsiHelper.load_item_texture("items/armor/boot/leather_boots.lowend.png")
	elif "手套" in s or "护手" in s:
		return AnsiHelper.load_item_texture("items/armor/glove/gloves_l.lowend.png")
	elif "带" in s:
		return AnsiHelper.load_item_texture("items/armor/belt/belt_m.lowend.png")
	elif "戒" in s:
		return AnsiHelper.load_item_texture("items/misc/ring/ring1.lowend.png")
	elif "链" in s:
		return AnsiHelper.load_item_texture("items/misc/amulet/amulet1.lowend.png")
	elif "护身符" in s or "护符" in s:
		return AnsiHelper.load_item_texture("items/misc/charm/charm_small.lowend.png")
	elif "符文" in s:
		return AnsiHelper.load_item_texture("items/misc/rune/el_rune.lowend.png")
	return null

func _show_stash_item_menu(label_str: String, look_cmd: String, icon_tex: Texture2D) -> void:
	if icon_tex:
		item_large_icon.texture = icon_tex
		icon_center.visible = true
	else:
		icon_center.visible = false
		
	var bb_title = AnsiHelper.to_bbcode(label_str)
	lbl_tooltip_content.text = "[center][b]【 战利品掉落 】[/b]\n%s\n\n[color=#94a3b8][ 正在检索暗黑魔法词缀... ][/color][/center]" % bb_title
	action_hbox.visible = true
	
	# 从 look 指令提取物品标识 target
	var target = look_cmd.replace("look ", "").strip_edges()
	
	for conn in btn_primary.pressed.get_connections():
		btn_primary.pressed.disconnect(conn.callable)
	for conn in btn_secondary.pressed.get_connections():
		btn_secondary.pressed.disconnect(conn.callable)
		
	btn_primary.text = "放入随身背包"
	btn_primary.pressed.connect(func():
		NetworkClient.send_raw("charm_bag in " + target)
		await get_tree().create_timer(0.25).timeout
		NetworkClient.send_raw(current_stash_filter_cmd)
	)
	
	btn_secondary.visible = true
	btn_secondary.text = "穿戴 / 使用"
	btn_secondary.pressed.connect(func():
		NetworkClient.send_raw("wear " + target)
		NetworkClient.send_raw("wield " + target)
		NetworkClient.send_raw("use " + target)
		await get_tree().create_timer(0.25).timeout
		NetworkClient.send_raw(current_stash_filter_cmd)
	)
	
	tooltip_box.visible = true

func _on_slot_hover(slot_name: String, is_hover: bool) -> void:
	if not is_hover: return
	_on_slot_click(slot_name)

func _on_slot_click(slot_name: String) -> void:
	var paperdoll = current_arm_data.get("paperdoll", {})
	if paperdoll is Dictionary and paperdoll.has(slot_name):
		var item = paperdoll[slot_name]
		if item is Dictionary and not item.is_empty():
			_show_item_tooltip(item, "paperdoll")
			return
			
	icon_center.visible = false
	var title = PAPERDOLL_CONFIG[slot_name].title
	lbl_tooltip_content.text = "[center][color=#94a3b8]【 %s 槽位 】[/color]\n[color=#64748b]未装备物品[/color][/center]" % title
	action_hbox.visible = false
	tooltip_box.visible = true

func _show_item_tooltip(item: Dictionary, source: String) -> void:
	var raw_name = str(item.get("name", "神秘物品"))
	var desc = str(item.get("desc", ""))
	var file_id = str(item.get("file", item.get("id", "")))
	var raw_icon = str(item.get("icon", ""))
	
	var item_tex = AnsiHelper.load_item_texture(raw_icon)
	if item_tex:
		item_large_icon.texture = item_tex
		icon_center.visible = true
	else:
		icon_center.visible = false
		
	var bb_name = AnsiHelper.to_bbcode(raw_name)
	var content = "[center][b]%s[/b][/center]\n" % bb_name
	if not desc.is_empty():
		content += AnsiHelper.to_bbcode(desc)
		
	lbl_tooltip_content.text = content
	action_hbox.visible = true
	
	for conn in btn_primary.pressed.get_connections():
		btn_primary.pressed.disconnect(conn.callable)
	for conn in btn_secondary.pressed.get_connections():
		btn_secondary.pressed.disconnect(conn.callable)
		
	if source == "paperdoll":
		btn_primary.text = "卸下装备"
		btn_primary.pressed.connect(func():
			NetworkClient.send_raw("unequip " + file_id)
			await get_tree().create_timer(0.25).timeout
			NetworkClient.send_raw("arm")
		)
		btn_secondary.visible = false
	else:
		btn_primary.text = "移出随身背包"
		btn_primary.pressed.connect(func():
			NetworkClient.send_raw("charm_bag out " + file_id)
			await get_tree().create_timer(0.25).timeout
			NetworkClient.send_raw("arm")
		)
		
		btn_secondary.visible = true
		btn_secondary.text = "穿戴 / 使用"
		btn_secondary.pressed.connect(func():
			NetworkClient.send_raw("wear " + file_id)
			NetworkClient.send_raw("wield " + file_id)
			NetworkClient.send_raw("use " + file_id)
			await get_tree().create_timer(0.25).timeout
			NetworkClient.send_raw("arm")
		)
		
	tooltip_box.visible = true

func _get_quality_color(quality: String) -> Color:
	match quality.to_lower():
		"unique", "暗金":
			return Color(0.95, 0.85, 0.5)
		"set", "套装":
			return Color(0.1, 0.95, 0.2)
		"rare", "稀有":
			return Color(0.95, 0.95, 0.2)
		"magic", "魔法":
			return Color(0.4, 0.6, 0.95)
		"crafted", "手工":
			return Color(1.0, 0.6, 0.1)
		_:
			return Color(1, 1, 1, 1)
