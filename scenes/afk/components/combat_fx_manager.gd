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

# 纯参数化粒子特效场景 (参考 GODOT-VFX-LIBRARY，零贴图依赖)
const BLOOD_SPLASH_SCENE = preload("res://scenes/vfx/blood_splash.tscn")
const SHIELD_BREAK_SCENE = preload("res://scenes/vfx/shield_break.tscn")
const ENERGY_BURST_SCENE = preload("res://scenes/vfx/energy_burst.tscn")
const ICE_FROST_SCENE = preload("res://scenes/vfx/ice_frost.tscn")

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

# Token 栈式时间缩放/顿帧管理 (多技能命中并发安全)
var _time_scale_requests: Dictionary = {}
var _time_scale_token_counter: int = 0
var _time_scale_original: float = 1.0

func _init() -> void:
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func _ready() -> void:
	z_index = 10 # 确保处于怪物本体上方、HUD 界面下方
	tree_exiting.connect(_cleanup_on_exit)

func _cleanup_on_exit() -> void:
	_time_scale_requests.clear()
	Engine.time_scale = 1.0

## Token 栈式顿帧 (Hit-stop: 暴击/斩杀时微小时间定格，大幅提升打击分量感)
func freeze_frame(duration: float = 0.045, time_scale: float = 0.1) -> void:
	if not is_inside_tree(): return
	var token = _time_scale_token_counter
	_time_scale_token_counter += 1
	if _time_scale_requests.is_empty():
		_time_scale_original = Engine.time_scale
	_time_scale_requests[token] = clampf(time_scale, 0.0, 1.0)
	_apply_time_scale_requests()
	
	get_tree().create_timer(duration, true, false, true).timeout.connect(_on_freeze_timeout.bind(token))

func _on_freeze_timeout(token: int) -> void:
	if is_inside_tree():
		_time_scale_requests.erase(token)
		_apply_time_scale_requests()

func _apply_time_scale_requests() -> void:
	if _time_scale_requests.is_empty():
		Engine.time_scale = _time_scale_original
		return
	var min_req: float = 1.0
	for v in _time_scale_requests.values():
		min_req = minf(min_req, float(v))
	Engine.time_scale = minf(_time_scale_original, min_req)

## 轻量相机微震屏 (暴击/高能技能命中短促震动，杜绝眩晕)
func screen_shake(intensity: float = 3.5, duration: float = 0.09) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig_offset = cam.offset
	var tw = create_tween().bind_node(self)
	tw.set_ease(Tween.EASE_OUT)
	var steps = 2
	var step_dur = duration / float(steps)
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(cam, "offset", orig_offset + offset, step_dur)
	tw.tween_property(cam, "offset", orig_offset, step_dur * 0.5)

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

	var fx_type = fx_type_override if not fx_type_override.is_empty() else _detect_fx_type(skill_code, elem)
	
	match fx_type:
		"thunder_storm":
			_spawn_thunder_storm(target_pos, col, on_hit, is_crit)
		"sky_fall":
			_spawn_sky_fall(target_pos, skill_code, col, on_hit, is_crit, is_from_player)
		"radial_nova":
			_spawn_radial_nova(actual_start, actual_target, skill_code, col, on_hit, is_crit)
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

## 1. 动态飞行物弹道 (形态分类、流光彗尾、战锤自转、白炽光核)
func _spawn_projectile(
	start_pos: Vector2,
	target_pos: Vector2,
	fx_type: String,
	color: Color,
	on_hit: Callable,
	is_crit: bool,
	is_from_player: bool
) -> void:
	var proj = Node2D.new()
	proj.global_position = start_pos
	add_child(proj)
	
	# 选择对应形态剪影贴图与缩放比例
	var tex = FX_ORB_TEX
	var base_scale = Vector2(0.28, 0.28)
	var is_rotating = false
	var use_trail = true
	var trail_width = 6.0 if not is_crit else 8.5
	var tail_span = 0.32
	var fade_time = 0.06
	
	match fx_type:
		"hammer":
			tex = FX_HAMMER_TEX
			base_scale = Vector2(0.32, 0.32)
			is_rotating = true
			color = Color(1.15, 0.95, 0.50, 1.0) # 圣光专属白金色
		"arrow":
			tex = FX_ARROW_TEX
			# 箭矢贴图原尺寸 256x112，缩减长度(X=0.18，约46px)与粗细(Y=0.08，约9px)，呈现真实纤细锐利箭身
			base_scale = Vector2(0.18, 0.08)
			trail_width = 1.6 if not is_crit else 2.2
			tail_span = 0.08
			fade_time = 0.015
		"spike":
			tex = FX_SPIKE_TEX
			base_scale = Vector2(0.35, 0.35)
		"orb":
			tex = FX_ORB_TEX
			base_scale = Vector2(0.30, 0.30)
		_:
			tex = ATTACK_EFFECT_TEX
			base_scale = Vector2(0.38, 0.22)
	
	if is_crit:
		if fx_type == "arrow":
			base_scale *= 1.15
		else:
			base_scale *= 1.3
		
	# 主光核精灵 (Additive 发光)
	var sp = Sprite2D.new()
	sp.texture = tex
	sp.material = _additive_material
	sp.modulate = color
	sp.scale = base_scale
	proj.add_child(sp)
	
	# 炽白能量内核 (赋予火球/箭尖/战锤高能白炽光感)
	var core_sp = Sprite2D.new()
	core_sp.texture = tex
	core_sp.material = _additive_material
	if fx_type == "arrow":
		# 箭矢仅头部微亮，避免整身通体过曝
		core_sp.modulate = Color(1.0, 1.0, 1.0, 0.5)
		core_sp.scale = base_scale * Vector2(0.65, 0.5)
	else:
		core_sp.modulate = Color(1.0, 1.0, 1.0, 0.85)
		core_sp.scale = base_scale * 0.65
	proj.add_child(core_sp)
	
	# 流光彗尾 Line2D (动态沿轨迹拉伸出由粗变细、由亮变透的流光带)
	var trail: Line2D = null
	if use_trail:
		trail = Line2D.new()
		trail.material = _additive_material
		trail.width = trail_width
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		var grad = Gradient.new()
		if fx_type == "arrow":
			# 箭矢微风微光尾迹：透明度更轻柔，不产生浓厚光柱
			grad.set_color(0, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.0))
			grad.set_color(1, Color(color.r * 1.1, color.g * 1.1, color.b * 1.1, 0.65))
		else:
			grad.set_color(0, Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.0))
			grad.set_color(1, Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.9))
		trail.gradient = grad
		add_child(trail)

	var dist = start_pos.distance_to(target_pos)
	
	if is_from_player:
		# 玩家弹道：笔直迅捷疾冲
		if not is_rotating:
			proj.look_at(target_pos)
			
		var dur = clamp(dist / 1450.0, 0.09, 0.17)
		var tw = create_tween().bind_node(proj)
		tw.set_ease(Tween.EASE_OUT)
		
		tw.tween_method(
			_update_projectile_straight.bind(proj, sp, trail, start_pos, target_pos, is_rotating, base_scale, tail_span),
			0.0, 1.0, dur
		)
		tw.tween_callback(
			_on_projectile_arrived.bind(target_pos, color, is_crit, on_hit, proj, trail, "", fade_time)
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
		tw.set_ease(Tween.EASE_OUT)
		
		tw.tween_method(
			_update_projectile_curved.bind(proj, trail, p0, p1, p2, is_rotating),
			0.0, 1.0, dur
		)
		tw.tween_callback(
			_on_projectile_arrived.bind(target_pos, color, is_crit, on_hit, proj, trail)
		)

func _update_projectile_straight(
	t: float,
	proj: Node2D,
	sp: Sprite2D,
	trail: Line2D,
	start_pos: Vector2,
	target_pos: Vector2,
	is_rotating: bool,
	base_scale: Vector2,
	tail_span: float = 0.32
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
		var tail_t = max(0.0, t - tail_span)
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
	elem: String = "",
	fade_time: float = 0.06
) -> void:
	_spawn_hit_impact(target_pos, color, is_crit, elem)
	if on_hit.is_valid():
		on_hit.call()
		
	if is_instance_valid(proj):
		proj.queue_free()
		
	# 尾迹残留迅速淡出
	if trail and is_instance_valid(trail):
		var tw = create_tween().bind_node(trail)
		tw.tween_property(trail, "modulate:a", 0.0, fade_time)
		tw.tween_callback(trail.queue_free)

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
	_spawn_hit_impact(target_pos, Color(1.3, 1.3, 1.5), is_crit, "电")
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
	_spawn_hit_impact(target_pos, color, is_crit, "物理")
	if on_hit.is_valid():
		on_hit.call()
		
	var tw = create_tween().bind_node(slash)
	tw.tween_property(sp, "scale", max_scale, 0.04).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "rotation", 0.6, 0.09)
	tw.tween_property(sp, "modulate:a", 0.0, 0.06)
	tw.tween_callback(slash.queue_free)

## 4. 击中爆点微光与物理/元素爆裂粒子 (Hit Impact + Particle Burst)
func _spawn_hit_impact(pos: Vector2, color: Color, is_crit: bool, elem: String = "") -> void:
	var impact = Sprite2D.new()
	impact.global_position = pos
	impact.texture = FX_FLARE_TEX
	impact.material = _additive_material
	impact.modulate = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	var start_s = Vector2(0.12, 0.12)
	var end_s = Vector2(0.55, 0.55) if is_crit else Vector2(0.36, 0.36)
	impact.scale = start_s
	add_child(impact)
	
	var tw = create_tween().bind_node(impact)
	tw.set_parallel(true)
	tw.tween_property(impact, "scale", end_s, 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_property(impact, "rotation", randf_range(0.3, 0.8), 0.09)
	tw.tween_property(impact, "modulate:a", 0.0, 0.10).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(impact.queue_free)

	_spawn_element_particles(pos, elem, color, is_crit)

## 派发无贴图纯参数化打击粒子 (血溅/冰渣/烈焰爆裂)
func _spawn_element_particles(pos: Vector2, elem: String, color: Color, is_crit: bool) -> void:
	var el = elem.to_lower()
	var particle_scene: PackedScene = null
	
	if "冰" in el or "cold" in el:
		particle_scene = ICE_FROST_SCENE
	elif "火" in el or "fire" in el or "魔" in el:
		particle_scene = ENERGY_BURST_SCENE
	elif is_crit or "物" in el or "phys" in el:
		particle_scene = BLOOD_SPLASH_SCENE
		
	if particle_scene:
		var p = particle_scene.instantiate()
		p.global_position = pos
		if p is CPUParticles2D:
			p.emitting = true
			p.one_shot = true
		add_child(p)
		var p_tw = p.create_tween()
		p_tw.tween_interval(p.lifetime if p is CPUParticles2D else 0.55)
		p_tw.tween_callback(p.queue_free)

	if is_crit:
		freeze_frame(0.045, 0.1)
		screen_shake(3.5, 0.09)

## 触发格挡护盾破碎粒子 (Block Feedback)
func play_shield_block(pos: Vector2) -> void:
	var p = SHIELD_BREAK_SCENE.instantiate()
	p.global_position = pos
	if p is CPUParticles2D:
		p.emitting = true
		p.one_shot = true
	add_child(p)
	var p_tw = p.create_tween()
	p_tw.tween_interval(0.55)
	p_tw.tween_callback(p.queue_free)

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
	_spawn_projectile(start_pos, target_pos, "spike", Color(1.3, 1.4, 1.8), _on_fury_impact.bind(target_pos, on_hit, is_crit), is_crit, is_from_player)

func _on_fury_impact(target_pos: Vector2, on_hit: Callable, is_crit: bool) -> void:
	if on_hit.is_valid():
		on_hit.call()
	# 阶段 2: 目标处剧烈雷核核爆 + 向全屏四周爆发 10 道放射状折线雷霆
	_spawn_hit_impact(target_pos, Color(1.5, 1.6, 2.0), true, "电")
	
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

## 10. 雷暴术 (Thunder Storm)：苍穹虚空垂直疾速劈落白炽双层折线天雷 + 触地电火花炸裂
func _spawn_thunder_storm(target_pos: Vector2, color: Color, on_hit: Callable, is_crit: bool) -> void:
	var start_pos = target_pos - Vector2(randf_range(-15.0, 15.0), 260.0)
	var seg_count = 6
	var points: Array[Vector2] = []
	points.append(start_pos)
	
	for i in range(1, seg_count):
		var t = float(i) / float(seg_count)
		var pt = start_pos.lerp(target_pos, t)
		var jitter_x = randf_range(-22.0, 22.0)
		points.append(pt + Vector2(jitter_x, 0))
	points.append(target_pos)

	# 1. 外层发光电离折线 (青蓝电晕)
	var outer_line = Line2D.new()
	outer_line.material = _additive_material
	outer_line.default_color = Color(0.35, 0.75, 1.25, 0.75)
	outer_line.width = 6.0 if is_crit else 4.5
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for pt in points:
		outer_line.add_point(pt)
	add_child(outer_line)

	# 2. 内层高能白炽电芯 (刺目银白)
	var inner_line = Line2D.new()
	inner_line.material = _additive_material
	inner_line.default_color = Color(1.6, 1.7, 2.0, 1.0)
	inner_line.width = 2.4 if is_crit else 1.8
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for pt in points:
		inner_line.add_point(pt)
	add_child(inner_line)

	# 3. 产生 1 道微小折线分叉 (增加闪电真实感)
	var fork_line = Line2D.new()
	fork_line.material = _additive_material
	fork_line.default_color = Color(0.8, 1.2, 1.8, 0.8)
	fork_line.width = 1.4
	var fork_start_idx = seg_count / 2
	var f_start = points[fork_start_idx]
	var f_mid = f_start + Vector2(randf_range(-28.0, 28.0), 30.0)
	var f_end = f_mid + Vector2(randf_range(-20.0, 20.0), 25.0)
	fork_line.add_point(f_start)
	fork_line.add_point(f_mid)
	fork_line.add_point(f_end)
	add_child(fork_line)

	# 4. 瞬态落地 (0.045s 极速落雷)，触发命中反馈
	var tw = create_tween().bind_node(self)
	tw.tween_interval(0.045)
	tw.tween_callback(func():
		if on_hit.is_valid():
			on_hit.call()
		screen_shake(3.2 if is_crit else 2.2, 0.08)
		_spawn_thunder_impact_sparks(target_pos, is_crit)
	)

	# 5. 电光 0.12s 极速淡出销毁
	var tw_fade = create_tween().bind_node(outer_line)
	tw_fade.tween_property(outer_line, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_OUT)
	tw_fade.tween_callback(outer_line.queue_free)

	var tw_inner = create_tween().bind_node(inner_line)
	tw_inner.tween_property(inner_line, "modulate:a", 0.0, 0.10).set_ease(Tween.EASE_OUT)
	tw_inner.tween_callback(inner_line.queue_free)

	var tw_fork = create_tween().bind_node(fork_line)
	tw_fork.tween_property(fork_line, "modulate:a", 0.0, 0.09).set_ease(Tween.EASE_OUT)
	tw_fork.tween_callback(fork_line.queue_free)

## 雷暴触地高光电火花炸裂
func _spawn_thunder_impact_sparks(pos: Vector2, is_crit: bool) -> void:
	var spark_count = 8 if is_crit else 5
	for i in range(spark_count):
		var spark = Line2D.new()
		spark.material = _additive_material
		spark.default_color = Color(1.5, 1.6, 2.0, 1.0)
		spark.width = 1.8 if is_crit else 1.2
		var angle = randf_range(0.0, TAU)
		var s_dir = Vector2.RIGHT.rotated(angle)
		var dist = randf_range(16.0, 36.0)
		spark.add_point(pos)
		spark.add_point(pos + s_dir * dist)
		add_child(spark)

		var tw = create_tween().bind_node(spark)
		tw.tween_property(spark, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_callback(spark.queue_free)

## 工具函数：推断特效表现类型 (支持专属技能分流 + sky_fall/radial_nova/hammer/arrow/spike/orb/lightning/melee)
func _detect_fx_type(skill_code: String, elem: String) -> String:
	var sk = skill_code.to_lower()
	
	# 0. 空间宏观形态：天降坠击型 (暴风雪/陨石/天罚)
	if "blizzard" in sk or "meteor" in sk or "armageddon" in sk or "heavens_fist" in sk:
		return "sky_fall"

	# 0.5 专属形态：雷暴术 (Thunder Storm，天罚垂直疾速折线落雷)
	if "thunder_storm" in sk or (sk == "thunder_storm"):
		return "thunder_storm"
		
	# 1. 空间宏观形态：环形新星型 (霜之新星/剧毒新星/神圣新星)
	if "nova" in sk:
		return "radial_nova"
	
	# 2. 亚马逊专属标枪电系特征细化分流
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
		
	# 3. 战锤型
	if "hammer" in sk:
		return "hammer"
		
	# 4. 闪电型
	if "lightning" in sk or "chain" in sk or ("bolt" in sk and "light" in elem):
		return "lightning"
		
	# 5. 箭矢型
	if "arrow" in sk or "shot" in sk or "strafe" in sk:
		return "arrow"
		
	# 6. 尖刺/骨矛/标枪型
	if "spear" in sk or "spike" in sk or "javelin" in sk:
		return "spike"
		
	# 7. 经典近战或普通挥击判定 (包括随从近战斩击/重砸/撕咬/突刺)
	if sk in ["attack", "frenzy", "zeal", "bash", "stun", "concentrate", "smite", "berserk", "venom",
		"skeleton_slash", "golem_slam", "bloodgolem_strike", "irongolem_slam", "firegolem_punch",
		"grizzly_maul", "fenris_bite", "spirit_wolf_bite", "valkyrie_strike", "irongolem_thorns"]:
		return "melee"
		
	# 8. 法球/火球/冰弹/其它
	return "orb"

## 10. 天降坠击型技能 (Sky Fall: 暴风雪/陨石/天罚，高空垂直加速砸落，地面爆开元素圈)
func _spawn_sky_fall(
	target_pos: Vector2,
	skill_code: String,
	color: Color,
	on_hit: Callable,
	is_crit: bool,
	is_from_player: bool
) -> void:
	var sk = skill_code.to_lower()
	var is_blizzard = "blizzard" in sk
	var shard_count = 3 if is_blizzard else 1
	var fall_h = 240.0
	
	for i in range(shard_count):
		var x_offset = (float(i) - float(shard_count - 1) * 0.5) * 26.0 + randf_range(-6.0, 6.0)
		var shard_target = target_pos + Vector2(x_offset, randf_range(-8.0, 8.0))
		var shard_start = shard_target + Vector2(randf_range(-15.0, 15.0), -fall_h)
		
		var proj = Node2D.new()
		proj.global_position = shard_start
		add_child(proj)
		
		var sp = Sprite2D.new()
		sp.texture = FX_SPIKE_TEX if is_blizzard else FX_ORB_TEX
		sp.material = _additive_material
		sp.modulate = color
		sp.scale = Vector2(0.22, 0.45) if is_blizzard else Vector2(0.42, 0.42)
		sp.rotation = PI * 0.5 # 尖端垂直朝下
		proj.add_child(sp)
		
		var trail = Line2D.new()
		trail.material = _additive_material
		trail.width = 4.5
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		var grad = Gradient.new()
		grad.set_color(0, Color(color.r, color.g, color.b, 0.0))
		grad.set_color(1, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.85))
		trail.gradient = grad
		add_child(trail)
		
		var dur = 0.13 + float(i) * 0.035
		var tw = create_tween().bind_node(proj)
		tw.set_ease(Tween.EASE_IN)
		var sub_on_hit = on_hit if i == 0 else Callable()
		
		tw.tween_method(
			_update_projectile_straight.bind(proj, sp, trail, shard_start, shard_target, false, sp.scale),
			0.0, 1.0, dur
		)
		var shard_elem = "冰" if is_blizzard else "火"
		tw.tween_callback(
			_on_projectile_arrived.bind(shard_target, color, is_crit, sub_on_hit, proj, trail, shard_elem)
		)

## 11. 环形新星型技能 (Radial Nova: 霜之新星/剧毒新星，360度冲击波环与辐射散射)
func _spawn_radial_nova(
	start_pos: Vector2,
	target_pos: Vector2,
	skill_code: String,
	color: Color,
	on_hit: Callable,
	is_crit: bool
) -> void:
	var center = target_pos
	var ring = Line2D.new()
	ring.material = _additive_material
	ring.default_color = color
	ring.width = 4.5
	ring.closed = true
	add_child(ring)
	
	var pt_count = 20
	for p in range(pt_count):
		var ang = float(p) * (TAU / float(pt_count))
		ring.add_point(center + Vector2.RIGHT.rotated(ang) * 6.0)
		
	var tw = create_tween().bind_node(ring)
	var max_r = 95.0
	tw.tween_method(_update_nova_ring.bind(ring, center, pt_count), 6.0, max_r, 0.16).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.16).set_delay(0.05)
	tw.tween_callback(ring.queue_free)
	
	# 周围放射 8 发元素爆裂微斑
	for k in range(8):
		var ray_ang = float(k) * (TAU / 8.0)
		var ray_target = center + Vector2.RIGHT.rotated(ray_ang) * (max_r * 0.8)
		_spawn_hit_impact(ray_target, color * 0.75, false, "冰" if "frost" in skill_code else "毒")
		
	_spawn_hit_impact(center, color, is_crit, "冰" if "frost" in skill_code else "毒")
	if on_hit.is_valid():
		on_hit.call()

func _update_nova_ring(r: float, ring: Line2D, center: Vector2, pt_count: int) -> void:
	if not is_instance_valid(ring): return
	ring.clear_points()
	for p in range(pt_count):
		var ang = float(p) * (TAU / float(pt_count))
		ring.add_point(center + Vector2.RIGHT.rotated(ang) * r)
