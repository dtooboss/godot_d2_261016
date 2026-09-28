extends LineEdit
class_name ChatInputField

## 支持拖拽装备进入聊天框的原生 LineEdit 扩展
signal item_dropped(item_data: Dictionary)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("item_data"):
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item_data"):
		var it = data.get("item_data", {})
		if it is Dictionary:
			item_dropped.emit(it)
