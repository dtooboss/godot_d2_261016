extends Control
class_name AFK_BattleSpot

signal spot_clicked(spot_data)

@onready var icon_btn: TextureButton = %IconBtn
@onready var label_panel: PanelContainer = %LabelPanel
@onready var name_label: Label = %NameLabel

var data: Dictionary = {}

func setup(spot_data: Dictionary) -> void:
	data = spot_data
	var s_name = spot_data.get("name", "")
	var s_lvl = spot_data.get("lvl", 1)
	var s_id = spot_data.get("stage_id", 0)
	var is_cleared = spot_data.get("cleared", false)
	var is_current = spot_data.get("is_current", false)
	var is_unlocked = spot_data.get("unlocked", true)
	var is_town = spot_data.get("is_town", false)
	var is_boss_level = (s_id == 13 or s_id == 14)

	if name_label:
		if is_town:
			name_label.text = "🌟 %s (小站)" % s_name
		else:
			name_label.text = "Lv.%d %s" % [s_lvl, s_name]
	
	# 设置据点标签样式 (小站奥术幽蓝、Boss关红边、已通关翠绿、当前挑战关高亮绿底金框、未解锁暗灰)
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	
	if is_town:
		# 安全区小站：明亮奥术蔚蓝神圣底色 + 符文金光边框，100%满亮度图标，极度醒目
		style.bg_color = Color(0.12, 0.40, 0.82, 0.96)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.88, 0.35, 1.0)
		if name_label:
			name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85, 1.0))
		if icon_btn:
			icon_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif not is_unlocked:
		# 未解锁：暗灰沉寂，半透明置灰，光标禁用
		style.bg_color = Color(0.18, 0.20, 0.22, 0.85)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.28, 0.30, 0.33, 0.8)
		if name_label:
			name_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62, 0.75))
		if icon_btn:
			icon_btn.modulate = Color(0.4, 0.4, 0.4, 0.45)
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	elif is_current:
		# 当前正在推进点（已点亮解锁）：醒目点亮并带高亮金边，明确当前可挑战
		if is_boss_level:
			style.bg_color = Color(0.65, 0.12, 0.12, 0.95) # 终极 Boss 鲜红王座
		else:
			style.bg_color = Color(0.14, 0.52, 0.22, 0.95) # 亮绿点亮底
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.88, 0.25, 1.0) # 金色激活外框
		if name_label:
			name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.75, 1.0))
		if icon_btn:
			icon_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif is_cleared:
		# 已通关历史关卡：翠绿通关底
		style.bg_color = Color(0.12, 0.45, 0.18, 0.92) # 翠绿底色
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.35, 0.82, 0.45, 0.8)
		if name_label:
			name_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95, 1.0))
		if icon_btn:
			icon_btn.modulate = Color(0.9, 1.0, 0.9, 1.0)
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		# 普通已解锁
		style.bg_color = Color(0.15, 0.18, 0.25, 0.92)
		if name_label:
			name_label.remove_theme_color_override("font_color")
		if icon_btn:
			icon_btn.modulate = Color.WHITE
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
	if label_panel:
		label_panel.add_theme_stylebox_override("panel", style)

func _ready() -> void:
	if icon_btn:
		icon_btn.pressed.connect(func():
			if not data.get("unlocked", true):
				return
			spot_clicked.emit(data)
		)
