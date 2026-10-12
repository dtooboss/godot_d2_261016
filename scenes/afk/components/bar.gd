extends Control
class_name AFK_Bar

@onready var _bar: Control = %Bar
@onready var _label: Label = %Label
@onready var _glow: Control = get_node_or_null("%Glow")

var cur_val: int = 80
var max_val: int = 80
var _mat: ShaderMaterial
var _tween: Tween
var _pulse_tween: Tween
var _ghost_ratio: float = 1.0
var _fill_ratio: float = 1.0
var _glow_pulse: float = 0.0

func _ensure_init() -> void:
	if not _bar:
		_bar = get_node_or_null("%Bar")
	if _bar and not _mat and _bar.material is ShaderMaterial:
		_mat = _bar.material
	if not _label:
		_label = get_node_or_null("%Label")
	if not _glow:
		_glow = get_node_or_null("%Glow")

func _ready() -> void:
	_ensure_init()
	_ghost_ratio = float(cur_val) / float(max(1, max_val))
	_fill_ratio = _ghost_ratio
	_apply_ratios()
	update_display()

## 施法法力脉冲激荡（出招时即便满蓝秒吸回，水面也会剧烈震荡、下压微弹并爆发奥术高光）
func pulse_cast() -> void:
	_ensure_init()
	if not is_inside_tree() or not _mat:
		return

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_parallel(true)

	# 1. 奥术高光外溢爆闪
	_glow_pulse = 0.35
	_pulse_tween.tween_property(self, "_glow_pulse", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. 激荡剧烈大波浪 (0.007 -> 0.022) 并在 0.4s 内衰减平复
	_mat.set_shader_parameter("wave_amplitude", 0.022)
	_pulse_tween.tween_property(_mat, "shader_parameter/wave_amplitude", 0.007, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3. 水位微幅下压与反弹 (Dip & Bounce)
	# 若水位在 90% 以上（顶在球顶看不见水面），瞬间下沉约 7% 露出翻滚液面与浪花，随后迅速弹回
	var real_target_ratio = clampf(float(cur_val) / float(max(1, max_val)), 0.0, 1.0)
	if real_target_ratio >= 0.90:
		var dip_ratio = maxf(0.91, real_target_ratio - 0.07)
		var dip_tw = create_tween()
		dip_tw.tween_property(self, "_fill_ratio", dip_ratio, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dip_tw.tween_property(self, "_fill_ratio", real_target_ratio, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_stat(cur: int, maximum: int, animated: bool = true) -> void:
	_ensure_init()
	var old_ratio = _fill_ratio
	cur_val = cur
	max_val = max(1, maximum)
	var new_ratio = clampf(float(cur_val) / float(max_val), 0.0, 1.0)
	
	if not is_inside_tree() or not animated or not _mat:
		_fill_ratio = new_ratio
		_ghost_ratio = new_ratio
		_apply_ratios()
		update_display()
		return
		
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	
	if new_ratio < old_ratio:
		# 1. 受创掉血: 实血迅速下降 (0.15s)，激荡大波浪，受创残影滞后追随
		_tween.tween_property(self, "_fill_ratio", new_ratio, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_mat.set_shader_parameter("wave_amplitude", 0.016)
		_tween.tween_property(_mat, "shader_parameter/wave_amplitude", 0.007, 0.5).set_delay(0.15)
		_tween.tween_property(self, "_ghost_ratio", new_ratio, 0.35).set_delay(0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# 2. 药水/自然回血: D2R 吞服延迟 0.15s，随后波浪涌动平滑注入
		_mat.set_shader_parameter("wave_amplitude", 0.013)
		_tween.tween_property(self, "_fill_ratio", new_ratio, 0.85).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_ghost_ratio", new_ratio, 0.85).set_delay(0.15)
		_tween.tween_property(_mat, "shader_parameter/wave_amplitude", 0.007, 0.5).set_delay(1.0)
		
	# 数值标签平滑同步滚动
	_tween.tween_method(func(v: float):
		if _label:
			var display_cur = int(round(v * float(max_val)))
			_label.text = "%d/%d(%d%%)" % [display_cur, max_val, int(round(v * 100.0))]
	, old_ratio, new_ratio, 0.25 if new_ratio < old_ratio else 0.85)

func _process(_delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fill_ratio", _fill_ratio)
		_mat.set_shader_parameter("ghost_ratio", _ghost_ratio)
	if _glow:
		_glow.modulate.a = clampf(_fill_ratio * 0.18 + _glow_pulse, 0.0, 0.65)

func _apply_ratios() -> void:
	if _mat:
		_mat.set_shader_parameter("fill_ratio", _fill_ratio)
		_mat.set_shader_parameter("ghost_ratio", _ghost_ratio)
	if _glow:
		_glow.modulate.a = clampf(_fill_ratio * 0.18 + _glow_pulse, 0.0, 0.65)

func update_display() -> void:
	if _label:
		var pct = int(round(_fill_ratio * 100.0))
		_label.text = "%d/%d(%d%%)" % [cur_val, max_val, pct]
