extends Control
class_name AFK_BattleStatistics

@onready var val_time: Label = %ValTime
@onready var val_death: Label = %ValDeath
@onready var val_dps: Label = %ValDPS
@onready var val_heal: Label = %ValHeal
@onready var val_take_dmg: Label = %ValTakeDmg
@onready var val_kill_rate: Label = %ValKillRate
@onready var val_exp_rate: Label = %ValExpRate
@onready var btn_reset: Button = %BtnReset

var elapsed_seconds: float = 0.0
var death_count: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var total_heal: int = 0
var total_kills: int = 0
var total_exp: int = 0

func _ready() -> void:
	if btn_reset and not btn_reset.pressed.is_connected(reset_stats):
		btn_reset.pressed.connect(reset_stats)
	update_display()

func _process(delta: float) -> void:
	elapsed_seconds += delta
	update_display()

## 事件接入接口
func record_damage_dealt(dmg: int) -> void:
	if dmg > 0:
		total_damage_dealt += dmg

func record_damage_taken(dmg: int) -> void:
	if dmg > 0:
		total_damage_taken += dmg

func record_heal(amount: int) -> void:
	if amount > 0:
		total_heal += amount

func record_kill(count: int = 1) -> void:
	if count > 0:
		total_kills += count

func record_exp(amount: int) -> void:
	if amount > 0:
		total_exp += amount

func record_death() -> void:
	death_count += 1
	if val_death:
		val_death.text = str(death_count)

func update_time() -> void:
	if not val_time:
		return
	var total_sec: int = int(elapsed_seconds)
	var hrs: int = total_sec / 3600
	var mins: int = (total_sec % 3600) / 60
	var secs: int = total_sec % 60
	val_time.text = "%02d:%02d:%02d" % [hrs, mins, secs]

func update_display() -> void:
	update_time()
	if val_death: val_death.text = str(death_count)
	
	var sec: float = max(1.0, elapsed_seconds)
	var cur_dps: float = float(total_damage_dealt) / sec
	var cur_take_dps: float = float(total_damage_taken) / sec
	var cur_hps: float = float(total_heal) / sec
	var kpm: float = (float(total_kills) / sec) * 60.0
	var epm: float = (float(total_exp) / sec) * 60.0
	
	if val_dps: val_dps.text = _format_rate(cur_dps)
	if val_heal: val_heal.text = _format_rate(cur_hps)
	if val_take_dmg: val_take_dmg.text = _format_rate(cur_take_dps)
	if val_kill_rate: val_kill_rate.text = "%.2f" % kpm
	if val_exp_rate: val_exp_rate.text = _format_exp_rate(epm)

func _format_rate(val: float) -> String:
	if val >= 1000000.0:
		return "%.1fM" % (val / 1000000.0)
	elif val >= 10000.0:
		return "%.1fK" % (val / 1000.0)
	elif val >= 100.0:
		return "%.0f" % val
	else:
		return "%.1f" % val

func _format_exp_rate(val: float) -> String:
	if val >= 1000000.0:
		return "%.2fM" % (val / 1000000.0)
	elif val >= 1000.0:
		return "%.1fK" % (val / 1000.0)
	else:
		return "%.0f" % val

func reset_stats() -> void:
	elapsed_seconds = 0.0
	death_count = 0
	total_damage_dealt = 0
	total_damage_taken = 0
	total_heal = 0
	total_kills = 0
	total_exp = 0
	update_display()
