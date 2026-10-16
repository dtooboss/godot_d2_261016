# monster_texture_manager.gd
# 暗黑破坏神2 怪物贴图与体型尺寸管理服务
# 1. 负责将服务端的 mon_key / code 映射到 res://assets/monsters/ 下的 274 张高清透明 PNG
# 2. 提供小怪、中怪、大怪、史诗 Boss 四级体型构图矩阵（高度、缩放比）
# 3. 提供物理体积守恒呼吸动画的差异化节奏参数

extends RefCounted
class_name MonsterTextureManager

# 四级体型构图定义
const TIER_SMALL = "small"       # 小型怪 (~160px, 缩放 0.68)
const TIER_MEDIUM = "medium"     # 中型怪 (~240px, 缩放 1.0)
const TIER_LARGE = "large"       # 大型/精英 (~310px, 缩放 1.25)
const TIER_BOSS = "boss"         # 史诗魔王 (~400px, 缩放 1.55)

# 经典自造码/MUD键到贴图文件名的显式映射表
const MUDKEY_TO_PNG: Dictionary = {
	# Act 1
	"fallen": "fallen",
	"blood_zombie": "zombie",
	"skeleton": "skeleton",
	"cold_zombie": "zombie",
	"burial_zombie": "zombie",
	"burial_skeleton": "skeletonarcher",
	"stony_carver": "fallen",
	"stony_golem": "brute",
	"cave_bat": "desertwing",
	"cave_skeleton": "skeleton",
	"dark_brute": "brute",
	"dark_hunter": "corruptrogue1",
	"forest_shaman": "fallenshaman",
	"marsh_wraith": "wraith",
	"marsh_archer": "darkarcher",
	"dark_archer": "darkarcher",
	"tamoe_lancer": "darklancer",
	"tamoe_marauder": "fallenshaman",
	"pit_lord": "pitlord",
	"outer_rogue": "corruptrogue1",
	"gatekeeper": "brute",
	"barracks_axe": "bloodclan",
	"jail_mage": "bonemage1",
	"fouldog": "afflicted",
	"cathedral_bone": "bonemage2",
	"cathedral_zealot": "bloodclan",
	"cata_ghoul": "zombie",
	"crypt_spider": "arach",
	"crypt_vampire": "ghoullord",
	"quill_rat": "quillrat",
	"quillrat": "quillrat",
	"tristram_clan": "bloodclan",
	"tristram_night": "nightclan",
	"vulture": "carrionbird",
	
	# Act 1 Boss / Superuniques
	"corpsefire": "zombie",
	"bishibosh": "fallenshaman",
	"blood_raven": "bloodraven",
	"bloodraven": "bloodraven",
	"rakanishu": "fallen",
	"treehead": "brute",
	"the_countess": "darkarcher",
	"countess": "darkarcher",
	"the_smith": "brute",
	"smith": "brute",
	"bone_ash": "bonemage1",
	"boneash": "bonemage1",
	"andariel": "andariel",
	
	# 牛关
	"cow_hell_bovine": "hellbovine",
	"cow_king": "hellbovine",
	"hellbovine": "hellbovine",
	"cowking": "hellbovine",
	
	# Act 2
	"radament": "radament",
	"sand_raider": "sandraider",
	"sandmaggot": "sandmaggot",
	"claw_viper": "clawviper",
	"clawviper": "clawviper",
	"bloodwitch": "bloodwitch",
	"coldworm": "sandmaggot",
	"fangskin": "clawviper",
	"summoner": "hierophant",
	"duriel": "sandmaggot",
	
	# Act 3
	"jungle_spider": "arach",
	"thorned_hulk": "thornedhulk",
	"flayer": "flayer",
	"sszark": "arach",
	"endugu": "flayershaman",
	"sarina": "corruptrogue1",
	"ismail": "councilmember",
	"councilmember": "councilmember",
	"mephisto": "ghoullord",
	"fetish": "fetish",
	
	# Act 4
	"abyss_knight": "abyssknight",
	"doom_knight": "doomknight",
	"oblivion_knight": "oblivionknight",
	"izual": "pitlord",
	"hephasto": "overlord",
	"diablo": "balrog",
	
	# Act 5
	"suicide_minion": "enslaved",
	"baal_minion": "minionofdestruction",
	"minionofdestruction": "minionofdestruction",
	"shenk": "overseer",
	"overseer": "overseer",
	"talic": "talic",
	"madawc": "talic",
	"korlic": "talic",
	"ancients": "talic",
	"nihlathak": "bonemage1",
	"baal": "baal",
	"baalcrab": "baal",
	"baaltaunt": "baal",
	# --- 全 85 关关卡场景 Boss 显式材质对齐 (Stage 1 ~ 85) ---
	"corpsefire_scout": "zombie",  # Stage  1 (Act 1) 尸火斥候
	"griswold": "brute",  # Stage  6 (Act 1) 格里斯瓦德
	"marsh_wraith_boss": "wraith",  # Stage  9 (Act 1) 荒地潜行者
	"desert_raider": "sandraider",  # Stage 15 (Act 2) 沙漠掠夺者
	"burning_dead_captain": "burningdead",  # Stage 16 (Act 2) 燃烧死尸队长
	"horror": "horror",  # Stage 17 (Act 2) 恐惧木乃伊
	"sand_raider_chief": "sandraider",  # Stage 19 (Act 2) 沙匪首领
	"dry_hills_scout": "huntress",  # Stage 20 (Act 2) 荒漠猎手首领
	"hollow_one_elite": "hollowone",  # Stage 21 (Act 2) 空洞尸魔
	"mummy_priest": "unraveler",  # Stage 22 (Act 2) 木乃伊祭司
	"sand_maggot_brood": "sandmaggot",  # Stage 24 (Act 2) 巨型沙虫幼王
	"dark_elder": "darklord",  # Stage 26 (Act 2) 暗黑长老
	"ancient_guardian": "clawviper",  # Stage 27 (Act 2) 古代守护者
	"blunderbore": "blunderbore",  # Stage 29 (Act 2) 愚笨魔领主
	"canyon_fiend": "crusher",  # Stage 31 (Act 2) 峡谷狂魔
	"creeping_feature": "decayed",  # Stage 32 (Act 2) 蠕行死尸
	"unraveler": "unraveler",  # Stage 33 (Act 2) 古代解开者
	"jungle_hunter": "junglehunter",  # Stage 35 (Act 3) 雨林猎手
	"flamefinger": "thornedhulk",  # Stage 36 (Act 3) 烈火之指
	"arachnid_queen": "arach",  # Stage 38 (Act 3) 巨蛛母后
	"swamp_dweller_boss": "swampdweller",  # Stage 39 (Act 3) 湿地巨鳄
	"flayer_chief": "flayershaman",  # Stage 40 (Act 3) 剥皮酋长
	"flayer_warrior": "flayer",  # Stage 41 (Act 3) 剥皮狂战士
	"bone_witch": "darkstalker",  # Stage 42 (Act 3) 白骨女巫
	"zakarum_zealot_leader": "zealot",  # Stage 44 (Act 3) 萨卡兰姆狂热领袖
	"bazaar_stalker": "darkstalker",  # Stage 45 (Act 3) 市集撕裂者
	"fane_guardian": "hierophant",  # Stage 47 (Act 3) 神庙守卫者
	"temple_lord": "cantor",  # Stage 48 (Act 3) 黑石圣殿主
	"sewer_horror": "undeadfetish",  # Stage 49 (Act 3) 下水道恶鬼
	"undead_heart": "mummysarcophagus",  # Stage 50 (Act 3) 腐败心脏
	"high_inquisitor": "cantor",  # Stage 51 (Act 3) 高阶审判官
	"causeway_knight": "zakarumite",  # Stage 52 (Act 3) 堤道重骑兵
	"blood_lord": "bloodlord",  # Stage 54 (Act 3) 吸血领主
	"undead_flayer": "undeadflayer",  # Stage 55 (Act 3) 不死剥皮者
	"abyss_watcher": "oblivionknight",  # Stage 57 (Act 4) 深渊观察者
	"steppe_fiend": "fleshspawner",  # Stage 58 (Act 4) 草原恶魔
	"damned_soul": "damned",  # Stage 60 (Act 4) 受罚幽魂
	"chaos_knight": "doomknight",  # Stage 62 (Act 4) 混沌骑士
	"grand_vizier": "stormcaster",  # Stage 63 (Act 4) 大西席·墨菲
	"siege_breaker": "siegebeast",  # Stage 65 (Act 5) 破城恶魔
	"eldritch": "enslaved",  # Stage 67 (Act 5) 矫正者·艾尔德利奇
	"thresh_socket": "crusher",  # Stage 68 (Act 5) 利牙·凹槽
	"frozen_creeper": "frozenhorror",  # Stage 69 (Act 5) 极寒潜伏者
	"frozenstein": "yeti",  # Stage 70 (Act 5) 冰霜女巫
	"bonesaw": "reanimatedhorde",  # Stage 71 (Act 5) 碎骨者
	"pain_master": "overlord",  # Stage 72 (Act 5) 痛苦典狱长
	"tundra_beast": "abominable",  # Stage 74 (Act 5) 苔原巨兽
	"ancient_scout": "bloodtemptress",  # Stage 75 (Act 5) 先祖斥候
	"worldstone_guard": "deathlord",  # Stage 77 (Act 5) 要塞守卫
	"black_soul": "blacksoul",  # Stage 78 (Act 5) 黑魂幽灵
	"blood_fiend": "fleshhunter",  # Stage 79 (Act 5) 血腥狂魔
	"colenzo": "warpedshaman",  # Stage 80 (Act 5) 毁灭五波首领
	"uber_duriel": "sandmaggot",  # Stage 82 (Act 5) 超级都瑞尔
	"uber_izual": "pitlord",  # Stage 83 (Act 5) 超级衣卒尔
	"uber_lilith": "andariel",  # Stage 84 (Act 5) 超级莉莉丝
	"uber_mephisto": "ghoullord",  # Stage 85 (Act 5) 地狱三魔神分身
}

# 小型怪名单 (高度 ~160px, 节奏较快)
const SMALL_MONSTERS: Array[String] = [
	"fallen", "carver", "devilkin", "darkone", "warpedone",
	"quillrat", "spikefiend", "razorspine",
	"fetish", "flayer", "soulkiller", "ratman",
	"sandmaggotyoung", "bloodmaggotyoung", "giantlampreyyoung",
	"itchies", "blacklocusts", "hellswarm",
	"scarab", "steelscarab", "bonescarab", "deathbeetle"
]

# 大型/精英怪物名单 (高度 ~310px)
const LARGE_MONSTERS: Array[String] = [
	"brute", "yeti", "crusher", "wailingbeast", "gargantuanbeast",
	"blunderbore", "mauler", "gorebelly", "urdar",
	"clawviper", "salamander", "tombviper", "serpentmagus",
	"corpsespitter", "mawfiend", "bloodlord", "helllord", "moonlord", "nightlord",
	"thornedhulk", "bramblehulk", "thrasher",
	"siegebeast", "overlord", "bloodraven", "treehead"
]

# 关卡魔神 Boss 名单 (高度 ~400px, 顶天立地)
const BOSS_MONSTERS: Array[String] = [
	"andariel", "duriel", "mephisto", "diablo", "baal",
	"cowking", "bloodraven", "the_smith", "smith", "hephasto", "izual"
]

# 材质缓存字典
static var _texture_cache: Dictionary = {}

## 获取怪物对应的贴图
static func get_monster_texture(mon_key: String, mon_code: String = "") -> Texture2D:
	var clean_k = mon_key.to_lower().strip_edges()
	var clean_c = mon_code.to_lower().strip_edges()
	
	var cache_key = clean_k + "_" + clean_c
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
		
	var file_id = _resolve_png_filename(clean_k, clean_c)
	var tex: Texture2D = _load_monster_tex(file_id)
	
	# 如果未找到，尝试族类回退
	if not tex:
		var fallback_path = _find_fallback_path(file_id)
		tex = _load_monster_tex(fallback_path)
			
	# 保底：若依然未找到，采用沉沦魔或僵尸底材，绝不报错或显示空图
	if not tex:
		if "zombie" in clean_k or "dead" in clean_k:
			tex = _load_monster_tex("zombie")
		elif "skeleton" in clean_k or "bone" in clean_k:
			tex = _load_monster_tex("skeleton")
		else:
			tex = _load_monster_tex("fallen")
			
	_texture_cache[cache_key] = tex
	return tex

## 智能双模加载怪物贴图 (优先 WebP，自动兼容 PNG)
static func _load_monster_tex(file_or_path: String) -> Texture2D:
	var id = file_or_path.get_file().to_lower().trim_suffix(".png").trim_suffix(".webp")
	var p_webp = "res://assets/monsters/%s.webp" % id
	if ResourceLoader.exists(p_webp):
		return load(p_webp)
	var p_png = "res://assets/monsters/%s.png" % id
	if ResourceLoader.exists(p_png):
		return load(p_png)
	return null

## 解析最贴切的 png 文件名 (不含 .png 后缀)
static func _resolve_png_filename(mon_key: String, mon_code: String) -> String:
	# 1. 优先从显式映射表匹配
	if MUDKEY_TO_PNG.has(mon_key):
		return MUDKEY_TO_PNG[mon_key]
		
	# 2. 如果 mon_code 存在且有映射
	if not mon_code.is_empty() and MUDKEY_TO_PNG.has(mon_code):
		return MUDKEY_TO_PNG[mon_code]
		
	# 3. 尝试去除尾部数字 (如 fallen1 -> fallen, zombie2 -> zombie)
	var regex = RegEx.new()
	regex.compile("\\d+$")
	var stripped_code = regex.sub(mon_code, "") if not mon_code.is_empty() else ""
	if not stripped_code.is_empty() and MUDKEY_TO_PNG.has(stripped_code):
		return MUDKEY_TO_PNG[stripped_code]
		
	var stripped_k = regex.sub(mon_key, "").replace("_", "")
	if MUDKEY_TO_PNG.has(stripped_k):
		return MUDKEY_TO_PNG[stripped_k]
		
	# 4. 直接尝试以 mon_key 或 mon_code 文件名检测
	if ResourceLoader.exists("res://assets/monsters/%s.png" % mon_key):
		return mon_key
	if not mon_code.is_empty() and ResourceLoader.exists("res://assets/monsters/%s.png" % mon_code):
		return mon_code
	if not stripped_k.is_empty() and ResourceLoader.exists("res://assets/monsters/%s.png" % stripped_k):
		return stripped_k
	if not stripped_code.is_empty() and ResourceLoader.exists("res://assets/monsters/%s.png" % stripped_code):
		return stripped_code
		
	return stripped_k if not stripped_k.is_empty() else mon_key

## 寻找通配回退路径
static func _find_fallback_path(file_id: String) -> String:
	var fid = file_id.to_lower()
	if "shaman" in fid:
		return "res://assets/monsters/fallenshaman.png"
	if "archer" in fid:
		return "res://assets/monsters/darkarcher.png"
	if "mage" in fid:
		return "res://assets/monsters/bonemage1.png"
	if "zombie" in fid or "ghoul" in fid:
		return "res://assets/monsters/zombie.png"
	if "skeleton" in fid:
		return "res://assets/monsters/skeleton.png"
	if "bat" in fid:
		return "res://assets/monsters/desertwing.png"
	if "brute" in fid:
		return "res://assets/monsters/brute.png"
	if "spider" in fid or "arach" in fid:
		return "res://assets/monsters/arach.png"
	return "res://assets/monsters/fallen.png"

## 获取怪物所属体型构图级别 (small, medium, large, boss)
static func get_monster_tier(mon_key: String, rank: String = "normal") -> String:
	var k = mon_key.to_lower().replace("_", "")
	if rank == "boss":
		return TIER_BOSS
		
	for b in BOSS_MONSTERS:
		if b in k: return TIER_BOSS
		
	if rank == "unique" or rank == "champion":
		return TIER_LARGE
		
	for sm in SMALL_MONSTERS:
		if sm in k: return TIER_SMALL
		
	for lg in LARGE_MONSTERS:
		if lg in k: return TIER_LARGE
		
	return TIER_MEDIUM

## 获取怪物尺寸与缩放配置
## 返回 Dictionary: { "target_height": int, "scale": float, "breath_speed": float, "breath_amp_y": float }
static func get_tier_config(tier: String) -> Dictionary:
	match tier:
		TIER_SMALL:
			return {
				"target_height": 160,
				"scale": 0.72,
				"breath_speed": 4.5,     # 周期约 1.4 秒 (较快灵动)
				"breath_amp_y": 0.045,   # Y 轴起伏 4.5%
				"breath_amp_x": 0.020,
			}
		TIER_MEDIUM:
			return {
				"target_height": 240,
				"scale": 1.0,
				"breath_speed": 3.14,    # 周期 2.0 秒 (沉稳平和)
				"breath_amp_y": 0.035,   # Y 轴起伏 3.5%
				"breath_amp_x": 0.015,
			}
		TIER_LARGE:
			return {
				"target_height": 310,
				"scale": 1.25,
				"breath_speed": 2.5,     # 周期约 2.5 秒
				"breath_amp_y": 0.030,   # Y 轴起伏 3.0%
				"breath_amp_x": 0.012,
			}
		TIER_BOSS:
			return {
				"target_height": 400,
				"scale": 1.55,
				"breath_speed": 1.8,     # 周期约 3.5 秒 (深沉威严)
				"breath_amp_y": 0.025,   # Y 轴微幅威压起伏
				"breath_amp_x": 0.010,
			}
		_:
			return {
				"target_height": 240,
				"scale": 1.0,
				"breath_speed": 3.14,
				"breath_amp_y": 0.035,
				"breath_amp_x": 0.015,
			}
