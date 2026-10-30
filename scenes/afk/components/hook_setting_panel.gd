extends Control
class_name AFK_HookSettingPanel

signal settings_saved(config: Dictionary)

@onready var btn_close: Button = %BtnClose
@onready var chk_auto_next: CheckBox = %ChkAutoNext
@onready var potion_container: HBoxContainer = %PotionSlotsContainer
@onready var auto_skill_container: HBoxContainer = %AutoSkillSlotsContainer
@onready var slider_potion_pct: HSlider = %SliderPotionPct
@onready var label_potion_pct: Label = %LabelPotionPct
@onready var btn_save: Button = %BtnSave
@onready var btn_cancel: Button = %BtnCancel

# 4 个药水槽位配置 [code1, code2, code3, code4]
var potion_slots: Array[String] = ["", "", "", ""]
var slot_controls: Array[Control] = []

# 4 个自动巡检技能槽位配置 [sk1, sk2, sk3, sk4]
var auto_skill_slots: Array[String] = ["", "", "", ""]
var auto_slot_controls: Array[Control] = []

# 技能选择浮窗菜单
var _skill_picker_menu: PopupMenu = null
var _picking_slot_index: int = -1

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

# 全职业可自律巡检技能元数据定义与互斥组
const AUTO_SKILL_DEFS: Dictionary = {
	# 法师 (sor)
	"frozen_armor": { "name": "冰封甲", "class": "sor", "group": "sor_armor", "icon": "res://assets/skills/sor/04_frozen_armor.png", "desc": "提升防御力，冻结近战攻击者" },
	"shiver_armor": { "name": "碎冰甲", "class": "sor", "group": "sor_armor", "icon": "res://assets/skills/sor/14_shiver_armor.png", "desc": "提升防御力，反弹冰冷伤害与减速" },
	"chilling_armor": { "name": "寒冰甲", "class": "sor", "group": "sor_armor", "icon": "res://assets/skills/sor/24_chilling_armor.png", "desc": "大幅提升防御力，反弹远程魔法飞弹" },
	"energy_shield": { "name": "能量护盾", "class": "sor", "group": "", "icon": "res://assets/skills/sor/22_energy_shield.png", "desc": "以法力值吸收承受的伤害" },
	"thunder_storm": { "name": "雷暴术", "class": "sor", "group": "", "icon": "res://assets/skills/sor/21_thunder_storm.png", "desc": "头顶雷云天罚，自动天降雷霆劈击敌怪" },
	"enchant": { "name": "强化", "class": "sor", "group": "", "icon": "res://assets/skills/sor/16_enchant.png", "desc": "为武器附加巨额火焰伤害与命中率" },
	# 圣骑士 (pal)
	"holy_shield": { "name": "神圣之盾", "class": "pal", "group": "", "icon": "res://assets/skills/pal/21_holy_shield.png", "desc": "大幅提高盾牌格挡几率与防御力" },
	# 野蛮人 (bar)
	"battle_command": { "name": "战斗指挥", "class": "bar", "group": "", "icon": "res://assets/skills/bar/29_battle_command.png", "desc": "全队所有技能等级提升 1 级" },
	"battle_orders": { "name": "战斗号令", "class": "bar", "group": "", "icon": "res://assets/skills/bar/23_battle_orders.png", "desc": "极大提升最大生命值与法力值" },
	"shout": { "name": "大吼", "class": "bar", "group": "", "icon": "res://assets/skills/bar/12_shout.png", "desc": "巨幅提升自身与小队的防御力" },
	# 死灵法师 (nec)
	"bone_armor": { "name": "白骨装甲", "class": "nec", "group": "", "icon": "res://assets/skills/nec/02_bone_armor.png", "desc": "白骨环绕周身吸收物理伤害" },
	"clay_golem": { "name": "黏土傀儡", "class": "nec", "group": "nec_golem", "icon": "res://assets/skills/nec/09_clay_golem.png", "desc": "召唤控场重坦，攻击减速迟缓，超高生命挡刀" },
	"bloodgolem": { "name": "鲜血傀儡", "class": "nec", "group": "nec_golem", "icon": "res://assets/skills/nec/19_bloodgolem.png", "desc": "召唤吸血肉盾，攻击按比例转化主人生命，挂机续航" },
	"irongolem": { "name": "钢铁傀儡", "class": "nec", "group": "nec_golem", "icon": "res://assets/skills/nec/24_irongolem.png", "desc": "召唤反伤战神，近战荆棘反弹，高防御护身" },
	"firegolem": { "name": "火焰傀儡", "class": "nec", "group": "nec_golem", "icon": "res://assets/skills/nec/28_firegolem.png", "desc": "召唤烈焰重坦，烈火灼烧光环，阵亡烈焰自爆" },
	# 刺客 (asn)
	"quickness": { "name": "速度爆发", "class": "asn", "group": "asn_buff", "icon": "res://assets/skills/asn/07_quickness.png", "desc": "大幅提升攻击速度与移动速度" },
	"fade": { "name": "能量消解", "class": "asn", "group": "asn_buff", "icon": "res://assets/skills/asn/16_fade.png", "desc": "大幅提升全元素抗性与物理抗性" },
	"venom": { "name": "毒牙", "class": "asn", "group": "", "icon": "res://assets/skills/asn/27_venom.png", "desc": "为武器涂抹剧毒附加毒素伤害" },
	"blade_shield": { "name": "刀刃之盾", "class": "asn", "group": "", "icon": "res://assets/skills/asn/26_blade_shield.png", "desc": "召唤飞旋利刃切割近身敌人" },
	# 德鲁伊 (dru)
	"cyclone_armor": { "name": "飓风装甲", "class": "dru", "group": "", "icon": "res://assets/skills/dru/04_cyclone_armor.png", "desc": "召唤狂风吸收火冰电元素伤害" },
	"wearwolf": { "name": "狼人变化", "class": "dru", "group": "dru_shapeshift", "icon": "res://assets/skills/dru/10_werewolf.png", "desc": "变身为狼人，提升攻速与命中" },
	"wearbear": { "name": "熊人变化", "class": "dru", "group": "dru_shapeshift", "icon": "res://assets/skills/dru/12_werebear.png", "desc": "变身为熊人，大幅提升防御与伤害" },
	"oak_sage": { "name": "橡木智者", "class": "dru", "group": "dru_spirit", "icon": "res://assets/skills/dru/21_oak_sage.png", "desc": "召唤自然灵体提升全队最大生命" },
	"heart_of_wolverine": { "name": "狼獾之心", "class": "dru", "group": "dru_spirit", "icon": "res://assets/skills/dru/24_heart_of_wolverine.png", "desc": "召唤狂暴灵体提升全队伤害与命中" },
	"spirit_of_barbs": { "name": "荆棘之灵", "class": "dru", "group": "dru_spirit", "icon": "res://assets/skills/dru/27_spirit_of_barbs.png", "desc": "召唤荆棘灵体反弹近战伤害" },
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
	_setup_auto_skill_slots()
	_setup_skill_picker()
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

func _setup_auto_skill_slots() -> void:
	if not auto_skill_container:
		auto_skill_container = get_node_or_null("%AutoSkillSlotsContainer")
	if not auto_skill_container:
		return

	auto_slot_controls.clear()
	for i in range(4):
		var slot_node = auto_skill_container.get_node_or_null("Slot%d" % (i + 1))
		if slot_node:
			auto_slot_controls.append(slot_node)
			slot_node.gui_input.connect(_on_auto_skill_slot_input.bind(i))
			_update_auto_skill_display(i)

func _setup_skill_picker() -> void:
	if not _skill_picker_menu:
		_skill_picker_menu = PopupMenu.new()
		_skill_picker_menu.id_pressed.connect(_on_skill_picker_item_selected)
		add_child(_skill_picker_menu)

func _bind_slot_drag_drop(slot: Control, idx: int) -> void:
	slot.set_meta("slot_index", idx)
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
		slot.tooltip_text = "【药水槽 %d】空\n可从背包拖入药水\n(生命/法力/活力药水)" % (idx + 1)

## -------------------------------------------------------------
## 自动巡检技能槽交互与互斥过滤
## -------------------------------------------------------------
func _on_auto_skill_slot_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_open_skill_picker(idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_slot_auto_skill(idx)

func clear_slot_auto_skill(idx: int) -> void:
	if idx >= 0 and idx < 4:
		auto_skill_slots[idx] = ""
		_update_auto_skill_display(idx)

func _get_skill_group(sk_code: String) -> String:
	if AUTO_SKILL_DEFS.has(sk_code):
		return str(AUTO_SKILL_DEFS[sk_code].get("group", ""))
	return ""

func set_slot_auto_skill(idx: int, sk_code: String) -> void:
	if idx < 0 or idx >= 4:
		return
	var new_grp = _get_skill_group(sk_code)
	if not new_grp.is_empty():
		# 互斥检查：清空其他槽位中的同组旧技能，防止心跳死循环
		for i in range(4):
			if i != idx and _get_skill_group(auto_skill_slots[i]) == new_grp:
				var old_name = AUTO_SKILL_DEFS[auto_skill_slots[i]]["name"]
				auto_skill_slots[i] = ""
				_update_auto_skill_display(i)
				_toast("已自动替换同组互斥技能【%s】" % old_name)
	auto_skill_slots[idx] = sk_code
	_update_auto_skill_display(idx)

func _update_auto_skill_display(idx: int) -> void:
	if idx < 0 or idx >= auto_slot_controls.size():
		return
	var slot = auto_slot_controls[idx]
	var code = auto_skill_slots[idx] if idx < auto_skill_slots.size() else ""

	var icon_rect = slot.get_node_or_null("Icon") as TextureRect
	var label_num = slot.get_node_or_null("LabelNum") as Label

	if label_num:
		label_num.text = str(idx + 1)

	if AUTO_SKILL_DEFS.has(code):
		var info = AUTO_SKILL_DEFS[code]
		if icon_rect:
			if ResourceLoader.exists(info["icon"]):
				icon_rect.texture = load(info["icon"])
				icon_rect.show()
			else:
				icon_rect.hide()
		slot.tooltip_text = "【%s】(自律巡检槽 %d)\n效果: %s\n(左键更换 / 右键清空)" % [info["name"], idx + 1, info["desc"]]
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.hide()
		slot.tooltip_text = "【巡检槽 %d】空\n左键点击选择自律技能\n(护甲/护盾/雷暴/战吼)" % (idx + 1)

var _picker_skill_codes: Array[String] = []

func _open_skill_picker(slot_idx: int) -> void:
	_picking_slot_index = slot_idx
	if not _skill_picker_menu:
		_setup_skill_picker()
	_skill_picker_menu.clear()
	_picker_skill_codes.clear()

	var char_class = ""
	if GameState.selected_character is Dictionary:
		char_class = str(GameState.selected_character.get("class", "")).to_lower()

	# 添加“清空该槽位”选项
	_skill_picker_menu.add_item("× 清空该槽位", 0)
	_picker_skill_codes.append("")

	var menu_idx = 1
	for sk_code in AUTO_SKILL_DEFS.keys():
		var def = AUTO_SKILL_DEFS[sk_code]
		# 若指定了职业，优先呈现本职业技能；全职通用或无过滤时全列出
		if not char_class.is_empty() and def["class"] != char_class:
			continue
		var item_label = "【%s】 - %s" % [def["name"], def["desc"]]
		var grp = str(def.get("group", ""))
		if not grp.is_empty():
			item_label += " (同系互斥)"
		_skill_picker_menu.add_item(item_label, menu_idx)
		_picker_skill_codes.append(sk_code)
		menu_idx += 1

	var slot_node = auto_slot_controls[slot_idx]
	var pop_pos = slot_node.get_global_position() + Vector2(0, slot_node.size.y + 4)
	_skill_picker_menu.position = Vector2i(int(pop_pos.x), int(pop_pos.y))
	_skill_picker_menu.popup()

func _on_skill_picker_item_selected(index: int) -> void:
	if _picking_slot_index < 0 or index < 0 or index >= _picker_skill_codes.size():
		return
	var code = _picker_skill_codes[index]
	if code.is_empty():
		clear_slot_auto_skill(_picking_slot_index)
	else:
		set_slot_auto_skill(_picking_slot_index, code)

func _toast(msg: String) -> void:
	var hud = get_parent()
	if hud and hud.has_method("show_toast"):
		hud.show_toast(msg)

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
	if auto_slot_controls.is_empty():
		_setup_auto_skill_slots()

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

	# 巡检技能槽位解析
	var skills_str = str(data.get("auto_skills", ""))
	auto_skill_slots = ["", "", "", ""]
	if not skills_str.is_empty():
		var sk_parts = skills_str.split(",", false)
		for i in range(mini(sk_parts.size(), 4)):
			var sk = sk_parts[i].strip_edges().to_lower()
			auto_skill_slots[i] = sk

	for i in range(4):
		_update_auto_skill_display(i)

	# 喝药阈值处理
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

	var clean_skills: Array[String] = []
	for s in auto_skill_slots:
		if not s.is_empty():
			clean_skills.append(s)
	var skills_arg = ",".join(clean_skills)
	if skills_arg.is_empty():
		skills_arg = "clear"

	# 环境变量与 afkset 设置帧同步
	_send_lpc_cmd("set auto_potion_pct %d" % target_pct)
	_send_lpc_cmd("afkset save %d %s %d %s" % [auto_next, pots_arg, target_pct, skills_arg])

	settings_saved.emit({
		"auto_next_stage": auto_next,
		"hook_potions": clean_pots,
		"auto_potion_pct": target_pct,
		"auto_skills": clean_skills,
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
