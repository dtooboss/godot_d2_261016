extends PanelContainer

## 角色卡片组件 (CharacterCard)
## 展示英雄头像、名字、职业、等级与生命状态，支持点击选中

signal card_selected(char_data: Dictionary)

@onready var avatar_rect: TextureRect = $HBox/AvatarMargin/AvatarRect
@onready var name_label: Label = $HBox/InfoBox/NameLabel
@onready var class_level_label: Label = $HBox/InfoBox/ClassLevelLabel
@onready var select_btn: Button = $SelectButton

var character_data: Dictionary = {}
var is_selected: bool = false

func _ready() -> void:
	select_btn.pressed.connect(_on_pressed)

func setup(data: Dictionary, selected: bool = false) -> void:
	character_data = data
	is_selected = selected
	
	var char_name = str(data.get("name", "未命名"))
	var cls = str(data.get("class", "sor"))
	var cls_display = str(data.get("class_name", GameState.get_class_display_name(cls)))
	var level = int(data.get("level", 1))
	
	# 设置文本
	name_label.text = char_name
	class_level_label.text = "Lv.%d %s" % [level, cls_display]
	
	# 设置头像
	avatar_rect.texture = GameState.get_class_icon(cls)
	
	update_selection_visual()

func set_selected(val: bool) -> void:
	is_selected = val
	update_selection_visual()

func update_selection_visual() -> void:
	if is_selected:
		self.modulate = Color(1.15, 1.1, 0.9)
		name_label.modulate = Color(1.0, 0.85, 0.4) # 金色高亮
	else:
		self.modulate = Color(0.85, 0.85, 0.85)
		name_label.modulate = Color(0.9, 0.9, 0.9)

func _on_pressed() -> void:
	emit_signal("card_selected", character_data)
