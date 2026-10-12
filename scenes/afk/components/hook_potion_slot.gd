extends Panel
class_name AFK_HookPotionSlot

signal slot_dropped(potion_code: String)
signal slot_cleared()

const VALID_POTIONS = [
	"hp1", "hp2", "hp3", "hp4", "hp5",
	"mp1", "mp2", "mp3", "mp4", "mp5",
	"rvs", "rvl"
]

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var it = data.get("item_data", {})
	if not (it is Dictionary) or it.is_empty():
		return false
		
	var code = _extract_potion_code(it)
	return not code.is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		var it = data.get("item_data", {})
		var code = _extract_potion_code(it)
		if not code.is_empty():
			slot_dropped.emit(code)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			slot_cleared.emit()

func _extract_potion_code(it: Dictionary) -> String:
	# 1. 优先提取精确药水代号
	var id_s = str(it.get("id", "")).to_lower()
	if id_s in VALID_POTIONS:
		return id_s
		
	var pcode = str(it.get("potion_code", "")).to_lower()
	if pcode in VALID_POTIONS:
		return pcode
		
	# 2. 从文件 ID 中解析
	var fid = str(it.get("file_id", "")).to_lower()
	for vp in VALID_POTIONS:
		if fid == vp or fid.begins_with(vp + "#") or fid.begins_with(vp + "_"):
			return vp
			
	# 3. 从名称模糊匹配
	var name_s = str(it.get("name", ""))
	if "全面恢复" in name_s: return "rvl"
	if "恢复活力" in name_s: return "rvs"
	if "超级治疗" in name_s: return "hp5"
	if "强效治疗" in name_s: return "hp4"
	if "治疗药水" in name_s: return "hp3"
	if "次级治疗" in name_s: return "hp2"
	if "轻微治疗" in name_s: return "hp1"
	if "超级法力" in name_s: return "mp5"
	if "强效法力" in name_s: return "mp4"
	if "法力药水" in name_s: return "mp3"
	if "次级法力" in name_s: return "mp2"
	if "轻微法力" in name_s: return "mp1"
	
	return ""
