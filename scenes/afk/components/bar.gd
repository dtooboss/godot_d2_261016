extends Control
class_name AFK_Bar

@onready var _bar: Control = %Bar
@onready var _label: Label = %Label
@onready var _glow: Control = get_node_or_null("%Glow")

var cur_val: int = 80
var max_val: int = 80
var _mat: ShaderMaterial
var _tween: Tween
var _ghost_ratio: float = 1.0
var _fill_ratio: float = 1.0

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
		_glow.modulate.a = clampf(_fill_ratio * 0.18, 0.0, 0.20)

func _apply_ratios() -> void:
	if _mat:
		_mat.set_shader_parameter("fill_ratio", _fill_ratio)
		_mat.set_shader_parameter("ghost_ratio", _ghost_ratio)
	if _glow:
		_glow.modulate.a = clampf(_fill_ratio * 0.18, 0.0, 0.20)

func update_display() -> void:
	if _label:
		var pct = int(round(_fill_ratio * 100.0))
		_label.text = "%d/%d(%d%%)" % [cur_val, max_val, pct]
