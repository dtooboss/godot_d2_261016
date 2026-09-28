extends Control

@onready var hud_instance = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_run_mock_test()

func _run_mock_test() -> void:
	print(">>> 开始模拟暗黑2背包排序与叠加药水测试...")
	var inv_panel = hud_instance.inventory_panel
	var tooltip = hud_instance.item_tooltip
	
	if not inv_panel:
		print("未找到 PlayerInventoryPanel!")
		return

	# 模拟经过 LPC sort_items 排序后的暗黑2物品序列（品质优先：暗金 > 绿装 > 亮金 > 蓝白 > 药水材料）
	var mock_items = [
		# 1. 暗金装备 (Unique置顶，武器 > 衣服 > 头盔)
		{
			"name": "海鸥 (Seagull)",
			"quality": "unique",
			"amount": 1,
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"cmd": "look mock_seagull",
			"item_info": {"desc": "伤害: 2-7\n[color=#ffff64]+100% 更加寻获魔法物品机会[/color]"}
		},
		{
			"name": "都瑞尔的壳 (Duriel's Shell)",
			"quality": "unique",
			"amount": 1,
			"icon": "items/armor/armor/ancient_armor.lowend.png",
			"cmd": "look mock_duriel",
			"item_info": {"desc": "防御: 610\n[color=#ffff64]+1.25 生命 (按角色等级)\n无法被冻结[/color]"}
		},
		{
			"name": "军帽 (Harlequin Crest)",
			"quality": "unique",
			"amount": 1,
			"icon": "items/armor/helmet/helm.lowend.png",
			"cmd": "look mock_shako",
			"item_info": {"desc": "防御: 141\n[color=#ffff64]+2 级所有技能\n+50% 更加寻获魔法物品机会[/color]"}
		},
		{
			"name": "乔丹之石 (Stone of Jordan)",
			"quality": "unique",
			"amount": 1,
			"icon": "items/misc/ring/ring1.lowend.png",
			"cmd": "look mock_soj",
			"item_info": {"desc": "[color=#ffff64]+1 级所有技能\n提高法力上限 25%[/color]"}
		},
		# 2. 绿色套装 (Set)
		{
			"name": "塔·拉夏的守护 (Tal Rasha's Guardianship)",
			"quality": "set",
			"amount": 1,
			"icon": "items/armor/armor/ancient_armor.lowend.png",
			"cmd": "look mock_tal_armor",
			"item_info": {"desc": "防御: 941\n[color=#00aa00]所有抗性 +40\n88% 更加寻获魔法物品[/color]"}
		},
		{
			"name": "吉永之脸 (Guillaume's Face)",
			"quality": "set",
			"amount": 1,
			"icon": "items/armor/helmet/helm.lowend.png",
			"cmd": "look mock_cb_helm",
			"item_info": {"desc": "防御: 217\n[color=#00aa00]+35% 造成压碎性打击概率[/color]"}
		},
		# 3. 亮金装备 (Rare)
		{
			"name": "风暴之握 锁子甲 (Storm Grip)",
			"quality": "rare",
			"amount": 1,
			"icon": "items/armor/armor/ancient_armor.lowend.png",
			"cmd": "look mock_rare_armor",
			"item_info": {"desc": "防御: 480\n[color=#ffff64]+24% 快速打击恢复\n火焰抗性 +28%[/color]"}
		},
		{
			"name": "残酷之刃 水晶剑",
			"quality": "rare",
			"amount": 1,
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"cmd": "look mock_rare_sword",
			"item_info": {"desc": "伤害: 45-120\n[color=#ffff64]+180% 增强伤害\n+20% 攻击速度[/color]"}
		},
		# 4. 魔法装备 (Magic)
		{
			"name": "珠宝匠之偏向 统治者大盾",
			"quality": "magic",
			"amount": 1,
			"icon": "items/armor/shield/large_shield.lowend.png",
			"cmd": "look mock_jmod",
			"item_info": {"desc": "防御: 148\n[color=#4850b8]+30% 快速格挡率\n20% 增加格挡几率\n带孔 (4)[/color]"}
		},
		# 5. 普通打孔 (Normal)
		{
			"name": "超强的 水晶剑 (4孔)",
			"quality": "normal",
			"amount": 1,
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"cmd": "look mock_cs_4os",
			"item_info": {"desc": "伤害: 5-15\n带孔 (4)"}
		},
		# 6. 符文与宝石 (材料)
		{
			"name": "31# 乔 (Jah Rune)",
			"quality": "normal",
			"amount": 3,
			"icon": "items/misc/rune/el_rune.lowend.png",
			"cmd": "look mock_jah",
			"item_info": {"desc": "符文编号: 31\n镶嵌武器: 忽视目标防御\n镶嵌防具: 增加最大生命 5%"}
		},
		{
			"name": "完美红宝石",
			"quality": "normal",
			"amount": 15,
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_ruby",
			"item_info": {"desc": "完美品质宝石\n镶嵌防具: +38 生命"}
		},
		# 7. 可叠加药水与卷轴 (测试各种叠加量级角标)
		{
			"name": "超强生命药水",
			"quality": "normal",
			"amount": 20, # 测试两位数 (20)
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_hp_potion",
			"item_info": {"desc": "瞬间回复 320 点生命值。"}
		},
		{
			"name": "超强法力药水",
			"quality": "normal",
			"amount": 999, # 测试三位数极值 (999)
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_mp_potion",
			"item_info": {"desc": "瞬间回复 250 点法力值。"}
		},
		{
			"name": "城镇传送卷轴",
			"quality": "normal",
			"amount": 1500, # 测试 1k~9.9k 区间 (1.5k)
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_tp_scroll",
			"item_info": {"desc": "开启一扇通往城镇的安全传送门。"}
		},
		{
			"name": "辨识卷轴",
			"quality": "normal",
			"amount": 88000, # 测试 10k~999k 区间 (88k)
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_id_scroll",
			"item_info": {"desc": "辨识一件未知的魔法装备。"}
		},
		{
			"name": "暗金粉末 (合成精华)",
			"quality": "unique",
			"amount": 999000, # 测试 999k 极限字符宽度
			"icon": "items/misc/herb/herb.lowend.png",
			"cmd": "look mock_powder",
			"item_info": {"desc": "重铸暗金神器的珍稀古代精华粉末。"}
		}
	]
	
	# 渲染背包
	inv_panel.render_lpc_items(mock_items, 8, 40, 1)
	
	# 模拟鼠标悬停在第 16 个格子（即数量为 999000 的暗金粉末）上，触发 Tooltip 展示数量
	await get_tree().create_timer(0.2).timeout
	if inv_panel.slots.size() > 16 and tooltip:
		var slot_btn = inv_panel.slots[16]
		var item_data = inv_panel.items_map.get(16, {})
		if not item_data.is_empty():
			tooltip.show_item(item_data, slot_btn.global_position)
	
	await get_tree().create_timer(0.5).timeout
	
	# 截图保存
	var img = get_viewport().get_texture().get_image()
	var global_path = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/bag_sort_and_stack_preview.png"
	img.save_png(global_path)
	print(">>> 实机截图已成功保存到: %s" % global_path)
	get_tree().quit(0)
