extends Control
class_name AFK_WorldMap

signal enter_spot(spot_data)
signal closed()

@onready var world_name_label: Label = %WorldNameLabel
@onready var btn_switch_act: Button = %BtnSwitchAct
@onready var btn_close: Button = %BtnClose
@onready var spots_container: Control = %SpotsContainer
@onready var line_container: Control = %LineContainer
@onready var change_world_panel: AFK_ChangeWorldPanel = %ChangeWorldPanel
@onready var map_background: TextureRect = $MapBackground

var current_act_id: String = "act1"
var current_world_name: String = "第一幕：罗格营地"

# 暗黑破坏神2 全 5 幕 (ACT 1 ~ 5) 85 个正统纯单链关卡大地图配置
const ACTS_CONFIG = {
	"act1": {
		"id": "act1",
		"name": "第一幕：罗格营地",
		"bg": "res://mods/vanilla/assets/worlds/1/map.png",
		"min_stage": 1,
		"max_stage": 14,
		"spots": [
			{"stage_id": 1, "name": "鲜血荒地", "lvl": 1, "boss": "尸火斥候", "pos": Vector2(432, 617), "bg": "res://mods/vanilla/assets/worlds/1/1.png"},
			{"stage_id": 2, "name": "冰冷之原", "lvl": 2, "boss": "毕须博须", "pos": Vector2(238, 451), "bg": "res://mods/vanilla/assets/worlds/1/2.png"},
			{"stage_id": 3, "name": "埋骨之地", "lvl": 3, "boss": "血鸦", "pos": Vector2(34, 345), "bg": "res://mods/vanilla/assets/worlds/1/3.png"},
			{"stage_id": 4, "name": "邪恶洞窟", "lvl": 4, "boss": "尸火", "pos": Vector2(163, 142), "bg": "res://mods/vanilla/assets/worlds/1/4.png"},
			{"stage_id": 5, "name": "石块旷野", "lvl": 5, "boss": "拉卡尼休", "pos": Vector2(359, 192), "bg": "res://mods/vanilla/assets/worlds/1/5.png"},
			{"stage_id": 6, "name": "崔斯特姆", "lvl": 6, "boss": "格里斯瓦德", "pos": Vector2(453, 281), "bg": "res://mods/vanilla/assets/worlds/1/6.png"},
			{"stage_id": 7, "name": "地底通道", "lvl": 7, "boss": "巨身蛮兽", "pos": Vector2(517, 247), "bg": "res://mods/vanilla/assets/worlds/1/7.png"},
			{"stage_id": 8, "name": "黑暗森林", "lvl": 8, "boss": "树头木拳", "pos": Vector2(687, 164), "bg": "res://mods/vanilla/assets/worlds/1/8.png"},
			{"stage_id": 9, "name": "黑色荒地", "lvl": 9, "boss": "荒地潜行者", "pos": Vector2(701, 261), "bg": "res://mods/vanilla/assets/worlds/1/9.png"},
			{"stage_id": 10, "name": "遗忘之塔", "lvl": 10, "boss": "女伯爵", "pos": Vector2(699, 313), "bg": "res://mods/vanilla/assets/worlds/1/10.png"},
			{"stage_id": 11, "name": "泰摩高地", "lvl": 11, "boss": "深渊领主", "pos": Vector2(789, 416), "bg": "res://mods/vanilla/assets/worlds/1/11.png"},
			{"stage_id": 12, "name": "修道院外回廊", "lvl": 12, "boss": "铁匠", "pos": Vector2(1004, 551), "bg": "res://mods/vanilla/assets/worlds/1/12.png"},
			{"stage_id": 13, "name": "修道院军营监牢", "lvl": 13, "boss": "骨灰", "pos": Vector2(822, 272), "bg": "res://mods/vanilla/assets/worlds/1/13.png"},
			{"stage_id": 14, "name": "地下墓穴第四层", "lvl": 14, "boss": "安达莉尔", "pos": Vector2(924, 233), "bg": "res://mods/vanilla/assets/worlds/1/14.png"}
		]
	},
	"act2": {
		"id": "act2",
		"name": "第二幕：鲁高因",
		"bg": "res://mods/vanilla/assets/worlds/2/map.png",
		"min_stage": 15,
		"max_stage": 34,
		"spots": [
			{"stage_id": 15, "name": "鲁高因码头卫所", "lvl": 13, "boss": "沙漠掠夺者", "pos": Vector2(276, 557), "bg": "res://mods/vanilla/assets/worlds/2/1.png"},
			{"stage_id": 16, "name": "下水道一层", "lvl": 13, "boss": "燃烧死尸队长", "pos": Vector2(453, 552), "bg": "res://mods/vanilla/assets/worlds/2/2.png"},
			{"stage_id": 17, "name": "下水道二层", "lvl": 13, "boss": "恐惧木乃伊", "pos": Vector2(458, 472), "bg": "res://mods/vanilla/assets/worlds/2/3.png"},
			{"stage_id": 18, "name": "下水道三层", "lvl": 14, "boss": "罗达门特", "pos": Vector2(357, 452), "bg": "res://mods/vanilla/assets/worlds/2/4.png"},
			{"stage_id": 19, "name": "碎石荒野", "lvl": 14, "boss": "沙匪首领", "pos": Vector2(350, 340), "bg": "res://mods/vanilla/assets/worlds/2/5.png"},
			{"stage_id": 20, "name": "干燥高地", "lvl": 15, "boss": "荒漠猎手首领", "pos": Vector2(466, 304), "bg": "res://mods/vanilla/assets/worlds/2/6.png"},
			{"stage_id": 21, "name": "亡者之殿一层", "lvl": 12, "boss": "空洞尸魔", "pos": Vector2(545, 354), "bg": "res://mods/vanilla/assets/worlds/2/7.png"},
			{"stage_id": 22, "name": "亡者之殿二层", "lvl": 13, "boss": "木乃伊祭司", "pos": Vector2(642, 335), "bg": "res://mods/vanilla/assets/worlds/2/8.png"},
			{"stage_id": 23, "name": "亡者之殿三层", "lvl": 13, "boss": "疯狂血巫", "pos": Vector2(633, 206), "bg": "res://mods/vanilla/assets/worlds/2/9.png"},
			{"stage_id": 24, "name": "遥远绿洲", "lvl": 16, "boss": "巨型沙虫幼王", "pos": Vector2(737, 283), "bg": "res://mods/vanilla/assets/worlds/2/10.png"},
			{"stage_id": 25, "name": "蛆虫巢穴", "lvl": 17, "boss": "钻地冰虫", "pos": Vector2(839, 313), "bg": "res://mods/vanilla/assets/worlds/2/11.png"},
			{"stage_id": 26, "name": "失落之城", "lvl": 17, "boss": "暗黑长老", "pos": Vector2(830, 443), "bg": "res://mods/vanilla/assets/worlds/2/12.png"},
			{"stage_id": 27, "name": "古代通道", "lvl": 17, "boss": "古代守护者", "pos": Vector2(872, 530), "bg": "res://mods/vanilla/assets/worlds/2/13.png"},
			{"stage_id": 28, "name": "利爪蝮蛇神殿", "lvl": 14, "boss": "牙皮", "pos": Vector2(948, 654), "bg": "res://mods/vanilla/assets/worlds/2/14.png"},
			{"stage_id": 29, "name": "皇宫监牢", "lvl": 13, "boss": "愚笨魔领主", "pos": Vector2(1078, 609), "bg": "res://mods/vanilla/assets/worlds/2/15.png"},
			{"stage_id": 30, "name": "神秘避难所", "lvl": 14, "boss": "召唤者", "pos": Vector2(1063, 505), "bg": "res://mods/vanilla/assets/worlds/2/16.png"},
			{"stage_id": 31, "name": "术士峡谷", "lvl": 16, "boss": "峡谷狂魔", "pos": Vector2(944, 382), "bg": "res://mods/vanilla/assets/worlds/2/17.png"},
			{"stage_id": 32, "name": "石制古墓", "lvl": 16, "boss": "蠕行死尸", "pos": Vector2(933, 279), "bg": "res://mods/vanilla/assets/worlds/2/18.png"},
			{"stage_id": 33, "name": "塔拉夏古墓", "lvl": 17, "boss": "古代解开者", "pos": Vector2(1037, 289), "bg": "res://mods/vanilla/assets/worlds/2/19.png"},
			{"stage_id": 34, "name": "督瑞尔巢穴", "lvl": 17, "boss": "都瑞尔", "pos": Vector2(1100, 183), "bg": "res://mods/vanilla/assets/worlds/2/20.png"}
		]
	},
	"act3": {
		"id": "act3",
		"name": "第三幕：库拉斯特海港",
		"bg": "res://mods/vanilla/assets/worlds/3/map.png",
		"min_stage": 35,
		"max_stage": 56,
		"spots": [
			{"stage_id": 35, "name": "库拉斯特外港防线", "lvl": 20, "boss": "雨林猎手", "pos": Vector2(266, 581), "bg": "res://mods/vanilla/assets/worlds/3/1.png"},
			{"stage_id": 36, "name": "蜘蛛森林", "lvl": 21, "boss": "烈火之指", "pos": Vector2(159, 373), "bg": "res://mods/vanilla/assets/worlds/3/2.png"},
			{"stage_id": 37, "name": "蜘蛛洞窟", "lvl": 21, "boss": "燃烧者·韦布", "pos": Vector2(195, 294), "bg": "res://mods/vanilla/assets/worlds/3/3.png"},
			{"stage_id": 38, "name": "蜘蛛巢穴", "lvl": 21, "boss": "巨蛛母后", "pos": Vector2(322, 257), "bg": "res://mods/vanilla/assets/worlds/3/4.png"},
			{"stage_id": 39, "name": "庞大湿地", "lvl": 21, "boss": "湿地巨鳄", "pos": Vector2(433, 250), "bg": "res://mods/vanilla/assets/worlds/3/5.png"},
			{"stage_id": 40, "name": "剥皮丛林", "lvl": 22, "boss": "剥皮酋长", "pos": Vector2(459, 332), "bg": "res://mods/vanilla/assets/worlds/3/6.png"},
			{"stage_id": 41, "name": "剥皮地窖一层", "lvl": 22, "boss": "剥皮狂战士", "pos": Vector2(435, 501), "bg": "res://mods/vanilla/assets/worlds/3/7.png"},
			{"stage_id": 42, "name": "剥皮地窖二层", "lvl": 22, "boss": "白骨女巫", "pos": Vector2(473, 563), "bg": "res://mods/vanilla/assets/worlds/3/8.png"},
			{"stage_id": 43, "name": "剥皮地窖三层", "lvl": 22, "boss": "古巫医·印杜古", "pos": Vector2(514, 643), "bg": "res://mods/vanilla/assets/worlds/3/9.png"},
			{"stage_id": 44, "name": "下库拉斯特", "lvl": 22, "boss": "萨卡兰姆狂热领袖", "pos": Vector2(559, 389), "bg": "res://mods/vanilla/assets/worlds/3/10.png"},
			{"stage_id": 45, "name": "库拉斯特商场", "lvl": 22, "boss": "市集撕裂者", "pos": Vector2(574, 254), "bg": "res://mods/vanilla/assets/worlds/3/11.png"},
			{"stage_id": 46, "name": "残破神庙", "lvl": 23, "boss": "战场处女·萨琳娜", "pos": Vector2(740, 125), "bg": "res://mods/vanilla/assets/worlds/3/12.png"},
			{"stage_id": 47, "name": "废弃神庙", "lvl": 23, "boss": "神庙守卫者", "pos": Vector2(838, 156), "bg": "res://mods/vanilla/assets/worlds/3/13.png"},
			{"stage_id": 48, "name": "遗忘神庙", "lvl": 24, "boss": "黑石圣殿主", "pos": Vector2(785, 260), "bg": "res://mods/vanilla/assets/worlds/3/14.png"},
			{"stage_id": 49, "name": "库拉斯特下水道一层", "lvl": 23, "boss": "下水道恶鬼", "pos": Vector2(720, 389), "bg": "res://mods/vanilla/assets/worlds/3/15.png"},
			{"stage_id": 50, "name": "库拉斯特下水道二层", "lvl": 23, "boss": "腐败心脏", "pos": Vector2(775, 486), "bg": "res://mods/vanilla/assets/worlds/3/16.png"},
			{"stage_id": 51, "name": "上库拉斯特", "lvl": 23, "boss": "高阶审判官", "pos": Vector2(919, 452), "bg": "res://mods/vanilla/assets/worlds/3/17.png"},
			{"stage_id": 52, "name": "库拉斯特堤道", "lvl": 24, "boss": "堤道重骑兵", "pos": Vector2(932, 338), "bg": "res://mods/vanilla/assets/worlds/3/18.png"},
			{"stage_id": 53, "name": "崔凡克", "lvl": 24, "boss": "瘸子·伊斯梅尔", "pos": Vector2(902, 256), "bg": "res://mods/vanilla/assets/worlds/3/19.png"},
			{"stage_id": 54, "name": "憎恨囚牢一层", "lvl": 25, "boss": "吸血领主", "pos": Vector2(999, 220), "bg": "res://mods/vanilla/assets/worlds/3/20.png"},
			{"stage_id": 55, "name": "憎恨囚牢二层", "lvl": 25, "boss": "不死剥皮者", "pos": Vector2(1136, 228), "bg": "res://mods/vanilla/assets/worlds/3/21.png"},
			{"stage_id": 56, "name": "憎恨王座", "lvl": 25, "boss": "墨菲斯托", "pos": Vector2(1092, 111), "bg": "res://mods/vanilla/assets/worlds/3/22.png"}
		]
	},
	"act4": {
		"id": "act4",
		"name": "第四幕：群魔堡垒",
		"bg": "res://mods/vanilla/assets/worlds/4/map.png",
		"min_stage": 57,
		"max_stage": 64,
		"spots": [
			{"stage_id": 57, "name": "堡垒外侧前哨", "lvl": 26, "boss": "深渊观察者", "pos": Vector2(194, 595), "bg": "res://mods/vanilla/assets/worlds/4/1.png"},
			{"stage_id": 58, "name": "郊外大草原", "lvl": 26, "boss": "草原恶魔", "pos": Vector2(502, 523), "bg": "res://mods/vanilla/assets/worlds/4/2.png"},
			{"stage_id": 59, "name": "绝望平原", "lvl": 26, "boss": "衣卒尔", "pos": Vector2(596, 348), "bg": "res://mods/vanilla/assets/worlds/4/3.png"},
			{"stage_id": 60, "name": "神罚之城", "lvl": 27, "boss": "受罚幽魂", "pos": Vector2(695, 333), "bg": "res://mods/vanilla/assets/worlds/4/4.png"},
			{"stage_id": 61, "name": "火焰之河", "lvl": 27, "boss": "铁匠·赫法斯托", "pos": Vector2(757, 401), "bg": "res://mods/vanilla/assets/worlds/4/5.png"},
			{"stage_id": 62, "name": "混沌避难所", "lvl": 28, "boss": "混沌骑士", "pos": Vector2(844, 314), "bg": "res://mods/vanilla/assets/worlds/4/6.png"},
			{"stage_id": 63, "name": "混沌封印殿", "lvl": 28, "boss": "大西席·墨菲", "pos": Vector2(941, 260), "bg": "res://mods/vanilla/assets/worlds/4/7.png"},
			{"stage_id": 64, "name": "恐惧王座", "lvl": 28, "boss": "迪亚波罗", "pos": Vector2(966, 123), "bg": "res://mods/vanilla/assets/worlds/4/8.png"}
		]
	},
	"act5": {
		"id": "act5",
		"name": "第五幕：哈洛加斯",
		"bg": "res://mods/vanilla/assets/worlds/5/map.png",
		"min_stage": 65,
		"max_stage": 81,
		"spots": [
			{"stage_id": 65, "name": "哈洛加斯城塞", "lvl": 30, "boss": "破城恶魔", "pos": Vector2(248, 481), "bg": "res://mods/vanilla/assets/worlds/5/1.png"},
			{"stage_id": 66, "name": "血腥丘陵", "lvl": 32, "boss": "督军山克", "pos": Vector2(382, 361), "bg": "res://mods/vanilla/assets/worlds/5/2.png"},
			{"stage_id": 67, "name": "冰冻高地", "lvl": 33, "boss": "矫正者·艾尔德利奇", "pos": Vector2(305, 301), "bg": "res://mods/vanilla/assets/worlds/5/3.png"},
			{"stage_id": 68, "name": "亚瑞特高原", "lvl": 34, "boss": "利牙·凹槽", "pos": Vector2(392, 238), "bg": "res://mods/vanilla/assets/worlds/5/4.png"},
			{"stage_id": 69, "name": "晶化通道", "lvl": 35, "boss": "极寒潜伏者", "pos": Vector2(481, 308), "bg": "res://mods/vanilla/assets/worlds/5/5.png"},
			{"stage_id": 70, "name": "冰冻之河", "lvl": 35, "boss": "冰霜女巫", "pos": Vector2(486, 364), "bg": "res://mods/vanilla/assets/worlds/5/6.png"},
			{"stage_id": 71, "name": "冰川小径", "lvl": 36, "boss": "碎骨者", "pos": Vector2(569, 355), "bg": "res://mods/vanilla/assets/worlds/5/7.png"},
			{"stage_id": 72, "name": "悲痛殿堂", "lvl": 36, "boss": "痛苦典狱长", "pos": Vector2(475, 444), "bg": "res://mods/vanilla/assets/worlds/5/8.png"},
			{"stage_id": 73, "name": "瓦特殿堂", "lvl": 38, "boss": "尼拉塞克", "pos": Vector2(694, 435), "bg": "res://mods/vanilla/assets/worlds/5/9.png"},
			{"stage_id": 74, "name": "冰冻苔原", "lvl": 37, "boss": "苔原巨兽", "pos": Vector2(814, 420), "bg": "res://mods/vanilla/assets/worlds/5/10.png"},
			{"stage_id": 75, "name": "远古之路", "lvl": 38, "boss": "先祖斥候", "pos": Vector2(588, 260), "bg": "res://mods/vanilla/assets/worlds/5/11.png"},
			{"stage_id": 76, "name": "亚瑞特山巅", "lvl": 39, "boss": "古代野蛮人先祖", "pos": Vector2(720, 165), "bg": "res://mods/vanilla/assets/worlds/5/12.png"},
			{"stage_id": 77, "name": "世界石要塞一层", "lvl": 40, "boss": "要塞守卫", "pos": Vector2(748, 292), "bg": "res://mods/vanilla/assets/worlds/5/13.png"},
			{"stage_id": 78, "name": "世界石要塞二层", "lvl": 41, "boss": "黑魂幽灵", "pos": Vector2(850, 330), "bg": "res://mods/vanilla/assets/worlds/5/14.png"},
			{"stage_id": 79, "name": "世界石要塞三层", "lvl": 42, "boss": "血腥狂魔", "pos": Vector2(844, 263), "bg": "res://mods/vanilla/assets/worlds/5/15.png"},
			{"stage_id": 80, "name": "毁灭王座", "lvl": 42, "boss": "毁灭五波首领", "pos": Vector2(812, 195), "bg": "res://mods/vanilla/assets/worlds/5/16.png"},
			{"stage_id": 81, "name": "世界之石大厅", "lvl": 42, "boss": "巴尔", "pos": Vector2(838, 144), "bg": "res://mods/vanilla/assets/worlds/5/17.png"}
		]
	}
}

var current_spots: Array = []
var _user_selected_act: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if map_background:
		map_background.mouse_filter = Control.MOUSE_FILTER_STOP

	if btn_switch_act and change_world_panel:
		btn_switch_act.pressed.connect(func(): 
			change_world_panel.show()
		)
	if btn_close:
		btn_close.pressed.connect(func(): 
			_user_selected_act = false
			hide()
			closed.emit()
		)
	if change_world_panel:
		change_world_panel.world_selected.connect(_on_world_selected)
		change_world_panel.hide()
	
	_auto_locate_act()
	update_progress(GameState.player_max_stage)

func reset_user_selection() -> void:
	_user_selected_act = false

## 智能定位到玩家当前选点或物理身处的大幕
## 优先级 1: 用户在当前打开会话中主动切换了大幕 (_user_selected_act)
## 优先级 2: 玩家当前战斗关卡所属大幕 (GameState.current_stage_info)
## 优先级 3: 玩家当前物理所在城镇/大幕 (GameState.current_location_act)
## 优先级 4: 玩家选点所在的大幕 (GameState.selected_act)
## 优先级 5: 历史最高进度兜底 (仅首次登录无任何选点与所在记录时)
func _auto_locate_act() -> void:
	if _user_selected_act: return

	# 优先对齐当前战斗关卡所属大幕 (在野外战斗挂机时，打开大地图必定直达当前挂机大幕)
	if GameState.current_stage_info is Dictionary and GameState.current_stage_info.has("act"):
		var a_num = AnsiHelper.to_safe_int(GameState.current_stage_info.get("act"), 0)
		if a_num > 0:
			var a_key = "act%d" % a_num
			if ACTS_CONFIG.has(a_key):
				switch_act(a_key, false)
				return

	# 其次对齐当前物理所在城镇/大幕 (身在城镇时打开大地图精准呈现当前幕)
	if GameState.current_location_act != "" and ACTS_CONFIG.has(GameState.current_location_act):
		switch_act(GameState.current_location_act, false)
		return

	# 再次对齐选点所属大幕
	if GameState.selected_act != "" and ACTS_CONFIG.has(GameState.selected_act):
		switch_act(GameState.selected_act, false)
		return

	var max_s = GameState.player_max_stage if "player_max_stage" in GameState else 0
	var next_s = max_s + 1
	if next_s >= 65: switch_act("act5", false)
	elif next_s >= 57: switch_act("act4", false)
	elif next_s >= 35: switch_act("act3", false)
	elif next_s >= 15: switch_act("act2", false)
	else: switch_act("act1", false)

## 切换大幕展现 (底图、据点、连线与标题)
func switch_act(act_id: String, user_explicit: bool = true) -> void:
	if not ACTS_CONFIG.has(act_id): return
	if user_explicit:
		_user_selected_act = true
		
	current_act_id = act_id
	var cfg = ACTS_CONFIG[act_id]
	current_world_name = cfg["name"]
	_update_title_label()
		
	if not map_background:
		map_background = get_node_or_null("MapBackground")
	if map_background and ResourceLoader.exists(cfg["bg"]):
		map_background.texture = load(cfg["bg"])
		
	current_spots.clear()
	for s in cfg["spots"]:
		current_spots.append(s.duplicate(true))
		
	update_progress(GameState.player_max_stage)

func _update_title_label() -> void:
	if not world_name_label: return
	if GameState.is_in_team and not GameState.team_bottleneck_name.is_empty():
		world_name_label.text = "%s (⚠️ 队伍受限: %s)" % [current_world_name, GameState.team_bottleneck_name]
	else:
		world_name_label.text = current_world_name

## 根据玩家最高通关纪录动态刷新据点与路线状态
## 严格纯链式单向解锁逻辑：通关第 N 关，仅且只解锁第 N+1 关
## 难度规则：若玩家处于/已解锁更高难度，低难度的全部站点默认全开；
func update_progress(user_max_stage: int) -> void:
	_update_title_label()
	if current_spots.is_empty():
		var cfg = ACTS_CONFIG.get(current_act_id, ACTS_CONFIG["act1"])
		current_spots.clear()
		for s in cfg["spots"]:
			current_spots.append(s.duplicate(true))

	var cur_max = max(0, user_max_stage)
	
	var player_diff = GameState.selected_difficulty
	if player_diff.is_empty() and GameState.selected_character:
		player_diff = str(GameState.selected_character.get("difficulty", "normal")).to_lower()
	if player_diff == "nightmare": player_diff = "nm"
	
	var unlocked_diff_level = 1
	if GameState.selected_character and not GameState.selected_character.is_empty():
		unlocked_diff_level = AnsiHelper.to_safe_int(GameState.selected_character.get("unlocked_diff", GameState.selected_character.get("d2_diff_unlocked", GameState.selected_character.get("d2_unlocked_diff", 1))), 1)
	
	var cur_diff_level = 1
	if player_diff == "nm": cur_diff_level = 2
	elif player_diff == "hell": cur_diff_level = 3
	
	# 若当前难度低于其已解锁最高难度，低难度站点全开！
	var is_lower_diff_cleared = (cur_diff_level < unlocked_diff_level)

	for s in current_spots:
		var s_id = AnsiHelper.to_safe_int(s.get("stage_id"), 1)
		# 优先采用服务端下发的权威区域等级 (alvl)
		if GameState.has_method("get_stage_alvl"):
			s["lvl"] = GameState.get_stage_alvl(s_id, AnsiHelper.to_safe_int(s.get("lvl"), 1))
		if is_lower_diff_cleared:
			s["cleared"] = true
			s["is_current"] = false
			s["unlocked"] = true
		else:
			s["cleared"] = (s_id <= cur_max)
			s["is_current"] = (s_id == cur_max + 1)
			s["unlocked"] = (s_id <= cur_max + 1)
		
	_create_spots()
	_create_lines()

func _create_spots() -> void:
	if not spots_container: return
	for c in spots_container.get_children():
		c.queue_free()
		
	var spot_scene = load("res://scenes/afk/world_map/battle_spot.tscn")
	for s in current_spots:
		var inst = spot_scene.instantiate()
		inst.position = s["pos"]
		spots_container.add_child(inst)
		inst.setup(s)
		inst.spot_clicked.connect(_on_spot_clicked)

## 纯链式单向连线绘制：从头到尾单一连续黄金大路，彻底消除所有分叉支线
func _create_lines() -> void:
	if not line_container: return
	for c in line_container.get_children():
		c.queue_free()

	if current_spots.size() < 2: return
	
	for i in range(current_spots.size() - 1):
		var s_a = current_spots[i]
		var s_b = current_spots[i + 1]
		var is_unlocked = s_b.get("unlocked", false)
		
		var seg = Line2D.new()
		seg.width = 3.5
		seg.antialiased = true
		if is_unlocked:
			seg.default_color = Color(0.95, 0.82, 0.45, 0.9) # 金黄大路 (已通关/已解锁可达)
		else:
			seg.default_color = Color(0.35, 0.35, 0.35, 0.3) # 暗灰迷雾未涉足
		seg.add_point(s_a["pos"])
		seg.add_point(s_b["pos"])
		line_container.add_child(seg)

func _on_spot_clicked(spot_data: Dictionary) -> void:
	if not spot_data.get("unlocked", true):
		print("[WorldMap] 该据点尚未解锁: ", spot_data.get("name", ""))
		return
	print("[WorldMap] 点击据点: ", spot_data.get("name", ""), " (Stage ", spot_data.get("stage_id", 1), ")")
	
	# 准确记录玩家主动选点状态与所属大幕
	var st_id = AnsiHelper.to_safe_int(spot_data.get("stage_id"), 1)
	GameState.selected_stage_id = st_id
	GameState.selected_act = current_act_id
	GameState.current_stage_info = {
		"stage": st_id,
		"name": spot_data.get("name", ""),
		"act": AnsiHelper.to_safe_int(current_act_id.replace("act", ""), 1)
	}
	
	enter_spot.emit(spot_data)
	hide()

func _on_world_selected(w_id: String, _w_name: String) -> void:
	switch_act(w_id, true)
