extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	print("=== 开始验证背包与纸娃娃孔位（Sockets）及镶嵌物（Inlays）渲染 ===")
	
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		net.set_process(false)
		net.is_connected = true
	
	var char_panel = hud.char_info_panel
	var bag_panel = hud.inventory_panel
	char_panel.open()
	bag_panel.show()
	await get_tree().process_frame
	
	var esc = char(27)
	
	# 1. 模拟纸娃娃数据 (gscore)
	# weapon: 6孔 (镶嵌 6 颗符文/宝石)
	# armor: 4孔 (经典符文之语刚毅: el, sol, dol, lo)
	# off_hand: 3孔 (空孔)
	# helmet: 2孔 (1孔嵌完美黄宝石, 1孔空孔)
	var test_gscore = {
		"level": 90,
		"hp": 2200,
		"max_hp": 2200,
		"mp": 800,
		"max_mp": 800,
		"equips": {
			"main_hand": {
				"name": "末日之刃",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/weapon/sword/phase_blade.lowend.png",
				"sockets": 6,
				"inlays": [
					"items/misc/rune/jah_rune.lowend.png",
					"items/misc/rune/ber_rune.lowend.png",
					"items/misc/rune/cham_rune.lowend.png",
					"items/misc/gem/perfect_ruby.lowend.png",
					"items/misc/gem/perfect_topaz.lowend.png",
					"items/misc/gem/perfect_diamond.lowend.png"
				],
				"desc": "末日之刃\n相刃\n6孔满镶嵌",
				"file_id": "/d/d2/obj/weapon#doom"
			},
			"armor": {
				"name": "法师铠甲·谜团",
				"quality": "crafted",
				"color": "#ff8c00",
				"icon": "items/armor/armor/plate_mail.lowend.png",
				"sockets": 3,
				"inlays": [
					"items/misc/rune/jah_rune.lowend.png",
					"items/misc/rune/ith_rune.lowend.png",
					"items/misc/rune/ber_rune.lowend.png"
				],
				"desc": "法师铠甲·谜团\n轻甲\n防御: 1067\n需要力量: 55\n需要等级: 65\n+2 所有技能\n+45% 奔跑/行走速度\n+1 传送 (Teleport)\n+775 防御力\n+74 力量 (按等级提高)\n物理伤害减少 8%\n增加最大生命 5%\n88% 获得魔法装备机率 (按等级提高)",
				"file_id": "/d/d2/obj/armor#enigma",
				"item_info": {
					"desc": "法师铠甲·谜团\n轻甲\n防御: 1067\n需要力量: 55\n需要等级: 65\n+2 所有技能\n+45% 奔跑/行走速度\n+1 传送 (Teleport)\n+775 防御力\n+74 力量 (按等级提高)\n物理伤害减少 8%\n增加最大生命 5%\n88% 获得魔法装备机率 (按等级提高)"
				}
			},
			"off_hand": {
				"name": "君主盾 (3孔)",
				"quality": "normal",
				"color": "#ffffff",
				"icon": "items/armor/shield/large_shield.lowend.png",
				"sockets": 3,
				"inlays": [],
				"desc": "君主盾\n凹槽 (3)",
				"file_id": "/d/d2/obj/shield#monarch3s"
			},
			"helmet": {
				"name": "巨骷髅 (2孔)",
				"quality": "unique",
				"color": "#c7b377",
				"icon": "items/armor/helmet/helm.lowend.png",
				"sockets": 2,
				"inlays": [
					"items/misc/gem/perfect_topaz.lowend.png"
				],
				"desc": "巨骷髅\n骨面罩\n凹槽 (2)",
				"file_id": "/d/d2/obj/helm#giantskull"
			}
		}
	}
	
	char_panel.render_gscore_data(test_gscore)
	
	# 2. 模拟背包物品数据 (gbag)
	# 包含 1孔(空), 2孔(嵌宝石), 3孔(谜团), 4孔(眼光), 5孔(梅花), 6孔(满嵌), 并且测试 URL 携带 ?sock=... 格式
	var test_bag_items = [
		{
			"name": "暗影匕首 (1孔)",
			"quality": "normal",
			"amount": 1,
			"cmd": "look /d/d2/obj/dagger#1",
			"icon": "items/weapon/dagger/dagger.lowend.png",
			"sockets": 1,
			"inlays": []
		},
		{
			"name": "水晶剑 (2孔)",
			"quality": "magic",
			"amount": 1,
			"cmd": "look /d/d2/obj/sword#2",
			"icon": "items/weapon/sword/short_sword.lowend.png",
			"sockets": 2,
			"inlays": ["items/misc/gem/perfect_ruby.lowend.png"]
		},
		{
			"name": "法师铠甲·谜团",
			"quality": "unique",
			"amount": 1,
			"cmd": "look /d/d2/obj/armor#enigma",
			"icon": "items/armor/armor/plate_mail.lowend.png",
			"sockets": 3,
			"inlays": [
				"items/misc/rune/jah_rune.lowend.png",
				"items/misc/rune/ith_rune.lowend.png",
				"items/misc/rune/ber_rune.lowend.png"
			]
		},
		{
			"name": "巨神之斧·眼光",
			"quality": "unique",
			"amount": 1,
			"cmd": "look /d/d2/obj/polearm#insight",
			"icon": "items/weapon/spear/spear.lowend.png",
			"sockets": 4,
			"inlays": [
				"items/misc/rune/ral_rune.lowend.png",
				"items/misc/rune/tir_rune.lowend.png",
				"items/misc/rune/tal_rune.lowend.png",
				"items/misc/rune/sol_rune.lowend.png"
			]
		},
		{
			"name": "狂战士斧 (5孔梅花)",
			"quality": "rare",
			"amount": 1,
			"cmd": "look /d/d2/obj/axe#5",
			"icon": "items/weapon/axe/hand_axe.lowend.png",
			"sockets": 5,
			"inlays": [
				"items/misc/rune/hel_rune.lowend.png",
				"items/misc/gem/flawless_emerald.lowend.png"
			]
		},
		{
			"name": "九头蛇弓 (6孔URL兼容)",
			"quality": "crafted",
			"amount": 1,
			"cmd": "look /d/d2/obj/bow#hydra6",
			"icon": "items/weapon/bow/composite_bow.lowend.png?sock=6&inlays=items/misc/rune/ber_rune.lowend.png,items/misc/gem/perfect_diamond.lowend.png,items/misc/rune/ist_rune.lowend.png",
			"sockets": 0, # 测试从 icon 自动解析容错
			"inlays": []
		}
	]
	
	bag_panel.render_lpc_items(test_bag_items, 0, 40, 1, 1)
	
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	
	# 3. 验证纸娃娃上的 sockets_overlay
	var p_weapon = char_panel.slot_main_hand
	var p_armor = char_panel.slot_armor
	var p_shield = char_panel.slot_off_hand
	var p_helm = char_panel.slot_helmet
	
	assert(p_weapon.sockets_overlay != null, "武器槽位应有 sockets_overlay")
	assert(p_weapon.sockets_overlay.current_sock_count == 6, "武器应为 6 孔")
	assert(p_weapon.sockets_overlay.current_inlays.size() == 6, "武器应有 6 个镶嵌物")
	
	assert(p_armor.sockets_overlay.current_sock_count == 3, "护甲应为 3 孔")
	assert(p_armor.sockets_overlay.current_inlays.size() == 3, "护甲应有 3 个符文")
	
	assert(p_shield.sockets_overlay.current_sock_count == 3, "盾牌应为 3 孔")
	assert(p_shield.sockets_overlay.current_inlays.size() == 0, "盾牌应为 3 个空孔")
	
	assert(p_helm.sockets_overlay.current_sock_count == 2, "头盔应为 2 孔")
	assert(p_helm.sockets_overlay.current_inlays.size() == 1, "头盔应有 1 个镶嵌物")
	
	# 4. 验证背包格子的 sockets_overlay
	var b_slot0 = bag_panel.slots[0]
	var b_slot1 = bag_panel.slots[1]
	var b_slot2 = bag_panel.slots[2]
	var b_slot3 = bag_panel.slots[3]
	var b_slot4 = bag_panel.slots[4]
	var b_slot5 = bag_panel.slots[5]
	
	assert(b_slot0.sockets_overlay != null and b_slot0.sockets_overlay.current_sock_count == 1, "背包0应为 1 孔")
	assert(b_slot1.sockets_overlay != null and b_slot1.sockets_overlay.current_sock_count == 2, "背包1应为 2 孔")
	assert(b_slot2.sockets_overlay != null and b_slot2.sockets_overlay.current_sock_count == 3, "背包2应为 3 孔")
	assert(b_slot3.sockets_overlay != null and b_slot3.sockets_overlay.current_sock_count == 4, "背包3应为 4 孔")
	assert(b_slot4.sockets_overlay != null and b_slot4.sockets_overlay.current_sock_count == 5, "背包4应为 5 孔")
	assert(b_slot5.sockets_overlay != null and b_slot5.sockets_overlay.current_sock_count == 6, "背包5从URL解析应为 6 孔")
	assert(b_slot5.sockets_overlay.current_inlays.size() == 3, "背包5从URL解析应有 3 个镶嵌物")
	
	print(">>> 所有纸娃娃与背包凹槽及镶嵌物数据与节点断言全部通过！准备截屏...")
	
	# 截屏保存常规状态 (验证孔位像素级居中)
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_sockets_overlay.png")
	print(">>> 常规截图已保存至 res://test_sockets_overlay.png")
	
	# 5. 验证纸娃娃装备 (法师铠甲·谜团, 3孔) 鼠标悬浮 Tooltip 呈现完整属性与孔位
	var tooltip = hud.item_tooltip
	# 触发纸娃娃 armor 槽位的真实 hover 信号
	char_panel.slot_armor.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	
	assert(tooltip.visible, "Tooltip 必须处于显示状态")
	assert(tooltip.tooltip_sockets != null, "Tooltip 顶层原画大图必须挂载 tooltip_sockets")
	assert(tooltip.tooltip_sockets.current_sock_count == 3, "Tooltip 顶层大图必须正确显示 3 个孔位")
	assert(tooltip.content_label.text.contains("传送"), "Tooltip 属性中必须包含谜团的核心词缀【传送】")
	assert(tooltip.content_label.text.contains("所有技能"), "Tooltip 属性中必须包含【+2 所有技能】")
	assert(tooltip.content_label.text.contains("凹槽"), "Tooltip 文本底部必须包含【凹槽 (3)】")
	print(">>> 纸娃娃谜团 Tooltip 完整属性词缀与镶嵌物验证全部 100% 通过！准备截屏...")
	
	var img_tooltip = get_viewport().get_texture().get_image()
	img_tooltip.save_png("res://test_sockets_tooltip.png")
	print(">>> Tooltip 截图已保存至 res://test_sockets_tooltip.png")
	get_tree().quit(0)
