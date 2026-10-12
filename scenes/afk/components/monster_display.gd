extends Control
class_name AFK_MonsterDisplay

const MonsterTextureMgr = preload("res://scripts/managers/monster_texture_manager.gd")
const AnsiHelperScript = preload("res://scripts/utils/ansi_helper.gd")

@onready var sprite: TextureRect = %MonsterSprite
@onready var name_label: Label = %MonsterNameLabel
@onready var hp_bar: ProgressBar = %MonsterHPBar
@onready var hp_label: Label = %MonsterHPLabel
@onready var attack_bar: ProgressBar = %MonsterAttackBar
@onready var skill_label: Label = %MonsterSkillLabel
@onready var damage_container: Control = %DamageContainer

signal target_clicked(monster_id: String)

# 怪物基础数据
var cur_id: String = ""
var cur_mon_key: String = ""
var cur_hp: int = 0
var max_hp: int = 1
var cur_rank: String = "normal"
var cur_tier: String = MonsterTextureMgr.TIER_MEDIUM
var slot_index: int = -1
var is_focused: bool = false
var is_dying: bool = false

# 生物呼吸算法参数 (Idle Breathing Animation)
var breath_time: float = 0.0
var breath_speed: float = 3.14
var breath_amp_y: float = 0.035
var breath_amp_x: float = 0.015
var base_scale: float = 1.0
var is_breathing_enabled: bool = true

# 受击硬直与血条动效 Tween
var _hit_tween: Tween = null
var _hp_tween: Tween = null
var _is_in_hit_anim: bool = false

# DoT 状态机
var is_poisoned: bool = false
var is_chilled: bool = false
var dot_color: Color = Color.WHITE

# 攻击条模拟
var attack_timer: float = 0.0
var attack_duration: float = 2.0

func _ready() -> void:
	# 随机化呼吸相位差，彻底杜绝群怪机械同步
	breath_time = randf_range(0.0, 6.28)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 彻底告别哥布林！初始化时清空占位贴图并保持隐藏，等待服务端真实数据注入
	if sprite: sprite.texture = null
	visible = false
	if name_label: name_label.text = "正在索敌..."
	if hp_label: hp_label.text = "0/0"
	if hp_bar: hp_bar.value = 100.0
	if skill_label: skill_label.text = "准备中"
	_update_pivot()

func _process(delta: float) -> void:
	# 1. 物理体积守恒的正弦生物呼吸动画
	if is_breathing_enabled and sprite and not _is_in_hit_anim:
		_process_breathing(delta)
		
	# 2. 怪物攻击动作条平滑推进
	if attack_bar and attack_duration > 0.0 and not is_dying:
		var speed_mult = 0.5 if is_chilled else 1.0
		attack_timer += delta * speed_mult
		if attack_timer >= attack_duration * 1.5:
			attack_timer = 0.0
		var pct = clamp(attack_timer / attack_duration, 0.0, 1.0)
		attack_bar.value = pct

## 底部中心接地锚点
func _update_pivot() -> void:
	if sprite:
		sprite.pivot_offset = Vector2(sprite.size.x * 0.5, sprite.size.y)

## 正弦生物呼吸计算
func _process_breathing(delta: float) -> void:
	breath_time += delta * breath_speed
	if breath_time > 628.3: breath_time -= 628.3 # 防浮点溢出
	
	var s = sin(breath_time)
	var sy = base_scale * (1.0 + s * breath_amp_y)
	var sx = base_scale * (1.0 - s * breath_amp_x)
	sprite.scale = Vector2(sx, sy)

## 绑定真实服务端怪物数据
func bind_monster_data(mon_data: Dictionary) -> void:
	if mon_data.is_empty():
		visible = false
		return
		
	visible = true
	cur_id = str(mon_data.get("id", ""))
	var raw_key = str(mon_data.get("mon_key", ""))
	if raw_key.is_empty():
		raw_key = str(mon_data.get("code", "fallen"))
	cur_mon_key = raw_key
	
	var m_name = str(mon_data.get("name", "恶魔"))
	var rank = str(mon_data.get("rank", "normal"))
	cur_rank = rank
	cur_hp = int(mon_data.get("hp", 100))
	max_hp = max(1, int(mon_data.get("max_hp", 100)))
	var lvl = int(mon_data.get("level", 1))
	
	var mon_code = str(mon_data.get("code", ""))
	
	# 1. 获取贴图与尺寸梯队配置 (双参数保障: mon_key + official code)
	var tex = MonsterTextureMgr.get_monster_texture(cur_mon_key, mon_code)
	if sprite:
		sprite.texture = tex
		sprite.visible = true
	visible = true
		
	cur_tier = MonsterTextureMgr.get_monster_tier(cur_mon_key, rank)
	var tier_cfg = MonsterTextureMgr.get_tier_config(cur_tier)
	
	base_scale = tier_cfg["scale"]
	breath_speed = tier_cfg["breath_speed"]
	breath_amp_y = tier_cfg["breath_amp_y"]
	breath_amp_x = tier_cfg["breath_amp_x"]
	
	_update_pivot()
	
	# 动态根据体型自适应头顶血条面板高度
	var np = get_node_or_null("NamePanel")
	if np:
		var head_y = -90.0 * base_scale - 8.0
		np.offset_top = head_y - 50.0
		np.offset_bottom = head_y	
	# 2. 渲染名称与品质色彩 (普通白、勇士蓝、暗金黄、Boss猩红金冠)
	if name_label:
		var prefix = ""
		var col = Color(0.9, 0.9, 0.9, 1.0)
		match rank:
			"champion":
				prefix = "⚡ "
				col = Color(0.2, 0.65, 1.0, 1.0) # 亮蓝
			"unique":
				prefix = "★ "
				col = Color(1.0, 0.84, 0.0, 1.0) # 暗金黄
			"boss":
				prefix = "👑 "
				col = Color(1.0, 0.25, 0.25, 1.0) # 猩红
				
		name_label.text = "%sLv.%d %s" % [prefix, lvl, m_name]
		name_label.add_theme_color_override("font_color", col)
		
	# 3. 渲染真实血条数值
	update_hp(cur_hp, max_hp)

	# 4. 渲染 Debuff 减益徽章 (伤害加深、衰老、降低抗性、剧毒等)
	var dbs = mon_data.get("debuffs", [])
	update_debuffs(dbs if dbs is Array else [])

var _last_debuff_sig: String = ""

## 实时更新怪物减益徽章 (Debuff Badges)
func update_debuffs(debuff_list: Array) -> void:
	_render_debuffs(debuff_list)

## 渲染怪物减益徽章 (Debuff Badges)
func _render_debuffs(debuff_list: Array) -> void:
	var sig: String = ""
	for item in debuff_list:
		if item is Dictionary:
			sig += str(item.get("id", "")) + ","
	if sig == _last_debuff_sig:
		return
	_last_debuff_sig = sig

	var debuff_box = get_node_or_null("NamePanel/VBox/DebuffBox")
	if not debuff_box:
		var vbox = get_node_or_null("NamePanel/VBox")
		if vbox:
			debuff_box = HBoxContainer.new()
			debuff_box.name = "DebuffBox"
			debuff_box.alignment = BoxContainer.ALIGNMENT_CENTER
			debuff_box.add_theme_constant_override("separation", 3)
			vbox.add_child(debuff_box)
			vbox.move_child(debuff_box, 1)

	if not debuff_box: return

	for child in debuff_box.get_children():
		child.queue_free()

	if debuff_list.is_empty():
		debuff_box.visible = false
		return

	debuff_box.visible = true
	for item in debuff_list:
		if not item is Dictionary: continue
		var did = str(item.get("id", ""))
		var dname = str(item.get("name", "减益"))
		var dcol_hex = str(item.get("color", "#ff4444"))
		var dcol = Color.from_string(dcol_hex, Color(1.0, 0.27, 0.27))
		
		var badge = PanelContainer.new()
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(dcol.r * 0.2, dcol.g * 0.2, dcol.b * 0.2, 0.9)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = dcol
		sb.corner_radius_top_left = 2
		sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_right = 2
		sb.corner_radius_bottom_left = 2
		sb.content_margin_left = 3
		sb.content_margin_right = 3
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		badge.add_theme_stylebox_override("panel", sb)

		var lbl = Label.new()
		var icon_sym = "🩸"
		if did == "decrepify": icon_sym = "⌛"
		elif did == "lower_resist": icon_sym = "✨"
		elif did == "poison": icon_sym = "🧪"
		elif did == "chill": icon_sym = "❄"
		elif did == "clay_slow": icon_sym = "🗿"
		lbl.text = "%s %s" % [icon_sym, dname]
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", dcol)
		badge.add_child(lbl)
		badge.tooltip_text = "减益状态: %s" % dname
		debuff_box.add_child(badge)

## 更新当前生命值
func update_hp(hp: int, m_hp: int = -1) -> void:
	cur_hp = max(0, hp)
	if m_hp > 0: max_hp = m_hp
	if max_hp < 1: max_hp = 1
	
	if hp_label:
		hp_label.text = "%d / %d" % [cur_hp, max_hp]
	if hp_bar:
		var pct = (float(cur_hp) / float(max_hp)) * 100.0
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
		_hp_tween = create_tween().bind_node(self)
		_hp_tween.tween_property(hp_bar, "value", pct, 0.12).set_ease(Tween.EASE_OUT)

## 触发真实受击动效 (受击硬直 + 红色闪白 + 弹性恢复)
func play_hit_reaction(is_crit: bool = false) -> void:
	if not sprite: return
	
	_is_in_hit_anim = true
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
		
	_hit_tween = create_tween()
	# 1. 瞬间受击形变 (轻微下压后仰)
	var hit_sy = base_scale * (0.88 if is_crit else 0.93)
	var hit_sx = base_scale * (1.10 if is_crit else 1.05)
	
	# 2. 闪红/闪白
	var flash_col = Color(1.8, 0.4, 0.4, 1.0) if is_crit else Color(1.4, 0.7, 0.7, 1.0)
	sprite.modulate = flash_col
	
	_hit_tween.tween_property(sprite, "scale", Vector2(hit_sx, hit_sy), 0.06).set_ease(Tween.EASE_OUT)
	_hit_tween.parallel().tween_property(sprite, "modulate", _get_current_state_color(), 0.12).set_delay(0.04)
	_hit_tween.tween_property(sprite, "scale", Vector2(base_scale, base_scale), 0.12).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_callback(func():
		_is_in_hit_anim = false
	)

## 设置 DoT 状态 (中剧毒/被冰冻)
func set_dot_state(poison: bool, cold: bool) -> void:
	is_poisoned = poison
	is_chilled = cold
	if not _is_in_hit_anim and sprite:
		sprite.modulate = _get_current_state_color()

func _get_current_state_color() -> Color:
	if is_poisoned:
		return Color(0.45, 1.0, 0.45, 1.0) # 剧毒幽绿
	if is_chilled:
		return Color(0.55, 0.85, 1.0, 1.0) # 冰霜幽蓝
	return Color.WHITE

## 升级 6 系暗黑原版元素飘字引擎 (含暴击大字与 AoE 扩散，支持自身高光大字与队友小字半透分流)
func spawn_damage(amount: int, elem_type: String = "物理", is_crit: bool = false, is_aoe: bool = false, is_attacker_me: bool = true) -> void:
	if not damage_container: return
	
	var lbl = Label.new()
	# 自己打的数字大 (20/28px)；其他人打的数字小 (13/17px)
	var font_sz = 20 if is_attacker_me else 13
	
	# 特殊战况文本判定
	if amount == 0:
		lbl.text = "MISS"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9 if is_attacker_me else 0.55))
	elif amount == -1:
		lbl.text = "DODGE"
		lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.9 if is_attacker_me else 0.55))
	elif amount == -2:
		lbl.text = "BLOCK"
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.9 if is_attacker_me else 0.55))
	else:
		lbl.text = ("-" + str(amount)) if not is_crit else ("💥 -" + str(amount) + "!")
		var color = _get_element_color(elem_type, is_crit)
		if not is_attacker_me:
			color.a = 0.65 # 他人伤害淡化半透
		lbl.add_theme_color_override("font_color", color)
		if is_crit:
			font_sz = 28 if is_attacker_me else 17
		
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0 if is_attacker_me else 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 2 if is_attacker_me else 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2 if is_attacker_me else 1)
	lbl.add_theme_font_size_override("font_size", font_sz)
	
	# 飘字生成位置与抛物线轨迹
	var start_x = 0.0
	var target_x = 0.0
	if is_aoe:
		# AoE 扩散：向左右两侧弧形抛射
		var dir = -1.0 if randf() < 0.5 else 1.0
		start_x = dir * randf_range(30.0, 70.0)
		target_x = start_x + dir * randf_range(20.0, 50.0)
	elif is_attacker_me:
		# 自身伤害：核心中轴上抛
		start_x = randf_range(-20.0, 20.0)
		target_x = start_x + randf_range(-10.0, 10.0)
	else:
		# 队友伤害：略微向外散开
		var dir = -1.0 if randf() < 0.5 else 1.0
		start_x = dir * randf_range(15.0, 45.0)
		target_x = start_x + dir * randf_range(10.0, 25.0)
		
	lbl.position = Vector2(start_x, -50.0)
	damage_container.add_child(lbl)
	
	var tw = create_tween().bind_node(lbl)
	var dur = (0.7 if is_crit else 0.55) if is_attacker_me else (0.6 if is_crit else 0.45)
	var rise_h = (55.0 if is_crit else 42.0) if is_attacker_me else (38.0 if is_crit else 28.0)
	
	tw.tween_property(lbl, "position:y", lbl.position.y - rise_h, dur).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:x", target_x, dur).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.tween_callback(lbl.queue_free)

## 原版 6 系元素色彩映射表
func _get_element_color(elem: String, is_crit: bool) -> Color:
	var el = elem.to_lower()
	if is_crit:
		return Color(1.0, 0.88, 0.1, 1.0) # 暴击大金字
		
	if "冰" in el or "cold" in el:
		return Color(0.29, 0.77, 1.0, 1.0)   # 冰蓝色
	elif "火" in el or "fire" in el:
		return Color(1.0, 0.35, 0.13, 1.0)   # 火焰橙红
	elif "电" in el or "light" in el:
		return Color(1.0, 0.92, 0.23, 1.0)   # 闪电金黄
	elif "毒" in el or "poison" in el:
		return Color(0.3, 0.85, 0.3, 1.0)    # 翠绿色
	elif "魔" in el or "magic" in el:
		return Color(0.88, 0.25, 0.98, 1.0)  # 神秘幻紫
	else:
		return Color(0.95, 0.95, 0.95, 1.0)  # 纯白物理

## 处理点击手动转火
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not cur_id.is_empty() and not is_dying:
			target_clicked.emit(cur_id)

## 收到怪物真实出手事件时触发对齐与周期自适应更新
func trigger_attack(interval: float = -1.0, skill_name: String = "") -> void:
	if is_dying: return
	if interval > 0.05:
		attack_duration = interval
	attack_timer = 0.0
	if attack_bar:
		attack_bar.value = 0.0
		attack_bar.visible = true
	if skill_label:
		var clean_name = AnsiHelperScript.to_plain_text(skill_name).strip_edges()
		if clean_name.is_empty():
			skill_label.text = "普通攻击"
		else:
			skill_label.text = clean_name

## 设置当前是否为主集火目标
func set_focused(focused: bool) -> void:
	is_focused = focused
	if focused:
		modulate = Color.WHITE
	else:
		# 副怪微透明暗淡以凸显主目标
		modulate = Color(0.92, 0.92, 0.95, 0.95)

## 虚空入场渐现动效
func play_spawn_animation() -> void:
	is_dying = false
	is_breathing_enabled = true
	if attack_bar: attack_bar.visible = true
	modulate.a = 0.0
	var tw = create_tween().bind_node(self)
	tw.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

## 死亡灰度消散动效
func play_death_animation(callback: Callable = Callable()) -> void:
	if is_dying: return
	is_dying = true
	is_breathing_enabled = false
	if attack_bar: attack_bar.visible = false
	update_hp(0, max_hp)
	is_focused = false
	
	var tw = create_tween().bind_node(self)
	# 灰度褪色 + 缩放缩小 + 渐隐
	tw.parallel().tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.25).set_ease(Tween.EASE_IN)
	if sprite:
		tw.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.7, base_scale * 0.7), 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_death_animation_finished.bind(callback))

func _on_death_animation_finished(cb: Callable) -> void:
	if cb.is_valid():
		cb.call()

