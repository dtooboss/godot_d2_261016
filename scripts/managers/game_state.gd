extends Node

## 全局游戏状态管理单例 (GameState)
## 负责缓存玩家当前通行证、可用角色列表、当前操作角色及主城状态

var current_account: String = ""
var character_list: Array = []
var selected_character: Dictionary = {}
var selected_difficulty: String = "normal" # "normal" | "nm" | "hell"

## 客户端版本号与服务端版本校验信息
const CLIENT_VERSION: String = "0.1"
var version_info: Dictionary = {}

## --- 全局字体偏好管理 (内置暗黑暴雪字体 vs 操作系统清晰字体) ---
const SETTINGS_SAVE_PATH: String = "user://login_settings.json"
const BUILTIN_FONT_PATH: String = "res://assets/fonts/blizzardglobal-v5_81.ttf"
const GLOBAL_THEME_PATH: String = "res://assets/theme/d2_theme.tres"

var use_system_font: bool = false
var _system_font_inst: SystemFont = null
var _builtin_font_inst: Font = null

func _ready() -> void:
	_load_and_apply_font_preference()

func _load_and_apply_font_preference() -> void:
	if FileAccess.file_exists(SETTINGS_SAVE_PATH):
		var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			var json = JSON.new()
			if json.parse(json_str) == OK and json.data is Dictionary:
				use_system_font = bool(json.data.get("use_system_font", false))
	apply_font_preference(use_system_font)

## 全局热切换字体偏好并广播给全场景树
func apply_font_preference(enable_system_font: bool) -> void:
	use_system_font = enable_system_font
	
	if not _builtin_font_inst:
		if ResourceLoader.exists(BUILTIN_FONT_PATH):
			_builtin_font_inst = load(BUILTIN_FONT_PATH)
	
	if not _system_font_inst:
		_system_font_inst = SystemFont.new()
		_system_font_inst.font_names = PackedStringArray([
			"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei", "Segoe UI", "sans-serif"
		])
		_system_font_inst.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_system_font_inst.hinting = TextServer.HINTING_LIGHT
	
	var target_font: Font = _system_font_inst if use_system_font else _builtin_font_inst
	if not target_font:
		return
		
	# 1. 动态注入全局主题 (d2_theme.tres)
	if ResourceLoader.exists(GLOBAL_THEME_PATH):
		var global_theme: Theme = load(GLOBAL_THEME_PATH)
		if global_theme:
			global_theme.default_font = target_font
			global_theme.set_font("font", "Label", target_font)
			global_theme.set_font("font", "Button", target_font)
			global_theme.set_font("font", "CheckBox", target_font)
			global_theme.set_font("font", "LineEdit", target_font)
			global_theme.set_font("normal_font", "RichTextLabel", target_font)
			global_theme.set_font("bold_font", "RichTextLabel", target_font)
			
	# 2. 注入全局 ThemeDB 兜底字体
	if "fallback_font" in ThemeDB:
		ThemeDB.fallback_font = target_font
		
	# 3. 广播主题刷新通知，让当前活动场景即刻热重绘
	var tree = get_tree()
	if tree and tree.root:
		tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)

var player_id: String:
	get:
		return get_my_character_id()

# 职业代号到头像与全称的映射字典
const CLASS_INFO = {
	"ama": { "name": "亚马逊", "icon": "res://assets/avatars/amazon.png" },
	"asn": { "name": "刺客", "icon": "res://assets/avatars/assassin.png" },
	"bar": { "name": "野蛮人", "icon": "res://assets/avatars/barbarian.png" },
	"dru": { "name": "德鲁伊", "icon": "res://assets/avatars/druid.png" },
	"nec": { "name": "死灵法师", "icon": "res://assets/avatars/necromancer.png" },
	"pal": { "name": "圣骑士", "icon": "res://assets/avatars/paladin.png" },
	"sor": { "name": "法师", "icon": "res://assets/avatars/sorceress.png" }
}

func get_class_icon(cls: String) -> Texture2D:
	var info = CLASS_INFO.get(cls.to_lower(), null)
	if info and ResourceLoader.exists(info.icon):
		return load(info.icon)
	return load("res://assets/avatars/sorceress.png") # 默认兜底

func get_class_display_name(cls: String) -> String:
	var info = CLASS_INFO.get(cls.to_lower(), null)
	if info:
		return info.name
	return "未知英雄"

## --- 全局聊天与传音历史缓存 (跨场景保持连贯) ---
signal chat_message_added(bbcode: String, snippet: String)

var chat_history: Array[String] = []
var latest_chat_snippet: String = "暂无新的传音消息"
const MAX_CHAT_HISTORY: int = 100

const AnsiHelperScript = preload("res://scripts/utils/ansi_helper.gd")

func add_chat_message(bbcode: String, snippet: String = "") -> void:
	var clean_bbcode = bbcode.strip_edges(false, true)
	chat_history.append(clean_bbcode)
	if chat_history.size() > MAX_CHAT_HISTORY:
		chat_history.pop_front()
	
	if not snippet.is_empty():
		latest_chat_snippet = AnsiHelperScript.to_plain_text(AnsiHelperScript.strip_bbcode(snippet))
	else:
		latest_chat_snippet = AnsiHelperScript.to_plain_text(AnsiHelperScript.strip_bbcode(clean_bbcode))
	latest_chat_snippet = latest_chat_snippet.replace("\n", " ").strip_edges()
		
	chat_message_added.emit(clean_bbcode, latest_chat_snippet)

## --- 全局队伍状态管理 (支持主城与野外战斗常驻) ---
signal team_updated(members: Array)

var current_team_members: Array = []
var current_team_leader: String = ""
var is_in_team: bool = false
var team_bottleneck_name: String = ""
## --- 关卡与世界三权分立状态 (选点、物理所在、解锁大幕) ---
# 1. 选点状态 (玩家在大地图或挂机房指定的关卡与所属幕)
var selected_stage_id: int = 1
var selected_act: String = "act1"
var current_stage_info: Dictionary = { "stage": 1, "name": "鲜血荒地", "act": 1 }

# 2. 当前物理所在状态 (主城/野外真实归属)
var current_town_name: String = "罗格营地"
var current_location_act: String = "act1"

# 3. 解锁大幕权威列表 (完全由后端 LPC 下发的 worlds 驱动)
var unlocked_worlds: Array = []
var player_max_stage: int = 0

# 4. 关卡权威区域等级字典 (由后端 stage_info 动态下发，形如 {"1": 36, "2": 37, ...})
var stage_alvls: Dictionary = {}

# 5. 跨场景死亡休整倒计时剩余秒数 (用于队长护送倒地队员回城时在营地无缝接续倒计时)
var death_countdown_remain: float = 0.0

func get_stage_alvl(stage_id: int, fallback_lvl: int = 1) -> int:
	var key = str(stage_id)
	if stage_alvls.has(key):
		return AnsiHelper.to_safe_int(stage_alvls[key], fallback_lvl)
	return fallback_lvl

var player_level: int:
	get:
		if selected_character and not selected_character.is_empty():
			return AnsiHelper.to_safe_int(selected_character.get("level"), 1)
		return 1

func update_team_data(leader_id: String, members: Array) -> void:
	current_team_leader = leader_id
	current_team_members = members
	is_in_team = members.size() > 1
	team_updated.emit(current_team_members)

func clear_team() -> void:
	current_team_leader = ""
	current_team_members.clear()
	is_in_team = false
	team_bottleneck_name = ""
	team_updated.emit([])

func get_my_character_id() -> String:
	var mid = str(selected_character.get("id", ""))
	if mid.is_empty():
		mid = str(selected_character.get("char_id", ""))
	return mid

func is_team_leader() -> bool:
	if not is_in_team: return true
	var my_id = get_my_character_id()
	return my_id == current_team_leader

## 登出时复位全局角色、队伍与临时状态
func reset_on_logout() -> void:
	selected_character.clear()
	selected_difficulty = "normal"
	clear_team()
	team_bottleneck_name = ""
	chat_history.clear()
	latest_chat_snippet = "暂无新的传音消息"
	unlocked_worlds.clear()
	player_max_stage = 0
	current_town_name = "罗格营地"
	current_location_act = "act1"
	selected_stage_id = 1
	selected_act = "act1"
	current_stage_info = { "stage": 1, "name": "鲜血荒地", "act": 1 }
	stage_alvls.clear()
