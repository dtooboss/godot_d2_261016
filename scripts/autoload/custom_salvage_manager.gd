extends Node
## CustomSalvageManager (客户端细则分解与智能规则引擎)
## 
## 设计原则 (KISS & 第一性原理):
## 1. 复杂规则全在客户端本地评估，服务端零计算负担，仅接收简明 fenjie/gfenjie 指令；
## 2. 严格遵循白名单优先 (Keep Rules) 保护机制，只有未被保护且命中分解目标 (Salvage Rules) 的装备才会被分解；
## 3. 任何情况下绝对不分解：穿戴装备、锁定装备、护身符小口袋、符文宝石消耗品与暗金神物；
## 4. 规则保存在客户端本地 user://custom_salvage_rules.json，支持随时导入导出与热重载。

signal rules_updated()
signal salvage_triggered(count: int, item_names: Array[String])

const CONFIG_PATH = "user://custom_salvage_rules.json"

## 内存中加载的规则字典
var current_rules: Dictionary = {}

## 掉落聚合定时器 (防抖触发，避免瞬间多怪掉落时向服务端频繁发包)
var _debounce_timer: Timer = null
var _pending_check: bool = false
var _pending_salvage_fids: Array[String] = []

func _ready() -> void:
	_init_debounce_timer()
	load_rules()

func _init_debounce_timer() -> void:
	if not _debounce_timer:
		_debounce_timer = Timer.new()
		_debounce_timer.one_shot = true
		_debounce_timer.wait_time = 0.25 # 250ms 防抖聚合
		_debounce_timer.timeout.connect(_on_debounce_timeout)
		add_child(_debounce_timer)

## 加载本地规则 (如不存在则生成默认典雅预设)
func load_rules() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var txt = file.get_as_text()
			var json = JSON.new()
			if json.parse(txt) == OK and json.data is Dictionary:
				current_rules = json.data
				print("[CustomSalvageManager] 成功载入本地细则分解规则 (版本: %s)" % current_rules.get("version", 1))
				rules_updated.emit()
				return
	
	# 首次使用或文件损坏，生成开箱即用的神级底材预设
	current_rules = get_default_rules()
	save_rules()
	rules_updated.emit()

## 保存当前规则到本地文件
func save_rules() -> bool:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(current_rules, "  ")
		file.store_string(json_str)
		file.close()
		rules_updated.emit()
		return true
	return false

## 从外部 JSON 字符串导入
func import_rules_from_string(json_str: String) -> Dictionary:
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return {"success": false, "msg": "JSON 格式解析失败 (错误行: %d)" % json.get_error_line()}
	if not json.data is Dictionary:
		return {"success": false, "msg": "规则必须是根级 JSON 对象 ({ ... })"}
	
	var data: Dictionary = json.data
	if not data.has("keep_rules") and not data.has("salvage_rules"):
		return {"success": false, "msg": "规则必须包含 keep_rules 或 salvage_rules 字段"}
	
	# 🛡️ 严格限定安全防线：暗金 (unique) 与 套装 (set) 绝不入细则分解
	if data.has("salvage_rules") and data["salvage_rules"] is Array:
		for rule in data["salvage_rules"]:
			if rule is Dictionary and rule.has("qualities") and rule["qualities"] is Array:
				var filtered_q: Array = []
				for q in rule["qualities"]:
					var sq = str(q).to_lower()
					if sq != "unique" and sq != "set":
						filtered_q.append(sq)
				rule["qualities"] = filtered_q

	current_rules = data
	save_rules()
	return {"success": true, "msg": "规则导入成功！"}

## 开箱即用正统默认规则预设 (精神/眼光/无限/刚毅/谜团)
func get_default_rules() -> Dictionary:
	return {
		"version": 1,
		"enabled": false,
		"auto_salvage_on_loot": false,
		"keep_rules": [
			{
				"name": "精神剑底材 (4孔水晶剑/阔剑)",
				"base_names": ["水晶剑", "阔剑"],
				"sockets": [4],
				"qualities": ["normal", "superior"]
			},
			{
				"name": "精神盾底材 (4孔统御者大盾/圣甲虫圆盾)",
				"base_names": ["统御者大盾", "圣甲虫圆盾", "神圣小盾", "库拉斯特之盾", "撒卡兰姆盾", "旋风盾"],
				"sockets": [4],
				"qualities": ["normal", "superior"]
			},
			{
				"name": "眼光/无限神级底材 (4孔无形长柄武器)",
				"base_names": ["巨神之斧", "神秘之斧", "巨长斧", "斩镰", "锐利之斧"],
				"sockets": [4],
				"ethereal": true,
				"qualities": ["normal", "superior"]
			},
			{
				"name": "刚毅/石块底材 (4孔高防无形甲)",
				"base_names": ["执政官铠甲", "圣堂武士之铠", "神圣盔甲", "漆黑之甲", "海妖壳甲", "阴影铠甲"],
				"sockets": [4],
				"ethereal": true,
				"qualities": ["normal", "superior"]
			},
			{
				"name": "谜团底材 (3孔法师铠甲/执政官铠甲)",
				"base_names": ["法师铠甲", "执政官铠甲"],
				"sockets": [3],
				"qualities": ["normal", "superior"]
			},
			{
				"name": "极品超强底材 (带10%以上增强伤害或防御)",
				"qualities": ["superior"],
				"min_ed": 10
			}
		],
		"salvage_rules": [
			{
				"name": "分解所有未保留的普通白板装备与垃圾超强",
				"qualities": ["normal", "superior"]
			}
		]
	}
## 核心判定算法：判断一件装备是否应该在客户端本地被分解
func should_salvage(item_data: Dictionary) -> bool:
	if not bool(current_rules.get("enabled", false)):
		return false
	if item_data.is_empty():
		return false

	# 🛡️ 严格限定安全铁律：暗金 (unique) 与 套装 (set) 绝对不入细则分解，永久免死保护！
	var qual = str(item_data.get("quality", "normal")).to_lower()
	if qual in ["unique", "set"]:
		return false

	# 🛡️ 绝对物理免死令：穿戴装备、手动锁定、小口袋护身符
	if bool(item_data.get("equipped", false)):
		return false
	if bool(item_data.get("item_locked", false)):
		return false
	if bool(item_data.get("in_charm_bag", false)):
		return false
	if bool(item_data.get("is_charm", false)):
		return false
		
	# 🛡️ 绝对物理免死令：符文、宝石、药水、卷轴、任务道具、消耗品
	var d2_type = str(item_data.get("d2_type", item_data.get("type", ""))).to_lower()
	if d2_type in ["符文", "宝石", "药水", "卷轴", "材料", "消耗品", "rune", "gem", "potion", "scroll", "material"]:
		return false
	if bool(item_data.get("is_stackable", false)) and AnsiHelper.to_safe_int(item_data.get("amount", 1)) > 1:
		return false
	if str(item_data.get("file_id", "")).is_empty():
		return false

	# 提取物品关键比对特征
	var iname = str(item_data.get("raw_name", item_data.get("name", "")))
	var clean_name = AnsiHelper.to_plain_text(iname)
	var sockets = AnsiHelper.to_safe_int(item_data.get("sockets"), 0)
	
	# 从描述或文本提取无形特征与 ED (增强伤害/防御)
	var desc = ""
	var item_info = item_data.get("item_info")
	if item_info is Dictionary:
		desc = str(item_info.get("desc", ""))
	var is_ethereal = bool(item_data.get("ethereal", false)) or ("无形" in clean_name) or ("无形" in desc) or ("无法修复" in desc)
	var ed_val = _extract_ed_percent(clean_name, desc)

	# 1. 优先检查【白名单保留规则 (Keep Rules)】：一旦命中任何一条，坚决保留！
	var keep_rules = current_rules.get("keep_rules", [])
	if keep_rules is Array:
		for rule in keep_rules:
			if rule is Dictionary and _matches_rule(rule, clean_name, qual, sockets, is_ethereal, ed_val):
				return false # 命中保留白名单，绝对安全不分解

	# 2. 检查【分解规则 (Salvage Rules)】：命中任一分解规则则允许分解
	var salvage_rules = current_rules.get("salvage_rules", [])
	if salvage_rules is Array:
		for rule in salvage_rules:
			if rule is Dictionary and _matches_rule(rule, clean_name, qual, sockets, is_ethereal, ed_val):
				return true # 命中分解目标，执行分解

	# 默认安全保守原则：未明确要求分解的，保留
	return false

## 单条规则匹配器
func _matches_rule(rule: Dictionary, clean_name: String, qual: String, sockets: int, is_ethereal: bool, ed_val: int) -> bool:
	# (1) 品质匹配
	if rule.has("qualities"):
		var req_quals = rule["qualities"]
		if req_quals is Array and not req_quals.is_empty():
			var q_matched = false
			for q in req_quals:
				if str(q).to_lower() == qual:
					q_matched = true
					break
			if not q_matched:
				return false

	# (2) 底材名称匹配 (支持列表或单字符串，子串命中即可，如 '水晶剑' 命中 '超强的 水晶剑')
	if rule.has("base_names"):
		var b_names = rule["base_names"]
		if b_names is Array and not b_names.is_empty():
			var name_matched = false
			for b in b_names:
				if str(b) != "" and str(b) in clean_name:
					name_matched = true
					break
			if not name_matched:
				return false

	# (3) 孔数匹配 (支持数组 [4] 或范围，0 表示无孔)
	if rule.has("sockets"):
		var s_req = rule["sockets"]
		if s_req is Array and not s_req.is_empty():
			var s_matched = false
			for s in s_req:
				if int(s) == sockets:
					s_matched = true
					break
			if not s_matched:
				return false
		elif s_req is int or s_req is float:
			if int(s_req) != sockets:
				return false

	# (4) 无形匹配 (如果规则显式指定了 ethereal)
	if rule.has("ethereal"):
		var req_eth = bool(rule["ethereal"])
		if req_eth != is_ethereal:
			return false

	# (5) 增强伤害/防御门槛 (min_ed)
	if rule.has("min_ed"):
		var min_ed = int(rule["min_ed"])
		if min_ed > 0 and ed_val < min_ed:
			return false

	return true

## 从物品名称与描述中提取 ED 数值 (例如 +15% 增强伤害，防御力强化 +15%)
func _extract_ed_percent(clean_name: String, desc: String) -> int:
	var full_text = clean_name + " " + desc
	var reg = RegEx.new()
	# 形式 1：+15% 增强伤害 / +15% 防御力强化
	reg.compile(r"(\+|\b)(\d{1,3})%\s*(增强伤害|防御力强化|防御强化|增强防御|强化防御|防御增加|伤害增加|ED)")
	var res = reg.search(full_text)
	if res:
		return AnsiHelper.to_safe_int(res.get_string(2), 0)

	# 形式 2：防御力强化 +15% / 增强伤害 +15% / ED: 15%
	var reg_rev = RegEx.new()
	reg_rev.compile(r"(增强伤害|防御力强化|防御强化|增强防御|强化防御|防御增加|伤害增加|ED)[:：\s]*\+?(\d{1,3})%")
	var res_rev = reg_rev.search(full_text)
	if res_rev:
		return AnsiHelper.to_safe_int(res_rev.get_string(2), 0)

	# 次选：匹配超强底材常规词缀 '+15% 伤害' 或 '伤害 +15%'
	var reg2 = RegEx.new()
	reg2.compile(r"(\+|\b)(\d{1,3})%\s*(伤害|防御)")
	var res2 = reg2.search(full_text)
	if res2:
		return AnsiHelper.to_safe_int(res2.get_string(2), 0)

	var reg3 = RegEx.new()
	reg3.compile(r"(伤害|防御)[:：\s]*\+?(\d{1,3})%")
	var res3 = reg3.search(full_text)
	if res3:
		return AnsiHelper.to_safe_int(res3.get_string(2), 0)

	return 0

## 收到掉落战利品时即刻评估 (若开启细则分解且命中目标，压入防抖批处理队列)
func handle_loot_dropped(item_data: Dictionary) -> void:
	if not bool(current_rules.get("enabled", false)):
		return
	if not bool(current_rules.get("auto_salvage_on_loot", false)):
		return
	if item_data.is_empty():
		return
	if should_salvage(item_data):
		var fid = str(item_data.get("file_id", ""))
		if not fid.is_empty() and not _pending_salvage_fids.has(fid):
			_pending_salvage_fids.append(fid)
	notify_loot_dropped()

## 战利品掉落时被外部触发防抖检查
func notify_loot_dropped() -> void:
	if not bool(current_rules.get("enabled", false)):
		return
	if not bool(current_rules.get("auto_salvage_on_loot", false)):
		return
	_pending_check = true
	_debounce_timer.start()

func _on_debounce_timeout() -> void:
	if _pending_check or not _pending_salvage_fids.is_empty():
		_pending_check = false
		scan_and_salvage_bag()

## 扫描背包中所有物品，将命中细则分解的装备发送指令分解
func scan_and_salvage_bag() -> int:
	if not bool(current_rules.get("enabled", false)):
		_pending_salvage_fids.clear()
		return 0

	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		_pending_salvage_fids.clear()
		return 0
		
	var inv_panel = _find_inventory_panel(tree.current_scene)
	if not inv_panel:
		_pending_salvage_fids.clear()
		return 0

	# 聚合双重数据源：优先 items_map (当前格子上落位物品) + 补充 raw_all_items (全量缓存)
	var candidate_items: Array = []
	var seen_fids: Dictionary = {}

	var imap = inv_panel.get("items_map")
	if imap is Dictionary:
		for it in imap.values():
			if it is Dictionary:
				var fid = str(it.get("file_id", ""))
				if not fid.is_empty():
					seen_fids[fid] = true
				candidate_items.append(it)

	var raw_items = inv_panel.get("raw_all_items")
	if raw_items is Array:
		for it in raw_items:
			if it is Dictionary:
				var fid = str(it.get("file_id", ""))
				if fid.is_empty() or not seen_fids.has(fid):
					if not fid.is_empty():
						seen_fids[fid] = true
					candidate_items.append(it)

	var to_salvage_fids: Array[String] = []
	var to_salvage_names: Array[String] = []

	# 先合并掉落拦截队列中待分解的 fids
	for pfid in _pending_salvage_fids:
		if not pfid.is_empty() and not to_salvage_fids.has(pfid):
			to_salvage_fids.append(pfid)
	_pending_salvage_fids.clear()

	# 遍历背包候选物品，判定命中细则分解者
	for it in candidate_items:
		if it is Dictionary and should_salvage(it):
			var fid = str(it.get("file_id", ""))
			if not fid.is_empty() and not to_salvage_fids.has(fid):
				to_salvage_fids.append(fid)
				var nm = AnsiHelper.to_plain_text(str(it.get("raw_name", it.get("name", "未名装备"))))
				to_salvage_names.append(nm)

	if to_salvage_fids.is_empty():
		return 0
		
	print("[CustomSalvageManager] 细则分解判定命中 %d 件装备，正在通知服务端分解: %s" % [to_salvage_fids.size(), ", ".join(to_salvage_names)])
	
	# 向服务端发送分号批量分解指令 (服务端 gfenjie fid1;fid2;... 是经深度优化的原子批处理指令)
	var cur_page = int(inv_panel.get("current_page")) if "current_page" in inv_panel else 1
	var cmd = "gfenjie %s %d" % [";".join(to_salvage_fids), cur_page]
	_send_lpc_cmd(cmd)
	
	salvage_triggered.emit(to_salvage_fids.size(), to_salvage_names)
	return to_salvage_fids.size()

func _send_lpc_cmd(cmd: String) -> void:
	if Engine.has_singleton("NetworkClient") or (Engine.get_main_loop() and (Engine.get_main_loop() as SceneTree).root.has_node("NetworkClient")):
		var net = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("NetworkClient")
		if net and net.is_connected:
			net.send_raw(cmd)

func _find_inventory_panel(root: Node) -> Node:
	if not root:
		return null
	if "raw_all_items" in root and "items_map" in root:
		return root
	for child in root.get_children():
		var res = _find_inventory_panel(child)
		if res:
			return res
	return null
