extends Control
class_name AFK_MainHUD

const MonsterDisplayScene = preload("res://scenes/afk/components/monster_display.tscn")
const CombatFXManagerScene = preload("res://scenes/afk/components/combat_fx_manager.gd")
const LootDropFxScript = preload("res://scenes/afk/components/loot_drop_fx.gd")

# 战场多点位动态槽位池配置 (对齐 AFKandia 10 席网格容量，前排 5、后排 5 错落分布)
const SLOT_POSITIONS = [
	Vector2(0.18, 0.54), # Slot 0: 远左前
	Vector2(0.34, 0.56), # Slot 1: 左前锋
	Vector2(0.50, 0.58), # Slot 2: 正前中锋 (Boss在场时让出)
	Vector2(0.66, 0.56), # Slot 3: 右前锋
	Vector2(0.82, 0.54), # Slot 4: 远右前
	Vector2(0.12, 0.46), # Slot 5: 远左后 (微调避让左上Party HUD)
	Vector2(0.28, 0.44), # Slot 6: 左后 (微调避让左上Party HUD)
	Vector2(0.50, 0.38), # Slot 7: 正后中位
	Vector2(0.72, 0.40), # Slot 8: 右后
	Vector2(0.88, 0.42), # Slot 9: 远右后
]
const BOSS_SLOT = Vector2(0.50, 0.46) # Boss 居中王座
@onready var btn_return_town: Button = %BtnReturnTown
@onready var btn_return_map: Button = %BtnReturnMap
@onready var current_map_label: Label = %CurrentMapLabel
@onready var background_rect: TextureRect = $MainHBox/LeftViewport/Background
@onready var boss_progress_label: Label = %BossProgressLabel
@onready var boss_progress_bar: ProgressBar = %BossProgressBar

@onready var left_viewport: Control = $MainHBox/LeftViewport
@onready var monster_display: AFK_MonsterDisplay = %MonsterDisplay
@onready var battle_statistics: AFK_BattleStatistics = %BattleStatistics
@onready var player_bottom_bar: AFK_PlayerBottomBar = %PlayerBottomBar
@onready var inventory_panel: Control = %PlayerInventoryPanel
@onready var char_info_panel: Control = %CharacterInfoPanel
@onready var control_matrix: AFK_ControlMatrixPanel = %ControlMatrixPanel
@onready var item_tooltip: Control = %ItemTooltip
@onready var world_map: AFK_WorldMap = %WorldMap
@onready var pickup_setting_panel: Control = %PickupSettingPanel
@onready var hook_setting_panel: Control = %HookSettingPanel
@onready var salvage_dialog: Control = %SalvageUniqueConfirmDialog
@onready var skill_panel: AFK_SkillPanel = %SkillPanel
@onready var collapsible_chat: AFK_CollapsibleChatPanel = %CollapsibleChatPanel
@onready var team_invite_dialog: Control = get_node_or_null("%TeamInviteDialog")
@onready var party_hud_panel: Control = get_node_or_null("%PartyHudPanel")
@onready var right_sidebar: Control = %RightSidebar
@onready var btn_toggle_sidebar: Button = %BtnToggleSidebar
var is_sidebar_expanded: bool = true

@onready var death_overlay: ColorRect = get_node_or_null("%DeathOverlay")
@onready var death_countdown_box: Control = get_node_or_null("%DeathCountdownBox")
@onready var death_countdown_num: Label = get_node_or_null("%DeathCountdownNum")
var _death_countdown_timer: float = 0.0
var _death_tween: Tween = null

var cube_panel: AFK_CubePanel = null
const GShopPanelScript = preload("res://scenes/afk/components/gshop_panel.gd")
var gshop_panel: Control = null
var fx_manager: Node2D = null

var current_boss_kills: int = 0
var max_boss_kills: int = 300
var sync_timer: float = 0.0
var _last_tracked_player_hp: int = -1

func _update_player_hp(cur: int, maximum: int) -> void:
	if _last_tracked_player_hp > 0 and cur > _last_tracked_player_hp and _death_countdown_timer <= 0.0:
		var heal_diff = cur - _last_tracked_player_hp
		if battle_statistics and is_instance_valid(battle_statistics):
			battle_statistics.record_heal(heal_diff)
	_last_tracked_player_hp = cur
	if player_bottom_bar and is_instance_valid(player_bottom_bar):
		player_bottom_bar.update_hp(cur, maximum)
	if party_hud_panel and is_instance_valid(party_hud_panel) and party_hud_panel.is_inside_tree() and party_hud_panel.has_method("update_self_hp"):
		party_hud_panel.update_self_hp(cur, maximum)

## 规范化关卡与房间名：剔除冗余的难度前缀 (【普通】/【噩梦】/【地狱】/[普通]等) 及后缀 ((挂机副本)/(挂机点))，纯净展示地名
func _clean_stage_name(raw_name: String) -> String:
	var s = AnsiHelper.to_plain_text(raw_name).strip_edges()
	s = s.replace("【普通】", "").replace("【噩梦】", "").replace("【地狱】", "")
	s = s.replace("[普通]", "").replace("[噩梦]", "").replace("[地狱]", "")
	s = s.replace("(挂机副本)", "").replace("（挂机副本）", "")
	s = s.replace("(挂机点)", "").replace("（挂机点）", "")
	s = s.replace("(副本)", "").replace("（副本）", "")
	return s.strip_edges()

## 统一安全更新当前地图标签（去重与防抖，仅在发生真实变化时更新）
func _set_current_map_label(raw_name: String) -> void:
	if not current_map_label:
		return
	var clean = _clean_stage_name(raw_name)
	if not clean.is_empty() and current_map_label.text != clean:
		current_map_label.text = clean

var _my_player_name: String = ""
var _is_returning_to_town: bool = false

func _ready() -> void:
	if monster_display:
		monster_display.visible = false
	if current_map_label and GameState.current_stage_info is Dictionary and not GameState.current_stage_info.is_empty():
		var init_name = str(GameState.current_stage_info.get("name", ""))
		if not init_name.is_empty():
			_set_current_map_label(init_name)
	# 初始化战斗特效层并挂载至战斗左视口
	fx_manager = CombatFXManagerScene.new()
	var left_vp = get_node_or_null("MainHBox/LeftViewport")
	if left_vp:
		left_vp.add_child(fx_manager)
	else:
		add_child(fx_manager)

	if btn_return_town:
		btn_return_town.pressed.connect(_on_return_town_pressed)
	if btn_return_map:
		btn_return_map.pressed.connect(_on_return_map_pressed)
	if char_info_panel:
		if char_info_panel.has_signal("item_hovered") and item_tooltip:
			char_info_panel.item_hovered.connect(func(item_data, pos):
				item_tooltip.show_item(item_data, pos)
			)
			char_info_panel.item_unhovered.connect(func():
				item_tooltip.hide_tooltip()
			)
		if char_info_panel.has_signal("panel_visibility_changed"):
			char_info_panel.panel_visibility_changed.connect(_on_char_panel_visibility_changed)


	if btn_toggle_sidebar:
		_setup_toggle_button_style()
		btn_toggle_sidebar.pressed.connect(toggle_sidebar)

	
	if inventory_panel and item_tooltip:
		inventory_panel.item_hovered.connect(func(item_data, pos):
			item_tooltip.show_item(item_data, pos)
		)
		inventory_panel.item_unhovered.connect(func():
			item_tooltip.hide_tooltip()
		)
		if inventory_panel.little_pocket_panel:
			inventory_panel.little_pocket_panel.visibility_changed.connect(func():
				if inventory_panel.little_pocket_panel.visible:
					# 单窗口互斥: 打开小口袋时，关闭纸娃娃、魔盒与随身商店
					if char_info_panel and char_info_panel.visible:
						char_info_panel.close()
					if cube_panel and cube_panel.visible:
						cube_panel.visible = false
					if gshop_panel and gshop_panel.visible:
						gshop_panel.close()
			)
		if inventory_panel.socketing_workbench_panel:
			inventory_panel.socketing_workbench_panel.visibility_changed.connect(func():
				if inventory_panel.socketing_workbench_panel.visible:
					# 单窗口互斥: 打开工坊/镶嵌打孔时，关闭纸娃娃、魔盒、技能与随身商店
					if char_info_panel and char_info_panel.visible:
						char_info_panel.close()
					if cube_panel and cube_panel.visible:
						cube_panel.visible = false
					if gshop_panel and gshop_panel.visible:
						gshop_panel.close()
					if skill_panel and skill_panel.visible:
						skill_panel.close()
			)
		
	if world_map:
		world_map.z_index = 200
		world_map.hide()
		world_map.enter_spot.connect(_on_spot_selected)
		world_map.closed.connect(func():
			world_map.hide()
			var cur_st = 1
			var gs = get_node_or_null("/root/GameState")
			if gs and "current_stage_info" in gs and gs.current_stage_info is Dictionary:
				cur_st = _safe_int(gs.current_stage_info.get("stage"), 1)
			if NetworkClient.is_connected and cur_st > 0:
				NetworkClient.send_raw("stage %d" % cur_st)
		)
		
	if control_matrix:
		control_matrix.btn_character_clicked.connect(toggle_character_info)
		control_matrix.btn_hook_clicked.connect(toggle_hook_setting)
		control_matrix.btn_pickup_clicked.connect(toggle_pickup_setting)
		control_matrix.btn_workbench_clicked.connect(toggle_workbench)
		control_matrix.btn_smelt_clicked.connect(func(): NetworkClient.send_raw("gfenjie all"))
		control_matrix.btn_shop_clicked.connect(toggle_gshop_panel)
		control_matrix.btn_skills_clicked.connect(toggle_skill_panel)
		control_matrix.btn_craft_clicked.connect(toggle_cube_panel)
		control_matrix.btn_exit_clicked.connect(_on_exit_to_title)

		# 挂机战斗区：合成魔盒与镶嵌打孔置灰禁用，引导玩家返回营地安全区操作
		if control_matrix.btn_workbench:
			control_matrix.btn_workbench.disabled = true
			control_matrix.btn_workbench.tooltip_text = "战斗区域无法进行镶嵌打孔，请返回营地安全区操作"
		if control_matrix.btn_craft:
			control_matrix.btn_craft.disabled = true
			control_matrix.btn_craft.tooltip_text = "战斗区域无法使用合成魔盒，请返回营地安全区操作"

	if hook_setting_panel:
		hook_setting_panel.settings_saved.connect(func(_cfg):
			_update_hook_btn_style(false)
			if NetworkClient.is_connected:
				NetworkClient.send_raw("chat 挂机设置已成功更新！")
		)
		hook_setting_panel.visibility_changed.connect(func():
			if not hook_setting_panel.visible:
				_update_hook_btn_style(false)
		)

	if skill_panel:
		skill_panel.hide()
		skill_panel.skill_learn_requested.connect(func(code: String):
			if NetworkClient.is_connected:
				NetworkClient.send_raw("glearn " + code)
		)
		skill_panel.skill_reset_requested.connect(func():
			if NetworkClient.is_connected:
				NetworkClient.send_raw("gresetskill")
		)
		skill_panel.skill_buy_respec_requested.connect(func():
			if NetworkClient.is_connected:
				NetworkClient.send_raw("gbuyrespec skill")
		)
		skill_panel.skill_set_binding_requested.connect(func(code: String, slot: String):
			if NetworkClient.is_connected:
				NetworkClient.send_raw("gsetskill %s %s" % [code, slot])
		)

	# 赫拉迪克魔盒浮窗 (gcube 系统功能, 无实体方块门槛)
	if cube_panel == null:
		cube_panel = AFK_CubePanel.new()
		cube_panel.z_index = 150
		add_child(cube_panel)
		cube_panel.visible = false
		cube_panel.action_requested.connect(func(cmd: String):
			if NetworkClient.is_connected:
				NetworkClient.send_raw(cmd)
		)
		cube_panel.item_hovered.connect(func(item_data, pos):
			if item_tooltip:
				item_tooltip.show_item(item_data, pos)
		)
		cube_panel.item_unhovered.connect(func():
			if item_tooltip:
				item_tooltip.hide_tooltip()
		)

	# 随身补给商店浮窗 (4x7 网格随身商店)
	if gshop_panel == null:
		gshop_panel = GShopPanelScript.new()
		gshop_panel.z_index = 150
		add_child(gshop_panel)
		gshop_panel.visible = false
		gshop_panel.item_hovered.connect(func(item_data, pos):
			if item_tooltip:
				item_tooltip.show_item(item_data, pos)
		)
		gshop_panel.item_unhovered.connect(func():
			if item_tooltip:
				item_tooltip.hide_tooltip()
		)

	# 挂机战斗专属可回缩传音视窗联动 (点击与悬浮查看装备属性)
	if collapsible_chat:
		collapsible_chat.item_inspected.connect(_on_chat_item_inspected)
		collapsible_chat.item_hovered.connect(func(file_id: String):
			if item_tooltip:
				var mouse_pos = get_viewport().get_mouse_position()
				item_tooltip.show_item({ "file_id": file_id, "cmd": "glookitem " + file_id }, mouse_pos)
		)
		collapsible_chat.item_unhovered.connect(func():
			if item_tooltip:
				item_tooltip.hide_tooltip()
		)
		
	_update_boss_ui()
	_hook_network_client()
	
	if party_hud_panel:
		if GameState.is_in_team:
			party_hud_panel.update_party(GameState.current_team_members)
		party_hud_panel.tell_requested.connect(func(target_id):
			if collapsible_chat and collapsible_chat.chat_input:
				collapsible_chat.chat_input.text = "/tell %s " % target_id
				collapsible_chat.chat_input.grab_focus()
				collapsible_chat.chat_input.caret_column = collapsible_chat.chat_input.text.length()
		)
		party_hud_panel.team_dismiss_requested.connect(func():
			if not GameState.is_team_leader():
				show_toast("正在脱离队伍并安全返回主城营地...")
				await get_tree().create_timer(0.3).timeout
				_on_return_town_pressed(true)
		)
	
	# 客户端细则分解提示挂接
	if has_node("/root/CustomSalvageManager"):
		var csm = get_node("/root/CustomSalvageManager")
		if csm and csm.has_signal("salvage_triggered"):
			csm.salvage_triggered.connect(func(cnt: int, names: Array[String]):
				var sample = "、".join(names.slice(0, 3)) + (" 等" if names.size() > 3 else "")
				var tip = "[color=#ffb74d]♻️ 【细则分解】[/color] 自动分解了 %d 件未保留装备：%s" % [cnt, sample]
				GameState.add_chat_message(tip, "细则分解")
			)

	# 向 LPC 请求初始核心全量数据帧
	_request_lpc_sync()
	
	# 初始化战斗场景背景图 (动态对齐当前关卡实景)
	var init_bg = ""
	var init_st = 1
	if GameState.current_stage_info is Dictionary:
		init_bg = str(GameState.current_stage_info.get("bg", ""))
		init_st = _safe_int(GameState.current_stage_info.get("stage"), 1)
	_update_battlefield_background(init_bg, init_st)

func _process(delta: float) -> void:
	# 死亡倒地调息大倒计时动态推进
	if _death_countdown_timer > 0.0:
		var old_int = int(ceil(_death_countdown_timer))
		_death_countdown_timer = max(0.0, _death_countdown_timer - delta)
		var new_int = int(ceil(_death_countdown_timer))
		if new_int != old_int and new_int > 0:
			_update_death_countdown_display(new_int, true)
		elif _death_countdown_timer <= 0.0:
			_end_death_state()

	# 每 1.5 秒与 LPC 服务端同步全景战斗快照 (ghp1) 与角色基础属性 (gscore)
	sync_timer += delta
	if sync_timer >= 1.5:
		sync_timer = 0.0
		if NetworkClient.is_connected:
			NetworkClient.send_raw("ghp1")
			NetworkClient.send_raw("gscore")

## 启动死亡黑白灰度视界与居中大倒计时
func _start_death_state(seconds: float = 10.0) -> void:
	if battle_statistics and is_instance_valid(battle_statistics):
		battle_statistics.record_death()
	if not death_overlay:
		death_overlay = get_node_or_null("%DeathOverlay")
	if not death_overlay:
		return

	death_overlay.visible = true
	_death_countdown_timer = seconds
	_update_death_countdown_display(int(ceil(_death_countdown_timer)), true)
	if btn_return_town:
		btn_return_town.disabled = true

	# 平滑渐变进入黑白灰度与暗调 (Rec. 601 灰度加权)
	var mat = death_overlay.material as ShaderMaterial
	if mat:
		if _death_tween and _death_tween.is_valid():
			_death_tween.kill()
		_death_tween = create_tween().set_parallel(true)
		_death_tween.tween_property(mat, "shader_parameter/gray_amount", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_death_tween.tween_property(mat, "shader_parameter/darkness", 0.35, 0.35)

## 结束死亡黑白灰度，恢复明亮色彩
func _end_death_state(instant: bool = false) -> void:
	_death_countdown_timer = 0.0
	if btn_return_town:
		btn_return_town.disabled = false
	if not death_overlay:
		death_overlay = get_node_or_null("%DeathOverlay")
	if not death_overlay:
		return

	var mat = death_overlay.material as ShaderMaterial
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()

	if instant or not mat:
		if mat:
			mat.set_shader_parameter("gray_amount", 0.0)
			mat.set_shader_parameter("darkness", 0.0)
		death_overlay.visible = false
		return

	_death_tween = create_tween().bind_node(death_overlay).set_parallel(true)
	_death_tween.tween_property(mat, "shader_parameter/gray_amount", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(mat, "shader_parameter/darkness", 0.0, 0.35)
	_death_tween.chain().tween_callback(_on_death_overlay_hidden)

func _on_death_overlay_hidden() -> void:
	if btn_return_town:
		btn_return_town.disabled = false
	if is_instance_valid(death_overlay):
		death_overlay.visible = false

## 更新居中大倒计时数字，并伴随弹性缩放回弹动效
func _update_death_countdown_display(num: int, pulse: bool = false) -> void:
	if not death_countdown_num:
		death_countdown_num = get_node_or_null("%DeathCountdownNum")
	if death_countdown_num:
		death_countdown_num.text = str(max(1, num))
		if pulse:
			death_countdown_num.pivot_offset = death_countdown_num.size * 0.5
			var tw = create_tween()
			tw.tween_property(death_countdown_num, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(death_countdown_num, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _request_lpc_sync() -> void:
	if NetworkClient.is_connected:
		print("[AFK_MainHUD] 正在向 LPC 发送 ghp1, gscore, gbag 1, stage, look 初始化指令...")
		NetworkClient.send_raw("ghp1")
		NetworkClient.send_raw("gscore")
		NetworkClient.send_raw("gbag 1")
		NetworkClient.send_raw("stage")
		NetworkClient.send_raw("look")

var _is_changing_scene: bool = false

func _on_return_town_pressed(force: bool = false) -> void:
	if _is_changing_scene:
		return

	# 若玩家正处于死亡倒地休整状态，且非强制，严禁手动回城，防止规避死亡惩罚
	if not force and _death_countdown_timer > 0.0:
		show_toast("当前正处于重伤休整中，无法返回营地！")
		return

	# 组队状态下，仅队长有权带队返回安全区；队员禁止单独返回安全区（除非先主动离队）
	if not force and GameState.is_in_team and not GameState.is_team_leader():
		show_toast("当前处于队伍中，队员无法单独返回安全区，请先离队！")
		return

	# 依据当前关卡所属大幕精准预设目标主城，杜绝切场景瞬间闪烁或误判
	if GameState.current_stage_info is Dictionary and GameState.current_stage_info.has("act"):
		var cur_act = int(GameState.current_stage_info.get("act", 1))
		if cur_act == 1:
			GameState.current_town_name = "罗格营地"
			GameState.current_location_act = "act1"
		elif cur_act == 2:
			GameState.current_town_name = "鲁高因"
			GameState.current_location_act = "act2"
		elif cur_act == 3:
			GameState.current_town_name = "库拉斯特"
			GameState.current_location_act = "act3"
		elif cur_act == 4:
			GameState.current_town_name = "群魔堡垒"
			GameState.current_location_act = "act4"
		elif cur_act == 5:
			GameState.current_town_name = "哈洛加斯"
			GameState.current_location_act = "act5"

	if not force:
		if NetworkClient.is_connected:
			print("[AFK_MainHUD] 正在向服务端请求脱战返回安全大本营: stage town ...")
			NetworkClient.send_raw("stage town")
			show_toast("正在向营地撤退脱战...")
		# 核心：普通点击绝不盲切场景！严守由服务端权威下发的 stage_leave 确认帧触发切场景！
		return

	# 仅在 force == true（如 gstatus 确认人已在主城安全区，或特定系统兜底强制切换）时才直接切场景
	_is_changing_scene = true
	print("[AFK_MainHUD] 确认进入主城安全大本营: res://scenes/town/town_hub.tscn")
	_end_death_state(true)
	var tree = get_tree()
	if tree and is_inside_tree():
		tree.change_scene_to_file("res://scenes/town/town_hub.tscn")

## 清空战场全部实体与飞行中特效 (用于返回大地图或切关时彻底清场)
func _clear_battlefield() -> void:
	_end_death_state(true)
	var preset_display = get_node_or_null("%MonsterDisplay")
	monster_display = preset_display
	if monster_display and is_instance_valid(monster_display):
		monster_display.visible = false

	for mid in _monster_instances.keys():
		var node = _monster_instances[mid]
		if is_instance_valid(node) and node != preset_display:
			node.queue_free()
	_monster_instances.clear()
	_occupied_slots.clear()
	_current_target_id = ""

	# 深度兜底：地毯式清除战场父视口下的全部怪物节点，杜绝任何游离怪
	var parent_vp = left_viewport if left_viewport else get_node_or_null("MainHBox/LeftViewport")
	if parent_vp and is_instance_valid(parent_vp):
		for child in parent_vp.get_children():
			if child != preset_display and is_instance_valid(child) and child.has_method("bind_monster_data"):
				child.queue_free()
	
	# 清空正在飞行的残余弹道与特效节点
	if fx_manager and is_instance_valid(fx_manager):
		for child in fx_manager.get_children():
			if is_instance_valid(child):
				child.queue_free()
				
	# 重置底栏攻速进度条归零
	if player_bottom_bar and is_instance_valid(player_bottom_bar):
		player_bottom_bar.attack_timer = 0.0
		if player_bottom_bar.attack_progress_bar:
			player_bottom_bar.attack_progress_bar.value = 0.0

func _on_return_map_pressed() -> void:
	# 组队状态下，仅队长有权操作大地图选点
	if GameState.is_in_team and not GameState.is_team_leader():
		show_toast("当前处于队伍中，仅队长可操作大地图选点！")
		return

	# 仅请求最新大地图进度 stage_info，绝不发送 stage leave 破坏挂机
	if NetworkClient.is_connected:
		NetworkClient.send_raw("stage")

	# 弹出大地图供玩家从容选点：保持当前挂机关卡所属大幕连贯
	if world_map:
		world_map.reset_user_selection()
		var target_act = ""
		if GameState.current_stage_info is Dictionary and GameState.current_stage_info.has("act"):
			var cur_act_num = int(GameState.current_stage_info.get("act", 1))
			target_act = "act%d" % cur_act_num
			GameState.selected_act = target_act
		elif GameState.current_location_act != "":
			target_act = GameState.current_location_act
		elif GameState.selected_act != "":
			target_act = GameState.selected_act

		if target_act != "" and world_map.ACTS_CONFIG.has(target_act):
			world_map.switch_act(target_act, false)
		else:
			world_map._auto_locate_act()

		world_map.update_progress(GameState.player_max_stage)
		world_map.move_to_front()
		world_map.show()

func _on_spot_selected(spot_data: Dictionary) -> void:
	var is_town = spot_data.get("is_town", false)
	var s_name = str(spot_data.get("name", "鲜血荒地"))
	var stage_id = _safe_int(spot_data.get("stage_id"), 0 if is_town else 1)
	var bg = str(spot_data.get("bg", ""))

	if is_town:
		var act_id = str(spot_data.get("act_id", ""))
		if act_id.is_empty():
			var r_path = str(spot_data.get("room_path", ""))
			if "/d/act5/" in r_path: act_id = "act5"
			elif "/d/act4/" in r_path: act_id = "act4"
			elif "/d/act3/" in r_path: act_id = "act3"
			elif "/d/act2/" in r_path: act_id = "act2"
			elif "/d/act1/" in r_path: act_id = "act1"
			else: act_id = "act1"
		print("[AFK_MainHUD] 大地图点选安全区小站: %s (%s)，请求安全脱战前往大本营..." % [s_name, act_id])
		if world_map:
			world_map.hide()
		show_toast("正在通过传送小站前往【%s】..." % s_name)
		if NetworkClient.is_connected:
			NetworkClient.send_raw("stage town %s" % act_id)
		return

	_set_current_map_label(s_name)
	_update_battlefield_background(bg, stage_id)
	print("[AFK_MainHUD] 大地图选点切关: Stage %d【%s】" % [stage_id, s_name])
	if world_map:
		world_map.hide()
	_clear_battlefield()
	if NetworkClient.is_connected:
		NetworkClient.send_raw("stage %d" % stage_id)

## 动态刷新战场背景贴图 (根据大幕与关卡 1:1 加载 worlds/{act}/{idx}.png，彻底消除万年鲜血荒地)
func _update_battlefield_background(bg_path: String, stage_id: int = 0) -> void:
	if not background_rect:
		background_rect = get_node_or_null("MainHBox/LeftViewport/Background")
	if not background_rect:
		return
		
	var target_res = bg_path
	if target_res.is_empty() and stage_id > 0:
		var act = 1
		var sub_idx = stage_id
		if stage_id > 64:
			act = 5
			sub_idx = stage_id - 64
		elif stage_id > 56:
			act = 4
			sub_idx = stage_id - 56
		elif stage_id > 34:
			act = 3
			sub_idx = stage_id - 34
		elif stage_id > 14:
			act = 2
			sub_idx = stage_id - 14
		else:
			act = 1
			sub_idx = stage_id
		target_res = "res://mods/vanilla/assets/worlds/%d/%d.webp" % [act, sub_idx]
	
	# 兼容处理：因客户端已瘦身为 .webp，若传入为 .png 且不存在时自动重定向为 .webp
	if not ResourceLoader.exists(target_res) and target_res.ends_with(".png"):
		var webp_res = target_res.replace(".png", ".webp")
		if ResourceLoader.exists(webp_res):
			target_res = webp_res

	if not target_res.is_empty() and ResourceLoader.exists(target_res):
		background_rect.texture = load(target_res)
		print("[AFK_MainHUD] 战场实景贴图已切换: ", target_res)

func _update_boss_ui() -> void:
	if max_boss_kills <= 0:
		return
	var pct = int((float(current_boss_kills) / float(max_boss_kills)) * 100.0)
	if boss_progress_label:
		boss_progress_label.text = "BOSS进度: (%d/%d) %d%%" % [current_boss_kills, max_boss_kills, pct]
	if boss_progress_bar:
		boss_progress_bar.value = pct

func _on_exit_to_title() -> void:
	await NetworkClient.safe_quit_and_disconnect()
	var tree = get_tree()
	if tree and is_inside_tree():
		tree.change_scene_to_file("res://scenes/login/login_screen.tscn")

func _hook_network_client() -> void:
	# 1. 从 GameState 兜底初始化
	var cdata = GameState.selected_character
	if not cdata.is_empty():
		var cname = str(cdata.get("name", "英雄"))
		var clevel = int(cdata.get("level", 1))
		var clife = int(cdata.get("life", 173))
		var cmana = int(cdata.get("mana", 84))
		var cgold = int(cdata.get("gold", 0))
		if player_bottom_bar:
			player_bottom_bar.update_player_info("Lv.%d %s" % [clevel, cname])
			player_bottom_bar.update_hp(clife, clife)
			player_bottom_bar.update_mp(cmana, cmana)
		if inventory_panel and inventory_panel.gold_label:
			inventory_panel.gold_label.text = "%sG" % str(cgold)
			
	# 2. 监听 LPC 战网事件 (防重连接保护)
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		var net = get_node_or_null("/root/NetworkClient")
		if net:
			print("[AFK_MainHUD] Connected to NetworkClient successfully")
			if not net.json_frame_received.is_connected(_on_network_json):
				net.json_frame_received.connect(_on_network_json)
			if not net.text_received.is_connected(_on_network_text):
				net.text_received.connect(_on_network_text)
			if net.has_signal("reconnected_to_server") and not net.reconnected_to_server.is_connected(_on_reconnected_to_server):
				net.reconnected_to_server.connect(_on_reconnected_to_server)

func _exit_tree() -> void:
	var net = get_node_or_null("/root/NetworkClient")
	if net:
		if net.has_signal("json_frame_received") and net.json_frame_received.is_connected(_on_network_json):
			net.json_frame_received.disconnect(_on_network_json)
		if net.has_signal("text_received") and net.text_received.is_connected(_on_network_text):
			net.text_received.disconnect(_on_network_text)
		if net.has_signal("reconnected_to_server") and net.reconnected_to_server.is_connected(_on_reconnected_to_server):
			net.reconnected_to_server.disconnect(_on_reconnected_to_server)

func _on_reconnected_to_server() -> void:
	print("[AFK_MainHUD] ★★★ 断线重连成功，正在向 LPC 请求最新战场状态同步 ★★★")
	show_toast("已重新连接服务器！正在同步战场状态...")
	_request_lpc_sync()

static func _safe_int(val: Variant, default_val: int = 0) -> int:
	if val == null:
		return default_val
	if val is int:
		return val
	if val is float:
		return int(val)
	if val is String:
		return val.to_int() if val.is_valid_int() else default_val
	return default_val

static func _safe_float(val: Variant, default_val: float = 0.0) -> float:
	if val == null:
		return default_val
	if val is float:
		return val
	if val is int:
		return float(val)
	if val is String:
		return val.to_float() if val.is_valid_float() else default_val
	return default_val

## 精准寻找战场怪物实例 (强制 UUID/file_name 精准对齐，杜绝同名/子串误伤)
func _find_monster_node(mon_id: String, mon_uuid: String) -> AFK_MonsterDisplay:
	# 1. 严格优先通过全局唯一 UUID (即服务端的 file_name) 精准查找
	var raw_uuid = mon_uuid.strip_edges()
	if raw_uuid.begins_with("look "):
		raw_uuid = raw_uuid.substr(5).strip_edges()
		
	if not raw_uuid.is_empty():
		if _monster_instances.has(raw_uuid):
			var cand = _monster_instances[raw_uuid]
			if is_instance_valid(cand) and not cand.is_dying:
				return cand
		# 兼容带/不带前导斜杠的不同序列化形式
		var alt_uuid = ("/" + raw_uuid) if not raw_uuid.begins_with("/") else raw_uuid.substr(1)
		if _monster_instances.has(alt_uuid):
			var cand = _monster_instances[alt_uuid]
			if is_instance_valid(cand) and not cand.is_dying:
				return cand
				
	# 2. 备用安全查找：仅在 mon_uuid 确实为空时进行严格相等匹配，严禁子串模糊污染！
	if not mon_id.is_empty():
		# 优先检查当前聚焦目标是否正好是该 id/key
		if not _current_target_id.is_empty() and _monster_instances.has(_current_target_id):
			var cur_node = _monster_instances[_current_target_id]
			if is_instance_valid(cur_node) and not cur_node.is_dying:
				if cur_node.cur_mon_key == mon_id or cur_node.cur_id == mon_id:
					return cur_node
		# 严格相等比对，绝不使用 "in" 子串模糊命中
		for mid in _monster_instances.keys():
			var n = _monster_instances[mid]
			if is_instance_valid(n) and not n.is_dying:
				if n.cur_mon_key == mon_id or n.cur_id == mon_id or mid == mon_id:
					return n
	return null

## -------------------------------------------------------------
## LPC 服务端专属协议解构
## -------------------------------------------------------------
func _on_network_json(type: String, data: Variant) -> void:
	if not is_inside_tree():
		return

	# 0. LPC 专属大地图关卡进度帧 (stage_info 按需查询或Boss晋级推送)
	if type == "stage_info" and data is Dictionary:
		var max_s = _safe_int(data.get("max_stage"), 0)
		GameState.player_max_stage = max_s
		GameState.team_bottleneck_name = str(data.get("bottleneck_name", ""))
		if data.has("worlds") and data["worlds"] is Array:
			GameState.unlocked_worlds = data["worlds"]
		if data.has("selected_stage"):
			GameState.selected_stage_id = _safe_int(data.get("selected_stage"), 1)
		if data.has("selected_act"):
			GameState.selected_act = str(data.get("selected_act", "act1"))
		if data.has("stage_alvls") and data["stage_alvls"] is Dictionary:
			GameState.stage_alvls = data["stage_alvls"]
		print("[AFK_MainHUD] 收到关卡进度更新: max_stage = %d, worlds = %d, selected = %d (%s), alvls = %d" % [max_s, GameState.unlocked_worlds.size(), GameState.selected_stage_id, GameState.selected_act, GameState.stage_alvls.size()])
		if world_map:
			world_map.update_progress(max_s)

	# 0.1 LPC 专属拾取与分解帧 (gfenjie)
	if type == "gfenjie" and data is Dictionary:
		var action = str(data.get("action", ""))
		if action == "config" or action == "save_success":
			var cfg = data.get("config", {})
			if pickup_setting_panel and pickup_setting_panel.has_method("open_with_config"):
				pickup_setting_panel.open_with_config(cfg)
		elif action == "salvage_result":
			var count = _safe_int(data.get("count"), 1)
			var it_name = AnsiHelper.to_plain_text(str(data.get("item_name", "")))
			var rewards = data.get("rewards", {})
			var gold = _safe_int(rewards.get("gold"), 0)
			var dust = _safe_int(rewards.get("dust"), 0)
			var shard = _safe_int(rewards.get("shard"), 0)
			var essence = _safe_int(rewards.get("essence"), 0)
			var jinsha = _safe_int(rewards.get("jinsha"), 0)
			print("[AFK_MainHUD] 分解成功: %d 件物品, 获得金币: +%d, 魔尘: +%d, 暗金碎片: +%d" % [count, gold, dust, shard])
			
			var tip_parts: Array[String] = []
			if gold > 0: tip_parts.append("金币 +%d" % gold)
			if dust > 0: tip_parts.append("魔尘 +%d" % dust)
			if shard > 0: tip_parts.append("暗金碎片 +%d" % shard)
			if essence > 0: tip_parts.append("套装精华 +%d" % essence)
			if jinsha > 0: tip_parts.append("金沙 +%d" % jinsha)
			var tip_str = ("，".join(tip_parts)) if not tip_parts.is_empty() else "成功"
			
			if count == 1 and not it_name.is_empty():
				show_toast("成功分解【%s】（%s）" % [it_name, tip_str])
			else:
				show_toast("成功分解 %d 件物品（%s）" % [count, tip_str])
			
			var sal_ids = data.get("salvaged_ids", [])
			if sal_ids is Array and inventory_panel and inventory_panel.has_method("update_item_amount"):
				for s_fid in sal_ids:
					inventory_panel.update_item_amount(str(s_fid), 0)
		elif action == "error":
			var msg = str(data.get("msg", "分解失败！"))
			show_toast(msg)

	# 0.2 LPC 专属挂机与推图设置帧 (afk_settings)
	if type == "afk_settings" and data is Dictionary:
		if hook_setting_panel and hook_setting_panel.has_method("_apply_settings_from_server"):
			hook_setting_panel._apply_settings_from_server(data)
			
	# 1. LPC 专属全结构化角色属性帧 (gscore)
	if type == "gscore" and data is Dictionary:
		var cname = str(data.get("name", "英雄"))
		var lvl = _safe_int(data.get("level"), 1)
		var hp = _safe_int(data.get("hp"), 0)
		var max_hp = _safe_int(data.get("max_hp"), 1)
		var mp = _safe_int(data.get("mp"), 0)
		var max_mp = _safe_int(data.get("max_mp"), 1)
		var zone = str(data.get("zone", ""))
		
		if player_bottom_bar:
			player_bottom_bar.update_player_info("Lv.%d %s" % [lvl, cname])
			_update_player_hp(hp, max_hp)
			player_bottom_bar.update_mp(mp, max_mp)
			var g_cur = _safe_int(data.get("exp_cur"), -1)
			var g_max = _safe_int(data.get("exp_max"), -1)
			var g_pct = float(data.get("exp_pct", -1.0))
			if g_cur >= 0 and g_max >= 0:
				player_bottom_bar.update_exp(g_cur, g_max, g_pct)
		# gscore 专注角色属性同步；仅在地图标签未初始化时进行保底赋值，打怪过程中绝不重复改写
		if not zone.is_empty() and current_map_label and (current_map_label.text.is_empty() or current_map_label.text == "烈风平原"):
			_set_current_map_label(zone)
		if char_info_panel and char_info_panel.has_method("render_gscore_data"):
			char_info_panel.render_gscore_data(data)

			
	# 2. LPC 专属背包帧 (gbag)
	elif type == "gbag" and data is Dictionary:
		var items_list = data.get("items", [])
		var charm_used = _safe_int(data.get("charm_used_slots"), -1)
		var charm_max = _safe_int(data.get("charm_max_slots"), 40)
		var total_pages = _safe_int(data.get("pages"), 1)
		var cur_page = _safe_int(data.get("page", data.get("current_page")), 1)
		print("[AFK_MainHUD] 收到 LPC 专属背包帧 gbag: %d 件物品, 护身符口袋: %d/%d, 总页数: %d, 当前页: %d" % [items_list.size(), charm_used, charm_max, total_pages, cur_page])
		if inventory_panel:
			inventory_panel.render_lpc_items(items_list, charm_used, charm_max, total_pages, cur_page, data)
			
	# 2.1 LPC 专属背包物品增量更新帧 (gbag_item_update: 零重绘局部 -1 或清空格子)
	elif type == "gbag_item_update" and data is Dictionary:
		var fid = str(data.get("file_id", ""))
		var amt = _safe_int(data.get("amount"), 0)
		if inventory_panel and inventory_panel.has_method("update_item_amount"):
			inventory_panel.update_item_amount(fid, amt)
	# 2.2 LPC 背包账本补丁帧 (gbag_patch: 掉落入包的权威页/槽/条目, 虚影根治 2026-10-04)
	elif type == "gbag_patch" and data is Dictionary:
		if inventory_panel and inventory_panel.has_method("apply_gbag_patch"):
			inventory_panel.apply_gbag_patch(data)
		if has_node("/root/CustomSalvageManager"):
			var csm = get_node("/root/CustomSalvageManager")
			if csm and csm.has_method("notify_loot_dropped"):
				csm.notify_loot_dropped()

	# 3. 经典状态帧 (status: 仅更新玩家自身状态)
	elif type == "status" and data is Dictionary:
		var bars = data.get("bars", [])
		if bars is Array and bars.size() >= 4:
			var hp_b = bars[0]
			var mp_b = bars[3]
			var h_cur = _safe_int(hp_b.get("cur"), -1)
			var h_max = _safe_int(hp_b.get("max"), -1)
			var m_cur = _safe_int(mp_b.get("cur"), -1)
			var m_max = _safe_int(mp_b.get("max"), -1)
			if h_cur >= 0 and h_max > 0: _update_player_hp(h_cur, h_max)
			if player_bottom_bar and m_cur >= 0 and m_max > 0: player_bottom_bar.update_mp(m_cur, m_max)
		elif data.has("qi") or data.has("max_qi") or data.has("jing") or data.has("max_jing"):
			var hp = _safe_int(data.get("qi"), -1)
			var max_hp = _safe_int(data.get("max_qi"), -1)
			var mp = _safe_int(data.get("jing"), -1)
			var max_mp = _safe_int(data.get("max_jing"), -1)
			if hp >= 0 and max_hp > 0: _update_player_hp(hp, max_hp)
			if player_bottom_bar and mp >= 0 and max_mp > 0: player_bottom_bar.update_mp(mp, max_mp)
		# 纯后端数据驱动：更新经验进度条
		var s_cur = _safe_int(data.get("exp_cur"), -1)
		var s_max = _safe_int(data.get("exp_max"), -1)
		var s_pct = float(data.get("exp_pct", -1.0))
		if s_cur >= 0 and s_max >= 0 and player_bottom_bar:
			player_bottom_bar.update_exp(s_cur, s_max, s_pct)
		var s_lvl = _safe_int(data.get("lvl"), -1)
		if s_lvl > 0 and player_bottom_bar and not _my_player_name.is_empty():
			player_bottom_bar.update_player_info("Lv.%d %s" % [s_lvl, _my_player_name])
		var gold = _safe_int(data.get("gold"), -1)
		if gold >= 0:
			if inventory_panel:
				if inventory_panel.has_method("update_gold"):
					inventory_panel.update_gold(gold)
				elif inventory_panel.gold_label:
					inventory_panel.gold_label.text = "%dG" % gold
			if gshop_panel and gshop_panel.has_method("update_gold"):
				gshop_panel.update_gold(gold)
				
	# 3.1 目标怪物血量帧 (charhp: 严格按服务端下发的实体 UUID/file_name 精准定向更新)
	elif type == "charhp" and data is Dictionary:
		var raw_hp = str(data.get("hp", ""))
		var target_name = str(data.get("name", ""))
		if ":" in raw_hp and not target_name.is_empty():
			var parts = raw_hp.split(":")
			if parts.size() >= 2:
				var c_hp = parts[0].to_int()
				var m_hp = parts[1].to_int()
				# 严格按服务端发来的受击实体 file_name 进行精准定向更新，彻底杜绝盲写当前目标！
				var target_node = _find_monster_node("", target_name)
				if target_node and is_instance_valid(target_node):
					# 若该怪物当前正处于多段连击弹道飞行窗口中，暂不让 charhp 提前抢跑剧透血量
					var in_combo_until = int(target_node.get_meta("in_combo_until", 0))
					if in_combo_until > Time.get_ticks_msec():
						pass
					else:
						target_node.update_hp(c_hp, m_hp)
			
	# 3.2 角色升级纯 JSON 事件帧 (level_up: 纯后端数据驱动)
	elif type == "level_up" and data is Dictionary:
		var n_lvl = _safe_int(data.get("level"), 1)
		var msg = str(data.get("msg", "恭喜升级！"))
		print("[AFK_MainHUD] ★★★ 收到升级广播: Lv.%d, %s ★★★" % [n_lvl, msg])
		show_toast("★★★ %s ★★★" % msg)
		if player_bottom_bar:
			player_bottom_bar.play_level_up_fx()
			if not _my_player_name.is_empty():
				player_bottom_bar.update_player_info("Lv.%d %s" % [n_lvl, _my_player_name])
		_send_lpc_cmd("gscore")
			
	# 4. 场景标题 (title / room)
	elif (type == "title" or type == "room") and data is Dictionary:
		var rname = str(data.get("name", ""))
		# 仅在首次进入房间或地图标签为空时兜底设置，避免与 stage_enter 冲突
		if not rname.is_empty() and current_map_label and (current_map_label.text.is_empty() or current_map_label.text == "烈风平原"):
			_set_current_map_label(rname)
			
	# 5. LPC 专属凹槽工坊帧 (gsocket)
	elif type == "gsocket" and data is Dictionary:
		if inventory_panel and inventory_panel.socketing_workbench_panel:
			inventory_panel.socketing_workbench_panel.render_workbench_data(data)

	# 6. LPC 专属赫拉迪克魔盒帧 (gcube)
	elif type == "gcube" and data is Dictionary:
		if cube_panel:
			cube_panel.render_gcube_data(data)

	# 6.5 LPC 专属随身补给商店帧 (gshop)
	elif type == "gshop" and data is Dictionary:
		if gshop_panel:
			gshop_panel.update_shop_data(data)
			if gshop_panel.visible:
				_position_gshop_panel()

	# 6.6 LPC 随身商店购买反馈帧 (gshop_msg)
	elif type == "gshop_msg" and data is Dictionary:
		var msg = str(data.get("msg", ""))
		if not msg.is_empty():
			show_toast(msg)

	# 6.7 LPC 背包系统与满包警告反馈帧 (gbag_msg)
	elif type == "gbag_msg" and data is Dictionary:
		var msg = str(data.get("msg", ""))
		if not msg.is_empty():
			show_toast(msg)

	# 7. LPC 专属全结构化技能树帧 (gskills)
	elif type == "gskills" and data is Dictionary:
		if skill_panel:
			skill_panel.render_gskills_data(data)
		# 实时同步当前主攻技能到界面底栏
		var main_sk = str(data.get("main_skill", ""))
		if player_bottom_bar:
			if not main_sk.is_empty():
				var sk_info = data.get("skills", {}).get(main_sk, {})
				var sk_display = sk_info.get("name", main_sk) if sk_info is Dictionary else main_sk
				player_bottom_bar.set_main_skill(str(sk_display), main_sk)
			else:
				player_bottom_bar.set_main_skill("普通攻击", "attack")

	# 8. LPC 专属轻提示帧 (toast)
	elif type == "toast":
		show_toast(str(data))

	# 9. LPC 专属频道广播帧 (channel: chat/bill/rumor 等)
	elif type == "channel":
		var channel_text = ""
		if data is Dictionary:
			channel_text = str(data.get("text", data.get("msg", "")))
		elif data is String:
			channel_text = data
		if not channel_text.is_empty():
			_process_chat_text(channel_text)

	# 10. LPC 普通文本/富文本/系统反馈帧 (text: 队伍聊天/系统提示/操作报错)
	elif type == "text":
		var plain_or_ansi = ""
		if data is String:
			plain_or_ansi = data
		elif data is Dictionary:
			plain_or_ansi = str(data.get("text", data.get("msg", "")))
		if not plain_or_ansi.is_empty():
			_process_chat_text(plain_or_ansi)

	# 11. LPC 复合交互面板帧 (panel: 组队邀请确认、交互菜单等)
	elif type == "panel" and data is Dictionary:
		var desc = str(data.get("desc", ""))
		var raw_actions = data.get("actions", [])
		var actions: Array = raw_actions if raw_actions is Array else []
		
		var is_team_invite = false
		var accept_cmd = ""
		var reject_cmd = "look"
		
		var clean_desc = AnsiHelper.to_plain_text(desc)
		if "邀请你加入" in clean_desc or "组队" in clean_desc:
			is_team_invite = true
			
		for act in actions:
			if act is Dictionary:
				var cmd = str(act.get("cmd", ""))
				var raw_lbl = str(act.get("label", act.get("name", "")))
				var clean_lbl = AnsiHelper.to_plain_text(raw_lbl).strip_edges()
				
				if cmd.begins_with("team with "):
					is_team_invite = true
					accept_cmd = cmd
				elif clean_lbl == "接受" and accept_cmd.is_empty():
					accept_cmd = cmd
				elif clean_lbl == "拒绝":
					reject_cmd = cmd
					
		if is_team_invite and not accept_cmd.is_empty():
			if team_invite_dialog:
				team_invite_dialog.show_invite(desc, accept_cmd, reject_cmd)
			return
			
		if item_tooltip and item_tooltip.visible:
			item_tooltip._on_network_json("panel", data)

	# 12. LPC 专属组队更新帧 (team: 队长与队员实时列表及血量)
	elif type == "team" and data is Dictionary:
		var leader_id = str(data.get("leader", ""))
		var raw_m = data.get("members", [])
		var members: Array = raw_m if raw_m is Array else []
		GameState.update_team_data(leader_id, members)
		if party_hud_panel and party_hud_panel.has_method("update_party"):
			party_hud_panel.update_party(members)

	# 13. LPC 线性推关进场帧 (stage_enter)
	elif type == "stage_enter" and data is Dictionary:
		var s_name = str(data.get("name", "挂机副本"))
		var s_id = _safe_int(data.get("stage"), 1)
		var bg = str(data.get("bg", ""))
		GameState.current_stage_info = data
		GameState.selected_stage_id = s_id
		var act_num = _safe_int(data.get("act"), 1)
		GameState.selected_act = "act%d" % act_num
		GameState.current_location_act = "act%d" % act_num
		_set_current_map_label(s_name)
		_update_battlefield_background(bg, s_id)

		# 切图平滑清场：销毁旧场景残留怪节点、清空槽位与残余特效
		_is_returning_to_town = false
		_clear_battlefield()

		NetworkClient.send_raw("ghp1")

	# 13.1 LPC 离开挂机副本待机帧 (stage_leave: 队长带队回城广播或单人脱战)
	elif type == "stage_leave":
		_clear_battlefield()
		var t_name = "罗格营地"
		var act_id = "act1"
		var revive_rem = 0.0
		if data is Dictionary:
			t_name = str(data.get("town_name", data.get("town", "罗格营地")))
			act_id = str(data.get("act_id", "act1"))
			revive_rem = float(data.get("revive_remain", 0.0))
		elif data is String:
			for part in data.split(","):
				if part.begins_with("town_name:"):
					t_name = part.substr(10)
				elif part.begins_with("town:"):
					t_name = part.substr(5)
				elif part.begins_with("act_id:"):
					act_id = part.substr(7)
				elif part.begins_with("revive_remain:"):
					revive_rem = float(part.substr(14))
		GameState.current_town_name = t_name
		GameState.current_location_act = act_id
		GameState.selected_act = act_id
		GameState.death_countdown_remain = revive_rem
		if current_map_label:
			current_map_label.text = "大地图休整 (%s)" % t_name
		if revive_rem > 0.0:
			show_toast("你身负重伤已被护送回大本营【%s】调息！" % t_name)
		else:
			show_toast("已安全脱离战场，返回大本营【%s】" % t_name)
		_end_death_state(true)
		var tree = get_tree()
		if tree and is_inside_tree():
			tree.change_scene_to_file("res://scenes/town/town_hub.tscn")

	# 13.2 LPC 角色阵亡救护回城帧 (player_death_revive: 仅非副本区域使用)
	elif type == "player_death_revive":
		_clear_battlefield()
		var msg = str(data.get("msg", "你在战斗中力竭倒地，已被修女与卫队救回营地大本营！")) if data is Dictionary else "你在战斗中力竭倒地，已被修女与卫队救回营地大本营！"
		show_toast(msg)
		var tree = get_tree()
		if tree and is_inside_tree():
			tree.create_timer(1.2).timeout.connect(func():
				if is_instance_valid(self) and is_inside_tree():
					_on_return_town_pressed()
			)

	# 13.3 挂机副本 10 秒倒地休整帧 (player_down: 纯图形灰度与大倒计时驱动，零冗余文本)
	elif type == "player_down":
		var revive_sec = 10.0
		if data is Dictionary and data.has("revive_time"):
			revive_sec = float(data["revive_time"])
		_start_death_state(revive_sec)
		if player_bottom_bar:
			var max_h = player_bottom_bar.max_hp if "max_hp" in player_bottom_bar else 100
			var max_m = player_bottom_bar.max_mp if "max_mp" in player_bottom_bar else 100
			player_bottom_bar.update_hp(0, max_h)
			player_bottom_bar.update_mp(0, max_m)
			player_bottom_bar.attack_timer = 0.0
			if player_bottom_bar.attack_progress_bar:
				player_bottom_bar.attack_progress_bar.value = 0.0

	# 13.4 挂机副本 10 秒倒地复苏帧 (player_revive: 满状态原地复活，平滑褪回全彩)
	elif type == "player_revive":
		_end_death_state()

	# 14. LPC 前端战斗全景快照帧 (gstatus: 由 ghp1 驱动)
	elif type == "gstatus" and data is Dictionary:
		_handle_gstatus_data(data)

	# 15. LPC 实时战斗打击帧 (combat: 由 d2_combatd 与 message_combatd 驱动)
	elif type == "combat" and data is Dictionary:
		_handle_combat_data(data)

	# 16. LPC 击杀掉落与战利品气泡帧 (reward_pop)
	elif type == "reward_pop" and data is Dictionary:
		_handle_reward_pop(data)

var _active_monsters: Array = []
var _current_target_id: String = ""
var _monster_instances: Dictionary = {} # mid (String) -> AFK_MonsterDisplay
var _occupied_slots: Dictionary = {}    # slot_idx (int) -> mid (String)
var _last_killed_slot: int = -1
var _last_killed_pos: Vector2 = Vector2.ZERO
var _killed_monster_positions: Dictionary = {} # mid (String) -> Vector2

# 连击弹道错峰状态: 同攻击者+技能 250ms 内的突发帧视为一次连击串，按序错开发射
var _last_skill_key: String = ""
var _last_volley_time: int = 0
var _last_victim_id: String = ""
var _volley_idx: int = 0

## 为新怪物随机动态分配空闲战场槽位 (Boss 居中，小怪随机且异位刷新)
func _allocate_slot_for_monster(rank: String) -> int:
	if rank == "boss":
		return -99 # Boss 独占居中王座
		
	var free_slots: Array = []
	for i in range(SLOT_POSITIONS.size()):
		if not _occupied_slots.has(i):
			free_slots.append(i)
			
	if free_slots.is_empty():
		return randi() % SLOT_POSITIONS.size()
		
	# 满足用户需求：“比如中间的死了，下一个刷到其他位置”
	# 如果有多个空闲槽位且包含刚刚击杀的槽位，优先排除刚刚死过的点位
	if free_slots.size() > 1 and _last_killed_slot in free_slots:
		free_slots.erase(_last_killed_slot)
		
	# 若当前处于组队状态 (左上角展开 Party HUD 队友卡片)，坚决避开被遮挡的 Slot 5 与 Slot 6
	if GameState.is_in_team or (party_hud_panel and party_hud_panel.visible):
		if free_slots.size() > 1 and 5 in free_slots:
			free_slots.erase(5)
		if free_slots.size() > 1 and 6 in free_slots:
			free_slots.erase(6)

	# 若当前场上存在 Boss（-99 被占），小怪避开正前中锋 Slot 2 与后排中央 Slot 7，留出开阔视野
	if _occupied_slots.has(-99):
		if free_slots.size() > 1 and 2 in free_slots:
			free_slots.erase(2)
		if free_slots.size() > 1 and 7 in free_slots:
			free_slots.erase(7)

	free_slots.shuffle()
	return free_slots[0]

## 应用归一化锚点坐标与强制物理像素坐标至怪物节点，自适应视口拉伸并按景深分层
func _apply_monster_slot_position(m_node: AFK_MonsterDisplay, slot_idx: int) -> void:
	var pos_ratio = BOSS_SLOT if slot_idx == -99 else SLOT_POSITIONS[slot_idx]
	m_node.anchor_left = pos_ratio.x
	m_node.anchor_right = pos_ratio.x
	m_node.anchor_top = pos_ratio.y
	m_node.anchor_bottom = pos_ratio.y
	m_node.offset_left = 0
	m_node.offset_right = 0
	m_node.offset_top = 0
	m_node.offset_bottom = 0
	
	# 双重保险：强制设置绝对物理像素坐标，彻底杜绝引擎未触发布局帧时的原点偏差与飞出屏幕
	var vp = left_viewport if left_viewport else get_node_or_null("MainHBox/LeftViewport")
	var vp_w = vp.size.x if (vp and vp.size.x > 10.0) else 986.0
	var vp_h = vp.size.y if (vp and vp.size.y > 10.0) else 720.0
	m_node.position = Vector2(vp_w * pos_ratio.x, vp_h * pos_ratio.y)
	
	# 动态 Z-Index 景深排序：限制在战场层 (10~20)，保证永远处于所有弹窗面板 (150+) 下方
	if slot_idx == -99:
		m_node.z_index = 15 # Boss 景深位
	else:
		m_node.z_index = 10 + int(pos_ratio.y * 10.0)

## 处理 LPC 前端全景战斗快照
func _handle_gstatus_data(data: Dictionary) -> void:
	# 0. 视觉顶级门禁：若大地图正打开着，彻底忽略怪群生成与战斗刷新，杜绝在途旧帧画出怪物
	if world_map and world_map.visible:
		_clear_battlefield()
		return

	# 0.1 玩家自身核心战斗生命与法力快照 (与 ghp1 心跳高频同步)
	var p = data.get("player", {})
	if p is Dictionary and not p.is_empty():
		var p_hp = _safe_int(p.get("hp"), 0)
		var p_max_hp = _safe_int(p.get("max_hp"), 1)
		var p_mp = _safe_int(p.get("mp"), 0)
		var p_max_mp = _safe_int(p.get("max_mp"), 1)
		var p_name = str(p.get("name", ""))
		if not p_name.is_empty():
			_my_player_name = p_name
		var p_lvl = _safe_int(p.get("level"), 1)
		var exp_cur = _safe_int(p.get("exp_cur"), -1)
		var exp_max = _safe_int(p.get("exp_max"), -1)
		var exp_pct = float(p.get("exp_pct", -1.0))
		if player_bottom_bar:
			if not p_name.is_empty():
				player_bottom_bar.update_player_info("Lv.%d %s" % [p_lvl, p_name])
			if p_max_hp > 0:
				player_bottom_bar.update_hp(p_hp, p_max_hp)
			if p_max_mp > 0:
				player_bottom_bar.update_mp(p_mp, p_max_mp)
			if exp_cur >= 0 and exp_max >= 0:
				player_bottom_bar.update_exp(exp_cur, exp_max, exp_pct)
			var revive_remain = _safe_int(p.get("revive_remain"), 0)
			if revive_remain > 0:
				player_bottom_bar.attack_timer = 0.0
				if player_bottom_bar.attack_progress_bar:
					player_bottom_bar.attack_progress_bar.value = 0.0
				if _death_countdown_timer <= 0.0:
					_start_death_state(float(revive_remain))
			elif _death_countdown_timer > 0.0 and p_hp > 0:
				_end_death_state()

		# 单人常驻个人卡片数据与 Buff 光环高频同步
		if party_hud_panel and is_instance_valid(party_hud_panel) and not GameState.is_in_team:
			var solo_data = {
				"id": str(p.get("id", GameState.get_my_character_id())),
				"name": p_name,
				"class": str(p.get("class", "ama")),
				"level": p_lvl,
				"hp": p_hp,
				"max_hp": p_max_hp,
				"power": str(p.get("power", "10")),
				"is_leader": true,
				"buffs": p.get("buffs", [])
			}
			if party_hud_panel.has_method("update_solo_card"):
				party_hud_panel.update_solo_card(solo_data)

		# 召唤仆从状态徽章展示 (复生骷髅、石魔等)
		_update_summons_display(data.get("summons", []))

	# 1. 关卡与 Boss 进度
	var st = data.get("stage", {})
	if st is Dictionary and not st.is_empty():
		var s_name = str(st.get("stage_name", ""))
		var s_id = _safe_int(st.get("stage_id"), -1)
		# 仅在关卡 ID 发生实际变更，或当前地图标签未初始化时才更新，避免高频战斗快照反复重绘
		if not s_name.is_empty() and current_map_label:
			if GameState.selected_stage_id != s_id or current_map_label.text.is_empty() or current_map_label.text == "烈风平原":
				_set_current_map_label(s_name)
				if s_id > 0:
					GameState.selected_stage_id = s_id

		var is_town = _safe_int(st.get("is_town"), 0) == 1 or s_name == "城镇安全区" or (_safe_int(st.get("stage_id"), -1) == 0)
		var threshold_val = _safe_int(st.get("threshold"), 0)

		if is_town:
			# 角色当前处于城镇安全区（例如阵亡被救回营地或主动回城）
			_clear_battlefield()
			if boss_progress_label:
				boss_progress_label.text = "🏕️ 【安全营地】休整备战中 (点击大地图出征)"
				boss_progress_label.remove_theme_color_override("font_color")
			if boss_progress_bar:
				boss_progress_bar.value = 0
			# 关键防护：大地图正处于打开展示中，绝对禁止自动返回主城
			if world_map and world_map.visible:
				return
			# 如果由于阵亡或重连留在战斗场景，提示并平滑切回主城大厅
			if not _is_returning_to_town:
				_is_returning_to_town = true
				show_toast("当前处于城镇安全区，正在返回大本营...")
				get_tree().create_timer(1.2).timeout.connect(func():
					if is_instance_valid(self) and _is_returning_to_town:
						_on_return_town_pressed(true)
				)
			return

		_is_returning_to_town = false
		current_boss_kills = _safe_int(st.get("kill_step"), 0)
		max_boss_kills = max(1, threshold_val if threshold_val > 0 else 100)
		var boss_active = _safe_int(st.get("boss_active"), 0)

		# Boss 降临特写呈现
		if boss_active == 1:
			if boss_progress_label:
				boss_progress_label.text = "👑 【领主降临】魔王大军已至，全员集火！"
				boss_progress_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
		else:
			_update_boss_ui()
			if boss_progress_label:
				boss_progress_label.remove_theme_color_override("font_color")

	# 2. 多点位怪群同屏渲染与异位出生管理
	var raw_m = data.get("monsters", [])
	_active_monsters = raw_m if raw_m is Array else []
	
	var incoming_ids: Array = []
	var parent_viewport = left_viewport if left_viewport else get_node_or_null("MainHBox/LeftViewport")
	
	for m in _active_monsters:
		if not m is Dictionary: continue
		var mid = str(m.get("id", ""))
		if mid.is_empty(): continue
		incoming_ids.append(mid)
		
		var m_rank = str(m.get("rank", "normal"))
		var m_node: AFK_MonsterDisplay = _monster_instances.get(mid, null)
		
		if m_node == null or not is_instance_valid(m_node):
			# 发现新怪物！统一通过 MonsterDisplayScene 动态创建独立实体，彻底杜绝复用污染
			m_node = MonsterDisplayScene.instantiate()
			if parent_viewport:
				parent_viewport.add_child(m_node)
					
			var slot_idx: int = -1
			if m_rank == "boss":
				slot_idx = -99
			elif m.has("slot") and m.get("slot") != null:
				slot_idx = _safe_int(m.get("slot"), -1)
			
			# 仅当服务端未提供有效槽位 (单机或离线兜底) 时才退化为本地分配
			if slot_idx == -1:
				slot_idx = _allocate_slot_for_monster(m_rank)

			m_node.slot_index = slot_idx
			if slot_idx != -99:
				_occupied_slots[slot_idx] = mid
				
			_apply_monster_slot_position(m_node, slot_idx)
			m_node.bind_monster_data(m)
			m_node.play_spawn_animation()
			
			if not m_node.target_clicked.is_connected(_on_monster_target_clicked):
				m_node.target_clicked.connect(_on_monster_target_clicked)
				
			_monster_instances[mid] = m_node
		else:
			# 存活怪物刷新血量与 Debuff 减益徽章状态 (实时同步伤害加深/衰老/降抗等减益)
			m_node.update_hp(_safe_int(m.get("hp")), _safe_int(m.get("max_hp")))
			var cur_dbs = m.get("debuffs", [])
			m_node.update_debuffs(cur_dbs if cur_dbs is Array else [])
			# 权威槽位对齐：若服务端指定了有效槽位且与当前不一致，即刻校准
			if m.has("slot") and m.get("slot") != null:
				var s_slot = _safe_int(m.get("slot"), -1)
				if s_slot != -1 and s_slot != m_node.slot_index:
					if _occupied_slots.has(m_node.slot_index) and _occupied_slots[m_node.slot_index] == mid:
						_occupied_slots.erase(m_node.slot_index)
					m_node.slot_index = s_slot
					if s_slot != -99:
						_occupied_slots[s_slot] = mid
					_apply_monster_slot_position(m_node, s_slot)
			
	# 清理服务端已移除的过期怪
	var to_clean: Array = []
	for mid in _monster_instances.keys():
		if not mid in incoming_ids:
			to_clean.append(mid)
	for mid in to_clean:
		var node = _monster_instances[mid]
		_monster_instances.erase(mid)
		if is_instance_valid(node):
			if _occupied_slots.has(node.slot_index):
				_occupied_slots.erase(node.slot_index)
			if monster_display == node:
				monster_display = get_node_or_null("%MonsterDisplay")
			node.queue_free()
				
	_update_target_focus()
	
	# 3. 队友同屏血量联动 (驱动左侧 Party HUD 常驻展示)
	var raw_team = data.get("team", [])
	if raw_team is Array:
		if raw_team.size() > 1:
			var t_leader = str(data.get("team_leader", ""))
			if t_leader.is_empty():
				for tm in raw_team:
					if tm is Dictionary and tm.get("is_leader") == 1:
						t_leader = str(tm.get("id", ""))
						break
			GameState.update_team_data(t_leader, raw_team)
			if party_hud_panel and party_hud_panel.has_method("update_party"):
				party_hud_panel.update_party(raw_team)
		elif raw_team.is_empty() and GameState.is_in_team:
			GameState.clear_team()
			if party_hud_panel and party_hud_panel.has_method("update_party"):
				party_hud_panel.update_party([])

## 智能集火目标更新 (Boss > 暗金 > 勇士 > 残血)
func _update_target_focus() -> void:
	var current_node = _monster_instances.get(_current_target_id, null)
	if current_node == null or not is_instance_valid(current_node) or current_node.cur_hp <= 0 or current_node.is_dying:
		_current_target_id = ""
		
	if _current_target_id.is_empty() and _active_monsters.size() > 0:
		var best_score = -999999
		var best_id = ""
		for m in _active_monsters:
			var mid = str(m.get("id", ""))
			var m_node = _monster_instances.get(mid, null)
			if m_node == null or not is_instance_valid(m_node) or m_node.is_dying: continue
			var hp = m_node.cur_hp
			var max_hp = max(1, m_node.max_hp)
			if hp <= 0: continue
			
			var rank = str(m.get("rank", "normal"))
			var k = str(m.get("mon_key", ""))
			var ratio = (hp * 100) / max_hp
			
			var score = 0
			if rank == "boss": score += 2000
			elif rank == "unique": score += 800
			elif rank == "champion": score += 400
			if "shaman" in k or "unraveler" in k: score += 600
			score += (100 - ratio) * 5
			
			if score > best_score:
				best_score = score
				best_id = mid
		_current_target_id = best_id
		
	# 刷新所有在场怪物节点的聚焦金色角标
	for mid in _monster_instances.keys():
		var node = _monster_instances[mid]
		if is_instance_valid(node):
			node.set_focused(mid == _current_target_id)
			
	# 向后兼容：确保 monster_display 句柄指向当前主集火目标 (若无目标安全回退预置节点)
	if not _current_target_id.is_empty() and _monster_instances.has(_current_target_id):
		var target_node = _monster_instances[_current_target_id]
		if is_instance_valid(target_node):
			monster_display = target_node
	else:
		var preset_display = get_node_or_null("%MonsterDisplay")
		if preset_display and is_instance_valid(preset_display):
			monster_display = preset_display

## 处理玩家点击任意怪物手动转火
func _on_monster_target_clicked(mid: String) -> void:
	if not mid.is_empty() and _monster_instances.has(mid):
		_current_target_id = mid
		_update_target_focus()

## 甄别指定实体是否为当前玩家角色 (支持匹配 ID、中文名、当前缓存名)
func _is_me(actor_id: String, actor_name: String = "") -> bool:
	if actor_id.is_empty() and actor_name.is_empty():
		return false
	var my_id = GameState.player_id
	if not my_id.is_empty() and (actor_id == my_id or actor_name == my_id):
		return true
	var char_id = str(GameState.selected_character.get("id", ""))
	if not char_id.is_empty() and (actor_id == char_id or actor_name == char_id):
		return true
	var char_name = str(GameState.selected_character.get("name", ""))
	if not char_name.is_empty() and (actor_id == char_name or actor_name == char_name):
		return true
	if not _my_player_name.is_empty() and (actor_id == _my_player_name or actor_name == _my_player_name):
		return true
	return false

## 处理 LPC 实时打击与伤害事件
func _handle_combat_data(data: Dictionary) -> void:
	# 0. 视觉门禁：若大地图全屏浮层正打开着，彻底屏蔽任何弹道发射与飘字动效
	if world_map and world_map.visible:
		return

	var atk_id = str(data.get("attacker", ""))
	var atk_name = str(data.get("attacker_name", ""))
	var vic_id = str(data.get("victim", ""))
	var vic_name = str(data.get("victim_name", ""))
	var vic_uuid = str(data.get("victim_uuid", ""))
	var dmg = _safe_int(data.get("dmg"), 0)
	var elem = str(data.get("elem", "物理"))
	var is_crit = (_safe_int(data.get("crit"), 0) == 1)
	var result = str(data.get("result", "hit"))
	var skill_code = str(data.get("skill_code", "attack"))
	var skill_name = str(data.get("skill", ""))
	var interval = _safe_float(data.get("interval"), -1.0)

	# 0. 严格甄别玩家身份，杜绝怪物法力污染玩家蓝球 (怪打玩家时 me_mp 是怪物的法力，绝不更新给玩家)
	var p_hp = -1
	var p_max_hp = -1
	var p_mp = -1
	var p_max_mp = -1

	var is_attacker_me = _is_me(atk_id, atk_name)
	var is_victim_me = _is_me(vic_id, vic_name)
	var is_minion = bool(data.get("is_minion", false)) or (_safe_int(data.get("is_minion"), 0) == 1)
	var is_proc = bool(data.get("is_proc", false)) or (_safe_int(data.get("is_proc"), 0) == 1) or (skill_code == "thunder_storm") or is_minion

	if is_attacker_me:
		# 玩家主动出手攻击：记录输出伤害，攻速条真实归零推进与周期同步
		if dmg > 0 and battle_statistics and is_instance_valid(battle_statistics):
			battle_statistics.record_damage_dealt(dmg)
		p_hp = _safe_int(data.get("me_hp"), -1)
		p_max_hp = _safe_int(data.get("me_max_hp"), -1)
		p_mp = _safe_int(data.get("me_mp"), -1)
		p_max_mp = _safe_int(data.get("me_max_mp"), -1)
		if player_bottom_bar and not is_proc and not is_minion:
			player_bottom_bar.trigger_attack(interval)
			# 主动技能施法起手：触发法力球翻涌与脉冲激荡
			var seq_num := _safe_int(data.get("seq"), 1)
			if seq_num <= 1 and skill_code != "attack" and not skill_name.is_empty() and skill_name != "普通攻击":
				player_bottom_bar.pulse_mp()
	elif is_victim_me:
		# 玩家受击：记录承受伤害
		if dmg > 0 and battle_statistics and is_instance_valid(battle_statistics):
			battle_statistics.record_damage_taken(dmg)
		p_hp = _safe_int(data.get("you_hp"), -1)
		p_max_hp = _safe_int(data.get("you_max_hp"), -1)
		p_mp = _safe_int(data.get("you_mp"), -1)
		p_max_mp = _safe_int(data.get("you_max_mp"), -1)

	if p_hp >= 0 and p_max_hp > 0:
		_update_player_hp(p_hp, p_max_hp)
	if player_bottom_bar and p_mp >= 0 and p_max_mp > 0:
		player_bottom_bar.update_mp(p_mp, p_max_mp)

	# 0.5 怪物主动出手攻击：触发攻击者怪物技能条真实归零推进与技能名/元素显示
	var atk_node = null
	if not is_attacker_me:
		atk_node = _find_monster_node(atk_id, str(data.get("attacker_uuid", "")))
		if atk_node and is_instance_valid(atk_node):
			atk_node.trigger_attack(interval, skill_name, elem)

	# 1. 连击弹道错峰 + 连锁蔓延起点解析 (接收时刻快照，错峰延迟后坐标仍准)
	#    服务端 effect/seq/from 字段优先: combo=seq×110ms 连珠串, chain=seq×80ms 逐段从上一跳蔓延;
	#    全局客观判定: 无论是自己还是组队队友打出的连击/连锁技能，均按权威字段错峰发射，保持连环打击视觉;
	#    旧帧无字段时启发式: 同源同技 250ms 突发 → 同目标连续=连击错峰, 闪电系=从上一跳受害者起弧
	#    (AoE 异目标不受影响: 不错峰、从玩家/队友卡片齐射)
	var launch_delay := 0.0
	var chain_from := ""
	var fx_effect := str(data.get("effect", ""))
	var fx_seq := _safe_int(data.get("seq"), 1)
	if fx_effect == "combo" and fx_seq > 1:
		launch_delay = float(fx_seq - 1) * 0.11
	elif fx_effect == "chain" and fx_seq > 1:
		launch_delay = float(fx_seq - 1) * 0.08
		chain_from = str(data.get("from", ""))
	elif is_attacker_me:
		var now_ms := Time.get_ticks_msec()
		var skill_key: String = atk_id + "|" + skill_code
		var same_skill := now_ms - _last_volley_time < 250 and skill_key == _last_skill_key
		if same_skill and vic_id == _last_victim_id:
			_volley_idx += 1
		else:
			_volley_idx = 0
		# 连锁家族 (闪电/链) 启发式: 突发内后续帧从上一跳受害者身上起弧蔓延
		if same_skill and _is_chain_visual_skill(skill_code, elem):
			chain_from = _last_victim_id
		_last_skill_key = skill_key
		_last_volley_time = now_ms
		_last_victim_id = vic_id
		if _volley_idx > 0:
			launch_delay = float(_volley_idx) * 0.11
	launch_delay = min(launch_delay, 0.7)

	# 多段连击保护：设置该怪物处于连击弹道飞行的保护窗口时间戳，防止 charhp 提前跑满剧透导致血条倒流跳动
	var target_mon = _find_monster_node(vic_id, vic_uuid)
	if target_mon and is_instance_valid(target_mon):
		var combo_guard_ms = 0
		if launch_delay > 0.001:
			combo_guard_ms = Time.get_ticks_msec() + int(launch_delay * 1000.0) + 450
		elif fx_effect == "combo" or _safe_int(data.get("total"), 1) > 1:
			var est_total = _safe_int(data.get("total"), 2)
			combo_guard_ms = Time.get_ticks_msec() + int((est_total - 1) * 110.0) + 450
		if combo_guard_ms > int(target_mon.get_meta("in_combo_until", 0)):
			target_mon.set_meta("in_combo_until", combo_guard_ms)

	if launch_delay <= 0.001:
		_launch_combat_fx(vic_id, vic_uuid, atk_id, str(data.get("attacker_uuid", "")), skill_code, elem, is_crit, is_attacker_me, is_victim_me, result, dmg, data, chain_from)
	else:
		var fx_tw = create_tween().bind_node(self)
		fx_tw.tween_interval(launch_delay)
		fx_tw.tween_callback(_launch_combat_fx.bind(vic_id, vic_uuid, atk_id, str(data.get("attacker_uuid", "")), skill_code, elem, is_crit, is_attacker_me, is_victim_me, result, dmg, data, chain_from))

## 连锁视觉家族判定 (闪电/链系技能: 弧线应从目标身上蔓延而非玩家齐射)
func _is_chain_visual_skill(skill_code: String, elem: String) -> bool:
	var sk := skill_code.to_lower()
	return "lightning" in sk or "chain" in sk or "电" in elem or "light" in elem.to_lower()

## 弹道发射器：计算起点/终点并触发投射物 (错峰延迟后在发射时刻重算坐标，目标移动/阵亡仍准确)
## chain_from 非空 = 连锁蔓延帧: 弧线起点锚定上一跳受害者 (活怪查节点，阵亡回落死亡坐标)
func _launch_combat_fx(
	vic_id: String,
	vic_uuid: String,
	atk_id: String,
	atk_uuid: String,
	skill_code: String,
	elem: String,
	is_crit: bool,
	is_attacker_me: bool,
	is_victim_me: bool,
	result: String,
	dmg: int,
	data: Dictionary,
	chain_from: String
) -> void:
	if world_map and world_map.visible:
		return

	# 1. 寻找受击怪物用于确定弹道目标点
	var hit_node = _find_monster_node(vic_id, vic_uuid)

	# 2. 计算弹道起点与目标点
	var player_pos = Vector2.ZERO
	if player_bottom_bar and is_instance_valid(player_bottom_bar):
		player_pos = player_bottom_bar.global_position + Vector2(player_bottom_bar.size.x * 0.5, 10.0)
	else:
		player_pos = get_viewport_rect().size * Vector2(0.5, 0.85)

	var start_pos = player_pos
	var target_pos = player_pos
	var is_friendly_attacker: bool = is_attacker_me

	var is_minion_fx = bool(data.get("is_minion", false)) or (_safe_int(data.get("is_minion"), 0) == 1)
	if is_attacker_me:
		if is_minion_fx:
			# 随从军团攻击：攻击直接在目标怪物周围就近挥砍/打击，绝不锚定玩家本体，杜绝玩家冒光假象
			if hit_node and is_instance_valid(hit_node):
				target_pos = hit_node.global_position
			else:
				target_pos = _killed_monster_positions.get(vic_id, get_viewport_rect().size * Vector2(0.5, 0.45))
			start_pos = target_pos + Vector2(randf_range(-20.0, 20.0), randf_range(15.0, 25.0))
		else:
			start_pos = player_pos
			# 连锁蔓延: 起弧锚定上一跳受害者 (而非玩家)，形成 怪→怪 蔓延视觉
			if not chain_from.is_empty():
				var from_node = _find_monster_node(chain_from, "")
				if from_node and is_instance_valid(from_node):
					start_pos = from_node.global_position
				elif _killed_monster_positions.has(chain_from):
					start_pos = _killed_monster_positions[chain_from]
			if hit_node and is_instance_valid(hit_node):
				target_pos = hit_node.global_position
			else:
				target_pos = _killed_monster_positions.get(vic_id, get_viewport_rect().size * Vector2(0.5, 0.45))
	else:
		# 优先判定攻击者是否为组队队友 (从左上角队友卡片发射)
		var teammate_card_pos = Vector2.ZERO
		if party_hud_panel and is_instance_valid(party_hud_panel) and party_hud_panel.has_method("get_member_card_anchor_pos"):
			teammate_card_pos = party_hud_panel.get_member_card_anchor_pos(atk_id)
		
		if teammate_card_pos != Vector2.ZERO:
			if not chain_from.is_empty():
				var from_node = _find_monster_node(chain_from, "")
				if from_node and is_instance_valid(from_node):
					start_pos = from_node.global_position
				elif _killed_monster_positions.has(chain_from):
					start_pos = _killed_monster_positions[chain_from]
				else:
					start_pos = teammate_card_pos
			else:
				start_pos = teammate_card_pos
			is_friendly_attacker = true
			if hit_node and is_instance_valid(hit_node):
				target_pos = hit_node.global_position
			else:
				target_pos = _killed_monster_positions.get(vic_id, get_viewport_rect().size * Vector2(0.5, 0.45))
		else:
			# 怪物攻击玩家或其它实体
			var atk_node = _find_monster_node(atk_id, atk_uuid)
			if atk_node and is_instance_valid(atk_node):
				start_pos = atk_node.global_position
			else:
				start_pos = get_viewport_rect().size * Vector2(0.5, 0.45)
			
			# 判定受击目标：若受害者是队友，目标点锚定受害队友的卡片
			var victim_card_pos = Vector2.ZERO
			if party_hud_panel and is_instance_valid(party_hud_panel) and party_hud_panel.has_method("get_member_card_anchor_pos"):
				victim_card_pos = party_hud_panel.get_member_card_anchor_pos(vic_id)
			
			if is_victim_me:
				target_pos = player_pos
			elif victim_card_pos != Vector2.ZERO:
				target_pos = victim_card_pos
			elif hit_node and is_instance_valid(hit_node):
				target_pos = hit_node.global_position
			else:
				target_pos = player_pos

	# 3. 封装受击核心结算回调 (Method Callable.bind: 杜绝 Lambda 闭包捕获 Node 导致已释放报错)
	var apply_hit_action = _apply_combat_hit.bind(vic_id, vic_uuid, result, elem, dmg, is_crit, data, is_attacker_me)

	# 4. 触发轻量弹道视觉效果并在飞抵瞬间触发打击结算 (区分玩家与怪物弹道分流，支持数量与形态)
	if fx_manager and is_instance_valid(fx_manager):
		var fx_count = _safe_int(data.get("count"), 1)
		var fx_type = str(data.get("fx_type", ""))
		fx_manager.play_combat_fx(start_pos, target_pos, skill_code, elem, apply_hit_action, is_crit, is_friendly_attacker, fx_count, fx_type)
	else:
		apply_hit_action.call()

## 封装受击核心结算逻辑 (飘字 + 受击硬直 + 扣血 + 死亡消散)
func _apply_combat_hit(
	vic_id: String,
	vic_uuid: String,
	result: String,
	elem: String,
	dmg: int,
	is_crit: bool,
	data: Dictionary,
	is_attacker_me: bool = true
) -> void:
	if not is_instance_valid(self): return
	var hit_node = _find_monster_node(vic_id, vic_uuid)
	if hit_node and is_instance_valid(hit_node) and hit_node.visible:
		# 飘字与受击动效 (透传 is_attacker_me: 自身大字高光 vs 队友小字半透)
		if result == "miss":
			hit_node.spawn_damage(0, elem, false, false, is_attacker_me)
		elif result == "dodge":
			hit_node.spawn_damage(-1, elem, false, false, is_attacker_me)
		elif result == "block":
			hit_node.spawn_damage(-2, elem, false, false, is_attacker_me)
			if fx_manager and is_instance_valid(fx_manager):
				fx_manager.play_shield_block(hit_node.global_position)
		else:
			hit_node.spawn_damage(dmg, elem, is_crit, false, is_attacker_me)
			hit_node.play_hit_reaction(is_crit, elem)
			
		# 服务端权威生命值对齐 (Authoritative Server First):
		# 1. 服务端下发了权威受击者生命快照 you_hp (vic_hp):
		#    - 若 vic_hp == 0: 服务端权威判定斩杀，立即执行致死归零流程
		#    - 若 vic_hp > 0: 服务端权威判定存活，血量严格对齐 vic_hp (支持回血/格挡减免/多段判定)，绝不越权假死！
		# 2. 仅在服务端未提供 you_hp (离线/单机降级) 时，才以本地步进扣除 step_hp
		var has_vic_hp: bool = data.has("you_hp")
		var raw_vic_hp: int = _safe_int(data.get("you_hp"), 0) if has_vic_hp else hit_node.cur_hp
		var vic_hp = max(0, raw_vic_hp)
		var vic_max_hp = _safe_int(data.get("you_max_hp"), -1)
		
		var target_hp: int = hit_node.cur_hp
		if has_vic_hp:
			if vic_hp == 0:
				target_hp = 0
			else:
				# 服务端明确存活！即便单次伤害数值大于怪物当前血量，也绝对采纳服务端存活事实
				target_hp = max(1, vic_hp)
		else:
			# 离线或无服务端血量兜底步进
			if dmg > 0 and hit_node.cur_hp > 0:
				target_hp = max(0, hit_node.cur_hp - dmg)
			else:
				target_hp = hit_node.cur_hp
		
		# 关键防护：防止跨阶级血量篡改 (严禁将 Boss 级巨额血量覆盖给普通小怪)
		if vic_max_hp > 0:
			if hit_node.cur_rank == "normal" and vic_max_hp > hit_node.max_hp * 3 and hit_node.max_hp < 1000:
				var safe_cur = int(float(target_hp) * float(hit_node.max_hp) / float(vic_max_hp)) if vic_max_hp > 0 else target_hp
				if target_hp > 0 and safe_cur < 1:
					safe_cur = 1
				hit_node.update_hp(safe_cur, hit_node.max_hp)
			else:
				hit_node.update_hp(target_hp, vic_max_hp)
		else:
			hit_node.update_hp(target_hp)
		
		# 核心致死判定：血量归零即刻触发该点位怪物就地死亡消散，并记录绝对屏幕物理坐标！
		if target_hp <= 0 and not hit_node.is_dying:
			if battle_statistics and is_instance_valid(battle_statistics):
				battle_statistics.record_kill(1)
			var dead_mid = hit_node.cur_id
			var dead_slot = hit_node.slot_index
			var dead_screen_pos = hit_node.global_position
			_last_killed_slot = dead_slot
			_last_killed_pos = dead_screen_pos
			_killed_monster_positions[dead_mid] = dead_screen_pos
			# 关键防重叠设计：死亡渐隐动效播完前严格保持槽位锁定，动效完成后才归还槽位与清理实例
			hit_node.play_death_animation(_on_monster_death_completed.bind(dead_mid, dead_slot))
			
			# 若阵亡的是当前主目标，0 延迟平滑转火下一只存活怪
			if dead_mid == _current_target_id:
				_current_target_id = ""
				_update_target_focus()
				
			if NetworkClient.is_connected:
				NetworkClient.send_raw("ghp1")
			
	elif not _is_user_or_team_member(vic_id) and not _monster_instances.is_empty():
		# AoE 弧线飘字：仅在当前存活目标有效时播放
		if dmg > 0:
			var any_node = _monster_instances.get(_current_target_id, null)
			if any_node and is_instance_valid(any_node) and not any_node.is_dying:
				any_node.spawn_damage(dmg, elem, is_crit, true, is_attacker_me)

func _on_monster_death_completed(dead_mid: String, dead_slot: int) -> void:
	if not is_instance_valid(self): return
	if _occupied_slots.has(dead_slot):
		_occupied_slots.erase(dead_slot)
	var node = _monster_instances.get(dead_mid, null)
	_monster_instances.erase(dead_mid)
	if node and is_instance_valid(node):
		if monster_display == node:
			monster_display = get_node_or_null("%MonsterDisplay")
		node.queue_free()

## 0 延迟即刻平滑切向下一个存活目标
func _switch_to_next_target(dead_id: String) -> void:
	if dead_id == _current_target_id:
		_current_target_id = ""
	_update_target_focus()

func _is_user_or_team_member(id_str: String) -> bool:
	if id_str.is_empty(): return false
	if GameState.player_id == id_str: return true
	for m in GameState.current_team_members:
		if str(m.get("id")) == id_str or str(m.get("char_id")) == id_str:
			return true
	return false

## 处理战利品与掉落奖励 (纯增量即刻入包，并在击杀怪物尸体原位冉冉升起掉落提示)
func _handle_reward_pop(data: Dictionary) -> void:
	var gold = _safe_int(data.get("gold"), 0)
	var exp_val = _safe_int(data.get("exp"), 0)
	if exp_val > 0 and battle_statistics and is_instance_valid(battle_statistics):
		battle_statistics.record_exp(exp_val)
	var it = data.get("item")
	var mon_name = str(data.get("monster_name", ""))
	var mon_id = str(data.get("monster_id", ""))

	# 精准锁定该击杀怪物的屏幕物理坐标
	var spawn_pos = Vector2.ZERO
	if not mon_id.is_empty() and _killed_monster_positions.has(mon_id):
		spawn_pos = _killed_monster_positions[mon_id]
	elif not mon_id.is_empty() and _monster_instances.has(mon_id):
		var m_inst = _monster_instances[mon_id]
		if is_instance_valid(m_inst):
			spawn_pos = m_inst.global_position
	elif _last_killed_pos != Vector2.ZERO:
		spawn_pos = _last_killed_pos
	
	if it is Dictionary and not it.is_empty():
		# 1. 核心重磅事件：掉落装备！
		var iname = str(it.get("raw_name", it.get("name", "神秘战利品")))
		var clean_name = AnsiHelper.to_plain_text(iname)
		var qual = str(it.get("quality", "normal")).to_lower()
		var col_hex = "#ffffff"
		match qual:
			"unique": col_hex = "#a59263"
			"set": col_hex = "#00aa00"
			"rare": col_hex = "#ffff64"
			"magic": col_hex = "#4850b8"
			"crafted": col_hex = "#ff8000"
			_: col_hex = "#d8d8d8"

		# (1) 纯增量落入背包槽位
		if inventory_panel and inventory_panel.has_method("add_incremental_reward"):
			inventory_panel.add_incremental_reward(it, gold)

		# (1.1) 触发客户端细则分解防抖检查与即刻拦截
		if has_node("/root/CustomSalvageManager"):
			var csm = get_node("/root/CustomSalvageManager")
			if csm:
				if csm.has_method("handle_loot_dropped"):
					csm.handle_loot_dropped(it)
				elif csm.has_method("notify_loot_dropped"):
					csm.notify_loot_dropped()

		# (2) 战利品横幅弹出完全交由服务端权威裁决 (如暗金或未来高阶符文)
		var allow_banner = bool(it.get("show_banner", false)) or bool(data.get("show_banner", false))
		if allow_banner:
			_show_loot_banner(it, mon_name, gold, exp_val, col_hex)

		# (2.1) 击杀怪物精准落位于脚下地表，呼吸晃动 2.2s，随后化作流光小箭头直射背包 (避让原位刷新出的新怪)
		var drop_pos = spawn_pos
		if drop_pos == Vector2.ZERO:
			drop_pos = Vector2(size.x * 0.45, size.y * 0.58)
		else:
			drop_pos += Vector2(0.0, 75.0) # 精准落位于怪物脚下地表
		_spawn_loot_drop_fx(it, drop_pos, col_hex)

		# (3) 永久追加至系统战斗信息流中，挂机亦可随时翻阅
		var chat_bb = "[color=#ffd700]★ 击杀【%s】掉落了：[/color][color=%s]【%s】[/color]" % [mon_name if not mon_name.is_empty() else "怪物", col_hex, clean_name]
		if gold > 0: chat_bb += "[color=#e6c66e] (金币+%d)[/color]" % gold
		if exp_val > 0: chat_bb += "[color=#66bbff] (经验+%d)[/color]" % exp_val
		GameState.add_chat_message(chat_bb, "★ 击杀战利品: %s" % clean_name)

	elif gold > 0 or exp_val > 0:
		# 2. 轻量普通收益：纯金币与经验 (在被击杀怪物身上原地升起消散)
		if gold > 0 and inventory_panel and inventory_panel.has_method("update_gold"):
			inventory_panel.update_gold(inventory_panel.current_player_gold + gold)
		_show_minor_reward_toast(gold, exp_val, mon_name, spawn_pos)

## 挂机战斗主场景中的公频与文本分流处理器
func _process_chat_text(text: String) -> void:
	var clean = AnsiHelper.to_plain_text(text).strip_edges()
	if clean.is_empty(): return
	
	if "『闲聊』" in clean or "闲聊" in clean:
		var raw_replaced = text.replace("闲聊", "世界")
		var bb = AnsiHelper.to_bbcode(raw_replaced)
		GameState.add_chat_message(bb, clean.replace("闲聊", "世界"))
	elif "『交易』" in clean or "【队伍】" in clean or "『队伍』" in clean or "『" in clean or "【" in clean or "说：" in clean:
		var bb = AnsiHelper.to_bbcode(text)
		GameState.add_chat_message(bb, clean)
	elif "加入队伍" in clean or "解散队伍" in clean or "组队" in clean:
		GameState.add_chat_message("[color=#ffd700]" + clean + "[/color]", clean)
		show_toast(clean)

## 点击公频聊天中装备超链接，弹出装备悬浮面板
func _on_chat_item_inspected(file_id: String) -> void:
	if item_tooltip:
		var mouse_pos = get_viewport().get_mouse_position()
		item_tooltip.show_item({ "file_id": file_id, "cmd": "glookitem " + file_id }, mouse_pos)
	if NetworkClient.is_connected:
		NetworkClient.send_raw("glookitem " + file_id)

var _toast_label: Label = null
var _loot_banner: PanelContainer = null
var _minor_reward_label: Label = null
var _loot_tween: Tween = null
var _minor_tween: Tween = null

## 专属战利品高亮横幅 (带装备图标、品质配色、3秒驻留，杜绝被金币冲刷)
func _show_loot_banner(it: Dictionary, mon_name: String, gold: int, exp_val: int, col_hex: String) -> void:
	var iname = str(it.get("raw_name", it.get("name", "神秘战利品")))
	var clean_name = AnsiHelper.to_plain_text(iname)
	var icon_path = str(it.get("icon", ""))
	
	if not _loot_banner:
		_loot_banner = PanelContainer.new()
		_loot_banner.z_index = 30
		_loot_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.09, 0.95)
		style.set_content_margin_all(10.0)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.85, 0.75, 0.35, 1.0)
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_size = 6
		_loot_banner.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.name = "HBox"
		hbox.add_theme_constant_override("separation", 10)
		_loot_banner.add_child(hbox)
		
		var icon_rect = TextureRect.new()
		icon_rect.name = "LootIcon"
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon_rect)
		
		var vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)
		
		var title_label = Label.new()
		title_label.name = "LootTitle"
		title_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(title_label)
		
		var sub_label = Label.new()
		sub_label.name = "LootSub"
		sub_label.add_theme_font_size_override("font_size", 12)
		sub_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
		vbox.add_child(sub_label)
		
		add_child(_loot_banner)

	# 装填战利品信息
	var hbox = _loot_banner.get_node("HBox")
	var icon_rect = hbox.get_node("LootIcon") as TextureRect
	var title_label = hbox.get_node("VBox/LootTitle") as Label
	var sub_label = hbox.get_node("VBox/LootSub") as Label
	
	var tex = AnsiHelper.load_item_texture(icon_path) if not icon_path.is_empty() else null
	if tex:
		icon_rect.texture = tex
		icon_rect.visible = true
	else:
		icon_rect.visible = false
		
	title_label.text = "★ 战利品掉落：%s" % clean_name
	title_label.add_theme_color_override("font_color", Color.from_string(col_hex, Color.GOLD))
	
	var sub_parts = []
	if not mon_name.is_empty():
		sub_parts.append("击杀: %s" % mon_name)
	if gold > 0:
		sub_parts.append("金币 +%d" % gold)
	if exp_val > 0:
		sub_parts.append("经验 +%d" % exp_val)
	sub_label.text = " | ".join(sub_parts)
	
	_loot_banner.reset_size()
	_loot_banner.position = Vector2((size.x - _loot_banner.size.x) / 2.0, size.y * 0.22)
	_loot_banner.visible = true
	
	if _loot_tween and _loot_tween.is_valid():
		_loot_tween.kill()
	_loot_tween = create_tween().bind_node(_loot_banner)
	_loot_banner.modulate.a = 0.0
	_loot_banner.scale = Vector2(0.9, 0.9)
	_loot_tween.tween_property(_loot_banner, "modulate:a", 1.0, 0.15)
	_loot_tween.parallel().tween_property(_loot_banner, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_loot_tween.tween_interval(2.8) # 充足驻留 2.8 秒
	_loot_tween.tween_property(_loot_banner, "modulate:a", 0.0, 0.35)
	_loot_tween.tween_callback(_hide_loot_banner)

func _hide_loot_banner() -> void:
	if is_instance_valid(_loot_banner):
		_loot_banner.visible = false

## 击杀现场掉落浮字 (金币/经验在被击杀怪物身上原地升起消散)
func _show_minor_reward_toast(gold: int, exp_val: int, mon_name: String, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	var lbl = Label.new()
	_minor_reward_label = lbl
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0)) # 纯正暗黑金
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.z_index = 25
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	var text = ""
	if gold > 0 and exp_val > 0:
		text = "+%d G   +%d EXP" % [gold, exp_val]
	elif gold > 0:
		text = "+%d G" % gold
	elif exp_val > 0:
		text = "+%d EXP" % exp_val
		
	lbl.text = text
	lbl.reset_size()

	var start_pos = spawn_pos + Vector2(-lbl.size.x / 2.0, -40.0) if spawn_pos != Vector2.ZERO else Vector2((size.x - lbl.size.x) / 2.0, size.y * 0.76)
	lbl.position = start_pos
	lbl.modulate.a = 1.0

	var tw = create_tween().bind_node(lbl)
	tw.tween_property(lbl, "position:y", start_pos.y - 45.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tw.tween_callback(lbl.queue_free)

## 触发战利品掉落呼吸晃动 1.0s 与流光小箭头入包动效
func _spawn_loot_drop_fx(it: Dictionary, spawn_pos: Vector2, col_hex: String) -> void:
	var target_pos = _get_bag_target_pos()
	var fx = LootDropFxScript.new()
	add_child(fx)
	fx.setup(it, spawn_pos, target_pos, col_hex, Callable(self, "_on_loot_reach_bag"))

## 获取背包入口屏幕物理坐标
func _get_bag_target_pos() -> Vector2:
	if inventory_panel and is_instance_valid(inventory_panel) and inventory_panel.is_visible_in_tree():
		return inventory_panel.global_position + Vector2(40.0, 100.0)
	return Vector2(size.x - 60.0, size.y * 0.4)

## 战利品流光小箭头击中背包入口反馈 (微震呼吸)
func _on_loot_reach_bag() -> void:
	if inventory_panel and is_instance_valid(inventory_panel):
		var tw = create_tween().bind_node(inventory_panel)
		tw.tween_property(inventory_panel, "scale", Vector2(1.02, 1.02), 0.08).set_trans(Tween.TRANS_SINE)
		tw.tween_property(inventory_panel, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)

## 击杀现场战利品名称浮字 (品质色彩在尸体处冉冉升起)
func _show_ground_item_toast(item_name: String, col_hex: String, spawn_pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.from_string(col_hex, Color.WHITE))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.z_index = 26
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	lbl.text = "★ " + item_name
	lbl.reset_size()
	var start_pos = spawn_pos + Vector2(-lbl.size.x / 2.0, -70.0)
	lbl.position = start_pos
	lbl.modulate.a = 1.0

	var tw = create_tween().bind_node(lbl)
	tw.tween_property(lbl, "position:y", start_pos.y - 50.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_callback(lbl.queue_free)

func show_toast(msg: String) -> void:
	var clean = AnsiHelper.to_plain_text(msg).strip_edges()
	if clean.is_empty():
		return
	if not _toast_label:
		_toast_label = Label.new()
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_size_override("font_size", 16)
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_toast_label.add_theme_constant_override("shadow_offset_x", 1)
		_toast_label.add_theme_constant_override("shadow_offset_y", 1)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
		style.set_content_margin_all(8.0)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.6, 0.5, 0.2, 0.8)
		_toast_label.add_theme_stylebox_override("normal", style)
		_toast_label.z_index = 350
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast_label)

	_toast_label.text = clean
	_toast_label.reset_size()
	_toast_label.position = Vector2((size.x - _toast_label.size.x) / 2.0, size.y * 0.35)
	_toast_label.modulate.a = 0.0
	_toast_label.visible = true

	var tween = create_tween().bind_node(_toast_label)
	tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.8)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_hide_toast_label)

func _hide_toast_label() -> void:
	if is_instance_valid(_toast_label):
		_toast_label.visible = false

func _on_network_text(text: String) -> void:
	if "不足" in text or "无法装备" in text or "拿不动" in text or "专属装备" in text or "你装备了" in text or "你脱下了" in text:
		show_toast(text)


func _setup_toggle_button_style() -> void:
	if not btn_toggle_sidebar:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_right = 0
	style.border_color = Color(0.35, 0.3, 0.2, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	btn_toggle_sidebar.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.border_color = Color(0.9, 0.8, 0.3, 1.0)
	hover.bg_color = Color(0.14, 0.14, 0.16, 0.98)
	btn_toggle_sidebar.add_theme_stylebox_override("hover", hover)
	btn_toggle_sidebar.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))

func toggle_sidebar() -> void:
	set_sidebar_expanded(not is_sidebar_expanded)

func set_sidebar_expanded(expand: bool) -> void:
	is_sidebar_expanded = expand
	if right_sidebar:
		right_sidebar.visible = is_sidebar_expanded
		
	# 如果折叠收起，同时隐藏小口袋与悬浮窗
	if not is_sidebar_expanded:
		if inventory_panel and inventory_panel.little_pocket_panel:
			inventory_panel.little_pocket_panel.hide()
		if item_tooltip:
			item_tooltip.hide_tooltip()

	_update_toggle_button_position()
	# 魔盒与商店浮窗跟随侧栏开合重新贴位
	if cube_panel and cube_panel.visible:
		_position_cube_panel()
	if gshop_panel and gshop_panel.visible:
		_position_gshop_panel()

func _update_toggle_button_position() -> void:
	if not btn_toggle_sidebar:
		return
	if is_sidebar_expanded:
		btn_toggle_sidebar.text = "▶"
		btn_toggle_sidebar.offset_left = -320.0
		btn_toggle_sidebar.offset_right = -304.0
	else:
		btn_toggle_sidebar.text = "◀"
		btn_toggle_sidebar.offset_left = -16.0
		btn_toggle_sidebar.offset_right = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# 1. 焦点阻断：当玩家在聊天输入框打字时，彻底屏蔽所有挂机游戏操作快捷键
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			focus_owner.release_focus()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		# 支持 Alt+Q 一键折叠/展开右侧边栏
		if event.keycode == KEY_C and not event.echo:
			get_viewport().set_input_as_handled()
			toggle_character_info()
		elif event.keycode == KEY_P and not event.echo:
			get_viewport().set_input_as_handled()
			toggle_pickup_setting()
		elif event.keycode == KEY_A and not event.echo:
			get_viewport().set_input_as_handled()
			toggle_hook_setting()
		elif event.keycode == KEY_T and not event.echo:
			get_viewport().set_input_as_handled()
			toggle_skill_panel()
		elif event.alt_pressed and event.keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			toggle_sidebar()


func toggle_character_info() -> void:
	if not char_info_panel:
		return
	if char_info_panel.visible:
		char_info_panel.close()
	else:
		# 单窗口互斥: 关魔盒、随身商店与技能面板、工坊与小口袋
		if skill_panel and skill_panel.visible:
			skill_panel.close()
		if cube_panel and cube_panel.visible:
			cube_panel.visible = false
		if gshop_panel and gshop_panel.visible:
			gshop_panel.close()
		if inventory_panel:
			if inventory_panel.socketing_workbench_panel:
				inventory_panel.socketing_workbench_panel.close()
			if inventory_panel.little_pocket_panel:
				inventory_panel.little_pocket_panel.hide()
		item_tooltip.hide_tooltip()
		char_info_panel.open()

func toggle_skill_panel() -> void:
	if not skill_panel:
		return
	if skill_panel.visible:
		skill_panel.close()
	else:
		# 单窗口互斥
		if char_info_panel and char_info_panel.visible:
			char_info_panel.close()
		if cube_panel and cube_panel.visible:
			cube_panel.visible = false
		if gshop_panel and gshop_panel.visible:
			gshop_panel.close()
		if pickup_setting_panel and pickup_setting_panel.visible:
			pickup_setting_panel.hide()
		if inventory_panel:
			if inventory_panel.socketing_workbench_panel:
				inventory_panel.socketing_workbench_panel.close()
			if inventory_panel.little_pocket_panel:
				inventory_panel.little_pocket_panel.hide()
		item_tooltip.hide_tooltip()
		if NetworkClient.is_connected:
			NetworkClient.send_raw("gskills")
		else:
			skill_panel.open()

# 魔盒开合: 挂机战斗区禁止使用，友好飘字引导回营
func toggle_cube_panel() -> void:
	show_toast("战斗区域无法使用合成魔盒，请返回营地安全区操作")
	return

func _position_cube_panel() -> void:
	if cube_panel == null or not cube_panel.visible:
		return
	# 侧栏展开时让开侧栏宽度 (约 320px), 折叠时贴屏幕右缘
	var right_margin := 336.0 if is_sidebar_expanded else 16.0
	var x := size.x - right_margin - cube_panel.size.x
	var y := (size.y - cube_panel.size.y) * 0.5
	cube_panel.position = Vector2(max(10.0, x), max(10.0, y))

# 镶嵌打孔(工坊)开合: 挂机战斗区禁止使用，友好飘字引导回营
func toggle_workbench() -> void:
	show_toast("战斗区域无法进行镶嵌打孔，请返回营地安全区操作")
	return

# 随身补给商店开合: 单窗口互斥 (关纸娃娃/技能/魔盒/工坊/小口袋), 打开时拉取服务端实时状态帧, 位置贴右侧栏
func toggle_gshop_panel() -> void:
	if gshop_panel == null:
		return
	if gshop_panel.visible:
		gshop_panel.close()
		item_tooltip.hide_tooltip()
	else:
		# 若侧栏处于收起状态，自动展开以支持即时整装
		if not is_sidebar_expanded:
			set_sidebar_expanded(true)
		# 单窗口互斥
		if char_info_panel and char_info_panel.visible:
			char_info_panel.close()
		if skill_panel and skill_panel.visible:
			skill_panel.close()
		if cube_panel and cube_panel.visible:
			cube_panel.visible = false
		if pickup_setting_panel and pickup_setting_panel.visible:
			pickup_setting_panel.hide()
		if inventory_panel:
			if inventory_panel.socketing_workbench_panel:
				inventory_panel.socketing_workbench_panel.close()
			if inventory_panel.little_pocket_panel:
				inventory_panel.little_pocket_panel.hide()
		item_tooltip.hide_tooltip()
		gshop_panel.open()
		await get_tree().process_frame
		_position_gshop_panel()

func _position_gshop_panel() -> void:
	if gshop_panel == null or not gshop_panel.visible:
		return
	var right_margin: float = 336.0 if is_sidebar_expanded else 16.0
	var x: float = float(size.x) - right_margin - float(gshop_panel.size.x)
	var y: float = (float(size.y) - float(gshop_panel.size.y)) * 0.5
	gshop_panel.position = Vector2(max(10.0, x), max(10.0, y))

func _on_char_panel_visibility_changed(is_visible: bool) -> void:
	if not control_matrix:
		return
	var btn_char = control_matrix.btn_character if "btn_character" in control_matrix else control_matrix.get_node_or_null("%BtnCharacter")
	if btn_char:
		if is_visible:
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.1, 0.55, 0.15, 1.0) # 绿色高亮
			active_style.border_width_left = 1
			active_style.border_width_top = 1
			active_style.border_width_right = 1
			active_style.border_width_bottom = 1
			active_style.border_color = Color(0.2, 0.85, 0.25, 1.0)
			active_style.corner_radius_top_left = 2
			active_style.corner_radius_top_right = 2
			active_style.corner_radius_bottom_right = 2
			active_style.corner_radius_bottom_left = 2
			btn_char.add_theme_stylebox_override("normal", active_style)
		else:
			btn_char.remove_theme_stylebox_override("normal")

# ========== 拖拽分解 (Drag to Salvage) ==========
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("source") == "main_bag":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("source") == "main_bag":
		var it = data.get("item_data", {})
		_handle_item_salvage_drop(it)

func _handle_item_salvage_drop(item_data: Dictionary) -> void:
	var fid = str(item_data.get("file_id", ""))
	if fid.is_empty():
		return
		
	# 检查是否为受保护的护身符
	var is_charm = bool(item_data.get("is_charm", false))
	var in_pocket = bool(item_data.get("in_charm_bag", false))
	if is_charm or in_pocket:
		print("[AFK_MainHUD] 护身符受到系统保护，无法分解！")
		return
		
	var qual = str(item_data.get("quality", "normal")).to_lower()
	var confirm_unique_enabled = true
	if pickup_setting_panel and pickup_setting_panel.has_method("get") and pickup_setting_panel.current_config:
		confirm_unique_enabled = bool(pickup_setting_panel.current_config.get("confirm_unique", true))
		
	if qual == "unique" and confirm_unique_enabled:
		if salvage_dialog:
			salvage_dialog.prompt_confirm(item_data, func(target_fid):
				_send_lpc_cmd("gfenjie one %s %d" % [target_fid, _bag_page()])
			)
	else:
		# 普通/蓝装/黄装秒级便捷分解 (保当前页)
		_send_lpc_cmd("gfenjie one %s %d" % [fid, _bag_page()])

# 背包当前浏览页 (供分解等操作保页码)
func _bag_page() -> int:
	if inventory_panel and "current_page" in inventory_panel:
		return inventory_panel.current_page
	return 1

func toggle_pickup_setting() -> void:
	if not pickup_setting_panel:
		return
	if pickup_setting_panel.visible:
		pickup_setting_panel.hide_panel()
		_update_pickup_btn_style(false)
	else:
		if hook_setting_panel and hook_setting_panel.visible:
			hook_setting_panel.hide_panel()
			_update_hook_btn_style(false)
		pickup_setting_panel.show_panel()
		_update_pickup_btn_style(true)

func _update_pickup_btn_style(is_active: bool) -> void:
	if not control_matrix:
		return
	var btn_p = control_matrix.get_node_or_null("%BtnPickup")
	if btn_p:
		if is_active:
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.1, 0.55, 0.15, 1.0)
			active_style.border_width_left = 1
			active_style.border_width_top = 1
			active_style.border_width_right = 1
			active_style.border_width_bottom = 1
			active_style.border_color = Color(0.2, 0.85, 0.25, 1.0)
			active_style.corner_radius_top_left = 2
			active_style.corner_radius_top_right = 2
			active_style.corner_radius_bottom_right = 2
			active_style.corner_radius_bottom_left = 2
			btn_p.add_theme_stylebox_override("normal", active_style)
			btn_p.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			btn_p.remove_theme_stylebox_override("normal")
			btn_p.remove_theme_color_override("font_color")

func toggle_hook_setting() -> void:
	if not hook_setting_panel:
		return
	if hook_setting_panel.visible:
		hook_setting_panel.hide_panel()
		_update_hook_btn_style(false)
	else:
		if pickup_setting_panel and pickup_setting_panel.visible:
			pickup_setting_panel.hide_panel()
			_update_pickup_btn_style(false)
		if char_info_panel and char_info_panel.visible:
			char_info_panel.close()
		if skill_panel and skill_panel.visible:
			skill_panel.close()
		if cube_panel and cube_panel.visible:
			cube_panel.visible = false
		if gshop_panel and gshop_panel.visible:
			gshop_panel.close()
		hook_setting_panel.show_panel()
		_update_hook_btn_style(true)

func _update_hook_btn_style(is_active: bool) -> void:
	if not control_matrix:
		return
	var btn_h = control_matrix.get_node_or_null("%BtnHook")
	if btn_h:
		if is_active:
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.15, 0.45, 0.6, 1.0)
			active_style.border_width_left = 1
			active_style.border_width_top = 1
			active_style.border_width_right = 1
			active_style.border_width_bottom = 1
			active_style.border_color = Color(0.3, 0.75, 0.95, 1.0)
			active_style.corner_radius_top_left = 2
			active_style.corner_radius_top_right = 2
			active_style.corner_radius_bottom_right = 2
			active_style.corner_radius_bottom_left = 2
			btn_h.add_theme_stylebox_override("normal", active_style)
			btn_h.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			btn_h.remove_theme_stylebox_override("normal")
			btn_h.remove_theme_color_override("font_color")

func _send_lpc_cmd(cmd: String) -> void:
	if NetworkClient.is_connected:
		NetworkClient.send_raw(cmd)

## 渲染玩家当前召唤仆从聚合状态徽章 (复生骷髅、石魔等)
func _update_summons_display(summons: Variant) -> void:
	var viewport = get_node_or_null("MainHBox/LeftViewport")
	var target_parent: Node = viewport if viewport != null else self

	var box: VBoxContainer = target_parent.get_node_or_null("SummonsContainer") as VBoxContainer
	if not box:
		box = VBoxContainer.new()
		box.name = "SummonsContainer"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.layout_mode = 1
		box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		# 左边距 12.0，右边距 187.0，宽度精确对齐玩家队伍卡片(175px)
		# 底部吸附在聊天视窗展开顶部(-285px)上方，预留 10px 黄金安全间距，彻底杜绝与聊天窗及血球重叠
		box.offset_left = 12.0
		box.offset_right = 187.0
		box.offset_bottom = -295.0
		box.offset_top = -415.0
		box.z_index = 85
		box.z_as_relative = false
		target_parent.add_child(box)

	for child in box.get_children():
		child.queue_free()

	if not summons is Array or summons.is_empty():
		box.visible = false
		return

	var has_any = false
	for s in summons:
		if not s is Dictionary: continue
		var count = _safe_int(s.get("count"), 0)
		var max_count = _safe_int(s.get("max_count"), 0)
		if count <= 0 and max_count <= 0: continue
		has_any = true

		var s_name = str(s.get("name", "仆从"))
		var stype = str(s.get("type", ""))
		var hp_pct = _safe_int(s.get("hp_pct"), 100)
		var icon_sym = str(s.get("icon", ""))
		if icon_sym.is_empty():
			if "valkyrie" in stype: icon_sym = "🛡️"
			elif "golem" in stype: icon_sym = "🗿"
			elif "grizzly" in stype: icon_sym = "🐻"
			elif "spirit_wolf" in stype: icon_sym = "❄️"
			elif "wolf" in stype: icon_sym = "🐺"
			elif "mage" in stype: icon_sym = "🧙"
			else: icon_sym = "💀"

		var card = PanelContainer.new()
		# 强制卡片宽度与玩家卡片(175px)严格等长
		card.custom_minimum_size = Vector2(175, 24)

		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.075, 0.07, 0.94)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		# 边框风格与玩家卡片统一：满额亮金，折损银灰
		sb.border_color = Color(0.85, 0.72, 0.3, 0.95) if count >= max_count else Color(0.48, 0.44, 0.38, 0.8)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		card.add_theme_stylebox_override("panel", sb)

		var lbl = Label.new()
		lbl.text = "%s %s: %d / %d (%d%%)" % [icon_sym, s_name, count, max_count, hp_pct]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45) if count >= max_count else Color(0.85, 0.85, 0.85))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(lbl)
		box.add_child(card)

	box.visible = has_any
