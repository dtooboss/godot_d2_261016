extends Control
class_name PartyHudPanel

## 暗黑2战网风格野外战斗队伍与个人状态面板 (Party HUD)
## 包含单人常驻个人状态牌、组队全员状态、顶置3px极细血条、紧凑双行排布与Buff/光环图标栏

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

## 暗黑2 经典光环/增益图标资源映射表
const BUFF_ICON_MAP: Dictionary = {
	"concentration": "res://assets/skills/pal/17_concentration.png",
	"fanaticism": "res://assets/skills/pal/26_fanaticism.png",
	"might": "res://assets/skills/pal/02_might.png",
	"holy_freeze": "res://assets/skills/pal/18_holy_freeze.png",
	"holy_shock": "res://assets/skills/pal/22_holy_shock.png",
	"holy_fire": "res://assets/skills/pal/06_holy_fire.png",
	"defiance": "res://assets/skills/pal/08_defiance.png",
	"conviction": "res://assets/skills/pal/27_conviction.png",
	"salvation": "res://assets/skills/pal/29_salvation.png",
	"meditation": "res://assets/skills/pal/24_meditation.png",
	"thorns": "res://assets/skills/pal/07_thorns.png",
	"vigor": "res://assets/skills/pal/19_vigor.png",
	"sanctuary": "res://assets/skills/pal/23_sanctuary.png",
	"cleansing": "res://assets/skills/pal/13_cleansing.png",
	"resist_fire": "res://assets/skills/pal/04_resist_fire.png",
	"resist_cold": "res://assets/skills/pal/09_resist_cold.png",
	"resist_lightning": "res://assets/skills/pal/14_resist_lightning.png",
	"prayer": "res://assets/skills/pal/03_prayer.png",
	"redemption": "res://assets/skills/pal/28_redemption.png",
	"holy_shield": "res://assets/skills/pal/21_holy_shield.png",
	"bo": "res://assets/skills/bar/23_battle_orders.png",
	"battle_orders": "res://assets/skills/bar/23_battle_orders.png",
	"bc": "res://assets/skills/bar/29_battle_command.png",
	"battle_command": "res://assets/skills/bar/29_battle_command.png",
	"shout": "res://assets/skills/bar/12_shout.png",
	"enchant": "res://assets/skills/sor/16_enchant.png",
	"frozen_armor": "res://assets/skills/sor/04_frozen_armor.png",
	"shiver_armor": "res://assets/skills/sor/14_shiver_armor.png",
	"chilling_armor": "res://assets/skills/sor/24_chilling_armor.png",
	"energy_shield": "res://assets/skills/sor/22_energy_shield.png",
	"thunder_storm": "res://assets/skills/sor/21_thunder_storm.png",
	"battle_cry": "res://assets/skills/bar/20_battle_cry.png",
	"war_cry": "res://assets/skills/bar/28_war_cry.png",
	"burst_of_speed": "res://assets/skills/asn/07_quickness.png",
	"bone_armor": "res://assets/skills/nec/02_bone_armor.png",
	"cyclone_armor": "res://assets/skills/dru/04_cyclone_armor.png",
	"quickness": "res://assets/skills/asn/07_quickness.png",
	"fade": "res://assets/skills/asn/16_fade.png",
	"venom": "res://assets/skills/asn/27_venom.png",
	"wearwolf": "res://assets/skills/dru/10_werewolf.png",
	"werewolf": "res://assets/skills/dru/10_werewolf.png",
	"wearbear": "res://assets/skills/dru/12_werebear.png",
	"werebear": "res://assets/skills/dru/12_werebear.png",
	"oak_sage": "res://assets/skills/dru/21_oak_sage.png",
	"heart_of_wolverine": "res://assets/skills/dru/24_heart_of_wolverine.png",
	"spirit_of_barbs": "res://assets/skills/dru/27_spirit_of_barbs.png",
	"cycle_of_life": "res://assets/skills/dru/23_carrion_vine.png",
	"carrion_vine": "res://assets/skills/dru/23_carrion_vine.png",
	"vines": "res://assets/skills/dru/26_solar_creeper.png",
	"solar_creeper": "res://assets/skills/dru/26_solar_creeper.png",
	"plague_poppy": "res://assets/skills/dru/20_poison_creeper.png",
	"poison_creeper": "res://assets/skills/dru/20_poison_creeper.png",
}

## 光环/增益中文名与效果描述
const BUFF_INFO_MAP: Dictionary = {
	"concentration": {"name": "专注光环", "desc": "物理伤害巨幅提升，降低攻击被打断几率"},
	"fanaticism": {"name": "狂热光环", "desc": "提升物理伤害、攻击速度与命中率"},
	"might": {"name": "力量光环", "desc": "提升全队物理伤害"},
	"holy_freeze": {"name": "神圣冰冻", "desc": "附加冰冷伤害并减速周围敌人"},
	"holy_shock": {"name": "神圣冲击", "desc": "附加高额闪电伤害"},
	"holy_fire": {"name": "神圣火焰", "desc": "附加火焰伤害"},
	"defiance": {"name": "蔑视光环", "desc": "大幅提升防御力"},
	"conviction": {"name": "审判光环", "desc": "大幅降低周围敌人的抗性与防御力"},
	"salvation": {"name": "救助光环", "desc": "全队获得巨额全元素抗性"},
	"meditation": {"name": "冥想光环", "desc": "全队法力回复速度巨幅提升"},
	"thorns": {"name": "荆棘光环", "desc": "全队受到近战物理攻击时高额反弹伤害"},
	"vigor": {"name": "活力光环", "desc": "提升移动速度与耐力恢复"},
	"sanctuary": {"name": "庇护所", "desc": "击退周围不死生物并剥离其物理免疫"},
	"cleansing": {"name": "净化光环", "desc": "全队受到毒素与诅咒的持续时间大幅缩减"},
	"resist_fire": {"name": "抵抗火焰", "desc": "全队火焰抗性提升，被动提升火抗上限"},
	"resist_cold": {"name": "抵抗冰冷", "desc": "全队冰冷抗性提升，被动提升冰抗上限"},
	"resist_lightning": {"name": "抵抗闪电", "desc": "全队闪电抗性提升，被动提升电抗上限"},
	"prayer": {"name": "祈祷光环", "desc": "全队持续恢复生命值"},
	"redemption": {"name": "救赎光环", "desc": "全队周期性超度敌怪亡魂恢复生命与法力"},
	"holy_shield": {"name": "神圣之盾", "desc": "提升格挡几率与防御力"},
	"bo": {"name": "战斗体质", "desc": "极大提升生命与法力上限"},
	"battle_orders": {"name": "战斗体质", "desc": "极大提升生命与法力上限"},
	"bc": {"name": "战斗指挥", "desc": "全技能等级 +1"},
	"battle_command": {"name": "战斗指挥", "desc": "全技能等级 +1"},
	"shout": {"name": "大叫", "desc": "全队防御力大幅提升"},
	"battle_cry": {"name": "战斗怒吼", "desc": "恐吓周围敌怪，削弱其防御力与物理伤害"},
	"war_cry": {"name": "战争践踏", "desc": "震慑周围敌怪造成伤害并眩晕"},
	"enchant": {"name": "强化", "desc": "附加高额火焰伤害与攻击命中率"},
	"frozen_armor": {"name": "冰封甲", "desc": "提升自身防御力，近战攻击者将被冻结"},
	"shiver_armor": {"name": "碎冰甲", "desc": "提升自身防御力，反弹冰冷伤害与减速"},
	"chilling_armor": {"name": "寒冰甲", "desc": "大幅提升自身防御力，反弹远程飞弹"},
	"energy_shield": {"name": "能量护盾", "desc": "以法力值吸收承受的伤害"},
	"thunder_storm": {"name": "雷暴术", "desc": "召唤致命雷云风暴，周期性以九天神雷轰击周围敌怪"},
	"bone_armor": {"name": "白骨装甲", "desc": "召唤白骨环绕周身吸收物理伤害"},
	"cyclone_armor": {"name": "飓风装甲", "desc": "召唤狂风吸收火冰电元素伤害"},
	"quickness": {"name": "速度爆发", "desc": "大幅提升攻击速度与移动速度"},
	"burst_of_speed": {"name": "速度爆发", "desc": "大幅提升攻击速度与移动速度"},
	"fade": {"name": "能量消解", "desc": "大幅提升全元素抗性与物理抗性"},
	"venom": {"name": "毒牙", "desc": "为武器涂抹剧毒附加毒素伤害"},
	"wearwolf": {"name": "狼人变化", "desc": "变身为狂暴狼人，大幅提升生命、命中、攻速与偷血，拥有15%物理减伤"},
	"werewolf": {"name": "狼人变化", "desc": "变身为狂暴狼人，大幅提升生命、命中、攻速与偷血，拥有15%物理减伤"},
	"wearbear": {"name": "熊人变化", "desc": "变身为铁甲巨熊，巨幅提升生命、防御与伤害，拥有25%物理硬抗减伤"},
	"werebear": {"name": "熊人变化", "desc": "变身为铁甲巨熊，巨幅提升生命、防御与伤害，拥有25%物理硬抗减伤"},
	"oak_sage": {"name": "橡木智者", "desc": "召唤自然灵体，大幅提升全队最大生命值"},
	"heart_of_wolverine": {"name": "狼獾之心", "desc": "召唤战斗灵体，巨幅提升全队物理伤害与命中率"},
	"spirit_of_barbs": {"name": "棘灵", "desc": "召唤荆棘灵体，全队反弹敌人近战伤害"},
	"cycle_of_life": {"name": "食尸藤", "desc": "召唤食尸藤吞噬尸骸，持续恢复生命值"},
	"vines": {"name": "太阳藤", "desc": "召唤太阳藤吞噬尸骸，持续恢复法力值"},
	"plague_poppy": {"name": "剧毒藤", "desc": "召唤剧毒藤蔓，提升全队毒素抗性"},
}

## 统一战力字符串格式化接口 (支持 1000->1k, 1100->1.1k, 兼容整型或已有字符串)
static func format_power_str(p_val) -> String:
	if p_val == null:
		return "10"
	if p_val is String:
		var s := str(p_val).strip_edges()
		if not s.is_empty():
			return s
		return "10"
	var p_num := int(p_val)
	if p_num < 1000:
		return str(max(1, p_num))
	elif p_num < 1000000:
		if p_num % 1000 == 0:
			return "%dk" % (p_num / 1000)
		var k_str := "%.1fk" % (float(p_num) / 1000.0)
		return k_str.replace(".0k", "k")
	else:
		if p_num % 1000000 == 0:
			return "%dm" % (p_num / 1000000)
		var m_str := "%.1fm" % (float(p_num) / 1000000.0)
		return m_str.replace(".0m", "m")

## 纯净化角色名 (剥离 "野蛮人·"、"亚马逊·"、"圣骑士" 等职业信息，头像已展示职业图标)
static func clean_character_name(raw_name: String) -> String:
	var s := AnsiHelperScript.to_plain_text(raw_name).strip_edges()
	if s.is_empty():
		return "队员"
	
	var class_prefixes := [
		"死灵法师", "野蛮人", "圣骑士", "亚马逊", "德鲁伊",
		"法师", "女巫", "巫师", "死灵", "刺客"
	]
	
	# 如果带有常见分隔符，如 "野蛮人·狂徒"、"野蛮人-狂徒"、"野蛮人 狂徒"、"野蛮人:狂徒"
	for sep in ["·", "•", "-", " ", ":", "：", "|", "/"]:
		if sep in s:
			var parts := s.split(sep, false, 1)
			if parts.size() == 2:
				var prefix := parts[0].strip_edges()
				var suffix := parts[1].strip_edges()
				if not suffix.is_empty():
					for cp in class_prefixes:
						if prefix == cp or prefix.ends_with(cp):
							return suffix
	
	# 如果没有分隔符但直接以职业名开头，如 "野蛮人小强"
	for cp in class_prefixes:
		if s.begins_with(cp) and s.length() > cp.length():
			var trimmed := s.substr(cp.length()).strip_edges()
			if not trimmed.is_empty():
				return trimmed
				
	return s

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
	GameState.team_updated.connect(update_party)
	if GameState.is_in_team:
		update_party(GameState.current_team_members)
	elif GameState.selected_character and not GameState.selected_character.is_empty():
		_show_solo_card()
	else:
		visible = false

## 刷新整支队伍状态
func update_party(members: Array) -> void:
	if members.size() <= 1:
		_show_solo_card()
		return
		
	visible = true
	var header_hbox = get_node_or_null("RootVBox/HeaderHBox")
	if header_hbox: header_hbox.visible = true
	
	var current_ids = []
	
	# 刷新顶部队伍标题与行动按钮
	var is_leader = GameState.is_team_leader()
		
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
			if member_cards[mid].get_parent():
				member_cards[mid].get_parent().remove_child(member_cards[mid])
			member_cards[mid].queue_free()
		member_cards.erase(mid)

## 单人状态下常驻展示玩家自身的精简状态牌
func _show_solo_card() -> void:
	var my_data = _get_self_member_data()
	if my_data.is_empty():
		visible = false
		_clear_all_cards()
		return
		
	visible = true
	var header_hbox = get_node_or_null("RootVBox/HeaderHBox")
	if header_hbox: header_hbox.visible = false
	if context_menu: context_menu.visible = false
	if confirm_dialog: confirm_dialog.visible = false
	
	var my_id = str(my_data.get("id", "self"))
	var to_remove = []
	for mid in member_cards.keys():
		if mid != my_id:
			to_remove.append(mid)
	for mid in to_remove:
		if is_instance_valid(member_cards[mid]):
			if member_cards[mid].get_parent():
				member_cards[mid].get_parent().remove_child(member_cards[mid])
			member_cards[mid].queue_free()
		member_cards.erase(mid)
		
	if member_cards.has(my_id):
		_update_card_data(member_cards[my_id], my_data)
	else:
		var card = _create_member_card(my_data)
		member_list_vbox.add_child(card)
		member_cards[my_id] = card

## 供外界高频心跳 (ghp1) 同步单人数据与 Buff
func update_solo_card(my_data: Dictionary) -> void:
	if my_data.is_empty(): return
	visible = true
	var header_hbox = get_node_or_null("RootVBox/HeaderHBox")
	if header_hbox: header_hbox.visible = false
	
	var my_id = str(my_data.get("id", "self"))
	if member_cards.has(my_id):
		_update_card_data(member_cards[my_id], my_data)
	else:
		var card = _create_member_card(my_data)
		member_list_vbox.add_child(card)
		member_cards[my_id] = card

## 构造玩家自身数据字典
func _get_self_member_data() -> Dictionary:
	var sc = GameState.selected_character
	if not sc or sc.is_empty():
		return {}
		
	var mid = GameState.get_my_character_id()
	if mid.is_empty(): mid = "self"
	var mname = str(sc.get("name", "玩家"))
	var mclass = str(sc.get("class", "ama")).to_lower()
	var mlvl = AnsiHelper.to_safe_int(sc.get("level"), 1)
	var cur_hp = AnsiHelper.to_safe_int(sc.get("hp", sc.get("qi", 100)), 100)
	var max_hp = AnsiHelper.to_safe_int(sc.get("max_hp", sc.get("max_qi", 100)), 100)
	if max_hp <= 0: max_hp = 1
	
	# 收集当前激活的光环/Buff
	var buffs = []
	var act_aura = str(sc.get("d2_active_aura", sc.get("active_aura", "")))
	if not act_aura.is_empty() and act_aura != "none" and act_aura != "0":
		buffs.append(act_aura)
		
	# 检查装备赋予的光环 (如武器上的 10 级专注光环)
	var eq_aura = str(sc.get("equipped_aura", sc.get("aura_concentration", "")))
	if not eq_aura.is_empty() and eq_aura != "none" and not eq_aura in buffs:
		buffs.append(eq_aura)
	elif sc.has("aura") and not str(sc.get("aura")).is_empty():
		var sa = str(sc.get("aura"))
		if not sa in buffs: buffs.append(sa)
		
	var raw_pwr = sc.get("power", sc.get("combat_power", sc.get("rating", "10")))
	var pwr_str = format_power_str(raw_pwr)
		
	return {
		"id": mid,
		"name": mname,
		"class": mclass,
		"level": mlvl,
		"hp": cur_hp,
		"max_hp": max_hp,
		"is_leader": true,
		"power": pwr_str,
		"buffs": buffs
	}

## 供外界 (如 afk_main_hud) 实时同步玩家自身血量到单人卡片
func update_self_hp(cur: int, maximum: int) -> void:
	if not is_inside_tree():
		return
	if not GameState.is_in_team:
		var my_id = GameState.get_my_character_id()
		if my_id.is_empty(): my_id = "self"
		if member_cards.has(my_id):
			var card_node = member_cards[my_id]
			if is_instance_valid(card_node):
				var hp_bar = card_node.find_child("HpBar", true, false)
				if hp_bar is ProgressBar:
					hp_bar.max_value = max(1, maximum)
					hp_bar.value = cur
					var card_body = card_node.get_child(0) if card_node.get_child_count() > 0 else card_node
					if card_body is Control:
						card_body.tooltip_text = "生命值: %d / %d (%.0f%%)" % [cur, maximum, (float(cur) / max(1, maximum)) * 100.0]

func _clear_all_cards() -> void:
	for mid in member_cards.keys():
		if is_instance_valid(member_cards[mid]):
			member_cards[mid].queue_free()
	member_cards.clear()

## 获取指定队员卡片的全局发射/受击锚点坐标
func get_member_card_anchor_pos(mid: String) -> Vector2:
	if not visible:
		return Vector2.ZERO
	if member_cards.has(mid):
		var row = member_cards[mid]
		if is_instance_valid(row) and row.is_visible_in_tree():
			var card_body = row.get_child(0) if row.get_child_count() > 0 else row
			if card_body is Control:
				return card_body.global_position + Vector2(card_body.size.x + 4.0, card_body.size.y * 0.5)
			return row.global_position + Vector2(175.0, 22.0)
	return Vector2.ZERO

## 动态创建单个队员卡片 (文字端紧凑风格：顶置3px细血条 + 双行高密度排布)
func _create_member_card(data: Dictionary) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 44)
	
	# 1. 卡片主体 (宽度 175, 高度 44，宽裕容纳长名字+等级+战力)
	var card_body = PanelContainer.new()
	card_body.custom_minimum_size = Vector2(175, 44)
	card_body.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.075, 0.07, 0.94)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	
	var is_leader = bool(data.get("is_leader", false))
	sb.border_color = Color(0.85, 0.72, 0.3, 0.95) if is_leader else Color(0.48, 0.44, 0.38, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 5
	sb.content_margin_top = 0
	sb.content_margin_right = 5
	sb.content_margin_bottom = 4
	card_body.add_theme_stylebox_override("panel", sb)
	row.add_child(card_body)
	
	# 点击卡片交互
	var mid = str(data.get("id", ""))
	var raw_name = str(data.get("name", "队员"))
	var clean_name = clean_character_name(raw_name)
	card_body.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_context_menu(mid, clean_name, card_body.get_global_mouse_position())
	)
	
	# 纵向容器 (顶部贴沿细血条 + 下方主体内容)
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 2)
	card_body.add_child(card_vbox)
	
	# --- 顶部 3px 极细血条 (参考文字端规范) ---
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(0, 3)
	hp_bar.show_percentage = false
	
	var cur_hp = AnsiHelper.to_safe_int(data.get("hp"), 100)
	var max_hp = AnsiHelper.to_safe_int(data.get("max_hp"), 100)
	if max_hp <= 0: max_hp = 1
	hp_bar.max_value = max_hp
	hp_bar.value = cur_hp
	
	var bg_hp = StyleBoxFlat.new()
	bg_hp.bg_color = Color(0.22, 0.04, 0.04, 0.9)
	bg_hp.corner_radius_top_left = 3
	bg_hp.corner_radius_top_right = 3
	hp_bar.add_theme_stylebox_override("background", bg_hp)
	
	var fill_hp = StyleBoxFlat.new()
	fill_hp.bg_color = Color(0.92, 0.16, 0.16, 1.0)
	fill_hp.corner_radius_top_left = 3
	fill_hp.corner_radius_top_right = 3
	hp_bar.add_theme_stylebox_override("fill", fill_hp)
	
	card_vbox.add_child(hp_bar)
	card_body.tooltip_text = "生命值: %d / %d (%.0f%%)" % [cur_hp, max_hp, (float(cur_hp) / max_hp) * 100.0]
	
	# --- 主体内容横排 (头像 + 右侧双行文本/状态) ---
	var content_h = HBoxContainer.new()
	content_h.add_theme_constant_override("separation", 6)
	content_h.alignment = BoxContainer.ALIGNMENT_CENTER
	content_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(content_h)
	
	# 职业头像带精致金框
	var avatar_frame = PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(32, 32)
	var av_sb = StyleBoxFlat.new()
	av_sb.bg_color = Color(0.04, 0.04, 0.04, 0.95)
	av_sb.border_width_left = 1
	av_sb.border_width_top = 1
	av_sb.border_width_right = 1
	av_sb.border_width_bottom = 1
	av_sb.border_color = Color(0.65, 0.52, 0.25, 0.85)
	av_sb.corner_radius_top_left = 2
	av_sb.corner_radius_top_right = 2
	av_sb.corner_radius_bottom_right = 2
	av_sb.corner_radius_bottom_left = 2
	av_sb.content_margin_left = 1
	av_sb.content_margin_top = 1
	av_sb.content_margin_right = 1
	av_sb.content_margin_bottom = 1
	avatar_frame.add_theme_stylebox_override("panel", av_sb)
	content_h.add_child(avatar_frame)
	
	var avatar = TextureRect.new()
	avatar.custom_minimum_size = Vector2(30, 30)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cls = str(data.get("class", "sor")).to_lower()
	avatar.texture = GameState.get_class_icon(cls)
	avatar_frame.add_child(avatar)
	
	# 右侧垂直信息列
	var vcol = VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.add_theme_constant_override("separation", 2)
	content_h.add_child(vcol)
	
	# 第一行：名字 + 等级 + 战力 (并排紧贴排布)
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vcol.add_child(name_row)
	
	var lbl_name = Label.new()
	lbl_name.name = "NameLabel"
	lbl_name.text = ("👑 " if is_leader else "") + clean_name
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_leader else Color(0.95, 0.95, 0.95))
	name_row.add_child(lbl_name)
	
	var lvl = AnsiHelper.to_safe_int(data.get("level"), 1)
	var lbl_lvl = Label.new()
	lbl_lvl.name = "LevelLabel"
	lbl_lvl.text = "LV.%d" % lvl
	lbl_lvl.add_theme_font_size_override("font_size", 10)
	lbl_lvl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5)) # 鲜亮绿，参考文字端
	name_row.add_child(lbl_lvl)
	
	# 战力微型盒子 (放置在第一行)
	var pwr_box = HBoxContainer.new()
	pwr_box.name = "PowerBox"
	pwr_box.add_theme_constant_override("separation", 1)
	name_row.add_child(pwr_box)

	var lbl_sword = Label.new()
	lbl_sword.text = "⚔"
	lbl_sword.add_theme_font_size_override("font_size", 9)
	lbl_sword.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	pwr_box.add_child(lbl_sword)
	
	var raw_power = data.get("power", data.get("combat_power", data.get("rating", "10")))
	var lbl_power = Label.new()
	lbl_power.name = "PowerLabel"
	lbl_power.text = format_power_str(raw_power)
	lbl_power.add_theme_font_size_override("font_size", 10)
	lbl_power.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2)) # 金黄色，参考文字端
	pwr_box.add_child(lbl_power)
	
	# 第二行：纯 Buff 图标容器 (独占整行横向空间，可横排容纳更多 Buff)
	var buff_row = HBoxContainer.new()
	buff_row.add_theme_constant_override("separation", 2)
	buff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.add_child(buff_row)

	var buff_container = HBoxContainer.new()
	buff_container.name = "BuffContainer"
	buff_container.add_theme_constant_override("separation", 2)
	buff_row.add_child(buff_container)
	
	_render_buff_icons(buff_container, data.get("buffs", []))
	
	return row

## 更新单个卡片的数据
func _update_card_data(card_node: Control, data: Dictionary) -> void:
	if not is_instance_valid(card_node): return
	
	var hp_bar = card_node.find_child("HpBar", true, false)
	if hp_bar is ProgressBar:
		var cur_hp = AnsiHelper.to_safe_int(data.get("hp"), 100)
		var max_hp = AnsiHelper.to_safe_int(data.get("max_hp"), 100)
		if max_hp <= 0: max_hp = 1
		hp_bar.max_value = max_hp
		hp_bar.value = cur_hp
		
		var card_body = card_node.get_child(0) if card_node.get_child_count() > 0 else card_node
		if card_body is Control:
			card_body.tooltip_text = "生命值: %d / %d (%.0f%%)" % [cur_hp, max_hp, (float(cur_hp) / max_hp) * 100.0]
		
	var lbl_name = card_node.find_child("NameLabel", true, false)
	if lbl_name is Label:
		var is_leader = bool(data.get("is_leader", false))
		var raw_name = str(data.get("name", "队员"))
		var clean_name = clean_character_name(raw_name)
		lbl_name.text = ("👑 " if is_leader else "") + clean_name
		
	var lbl_lvl = card_node.find_child("LevelLabel", true, false)
	if lbl_lvl is Label:
		var lvl = AnsiHelper.to_safe_int(data.get("level"), 1)
		lbl_lvl.text = "LV.%d" % lvl
		
	var lbl_power = card_node.find_child("PowerLabel", true, false)
	if lbl_power is Label:
		var raw_power = data.get("power", data.get("combat_power", data.get("rating", "10")))
		lbl_power.text = format_power_str(raw_power)
		
	var buff_container = card_node.find_child("BuffContainer", true, false)
	if buff_container is HBoxContainer:
		_render_buff_icons(buff_container, data.get("buffs", []))

## 单个 Buff/光环微型勋章节点 (支持永久光环金边展示与战吼倒计时/呼吸频闪)
class BuffBadgeNode extends PanelContainer:
	var buff_id: String = ""
	var buff_name: String = ""
	var buff_level: int = 0
	var remain_time: float = -1.0 # -1.0 为常驻光环
	var total_duration: float = -1.0
	var lbl_timer: Label
	var icon_rect: TextureRect
	var time_accum: float = 0.0
	var border_style: StyleBoxFlat
	
	func setup(data) -> void:
		custom_minimum_size = Vector2(18, 18)
		mouse_filter = Control.MOUSE_FILTER_PASS
		
		if data is Dictionary:
			buff_id = str(data.get("id", data.get("name", ""))).to_lower().strip_edges()
			buff_name = str(data.get("name", ""))
			buff_level = int(data.get("level", 0))
			if data.has("remain"):
				remain_time = float(data.get("remain"))
			elif data.has("duration"):
				remain_time = float(data.get("duration"))
			total_duration = float(data.get("duration", remain_time))
		else:
			buff_id = str(data).to_lower().strip_edges()
			if buff_id in ["bo", "battle_orders", "bc", "battle_command", "shout", "enchant"]:
				remain_time = 120.0
				total_duration = 120.0
				
		var is_timed = remain_time > 0.0
		
		border_style = StyleBoxFlat.new()
		border_style.bg_color = Color(0.04, 0.04, 0.05, 0.95)
		border_style.border_width_left = 1
		border_style.border_width_top = 1
		border_style.border_width_right = 1
		border_style.border_width_bottom = 1
		border_style.border_color = Color(0.35, 0.75, 1.0, 0.85) if is_timed else Color(0.78, 0.62, 0.25, 0.85)
		border_style.corner_radius_top_left = 2
		border_style.corner_radius_top_right = 2
		border_style.corner_radius_bottom_right = 2
		border_style.corner_radius_bottom_left = 2
		border_style.content_margin_left = 1
		border_style.content_margin_top = 1
		border_style.content_margin_right = 1
		border_style.content_margin_bottom = 1
		add_theme_stylebox_override("panel", border_style)
		
		icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		var p: String = ""
		if PartyHudPanel.BUFF_ICON_MAP.has(buff_id):
			p = PartyHudPanel.BUFF_ICON_MAP[buff_id]
		
		# 动态目录匹配兜底 (杜绝任何漏写导致的贴图丢失，支持带编号前缀的贴图如 21_thunder_storm.png)
		if p.is_empty() or not ResourceLoader.exists(p):
			for c_dir in ["bar", "sor", "pal", "nec", "dru", "asn", "ama"]:
				var candidate = "res://assets/skills/%s/%s.png" % [c_dir, buff_id]
				if ResourceLoader.exists(candidate):
					p = candidate
					break
				for num in range(30):
					var c_num = "res://assets/skills/%s/%02d_%s.png" % [c_dir, num, buff_id]
					if ResourceLoader.exists(c_num):
						p = c_num
						break
				if not p.is_empty():
					break
		
		if not p.is_empty() and ResourceLoader.exists(p):
			icon_rect.texture = load(p)
		add_child(icon_rect)
		
		lbl_timer = Label.new()
		lbl_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_timer.add_theme_font_size_override("font_size", 8)
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45) if is_timed else Color(0.45, 0.85, 1.0))
		lbl_timer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl_timer.add_theme_constant_override("outline_size", 2)
		lbl_timer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lbl_timer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		lbl_timer.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(lbl_timer)
		
		_update_display()
		set_process(is_timed)
		
	func _process(delta: float) -> void:
		if remain_time > 0.0:
			remain_time -= delta
			time_accum += delta
			if remain_time <= 0.0:
				queue_free()
				return
				
			if remain_time <= 5.0:
				modulate.a = 0.45 + 0.55 * abs(sin(time_accum * 7.0))
				if border_style:
					border_style.border_color = Color(1.0, 0.35, 0.2, 0.95)
			else:
				modulate.a = 1.0
				
			_update_display()

	func _update_display() -> void:
		if remain_time > 0.0:
			if remain_time >= 60.0:
				lbl_timer.text = "%dm" % int(ceil(remain_time / 60.0))
			else:
				lbl_timer.text = "%d" % int(ceil(remain_time))
		elif buff_level > 0:
			lbl_timer.text = "%d" % buff_level
		else:
			lbl_timer.text = ""
			
		var info = PartyHudPanel.BUFF_INFO_MAP.get(buff_id, {})
		var cname = info.get("name", "")
		if cname.is_empty():
			cname = buff_name
		if cname.is_empty() or cname == buff_id:
			cname = buff_id.replace("_", " ").capitalize()
			
		var cdesc = info.get("desc", "")
		var tip = "【%s】" % cname
		if buff_level > 0:
			tip += " (Lv.%d)" % buff_level
		if not cdesc.is_empty():
			tip += "\n%s" % cdesc
		if remain_time > 0.0:
			tip += "\n⏱️ 剩余时间: %d 秒" % int(remain_time)
		else:
			tip += "\n✨ 常驻增益"
		tooltip_text = tip

## 渲染 Buff / 光环小图标
func _render_buff_icons(container: HBoxContainer, buffs: Array) -> void:
	var old_keys = []
	for child in container.get_children():
		if child is BuffBadgeNode:
			old_keys.append("%s_%d" % [child.buff_id, child.buff_level])
			
	var new_keys = []
	for b in buffs:
		var k = ""
		var lvl = 0
		if b is Dictionary:
			k = str(b.get("id", b.get("name", ""))).to_lower().strip_edges()
			lvl = int(b.get("level", 0))
		else:
			k = str(b).to_lower().strip_edges()
		if not k.is_empty():
			new_keys.append("%s_%d" % [k, lvl])
			
	if old_keys == new_keys and not old_keys.is_empty():
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
		
	for b in buffs:
		var badge = BuffBadgeNode.new()
		badge.setup(b)
		container.add_child(badge)

## 弹出上下文菜单
func _show_context_menu(mid: String, mname: String, global_pos: Vector2) -> void:
	selected_member_id = mid
	selected_member_name = mname
	
	var my_id = GameState.get_my_character_id()
	var is_leader = GameState.is_team_leader()
	var is_self = (mid == my_id or mid == "self")
	
	if is_self:
		if is_leader and GameState.is_in_team:
			_on_team_action_pressed()
		return
		
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
		if NetworkClient.is_connected:
			NetworkClient.send_raw("team cleader " + selected_member_id)

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
	var is_leader = GameState.is_team_leader()
		
	pending_confirm_action = "dismiss"
	if confirm_msg:
		confirm_msg.text = "确定要解散整支队伍吗？" if is_leader else "确定要脱离当前队伍吗？"
	if confirm_dialog:
		confirm_dialog.visible = true

func _on_confirm_ok_pressed() -> void:
	if confirm_dialog: confirm_dialog.visible = false
	
	if pending_confirm_action == "dismiss":
		team_dismiss_requested.emit()
		if NetworkClient.is_connected:
			NetworkClient.send_raw("team dismiss")
	elif pending_confirm_action == "kick":
		if not selected_member_id.is_empty():
			if NetworkClient.is_connected:
				NetworkClient.send_raw("team dismiss " + selected_member_id)
					
	pending_confirm_action = ""

func _unhandled_input(event: InputEvent) -> void:
	if context_menu and context_menu.visible and event is InputEventMouseButton and event.pressed:
		context_menu.visible = false
