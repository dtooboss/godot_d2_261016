extends Node
## 自动化测试：客户端细则分解与智能规则引擎 (CustomSalvageManager)

func _ready() -> void:
	print("=========================================================================")
	print("[开始测试] 客户端细则分解与智能规则引擎 (CustomSalvageManager)")
	print("=========================================================================")
	
	var csm = CustomSalvageManager if has_node("/root/CustomSalvageManager") else load("res://scripts/autoload/custom_salvage_manager.gd").new()
	if not has_node("/root/CustomSalvageManager"):
		add_child(csm)
		
	# 1. 验证默认规则加载 (默认关闭安全状态)
	csm.current_rules = csm.get_default_rules()
	assert(csm.current_rules["keep_rules"].size() >= 5, "默认保留规则应包含至少5条经典底材")
	assert(csm.current_rules.get("enabled", false) == false, "默认规则必须保持 enabled = false 关闭状态！")
	assert(csm.current_rules.get("auto_salvage_on_loot", false) == false, "默认规则必须保持 auto_salvage_on_loot = false 关闭状态！")
	
	# 验证在未开启状态下，任何装备均不可分解 (绝对安全保守)
	var test_junk = { "file_id": "/clone/equip/sword#001", "name": "短剑", "quality": "normal", "sockets": 0 }
	assert(csm.should_salvage(test_junk) == false, "未勾选启用细则分解时，任何装备绝对不应被分解！")
	print("✔ Test 1 通过：默认典雅规则加载成功，且默认保持安全关闭状态 (未勾选)")
	
	# 开启细则分解开关以执行后续细则过滤测试
	csm.current_rules["enabled"] = true
	csm.current_rules["auto_salvage_on_loot"] = true
	
	# 2. 验证神级底材白名单保留 (命中 Keep Rules)
	var spirit_sword = {
		"file_id": "/clone/equip/sword#101",
		"name": "超强的 水晶剑 (4孔)",
		"raw_name": "水晶剑",
		"quality": "superior",
		"sockets": 4,
		"item_info": { "desc": "【四孔水晶剑】底材" }
	}
	assert(csm.should_salvage(spirit_sword) == false, "4孔超强水晶剑 (精神底材) 必须被绝对保护保留！")
	
	var insight_polearm = {
		"file_id": "/clone/equip/polearm#102",
		"name": "无形的 巨神之斧 (4孔)",
		"raw_name": "巨神之斧",
		"quality": "normal",
		"sockets": 4,
		"ethereal": true,
		"item_info": { "desc": "无形的(无法修复) 4插槽" }
	}
	assert(csm.should_salvage(insight_polearm) == false, "4孔无形巨神之斧 (眼光/无限底材) 必须被绝对保护保留！")

	var enigma_armor = {
		"file_id": "/clone/equip/armor#103",
		"name": "法师铠甲 (3孔)",
		"raw_name": "法师铠甲",
		"quality": "normal",
		"sockets": 3,
		"item_info": { "desc": "3插槽" }
	}
	assert(csm.should_salvage(enigma_armor) == false, "3孔法师铠甲 (谜团底材) 必须被绝对保护保留！")
	
	var high_ed_armor = {
		"file_id": "/clone/equip/armor#104",
		"name": "超强的 执政官铠甲",
		"raw_name": "执政官铠甲",
		"quality": "superior",
		"sockets": 0,
		"item_info": { "desc": "防御力强化 +15%，耐久度上限增加 12%" }
	}
	assert(csm.should_salvage(high_ed_armor) == false, "15% ED 超强执政官铠甲必须被保护保留！")
	print("✔ Test 2 通过：经典符文之语神级底材 (精神/眼光/谜团/极品ED) 100% 命中白名单保留")
	
	# 3. 验证垃圾底材精准分解 (未命中 Keep，命中 Salvage)
	var junk_superior_bow = {
		"file_id": "/clone/equip/bow#201",
		"name": "超强的 短弓",
		"raw_name": "短弓",
		"quality": "superior",
		"sockets": 0,
		"item_info": { "desc": "耐久度上限增加 10%" }
	}
	assert(csm.should_salvage(junk_superior_bow) == true, "垃圾超强短弓未达到保留条件，必须判定为分解！")

	var junk_white_armor = {
		"file_id": "/clone/equip/armor#202",
		"name": "粗糙的 皮甲",
		"raw_name": "皮甲",
		"quality": "normal",
		"sockets": 0,
		"item_info": { "desc": "普通防具" }
	}
	assert(csm.should_salvage(junk_white_armor) == true, "垃圾白板皮甲未达到保留条件，必须判定为分解！")
	print("✔ Test 3 通过：垃圾超强与无用白板装备准确判定为分解，解决背包被垃圾塞满的痛点")
	
	# 4. 验证安全绝对免死防线
	var equipped_item = junk_superior_bow.duplicate()
	equipped_item["equipped"] = true
	assert(csm.should_salvage(equipped_item) == false, "穿戴中的装备绝对不可分解")
	
	var locked_item = junk_white_armor.duplicate()
	locked_item["item_locked"] = true
	assert(csm.should_salvage(locked_item) == false, "玩家手动锁定的装备绝对不可分解")
	
	var charm_item = {
		"file_id": "/clone/d2/charm#301",
		"name": "超大护身符",
		"d2_type": "护符",
		"is_charm": true,
		"quality": "magic"
	}
	assert(csm.should_salvage(charm_item) == false, "护身符绝对不可分解")
	
	var rune_item = {
		"file_id": "/clone/d2/rune#302",
		"name": "乔(31#)",
		"d2_type": "符文",
		"amount": 2
	}
	assert(csm.should_salvage(rune_item) == false, "高阶符文绝对不可分解")

	# 🛡️ 验证暗金与套装绝对不入细则免死防线 (铁律保护)
	var unique_shako = {
		"file_id": "/clone/equip/helm#303",
		"name": "军神之顶 谐角之冠",
		"raw_name": "谐角之冠",
		"quality": "unique",
		"sockets": 0,
		"item_info": { "desc": "所有技能 +2, 50% 获得魔法装备" }
	}
	assert(csm.should_salvage(unique_shako) == false, "暗金装备绝对不可被细则分解！")

	var set_tal_armor = {
		"file_id": "/clone/equip/armor#304",
		"name": "塔·拉夏的漆黑之蛹 漆黑之甲",
		"raw_name": "漆黑之甲",
		"quality": "set",
		"sockets": 0,
		"item_info": { "desc": "抗寒 +40%, 抗火 +40%, 抗电 +40%" }
	}
	assert(csm.should_salvage(set_tal_armor) == false, "绿色套装装备绝对不可被细则分解！")
	print("✔ Test 4 通过：穿戴装备、手动锁定装备、护身符、暗金与套装绝对不入细则安全防线 100% 坚固")

	# 5. 验证从 Web 工具生成的 JSON 文本导入与热解析，并验证恶意包含 unique/set 时自动净化
	var test_imported_json = """
	{
		"version": 1,
		"enabled": true,
		"auto_salvage_on_loot": true,
		"keep_rules": [
			{
				"name": "专属测试底材 (5孔狂战士之斧)",
				"base_names": ["狂战士之斧"],
				"sockets": [5],
				"qualities": ["normal", "superior"]
			}
		],
		"salvage_rules": [
			{
				"name": "测试恶意包含暗金套装配置",
				"qualities": ["unique", "set", "normal", "superior"]
			}
		]
	}
	"""
	var res = csm.import_rules_from_string(test_imported_json)
	assert(res["success"] == true, "JSON 规则字符串应成功导入")
	assert(csm.current_rules["keep_rules"].size() == 1, "导入后保留规则应为1条")
	
	# 检查净化结果：salvage_rules 中的 unique 和 set 必须被自动剔除
	var q_list = csm.current_rules["salvage_rules"][0]["qualities"]
	assert(not ("unique" in q_list), "导入规则必须彻底过滤剔除 unique！")
	assert(not ("set" in q_list), "导入规则必须彻底过滤剔除 set！")
	assert(csm.should_salvage(unique_shako) == false, "即使规则中包含暗金，判定引擎依然永久绝对豁免！")
	assert(csm.should_salvage(set_tal_armor) == false, "即使规则中包含套装，判定引擎依然永久绝对豁免！")
	
	var grief_axe = {
		"file_id": "/clone/equip/axe#401",
		"name": "狂战士之斧 (5孔)",
		"raw_name": "狂战士之斧",
		"quality": "superior",
		"sockets": 5
	}
	assert(csm.should_salvage(grief_axe) == false, "导入的5孔狂战士之斧规则必须成功生效并保留！")
	print("✔ Test 5 通过：Web 工具导出的 JSON 字符串无缝导入与动态生效验证通过")

	print("=========================================================================")
	print("🎉 全量测试全部 PASS (5/5)！客户端细则分解系统稳健可靠！")
	print("=========================================================================")
	get_tree().quit(0)
