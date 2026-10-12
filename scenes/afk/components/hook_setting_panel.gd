extends Control
class_name AFK_HookSettingPanel

signal settings_saved(config: Dictionary)

@onready var btn_close: Button = %BtnClose
@onready var chk_auto_next: CheckBox = %ChkAutoNext
@onready var potion_container: HBoxContainer = %PotionSlotsContainer
@onready var slider_potion_pct: HSlider = %SliderPotionPct
@onready var label_potion_pct: Label = %LabelPotionPct
@onready var btn_save: Button = %BtnSave
@onready var btn_cancel: Button = %BtnCancel

# 4 个药水槽位配置 [code1, code2, code3, code4]
var potion_slots: Array[String] = ["", "", "", ""]
var slot_controls: Array[Control] = []

const POTION_DEFS = {
	"hp1": { "name": "轻微治疗药水", "icon": "res://assets/items/misc/potion/lesser_healing_potion.lowend.png" },
	"hp2": { "name": "次级治疗药水", "icon": "res://assets/items/misc/potion/light_healing_potion.lowend.png" },
	"hp3": { "name": "治疗药水", "icon": "res://assets/items/misc/potion/healing_potion.lowend.png" },
	"hp4": { "name": "强效治疗药水", "icon": "res://assets/items/misc/potion/greater_healing_potion.lowend.png" },
	"hp5": { "name": "超级治疗药水", "icon": "res://assets/items/misc/potion/full_healing_potion.lowend.png" },
	"mp1": { "name": "轻微法力药水", "icon": "res://assets/items/misc/potion/lesser_mana_potion.lowend.png" },
	"mp2": { "name": "次级法力药水", "icon": "res://assets/items/misc/potion/light_mana_potion.lowend.png" },
	"mp3": { "name": "法力药水", "icon": "res://assets/items/misc/potion/mana_potion.lowend.png" },
	"mp4": { "name": "强效法力药水", "icon": "res://assets/items/misc/potion/greater_mana_potion.lowend.png" },
	"mp5": { "name": "超级法力药水", "icon": "res://assets/items/misc/potion/full_mana_potion.lowend.png" },
	"rvs": { "name": "恢复活力药剂", "icon": "res://assets/items/misc/potion/rejuv_potion.lowend.png" },
	"rvl": { "name": "全面恢复活力药剂", "icon": "res://assets/items/misc/potion/full_rejuv_potion.lowend.png" },
}

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 160
	
	if btn_close:
		btn_close.pressed.connect(hide_panel)
	if btn_cancel:
		btn_cancel.pressed.connect(hide_panel)
	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)
	if slider_potion_pct:
		slider_potion_pct.value_changed.connect(_on_slider_potion_pct_changed)
		
	_setup_potion_slots()
	_register_network_listener()

func _setup_potion_slots() -> void:
	if not potion_container:
		potion_container = get_node_or_null("%PotionSlotsContainer")
	if not potion_container:
		return
		
	slot_controls.clear()
	for i in range(4):
		var slot_node = potion_container.get_node_or_null("Slot%d" % (i + 1))
		if slot_node:
			slot_controls.append(slot_node)
			_bind_slot_drag_drop(slot_node, i)
			_update_slot_display(i)

func _bind_slot_drag_drop(slot: Control, idx: int) -> void:
	slot.set_meta("slot_index", idx)
	# 自定义拖拽判定与接收
	slot.set_script(preload("res://scenes/afk/components/hook_potion_slot.gd"))
	if slot.has_signal("slot_dropped"):
		slot.slot_dropped.connect(func(code): set_slot_potion(idx, code))
	if slot.has_signal("slot_cleared"):
		slot.slot_cleared.connect(func(): clear_slot_potion(idx))

func set_slot_potion(idx: int, p_code: String) -> void:
	if idx >= 0 and idx < 4:
		potion_slots[idx] = p_code
		_update_slot_display(idx)

func clear_slot_potion(idx: int) -> void:
	if idx >= 0 and idx < 4:
		potion_slots[idx] = ""
		_update_slot_display(idx)

func _update_slot_display(idx: int) -> void:
	if idx < 0 or idx >= slot_controls.size():
		return
	var slot = slot_controls[idx]
	var code = potion_slots[idx] if idx < potion_slots.size() else ""
	
	var icon_rect = slot.get_node_or_null("Icon") as TextureRect
	var label_num = slot.get_node_or_null("LabelNum") as Label
	
	if label_num:
		label_num.text = str(idx + 1)
		
	if POTION_DEFS.has(code):
		var info = POTION_DEFS[code]
		if icon_rect:
			if ResourceLoader.exists(info["icon"]):
				icon_rect.texture = load(info["icon"])
				icon_rect.show()
			else:
				icon_rect.hide()
		slot.tooltip_text = "【%s】\n优先序号: %d\n(右键点击移除)" % [info["name"], idx + 1]
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.hide()
		slot.tooltip_text = "【槽位 %d】空\n可从背包拖入药水\n(生命/法力/活力药水)" % (idx + 1)

func show_panel() -> void:
	_register_network_listener()
	_sync_from_server()
	show()

func hide_panel() -> void:
	hide()

func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func _sync_from_server() -> void:
	_send_lpc_cmd("afkset")

func _register_network_listener() -> void:
	var net = _get_net_client()
	if net and net.has_signal("json_frame_received"):
		if not net.json_frame_received.is_connected(_on_json_frame_received):
			net.json_frame_received.connect(_on_json_frame_received)

func _on_json_frame_received(type: String, data: Variant) -> void:
	if type == "afk_settings" and data is Dictionary:
		_apply_settings_from_server(data)

func _apply_settings_from_server(data: Dictionary) -> void:
	if not chk_auto_next:
		chk_auto_next = get_node_or_null("%ChkAutoNext")
	if not slider_potion_pct:
		slider_potion_pct = get_node_or_null("%SliderPotionPct")
	if not label_potion_pct:
		label_potion_pct = get_node_or_null("%LabelPotionPct")
	if slot_controls.is_empty():
		_setup_potion_slots()

	var auto_next = bool(data.get("auto_next_stage", 0))
	if chk_auto_next:
		chk_auto_next.button_pressed = auto_next
		
	var pots_str = str(data.get("hook_potions", ""))
	potion_slots = ["", "", "", ""]
	if not pots_str.is_empty():
		var parts = pots_str.split(",", false)
		for i in range(mini(parts.size(), 4)):
			var c = parts[i].strip_edges().to_lower()
			potion_slots[i] = c
			
	for i in range(4):
		_update_slot_display(i)

	# 喝药阈值处理 (后端推送，默认 50%)
	var pot_pct = int(data.get("auto_potion_pct", 50))
	if pot_pct <= 0:
		pot_pct = 50
	if slider_potion_pct:
		slider_potion_pct.value = pot_pct
	_on_slider_potion_pct_changed(pot_pct)

func _on_slider_potion_pct_changed(val: float) -> void:
	if label_potion_pct:
		label_potion_pct.text = "低于 %d%% 时喝药" % int(val)

func _on_save_pressed() -> void:
	var auto_next = 1 if (chk_auto_next and chk_auto_next.button_pressed) else 0
	var clean_pots: Array[String] = []
	for p in potion_slots:
		if not p.is_empty():
			clean_pots.append(p)
			
	var pots_arg = ",".join(clean_pots)
	if pots_arg.is_empty():
		pots_arg = "clear"
		
	var target_pct = int(slider_potion_pct.value) if slider_potion_pct else 50

	# 优先通过玩家建议的 set 指令保存环境变量
	_send_lpc_cmd("set auto_potion_pct %d" % target_pct)
	# 同时通过 afkset 保持挂机设置帧同步
	_send_lpc_cmd("afkset save %d %s %d" % [auto_next, pots_arg, target_pct])

	settings_saved.emit({
		"auto_next_stage": auto_next,
		"hook_potions": clean_pots,
		"auto_potion_pct": target_pct
	})
	hide_panel()

func _send_lpc_cmd(cmd: String) -> void:
	var net = _get_net_client()
	if net and net.is_connected:
		net.send_raw(cmd)

func _get_net_client() -> Node:
	if Engine.has_singleton("NetworkClient"):
		return Engine.get_singleton("NetworkClient")
	if has_node("/root/NetworkClient"):
		return get_node("/root/NetworkClient")
	return null

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()
