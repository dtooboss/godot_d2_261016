extends Node2D
class_name AFK_CombatFXManager

## 挂机战斗技能弹道与打击视觉引擎 2.0 (KISS 原则：轻量、纯 2D、极致暗黑质感)

# 专属形态剪影贴图 (高通透白光 + 细节雕纹)
const FX_ORB_TEX = preload("res://assets/fx/fx_orb.png")
const FX_ARROW_TEX = preload("res://assets/fx/fx_arrow.png")
const FX_HAMMER_TEX = preload("res://assets/fx/fx_hammer.png")
const FX_SPIKE_TEX = preload("res://assets/fx/fx_spike.png")
const FX_FLARE_TEX = preload("res://assets/fx/fx_flare.png")
const ATTACK_EFFECT_TEX = preload("res://assets/images/attack_effect.png")

# 暗黑 6 系元素高通透发光色阶 (高亮白炽内核 + 饱和外晕)
const ELEMENT_COLORS = {
	"物理": Color(0.92, 0.90, 0.85, 1.0),
	"phys": Color(0.92, 0.90, 0.85, 1.0),
	"unarmed": Color(0.92, 0.90, 0.85, 1.0),
	"火": Color(1.0, 0.42, 0.12, 1.0),
	"fire": Color(1.0, 0.42, 0.12, 1.0),
	"冰": Color(0.30, 0.85, 1.0, 1.0),
	"cold": Color(0.30, 0.85, 1.0, 1.0),
	"电": Color(0.96, 0.96, 1.25, 1.0), # 高压纯正银白
	"light": Color(0.96, 0.96, 1.25, 1.0),
	"毒": Color(0.25, 0.95, 0.28, 1.0),
	"poison": Color(0.25, 0.95, 0.28, 1.0),
	"魔法": Color(1.0, 0.85, 0.42, 1.0), # 圣辉白金
	"magic": Color(1.0, 0.85, 0.42, 1.0),
}

# 默认发光材质 (Additive 混合模式，赋予暗黑魔法通透质感)
var _additive_material: CanvasItemMaterial = null

# ========== P1.1 对象池 (2026-10-13)：弹道对(proj+trail)与命中冲击复用，杜绝高频 new/free ==========
const POOL_CAP_PER_TYPE := 8    # 每形态池上限，超出直接释放
const IMPACT_POOL_CAP := 12     # 命中冲击池上限
var _proj_pool: Dictionary = {}      # fx_type -> Array[{proj:Node2D, trail:Line2D}]
var _impact_pool: Array = []         # 回收的 flare Sprite2D
var _live_count := 0                 # 同屏活跃弹道 (超 30 兜底直收)
var _live_proj_list: Array = []      # 活跃弹道队列 (超限回收最旧)

# ========== P1.4 技能→形态规则表 (数据化，新技能加一行即接入) ==========
const SKILL_FX_TABLE := {
	"charged_strike": "charged_strike",
	"lightning_fury": "lightning_fury",
	"lightning_strike": "lightning_strike",
	"lightning_bolt": "lightning_javelin",
	"power_strike": "spear_thrust", "jab": "spear_thrust", "fend": "spear_thrust", "impale": "spear_thrust",
	"bone_spear": "spike", "bone_spirit": "orb", "poison_dagger": "melee",
	"fire_ball": "orb", "meteor": "orb", "fire_trap": "orb", "enchant": "orb",
	"blizzard": "orb", "frozen_orb": "orb", "ice_bolt": "spike", "glacial_spike": "spike",
	"frozen_armor": "orb", "shiver_armor": "orb", "chilling_armor": "orb",
	"poison_explosion": "orb", "poison_nova": "orb", "poison_javelin": "spear_thrust",
	"multiple_shot": "arrow", "strafe": "arrow", "guided_arrow": "arrow", "cold_arrow": "arrow",
	"fire_arrow": "arrow", "immolation_arrow": "arrow", "magic_arrow": "arrow",
	"holy_bolt": "orb", "fist_of_the_heavens": "lightning_strike",
	"teeth": "spike", "corpse_explosion": "orb",
	"whirlwind": "melee", "frenzy": "melee", "zeal": "melee", "bash": "melee",
	"stun": "melee", "concentrate": "melee", "smite": "melee", "berserk": "melee",
	"double_swing": "melee", "double_throw": "arrow",
}

# 地面残留技能 (命中/施放时在目标点铺持续层)
const GROUND_SKILLS := {
	"fire_wall": {"kind": "fire", "radius": 90.0, "dur": 5.0},
	"meteor": {"kind": "fire", "radius": 70.0, "dur": 2.5},
	"poison_nova": {"kind": "poison", "radius": 110.0, "dur": 4.0},
	"poison_explosion": {"kind": "poison", "radius": 80.0, "dur": 3.0},
	"blizzard": {"kind": "ice", "radius": 120.0, "dur": 4.0},
	"frozen_orb": {"kind": "ice", "radius": 70.0, "dur": 2.0},
}

func _init() -> void:
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func _ready() -> void:
	z_index = 10 # 确保处于怪物本体上方、HUD 界面下方

## 统一对外调度入口 (支持形态分类、数量阵列、玩家与怪物双轨分流)
func play_combat_fx(
	start_pos: Vector2,
	target_pos: Vector2,
	skill_code: String,
	elem: String,
	on_hit: Callable,
	is_crit: bool = false,
	is_from_player: bool = true,
	count: int = 1,
	fx_type_override: String = ""
) -> void:
	var col = _get_element_color(elem, skill_code)
	if not is_from_player:
		# 怪物弹道：混入 35% 恶魔血煞暗蚀微光，赋予鲜明的邪能敌意视觉
		col = col.lerp(Color(0.95, 0.22, 0.26, 1.0), 0.35)
	
	# 计算弹道前进方向与垂直法线 (用于双车道分流)
	var delta = target_pos - start_pos
	var dist = delta.length()
	var dir = delta.normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.UP
	var normal = Vector2(-dir.y, dir.x).normalized()
	
	# 靠右行驶法则：玩家右偏 18px，怪物左偏 18px，形成自然平行的 36px 隔离双车道
	var offset = normal * (18.0 if is_from_player else -18.0)
	var actual_start = start_pos + offset
	var actual_target = target_pos + offset

	var fx_type = fx_type_override if not fx_type_override.is_empty() else _lookup_fx_type(skill_code, elem)

	# P1.3 地面残留层 (火焰墙/毒云/冰霜等持续区域，铺在弹道层之下)
	if GROUND_SKILLS.has(skill_code):
		var g: Dictionary = GROUND_SKILLS[skill_code]
		_spawn_ground_fx(str(g["kind"]), target_pos, float(g["radius"]), float(g["dur"]), col)

	# P1.1 池化兜底：同屏活跃弹道超限回收最旧
	if _live_count >= 30:
		_recycle_oldest_projectile()

	match fx_type:
		"charged_strike":
			_spawn_charged_strike(target_pos, col, on_hit, is_crit)
		"lightning_fury":
			_spawn_lightning_fury(actual_start, actual_target, col, on_hit, is_crit, is_from_player)
		"lightning_strike":
			_spawn_lightning_strike(target_pos, col, on_hit, is_crit)
		"lightning_javelin":
			_spawn_lightning_javelin(actual_start, actual_target, col, on_hit, is_crit, is_from_player)
		"spear_thrust":
			_spawn_spear_thrust(target_pos, col, on_hit, is_crit)
		"lightning":
			_spawn_lightning(actual_start, actual_target, col, on_hit, is_crit)
		"melee":
			_spawn_melee_slash(target_pos, col, on_hit, is_crit)
		_:
			# 飞行弹道：支持单发与扇形多发 (count > 1)
			var total_projectiles = clamp(count, 1, 7)
			if total_projectiles <= 1:
				_spawn_projectile(actual_start, actual_target, fx_type, col, on_hit, is_crit, is_from_player)
			else:
				# 扇形散射：中心弹道触发 on_hit，侧翼弹道同步飞射
				var spread_angle_step = deg_to_rad(6.5)
				var half_spread = float(total_projectiles - 1) * 0.5
				for i in range(total_projectiles):
					var angle_offset = (float(i) - half_spread) * spread_angle_step
					var sub_dir = dir.rotated(angle_offset)
					var sub_target = actual_start + sub_dir * dist
					var sub_on_hit = on_hit if i == int(half_spread) else Callable()
					_spawn_projectile(actual_start, sub_target, fx_type, col, sub_on_hit, is_crit, is_from_player)

## 1. 动态飞行物弹道 (对象池复用版：按 fx_type 池化 proj+trail 对，杜绝高频 new/free)
func _spawn_projectile(
	start_pos: Vector2,
	target_pos: Vector2,
	fx_type: String,
	color: Color,
	on_hit: Callable,
	is_crit: bool,
	is_from_player: bool
) -> void:
	_live_count += 1
	var e: Dictionary = _acquire_projectile(fx_type)
	var proj: Node2D = e["proj"]
	var trail: Line2D = e["trail"]
	_live_proj_list.append({"fx": fx_type, "proj": proj, "trail": trail})
	var sp: Sprite2D = e["sp"]
	var tex: Texture2D = e["tex"]

	var base_scale: Vector2 = e["scale"] * (1.3 if is_crit else 1.0)
	var is_rotating: bool = e["rot"]
	# 每次发射重置可见性与颜色 (池化节点复用)
	proj.visible = true
	proj.modulate = Color(1, 1, 1, 1)
	trail.visible = true
	trail.modulate = Color(1, 1, 1, 1)
	sp.modulate = color
	sp.scale = base_scale
	proj.global_position = start_pos

	# 流光彗尾渐变按元素色重置
	if trail.gradient:
		trail.gradient.set_color(0, Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.0))
		trail.gradient.set_color(1, Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.9))
		trail.width = 8.5 if is_crit else 6.0

	var dist = start_pos.distance_to(target_pos)

	if is_from_player:
		# 玩家弹道：笔直迅捷疾冲
		if not is_rotating:
			proj.look_at(target_pos)

		var dur = clamp(dist / 1450.0, 0.09, 0.17)
		var tw = create_tween().bind_node(proj)
		e["tween"] = tw
		tw.set_ease(Tween.EASE_OUT)

		tw.tween_method(
			_update_projectile_straight.bind(proj, sp, trail, start_pos, target_pos, is_rotating, base_scale),
			0.0, 1.0, dur
		)
		tw.tween_callback(
			_on_projectile_arrived.bind(target_pos, color, is_crit, on_hit, proj, trail, fx_type)
		)
	else:
		# 怪物弹道：带自然的贝塞尔微抛物线弧度，切线自适应转向
		var p0 = start_pos
		var p2 = target_pos
		var d = p2 - p0
		var norm = Vector2(-d.y, d.x).normalized()
		var p1 = (p0 + p2) * 0.5 + norm * -25.0

		var dur = clamp(dist / 1150.0, 0.12, 0.22)
		var tw = create_tween().bind_node(proj)
		e["tween"] = tw
		tw.set_ease(Tween.EASE_OUT)

		tw.tween_method(
			_update_projectile_curved.bind(proj, trail, p0, p1, p2, is_rotating),
			0.0, 1.0, dur
		)
		tw.tween_callback(
			_on_projectile_arrived.bind(target_pos, color, is_crit, on_hit, proj, trail, fx_type)
		)

func _update_projectile_straight(
	t: float,
	proj: Node2D,
	sp: Sprite2D,
	trail: Line2D,
	start_pos: Vector2,
	target_pos: Vector2,
	is_rotating: bool,
	base_scale: Vector2
) -> void:
	if not is_instance_valid(proj): return
	var cur_pos = start_pos.lerp(target_pos, t)
	proj.global_position = cur_pos
	
	if is_rotating:
		proj.rotation = t * 18.0
	elif is_instance_valid(sp):
		var pulse = 1.0 + sin(t * 20.0) * 0.08
		sp.scale = base_scale * pulse
		
	if trail and is_instance_valid(trail):
		trail.clear_points()
		var tail_t = max(0.0, t - 0.32)
		for k in range(5):
			var sub_t = lerp(tail_t, t, float(k) / 4.0)
			trail.add_point(start_pos.lerp(target_pos, sub_t))

func _update_projectile_curved(
	t: float,
	proj: Node2D,
	trail: Line2D,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	is_rotating: bool
) -> void:
	if not is_instance_valid(proj): return
	var inv_t = 1.0 - t
	var cur_pos = inv_t * inv_t * p0 + 2.0 * inv_t * t * p1 + t * t * p2
	proj.global_position = cur_pos
	
	if is_rotating:
		proj.rotation = t * 16.0
	else:
		var tangent = 2.0 * inv_t * (p1 - p0) + 2.0 * t * (p2 - p1)
		if tangent.length_squared() > 0.01:
			proj.rotation = tangent.angle()
			
	if trail and is_instance_valid(trail):
		trail.clear_points()
		var tail_t = max(0.0, t - 0.28)
		for k in range(5):
			var st = lerp(tail_t, t, float(k) / 4.0)
			var sinv = 1.0 - st
			var sp_pos = sinv * sinv * p0 + 2.0 * sinv * st * p1 + st * st * p2
			trail.add_point(sp_pos)

func _on_projectile_arrived(
	target_pos: Vector2,
	color: Color,
	is_crit: bool,
	on_hit: Callable,
	proj: Node2D,
	trail: Line2D,
	fx_type: String
) -> void:
	_spawn_hit_impact(target_pos, color, is_crit)
	if on_hit.is_valid():
		on_hit.call()

	# 池化回收 (替代 queue_free)
	_live_count = max(0, _live_count - 1)
	_release_projectile(fx_type, proj, trail)

## 池化：按 fx_type 取出复用对，池空则新建 (建一次终身复用)
func _acquire_projectile(fx_type: String) -> Dictionary:
	var arr: Array = _proj_pool.get(fx_type, [])
	if arr.size() > 0:
		var e: Dictionary = arr.pop_back()
		_proj_pool[fx_type] = arr
		return e

	# 首建：形态贴图与缩放配置
	var tex: Texture2D = FX_ORB_TEX
	var base_scale := Vector2(0.30, 0.30)
	var is_rotating := false
	match fx_type:
		"hammer":
			tex = FX_HAMMER_TEX
			base_scale = Vector2(0.32, 0.32)
			is_rotating = true
		"arrow":
			tex = FX_ARROW_TEX
			base_scale = Vector2(0.34, 0.34)
		"spike":
			tex = FX_SPIKE_TEX
			base_scale = Vector2(0.35, 0.35)
		"orb":
			tex = FX_ORB_TEX
			base_scale = Vector2(0.30, 0.30)
		_:
			tex = ATTACK_EFFECT_TEX
			base_scale = Vector2(0.38, 0.22)

	var proj = Node2D.new()
	add_child(proj)
	var sp = Sprite2D.new()
	sp.texture = tex
	sp.material = _additive_material
	proj.add_child(sp)
	var core_sp = Sprite2D.new()
	core_sp.texture = tex
	core_sp.material = _additive_material
	core_sp.modulate = Color(1.0, 1.0, 1.0, 0.85)
	core_sp.scale = base_scale * 0.65
	proj.add_child(core_sp)
	var trail = Line2D.new()
	trail.material = _additive_material
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)

	var entry := {"proj": proj, "trail": trail, "sp": sp, "tex": tex, "scale": base_scale,
		"rot": is_rotating, "tween": null}
	proj.set_meta("pool_entry", entry)
	return entry

## 池化：归还复用对 (超上限才真正释放)
func _release_projectile(fx_type: String, proj: Node2D, trail: Line2D) -> void:
	if is_instance_valid(proj):
		proj.visible = false
	if trail and is_instance_valid(trail):
		trail.visible = false
		trail.clear_points()
	var arr: Array = _proj_pool.get(fx_type, [])
	var entry: Dictionary = proj.get_meta("pool_entry", {"proj": proj, "trail": trail})
	entry["proj"] = proj
	entry["trail"] = trail
	if entry.has("tween") and entry["tween"] != null and entry["tween"].is_valid():
		entry["tween"].kill()
	entry["tween"] = null
	if arr.size() < POOL_CAP_PER_TYPE:
		arr.append(entry)
		_proj_pool[fx_type] = arr
	else:
		proj.set_meta("pool_entry", null)
		if is_instance_valid(proj): proj.queue_free()
		if trail and is_instance_valid(trail): trail.queue_free()

## 池化兜底：同屏弹道超限时强制回收最旧一只 (直接进池)
func _recycle_oldest_projectile() -> bool:
	if _live_proj_list.is_empty():
		return false
	var oldest: Dictionary = _live_proj_list.pop_front()
	if is_instance_valid(oldest["proj"]):
		_release_projectile(str(oldest["fx"]), oldest["proj"], oldest["trail"])
	_live_count = max(0, _live_count - 1)
	return true

## 2. 即时纯正高亮银白电弧/连环闪电折线 (双层渲染：银白主芯 + 青紫电晕)
func _spawn_lightning(
	start_pos: Vector2,
	target_pos: Vector2,
	color: Color,
	on_hit: Callable,
	is_crit: bool
) -> void:
	# 外层微光电晕 (青紫/元素外晕)
	var outer_line = Line2D.new()
	outer_line.material = _additive_material
	outer_line.default_color = Color(0.70, 0.80, 1.0, 0.55)
	outer_line.width = 6.5 if is_crit else 4.5
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(outer_line)
	
	# 内层高能银白电芯 (纯银白耀眼光芒)
	var inner_line = Line2D.new()
	inner_line.material = _additive_material
	inner_line.default_color = Color(1.5, 1.5, 1.6, 1.0)
	inner_line.width = 2.8 if is_crit else 1.8
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(inner_line)
	
	# 生成 5 段随机高频抖动折线点
	var seg_count = 6
	var delta_vec = target_pos - start_pos
	var norm_vec = Vector2(-delta_vec.y, delta_vec.x).normalized()
	
	outer_line.add_point(start_pos)
	inner_line.add_point(start_pos)
	
	for i in range(1, seg_count):
		var t = float(i) / float(seg_count)
		var p = start_pos.lerp(target_pos, t)
		var jitter = norm_vec * randf_range(-14.0, 14.0)
		var pt = p + jitter
		outer_line.add_point(pt)
		inner_line.add_point(pt)
		
	outer_line.add_point(target_pos)
	inner_line.add_point(target_pos)
	
	# 瞬间触发命中结算
	_spawn_hit_impact(target_pos, Color(1.3, 1.3, 1.5), is_crit)
	if on_hit.is_valid():
		on_hit.call()
		
	# 电弧残留 0.08 秒闪烁淡出
	var tw = create_tween().bind_node(outer_line)
	tw.set_parallel(true)
	tw.tween_property(outer_line, "modulate:a", 0.0, 0.08).set_ease(Tween.EASE_IN)
	tw.tween_property(inner_line, "modulate:a", 0.0, 0.08).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_safe_free_pair.bind(outer_line, inner_line))

func _safe_free_pair(n1: Node, n2: Node) -> void:
	if is_instance_valid(n1): n1.queue_free()
	if is_instance_valid(n2): n2.queue_free()

## 3. 近战挥砍与弧形刀光
func _spawn_melee_slash(
	target_pos: Vector2,
	color: Color,
	on_hit: Callable,
	is_crit: bool
) -> void:
	var slash = Node2D.new()
	slash.global_position = target_pos
	slash.rotation = randf_range(-0.4, 0.4)
	add_child(slash)
	
	var sp = Sprite2D.new()
	sp.texture = ATTACK_EFFECT_TEX
	sp.material = _additive_material
	sp.modulate = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.95)
	var max_scale = Vector2(0.55, 0.35) if is_crit else Vector2(0.40, 0.22)
	sp.scale = Vector2(0.1, 0.1)
	slash.add_child(sp)
	
	# 立即触发击中回调，刀光瞬间扩张并淡出 (0.11s)
	_spawn_hit_impact(target_pos, color, is_crit)
	if on_hit.is_valid():
		on_hit.call()
		
	var tw = create_tween().bind_node(slash)
	tw.tween_property(sp, "scale", max_scale, 0.04).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "rotation", 0.6, 0.09)
	tw.tween_property(sp, "modulate:a", 0.0, 0.06)
	tw.tween_callback(slash.queue_free)

## 4. 击中爆点微光 (Hit Impact - 星芒高光爆裂)
## 工具函数：推断元素色彩 (综合 elem 与 skill_code 原生属性，杜绝微小附魔词缀喧宾夺主)
func _get_element_color(elem: String, skill_code: String = "") -> Color:
	var sk = skill_code.to_lower()
	
	# 1. 技能原生固有标志性元素优先
	if "exploding" in sk or "fire_arrow" in sk or "immolation" in sk or "fire_ball" in sk or "fire_bolt" in sk or "meteor" in sk or "hydra" in sk or "blaze" in sk or "inferno" in sk:
		return ELEMENT_COLORS["火"]
	if "cold_arrow" in sk or "ice_arrow" in sk or "freezing" in sk or "ice_bolt" in sk or "ice_blast" in sk or "glacial" in sk or "blizzard" in sk or "frozen_orb" in sk or "frost_nova" in sk:
		return ELEMENT_COLORS["冰"]
	if "lightning_bolt" in sk or "lightning_fury" in sk or "charged_bolt" in sk or "chain_lightning" in sk or "thunder_storm" in sk or (sk == "lightning"):
		return ELEMENT_COLORS["电"]
	if "poison_javelin" in sk or "plague_javelin" in sk or "poison_dagger" in sk or "poison_explosion" in sk or "poison_nova" in sk or "rabies" in sk:
		return ELEMENT_COLORS["毒"]
	if "blessed_hammer" in sk or "holy_bolt" in sk or "teeth" in sk or "bone_spear" in sk or "bone_spirit" in sk:
		return ELEMENT_COLORS["魔法"]
	if "multiple_shot" in sk or "guided_arrow" in sk or "strafe" in sk:
		return ELEMENT_COLORS["物理"]

	# 2. 其它技能或普攻：严格匹配传入的 elem
	for k in ELEMENT_COLORS.keys():
		if k in elem:
			return ELEMENT_COLORS[k]
	return ELEMENT_COLORS["物理"]

## 5. 亚马逊·充能一击 (Charged Strike)：近身刺击 + 炸裂多道蜿蜒窜动的电荷弹
func _spawn_charged_strike(target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool) -> void:
	_spawn_spear_thrust(target_pos, color, on_hit, is_crit)
	
	# 从受击中心向四周辐射喷射 6 道乱窜的银白高能电荷弹
	var bolt_count = 6
	for b in range(bolt_count):
		var base_angle = float(b) * (TAU / float(bolt_count)) + randf_range(-0.35, 0.35)
		var rad_dir = Vector2.RIGHT.rotated(base_angle)
		var travel_dist = randf_range(45.0, 75.0)
		
		var bolt_line = Line2D.new()
		bolt_line.material = _additive_material
		bolt_line.default_color = Color(1.3, 1.4, 1.8, 0.95)
		bolt_line.width = 2.2 if is_crit else 1.6
		bolt_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bolt_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(bolt_line)
		
		# 3段蜿蜒游走路径点
		var pt0 = target_pos
		var pt1 = pt0 + rad_dir * (travel_dist * 0.45) + rad_dir.orthogonal() * randf_range(-12.0, 12.0)
		var pt2 = pt0 + rad_dir * travel_dist + rad_dir.orthogonal() * randf_range(-8.0, 8.0)
		bolt_line.add_point(pt0)
		bolt_line.add_point(pt1)
		bolt_line.add_point(pt2)
		
		var tw = create_tween().bind_node(bolt_line)
		tw.tween_property(bolt_line, "modulate:a", 0.0, 0.16).set_ease(Tween.EASE_IN)
		tw.tween_callback(bolt_line.queue_free)

## 6. 亚马逊·雷霆之怒 (Lightning Fury)：雷神之矛飞掷 + 环状全屏群雷暴轰
func _spawn_lightning_fury(start_pos: Vector2, target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool, is_from_player: bool) -> void:
	# 阶段 1: 投掷实体高能闪电标枪
	var on_fury_impact = func():
		if on_hit.is_valid():
			on_hit.call()
		# 阶段 2: 目标处剧烈雷核核爆 + 向全屏四周爆发 10 道放射状折线雷霆
		_spawn_hit_impact(target_pos, Color(1.5, 1.6, 2.0), true)
		
		var ray_count = 10
		for r in range(ray_count):
			var angle = float(r) * (TAU / float(ray_count)) + randf_range(-0.25, 0.25)
			var ray_dir = Vector2.RIGHT.rotated(angle)
			var ray_len = randf_range(80.0, 140.0)
			var ray_end = target_pos + ray_dir * ray_len
			
			var ray_line = Line2D.new()
			ray_line.material = _additive_material
			ray_line.default_color = Color(1.4, 1.5, 1.8, 0.9)
			ray_line.width = 3.2 if is_crit else 2.2
			ray_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			ray_line.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(ray_line)
			
			# 生成折线
			ray_line.add_point(target_pos)
			var mid1 = target_pos + ray_dir * (ray_len * 0.35) + ray_dir.orthogonal() * randf_range(-10.0, 10.0)
			var mid2 = target_pos + ray_dir * (ray_len * 0.70) + ray_dir.orthogonal() * randf_range(-10.0, 10.0)
			ray_line.add_point(mid1)
			ray_line.add_point(mid2)
			ray_line.add_point(ray_end)
			
			var tw = create_tween().bind_node(ray_line)
			tw.tween_property(ray_line, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
			tw.tween_callback(ray_line.queue_free)

	_spawn_projectile(start_pos, target_pos, "spike", Color(1.3, 1.4, 1.8), on_fury_impact, is_crit, is_from_player)

## 7. 亚马逊·闪电标枪 (Lightning Bolt)：高光电弧缠绕的实体长矛投掷
func _spawn_lightning_javelin(start_pos: Vector2, target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool, is_from_player: bool) -> void:
	_spawn_projectile(start_pos, target_pos, "spike", Color(1.4, 1.4, 1.9), on_hit, is_crit, is_from_player)

## 8. 亚马逊·闪电攻击 (Lightning Strike)：近身戳刺 + 连环闪电弹射
func _spawn_lightning_strike(target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool) -> void:
	_spawn_spear_thrust(target_pos, color, on_hit, is_crit)
	
	# 从击中点向周围 3 个方向蔓延出弹射闪电
	for c in range(3):
		var spread_pos = target_pos + Vector2(randf_range(-70.0, 70.0), randf_range(-60.0, 60.0))
		_spawn_lightning(target_pos, spread_pos, Color(1.2, 1.3, 1.7), Callable(), is_crit)

## 9. 长矛/标枪专属直刺突击 (Spear Thrust - 区别于横向弧斩的纵向刺击)
func _spawn_spear_thrust(target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool) -> void:
	var thrust = Node2D.new()
	thrust.global_position = target_pos
	thrust.rotation = randf_range(-0.15, 0.15)
	add_child(thrust)
	
	var sp = Sprite2D.new()
	sp.texture = FX_SPIKE_TEX
	sp.material = _additive_material
	sp.modulate = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.95)
	sp.scale = Vector2(0.2, 0.45) if is_crit else Vector2(0.15, 0.35)
	thrust.add_child(sp)
	
	_spawn_hit_impact(target_pos, color, is_crit)
	if on_hit.is_valid():
		on_hit.call()
		
	var tw = create_tween().bind_node(thrust)
	tw.tween_property(sp, "scale:y", sp.scale.y * 1.35, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, 0.06)
	tw.tween_callback(thrust.queue_free)

## 工具函数：推断特效表现类型 (支持专属技能分流 + hammer/arrow/spike/orb/lightning/melee)
## P1.4 规则表入口: 数据表优先, 关键词规则兜底
func _lookup_fx_type(skill_code: String, elem: String) -> String:
	var sk = skill_code.to_lower()
	if SKILL_FX_TABLE.has(sk):
		return SKILL_FX_TABLE[sk]
	return _detect_fx_type(skill_code, elem)

func _detect_fx_type(skill_code: String, elem: String) -> String:
	var sk = skill_code.to_lower()
	
	# 0. 亚马逊专属标枪电系特征细化分流
	if sk == "charged_strike":
		return "charged_strike" # 充能一击：刺击 + 炸出多道乱窜电荷弹
	if sk == "lightning_fury":
		return "lightning_fury" # 雷霆之怒：雷霆神矛投掷 + 全屏群雷环形炸裂
	if sk == "lightning_strike":
		return "lightning_strike" # 闪电攻击：刺击 + 连锁闪电弹射
	if sk == "lightning_bolt":
		return "lightning_javelin" # 闪电标枪：实体高光电弧标枪贯穿投掷
	if sk in ["power_strike", "jab", "fend", "impale"]:
		return "spear_thrust" # 近战长矛/标枪迅捷戳刺
		
	# 1. 战锤型
	if "hammer" in sk:
		return "hammer"
		
	# 2. 闪电型
	if "lightning" in sk or "chain" in sk or ("bolt" in sk and "light" in elem):
		return "lightning"
		
	# 3. 箭矢型
	if "arrow" in sk or "shot" in sk or "strafe" in sk:
		return "arrow"
		
	# 4. 尖刺/骨矛/标枪型
	if "spear" in sk or "spike" in sk or "javelin" in sk:
		return "spike"
		
	# 5. 经典近战或普通挥击判定
	if sk in ["attack", "frenzy", "zeal", "bash", "stun", "concentrate", "smite", "berserk", "venom"]:
		return "melee"
		
	# 6. 法球/火球/冰弹/其它
	return "orb"

## ========== P1.2 命中冲击 v2 (池化 flare + 程序化火花爆裂) ==========
func _spawn_hit_impact(pos: Vector2, color: Color, is_crit: bool) -> void:
	var impact: Sprite2D
	if _impact_pool.size() > 0:
		impact = _impact_pool.pop_back()
		impact.visible = true
	else:
		impact = Sprite2D.new()
		impact.texture = FX_FLARE_TEX
		impact.material = _additive_material
		add_child(impact)
	if impact.get_parent() == null:
		add_child(impact)
	impact.global_position = pos
	impact.modulate = Color(min(color.r * 1.5, 2.0), min(color.g * 1.5, 2.0), min(color.b * 1.5, 2.0), 1.0)
	var start_s = Vector2(0.12, 0.12)
	var end_s = Vector2(0.55, 0.55) if is_crit else Vector2(0.36, 0.36)
	impact.scale = start_s

## ========== P1.3 地面残留层 (火焰墙/毒云/冰霜 decal, z 低于怪物) ==========
var _ground_pool: Array = []
var _active_ground := 0

func _spawn_ground_fx(kind: String, pos: Vector2, radius: float, dur: float, col: Color) -> void:
	if _active_ground >= 6:
		return
	_active_ground += 1
	var gcol: Color
	match kind:
		"fire":
			gcol = Color(1.0, 0.45, 0.1, 0.5)
		"poison":
			gcol = Color(0.3, 0.9, 0.3, 0.42)
		"ice":
			gcol = Color(0.4, 0.8, 1.0, 0.45)
		_:
			gcol = Color(col.r, col.g, col.b, 0.45)

	var decal: Sprite2D
	if _ground_pool.size() > 0:
		decal = _ground_pool.pop_back()
		decal.visible = true
	else:
		decal = Sprite2D.new()
		decal.texture = FX_FLARE_TEX
		decal.material = _additive_material
	add_child(decal)
	decal.global_position = pos
	decal.modulate = Color(gcol.r, gcol.g, gcol.b, 0.0)
	decal.scale = Vector2.ONE * (radius / 96.0)
	decal.rotation = randf_range(0.0, TAU)
	z_index = -20 # 地面层：相对弹道层压到最底

	var tw = create_tween().bind_node(decal)
	tw.set_parallel(true)
	tw.tween_property(decal, "modulate:a", gcol.a, 0.25)
	tw.tween_property(decal, "rotation", decal.rotation + randf_range(0.4, 1.2), dur)
	tw.chain().tween_property(decal, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func():
		if is_instance_valid(decal):
			decal.visible = false
			_ground_pool.append(decal)
		_active_ground = max(0, _active_ground - 1))
