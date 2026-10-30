extends Control
class_name AFK_CharacterInfoPanel

signal item_hovered(item_data, pos)
signal item_unhovered()
signal panel_visibility_changed(is_visible: bool)

@onready var btn_close: Button = %BtnClose
@onready var points_label: Label = %PointsLabel

# 纸娃娃槽位按钮
@onready var slot_helmet: Button = %SlotHelmet
@onready var slot_armor: Button = %SlotArmor
@onready var slot_pants: Button = %SlotPants
@onready var slot_gloves: Button = %SlotGloves
@onready var slot_boots: Button = %SlotBoots
@onready var slot_necklace: Button = %SlotNecklace
@onready var slot_ring1: Button = %SlotRing1
@onready var slot_ring2: Button = %SlotRing2
@onready var slot_main_hand: Button = %SlotMainHand
@onready var slot_off_hand: Button = %SlotOffHand
@onready var slot_wings: Button = %SlotWings
@onready var slot_pet: Button = %SlotPet

# 四维属性数值与加点按钮
@onready var val_str: Label = %ValStr
@onready var val_dex: Label = %ValDex
@onready var val_vit: Label = %ValVit
@onready var val_int: Label = %ValInt
@onready var btn_add_str: Button = %BtnAddStr
@onready var btn_add_dex: Button = %BtnAddDex
@onready var btn_add_vit: Button = %BtnAddVit
@onready var btn_add_int: Button = %BtnAddInt

# 属性重置与洗点
@onready var btn_reset_stats: Button = %BtnResetStats
@onready var lbl_respec_count: Label = %LblRespecCount
@onready var btn_buy_respec: Button = %BtnBuyRespec

# 右侧全量战斗与冒险数值标签 (6大分类)
# 1. 基础信息与资源
@onready var lbl_level: Label = %LblLevel
@onready var lbl_exp: Label = %LblExp
@onready var lbl_hp: Label = %LblHp
@onready var lbl_mp: Label = %LblMp

# 2. 综合攻防与命中
@onready var lbl_phy_dmg: Label = %LblPhyDmg
@onready var lbl_phy_dps: Label = %LblPhyDps
@onready var lbl_mag_dmg: Label = %LblMagDmg
@onready var lbl_mag_dps: Label = %LblMagDps
@onready var lbl_dmg_enhance: Label = %LblDmgEnhance
@onready var lbl_ar: Label = %LblAr
@onready var lbl_hit_rate: Label = %LblHitRate
@onready var lbl_defense: Label = %LblDefense
@onready var lbl_block: Label = %LblBlock

# 3. 元素抗性与减免
@onready var lbl_res_fire: Label = %LblResFire
@onready var lbl_res_cold: Label = %LblResCold
@onready var lbl_res_light: Label = %LblResLight
@onready var lbl_res_poison: Label = %LblResPoison
@onready var lbl_dr_pct: Label = %LblDrPct
@onready var lbl_dr: Label = %LblDr
@onready var lbl_mdr: Label = %LblMdr
@onready var lbl_plr: Label = %LblPlr

# 4. 战斗档位与机动
@onready var lbl_atk_speed: Label = %LblAtkSpeed
@onready var lbl_fcr: Label = %LblFcr
@onready var lbl_fhr: Label = %LblFhr
@onready var lbl_fbr: Label = %LblFbr
@onready var lbl_frw: Label = %LblFrw

# 5. 打击特效与偷取
@onready var lbl_cb: Label = %LblCb
@onready var lbl_ds: Label = %LblDs
@onready var lbl_ow: Label = %LblOw
@onready var lbl_crit: Label = %LblCrit
@onready var lbl_crit_dmg: Label = %LblCritDmg
@onready var lbl_ll: Label = %LblLl
@onready var lbl_ml: Label = %LblMl
@onready var lbl_lak: Label = %LblLak
@onready var lbl_mak: Label = %LblMak
@onready var lbl_itd: Label = %LblItd

# 6. 技能与寻宝探索
@onready var lbl_all_skills: Label = %LblAllSkills
@onready var lbl_mf: Label = %LblMf
@onready var lbl_gf: Label = %LblGf
@onready var lbl_light_radius: Label = %LblLightRadius
@onready var lbl_cannot_be_frozen: Label = %LblCannotBeFrozen


var equips_map: Dictionary = {}
var current_stat_points: int = 0
var current_respecs: int = 0
var current_respec_price: int = 0
var current_level: int = 1
var current_gold: int = 0

static func _calc_respec_gold_cost(lvl: int) -> int:
	if lvl < 1: lvl = 1
	return 10000 + (lvl * lvl * lvl * lvl) / 2

static func _format_gold(amount: int) -> String:
	var s = str(amount)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _ready() -> void:
	hide()
	if btn_close:
		btn_close.pressed.connect(close)
		
	_bind_add_button(btn_add_str, "str")
	_bind_add_button(btn_add_dex, "dex")
	_bind_add_button(btn_add_vit, "vit")
	_bind_add_button(btn_add_int, "int")

	if btn_reset_stats:
		btn_reset_stats.pressed.connect(_on_reset_stats_pressed)
	if btn_buy_respec:
		btn_buy_respec.visible = false
	
	_setup_slot(slot_helmet, "helmet", "head")
	_setup_slot(slot_armor, "armor", "armor")
	_setup_slot(slot_pants, "pants", "waist")
	_setup_slot(slot_gloves, "gloves", "hands")
	_setup_slot(slot_boots, "boots", "boots")
	_setup_slot(slot_necklace, "necklace", "neck")
	_setup_slot(slot_ring1, "ring1", "finger")
	_setup_slot(slot_ring2, "ring2", "finger2")
	_setup_slot(slot_main_hand, "main_hand", "weapon")
	_setup_slot(slot_off_hand, "off_hand", "shield")
	_setup_slot(slot_wings, "wings", "surcoat")
	_setup_slot(slot_pet, "pet", "pet")

func _bind_add_button(btn: Button, stat_name: String) -> void:
	if btn:
		btn.pressed.connect(func():
			_send_lpc_cmd("gaddstat %s 1" % stat_name)
		)

func _on_reset_stats_pressed() -> void:
	var dlg = ConfirmationDialog.new()
	dlg.cancel_button_text = "取消"
	add_child(dlg)

	if current_respecs > 0:
		dlg.title = "重置属性点 (免费)"
		dlg.dialog_text = "确定要消耗 1 次【免费洗点机会】重置所有属性点吗？\n已分配的属性点将 100%% 全额退还为未分配点数。（当前剩余免费: %d 次）" % current_respecs
		dlg.ok_button_text = "确认重置"
		dlg.confirmed.connect(func():
			_send_lpc_cmd("gresetstat")
			dlg.queue_free()
		)
	else:
		var cost = current_respec_price if current_respec_price > 0 else _calc_respec_gold_cost(current_level)
		dlg.title = "重置属性点 (消耗金币)"
		if current_gold < cost:
			dlg.dialog_text = "任务免费洗点次数已用尽！\n本次重置需要消耗金币：%s\n当前拥有金币：%s\n\n【金币不足，无法洗点】" % [
				_format_gold(cost), _format_gold(current_gold)
			]
			dlg.ok_button_text = "我知道了"
			dlg.confirmed.connect(func(): dlg.queue_free())
		else:
			dlg.dialog_text = "任务免费洗点次数已用尽！\n本次重置需要消耗金币：%s\n当前拥有金币：%s\n\n是否确认扣除金币并重置属性点？" % [
				_format_gold(cost), _format_gold(current_gold)
			]
			dlg.ok_button_text = "确认扣费并重置"
			dlg.confirmed.connect(func():
				_send_lpc_cmd("gresetstat")
				dlg.queue_free()
			)

	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()

func _on_buy_respec_pressed() -> void:
	pass

func _setup_slot(btn: Button, slot_key: String, mud_part: String) -> void:
	if not btn:
		return
	btn.mouse_entered.connect(func():
		if equips_map.has(slot_key) and equips_map[slot_key] is Dictionary:
			var it = equips_map[slot_key].duplicate()
			if not it.has("desc") and it.has("item_info") and it["item_info"] is Dictionary:
				it["desc"] = str(it["item_info"].get("desc", ""))
			if not it.has("cmd") and it.has("file_id") and not str(it["file_id"]).is_empty():
				it["cmd"] = "look " + str(it["file_id"])
			item_hovered.emit(it, btn.global_position)
	)
	btn.mouse_exited.connect(func():
		item_unhovered.emit()
	)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if equips_map.has(slot_key) and equips_map[slot_key] is Dictionary:
				var it = equips_map[slot_key]
				var fid = str(it.get("file_id", ""))
				if not fid.is_empty():
					print("[CharacterInfoPanel] 右键卸下装备: %s" % fid)
					_send_lpc_cmd("gremove %s" % fid)
	)
	if btn.has_signal("slot_dropped"):
		btn.slot_dropped.connect(func(data):
			_handle_equip_drop(data)
		)

# ========== 拖拽穿戴装备 (由具体的 PaperdollSlotButton 负责精准类型校验) ==========
func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass

func _handle_equip_drop(data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		var fid = str(it.get("file_id", ""))
		if not fid.is_empty():
			print("[CharacterInfoPanel] 拖拽穿戴装备: %s" % fid)
			_send_lpc_cmd("gwear %s" % fid)

func open() -> void:
	show()
	panel_visibility_changed.emit(true)
	_send_lpc_cmd("gscore")

func close() -> void:
	hide()
	panel_visibility_changed.emit(false)

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

static func _safe_int(val: Variant, default_val: int = 0) -> int:
	if val == null:
		return default_val
	if val is int:
		return val
	if val is float:
		return int(val)
	if val is String:
		return val.to_int() if val.is_valid_int() else default_val
	return default_val

static func _safe_float(val: Variant, default_val: float = 0.0) -> float:
	if val == null:
		return default_val
	if val is float:
		return val
	if val is int:
		return float(val)
	if val is String:
		return val.to_float() if val.is_valid_float() else default_val
	return default_val

# 接收 LPC 的 gscore 数据并刷新界面（纯渲染模式：前端绝不参与数值计算）
func render_gscore_data(data: Dictionary) -> void:
	if not data is Dictionary:
		return
		
	# 1. 基础信息与资源
	var lvl = _safe_int(data.get("level"), 1)
	var hp = _safe_int(data.get("hp"), 0)
	var max_hp = _safe_int(data.get("max_hp"), 1)
	var mp = _safe_int(data.get("mp"), 0)
	var max_mp = _safe_int(data.get("max_mp"), 1)
	var exp = _safe_int(data.get("exp"), 0)
	var next_exp = _safe_int(data.get("next_exp"), 160)
	var exp_pct = float(data.get("exp_pct", -1.0))
	var raw_pts = data.get("stat_points")
	if raw_pts == null:
		raw_pts = data.get("stat_pts", 0)
	current_stat_points = _safe_int(raw_pts, 0)
	
	if lbl_level: lbl_level.text = str(lvl)
	if lbl_exp:
		if exp_pct >= 0.0:
			lbl_exp.text = "%d / %d (%.1f%%)" % [exp, next_exp, exp_pct]
		else:
			lbl_exp.text = "%d / %d" % [exp, next_exp]
	if lbl_hp: lbl_hp.text = "%d / %d" % [hp, max_hp]
	if lbl_mp: lbl_mp.text = "%d / %d" % [mp, max_mp]
	if points_label: points_label.text = str(current_stat_points)

	current_level = lvl
	current_gold = _safe_int(data.get("gold", 0), 0)
	current_respecs = _safe_int(data.get("stat_respecs", data.get("free_respecs", 0)), 0)
	var dynamic_cost = _calc_respec_gold_cost(current_level)
	current_respec_price = _safe_int(data.get("respec_gold_cost", data.get("respec_price", dynamic_cost)), dynamic_cost)

	if lbl_respec_count:
		if current_respecs > 0:
			lbl_respec_count.text = "免费洗点: %d次" % current_respecs
			lbl_respec_count.modulate = Color(0.4, 0.95, 0.4, 1.0)
		else:
			lbl_respec_count.text = "洗点: %s金币" % _format_gold(current_respec_price)
			lbl_respec_count.modulate = Color(0.95, 0.8, 0.3, 1.0)
		lbl_respec_count.tooltip_text = "剩余免费洗点 %d 次。免费次数用尽后，每次洗点消耗 10000+等级^4/2 金币。" % current_respecs

	if btn_buy_respec:
		btn_buy_respec.visible = false
	
	# 2. 四维核心属性（显示实时值与基础加成，如 11 (+1)）
	var str_v = _safe_int(data.get("str"), 10)
	var dex_v = _safe_int(data.get("dex"), 10)
	var vit_v = _safe_int(data.get("vit"), 20)
	var int_v = _safe_int(data.get("int"), 10)
	var b_str = _safe_int(data.get("bonus_str"), 0)
	var b_dex = _safe_int(data.get("bonus_dex"), 0)
	var b_vit = _safe_int(data.get("bonus_vit"), 0)
	var b_int = _safe_int(data.get("bonus_int"), 0)
	
	if val_str: val_str.text = "%d (+%d)" % [str_v, b_str] if b_str > 0 else ("%d (%d)" % [str_v, b_str] if b_str < 0 else str(str_v))
	if val_dex: val_dex.text = "%d (+%d)" % [dex_v, b_dex] if b_dex > 0 else ("%d (%d)" % [dex_v, b_dex] if b_dex < 0 else str(dex_v))
	if val_vit: val_vit.text = "%d (+%d)" % [vit_v, b_vit] if b_vit > 0 else ("%d (%d)" % [vit_v, b_vit] if b_vit < 0 else str(vit_v))
	if val_int: val_int.text = "%d (+%d)" % [int_v, b_int] if b_int > 0 else ("%d (%d)" % [int_v, b_int] if b_int < 0 else str(int_v))
	
	var can_add = current_stat_points > 0
	if btn_add_str: btn_add_str.visible = can_add
	if btn_add_dex: btn_add_dex.visible = can_add
	if btn_add_vit: btn_add_vit.visible = can_add
	if btn_add_int: btn_add_int.visible = can_add
	
	# 3. 详细战斗与探索数值 (纯渲染，全权消费 LPC 下发的最终汇总结果)
	var combat = data.get("combat", {})
	if combat is Dictionary:
		# (1) 综合攻防与命中
		var p_min = _safe_int(combat.get("phy_dmg_min"), 0)
		var p_max = _safe_int(combat.get("phy_dmg_max"), 0)
		var p_dps = _safe_float(combat.get("phy_dps"), 0.0)
		var m_min = _safe_int(combat.get("mag_dmg_min"), 0)
		var m_max = _safe_int(combat.get("mag_dmg_max"), 0)
		var m_dps = _safe_float(combat.get("mag_dps"), 0.0)
		var ar_v = _safe_int(combat.get("ar"), 0)
		var hit_v = _safe_int(combat.get("hit_rate"), 80)
		var def_v = _safe_int(combat.get("defense"), 0)
		var blk_v = _safe_int(combat.get("block_rate"), 0)
		var ed_v = _safe_int(combat.get("dmg_enhance"), 0)

		if lbl_phy_dmg: lbl_phy_dmg.text = "%d ~ %d" % [p_min, p_max]
		if lbl_phy_dps: lbl_phy_dps.text = "%.2f" % p_dps
		if lbl_mag_dmg: lbl_mag_dmg.text = "%d ~ %d" % [m_min, m_max]
		if lbl_mag_dps: lbl_mag_dps.text = "%.2f" % m_dps
		
		var skill_name = str(combat.get("main_skill_name", ""))
		var title_mag = get_node_or_null("%LblMagDmg/../T") as Label
		if title_mag:
			if skill_name != "" and skill_name != "普通攻击":
				title_mag.text = "魔法攻击 (%s)" % skill_name
			else:
				title_mag.text = "魔法攻击"
				
		if lbl_dmg_enhance: lbl_dmg_enhance.text = "%d%%" % ed_v
		if lbl_ar: lbl_ar.text = str(ar_v)
		if lbl_hit_rate: lbl_hit_rate.text = "%d%%" % hit_v
		if lbl_defense: lbl_defense.text = str(def_v)
		if lbl_block: lbl_block.text = "%d%% / 75%%" % blk_v

		# (2) 元素抗性与伤害减免 (带上限与满抗金色/负抗暗红高亮)
		_render_resist(lbl_res_fire, _safe_int(combat.get("res_fire"), 0), _safe_int(combat.get("max_res_fire"), 75), Color(1, 0.45, 0.35, 1))
		_render_resist(lbl_res_cold, _safe_int(combat.get("res_cold"), 0), _safe_int(combat.get("max_res_cold"), 75), Color(0.45, 0.75, 1, 1))
		_render_resist(lbl_res_light, _safe_int(combat.get("res_lightning"), 0), _safe_int(combat.get("max_res_lightning"), 75), Color(1, 0.92, 0.35, 1))
		_render_resist(lbl_res_poison, _safe_int(combat.get("res_poison"), 0), _safe_int(combat.get("max_res_poison"), 75), Color(0.45, 0.95, 0.45, 1))
		
		if lbl_dr_pct: lbl_dr_pct.text = "%d%%" % _safe_int(combat.get("dr_pct"), 0)
		if lbl_dr: lbl_dr.text = str(_safe_int(combat.get("dr"), 0))
		if lbl_mdr: lbl_mdr.text = str(_safe_int(combat.get("mdr"), 0))
		if lbl_plr: lbl_plr.text = "%d%%" % _safe_int(combat.get("plr"), 0)

		# (3) 战斗档位与机动
		if lbl_atk_speed: lbl_atk_speed.text = "%d%%" % _safe_int(combat.get("attack_speed"), 0)
		if lbl_fcr: lbl_fcr.text = "%d%%" % _safe_int(combat.get("fcr"), 0)
		if lbl_fhr: lbl_fhr.text = "%d%%" % _safe_int(combat.get("fhr"), 0)
		if lbl_fbr: lbl_fbr.text = "%d%%" % _safe_int(combat.get("fbr"), 0)
		if lbl_frw: lbl_frw.text = "%d%%" % _safe_int(combat.get("frw"), 0)

		# (4) 打击特技与偷取
		_render_proc(lbl_cb, _safe_int(combat.get("crushing_blow"), 0))
		var ds_val = _safe_int(combat.get("deadly_strike"), 0)
		var ds_eq = _safe_int(combat.get("ds_equip"), 0)
		var cs_sk = _safe_int(combat.get("cs_skill"), 0)
		_render_proc(lbl_ds, ds_val)
		if lbl_ds:
			if ds_eq > 0 and cs_sk > 0:
				lbl_ds.tooltip_text = "综合双倍几率: %d%%\n- 装备致命 (DS): %d%%\n- 技能暴击 (CS): %d%%" % [ds_val, ds_eq, cs_sk]
			elif ds_eq > 0:
				lbl_ds.tooltip_text = "装备致命 (DS): %d%%" % ds_eq
			elif cs_sk > 0:
				lbl_ds.tooltip_text = "技能暴击 (CS): %d%%" % cs_sk
			else:
				lbl_ds.tooltip_text = ""
		_render_proc(lbl_ow, _safe_int(combat.get("open_wounds"), 0))

		# 隐藏非 D2 原版的冗余行（暴击率与暴击伤害）
		if lbl_crit and lbl_crit.get_parent():
			lbl_crit.get_parent().visible = false
		if lbl_crit_dmg and lbl_crit_dmg.get_parent():
			lbl_crit_dmg.get_parent().visible = false
		_render_proc(lbl_ll, _safe_int(combat.get("life_steal"), 0))
		_render_proc(lbl_ml, _safe_int(combat.get("mana_steal"), 0))
		if lbl_lak: lbl_lak.text = str(_safe_int(combat.get("life_after_kill"), 0))
		if lbl_mak: lbl_mak.text = str(_safe_int(combat.get("mana_after_kill"), 0))
		if lbl_itd:
			var is_itd = _safe_int(combat.get("ignore_def"), 0) > 0
			lbl_itd.text = "是" if is_itd else "否"
			lbl_itd.modulate = Color(1, 0.85, 0.3, 1) if is_itd else Color(0.7, 0.7, 0.7, 1)

		# (5) 技能与寻宝探索
		if lbl_all_skills:
			var sk_val = _safe_int(combat.get("all_skills"), 0)
			lbl_all_skills.text = "+%d" % sk_val if sk_val > 0 else str(sk_val)
			lbl_all_skills.modulate = Color(0.35, 1.0, 0.45, 1) if sk_val > 0 else Color(0.7, 0.7, 0.7, 1)
		if lbl_mf: lbl_mf.text = "%d%%" % _safe_int(combat.get("magic_find"), 0)
		if lbl_gf: lbl_gf.text = "%d%%" % _safe_int(combat.get("gold_find"), 0)
		if lbl_light_radius:
			var lr_v = _safe_int(combat.get("light_radius"), 0)
			lbl_light_radius.text = "+%d" % lr_v if lr_v > 0 else str(lr_v)
		if lbl_cannot_be_frozen:
			var no_frz = _safe_int(combat.get("cannot_be_frozen"), 0) > 0
			lbl_cannot_be_frozen.text = "是" if no_frz else "否"
			lbl_cannot_be_frozen.modulate = Color(0.3, 0.9, 1.0, 1) if no_frz else Color(0.7, 0.7, 0.7, 1)
		
	# 4. 纸娃娃穿戴装备映射
	var equips = data.get("equips", {})
	if equips is Dictionary:
		equips_map = equips
		_render_slot(slot_helmet, "helmet", equips.get("helmet"))
		_render_slot(slot_armor, "armor", equips.get("armor"))
		_render_slot(slot_pants, "pants", equips.get("pants"))
		_render_slot(slot_gloves, "gloves", equips.get("gloves"))
		_render_slot(slot_boots, "boots", equips.get("boots"))
		_render_slot(slot_necklace, "necklace", equips.get("necklace"))
		_render_slot(slot_ring1, "ring1", equips.get("ring1"))
		_render_slot(slot_ring2, "ring2", equips.get("ring2"))
		_render_slot(slot_main_hand, "main_hand", equips.get("main_hand"))
		_render_slot(slot_off_hand, "off_hand", equips.get("off_hand"))
		_render_slot(slot_wings, "wings", equips.get("wings"))
		_render_slot(slot_pet, "pet", equips.get("pet"))

func _render_slot(btn: Button, slot_key: String, item_info: Variant) -> void:
	if not btn:
		return
	if btn.has_method("set_slot_data"):
		btn.set_slot_data(slot_key, item_info)
	elif item_info is Dictionary and not item_info.is_empty():
		var icon_path = str(item_info.get("icon", ""))
		var tex = AnsiHelper.load_item_texture(icon_path)
		if tex:
			btn.icon = tex
		btn.modulate = Color(1, 1, 1, 1)
	else:
		btn.icon = null
		btn.modulate = Color(0.65, 0.65, 0.65, 0.75)

func _send_lpc_cmd(cmd: String) -> void:
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net and net.is_connected:
			net.send_raw(cmd)

func _render_resist(lbl: Label, val: int, max_val: int, default_color: Color) -> void:
	if not lbl:
		return
	lbl.text = "%d%% / %d%%" % [val, max_val]
	if val >= max_val and max_val > 0:
		lbl.modulate = Color(1.0, 0.88, 0.25, 1.0) # 满抗暗黑耀金
	elif val < 0:
		lbl.modulate = Color(0.95, 0.25, 0.25, 1.0) # 负抗暗红警示
	else:
		lbl.modulate = default_color

func _render_proc(lbl: Label, val: int) -> void:
	if not lbl:
		return
	lbl.text = "%d%%" % val
	if val > 0:
		lbl.modulate = Color(1.0, 0.78, 0.35, 1.0) # 激活橙黄
	else:
		lbl.modulate = Color(0.65, 0.65, 0.65, 0.85) # 未激活微暗灰
