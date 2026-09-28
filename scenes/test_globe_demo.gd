extends Control

## 血球/法力球 扣血·补血效果演示场景 (临时, 看完可删)
## 运行: Godot 打开本场景直接 F5, 或命令行:
##   Godot_v4.5.1-stable_win64.exe --path . res://scenes/test_globe_demo.tscn

@onready var hp: AFK_Bar = $HPBar
@onready var mp: AFK_Bar = $MPBar

var hp_cur := 162
var hp_max := 162
var mp_cur := 210
var mp_max := 210

func _ready() -> void:
	hp.set_stat(hp_cur, hp_max, false)
	mp.set_stat(mp_cur, mp_max, false)
	_loop()

func _loop() -> void:
	while true:
		# -- 阶段1: 连续两下重击掉血 (白影残迹+激荡波浪)
		await get_tree().create_timer(1.2).timeout
		hp_cur = int(hp_cur * 0.55)
		mp_cur = max(12, mp_cur - int(mp_max * 0.28))
		hp.set_stat(hp_cur, hp_max)
		mp.set_stat(mp_cur, mp_max)
		await get_tree().create_timer(1.0).timeout
		hp_cur = max(18, int(hp_cur * 0.5))
		mp_cur = max(12, mp_cur - int(mp_max * 0.18))
		hp.set_stat(hp_cur, hp_max)
		mp.set_stat(mp_cur, mp_max)
		# -- 阶段2: 濒血停留片刻 (看低液面波浪)
		await get_tree().create_timer(1.8).timeout
		# -- 阶段3: 大血瓶/法力瓶回满 (吞服延迟+涌入动画)
		hp_cur = hp_max
		mp_cur = mp_max
		hp.set_stat(hp_cur, hp_max)
		mp.set_stat(mp_cur, mp_max)
		await get_tree().create_timer(2.6).timeout
