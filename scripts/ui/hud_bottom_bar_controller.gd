extends Control

## 暗黑破坏神2 经典底部 HUD 双球控制器 (HudBottomBarController)
## 管理天使生命红球、恶魔魔力蓝球平滑波浪流体与中央系统按键

signal bag_pressed
signal party_pressed
signal leave_town_pressed

@onready var hp_liquid: ColorRect = $LeftGlobe/HpLiquid
@onready var hp_label: Label = $LeftGlobe/HpLabel
@onready var mp_liquid: ColorRect = $RightGlobe/MpLiquid
@onready var mp_label: Label = $RightGlobe/MpLabel

@onready var btn_bag: Button = $CenterPanel/HBox/BtnBag
@onready var btn_party: Button = $CenterPanel/HBox/BtnParty
@onready var btn_leave: Button = $CenterPanel/HBox/BtnLeave

var current_hp: int = 100
var max_hp: int = 100
var current_mp: int = 50
var max_mp: int = 50

var hp_tween: Tween
var mp_tween: Tween

func _ready() -> void:
	btn_bag.pressed.connect(func(): bag_pressed.emit())
	btn_party.pressed.connect(func(): party_pressed.emit())
	btn_leave.pressed.connect(func(): leave_town_pressed.emit())
	
	# 支持点击球体切换数值显示格式
	$LeftGlobe.gui_input.connect(_on_left_globe_input)
	$RightGlobe.gui_input.connect(_on_right_globe_input)

func update_health(cur: int, max_val: int) -> void:
	current_hp = cur
	max_hp = max(1, max_val)
	hp_label.text = "%d / %d" % [current_hp, max_hp]
	
	var target_ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
	if hp_liquid.material:
		if hp_tween and hp_tween.is_valid():
			hp_tween.kill()
		hp_tween = create_tween()
		hp_tween.tween_property(hp_liquid.material, "shader_parameter/fill_ratio", target_ratio, 0.35)

func update_mana(cur: int, max_val: int) -> void:
	current_mp = cur
	max_mp = max(1, max_val)
	mp_label.text = "%d / %d" % [current_mp, max_mp]
	
	var target_ratio = clamp(float(current_mp) / float(max_mp), 0.0, 1.0)
	if mp_liquid.material:
		if mp_tween and mp_tween.is_valid():
			mp_tween.kill()
		mp_tween = create_tween()
		mp_tween.tween_property(mp_liquid.material, "shader_parameter/fill_ratio", target_ratio, 0.35)

func update_leave_button(text_str: String) -> void:
	btn_leave.text = text_str

var show_hp_percent: bool = false
var show_mp_percent: bool = false

func _on_left_globe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_hp_percent = not show_hp_percent
		if show_hp_percent:
			hp_label.text = "%.1f%%" % (float(current_hp) / float(max_hp) * 100.0)
		else:
			hp_label.text = "%d / %d" % [current_hp, max_hp]

func _on_right_globe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_mp_percent = not show_mp_percent
		if show_mp_percent:
			mp_label.text = "%.1f%%" % (float(current_mp) / float(max_mp) * 100.0)
		else:
			mp_label.text = "%d / %d" % [current_mp, max_mp]
