extends Control
class_name AFK_PlayerBottomBar

const AnsiHelperScript = preload("res://scripts/utils/ansi_helper.gd")

@onready var hp_bar: AFK_Bar = %HPBar
@onready var mp_bar: AFK_Bar = %MPBar
@onready var player_info_label: Label = %PlayerInfoLabel
@onready var attack_progress_bar: ProgressBar = %AttackProgressBar
@onready var skill_name_label: Label = %SkillNameLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var exp_label: Label = %ExpLabel

var current_exp: int = 0
var max_exp: int = 160
var attack_timer: float = 0.0
var attack_duration: float = 1.5

func _ready() -> void:
	update_player_info("Lv.1 哈哈哈")
	update_hp(38, 80)
	update_mp(70, 70)
	update_exp(0, 160)

func _process(delta: float) -> void:
	if attack_duration > 0.0 and attack_progress_bar:
		attack_timer += delta
		# 跑满后平滑停留在 1.0 等待下一次出手帧归零，或者若超过 1.5 倍周期间隔自循环兜底
		if attack_timer >= attack_duration * 1.5:
			attack_timer = 0.0
		var pct = clamp(attack_timer / attack_duration, 0.0, 1.0)
		attack_progress_bar.value = pct

## 收到玩家真实出手事件时触发对齐与周期自适应更新
func trigger_attack(interval: float = -1.0) -> void:
	if interval > 0.05:
		attack_duration = interval
	attack_timer = 0.0
	if attack_progress_bar:
		attack_progress_bar.value = 0.0

## 设置当前主攻技能显示 (严格过滤 ANSI 控制符与颜色码)
func set_main_skill(skill_name: String, _skill_code: String = "") -> void:
	if skill_name_label:
		var clean_name = AnsiHelperScript.to_plain_text(skill_name).strip_edges()
		if clean_name.is_empty():
			skill_name_label.text = "普通攻击"
		else:
			skill_name_label.text = "【主攻】" + clean_name

func update_player_info(text: String) -> void:
	if player_info_label:
		player_info_label.text = text

func update_hp(cur: int, maximum: int) -> void:
	if not hp_bar:
		hp_bar = get_node_or_null("%HPBar")
	if hp_bar:
		hp_bar.set_stat(cur, maximum)

func update_mp(cur: int, maximum: int) -> void:
	if not mp_bar:
		mp_bar = get_node_or_null("%MPBar")
	if mp_bar:
		mp_bar.set_stat(cur, maximum)

## 触发法力球施法脉冲激荡（出招翻涌与高光）
func pulse_mp() -> void:
	if not mp_bar:
		mp_bar = get_node_or_null("%MPBar")
	if mp_bar and mp_bar.has_method("pulse_cast"):
		mp_bar.pulse_cast()

## 纯后端数据驱动更新经验条 (零前端死算，完美适配满级 MAX 与后端直出百分比)
func update_exp(cur: int, maximum: int, pct_override: float = -1.0) -> void:
	current_exp = cur
	max_exp = max(1, maximum)
	var pct: float = 0.0
	if pct_override >= 0.0:
		pct = clamp(pct_override, 0.0, 100.0)
	else:
		pct = clamp((float(cur) / float(max_exp)) * 100.0, 0.0, 100.0)
		
	if exp_bar:
		exp_bar.value = pct
	if exp_label:
		if maximum <= 0:
			exp_label.text = "MAX / MAX (100.0%)"
		else:
			exp_label.text = "%s / %s (%.1f%%)" % [_format_number(cur), _format_number(max_exp), pct]

## 升级金光高光微动效
func play_level_up_fx() -> void:
	if exp_bar:
		var tw = create_tween()
		tw.tween_property(exp_bar, "modulate", Color(2.0, 1.8, 0.5, 1.0), 0.15)
		tw.tween_property(exp_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
	if player_info_label:
		player_info_label.pivot_offset = player_info_label.size * 0.5
		var tw2 = create_tween()
		tw2.tween_property(player_info_label, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(player_info_label, "scale", Vector2(1.0, 1.0), 0.25)

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
