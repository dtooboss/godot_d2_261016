extends PanelContainer
class_name AFK_LittlePocketPanel



signal item_hovered(item_data: Dictionary, global_pos: Vector2)
signal item_unhovered()
signal pocket_action_requested(action: String, file_id: String) # "in" 或 "out"

@onready var grid_container: GridContainer = %GridContainer
@onready var title_label: Label = %TitleLabel
@onready var btn_close: Button = %BtnClose
@onready var hint_label: RichTextLabel = %HintLabel

const COLS: int = 4
const ROWS: int = 10
const TOTAL_SLOTS: int = COLS * ROWS # 40格

var slots: Array[Button] = []
var items_map: Dictionary = {}
var max_slots: int = 40
var used_slots: int = 0

func _ready() -> void:
	_init_grid()
	if btn_close:
		btn_close.pressed.connect(close)

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
		btn.slot_type = "pocket"
		btn.slot_index = i
		
		# 暗黑2经典风格格子
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.07, 0.96)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.24, 0.22, 0.18, 0.8)
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
		btn.mouse_exited.connect(_on_slot_unhovered)
		btn.gui_input.connect(_on_slot_gui_input.bind(i, btn))
		
		grid_container.add_child(btn)
		slots.append(btn)

func open() -> void:
	show()

func close() -> void:
	hide()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# 渲染小口袋中的物品列表
func render_pocket_items(pocket_items: Array, current_used: int, total_max: int = 40) -> void:
	used_slots = current_used
	max_slots = total_max
	
	if title_label:
		title_label.text = "小口袋 (" + str(used_slots) + "/" + str(max_slots) + ")"
		
	items_map.clear()
	for btn in slots:
		btn.icon = null
		btn.tooltip_text = ""
		if btn.has_method("set_slot_quality"):
			btn.set_slot_quality("")
		if btn.has_method("set_slot_sockets"):
			btn.set_slot_sockets(0, [])
		
	for i in range(pocket_items.size()):
		if i >= slots.size():
			break
		var it = pocket_items[i]
		if not it is Dictionary:
			continue
			
		items_map[i] = it
		var btn = slots[i]
		if btn.has_method("set_slot_quality"):
			btn.set_slot_quality(str(it.get("quality", "magic")))
		if btn.has_method("set_slot_sockets"):
			var s_cnt = AnsiHelper.to_safe_int(it.get("sockets"), 0)
			var in_list = it.get("inlays", [])
			btn.set_slot_sockets(s_cnt, in_list if in_list is Array else [])
		if it.has("icon_texture"):
			btn.icon = it["icon_texture"]
		elif it.has("icon"):
			var tex = AnsiHelper.load_item_texture(it["icon"])
			if tex:
				btn.icon = tex
				it["icon_texture"] = tex

func _on_slot_hovered(slot_idx: int, btn: Button) -> void:
	if items_map.has(slot_idx):
		item_hovered.emit(items_map[slot_idx], btn.global_position)

func _on_slot_unhovered() -> void:
	item_unhovered.emit()

func _on_slot_gui_input(event: InputEvent, slot_idx: int, _btn: Button = null) -> void:
	if event is InputEventMouseButton:
		# 鼠标右键：直接移出小口袋存入主背包
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if items_map.has(slot_idx):
				var it = items_map[slot_idx]
				var fid = it.get("file_id", "")
				if not fid.is_empty():
					pocket_action_requested.emit("out", fid)

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
		"source": "pocket",
		"slot_idx": slot_idx,
		"item_data": it
	}

func can_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> bool:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		return bool(it.get("is_charm", false)) or int(it.get("is_charm", 0)) == 1
	return false

func on_slot_drop_data(_slot_type: String, _slot_idx: int, data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		var is_charm = bool(it.get("is_charm", false)) or int(it.get("is_charm", 0)) == 1
		if not is_charm:
			return
		var fid = it.get("file_id", "")
		if not fid.is_empty():
			pocket_action_requested.emit("in", fid)

# 允许直接拖到小口袋面板空白处（仅限护身符）
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		return bool(it.get("is_charm", false)) or int(it.get("is_charm", 0)) == 1
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		var is_charm = bool(it.get("is_charm", false)) or int(it.get("is_charm", 0)) == 1
		if not is_charm:
			return
		var fid = it.get("file_id", "")
		if not fid.is_empty():
			pocket_action_requested.emit("in", fid)
